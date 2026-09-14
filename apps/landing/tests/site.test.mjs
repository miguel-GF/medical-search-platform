import { test } from 'node:test';
import assert from 'node:assert/strict';
import { publicationConfig, publicUrl } from '../shared/site.mjs';

test('preview needs no destinations and cannot claim indexing', () => {
  assert.deepEqual(publicationConfig({}), { siteUrl: '', patientUrl: '', indexable: false });
  assert.throws(() => publicationConfig({ NUXT_PUBLIC_INDEXABLE: 'true' }));
});
test('destinations reject unsafe protocols, credentials and tracking', () => {
  for (const url of ['javascript:alert(1)', 'http://example.com', 'https://user:pass@example.com', 'https://example.com?token=x', 'https://example.com#token=x', 'https://example.com:444']) assert.throws(() => publicUrl(url));
});
test('indexable build requires both configured destinations and a site origin', () => {
  assert.throws(() => publicationConfig({ NUXT_PUBLIC_SITE_URL: 'https://example.com/path' }));
  assert.throws(() => publicationConfig({ NUXT_PUBLIC_SITE_URL: 'https://example.com', NUXT_PUBLIC_INDEXABLE: 'true' }));
  assert.equal(publicationConfig({ NUXT_PUBLIC_SITE_URL: 'https://example.com/', NUXT_PUBLIC_PATIENT_URL: 'https://app.example.com', NUXT_PUBLIC_INDEXABLE: 'true' }).siteUrl, 'https://example.com');
});
