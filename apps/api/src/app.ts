import { SupabaseRpcClient } from './supabase.js';
import type { AdminAlert, AdminCatalogItem, AdminQualityIssue, AdminUser, Env, PackageResolutionResponse, ResolutionResponse, RpcClient, SearchRow } from './types.js';
import { buildPackageResolution, normalizeBatchRpcPayload, parseBatchRequest } from './batch.js';
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
    const origin = env.ALLOWED_ORIGIN ?? '*';
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    try {
      const url = new URL(request.url);
      if (url.pathname === '/health' && request.method === 'GET') {
        return json({ status: 'ok', service: 'pruevia-api', version: env.API_VERSION ?? 'v1' }, 200, origin);
      }
      if (url.pathname === '/api/v1/search' && request.method === 'GET') {
        return await searchResponse(url, dependencies.rpc, origin);
      }
      if (url.pathname === '/api/v1/resolve' && request.method === 'POST') {
        return await resolveResponse(request, dependencies.rpc, origin);
      }
      if (url.pathname === '/api/v1/resolve-batch' && request.method === 'POST') {
        return await resolveBatchResponse(request, dependencies.rpc, origin);
      }
      if (url.pathname === '/api/v1/resolve-image' && request.method === 'POST') {
        return await resolveImageResponse(request, dependencies.rpc, env, origin);
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
        return json(serviceMatch[2] ? { service_id: serviceMatch[1], providers: (payload as { offers?: unknown[] }).offers ?? [] } : payload, 200, origin);
      }
      const providerMatch = url.pathname.match(/^\/api\/v1\/providers\/([^/]+)(?:\/(services))?$/i);
      if (providerMatch && request.method === 'GET') {
        if (!isUuid(providerMatch[1])) return json({ error: { code: 'invalid_id', message: 'provider id must be a UUID' } }, 400, origin);
        const payload = await dependencies.rpc.call('api_provider_detail', { p_provider_brand_id: providerMatch[1] });
        if (!payload) return json(null, 404, origin);
        return json(providerMatch[2] ? { provider_id: providerMatch[1], services: (payload as { services?: unknown[] }).services ?? [] } : payload, 200, origin);
      }
      if (url.pathname.startsWith('/api/v1/admin/')) {
        return await adminResponse(request, url, env, dependencies.rpc, origin, dependencies.authenticateAdmin ?? verifyAdmin);
      }
      if (url.pathname.startsWith('/api/v1/provider/')) {
        return await providerResponse(request, url, env, dependencies.rpc, origin, dependencies.authenticateUser ?? verifyUser);
      }
      return json({ error: { code: 'not_found', message: 'Route not found' } }, 404, origin);
    } catch (error) {
      console.error('Pruevia API request failed', error);
      return json({ error: { code: 'internal_error', message: 'The request could not be completed' } }, 500, origin);
    }
  };
}

export function createWorkerHandler(env: Env) {
  return createHandler({ rpc: new SupabaseRpcClient(env) });
}

async function searchResponse(url: URL, rpc: RpcClient, origin: string): Promise<Response> {
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
  return json({ query, results: groupSearchRows(rows ?? []) }, 200, origin);
}

async function resolveResponse(request: Request, rpc: RpcClient, origin: string): Promise<Response> {
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
  return json(payload, 200, origin);
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

async function resolveImageResponse(request: Request, rpc: RpcClient, env: Env, origin: string): Promise<Response> {
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
    if (error instanceof OcrUnavailableError) return json({ error: { code: error.code, message: 'OCR is not configured for this environment' } }, 503, origin);
    if (error instanceof OcrRecognitionError) return json({ error: { code: error.code, message: 'The image could not be transcribed safely' } }, 502, origin);
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
  parsed: { items: string[]; original_text: string; objective: PackageResolutionResponse['objective']; max_solutions: number },
  context: PackageContext,
  rpc: RpcClient,
  fromOcr = false,
): Promise<PackageResolutionResponse> {
  const raw = await rpc.call<unknown>(fromOcr ? 'api_resolve_ocr_package' : 'api_resolve_package', {
    p_items: parsed.items,
    p_domain_code: context.domain,
    p_latitude: context.latitude,
    p_longitude: context.longitude,
    p_location_id: context.location_id,
    p_limit: 10,
  });
  return buildPackageResolution(
    normalizeBatchRpcPayload(raw),
    parsed.original_text,
    parsed.objective,
    parsed.max_solutions,
  );
}

async function adminResponse(request: Request, url: URL, env: Env, rpc: RpcClient, origin: string, authenticateAdmin: (request: Request, env: Env) => Promise<AdminUser | null>): Promise<Response> {
  const user = await authenticateAdmin(request, env);
  if (!user) {
    return json({ error: { code: 'unauthorized', message: 'Admin authorization required' } }, 401, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/dashboard') {
    return json(await rpc.call('api_admin_dashboard', {}, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/normalization-queue') {
    return json(
      await rpc.call('api_admin_normalization_queue', {
        p_status: url.searchParams.get('status'),
        p_limit: parseBoundedInt(url.searchParams.get('limit'), 50, 1, 200),
      }, { admin: true }),
      200,
      origin,
    );
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/raw-records') {
    return json(
      await rpc.call('api_admin_raw_records', { p_limit: parseBoundedInt(url.searchParams.get('limit'), 50, 1, 200) }, { admin: true }),
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
    return json(await rpc.call(lookup.rpc, { p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, lookup.limit) }, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/quality-issues') {
    return json(await rpc.call<AdminQualityIssue[]>('api_admin_quality_issues', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/alerts') {
    return json(await rpc.call<AdminAlert[]>('api_admin_alerts', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/provider-claims') {
    return json(await rpc.call('api_admin_provider_claims', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true }), 200, origin);
  }
  if (request.method === 'GET' && url.pathname === '/api/v1/admin/provider-change-requests') {
    return json(await rpc.call('api_admin_provider_change_requests', { p_status: url.searchParams.get('status'), p_limit: parseBoundedInt(url.searchParams.get('limit'), 100, 1, 200) }, { admin: true }), 200, origin);
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
  return allowedIds.has(user.id.toLowerCase()) ? { id: user.id } : null;
}

async function verifyUser(request: Request, env: Env): Promise<AuthenticatedUser | null> {
  const authorization = request.headers.get('authorization') ?? '';
  const match = authorization.match(/^Bearer\s+([^\s]+)$/i);
  if (!match || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(`${env.SUPABASE_URL.replace(/\/$/, '')}/auth/v1/user`, {
      headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${match[1]}` },
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
      source: row.source_url ? { url: row.source_url, last_seen_at: row.price_last_seen_at } : null,
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

function json(value: unknown, status: number, origin: string): Response {
  return new Response(JSON.stringify(value), { status, headers: { ...JSON_HEADERS, ...corsHeaders(origin) } });
}

function corsHeaders(origin: string): Record<string, string> {
  return { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'authorization,content-type', 'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS' };
}
