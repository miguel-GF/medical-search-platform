import type { Env, RpcClient } from './types.js';

/**
 * Errors crossing the Supabase boundary are deliberately typed.  The public
 * API can expose a safe, localized explanation while the log keeps a stable
 * machine-readable tag for operations.
 */
export class SupabaseConfigurationError extends Error {
  readonly code = 'service_not_configured';
  readonly tag = 'CONFIGURATION';
  readonly retryable = false;

  constructor(message = 'Supabase credentials are not configured') {
    super(message);
    this.name = 'SupabaseConfigurationError';
  }
}

export class SupabaseTimeoutError extends Error {
  readonly code = 'upstream_timeout';
  readonly tag = 'UPSTREAM_TIMEOUT';
  readonly retryable = true;
  readonly timeoutMs: number;

  constructor(readonly rpcName: string, timeoutMs: number) {
    super(`Supabase RPC ${rpcName} timed out after ${timeoutMs}ms`);
    this.name = 'SupabaseTimeoutError';
    this.timeoutMs = timeoutMs;
  }
}

export class SupabaseRpcError extends Error {
  readonly code = 'upstream_rpc_error';
  readonly tag = 'UPSTREAM_RPC';
  readonly retryable: boolean;

  constructor(readonly rpcName: string, readonly status: number, detail: string) {
    // Keep details in the server-side error only.  It can contain database
    // internals and must never be sent to a patient.
    super(`Supabase RPC ${rpcName} failed (${status}): ${detail}`);
    this.name = 'SupabaseRpcError';
    this.retryable = status === 408 || status === 425 || status === 429 || status >= 500;
  }
}

export class SupabaseResponseError extends Error {
  readonly code = 'upstream_invalid_response';
  readonly tag = 'UPSTREAM_PROTOCOL';
  readonly retryable = true;

  constructor(readonly rpcName: string) {
    super(`Supabase RPC ${rpcName} returned invalid JSON`);
    this.name = 'SupabaseResponseError';
  }
}

export class SupabaseRpcClient implements RpcClient {
  private readonly fetcher: typeof fetch;

  constructor(private readonly env: Env, fetcher?: typeof fetch) {
    // Cloudflare's fetch implementation is method-bound. Keeping the injected
    // fetcher makes tests deterministic, while binding the global implementation
    // prevents `Illegal invocation` in Workers/local Wrangler runtimes.
    this.fetcher = fetcher ?? globalThis.fetch.bind(globalThis);
  }

  async call<T>(name: string, body: Record<string, unknown>, options: { admin?: boolean; accessToken?: string } = {}): Promise<T> {
    const key = options.admin
      ? this.env.SUPABASE_SECRET_KEY ?? this.env.SUPABASE_SERVICE_ROLE_KEY
      : this.env.SUPABASE_PUBLISHABLE_KEY ?? this.env.SUPABASE_ANON_KEY;
    if (!key || !this.env.SUPABASE_URL) throw new SupabaseConfigurationError();
    let baseUrl: URL;
    try {
      baseUrl = new URL(this.env.SUPABASE_URL);
      const localDevelopment = baseUrl.protocol === 'http:'
        && (baseUrl.hostname === 'localhost' || baseUrl.hostname === '127.0.0.1' || baseUrl.hostname === '::1')
        && this.env.APP_ENV !== 'production';
      if (baseUrl.protocol !== 'https:' && !localDevelopment) throw new Error('https is required for Supabase');
    } catch {
      throw new SupabaseConfigurationError('Supabase URL is invalid');
    }
    const authorization = options.accessToken ?? key;
    const timeoutMs = parseTimeout(this.env.SUPABASE_TIMEOUT_MS);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort('supabase_timeout'), timeoutMs);
    try {
      const response = await this.fetcher(`${baseUrl.toString().replace(/\/$/, '')}/rest/v1/rpc/${name}`, {
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
        throw new SupabaseRpcError(name, response.status, detail.slice(0, 500));
      }
      try {
        return (await response.json()) as T;
      } catch {
        throw new SupabaseResponseError(name);
      }
    } catch (error) {
      if (controller.signal.aborted) throw new SupabaseTimeoutError(name, timeoutMs);
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
