import type { Env, RpcClient } from './types.js';

const DENUE_BASE_URL = 'https://www.inegi.org.mx/app/api/denue/v1/consulta';
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
const MAX_BATCH_RECORDS = 1_000;
const MAX_BATCH_BYTES = 3 * 1024 * 1024;
const REQUEST_TIMEOUT_MS = 12_000;
const RADIUS_METERS = 5_000;
const COLLECTOR_VERSION = 'v1';

const CENTERS = [
  { name: 'puebla', latitude: 19.0437, longitude: -98.1982 },
  { name: 'cholula_san_pedro', latitude: 19.0641, longitude: -98.3035 },
  { name: 'cholula_san_andres', latitude: 19.0514, longitude: -98.2952 },
  { name: 'amozoc', latitude: 19.0431, longitude: -98.0452 },
  { name: 'tlaxcala', latitude: 19.3182, longitude: -98.2375 },
] as const;
const SEARCH_TERMS = ['laboratorio', 'análisis clínicos'] as const;

type JsonObject = Record<string, unknown>;
type DenueObservation = {
  entity_type: 'provider_location';
  attribute_name: string;
  observed_value: unknown;
  confidence: 1;
  status: 'candidate';
};
type DenueRecord = {
  external_record_id: string;
  source_url: string;
  payload: JsonObject;
  observations: DenueObservation[];
};

export interface ScheduledDenueResult {
  enabled: boolean;
  skipped?: 'disabled' | 'missing_token' | 'empty';
  request_id?: string;
  records?: number;
  result?: Record<string, unknown>;
}

/**
 * Collect a small monthly location-only snapshot from the official DENUE API.
 * The database RPC rechecks persisted source approval and writes only RAW
 * evidence; this function cannot create providers, services, offers, or prices.
 */
export async function runScheduledDenueCollection(
  env: Env,
  rpc: RpcClient = {
    call: async () => { throw new Error('RPC client is required'); },
  },
  scheduledTime = Date.now(),
  fetcher: typeof fetch = globalThis.fetch.bind(globalThis),
): Promise<ScheduledDenueResult> {
  if (env.DENUE_COLLECTION_ENABLED !== 'true') return { enabled: false, skipped: 'disabled' };
  const token = env.DENUE_API_TOKEN?.trim() ?? '';
  if (!token || token.length > 256 || /[\u0000-\u001f\u007f]/.test(token)) {
    return { enabled: false, skipped: 'missing_token' };
  }

  const date = new Date(scheduledTime);
  if (!Number.isFinite(date.getTime())) throw new Error('invalid_scheduled_time');
  const requestId = `denue-locations-${date.toISOString().slice(0, 7)}-${COLLECTOR_VERSION}`;
  const records = new Map<string, DenueRecord>();

  for (const center of CENTERS) {
    for (const condition of SEARCH_TERMS) {
      const query = { ...center, condition, radius_meters: RADIUS_METERS };
      const rows = await fetchDenueRows(query, token, fetcher);
      for (const row of rows) {
        // Retain only fields useful to identify and locate an establishment.
        // DENUE also returns phone, email and website fields; they are not
        // needed by this pilot and are deliberately neither stored nor logged.
        const safeRow = minimizeDenueRow(row);
        const externalId = getText(safeRow, ['Id', 'CLEE']);
        if (!externalId || externalId.length > 256 || !/^[A-Za-z0-9_-]+$/.test(externalId)) {
          throw new Error('invalid_denue_record_identity');
        }
        const sourceUrl = `${DENUE_BASE_URL}/Ficha/${externalId}`;
        const previous = records.get(externalId);
        if (previous) {
          if (stableJson(stripPrueviaFields(previous.payload)) !== stableJson(safeRow)) {
            throw new Error('inconsistent_duplicate_denue_record');
          }
          const queries = previous.payload._pruevia_queries;
          if (Array.isArray(queries)) queries.push(query);
          continue;
        }
        records.set(externalId, {
          external_record_id: externalId,
          source_url: sourceUrl,
          payload: {
          ...safeRow,
            _pruevia_source_url: sourceUrl,
            _pruevia_source_citation: 'Fuente: INEGI, DENUE',
            _pruevia_collector_version: COLLECTOR_VERSION,
            _pruevia_queries: [query],
          },
          observations: buildObservations(safeRow),
        });
        if (records.size > MAX_BATCH_RECORDS) throw new Error('denue_batch_record_limit_exceeded');
      }
    }
  }

  if (records.size === 0) return { enabled: true, skipped: 'empty', request_id: requestId, records: 0 };
  const batch = [...records.values()];
  if (new TextEncoder().encode(JSON.stringify(batch)).byteLength > MAX_BATCH_BYTES) {
    throw new Error('denue_batch_size_limit_exceeded');
  }
  const result = await rpc.call<Record<string, unknown>>('api_system_ingest_denue_locations', {
    p_request_key: requestId,
    p_records: batch,
  }, { admin: true });
  return { enabled: true, request_id: requestId, records: batch.length, result };
}

async function fetchDenueRows(
  query: { latitude: number; longitude: number; condition: string; radius_meters: number },
  token: string,
  fetcher: typeof fetch,
): Promise<JsonObject[]> {
  const url = `${DENUE_BASE_URL}/Buscar/${encodeURIComponent(query.condition)}/${query.latitude.toFixed(8)},${query.longitude.toFixed(8)}/${query.radius_meters}/${encodeURIComponent(token)}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort('denue_timeout'), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetcher(url, {
      method: 'GET',
      headers: { Accept: 'application/json', 'User-Agent': 'PrueviaCollector/0.1 (+https://pruevia.com.mx)' },
      redirect: 'manual',
      cache: 'no-store',
      signal: controller.signal,
    });
    if (!response.ok) throw new Error('denue_upstream_status');
    const payload = await readBoundedJson(response);
    return decodeRows(payload);
  } catch {
    // The token is part of the official API path. Never propagate the fetch
    // exception or URL to logs, the database, or the scheduled event output.
    if (controller.signal.aborted) throw new Error('denue_upstream_timeout');
    throw new Error('denue_upstream_failed');
  } finally {
    clearTimeout(timer);
  }
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const encoding = response.headers.get('content-encoding')?.trim().toLowerCase() ?? '';
  if (encoding !== '' && encoding !== 'identity') throw new Error('compressed_response_rejected');
  const length = response.headers.get('content-length');
  if (length !== null && (!/^\d{1,10}$/.test(length) || Number(length) > MAX_RESPONSE_BYTES)) {
    throw new Error('response_too_large');
  }
  const reader = response.body?.getReader();
  if (!reader) {
    if (length !== null && Number(length) !== 0) throw new Error('response_length_mismatch');
    return null;
  }
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const result = await reader.read();
      if (result.done) break;
      size += result.value.byteLength;
      if (size > MAX_RESPONSE_BYTES) throw new Error('response_too_large');
      chunks.push(result.value);
    }
  } catch (error) {
    try { await reader.cancel(); } catch { /* best-effort cleanup */ }
    throw error;
  } finally {
    reader.releaseLock();
  }
  if (length !== null && size !== Number(length)) throw new Error('response_length_mismatch');
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(bytes)) as unknown;
  } catch {
    throw new Error('invalid_denue_json');
  }
}

function decodeRows(value: unknown): JsonObject[] {
  let rows: unknown = value;
  if (isJsonObject(value)) {
    rows = value.data ?? value.Data ?? value.resultados ?? value.Resultados ?? value.establecimientos;
  }
  if (!Array.isArray(rows) || rows.length > 20_000 || rows.some(row => !isJsonObject(row))) {
    throw new Error('invalid_denue_response_shape');
  }
  return rows as JsonObject[];
}

function buildObservations(row: JsonObject): DenueObservation[] {
  const result: DenueObservation[] = [];
  const fields: Array<[string, string[]]> = [
    ['name', ['Nombre', 'nombre', 'Nombre_del_establecimiento']],
    ['activity_code', ['Clase_actividad', 'clase_actividad']],
    ['postal_code', ['CP', 'Codigo_postal', 'Código_postal']],
  ];
  for (const [attribute, keys] of fields) {
    const value = getValue(row, keys);
    if (value !== undefined && value !== null && value !== '') result.push(observation(attribute, value));
  }

  const address: JsonObject = {};
  const addressFields: Array<[string, string[]]> = [
    ['street', ['Calle', 'calle', 'vialidad']],
    ['exterior_number', ['Num_Exterior', 'Numero_exterior']],
    ['interior_number', ['Num_Interior', 'Numero_interior']],
    ['neighborhood', ['Colonia', 'colonia', 'asentamiento']],
    ['postal_code', ['CP', 'Codigo_postal', 'Código_postal']],
    ['locality', ['Localidad', 'localidad']],
    ['municipality', ['Municipio', 'municipio']],
    ['state', ['Entidad', 'entidad', 'estado']],
    ['location_label', ['Ubicacion', 'ubicacion']],
  ];
  for (const [key, aliases] of addressFields) {
    const value = getValue(row, aliases);
    if (value !== undefined && value !== null && value !== '') address[key] = value;
  }
  if (Object.keys(address).length) result.push(observation('address', address));

  const latitude = Number(getValue(row, ['Latitud', 'latitud']));
  const longitude = Number(getValue(row, ['Longitud', 'longitud']));
  if (Number.isFinite(latitude) && Number.isFinite(longitude)
    && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180) {
    result.push(observation('latitude', latitude), observation('longitude', longitude));
    result.push(observation('coordinates', { latitude, longitude }));
  }
  return result;
}

function minimizeDenueRow(row: JsonObject): JsonObject {
  const fields: Array<[string, string[]]> = [
    ['Id', ['Id', 'id']],
    ['CLEE', ['CLEE', 'clee']],
    ['Nombre', ['Nombre', 'nombre', 'Nombre_del_establecimiento']],
    ['Clase_actividad', ['Clase_actividad', 'clase_actividad']],
    ['Tipo_vialidad', ['Tipo_vialidad', 'tipo_vialidad']],
    ['Calle', ['Calle', 'calle']],
    ['Num_Exterior', ['Num_Exterior', 'Numero_exterior']],
    ['Num_Interior', ['Num_Interior', 'Numero_interior']],
    ['Colonia', ['Colonia', 'colonia']],
    ['CP', ['CP', 'Codigo_postal', 'Código_postal']],
    ['Ubicacion', ['Ubicacion', 'ubicacion']],
    ['Tipo', ['Tipo', 'tipo']],
    ['Longitud', ['Longitud', 'longitud']],
    ['Latitud', ['Latitud', 'latitud']],
    ['AGEB', ['AGEB', 'ageb']],
    ['Manzana', ['Manzana', 'manzana']],
    ['Fecha_Alta', ['Fecha_Alta', 'fecha_alta']],
  ];
  const result: JsonObject = {};
  for (const [outputKey, aliases] of fields) {
    const value = getValue(row, aliases);
    if (value !== undefined && value !== null && value !== '') result[outputKey] = value;
  }
  return result;
}

function observation(attribute_name: string, observed_value: unknown): DenueObservation {
  return { entity_type: 'provider_location', attribute_name, observed_value, confidence: 1, status: 'candidate' };
}

function getValue(row: JsonObject, aliases: string[]): unknown {
  const names = new Set(aliases.map(normalizeKey));
  for (const [key, value] of Object.entries(row)) {
    if (names.has(normalizeKey(key)) && value !== undefined && value !== null && value !== '') return value;
  }
  return undefined;
}

function getText(row: JsonObject, aliases: string[]): string | null {
  const value = getValue(row, aliases);
  return typeof value === 'string' || typeof value === 'number' ? String(value).trim() || null : null;
}

function normalizeKey(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

function isJsonObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (isJsonObject(value)) {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value) ?? 'null';
}

function stripPrueviaFields(payload: JsonObject): JsonObject {
  return Object.fromEntries(Object.entries(payload).filter(([key]) => !key.startsWith('_pruevia_')));
}
