import { describe, expect, it, vi } from 'vitest';
import { createAdminApi, formatDate } from '../src/api';

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
    await expect(createAdminApi('https://api.test', async () => null, fetcher).dashboard()).rejects.toThrow('Admin session required');
    expect(fetcher).not.toHaveBeenCalled();
  });
});
