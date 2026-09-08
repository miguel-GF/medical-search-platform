import { describe, expect, it } from 'vitest';
import {
  buildPackageResolution,
  normalizeBatchRpcPayload,
  parseBatchRequest,
  readCatalogSegments,
  splitBatchText,
} from '../src/batch.js';
import type { PackageItem, PackageOffer, PackageRpcResponse } from '../src/types.js';

const candidate = (serviceId: string, displayName: string) => ({
  service_id: serviceId,
  display_name: displayName,
  matched_term: displayName,
  term_source: 'alias',
  confidence: 1,
  resolution_status: 'resolved' as const,
  match_method: 'exact',
  explanation: {},
});

function item(index: number, input: string, serviceId: string, status: PackageItem['status'] = 'resolved'): PackageItem {
  return {
    index,
    input,
    normalized_query: input.toLowerCase(),
    status,
    candidates: status === 'no_match' ? [] : [candidate(serviceId, input)],
    reason_code: status === 'resolved' ? undefined : status === 'ambiguous' ? 'ambiguous_service' : 'service_not_found',
  };
}

function offer(itemIndex: number, itemId: string, locationId = 'location-ruiz'): PackageOffer {
  return {
    item_index: itemIndex,
    item_id: itemId,
    offer_id: `offer-${itemIndex}`,
    provider_brand_id: 'brand-ruiz',
    provider_name: 'Laboratorio Ruiz',
    provider_location_id: locationId,
    provider_location_name: locationId === 'location-ruiz' ? 'Ruiz Puebla Centro' : 'Ruiz Cholula',
    latitude: 19.04,
    longitude: -98.2,
    distance_meters: locationId === 'location-ruiz' ? 1200 : 8500,
    source_url: 'https://example.test/estudio',
    price_type: 'regular',
    price_key: 'default',
    amount_minor: 10000 + itemIndex,
    currency: 'MXN',
    price_last_seen_at: null,
    requires_quote: false,
  };
}

describe('batch request parser', () => {
  it('parses numbered prescription text into independent studies', () => {
    const result = parseBatchRequest({ text: '1: B H\n2: Q S completa\n3: EGO\n4: Perfil toroideo' });
    expect(result).toEqual(expect.objectContaining({ ok: true }));
    if (result.ok) expect(result.value.items).toEqual(['B H', 'Q S completa', 'EGO', 'Perfil toroideo']);
  });

  it('supports inline numbering, safe comma lists and explicit items', () => {
    expect(splitBatchText('1: BH, 2: EGO, 3: perfil tiroideo')).toEqual(['BH', 'EGO', 'perfil tiroideo']);
    expect(splitBatchText('Biometría hemática, EGO, perfil tiroideo')).toEqual(['Biometría hemática', 'EGO', 'perfil tiroideo']);
    expect(splitBatchText('B H, Q S completa, EGO, Perfil toroideo')).toEqual(['B H', 'Q S completa', 'EGO', 'Perfil toroideo']);
    expect(splitBatchText('ultrasonido renal con Doppler, indicación: dolor')).toEqual(['ultrasonido renal con Doppler, indicación: dolor']);
    const result = parseBatchRequest({ items: [{ text: 'BH' }, 'audiometría'], objective: 'nearest', max_solutions: 3 });
    expect(result).toEqual(expect.objectContaining({ ok: true }));
    if (result.ok) expect(result.value).toMatchObject({ items: ['BH', 'audiometría'], objective: 'nearest', max_solutions: 3 });
  });

  it('marks free-form text separately from an explicit item array', () => {
    const text = parseBatchRequest({ text: 'BH EGO' });
    expect(text).toMatchObject({ ok: true });
    if (text.ok) expect(text.value.input_source).toBe('text');
    const items = parseBatchRequest({ items: ['BH', 'EGO'] });
    expect(items).toMatchObject({ ok: true });
    if (items.ok) expect(items.value.input_source).toBe('items');
  });

  it('accepts only exact catalog segments that reconstruct the source', () => {
    const response = {
      status: 'segmented',
      segments: [
        { text: 'Biometria hematica', method: 'catalog_exact' },
        { text: 'EGO', method: 'catalog_exact' },
      ],
    };
    expect(readCatalogSegments(response, 'Biometria hematica EGO')).toEqual([
      'Biometria hematica',
      'EGO',
    ]);
    expect(readCatalogSegments({ ...response, segments: [{ text: 'BH', method: 'word_fuzzy' }, response.segments[1]] }, 'BH EGO')).toBeNull();
    expect(readCatalogSegments({ ...response, segments: [{ text: 'BH', method: 'catalog_exact' }] }, 'BH EGO')).toBeNull();
    expect(readCatalogSegments({
      ...response,
      segments: [
        { text: 'BH', method: 'catalog_exact' },
        { text: 'QS completa', method: 'catalog_exact_ambiguous' },
      ],
    }, 'BH QS completa')).toEqual(['BH', 'QS completa']);
  });

  it('rejects ambiguous input shapes and unsafe bounds', () => {
    expect(parseBatchRequest({ text: 'BH', items: ['EGO'] })).toMatchObject({ ok: false, error: { code: 'invalid_body' } });
    expect(parseBatchRequest({ items: [] })).toMatchObject({ ok: false, error: { code: 'invalid_items' } });
    expect(parseBatchRequest({ text: 'BH', objective: 'guess' })).toMatchObject({ ok: false, error: { code: 'invalid_objective' } });
    expect(parseBatchRequest({ items: Array.from({ length: 31 }, () => 'BH') })).toMatchObject({ ok: false, error: { code: 'invalid_items' } });
  });
});

describe('compound study parsing', () => {
  it('splits safe study conjunctions without splitting ordinary phrases', () => {
    expect(splitBatchText('Glucosa e Insulina')).toEqual(['Glucosa', 'Insulina']);
    expect(splitBatchText('BH y EGO')).toEqual(['BH', 'EGO']);
    expect(splitBatchText('prueba e insulina')).toEqual(['prueba e insulina']);
  });
});

describe('deterministic package solver', () => {
  it('drops malformed RPC array entries before solving', () => {
    const normalized = normalizeBatchRpcPayload({
      items: [null, item(1, 'BH', 'bh'), 'invalid'],
      offers: [null, offer(1, 'bh'), 42],
      ocr_corrections: [null, { index: 1, input: 'BH' }],
    });
    expect(normalized.items).toHaveLength(1);
    expect(normalized.offers).toHaveLength(1);
    expect(normalized.ocr_corrections).toHaveLength(1);
  });

  it('caps hostile RPC arrays before package solving', () => {
    const normalized = normalizeBatchRpcPayload({
      items: Array.from({ length: 100 }, (_, index) => item(index + 1, 'BH', `bh-${index}`)),
      offers: Array.from({ length: 5_005 }, (_, index) => offer(1, `bh-${index}`)),
    });
    expect(normalized.items).toHaveLength(60);
    expect(normalized.offers).toHaveLength(5_000);
    expect(buildPackageResolution({ ...normalized, engine_version: 'test' }, 'BH', 'all_in_one', 1).solutions).toHaveLength(1);
  });

  it('does not invent a package when a prescription has unresolved studies', () => {
    const payload: PackageRpcResponse = {
      engine_version: 'clinical-resolver-v6',
      items: [item(1, 'B H', 'bh'), item(2, 'Q S completa', 'qs', 'ambiguous'), item(3, 'EGO', 'ego'), item(4, 'Perfil toroideo', 'tiroideo', 'ambiguous')],
      offers: [offer(1, 'bh'), offer(3, 'ego')],
    };
    const result = buildPackageResolution(payload, '1: B H\n2: Q S completa\n3: EGO\n4: Perfil toroideo', 'all_in_one', 10);
    expect(result.package_status).toBe('needs_clarification');
    expect(result.coverage_status).toBe('none');
    expect(result.clarifications.map((entry) => entry.index)).toEqual([2, 4]);
    expect(result.solutions).toEqual([]);
  });

  it('keeps OCR corrections auditable while using the resolver result', () => {
    const payload: PackageRpcResponse = {
      engine_version: 'clinical-resolver-v6',
      items: [{
        ...item(1, 'OBH', 'bh'),
        ocr_correction: {
          suggested_text: 'BH',
          correction_type: 'character_confusion',
          confidence: 0.98,
          source_note: 'curated OCR rule',
        },
      }],
      offers: [],
      ocr_corrections: [{
        index: 1,
        input: 'OBH',
        suggested_text: 'BH',
        correction_type: 'character_confusion',
        confidence: 0.98,
        source_note: 'curated OCR rule',
      }],
    };
    const result = buildPackageResolution(payload, 'OBH', 'all_in_one', 10);
    expect(result.items[0].input).toBe('OBH');
    expect(result.items[0].ocr_correction?.suggested_text).toBe('BH');
    expect(result.ocr_corrections?.[0]).toMatchObject({ input: 'OBH', suggested_text: 'BH' });
  });

  it('covers arbitrary unrelated studies at one provider branch', () => {
    const payload: PackageRpcResponse = {
      engine_version: 'clinical-resolver-v6',
      items: [item(1, 'BH', 'bh'), item(2, 'Audiometría', 'audio'), item(3, 'Ultrasonido renal', 'renal')],
      offers: [offer(1, 'bh'), offer(2, 'audio'), offer(3, 'renal')],
    };
    const result = buildPackageResolution(payload, 'BH, Audiometría, Ultrasonido renal', 'all_in_one', 10);
    expect(result.package_status).toBe('ready');
    expect(result.coverage_status).toBe('complete');
    expect(result.solutions[0]).toMatchObject({ coverage_count: 3, requested_count: 3, location_count: 1, missing_item_indexes: [] });
  });

  it('does not count offers for a low-confidence no-match candidate', () => {
    const payload: PackageRpcResponse = {
      engine_version: 'clinical-resolver-v6',
      items: [
        item(1, 'Glucosa', 'glucose'),
        {
          ...item(2, 'Insulina', 'anti-insulina', 'no_match'),
          candidates: [{
            ...candidate('anti-insulina', 'AC ANTI INSULINA (M)'),
            confidence: 0.5,
            resolution_status: 'ambiguous',
            match_method: 'word_fuzzy',
            explanation: { requires_confirmation: true },
          }],
          reason_code: 'low_confidence_match',
        },
      ],
      offers: [offer(1, 'glucose'), offer(2, 'anti-insulina')],
    };
    const result = buildPackageResolution(payload, 'Glucosa, Insulina', 'all_in_one', 10);
    expect(result.package_status).toBe('partial');
    expect(result.solutions[0].coverage_count).toBe(1);
    expect(result.solutions[0].missing_item_indexes).toEqual([2]);
  });

  it('finds a complete solution across two branches and reports partial coverage', () => {
    const payload: PackageRpcResponse = {
      engine_version: 'clinical-resolver-v6',
      items: [item(1, 'BH', 'bh'), item(2, 'EGO', 'ego'), item(3, 'Glucosa', 'glucose')],
      offers: [offer(1, 'bh', 'location-ruiz'), offer(2, 'ego', 'location-ruiz'), offer(3, 'glucose', 'location-other')],
    };
    const result = buildPackageResolution(payload, 'BH, EGO, glucosa', 'all_in_one', 10);
    expect(result.coverage_status).toBe('complete');
    expect(result.solutions[0]).toMatchObject({ coverage_count: 3, location_count: 2 });

    const partial = buildPackageResolution({ ...payload, offers: [offer(1, 'bh', 'location-ruiz')] }, 'BH, EGO, glucosa', 'all_in_one', 10);
    expect(partial.coverage_status).toBe('partial');
    expect(partial.solutions[0].missing_item_indexes).toEqual([2, 3]);
    expect(partial.solutions[0].requires_quote).toBe(true);
  });
});
