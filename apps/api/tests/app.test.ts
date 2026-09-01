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
  const authenticateUser = async (request: Request) => request.headers.get('authorization') === 'Bearer provider-token'
    ? { id: '00000000-0000-0000-0000-000000000098', accessToken: 'provider-token' }
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

  it('protects provider routes and forwards a branch claim with the user token', async () => {
    const rpc = rpcWith({ claim_id: '00000000-0000-0000-0000-000000000010', status: 'pending' });
    const handler = createHandler({ rpc, authenticateUser });
    expect((await handler(new Request('https://api.test/api/v1/provider/claims'), env)).status).toBe(401);
    const response = await handler(new Request('https://api.test/api/v1/provider/claims', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({
        scope_type: 'location',
        provider_brand_id: row.provider_brand_id,
        provider_location_id: '00000000-0000-0000-0000-000000000011',
        organization_id: '00000000-0000-0000-0000-000000000012',
        requested_role: 'location_manager',
        relationship_type: 'operator',
        reason: 'I manage this branch',
      }),
    }), env);
    expect(response.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_create_claim', expect.objectContaining({
      p_scope_type: 'location',
      p_provider_location_id: '00000000-0000-0000-0000-000000000011',
      p_requested_role: 'location_manager',
    }), { accessToken: 'provider-token' });
  });

  it('validates provider documents and forwards memberships to the scoped RPCs', async () => {
    const rpc = rpcWith({ document_id: '00000000-0000-0000-0000-000000000013' });
    const handler = createHandler({ rpc, authenticateUser });
    const invalid = await handler(new Request('https://api.test/api/v1/provider/claims/not-a-uuid/documents', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: '{}',
    }), env);
    expect(invalid.status).toBe(400);
    const document = await handler(new Request('https://api.test/api/v1/provider/claims/00000000-0000-0000-0000-000000000010/documents', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ document_type: 'rfc', object_key: 'claims/10/rfc.pdf', sha256: 'a'.repeat(64) }),
    }), env);
    expect(document.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_add_claim_document', expect.objectContaining({ p_sha256: 'a'.repeat(64) }), { accessToken: 'provider-token' });
    const member = await handler(new Request('https://api.test/api/v1/provider/claims/00000000-0000-0000-0000-000000000010/members', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ user_id: '00000000-0000-0000-0000-000000000014', role: 'location_manager' }),
    }), env);
    expect(member.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_invite_member', expect.objectContaining({ p_role: 'location_manager' }), { accessToken: 'provider-token' });
  });

  it('submits only scoped provider profile proposals', async () => {
    const rpc = rpcWith({ request_id: '00000000-0000-0000-0000-000000000015', status: 'pending' });
    const handler = createHandler({ rpc, authenticateUser });
    const response = await handler(new Request('https://api.test/api/v1/provider/locations/00000000-0000-0000-0000-000000000011/profile', {
      method: 'PATCH',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ claim_id: '00000000-0000-0000-0000-000000000010', changes: { phone: '2220000000' } }),
    }), env);
    expect(response.status).toBe(202);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_submit_location_change', {
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_provider_location_id: '00000000-0000-0000-0000-000000000011',
      p_changes: { phone: '2220000000' },
    }, { accessToken: 'provider-token' });
  });

  it('lists and accepts memberships, while requiring a reason to revoke claims', async () => {
    const rpc = rpcWith({ membership_id: '00000000-0000-0000-0000-000000000016', status: 'active' });
    const handler = createHandler({ rpc, authenticateUser, authenticateAdmin });
    const memberships = await handler(new Request('https://api.test/api/v1/provider/memberships?status=invited', {
      headers: { authorization: 'Bearer provider-token' },
    }), env);
    expect(memberships.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_my_memberships', { p_status: 'invited', p_limit: 100 }, { accessToken: 'provider-token' });
    const accepted = await handler(new Request('https://api.test/api/v1/provider/memberships/00000000-0000-0000-0000-000000000016/accept', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token' },
    }), env);
    expect(accepted.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_provider_accept_membership', { p_membership_id: '00000000-0000-0000-0000-000000000016' }, { accessToken: 'provider-token' });
    const invalidRevoke = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/revoke', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ reason: '' }),
    }), env);
    expect(invalidRevoke.status).toBe(400);
    const revoked = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/revoke', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ reason: 'Relationship ended' }),
    }), env);
    expect(revoked.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_revoke_provider_claim', expect.objectContaining({
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
      p_reason: 'Relationship ended',
    }), { admin: true });
  });

  it('exposes admin claim review without exposing provider routes publicly', async () => {
    const rpc = rpcWith({ claim_id: '00000000-0000-0000-0000-000000000010', status: 'approved' });
    const handler = createHandler({ rpc, authenticateAdmin });
    const response = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/review', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ decision: 'approved', reason: 'Evidence accepted' }),
    }), env);
    expect(response.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_provider_claim', expect.objectContaining({
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_decision: 'approved',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
    }), { admin: true });
    const changeResponse = await handler(new Request('https://api.test/api/v1/admin/provider-change-requests/00000000-0000-0000-0000-000000000015/review', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ decision: 'approved' }),
    }), env);
    expect(changeResponse.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_provider_change', expect.objectContaining({
      p_request_id: '00000000-0000-0000-0000-000000000015',
      p_decision: 'approved',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
    }), { admin: true });
  });
});
