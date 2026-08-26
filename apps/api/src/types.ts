export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_TIMEOUT_MS?: string;
  ADMIN_TOKEN?: string;
  API_VERSION?: string;
  ALLOWED_ORIGIN?: string;
}

export interface RpcClient {
  call<T>(name: string, body: Record<string, unknown>, options?: { admin?: boolean }): Promise<T>;
}

export interface SearchRow {
  service_id: string;
  display_name: string;
  matched_term: string;
  term_source: string;
  confidence: number;
  offer_id: string;
  provider_brand_id: string;
  provider_name: string;
  provider_location_id: string | null;
  provider_location_name: string | null;
  latitude: number | null;
  longitude: number | null;
  distance_meters: number | null;
  source_url: string | null;
  price_type: string | null;
  price_key: string | null;
  amount_minor: number | null;
  currency: string | null;
  price_last_seen_at: string | null;
}
