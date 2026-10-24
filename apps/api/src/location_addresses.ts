import { SupabaseRpcClient } from './supabase.js';
import type { Env } from './types.js';

const UUID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

/** Enrich only locations already present in a successful public response. */
export async function withLocationAddresses(response: Response, request: Request, env: Env): Promise<Response> {
  const path = new URL(request.url).pathname;
  if (!response.ok || !/^\/api\/v1\/(search|resolve|resolve-batch|resolve-image|services\/[0-9a-f-]+)$/.test(path)) return response;
  try {
    const payload: unknown = await response.clone().json();
    const locations = new Map<string, Record<string, unknown>[]>();
    let visited = 0;
    function remember(value: unknown) {
      if (!value || typeof value !== 'object' || Array.isArray(value)) return;
      const record = value as Record<string, unknown>;
      const id = record.id;
      if (typeof id !== 'string' || !UUID.test(id) || locations.size >= 500) return;
      locations.set(id, [...(locations.get(id) ?? []), record]);
    }
    function walk(value: unknown, depth = 0) {
      if (!value || typeof value !== 'object' || depth > 16 || ++visited > 5000) return;
      if (Array.isArray(value)) { value.forEach(v => walk(v, depth + 1)); return; }
      for (const [key, child] of Object.entries(value)) {
        if (key === 'location') remember(child);
        if (key === 'locations' && Array.isArray(child)) child.forEach(remember);
        walk(child, depth + 1);
      }
    }
    walk(payload);
    if (!locations.size) return response;
    const addresses = await new SupabaseRpcClient(env).call<{ id: string; address: string | null }[]>(
      'api_public_location_addresses', { p_location_ids: [...locations.keys()] }, { admin: true },
    );
    for (const row of addresses) {
      const address = typeof row.address === 'string' ? row.address.trim().slice(0, 1000) : null;
      for (const location of locations.get(row.id) ?? []) location.address = address || null;
    }
    return new Response(JSON.stringify(payload), { status: response.status, headers: response.headers });
  } catch {
    // Address lookup failure must not turn a valid study result into an error.
    return response;
  }
}
