import { createWorkerHandler, runScheduledNormalizationReprocess } from './app.js';
import { SupabaseRpcClient } from './supabase.js';
import type { Env } from './types.js';

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return createWorkerHandler(env)(request, env);
  },
  async scheduled(controller: ScheduledController, env: Env): Promise<void> {
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
