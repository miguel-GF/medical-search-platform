import { SupabaseRpcClient } from './supabase.js';
import type { Env } from './types.js';

/** Fixed action names only. Never pass a URL, query, IP, visitor or study ID. */
export function usageAction(request: Request, response: Response): string | null {
  if (!response.ok) return null;
  const url = new URL(request.url);
  if (request.method === 'GET' && url.pathname === '/api/v1/search') {
    return url.searchParams.has('selected_service_id') ? 'study_selection' : 'study_search';
  }
  if (request.method !== 'POST') return null;
  return ({ '/api/v1/resolve': 'order_resolution', '/api/v1/resolve-batch': 'order_batch', '/api/v1/resolve-image': 'order_image' } as Record<string, string>)[url.pathname] ?? null;
}

export async function countAggregateUsage(env: Env, action: string): Promise<void> {
  try {
    // A separate bounded call cannot delay the response or log clinical input.
    await new SupabaseRpcClient({ ...env, SUPABASE_TIMEOUT_MS: '1000' }).call(
      'api_increment_usage_total', { p_action: action }, { admin: true },
    );
  } catch {
    // Best effort counters measure requests, never unique people or coverage.
  }
}
