import { describe, expect, it, vi } from 'vitest';
import { SupabaseRpcClient } from '../src/supabase.js';
import type { Env } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://project.supabase.co/',
  SUPABASE_ANON_KEY: 'anon-key',
  SUPABASE_SERVICE_ROLE_KEY: 'service-key',
  SUPABASE_TIMEOUT_MS: '5000',
};

describe('Supabase RPC transport', () => {
  it('sends the selected credential and returns JSON', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(String(input)).toBe('https://project.supabase.co/rest/v1/rpc/api_search');
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'anon-key', Authorization: 'Bearer anon-key' }));
      expect(init?.signal).toBeInstanceOf(AbortSignal);
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
});
