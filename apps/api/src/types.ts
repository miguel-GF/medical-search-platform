export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_TIMEOUT_MS?: string;
  ADMIN_USER_IDS?: string;
  API_VERSION?: string;
  ALLOWED_ORIGIN?: string;
}

export interface RpcClient {
  call<T>(name: string, body: Record<string, unknown>, options?: { admin?: boolean }): Promise<T>;
}

export interface AdminUser {
  id: string;
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

export interface ResolutionCandidate {
  service_id: string;
  display_name: string;
  matched_term: string;
  term_source: string;
  provider_brand_id: string | null;
  confidence: number;
  resolution_status: 'resolved' | 'ambiguous';
  match_method: string;
  explanation: Record<string, unknown>;
  offers: Array<Record<string, unknown>>;
}

export interface ResolutionResponse {
  query: string;
  normalized_query: string;
  engine_version: string;
  status: 'resolved' | 'ambiguous' | 'no_match';
  candidates: ResolutionCandidate[];
}

export interface AdminCatalogItem {
  item_id: string;
  display_name: string;
  service_type: string;
  status: string;
}

export interface AdminProvider {
  provider_id: string;
  provider_name: string;
  status: string;
  verification_status: string;
  locations_count: number;
  active_offers_count: number;
}

export interface AdminLocation {
  location_id: string;
  provider_name: string;
  location_name: string;
  address: string | null;
  locality: string | null;
  status: string;
  latitude: number | null;
  longitude: number | null;
}

export interface AdminOffer {
  offer_id: string;
  provider_name: string;
  service_name: string;
  catalog_item_id: string;
  status: string;
  current_price_count: number;
  last_seen_at: string | null;
}

export interface AdminPrice {
  price_version_id: string;
  provider_name: string;
  service_name: string;
  amount_minor: number;
  currency: string;
  price_type: string;
  last_seen_at: string;
  source_url: string | null;
}

export interface AdminQualityIssue {
  issue_id: string;
  issue_code: string;
  severity: string;
  status: string;
  source_id: string | null;
  crawl_run_id: string | null;
  details: Record<string, unknown>;
  created_at: string;
}

export interface AdminAlert {
  alert_id: string;
  alert_code: string;
  severity: string;
  status: string;
  source: string | null;
  title: string;
  detail: string | null;
  created_at: string;
}
