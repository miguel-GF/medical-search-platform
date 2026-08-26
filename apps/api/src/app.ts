import { SupabaseRpcClient } from './supabase.js';
import type { Env, RpcClient, SearchRow } from './types.js';

interface Dependencies {
  rpc: RpcClient;
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
      if (url.pathname === '/api/v1/services' && request.method === 'GET') {
        return json({ error: { code: 'route_requires_id', message: 'Use /api/v1/services/{id}' } }, 400, origin);
      }
      const serviceMatch = url.pathname.match(/^\/api\/v1\/services\/([0-9a-f-]{36})(?:\/(providers))?$/i);
      if (serviceMatch && request.method === 'GET') {
        const payload = await dependencies.rpc.call('api_service_detail', { p_service_id: serviceMatch[1] });
        return json(payload ?? null, payload ? 200 : 404, origin);
      }
      const providerMatch = url.pathname.match(/^\/api\/v1\/providers\/([0-9a-f-]{36})(?:\/(services))?$/i);
      if (providerMatch && request.method === 'GET') {
        const payload = await dependencies.rpc.call('api_provider_detail', { p_provider_brand_id: providerMatch[1] });
        return json(payload ?? null, payload ? 200 : 404, origin);
      }
      if (url.pathname.startsWith('/api/v1/admin/')) {
        return await adminResponse(request, url, env, dependencies.rpc, origin);
      }
      return json({ error: { code: 'not_found', message: 'Route not found' } }, 404, origin);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unexpected error';
      return json({ error: { code: 'internal_error', message } }, 500, origin);
    }
  };
}

export function createWorkerHandler(env: Env) {
  return createHandler({ rpc: new SupabaseRpcClient(env) });
}

async function searchResponse(url: URL, rpc: RpcClient, origin: string): Promise<Response> {
  const query = (url.searchParams.get('q') ?? '').trim();
  if (!query || query.length > 200) {
    return json({ error: { code: 'invalid_query', message: 'q is required and must be at most 200 characters' } }, 400, origin);
  }
  const limit = parseBoundedInt(url.searchParams.get('limit'), 20, 1, 100);
  const latitude = parseCoordinate(url.searchParams.get('lat'), -90, 90);
  const longitude = parseCoordinate(url.searchParams.get('lng'), -180, 180);
  if ((latitude === null) !== (longitude === null) || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return json({ error: { code: 'invalid_coordinates', message: 'lat and lng must be provided together' } }, 400, origin);
  }
  const rows = await rpc.call<SearchRow[]>('api_search', {
    p_query: query,
    p_domain_code: url.searchParams.get('domain') ?? 'health_diagnostics',
    p_latitude: latitude,
    p_longitude: longitude,
    p_location_id: url.searchParams.get('location_id'),
    p_limit: limit,
  });
  return json({ query, results: groupSearchRows(rows ?? []) }, 200, origin);
}

async function adminResponse(request: Request, url: URL, env: Env, rpc: RpcClient, origin: string): Promise<Response> {
  if (!env.ADMIN_TOKEN || request.headers.get('authorization') !== `Bearer ${env.ADMIN_TOKEN}`) {
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
  const resolveMatch = url.pathname.match(/^\/api\/v1\/admin\/normalization\/([0-9a-f-]{36})\/resolve$/i);
  if (resolveMatch && request.method === 'POST') {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body || typeof body.selected_item_id !== 'string' || typeof body.alias !== 'string') {
      return json({ error: { code: 'invalid_body', message: 'selected_item_id and alias are required' } }, 400, origin);
    }
    return json(await rpc.call('api_admin_update_alias', {
      p_normalization_run_id: resolveMatch[1],
      p_selected_item_id: body.selected_item_id,
      p_alias: body.alias,
      p_provider_brand_id: typeof body.provider_brand_id === 'string' ? body.provider_brand_id : null,
      p_reason: typeof body.reason === 'string' ? body.reason : 'Manual admin review',
    }, { admin: true }), 200, origin);
  }
  return json({ error: { code: 'not_found', message: 'Admin route not found' } }, 404, origin);
}

function groupSearchRows(rows: SearchRow[]) {
  const services = new Map<string, { service: Record<string, unknown>; offers: Record<string, unknown>[] }>();
  for (const row of rows) {
    const existing = services.get(row.service_id) ?? {
      service: {
        id: row.service_id,
        display_name: row.display_name,
        matched_term: row.matched_term,
        term_source: row.term_source,
        confidence: row.confidence,
      },
      offers: [],
    };
    existing.offers.push({
      id: row.offer_id,
      provider: { id: row.provider_brand_id, name: row.provider_name },
      location: row.provider_location_id ? {
        id: row.provider_location_id,
        name: row.provider_location_name,
        latitude: row.latitude,
        longitude: row.longitude,
      } : null,
      distance_meters: row.distance_meters,
      price: row.amount_minor === null ? null : {
        type: row.price_type,
        key: row.price_key,
        amount_minor: row.amount_minor,
        currency: row.currency,
        last_seen_at: row.price_last_seen_at,
      },
      source: row.source_url ? { url: row.source_url, last_seen_at: row.price_last_seen_at } : null,
    });
    services.set(row.service_id, existing);
  }
  return [...services.values()].map((entry) => ({ service: entry.service, offers: entry.offers }));
}

function parseBoundedInt(value: string | null, fallback: number, min: number, max: number): number {
  const parsed = value === null ? Number.NaN : Number(value);
  return Number.isInteger(parsed) ? Math.max(min, Math.min(max, parsed)) : fallback;
}

function parseCoordinate(value: string | null, min: number, max: number): number | null {
  if (value === null || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : Number.NaN;
}

function json(value: unknown, status: number, origin: string): Response {
  return new Response(JSON.stringify(value), { status, headers: { ...JSON_HEADERS, ...corsHeaders(origin) } });
}

function corsHeaders(origin: string): Record<string, string> {
  return { 'access-control-allow-origin': origin, 'access-control-allow-headers': 'authorization,content-type', 'access-control-allow-methods': 'GET,POST,OPTIONS' };
}
