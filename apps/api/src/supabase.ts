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

const MAX_RPC_RESPONSE_BYTES = 2 * 1024 * 1024;
const MAX_RPC_ERROR_BYTES = 16 * 1024;

export class SupabaseRpcClient implements RpcClient {
  private readonly fetcher: typeof fetch;

  constructor(private readonly env: Env, fetcher?: typeof fetch) {
    // Cloudflare's fetch implementation is method-bound. Keeping the injected
    // fetcher makes tests deterministic, while binding the global implementation
    // prevents `Illegal invocation` in Workers/local Wrangler runtimes.
    this.fetcher = fetcher ?? globalThis.fetch.bind(globalThis);
  }

  async call<T>(name: string, body: Record<string, unknown>, options: { admin?: boolean; accessToken?: string } = {}): Promise<T> {
    // RPC names are internal constants. Validate them at the transport
    // boundary anyway so a future call site can never turn a path segment into
    // traversal, a query string, or a host-relative URL.
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(name)) {
      throw new SupabaseConfigurationError('Supabase RPC name is invalid');
    }
    // Public API RPCs are Worker-only so their validation/rate limits cannot
    // be bypassed through PostgREST. Provider routes also use service-only
    // wrappers with the actor derived from a verified Supabase session.
    // accessToken is a transport option, not an authorization bypass; any
    // user-token call remains subject to the database role's RPC privileges.
    // Treat the presence of `accessToken` as an explicit request to use the
    // user-token lane. A truthiness check would silently fall back to the
    // service key for an empty/malformed token, turning a future call-site bug
    // into a privilege escalation. Fail closed before any request is sent.
    const userAccessToken = options.accessToken;
    if (userAccessToken !== undefined
      && (typeof userAccessToken !== 'string' || userAccessToken.length === 0
        || userAccessToken.length > 8_192 || /\s/.test(userAccessToken))) {
      throw new SupabaseConfigurationError('Supabase access token is invalid');
    }
    const key = userAccessToken !== undefined
      ? this.env.SUPABASE_PUBLISHABLE_KEY ?? this.env.SUPABASE_ANON_KEY
      : this.env.SUPABASE_SECRET_KEY ?? this.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key || !this.env.SUPABASE_URL) throw new SupabaseConfigurationError();
    let baseUrl: URL;
    try {
      baseUrl = new URL(this.env.SUPABASE_URL);
      const localDevelopment = baseUrl.protocol === 'http:'
        && (baseUrl.hostname === 'localhost' || baseUrl.hostname === '127.0.0.1' || baseUrl.hostname === '::1')
        && (this.env.APP_ENV === 'development' || this.env.APP_ENV === 'test');
      if (baseUrl.protocol !== 'https:' && !localDevelopment) throw new Error('https is required for Supabase');
      if (baseUrl.username || baseUrl.password || baseUrl.search || baseUrl.hash
        || (baseUrl.pathname !== '' && baseUrl.pathname !== '/')
        || (baseUrl.protocol === 'https:' && baseUrl.port && baseUrl.port !== '443')) {
        throw new Error('Supabase URL must be a clean origin');
      }
    } catch {
      throw new SupabaseConfigurationError('Supabase URL is invalid');
    }
    const authorization = userAccessToken ?? key;
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
        // Supabase RPCs must stay on the configured origin. Following a
        // redirect could disclose a privileged API key or provider JWT to an
        // unexpected host, while caching clinical responses creates a side
        // channel between users.
        redirect: 'error',
        cache: 'no-store',
        signal: controller.signal,
      });
      if (!response.ok) {
        let detail = '';
        try {
          detail = await readResponseText(response, MAX_RPC_ERROR_BYTES);
        } catch {
          detail = 'invalid upstream error body';
        }
        throw new SupabaseRpcError(name, response.status, detail.slice(0, 500));
      }
      try {
        return JSON.parse(await readResponseText(response, MAX_RPC_RESPONSE_BYTES)) as T;
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

async function readResponseText(response: Response, maximum: number): Promise<string> {
  const encoding = response.headers.get('content-encoding')?.trim().toLowerCase() ?? '';
  if (encoding !== '' && encoding !== 'identity') throw new Error('compressed upstream response rejected');
  const length = response.headers.get('content-length');
  if (length !== null && (!/^\d{1,10}$/.test(length) || Number(length) > maximum)) {
    throw new Error('upstream response exceeds limit');
  }
  const reader = response.body?.getReader();
  if (!reader) {
    const empty = new Uint8Array();
    if (length !== null && Number(length) !== 0) throw new Error('upstream response length mismatch');
    return new TextDecoder().decode(empty);
  }
  const bytes = new Uint8Array(maximum);
  let offset = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      const value = chunk.value;
      if (offset + value.byteLength > maximum) throw new Error('upstream response exceeds limit');
      bytes.set(value, offset);
      offset += value.byteLength;
    }
  } catch (error) {
    try { await reader.cancel(); } catch { /* best-effort connection cleanup */ }
    throw error;
  } finally {
    reader.releaseLock();
  }
  if (length !== null && offset !== Number(length)) throw new Error('upstream response length mismatch');
  return new TextDecoder().decode(bytes.subarray(0, offset));
}

function parseTimeout(value: string | undefined): number {
  const parsed = value === undefined ? 5000 : Number(value);
  return Number.isFinite(parsed) && parsed >= 250 && parsed <= 30000 ? Math.round(parsed) : 5000;
}
