import type { StatusLike } from "../types";

interface StatusStyle {
  color: string;
  bg: string;
  border: string;
}

const STATUS_STYLES: Record<string, StatusStyle> = {
  Draft: { color: "var(--qc-neutral)", bg: "var(--qc-neutral-bg)", border: "var(--qc-neutral-border)" },
  Submitted: { color: "var(--qc-primary)", bg: "var(--qc-primary-light)", border: "var(--qc-primary-border)" },
  Stage1Pending: { color: "var(--qc-primary)", bg: "var(--qc-primary-light)", border: "var(--qc-primary-border)" },
  ClientReview: { color: "var(--qc-primary)", bg: "var(--qc-primary-light)", border: "var(--qc-primary-border)" },
  Stage1Released: { color: "var(--qc-primary)", bg: "var(--qc-primary-light)", border: "var(--qc-primary-border)" },
  RevisionRequested: { color: "var(--qc-warning)", bg: "var(--qc-warning-bg)", border: "var(--qc-warning-border)" },
  Stage2ChangesRequested: { color: "var(--qc-warning)", bg: "var(--qc-warning-bg)", border: "var(--qc-warning-border)" },
  Accepted: { color: "var(--qc-success)", bg: "var(--qc-success-bg)", border: "var(--qc-success-border)" },
  Stage2Approved: { color: "var(--qc-success)", bg: "var(--qc-success-bg)", border: "var(--qc-success-border)" },
  Rejected: { color: "var(--qc-danger)", bg: "var(--qc-danger-bg)", border: "var(--qc-danger-border)" },
  Stage1Rejected: { color: "var(--qc-danger)", bg: "var(--qc-danger-bg)", border: "var(--qc-danger-border)" },
  Stage2Rejected: { color: "var(--qc-danger)", bg: "var(--qc-danger-bg)", border: "var(--qc-danger-border)" },
  PendingSignature: { color: "var(--qc-warning)", bg: "var(--qc-warning-bg)", border: "var(--qc-warning-border)" },
  Active: { color: "var(--qc-success)", bg: "var(--qc-success-bg)", border: "var(--qc-success-border)" },
  Completed: { color: "var(--qc-primary)", bg: "var(--qc-primary-light)", border: "var(--qc-primary-border)" },
  Cancelled: { color: "var(--qc-danger)", bg: "var(--qc-danger-bg)", border: "var(--qc-danger-border)" },
};

function toLabel(status: StatusLike | undefined): string {
  if (!status) {
    return "Unknown";
  }

  const value = typeof status === "object" ? status.value ?? status.name ?? "Unknown" : status;
  if (value === "Stage1Pending") return "Submitted";
  if (value === "Stage1Released") return "Client Review";
  if (value === "Stage2Approved") return "Accepted";
  if (value === "Stage2ChangesRequested") return "Revision Requested";
  if (value === "Stage1Rejected" || value === "Stage2Rejected") return "Rejected";

  return String(value).replace(/([a-z])([A-Z])/g, "$1 $2");
}

interface StatusBadgeProps {
  status: StatusLike;
}

export default function StatusBadge({ status }: StatusBadgeProps) {
  const cleanStatus = status && typeof status === "object" ? status.value ?? status.name : status;

  const style: StatusStyle =
  (cleanStatus ? STATUS_STYLES[cleanStatus] : undefined) ?? {
    color: "var(--qc-neutral)",
    bg: "var(--qc-neutral-bg)",
    border: "var(--qc-neutral-border)",
  };

  return (
    <span
      className="qc-badge"
      style={{
        color: style.color,
        background: style.bg,
        borderColor: style.border,
      }}
    >
      {toLabel(cleanStatus)}
    </span>
  );
}