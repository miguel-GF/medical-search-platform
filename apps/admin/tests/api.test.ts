import { describe, expect, it, vi } from 'vitest';
import { AdminApiError, createAdminApi, formatDate } from '../src/api';

describe('admin API client', () => {
  it('adds admin auth and reads dashboard', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ active_catalog_items: 143 }), { status: 200 }));
    const api = createAdminApi('https://api.test/', async () => 'secret', fetcher);
    await expect(api.dashboard()).resolves.toEqual({ active_catalog_items: 143 });
    expect(fetcher).toHaveBeenCalledWith('https://api.test/api/v1/admin/dashboard', expect.objectContaining({ headers: expect.objectContaining({ authorization: 'Bearer secret' }) }));
  });
  it('surfaces API errors and formats dates', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ error: { message: 'unauthorized' } }), { status: 401 }));
    await expect(createAdminApi('https://api.test', async () => 'x', fetcher).dashboard()).rejects.toThrow('unauthorized');
    expect(formatDate(null)).toBe('—');
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
});
