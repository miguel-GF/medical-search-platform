import { describe, expect, it } from 'vitest';
import { safeSupabaseUrl } from '../src/auth';

describe('admin Supabase Auth origin validation', () => {
  it('rejects credential endpoints on alternate HTTPS ports', () => {
    expect(safeSupabaseUrl('https://supabase.example:8443')).toBeUndefined();
  });

  it('rejects credentials, query strings and fragments', () => {
    expect(safeSupabaseUrl('https://user:secret@supabase.example')).toBeUndefined();
    expect(safeSupabaseUrl('https://supabase.example/?access_token=leak')).toBeUndefined();
    expect(safeSupabaseUrl('https://supabase.example/#fragment')).toBeUndefined();
    expect(safeSupabaseUrl('https://supabase.example/auth')).toBeUndefined();
  });

  it('accepts a clean HTTPS origin', () => {
    expect(safeSupabaseUrl('https://supabase.example/')).toBe('https://supabase.example');
  });
});
