export const PRIVACY_NOTICE_VERSION = 'pruevia-privacidad-2026-10-23-v3';
export const PRIVACY_REMINDER_STORAGE_KEY = 'pruevia.privacyNoticeReminder';
export const PRIVACY_REMINDER_RETENTION_MS = 180 * 24 * 60 * 60 * 1000;

export interface PrivacyReminderRecord {
  version: string;
  date: string;
  expiresAt: string;
}

export function currentPrivacyReminder(value: unknown, now: number): PrivacyReminderRecord | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  if (record.version !== PRIVACY_NOTICE_VERSION
      || typeof record.date !== 'string' || typeof record.expiresAt !== 'string') return null;
  const date = Date.parse(record.date);
  const expiresAt = Date.parse(record.expiresAt);
  if (!Number.isFinite(date) || !Number.isFinite(expiresAt)
      || date > now || expiresAt <= now
      || expiresAt - date !== PRIVACY_REMINDER_RETENTION_MS) return null;
  return { version: PRIVACY_NOTICE_VERSION, date: record.date, expiresAt: record.expiresAt };
}
