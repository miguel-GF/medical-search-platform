import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = resolve(root, 'public', '_headers');
const output = resolve(root, 'dist', '_headers');

function cleanOrigin(name) {
  const raw = (process.env[name] ?? '').trim();
  if (!raw) throw new Error(`${name} is required to render production headers`);
  const parsed = new URL(raw);
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password
    || parsed.search || parsed.hash || parsed.pathname !== '/' || parsed.port) {
    throw new Error(`${name} must be a clean HTTPS origin`);
  }
  return parsed.origin;
}

const apiOrigin = cleanOrigin('VITE_API_URL');
const allowedHosts = (process.env.VITE_API_ALLOWED_HOSTS ?? '')
  .split(',').map((host) => host.trim().toLowerCase()).filter(Boolean);
if (!allowedHosts.includes(new URL(apiOrigin).hostname.toLowerCase())) {
  throw new Error('VITE_API_URL hostname must be listed in VITE_API_ALLOWED_HOSTS');
}
const supabaseOrigin = cleanOrigin('VITE_SUPABASE_URL');
const allowedSupabaseHosts = (process.env.VITE_SUPABASE_ALLOWED_HOSTS ?? '')
  .split(',').map((host) => host.trim().toLowerCase()).filter(Boolean);
if (allowedSupabaseHosts.some((host) => !/^[a-z0-9.-]+$/.test(host) || host.includes('..'))) {
  throw new Error('VITE_SUPABASE_ALLOWED_HOSTS must contain exact DNS hostnames');
}
if (!allowedSupabaseHosts.includes(new URL(supabaseOrigin).hostname.toLowerCase())) {
  throw new Error('VITE_SUPABASE_URL hostname must be listed in VITE_SUPABASE_ALLOWED_HOSTS');
}
const template = readFileSync(source, 'utf8');
if (!template.includes('__PRUEVIA_CONNECT_SRC__')) throw new Error('CSP placeholder is missing from public/_headers');
const connectSources = [apiOrigin, supabaseOrigin].join(' ');
const rendered = template.replace('__PRUEVIA_CONNECT_SRC__', connectSources);
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, rendered, 'utf8');
