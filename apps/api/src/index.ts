import { createWorkerHandler, runScheduledNormalizationReprocess } from './app.js';
import { runScheduledDenueCollection } from './scheduled_denue.js';
import { SupabaseRpcClient } from './supabase.js';
import type { Env } from './types.js';
import { countAggregateUsage, usageAction } from './aggregate_usage.js';

export default {
  async fetch(request: Request, env: Env, context: ExecutionContext): Promise<Response> {
    const response = await createWorkerHandler(env)(request, env);
    if (env.AGGREGATE_USAGE_ENABLED === 'true') {
      const action = usageAction(request, response);
      if (action) context.waitUntil(countAggregateUsage(env, action));
    }
    return response;
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
