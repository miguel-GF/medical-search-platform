(() => {
  'use strict';

  const secureOrigin = location.protocol === 'https:' ||
    (location.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(location.hostname));
  if ('serviceWorker' in navigator && secureOrigin) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./pruevia-sw.js', { updateViaCache: 'none' }).catch(() => {
        // Installation from the browser menu remains available if registration fails.
      });
    });
  }

  const banner = document.getElementById('install-help');
  const message = document.getElementById('install-message');
  const action = document.getElementById('install-action');
  const dismiss = document.getElementById('install-dismiss');
  if (!banner || !message || !action || !dismiss) return;

  const standalone = () => window.matchMedia('(display-mode: standalone)').matches ||
    window.matchMedia('(display-mode: fullscreen)').matches || navigator.standalone === true;
  const mobile = () => window.matchMedia('(max-width: 768px)').matches;
  const ios = /iPad|iPhone|iPod/.test(navigator.userAgent);
  const safari = /Safari/.test(navigator.userAgent) && !/CriOS|FxiOS|EdgiOS/.test(navigator.userAgent);
  let installEvent = null;
  let dismissed = false;

  function render() {
    if (standalone() || !mobile() || dismissed) {
      banner.hidden = true;
      return;
    }
    banner.hidden = false;
    action.hidden = !installEvent;
    message.textContent = installEvent
      ? 'Puedes instalar Pruevia en tu celular.'
      : ios
        ? safari
          ? 'Para instalar Pruevia: Compartir → Agregar a pantalla de inicio.'
          : 'Abre Pruevia en Safari y usa Compartir → Agregar a pantalla de inicio.'
        : 'Para instalar Pruevia: abre el menú del navegador (⋮) y elige Instalar app o Agregar a pantalla principal.';
  }

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    installEvent = event;
    render();
  });
  window.addEventListener('appinstalled', () => {
    installEvent = null;
    banner.hidden = true;
  });
  action.addEventListener('click', async () => {
    if (!installEvent) return;
    const pending = installEvent;
    installEvent = null;
    try {
      await pending.prompt();
      await pending.userChoice;
    } catch (_) {
      // Browsers may decline to show a native prompt; keep manual guidance.
    } finally {
      render();
    }
  });
  dismiss.addEventListener('click', () => {
    dismissed = true;
    render();
  });
  window.addEventListener('resize', render);
  render();
})();
