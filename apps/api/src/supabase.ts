import type { Env, RpcClient } from './types.js';

export class SupabaseRpcClient implements RpcClient {
  constructor(
    private readonly env: Env,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async call<T>(name: string, body: Record<string, unknown>, options: { admin?: boolean } = {}): Promise<T> {
    const key = options.admin ? this.env.SUPABASE_SERVICE_ROLE_KEY : this.env.SUPABASE_ANON_KEY;
    if (!key) throw new Error('Supabase credential is not configured');
    const response = await this.fetcher(`${this.env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Supabase RPC ${name} failed (${response.status}): ${detail.slice(0, 500)}`);
    }
    return (await response.json()) as T;
  }
}
