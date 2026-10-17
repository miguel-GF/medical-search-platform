import type { RpcClient } from './types.js';

export interface CatalogSearchSuggestion { item_id: string; display_name: string }
interface Term { id: string; name: string; tokens: string[] }
interface CachedTerms { expires: number; terms?: Term[]; pending?: Promise<Term[]> }
const cache = new Map<string, CachedTerms>();
const TTL_MS = 5 * 60_000;
const PAGE_SIZE = 500;
const MAX_ROWS = 5_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STOP = new Set(['a', 'al', 'de', 'del', 'el', 'en', 'la', 'las', 'los', 'para', 'por', 'y']);
// These qualifiers must be literal. A suggestion may never silently repair an
// isotype, specimen, acquisition variant, contrast, side or measurement unit.
const LITERAL = new Set(['igg', 'igm', 'iga', 'ige', 'igd', 'pcr', 'rna', 'dna',
  'suero', 'serum', 'plasma', 'sangre', 'blood', 'orina', 'urine', 'saliva',
  'heces', 'stool', 'nasal', 'semen', 'lcr', 'total', 'totales', 'libre',
  'libres', 'directa', 'indirecta', 'beta', 'alfa', 'alpha', 'sin', 'con',
  'contraste', 'reposo', 'esfuerzo', 'pediatrico', 'izquierdo', 'derecho',
  'bilateral', 'matutina', 'ayuno', '24', 'horas', 'minutos']);

function tokens(text: string): string[] {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ').trim().split(/\s+/).filter(v => v && !STOP.has(v));
}

export function hepaticSearchNotice(query: string): string | undefined {
  if (!tokens(query).some(t => /^(?:hepatic[ao]s?|hepatic)$/.test(t))) return undefined;
  return 'No tenemos un perfil hepático verificado. Estos estudios individuales no sustituyen el perfil de tu orden. Elige solo el nombre que aparece en ella o usa Resolver con receta.';
}

// Exploration of individual approved studies, not a panel definition or a
// recommended set. Relationship reviewed 2026-10-16 against MedlinePlus:
// https://medlineplus.gov/spanish/pruebas-de-laboratorio/pruebas-funcionales-hepaticas/
const HEPATIC_INDIVIDUALS: Array<[string, string]> = [
  ['c412ce8e-0a96-55f1-b2bf-4ac490cdeff6', 'Alanina aminotransferasa (ALT/TGP)'],
  ['217cd597-da6b-53e2-aa6e-108ea4e93934', 'Aspartato aminotransferasa (AST/TGO)'],
  ['b1c45cd0-ac60-5b46-9032-a24c02ff9f9d', 'Gammaglutamil transferasa (GGT)'],
  ['bd809424-ae9f-5815-b772-3584b82ea05b', 'Bilirrubina total'],
  ['c85f9219-f105-5865-85a8-094e65409e8e', 'Fosfatasa alcalina (ALP)'],
];
const HEPATIC_BROWSING_WORDS = new Set(['perfil', 'perfiles', 'panel', 'paneles',
  'prueba', 'pruebas', 'funcion', 'funciones', 'biometria', 'hepatic', 'hepatica',
  'hepaticas', 'hepatico', 'hepaticos']);

function record(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

async function readTerms(rpc: RpcClient): Promise<Term[]> {
  const terms: Term[] = [];
  for (let offset = 0; offset < MAX_ROWS; offset += PAGE_SIZE) {
    const page = await rpc.call<unknown>('api_admin_catalog_terms', {
      p_limit: PAGE_SIZE, p_offset: offset,
    }, { admin: true });
    if (!Array.isArray(page) || page.length > PAGE_SIZE) throw new Error('CATALOG_TERMS_FORMAT');
    for (const row of page) {
      // Provider-only aliases are evidence for their source, not public synonyms.
      if (!record(row) || row.provider_brand_id != null
        || !['name', 'alias'].includes(String(row.term_type))
        || typeof row.item_id !== 'string' || !UUID.test(row.item_id)
        || typeof row.display_name !== 'string' || !row.display_name.trim()
        || row.display_name.length > 200 || typeof row.term !== 'string'
        || row.term.length > 200) continue;
      terms.push({ id: row.item_id, name: row.display_name, tokens: tokens(row.term) });
    }
    if (page.length < PAGE_SIZE) break;
  }
  return terms;
}

async function catalogTerms(rpc: RpcClient, backend: string | undefined): Promise<Term[]> {
  // No global sharing without an actual configured backend. Never key by a
  // credential or cache a query/patient value. Each isolate keeps at most 4 DBs.
  if (!backend) return readTerms(rpc);
  const existing = cache.get(backend);
  if (existing?.pending) return existing.pending;
  if (existing?.terms && existing.expires > Date.now()) return existing.terms;
  if (cache.size >= 4 && !cache.has(backend)) cache.delete(cache.keys().next().value!);
  const entry: CachedTerms = { expires: 0 };
  entry.pending = readTerms(rpc).then(terms => {
    entry.terms = terms; entry.expires = Date.now() + TTL_MS; entry.pending = undefined;
    return terms;
  }).catch(error => { cache.delete(backend); throw error; });
  cache.set(backend, entry);
  return entry.pending;
}

function distance(a: string, b: string, cap: number): number {
  if (Math.abs(a.length - b.length) > cap) return cap + 1;
  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const current = [i];
    for (let j = 1; j <= b.length; j++) current[j] = Math.min(
      previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
    );
    previous = current;
  }
  return previous[b.length];
}

function tokenScore(query: string, candidate: string): number {
  if (query === candidate) return 100;
  if (query.length < 5 || candidate.length < 5 || LITERAL.has(query)
    || LITERAL.has(candidate) || /\d/.test(query + candidate)) return 0;
  if (candidate.startsWith(query) && query.length / candidate.length >= .55) return 80;
  if (query.length < 7 || candidate.length < 7) return 0;
  const cap = Math.min(query.length, candidate.length) >= 12 ? 3 : 2;
  const edits = distance(query, candidate, cap);
  return edits <= cap && edits / Math.max(query.length, candidate.length) <= .24 ? 70 - edits * 8 : 0;
}

function score(query: string[], candidate: string[]): number {
  if (query.length > candidate.length || query.length > 12) return 0;
  const used = new Set<number>();
  let result = 0;
  for (const word of query) {
    let best = 0, at = -1;
    for (let i = 0; i < candidate.length; i++) {
      if (used.has(i)) continue;
      const value = tokenScore(word, candidate[i]);
      if (value > best) { best = value; at = i; }
    }
    if (at < 0) return 0;
    used.add(at); result += best;
  }
  return result / query.length - (candidate.length - query.length);
}

/** Navigation only: never a resolution, alias approval, diagnosis or offer. */
export async function catalogSearchSuggestions(
  query: string, rpc: RpcClient, backend?: string,
): Promise<CatalogSearchSuggestion[]> {
  if (hepaticSearchNotice(query)) {
    // A family lookup is not permission to drop urine, isotype, collection time
    // or any other qualifier supplied alongside it.
    return tokens(query).every(word => HEPATIC_BROWSING_WORDS.has(word))
      ? verifyCatalogSearchSuggestions(HEPATIC_INDIVIDUALS, rpc) : [];
  }
  const input = tokens(query);
  if (!input.length || !input.some(t => t.length >= 5) || input.length > 12) return [];
  const candidates = new Map<string, { name: string; score: number }>();
  for (const term of await catalogTerms(rpc, backend)) {
    const value = score(input, term.tokens);
    if (value > 0 && value > (candidates.get(term.id)?.score ?? 0)) {
      candidates.set(term.id, { name: term.name, score: value });
    }
  }
  const ranked = [...candidates.entries()].sort((a, b) => b[1].score - a[1].score || a[0].localeCompare(b[0])).slice(0, 5);
  return verifyCatalogSearchSuggestions(ranked.map(([id, candidate]) => [id, candidate.name]), rpc);
}

export async function verifyCatalogSearchSuggestions(
  candidates: Array<[string, string]>, rpc: RpcClient,
): Promise<CatalogSearchSuggestion[]> {
  const verified = await Promise.all(candidates.slice(0, 5).map(async ([id, name]): Promise<CatalogSearchSuggestion | null> => {
    try {
      const payload = await rpc.call<unknown>('api_resolve_search', {
        p_query: name, p_domain_code: 'health_diagnostics',
        p_latitude: null, p_longitude: null, p_location_id: null, p_limit: 5,
      });
      if (!record(payload) || payload.status !== 'resolved' || !Array.isArray(payload.candidates)) return null;
      const match = payload.candidates.find(row => record(row) && row.service_id === id);
      if (!record(match) || match.resolution_status !== 'resolved'
        || !['exact', 'approved_alias'].includes(String(match.match_method))
        || match.display_name !== name) return null;
      return { item_id: id, display_name: name };
    } catch { return null; }
  }));
  return verified.filter((value): value is CatalogSearchSuggestion => value !== null);
}
