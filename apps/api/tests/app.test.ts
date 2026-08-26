import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, RpcClient, SearchRow } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  ADMIN_TOKEN: 'admin-secret',
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
  it('returns a grouped search response', async () => {
    const rpc = rpcWith([row]);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/search?q=biometria'), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      query: 'biometria',
      results: [{
        service: expect.objectContaining({ id: row.service_id, display_name: row.display_name }),
        offers: [expect.objectContaining({ id: row.offer_id, price: expect.objectContaining({ amount_minor: 25000 }) })],
      }],
    });
  });

  it('rejects incomplete coordinates and empty queries', async () => {
    const handler = createHandler({ rpc: rpcWith([]) });
    expect((await handler(new Request('https://api.test/api/v1/search?lat=19'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q='), env)).status).toBe(400);
  });

  it('protects admin routes and forwards a manual resolution', async () => {
    const rpc = rpcWith({ status: 'resolved' });
    const handler = createHandler({ rpc });
    const denied = await handler(new Request('https://api.test/api/v1/admin/dashboard'), env);
    expect(denied.status).toBe(401);
    const allowed = await handler(new Request('https://api.test/api/v1/admin/normalization/00000000-0000-0000-0000-000000000001/resolve', {
      method: 'POST',
      headers: { authorization: 'Bearer admin-secret', 'content-type': 'application/json' },
      body: JSON.stringify({ selected_item_id: row.service_id, alias: 'BH' }),
    }), env);
    expect(allowed.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_update_alias', expect.objectContaining({ p_alias: 'BH' }), { admin: true });
  });
});
