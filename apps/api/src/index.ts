import { createWorkerHandler, runScheduledNormalizationReprocess } from './app.js';
import { runScheduledDenueCollection } from './scheduled_denue.js';
import { SupabaseRpcClient } from './supabase.js';
import type { Env } from './types.js';

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return createWorkerHandler(env)(request, env);
  },
  async scheduled(controller: ScheduledController, env: Env): Promise<void> {
    if (controller.cron === '17 14 1 * *') {
      try {
        const outcome = await runScheduledDenueCollection(
          env,
          new SupabaseRpcClient(env),
          controller.scheduledTime,
        );
        console.log(JSON.stringify({ event: 'denue_collection_completed', ...outcome }));
      } catch {
        // The DENUE token is embedded in upstream request paths. Never log the
        // exception object or URL, even on fetch/parse failure.
        console.error(JSON.stringify({ event: 'denue_collection_failed', reason: 'bounded_job_error' }));
      }
      return;
    }
    const outcome = await runScheduledNormalizationReprocess(
      env,
      new SupabaseRpcClient(env),
      controller.scheduledTime,
    );
    if (outcome.skipped) {
      console.log(JSON.stringify({ event: 'normalization_cron_skipped', reason: outcome.skipped }));
      return;
    }
    console.log(JSON.stringify({
      event: 'normalization_cron_completed',
      request_id: outcome.request_id,
      result: outcome.result,
    }));
  },
};
