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

export interface ProviderRow { provider_id: string; provider_name: string; status: string; verification_status: string; locations_count: number; active_offers_count: number; }
export interface LocationRow { location_id: string; provider_name: string; location_name: string; address: string | null; locality: string | null; status: string; latitude: number | null; longitude: number | null; }
export interface OfferRow { offer_id: string; provider_name: string; service_name: string; catalog_item_id: string; status: string; current_price_count: number; last_seen_at: string | null; }
export interface PriceRow { price_version_id: string; provider_name: string; service_name: string; amount_minor: number; currency: string; price_type: string; last_seen_at: string; source_url: string | null; }
export interface QualityIssueRow { issue_id: string; issue_code: string; severity: string; status: string; source_id: string | null; crawl_run_id: string | null; details: Record<string, unknown>; created_at: string; }
export interface AlertRow { alert_id: string; alert_code: string; severity: string; status: string; source: string | null; title: string; detail: string | null; created_at: string; }

export class AdminApiError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly code: string,
    readonly errorTag: string,
    readonly severity: string,
    readonly retryable: boolean,
    readonly requestId?: string,
  ) {
    super(message);
    this.name = 'AdminApiError';
  }
}

export interface AdminApi {
  dashboard(): Promise<Dashboard>;
  normalizationQueue(status?: string): Promise<NormalizationRow[]>;
  rawRecords(): Promise<RawRecord[]>;
  catalogItems(query: string): Promise<CatalogItem[]>;
  providers(): Promise<ProviderRow[]>;
  locations(): Promise<LocationRow[]>;
  offers(): Promise<OfferRow[]>;
  prices(): Promise<PriceRow[]>;
  qualityIssues(): Promise<QualityIssueRow[]>;
  alerts(): Promise<AlertRow[]>;
  resolveNormalization(id: string, input: { selected_item_id: string; alias: string; provider_brand_id?: string; reason?: string }): Promise<unknown>;
}

export function createAdminApi(baseUrl: string, accessToken: () => Promise<string | null>, fetcher: typeof fetch = fetch): AdminApi {
  const base = baseUrl.replace(/\/$/, '');
  async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const token = await accessToken();
    if (!token) throw new AdminApiError(
      'Tu sesión administrativa es necesaria para continuar.',
      401,
      'unauthorized',
      'CLIENT.AUTH',
      'medium',
      false,
    );
    let response: Response;
    try {
      response = await fetcher(`${base}${path}`, {
        ...init,
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json', ...(init.headers ?? {}) },
      });
    } catch {
      throw new AdminApiError(
        'No pudimos conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
        503,
        'client_connection_error',
        'CLIENT.CONNECTION',
        'medium',
        true,
      );
    }
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      const error = (payload as { error?: { code?: string; message?: string; type?: string; error_tag?: string; severity?: string; retryable?: boolean; request_id?: string } } | null)?.error;
      const code = error?.code ?? 'request_failed';
      throw new AdminApiError(
        localizeError(code, error?.message ?? `HTTP ${response.status}`),
        response.status,
        code,
        error?.error_tag ?? 'API.REQUEST',
        error?.severity ?? 'medium',
        error?.retryable === true,
        error?.request_id ?? response.headers.get('x-request-id') ?? undefined,
      );
    }
    return payload as T;
  }
  return {
    dashboard: () => request<Dashboard>('/api/v1/admin/dashboard'),
    normalizationQueue: (status = 'no_match') => request<NormalizationRow[]>(`/api/v1/admin/normalization-queue?status=${encodeURIComponent(status)}&limit=100`),
    rawRecords: () => request<RawRecord[]>('/api/v1/admin/raw-records?limit=100'),
    catalogItems: (query) => request<CatalogItem[]>(`/api/v1/admin/catalog-items?q=${encodeURIComponent(query)}&limit=25`),
    providers: () => request<ProviderRow[]>('/api/v1/admin/providers?limit=200'),
    locations: () => request<LocationRow[]>('/api/v1/admin/locations?limit=200'),
    offers: () => request<OfferRow[]>('/api/v1/admin/offers?limit=200'),
    prices: () => request<PriceRow[]>('/api/v1/admin/prices?limit=200'),
    qualityIssues: () => request<QualityIssueRow[]>('/api/v1/admin/quality-issues?limit=200'),
    alerts: () => request<AlertRow[]>('/api/v1/admin/alerts?limit=200'),
    resolveNormalization: (id, input) => request(`/api/v1/admin/normalization/${id}/resolve`, { method: 'POST', body: JSON.stringify(input) }),
  };
}

function localizeError(code: string, fallback: string): string {
  switch (code) {
    case 'service_not_configured': return 'El servicio de datos no está configurado. Revisa la configuración del entorno.';
    case 'upstream_timeout': return 'La fuente de datos tardó demasiado. Inténtalo de nuevo.';
    case 'upstream_connection_error':
    case 'client_connection_error': return 'No pudimos conectar con la fuente de datos. Revisa tu conexión.';
    case 'unauthorized': return 'Tu sesión administrativa no es válida o ya expiró.';
    case 'forbidden': return 'Tu cuenta no tiene permisos para esta acción.';
    case 'invalid_body': return 'La solicitud administrativa no tiene un formato válido.';
    case 'not_found': return 'No encontramos el recurso solicitado.';
    default: return fallback;
  }
}

export function formatDate(value: string | null): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('es-MX', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value));
}
