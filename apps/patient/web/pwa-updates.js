(() => {
  'use strict';
  const currentBuild = document.querySelector('meta[name="pruevia-build"]')?.content;
  if (!/^[a-f0-9]{64}$/.test(currentBuild || '')) return;
  const banner = document.getElementById('app-update');
  const update = document.getElementById('app-update-action');
  const later = document.getElementById('app-update-later');
  const message = document.getElementById('app-update-message');
  if (!banner || !update || !later || !message) return;
  const interval = 5 * 60 * 1000;
  let checking = false;
  let availableBuild = null;
  let postponedBuild = null;
  let postponedUntil = 0;
  let lastCheck = 0;

  async function publishedBuild() {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(new URL('app-version.json', document.baseURI), {
        cache: 'no-store', credentials: 'omit', signal: controller.signal,
      });
      if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) return null;
      const text = await response.text();
      if (text.length > 4096) return null;
      const value = JSON.parse(text);
      return value?.schema === 1 && /^[a-f0-9]{64}$/.test(value.build || '') ? value.build : null;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function check(force = false) {
    if (checking || document.visibilityState === 'hidden' || !navigator.onLine) return;
    if (!force && Date.now() - lastCheck < 30000) return;
    checking = true;
    lastCheck = Date.now();
    try {
      const version = await publishedBuild();
      if (!version) return;
      availableBuild = version !== currentBuild ? version : null;
      message.textContent = 'Puedes seguir usando la app o actualizar ahora.';
      banner.hidden = !availableBuild ||
        (availableBuild === postponedBuild && Date.now() < postponedUntil);
      if (availableBuild && 'serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistration().then(registration => registration?.update()).catch(() => {});
      }
    } catch (_) {
      // Offline, an unavailable endpoint or an invalid manifest never interrupts an order.
    } finally {
      checking = false;
    }
  }

  later.addEventListener('click', () => {
    postponedBuild = availableBuild;
    postponedUntil = Date.now() + 30 * 60 * 1000;
    banner.hidden = true;
  });
  update.addEventListener('click', async () => {
    update.disabled = true;
    try {
      const version = await publishedBuild();
      if (!version || !navigator.onLine) throw new Error('update_unavailable');
      // Reload only after the person's explicit action and the visible draft warning.
      const destination = new URL(window.location.href);
      destination.searchParams.set('pruevia-release', version);
      window.location.replace(destination.href);
    } catch (_) {
      message.textContent = 'No pudimos obtener la actualización. Tu consulta sigue abierta; inténtalo cuando tengas conexión.';
      update.disabled = false;
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') check(true);
  });
  window.addEventListener('pageshow', () => check());
  window.addEventListener('online', () => check(true));
  setInterval(() => check(), interval);
  setTimeout(() => check(), 2000);
})();
