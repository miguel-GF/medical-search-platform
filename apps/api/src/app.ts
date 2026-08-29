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
}

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8' };

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
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 16_384) {
    return json({ error: { code: 'payload_too_large', message: 'The request body is too large' } }, 413, origin);
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: { code: 'invalid_json', message: 'Request body must be valid JSON' } }, 400, origin);
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return json({ error: { code: 'invalid_body', message: 'Request body must be an object' } }, 400, origin);
  }
  const input = body as Record<string, unknown>;
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
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 16_384) {
    return json({ error: { code: 'payload_too_large', message: 'The request body is too large' } }, 413, origin);
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: { code: 'invalid_json', message: 'Request body must be valid JSON' } }, 400, origin);
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return json({ error: { code: 'invalid_body', message: 'Request body must be an object' } }, 400, origin);
  }
  const parsed = parseBatchRequest(body as Record<string, unknown>);
  if (!parsed.ok) return json({ error: parsed.error }, 400, origin);
  const input = body as Record<string, unknown>;
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
  const packageResult = await resolvePackagePayload(parsed.value, context, rpc);
  return json({
    ocr: { engine: ocr.engine, model: ocr.model, input_bytes: ocr.input_bytes, text: ocr.text, confidence: ocr.confidence ?? null },
    ...packageResult,
  }, 200, origin);
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
): Promise<PackageResolutionResponse> {
  const raw = await rpc.call<unknown>('api_resolve_package', {
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
  const resolveMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([^/]+)\/resolve$/i);
  if (resolveMatch && request.method === 'POST') {
    if (!isUuid(resolveMatch[1])) return json({ error: { code: 'invalid_id', message: 'normalization run id must be a UUID' } }, 400, origin);
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body || typeof body.selected_item_id !== 'string' || !isUuid(body.selected_item_id) || typeof body.alias !== 'string' || body.alias.trim().length === 0 || body.alias.length > 200) {
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

async function verifyAdmin(request: Request, env: Env): Promise<AdminUser | null> {
  const authorization = request.headers.get('authorization') ?? '';
  const match = authorization.match(/^Bearer\s+([^\s]+)$/i);
  if (!match || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  const allowedIds = new Set((env.ADMIN_USER_IDS ?? '').split(',').map((value) => value.trim().toLowerCase()).filter(isUuid));
  if (allowedIds.size === 0) return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(`${env.SUPABASE_URL.replace(/\/$/, '')}/auth/v1/user`, {
      headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${match[1]}` },
      signal: controller.signal,
    });
    if (!response.ok) return null;
    const user = await response.json() as { id?: unknown };
    if (typeof user.id !== 'string' || !isUuid(user.id) || !allowedIds.has(user.id.toLowerCase())) return null;
    return { id: user.id };
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
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
  const services = new Map<string, { service: Record<string, unknown>; offers: Map<string, GroupedOffer> }>();
  for (const row of rows) {
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

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function json(value: unknown, status: number, origin: string): Response {
  return new Response(JSON.stringify(value), { status, headers: { ...JSON_HEADERS, ...corsHeaders(origin) } });
}

function corsHeaders(origin: string): Record<string, string> {
  return { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'authorization,content-type', 'access-control-allow-methods': 'GET,POST,OPTIONS' };
}
