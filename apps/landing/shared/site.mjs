export function publicUrl(value, { allowLoopback = false } = {}) {
  if (!value?.trim()) return '';
  const url = new URL(value.trim());
  const loopback = allowLoopback && url.protocol === 'http:'
    && ['localhost', '127.0.0.1', '::1'].includes(url.hostname);
  if ((!loopback && url.protocol !== 'https:') || url.username || url.password || url.search || url.hash
    || (!loopback && url.port && url.port !== '443')) {
    throw new Error('Public destinations require HTTPS (or loopback HTTP in development) without credentials, query or fragment');
  }
  return url.href.replace(/\/$/, '');
}

export function publicApiUrl(value) {
  if (!value?.trim()) return '';
  const url = new URL(value.trim());
  const loopback = url.protocol === 'http:' && ['localhost', '127.0.0.1', '::1'].includes(url.hostname);
  if ((!loopback && url.protocol !== 'https:') || url.username || url.password || url.search || url.hash
    || (url.pathname !== '' && url.pathname !== '/') || (!loopback && url.port && url.port !== '443')) {
    throw new Error('API_URL must be an HTTPS origin (HTTP is allowed only for loopback development)');
  }
  return url.href.replace(/\/$/, '');
}

function privacyEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('PRIVACY_EMAIL is invalid');
  return email;
}

export function publicationConfig(env) {
  const siteUrl = publicUrl(env.NUXT_PUBLIC_SITE_URL);
  const patientUrl = publicUrl(env.NUXT_PUBLIC_PATIENT_URL, { allowLoopback: true });
  const providerUrl = publicUrl(env.NUXT_PUBLIC_PROVIDER_URL, { allowLoopback: true });
  const apiUrl = publicApiUrl(env.NUXT_PUBLIC_API_URL);
  const indexable = env.NUXT_PUBLIC_INDEXABLE === 'true';
  const testerIntakeEnabled = env.NUXT_PUBLIC_TESTER_INTAKE_ENABLED === 'true';
  const privacyController = String(env.NUXT_PUBLIC_PRIVACY_CONTROLLER || '').trim();
  const privacyAddress = String(env.NUXT_PUBLIC_PRIVACY_ADDRESS || '').trim();
  const privacyEmailAddress = privacyEmail(env.NUXT_PUBLIC_PRIVACY_EMAIL);
  const supportEmail = privacyEmail(env.NUXT_PUBLIC_SUPPORT_EMAIL);
  const testerNoticeVersion = String(env.NUXT_PUBLIC_TESTER_NOTICE_VERSION || 'android-testers-2026-09-v1').trim();
  if (siteUrl && new URL(siteUrl).pathname !== '/') {
    throw new Error('SITE_URL must be an origin');
  }
  if (indexable && (!siteUrl || !patientUrl || new URL(patientUrl).protocol !== 'https:')) {
    throw new Error('Indexing requires reviewed site and patient destinations');
  }
  if (testerIntakeEnabled && (!apiUrl || privacyController.length < 3 || privacyAddress.length < 10
    || !privacyEmailAddress || testerNoticeVersion.length < 3)) {
    throw new Error('Tester intake requires API, controller, address, privacy email and notice version');
  }
  return {
    siteUrl,
    patientUrl,
    providerUrl,
    apiUrl,
    indexable,
    testerIntakeEnabled,
    privacyController,
    privacyAddress,
    privacyEmail: privacyEmailAddress,
    supportEmail,
    testerNoticeVersion,
  };
}
