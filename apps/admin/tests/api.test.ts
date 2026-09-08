import { describe, expect, it, vi } from 'vitest';
import { AdminApiError, createAdminApi, formatDate } from '../src/api';

describe('admin API client', () => {
  it('adds admin auth and reads dashboard', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ active_catalog_items: 143 }), { status: 200 }));
    const api = createAdminApi('https://api.test/', async () => 'secret', fetcher);
    await expect(api.dashboard()).resolves.toEqual({ active_catalog_items: 143 });
    expect(fetcher).toHaveBeenCalledWith('https://api.test/api/v1/admin/dashboard', expect.objectContaining({
      redirect: 'error',
      cache: 'no-store',
      headers: expect.objectContaining({ authorization: 'Bearer secret' }),
    }));
  });
  it('surfaces API errors and formats dates', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ error: { message: 'unauthorized' } }), { status: 401 }));
    await expect(createAdminApi('https://api.test', async () => 'x', fetcher).dashboard()).rejects.toThrow('La solicitud no pudo completarse.');
    expect(formatDate(null)).toBe('—');
  });
  it('does not expose unknown upstream error messages', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ error: { code: 'unknown', message: 'SQL password=secret stack trace' } }), { status: 500 }));
    await expect(createAdminApi('https://api.test', async () => 'x', fetcher).dashboard())
      .rejects.toThrow('El servicio no pudo completar la solicitud.');
  });

  it('refuses requests without an authenticated session', async () => {
    const fetcher = vi.fn();
    await expect(createAdminApi('https://api.test', async () => null, fetcher).dashboard()).rejects.toMatchObject({
      name: 'AdminApiError',
      statusCode: 401,
      code: 'unauthorized',
    } satisfies Partial<AdminApiError>);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('refuses an insecure remote API base before reading or sending the token', async () => {
    const fetcher = vi.fn();
    const token = vi.fn(async () => 'secret');
    await expect(createAdminApi('http://remote.api.test', token, fetcher).dashboard()).rejects.toMatchObject({
      name: 'AdminApiError',
      code: 'client_configuration_error',
      statusCode: 0,
    } satisfies Partial<AdminApiError>);
    expect(token).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('refuses API bases carrying query or fragment data', async () => {
    const fetcher = vi.fn();
    const token = vi.fn(async () => 'secret');
    await expect(createAdminApi('https://api.test/?access_token=leak#fragment', token, fetcher).dashboard()).rejects.toMatchObject({
      code: 'client_configuration_error',
      statusCode: 0,
    } satisfies Partial<AdminApiError>);
    expect(token).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('refuses an alternate HTTPS port before reading or sending the token', async () => {
    const fetcher = vi.fn();
    const token = vi.fn(async () => 'secret');
    await expect(createAdminApi('https://api.test:8443', token, fetcher).dashboard()).rejects.toMatchObject({
      code: 'client_configuration_error',
      statusCode: 0,
    } satisfies Partial<AdminApiError>);
    expect(token).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('fails closed when the production API origin is missing', async () => {
    const fetcher = vi.fn();
    const token = vi.fn(async () => 'secret');
    await expect(createAdminApi('', token, fetcher).dashboard()).rejects.toMatchObject({
      code: 'client_configuration_error',
      statusCode: 0,
    } satisfies Partial<AdminApiError>);
    expect(token).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('keeps a caller-provided mutation id stable on the request', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ status: 'resolved' }), { status: 200 }));
    const api = createAdminApi('https://api.test', async () => 'secret', fetcher);
    await api.reviewNormalization('00000000-0000-0000-0000-000000000001', {
      decision: 'no_match',
      reason: 'No corresponde',
    }, 'review-12345678');
    expect(fetcher).toHaveBeenCalledWith(
      'https://api.test/api/v1/admin/normalization/00000000-0000-0000-0000-000000000001/review',
      expect.objectContaining({ headers: expect.objectContaining({ 'x-request-id': 'review-12345678' }) }),
    );
  });

  it('rejects oversized successful API responses before buffering them', async () => {
    const fetcher = vi.fn(async () => new Response('x'.repeat(2 * 1024 * 1024 + 1), { status: 200 }));
    await expect(createAdminApi('https://api.test', async () => 'secret', fetcher).dashboard()).rejects.toMatchObject({
      code: 'invalid_response',
      statusCode: 502,
    } satisfies Partial<AdminApiError>);
  });

  it('keeps malformed identifiers inside one URL path segment', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ status: 'resolved' }), { status: 200 }));
    const api = createAdminApi('https://api.test', async () => 'secret', fetcher);
    await api.reviewNormalization('id/../../alerts?status=resolved#fragment', { decision: 'no_match' });
    const calls = fetcher.mock.calls as unknown as Array<[string]>;
    expect(calls[0][0]).toContain('/normalization/id%2F..%2F..%2Falerts%3Fstatus%3Dresolved%23fragment/review');
  });
});
