export interface Dashboard {
  sources: number;
  crawl_runs: number;
  failed_or_quarantined_runs: number;
  normalization_pending: number;
  open_quality_issues: number;
  active_catalog_items: number;
  active_offers: number;
  normalization_ambiguous: number;
  normalization_no_match: number;
  open_alerts: number;
  critical_alerts: number;
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
  input_type: 'crawler' | 'search' | 'ocr' | 'manual' | 'import';
  raw_record_id: string | null;
  raw_text: string | null;
  normalized_input: string | null;
  provider_brand_id: string | null;
  provider_brand_name: string | null;
  status: string;
  engine_version: string | null;
  created_at: string;
  candidate_count: number;
  decision_type: string | null;
  decision_reason: string | null;
  source_name: string | null;
}

export interface NormalizationCandidate {
  candidate_id: string;
  catalog_item_id: string;
  display_name: string;
  rank: number;
  score: number;
  method: string;
  explanation: Record<string, unknown>;
}

export interface NormalizationDetail {
  run: {
    normalization_run_id: string;
    input_type: string;
    raw_record_id: string | null;
    raw_text: string | null;
    normalized_input: string | null;
    provider_brand_id: string | null;
    provider_brand_name: string | null;
    status: string;
    engine_version: string | null;
    created_at: string;
    resolved_at: string | null;
  };
  raw_record: {
    raw_record_id: string;
    source_name: string | null;
    record_type: string;
    external_record_id: string | null;
    parse_status: string;
    observed_at: string;
    crawl_run_id: string;
    source_url: string | null;
    payload_bytes: number;
    payload: Record<string, unknown> | null;
  } | null;
  candidates: NormalizationCandidate[];
  decision: {
    decision_id: string;
    selected_item_id: string | null;
    decision_type: string;
    reviewer_user_id: string | null;
    reason: string | null;
    decided_at: string;
    metadata: Record<string, unknown>;
  } | null;
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
  normalizationQueue(status?: string, inputType?: string, cursor?: { before_created_at: string; before_id: string }): Promise<NormalizationRow[]>;
  normalizationDetail(id: string, includePayload?: boolean): Promise<NormalizationDetail | null>;
  rawRecords(): Promise<RawRecord[]>;
  catalogItems(query: string): Promise<CatalogItem[]>;
  providers(): Promise<ProviderRow[]>;
  locations(): Promise<LocationRow[]>;
  offers(): Promise<OfferRow[]>;
  prices(): Promise<PriceRow[]>;
  qualityIssues(): Promise<QualityIssueRow[]>;
  alerts(): Promise<AlertRow[]>;
  resolveNormalization(id: string, input: { selected_item_id: string; alias: string; provider_brand_id?: string; reason?: string }): Promise<unknown>;
  addManualCandidate(id: string, input: { catalog_item_id: string; reason: string }): Promise<{ candidate_id: string; catalog_item_id: string; created: boolean; method: string }>;
  reviewNormalization(id: string, input: { decision: 'approve_candidate' | 'no_match'; selected_candidate_id?: string; alias?: string; reason?: string }): Promise<unknown>;
  updateAlertStatus(id: string, status: 'acknowledged' | 'resolved' | 'ignored', reason?: string): Promise<unknown>;
  updateQualityIssueStatus(id: string, status: 'acknowledged' | 'resolved' | 'ignored', reason?: string): Promise<unknown>;
}

export function createAdminApi(baseUrl: string, accessToken: () => Promise<string | null>, fetcher: typeof fetch = fetch): AdminApi {
  const base = normalizeApiBaseUrl(baseUrl);
  function mutationRequestId(): string | undefined {
    try { return globalThis.crypto?.randomUUID?.(); }
    catch { return undefined; }
  }
  async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
    if (base === null) throw new AdminApiError(
      'La URL de la API no es segura o no es válida.',
      0,
      'client_configuration_error',
      'CLIENT.CONFIGURATION',
      'high',
      false,
    );
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
    normalizationQueue: (status, inputType = '', cursor) => {
      const params = new URLSearchParams({ limit: '100' });
      if (status) params.set('status', status);
      if (inputType) params.set('input_type', inputType);
      if (cursor) {
        params.set('before_created_at', cursor.before_created_at);
        params.set('before_id', cursor.before_id);
      }
      return request<NormalizationRow[]>(`/api/v1/admin/normalization-queue?${params.toString()}`);
    },
    normalizationDetail: (id, includePayload = false) => request<NormalizationDetail | null>(`/api/v1/admin/normalization/${encodeURIComponent(id)}${includePayload ? '?include_payload=true' : ''}`),
    rawRecords: () => request<RawRecord[]>('/api/v1/admin/raw-records?limit=25'),
    catalogItems: (query) => request<CatalogItem[]>(`/api/v1/admin/catalog-items?q=${encodeURIComponent(query)}&limit=25`),
    providers: () => request<ProviderRow[]>('/api/v1/admin/providers?limit=200'),
    locations: () => request<LocationRow[]>('/api/v1/admin/locations?limit=200'),
    offers: () => request<OfferRow[]>('/api/v1/admin/offers?limit=200'),
    prices: () => request<PriceRow[]>('/api/v1/admin/prices?limit=200'),
    qualityIssues: () => request<QualityIssueRow[]>('/api/v1/admin/quality-issues?limit=200'),
    alerts: () => request<AlertRow[]>('/api/v1/admin/alerts?limit=200'),
    resolveNormalization: (id, input) => request(`/api/v1/admin/normalization/${id}/resolve`, { method: 'POST', body: JSON.stringify(input), headers: { 'x-request-id': mutationRequestId() ?? '' } }),
    addManualCandidate: (id, input) => request(`/api/v1/admin/normalization/${id}/candidates`, { method: 'POST', body: JSON.stringify(input), headers: { 'x-request-id': mutationRequestId() ?? '' } }),
    reviewNormalization: (id, input) => request(`/api/v1/admin/normalization/${id}/review`, { method: 'POST', body: JSON.stringify(input), headers: { 'x-request-id': mutationRequestId() ?? '' } }),
    updateAlertStatus: (id, status, reason) => request(`/api/v1/admin/alerts/${id}/status`, { method: 'POST', body: JSON.stringify({ status, reason }), headers: { 'x-request-id': mutationRequestId() ?? '' } }),
    updateQualityIssueStatus: (id, status, reason) => request(`/api/v1/admin/quality-issues/${id}/status`, { method: 'POST', body: JSON.stringify({ status, reason }), headers: { 'x-request-id': mutationRequestId() ?? '' } }),
  };
}

function normalizeApiBaseUrl(value: string): string | null {
  const candidate = value.trim();
  if (!candidate) return '';
  try {
    const parsed = new URL(candidate);
    const localDevelopment = parsed.protocol === 'http:'
      && (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1' || parsed.hostname === '::1');
    if (parsed.protocol !== 'https:' && !localDevelopment) return null;
    return parsed.toString().replace(/\/$/, '');
  } catch {
    return null;
  }
}

function localizeError(code: string, fallback: string): string {
  switch (code) {
    case 'mfa_required': return 'Confirma el segundo factor de tu autenticador para entrar al panel.';
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
