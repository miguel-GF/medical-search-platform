import { createClient, type Session, type SupabaseClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

function safeSupabaseUrl(value: string | undefined): string | undefined {
  if (!value?.trim()) return undefined;
  try {
    const parsed = new URL(value.trim());
    const localDevelopment = parsed.protocol === 'http:'
      && (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1' || parsed.hostname === '::1');
    if (parsed.protocol !== 'https:' && !localDevelopment) return undefined;
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
