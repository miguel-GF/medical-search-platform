import type {
  PackageCandidate,
  PackageItem,
  PackageObjective,
  PackageOffer,
  PackageResolutionResponse,
  PackageRpcResponse,
  PackageSolution,
} from './types.js';

export const PACKAGE_MAX_ITEMS = 30;
export const PACKAGE_MAX_ITEM_LENGTH = 200;
export const PACKAGE_MAX_TEXT_LENGTH = 4_000;
// The database response is still an untrusted network boundary. A 2 MiB JSON
// response can contain far more rows than the package solver needs; keep the
// amount of hostile/malformed data that reaches the combinatorial code bounded.
const PACKAGE_RPC_MAX_ITEMS = 60;
const PACKAGE_RPC_MAX_OFFERS = 5_000;

const OBJECTIVES: PackageObjective[] = ['all_in_one', 'lowest_cost', 'nearest', 'balanced'];

export interface ParsedBatchRequest {
  items: string[];
  original_text: string;
  /** Whether items came from free-form text and may need catalog segmentation. */
  input_source: 'text' | 'items';
  objective: PackageObjective;
  max_solutions: number;
}

export interface BatchInputError {
  code: 'invalid_body' | 'invalid_query' | 'invalid_items' | 'invalid_objective';
  message: string;
}

export type BatchParseResult = { ok: true; value: ParsedBatchRequest } | { ok: false; error: BatchInputError };

export function parseBatchRequest(input: Record<string, unknown>): BatchParseResult {
  const hasText = Object.prototype.hasOwnProperty.call(input, 'text');
  const hasItems = Object.prototype.hasOwnProperty.call(input, 'items');
  if (hasText && hasItems) {
    return { ok: false, error: { code: 'invalid_body', message: 'Provide text or items, not both' } };
  }

  let items: string[];
  let originalText: string;
  if (hasItems) {
    if (!Array.isArray(input.items)) {
      return { ok: false, error: { code: 'invalid_items', message: 'items must be an array' } };
    }
    if (input.items.length === 0 || input.items.length > PACKAGE_MAX_ITEMS) {
      return { ok: false, error: { code: 'invalid_items', message: `items must contain 1-${PACKAGE_MAX_ITEMS} entries` } };
    }
    items = [];
    for (const entry of input.items) {
      const text = typeof entry === 'string'
        ? entry
        : entry && typeof entry === 'object' && typeof (entry as { text?: unknown }).text === 'string'
          ? (entry as { text: string }).text
          : null;
      if (text === null) {
        return { ok: false, error: { code: 'invalid_items', message: 'Each item must be a string or an object with text' } };
      }
      const value = text.trim();
      if (!isValidItemText(value)) {
        return { ok: false, error: { code: 'invalid_items', message: `Each item must contain letters/numbers and be at most ${PACKAGE_MAX_ITEM_LENGTH} characters` } };
      }
      items.push(value);
    }
    originalText = items.join('\n');
  } else {
    if (typeof input.text !== 'string') {
      return { ok: false, error: { code: 'invalid_query', message: 'text or items is required' } };
    }
    originalText = input.text.trim();
    if (!originalText || originalText.length > PACKAGE_MAX_TEXT_LENGTH || !/[\p{L}\p{N}]/u.test(originalText)) {
      return { ok: false, error: { code: 'invalid_query', message: `text is required and must be at most ${PACKAGE_MAX_TEXT_LENGTH} characters` } };
    }
    items = splitBatchText(originalText);
    if (items.length === 0 || items.length > PACKAGE_MAX_ITEMS) {
      return { ok: false, error: { code: 'invalid_items', message: `text must produce 1-${PACKAGE_MAX_ITEMS} studies` } };
    }
    if (items.some((item) => !isValidItemText(item))) {
      return { ok: false, error: { code: 'invalid_items', message: `Each parsed item must contain letters/numbers and be at most ${PACKAGE_MAX_ITEM_LENGTH} characters` } };
    }
  }

  const objective = input.objective === undefined ? 'all_in_one' : input.objective;
  if (typeof objective !== 'string' || !OBJECTIVES.includes(objective as PackageObjective)) {
    return { ok: false, error: { code: 'invalid_objective', message: `objective must be one of: ${OBJECTIVES.join(', ')}` } };
  }
  const maxSolutions = input.max_solutions === undefined ? 10 : input.max_solutions;
  if (typeof maxSolutions !== 'number' || !Number.isInteger(maxSolutions) || maxSolutions < 1 || maxSolutions > 20) {
    return { ok: false, error: { code: 'invalid_items', message: 'max_solutions must be an integer between 1 and 20' } };
  }

  return {
    ok: true,
    value: {
      items,
      original_text: originalText,
      input_source: hasItems ? 'items' : 'text',
      objective: objective as PackageObjective,
      max_solutions: maxSolutions,
    },
  };
}

/**
 * Validate the response from the catalog-backed free-form text segmenter.
 *
 * The segmenter runs in SQL because only the database has the current set of
 * approved names and aliases. Its response is still untrusted at the Worker
 * boundary: callers must only use a segmented result when the fragments
 * reconstruct the normalized original text exactly. This prevents a malformed
 * or stale RPC response from silently dropping, adding, or rewriting a study.
 */
export function readCatalogSegments(value: unknown, originalText: string): string[] | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const payload = value as { status?: unknown; segments?: unknown };
  if (payload.status !== 'segmented' || !Array.isArray(payload.segments)) return null;
  if (payload.segments.length < 2 || payload.segments.length > PACKAGE_MAX_ITEMS) return null;
  const segments: string[] = [];
  for (const segment of payload.segments) {
    if (!segment || typeof segment !== 'object' || Array.isArray(segment)) return null;
    const text = (segment as { text?: unknown }).text;
    const method = (segment as { method?: unknown }).method;
    if (typeof text !== 'string' || !isValidItemText(text.trim())) return null;
    // Only the exact catalog evidence path can be used automatically. A
    // future fuzzy/AI mode must remain a clarification, never a split.
    if (method !== 'catalog_exact' && method !== 'catalog_exact_ambiguous') return null;
    segments.push(text.trim());
  }
  return normalizeForSegmentation(segments.join(' ')) === normalizeForSegmentation(originalText)
    ? segments
    : null;
}

function normalizeForSegmentation(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function splitBatchText(input: string): string[] {
  const items: string[] = [];
  for (const line of input.replace(/\r\n?/g, '\n').split('\n')) {
    for (const semicolonPart of line.split(';')) {
      const part = semicolonPart.trim();
      if (!part) continue;
      const inline = splitInlineNumbered(part);
      for (const candidate of inline) {
        const cleaned = stripListMarker(candidate);
        if (!cleaned) continue;
        const commaParts = splitSafeStudyCommas(cleaned);
        items.push(...commaParts.flatMap(splitSafeStudyConjunction));
      }
    }
  }
  return items.map((item) => item.trim()).filter(Boolean);
}

function splitInlineNumbered(value: string): string[] {
  const matches = [...value.matchAll(/(?:^|,\s*)(\d+)\s*[:.)-]\s*/g)];
  if (matches.length < 2) return [value];
  return matches.map((match, index) => {
    const start = (match.index ?? 0) + match[0].length;
    const end = index + 1 < matches.length ? (matches[index + 1].index ?? value.length) : value.length;
    return value.slice(start, end).replace(/[;,]\s*$/, '').trim();
  });
}

function stripListMarker(value: string): string {
  return value.replace(/^\s*(?:[-*•]\s*)?(?:\d+\s*[:.)-]\s*)?/, '').replace(/[;,]\s*$/, '').trim();
}

function splitSafeStudyCommas(value: string): string[] {
  if (!value.includes(',') || /[()]/.test(value)) return [value];
  const parts = value.split(',').map((part) => stripListMarker(part)).filter(Boolean);
  if (parts.length < 2 || parts.some((part) => !looksLikeStudyPhrase(part))) return [value];
  return parts;
}

function splitSafeStudyConjunction(value: string): string[] {
  if (!/\s+(?:e|y)\s+/i.test(value) || /[()]/.test(value)) return [value];
  const parts = value.split(/\s+(?:e|y)\s+/i).map((part) => part.trim()).filter(Boolean);
  if (parts.length < 2 || parts.some((part) => !looksLikeStudyPhrase(part))) return [value];
  return parts;
}

function looksLikeStudyPhrase(value: string): boolean {
  if (/(?:\bb\s*h\b|\bbh\b|\bq\s*s\b|\bqs\b)/i.test(value)) return true;
  if (/\binsulin\w*/i.test(value)) return true;
  return /(?:biometr|hemograma|\bego\b|orina|qu[ií]m|perfil|audiometr|espirom|ultrason|ecograf|resonancia|\brm\b|tomograf|\btac\b|rayos|radiograf|mastograf|electro|holter|gasometr|covid|colposcop|densitometr|glucosa|creatinin|\binr\b|\btp\b|\bttp\b)/i.test(value);
}

function isValidItemText(value: string): boolean {
  return value.length > 0 && value.length <= PACKAGE_MAX_ITEM_LENGTH && /[\p{L}\p{N}]/u.test(value);
}

export function buildPackageResolution(
  payload: PackageRpcResponse,
  query: string,
  objective: PackageObjective,
  maxSolutions: number,
): PackageResolutionResponse {
  const items = [...(payload.items ?? [])].sort((a, b) => a.index - b.index);
  const hasAmbiguous = items.some((item) => item.status === 'ambiguous');
  const resolvedItems = items.filter((item) => item.status === 'resolved');
  const hasNoMatch = items.some((item) => item.status === 'no_match');
  const packageStatus: PackageResolutionResponse['package_status'] = hasAmbiguous
    ? 'needs_clarification'
    : resolvedItems.length === 0
      ? 'no_match'
      : hasNoMatch
        ? 'partial'
        : 'ready';
  const clarifications = items
    .filter((item) => item.status !== 'resolved')
    .map((item) => ({
      index: item.index,
      input: item.input,
      reason_code: item.reason_code ?? (item.status === 'ambiguous' ? 'ambiguous_service' : 'service_not_found'),
      candidates: item.candidates ?? [],
    }));

  const canSearchCoverage = !hasAmbiguous && resolvedItems.length > 0;
  const resolvedIndexes = new Set(resolvedItems.map((item) => item.index));
  const resolvedOffers = (payload.offers ?? []).filter((offer) => resolvedIndexes.has(offer.item_index));
  const solutions = canSearchCoverage
    ? findPackageSolutions(items, resolvedOffers, objective, maxSolutions)
    : [];
  const requestedCount = items.length;
  const bestCoverage = solutions.reduce((max, solution) => Math.max(max, solution.coverage_count), 0);
  const coverageStatus: PackageResolutionResponse['coverage_status'] = bestCoverage === requestedCount && requestedCount > 0
    ? 'complete'
    : bestCoverage > 0
      ? 'partial'
      : 'none';

  return {
    query,
    engine_version: payload.engine_version ?? 'clinical-resolver-v6',
    objective,
    package_status: packageStatus,
    coverage_status: coverageStatus,
    items,
    ...(payload.ocr_corrections && payload.ocr_corrections.length > 0
      ? { ocr_corrections: payload.ocr_corrections }
      : {}),
    clarifications,
    solutions,
  };
}

interface LocationBucket {
  location: PackageSolution['locations'][number];
  // At most one (best) offer per requested item is needed for a location.
  // Keeping this index avoids repeatedly scanning every offer for every
  // location combination, which otherwise turns a large upstream payload into
  // a CPU-amplification vector.
  offersByItem: Map<number, PackageOffer>;
  covered: Set<number>;
}

function findPackageSolutions(
  items: PackageItem[],
  offers: PackageOffer[],
  objective: PackageObjective,
  maxSolutions: number,
): PackageSolution[] {
  const byLocation = new Map<string, LocationBucket>();
  const requestedIndexes = new Set(items.map((item) => item.index));
  for (const offer of offers) {
    if (!offer.provider_location_id || !Number.isInteger(offer.item_index) || !requestedIndexes.has(offer.item_index)) continue;
    let bucket = byLocation.get(offer.provider_location_id);
    if (!bucket) {
      bucket = {
        location: {
          id: offer.provider_location_id,
          name: offer.provider_location_name,
          provider_brand_id: offer.provider_brand_id,
          provider_name: offer.provider_name,
          latitude: offer.latitude,
          longitude: offer.longitude,
          distance_meters: offer.distance_meters,
        },
        offersByItem: new Map<number, PackageOffer>(),
        covered: new Set<number>(),
      };
      byLocation.set(offer.provider_location_id, bucket);
    }
    const previous = bucket.offersByItem.get(offer.item_index);
    if (!previous || compareOffers(offer, previous) < 0) {
      bucket.offersByItem.set(offer.item_index, offer);
    }
    bucket.covered.add(offer.item_index);
  }
  const candidates = [...byLocation.values()]
    .sort((a, b) => compareLocationBuckets(a, b))
    .slice(0, 40);
  if (candidates.length === 0) return [];

  const combinations: string[][] = [];
  for (let i = 0; i < candidates.length; i += 1) {
    combinations.push([candidates[i].location.id]);
    for (let j = i + 1; j < candidates.length; j += 1) {
      combinations.push([candidates[i].location.id, candidates[j].location.id]);
      for (let k = j + 1; k < candidates.length; k += 1) {
        combinations.push([candidates[i].location.id, candidates[j].location.id, candidates[k].location.id]);
      }
    }
  }

  const bucketMap = new Map(candidates.map((candidate) => [candidate.location.id, candidate]));
  const evaluated = combinations.map((locationIds) => evaluateCombination(items, locationIds, bucketMap));
  const unique = new Map<string, PackageSolution>();
  for (const solution of evaluated) {
    const key = `${solution.locations.map((location) => location.id).join('|')}::${solution.missing_item_indexes.join(',')}`;
    unique.set(key, solution);
  }
  return [...unique.values()]
    .sort((a, b) => compareSolutions(a, b, objective))
    .slice(0, maxSolutions);
}

function evaluateCombination(
  items: PackageItem[],
  locationIds: string[],
  buckets: Map<string, LocationBucket>,
): PackageSolution {
  const selected: PackageOffer[] = [];
  const missing: number[] = [];
  for (const item of items) {
    const options = locationIds
      .map((locationId) => buckets.get(locationId)?.offersByItem.get(item.index))
      .filter((offer): offer is PackageOffer => Boolean(offer))
      .sort(compareOffers);
    const best = options[0];
    if (best) selected.push(best);
    else missing.push(item.index);
  }
  const locations = locationIds.map((id) => buckets.get(id)?.location).filter((location): location is PackageSolution['locations'][number] => Boolean(location));
  const currencies = new Set(selected.map((offer) => offer.currency).filter((currency): currency is string => Boolean(currency)));
  const hasQuote = selected.some((offer) => offer.requires_quote || offer.amount_minor === null);
  const completePrice = missing.length === 0 && !hasQuote && currencies.size === 1 && selected.length === items.length;
  const total = completePrice ? selected.reduce((sum, offer) => sum + (offer.amount_minor ?? 0), 0) : null;
  const distances = locations.map((location) => location.distance_meters).filter((distance): distance is number => distance !== null);
  return {
    coverage_count: selected.length,
    requested_count: items.length,
    coverage_percent: items.length === 0 ? 0 : Math.round((selected.length / items.length) * 10000) / 100,
    missing_item_indexes: missing,
    location_count: locations.length,
    locations,
    total_amount_minor: total,
    currency: completePrice ? [...currencies][0] : null,
    requires_quote: hasQuote || missing.length > 0,
    distance_meters: distances.length === 0 ? null : Math.max(...distances),
    selected_offers: selected.map((offer) => ({
      item_index: offer.item_index,
      item_id: offer.item_id,
      offer_id: offer.offer_id,
      provider_brand_id: offer.provider_brand_id,
      provider_name: offer.provider_name,
      provider_location_id: offer.provider_location_id,
      provider_location_name: offer.provider_location_name,
      amount_minor: offer.amount_minor,
      currency: offer.currency,
      requires_quote: offer.requires_quote,
      source_url: offer.source_url,
    })),
  };
}

function compareOffers(a: PackageOffer, b: PackageOffer): number {
  const aMissing = a.amount_minor === null || a.requires_quote;
  const bMissing = b.amount_minor === null || b.requires_quote;
  if (aMissing !== bMissing) return aMissing ? 1 : -1;
  if (a.amount_minor !== null && b.amount_minor !== null && a.amount_minor !== b.amount_minor) return a.amount_minor - b.amount_minor;
  return `${a.provider_name}|${a.offer_id}`.localeCompare(`${b.provider_name}|${b.offer_id}`);
}

function compareLocationBuckets(a: LocationBucket, b: LocationBucket): number {
  if (a.covered.size !== b.covered.size) return b.covered.size - a.covered.size;
  return compareNullableNumber(a.location.distance_meters, b.location.distance_meters) || `${a.location.provider_name}|${a.location.name}`.localeCompare(`${b.location.provider_name}|${b.location.name}`);
}

function compareSolutions(a: PackageSolution, b: PackageSolution, objective: PackageObjective): number {
  if (a.coverage_count !== b.coverage_count) return b.coverage_count - a.coverage_count;
  if (objective === 'all_in_one' && a.location_count !== b.location_count) return a.location_count - b.location_count;
  if (objective === 'lowest_cost') {
    const cost = compareNullableNumber(a.total_amount_minor, b.total_amount_minor);
    if (cost) return cost;
  }
  if (objective === 'nearest' || objective === 'balanced' || objective === 'all_in_one') {
    const distance = compareNullableNumber(a.distance_meters, b.distance_meters);
    if (distance) return distance;
  }
  if (objective !== 'all_in_one' && a.location_count !== b.location_count) return a.location_count - b.location_count;
  const cost = compareNullableNumber(a.total_amount_minor, b.total_amount_minor);
  if (cost) return cost;
  return a.locations.map((location) => location.id).join('|').localeCompare(b.locations.map((location) => location.id).join('|'));
}

function compareNullableNumber(a: number | null, b: number | null): number {
  if (a === null && b === null) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return a - b;
}

export function normalizeBatchRpcPayload(value: unknown): PackageRpcResponse {
  if (!value || typeof value !== 'object') return { engine_version: 'clinical-resolver-v6', items: [], offers: [] };
  const input = value as Partial<PackageRpcResponse>;
  return {
    engine_version: typeof input.engine_version === 'string' ? input.engine_version : 'clinical-resolver-v6',
    // Supabase responses are trusted for authorization, not for shape. Drop
    // malformed array entries before the deterministic resolver touches them;
    // otherwise a null/object from a bad migration could crash the Worker.
    // The caps also prevent an oversized-but-valid upstream JSON response from
    // amplifying CPU in the package set-cover solver.
    items: Array.isArray(input.items) ? input.items.filter(isRecord).slice(0, PACKAGE_RPC_MAX_ITEMS) as PackageItem[] : [],
    offers: Array.isArray(input.offers) ? input.offers.filter(isRecord).slice(0, PACKAGE_RPC_MAX_OFFERS) as PackageOffer[] : [],
    ocr_corrections: Array.isArray(input.ocr_corrections)
      ? input.ocr_corrections.filter(isRecord) as PackageRpcResponse['ocr_corrections']
      : undefined,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export type { PackageCandidate };
