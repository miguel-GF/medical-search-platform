<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { createAdminApi, formatDate, type AlertRow, type CatalogItem, type Dashboard, type LocationRow, type NormalizationDetail, type NormalizationRow, type OfferRow, type PriceRow, type ProviderRow, type QualityIssueRow, type RawRecord } from './api';
import { supabase } from './auth';

type Tab = 'overview' | 'providers' | 'locations' | 'offers' | 'prices' | 'queue' | 'records' | 'quality' | 'alerts';
const api = createAdminApi(import.meta.env.VITE_API_URL ?? 'http://localhost:8787', async () => (await supabase?.auth.getSession())?.data.session?.access_token ?? null);
const session = ref<import('@supabase/supabase-js').Session | null>(null);
const email = ref('');
const password = ref('');
const passwordSetupRequired = ref(hasPasswordSetupLink());
const newPassword = ref('');
const confirmPassword = ref('');
const authError = ref('');
const authLoading = ref(false);
const mfaPending = ref(false);
const mfaSetupRequired = ref(false);
const mfaFactorId = ref('');
const mfaChallengeId = ref('');
const mfaCode = ref('');
const mfaLoading = ref(false);
const enrollmentQr = ref('');
const enrollmentSecret = ref('');
const enrollmentFactorId = ref('');
const enrollmentCode = ref('');
let authSubscription: { unsubscribe: () => void } | null = null;
const tab = ref<Tab>('overview');
const loading = ref(false);
const error = ref('');
const notice = ref('');
const dashboard = ref<Dashboard | null>(null);
const queue = ref<NormalizationRow[]>([]);
const queueHasMore = ref(false);
const queueLoadingMore = ref(false);
const queueStatus = ref('ambiguous');
const queueInputType = ref('');
const records = ref<RawRecord[]>([]);
const providers = ref<ProviderRow[]>([]);
const locations = ref<LocationRow[]>([]);
const offers = ref<OfferRow[]>([]);
const prices = ref<PriceRow[]>([]);
const qualityIssues = ref<QualityIssueRow[]>([]);
const alerts = ref<AlertRow[]>([]);
const selected = ref<NormalizationRow | null>(null);
const detail = ref<NormalizationDetail | null>(null);
const selectedCandidateId = ref('');
const alias = ref('');
const reason = ref('');
const manualCatalogQuery = ref('');
const manualCatalogResults = ref<CatalogItem[]>([]);
const manualCatalogItemId = ref('');
const manualCatalogLoading = ref(false);

const aliasRequired = computed(() => Boolean(selected.value?.provider_brand_id));
const canApprove = computed(() => !loading.value
  && (!aliasRequired.value || Boolean(alias.value.trim()))
  && Boolean(selectedCandidateId.value)
  && (!manualCatalogItemId.value || Boolean(reason.value.trim())));

const cards = computed(() => dashboard.value ? [
  ['Catálogo activo', dashboard.value.active_catalog_items, 'servicios'],
  ['Ofertas activas', dashboard.value.active_offers, 'proveedores'],
  ['Ambiguos', dashboard.value.normalization_ambiguous, 'requieren decisión'],
  ['Sin match', dashboard.value.normalization_no_match, 'requieren descarte'],
  ['Alertas abiertas', dashboard.value.open_alerts, 'operación'],
  ['Alertas críticas', dashboard.value.critical_alerts, 'atención inmediata'],
] : []);

function errorMessage(cause: unknown, fallback: string): string {
  return cause instanceof Error ? cause.message : fallback;
}

function hasPasswordSetupLink(): boolean {
  if (typeof window === 'undefined') return false;
  const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  const queryParams = new URLSearchParams(window.location.search);
  const type = hashParams.get('type') ?? queryParams.get('type');
  return type === 'invite' || type === 'recovery';
}

function safeHttpUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    url.search = '';
    url.hash = '';
    return url.toString();
  } catch {
    return null;
  }
}

function sanitizeDetail(value: NormalizationDetail | null): NormalizationDetail | null {
  if (!value?.raw_record) return value;
  return {
    ...value,
    raw_record: { ...value.raw_record, source_url: safeHttpUrl(value.raw_record.source_url) },
  };
}

async function establishMfa() {
  if (!supabase) return false;
  try {
  const assurance = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (assurance.error) { authError.value = 'No se pudo consultar el estado MFA.'; return false; }
  if (assurance.data.currentLevel === 'aal2') {
    mfaPending.value = false;
    mfaSetupRequired.value = false;
    await refresh();
    return true;
  }
  const factors = await supabase.auth.mfa.listFactors();
  if (factors.error) { authError.value = 'No se pudieron consultar los factores MFA.'; return false; }
  const verified = factors.data.totp.find((factor) => factor.status === 'verified');
  if (!verified) {
    mfaPending.value = true;
    mfaSetupRequired.value = true;
    return false;
  }
  mfaFactorId.value = verified.id;
  mfaPending.value = true;
  mfaSetupRequired.value = false;
  return false;
  } catch {
    authError.value = 'No se pudo consultar el estado de autenticación. Inténtalo de nuevo.';
    mfaPending.value = true;
    return false;
  }
}

async function verifyMfa() {
  if (!supabase || !mfaFactorId.value || !/^\d{6}$/.test(mfaCode.value.trim())) {
    authError.value = 'Escribe el código de seis dígitos de tu autenticador.';
    return;
  }
  mfaLoading.value = true;
  authError.value = '';
  try {
  const challenge = await supabase.auth.mfa.challenge({ factorId: mfaFactorId.value });
  if (challenge.error) { authError.value = 'No se pudo iniciar el desafío MFA.'; mfaLoading.value = false; return; }
  mfaChallengeId.value = challenge.data.id;
  const verification = await supabase.auth.mfa.verify({ factorId: mfaFactorId.value, challengeId: mfaChallengeId.value, code: mfaCode.value.trim() });
  if (verification.error) {
    authError.value = 'El código MFA no es válido o ya expiró.';
    mfaLoading.value = false;
    return;
  }
  mfaCode.value = '';
  mfaLoading.value = false;
  await supabase.auth.refreshSession();
  await establishMfa();
  } catch {
    authError.value = 'No se pudo completar la verificación MFA. Inténtalo de nuevo.';
    mfaChallengeId.value = '';
  }
  mfaLoading.value = false;
}

async function beginEnrollment() {
  if (!supabase) return;
  mfaLoading.value = true;
  authError.value = '';
  try {
  const result = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: `Admin ${session.value?.user.email ?? email.value.trim()}` });
  if (result.error) authError.value = 'No se pudo iniciar el registro del autenticador.';
  else {
    enrollmentFactorId.value = result.data.id;
    enrollmentQr.value = result.data.totp.qr_code;
    enrollmentSecret.value = result.data.totp.secret;
  }
  } catch {
    authError.value = 'No se pudo iniciar el registro del autenticador. Inténtalo de nuevo.';
  }
  mfaLoading.value = false;
}

async function verifyEnrollment() {
  if (!supabase || !enrollmentFactorId.value || !/^\d{6}$/.test(enrollmentCode.value.trim())) {
    authError.value = 'Escribe el código de seis dígitos mostrado por tu autenticador.';
    return;
  }
  mfaLoading.value = true;
  authError.value = '';
  try {
  const challenge = await supabase.auth.mfa.challenge({ factorId: enrollmentFactorId.value });
  if (challenge.error) { authError.value = 'No se pudo validar el autenticador.'; mfaLoading.value = false; return; }
  const verification = await supabase.auth.mfa.verify({ factorId: enrollmentFactorId.value, challengeId: challenge.data.id, code: enrollmentCode.value.trim() });
  if (verification.error) { authError.value = 'El código no es válido. Revisa la hora del dispositivo.'; mfaLoading.value = false; return; }
  enrollmentCode.value = '';
  enrollmentQr.value = '';
  enrollmentSecret.value = '';
  mfaLoading.value = false;
  await supabase.auth.refreshSession();
  await establishMfa();
  } catch {
    authError.value = 'No se pudo completar el registro MFA. Inténtalo de nuevo.';
  }
  mfaLoading.value = false;
}

async function loadQueue(reset = true) {
  const last = queue.value[queue.value.length - 1];
  const cursor = !reset && last ? { before_created_at: last.created_at, before_id: last.normalization_run_id } : undefined;
  const rows = await api.normalizationQueue(queueStatus.value === 'all' ? undefined : queueStatus.value, queueInputType.value || undefined, cursor);
  if (reset) queue.value = rows;
  else queue.value = [...queue.value, ...rows];
  queueHasMore.value = rows.length === 100;
}

async function loadMoreQueue() {
  if (!queueHasMore.value || queueLoadingMore.value) return;
  queueLoadingMore.value = true;
  try { await loadQueue(false); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo cargar más casos'); }
  finally { queueLoadingMore.value = false; }
}

async function refresh() {
  loading.value = true;
  error.value = '';
  try {
    dashboard.value = await api.dashboard();
    if (tab.value === 'queue') await loadQueue();
    if (tab.value === 'records') records.value = await api.rawRecords();
    if (tab.value === 'providers') providers.value = await api.providers();
    if (tab.value === 'locations') locations.value = await api.locations();
    if (tab.value === 'offers') offers.value = await api.offers();
    if (tab.value === 'prices') prices.value = (await api.prices()).map((row) => ({ ...row, source_url: safeHttpUrl(row.source_url) }));
    if (tab.value === 'quality') qualityIssues.value = await api.qualityIssues();
    if (tab.value === 'alerts') alerts.value = await api.alerts();
  } catch (cause) { error.value = errorMessage(cause, 'No se pudo consultar la API'); }
  finally { loading.value = false; }
}

async function switchTab(next: Tab) {
  tab.value = next;
  notice.value = '';
  try {
    if (next === 'queue' && !queue.value.length) await loadQueue();
    if (next === 'records' && !records.value.length) records.value = await api.rawRecords();
    if (next === 'providers' && !providers.value.length) providers.value = await api.providers();
    if (next === 'locations' && !locations.value.length) locations.value = await api.locations();
    if (next === 'offers' && !offers.value.length) offers.value = await api.offers();
    if (next === 'prices' && !prices.value.length) prices.value = (await api.prices()).map((row) => ({ ...row, source_url: safeHttpUrl(row.source_url) }));
    if (next === 'quality' && !qualityIssues.value.length) qualityIssues.value = await api.qualityIssues();
    if (next === 'alerts' && !alerts.value.length) alerts.value = await api.alerts();
  } catch (cause) { error.value = errorMessage(cause, 'No se pudo cargar la sección'); }
}

async function changeQueueFilter() {
  try { await loadQueue(); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo cargar la cola'); }
}

async function searchCatalog() {
  const query = manualCatalogQuery.value.trim();
  manualCatalogItemId.value = '';
  if (query.length < 2) { manualCatalogResults.value = []; return; }
  manualCatalogLoading.value = true;
  try { manualCatalogResults.value = await api.catalogItems(query); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo buscar en el catálogo'); }
  finally { manualCatalogLoading.value = false; }
}

function chooseManualCatalogItem(item: CatalogItem) {
  manualCatalogItemId.value = item.item_id;
  selectedCandidateId.value = item.item_id;
}

async function openRow(row: NormalizationRow) {
  selected.value = row;
  detail.value = null;
  selectedCandidateId.value = '';
  alias.value = row.raw_text ?? row.normalized_input ?? '';
  reason.value = '';
  manualCatalogQuery.value = '';
  manualCatalogResults.value = [];
  manualCatalogItemId.value = '';
  try {
    detail.value = sanitizeDetail(await api.normalizationDetail(row.normalization_run_id));
    if (detail.value?.candidates.length === 1) selectedCandidateId.value = detail.value.candidates[0].candidate_id;
  } catch (cause) { error.value = errorMessage(cause, 'No se pudo cargar la evidencia'); }
}

function closeReview() { selected.value = null; detail.value = null; selectedCandidateId.value = ''; }

async function showPayload() {
  if (!selected.value) return;
    try { detail.value = sanitizeDetail(await api.normalizationDetail(selected.value.normalization_run_id, true)); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo cargar el payload'); }
}

async function approveCandidate() {
  if (!canApprove.value || !selected.value) return;
  loading.value = true;
  error.value = '';
  try {
    let candidateId = selectedCandidateId.value;
    if (manualCatalogItemId.value && candidateId === manualCatalogItemId.value) candidateId = '';
    if (!candidateId && manualCatalogItemId.value) {
      if (!reason.value.trim()) {
        error.value = 'Escribe el motivo de la selección manual antes de aprobar.';
        return;
      }
      const manual = await api.addManualCandidate(selected.value.normalization_run_id, {
        catalog_item_id: manualCatalogItemId.value,
        reason: reason.value.trim(),
      });
      candidateId = manual.candidate_id;
    }
    if (!candidateId) return;
    const reviewInput: { decision: 'approve_candidate'; selected_candidate_id: string; alias?: string; reason?: string } = {
      decision: 'approve_candidate',
      selected_candidate_id: candidateId,
      reason: reason.value.trim() || undefined,
    };
    if (aliasRequired.value) reviewInput.alias = alias.value.trim();
    await api.reviewNormalization(selected.value.normalization_run_id, reviewInput);
    notice.value = aliasRequired.value
      ? 'Candidato aprobado y alias guardado para futuras resoluciones.'
      : 'Candidato aprobado. No se creó un alias global fuera de un proveedor.';
    closeReview();
    await loadQueue();
    dashboard.value = await api.dashboard();
  } catch (cause) { error.value = errorMessage(cause, 'No se pudo aprobar el candidato'); }
  finally { loading.value = false; }
}

async function markNoMatch() {
  if (!selected.value || !reason.value.trim()) return;
  loading.value = true;
  error.value = '';
  try {
    await api.reviewNormalization(selected.value.normalization_run_id, { decision: 'no_match', reason: reason.value.trim() });
    notice.value = 'Caso marcado como no_match y no se publicará ninguna equivalencia.';
    closeReview();
    await loadQueue();
    dashboard.value = await api.dashboard();
  } catch (cause) { error.value = errorMessage(cause, 'No se pudo marcar el caso'); }
  finally { loading.value = false; }
}

async function updateAlert(row: AlertRow, status: 'acknowledged' | 'resolved' | 'ignored') {
  try { await api.updateAlertStatus(row.alert_id, status); row.status = status; notice.value = `Alerta actualizada: ${status}.`; dashboard.value = await api.dashboard(); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo actualizar la alerta'); }
}

async function updateQuality(row: QualityIssueRow, status: 'acknowledged' | 'resolved' | 'ignored') {
  try { await api.updateQualityIssueStatus(row.issue_id, status); row.status = status; notice.value = `Issue actualizado: ${status}.`; dashboard.value = await api.dashboard(); }
  catch (cause) { error.value = errorMessage(cause, 'No se pudo actualizar el issue'); }
}

async function signIn() {
  if (!supabase || !email.value.trim() || !password.value) return;
  authLoading.value = true;
  authError.value = '';
  authFlowInProgress = true;
  try {
  const result = await supabase.auth.signInWithPassword({ email: email.value.trim(), password: password.value });
  password.value = '';
  if (result.error) { authError.value = 'No se pudo iniciar sesión.'; authLoading.value = false; return; }
  session.value = result.data.session;
  await establishMfa();
  } catch {
    authError.value = 'No se pudo iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';
  } finally {
    authFlowInProgress = false;
    authLoading.value = false;
  }
}

async function setPassword() {
  if (!supabase || !session.value) return;
  if (newPassword.value.length < 12) {
    authError.value = 'La contraseña debe tener al menos 12 caracteres.';
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    authError.value = 'Las contraseñas no coinciden.';
    return;
  }
  authLoading.value = true;
  authError.value = '';
  try {
    const result = await supabase.auth.updateUser({ password: newPassword.value });
    if (result.error) {
      authError.value = 'No se pudo guardar la contraseña. Solicita una nueva invitación si el enlace expiró.';
      return;
    }
    newPassword.value = '';
    confirmPassword.value = '';
    passwordSetupRequired.value = false;
    await establishMfa();
  } catch {
    authError.value = 'No se pudo guardar la contraseña. Inténtalo de nuevo.';
  } finally {
    authLoading.value = false;
  }
}

async function signOut() {
  try { await supabase?.auth.signOut(); }
  catch { /* Local state is cleared even if the network logout fails. */ }
  finally { resetAdminState(); }
}

function resetAdminState(options: { preservePasswordSetup?: boolean } = {}) {
  session.value = null;
  passwordSetupRequired.value = options.preservePasswordSetup === true;
  newPassword.value = '';
  confirmPassword.value = '';
  mfaPending.value = false;
  mfaSetupRequired.value = false;
  mfaFactorId.value = '';
  mfaChallengeId.value = '';
  mfaCode.value = '';
  enrollmentQr.value = '';
  enrollmentSecret.value = '';
  enrollmentFactorId.value = '';
  enrollmentCode.value = '';
  email.value = '';
  password.value = '';
  authError.value = '';
  error.value = '';
  notice.value = '';
  tab.value = 'overview';
  queue.value = [];
  queueHasMore.value = false;
  queueLoadingMore.value = false;
  records.value = [];
  providers.value = [];
  locations.value = [];
  offers.value = [];
  prices.value = [];
  qualityIssues.value = [];
  alerts.value = [];
  dashboard.value = null;
  selected.value = null;
  detail.value = null;
  selectedCandidateId.value = '';
  alias.value = '';
  reason.value = '';
  manualCatalogQuery.value = '';
  manualCatalogResults.value = [];
  manualCatalogItemId.value = '';
}

let authFlowInProgress = false;

async function syncAuthState(nextSession: import('@supabase/supabase-js').Session | null, event = '') {
  const previousUserId = session.value?.user.id ?? null;
  const nextUserId = nextSession?.user.id ?? null;
  const shouldSetupPassword = passwordSetupRequired.value;
  session.value = nextSession;
  if (!nextSession) {
    resetAdminState();
    return;
  }
  if (previousUserId !== nextUserId && !authFlowInProgress) {
    resetAdminState({ preservePasswordSetup: shouldSetupPassword });
    session.value = nextSession;
    email.value = nextSession.user.email ?? '';
    mfaPending.value = true;
    if (!passwordSetupRequired.value) await establishMfa();
    return;
  }
  if (event === 'TOKEN_REFRESHED' && !passwordSetupRequired.value) {
    await establishMfa();
  }
}

onMounted(async () => {
  if (!supabase) return;
  try {
    session.value = (await supabase.auth.getSession()).data.session;
    if (session.value) {
      email.value = session.value.user.email ?? '';
      if (passwordSetupRequired.value) mfaPending.value = true;
      else await establishMfa();
    }
    const subscription = supabase.auth.onAuthStateChange((event, nextSession) => { void syncAuthState(nextSession, event); });
    authSubscription = subscription.data.subscription;
  } catch {
    resetAdminState();
    authError.value = 'No se pudo restaurar la sesión. Inicia sesión de nuevo.';
  }
});
onUnmounted(() => {
  authSubscription?.unsubscribe();
  enrollmentQr.value = '';
  enrollmentSecret.value = '';
  enrollmentCode.value = '';
  mfaCode.value = '';
  newPassword.value = '';
  confirmPassword.value = '';
});
</script>

<template>
  <main v-if="!supabase" class="auth-shell"><section class="auth-card"><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin no configurado</h1><p>Faltan VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY.</p></section></main>
  <main v-else-if="!session" class="auth-shell"><form class="auth-card" @submit.prevent="signIn"><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin</h1><p class="subtitle">Inicia sesión con tu cuenta administrativa de Supabase.</p><label>Correo<input v-model="email" type="email" autocomplete="username" required /></label><label>Contraseña<input v-model="password" type="password" autocomplete="current-password" required /></label><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="authLoading">{{ authLoading ? 'Iniciando…' : 'Iniciar sesión' }}</button></form></main>
  <main v-else-if="passwordSetupRequired" class="auth-shell"><form class="auth-card" @submit.prevent="setPassword"><p class="eyebrow">CUENTA ADMINISTRATIVA</p><h1>Define tu contraseña</h1><p class="subtitle">La invitación es de un solo uso. Define una contraseña fuerte antes de activar el segundo factor.</p><label>Nueva contraseña<input v-model="newPassword" type="password" autocomplete="new-password" minlength="12" required /></label><label>Repite la contraseña<input v-model="confirmPassword" type="password" autocomplete="new-password" minlength="12" required /></label><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="authLoading">{{ authLoading ? 'Guardando…' : 'Guardar contraseña' }}</button><button class="secondary full-button" type="button" @click="signOut">Cerrar sesión</button></form></main>
  <main v-else-if="mfaPending" class="auth-shell"><form v-if="mfaSetupRequired && !enrollmentQr" class="auth-card" @submit.prevent="beginEnrollment"><p class="eyebrow">SEGUNDO FACTOR</p><h1>Configura tu autenticador</h1><p class="subtitle">El panel requiere TOTP para aprobar candidatos y cambiar datos operativos.</p><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Preparando…' : 'Mostrar código QR' }}</button><button class="secondary full-button" type="button" @click="signOut">Cerrar sesión</button></form><form v-else-if="mfaSetupRequired" class="auth-card" @submit.prevent="verifyEnrollment"><p class="eyebrow">SEGUNDO FACTOR</p><h1>Escanea y confirma</h1><p class="subtitle">Escanea el QR una sola vez con Google Authenticator, Authy o 1Password.</p><img class="totp-qr" :src="`data:image/svg+xml;charset=utf-8,${encodeURIComponent(enrollmentQr)}`" alt="Código QR para configurar TOTP" /><details class="secret"><summary>Mostrar clave manual sólo si no puedes escanear</summary><code>{{ enrollmentSecret }}</code><p class="hint">Esta clave permite clonar el autenticador. No la compartas ni la guardes en capturas.</p></details><label>Código de seis dígitos<input v-model="enrollmentCode" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" required /></label><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Verificando…' : 'Activar autenticador' }}</button><button class="secondary full-button" type="button" @click="signOut">Cancelar</button></form><form v-else class="auth-card" @submit.prevent="verifyMfa"><p class="eyebrow">SEGUNDO FACTOR</p><h1>Confirma tu identidad</h1><p class="subtitle">Escribe el código actual de tu aplicación autenticadora.</p><label>Código de seis dígitos<input v-model="mfaCode" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" autofocus required /></label><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Verificando…' : 'Entrar al panel' }}</button><button class="secondary full-button" type="button" @click="signOut">Cerrar sesión</button></form></main>
   <div v-else class="shell">
    <header class="topbar"><div><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Panel administrativo</h1><p class="subtitle">Automatización primero; revisión humana sólo para excepciones.</p></div><div class="topbar-actions"><button class="refresh" :disabled="loading" @click="refresh">{{ loading ? 'Actualizando…' : 'Actualizar' }}</button><button class="secondary" @click="signOut">Cerrar sesión</button></div></header>
    <nav class="tabs" aria-label="Secciones administrativas"><button v-for="entry in ([['overview','Resumen'],['providers','Providers'],['locations','Locations'],['offers','Offers'],['prices','Prices'],['queue','Revisión'],['records','Raw records'],['quality','Calidad'],['alerts','Alertas']] as [Tab,string][])" :key="entry[0]" :class="{ active: tab === entry[0] }" @click="switchTab(entry[0])">{{ entry[1] }}</button></nav>
    <p v-if="error" class="alert error">{{ error }}</p><p v-if="notice" class="alert success">{{ notice }}</p>
    <main v-if="tab === 'overview'"><section class="cards"><article v-for="card in cards" :key="card[0]" class="card"><span>{{ card[0] }}</span><strong>{{ card[1] }}</strong><small>{{ card[2] }}</small></article></section><section class="panel"><div class="panel-title"><div><p class="eyebrow">INGESTA</p><h2>Corridas recientes</h2></div><span v-if="dashboard" class="muted">{{ dashboard.sources }} fuentes activas · {{ dashboard.crawl_runs }} corridas</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Estado</th><th>Recibidos</th><th>Válidos</th><th>Publicados</th><th>Inicio</th></tr></thead><tbody><tr v-for="run in dashboard?.recent_runs ?? []" :key="run.id"><td>{{ run.source_name }}</td><td><span class="status" :class="run.status">{{ run.status }}</span></td><td>{{ run.records_received }}</td><td>{{ run.records_valid }}</td><td>{{ run.records_published }}</td><td>{{ formatDate(run.started_at) }}</td></tr><tr v-if="!dashboard?.recent_runs?.length"><td colspan="6" class="empty">Sin corridas todavía.</td></tr></tbody></table></div></section></main>
    <main v-else-if="tab === 'providers'" class="panel"><div class="panel-title"><div><p class="eyebrow">CATÁLOGO</p><h2>Providers</h2></div><span class="muted">{{ providers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Estado</th><th>Verificación</th><th>Locations</th><th>Offers</th></tr></thead><tbody><tr v-for="row in providers" :key="row.provider_id"><td>{{ row.provider_name }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.verification_status }}</td><td>{{ row.locations_count }}</td><td>{{ row.active_offers_count }}</td></tr><tr v-if="!providers.length"><td colspan="5" class="empty">Sin providers.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'locations'" class="panel"><div class="panel-title"><div><p class="eyebrow">GEOGRAFÍA</p><h2>Locations</h2></div><span class="muted">{{ locations.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Sucursal</th><th>Dirección</th><th>Localidad</th><th>Estado</th><th>Coordenadas</th></tr></thead><tbody><tr v-for="row in locations" :key="row.location_id"><td>{{ row.provider_name }}</td><td>{{ row.location_name }}</td><td>{{ row.address ?? '—' }}</td><td>{{ row.locality ?? '—' }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.latitude ?? '—' }}, {{ row.longitude ?? '—' }}</td></tr><tr v-if="!locations.length"><td colspan="6" class="empty">Sin locations.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'offers'" class="panel"><div class="panel-title"><div><p class="eyebrow">COMERCIO</p><h2>Offers</h2></div><span class="muted">{{ offers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Estado</th><th>Precios vigentes</th><th>Última observación</th></tr></thead><tbody><tr v-for="row in offers" :key="row.offer_id"><td>{{ row.provider_name }}</td><td>{{ row.service_name }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.current_price_count }}</td><td>{{ formatDate(row.last_seen_at) }}</td></tr><tr v-if="!offers.length"><td colspan="5" class="empty">Sin offers.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'prices'" class="panel"><div class="panel-title"><div><p class="eyebrow">PRECIOS</p><h2>Prices</h2></div><span class="muted">{{ prices.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Tipo</th><th>Importe</th><th>Última observación</th><th>Fuente</th></tr></thead><tbody><tr v-for="row in prices" :key="row.price_version_id"><td>{{ row.provider_name }}</td><td>{{ row.service_name }}</td><td>{{ row.price_type }}</td><td>{{ row.amount_minor / 100 }} {{ row.currency }}</td><td>{{ formatDate(row.last_seen_at) }}</td><td><a v-if="row.source_url" :href="row.source_url" target="_blank" rel="noopener noreferrer">Abrir</a><span v-else>—</span></td></tr><tr v-if="!prices.length"><td colspan="6" class="empty">Sin prices.</td></tr></tbody></table></div></main>
     <main v-else-if="tab === 'queue'" class="panel"><div class="panel-title"><div><p class="eyebrow">REVISIÓN HUMANA</p><h2>Excepciones del resolver</h2><p class="hint">Los casos automáticos no aparecen aquí. Sólo puedes aprobar candidatos que el resolver produjo.</p></div><div class="panel-tools"><select v-model="queueStatus" @change="changeQueueFilter"><option value="ambiguous">Ambiguos</option><option value="no_match">Sin match</option><option value="pending">Pendientes</option><option value="all">Todos</option></select><select v-model="queueInputType" @change="changeQueueFilter"><option value="">Todos los orígenes</option><option value="search">Búsqueda</option><option value="crawler">Scraper</option><option value="ocr">OCR</option></select><span class="muted">{{ queue.length }} registros</span><button v-if="queueHasMore" class="link" type="button" :disabled="queueLoadingMore" @click="loadMoreQueue">{{ queueLoadingMore ? 'Cargando…' : 'Cargar más' }}</button></div></div><div class="table-wrap"><table><thead><tr><th>Entrada</th><th>Origen</th><th>Fuente</th><th>Estado</th><th>Candidatos</th><th>Creado</th><th></th></tr></thead><tbody><tr v-for="row in queue" :key="row.normalization_run_id"><td><strong>{{ row.raw_text ?? row.normalized_input ?? '—' }}</strong><small class="block">{{ row.normalized_input ?? '—' }}</small></td><td>{{ row.input_type }}</td><td>{{ row.source_name ?? '—' }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.candidate_count }}</td><td>{{ formatDate(row.created_at) }}</td><td><button class="link" @click="openRow(row)">Revisar</button></td></tr><tr v-if="!queue.length"><td colspan="7" class="empty">No hay casos en esta cola.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'quality'" class="panel"><div class="panel-title"><div><p class="eyebrow">CALIDAD</p><h2>Data quality issues</h2></div><span class="muted">{{ qualityIssues.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Severidad</th><th>Estado</th><th>Run</th><th>Creado</th><th>Detalle</th><th>Acciones</th></tr></thead><tbody><tr v-for="row in qualityIssues" :key="row.issue_id"><td>{{ row.issue_code }}</td><td><span class="status" :class="row.severity">{{ row.severity }}</span></td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.crawl_run_id ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td><td><pre>{{ JSON.stringify(row.details, null, 2) }}</pre></td><td class="actions" v-if="row.status === 'open' || row.status === 'acknowledged'"><button class="link" @click="updateQuality(row, 'acknowledged')">Reconocer</button><button class="link" @click="updateQuality(row, 'resolved')">Resolver</button><button class="link danger-link" @click="updateQuality(row, 'ignored')">Ignorar</button></td><td v-else>—</td></tr><tr v-if="!qualityIssues.length"><td colspan="7" class="empty">Sin issues registrados.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'alerts'" class="panel"><div class="panel-title"><div><p class="eyebrow">OPERACIÓN</p><h2>Alertas</h2></div><span class="muted">{{ alerts.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Título</th><th>Severidad</th><th>Estado</th><th>Fuente</th><th>Creado</th><th>Acciones</th></tr></thead><tbody><tr v-for="row in alerts" :key="row.alert_id"><td>{{ row.alert_code }}</td><td><strong>{{ row.title }}</strong><small class="block">{{ row.detail ?? '' }}</small></td><td><span class="status" :class="row.severity">{{ row.severity }}</span></td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.source ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td><td class="actions" v-if="row.status === 'open' || row.status === 'acknowledged'"><button class="link" @click="updateAlert(row, 'acknowledged')">Reconocer</button><button class="link" @click="updateAlert(row, 'resolved')">Resolver</button><button class="link danger-link" @click="updateAlert(row, 'ignored')">Ignorar</button></td><td v-else>—</td></tr><tr v-if="!alerts.length"><td colspan="7" class="empty">Sin alertas registradas.</td></tr></tbody></table></div></main>
    <main v-else class="panel"><div class="panel-title"><div><p class="eyebrow">AUDITORÍA</p><h2>Raw records recientes</h2></div><span class="muted">{{ records.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Tipo</th><th>ID externo</th><th>Parse</th><th>Observado</th><th>Payload</th></tr></thead><tbody><tr v-for="record in records" :key="record.raw_record_id"><td>{{ record.source_name }}</td><td>{{ record.record_type }}</td><td>{{ record.external_record_id ?? '—' }}</td><td><span class="status" :class="record.parse_status">{{ record.parse_status }}</span></td><td>{{ formatDate(record.observed_at) }}</td><td><details><summary>Ver JSON</summary><pre>{{ JSON.stringify(record.payload, null, 2) }}</pre></details></td></tr><tr v-if="!records.length"><td colspan="6" class="empty">Sin raw records cargados.</td></tr></tbody></table></div></main>
     <div v-if="selected" class="modal-backdrop" @click.self="closeReview"><section class="modal review-modal"><div class="panel-title"><div><p class="eyebrow">EVIDENCIA Y DECISIÓN</p><h2>Revisar excepción</h2></div><button class="close" @click="closeReview">×</button></div><div v-if="detail" class="review-content"><div class="review-summary"><div><span class="muted">Entrada</span><strong>{{ detail.run.raw_text ?? detail.run.normalized_input ?? '—' }}</strong></div><div><span class="muted">Origen</span><strong>{{ detail.run.input_type }}</strong></div><div><span class="muted">Motor</span><strong>{{ detail.run.engine_version ?? '—' }}</strong></div><div><span class="muted">Estado</span><span class="status" :class="detail.run.status">{{ detail.run.status }}</span></div></div><section v-if="detail.candidates.length" class="candidate-list"><h3>Candidatos del resolver</h3><label v-for="candidate in detail.candidates" :key="candidate.candidate_id" class="candidate-card" :class="{ selected: selectedCandidateId === candidate.candidate_id }"><input v-model="selectedCandidateId" type="radio" :value="candidate.candidate_id" /><span class="candidate-main"><strong>{{ candidate.display_name }}</strong><small>{{ candidate.method }} · score {{ Number(candidate.score).toFixed(3) }} · rank {{ candidate.rank }}</small><details><summary>Ver explicación</summary><pre>{{ JSON.stringify(candidate.explanation, null, 2) }}</pre></details></span></label></section><p v-else class="empty">El resolver no produjo candidatos.</p><p v-if="detail.candidates.length && !detail.run.provider_brand_id" class="hint">Esta revisión no tiene proveedor asociado; aprobarla no crea un alias global.</p><section v-if="detail.raw_record" class="evidence"><div class="section-title"><h3>Evidencia del scraper</h3><span class="muted">{{ detail.raw_record.source_name ?? 'Fuente desconocida' }} · {{ detail.raw_record.payload_bytes }} bytes</span></div><p>{{ detail.raw_record.record_type }} · {{ detail.raw_record.external_record_id ?? 'sin ID externo' }} · {{ formatDate(detail.raw_record.observed_at) }}</p><a v-if="detail.raw_record.source_url" :href="detail.raw_record.source_url" target="_blank" rel="noopener noreferrer">Abrir fuente original</a><details v-if="detail.raw_record.payload"><summary>Ver payload acotado</summary><pre>{{ JSON.stringify(detail.raw_record.payload, null, 2) }}</pre></details><button v-else class="link" @click="showPayload">Cargar payload (máximo 64 KB)</button></section><label v-if="detail.candidates.length && detail.run.provider_brand_id">Alias que se aprobará<input v-model="alias" maxlength="200" /></label><label>Motivo / notas<textarea v-model="reason" rows="3" maxlength="1000" placeholder="Explica por qué se aprueba o descarta…" /></label><div class="modal-actions"><button class="secondary" @click="closeReview">Cancelar</button><button class="danger" :disabled="loading || !reason.trim()" @click="markNoMatch">Marcar no_match</button><button class="primary" :disabled="loading || !selectedCandidateId || (aliasRequired && !alias.trim())" @click="approveCandidate">{{ loading ? 'Guardando…' : 'Aprobar candidato' }}</button></div></div><p v-else class="empty">Cargando evidencia…</p></section></div>
    <section v-if="selected && detail && !detail.candidates.length && !manualCatalogItemId" class="manual-candidate-drawer">
      <div class="panel-title"><div><p class="eyebrow">SELECCION MANUAL</p><h2>Buscar servicio canonico</h2><p class="hint">Este caso no tiene candidatos del resolver. Elige un servicio activo del catalogo; quedara registrado como candidato manual.</p></div></div>
      <form class="manual-search" @submit.prevent="searchCatalog"><input v-model="manualCatalogQuery" placeholder="Ej. biometria hematica" maxlength="200" /><button class="secondary" type="submit" :disabled="manualCatalogLoading">{{ manualCatalogLoading ? 'Buscando...' : 'Buscar' }}</button></form>
      <div v-if="manualCatalogResults.length" class="manual-results"><button v-for="item in manualCatalogResults" :key="item.item_id" type="button" class="manual-result" @click="chooseManualCatalogItem(item)"><strong>{{ item.display_name }}</strong><small>{{ item.service_type }} · {{ item.status }}</small></button></div>
       <label v-if="selected.provider_brand_id">Alias que se aprobara<input v-model="alias" maxlength="200" /></label>
    </section>
  </div>
</template>
