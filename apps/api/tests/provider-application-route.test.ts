import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, RpcClient } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  APP_ENV: 'test',
  PROVIDER_DOCUMENTS_ENABLED: 'false',
};
const provider = { id: '00000000-0000-0000-0000-000000000098', aal: 'aal2' as const };
const admin = { id: '00000000-0000-0000-0000-000000000099', aal: 'aal2' as const };

function setup(value: unknown = { items: [] }, providerAal: 'aal1' | 'aal2' = 'aal2') {
  const call = vi.fn(async <T>(_name: string, _body: Record<string, unknown>): Promise<T> => value as T);
  const rpc: RpcClient = { call: call as RpcClient['call'] };
  const handler = createHandler({
    rpc,
    authenticateUser: async (request) => request.headers.get('authorization') === 'Bearer provider' ? { ...provider, aal: providerAal } : null,
    authenticateAdmin: async (request) => request.headers.get('authorization') === 'Bearer admin' ? admin : null,
  });
  return { call, handler };
}

describe('provider application routes', () => {
  it('exposes only the public intake configuration without authenticating', async () => {
    const { call, handler } = setup({ enabled: false, notice_version: 'providers-test-v1' });
    const response = await handler(new Request('https://api.test/api/v1/provider-intake'), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ enabled: false, notice_version: 'providers-test-v1' });
    expect(call).toHaveBeenCalledWith('api_provider_intake_info', {}, { admin: true });
  });

  it('rejects malformed privacy requests before the service boundary', async () => {
    const { call, handler } = setup();
    const response = await handler(new Request('https://api.test/api/v1/provider/applications/privacy_request', {
      method: 'POST', headers: { authorization: 'Bearer provider', 'content-type': 'application/json' }, body: JSON.stringify({ kind: 'unknown', message: '' }),
    }), env);
    expect(response.status).toBe(400);
    expect(call).not.toHaveBeenCalled();
  });

  it('passes provider list requests as non-admin and requires stepped-up auth', async () => {
    const { call, handler } = setup({ items: [{ id: 'app' }] });
    const response = await handler(new Request('https://api.test/api/v1/provider/applications?days=15', { headers: { authorization: 'Bearer provider' } }), env);
    expect(response.status).toBe(200);
    expect(call).toHaveBeenCalledWith('api_server_provider_application', expect.objectContaining({ p_is_admin: false, p_action: 'list' }), { admin: true });

    const { handler: aal1Handler, call: aal1Call } = setup(undefined, 'aal1');
    const denied = await aal1Handler(new Request('https://api.test/api/v1/provider/applications', { headers: { authorization: 'Bearer provider' } }), env);
    expect(denied.status).toBe(403);
    expect(aal1Call).not.toHaveBeenCalled();
  });

  it('routes admin decisions through the server-only application RPC', async () => {
    const { call, handler } = setup({ id: '00000000-0000-0000-0000-000000000010', status: 'approved', revision: 4 });
    const id = '00000000-0000-0000-0000-000000000010';
    const response = await handler(new Request(`https://api.test/api/v1/admin/provider-applications/${id}/approve`, {
      method: 'POST', headers: { authorization: 'Bearer admin', 'content-type': 'application/json' },
      body: JSON.stringify({ revision: 3, scope_confirmed: true, message: 'Alcance y representación confirmados.' }),
    }), env);
    expect(response.status).toBe(200);
    expect(call).toHaveBeenCalledWith('api_server_provider_application', expect.objectContaining({ p_actor_user_id: admin.id, p_is_admin: true, p_action: 'approve', p_id: id }), { admin: true });
  });
});
