export type StatusLike = string | { value?: string; name?: string } | undefined | null;

export interface QuoteItem {
  id?: string;
  description: string;
  category: string;
  quantity: number;
  unitCost: number;
  totalCost?: number;
}

export interface Quote {
  id: string;
  projectRequestId: string;
  designerId: string;
  scopeSummary: string;
  notes?: string;
  isAiGenerated: boolean;
  status: StatusLike;
  totalCost: number;
  items: QuoteItem[];
  createdAt?: string;
  updatedAt?: string;
}

export interface Contract {
  id: string;
  quoteId?: string;
  projectRequestId?: string;
  designerId?: string;
  clientId?: string;
  status: string;
  totalAmount: number;
  terms?: string;
  termsSummary?: string;
  startDate?: string;
  endDate?: string;
  signedAt?: string;
  createdAt?: string;
  updatedAt?: string;
  quote?: Quote;
}

export interface AgentQuoteItemDraft {
  description: string;
  category: string;
  quantity: number;
  unitCost: number;
}

export interface AgentBudgetScopeResponse {
  scopeSummary?: string;
  scope_summary?: string;
  items: AgentQuoteItemDraft[];
  notes?: string;
  estimatedTotal?: number;
  estimated_total?: number;
  withinBudget?: boolean;
  within_budget?: boolean;
  source?: string;
}

export interface PagedResult<T> {
  items: T[];
  totalCount: number;
  page: number;
  pageSize: number;
}
