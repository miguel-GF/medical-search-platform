import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import { SupabaseConfigurationError, SupabaseTimeoutError } from '../src/supabase.js';
import type { Env, RpcClient, SearchRow } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  APP_ENV: 'test',
  PROVIDER_DOCUMENTS_ENABLED: 'true',
  ADMIN_USER_IDS: '00000000-0000-0000-0000-000000000099',
  API_VERSION: 'v1',
};

function rpcWith<T>(value: T): RpcClient {
  const call = vi.fn(async <U>(_name: string, _body: Record<string, unknown>): Promise<U> => value as unknown as U);
  return { call: call as RpcClient['call'] };
}

function streamedJsonRequest(url: string, body: string, authorization = 'Bearer user-token'): Request {
  const bytes = new TextEncoder().encode(body);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
      controller.close();
    },
  });
  return new Request(url, {
    method: 'POST',
    headers: { authorization, 'content-type': 'application/json' },
    body: stream,
    duplex: 'half',
  } as RequestInit);
}

const row: SearchRow = {
  service_id: '00000000-0000-0000-0000-000000000001',
  display_name: 'Biometría hemática',
  matched_term: 'biometria hematica',
  term_source: 'name',
  confidence: 1,
  offer_id: '00000000-0000-0000-0000-000000000002',
  provider_brand_id: '00000000-0000-0000-0000-000000000003',
  provider_name: 'Laboratorio Ruiz',
  provider_location_id: null,
  provider_location_name: null,
  latitude: null,
  longitude: null,
  distance_meters: null,
  source_url: 'https://example.test/study',
  price_type: 'regular',
  price_key: 'default',
  amount_minor: 25000,
  currency: 'MXN',
  price_last_seen_at: '2026-08-25T00:00:00Z',
};

describe('Pruevia API', () => {
  const authenticateAdmin = async (request: Request) => request.headers.get('authorization') === 'Bearer user-token'
    ? { id: '00000000-0000-0000-0000-000000000099', aal: 'aal2' as const }
    : null;
  const authenticateUser = async (request: Request) => request.headers.get('authorization') === 'Bearer provider-token'
    ? { id: '00000000-0000-0000-0000-000000000098', aal: 'aal2' as const }
    : null;

  it('returns a grouped search response', async () => {
    const rpc = rpcWith([row, { ...row, price_type: 'member', price_key: 'blue_card', amount_minor: 22000 }]);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/search?q=biometria'), env);
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toBe('no-store');
    const payload = await response.json() as { results: Array<{ offers: Array<{ prices: unknown[] }> }> };
    expect(payload).toEqual(expect.objectContaining({
      query: 'biometria',
      results: [{
        service: expect.objectContaining({ id: row.service_id, display_name: row.display_name }),
        offers: [expect.objectContaining({ id: row.offer_id, price: expect.objectContaining({ amount_minor: 25000 }), prices: expect.any(Array) })],
      }],
    }));
    expect(payload.results[0].offers).toHaveLength(1);
    expect(payload.results[0].offers[0].prices).toHaveLength(2);
    expect(rpc.call).toHaveBeenCalledWith('api_search', expect.objectContaining({ p_query: 'biometria' }));
  });

  it('drops non-http source URLs from public offers', async () => {
    const response = await createHandler({ rpc: rpcWith([{ ...row, source_url: 'javascript:alert(1)' }]) })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    const payload = await response.json() as { results: Array<{ offers: Array<{ source: unknown }> }> };
    expect(payload.results[0].offers[0].source).toBeNull();
  });

  it('removes query strings and fragments from public source URLs', async () => {
    const response = await createHandler({ rpc: rpcWith([{ ...row, source_url: 'https://example.test/study?token=secret#private' }]) })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    const payload = await response.json() as { results: Array<{ offers: Array<{ source: { url: string } | null }> }> };
    expect(payload.results[0].offers[0].source).toEqual({ url: 'https://example.test/study', last_seen_at: row.price_last_seen_at });
  });

  it('does not expose insecure or alternate-port source URLs', async () => {
    const response = await createHandler({ rpc: rpcWith([{ ...row, source_url: 'http://provider.example.test:8080/price?token=secret' }]) })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    const payload = await response.json() as { results: Array<{ offers: Array<{ source: unknown }> }> };
    expect(payload.results[0].offers[0].source).toBeNull();
  });

  it('drops malformed search rows and bounds catalog text', async () => {
    const malformed = { ...row, display_name: 'x'.repeat(10_000) };
    const response = await createHandler({ rpc: rpcWith([null, malformed] as unknown as SearchRow[]) })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    expect(response.status).toBe(200);
    const payload = await response.json() as { results: Array<{ service: { display_name: string } }> };
    expect(payload.results).toHaveLength(1);
    expect(payload.results[0].service.display_name).toHaveLength(500);
  });

  it('fails closed in production when the native rate limiter is unavailable', async () => {
    const limiter = { limit: vi.fn(async () => { throw new Error('binding unavailable'); }) };
    const rpc = rpcWith([]);
    const response = await createHandler({ rpc })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      { ...env, APP_ENV: 'production', ALLOWED_ORIGIN: 'https://admin.example.test', PUBLIC_RATE_LIMITER: limiter },
    );
    expect(response.status).toBe(503);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('fails closed in production when a required limiter binding is missing', async () => {
    const rpc = rpcWith([]);
    const response = await createHandler({ rpc })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      { ...env, APP_ENV: 'production', ALLOWED_ORIGIN: 'https://admin.example.test' },
    );
    expect(response.status).toBe(503);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('sanitizes source and website URLs in public detail payloads', async () => {
    const response = await createHandler({ rpc: rpcWith({ website_url: 'javascript:alert(1)', offers: [{ source_url: 'data:text/html,x' }] }) })(
      new Request('https://api.test/api/v1/providers/00000000-0000-0000-0000-000000000001'),
      env,
    );
    expect(await response.json()).toEqual({ website_url: null, offers: [{ source_url: null }] });
  });

  it('bounds recursive public payload sanitization for hostile deep JSON', async () => {
    let nested: Record<string, unknown> = { href: 'https://example.test/private?token=secret' };
    for (let index = 0; index < 100; index += 1) nested = { nested };
    const response = await createHandler({ rpc: rpcWith(nested) })(
      new Request('https://api.test/api/v1/providers/00000000-0000-0000-0000-000000000001'),
      env,
    );
    expect(response.status).toBe(200);
    const payload = await response.json() as Record<string, unknown>;
    expect(JSON.stringify(payload)).not.toContain('secret');
  });

  it('rejects oversized public payload collections before recursive copying', async () => {
    const response = await createHandler({ rpc: rpcWith({ offers: Array.from({ length: 1001 }, () => ({ id: 'x' })) }) })(
      new Request('https://api.test/api/v1/providers/00000000-0000-0000-0000-000000000001'),
      env,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ offers: null });
  });

  it('bounds oversized public payload strings before returning them', async () => {
    const response = await createHandler({ rpc: rpcWith({ detail: 'x'.repeat(70 * 1024) }) })(
      new Request('https://api.test/api/v1/providers/00000000-0000-0000-0000-000000000001'),
      env,
    );
    expect(response.status).toBe(200);
    const payload = await response.json() as { detail: string };
    expect(payload.detail).toHaveLength(64 * 1024);
  });

  it('redacts credential-shaped keys from public and admin payload copies', async () => {
    const response = await createHandler({ rpc: rpcWith({
      api_token: 'do-not-expose',
      nested: { authorization: 'Bearer do-not-expose', visible: 'ok' },
    }) })(
      new Request('https://api.test/api/v1/providers/00000000-0000-0000-0000-000000000001'),
      env,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      api_token: '[REDACTED]',
      nested: { authorization: '[REDACTED]', visible: 'ok' },
    });
  });

  it('stops public traffic before an upstream call when the native limiter rejects it', async () => {
    const rpc = rpcWith([]);
    const limiter = { limit: vi.fn(async () => ({ success: false })) };
    const response = await createHandler({ rpc })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      { ...env, PUBLIC_RATE_LIMITER: limiter },
    );
    expect(response.status).toBe(429);
    expect(response.headers.get('retry-after')).toBe('60');
    expect(limiter.limit).toHaveBeenCalledOnce();
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('does not persist unlimited public review captures when the capture limiter rejects them', async () => {
    const resolution = {
      query: 'perfil tiroideo',
      normalized_query: 'perfil tiroideo',
      engine_version: 'clinical-resolver-v6',
      status: 'ambiguous',
      candidates: [],
    };
    const call = vi.fn(async <T>(name: string): Promise<T> =>
      (name === 'api_resolve_search' ? resolution : []) as T,
    );
    const reviewLimiter = { limit: vi.fn(async () => ({ success: false })) };
    const response = await createHandler({ rpc: { call: call as RpcClient['call'] } })(
      new Request('https://api.test/api/v1/search?q=perfil%20tiroideo'),
      { ...env, REVIEW_CAPTURE_RATE_LIMITER: reviewLimiter },
    );
    expect(response.status).toBe(200);
    expect(reviewLimiter.limit).toHaveBeenCalledOnce();
    expect(call).not.toHaveBeenCalledWith('api_record_resolution_review', expect.anything(), expect.anything());
  });

  it('also bounds public review captures across clients', async () => {
    const resolution = {
      query: 'perfil tiroideo',
      normalized_query: 'perfil tiroideo',
      engine_version: 'clinical-resolver-v6',
      status: 'ambiguous',
      candidates: [],
    };
    const call = vi.fn(async <T>(name: string): Promise<T> =>
      (name === 'api_resolve_search' ? resolution : []) as T,
    );
    const reviewLimiter = { limit: vi.fn(async ({ key }: { key: string }) => ({ success: !key.endsWith(':global') })) };
    const response = await createHandler({ rpc: { call: call as RpcClient['call'] } })(
      new Request('https://api.test/api/v1/search?q=perfil%20tiroideo'),
      { ...env, REVIEW_CAPTURE_RATE_LIMITER: reviewLimiter },
    );
    expect(response.status).toBe(200);
    expect(reviewLimiter.limit).toHaveBeenCalledTimes(2);
    expect(reviewLimiter.limit).toHaveBeenLastCalledWith({ key: 'review_capture:global' });
    expect(call).not.toHaveBeenCalledWith('api_record_resolution_review', expect.anything(), expect.anything());
  });

  it('fails closed in production when the allowed origin is not explicit HTTPS', async () => {
    const rpc = rpcWith([]);
    const response = await createHandler({ rpc })(
      new Request('https://api.test/health'),
      { ...env, APP_ENV: 'production', ALLOWED_ORIGIN: '*' },
    );
    expect(response.status).toBe(503);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('fails closed when APP_ENV is omitted or unknown', async () => {
    const rpc = rpcWith([]);
    const missing = await createHandler({ rpc })(
      new Request('https://api.test/health'),
      { ...env, APP_ENV: undefined, ALLOWED_ORIGIN: undefined },
    );
    expect(missing.status).toBe(503);
    const unknown = await createHandler({ rpc })(
      new Request('https://api.test/health'),
      { ...env, APP_ENV: 'staging', ALLOWED_ORIGIN: undefined },
    );
    expect(unknown.status).toBe(503);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('does not send a bearer token to an insecure Supabase auth endpoint', async () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);
    try {
      const response = await createHandler({ rpc: rpcWith([]) })(
        new Request('https://api.test/api/v1/admin/dashboard', { headers: { authorization: 'Bearer user-token' } }),
        { ...env, SUPABASE_URL: 'http://remote.supabase.test' },
      );
      expect(response.status).toBe(401);
      expect(fetcher).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('does not send a bearer token when Supabase URL contains credentials or query data', async () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);
    try {
      for (const SUPABASE_URL of ['https://user:pass@project.supabase.co', 'https://project.supabase.co?token=secret', 'https://project.supabase.co/internal']) {
        const response = await createHandler({ rpc: rpcWith([]) })(
          new Request('https://api.test/api/v1/admin/dashboard', { headers: { authorization: 'Bearer user-token' } }),
          { ...env, SUPABASE_URL },
        );
        expect(response.status).toBe(401);
      }
      expect(fetcher).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('rejects an oversized bearer token before contacting Supabase', async () => {
    const fetcher = vi.fn();
    vi.stubGlobal('fetch', fetcher);
    try {
      const response = await createHandler({ rpc: rpcWith([]) })(
        new Request('https://api.test/api/v1/admin/dashboard', { headers: { authorization: `Bearer ${'x'.repeat(8_193)}` } }),
        env,
      );
      expect(response.status).toBe(401);
      expect(fetcher).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('does not render an empty brand fallback beside a concrete branch offer', async () => {
    const branch = {
      ...row,
      provider_location_id: '00000000-0000-0000-0000-000000000011',
      provider_location_name: 'Puebla Municipio Libre',
      amount_minor: 12000,
    };
    const brandFallback = {
      ...row,
      amount_minor: null,
      price_type: null,
      price_key: null,
    };
    const response = await createHandler({ rpc: rpcWith([branch, brandFallback]) })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    const payload = await response.json() as { results: Array<{ offers: unknown[] }> };
    expect(payload.results[0].offers).toHaveLength(1);
  });

  it('shows recognized services without current offers in public search', async () => {
    const resolution = {
      query: 'perfil tiroideo',
      normalized_query: 'perfil tiroideo',
      engine_version: 'clinical-resolver-v6',
      status: 'ambiguous',
      candidates: [
        {
          service_id: row.service_id,
          display_name: 'Perfil tiroideo bÃ¡sico',
          matched_term: 'perfil tiroideo bÃ¡sico',
          term_source: 'name',
          provider_brand_id: null,
          confidence: 1,
          resolution_status: 'ambiguous',
          match_method: 'disambiguation',
          explanation: {},
          offers: [],
        },
      ],
    };
    const call = vi.fn(async <T>(name: string): Promise<T> =>
      (name === 'api_search' ? [] : resolution) as T,
    );
    const response = await createHandler({ rpc: { call: call as RpcClient['call'] } })(
      new Request('https://api.test/api/v1/search?q=perfil%20tiroideo'),
      env,
    );
    const payload = await response.json() as { results: Array<{ service: { display_name: string; resolution_status: string }; offers: unknown[] }> };
    expect(payload.results).toEqual([
      { service: expect.objectContaining({ display_name: 'Perfil tiroideo bÃ¡sico', resolution_status: 'ambiguous' }), offers: [] },
    ]);
    expect(call).toHaveBeenNthCalledWith(2, 'api_resolve_search', expect.objectContaining({ p_query: 'perfil tiroideo' }));
    expect(call).toHaveBeenNthCalledWith(3, 'api_record_resolution_review', expect.objectContaining({
      p_input_type: 'search',
      p_payload: resolution,
    }), { admin: true });
  });

  it('does not expose offers for an unresolved public candidate', async () => {
    const resolution = {
      query: 'biometria',
      normalized_query: 'biometria',
      engine_version: 'clinical-resolver-v6',
      status: 'ambiguous',
      candidates: [{
        service_id: row.service_id,
        display_name: row.display_name,
        matched_term: row.matched_term,
        term_source: row.term_source,
        provider_brand_id: row.provider_brand_id,
        confidence: 0.52,
        resolution_status: 'ambiguous',
        match_method: 'word_fuzzy',
        explanation: {},
        offers: [row],
      }],
    };
    const call = vi.fn(async <T>(name: string): Promise<T> =>
      (name === 'api_search' ? [row] : resolution) as T,
    );
    const response = await createHandler({ rpc: { call: call as RpcClient['call'] } })(
      new Request('https://api.test/api/v1/search?q=biometria'),
      env,
    );
    const payload = await response.json() as { results: Array<{ offers: unknown[] }> };
    expect(payload.results[0].offers).toEqual([]);
  });

  it('allowlists public resolution fields and strips resolver evidence', async () => {
    const resolution = {
      query: 'biometria',
      normalized_query: 'biometria',
      engine_version: 'clinical-resolver-v6',
      status: 'ambiguous',
      internal_trace: 'should-not-leave-the-api',
      candidates: [{
        ...row,
        service_id: row.service_id,
        display_name: row.display_name,
        matched_term: row.matched_term,
        term_source: row.term_source,
        provider_brand_id: row.provider_brand_id,
        confidence: 0.52,
        resolution_status: 'ambiguous',
        match_method: 'word_fuzzy',
        explanation: { raw_payload: 'sensitive resolver evidence' },
        offers: [row],
        raw_record: { patient_name: 'should-not-leave-the-api' },
      }],
    };
    const response = await createHandler({ rpc: rpcWith(resolution) })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'biometria' }),
    }), env);
    const payload = await response.json() as Record<string, unknown>;
    expect(payload).not.toHaveProperty('internal_trace');
    expect(payload).toEqual(expect.objectContaining({ status: 'ambiguous', candidates: [{
      service_id: row.service_id,
      display_name: row.display_name,
      matched_term: row.matched_term,
      term_source: row.term_source,
      provider_brand_id: row.provider_brand_id,
      confidence: 0.52,
      resolution_status: 'ambiguous',
      match_method: 'word_fuzzy',
      explanation: {},
      offers: [],
    }] }));
    expect(JSON.stringify(payload)).not.toContain('sensitive resolver evidence');
    expect(JSON.stringify(payload)).not.toContain('patient_name');
  });

  it('exposes deterministic resolution status and candidates', async () => {
    const resolution = {
      query: 'perfil tiroideo',
      normalized_query: 'perfil tiroideo',
      engine_version: 'clinical-resolver-v1',
      status: 'ambiguous',
      candidates: [
        { service_id: row.service_id, display_name: 'Perfil tiroideo básico', matched_term: 'perfil tiroideo', term_source: 'disambiguation', provider_brand_id: null, confidence: 0.92, resolution_status: 'ambiguous', match_method: 'disambiguation', explanation: {}, offers: [] },
      ],
    };
    const rpc = rpcWith(resolution);
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'perfil tiroideo' }),
    }), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(resolution);
    expect(rpc.call).toHaveBeenCalledWith('api_resolve_search', expect.objectContaining({ p_query: 'perfil tiroideo' }));
  });

  it('fails closed on malformed resolver candidates instead of throwing', async () => {
    const response = await createHandler({ rpc: rpcWith({
      status: 'resolved',
      candidates: [null, { service_id: row.service_id, offers: 'not-an-array' }],
    }) })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'biometria' }),
    }), env);
    expect(response.status).toBe(200);
    const payload = await response.json() as { candidates: Array<{ offers: unknown[] }> };
    expect(payload.candidates).toHaveLength(1);
    expect(payload.candidates[0].offers).toEqual([]);
  });

  it('rejects malformed resolution payloads', async () => {
    const handler = createHandler({ rpc: rpcWith({}) });
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: '{' }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: '---' }) }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: 'BH', latitude: 19 }) }), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/resolve', { method: 'POST', body: JSON.stringify({ text: 'BH', location_id: 'not-a-uuid' }) }), env)).status).toBe(400);
  });

  it('rejects compressed request bodies before parsing them', async () => {
    const rpc = rpcWith({});
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-encoding': 'gzip' },
      body: JSON.stringify({ text: 'biometria' }),
    }), env);
    expect(response.status).toBe(415);
    expect(await response.json()).toEqual({ error: { code: 'unsupported_content_encoding', message: 'Compressed request bodies are not supported' } });
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('rejects a body made of excessive tiny chunks before parsing it', async () => {
    const rpc = rpcWith({});
    const chunks = 4_097;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        for (let index = 0; index < chunks; index += 1) controller.enqueue(new Uint8Array([0x20]));
        controller.close();
      },
    });
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: stream,
      duplex: 'half',
    } as RequestInit), env);
    expect(response.status).toBe(413);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('rejects malformed or ambiguous content lengths before parsing JSON', async () => {
    const rpc = rpcWith([]);
    const malformed = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': '12,12' },
      body: JSON.stringify({ text: 'BH' }),
    }), env);
    expect(malformed.status).toBe(413);
    const oversized = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': '9999999999' },
      body: JSON.stringify({ text: 'BH' }),
    }), env);
    expect(oversized.status).toBe(413);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('rejects incomplete coordinates and empty queries', async () => {
    const handler = createHandler({ rpc: rpcWith([]) });
    expect((await handler(new Request('https://api.test/api/v1/search?lat=19'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=biometria&lat=not-a-number&lng=-98.2'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q='), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=---'), env)).status).toBe(400);
    expect((await handler(new Request('https://api.test/api/v1/search?q=biometria&location_id=not-a-uuid'), env)).status).toBe(400);
  });

  it('returns a safe, tagged Spanish error when the upstream is not configured', async () => {
    const rpc: RpcClient = { call: vi.fn(async () => { throw new SupabaseConfigurationError(); }) };
    const response = await createHandler({ rpc })(
      new Request('https://api.test/api/v1/search?q=mastografia'),
      env,
    );
    expect(response.status).toBe(503);
    const payload = await response.json() as { error: Record<string, unknown> };
    expect(payload.error).toEqual(expect.objectContaining({
      code: 'service_not_configured',
      type: 'configuration',
      error_tag: 'API.SERVER.CONFIGURATION',
      severity: 'high',
      retryable: false,
      operation: 'individual_search',
      message: 'El servicio de búsqueda no está configurado. Inténtalo más tarde.',
    }));
    expect(payload.error.request_id).toEqual(expect.any(String));
    expect(response.headers.get('x-request-id')).toBe(payload.error.request_id);
  });

  it('classifies upstream timeouts without leaking database details', async () => {
    const rpc: RpcClient = { call: vi.fn(async () => { throw new SupabaseTimeoutError('api_search', 5000); }) };
    const response = await createHandler({ rpc })(
      new Request('https://api.test/api/v1/search?q=mastografia'),
      env,
    );
    expect(response.status).toBe(504);
    const body = await response.text();
    expect(JSON.parse(body)).toEqual(expect.objectContaining({
      error: expect.objectContaining({
        code: 'upstream_timeout',
        type: 'timeout',
        error_tag: 'API.SERVER.TIMEOUT',
        retryable: true,
      }),
    }));
    expect(body).not.toContain('api_search');
  });

  it('protects admin routes and forwards a manual resolution', async () => {
    const rpc = rpcWith({ status: 'resolved' });
    const handler = createHandler({ rpc, authenticateAdmin });
    const denied = await handler(new Request('https://api.test/api/v1/admin/dashboard'), env);
    expect(denied.status).toBe(401);
    const allowed = await handler(new Request('https://api.test/api/v1/admin/normalization/00000000-0000-0000-0000-000000000001/resolve', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ selected_item_id: row.service_id, alias: 'BH' }),
    }), env);
    expect(allowed.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_update_alias', expect.objectContaining({ p_alias: 'BH', p_reviewer_user_id: '00000000-0000-0000-0000-000000000099' }), { admin: true });
  });

  it('scopes admin idempotency keys to the authenticated reviewer', async () => {
    const rpc = rpcWith({ status: 'resolved' });
    const handler = createHandler({ rpc, authenticateAdmin });
    const response = await handler(new Request('https://api.test/api/v1/admin/normalization/00000000-0000-0000-0000-000000000001/resolve', {
      method: 'POST',
      headers: {
        authorization: 'Bearer user-token',
        'content-type': 'application/json',
        'idempotency-key': 'shared-review-key',
      },
      body: JSON.stringify({ selected_item_id: row.service_id, alias: 'BH' }),
    }), env);
    expect(response.status).toBe(200);
    const call = (rpc.call as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(call[0]).toBe('api_admin_update_alias');
    expect(call[1].p_request_id).toMatch(/^[a-f0-9]{64}$/);
    expect(call[1].p_request_id).not.toBe('shared-review-key');
  });

  it('forwards the admin catalog lookup', async () => {
    const rpc = rpcWith([{ item_id: row.service_id, display_name: 'Biometría hemática', service_type: 'lab_test', status: 'active' }]);
    const response = await createHandler({ rpc, authenticateAdmin })(new Request('https://api.test/api/v1/admin/catalog-items?q=biometria&limit=10', { headers: { authorization: 'Bearer user-token' } }), env);
    expect(response.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_catalog_items', { p_query: 'biometria', p_limit: 10 }, { admin: true });
  });

  it('authenticates Admin JWTs through Supabase and enforces the user allowlist', async () => {
    const aal2Token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const target = String(input);
      expect(init?.headers).toEqual(expect.objectContaining({ apikey: 'anon', Authorization: `Bearer ${aal2Token}` }));
      expect(init?.redirect).toBe('error');
      expect(init?.cache).toBe('no-store');
      expect(target).toBe('https://example.supabase.co/auth/v1/user');
      return new Response(JSON.stringify({
        id: '00000000-0000-0000-0000-000000000099', is_anonymous: false,
        factors: [{ id: '00000000-0000-0000-0000-000000000097', factor_type: 'totp', status: 'verified' }],
      }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      const response = await createHandler({ rpc: rpcWith({}) })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${aal2Token}` },
      }), env);
      expect(response.status).toBe(200);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('rejects an aal1 claim after mocked Auth validation', async () => {
    const aal1Token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwxIn0.sig';
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      expect(String(input)).toBe('https://example.supabase.co/auth/v1/user');
      return new Response(JSON.stringify({ id: '00000000-0000-0000-0000-000000000099', is_anonymous: false }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({});
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${aal1Token}` },
      }), env);
      expect(response.status).toBe(403);
      expect(await response.json()).toEqual({ error: { code: 'mfa_required', message: 'A second factor is required for administrative access' } });
      expect(fetcher).toHaveBeenCalledOnce();
      expect(rpc.call).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('rejects an anonymous identity even when its JWT claims aal2', async () => {
    const token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      expect(String(input)).toBe('https://example.supabase.co/auth/v1/user');
      return new Response(JSON.stringify({
        id: '00000000-0000-0000-0000-000000000099',
        is_anonymous: true,
      }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({});
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/provider/claims', {
        headers: { authorization: `Bearer ${token}` },
      }), env);
      expect(response.status).toBe(401);
      expect(rpc.call).not.toHaveBeenCalled();
      expect(fetcher).toHaveBeenCalledOnce();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('fails closed when Auth omits the permanent-account marker', async () => {
    const token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      expect(String(input)).toBe('https://example.supabase.co/auth/v1/user');
      return new Response(JSON.stringify({ id: '00000000-0000-0000-0000-000000000099' }), { status: 200 });
    });
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({});
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${token}` },
      }), env);
      expect(response.status).toBe(401);
      expect(rpc.call).not.toHaveBeenCalled();
      expect(fetcher).toHaveBeenCalledOnce();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('returns bounded normalization evidence and forwards explicit review decisions', async () => {
    const rpc = rpcWith({
      ok: true,
      raw_record: {
        source_url: 'https://example.test/evidence?token=secret#private',
        payload: {
          url: 'https://example.test/raw?access_token=secret',
          nested: { href: 'https://example.test/nested?sig=secret' },
        },
      },
    });
    const handler = createHandler({ rpc, authenticateAdmin });
    const runId = '00000000-0000-0000-0000-000000000021';
    const detail = await handler(new Request(`https://api.test/api/v1/admin/normalization/${runId}?include_payload=true`, {
      headers: { authorization: 'Bearer user-token' },
    }), env);
    expect(detail.status).toBe(200);
    const detailPayload = await detail.json() as { raw_record: { source_url: string; payload: { url: string; nested: { href: string } } } };
    expect(detailPayload.raw_record.source_url).toBe('https://example.test/evidence');
    expect(detailPayload.raw_record.payload).toEqual({
      url: 'https://example.test/raw',
      nested: { href: 'https://example.test/nested' },
    });
    expect(rpc.call).toHaveBeenCalledWith('api_admin_normalization_detail', {
      p_normalization_run_id: runId,
      p_include_raw_payload: true,
    }, { admin: true });

    const reviewed = await handler(new Request(`https://api.test/api/v1/admin/normalization/${runId}/review`, {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({
        decision: 'approve_candidate',
        selected_candidate_id: '00000000-0000-0000-0000-000000000022',
        alias: 'BH',
        reason: 'Coincide con la evidencia revisada',
      }),
    }), env);
    expect(reviewed.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_normalization', expect.objectContaining({
      p_normalization_run_id: runId,
      p_decision: 'approve_candidate',
      p_selected_candidate_id: '00000000-0000-0000-0000-000000000022',
      p_request_id: expect.any(String),
    }), { admin: true });

    const alert = await handler(new Request('https://api.test/api/v1/admin/alerts/00000000-0000-0000-0000-000000000023/status', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'resolved', reason: 'Revisada' }),
    }), env);
    expect(alert.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_update_alert_status', expect.objectContaining({
      p_alert_id: '00000000-0000-0000-0000-000000000023',
      p_status: 'resolved',
      p_request_id: expect.any(String),
    }), { admin: true });
  });

  it('rejects invalid normalization cursors before invoking privileged RPCs', async () => {
    const rpc = rpcWith([]);
    const handler = createHandler({ rpc, authenticateAdmin });
    const response = await handler(new Request('https://api.test/api/v1/admin/normalization-queue?before_id=not-a-uuid', {
      headers: { authorization: 'Bearer user-token' },
    }), env);
    expect(response.status).toBe(400);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('forwards a valid keyset cursor for the normalization queue', async () => {
    const rpc = rpcWith([]);
    const handler = createHandler({ rpc, authenticateAdmin });
    const beforeId = '00000000-0000-0000-0000-000000000024';
    const beforeCreatedAt = '2026-09-03T12:34:56.000Z';
    const response = await handler(new Request(`https://api.test/api/v1/admin/normalization-queue?before_created_at=${encodeURIComponent(beforeCreatedAt)}&before_id=${beforeId}`, {
      headers: { authorization: 'Bearer user-token' },
    }), env);
    expect(response.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_normalization_queue_v2', expect.objectContaining({
      p_before_created_at: beforeCreatedAt,
      p_before_id: beforeId,
    }), { admin: true });
  });

  it('blocks Admin routes until the Supabase session reaches aal2', async () => {
    const authenticateAal1 = async () => ({ id: '00000000-0000-0000-0000-000000000099', aal: 'aal1' as const });
    const response = await createHandler({ rpc: rpcWith({}), authenticateAdmin: authenticateAal1 })(new Request('https://api.test/api/v1/admin/dashboard'), env);
    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: { code: 'mfa_required', message: 'A second factor is required for administrative access' } });
  });

  it('derives provider step-up assurance from the validated JWT claim', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      id: '00000000-0000-0000-0000-000000000098', is_anonymous: false,
      factors: [{ id: '00000000-0000-0000-0000-000000000097', factor_type: 'totp', status: 'verified' }],
    }), { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({ claim_id: '00000000-0000-0000-0000-000000000010', status: 'pending' });
      const token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/provider/claims', {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          scope_type: 'location',
          provider_brand_id: row.provider_brand_id,
          organization_id: '00000000-0000-0000-0000-000000000012',
          requested_role: 'location_manager',
          relationship_type: 'operator',
        }),
      }), env);
      expect(response.status).toBe(201);
      expect(rpc.call).toHaveBeenCalledWith('api_server_provider_create_claim', expect.objectContaining({
        p_actor_user_id: '00000000-0000-0000-0000-000000000098',
        p_actor_aal: 'aal2',
      }), { admin: true });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('downgrades a stale aal2 JWT when Supabase reports no verified factor', async () => {
    const token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      id: '00000000-0000-0000-0000-000000000099', is_anonymous: false, factors: [],
    }), { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({});
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${token}` },
      }), env);
      expect(response.status).toBe(403);
      expect(await response.json()).toEqual({ error: { code: 'mfa_required', message: 'A second factor is required for administrative access' } });
      expect(rpc.call).not.toHaveBeenCalled();
      expect(fetcher).toHaveBeenCalledTimes(1);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('does not accept a verified factor supplied through editable user metadata', async () => {
    const token = 'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhYWwiOiJhYWwyIn0.sig';
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      id: '00000000-0000-0000-0000-000000000099', is_anonymous: false,
      user_metadata: { factors: [{ id: '00000000-0000-0000-0000-000000000097', factor_type: 'totp', status: 'verified' }] },
    }), { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    try {
      const rpc = rpcWith({});
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/admin/dashboard', {
        headers: { authorization: `Bearer ${token}` },
      }), env);
      expect(response.status).toBe(403);
      expect(await response.json()).toEqual({ error: { code: 'mfa_required', message: 'A second factor is required for administrative access' } });
      expect(rpc.call).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('protects provider routes and forwards a branch claim with the user token', async () => {
    const rpc = rpcWith({ claim_id: '00000000-0000-0000-0000-000000000010', status: 'pending' });
    const handler = createHandler({ rpc, authenticateUser });
    expect((await handler(new Request('https://api.test/api/v1/provider/claims'), env)).status).toBe(401);
    const response = await handler(new Request('https://api.test/api/v1/provider/claims', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({
        scope_type: 'location',
        provider_brand_id: row.provider_brand_id,
        provider_location_id: '00000000-0000-0000-0000-000000000011',
        organization_id: '00000000-0000-0000-0000-000000000012',
        requested_role: 'location_manager',
        relationship_type: 'operator',
        reason: 'I manage this branch',
      }),
    }), env);
    expect(response.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_create_claim', expect.objectContaining({
      p_actor_user_id: '00000000-0000-0000-0000-000000000098',
      p_actor_aal: 'aal2',
      p_scope_type: 'location',
      p_provider_location_id: '00000000-0000-0000-0000-000000000011',
      p_requested_role: 'location_manager',
    }), { admin: true });
  });

  it('requires AAL2 before any provider access, including reads', async () => {
    const rpc = rpcWith({});
    const authenticateAal1 = async (request: Request) => request.headers.get('authorization') === 'Bearer provider-token'
      ? { id: '00000000-0000-0000-0000-000000000098', aal: 'aal1' as const }
      : null;
    const handler = createHandler({ rpc, authenticateUser: authenticateAal1 });
    const response = await handler(new Request('https://api.test/api/v1/provider/claims', {
      headers: { authorization: 'Bearer provider-token' },
    }), env);
    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: { code: 'mfa_required', message: 'A second factor is required for provider access' } });
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('rate limits the provider surface independently', async () => {
    const limiter = { limit: vi.fn(async () => ({ success: false })) };
    const response = await createHandler({ rpc: rpcWith({}), authenticateUser })(
      new Request('https://api.test/api/v1/provider/claims', {
        headers: { authorization: 'Bearer provider-token', 'cf-connecting-ip': '203.0.113.20' },
      }),
      { ...env, PROVIDER_RATE_LIMITER: limiter },
    );
    expect(response.status).toBe(429);
    expect(limiter.limit).toHaveBeenCalledWith({ key: 'provider:203.0.113.20' });
  });

  it('validates provider documents and forwards memberships to the scoped RPCs', async () => {
    const rpc = rpcWith({ document_id: '00000000-0000-0000-0000-000000000013' });
    const handler = createHandler({ rpc, authenticateUser });
    const invalid = await handler(new Request('https://api.test/api/v1/provider/claims/not-a-uuid/documents', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: '{}',
    }), env);
    expect(invalid.status).toBe(400);
    const document = await handler(new Request('https://api.test/api/v1/provider/claims/00000000-0000-0000-0000-000000000010/documents', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ document_type: 'rfc', object_key: 'claims/10/rfc.pdf', sha256: 'a'.repeat(64) }),
    }), env);
    expect(document.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_add_claim_document', expect.objectContaining({ p_sha256: 'a'.repeat(64) }), { admin: true });
    const member = await handler(new Request('https://api.test/api/v1/provider/claims/00000000-0000-0000-0000-000000000010/members', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ user_id: '00000000-0000-0000-0000-000000000014', role: 'location_manager' }),
    }), env);
    expect(member.status).toBe(201);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_invite_member', expect.objectContaining({ p_role: 'location_manager' }), { admin: true });
  });

  it('submits only scoped provider profile proposals', async () => {
    const rpc = rpcWith({ request_id: '00000000-0000-0000-0000-000000000015', status: 'pending' });
    const handler = createHandler({ rpc, authenticateUser });
    const response = await handler(new Request('https://api.test/api/v1/provider/locations/00000000-0000-0000-0000-000000000011/profile', {
      method: 'PATCH',
      headers: { authorization: 'Bearer provider-token', 'content-type': 'application/json' },
      body: JSON.stringify({ claim_id: '00000000-0000-0000-0000-000000000010', changes: { phone: '2220000000' } }),
    }), env);
    expect(response.status).toBe(202);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_submit_location_change', {
      p_actor_user_id: '00000000-0000-0000-0000-000000000098',
      p_actor_aal: 'aal2',
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_provider_location_id: '00000000-0000-0000-0000-000000000011',
      p_changes: { phone: '2220000000' },
    }, { admin: true });
  });

  it('lists and accepts memberships, while requiring a reason to revoke claims', async () => {
    const rpc = rpcWith({ membership_id: '00000000-0000-0000-0000-000000000016', status: 'active' });
    const handler = createHandler({ rpc, authenticateUser, authenticateAdmin });
    const memberships = await handler(new Request('https://api.test/api/v1/provider/memberships?status=invited', {
      headers: { authorization: 'Bearer provider-token' },
    }), env);
    expect(memberships.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_my_memberships', {
      p_actor_user_id: '00000000-0000-0000-0000-000000000098',
      p_actor_aal: 'aal2',
      p_status: 'invited',
      p_limit: 100,
    }, { admin: true });
    const accepted = await handler(new Request('https://api.test/api/v1/provider/memberships/00000000-0000-0000-0000-000000000016/accept', {
      method: 'POST',
      headers: { authorization: 'Bearer provider-token' },
    }), env);
    expect(accepted.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_server_provider_accept_membership', {
      p_actor_user_id: '00000000-0000-0000-0000-000000000098',
      p_actor_aal: 'aal2',
      p_membership_id: '00000000-0000-0000-0000-000000000016',
    }, { admin: true });
    const invalidRevoke = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/revoke', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ reason: '' }),
    }), env);
    expect(invalidRevoke.status).toBe(400);
    const revoked = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/revoke', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ reason: 'Relationship ended' }),
    }), env);
    expect(revoked.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_revoke_provider_claim', expect.objectContaining({
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
      p_reason: 'Relationship ended',
    }), { admin: true });
  });

  it('exposes admin claim review without exposing provider routes publicly', async () => {
    const rpc = rpcWith({ claim_id: '00000000-0000-0000-0000-000000000010', status: 'approved' });
    const handler = createHandler({ rpc, authenticateAdmin });
    const response = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/review', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ decision: 'approved', reason: 'Evidence accepted' }),
    }), env);
    expect(response.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_provider_claim', expect.objectContaining({
      p_claim_id: '00000000-0000-0000-0000-000000000010',
      p_decision: 'approved',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
    }), { admin: true });
    const changeResponse = await handler(new Request('https://api.test/api/v1/admin/provider-change-requests/00000000-0000-0000-0000-000000000015/review', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ decision: 'approved' }),
    }), env);
    expect(changeResponse.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_provider_change', expect.objectContaining({
      p_request_id: '00000000-0000-0000-0000-000000000015',
      p_decision: 'approved',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
    }), { admin: true });
  });

  it('requires verified document review before claim approval can be performed', async () => {
    const rpc = rpcWith([{ document_id: '00000000-0000-0000-0000-000000000017', scan_status: 'clean', content_verified: true }]);
    const handler = createHandler({ rpc, authenticateAdmin });
    const documents = await handler(new Request('https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/documents', {
      headers: { authorization: 'Bearer user-token' },
    }), env);
    expect(documents.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_provider_claim_documents', {
      p_claim_id: '00000000-0000-0000-0000-000000000010',
    }, { admin: true });

    const reviewed = await handler(new Request('https://api.test/api/v1/admin/provider-documents/00000000-0000-0000-0000-000000000017/review', {
      method: 'POST',
      headers: { authorization: 'Bearer user-token', 'content-type': 'application/json' },
      body: JSON.stringify({ decision: 'accepted', reason: 'Hash, MIME and scan verified' }),
    }), env);
    expect(reviewed.status).toBe(200);
    expect(rpc.call).toHaveBeenCalledWith('api_admin_review_provider_document', {
      p_document_id: '00000000-0000-0000-0000-000000000017',
      p_decision: 'accepted',
      p_reviewer_user_id: '00000000-0000-0000-0000-000000000099',
      p_reason: 'Hash, MIME and scan verified',
    }, { admin: true });
  });

  it('bounds streamed admin bodies before invoking privileged RPCs', async () => {
    const rpc = rpcWith({});
    const handler = createHandler({ rpc, authenticateAdmin });
    const response = await handler(streamedJsonRequest(
      'https://api.test/api/v1/admin/provider-claims/00000000-0000-0000-0000-000000000010/review',
      JSON.stringify({ decision: 'approved', reason: 'R'.repeat(20_000) }),
    ), env);
    expect(response.status).toBe(413);
    expect(rpc.call).not.toHaveBeenCalled();
  });

  it('accepts only consent-gated, non-clinical analytics metadata', async () => {
    const rpc = rpcWith({ accepted: true });
    const handler = createHandler({ rpc });
    const accepted = await handler(new Request('https://api.test/api/v1/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        event_name: 'search_completed',
        anonymous_id: '00000000-0000-0000-0000-000000000099',
        metadata: { result_count: 4, surface: 'pwa' },
      }),
    }), env);
    expect(accepted.status).toBe(202);
    expect(rpc.call).toHaveBeenCalledWith('api_record_analytics_event', {
      p_event_name: 'search_completed',
      p_anonymous_id: '00000000-0000-0000-0000-000000000099',
      p_metadata: { result_count: 4, surface: 'pwa' },
    });

    const rejected = await handler(new Request('https://api.test/api/v1/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ event_name: 'search_completed', anonymous_id: '00000000-0000-0000-0000-000000000099', metadata: { query: 'glucosa' } }),
    }), env);
    expect(rejected.status).toBe(400);
    expect(rpc.call).toHaveBeenCalledTimes(1);
  });
});
