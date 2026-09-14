export function publicUrl(value) {
  if (!value?.trim()) return '';
  const url = new URL(value.trim());
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash
    || (url.port && url.port !== '443')) {
    throw new Error('Public destinations require an HTTPS URL without credentials, query or fragment');
  }
  return url.href.replace(/\/$/, '');
}

export function publicationConfig(env) {
  const siteUrl = publicUrl(env.NUXT_PUBLIC_SITE_URL);
  const patientUrl = publicUrl(env.NUXT_PUBLIC_PATIENT_URL);
  const indexable = env.NUXT_PUBLIC_INDEXABLE === 'true';
  if (siteUrl && new URL(siteUrl).pathname !== '/') {
    throw new Error('SITE_URL must be an origin');
  }
  if (indexable && (!siteUrl || !patientUrl)) {
    throw new Error('Indexing requires reviewed site and patient destinations');
  }
  return { siteUrl, patientUrl, indexable };
}
