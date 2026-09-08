import { describe, expect, it, vi } from 'vitest';
import { SupabaseRpcClient } from '../src/supabase.js';
import type { Env } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://project.supabase.co/',
  SUPABASE_ANON_KEY: 'anon-key',
  SUPABASE_SERVICE_ROLE_KEY: 'service-key',
  APP_ENV: 'test',
  SUPABASE_TIMEOUT_MS: '5000',
};

describe('Supabase RPC transport', () => {
  it('sends the selected credential and returns JSON', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(String(input)).toBe('https://project.supabase.co/rest/v1/rpc/api_search');
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'service-key', Authorization: 'Bearer service-key' }));
      expect(init?.signal).toBeInstanceOf(AbortSignal);
      expect(init?.redirect).toBe('error');
      expect(init?.cache).toBe('no-store');
      return new Response(JSON.stringify([{ service_id: 'service-1' }]), { status: 200 });
    });
    const result = await new SupabaseRpcClient(env, fetcher).call('api_search', { p_query: 'mastografia' });
    expect(result).toEqual([{ service_id: 'service-1' }]);
  });

  it('uses the service role for admin RPCs', async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'service-key' }));
      return new Response('{}', { status: 200 });
    });
    await new SupabaseRpcClient(env, fetcher).call('api_admin_dashboard', {}, { admin: true });
  });

  it('prefers publishable and secret keys when the project exposes new API keys', async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'secret-key', Authorization: 'Bearer secret-key' }));
      return new Response('{}', { status: 200 });
    });
    const newKeyEnv = { ...env, SUPABASE_PUBLISHABLE_KEY: 'publishable-key', SUPABASE_SECRET_KEY: 'secret-key' };
    await new SupabaseRpcClient(newKeyEnv, fetcher).call('api_search', {});
    const adminFetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'secret-key', Authorization: 'Bearer secret-key' }));
      return new Response('{}', { status: 200 });
    });
    await new SupabaseRpcClient(newKeyEnv, adminFetcher).call('api_admin_dashboard', {}, { admin: true });
  });

  it('preserves a provider JWT while using the anon key as the API key', async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'anon-key', Authorization: 'Bearer provider-jwt' }));
      return new Response('{}', { status: 200 });
    });
    await new SupabaseRpcClient(env, fetcher).call('api_provider_my_claims', {}, { accessToken: 'provider-jwt' });
  });

  it('fails closed instead of falling back to the service key for an empty user token', async () => {
    const fetcher = vi.fn(async () => new Response('{}', { status: 200 }));
    await expect(new SupabaseRpcClient(env, fetcher).call('api_provider_my_claims', {}, { accessToken: '' }))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('binds the runtime fetch when no fetcher is injected', async () => {
    const fetcher = vi.fn(function (this: unknown, _input: RequestInfo | URL, _init?: RequestInit) {
      expect(this).toBe(globalThis);
      return Promise.resolve(new Response('{}', { status: 200 }));
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      await new SupabaseRpcClient(env).call('api_search', { p_query: 'mastografia' });
      expect(fetcher).toHaveBeenCalledOnce();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('classifies an invalid upstream JSON response', async () => {
    const fetcher = vi.fn(async () => new Response('not-json', { status: 200 }));
    await expect(new SupabaseRpcClient(env, fetcher).call('api_search', { p_query: 'mastografia' }))
      .rejects.toMatchObject({ code: 'upstream_invalid_response', tag: 'UPSTREAM_PROTOCOL', rpcName: 'api_search' });
  });

  it('rejects an oversized or compressed upstream response before parsing', async () => {
    await expect(new SupabaseRpcClient(env, vi.fn(async () => new Response('x', {
      status: 200, headers: { 'content-length': '3000000' },
    }))).call('api_search', {})).rejects.toMatchObject({ code: 'upstream_invalid_response' });
    await expect(new SupabaseRpcClient(env, vi.fn(async () => new Response('{}', {
      status: 200, headers: { 'content-encoding': 'gzip' },
    }))).call('api_search', {})).rejects.toMatchObject({ code: 'upstream_invalid_response' });
  });

  it('fails closed when the Supabase URL is missing or invalid', async () => {
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: '' }).call('api_search', { p_query: 'mastografia' }))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: 'file:///tmp/supabase' }).call('api_search', { p_query: 'mastografia' }))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: 'http://remote.supabase.test' }).call('api_search', { p_query: 'mastografia' }))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, APP_ENV: 'staging', SUPABASE_URL: 'http://localhost:54321' }).call('api_search', {}))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: 'https://user:pass@project.supabase.co' }).call('api_search', {}))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: 'https://project.supabase.co?token=secret' }).call('api_search', {}))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    await expect(new SupabaseRpcClient({ ...env, SUPABASE_URL: 'https://project.supabase.co/internal' }).call('api_search', {}))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
  });

  it('rejects RPC names that could escape the fixed endpoint path', async () => {
    const fetcher = vi.fn(async () => new Response('{}', { status: 200 }));
    await expect(new SupabaseRpcClient(env, fetcher).call('api_search/../../auth/v1/user', {}))
      .rejects.toMatchObject({ code: 'service_not_configured', tag: 'CONFIGURATION' });
    expect(fetcher).not.toHaveBeenCalled();
  });
});
