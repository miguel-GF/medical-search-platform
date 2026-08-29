import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, RpcClient, SearchRow } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  ADMIN_USER_IDS: '00000000-0000-0000-0000-000000000099',
  API_VERSION: 'v1',
};

function rpcWith<T>(value: T): RpcClient {
  const call = vi.fn(async <U>(_name: string, _body: Record<string, unknown>): Promise<U> => value as unknown as U);
  return { call: call as RpcClient['call'] };
}

const row: SearchRow = {
  service_id: '00000000-0000-0000-0000-000000000001',
  display_name: 'Biometría hemática',
  matched_term: 'biometria hematica',
  term_source: 'name',
  confidence: 1,
  offer_id: '00000000-0000-0000-0000-000000000002',
  provider_brand_id: '00000000-0000-0000-0000-000000000003',
  provider_name: 'Laboratorio Ruiz',
  provider_location_id: null,
  provider_location_name: null,
  latitude: null,
  longitude: null,
  distance_meters: null,
  source_url: 'https://example.test/study',
  price_type: 'regular',
  price_key: 'default',
  amount_minor: 25000,
  currency: 'MXN',
  price_last_seen_at: '2026-08-25T00:00:00Z',
};

describe('Pruevia API', () => {
  const authenticateAdmin = async (request: Request) => request.headers.get('authorization') === 'Bearer user-token'
    ? { id: '00000000-0000-0000-0000-000000000099' }
    : null;

  it('returns a grouped search response', async () => {
    const rpc = rpcWith([row, { ...row, price_type: 'member', price_key: 'blue_card', amount_minor: 22000 }]);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/search?q=biometria'), env);
    expect(response.status).toBe(200);
    const payload = await response.json() as { results: Array<{ offers: Array<{ prices: unknown[] }> }> };
    expect(payload).toEqual(expect.objectContaining({
      query: 'biometria',
      results: [{
        service: expect.objectContaining({ id: row.service_id, display_name: row.display_name }),
        offers: [expect.objectContaining({ id: row.offer_id, price: expect.objectContaining({ amount_minor: 25000 }), prices: expect.any(Array) })],
      }],
    }));
    expect(payload.results[0].offers).toHaveLength(1);
    expect(payload.results[0].offers[0].prices).toHaveLength(2);
    expect(rpc.call).toHaveBeenCalledWith('api_search', expect.objectContaining({ p_query: 'biometria' }));
  });

  it('exposes deterministic resolution status and candidates', async () => {
    const resolution = {
      query: 'perfil tiroideo',
      normalized_query: 'perfil tiroideo',
      engine_version: 'clinical-resolver-v1',
      status: 'ambiguous',
      candidates: [
        { service_id: row.service_id, display_name: 'Perfil tiroideo básico', matched_term: 'perfil tiroideo', term_source: 'disambiguation', confidence: 0.92, resolution_status: 'ambiguous', match_method: 'disambiguation', explanation: {}, offers: [] },
      ],
    };
    const rpc = rpcWith(resolution);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'perfil tiroideo' }),
    }), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(resolution);
    expect(rpc.call).toHaveBeenCalledWith('api_resolve_search', expect.objectContaining({ p_query: 'perfil tiroideo' }));
  });

  it('rejects malformed resolution payloads', async () => {
    const handler = createHandler({ rpc: rpcWith({}) });
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: '{' }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: '---' }) }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: 'BH', latitude: 19 }) }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: 'BH', location_id: 'not-a-uuid' }) }), env)).status).toBe(400);
  });

  it('rejects incomplete coordinates and empty queries', async () => {
    const handler = createHandler({ rpc: rpcWith([]) });
    expect((await handler(new Request('https://api.test/api/v1/search?lat=19'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=biometria&lat=not-a-number&lng=-98.2'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q='), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=---'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=biometria&location_id=not-a-uuid'), env)).status).toBe(400);
  });

  it('protects admin routes and forwards a manual resolution', async () => {
    const rpc = rpcWith({ status: 'resolved' });
    const handler = createHandler({ rpc, authenticateAdmin });
    const denied = await handler(new Request('https://api.test/api/v1/admin/dashboard'), env);
    expect(denied.status).toBe(401);
    const allowed = await handler(new Request('https://api.test/api/v1/admin/normalization/00000000-0000-0000-0000-000000000001/resolve', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ selected_item_id: row.service_id, alias: 'BH' }),
    }), env);
    expect(allowed.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_update_alias', expect.objectContaining({ p_alias: 'BH', p_reviewer_user_id: '00000000-0000-0000-0000-000000000099' }), { admin: true });
  });

  it('forwards the admin catalog lookup', async () => {
    const rpc = rpcWith([{ item_id: row.service_id, display_name: 'Biometría hemática', service_type: 'lab_test', status: 'active' }]);
    const response = await createHandler({ rpc, authenticateAdmin })(new Request('https://api.test/api/v1/admin/catalog-items?q=biometria&limit=10', { headers: { authorization: 'Bearer user-token' } }), env);
    expect(response.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_catalog_items', { p_query: 'biometria', p_limit: 10 }, { admin: true });
  });

  it('authenticates Admin JWTs through Supabase and enforces the user allowlist', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(String(input)).toBe('https://example.supabase.co/auth/v1/user');
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'anon', Authorization: 'Bearer valid-user-token' }));
      return new Response(JSON.stringify({ id: '00000000-0000-0000-0000-000000000099' }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      const response = await createHandler({ rpc: rpcWith({}) })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: 'Bearer valid-user-token' },
      }), env);
      expect(response.status).toBe(200);
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
