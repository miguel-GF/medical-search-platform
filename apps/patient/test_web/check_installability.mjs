// Smoke-test the built PWA or production URL in Chromium without submitting a search.
// Local: run after `flutter build web`; production: set PRUEVIA_PWA_URL to app.pruevia.com.mx.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { extname, join, resolve, sep } from 'node:path';

const root = resolve('build/web');
const chrome = process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const requestedUrl = process.env.PRUEVIA_PWA_URL;
if (requestedUrl && new URL(requestedUrl).origin !== 'https://app.pruevia.com.mx') {
  throw new Error('PRUEVIA_PWA_URL must use https://app.pruevia.com.mx');
}
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png' };
const delay = (ms) => new Promise((done) => setTimeout(done, ms));

const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = resolve(root, `.${pathname}`);
    if (file !== root && !file.startsWith(`${root}${sep}`)) { response.writeHead(403).end(); return; }
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
    const body = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] || 'application/octet-stream' }).end(body);
  } catch (_) { response.writeHead(404).end(); }
});

let profile;
let chromeProcess;
let socket;
let serverStarted = false;
try {
  let url = requestedUrl ? new URL(requestedUrl).href : null;
  if (!url) {
    await new Promise((done) => server.listen(0, '127.0.0.1', done));
    serverStarted = true;
    const address = server.address();
    url = `http://127.0.0.1:${address.port}/`;
  }
  profile = await mkdtemp(join(tmpdir(), 'pruevia-pwa-smoke-'));
  chromeProcess = spawn(chrome, [
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
  ], { windowsHide: true, stdio: 'ignore' });

  let port;
  for (let attempt = 0; attempt < 100; attempt++) {
    try { port = Number((await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); break; }
    catch (_) { await delay(100); }
  }
  if (!port) throw new Error('Chrome did not open DevTools');
  const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = pages.find((candidate) => candidate.type === 'page' && candidate.url === 'about:blank') ||
    pages.find((candidate) => candidate.type === 'page');
  if (!page) throw new Error('Chrome did not expose a page target');
  socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((done, reject) => {
    socket.addEventListener('open', done, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let nextId = 0;
  const pending = new Map();
  socket.addEventListener('message', (event) => {
    const payload = JSON.parse(event.data);
    if (!payload.id) return;
    const handler = pending.get(payload.id);
    pending.delete(payload.id);
    if (payload.error) handler.reject(new Error(payload.error.message));
    else handler.resolve(payload.result);
  });
  const send = (method, params = {}) => new Promise((done, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve: done, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await send('Emulation.setUserAgentOverride', {
    userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    platform: 'Android',
  });
  await send('Page.navigate', { url });
  let result;
  for (let attempt = 0; attempt < 100; attempt++) {
    const evaluated = await send('Runtime.evaluate', {
      expression: `(async () => {
        const registration = await navigator.serviceWorker?.getRegistration();
        const manifest = await fetch('/manifest.json').then(r => r.ok ? r.json() : null).catch(() => null);
        const banner = document.getElementById('install-help');
        const action = document.getElementById('install-action');
        return { ready: document.readyState, bannerVisible: !!banner && !banner.hidden && getComputedStyle(banner).display !== 'none',
          actionVisible: !!action && !action.hidden,
          instruction: document.getElementById('install-message')?.textContent,
          flutterViewPresent: !!document.querySelector('flutter-view'),
          registration: !!registration?.active, scope: registration?.scope,
          name: manifest?.short_name, display: manifest?.display,
          icons: manifest?.icons?.map(icon => icon.sizes) || [] };
      })()`,
      awaitPromise: true,
      returnByValue: true,
    });
    result = evaluated.result?.value;
    if (result?.ready === 'complete' && result.registration && result.bannerVisible && result.flutterViewPresent) break;
    await delay(150);
  }
  if (!result?.registration || !result.bannerVisible || !result.flutterViewPresent || result.name !== 'Pruevia' || result.display !== 'standalone' ||
      !result.icons.includes('192x192') || !result.icons.includes('512x512') ||
      !(result.actionVisible ? result.instruction?.includes('Puedes instalar') : result.instruction?.includes('Instalar app'))) {
    throw new Error(`Built PWA smoke failed: ${JSON.stringify(result)}`);
  }
  console.log(`Built PWA: Flutter mounted; service worker active at ${result.scope}; mobile ${result.actionVisible ? 'native install action' : 'manual install guidance'} visible; standalone manifest/icons valid.`);
} finally {
  socket?.close();
  chromeProcess?.kill();
  if (serverStarted) await new Promise((done) => server.close(done));
  if (profile && resolve(profile).startsWith(`${resolve(tmpdir())}${sep}`)) {
    await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}
