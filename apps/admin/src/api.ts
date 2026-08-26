export interface Dashboard {
  sources: number;
  crawl_runs: number;
  failed_or_quarantined_runs: number;
  normalization_pending: number;
  open_quality_issues: number;
  active_catalog_items: number;
  active_offers: number;
  recent_runs: CrawlRun[];
}

export interface CrawlRun {
  id: string;
  source_name: string;
  status: string;
  records_received: number;
  records_valid: number;
  records_rejected: number;
  records_published: number;
  started_at: string;
  finished_at: string | null;
}

export interface NormalizationRow {
  normalization_run_id: string;
  raw_text: string;
  normalized_input: string;
  provider_brand_id: string | null;
  provider_brand_name: string | null;
  status: string;
  engine_version: string | null;
  created_at: string;
  candidate_count: number;
  decision_type: string | null;
  decision_reason: string | null;
}

export interface RawRecord {
  raw_record_id: string;
  source_name: string;
  record_type: string;
  external_record_id: string | null;
  payload: Record<string, unknown>;
  parse_status: string;
  observed_at: string;
  crawl_run_id: string;
}

export interface CatalogItem {
  item_id: string;
  display_name: string;
  service_type: string;
  status: string;
}

export interface AdminApi {
  dashboard(): Promise<Dashboard>;
  normalizationQueue(status?: string): Promise<NormalizationRow[]>;
  rawRecords(): Promise<RawRecord[]>;
  catalogItems(query: string): Promise<CatalogItem[]>;
  resolveNormalization(id: string, input: { selected_item_id: string; alias: string; provider_brand_id?: string; reason?: string }): Promise<unknown>;
}

export function createAdminApi(baseUrl: string, token: string, fetcher: typeof fetch = fetch): AdminApi {
  const base = baseUrl.replace(/\/$/, '');
  async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetcher(`${base}${path}`, {
      ...init,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json', ...(init.headers ?? {}) },
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      const message = (payload as { error?: { message?: string } } | null)?.error?.message ?? `HTTP ${response.status}`;
      throw new Error(message);
    }
    return payload as T;
  }
  return {
    dashboard: () => request<Dashboard>('/api/v1/admin/dashboard'),
    normalizationQueue: (status = 'no_match') => request<NormalizationRow[]>(`/api/v1/admin/normalization-queue?status=${encodeURIComponent(status)}&limit=100`),
    rawRecords: () => request<RawRecord[]>('/api/v1/admin/raw-records?limit=100'),
    catalogItems: (query) => request<CatalogItem[]>(`/api/v1/admin/catalog-items?q=${encodeURIComponent(query)}&limit=25`),
    resolveNormalization: (id, input) => request(`/api/v1/admin/normalization/${id}/resolve`, { method: 'POST', body: JSON.stringify(input) }),
  };
}

export function formatDate(value: string | null): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('es-MX', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value));
}
