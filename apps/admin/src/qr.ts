/**
 * Convert the SVG returned by Supabase Auth into a safe, renderable data URL.
 * Auth currently returns a data URL, but older/newer client versions may
 * return the SVG payload itself (encoded or unencoded). Never accept a remote
 * URL here: the QR is an Auth artifact and must remain local to the page.
 */
export function toQrDataUrl(value: string | null | undefined): string {
  const input = value?.trim() ?? '';
  if (!input) return '';

  // A base64 SVG is already canonical and does not need decoding.
  if (/^data:image\/svg\+xml;[^,]*base64,[A-Za-z0-9+/=]+$/i.test(input)) return input;

  const dataUrlMatch = input.match(/^data:image\/svg\+xml(?:;[^,]*)?,([\s\S]*)$/i);
  let payload = dataUrlMatch ? dataUrlMatch[1] : input;
  try {
    payload = decodeURIComponent(payload);
  } catch {
    // Keep the original payload; the SVG check below will fail closed if it
    // is not a valid, readable SVG document.
  }

  const svgStart = payload.search(/<svg(?:\s|>)/i);
  if (svgStart < 0) return '';
  const svg = payload.slice(svgStart).trim();
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}
