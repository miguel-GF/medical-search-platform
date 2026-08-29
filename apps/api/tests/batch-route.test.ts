import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, RpcClient } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  ADMIN_USER_IDS: '',
  API_VERSION: 'v1',
};

const rpcPayload = {
  engine_version: 'clinical-resolver-v6',
  items: [{
    index: 1,
    input: 'BH',
    normalized_query: 'bh',
    status: 'resolved',
    candidates: [{
      service_id: '00000000-0000-0000-0000-000000001103',
      display_name: 'Biometría hemática',
      matched_term: 'BH',
      term_source: 'alias',
      confidence: 1,
      resolution_status: 'resolved',
      match_method: 'exact',
      explanation: {},
    }],
  }],
  offers: [],
};

function rpcWith(value: unknown): RpcClient {
  const call = vi.fn(async <T>(_name: string, _body: Record<string, unknown>): Promise<T> => value as T);
  return { call: call as RpcClient['call'] };
}

describe('POST /api/v1/resolve-batch', () => {
  it('forwards arbitrary study lists to the package RPC and returns the package contract', async () => {
    const rpc = rpcWith(rpcPayload);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ items: ['BH'], objective: 'all_in_one', max_solutions: 2 }),
    }), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(expect.objectContaining({
      package_status: 'ready',
      coverage_status: 'none',
      objective: 'all_in_one',
    }));
    expect(rpc.call).toHaveBeenCalledWith('api_resolve_package', expect.objectContaining({
      p_items: ['BH'],
      p_domain_code: 'health_diagnostics',
      p_limit: 10,
    }));
  });

  it('validates the batch body and coordinates before calling the database', async () => {
    const rpc = rpcWith(rpcPayload);
    const handler = createHandler({ rpc });
    expect((await handler(new Request('https://api.test/api/v1/resolve-batch', { method: 'POST', body: '{' }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST', body: JSON.stringify({ text: 'BH', items: ['EGO'] }),
    }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST', body: JSON.stringify({ text: 'BH', latitude: 19 }),
    }), env)).status).toBe(400);
    expect(rpc.call).not.toHaveBeenCalled();
  });
});
