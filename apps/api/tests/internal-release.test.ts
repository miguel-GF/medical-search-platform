import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, RpcClient } from '../src/types.js';

const env: Env = { APP_ENV: 'test', SUPABASE_URL: 'https://example.supabase.co' };
const id = '00000000-0000-0000-0000-000000000099';
const routes = [
  ['POST', `/api/v1/provider/claims/${id}/documents`],
  ['GET', `/api/v1/admin/provider-claims/${id}/documents`],
  ['POST', `/api/v1/admin/provider-documents/${id}/review`],
];

describe('internal release document boundary', () => {
  it.each([
    undefined, null, {}, [],
    [{ id, factor_type: 'totp', status: 'unverified' }],
    [{ id, factor_type: 'phone', status: 'verified' }],
    [{ id: 'invalid', factor_type: 'totp', status: 'verified' }],
  ])('rejects aal2 without a current verified TOTP factor: %j', async (factors) => {
    const call = vi.fn();
    // Auth is mocked here: this tests response handling, not JWT signatures.
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ id, is_anonymous: false, factors }))));
    try {
      const token = `header.${btoa(JSON.stringify({ aal: 'aal2' }))}.signature`;
      const response = await createHandler({ rpc: { call } })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${token}` },
      }), { ...env, ADMIN_USER_IDS: id, SUPABASE_PUBLISHABLE_KEY: 'test-public-key' });
      expect(response.status).toBe(403);
      expect(call).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it.each([undefined, 'false', '', 'TRUE', '1'])('fails closed for flag %s without calling RPC', async (flag) => {
    const call = vi.fn();
    const handler = createHandler({
      rpc: { call } as RpcClient,
      authenticateAdmin: async () => ({ id, aal: 'aal2' }),
      authenticateUser: async () => ({ id, aal: 'aal2', accessToken: 'verified-by-test' }),
    });
    for (const [method, path] of routes) {
      const response = await handler(new Request(`https://api.test${path}`, { method }), {
        ...env, PROVIDER_DOCUMENTS_ENABLED: flag,
      });
      expect(response.status).toBe(503);
      expect(await response.json()).toMatchObject({ error: { code: 'provider_documents_disabled' } });
      expect(response.headers.get('cache-control')).toBe('no-store');
    }
    expect(call).not.toHaveBeenCalled();
  });

  it('still requires MFA before exposing the disabled feature response', async () => {
    const call = vi.fn();
    const handler = createHandler({
      rpc: { call } as RpcClient,
      authenticateAdmin: async () => ({ id, aal: 'aal1' }),
      authenticateUser: async () => ({ id, aal: 'aal1', accessToken: 'verified-by-test' }),
    });
    for (const [method, path] of routes) {
      const response = await handler(new Request(`https://api.test${path}`, { method }), env);
      expect(response.status).toBe(403);
    }
    expect(call).not.toHaveBeenCalled();
  });

  it('keeps catalog review available for an authenticated MFA administrator', async () => {
    const call = vi.fn().mockResolvedValue([]);
    const handler = createHandler({ rpc: { call }, authenticateAdmin: async () => ({ id, aal: 'aal2' }) });
    const response = await handler(new Request('https://api.test/api/v1/admin/catalog-items'), env);
    expect(response.status).toBe(200);
    expect(call).toHaveBeenCalledWith('api_admin_catalog_items', expect.any(Object), { admin: true });
  });
});
