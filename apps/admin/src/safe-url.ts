const TRUSTED_SOURCE_DOMAINS = new Set([
  'chopo.com.mx',
  'laboratoriosruiz.com',
  'salud-digna.org',
  'emarketingsd.org',
  'inegi.org.mx',
  'familylabs.com.mx',
  'laboratorioasesores.com',
  'labxonaca.com',
  'semindigital.com',
]);

/**
 * Return only catalog links that an operator is expected to open.
 * Scraper URLs are untrusted data: HTTPS alone is not enough because an
 * attacker-controlled source could phish an operator or target a reserved
 * network address through the browser.
 */
export function safeHttpUrl(value: string | null | undefined): string | null {
  // Keep malformed catalog data from making URL parsing or DOM updates
  // disproportionately expensive, even if an upstream response is bounded.
  if (!value || value.length > 4_096) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || (url.port && url.port !== '443')
      || !isPublicHost(url.hostname) || !isTrustedSourceHost(url.hostname)) return null;
    if (url.username || url.password) return null;
    url.search = '';
    url.hash = '';
    return url.toString();
  } catch {
    return null;
  }
}

function isTrustedSourceHost(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/\.$/, '');
  return [...TRUSTED_SOURCE_DOMAINS].some((domain) => host === domain || host.endsWith(`.${domain}`));
}

function isPublicHost(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/\.$/, '');
  if (!host || host === 'localhost' || host.endsWith('.localhost')
    || host.endsWith('.local') || host.endsWith('.internal') || host.endsWith('.home.arpa')
    || /[^\x00-\x7f]/.test(host)) return false;
  const ipv4 = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(host);
  if (ipv4) {
    const octets = ipv4.slice(1).map(Number);
    if (octets.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return false;
    const [first, second] = octets;
    return first !== 0 && first !== 10 && first !== 127 && first !== 169
      && !(first === 172 && second >= 16 && second <= 31)
      && !(first === 192 && (second === 0 || second === 168))
      && !(first === 100 && second >= 64 && second <= 127)
      && !(first === 198 && (second === 18 || second === 19 || second === 51))
      && !(first === 203 && second === 0)
      && first < 224;
  }
  return !host.includes(':');
}
