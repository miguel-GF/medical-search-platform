// Visual-layout smoke for the generated landing or its production URL using Chrome.
// Local: node scripts/check_mobile_overflow.mjs
// Production: set PRUEVIA_LANDING_URL=https://pruevia.com.mx/ before running.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { join, resolve, sep, extname } from 'node:path';
import { tmpdir } from 'node:os';

const root = resolve('.output/public');
const chrome = process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const requestedUrl = process.env.PRUEVIA_LANDING_URL;
if (requestedUrl && new URL(requestedUrl).origin !== 'https://pruevia.com.mx') {
  throw new Error('PRUEVIA_LANDING_URL must use https://pruevia.com.mx');
}
const mime = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.json': 'application/json' };
const delay = (ms) => new Promise((done) => setTimeout(done, ms));

const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = resolve(root, `.${pathname}`);
    if (file !== root && !file.startsWith(`${root}${sep}`)) { response.writeHead(403).end(); return; }
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
    const body = await readFile(file);
    response.writeHead(200, { 'content-type': `${mime[extname(file)] || 'application/octet-stream'}; charset=utf-8` }).end(body);
  } catch (_) { response.writeHead(404).end(); }
});

let profile;
let processHandle;
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
  profile = await mkdtemp(join(tmpdir(), 'pruevia-chrome-'));
  processHandle = spawn(chrome, [
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
  await new Promise((done, reject) => { socket.addEventListener('open', done, { once: true }); socket.addEventListener('error', reject, { once: true }); });
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
  const send = (method, params = {}) => new Promise((resolvePromise, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve: resolvePromise, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
  await send('Page.enable');
  for (const width of [320, 360, 390, 430]) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: true });
    await send('Page.navigate', { url });
    let measurement;
    for (let attempt = 0; attempt < 25; attempt++) {
      const result = await send('Runtime.evaluate', {
        expression: `JSON.stringify({href:location.href,title:document.title,viewport:document.querySelector('meta[name="viewport"]')?.content,ready:document.readyState,inner:innerWidth,client:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth,offenders:[...document.querySelectorAll('body *')].filter(el=>el.getBoundingClientRect().right>innerWidth+1).slice(0,5).map(el=>el.className||el.tagName)})`,
        returnByValue: true,
      });
      if (result.result?.value) measurement = JSON.parse(result.result.value);
      if (measurement?.ready === 'complete' && measurement.href === url) break;
      await delay(100);
    }
    if (!measurement) throw new Error(`No measurement at ${width}px`);
    console.log(`${width}px: viewport=${measurement.client}, document=${measurement.scroll}, href=${measurement.href}, meta=${measurement.viewport}, candidates=${measurement.offenders.join(', ')}`);
    if (measurement.client !== width) throw new Error(`Mobile emulation failed at ${width}px`);
    if (measurement.scroll > measurement.client + 1) throw new Error(`Horizontal overflow at ${width}px`);
  }
} finally {
  socket?.close();
  processHandle?.kill();
  if (serverStarted) await new Promise((done) => server.close(done));
  if (profile && resolve(profile).startsWith(`${resolve(tmpdir())}${sep}`)) {
    await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}
