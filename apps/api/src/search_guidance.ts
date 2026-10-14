import type { RpcClient } from './types.js';
import { SupabaseConfigurationError, SupabaseRpcError } from './supabase.js';

export interface SearchGuidanceOption {
  item_id: string;
  display_name: string;
  detail: string;
  verification: 'current_catalog' | 'reviewed_catalog_snapshot';
}

export interface SearchGuidance {
  kind: 'specimen';
  specimen: 'blood' | 'urine';
  title: string;
  message: string;
  catalogue_reviewed_on: string;
  options: SearchGuidanceOption[];
}

interface Example {
  id: string;
  query: string;
  detail: string;
}

const examples: Record<'blood' | 'urine', Example[]> = {
  blood: [
    {
      id: '00000000-0000-0000-0000-000000001103',
      query: 'Biometría hemática',
      detail: 'Recuento y características de las células de la sangre.',
    },
    {
      id: '00000000-0000-0000-0000-000000001109',
      query: 'Glucosa',
      detail: 'Medición de glucosa. Revisa las condiciones que indica tu orden.',
    },
    {
      id: '78322e0d-fa32-58a4-98e4-ec538743eb49',
      query: 'Hemoglobina glicosilada (HbA1c)',
      detail: 'Hemoglobina glicosilada. Confirma la muestra y las condiciones con el proveedor.',
    },
    {
      id: '3aa94396-81e6-59ea-982a-3ece64e10fbf',
      query: 'Grupo sanguíneo y factor Rh (ABO/Rh)',
      detail: 'Clasificación conjunta del grupo ABO y el factor Rh. Confirma la muestra con el proveedor.',
    },
  ],
  urine: [
    {
      id: '00000000-0000-0000-0000-000000001104',
      query: 'Examen general de orina',
      detail: 'Examen general; es distinto de un cultivo y de una recolección de 24 horas.',
    },
    {
      id: '075b5a83-c228-5126-add0-7d916dcbbc86',
      query: 'Urocultivo (cultivo de orina)',
      detail: 'Cultivo de una muestra de orina. Revisa si tu orden incluye estudios adicionales.',
    },
    {
      id: '070781f6-e7b1-5807-a5d2-a915ccaa96a3',
      query: 'Creatinina en primera orina matutina',
      detail: 'Creatinina en una muestra de la primera orina de la mañana.',
    },
    {
      id: '2d663c0d-a45f-53e0-a9dd-c61d5d01c33a',
      query: 'Creatinina en orina de 24 horas',
      detail: 'Creatinina en una recolección de 24 horas.',
    },
    {
      id: 'c73ca1b9-ccef-53b5-8d40-8a20dad76dd6',
      query: 'Proteínas en orina de 24 horas',
      detail: 'Proteínas en una recolección de 24 horas.',
    },
  ],
};

export function specimenSearchIntent(query: string): 'blood' | 'urine' | null {
  const text = query.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().trim().replace(/\s+/g, ' ');
  if (/^(?:(?:analisis|estudios?|examen(?:es)?|pruebas?)(?: de| en)? )?sangre$/.test(text)) return 'blood';
  if (/^(?:(?:analisis|estudios?|examen(?:es)?|pruebas?)(?: de| en)? )?orina$/.test(text)) return 'urine';
  return null;
}

/** Browsing guidance: does not resolve a broad specimen as a medical order. */
export async function specimenSearchGuidance(query: string, rpc: RpcClient): Promise<SearchGuidance | null> {
  const specimen = specimenSearchIntent(query);
  if (!specimen) return null;
  const options = await Promise.all(examples[specimen].map(async (example): Promise<SearchGuidanceOption | null> => {
    try {
      // Check each known example against the current public clinical contract.
      // Keep no private explanation, prices or offers in browsing suggestions.
      const payload = await rpc.call<{
        status?: string;
        candidates?: Array<{ service_id?: string; display_name?: string; match_method?: string }>;
      }>('api_resolve_search', {
        p_query: example.query, p_domain_code: 'health_diagnostics',
        p_latitude: null, p_longitude: null, p_location_id: null, p_limit: 1,
      });
      const first = payload?.candidates?.[0];
      if (payload?.status !== 'resolved' || first?.service_id !== example.id
          || !['exact', 'approved_alias'].includes(first?.match_method ?? '')
          || typeof first.display_name !== 'string' || !first.display_name.trim()
          || first.display_name.length > 200) return null;
      return { item_id: example.id, display_name: first.display_name, detail: example.detail,
        verification: 'current_catalog' as const };
    } catch (error) {
      // These predefined names/IDs were individually observed against the
      // productive catalog on 2026-10-14. Keep browsing separate from resolving
      // an order or asserting a current offer while connectivity is unavailable.
      if (!(error instanceof SupabaseConfigurationError)
          && !(error instanceof SupabaseRpcError && !error.retryable)) {
        return { item_id: example.id, display_name: example.query, detail: example.detail,
          verification: 'reviewed_catalog_snapshot' as const };
      }
      // Configuration, permissions and a changed catalog do not get a fallback.
      return null;
    }
  }));
  const available = options.filter((option): option is SearchGuidanceOption => option !== null);
  const snapshot = available.some(option => option.verification === 'reviewed_catalog_snapshot');
  return {
    kind: 'specimen', specimen,
    catalogue_reviewed_on: '2026-10-14',
    title: specimen === 'blood' ? '¿Qué estudio de sangre buscas?' : '¿Qué estudio de orina buscas?',
    message: snapshot
      ? 'Opciones del catálogo revisado el 14 de octubre. No podemos consultar proveedores ahora; revisa cuál coincide con tu orden.'
      : 'La muestra puede usarse para estudios distintos. Elige el nombre que coincide con tu orden para consultar sus opciones.',
    options: available,
  };
}
