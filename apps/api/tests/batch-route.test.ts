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

function streamedJsonRequest(url: string, body: string): Request {
  const bytes = new TextEncoder().encode(body);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
      controller.close();
    },
  });
  return new Request(url, { method: 'POST', body: stream, duplex: 'half' } as RequestInit);
}

describe('POST /api/v1/resolve-batch', () => {
  it('uses exact catalog segmentation for an undelimited prescription line', async () => {
    const call = vi.fn(async <T>(name: string, _body: Record<string, unknown>): Promise<T> => {
      if (name === 'api_segment_package_text') {
        return {
          status: 'segmented',
          segments: [
            { text: 'BH', method: 'catalog_exact' },
            { text: 'EGO', method: 'catalog_exact' },
          ],
        } as T;
      }
      return rpcPayload as T;
    });
    const rpc: RpcClient = { call: call as RpcClient['call'] };
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'BH EGO', objective: 'all_in_one' }),
    }), env);
    expect(response.status).toBe(200);
    expect(call).toHaveBeenCalledWith('api_segment_package_text', {
      p_text: 'BH EGO',
      p_domain_code: 'health_diagnostics',
      p_max_items: 30,
    });
    expect(call).toHaveBeenCalledWith('api_resolve_package', expect.objectContaining({ p_items: ['BH', 'EGO'] }));
  });

  it('keeps the original item when the catalog cannot prove a unique partition', async () => {
    const call = vi.fn(async <T>(name: string, _body: Record<string, unknown>): Promise<T> => {
      if (name === 'api_segment_package_text') {
        return {
          status: 'ambiguous',
          reason: 'multiple_exact_partitions',
          segments: [],
        } as T;
      }
      return rpcPayload as T;
    });
    const rpc: RpcClient = { call: call as RpcClient['call'] };
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'BH EGO', objective: 'all_in_one' }),
    }), env);
    expect(response.status).toBe(200);
    expect(call).toHaveBeenCalledWith('api_resolve_package', expect.objectContaining({ p_items: ['BH EGO'] }));
  });

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

  it('sanitizes source URLs in selected package offers', async () => {
    const payload = {
      ...rpcPayload,
      offers: [{
        item_index: 1,
        item_id: '00000000-0000-0000-0000-000000001103',
        offer_id: '00000000-0000-0000-0000-000000001104',
        provider_brand_id: '00000000-0000-0000-0000-000000001105',
        provider_name: 'Laboratorio',
        provider_location_id: '00000000-0000-0000-0000-000000001106',
        provider_location_name: 'Centro',
        latitude: 19,
        longitude: -98,
        distance_meters: 1,
        source_url: 'javascript:alert(1)',
        price_type: 'regular',
        price_key: 'default',
        amount_minor: 100,
        currency: 'MXN',
        price_last_seen_at: null,
        requires_quote: false,
      }],
    };
    const response = await createHandler({ rpc: rpcWith(payload) })(new Request('https://api.test/api/v1/resolve-batch', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ items: ['BH'], objective: 'all_in_one' }),
    }), env);
    const result = await response.json() as { solutions: Array<{ selected_offers: Array<{ source_url: unknown }> }> };
    expect(result.solutions[0].selected_offers[0].source_url).toBeNull();
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

  it('bounds streamed bodies even when content-length is absent', async () => {
    const rpc = rpcWith(rpcPayload);
    const handler = createHandler({ rpc });
    const oversized = JSON.stringify({ items: ['B'.repeat(20_000)] });
    const batchResponse = await handler(streamedJsonRequest('https://api.test/api/v1/resolve-batch', oversized), env);
    expect(batchResponse.status).toBe(413);
    const resolveResponse = await handler(streamedJsonRequest('https://api.test/api/v1/resolve', oversized), env);
    expect(resolveResponse.status).toBe(413);
    expect(rpc.call).not.toHaveBeenCalled();
  });
});
