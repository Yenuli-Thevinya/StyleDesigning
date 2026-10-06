using System;
using System.Linq;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StyleSync.Api.Common.Persistence;
using StyleSync.Api.DTOs;
using StyleSync.Api.Models;

namespace StyleSync.Api.Controllers
{
    [ApiController]
    [Route("api/quotes")]
    public class QuotesController : ControllerBase
    {
        private readonly AppDbContext _db;

        public QuotesController(AppDbContext db)
        {
            _db = db;
        }

        // GET /api/quotes?status=Submitted&designerId=...&search=modern&page=1&pageSize=20&sort=-createdAt
        [HttpGet]
        public async Task<ActionResult<PagedResult<QuoteResponseDto>>> GetAll(
            [FromQuery] QuoteStatus? status,
            [FromQuery] Guid? designerId,
            [FromQuery] Guid? projectRequestId,
            [FromQuery] string? search,
            [FromQuery] string sort = "-createdAt",
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            page = Math.Max(page, 1);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Quotes.Include(q => q.Items).Include(q => q.Contract).AsQueryable();

            if (status.HasValue) query = query.Where(q => q.Status == status.Value);
            if (designerId.HasValue) query = query.Where(q => q.DesignerId == designerId.Value);
            if (projectRequestId.HasValue) query = query.Where(q => q.ProjectRequestId == projectRequestId.Value);
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(q => q.ScopeSummary != null && q.ScopeSummary.ToLower().Contains(term));
            }

            query = sort.TrimStart('-') switch
            {
                "totalCost" => sort.StartsWith('-') ? query.OrderByDescending(q => q.TotalCost) : query.OrderBy(q => q.TotalCost),
                "status" => sort.StartsWith('-') ? query.OrderByDescending(q => q.Status) : query.OrderBy(q => q.Status),
                _ => sort.StartsWith('-') ? query.OrderByDescending(q => q.CreatedAt) : query.OrderBy(q => q.CreatedAt),
            };

            var totalCount = await query.CountAsync();
            var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

            return Ok(new PagedResult<QuoteResponseDto>
            {
                Items = items.Select(ToResponseDto).ToList(),
                Page = page,
                PageSize = pageSize,
                TotalCount = totalCount
            });
        }

        // GET /api/quotes/{id}
        [HttpGet("{id:guid}")]
        public async Task<ActionResult<QuoteResponseDto>> GetById(Guid id)
        {
            var quote = await _db.Quotes.Include(q => q.Items).Include(q => q.Contract)
                .FirstOrDefaultAsync(q => q.Id == id);

            if (quote is null) return NotFound(new { message = $"Quote {id} was not found." });
            return Ok(ToResponseDto(quote));
        }

        // POST /api/quotes
        // Used by (a) the backend's AI-workflow endpoint, saving the Budget/Scope
        // Agent's draft as IsAiGenerated = true, or (b) a Designer creating one manually.
        [HttpPost]
        public async Task<ActionResult<QuoteResponseDto>> Create(CreateQuoteDto dto)
        {
            if (dto.Items.Count == 0)
                return BadRequest(new { message = "A quote needs at least one line item." });

            var projectRequestId = dto.ProjectRequestId.HasValue && dto.ProjectRequestId.Value != Guid.Empty
                ? dto.ProjectRequestId.Value
                : Guid.NewGuid();

            var designerId = dto.DesignerId.HasValue && dto.DesignerId.Value != Guid.Empty
                ? dto.DesignerId.Value
                : Guid.NewGuid();

            var quote = new Quote
            {
                Id = Guid.NewGuid(),
                ProjectRequestId = projectRequestId,
                DesignerId = designerId,
                ScopeSummary = dto.ScopeSummary,
                Notes = dto.Notes,
                IsAiGenerated = dto.IsAiGenerated,
                Status = QuoteStatus.Draft,
                Items = dto.Items.Select(i => new QuoteItem
                {
                    Id = Guid.NewGuid(),
                    Description = i.Description,
                    Category = i.Category,
                    Quantity = i.Quantity,
                    UnitCost = i.UnitCost,
                    LineTotal = i.Quantity * i.UnitCost
                }).ToList()
            };
            quote.TotalCost = quote.Items.Sum(i => i.LineTotal);

            _db.Quotes.Add(quote);
            await _db.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = quote.Id }, ToResponseDto(quote));
        }

        // POST /api/quotes/draft-from-agent
        // Step 7's bridge: calls the Python Budget/Scope Agent, then saves its
        // output as a normal Draft quote with IsAiGenerated = true — exactly what
        // a real LangGraph node would hand off to this component once the full
        // pipeline exists.
        [HttpPost("draft-from-agent")]
        public async Task<ActionResult<QuoteResponseDto>> DraftFromAgent(
            DraftQuoteFromAgentDto dto,
            [FromServices] IHttpClientFactory httpClientFactory)
        {
            var projectRequestId = dto.ProjectRequestId.HasValue && dto.ProjectRequestId.Value != Guid.Empty
                ? dto.ProjectRequestId.Value
                : Guid.NewGuid();

            var designerId = dto.DesignerId.HasValue && dto.DesignerId.Value != Guid.Empty
                ? dto.DesignerId.Value
                : Guid.NewGuid();

            var client = httpClientFactory.CreateClient("AiService");

            var agentRequest = new AgentBudgetScopeRequest
            {
                RoomType = dto.RoomType,
                RoomSizeSqft = dto.RoomSizeSqft,
                BudgetMin = dto.BudgetMin,
                BudgetMax = dto.BudgetMax,
                StyleProfile = dto.StyleProfile,
                StyleConfidence = dto.StyleConfidence,
                Preferences = dto.Preferences
            };

            AgentBudgetScopeResponse? agentResult = null;
            try
            {
                var agentHttpResponse = await client.PostAsJsonAsync("/agents/budget-scope", agentRequest);
                if (agentHttpResponse.IsSuccessStatusCode)
                {
                    agentResult = await agentHttpResponse.Content.ReadFromJsonAsync<AgentBudgetScopeResponse>();
                }
            }
            catch (Exception)
            {
                // Fall back to deterministic calculation
            }

            if (agentResult is null || agentResult.Items.Count == 0)
            {
                agentResult = GenerateFallbackEstimate(agentRequest);
            }

            var quoteId = Guid.NewGuid();
            var quote = new Quote
            {
                Id = quoteId,
                ProjectRequestId = projectRequestId,
                DesignerId = designerId,
                Status = QuoteStatus.Draft,
                IsAiGenerated = true,
                ScopeSummary = agentResult.ScopeSummary,
                Notes = $"{agentResult.Notes} (agent source: {agentResult.Source})",
                Items = agentResult.Items.Select(i => new QuoteItem
                {
                    Id = Guid.NewGuid(),
                    QuoteId = quoteId,
                    Description = i.Description,
                    Category = Enum.TryParse<QuoteItemCategory>(i.Category, true, out var cat) ? cat : QuoteItemCategory.Other,
                    Quantity = i.Quantity,
                    UnitCost = i.UnitCost,
                    LineTotal = i.Quantity * i.UnitCost
                }).ToList()
            };
            quote.TotalCost = quote.Items.Sum(i => i.LineTotal);

            _db.Quotes.Add(quote);
            await _db.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = quote.Id }, ToResponseDto(quote));
        }

        // POST /api/quotes/draft-preview
        // Calls the Python Budget/Scope Agent to preview the draft scope and cost breakdown
        // without saving to the database.
        [HttpPost("draft-preview")]
        public async Task<ActionResult<AgentBudgetScopeResponse>> DraftPreview(
            DraftQuoteFromAgentDto dto,
            [FromServices] IHttpClientFactory httpClientFactory)
        {
            var client = httpClientFactory.CreateClient("AiService");

            var agentRequest = new AgentBudgetScopeRequest
            {
                RoomType = dto.RoomType,
                RoomSizeSqft = dto.RoomSizeSqft,
                BudgetMin = dto.BudgetMin,
                BudgetMax = dto.BudgetMax,
                StyleProfile = dto.StyleProfile,
                StyleConfidence = dto.StyleConfidence,
                Preferences = dto.Preferences
            };

            AgentBudgetScopeResponse? agentResult = null;
            try
            {
                var agentHttpResponse = await client.PostAsJsonAsync("/agents/budget-scope", agentRequest);
                if (agentHttpResponse.IsSuccessStatusCode)
                {
                    agentResult = await agentHttpResponse.Content.ReadFromJsonAsync<AgentBudgetScopeResponse>();
                }
            }
            catch (Exception)
            {
                // Fall back to deterministic calculation
            }

            if (agentResult is null || agentResult.Items.Count == 0)
            {
                agentResult = GenerateFallbackEstimate(agentRequest);
            }

            return Ok(agentResult);
        }

        private static AgentBudgetScopeResponse GenerateFallbackEstimate(AgentBudgetScopeRequest request)
        {
            decimal targetBudget = (request.BudgetMin + request.BudgetMax) / 2 > 0
                ? (request.BudgetMin + request.BudgetMax) / 2
                : (decimal)request.RoomSizeSqft * 800m;

            var style = string.IsNullOrWhiteSpace(request.StyleProfile) ? "Modern" : request.StyleProfile;
            var room = string.IsNullOrWhiteSpace(request.RoomType) ? "Living Room" : request.RoomType;

            var split = new (string Category, decimal Pct, string Desc)[]
            {
                ("Design", 0.10m, $"Design — {style.ToLower()} {room.ToLower()} concept & planning"),
                ("Labor", 0.30m, $"Labor — {style.ToLower()} {room.ToLower()} installation & craftsmanship"),
                ("Materials", 0.35m, $"Materials — {style.ToLower()} {room.ToLower()} fixtures & finishes"),
                ("Furniture", 0.25m, $"Furniture — {style.ToLower()} {room.ToLower()} curated styling"),
            };

            var items = new List<AgentQuoteItemDraft>();
            foreach (var s in split)
            {
                decimal unitCost = Math.Round((targetBudget * s.Pct) / 100m, 0) * 100m;
                items.Add(new AgentQuoteItemDraft
                {
                    Description = s.Desc,
                    Category = s.Category,
                    Quantity = 1,
                    UnitCost = unitCost
                });
            }

            decimal total = items.Sum(i => i.UnitCost * i.Quantity);

            return new AgentBudgetScopeResponse
            {
                ScopeSummary = $"{style} {room.ToLower()} refresh, {request.RoomSizeSqft:0} sq ft.",
                Items = items,
                Notes = "Estimate generated via category ratio allocation (Design 10%, Labor 30%, Materials 35%, Furniture 25%).",
                EstimatedTotal = total,
                WithinBudget = request.BudgetMax > 0 ? (total >= request.BudgetMin && total <= request.BudgetMax) : true,
                Source = "fallback"
            };
        }

        // PUT /api/quotes/{id}
        // A Designer revising line items before client approval (PRD section 9, Update row).
        // Revising a quote always clears IsAiGenerated — once a human touches the
        // numbers it's no longer purely the agent's draft.
        [HttpPut("{id:guid}")]
        public async Task<ActionResult<QuoteResponseDto>> Update(Guid id, UpdateQuoteDto dto)
        {
            var quote = await _db.Quotes.Include(q => q.Items).FirstOrDefaultAsync(q => q.Id == id);
            if (quote is null) return NotFound(new { message = $"Quote {id} was not found." });

            if (quote.Status is QuoteStatus.Accepted or QuoteStatus.Rejected)
                return BadRequest(new { message = $"A {quote.Status} quote can no longer be edited." });

            if (dto.ScopeSummary is not null) quote.ScopeSummary = dto.ScopeSummary;
            if (dto.Notes is not null) quote.Notes = dto.Notes;

            if (dto.Items is not null)
            {
                if (dto.Items.Count == 0)
                    return BadRequest(new { message = "A quote needs at least one line item." });

                _db.QuoteItems.RemoveRange(quote.Items);

                var newItems = dto.Items.Select(i => new QuoteItem
                {
                    Id = Guid.NewGuid(),
                    QuoteId = quote.Id,
                    Description = i.Description,
                    Category = i.Category,
                    Quantity = i.Quantity,
                    UnitCost = i.UnitCost,
                    LineTotal = i.Quantity * i.UnitCost
                }).ToList();

                _db.QuoteItems.AddRange(newItems);

                quote.TotalCost = newItems.Sum(i => i.LineTotal);
                quote.Items = newItems;
                quote.IsAiGenerated = false;
            }

            quote.UpdatedAt = DateTime.UtcNow;

            // Two overlapping saves for the same quote (e.g. a double-click, or a
            // retry after a dropped connection) can race here: the second save's
            // snapshot goes stale mid-flight once the first one commits. Catch it
            // and return a clean 409 instead of an unhandled 500.
            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException ex)
            {
                var entityName = ex.Entries.FirstOrDefault()?.Entity.GetType().Name ?? "Unknown";
                return Conflict(new { message = $"Concurrency on {entityName}: {ex.Message}" });
            }

            return Ok(ToResponseDto(quote));
        }

        // PATCH /api/quotes/{id}/status
        // Drives Draft → Submitted → Client Review → Revision Requested → Accepted/Rejected.
        // Acceptance is handled by the dedicated /accept endpoint below, not this one,
        // because acceptance has a side effect (creating a Contract).
        [HttpPatch("{id:guid}/status")]
        public async Task<ActionResult<QuoteResponseDto>> UpdateStatus(Guid id, UpdateQuoteStatusDto dto)
        {
            if (dto.Status == QuoteStatus.Accepted)
                return BadRequest(new { message = "Use POST /api/quotes/{id}/accept to accept a quote — it also creates the contract." });

            var quote = await _db.Quotes.Include(q => q.Items).FirstOrDefaultAsync(q => q.Id == id);
            if (quote is null) return NotFound(new { message = $"Quote {id} was not found." });

            quote.Status = dto.Status;
            quote.UpdatedAt = DateTime.UtcNow;

            // When a client submits a quote, auto-create a linked contract so it appears in the designer's Contracts Studio ready to review and sign
            if (dto.Status == QuoteStatus.Submitted)
            {
                var existingContract = await _db.Contracts.FirstOrDefaultAsync(c => c.QuoteId == quote.Id);
                if (existingContract is null)
                {
                    var contract = new Contract
                    {
                        Id = Guid.NewGuid(),
                        QuoteId = quote.Id,
                        ProjectRequestId = quote.ProjectRequestId,
                        DesignerId = quote.DesignerId,
                        ClientId = quote.ProjectRequestId != Guid.Empty ? quote.ProjectRequestId : Guid.NewGuid(),
                        TotalAmount = quote.TotalCost,
                        TermsSummary = $"Official StyleSync Binding Agreement for {quote.ScopeSummary ?? "Interior Design"}. Milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover.",
                        Status = ContractStatus.PendingSignature,
                        Quote = quote
                    };
                    _db.Contracts.Add(contract);
                }
            }

            await _db.SaveChangesAsync();

            return Ok(ToResponseDto(quote));
        }

        // POST /api/quotes/{id}/accept
        // The one place a Contract gets created. Creates a corresponding Contract
        // and transitions the quote to Accepted.
        [HttpPost("{id:guid}/accept")]
        public async Task<ActionResult<ContractResponseDto>> Accept(Guid id, [FromQuery] string? clientId = null)
        {
            var quote = await _db.Quotes.Include(q => q.Items).Include(q => q.Contract)
                .FirstOrDefaultAsync(q => q.Id == id);

            if (quote is null) return NotFound(new { message = $"Quote {id} was not found." });
            if (quote.Contract is not null) return BadRequest(new { message = "This quote already has a contract." });
            if (quote.Status is QuoteStatus.Accepted or QuoteStatus.Rejected)
                return BadRequest(new { message = $"Quote is already {quote.Status}." });

            quote.Status = QuoteStatus.Accepted;
            quote.UpdatedAt = DateTime.UtcNow;

            Guid resolvedClientId = (Guid.TryParse(clientId, out var parsedGuid) && parsedGuid != Guid.Empty)
                ? parsedGuid
                : (quote.ProjectRequestId != Guid.Empty ? quote.ProjectRequestId : Guid.NewGuid());

            var contract = new Contract
            {
                Id = Guid.NewGuid(),
                QuoteId = quote.Id,
                ProjectRequestId = quote.ProjectRequestId,
                DesignerId = quote.DesignerId,
                ClientId = resolvedClientId,
                TotalAmount = quote.TotalCost,
                TermsSummary = string.IsNullOrWhiteSpace(quote.ScopeSummary) ? "Interior Design Contract" : quote.ScopeSummary,
                Status = ContractStatus.Draft,
                Quote = quote
            };

            _db.Contracts.Add(contract);
            await _db.SaveChangesAsync();

            return CreatedAtAction(
                nameof(ContractsController.GetById),
                "Contracts",
                new { id = contract.Id },
                ToContractResponseDto(contract));
        }

        // DELETE /api/quotes/{id}
        // Allows deleting a Draft or Submitted quote that has not been converted to an accepted contract.
        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            var quote = await _db.Quotes.Include(q => q.Items).Include(q => q.Contract).FirstOrDefaultAsync(q => q.Id == id);
            if (quote is null) return NotFound(new { message = $"Quote {id} was not found." });

            if (quote.Contract is not null || quote.Status == QuoteStatus.Accepted)
                return BadRequest(new { message = "An accepted quote with an existing contract cannot be deleted." });

            _db.QuoteItems.RemoveRange(quote.Items);
            _db.Quotes.Remove(quote);
            await _db.SaveChangesAsync();
            return NoContent();
        }

        private static QuoteResponseDto ToResponseDto(Quote q) => new()
        {
            Id = q.Id,
            ProjectRequestId = q.ProjectRequestId,
            DesignerId = q.DesignerId,
            Status = q.Status,
            IsAiGenerated = q.IsAiGenerated,
            ScopeSummary = q.ScopeSummary,
            Notes = q.Notes,
            TotalCost = q.TotalCost,
            CreatedAt = q.CreatedAt,
            UpdatedAt = q.UpdatedAt,
            ContractId = q.Contract?.Id,
            Items = q.Items.Select(i => new QuoteItemResponseDto
            {
                Id = i.Id,
                Description = i.Description,
                Category = i.Category,
                Quantity = i.Quantity,
                UnitCost = i.UnitCost,
                LineTotal = i.LineTotal
            }).ToList()
        };

        private static ContractResponseDto ToContractResponseDto(Contract c) => new()
        {
            Id = c.Id,
            QuoteId = c.QuoteId,
            ProjectRequestId = c.ProjectRequestId,
            DesignerId = c.DesignerId,
            ClientId = c.ClientId,
            Status = c.Status,
            TotalAmount = c.TotalAmount,
            StartDate = c.StartDate,
            EndDate = c.EndDate,
            SignedAt = c.SignedAt,
            TermsSummary = c.TermsSummary,
            CreatedAt = c.CreatedAt,
            UpdatedAt = c.UpdatedAt,
            Quote = c.Quote == null ? null : ToResponseDto(c.Quote)
        };
    }
}
