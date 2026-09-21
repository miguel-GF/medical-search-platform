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
  const siteUrl = publicUrl(env.PRUEVIA_SITE_URL);
  const patientAppEnabled = env.PRUEVIA_PATIENT_APP_ENABLED === 'true';
  const patientUrl = patientAppEnabled
    ? publicUrl(env.PRUEVIA_PATIENT_URL, { allowLoopback: true })
    : '';
  const providerAccessEnabled = env.PRUEVIA_PROVIDER_ACCESS_ENABLED === 'true';
  const configuredProviderUrl = providerAccessEnabled
    ? publicUrl(env.PRUEVIA_PROVIDER_URL, { allowLoopback: true })
    : '';
  const providerUrl = providerAccessEnabled ? configuredProviderUrl : '';
  const apiUrl = publicApiUrl(env.PRUEVIA_API_URL);
  const indexable = env.PRUEVIA_INDEXABLE === 'true';
  const testerIntakeEnabled = env.PRUEVIA_TESTER_INTAKE_ENABLED === 'true';
  const privacyController = String(env.PRUEVIA_PRIVACY_CONTROLLER || '').trim();
  const privacyAddress = String(env.PRUEVIA_PRIVACY_ADDRESS || '').trim();
  const privacyEmailAddress = privacyEmail(env.PRUEVIA_PRIVACY_EMAIL);
  const privacyReady = privacyController.length >= 3
    && privacyAddress.length >= 10
    && Boolean(privacyEmailAddress);
  const supportEmail = privacyEmail(env.PRUEVIA_SUPPORT_EMAIL);
  const testerNoticeVersion = String(env.PRUEVIA_TESTER_NOTICE_VERSION || 'android-testers-2026-09-v1').trim();
  const patientTarget = patientUrl ? new URL(patientUrl) : null;
  const patientLoopback = patientTarget?.protocol === 'http:'
    && ['localhost', '127.0.0.1', '::1'].includes(patientTarget.hostname);
  if (siteUrl && new URL(siteUrl).pathname !== '/') {
    throw new Error('SITE_URL must be an origin');
  }
  if (indexable && !siteUrl) {
    throw new Error('Indexing requires a reviewed site destination');
  }
  if (patientAppEnabled && (!patientTarget
    || (!patientLoopback && (patientTarget.protocol !== 'https:' || !privacyReady)))) {
    throw new Error('Patient app release requires an HTTPS destination and complete privacy contact');
  }
  if (testerIntakeEnabled && (!apiUrl || !privacyReady || testerNoticeVersion.length < 3)) {
    throw new Error('Tester intake requires API, controller, address, privacy email and notice version');
  }
  if (providerAccessEnabled && !providerUrl) {
    throw new Error('Provider access requires an explicit provider destination');
  }
  return {
    siteUrl,
    patientAppEnabled,
    patientUrl,
    providerAccessEnabled,
    providerUrl,
    apiUrl,
    indexable,
    testerIntakeEnabled,
    privacyController,
    privacyAddress,
    privacyEmail: privacyEmailAddress,
    privacyReady,
    supportEmail,
    testerNoticeVersion,
  };
}
