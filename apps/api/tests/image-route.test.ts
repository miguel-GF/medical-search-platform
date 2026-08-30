import { describe, expect, it, vi } from 'vitest';
import { createHandler } from '../src/app.js';
import type { Env, OcrAiBinding, RpcClient } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'anon',
  ADMIN_USER_IDS: '',
  OCR_AI_MODEL: '@cf/moondream/moondream3.1-9B-A2B',
};

const item = {
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
};

function rpcWith(value: unknown): RpcClient {
  const call = vi.fn(async <T>(_name: string, _body: Record<string, unknown>): Promise<T> => value as T);
  return { call: call as RpcClient['call'] };
}

describe('POST /api/v1/resolve-image', () => {
  it('transcribes the image and sends only extracted text to the deterministic package resolver', async () => {
    const ai: OcrAiBinding = { run: vi.fn(async () => ({ answer: 'BH' })) };
    const rpc = rpcWith({ engine_version: 'clinical-resolver-v6', items: [item], offers: [] });
    const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve-image', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ image: 'data:image/jpeg;base64,/9j/4AA=' }),
    }), { ...env, AI: ai });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(expect.objectContaining({
      ocr: expect.objectContaining({ engine: 'workers_ai', text: 'BH' }),
      package_status: 'ready',
      coverage_status: 'none',
    }));
    expect(ai.run).toHaveBeenCalledWith(env.OCR_AI_MODEL, expect.objectContaining({ temperature: 0 }));
    expect(rpc.call).toHaveBeenCalledWith('api_resolve_ocr_package', expect.objectContaining({ p_items: ['BH'] }));
  });

  it('returns a configuration error without an AI binding and validates image MIME', async () => {
    const handler = createHandler({ rpc: rpcWith({}) });
    const unavailable = await handler(new Request('https://api.test/api/v1/resolve-image', {
      method: 'POST', body: JSON.stringify({ image: 'data:image/jpeg;base64,/9j/4AA=' }),
    }), env);
    expect(unavailable.status).toBe(503);
    const invalid = await handler(new Request('https://api.test/api/v1/resolve-image', {
      method: 'POST', body: JSON.stringify({ image: 'AAE=', mime_type: 'application/pdf' }),
    }), { ...env, AI: { run: async () => ({ answer: 'BH' }) } });
    expect(invalid.status).toBe(400);
  });

  it('rejects an oversized body before calling AI', async () => {
    const ai: OcrAiBinding = { run: vi.fn(async () => ({ answer: 'BH' })) };
    const handler = createHandler({ rpc: rpcWith({}) });
    const oversized = JSON.stringify({ image: `data:image/jpeg;base64,${'A'.repeat(8_100_000)}` });
    const response = await handler(new Request('https://api.test/api/v1/resolve-image', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: oversized,
    }), { ...env, AI: ai });
    expect(response.status).toBe(413);
    expect(ai.run).not.toHaveBeenCalled();
  });

  it('uses the private Python OCR service when configured', async () => {
    const ai: OcrAiBinding = { run: vi.fn(async () => ({ answer: 'SHOULD NOT RUN' })) };
    const rpc = rpcWith({ engine_version: 'clinical-resolver-v6', items: [item], offers: [] });
    const serviceFetch = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      expect(init?.headers).toEqual(expect.objectContaining({ authorization: 'Bearer python-secret' }));
      return new Response(JSON.stringify({
        text: 'BH', engine: 'python_ocr', model: 'PP-OCRv6_rec_small', confidence: 0.91,
        lines: [{ text: 'BH', confidence: 0.88 }, { text: 'EGO', confidence: 0.99 }],
      }), { status: 200, headers: { 'content-type': 'application/json' } });
    });
    vi.stubGlobal('fetch', serviceFetch);
    try {
      const response = await createHandler({ rpc })(new Request('https://api.test/api/v1/resolve-image', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ image: 'data:image/jpeg;base64,/9j/4AA=' }),
      }), {
        ...env,
        AI: ai,
        OCR_SERVICE_URL: 'https://ocr.internal.example',
        OCR_SERVICE_TOKEN: 'python-secret',
      });
      expect(response.status).toBe(200);
      expect((await response.json()) as Record<string, unknown>).toEqual(expect.objectContaining({
        ocr: expect.objectContaining({
          engine: 'python_ocr',
          model: 'PP-OCRv6_rec_small',
          confidence: 0.91,
          review_required: true,
          low_confidence_lines: ['BH'],
          lines: [{ text: 'BH', confidence: 0.88 }, { text: 'EGO', confidence: 0.99 }],
        }),
      }));
      expect(ai.run).not.toHaveBeenCalled();
      expect(serviceFetch).toHaveBeenCalledWith('https://ocr.internal.example/v1/ocr/order', expect.anything());
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
