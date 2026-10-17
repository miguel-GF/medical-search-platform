import { describe, expect, it, vi } from 'vitest';
import { runScheduledDenueCollection } from '../src/scheduled_denue.js';
import type { Env, RpcClient } from '../src/types.js';

const env: Env = {
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_SECRET_KEY: 'service-role-test-key',
  DENUE_COLLECTION_ENABLED: 'true',
  DENUE_API_TOKEN: 'private-denue-token',
};

describe('scheduled DENUE location collector', () => {
  it('fails closed when disabled or missing its API token', async () => {
    const call = vi.fn();
    const fetcher = vi.fn();
    const disabled = await runScheduledDenueCollection(
      { ...env, DENUE_COLLECTION_ENABLED: 'false' },
      { call: call as RpcClient['call'] },
      1_790_856_000_000,
      fetcher as typeof fetch,
    );
    const missingToken = await runScheduledDenueCollection(
      { ...env, DENUE_API_TOKEN: undefined },
      { call: call as RpcClient['call'] },
      1_790_856_000_000,
      fetcher as typeof fetch,
    );

    expect(disabled).toEqual({ enabled: false, skipped: 'disabled' });
    expect(missingToken).toEqual({ enabled: false, skipped: 'missing_token' });
    expect(fetcher).not.toHaveBeenCalled();
    expect(call).not.toHaveBeenCalled();
  });

  it('collects bounded searches, deduplicates DENUE IDs, and submits candidate locations only', async () => {
    const row = {
      Id: '12345',
      CLEE: 'PUE12345',
      Nombre: 'Laboratorio de prueba',
      Clase_actividad: 'Laboratorios médicos y de diagnóstico',
      Calle: 'Calle de prueba',
      Num_Exterior: '10',
      Colonia: 'Centro',
      CP: '72000',
      Latitud: '19.04',
      Longitud: '-98.20',
      Telefono: '2225550101',
      Correo_e: 'contacto@ejemplo.test',
      Sitio_internet: 'https://ejemplo.test',
    };
    const fetcher = vi.fn(async () => new Response(JSON.stringify([row]), {
      headers: { 'content-type': 'application/json' },
    }));
    const call = vi.fn(async () => ({ status: 'ingested', records: 1 }));

    const result = await runScheduledDenueCollection(
      env,
      { call: call as RpcClient['call'] },
      Date.parse('2026-10-01T14:17:00Z'),
      fetcher as typeof fetch,
    );

    expect(fetcher).toHaveBeenCalledTimes(10);
    expect(result).toMatchObject({
      enabled: true,
      request_id: 'denue-locations-2026-10-v1',
      records: 1,
      result: { status: 'ingested', records: 1 },
    });
    expect(call).toHaveBeenCalledTimes(1);
    expect(call).toHaveBeenCalledWith('api_system_ingest_denue_locations', expect.objectContaining({
      p_request_key: 'denue-locations-2026-10-v1',
      p_records: [expect.objectContaining({
        external_record_id: '12345',
        source_url: 'https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/12345',
        observations: expect.arrayContaining([
          expect.objectContaining({ entity_type: 'provider_location', attribute_name: 'name', status: 'candidate' }),
          expect.objectContaining({ entity_type: 'provider_location', attribute_name: 'coordinates', status: 'candidate' }),
        ]),
      })],
    }), { admin: true });
    const submitted = JSON.stringify(call.mock.calls[0]);
    expect(submitted).not.toContain(env.DENUE_API_TOKEN);
    expect(submitted).not.toContain('service-role-test-key');
    expect(submitted).not.toContain('2225550101');
    expect(submitted).not.toContain('contacto@ejemplo.test');
    expect(submitted).not.toContain('https://ejemplo.test');
    expect(submitted).toContain('Fuente: INEGI, DENUE');
  });

  it('does not write an empty response and redacts upstream errors', async () => {
    const emptyRpc = vi.fn();
    const empty = await runScheduledDenueCollection(
      env,
      { call: emptyRpc as RpcClient['call'] },
      Date.parse('2026-10-01T14:17:00Z'),
      (async () => new Response('[]', { headers: { 'content-type': 'application/json' } })) as typeof fetch,
    );
    expect(empty).toMatchObject({ enabled: true, skipped: 'empty', records: 0 });
    expect(emptyRpc).not.toHaveBeenCalled();

    await expect(runScheduledDenueCollection(
      env,
      { call: emptyRpc as RpcClient['call'] },
      Date.parse('2026-10-01T14:17:00Z'),
      (async () => new Response('not json')) as typeof fetch,
    )).rejects.toThrow('denue_upstream_failed');
    expect(emptyRpc).not.toHaveBeenCalled();
  });
});
