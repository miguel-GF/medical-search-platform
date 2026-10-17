import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const script = await readFile(new URL('../web/install.js', import.meta.url), 'utf8');

function browser(userAgent = 'Mozilla Android Chrome') {
  const events = new Map();
  const elements = Object.fromEntries(['install-help', 'install-message', 'install-action', 'install-dismiss']
    .map((id) => [id, { hidden: id !== 'install-message', textContent: '', handlers: new Map(), addEventListener(name, callback) { this.handlers.set(name, callback); } }]));
  const context = {
    navigator: { userAgent },
    location: { protocol: 'https:', hostname: 'app.pruevia.com.mx' },
    window: {
      addEventListener(name, callback) { events.set(name, callback); },
      matchMedia(query) { return { matches: query.includes('max-width') }; },
    },
    document: { getElementById(id) { return elements[id]; } },
  };
  vm.runInNewContext(script, context);
  return { events, elements };
}

test('Android gets manual instructions, then a real browser install action', async () => {
  const { events, elements } = browser();
  assert.equal(elements['install-help'].hidden, false);
  assert.match(elements['install-message'].textContent, /Instalar app/);
  assert.equal(elements['install-action'].hidden, true);
  let prevented = false;
  let prompted = false;
  events.get('beforeinstallprompt')({
    preventDefault() { prevented = true; },
    async prompt() { prompted = true; },
    userChoice: Promise.resolve({ outcome: 'accepted' }),
  });
  assert.equal(prevented, true);
  assert.equal(elements['install-action'].hidden, false);
  await elements['install-action'].handlers.get('click')();
  assert.equal(prompted, true);
  events.get('appinstalled')();
  assert.equal(elements['install-help'].hidden, true);
});

test('iPhone receives Safari instructions and can dismiss them', () => {
  const { elements } = browser('Mozilla iPhone Safari');
  assert.match(elements['install-message'].textContent, /Compartir → Agregar a pantalla de inicio/);
  elements['install-dismiss'].handlers.get('click')();
  assert.equal(elements['install-help'].hidden, true);
});

test('service worker restricts its cache to public static files', async () => {
  const worker = await readFile(new URL('../web/pruevia-sw.js', import.meta.url), 'utf8');
  assert.match(worker, /url\.origin !== self\.location\.origin/);
  assert.match(worker, /url\.search/);
  assert.match(worker, /Authorization/);
  assert.doesNotMatch(worker, /api\/v1|recipes|search_results/);

  const listeners = new Map();
  vm.runInNewContext(worker, {
    self: { location: { origin: 'https://app.pruevia.com.mx' }, addEventListener(name, callback) { listeners.set(name, callback); } },
    URL,
    caches: { async open() { return { async put() {}, async match() { return null; } }; } },
    async fetch() { return { ok: true, type: 'basic', clone() { return this; } }; },
  });
  const intercepted = (url, { authorization = false, mode = 'cors' } = {}) => {
    let called = false;
    listeners.get('fetch')({
      request: { method: 'GET', url, mode, headers: { has() { return authorization; } } },
      respondWith(promise) { called = true; promise.catch(() => {}); },
    });
    return called;
  };
  assert.equal(intercepted('https://api.pruevia.com.mx/api/v1/search?q=sangre'), false);
  assert.equal(intercepted('https://app.pruevia.com.mx/api/v1/search'), false);
  assert.equal(intercepted('https://app.pruevia.com.mx/assets/secret.js?token=x'), false);
  assert.equal(intercepted('https://app.pruevia.com.mx/assets/app.js', { authorization: true }), false);
  assert.equal(intercepted('https://app.pruevia.com.mx/assets/app.js'), true);
});

test('custom Flutter bootstrap does not register its deprecated cleanup worker', async () => {
  const bootstrap = await readFile(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8');
  assert.match(bootstrap, /_flutter\.loader\.load\(\)/);
  assert.doesNotMatch(bootstrap, /serviceWorkerSettings|flutter_service_worker\.js/);
});

test('service worker registration is restricted to HTTPS or loopback', () => {
  for (const [protocol, hostname, allowed] of [
    ['https:', 'app.pruevia.com.mx', true],
    ['http:', '127.0.0.1', true],
    ['http:', 'localhost', true],
    ['http:', 'private.example', false],
  ]) {
    const events = new Map();
    const registrations = [];
    vm.runInNewContext(script, {
      navigator: { userAgent: 'Chrome Android', serviceWorker: { register: async (path) => { registrations.push(path); } } },
      location: { protocol, hostname },
      window: { addEventListener(name, callback) { events.set(name, callback); }, matchMedia() { return { matches: true }; } },
      document: { getElementById() { return null; } },
    });
    events.get('load')?.();
    assert.equal(registrations.length, allowed ? 1 : 0);
  }
});
