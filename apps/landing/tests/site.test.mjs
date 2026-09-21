import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { publicationConfig, publicApiUrl, publicUrl } from '../shared/site.mjs';

test('preview needs no destinations and cannot claim indexing', () => {
  assert.deepEqual(publicationConfig({}), {
    siteUrl: '', patientAppEnabled: false, patientUrl: '', providerAccessEnabled: false, providerUrl: '', apiUrl: '', indexable: false,
    testerIntakeEnabled: false, privacyController: '', privacyAddress: '', privacyEmail: '',
    privacyReady: false,
    supportEmail: '',
    testerNoticeVersion: 'android-testers-2026-09-v1',
  });
  assert.throws(() => publicationConfig({ PRUEVIA_INDEXABLE: 'true' }));
});
test('tester intake fails closed without reviewed privacy and API settings', () => {
  assert.equal(publicApiUrl('http://127.0.0.1:8787'), 'http://127.0.0.1:8787');
  assert.throws(() => publicApiUrl('http://api.example.com'));
  assert.throws(() => publicationConfig({ PRUEVIA_TESTER_INTAKE_ENABLED: 'true' }));
  const config = publicationConfig({
    PRUEVIA_TESTER_INTAKE_ENABLED: 'true',
    PRUEVIA_API_URL: 'https://api.example.com',
    PRUEVIA_PRIVACY_CONTROLLER: 'Pruevia Responsable',
    PRUEVIA_PRIVACY_ADDRESS: 'Domicilio revisado, Puebla',
    PRUEVIA_PRIVACY_EMAIL: 'privacidad@example.com',
  });
  assert.equal(config.testerIntakeEnabled, true);
  assert.equal(config.apiUrl, 'https://api.example.com');
});
test('destinations reject unsafe protocols, credentials and tracking', () => {
  for (const url of ['javascript:alert(1)', 'http://example.com', 'https://user:pass@example.com', 'https://example.com?token=x', 'https://example.com#token=x', 'https://example.com:444']) assert.throws(() => publicUrl(url));
});
test('local app destinations are allowed only on loopback during development', () => {
  const config = publicationConfig({
    PRUEVIA_PATIENT_APP_ENABLED: 'true',
    PRUEVIA_PATIENT_URL: 'http://127.0.0.1:8080',
    PRUEVIA_PRIVACY_CONTROLLER: 'Pruevia Responsable',
    PRUEVIA_PRIVACY_ADDRESS: 'Domicilio revisado, Puebla',
    PRUEVIA_PRIVACY_EMAIL: 'privacidad@example.com',
    PRUEVIA_PROVIDER_ACCESS_ENABLED: 'true',
    PRUEVIA_PROVIDER_URL: 'http://localhost:8080',
    PRUEVIA_SUPPORT_EMAIL: 'soporte@example.com',
  });
  assert.equal(config.patientUrl, 'http://127.0.0.1:8080');
  assert.equal(config.providerUrl, 'http://localhost:8080');
  assert.equal(config.supportEmail, 'soporte@example.com');
  assert.throws(() => publicationConfig({ PRUEVIA_PATIENT_APP_ENABLED: 'true', PRUEVIA_PATIENT_URL: 'http://example.com' }));
  assert.throws(() => publicationConfig({ PRUEVIA_SUPPORT_EMAIL: 'not-an-email' }));
});
test('provider access stays closed unless its explicit release gate is enabled', () => {
  const closed = publicationConfig({ PRUEVIA_PROVIDER_URL: 'https://app.example.com' });
  assert.equal(closed.providerAccessEnabled, false);
  assert.equal(closed.providerUrl, '');
  assert.throws(() => publicationConfig({ PRUEVIA_PROVIDER_ACCESS_ENABLED: 'true' }));
});
test('indexable landing requires its site origin and patient release requires privacy contact', () => {
  assert.throws(() => publicationConfig({ PRUEVIA_SITE_URL: 'https://example.com/path' }));
  assert.throws(() => publicationConfig({ PRUEVIA_INDEXABLE: 'true' }));
  assert.equal(publicationConfig({ PRUEVIA_SITE_URL: 'https://example.com/', PRUEVIA_INDEXABLE: 'true' }).siteUrl, 'https://example.com');
  assert.throws(() => publicationConfig({ PRUEVIA_PATIENT_APP_ENABLED: 'true', PRUEVIA_PATIENT_URL: 'https://app.example.com' }));
  assert.equal(publicationConfig({
    PRUEVIA_PATIENT_APP_ENABLED: 'true',
    PRUEVIA_PATIENT_URL: 'https://app.example.com',
    PRUEVIA_PRIVACY_CONTROLLER: 'Responsable Pruevia',
    PRUEVIA_PRIVACY_ADDRESS: 'Domicilio revisado, Puebla',
    PRUEVIA_PRIVACY_EMAIL: 'privacidad@example.com',
  }).patientUrl, 'https://app.example.com');
});

test('integral privacy notice covers pilot data, purposes, Play transfer and ARCO', async () => {
  const notice = await readFile(new URL('../app/pages/privacidad.vue', import.meta.url), 'utf8');
  for (const required of [
    'Responsable y contacto',
    'Datos que recopilaremos',
    'Finalidades necesarias',
    'Google Play y terceros',
    'Cómo ejercer tus derechos',
    'Cambios al aviso',
  ]) assert.match(notice, new RegExp(required));
  assert.match(notice, /Pueden revelar información de salud/);
  assert.match(notice, /Este formulario de testers no solicita datos de salud/);
});

test('closed pilot still renders a disabled form preview', async () => {
  const page = await readFile(new URL('../app/pages/prueba-android.vue', import.meta.url), 'utf8');
  assert.match(page, /Vista previa:/);
  assert.match(page, /:disabled="!available \|\| submitting"/);
  assert.match(page, /Registro aún no disponible/);
});

test('pilot progress waits for a complete active cohort before day one', async () => {
  const page = await readFile(new URL('../app/pages/prueba-android.vue', import.meta.url), 'utf8');
  assert.match(page, /const targetCount = ref\(20\)/);
  assert.match(page, /const testDurationDays = ref\(21\)/);
  assert.match(page, /Día \{\{ testDay \}\} de \{\{ testDurationDays \}\}/);
  assert.match(page, /los \{\{ testDurationDays \}\} días comenzarán cuando las \{\{ targetCount \}\} hayan activado el acceso/);
  assert.doesNotMatch(page, /play\.google\.com/);
});
