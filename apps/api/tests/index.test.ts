import { afterEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index.js';
import type { Env } from '../src/types.js';

describe('scheduled Worker dispatch', () => {
  afterEach(() => vi.restoreAllMocks());

  it('routes the monthly cron to the disabled-by-default DENUE collector', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const controller = {
      cron: '17 14 1 * *',
      scheduledTime: Date.parse('2026-10-01T14:17:00Z'),
    } as ScheduledController;
    const env: Env = {
      SUPABASE_URL: 'https://project.supabase.co',
      DENUE_COLLECTION_ENABLED: 'false',
    };

    await worker.scheduled(controller, env);

    expect(log).toHaveBeenCalledWith(expect.stringContaining('"event":"denue_collection_completed"'));
    expect(log).toHaveBeenCalledWith(expect.stringContaining('"skipped":"disabled"'));
  });

  it('keeps the hourly trigger on the exact-normalization handler', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const controller = {
      cron: '17 * * * *',
      scheduledTime: Date.parse('2026-10-01T14:17:00Z'),
    } as ScheduledController;
    const env: Env = { SUPABASE_URL: 'https://project.supabase.co' };

    await worker.scheduled(controller, env);

    expect(log).toHaveBeenCalledWith(expect.stringContaining('"event":"normalization_cron_skipped"'));
    expect(log).not.toHaveBeenCalledWith(expect.stringContaining('denue_collection'));
  });
});
