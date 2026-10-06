import type { Contract, PagedResult } from "../types";
import { getLocalQuotes } from "./quotesApi";

const RAW_API_BASE = import.meta.env?.VITE_API_BASE_URL ?? "http://localhost:5000";
const API_BASE = RAW_API_BASE.replace(/\/api\/?$/, "");

const CONTRACT_STORAGE_KEY = "stylesync_contracts_store";

function getLocalContracts(): Contract[] {
  const quotes = getLocalQuotes();
  let list: Contract[] = [];
  const data = localStorage.getItem(CONTRACT_STORAGE_KEY);
  if (data) {
    try {
      list = JSON.parse(data);
    } catch { /* ignore */ }
  } else {
    list = [
      {
        id: "cnt-501",
        quoteId: "q-100",
        projectRequestId: "req-000",
        designerId: "des-001",
        clientId: "client-123",
        status: "PendingSignature",
        totalAmount: 520000.00,
        termsSummary: "Executive Penthouse Interior Fitout & Custom Joinery",
        terms: "Standard StyleSync Interior Design & Installation Contract. 50% deposit, 50% upon final signoff.",
        createdAt: new Date(Date.now() - 86400000 * 3).toISOString(),
        updatedAt: new Date(Date.now() - 86400000).toISOString()
      },
      {
        id: "cnt-502",
        quoteId: "q-099",
        projectRequestId: "req-099",
        designerId: "des-003",
        clientId: "client-456",
        status: "Active",
        signedAt: new Date(Date.now() - 86400000 * 5).toISOString(),
        totalAmount: 380000.00,
        termsSummary: "Kitchen Makeover & Quartz Countertops Installation",
        terms: "Kitchen Makeover Contract with guaranteed delivery timeline.",
        createdAt: new Date(Date.now() - 86400000 * 7).toISOString(),
        updatedAt: new Date(Date.now() - 86400000 * 5).toISOString()
      }
    ];
  }

  // Auto-link submitted quotes so designer contracts dashboard always displays client-submitted quotes
  for (const q of quotes) {
    const s = typeof q.status === "string" ? q.status : (q.status as any)?.value ?? "";
    if (s === "Submitted" || s === "ClientReview" || s === "Stage1Pending" || s === "Stage1Released") {
      if (!list.some((c) => c.quoteId === q.id)) {
        list.unshift({
          id: `cnt-${q.id.replace(/[^a-zA-Z0-9]/g, "").slice(-4) || Date.now().toString().slice(-4)}`,
          quoteId: q.id,
          projectRequestId: q.projectRequestId,
          designerId: q.designerId,
          clientId: "client-default",
          status: "PendingSignature",
          totalAmount: q.totalCost,
          termsSummary: q.scopeSummary || "Client Submitted Interior Quote",
          terms: `Official StyleSync Binding Agreement for ${q.scopeSummary || "Interior Design"}. Milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover.`,
          createdAt: q.createdAt || new Date().toISOString(),
          updatedAt: q.updatedAt || new Date().toISOString(),
          quote: q,
        });
      }
    }
  }

  return list.map((c) => ({
    ...c,
    quote: c.quote || quotes.find((q) => q.id === c.quoteId),
  }));
}

function saveLocalContracts(contracts: Contract[]) {
  localStorage.setItem(CONTRACT_STORAGE_KEY, JSON.stringify(contracts));
}

export function addMockContract(contract: Contract) {
  const contracts = getLocalContracts();
  contracts.unshift(contract);
  saveLocalContracts(contracts);
}

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.message || `Request failed with ${res.status}`);
  }
  return res.status === 204 ? (null as T) : res.json();
}

interface ListContractsParams {
  status?: string;
  designerId?: string;
  clientId?: string;
  page?: number;
  pageSize?: number;
  sort?: string;
}

export async function listContracts({
  status,
  page = 1,
  pageSize = 20,
}: ListContractsParams = {}): Promise<PagedResult<Contract>> {
  try {
    const params = new URLSearchParams();
    if (status) params.set("status", status);
    params.set("page", String(page));
    params.set("pageSize", String(pageSize));

    const res = await fetch(`${API_BASE}/api/contracts?${params.toString()}`);
    const data = await handle<PagedResult<Contract>>(res);
    const quotes = getLocalQuotes();
    let items: Contract[] = (data.items || []).map((c) => ({
      ...c,
      quote: c.quote || quotes.find((q) => q.id === c.quoteId),
    }));

    // Ensure submitted client quotes also show up in designer's contracts studio
    const localContracts = getLocalContracts();
    for (const lc of localContracts) {
      if (!items.some((i) => i.id === lc.id || (lc.quoteId && i.quoteId === lc.quoteId))) {
        items.unshift(lc);
      }
    }

    return { ...data, items, totalCount: Math.max(data.totalCount || 0, items.length) };
  } catch {
    let contracts = getLocalContracts();
    if (status) {
      contracts = contracts.filter((c) => c.status.toLowerCase() === status.toLowerCase());
    }

    const start = (page - 1) * pageSize;
    const paginated = contracts.slice(start, start + pageSize);

    return {
      items: paginated,
      totalCount: contracts.length,
      page,
      pageSize,
    };
  }
}

export async function getContract(id: string): Promise<Contract> {
  try {
    const res = await fetch(`${API_BASE}/api/contracts/${id}`);
    const contract = await handle<Contract>(res);
    if (!contract.quote && contract.quoteId) {
      const quotes = getLocalQuotes();
      contract.quote = quotes.find((q) => q.id === contract.quoteId);
    }
    return contract;
  } catch {
    const contracts = getLocalContracts();
    const found = contracts.find((c) => c.id === id);
    if (!found) throw new Error("Contract not found");
    return found;
  }
}

export async function updateContract(id: string, payload: Partial<Contract>): Promise<Contract> {
  try {
    const res = await fetch(`${API_BASE}/api/contracts/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return await handle<Contract>(res);
  } catch {
    const contracts = getLocalContracts();
    const index = contracts.findIndex((c) => c.id === id);
    if (index === -1) throw new Error("Contract not found");

    const updated = { ...contracts[index], ...payload, updatedAt: new Date().toISOString() };
    contracts[index] = updated;
    saveLocalContracts(contracts);
    return updated;
  }
}

export async function signContract(id: string, signedAt: string): Promise<Contract> {
  try {
    const res = await fetch(`${API_BASE}/api/contracts/${id}/sign`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ signedAt }),
    });
    return await handle<Contract>(res);
  } catch {
    const contracts = getLocalContracts();
    const index = contracts.findIndex((c) => c.id === id);
    if (index === -1) throw new Error("Contract not found");

    const updated = { ...contracts[index], status: "Active", signedAt, updatedAt: new Date().toISOString() };
    contracts[index] = updated;
    saveLocalContracts(contracts);
    return updated;
  }
}

export async function cancelContract(id: string): Promise<Contract | null> {
  try {
    const res = await fetch(`${API_BASE}/api/contracts/${id}/cancel`, { method: "POST" });
    return await handle<Contract | null>(res);
  } catch {
    const contracts = getLocalContracts();
    const index = contracts.findIndex((c) => c.id === id);
    if (index === -1) throw new Error("Contract not found");

    const updated = { ...contracts[index], status: "Cancelled", updatedAt: new Date().toISOString() };
    contracts[index] = updated;
    saveLocalContracts(contracts);
    return updated;
  }
}