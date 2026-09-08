import { describe, expect, it } from 'vitest';
import { passwordCallbackMatcher } from '../src/auth-callback';

describe('password callback/session binding', () => {
  it('rejects recovery flags and arbitrary code parameters on an existing session', () => {
    for (const suffix of ['?type=recovery', '#type=invite', '?type=recovery&code=attacker']) {
      expect(passwordCallbackMatcher(`https://admin.test/${suffix}`)({ access_token: 'existing' })).toBe(false);
    }
  });
  it('requires the exact accepted invitation session and consumes the hint once', () => {
    const matches = passwordCallbackMatcher('https://admin.test/#type=invite&access_token=callback-token');
    expect(matches(null)).toBe(false);
    expect(matches({ access_token: 'unrelated-session' })).toBe(false);
    expect(matches({ access_token: 'callback-token' })).toBe(true);
    expect(matches({ access_token: 'callback-token' })).toBe(false);
  });
});
