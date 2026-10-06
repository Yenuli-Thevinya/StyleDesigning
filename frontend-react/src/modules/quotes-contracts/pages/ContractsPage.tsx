import { useEffect, useState } from "react";
import { listContracts, signContract, cancelContract } from "../api/contractsApi";
import { getQuote } from "../api/quotesApi";
import StatusBadge from "../components/StatusBadge";
import type { Contract, Quote } from "../types";
import "../styles/theme.css";

const STATUS_OPTIONS = ["Draft", "PendingSignature", "Active", "Completed", "Cancelled"];
const PAGE_SIZE = 10;

function formatMoney(value: number | undefined) {
  const num = Number(value);
  if (isNaN(num)) return "LKR 0.00";
  return `LKR ${num.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
}

export default function ContractsPage() {
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Viewing contract with fully submitted quote details
  const [viewingContract, setViewingContract] = useState<Contract | null>(null);
  const [loadingQuote, setLoadingQuote] = useState(false);

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const result = await listContracts({ status: statusFilter || undefined, page, pageSize: PAGE_SIZE });
      setContracts(result?.items || []);
      setTotalCount(result?.totalCount || 0);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Couldn't load contracts.");
      setContracts([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, statusFilter]);

  async function handleOpenContract(contract: Contract) {
    setViewingContract(contract);
    const hasItems = Boolean(contract.quote?.items && contract.quote.items.length > 0);
    if (!hasItems && contract.quoteId) {
      setLoadingQuote(true);
      try {
        const fullQuote = await getQuote(contract.quoteId);
        setViewingContract((prev) => (prev && prev.id === contract.id ? { ...prev, quote: fullQuote } : prev));
      } catch (err) {
        console.error("Could not load attached quote details", err);
      } finally {
        setLoadingQuote(false);
      }
    }
  }

  async function handleSign(contract: Contract) {
    if (!contract?.id) return;
    const updated = await signContract(contract.id, new Date().toISOString());
    if (viewingContract?.id === contract.id) {
      setViewingContract((prev) => prev ? { ...prev, status: "Active", signedAt: updated.signedAt } : null);
    }
    refresh();
  }

  async function handleCancel(contract: Contract) {
    if (!contract?.id) return;
    if (!window.confirm("Cancel this contract? It will be kept for the record but marked Cancelled.")) return;
    await cancelContract(contract.id);
    if (viewingContract?.id === contract.id) {
      setViewingContract((prev) => prev ? { ...prev, status: "Cancelled" } : null);
    }
    refresh();
  }

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));
  const activeQuote: Quote | undefined = viewingContract?.quote;

  return (
    <div className="qc-page">
      <div className="qc-page__header">
        <div>
          <div className="qc-page__title">Contracts Dashboard</div>
          <div className="qc-page__subtitle">Review legally binding agreements, track signatures, and inspect full submitted quote specifications.</div>
        </div>
      </div>

      <div className="qc-toolbar">
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
                <th style={{ minWidth: 260 }}>Contract & Linked Quote</th>
                <th style={{ width: 120 }}>Status</th>
                <th style={{ width: 140 }}>Amount</th>
                <th style={{ width: 120 }}>Signed</th>
                <th style={{ width: 110 }}>Updated</th>
                <th style={{ textAlign: "right", minWidth: 210, paddingRight: 20 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr><td colSpan={6} className="qc-table-empty">Loading contracts…</td></tr>
              )}
              {!loading && error && (
                <tr><td colSpan={6} className="qc-table-empty" style={{ color: "var(--qc-danger)" }}>{error}</td></tr>
              )}
              {!loading && !error && (!contracts || contracts.length === 0) && (
                <tr><td colSpan={6} className="qc-table-empty">No contracts found.</td></tr>
              )}
              {!loading && !error && contracts?.map((c) => {
                const quoteItemsCount = c.quote?.items?.length ?? 0;
                return (
                  <tr key={c.id}>
                    <td>
                      <div style={{ fontWeight: 600, fontSize: 13.5 }}>
                        {c.termsSummary || c.quote?.scopeSummary || "Interior Design Agreement"}
                      </div>
                      <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 4 }}>
                        <span style={{ fontFamily: "monospace", fontSize: 11, color: "var(--qc-muted)" }}>
                          ID: {c.id ? `${c.id.slice(0, 8)}…` : "—"}
                        </span>
                        {c.quoteId && (
                          <span
                            onClick={() => handleOpenContract(c)}
                            style={{
                              fontSize: 11,
                              background: "rgba(196, 138, 54, 0.12)",
                              color: "#C48A36",
                              padding: "1px 7px",
                              borderRadius: 4,
                              cursor: "pointer",
                              fontWeight: 500,
                            }}
                            title="Click to view full submitted quote"
                          >
                            📄 Quote: {c.quoteId.slice(0, 8)} ({quoteItemsCount > 0 ? `${quoteItemsCount} items` : "view details"})
                          </span>
                        )}
                      </div>
                    </td>
                    <td><StatusBadge status={c.status} /></td>
                    <td className="qc-money">{formatMoney(c.totalAmount)}</td>
                    <td style={{ color: "var(--qc-muted)", fontSize: 12.5, whiteSpace: "nowrap" }}>
                      {c.signedAt ? (
                        <span style={{ color: "var(--qc-success)", fontWeight: 500 }}>
                          ✓ {new Date(c.signedAt).toLocaleDateString()}
                        </span>
                      ) : (
                        <span style={{ color: "var(--qc-warning)" }}>Pending</span>
                      )}
                    </td>
                    <td style={{ color: "var(--qc-muted)", fontSize: 12.5, whiteSpace: "nowrap" }}>
                      {c.updatedAt ? new Date(c.updatedAt).toLocaleDateString() : "—"}
                    </td>
                    <td style={{ textAlign: "right", paddingRight: 20 }}>
                      <div style={{ display: "flex", gap: 6, justifyContent: "flex-end", alignItems: "center", flexWrap: "nowrap" }}>
                        <button
                          className="qc-btn qc-btn--ghost qc-btn--sm"
                          style={{ padding: "3px 9px", fontSize: 12, fontWeight: 600 }}
                          onClick={() => handleOpenContract(c)}
                        >
                          View Details
                        </button>
                        {(c.status === "Draft" || c.status === "PendingSignature") && (
                          <button className="qc-btn qc-btn--primary qc-btn--sm" onClick={() => handleSign(c)}>Mark signed</button>
                        )}
                        {c.status !== "Completed" && c.status !== "Cancelled" && (
                          <button className="qc-btn qc-btn--danger qc-btn--sm" onClick={() => handleCancel(c)}>Cancel</button>
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
          <span>{totalCount} contract{totalCount === 1 ? "" : "s"}</span>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <button className="qc-btn qc-btn--ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</button>
            <span>Page {page} of {totalPages}</span>
            <button className="qc-btn qc-btn--ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</button>
          </div>
        </div>
      </div>

      {/* Contract & Submitted Quote Specification Modal */}
      {viewingContract && (
        <div className="qc-modal-backdrop" onMouseDown={() => setViewingContract(null)}>
          <div
            className="qc-modal qc-modal--lg"
            style={{ maxWidth: 840, maxHeight: "90vh", overflowY: "auto" }}
            onMouseDown={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 18, borderBottom: "1px solid var(--qc-border)", paddingBottom: 14 }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                  <h2 className="qc-modal__title" style={{ margin: 0, fontSize: 18 }}>
                    Contract & Quote Specification
                  </h2>
                  <StatusBadge status={viewingContract.status} />
                  {activeQuote?.isAiGenerated && <span className="qc-ai-tag">✨ AI Draft</span>}
                  {activeQuote?.status && (
                    <span style={{ fontSize: 11, background: "rgba(34, 197, 94, 0.15)", color: "#16a34a", padding: "2px 8px", borderRadius: 999, fontWeight: 600 }}>
                      Quote Accepted
                    </span>
                  )}
                </div>
                <div style={{ fontSize: 13, color: "var(--qc-muted)", marginTop: 4 }}>
                  Contract ID: <span style={{ fontFamily: "monospace" }}>{viewingContract.id}</span>
                  {viewingContract.quoteId && (
                    <> • Linked Quote ID: <span style={{ fontFamily: "monospace" }}>{viewingContract.quoteId}</span></>
                  )}
                </div>
              </div>
              <button type="button" className="qc-icon-btn" onClick={() => setViewingContract(null)}>✕</button>
            </div>

            {/* Contract Overview Cards */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
                gap: 12,
                marginBottom: 20,
              }}
            >
              <div style={{ background: "var(--qc-surface-sunken)", padding: "12px 16px", borderRadius: 8, border: "1px solid var(--qc-border)" }}>
                <div style={{ fontSize: 11, color: "var(--qc-muted)", textTransform: "uppercase", fontWeight: 600 }}>Agreed Amount</div>
                <div style={{ fontSize: 18, fontWeight: 700, color: "var(--qc-primary)", marginTop: 4 }}>
                  {formatMoney(viewingContract.totalAmount)}
                </div>
              </div>

              <div style={{ background: "var(--qc-surface-sunken)", padding: "12px 16px", borderRadius: 8, border: "1px solid var(--qc-border)" }}>
                <div style={{ fontSize: 11, color: "var(--qc-muted)", textTransform: "uppercase", fontWeight: 600 }}>Signature Status</div>
                <div style={{ fontSize: 13, fontWeight: 600, marginTop: 4 }}>
                  {viewingContract.signedAt ? (
                    <span style={{ color: "var(--qc-success)" }}>
                      ✓ Signed ({new Date(viewingContract.signedAt).toLocaleDateString()})
                    </span>
                  ) : (
                    <span style={{ color: "var(--qc-warning)" }}>Pending Signature</span>
                  )}
                </div>
              </div>

              <div style={{ background: "var(--qc-surface-sunken)", padding: "12px 16px", borderRadius: 8, border: "1px solid var(--qc-border)" }}>
                <div style={{ fontSize: 11, color: "var(--qc-muted)", textTransform: "uppercase", fontWeight: 600 }}>Project / Request</div>
                <div style={{ fontSize: 12, fontFamily: "monospace", marginTop: 4, color: "var(--qc-ink)" }}>
                  {viewingContract.projectRequestId || activeQuote?.projectRequestId || "req-default"}
                </div>
              </div>

              <div style={{ background: "var(--qc-surface-sunken)", padding: "12px 16px", borderRadius: 8, border: "1px solid var(--qc-border)" }}>
                <div style={{ fontSize: 11, color: "var(--qc-muted)", textTransform: "uppercase", fontWeight: 600 }}>Created Date</div>
                <div style={{ fontSize: 13, fontWeight: 500, marginTop: 4, color: "var(--qc-ink)" }}>
                  {viewingContract.createdAt ? new Date(viewingContract.createdAt).toLocaleDateString() : "—"}
                </div>
              </div>
            </div>

            {/* Fully Submitted Quote Details Section */}
            <div style={{ marginBottom: 24 }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 10 }}>
                <div style={{ fontSize: 14, fontWeight: 700, display: "flex", alignItems: "center", gap: 6 }}>
                  <span>📄</span>
                  <span>Fully Submitted Quote Details</span>
                </div>
                {loadingQuote && (
                  <span style={{ fontSize: 12, color: "var(--qc-muted)" }}>Loading itemized quote…</span>
                )}
              </div>

              {/* Scope Summary Box */}
              <div
                style={{
                  background: "var(--qc-surface)",
                  border: "1px solid var(--qc-border)",
                  borderRadius: 8,
                  padding: "14px 16px",
                  marginBottom: 14,
                }}
              >
                <div style={{ fontSize: 12, fontWeight: 600, color: "var(--qc-muted)", marginBottom: 4 }}>
                  Scope of Work & Design Description
                </div>
                <div style={{ fontSize: 14, fontWeight: 600, color: "var(--qc-ink)" }}>
                  {activeQuote?.scopeSummary || viewingContract.termsSummary || "Interior Design & Room Makeover"}
                </div>

                {activeQuote?.notes && (
                  <div
                    style={{
                      marginTop: 10,
                      padding: "8px 12px",
                      background: "rgba(196, 138, 54, 0.08)",
                      borderLeft: "3px solid var(--qc-primary)",
                      borderRadius: 4,
                      fontSize: 12.5,
                      color: "var(--qc-neutral)",
                    }}
                  >
                    <strong>Designer Notes & Specifications:</strong> {activeQuote.notes}
                  </div>
                )}
              </div>

              {/* Itemized Cost Breakdown Table */}
              <div style={{ border: "1px solid var(--qc-border)", borderRadius: 8, overflow: "hidden" }}>
                <table className="qc-table" style={{ margin: 0 }}>
                  <thead>
                    <tr>
                      <th style={{ width: 120 }}>Category</th>
                      <th>Description</th>
                      <th style={{ textAlign: "right", width: 80 }}>Qty</th>
                      <th style={{ textAlign: "right", width: 130 }}>Unit Price</th>
                      <th style={{ textAlign: "right", width: 140 }}>Line Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {activeQuote && activeQuote.items && activeQuote.items.length > 0 ? (
                      activeQuote.items.map((item, idx) => (
                        <tr key={item.id || idx}>
                          <td>
                            <span className={`qc-category-badge qc-cat--${item.category || "Other"}`}>
                              {item.category || "General"}
                            </span>
                          </td>
                          <td style={{ fontWeight: 500 }}>{item.description}</td>
                          <td style={{ textAlign: "right" }}>{item.quantity}</td>
                          <td style={{ textAlign: "right" }}>{formatMoney(item.unitCost)}</td>
                          <td style={{ textAlign: "right", fontWeight: 600 }}>
                            {formatMoney((item.quantity || 1) * (item.unitCost || 0))}
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td>
                          <span className="qc-category-badge qc-cat--Design">Design</span>
                        </td>
                        <td style={{ fontWeight: 500 }}>
                          {viewingContract.termsSummary || "Turnkey Interior Design & Furnishing Package"}
                        </td>
                        <td style={{ textAlign: "right" }}>1</td>
                        <td style={{ textAlign: "right" }}>{formatMoney(viewingContract.totalAmount)}</td>
                        <td style={{ textAlign: "right", fontWeight: 600 }}>{formatMoney(viewingContract.totalAmount)}</td>
                      </tr>
                    )}
                    <tr style={{ background: "var(--qc-surface-sunken)" }}>
                      <td colSpan={4} style={{ fontWeight: 700, textAlign: "right", fontSize: 13 }}>
                        Total Submitted Quote Amount:
                      </td>
                      <td style={{ fontWeight: 700, textAlign: "right", color: "var(--qc-primary)", fontSize: 15 }}>
                        {formatMoney(activeQuote?.totalCost ?? viewingContract.totalAmount)}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* Contract Legal Agreement & Terms */}
            <div style={{ marginBottom: 20 }}>
              <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 8, display: "flex", alignItems: "center", gap: 6 }}>
                <span>📜</span>
                <span>Contract Agreement & Legal Terms</span>
              </div>
              <div
                style={{
                  background: "var(--qc-surface-sunken)",
                  border: "1px solid var(--qc-border)",
                  borderRadius: 8,
                  padding: "12px 16px",
                  fontSize: 12.5,
                  lineHeight: 1.6,
                  color: "var(--qc-neutral)",
                }}
              >
                {viewingContract.terms ||
                  `Official StyleSync Binding Agreement for ${viewingContract.termsSummary || "Interior Design"}. Payments follow standard milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover. All work guaranteed under StyleSync Designer Quality Assurance.`}
              </div>
            </div>

            {/* Modal Actions */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingTop: 14, borderTop: "1px solid var(--qc-border)" }}>
              <div style={{ display: "flex", gap: 8 }}>
                {(viewingContract.status === "Draft" || viewingContract.status === "PendingSignature") && (
                  <button
                    type="button"
                    className="qc-btn qc-btn--primary"
                    onClick={() => handleSign(viewingContract)}
                  >
                    Mark as Signed
                  </button>
                )}
                {viewingContract.status !== "Completed" && viewingContract.status !== "Cancelled" && (
                  <button
                    type="button"
                    className="qc-btn qc-btn--danger"
                    onClick={() => handleCancel(viewingContract)}
                  >
                    Cancel Contract
                  </button>
                )}
              </div>
              <button
                type="button"
                className="qc-btn qc-btn--ghost"
                onClick={() => setViewingContract(null)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}