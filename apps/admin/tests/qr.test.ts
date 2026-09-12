import { describe, expect, it } from 'vitest';
import { toQrDataUrl } from '../src/qr';

describe('TOTP QR normalization', () => {
  it('encodes a raw SVG payload', () => {
    const result = toQrDataUrl('<svg xmlns="http://www.w3.org/2000/svg"><rect /></svg>');
    expect(result).toMatch(/^data:image\/svg\+xml;charset=utf-8,/);
    expect(decodeURIComponent(result.split(',', 2)[1])).toContain('<svg');
  });

  it('normalizes an already encoded SVG data URL without double encoding', () => {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg"><path /></svg>';
    const result = toQrDataUrl(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`);
    expect(decodeURIComponent(result.split(',', 2)[1])).toBe(svg);
    expect(result).not.toContain('%253Csvg');
  });

  it('preserves a valid base64 SVG data URL', () => {
    const result = toQrDataUrl('data:image/svg+xml;base64,PHN2Zy8+');
    expect(result).toBe('data:image/svg+xml;base64,PHN2Zy8+');
  });

  it('fails closed for empty, non-SVG and remote inputs', () => {
    expect(toQrDataUrl('')).toBe('');
    expect(toQrDataUrl('https://attacker.example/qr.svg')).toBe('');
    expect(toQrDataUrl('data:image/png;base64,AAAA')).toBe('');
  });
});
