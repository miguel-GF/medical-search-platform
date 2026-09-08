import { createClient, type Session, type SupabaseClient } from '@supabase/supabase-js';
import { passwordCallbackMatcher } from './auth-callback';

export const matchesPasswordCallback = passwordCallbackMatcher(
  typeof window === 'undefined' ? 'https://localhost/' : window.location.href,
);

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
const supabaseAllowedHosts = new Set(
  String(import.meta.env.VITE_SUPABASE_ALLOWED_HOSTS ?? '')
    .split(',')
    .map((host) => host.trim().toLowerCase())
    .filter(Boolean),
);

export function safeSupabaseUrl(value: string | undefined): string | undefined {
  if (!value?.trim()) return undefined;
  try {
    const parsed = new URL(value.trim());
    const localDevelopment = import.meta.env.DEV && parsed.protocol === 'http:'
      && (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1' || parsed.hostname === '::1');
    if (parsed.protocol !== 'https:' && !localDevelopment) return undefined;
    // Supabase Auth is a credential endpoint. Keep it on the canonical HTTPS
    // origin so a malformed build-time variable cannot send the browser's
    // bearer/session traffic to an alternate TLS port.
    if (parsed.username || parsed.password || parsed.search || parsed.hash
      || (parsed.pathname !== '' && parsed.pathname !== '/')
      || (parsed.protocol === 'https:' && parsed.port && parsed.port !== '443')) return undefined;
    // A production bundle must send Auth traffic only to an explicitly
    // reviewed Supabase origin.  The publishable key is public, but the
    // session and MFA tokens sent alongside it are not.
    if (import.meta.env.PROD && !supabaseAllowedHosts.has(parsed.hostname.toLowerCase())) return undefined;
    return parsed.toString().replace(/\/$/, '');
  } catch {
    return undefined;
  }
}

const safeUrl = safeSupabaseUrl(url);

const browserSessionStorage = typeof window !== 'undefined' ? window.sessionStorage : undefined;

const clientKey = publishableKey?.trim() || anonKey?.trim();

export const supabase: SupabaseClient | null = safeUrl && clientKey ? createClient(safeUrl, clientKey, {
  auth: {
    autoRefreshToken: true,
    // Required for Supabase invitation/recovery links. Supabase consumes the
    // one-time token during initialization; the active session is kept only
    // in sessionStorage below.
    detectSessionInUrl: true,
    persistSession: true,
    ...(browserSessionStorage ? { storage: browserSessionStorage } : {}),
  },
}) : null;

export type AdminSession = Session;
