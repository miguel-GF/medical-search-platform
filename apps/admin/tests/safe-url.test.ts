import { describe, expect, it } from 'vitest';
import { safeHttpUrl } from '../src/safe-url';

describe('admin source URL boundary', () => {
  it('accepts only trusted provider domains and removes tracking data', () => {
    expect(safeHttpUrl('https://www.chopo.com.mx/results?token=ignored#fragment'))
      .toBe('https://www.chopo.com.mx/results');
    expect(safeHttpUrl('https://subdomain.inegi.org.mx/ficha')).toBe('https://subdomain.inegi.org.mx/ficha');
  });

  it('rejects phishing, non-HTTPS and reserved hosts', () => {
    for (const value of [
      'https://attacker.example/phish',
      'http://chopo.com.mx/insecure',
      'https://user:pass@chopo.com.mx/private',
      'https://127.0.0.1/admin',
      'https://100.64.0.1/internal',
      `https://chopo.com.mx/${'a'.repeat(4090)}`,
      'javascript:alert(1)',
    ]) {
      expect(safeHttpUrl(value)).toBeNull();
    }
  });
});
