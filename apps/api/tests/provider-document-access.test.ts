import { describe, expect, it, vi, afterEach } from 'vitest';
import { documentAccess } from '../src/provider-document-access.js';
import type { Env, RpcClient } from '../src/types.js';

const actor = { id: '00000000-0000-0000-0000-000000000099', aal: 'aal2' };
const key = 'provider-claims/00000000-0000-0000-0000-000000000001/00000000-0000-0000-0000-000000000002.pdf';
const env: Env = { SUPABASE_URL: 'https://example.supabase.co', SUPABASE_SECRET_KEY: 'server-secret', PROVIDER_DOCUMENTS_ENABLED: 'true', APP_ENV: 'test' };

afterEach(() => vi.unstubAllGlobals());

function rpc(value: unknown): RpcClient {
  return { call: vi.fn(async () => value) as RpcClient['call'] };
}

describe('private provider document access', () => {
  it('fails closed before touching Storage while the feature is disabled', async () => {
    const call = vi.fn();
    const result = await documentAccess('00000000-0000-0000-0000-000000000001', actor, { call: call as RpcClient['call'] }, { ...env, PROVIDER_DOCUMENTS_ENABLED: 'false' });
    expect(result).toEqual({ error: 'provider_documents_disabled' });
    expect(call).not.toHaveBeenCalled();
  });

  it('signs only a canonical clean object for a short download window', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(String(input)).toBe(`https://example.supabase.co/storage/v1/object/sign/${key}`);
      expect(init?.redirect).toBe('manual');
      expect((init?.headers as Record<string, string>).authorization).toBe('Bearer server-secret');
      expect(init?.body).toBe(JSON.stringify({ expiresIn: 60 }));
      return new Response(JSON.stringify({ signedURL: `/object/sign/${key}?token=short` }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    const result = await documentAccess('00000000-0000-0000-0000-000000000001', actor, rpc({ object_key: key }), env);
    expect(result.url).toBe(`https://example.supabase.co/storage/v1/object/sign/${key}?token=short&download=evidencia`);
  });

  it('rejects a path outside the claim prefix without an upstream request', async () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);
    const result = await documentAccess('00000000-0000-0000-0000-000000000001', actor, rpc({ object_key: 'provider-claims/../secret.pdf' }), env);
    expect(result).toEqual({ error: 'not_found' });
    expect(fetcher).not.toHaveBeenCalled();
  });
});
