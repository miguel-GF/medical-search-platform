import type { Env, RpcClient } from './types.js';

export class SupabaseRpcClient implements RpcClient {
  constructor(
    private readonly env: Env,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async call<T>(name: string, body: Record<string, unknown>, options: { admin?: boolean; accessToken?: string } = {}): Promise<T> {
    const key = options.admin ? this.env.SUPABASE_SERVICE_ROLE_KEY : this.env.SUPABASE_ANON_KEY;
    if (!key) throw new Error('Supabase credential is not configured');
    const authorization = options.accessToken ?? key;
    const timeoutMs = parseTimeout(this.env.SUPABASE_TIMEOUT_MS);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort('supabase_timeout'), timeoutMs);
    try {
      const response = await this.fetcher(`${this.env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${name}`, {
        method: 'POST',
        headers: {
          apikey: key,
          Authorization: `Bearer ${authorization}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      if (!response.ok) {
        const detail = await response.text();
        throw new Error(`Supabase RPC ${name} failed (${response.status}): ${detail.slice(0, 500)}`);
      }
      return (await response.json()) as T;
    } catch (error) {
      if (controller.signal.aborted) throw new Error(`Supabase RPC ${name} timed out after ${timeoutMs}ms`);
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
}

function parseTimeout(value: string | undefined): number {
  const parsed = value === undefined ? 5000 : Number(value);
  return Number.isFinite(parsed) && parsed >= 250 && parsed <= 30000 ? Math.round(parsed) : 5000;
}
