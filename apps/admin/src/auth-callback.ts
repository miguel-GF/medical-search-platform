/** Capture before Supabase consumes and removes an implicit callback fragment.
 * A URL flag is only a hint: setup requires the exact session accepted by Auth.
 */
export function passwordCallbackMatcher(href: string) {
  const url = new URL(href);
  const fragment = new URLSearchParams(url.hash.slice(1));
  const type = fragment.get('type');
  let expectedToken = (type === 'invite' || type === 'recovery')
    ? fragment.get('access_token') : null;
  return (session: { access_token: string } | null): boolean => {
    if (!session || !expectedToken || session.access_token !== expectedToken) return false;
    expectedToken = null;
    return true;
  };
}
