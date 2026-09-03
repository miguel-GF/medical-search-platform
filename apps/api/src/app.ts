import { SupabaseConfigurationError, SupabaseResponseError, SupabaseRpcError, SupabaseRpcClient, SupabaseTimeoutError } from './supabase.js';
import type { AdminAlert, AdminCatalogItem, AdminNormalizationDetail, AdminNormalizationQueueRow, AdminQualityIssue, AdminUser, Env, PackageResolutionResponse, RateLimitBinding, ResolutionCandidate, ResolutionResponse, RpcClient, SearchRow } from './types.js';
import {
  buildPackageResolution,
  normalizeBatchRpcPayload,
  parseBatchRequest,
  readCatalogSegments,
  type ParsedBatchRequest,
} from './batch.js';
import {
  OcrInputError,
  OcrRecognitionError,
  OcrUnavailableError,
  parseOcrImageInput,
  recognizeOrderImage,
  recognizeOrderImageViaService,
} from './ocr.js';

interface Dependencies {
  rpc: RpcClient;
  authenticateAdmin?: (request: Request, env: Env) => Promise<AdminUser | null>;
  authenticateUser?: (request: Request, env: Env) => Promise<AuthenticatedUser | null>;
}

// Search terms, OCR text and provider responses must not be retained by an
// intermediary/browser cache as a side channel for health-related queries.
const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
};
const ANALYTICS_EVENTS = new Set([
  'consent_granted',
  'search_completed',
  'package_resolved',
  'package_resolved_from_image',
  'provider_contact_clicked',
  'pwa_installed',
]);
const ANALYTICS_METADATA_KEYS = new Set(['result_count', 'item_count', 'status', 'review_required', 'surface']);
const ANALYTICS_STATUSES = new Set(['ready', 'partial', 'needs_clarification', 'no_match']);
const ANALYTICS_SURFACES = new Set(['web', 'pwa', 'android', 'ios']);

export function createHandler(dependencies: Dependencies) {
  return async function handle(request: Request, env: Env): Promise<Response> {
    const origin = configuredCorsOrigin(env.ALLOWED_ORIGIN);
    const requestId = requestIdFor(request);
    if (env.APP_ENV === 'production' && !isSecureConfiguredOrigin(env.ALLOWED_ORIGIN)) {
      console.error(JSON.stringify({ event: 'api_configuration_error', request_id: requestId, reason: 'https_origin_required' }));
      return errorJson('service_not_configured', 'The API is not securely configured.', 503, origin, requestId, 'API.SERVER.CONFIGURATION', 'high', false);
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    try {
      const url = new URL(request.url);
      if (url.pathname === '/health' && request.method === 'GET') {
        return json({ status: 'ok', service: 'pruevia-api', version: env.API_VERSION ?? 'v1' }, 200, origin);
      }
      const rateLimitResponse = await enforceRateLimit(request, url, env, origin, requestId);
      if (rateLimitResponse) return rateLimitResponse;
      if (url.pathname === '/api/v1/search' && request.method === 'GET') {
        return await searchResponse(url, dependencies.rpc, origin, requestId);
      }
      if (url.pathname === '/api/v1/resolve' && request.method === 'POST') {
        return await resolveResponse(request, dependencies.rpc, origin, requestId);
      }
      if (url.pathname === '/api/v1/resolve-batch' && request.method === 'POST') {
        return await resolveBatchResponse(request, dependencies.rpc, origin);
      }
      if (url.pathname === '/api/v1/resolve-image' && request.method === 'POST') {
        return await resolveImageResponse(request, dependencies.rpc, env, origin, requestId);
      }
      if (url.pathname === '/api/v1/events' && request.method === 'POST') {
        return await analyticsEventResponse(request, dependencies.rpc, origin);
      }
      if (url.pathname === '/api/v1/services' && request.method === 'GET') {
        return json({ error: { code: 'route_requires_id', message: 'Use /api/v1/services/{id}' } }, 400, origin);
      }
      const serviceMatch = url.pathname.match(/^\/api\/v1\/services\/([^/]+)(?:\/(providers))?$/i);
      if (serviceMatch && request.method === 'GET') {
        if (!isUuid(serviceMatch[1])) return json({ error: { code: 'invalid_id', message: 'service id must be a UUID' } }, 400, origin);
        const payload = await dependencies.rpc.call('api_service_detail', { p_service_id: serviceMatch[1] });
        if (!payload) return json(null, 404, origin);
        const publicPayload = sanitizePublicPayload(payload);
        return json(serviceMatch[2] ? { service_id: serviceMatch[1], providers: (publicPayload as { offers?: unknown[] }).offers ?? [] } : publicPayload, 200, origin);
      }
      const providerMatch = url.pathname.match(/^\/api\/v1\/providers\/([^/]+)(?:\/(services))?$/i);
      if (providerMatch && request.method === 'GET') {
        if (!isUuid(providerMatch[1])) return json({ error: { code: 'invalid_id', message: 'provider id must be a UUID' } }, 400, origin);
        const payload = await dependencies.rpc.call('api_provider_detail', { p_provider_brand_id: providerMatch[1] });
        if (!payload) return json(null, 404, origin);
        const publicPayload = sanitizePublicPayload(payload);
        return json(providerMatch[2] ? { provider_id: providerMatch[1], services: (publicPayload as { services?: unknown[] }).services ?? [] } : publicPayload, 200, origin);
      }
      if (url.pathname.startsWith('/api/v1/admin/')) {
        return await adminResponse(request, url, env, dependencies.rpc, origin, requestId, dependencies.authenticateAdmin ?? verifyAdmin);
      }
      if (url.pathname.startsWith('/api/v1/provider/')) {
        return await providerResponse(request, url, env, dependencies.rpc, origin, dependencies.authenticateUser ?? verifyUser);
      }
      return json({ error: { code: 'not_found', message: 'Route not found' } }, 404, origin);
    } catch (error) {
      const failure = classifyFailure(error, new URL(request.url).pathname);
      // Do not log query text, request bodies, tokens or upstream response
      // bodies.  The stable tag/request id is enough to correlate the event
      // with an operator trace without retaining clinical data.
      console.error(JSON.stringify({
        event: 'api_error',
        request_id: requestId,
        method: request.method,
        path: new URL(request.url).pathname,
        operation: failure.operation,
        error_tag: failure.errorTag,
        code: failure.code,
        severity: failure.severity,
        retryable: failure.retryable,
        status: failure.status,
        detail: safeErrorDetail(error),
      }));
      return json({
        error: {
          code: failure.code,
          type: failure.type,
          error_tag: failure.errorTag,
          severity: failure.severity,
          retryable: failure.retryable,
          operation: failure.operation,
          message: failure.message,
          request_id: requestId,
        },
      }, failure.status, origin, requestId);
    }
  };
}

export function createWorkerHandler(env: Env) {
  return createHandler({ rpc: new SupabaseRpcClient(env) });
}

async function searchResponse(url: URL, rpc: RpcClient, origin: string, requestId: string): Promise<Response> {
  const query = (url.searchParams.get('q') ?? '').trim();
  if (!query || query.length > 200 || !/[\p{L}\p{N}]/u.test(query)) {
    return json({ error: { code: 'invalid_query', message: 'q is required and must be at most 200 characters' } }, 400, origin);
  }
  const limit = parseBoundedInt(url.searchParams.get('limit'), 20, 1, 100);
  const latitude = parseCoordinate(url.searchParams.get('lat'), -90, 90);
  const longitude = parseCoordinate(url.searchParams.get('lng'), -180, 180);
  if ((latitude === null) !== (longitude === null) || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return json({ error: { code: 'invalid_coordinates', message: 'lat and lng must be provided together' } }, 400, origin);
  }
  const domain = url.searchParams.get('domain') ?? 'health_diagnostics';
  if (!/^[a-z][a-z0-9_]{1,63}$/.test(domain)) {
    return json({ error: { code: 'invalid_domain', message: 'domain is invalid' } }, 400, origin);
  }
  const locationId = url.searchParams.get('location_id');
  if (locationId && !isUuid(locationId)) {
    return json({ error: { code: 'invalid_location_id', message: 'location_id must be a UUID' } }, 400, origin);
  }
  const rows = await rpc.call<SearchRow[]>('api_search', {
    p_query: query,
    p_domain_code: domain,
    p_latitude: latitude,
    p_longitude: longitude,
    p_location_id: locationId,
    p_limit: limit,
  });
  const grouped = groupSearchRows(rows ?? []);
  const resolution = await rpc.call<ResolutionResponse>('api_resolve_search', {
    p_query: query,
    p_domain_code: domain,
    p_latitude: latitude,
    p_longitude: longitude,
    p_location_id: locationId,
    p_limit: limit,
  });
  await captureResolutionReview(resolution, rpc, domain, requestId);
  const publicResolution = isResolutionResponse(resolution) ? sanitizePublicResolution(resolution) : null;
  if (publicResolution && publicResolution.status !== 'resolved') {
    return json({ query, results: groupResolutionCandidates(publicResolution.candidates ?? []) }, 200, origin);
  }
  if (grouped.length > 0) return json({ query, results: grouped }, 200, origin);

  // Keep the public search useful when the clinical catalog recognizes a
  // service but no provider has a current offer. The search UI can then say
  // "recognized, no active offer" instead of looking like a typo/no-match.
  return json({ query, results: groupResolutionCandidates(publicResolution?.candidates ?? []) }, 200, origin);
}

async function resolveResponse(request: Request, rpc: RpcClient, origin: string, requestId: string): Promise<Response> {
  const input = await readJsonObject(request, 16_384, origin);
  if (input instanceof Response) return input;
  const query = typeof input.text === 'string' ? input.text.trim() : '';
  if (!query || query.length > 200 || !/[\p{L}\p{N}]/u.test(query)) {
    return json({ error: { code: 'invalid_query', message: 'text is required and must be at most 200 characters' } }, 400, origin);
  }
  const domain = typeof input.domain === 'string' && input.domain !== '' ? input.domain : 'health_diagnostics';
  if (!/^[a-z][a-z0-9_]{1,63}$/.test(domain)) {
    return json({ error: { code: 'invalid_domain', message: 'domain is invalid' } }, 400, origin);
  }
  const limit = typeof input.limit === 'number' && Number.isInteger(input.limit)
    ? Math.max(1, Math.min(input.limit, 50))
    : 20;
  const latitude = parseInputCoordinate(input.latitude, -90, 90);
  const longitude = parseInputCoordinate(input.longitude, -180, 180);
  if ((latitude === null) !== (longitude === null) || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return json({ error: { code: 'invalid_coordinates', message: 'latitude and longitude must be provided together' } }, 400, origin);
  }
  const locationId = input.location_id === undefined || input.location_id === null ? null : input.location_id;
  if (locationId !== null && (typeof locationId !== 'string' || !isUuid(locationId))) {
    return json({ error: { code: 'invalid_location_id', message: 'location_id must be a UUID' } }, 400, origin);
  }
  const payload = await rpc.call<ResolutionResponse>('api_resolve_search', {
    p_query: query,
    p_domain_code: domain,
    p_latitude: latitude,
    p_longitude: longitude,
    p_location_id: locationId,
    p_limit: limit,
  });
  await captureResolutionReview(payload, rpc, domain, requestId);
  return json(sanitizePublicResolution(payload), 200, origin);
}

/**
 * Review capture is deliberately best effort for the public request. A queue
 * outage must not turn a valid patient-facing resolution into a 5xx, while
 * the capture RPC itself remains service-role-only and deduplicated in SQL.
 */
async function captureResolutionReview(payload: ResolutionResponse, rpc: RpcClient, domain: string, requestId: string): Promise<void> {
  if (payload?.status !== 'ambiguous' && payload?.status !== 'no_match') return;
  try {
    await rpc.call('api_record_resolution_review', {
      p_payload: payload,
      p_input_type: 'search',
      p_scope_key: domain,
    }, { admin: true });
    } catch (error) {
      console.error(JSON.stringify({
        event: 'resolution_review_capture_failed',
        request_id: requestId,
        error_tag: error instanceof SupabaseRpcError ? error.tag : 'REVIEW_CAPTURE',
      retryable: error instanceof SupabaseRpcError ? error.retryable : true,
    }));
  }
}

function isResolutionResponse(value: unknown): value is ResolutionResponse {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const candidate = value as { status?: unknown; candidates?: unknown };
  return (candidate.status === 'resolved' || candidate.status === 'ambiguous' || candidate.status === 'no_match')
    && Array.isArray(candidate.candidates);
}

function sanitizePublicResolution(payload: ResolutionResponse): ResolutionResponse {
  const status = payload?.status === 'resolved' || payload?.status === 'ambiguous' || payload?.status === 'no_match'
    ? payload.status
    : 'no_match';
  const candidates = isResolutionResponse(payload)
    ? payload.candidates
      .filter((candidate) => isUuid(candidate.service_id))
      .slice(0, 20)
      .map((candidate) => ({
        service_id: candidate.service_id,
        display_name: safePublicText(candidate.display_name, 500),
        matched_term: safePublicText(candidate.matched_term, 500),
        term_source: safePublicText(candidate.term_source, 100),
        provider_brand_id: stringValue(candidate.provider_brand_id),
        confidence: Math.max(0, Math.min(1, numberValue(candidate.confidence) ?? 0)),
        resolution_status: candidate.resolution_status === 'resolved' ? 'resolved' as const : 'ambiguous' as const,
        match_method: safePublicText(candidate.match_method, 100),
        // Explanations can contain resolver evidence and internal metadata.
        // They are available only through the authenticated Admin detail API.
        explanation: {},
        offers: status === 'resolved' ? candidate.offers.slice(0, 100).map(sanitizePublicOffer) : [],
      }))
    : [];
  return {
    query: safePublicText(payload?.query, 200),
    normalized_query: safePublicText(payload?.normalized_query, 200),
    engine_version: safePublicText(payload?.engine_version, 100),
    status,
    candidates,
  };
}

function sanitizePublicOffer(offer: Record<string, unknown>): Record<string, unknown> {
  return {
    offer_id: stringValue(offer.offer_id),
    provider_brand_id: stringValue(offer.provider_brand_id),
    provider_name: safePublicText(offer.provider_name, 300),
    provider_location_id: stringValue(offer.provider_location_id),
    provider_location_name: safePublicText(offer.provider_location_name, 300),
    latitude: numberValue(offer.latitude),
    longitude: numberValue(offer.longitude),
    distance_meters: numberValue(offer.distance_meters),
    source_url: safeHttpUrl(offer.source_url),
    price_type: safePublicText(offer.price_type, 100),
    price_key: safePublicText(offer.price_key, 100),
    amount_minor: numberValue(offer.amount_minor),
    currency: safePublicText(offer.currency, 3),
    price_last_seen_at: safePublicText(offer.price_last_seen_at, 80),
  };
}

function safePublicText(value: unknown, maxLength: number): string {
  return (stringValue(value) ?? '').slice(0, maxLength);
}

function sanitizePackageResolution(payload: PackageResolutionResponse): PackageResolutionResponse {
  return {
    ...payload,
    solutions: payload.solutions.map((solution) => ({
      ...solution,
      selected_offers: solution.selected_offers.map((offer) => ({
        ...offer,
        source_url: safeHttpUrl(offer.source_url),
      })),
    })),
  };
}

function sanitizePublicPayload(value: unknown): unknown {
  if (Array.isArray(value)) return value.map((entry) => sanitizePublicPayload(entry));
  if (!isRecord(value)) return value;
  return Object.fromEntries(Object.entries(value).map(([key, entry]) => [
    key,
    key === 'source_url' || key === 'website_url' ? safeHttpUrl(entry) : sanitizePublicPayload(entry),
  ]));
}

async function resolveBatchResponse(request: Request, rpc: RpcClient, origin: string): Promise<Response> {
  const input = await readJsonObject(request, 16_384, origin);
  if (input instanceof Response) return input;
  const parsed = parseBatchRequest(input);
  if (!parsed.ok) return json({ error: parsed.error }, 400, origin);
  const context = parsePackageContext(input, origin);
  if (context instanceof Response) return context;
  return json(await resolvePackagePayload(parsed.value, context, rpc), 200, origin);
}

async function resolveImageResponse(request: Request, rpc: RpcClient, env: Env, origin: string, requestId?: string): Promise<Response> {
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 8_000_000) {
    return json({ error: { code: 'payload_too_large', message: 'The image request is too large' } }, 413, origin);
  }
  let body: unknown;
  try {
    body = JSON.parse(await readRequestText(request, 8_000_000));
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      return json({ error: { code: 'payload_too_large', message: 'The image request is too large' } }, 413, origin);
    }
    return json({ error: { code: 'invalid_json', message: 'Request body must be valid JSON' } }, 400, origin);
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return json({ error: { code: 'invalid_body', message: 'Request body must be an object' } }, 400, origin);
  }
  const input = body as Record<string, unknown>;
  const context = parsePackageContext(input, origin);
  if (context instanceof Response) return context;
  let image;
  try {
    image = parseOcrImageInput(input);
  } catch (error) {
    if (error instanceof OcrInputError) return json({ error: { code: error.code, message: error.message } }, 400, origin);
    throw error;
  }
  let ocr;
  try {
    ocr = env.OCR_SERVICE_URL
      ? await recognizeOrderImageViaService(
        env.OCR_SERVICE_URL,
        env.OCR_SERVICE_TOKEN,
        image,
        parsePositiveInt(env.OCR_SERVICE_TIMEOUT_MS, 20_000, 1_000, 60_000),
      )
      : await recognizeOrderImage(env.AI, image, env.OCR_AI_MODEL);
  } catch (error) {
    if (error instanceof OcrUnavailableError) {
      return errorJson(
        error.code,
        'La lectura de recetas no está disponible en este momento.',
        503,
        origin,
        requestId,
        'API.OCR.UNAVAILABLE',
        'medium',
        true,
      );
    }
    if (error instanceof OcrRecognitionError) {
      return errorJson(
        error.code,
        'No pudimos leer la receta con suficiente seguridad. Revisa el texto e inténtalo de nuevo.',
        502,
        origin,
        requestId,
        'API.OCR.RECOGNITION',
        'medium',
        true,
      );
    }
    throw error;
  }
  const parsed = parseBatchRequest({
    text: ocr.text,
    objective: input.objective,
    max_solutions: input.max_solutions,
  });
  if (!parsed.ok) {
    return json({
      error: { code: 'ocr_unusable', message: 'OCR text could not be converted into study entries' },
      ocr: { engine: ocr.engine, model: ocr.model, text: ocr.text },
    }, 422, origin);
  }
  const packageResult = await resolvePackagePayload(parsed.value, context, rpc, true);
  const lowConfidenceLines = (ocr.lines ?? [])
    .filter((line) => line.confidence !== null && line.confidence < 0.9)
    .map((line) => line.text);
  return json({
    ocr: {
      engine: ocr.engine,
      model: ocr.model,
      input_bytes: ocr.input_bytes,
      text: ocr.text,
      confidence: ocr.confidence ?? null,
      lines: ocr.lines ?? null,
      review_required: lowConfidenceLines.length > 0,
      low_confidence_lines: lowConfidenceLines,
    },
    ...packageResult,
  }, 200, origin);
}

async function analyticsEventResponse(request: Request, rpc: RpcClient, origin: string): Promise<Response> {
  const body = await readJsonObject(request, 4_096, origin);
  if (body instanceof Response) return body;
  if (typeof body.event_name !== 'string' || !ANALYTICS_EVENTS.has(body.event_name)) {
    return json({ error: { code: 'invalid_event', message: 'event_name is not supported' } }, 400, origin);
  }
  if (typeof body.anonymous_id !== 'string' || !isUuid(body.anonymous_id)) {
    return json({ error: { code: 'invalid_anonymous_id', message: 'anonymous_id must be a UUID' } }, 400, origin);
  }
  const metadata = parseAnalyticsMetadata(body.metadata);
  if (metadata === null) {
    return json({ error: { code: 'invalid_metadata', message: 'metadata contains unsupported or oversized values' } }, 400, origin);
  }
  return json(await rpc.call('api_record_analytics_event', {
    p_event_name: body.event_name,
    p_anonymous_id: body.anonymous_id,
    p_metadata: metadata,
  }), 202, origin);
}

function parseAnalyticsMetadata(value: unknown): Record<string, unknown> | null {
  if (value === undefined) return {};
  if (!isRecord(value)) return null;
  const metadata: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (!ANALYTICS_METADATA_KEYS.has(key)) return null;
    if (key === 'result_count' || key === 'item_count') {
      if (typeof entry !== 'number' || !Number.isInteger(entry) || entry < 0 || entry > 1000) return null;
      metadata[key] = entry;
    } else if (key === 'review_required') {
      if (typeof entry !== 'boolean') return null;
      metadata[key] = entry;
    } else if (key === 'status') {
      if (typeof entry !== 'string' || !ANALYTICS_STATUSES.has(entry)) return null;
      metadata[key] = entry;
    } else if (key === 'surface') {
      if (typeof entry !== 'string' || !ANALYTICS_SURFACES.has(entry)) return null;
      metadata[key] = entry;
    }
  }
  return metadata;
}

class RequestBodyTooLargeError extends Error {}

async function readRequestText(request: Request, maxBytes: number): Promise<string> {
  if (!request.body) return '';
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        throw new RequestBodyTooLargeError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bodyBytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bodyBytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bodyBytes);
}

interface PackageContext {
  domain: string;
  latitude: number | null;
  longitude: number | null;
  location_id: string | null;
}

function parsePackageContext(input: Record<string, unknown>, origin: string): PackageContext | Response {
  const domain = typeof input.domain === 'string' && input.domain !== '' ? input.domain : 'health_diagnostics';
  if (!/^[a-z][a-z0-9_]{1,63}$/.test(domain)) {
    return json({ error: { code: 'invalid_domain', message: 'domain is invalid' } }, 400, origin);
  }
  const latitude = parseInputCoordinate(input.latitude, -90, 90);
  const longitude = parseInputCoordinate(input.longitude, -180, 180);
  if ((latitude === null) !== (longitude === null) || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return json({ error: { code: 'invalid_coordinates', message: 'latitude and longitude must be provided together' } }, 400, origin);
  }
  const locationId = input.location_id === undefined || input.location_id === null ? null : input.location_id;
  if (locationId !== null && (typeof locationId !== 'string' || !isUuid(locationId))) {
    return json({ error: { code: 'invalid_location_id', message: 'location_id must be a UUID' } }, 400, origin);
  }
  return { domain, latitude, longitude, location_id: locationId as string | null };
}

async function resolvePackagePayload(
  parsed: ParsedBatchRequest,
  context: PackageContext,
  rpc: RpcClient,
  fromOcr = false,
): Promise<PackageResolutionResponse> {
  const effective = await segmentFreeFormPackageText(parsed, context.domain, rpc);
  const raw = await rpc.call<unknown>(fromOcr ? 'api_resolve_ocr_package' : 'api_resolve_package', {
    p_items: effective.items,
    p_domain_code: context.domain,
    p_latitude: context.latitude,
    p_longitude: context.longitude,
    p_location_id: context.location_id,
    p_limit: 10,
  });
  return sanitizePackageResolution(buildPackageResolution(
    normalizeBatchRpcPayload(raw),
    effective.original_text,
    effective.objective,
    effective.max_solutions,
  ));
}

/**
 * A prescription may arrive as one OCR/text line without punctuation. Ask the
 * database for a catalog-backed segmentation only for that narrow case. The
 * RPC is deliberately advisory: malformed, ambiguous, or unavailable results
 * leave the original single item untouched and therefore cannot fabricate a
 * package. Explicit `items` requests and already-separated text never incur
 * this extra lookup.
 */
async function segmentFreeFormPackageText(
  parsed: ParsedBatchRequest,
  domain: string,
  rpc: RpcClient,
): Promise<ParsedBatchRequest> {
  if (
    parsed.input_source !== 'text'
    || parsed.items.length !== 1
    || !/\s/.test(parsed.original_text)
    || /[\n;,]/.test(parsed.original_text)
  ) {
    return parsed;
  }

  let response: unknown;
  try {
    response = await rpc.call<unknown>('api_segment_package_text', {
      p_text: parsed.original_text,
      p_domain_code: domain,
      p_max_items: 30,
    });
  } catch {
    // The segmentation migration can be rolled out independently. Falling
    // back to the regular resolver keeps existing clients functional while it
    // is unavailable; a database outage in the actual package RPC is still
    // surfaced normally below.
    console.warn(JSON.stringify({
      event: 'api_degraded',
      error_tag: 'API.PACKAGE.SEGMENTATION_FALLBACK',
      operation: 'package_search',
      reason: 'segmenter_unavailable',
    }));
    return parsed;
  }
  const segments = readCatalogSegments(response, parsed.original_text);
  return segments === null ? parsed : { ...parsed, items: segments };
}

async function adminResponse(request: Request, url: URL, env: Env, rpc: RpcClient, origin: string, requestId: string, authenticateAdmin: (request: Request, env: Env) => Promise<AdminUser | null>): Promise<Response> {
  const user = await authenticateAdmin(request, env);
  if (!user) {
    return json({ error: { code: 'unauthorized', message: 'Admin authorization required' } }, 401, origin);
  }
  if (user.aal !== 'aal2') {
    return json({
      error: {
        code: 'mfa_required',
        message: 'A second factor is required for administrative access',
      },
    }, 403, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/dashboard') {
    return json(await rpc.call('api_admin_dashboard', {}, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/normalization-queue') {
    const queueStatus = url.searchParams.get('status');
    const queueInputType = url.searchParams.get('input_type');
    const beforeCreatedAt = url.searchParams.get('before_created_at');
    const beforeId = url.searchParams.get('before_id');
    if (queueStatus && !['pending', 'resolved', 'ambiguous', 'no_match', 'failed'].includes(queueStatus)) {
      return json({ error: { code: 'invalid_status', message: 'normalization queue status is invalid' } }, 400, origin);
    }
    if (queueInputType && !['crawler', 'search', 'ocr', 'manual', 'import'].includes(queueInputType)) {
      return json({ error: { code: 'invalid_input_type', message: 'normalization input_type is invalid' } }, 400, origin);
    }
    if ((beforeCreatedAt && !beforeId) || (!beforeCreatedAt && beforeId) || (beforeId !== null && !isUuid(beforeId)) || (beforeCreatedAt !== null && Number.isNaN(Date.parse(beforeCreatedAt)))) {
      return json({ error: { code: 'invalid_cursor', message: 'before_created_at and before_id must be a valid pair' } }, 400, origin);
    }
    return json(
      await rpc.call<AdminNormalizationQueueRow[]>('api_admin_normalization_queue_v2', {
        p_status: queueStatus,
        p_input_type: queueInputType,
        p_limit: parseBoundedInt(url.searchParams.get('limit'), 50, 1, 200),
        p_before_created_at: beforeCreatedAt,
        p_before_id: beforeId,
      }, { admin: true }),
      200,
      origin,
    );
  }
  const normalizationDetailMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([^/]+)$/i);
  if (normalizationDetailMatch && request.method === 'GET') {
    if (!isUuid(normalizationDetailMatch[1])) return json({ error: { code: 'invalid_id', message: 'normalization run id must be a UUID' } }, 400, origin);
    return json(
      sanitizePublicPayload(await rpc.call<AdminNormalizationDetail | null>('api_admin_normalization_detail', {
        p_normalization_run_id: normalizationDetailMatch[1],
        p_include_raw_payload: url.searchParams.get('include_payload') === 'true',
      }, { admin: true })),
      200,
      origin,
    );
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/raw-records') {
    return json(
      sanitizePublicPayload(await rpc.call('api_admin_raw_records', { p_limit: parseBoundedInt(url.searchParams.get('limit'), 50, 1, 200) }, { admin: true })),
      200,
      origin,
    );
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/catalog-items') {
    return json(
      await rpc.call<AdminCatalogItem[]>('api_admin_catalog_items', {
        p_query: url.searchParams.get('q'),
        p_limit: parseBoundedInt(url.searchParams.get('limit'), 25, 1, 100),
      }, { admin: true }),
      200,
      origin,
    );
  }
  const adminLookups: Record<string, { rpc: string; limit: number }> = {
    '/api/v1/admin/providers': { rpc: 'api_admin_providers', limit: 200 },
    '/api/v1/admin/locations': { rpc: 'api_admin_locations', limit: 200 },
    '/api/v1/admin/offers': { rpc: 'api_admin_offers', limit: 200 },
    '/api/v1/admin/prices': { rpc: 'api_admin_prices', limit: 200 },
  };
  const lookup = adminLookups[url.pathname];
  if (request.method === 'GET' && lookup) {
    return json(sanitizePublicPayload(await rpc.call(lookup.rpc, { p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, lookup.limit) }, { admin: true })), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/quality-issues') {
    return json(sanitizePublicPayload(await rpc.call<AdminQualityIssue[]>('api_admin_quality_issues', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true })), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/alerts') {
    return json(sanitizePublicPayload(await rpc.call<AdminAlert[]>('api_admin_alerts', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true })), 200, origin);
  }
  const alertStatusMatch = url.pathname.match(/^\/api\/v1\/admin\/alerts\/([^/]+)\/status$/i);
  if (alertStatusMatch && request.method === 'POST') {
    if (!isUuid(alertStatusMatch[1])) return json({ error: { code: 'invalid_id', message: 'alert id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (!['acknowledged', 'resolved', 'ignored'].includes(String(body.status))) {
      return json({ error: { code: 'invalid_body', message: 'status must be acknowledged, resolved or ignored' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 1000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 1000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_update_alert_status', {
      p_alert_id: alertStatusMatch[1],
      p_status: body.status,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
      p_reviewer_user_id: user.id,
      p_request_id: requestId,
    }, { admin: true }), 200, origin);
  }
  const qualityStatusMatch = url.pathname.match(/^\/api\/v1\/admin\/quality-issues\/([^/]+)\/status$/i);
  if (qualityStatusMatch && request.method === 'POST') {
    if (!isUuid(qualityStatusMatch[1])) return json({ error: { code: 'invalid_id', message: 'quality issue id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (!['acknowledged', 'resolved', 'ignored'].includes(String(body.status))) {
      return json({ error: { code: 'invalid_body', message: 'status must be acknowledged, resolved or ignored' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 1000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 1000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_update_quality_issue_status', {
      p_issue_id: qualityStatusMatch[1],
      p_status: body.status,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
      p_reviewer_user_id: user.id,
      p_request_id: requestId,
    }, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/provider-claims') {
    return json(sanitizePublicPayload(await rpc.call('api_admin_provider_claims', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true })), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/provider-change-requests') {
    return json(sanitizePublicPayload(await rpc.call('api_admin_provider_change_requests', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true })), 200, origin);
  }
  const providerClaimReviewMatch = url.pathname.match(/^\/api\/v1\/admin\/provider-claims\/([^/]+)\/review$/i);
  if (providerClaimReviewMatch && request.method === 'POST') {
    if (!isUuid(providerClaimReviewMatch[1])) return json({ error: { code: 'invalid_id', message: 'claim id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (body.decision !== 'approved' && body.decision !== 'rejected') {
      return json({ error: { code: 'invalid_body', message: 'decision must be approved or rejected' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 2000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 2000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_review_provider_claim', {
      p_claim_id: providerClaimReviewMatch[1],
      p_decision: body.decision,
      p_reviewer_user_id: user.id,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
    }, { admin: true }), 200, origin);
  }
  const providerClaimRevokeMatch = url.pathname.match(/^\/api\/v1\/admin\/provider-claims\/([^/]+)\/revoke$/i);
  if (providerClaimRevokeMatch && request.method === 'POST') {
    if (!isUuid(providerClaimRevokeMatch[1])) return json({ error: { code: 'invalid_id', message: 'claim id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (typeof body.reason !== 'string' || body.reason.trim().length === 0 || body.reason.length > 2000) {
      return json({ error: { code: 'invalid_body', message: 'a revocation reason of at most 2000 characters is required' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_revoke_provider_claim', {
      p_claim_id: providerClaimRevokeMatch[1],
      p_reviewer_user_id: user.id,
      p_reason: body.reason,
    }, { admin: true }), 200, origin);
  }
  const providerChangeReviewMatch = url.pathname.match(/^\/api\/v1\/admin\/provider-change-requests\/([^/]+)\/review$/i);
  if (providerChangeReviewMatch && request.method === 'POST') {
    if (!isUuid(providerChangeReviewMatch[1])) return json({ error: { code: 'invalid_id', message: 'change request id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (body.decision !== 'approved' && body.decision !== 'rejected') {
      return json({ error: { code: 'invalid_body', message: 'decision must be approved or rejected' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 2000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 2000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_review_provider_change', {
      p_request_id: providerChangeReviewMatch[1],
      p_decision: body.decision,
      p_reviewer_user_id: user.id,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
    }, { admin: true }), 200, origin);
  }
  const resolveMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([^/]+)\/resolve$/i);
  if (resolveMatch && request.method === 'POST') {
    if (!isUuid(resolveMatch[1])) return json({ error: { code: 'invalid_id', message: 'normalization run id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (typeof body.selected_item_id !== 'string' || !isUuid(body.selected_item_id) || typeof body.alias !== 'string' || body.alias.trim().length === 0 || body.alias.length > 200) {
      return json({ error: { code: 'invalid_body', message: 'selected_item_id and alias are required' } }, 400, origin);
    }
    if (typeof body.provider_brand_id === 'string' && !isUuid(body.provider_brand_id)) {
      return json({ error: { code: 'invalid_body', message: 'provider_brand_id must be a UUID' } }, 400, origin);
    }
    if (typeof body.reason === 'string' && body.reason.length > 1000) {
      return json({ error: { code: 'invalid_body', message: 'reason is too long' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_update_alias', {
      p_normalization_run_id: resolveMatch[1],
      p_selected_item_id: body.selected_item_id,
      p_alias: body.alias,
      p_provider_brand_id: typeof body.provider_brand_id === 'string' ? body.provider_brand_id : null,
      p_reason: typeof body.reason === 'string' ? body.reason : 'Manual admin review',
      p_reviewer_user_id: user.id,
      p_request_id: requestId,
    }, { admin: true }), 200, origin);
  }
  const manualCandidateMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([^/]+)\/candidates$/i);
  if (manualCandidateMatch && request.method === 'POST') {
    if (!isUuid(manualCandidateMatch[1])) return json({ error: { code: 'invalid_id', message: 'normalization run id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (typeof body.catalog_item_id !== 'string' || !isUuid(body.catalog_item_id) || typeof body.reason !== 'string' || body.reason.trim().length === 0 || body.reason.length > 1000) {
      return json({ error: { code: 'invalid_body', message: 'catalog_item_id and a reason of at most 1000 characters are required' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_add_manual_candidate', {
      p_normalization_run_id: manualCandidateMatch[1],
      p_catalog_item_id: body.catalog_item_id,
      p_reviewer_user_id: user.id,
      p_reason: body.reason.trim(),
      p_request_id: requestId,
    }, { admin: true }), 200, origin);
  }
  const reviewMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([^/]+)\/review$/i);
  if (reviewMatch && request.method === 'POST') {
    if (!isUuid(reviewMatch[1])) return json({ error: { code: 'invalid_id', message: 'normalization run id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (body.decision !== 'approve_candidate' && body.decision !== 'no_match') {
      return json({ error: { code: 'invalid_body', message: 'decision must be approve_candidate or no_match' } }, 400, origin);
    }
    if (body.decision === 'approve_candidate' && (typeof body.selected_candidate_id !== 'string' || !isUuid(body.selected_candidate_id))) {
      return json({ error: { code: 'invalid_body', message: 'selected_candidate_id is required for approval' } }, 400, origin);
    }
    if (body.decision === 'no_match' && (body.reason === undefined || typeof body.reason !== 'string' || body.reason.trim().length === 0)) {
      return json({ error: { code: 'invalid_body', message: 'a reason is required for no_match' } }, 400, origin);
    }
    if (body.alias !== undefined && body.alias !== null && (typeof body.alias !== 'string' || body.alias.trim().length === 0 || body.alias.length > 200)) {
      return json({ error: { code: 'invalid_body', message: 'alias must be at most 200 characters' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 1000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 1000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_review_normalization', {
      p_normalization_run_id: reviewMatch[1],
      p_decision: body.decision,
      p_selected_candidate_id: typeof body.selected_candidate_id === 'string' ? body.selected_candidate_id : null,
      p_alias: typeof body.alias === 'string' ? body.alias : null,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
      p_reviewer_user_id: user.id,
      p_request_id: requestId,
    }, { admin: true }), 200, origin);
  }
  return json({ error: { code: 'not_found', message: 'Admin route not found' } }, 404, origin);
}

interface AuthenticatedUser extends AdminUser {
  accessToken: string;
  /** Supabase's validated JWT assurance level; missing claims are aal1. */
  aal: 'aal1' | 'aal2';
}

async function providerResponse(
  request: Request,
  url: URL,
  env: Env,
  rpc: RpcClient,
  origin: string,
  authenticateUser: (request: Request, env: Env) => Promise<AuthenticatedUser | null>,
): Promise<Response> {
  const user = await authenticateUser(request, env);
  if (!user) return json({ error: { code: 'unauthorized', message: 'Provider authorization required' } }, 401, origin);
  // Reading one's own claims is allowed at AAL1 so the client can display the
  // enrollment step. Any provider mutation requires a verified second factor.
  if (request.method !== 'GET' && user.aal !== 'aal2') {
    return json({
      error: {
        code: 'mfa_required',
        message: 'A second factor is required for provider changes',
      },
    }, 403, origin);
  }
  const rpcOptions = { accessToken: user.accessToken };

  if (url.pathname === '/api/v1/provider/claims' && request.method === 'GET') {
    return json(await rpc.call('api_provider_my_claims', {
      p_status: url.searchParams.get('status'),
      p_limit: parseBoundedInt(url.searchParams.get('limit'), 50, 1, 100),
    }, rpcOptions), 200, origin);
  }
  if (url.pathname === '/api/v1/provider/memberships' && request.method === 'GET') {
    return json(await rpc.call('api_provider_my_memberships', {
      p_status: url.searchParams.get('status'),
      p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200),
    }, rpcOptions), 200, origin);
  }

  if (url.pathname === '/api/v1/provider/claims' && request.method === 'POST') {
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (typeof body.scope_type !== 'string' || !['brand', 'location'].includes(body.scope_type)) {
      return json({ error: { code: 'invalid_body', message: 'scope_type must be brand or location' } }, 400, origin);
    }
    if (!isUuidValue(body.provider_brand_id) || !isUuidValue(body.organization_id)) {
      return json({ error: { code: 'invalid_body', message: 'provider_brand_id and organization_id are required UUIDs' } }, 400, origin);
    }
    if (body.provider_location_id !== undefined && body.provider_location_id !== null && !isUuidValue(body.provider_location_id)) {
      return json({ error: { code: 'invalid_body', message: 'provider_location_id must be a UUID' } }, 400, origin);
    }
    if (typeof body.requested_role !== 'string' || !['brand_admin', 'location_manager', 'editor', 'read_only'].includes(body.requested_role)) {
      return json({ error: { code: 'invalid_body', message: 'requested_role is invalid' } }, 400, origin);
    }
    if (typeof body.relationship_type !== 'string' || !['owner', 'operator', 'franchisee', 'billing_entity', 'tenant', 'other'].includes(body.relationship_type)) {
      return json({ error: { code: 'invalid_body', message: 'relationship_type is invalid' } }, 400, origin);
    }
    if (body.reason !== undefined && body.reason !== null && (typeof body.reason !== 'string' || body.reason.length > 2000)) {
      return json({ error: { code: 'invalid_body', message: 'reason must be at most 2000 characters' } }, 400, origin);
    }
    return json(await rpc.call('api_provider_create_claim', {
      p_scope_type: body.scope_type,
      p_provider_brand_id: body.provider_brand_id,
      p_provider_location_id: body.provider_location_id ?? null,
      p_organization_id: body.organization_id,
      p_requested_role: body.requested_role,
      p_relationship_type: body.relationship_type,
      p_reason: typeof body.reason === 'string' ? body.reason : null,
      p_evidence_metadata: isRecord(body.evidence_metadata) ? body.evidence_metadata : {},
    }, rpcOptions), 201, origin);
  }

  const documentMatch = url.pathname.match(/^\/api\/v1\/provider\/claims\/([^/]+)\/documents$/i);
  if (documentMatch && request.method === 'POST') {
    if (!isUuid(documentMatch[1])) return json({ error: { code: 'invalid_id', message: 'claim id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (typeof body.document_type !== 'string' || typeof body.object_key !== 'string' || typeof body.sha256 !== 'string') {
      return json({ error: { code: 'invalid_body', message: 'document_type, object_key and sha256 are required' } }, 400, origin);
    }
    return json(await rpc.call('api_provider_add_claim_document', {
      p_claim_id: documentMatch[1],
      p_document_type: body.document_type,
      p_object_key: body.object_key,
      p_sha256: body.sha256,
      p_metadata: isRecord(body.metadata) ? body.metadata : {},
    }, rpcOptions), 201, origin);
  }

  const memberMatch = url.pathname.match(/^\/api\/v1\/provider\/claims\/([^/]+)\/members$/i);
  if (memberMatch && request.method === 'POST') {
    if (!isUuid(memberMatch[1])) return json({ error: { code: 'invalid_id', message: 'claim id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (!isUuidValue(body.user_id) || typeof body.role !== 'string' || !['brand_admin', 'location_manager', 'editor', 'read_only'].includes(body.role)) {
      return json({ error: { code: 'invalid_body', message: 'user_id and a valid role are required' } }, 400, origin);
    }
    if (body.provider_location_id !== undefined && body.provider_location_id !== null && !isUuidValue(body.provider_location_id)) {
      return json({ error: { code: 'invalid_body', message: 'provider_location_id must be a UUID' } }, 400, origin);
    }
    return json(await rpc.call('api_provider_invite_member', {
      p_claim_id: memberMatch[1],
      p_user_id: body.user_id,
      p_role: body.role,
      p_provider_location_id: body.provider_location_id ?? null,
    }, rpcOptions), 201, origin);
  }

  const profileMatch = url.pathname.match(/^\/api\/v1\/provider\/locations\/([^/]+)\/profile$/i);
  if (profileMatch && request.method === 'PATCH') {
    if (!isUuid(profileMatch[1])) return json({ error: { code: 'invalid_id', message: 'location id must be a UUID' } }, 400, origin);
    const body = await readJsonObject(request, 16_384, origin);
    if (body instanceof Response) return body;
    if (!isUuidValue(body.claim_id) || !isRecord(body.changes)) {
      return json({ error: { code: 'invalid_body', message: 'claim_id and changes object are required' } }, 400, origin);
    }
    return json(await rpc.call('api_provider_submit_location_change', {
      p_claim_id: body.claim_id,
      p_provider_location_id: profileMatch[1],
      p_changes: body.changes,
    }, rpcOptions), 202, origin);
  }
  const membershipAcceptMatch = url.pathname.match(/^\/api\/v1\/provider\/memberships\/([^/]+)\/accept$/i);
  if (membershipAcceptMatch && request.method === 'POST') {
    if (!isUuid(membershipAcceptMatch[1])) return json({ error: { code: 'invalid_id', message: 'membership id must be a UUID' } }, 400, origin);
    return json(await rpc.call('api_provider_accept_membership', { p_membership_id: membershipAcceptMatch[1] }, rpcOptions), 200, origin);
  }

  return json({ error: { code: 'not_found', message: 'Provider route not found' } }, 404, origin);
}

async function verifyAdmin(request: Request, env: Env): Promise<AdminUser | null> {
  const user = await verifyUser(request, env);
  if (!user) return null;
  const allowedIds = new Set((env.ADMIN_USER_IDS ?? '').split(',').map((value) => value.trim().toLowerCase()).filter(isUuid));
  if (allowedIds.size === 0) return null;
  return allowedIds.has(user.id.toLowerCase()) ? { id: user.id, aal: user.aal } : null;
}

async function verifyUser(request: Request, env: Env): Promise<AuthenticatedUser | null> {
  const authorization = request.headers.get('authorization') ?? '';
  const match = authorization.match(/^Bearer\s+([^\s]+)$/i);
  const publishableKey = env.SUPABASE_PUBLISHABLE_KEY ?? env.SUPABASE_ANON_KEY;
  if (!match || !env.SUPABASE_URL || !publishableKey) return null;
  let supabaseBaseUrl: URL;
  try {
    supabaseBaseUrl = new URL(env.SUPABASE_URL);
    const localDevelopment = supabaseBaseUrl.protocol === 'http:'
      && (supabaseBaseUrl.hostname === 'localhost' || supabaseBaseUrl.hostname === '127.0.0.1' || supabaseBaseUrl.hostname === '::1')
      && env.APP_ENV !== 'production';
    if (supabaseBaseUrl.protocol !== 'https:' && !localDevelopment) return null;
  } catch {
    return null;
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(new URL('/auth/v1/user', supabaseBaseUrl).toString(), {
      headers: { apikey: publishableKey, Authorization: `Bearer ${match[1]}` },
      signal: controller.signal,
    });
    if (!response.ok) return null;
    const user = await response.json() as { id?: unknown };
    if (typeof user.id !== 'string' || !isUuid(user.id)) return null;
    return { id: user.id, accessToken: match[1], aal: readJwtAal(match[1]) };
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * `/auth/v1/user` validates the bearer token. We only inspect the validated
 * token's `aal` claim here to enforce the provider step-up policy; no client
 * supplied role is trusted. An absent/malformed claim is deliberately aal1.
 */
function readJwtAal(token: string): 'aal1' | 'aal2' {
  const parts = token.split('.');
  if (parts.length !== 3) return 'aal1';
  try {
    const encoded = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '=');
    const payload = JSON.parse(atob(padded)) as { aal?: unknown };
    return payload.aal === 'aal2' ? 'aal2' : 'aal1';
  } catch {
    return 'aal1';
  }
}

function groupSearchRows(rows: SearchRow[]) {
  type GroupedOffer = {
    id: string;
    provider: Record<string, unknown>;
    location: Record<string, unknown> | null;
    distance_meters: number | null;
    price: Record<string, unknown> | null;
    prices: Map<string, Record<string, unknown>>;
    source: Record<string, unknown> | null;
  };
  const concreteOfferKeys = new Set(
    rows
      .filter((row) => row.provider_location_id !== null)
      .map((row) => `${row.service_id}:${row.offer_id}`),
  );
  const services = new Map<string, { service: Record<string, unknown>; offers: Map<string, GroupedOffer> }>();
  for (const row of rows) {
    // A brand-level fallback with no price is not useful when the same offer
    // already has a concrete branch row. It otherwise renders as a duplicate
    // card pointing to the same source URL.
    if (
      row.provider_location_id === null &&
      row.amount_minor === null &&
      concreteOfferKeys.has(`${row.service_id}:${row.offer_id}`)
    ) {
      continue;
    }
    const existing = services.get(row.service_id) ?? {
      service: {
        id: row.service_id,
        display_name: row.display_name,
        matched_term: row.matched_term,
        term_source: row.term_source,
        confidence: row.confidence,
      },
      offers: new Map<string, GroupedOffer>(),
    };
    const offerKey = `${row.offer_id}:${row.provider_location_id ?? 'brand'}`;
    const offer = existing.offers.get(offerKey) ?? {
      id: row.offer_id,
      provider: { id: row.provider_brand_id, name: row.provider_name },
      location: row.provider_location_id ? {
        id: row.provider_location_id,
        name: row.provider_location_name,
        latitude: row.latitude,
        longitude: row.longitude,
      } : null,
      distance_meters: row.distance_meters,
      price: null,
      prices: new Map<string, Record<string, unknown>>(),
      source: safeHttpUrl(row.source_url)
        ? { url: safeHttpUrl(row.source_url), last_seen_at: row.price_last_seen_at }
        : null,
    };
    if (row.amount_minor !== null) {
      const price = {
        type: row.price_type,
        key: row.price_key,
        amount_minor: row.amount_minor,
        currency: row.currency,
        last_seen_at: row.price_last_seen_at,
      };
      const priceKey = `${row.price_type ?? 'unknown'}:${row.price_key ?? 'default'}`;
      offer.prices.set(priceKey, price);
      offer.price ??= price;
    }
    existing.offers.set(offerKey, offer);
    services.set(row.service_id, existing);
  }
  return [...services.values()].map((entry) => ({
    service: entry.service,
    offers: [...entry.offers.values()].map((offer) => ({
      id: offer.id,
      provider: offer.provider,
      location: offer.location,
      distance_meters: offer.distance_meters,
      price: offer.price,
      prices: [...offer.prices.values()],
      source: offer.source,
    })),
  }));
}

function groupResolutionCandidates(candidates: ResolutionCandidate[]) {
  return candidates.map((candidate) => ({
    service: {
      id: candidate.service_id,
      display_name: candidate.display_name,
      matched_term: candidate.matched_term,
      term_source: candidate.term_source,
      confidence: candidate.confidence,
      resolution_status: candidate.resolution_status,
    },
    offers: candidate.offers.map((offer) => ({
      id: stringValue(offer.offer_id) ?? 'offer',
      provider: {
        id: stringValue(offer.provider_brand_id),
        name: stringValue(offer.provider_name) ?? 'Proveedor',
      },
      location: stringValue(offer.provider_location_id)
        ? {
            id: stringValue(offer.provider_location_id),
            name: stringValue(offer.provider_location_name),
            latitude: numberValue(offer.latitude),
            longitude: numberValue(offer.longitude),
          }
        : null,
      distance_meters: numberValue(offer.distance_meters),
      price: numberValue(offer.amount_minor) === null
        ? null
        : {
            type: stringValue(offer.price_type),
            key: stringValue(offer.price_key),
            amount_minor: numberValue(offer.amount_minor),
            currency: stringValue(offer.currency),
            last_seen_at: stringValue(offer.price_last_seen_at),
          },
      prices: [],
      source: safeHttpUrl(offer.source_url)
        ? { url: safeHttpUrl(offer.source_url), last_seen_at: stringValue(offer.price_last_seen_at) }
        : null,
    })),
  }));
}

function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

function safeHttpUrl(value: unknown): string | null {
  const raw = stringValue(value);
  if (!raw) return null;
  try {
    const parsed = new URL(raw);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
    if (parsed.username || parsed.password) return null;
    // Query strings and fragments may contain signed URLs, access tokens or
    // tracking identifiers. Public/admin screens only need the canonical
    // source location, never retrieval credentials.
    parsed.search = '';
    parsed.hash = '';
    return parsed.toString();
  } catch {
    return null;
  }
}

function numberValue(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseBoundedInt(value: string | null, fallback: number, min: number, max: number): number {
  const parsed = value === null ? Number.NaN : Number(value);
  return Number.isInteger(parsed) ? Math.max(min, Math.min(max, parsed)) : fallback;
}

function parsePositiveInt(value: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = value === undefined ? Number.NaN : Number(value);
  return Number.isInteger(parsed) ? Math.max(min, Math.min(max, parsed)) : fallback;
}

function parseCoordinate(value: string | null, min: number, max: number): number | null {
  if (value === null || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : Number.NaN;
}

function parseInputCoordinate(value: unknown, min: number, max: number): number | null {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'number') return Number.NaN;
  return Number.isFinite(value) && value >= min && value <= max ? value : Number.NaN;
}

async function readJsonObject(request: Request, maxBytes: number, origin: string): Promise<Record<string, unknown> | Response> {
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    return json({ error: { code: 'payload_too_large', message: 'The request body is too large' } }, 413, origin);
  }
  try {
    const parsed: unknown = JSON.parse(await readRequestText(request, maxBytes));
    if (!isRecord(parsed)) return json({ error: { code: 'invalid_body', message: 'Request body must be an object' } }, 400, origin);
    return parsed;
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) return json({ error: { code: 'payload_too_large', message: 'The request body is too large' } }, 413, origin);
    return json({ error: { code: 'invalid_json', message: 'Request body must be valid JSON' } }, 400, origin);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isUuidValue(value: unknown): value is string {
  return typeof value === 'string' && isUuid(value);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

type FailureSeverity = 'low' | 'medium' | 'high';

interface ClassifiedFailure {
  status: number;
  code: string;
  type: string;
  errorTag: string;
  severity: FailureSeverity;
  retryable: boolean;
  operation: string;
  message: string;
}

function classifyFailure(error: unknown, path: string): ClassifiedFailure {
  const operation = operationForPath(path);
  if (error instanceof SupabaseConfigurationError) {
    return {
      status: 503,
      code: error.code,
      type: 'configuration',
      errorTag: 'API.SERVER.CONFIGURATION',
      severity: 'high',
      retryable: false,
      operation,
      message: 'El servicio de búsqueda no está configurado. Inténtalo más tarde.',
    };
  }
  if (error instanceof SupabaseTimeoutError) {
    return {
      status: 504,
      code: error.code,
      type: 'timeout',
      errorTag: 'API.SERVER.TIMEOUT',
      severity: 'medium',
      retryable: true,
      operation,
      message: 'El servicio tardó demasiado en responder. Inténtalo de nuevo en unos segundos.',
    };
  }
  if (error instanceof SupabaseRpcError) {
    const rateLimited = error.status === 429;
    const status = rateLimited || error.status >= 500 ? 503 : 502;
    return {
      status,
      code: rateLimited ? 'upstream_rate_limited' : 'upstream_rpc_error',
      type: rateLimited ? 'rate_limit' : 'upstream',
      errorTag: rateLimited ? 'API.SERVER.RATE_LIMIT' : 'API.SERVER.UPSTREAM',
      severity: error.status >= 500 || rateLimited ? 'high' : 'medium',
      retryable: error.retryable,
      operation,
      message: rateLimited
        ? 'Hay muchas solicitudes en este momento. Inténtalo de nuevo en unos segundos.'
        : 'No pudimos completar la consulta en este momento. Inténtalo de nuevo.',
    };
  }
  if (error instanceof SupabaseResponseError) {
    return {
      status: 502,
      code: error.code,
      type: 'upstream_protocol',
      errorTag: 'API.SERVER.UPSTREAM_PROTOCOL',
      severity: 'high',
      retryable: true,
      operation,
      message: 'La fuente de datos devolvió una respuesta inválida. Inténtalo de nuevo.',
    };
  }
  if (isNetworkFailure(error)) {
    return {
      status: 503,
      code: 'upstream_connection_error',
      type: 'connection',
      errorTag: 'API.SERVER.CONNECTION',
      severity: 'medium',
      retryable: true,
      operation,
      message: 'No pudimos conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
    };
  }
  return {
    status: 500,
    code: 'internal_error',
    type: 'internal',
    errorTag: 'API.SERVER.INTERNAL',
    severity: 'high',
    retryable: false,
    operation,
    message: 'Ocurrió un problema inesperado. Inténtalo de nuevo más tarde.',
  };
}

function isNetworkFailure(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const candidate = error as { name?: unknown; message?: unknown };
  const name = typeof candidate.name === 'string' ? candidate.name : '';
  const message = typeof candidate.message === 'string' ? candidate.message : '';
  return name === 'AbortError' || /fetch|network|connect|socket|dns|timed out/i.test(`${name} ${message}`);
}

function operationForPath(path: string): string {
  if (path === '/api/v1/search' || path === '/api/v1/resolve') return 'individual_search';
  if (path === '/api/v1/resolve-batch') return 'package_search';
  if (path === '/api/v1/resolve-image') return 'recipe_ocr';
  if (path === '/api/v1/events') return 'analytics';
  if (path.startsWith('/api/v1/admin/')) return 'admin';
  if (path.startsWith('/api/v1/provider/')) return 'provider';
  return 'api';
}

function safeErrorDetail(error: unknown): string {
  if (error instanceof SupabaseRpcError) {
    return `rpc=${error.rpcName}; upstream_status=${error.status}`;
  }
  if (error instanceof SupabaseTimeoutError) {
    return `rpc=${error.rpcName}; timeout_ms=${error.timeoutMs}`;
  }
  if (error instanceof SupabaseConfigurationError) return 'supabase_configuration';
  if (error instanceof SupabaseResponseError) return `rpc=${error.rpcName}; invalid_json=true`;
  return 'internal_error';
}

async function enforceRateLimit(request: Request, url: URL, env: Env, origin: string, requestId: string): Promise<Response | null> {
  const scope = rateLimitScope(url.pathname, request.method);
  if (!scope) return null;
  const limiter = rateLimiterForScope(scope, env);
  if (!limiter) return null;
  try {
    const result = await limiter.limit({ key: `${scope}:${rateLimitIdentity(request)}` });
    if (result.success) return null;
    const response = errorJson(
      'rate_limited',
      'Too many requests. Try again later.',
      429,
      origin,
      requestId,
      'API.SERVER.RATE_LIMIT',
      'medium',
      true,
    );
    response.headers.set('retry-after', '60');
    return response;
  } catch {
    // In development a missing binding should not prevent local work. In
    // production, fail closed so a deployment without its abuse-control
    // binding cannot expose expensive or privileged routes without limits.
    console.warn(JSON.stringify({ event: 'rate_limit_unavailable', request_id: requestId, scope }));
    if (env.APP_ENV === 'production') {
      return errorJson(
        'rate_limit_unavailable',
        'The service is temporarily unavailable.',
        503,
        origin,
        requestId,
        'API.SERVER.RATE_LIMIT_CONFIGURATION',
        'high',
        true,
      );
    }
    return null;
  }
}

function rateLimitScope(path: string, method: string): 'public' | 'ocr' | 'admin' | null {
  if (path === '/api/v1/resolve-image' && method === 'POST') return 'ocr';
  if (path === '/api/v1/search' && method === 'GET') return 'public';
  if (method === 'GET' && /^\/api\/v1\/(?:services|providers)\/[^/]+(?:\/(?:providers|services))?$/i.test(path)) return 'public';
  if ((path === '/api/v1/resolve' || path === '/api/v1/resolve-batch' || path === '/api/v1/events') && method === 'POST') return 'public';
  if (path.startsWith('/api/v1/admin/')) return 'admin';
  return null;
}

function rateLimiterForScope(scope: 'public' | 'ocr' | 'admin', env: Env): RateLimitBinding | undefined {
  if (scope === 'ocr') return env.OCR_RATE_LIMITER;
  if (scope === 'admin') return env.ADMIN_RATE_LIMITER;
  return env.PUBLIC_RATE_LIMITER;
}

function rateLimitIdentity(request: Request): string {
  const address = request.headers.get('cf-connecting-ip')?.trim() ?? '';
  return /^[A-Fa-f0-9:.]{1,64}$/.test(address) ? address : 'unknown-client';
}

function isSecureConfiguredOrigin(value: string | undefined): boolean {
  if (!value || value === '*') return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' && parsed.origin === value.replace(/\/$/, '');
  } catch {
    return false;
  }
}

function configuredCorsOrigin(value: string | undefined): string {
  const candidate = value?.trim() ?? '';
  if (!candidate || candidate === '*') return '*';
  try {
    const parsed = new URL(candidate);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') return parsed.origin;
  } catch {
    // Fall through to the safe wildcard used only for development/misconfig.
  }
  return '*';
}

function requestIdFor(request: Request): string {
  const supplied = request.headers.get('idempotency-key')?.trim()
    || request.headers.get('x-request-id')?.trim()
    || '';
  // Correlation ids are accepted only in a conservative format so logs
  // cannot be polluted with arbitrary control characters or huge values.
  if (/^[A-Za-z0-9._:-]{8,96}$/.test(supplied)) return supplied;
  return crypto.randomUUID();
}

function json(value: unknown, status: number, origin: string, requestId?: string): Response {
  const headers: Record<string, string> = { ...JSON_HEADERS, ...corsHeaders(origin) };
  if (requestId) headers['x-request-id'] = requestId;
  return new Response(JSON.stringify(value), { status, headers });
}

function errorJson(
  code: string,
  message: string,
  status: number,
  origin: string,
  requestId: string | undefined,
  errorTag: string,
  severity: FailureSeverity,
  retryable: boolean,
): Response {
  return json({
    error: {
      code,
      type: code.startsWith('ocr_') ? 'ocr' : 'request',
      error_tag: errorTag,
      severity,
      retryable,
      message,
      ...(requestId ? { request_id: requestId } : {}),
    },
  }, status, origin, requestId);
}

function corsHeaders(origin: string): Record<string, string> {
  return { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'authorization,content-type,x-request-id,idempotency-key', 'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS' };
}
