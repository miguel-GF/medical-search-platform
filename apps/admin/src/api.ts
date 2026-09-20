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
  /** Rows already finalized as no-match, kept for audit but not open work. */
  normalization_closed_no_match?: number;
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

export interface ExactReprocessResult {
  applied: boolean;
  replayed: boolean;
  backlog_total: number;
  eligible_total: number;
  selected: number;
  processed: number;
  skipped: number;
  remaining_eligible: number;
  request_id: string | null;
}

export interface PilotCohort {
  pilot_key: string;
  target_count: number;
  registered_count: number;
  invited_count: number;
  active_count: number;
  completed_count: number;
  test_duration_days: number;
  invitations_released_at: string | null;
  test_started_at: string | null;
  test_ends_at: string | null;
  test_day: number | null;
  can_release_invitations: boolean;
  can_start_test: boolean;
}

export interface ClickMetrics {
  period_days: number;
  generated_at: string;
  summary: { total_clicks: number; unique_visitors: number; booking_clicks: number; services_with_clicks: number; locations_with_clicks: number };
  daily: Array<{ day: string; clicks: number }>;
  by_service: Array<{ service_id: string; service_name: string; provider_brand_id: string; provider_name: string; clicks: number; unique_visitors: number }>;
  by_location: Array<{ location_id: string | null; location_name: string; provider_brand_id: string; provider_name: string; clicks: number; unique_visitors: number }>;
  by_link_type: Array<{ link_type: string; clicks: number }>;
}

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

const MAX_ADMIN_RESPONSE_BYTES = 2 * 1024 * 1024;

export interface AdminApi {
  providerChanges():Promise<Record<string,any>[]>;
  reviewProviderChange(id:string,decision:string,reason:string):Promise<unknown>;
  providerDocument(id:string, action:'access'|'review', data?:Record<string,unknown>):Promise<Record<string,any>>;
  providerApplications(path?: string, data?: Record<string, unknown>): Promise<Record<string, any>>;
  research(kind: 'feedback' | 'testers', status?: string): Promise<{ items: Record<string, any>[] }>;
  updateResearch(kind: 'feedback' | 'testers', id: string, status: string, note?: string): Promise<Record<string, any>>;
  pilotCohort(): Promise<PilotCohort>;
  pilotCohortAction(action: 'mark_invitations_released' | 'start_test'): Promise<PilotCohort>;
  clickMetrics(days?: number): Promise<ClickMetrics>;
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
  resolveNormalization(id: string, input: { selected_item_id: string; alias: string; provider_brand_id?: string; reason?: string }, requestId?: string): Promise<unknown>;
  addManualCandidate(id: string, input: { catalog_item_id: string; reason: string }, requestId?: string): Promise<{ candidate_id: string; catalog_item_id: string; created: boolean; method: string }>;
  reviewNormalization(id: string, input: { decision: 'approve_candidate' | 'no_match'; selected_candidate_id?: string; alias?: string; reason?: string }, requestId?: string): Promise<unknown>;
  updateAlertStatus(id: string, status: 'acknowledged' | 'resolved' | 'ignored', reason?: string, requestId?: string): Promise<unknown>;
  updateQualityIssueStatus(id: string, status: 'acknowledged' | 'resolved' | 'ignored', reason?: string, requestId?: string): Promise<unknown>;
  reprocessExactNormalizations(input?: { apply?: boolean; limit?: number }, requestId?: string): Promise<ExactReprocessResult>;
}

export function createMutationRequestId(): string {
  try {
    const generated = globalThis.crypto?.randomUUID?.();
    if (generated) return generated;
  } catch {
    // Fall back to a correlation id. It is not an authentication credential.
  }
  return `m-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

export function createAdminApi(baseUrl: string, accessToken: () => Promise<string | null>, fetcher: typeof fetch = fetch): AdminApi {
  const base = normalizeApiBaseUrl(baseUrl);
  function mutationHeaders(requestId?: string): Record<string, string> {
    return { 'x-request-id': requestId ?? createMutationRequestId() };
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
        // Administrative responses contain provider claims, raw evidence and
        // review decisions. Never allow a redirect or an intermediary cache
        // to turn the bearer request into a credential/data disclosure.
        redirect: 'error',
        cache: 'no-store',
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
    let payload: unknown = null;
    try {
      payload = await readBoundedJson(response, MAX_ADMIN_RESPONSE_BYTES);
    } catch {
      if (response.ok) {
        throw new AdminApiError(
          'La respuesta del servicio no es válida o es demasiado grande.',
          502,
          'invalid_response',
          'CLIENT.RESPONSE',
          'high',
          true,
          response.headers.get('x-request-id') ?? undefined,
        );
      }
    }
    if (!response.ok) {
      const error = (payload as { error?: { code?: string; message?: string; type?: string; error_tag?: string; severity?: string; retryable?: boolean; request_id?: string } } | null)?.error;
      const code = error?.code ?? 'request_failed';
      throw new AdminApiError(
        localizeError(code, response.status),
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
    providerChanges:()=>request<Record<string,any>[]>('/api/v1/admin/provider-change-requests?status=pending&limit=100'),
    reviewProviderChange:(id,decision,reason)=>request(`/api/v1/admin/provider-change-requests/${encodeURIComponent(id)}/review`,{method:'POST',body:JSON.stringify({decision,reason})}),
    providerDocument: (id, action, data={}) => request<Record<string,any>>(`/api/v1/admin/provider-documents/${encodeURIComponent(id)}/${action}`,{method:'POST',body:JSON.stringify(data)}),
    providerApplications: (path = '', data) => request<Record<string, any>>(`/api/v1/admin/provider-applications${path}`, data ? { method: 'POST', body: JSON.stringify(data) } : undefined),
    research: (kind, status = '') => request<{ items: Record<string, any>[] }>(`/api/v1/admin/research?kind=${encodeURIComponent(kind)}&status=${encodeURIComponent(status)}&limit=200`),
    updateResearch: (kind, id, status, note = '') => request<Record<string, any>>(`/api/v1/admin/research/${encodeURIComponent(kind)}/${encodeURIComponent(id)}/status`, { method: 'POST', body: JSON.stringify({ status, note }), headers: mutationHeaders() }),
    pilotCohort: () => request<PilotCohort>('/api/v1/admin/research/cohort'),
    pilotCohortAction: (action) => request<PilotCohort>('/api/v1/admin/research/cohort/action', { method: 'POST', body: JSON.stringify({ action }), headers: mutationHeaders() }),
    clickMetrics: (days = 30) => request<ClickMetrics>(`/api/v1/admin/analytics/clicks?days=${Math.min(365, Math.max(1, Math.trunc(days)))}`),
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
    // Encode every server-provided identifier as one path segment. This keeps
    // a malformed/poisoned ID from changing the route or query string while
    // the API still performs its UUID validation server-side.
    resolveNormalization: (id, input, requestId) => request(`/api/v1/admin/normalization/${encodeURIComponent(id)}/resolve`, { method: 'POST', body: JSON.stringify(input), headers: mutationHeaders(requestId) }),
    addManualCandidate: (id, input, requestId) => request(`/api/v1/admin/normalization/${encodeURIComponent(id)}/candidates`, { method: 'POST', body: JSON.stringify(input), headers: mutationHeaders(requestId) }),
    reviewNormalization: (id, input, requestId) => request(`/api/v1/admin/normalization/${encodeURIComponent(id)}/review`, { method: 'POST', body: JSON.stringify(input), headers: mutationHeaders(requestId) }),
    updateAlertStatus: (id, status, reason, requestId) => request(`/api/v1/admin/alerts/${encodeURIComponent(id)}/status`, { method: 'POST', body: JSON.stringify({ status, reason }), headers: mutationHeaders(requestId) }),
    updateQualityIssueStatus: (id, status, reason, requestId) => request(`/api/v1/admin/quality-issues/${encodeURIComponent(id)}/status`, { method: 'POST', body: JSON.stringify({ status, reason }), headers: mutationHeaders(requestId) }),
    reprocessExactNormalizations: (input = {}, requestId) => request<ExactReprocessResult>('/api/v1/admin/normalization/reprocess-exact', { method: 'POST', body: JSON.stringify({ apply: input.apply === true, limit: input.limit ?? 100 }), headers: mutationHeaders(requestId) }),
  };
}

async function readBoundedJson(response: Response, maximum: number): Promise<unknown> {
  const encoding = response.headers.get('content-encoding')?.trim().toLowerCase() ?? '';
  if (encoding !== '' && encoding !== 'identity') throw new Error('compressed admin response rejected');
  const length = response.headers.get('content-length')?.trim() ?? null;
  if (length !== null && (!/^\d{1,10}$/.test(length) || Number(length) > maximum)) {
    throw new Error('admin response exceeds limit');
  }
  const reader = response.body?.getReader();
  if (!reader) {
    if (length !== null && Number(length) !== 0) throw new Error('admin response length mismatch');
    return null;
  }
  const bytes = new Uint8Array(maximum);
  let offset = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      if (offset + chunk.value.byteLength > maximum) throw new Error('admin response exceeds limit');
      bytes.set(chunk.value, offset);
      offset += chunk.value.byteLength;
    }
  } catch (error) {
    try { await reader.cancel(); } catch { /* best-effort cleanup */ }
    throw error;
  } finally {
    reader.releaseLock();
  }
  if (length !== null && offset !== Number(length)) throw new Error('admin response length mismatch');
  const text = new TextDecoder().decode(bytes.subarray(0, offset));
  return text.trim() ? JSON.parse(text) : null;
}

function normalizeApiBaseUrl(value: string): string | null {
  const candidate = value.trim();
  // A missing production API URL must fail closed. Returning an empty string
  // would make fetch() resolve the route against the Admin origin and send the
  // bearer token to the static host instead of raising a configuration error.
  if (!candidate) return null;
  try {
    const parsed = new URL(candidate);
    const localDevelopment = import.meta.env.DEV && parsed.protocol === 'http:'
      && (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1' || parsed.hostname === '::1');
    if (parsed.protocol !== 'https:' && !localDevelopment) return null;
    // The API URL is concatenated with route paths below. Query/fragment
    // values here would be malformed routing at best and accidentally expose
    // credentials at worst, so only a clean origin (or an intentional path
    // prefix) is accepted.
    if (parsed.username || parsed.password || parsed.search || parsed.hash
      || (parsed.protocol === 'https:' && parsed.port && parsed.port !== '443')) return null;
    // A production build must be bound to the reviewed Worker origin. HTTPS
    // alone cannot prevent a typo or compromised build environment from
    // sending the Supabase bearer token to an attacker-controlled host.
    if (!import.meta.env.DEV) {
      const allowedHosts = (import.meta.env.VITE_API_ALLOWED_HOSTS ?? '')
        .split(',')
        .map((host: string) => host.trim().toLowerCase())
        .filter(Boolean);
      if (allowedHosts.length === 0 || !allowedHosts.includes(parsed.hostname.toLowerCase())) return null;
    }
    return parsed.toString().replace(/\/$/, '');
  } catch {
    return null;
  }
}

function localizeError(code: string, status: number): string {
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
    // Never render an arbitrary upstream message: a compromised or
    // misconfigured API could otherwise inject SQL errors, stack traces or
    // sensitive data into the operator UI.
    default: return status >= 500
      ? 'El servicio no pudo completar la solicitud. Inténtalo de nuevo más tarde.'
      : 'La solicitud no pudo completarse. Revisa los datos e inténtalo de nuevo.';
  }
}

export function formatDate(value: string | null): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('es-MX', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value));
}
