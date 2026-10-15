<script setup lang="ts">
import {
  currentPrivacyReminder,
  PRIVACY_NOTICE_VERSION,
  PRIVACY_REMINDER_RETENTION_MS,
  PRIVACY_REMINDER_STORAGE_KEY,
  type PrivacyReminderRecord,
} from '~/utils/privacyNotice';

// Kept in the current Nuxt session if browser storage is unavailable.
const sessionReminder = useState<PrivacyReminderRecord | null>('privacy-notice-reminder', () => null);
const visible = ref(false);
const permanentLink = ref<HTMLAnchorElement | null>(null);
let expiryTimer: ReturnType<typeof setTimeout> | undefined;

function refreshReminder() {
  if (expiryTimer !== undefined) clearTimeout(expiryTimer);
  const current = currentPrivacyReminder(sessionReminder.value, Date.now());
  visible.value = current === null;
  if (current) {
    // Browser timers cannot wait 180 days in a single interval.
    const remaining = Date.parse(current.expiresAt) - Date.now();
    expiryTimer = setTimeout(refreshReminder, Math.min(Math.max(remaining, 1), 2_147_483_647));
  }
}

onMounted(() => {
  try {
    const stored = localStorage.getItem(PRIVACY_REMINDER_STORAGE_KEY);
    if (stored !== null) {
      sessionReminder.value = currentPrivacyReminder(JSON.parse(stored), Date.now())
        ?? currentPrivacyReminder(sessionReminder.value, Date.now());
    }
  } catch {
    // A blocked or malformed local record must not interrupt navigation.
  }
  refreshReminder();
});

onBeforeUnmount(() => {
  if (expiryTimer !== undefined) clearTimeout(expiryTimer);
});

async function dismissReminder(event: MouseEvent) {
  const now = Date.now();
  const record: PrivacyReminderRecord = {
    version: PRIVACY_NOTICE_VERSION,
    date: new Date(now).toISOString(),
    expiresAt: new Date(now + PRIVACY_REMINDER_RETENTION_MS).toISOString(),
  };
  sessionReminder.value = record;
  try {
    localStorage.setItem(PRIVACY_REMINDER_STORAGE_KEY, JSON.stringify(record));
  } catch {
    // The in-memory record still dismisses this reminder for the current session.
  }
  refreshReminder();
  if (event.detail === 0) {
    await nextTick();
    permanentLink.value?.focus({ preventScroll: true });
  }
}
</script>

<template>
  <aside class="privacy-reminder-shell" aria-label="Privacidad">
    <div class="privacy-reminder-container">
      <section v-if="visible" class="privacy-reminder" aria-labelledby="privacy-reminder-title">
        <div class="privacy-reminder-copy">
          <h2 id="privacy-reminder-title">Tu privacidad en Pruevia</h2>
          <p>
            Consulta cómo tratamos tus datos en el
            <NuxtLink to="/privacidad">aviso de privacidad</NuxtLink>.
            «Entendido» oculta este recordatorio por 180 días, salvo que cambie el aviso.
            Si tu navegador no guarda preferencias, el cierre dura esta sesión.
          </p>
        </div>
        <button class="privacy-reminder-button" type="button" @click="dismissReminder">Entendido</button>
      </section>
      <p class="privacy-reminder-permanent">
        <a ref="permanentLink" href="/privacidad">Aviso de privacidad</a>
      </p>
    </div>
  </aside>
</template>

<style scoped>
.privacy-reminder-shell {
  border-top: 1px solid var(--color-border);
  background: var(--color-canvas);
}
.privacy-reminder-container {
  width: min(1180px, calc(100% - 40px));
  margin-inline: auto;
  padding-block: 20px;
}
.privacy-reminder {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 18px 20px;
  border: 1px solid var(--color-border);
  border-radius: 9px;
  background: var(--color-surface);
}
.privacy-reminder-copy { flex: 1; min-width: 0; }
.privacy-reminder h2 { margin-bottom: 6px; font-size: 15px; line-height: 1.5; }
.privacy-reminder p { margin-bottom: 0; font-size: 13px; }
.privacy-reminder a,
.privacy-reminder-permanent a {
  color: var(--brand-primary-strong);
  text-decoration: underline;
  text-underline-offset: 3px;
}
.privacy-reminder-button {
  flex-shrink: 0;
  min-height: 44px;
  padding: 10px 18px;
  border: 1px solid var(--color-border);
  border-radius: 7px;
  background: var(--color-mint);
  color: var(--color-text);
  font-size: 13px;
  font-weight: 600;
}
.privacy-reminder-button:hover { background: var(--color-step-icon); }
.privacy-reminder-permanent { margin: 12px 0 0; font-size: 12px; }
.privacy-reminder-permanent:first-child { margin-top: 0; }
@media (max-width: 600px) {
  .privacy-reminder { align-items: flex-start; flex-direction: column; gap: 14px; padding: 16px; }
}
</style>
