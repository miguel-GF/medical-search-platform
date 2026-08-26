import { describe, expect, it, vi } from 'vitest';
import { createAdminApi, formatDate } from '../src/api';

describe('admin API client', () => {
  it('adds admin auth and reads dashboard', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ active_catalog_items: 143 }), { status: 200 }));
    const api = createAdminApi('https://api.test/', 'secret', fetcher);
    await expect(api.dashboard()).resolves.toEqual({ active_catalog_items: 143 });
    expect(fetcher).toHaveBeenCalledWith('https://api.test/api/v1/admin/dashboard', expect.objectContaining({ headers: expect.objectContaining({ authorization: 'Bearer secret' }) }));
  });
  it('surfaces API errors and formats dates', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ error: { message: 'unauthorized' } }), { status: 401 }));
    await expect(createAdminApi('https://api.test', 'x', fetcher).dashboard()).rejects.toThrow('unauthorized');
    expect(formatDate(null)).toBe('—');
  });
});
