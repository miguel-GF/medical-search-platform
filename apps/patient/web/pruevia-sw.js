// Only public application files are cached. Never intercept the external API,
// clinical images, search requests, authenticated calls or URLs with a query.
const CACHE = 'pruevia-public-shell-v1';
const SHELL = ['./', './index.html', './manifest.json', './favicon.png', './icons/Icon-192.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(Promise.all([
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith('pruevia-public-shell-') && key !== CACHE).map((key) => caches.delete(key)))),
    self.clients.claim(),
  ]));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.search || request.headers.has('Authorization')) return;
  const navigation = request.mode === 'navigate';
  const publicAsset = /^(\/assets\/|\/canvaskit\/|\/icons\/)/.test(url.pathname) ||
    /^\/(main\.[a-f0-9]{64}\.dart|flutter_bootstrap\.[a-f0-9]{64})\.js$/.test(url.pathname) ||
    /^\/(flutter_bootstrap|flutter|main\.dart|install|pruevia-sw|pwa-updates)\.(js|css)$/.test(url.pathname) ||
    ['/manifest.json', '/favicon.png'].includes(url.pathname);
  if (!navigation && !publicAsset) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const response = await fetch(request);
      if (response.ok && response.type === 'basic') {
        await cache.put(navigation ? './index.html' : request, response.clone());
      }
      return response;
    } catch (error) {
      const cached = await cache.match(navigation ? './index.html' : request);
      if (cached) return cached;
      throw error;
    }
  })());
});
