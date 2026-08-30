export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_TIMEOUT_MS?: string;
  ADMIN_USER_IDS?: string;
  API_VERSION?: string;
  ALLOWED_ORIGIN?: string;
  AI?: OcrAiBinding;
  OCR_AI_MODEL?: string;
  OCR_SERVICE_URL?: string;
  OCR_SERVICE_TOKEN?: string;
  OCR_SERVICE_TIMEOUT_MS?: string;
}

/** Narrow interface used so the Worker remains testable without an AI binding. */
export interface OcrAiBinding {
  run(model: string, inputs: Record<string, unknown>, options?: Record<string, unknown>): Promise<unknown>;
}

export interface OcrLine {
  text: string;
  confidence: number | null;
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

export type PackageObjective = 'all_in_one' | 'lowest_cost' | 'nearest' | 'balanced';
export type PackageItemStatus = 'resolved' | 'ambiguous' | 'no_match';

export interface PackageCandidate {
  service_id: string;
  display_name: string;
  matched_term: string;
  term_source: string;
  confidence: number;
  resolution_status: 'resolved' | 'ambiguous';
  match_method: string;
  explanation: Record<string, unknown>;
}

export interface PackageItem {
  index: number;
  input: string;
  normalized_query: string;
  status: PackageItemStatus;
  candidates: PackageCandidate[];
  reason_code?: string;
  ocr_correction?: OcrCorrection;
}

export interface OcrCorrection {
  suggested_text: string;
  correction_type: 'character_confusion' | 'spacing' | 'lexical_review';
  confidence: number;
  source_note?: string | null;
}

export interface PackageOffer {
  item_index: number;
  item_id: string;
  offer_id: string;
  provider_brand_id: string;
  provider_name: string;
  provider_location_id: string;
  provider_location_name: string;
  latitude: number | null;
  longitude: number | null;
  distance_meters: number | null;
  source_url: string | null;
  price_type: string | null;
  price_key: string | null;
  amount_minor: number | null;
  currency: string | null;
  price_last_seen_at: string | null;
  requires_quote: boolean;
}

export interface PackageRpcResponse {
  engine_version: string;
  items: PackageItem[];
  offers: PackageOffer[];
  ocr_corrections?: Array<{
    index: number;
    input: string;
    suggested_text: string;
    correction_type: OcrCorrection['correction_type'];
    confidence: number;
    source_note?: string | null;
  }>;
}

export interface PackageLocation {
  id: string;
  name: string;
  provider_brand_id: string;
  provider_name: string;
  latitude: number | null;
  longitude: number | null;
  distance_meters: number | null;
}

export interface PackageSolution {
  coverage_count: number;
  requested_count: number;
  coverage_percent: number;
  missing_item_indexes: number[];
  location_count: number;
  locations: PackageLocation[];
  total_amount_minor: number | null;
  currency: string | null;
  requires_quote: boolean;
  distance_meters: number | null;
  selected_offers: Array<Record<string, unknown>>;
}

export interface PackageResolutionResponse {
  query: string;
  engine_version: string;
  objective: PackageObjective;
  package_status: 'ready' | 'needs_clarification' | 'partial' | 'no_match';
  coverage_status: 'complete' | 'partial' | 'none';
  items: PackageItem[];
  ocr_corrections?: PackageRpcResponse['ocr_corrections'];
  clarifications: Array<{ index: number; input: string; reason_code: string; candidates: PackageCandidate[] }>;
  solutions: PackageSolution[];
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
