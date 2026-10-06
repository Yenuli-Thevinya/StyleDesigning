import { useEffect, useState } from "react";
import { listQuotes, createQuote, updateQuote, updateQuoteStatus, acceptQuote, deleteQuote, draftQuoteFromAgent } from "../api/quotesApi";
import StatusBadge from "../components/StatusBadge";
import QuoteFormModal, { type QuoteFormPayload } from "../components/QuoteFormModal";
import AiDraftModal, { type AiDraftPayload } from "../components/AiDraftModal";
import type { Quote, QuoteItem } from "../types";
import "../styles/theme.css";

const STATUS_OPTIONS = ["Draft", "Submitted", "ClientReview", "RevisionRequested", "Accepted", "Rejected"];
const PAGE_SIZE = 10;

function formatMoney(value: number | undefined) {
  const num = Number(value);
  if (isNaN(num)) return "LKR 0.00";
  return `LKR ${num.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
}

function getStatusStr(s: any): string {
  if (!s) return "";
  const val = typeof s === "string" ? s : s.value ?? s.name ?? "";
  if (val === "Stage1Pending") return "Submitted";
  if (val === "Stage1Released") return "ClientReview";
  if (val === "Stage2Approved") return "Accepted";
  if (val === "Stage2ChangesRequested" || val === "Stage1RevisionRequested") return "RevisionRequested";
  if (val === "Stage1Rejected" || val === "Stage2Rejected") return "Rejected";
  return val;
}

interface QuotesPageProps {
  onGoToContracts?: () => void;
}

export default function QuotesPage({ onGoToContracts }: QuotesPageProps = {}) {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [modalOpen, setModalOpen] = useState(false);
  const [editingQuote, setEditingQuote] = useState<Quote | null>(null);
  const [aiModalOpen, setAiModalOpen] = useState(false);

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const result = await listQuotes({ status: statusFilter || undefined, search: search || undefined, page, pageSize: PAGE_SIZE });
      setQuotes(result?.items || []);
      setTotalCount(result?.totalCount || 0);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Couldn't load quotes.");
      setQuotes([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, statusFilter]);

  function handleSearchSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setPage(1);
    refresh();
  }

  async function handleCreate(payload: QuoteFormPayload) {
    await createQuote({
      ...payload,
      projectRequestId: payload.projectRequestId ?? crypto.randomUUID(),
      designerId: payload.designerId ?? crypto.randomUUID(),
    });
    setModalOpen(false);
    refresh();
  }

  async function handleEdit(payload: QuoteFormPayload) {
    if (!editingQuote?.id) return;
    await updateQuote(editingQuote.id, payload);
    setEditingQuote(null);
    refresh();
  }

  async function handleAdvance(quote: Quote) {
    if (!quote?.id) return;
    const transitions: Record<string, string> = {
      Draft: "Submitted",
      Submitted: "ClientReview",
    };
    const status = getStatusStr(quote?.status);
    const next = transitions[status];
    if (!next) return;
    await updateQuoteStatus(quote.id, next);
    refresh();
  }

  async function handleAccept(quote: Quote) {
    if (!quote?.id) return;
    try {
      await acceptQuote(quote.id);
      await refresh();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to accept quote.");
    }
  }

  async function handleReject(quote: Quote) {
    if (!quote?.id) return;
    await updateQuoteStatus(quote.id, "Rejected");
    refresh();
  }

  async function handleDelete(quote: Quote) {
    if (!quote?.id) return;
    if (!window.confirm("Delete this draft quote? This can't be undone.")) return;
    await deleteQuote(quote.id);
    refresh();
  }

  const [viewingQuote, setViewingQuote] = useState<Quote | null>(null);

  async function handleAiDraft(
    payload: AiDraftPayload,
    finalQuote?: { scopeSummary: string; notes: string; items: QuoteItem[] }
  ) {
    if (finalQuote && finalQuote.items.length > 0) {
      await createQuote({
        projectRequestId: payload.projectRequestId ?? crypto.randomUUID(),
        designerId: payload.designerId ?? crypto.randomUUID(),
        scopeSummary: finalQuote.scopeSummary,
        notes: finalQuote.notes,
        isAiGenerated: true,
        items: finalQuote.items,
      });
    } else {
      await draftQuoteFromAgent(payload);
    }
    setAiModalOpen(false);
    refresh();
  }

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));

  return (
    <div className="qc-page">
      <div className="qc-page__header">
        <div>
          <div className="qc-page__title">Quotes</div>
          <div className="qc-page__subtitle">Draft, review, and turn accepted quotes into contracts.</div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <button
            className="qc-btn"
            style={{
              background: "linear-gradient(135deg, #C48A36 0%, #D97706 100%)",
              color: "#ffffff",
              border: "none",
              fontWeight: 600,
              boxShadow: "0 2px 8px rgba(196, 138, 54, 0.35)",
              display: "flex",
              alignItems: "center",
              gap: 6
            }}
            onClick={() => setAiModalOpen(true)}
          >
            <span></span> Generate with AI
          </button>
          <button className="qc-btn qc-btn--primary" onClick={() => setModalOpen(true)}>New quote</button>
        </div>
      </div>

      <div className="qc-toolbar">
        <form onSubmit={handleSearchSubmit} style={{ display: "flex", gap: 8 }}>
          <input
            className="qc-input"
            placeholder="Search scope summary…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <button type="submit" className="qc-btn qc-btn--ghost">Search</button>
        </form>

        <select
          className="qc-select"
          value={statusFilter}
          onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
        >
          <option value="">All statuses</option>
          {STATUS_OPTIONS.map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      <div className="qc-table-card">
        <div className="qc-table-responsive">
          <table className="qc-table">
            <thead>
              <tr>
                <th style={{ minWidth: 260 }}>Scope</th>
                <th style={{ width: 100 }}>Status</th>
                <th style={{ width: 80, textAlign: "center" }}>Items</th>
                <th style={{ width: 130 }}>Total</th>
                <th style={{ width: 110 }}>Updated</th>
                <th style={{ textAlign: "right", minWidth: 210, paddingRight: 20 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr><td colSpan={6} className="qc-table-empty">Loading quotes…</td></tr>
              )}
              {!loading && error && (
                <tr><td colSpan={6} className="qc-table-empty" style={{ color: "var(--qc-danger)" }}>{error}</td></tr>
              )}
              {!loading && !error && (!quotes || quotes.length === 0) && (
                <tr><td colSpan={6} className="qc-table-empty">No quotes yet. Create one or generate with AI to get started.</td></tr>
              )}
              {!loading && !error && quotes?.map((q) => {
                const statusStr = getStatusStr(q.status);
                return (
                  <tr key={q.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                        <span style={{ fontWeight: 600 }}>{q.scopeSummary || "Untitled scope"}</span>
                        {q.isAiGenerated && (
                          <span className="qc-ai-tag">✨ AI Draft</span>
                        )}
                      </div>
                      {q.notes && (
                        <div style={{ fontSize: 11.5, color: "var(--qc-muted)", marginTop: 2, maxWidth: 360, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {q.notes}
                        </div>
                      )}
                    </td>
                    <td><StatusBadge status={q.status} /></td>
                    <td style={{ textAlign: "center" }}>
                      <button
                        type="button"
                        className="qc-btn qc-btn--ghost qc-btn--sm"
                        style={{ padding: "2px 8px", fontSize: 12 }}
                        onClick={() => setViewingQuote(q)}
                        title="View line items"
                      >
                        {q.items?.length ?? 0} item{(q.items?.length ?? 0) === 1 ? "" : "s"}
                      </button>
                    </td>
                    <td className="qc-money">{formatMoney(q.totalCost)}</td>
                    <td style={{ color: "var(--qc-muted)", fontSize: 12.5, whiteSpace: "nowrap" }}>
                      {q.updatedAt ? new Date(q.updatedAt).toLocaleDateString() : "—"}
                    </td>
                    <td style={{ textAlign: "right", paddingRight: 20 }}>
                      <div style={{ display: "flex", gap: 6, justifyContent: "flex-end", alignItems: "center", flexWrap: "nowrap" }}>
                        {(statusStr === "Draft" || statusStr === "RevisionRequested") && (
                          <button className="qc-btn qc-btn--ghost qc-btn--sm" onClick={() => setEditingQuote(q)}>Edit</button>
                        )}
                        {statusStr === "Draft" && (
                          <button className="qc-btn qc-btn--ghost qc-btn--sm" onClick={() => handleAdvance(q)}>Submit</button>
                        )}
                        {(statusStr === "Submitted" || statusStr === "ClientReview") && (
                          <>
                            <button className="qc-btn qc-btn--primary qc-btn--sm" onClick={() => handleAccept(q)}>Accept</button>
                            <button className="qc-btn qc-btn--danger qc-btn--sm" onClick={() => handleDelete(q)}>Delete</button>
                          </>
                        )}
                        {statusStr === "Draft" && (
                          <button className="qc-btn qc-btn--danger qc-btn--sm" onClick={() => handleDelete(q)}>Delete</button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="qc-pagination">
          <span>{totalCount} quote{totalCount === 1 ? "" : "s"}</span>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <button className="qc-btn qc-btn--ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</button>
            <span>Page {page} of {totalPages}</span>
            <button className="qc-btn qc-btn--ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</button>
          </div>
        </div>
      </div>

      {/* Quote Details View Modal */}
      {viewingQuote && (
        <div className="qc-modal-backdrop" onMouseDown={() => setViewingQuote(null)}>
          <div className="qc-modal qc-modal--lg" onMouseDown={(e) => e.stopPropagation()}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 16 }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <div className="qc-modal__title" style={{ margin: 0 }}>Quote Details</div>
                  {viewingQuote.isAiGenerated && <span className="qc-ai-tag">✨ AI Draft</span>}
                  <StatusBadge status={viewingQuote.status} />
                </div>
                <div style={{ fontSize: 13, color: "var(--qc-muted)", marginTop: 4 }}>
                  {viewingQuote.scopeSummary}
                </div>
              </div>
              <button type="button" className="qc-icon-btn" onClick={() => setViewingQuote(null)}>✕</button>
            </div>

            {viewingQuote.notes && (
              <div style={{ background: "var(--qc-surface-sunken)", padding: "10px 14px", borderRadius: 8, fontSize: 12.5, marginBottom: 16, borderLeft: "3px solid var(--qc-primary)" }}>
                <strong>Notes:</strong> {viewingQuote.notes}
              </div>
            )}

            <div style={{ marginBottom: 16 }}>
              <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>Itemized Cost Breakdown</div>
              <div style={{ border: "1px solid var(--qc-border)", borderRadius: 8, overflow: "hidden" }}>
                <table className="qc-table" style={{ margin: 0 }}>
                  <thead>
                    <tr>
                      <th>Category</th>
                      <th>Description</th>
                      <th style={{ textAlign: "right" }}>Quantity</th>
                      <th style={{ textAlign: "right" }}>Unit Cost</th>
                      <th style={{ textAlign: "right" }}>Line Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(viewingQuote.items || []).map((item, idx) => (
                      <tr key={item.id || idx}>
                        <td>
                          <span className={`qc-category-badge qc-cat--${item.category || "Other"}`}>
                            {item.category}
                          </span>
                        </td>
                        <td>{item.description}</td>
                        <td style={{ textAlign: "right" }}>{item.quantity}</td>
                        <td style={{ textAlign: "right" }}>{formatMoney(item.unitCost)}</td>
                        <td style={{ textAlign: "right", fontWeight: 600 }}>
                          {formatMoney((item.quantity || 1) * (item.unitCost || 0))}
                        </td>
                      </tr>
                    ))}
                    <tr style={{ background: "var(--qc-surface-sunken)" }}>
                      <td colSpan={4} style={{ fontWeight: 700, textAlign: "right" }}>Total Cost:</td>
                      <td style={{ fontWeight: 700, textAlign: "right", color: "var(--qc-primary)", fontSize: 15 }}>
                        {formatMoney(viewingQuote.totalCost)}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>
              <button type="button" className="qc-btn qc-btn--ghost" onClick={() => setViewingQuote(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {modalOpen && (
        <QuoteFormModal onSubmit={handleCreate} onClose={() => setModalOpen(false)} />
      )}
      {editingQuote && (
        <QuoteFormModal
          key={`${editingQuote.id}-${editingQuote.updatedAt || ""}`}
          initialQuote={editingQuote}
          onSubmit={handleEdit}
          onClose={() => setEditingQuote(null)}
        />
      )}
      {aiModalOpen && (
        <AiDraftModal onSubmit={handleAiDraft} onClose={() => setAiModalOpen(false)} />
      )}
    </div>
  );
}