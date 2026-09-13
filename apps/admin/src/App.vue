<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue';
import { createAdminApi, createMutationRequestId, formatDate, type AlertRow, type CatalogItem, type Dashboard, type ExactReprocessResult, type LocationRow, type NormalizationDetail, type NormalizationRow, type OfferRow, type PriceRow, type ProviderRow, type QualityIssueRow, type RawRecord } from './api';
import { matchesPasswordCallback, supabase } from './auth';
import { toQrDataUrl } from './qr';
import { safeHttpUrl } from './safe-url';
import UiIcon from './components/UiIcon.vue';
import TableFilters, { type FilterOption } from './components/TableFilters.vue';

type Tab = 'overview' | 'providers' | 'locations' | 'offers' | 'prices' | 'queue' | 'records' | 'quality' | 'alerts';
// A production bundle must never silently target a developer's localhost.
// Keep the convenience fallback only for Vite's explicit dev mode; an absent
// production URL becomes a client configuration error and sends no token.
const api = createAdminApi(import.meta.env.VITE_API_URL ?? (import.meta.env.DEV ? 'http://localhost:8787' : ''), async () => (await supabase?.auth.getSession())?.data.session?.access_token ?? null);
const session = ref<import('@supabase/supabase-js').Session | null>(null);
const email = ref('');
const password = ref('');
const passwordSetupRequired = ref(false);
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
const mobileNavOpen = ref(false);
const loading = ref(false);
const error = ref('');
const notice = ref('');
const dashboardData = ref<Dashboard | null>(null);
const queueRows = ref<NormalizationRow[]>([]);
const queueHasMore = ref(false);
const queueLoadingMore = ref(false);
const queueStatus = ref('ambiguous');
const queueInputType = ref('');
const recordRows = ref<RawRecord[]>([]);
const providerRows = ref<ProviderRow[]>([]);
const locationRows = ref<LocationRow[]>([]);
const offerRows = ref<OfferRow[]>([]);
const priceRows = ref<PriceRow[]>([]);
const qualityIssueRows = ref<QualityIssueRow[]>([]);
const alertRows = ref<AlertRow[]>([]);
const exactReprocessLoading = ref(false);
const exactReprocessResult = ref<ExactReprocessResult | null>(null);
const selected = ref<NormalizationRow | null>(null);
const detail = ref<NormalizationDetail | null>(null);
const selectedCandidateId = ref('');
const alias = ref('');
const reason = ref('');
const manualCatalogQuery = ref('');
const manualCatalogResults = ref<CatalogItem[]>([]);
const manualCatalogItemId = ref('');
const manualCatalogLoading = ref(false);
const mutationRequestIds = new Map<string, string>();
const AUTO_REFRESH_MS = 30_000;
let autoRefreshTimer: number | null = null;
type TimeFilter = 'all' | '7' | '15' | '30';
interface TableFilterState {
  query: string;
  time: TimeFilter;
  status: string;
  secondary: string;
}

const tableFilter = reactive<TableFilterState>({ query: '', time: 'all', status: 'all', secondary: 'all' });
const timeFilterOptions: FilterOption[] = [
  { label: 'Todo', value: 'all' },
  { label: '7 días', value: '7' },
  { label: '15 días', value: '15' },
  { label: '30 días', value: '30' },
];
const allOption: FilterOption = { label: 'Todos', value: 'all' };
const statusOptions = (values: FilterOption[]): FilterOption[] => [allOption, ...values];
// Every logout or account switch advances this generation. Async Auth/API
// work captures it and must not write a late result into a different session.
let authGeneration = 0;

const aliasRequired = computed(() => Boolean(selected.value?.provider_brand_id));
const canApprove = computed(() => !loading.value
  && (!aliasRequired.value || Boolean(alias.value.trim()))
  && Boolean(selectedCandidateId.value)
  && (!manualCatalogItemId.value || Boolean(reason.value.trim())));

const navigation: { id: Tab; label: string; description: string; icon: string }[] = [
  { id: 'overview', label: 'Resumen', description: 'Estado general', icon: 'overview' },
  { id: 'providers', label: 'Proveedores', description: 'Red médica', icon: 'providers' },
  { id: 'locations', label: 'Sucursales', description: 'Cobertura', icon: 'locations' },
  { id: 'offers', label: 'Servicios', description: 'Oferta publicada', icon: 'offers' },
  { id: 'prices', label: 'Precios', description: 'Vigencia y fuente', icon: 'prices' },
  { id: 'queue', label: 'Revisión', description: 'Excepciones', icon: 'review' },
  { id: 'records', label: 'Registros fuente', description: 'Auditoría', icon: 'records' },
  { id: 'quality', label: 'Calidad', description: 'Integridad de datos', icon: 'quality' },
  { id: 'alerts', label: 'Alertas', description: 'Operación', icon: 'alerts' },
];

const cards = computed(() => {
  const current = dashboardData.value;
  if (!current) return [];
  const result = [
    { label: 'Catálogo activo', value: current.active_catalog_items, helper: 'servicios canónicos', icon: 'offers', tone: 'teal', action: undefined as string | undefined },
    { label: 'Ofertas activas', value: current.active_offers, helper: 'servicios publicados', icon: 'providers', tone: 'blue', action: undefined as string | undefined },
    { label: 'Por revisar', value: current.normalization_ambiguous, helper: 'con candidatos', icon: 'review', tone: current.normalization_ambiguous ? 'amber' : 'green', action: 'ambiguous' },
    { label: 'Alertas abiertas', value: current.open_alerts, helper: 'seguimiento operativo', icon: 'alerts', tone: current.open_alerts ? 'amber' : 'green', action: 'alerts' },
    { label: 'Críticas', value: current.critical_alerts, helper: current.critical_alerts ? 'atención inmediata' : 'todo en orden', icon: 'quality', tone: current.critical_alerts ? 'red' : 'green', action: 'alerts' },
  ];
  if (current.normalization_closed_no_match !== undefined) {
    result.splice(3, 0, {
      label: 'Sin cobertura', value: current.normalization_no_match, helper: 'faltan en el catálogo', icon: 'records', tone: current.normalization_no_match ? 'amber' : 'green', action: 'no_match',
    });
  }
  return result;
});

const currentSection = computed(() => navigation.find((entry) => entry.id === tab.value) ?? navigation[0]);
// The legacy dashboard counted finalized no_match rows as open work. Until
// the corrected RPC is present, do not expose that misleading number or its
// review entry in the operator UI.
const hasAccurateNormalizationCounts = computed(() => dashboardData.value?.normalization_closed_no_match !== undefined);
const tableFilterConfig = computed(() => {
  const base = { timeOptions: timeFilterOptions, statusLabel: 'Estado', statusOptions: undefined as FilterOption[] | undefined, secondaryLabel: 'Tipo', secondaryOptions: undefined as FilterOption[] | undefined };
  switch (tab.value) {
    case 'overview': return { ...base, placeholder: 'Buscar corrida por fuente o estado…', showTime: true, statusOptions: statusOptions([{ label: 'Completadas', value: 'succeeded' }, { label: 'Fallidas', value: 'failed' }, { label: 'Cuarentena', value: 'quarantined' }]) };
    case 'providers': return { ...base, placeholder: 'Buscar proveedor…', showTime: false, statusOptions: statusOptions([{ label: 'Activos', value: 'active' }, { label: 'Inactivos', value: 'inactive' }]), secondaryLabel: 'Verificación', secondaryOptions: statusOptions([{ label: 'Verificados', value: 'verified' }, { label: 'Pendientes', value: 'pending' }]) };
    case 'locations': return { ...base, placeholder: 'Buscar sucursal, proveedor o ciudad…', showTime: false, statusOptions: statusOptions([{ label: 'Activas', value: 'active' }, { label: 'Inactivas', value: 'inactive' }]) };
    case 'offers': return { ...base, placeholder: 'Buscar servicio o proveedor…', showTime: true, statusOptions: statusOptions([{ label: 'Activas', value: 'active' }, { label: 'Inactivas', value: 'inactive' }]) };
    case 'prices': return { ...base, placeholder: 'Buscar servicio o proveedor…', showTime: true, secondaryLabel: 'Tipo de precio', secondaryOptions: statusOptions([{ label: 'Particular', value: 'cash' }, { label: 'Aseguradora', value: 'insured' }, { label: 'Paquete', value: 'package' }]) };
    case 'queue': return { ...base, placeholder: 'Buscar texto, proveedor o fuente…', showTime: true, statusLabel: 'Resultado', statusOptions: hasAccurateNormalizationCounts.value ? statusOptions([{ label: 'Ambiguos', value: 'ambiguous' }, { label: 'Sin cobertura', value: 'no_match' }, { label: 'Pendientes', value: 'pending' }]) : statusOptions([{ label: 'Ambiguos', value: 'ambiguous' }, { label: 'Pendientes', value: 'pending' }]), secondaryLabel: 'Origen', secondaryOptions: statusOptions([{ label: 'Proveedor', value: 'crawler' }, { label: 'Búsqueda', value: 'search' }, { label: 'Receta OCR', value: 'ocr' }, { label: 'Manual', value: 'manual' }]) };
    case 'records': return { ...base, placeholder: 'Buscar fuente, tipo o ID externo…', showTime: true };
    case 'quality': return { ...base, placeholder: 'Buscar código o detalle…', showTime: true, statusOptions: statusOptions([{ label: 'Abiertas', value: 'open' }, { label: 'Reconocidas', value: 'acknowledged' }, { label: 'Resueltas', value: 'resolved' }, { label: 'Ignoradas', value: 'ignored' }]) };
    case 'alerts': return { ...base, placeholder: 'Buscar código, título o fuente…', showTime: true, statusOptions: statusOptions([{ label: 'Abiertas', value: 'open' }, { label: 'Reconocidas', value: 'acknowledged' }, { label: 'Resueltas', value: 'resolved' }, { label: 'Ignoradas', value: 'ignored' }]) };
  }
});
const adminInitial = computed(() => (session.value?.user.email?.trim().charAt(0) || 'A').toUpperCase());
const numberFormatter = new Intl.NumberFormat('es-MX');

function formatNumber(value: number): string { return numberFormatter.format(value); }

function normalizedFilterQuery(): string { return tableFilter.query.trim().toLocaleLowerCase('es-MX'); }

function matchesFilterQuery(query: string, values: unknown[]): boolean {
  const normalized = query.trim().toLocaleLowerCase('es-MX');
  if (!normalized) return true;
  return values.some((value) => String(value ?? '').toLocaleLowerCase('es-MX').includes(normalized));
}

function matchesTimeFilter(value: string | null | undefined): boolean {
  if (tableFilter.time === 'all') return true;
  if (!value) return false;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return false;
  const days = Number(tableFilter.time);
  return timestamp >= Date.now() - days * 24 * 60 * 60 * 1000;
}

function matchesStatusFilter(selected: string, values: unknown[]): boolean {
  return selected === 'all' || values.some((value) => String(value ?? '') === selected);
}

function resetTableFilter() {
  tableFilter.query = '';
  tableFilter.time = 'all';
  tableFilter.status = 'all';
  tableFilter.secondary = 'all';
}

function setTableStatus(value: string) {
  tableFilter.status = value;
  if (tab.value === 'queue') {
    queueStatus.value = value;
    void changeQueueFilter();
  }
}

function setTableTime(value: string) {
  if (value === 'all' || value === '7' || value === '15' || value === '30') tableFilter.time = value;
}

function setTableSecondary(value: string) {
  tableFilter.secondary = value;
  if (tab.value === 'queue') {
    queueInputType.value = value === 'all' ? '' : value;
    void changeQueueFilter();
  }
}

const filteredRecentRuns = computed(() => (dashboardData.value?.recent_runs ?? []).filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.source_name, row.status])
  && matchesTimeFilter(row.started_at)
  && matchesStatusFilter(tableFilter.status, [row.status])));
const filteredQueue = computed(() => queueRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.raw_text, row.normalized_input, row.provider_brand_name, row.source_name, row.status])
  && matchesTimeFilter(row.created_at)));
const filteredRecords = computed(() => recordRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.source_name, row.record_type, row.external_record_id, row.parse_status])
  && matchesTimeFilter(row.observed_at)));
const filteredProviders = computed(() => providerRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.provider_name, row.status, row.verification_status])
  && matchesStatusFilter(tableFilter.status, [row.status])
  && matchesStatusFilter(tableFilter.secondary, [row.verification_status])));
const filteredLocations = computed(() => locationRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.provider_name, row.location_name, row.address, row.locality, row.status])
  && matchesStatusFilter(tableFilter.status, [row.status])));
const filteredOffers = computed(() => offerRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.provider_name, row.service_name, row.status])
  && matchesTimeFilter(row.last_seen_at)
  && matchesStatusFilter(tableFilter.status, [row.status])));
const filteredPrices = computed(() => priceRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.provider_name, row.service_name, row.currency, row.price_type])
  && matchesTimeFilter(row.last_seen_at)
  && matchesStatusFilter(tableFilter.secondary, [row.price_type])));
const filteredQualityIssues = computed(() => qualityIssueRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.issue_code, row.severity, row.status, JSON.stringify(row.details)])
  && matchesTimeFilter(row.created_at)
  && matchesStatusFilter(tableFilter.status, [row.status])));
const filteredAlerts = computed(() => alertRows.value.filter((row) =>
  matchesFilterQuery(normalizedFilterQuery(), [row.alert_code, row.title, row.source, row.detail, row.severity, row.status])
  && matchesTimeFilter(row.created_at)
  && matchesStatusFilter(tableFilter.status, [row.status])));
// Keep the template readable while exposing only the rows matching the active
// toolbar filters. The raw collections above remain the source for refreshes.
const queue = filteredQueue;
const records = filteredRecords;
const providers = filteredProviders;
const locations = filteredLocations;
const offers = filteredOffers;
const prices = filteredPrices;
const qualityIssues = filteredQualityIssues;
const alerts = filteredAlerts;
const dashboard = computed(() => dashboardData.value
  ? { ...dashboardData.value, recent_runs: filteredRecentRuns.value }
  : null);

function statusLabel(value: string): string {
  const labels: Record<string, string> = {
    succeeded: 'Completada', failed: 'Fallida', quarantined: 'En cuarentena', partial: 'Parcial',
    active: 'Activo', inactive: 'Inactivo', verified: 'Verificado', pending: 'Pendiente',
    ambiguous: 'Ambiguo', no_match: 'Sin cobertura', resolved: 'Resuelto', approved: 'Aprobado',
    acknowledged: 'Reconocido', ignored: 'Ignorado', open: 'Abierto', critical: 'Crítico',
    high: 'Alta', medium: 'Media', low: 'Baja', parsed: 'Procesado', valid: 'Válido',
    crawler: 'Proveedor', search: 'Búsqueda', ocr: 'Receta OCR', manual: 'Manual', import: 'Importación',
    cash: 'Particular', insured: 'Aseguradora', package: 'Paquete', standard: 'Estándar',
  };
  return labels[value] ?? value.replaceAll('_', ' ');
}

async function activateSummaryCard(action?: string) {
  if (action === 'no_match' && !hasAccurateNormalizationCounts.value) return;
  if (action === 'ambiguous' || action === 'no_match') {
    queueStatus.value = action;
    await switchTab('queue');
    await changeQueueFilter();
  } else if (action === 'alerts') {
    await switchTab('alerts');
  }
}

async function previewExactReprocess() {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  exactReprocessLoading.value = true;
  error.value = '';
  try {
    const result = await api.reprocessExactNormalizations({ apply: false, limit: 200 });
    if (!isCurrentAuth(generation, userId)) return;
    exactReprocessResult.value = result;
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo analizar la cola');
  } finally {
    exactReprocessLoading.value = false;
  }
}

async function applyExactReprocess() {
  const eligible = exactReprocessResult.value?.eligible_total ?? 0;
  if (!eligible) return;
  if (typeof window !== 'undefined' && !window.confirm(`Se resolverán hasta ${Math.min(eligible, 200)} coincidencias exactas o alias aprobados. No se tocarán los casos ambiguos. ¿Continuar?`)) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  exactReprocessLoading.value = true;
  error.value = '';
  try {
    const result = await api.reprocessExactNormalizations({ apply: true, limit: 200 });
    if (!isCurrentAuth(generation, userId)) return;
    exactReprocessResult.value = result;
    notice.value = result.processed
      ? `Se resolvieron ${formatNumber(result.processed)} coincidencias seguras. Los demás casos siguen pendientes de catálogo.`
      : 'No hubo coincidencias nuevas para resolver.';
    await refresh();
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudieron reprocesar las coincidencias');
  } finally {
    exactReprocessLoading.value = false;
  }
}

function errorMessage(cause: unknown, fallback: string): string {
  return cause instanceof Error ? cause.message : fallback;
}

function clearAuthCallbackUrl() {
  if (typeof window === 'undefined') return;
  window.history.replaceState({}, document.title, window.location.pathname);
}

function sanitizeDetail(value: NormalizationDetail | null): NormalizationDetail | null {
  if (!value?.raw_record) return value;
  return {
    ...value,
    raw_record: { ...value.raw_record, source_url: safeHttpUrl(value.raw_record.source_url) },
  };
}

function isCurrentAuth(generation: number, userId: string | null): boolean {
  return generation === authGeneration && (session.value?.user.id ?? null) === userId;
}

async function establishMfa() {
  if (!supabase) return false;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  try {
  const assurance = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (!isCurrentAuth(generation, userId)) return false;
  if (assurance.error) {
    // Fail closed: a session without a confirmed assurance level must never
    // fall through to the administrative shell.
    authError.value = 'No se pudo consultar el estado MFA.';
    mfaPending.value = true;
    mfaSetupRequired.value = false;
    mfaFactorId.value = '';
    return false;
  }
  const factors = await supabase.auth.mfa.listFactors();
  if (!isCurrentAuth(generation, userId)) return false;
  if (factors.error) {
    // Keep the authenticated session behind the MFA gate while Supabase is
    // unavailable. The API independently requires aal2 as a second defense.
    authError.value = 'No se pudieron consultar los factores MFA.';
    mfaPending.value = true;
    mfaSetupRequired.value = false;
    mfaFactorId.value = '';
    return false;
  }
  // Supabase can temporarily report a stale aal2 JWT after a factor is
  // unenrolled. Never render the administrative shell unless the current
  // factors response still contains a verified factor as well.
  const hasVerifiedFactor = factors.data.all.some((factor) => factor.status === 'verified');
  if (assurance.data.currentLevel === 'aal2' && hasVerifiedFactor) {
    mfaPending.value = false;
    mfaSetupRequired.value = false;
    await refresh();
    return true;
  }
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
    if (!isCurrentAuth(generation, userId)) return false;
    authError.value = 'No se pudo consultar el estado de autenticación. Inténtalo de nuevo.';
    mfaPending.value = true;
    return false;
  }
}

async function verifyMfa() {
  if (!supabase || !mfaFactorId.value || !/^\d{6}$/.test(mfaCode.value.trim())) {
    authError.value = 'Escribe el codigo de seis digitos de tu autenticador.';
    return;
  }
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  mfaLoading.value = true;
  authError.value = '';
  try {
  const challenge = await supabase.auth.mfa.challenge({ factorId: mfaFactorId.value });
  if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
  if (challenge.error) { authError.value = 'No se pudo iniciar el desafío MFA.'; mfaLoading.value = false; return; }
  mfaChallengeId.value = challenge.data.id;
  const verification = await supabase.auth.mfa.verify({ factorId: mfaFactorId.value, challengeId: mfaChallengeId.value, code: mfaCode.value.trim() });
  if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
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
    if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
    authError.value = 'No se pudo completar la verificación MFA. Inténtalo de nuevo.';
    mfaChallengeId.value = '';
  }
  mfaLoading.value = false;
}

async function beginEnrollment() {
  if (!supabase) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  mfaLoading.value = true;
  authError.value = '';
  try {
    // A failed first enrollment can leave an unverified factor behind. Auth
    // refuses a second enrollment while that orphan exists, so remove only
    // unverified TOTP factors owned by this already-authenticated session.
    const currentFactors = await supabase.auth.mfa.listFactors();
    if (currentFactors.error) throw currentFactors.error;
    for (const factor of currentFactors.data.totp.filter((item) => item.status === 'unverified')) {
      const removed = await supabase.auth.mfa.unenroll({ factorId: factor.id });
      if (removed.error) throw removed.error;
    }
    const result = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: `Admin ${session.value?.user.email ?? email.value.trim()}` });
    if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
    if (result.error) authError.value = 'No se pudo iniciar el registro del autenticador.';
    else {
      enrollmentFactorId.value = result.data.id;
      // Keep the value intact and normalize raw/data-URL variants at render
      // time. This prevents double-encoding when the SDK already encoded it.
      enrollmentQr.value = result.data.totp.qr_code;
      enrollmentSecret.value = result.data.totp.secret;
    }
  } catch {
    if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
    authError.value = 'No se pudo iniciar el registro del autenticador. Inténtalo de nuevo.';
  }
  mfaLoading.value = false;
}

async function verifyEnrollment() {
  if (!supabase || !enrollmentFactorId.value || !/^\d{6}$/.test(enrollmentCode.value.trim())) {
    authError.value = 'Escribe el codigo de seis digitos mostrado por tu autenticador.';
    return;
  }
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  mfaLoading.value = true;
  authError.value = '';
  try {
  const challenge = await supabase.auth.mfa.challenge({ factorId: enrollmentFactorId.value });
  if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
  if (challenge.error) { authError.value = 'No se pudo validar el autenticador.'; mfaLoading.value = false; return; }
  const verification = await supabase.auth.mfa.verify({ factorId: enrollmentFactorId.value, challengeId: challenge.data.id, code: enrollmentCode.value.trim() });
  if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
  if (verification.error) { authError.value = 'El código no es válido. Revisa la hora del dispositivo.'; mfaLoading.value = false; return; }
  enrollmentCode.value = '';
  enrollmentQr.value = '';
  enrollmentSecret.value = '';
  mfaLoading.value = false;
  await supabase.auth.refreshSession();
  await establishMfa();
  } catch {
    if (!isCurrentAuth(generation, userId)) { mfaLoading.value = false; return; }
    authError.value = 'No se pudo completar el registro MFA. Inténtalo de nuevo.';
  }
  mfaLoading.value = false;
}

async function loadQueue(reset = true) {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  const last = queueRows.value[queueRows.value.length - 1];
  const cursor = !reset && last ? { before_created_at: last.created_at, before_id: last.normalization_run_id } : undefined;
  // Before the corrected queue RPC is installed, its "all" and "no_match"
  // filters include finalized audit rows. Fail closed to the actionable
  // ambiguous queue rather than showing stale work to an operator.
  if (!hasAccurateNormalizationCounts.value && (queueStatus.value === 'all' || queueStatus.value === 'no_match')) {
    queueStatus.value = 'ambiguous';
  }
  const rows = await api.normalizationQueue(queueStatus.value === 'all' ? undefined : queueStatus.value, queueInputType.value || undefined, cursor);
  if (!isCurrentAuth(generation, userId)) return;
  if (reset) queueRows.value = rows;
  else queueRows.value = [...queueRows.value, ...rows];
  queueHasMore.value = rows.length === 100;
}

async function loadMoreQueue() {
  if (!queueHasMore.value || queueLoadingMore.value) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  queueLoadingMore.value = true;
  try { await loadQueue(false); }
  catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo cargar más casos');
  }
  finally { queueLoadingMore.value = false; }
}

async function refresh() {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  loading.value = true;
  error.value = '';
  try {
    const nextDashboard = await api.dashboard();
    if (!isCurrentAuth(generation, userId)) return;
    dashboardData.value = nextDashboard;
    if (tab.value === 'queue') await loadQueue();
    if (tab.value === 'records') { const value = await api.rawRecords(); if (!isCurrentAuth(generation, userId)) return; recordRows.value = value; }
    if (tab.value === 'providers') { const value = await api.providers(); if (!isCurrentAuth(generation, userId)) return; providerRows.value = value; }
    if (tab.value === 'locations') { const value = await api.locations(); if (!isCurrentAuth(generation, userId)) return; locationRows.value = value; }
    if (tab.value === 'offers') { const value = await api.offers(); if (!isCurrentAuth(generation, userId)) return; offerRows.value = value; }
    if (tab.value === 'prices') { const value = (await api.prices()).map((row) => ({ ...row, source_url: safeHttpUrl(row.source_url) })); if (!isCurrentAuth(generation, userId)) return; priceRows.value = value; }
    if (tab.value === 'quality') { const value = await api.qualityIssues(); if (!isCurrentAuth(generation, userId)) return; qualityIssueRows.value = value; }
    if (tab.value === 'alerts') { const value = await api.alerts(); if (!isCurrentAuth(generation, userId)) return; alertRows.value = value; }
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo consultar la API');
  }
  finally { loading.value = false; }
}

function stopAutoRefresh() {
  if (autoRefreshTimer === null || typeof window === 'undefined') return;
  window.clearInterval(autoRefreshTimer);
  autoRefreshTimer = null;
}

function startAutoRefresh() {
  if (typeof window === 'undefined') return;
  stopAutoRefresh();
  autoRefreshTimer = window.setInterval(() => {
    if (document.visibilityState !== 'visible' || !session.value || loading.value || authFlowInProgress) return;
    void refresh();
  }, AUTO_REFRESH_MS);
}

function refreshOnVisibilityChange() {
  if (document.visibilityState === 'visible' && session.value && !loading.value) void refresh();
}

async function switchTab(next: Tab) {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  if (next !== tab.value) resetTableFilter();
  if (next === 'queue') {
    tableFilter.status = queueStatus.value || 'all';
    tableFilter.secondary = queueInputType.value || 'all';
  }
  tab.value = next;
  mobileNavOpen.value = false;
  notice.value = '';
  try {
    if (next === 'queue' && !queueRows.value.length) await loadQueue();
    if (next === 'records' && !recordRows.value.length) { const value = await api.rawRecords(); if (!isCurrentAuth(generation, userId)) return; recordRows.value = value; }
    if (next === 'providers' && !providerRows.value.length) { const value = await api.providers(); if (!isCurrentAuth(generation, userId)) return; providerRows.value = value; }
    if (next === 'locations' && !locationRows.value.length) { const value = await api.locations(); if (!isCurrentAuth(generation, userId)) return; locationRows.value = value; }
    if (next === 'offers' && !offerRows.value.length) { const value = await api.offers(); if (!isCurrentAuth(generation, userId)) return; offerRows.value = value; }
    if (next === 'prices' && !priceRows.value.length) { const value = (await api.prices()).map((row) => ({ ...row, source_url: safeHttpUrl(row.source_url) })); if (!isCurrentAuth(generation, userId)) return; priceRows.value = value; }
    if (next === 'quality' && !qualityIssueRows.value.length) { const value = await api.qualityIssues(); if (!isCurrentAuth(generation, userId)) return; qualityIssueRows.value = value; }
    if (next === 'alerts' && !alertRows.value.length) { const value = await api.alerts(); if (!isCurrentAuth(generation, userId)) return; alertRows.value = value; }
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo cargar la sección');
  }
}

async function changeQueueFilter() {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  try { await loadQueue(); }
  catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo cargar la cola');
  }
}

async function searchCatalog() {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  const query = manualCatalogQuery.value.trim();
  manualCatalogItemId.value = '';
  if (query.length < 2) { manualCatalogResults.value = []; return; }
  manualCatalogLoading.value = true;
  try {
    const value = await api.catalogItems(query);
    if (!isCurrentAuth(generation, userId)) return;
    manualCatalogResults.value = value;
  }
  catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo buscar en el catálogo');
  }
  finally { manualCatalogLoading.value = false; }
}

function chooseManualCatalogItem(item: CatalogItem) {
  manualCatalogItemId.value = item.item_id;
  selectedCandidateId.value = item.item_id;
}

async function openRow(row: NormalizationRow) {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  selected.value = row;
  detail.value = null;
  selectedCandidateId.value = '';
  alias.value = row.raw_text ?? row.normalized_input ?? '';
  reason.value = '';
  manualCatalogQuery.value = '';
  manualCatalogResults.value = [];
  manualCatalogItemId.value = '';
  try {
    const value = sanitizeDetail(await api.normalizationDetail(row.normalization_run_id));
    if (!isCurrentAuth(generation, userId)) return;
    detail.value = value;
    if (detail.value?.candidates.length === 1) selectedCandidateId.value = detail.value.candidates[0].candidate_id;
  } catch (cause) { if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo cargar la evidencia'); }
}

function closeReview() {
  const runId = selected.value?.normalization_run_id;
  if (runId) {
    mutationRequestIds.delete(`normalization:${runId}:approve`);
    mutationRequestIds.delete(`normalization:${runId}:no_match`);
  }
  selected.value = null;
  detail.value = null;
  selectedCandidateId.value = '';
}

function mutationRequestId(key: string): string {
  const existing = mutationRequestIds.get(key);
  if (existing) return existing;
  const created = createMutationRequestId();
  mutationRequestIds.set(key, created);
  return created;
}

function clearMutationRequestId(key: string) { mutationRequestIds.delete(key); }

async function showPayload() {
  if (!selected.value) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  const runId = selected.value.normalization_run_id;
  try {
    const value = sanitizeDetail(await api.normalizationDetail(runId, true));
    if (!isCurrentAuth(generation, userId)) return;
    detail.value = value;
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo cargar el payload');
  }
}

async function approveCandidate() {
  if (!canApprove.value || !selected.value) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  loading.value = true;
  error.value = '';
  const runId = selected.value.normalization_run_id;
  const requestId = mutationRequestId(`normalization:${runId}:approve`);
  try {
    let candidateId = selectedCandidateId.value;
    if (manualCatalogItemId.value && candidateId === manualCatalogItemId.value) candidateId = '';
    if (!candidateId && manualCatalogItemId.value) {
      if (!reason.value.trim()) {
        error.value = 'Escribe el motivo de la selección manual antes de aprobar.';
        return;
      }
      const manual = await api.addManualCandidate(runId, {
        catalog_item_id: manualCatalogItemId.value,
        reason: reason.value.trim(),
      }, `${requestId}:candidate`);
      if (!isCurrentAuth(generation, userId)) return;
      candidateId = manual.candidate_id;
    }
    if (!candidateId) return;
    const reviewInput: { decision: 'approve_candidate'; selected_candidate_id: string; alias?: string; reason?: string } = {
      decision: 'approve_candidate',
      selected_candidate_id: candidateId,
      reason: reason.value.trim() || undefined,
    };
    if (aliasRequired.value) reviewInput.alias = alias.value.trim();
    await api.reviewNormalization(runId, reviewInput, requestId);
    if (!isCurrentAuth(generation, userId)) return;
    notice.value = aliasRequired.value
      ? 'Candidato aprobado y alias guardado para futuras resoluciones.'
      : 'Candidato aprobado. No se creó un alias global fuera de un proveedor.';
    closeReview();
    await loadQueue();
    const nextDashboard = await api.dashboard();
    if (!isCurrentAuth(generation, userId)) return;
    dashboardData.value = nextDashboard;
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo aprobar el candidato');
  }
  finally { loading.value = false; }
}

async function markNoMatch() {
  if (!selected.value || !reason.value.trim()) return;
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  loading.value = true;
  error.value = '';
  const runId = selected.value.normalization_run_id;
  const requestId = mutationRequestId(`normalization:${runId}:no_match`);
  try {
    await api.reviewNormalization(runId, { decision: 'no_match', reason: reason.value.trim() }, requestId);
    if (!isCurrentAuth(generation, userId)) return;
    notice.value = 'Caso marcado como no_match y no se publicará ninguna equivalencia.';
    closeReview();
    await loadQueue();
    const nextDashboard = await api.dashboard();
    if (!isCurrentAuth(generation, userId)) return;
    dashboardData.value = nextDashboard;
  } catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo marcar el caso');
  }
  finally { loading.value = false; }
}

async function updateAlert(row: AlertRow, status: 'acknowledged' | 'resolved' | 'ignored') {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  const key = `alert:${row.alert_id}:${status}`;
  try {
    await api.updateAlertStatus(row.alert_id, status, undefined, mutationRequestId(key));
    if (!isCurrentAuth(generation, userId)) return;
    row.status = status;
    clearMutationRequestId(key);
    notice.value = `Alerta actualizada: ${status}.`;
    const nextDashboard = await api.dashboard();
    if (!isCurrentAuth(generation, userId)) return;
    dashboardData.value = nextDashboard;
  }
  catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo actualizar la alerta');
  }
}

async function updateQuality(row: QualityIssueRow, status: 'acknowledged' | 'resolved' | 'ignored') {
  const generation = authGeneration;
  const userId = session.value?.user.id ?? null;
  const key = `quality:${row.issue_id}:${status}`;
  try {
    await api.updateQualityIssueStatus(row.issue_id, status, undefined, mutationRequestId(key));
    if (!isCurrentAuth(generation, userId)) return;
    row.status = status;
    clearMutationRequestId(key);
    notice.value = `Issue actualizado: ${status}.`;
    const nextDashboard = await api.dashboard();
    if (!isCurrentAuth(generation, userId)) return;
    dashboardData.value = nextDashboard;
  }
  catch (cause) {
    if (isCurrentAuth(generation, userId)) error.value = errorMessage(cause, 'No se pudo actualizar el issue');
  }
}

async function signIn() {
  if (!supabase || !email.value.trim() || !password.value) return;
  if (email.value.trim().length > 320 || password.value.length > 256) {
    authError.value = 'El correo o la contraseña exceden el límite permitido.';
    return;
  }
  const generation = authGeneration;
  authLoading.value = true;
  authError.value = '';
  authFlowInProgress = true;
  try {
  const result = await supabase.auth.signInWithPassword({ email: email.value.trim(), password: password.value });
  password.value = '';
  if (authGeneration !== generation) { authLoading.value = false; return; }
  if (result.error) { authError.value = 'No se pudo iniciar sesión.'; authLoading.value = false; return; }
  session.value = result.data.session;
  await establishMfa();
  } catch {
    if (authGeneration !== generation) return;
    authError.value = 'No se pudo iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';
  } finally {
    authFlowInProgress = false;
    authLoading.value = false;
  }
}

async function setPassword() {
  if (!supabase || !session.value) return;
  const generation = authGeneration;
  const userId = session.value.user.id;
  if (newPassword.value.length < 12 || newPassword.value.length > 256) {
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
    if (!isCurrentAuth(generation, userId)) { authLoading.value = false; return; }
    if (result.error) {
      authError.value = 'No se pudo guardar la contraseña. Solicita una nueva invitación si el enlace expiró.';
      return;
    }
    newPassword.value = '';
    confirmPassword.value = '';
    passwordSetupRequired.value = false;
    await establishMfa();
  } catch {
    if (!isCurrentAuth(generation, userId)) return;
    authError.value = 'No se pudo guardar la contraseña. Inténtalo de nuevo.';
  } finally {
    authLoading.value = false;
  }
}

async function signOut() {
  // Invalidate in-flight enrollment, MFA and data requests before waiting on
  // the network logout. Otherwise a late TOTP secret or admin response could
  // be written after the user has already initiated a different session.
  authGeneration += 1;
  try { await supabase?.auth.signOut(); }
  catch { /* Local state is cleared even if the network logout fails. */ }
  finally { resetAdminState(); }
}

function resetAdminState(options: { preservePasswordSetup?: boolean } = {}) {
  authGeneration += 1;
  mutationRequestIds.clear();
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
  loading.value = false;
  exactReprocessLoading.value = false;
  exactReprocessResult.value = null;
  tab.value = 'overview';
  mobileNavOpen.value = false;
  queueRows.value = [];
  queueHasMore.value = false;
  queueLoadingMore.value = false;
  recordRows.value = [];
  providerRows.value = [];
  locationRows.value = [];
  offerRows.value = [];
  priceRows.value = [];
  qualityIssueRows.value = [];
  alertRows.value = [];
  dashboardData.value = null;
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
  const generation = authGeneration;
  // A URL query flag alone is attacker-controlled. Enter password setup only
  // after Supabase has accepted a real recovery/invitation credential and
  // emitted the corresponding authenticated event.
  const validatedPasswordFlow = Boolean(nextSession) && (event === 'PASSWORD_RECOVERY'
    || (['SIGNED_IN', 'INITIAL_SESSION'].includes(event) && matchesPasswordCallback(nextSession)));
  if (validatedPasswordFlow) {
    passwordSetupRequired.value = true;
    clearAuthCallbackUrl();
  }
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
    if (!passwordSetupRequired.value && isCurrentAuth(authGeneration, nextUserId)) await establishMfa();
    return;
  }
  if (event === 'TOKEN_REFRESHED' && !passwordSetupRequired.value) {
    if (isCurrentAuth(generation, nextUserId)) await establishMfa();
  }
}

onMounted(async () => {
  if (typeof document !== 'undefined') document.addEventListener('visibilitychange', refreshOnVisibilityChange);
  startAutoRefresh();
  if (!supabase) return;
  try {
    // Subscribe before waiting for SDK initialization; it emits INITIAL_SESSION
    // for restoration. Defer Auth calls until its notification lock is released.
    const subscription = supabase.auth.onAuthStateChange((event, nextSession) => {
      setTimeout(() => {
        if (authSubscription) void syncAuthState(nextSession, event);
      }, 0);
    });
    authSubscription = subscription.data.subscription;
  } catch {
    resetAdminState();
    authError.value = 'No se pudo restaurar la sesión. Inicia sesión de nuevo.';
  }
});
onUnmounted(() => {
  stopAutoRefresh();
  if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', refreshOnVisibilityChange);
  authGeneration += 1;
  authSubscription?.unsubscribe();
  authSubscription = null;
  enrollmentQr.value = '';
  enrollmentSecret.value = '';
  enrollmentCode.value = '';
  mfaCode.value = '';
  newPassword.value = '';
  confirmPassword.value = '';
});
</script>

<template>
  <main v-if="!supabase" class="auth-shell"><section class="auth-card auth-card-centered"><div class="brand-lockup"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><span class="auth-icon error-icon"><UiIcon name="alerts" :size="25" /></span><p class="eyebrow">CONFIGURACIÓN REQUERIDA</p><h1>Admin no configurado</h1><p class="subtitle">Agrega las variables de Supabase para habilitar el acceso seguro.</p><div class="config-note"><code>VITE_SUPABASE_URL</code><code>VITE_SUPABASE_PUBLISHABLE_KEY</code></div></section></main>
  <main v-else-if="!session" class="auth-shell"><section class="auth-welcome"><div class="auth-brand"><div class="brand-lockup light"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><div><p class="eyebrow">CENTRO DE OPERACIONES</p><h2>Datos confiables para decisiones más claras.</h2><p>Administra catálogo, proveedores y calidad desde un espacio protegido.</p></div><ul><li><UiIcon name="check" :size="17" />Acceso con doble factor</li><li><UiIcon name="check" :size="17" />Cambios siempre auditados</li><li><UiIcon name="check" :size="17" />Revisión clínica controlada</li></ul></div><form class="auth-card" @submit.prevent="signIn"><div class="brand-lockup mobile-brand"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><span class="auth-icon"><UiIcon name="lock" :size="25" /></span><p class="eyebrow">ACCESO ADMINISTRATIVO</p><h1>Bienvenido de nuevo</h1><p class="subtitle">Ingresa con la cuenta que recibió la invitación de Pruevia.</p><label>Correo electrónico<div class="input-shell"><UiIcon name="mail" :size="18" /><input v-model="email" type="email" autocomplete="username" placeholder="nombre@empresa.com" required /></div></label><label>Contraseña<div class="input-shell"><UiIcon name="lock" :size="18" /><input v-model="password" type="password" autocomplete="current-password" placeholder="Tu contraseña" required /></div></label><p v-if="authError" class="alert error"><UiIcon name="alerts" :size="18" />{{ authError }}</p><button class="primary primary-large" type="submit" :disabled="authLoading"><span>{{ authLoading ? 'Verificando acceso…' : 'Continuar' }}</span><UiIcon v-if="!authLoading" name="arrow" :size="18" /></button><p class="auth-footnote"><UiIcon name="lock" :size="14" />Sesión exclusiva para personal autorizado.</p></form></section></main>
  <main v-else-if="passwordSetupRequired" class="auth-shell"><form class="auth-card auth-card-centered" @submit.prevent="setPassword"><div class="brand-lockup"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><div class="setup-progress"><span class="active">1</span><i></i><span>2</span></div><p class="eyebrow">PASO 1 DE 2</p><h1>Protege tu cuenta</h1><p class="subtitle">Crea una contraseña única de al menos 12 caracteres. Después configuraremos tu autenticador.</p><label>Nueva contraseña<div class="input-shell"><UiIcon name="lock" :size="18" /><input v-model="newPassword" type="password" autocomplete="new-password" minlength="12" required /></div></label><label>Confirmar contraseña<div class="input-shell"><UiIcon name="check" :size="18" /><input v-model="confirmPassword" type="password" autocomplete="new-password" minlength="12" required /></div></label><p class="password-hint">Usa una frase larga que no utilices en ningún otro servicio.</p><p v-if="authError" class="alert error"><UiIcon name="alerts" :size="18" />{{ authError }}</p><button class="primary primary-large" type="submit" :disabled="authLoading">{{ authLoading ? 'Guardando…' : 'Guardar y continuar' }}</button><button class="text-button" type="button" @click="signOut">Cancelar y cerrar sesión</button></form></main>
  <main v-else-if="mfaPending" class="auth-shell"><form v-if="mfaSetupRequired && !enrollmentQr" class="auth-card auth-card-centered" @submit.prevent="beginEnrollment"><div class="brand-lockup"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><div class="setup-progress"><span class="done"><UiIcon name="check" :size="14" /></span><i class="done"></i><span class="active">2</span></div><span class="auth-icon"><UiIcon name="phone" :size="25" /></span><p class="eyebrow">PASO 2 DE 2</p><h1>Activa el segundo factor</h1><p class="subtitle">Usaremos un código temporal para confirmar que realmente eres tú al realizar cambios importantes.</p><div class="info-box"><UiIcon name="quality" :size="19" /><span>Compatible con Google Authenticator, Microsoft Authenticator, Authy y 1Password.</span></div><p v-if="authError" class="alert error"><UiIcon name="alerts" :size="18" />{{ authError }}</p><button class="primary primary-large" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Preparando código…' : 'Configurar autenticador' }}</button><button class="text-button" type="button" @click="signOut">Cerrar sesión</button></form><form v-else-if="mfaSetupRequired" class="auth-card qr-card" @submit.prevent="verifyEnrollment"><div class="brand-lockup"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><p class="eyebrow">CONECTA TU APLICACIÓN</p><h1>Escanea y confirma</h1><p class="subtitle">1. Escanea el QR. &nbsp;2. Escribe abajo los seis dígitos que aparezcan.</p><div class="qr-frame"><img v-if="toQrDataUrl(enrollmentQr)" class="totp-qr" :src="toQrDataUrl(enrollmentQr)" alt="Código QR para configurar TOTP" /><p v-else class="hint">No se pudo cargar el código QR. Usa la clave manual o vuelve a iniciar el registro.</p></div><details class="secret"><summary>No puedo escanear el código QR</summary><p>Agrega esta clave manualmente:</p><code>{{ enrollmentSecret }}</code><p class="hint">No la compartas ni la guardes en capturas.</p></details><label class="code-label">Código de verificación<input v-model="enrollmentCode" class="code-input" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" placeholder="000000" autofocus required /></label><p v-if="authError" class="alert error"><UiIcon name="alerts" :size="18" />{{ authError }}</p><button class="primary primary-large" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Verificando código…' : 'Activar y entrar' }}</button><button class="text-button" type="button" @click="signOut">Cancelar configuración</button></form><form v-else class="auth-card auth-card-centered" @submit.prevent="verifyMfa"><div class="brand-lockup"><span class="brand-mark"><UiIcon name="locations" :size="22" /></span><strong>Pruevia</strong></div><span class="auth-icon"><UiIcon name="quality" :size="26" /></span><p class="eyebrow">VERIFICACIÓN DE SEGURIDAD</p><h1>Confirma tu identidad</h1><p class="subtitle">Abre tu autenticador y escribe el código actual de seis dígitos.</p><label class="code-label">Código temporal<input v-model="mfaCode" class="code-input" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" placeholder="000000" autofocus required /></label><p class="code-hint">El código cambia cada 30 segundos.</p><p v-if="authError" class="alert error"><UiIcon name="alerts" :size="18" />{{ authError }}</p><button class="primary primary-large" type="submit" :disabled="mfaLoading">{{ mfaLoading ? 'Verificando…' : 'Entrar al panel' }}</button><button class="text-button" type="button" @click="signOut">Usar otra cuenta</button></form></main>
   <div v-else class="shell">
    <header class="topbar"><button class="mobile-menu" type="button" aria-label="Abrir menú" @click="mobileNavOpen = !mobileNavOpen"><UiIcon :name="mobileNavOpen ? 'close' : 'menu'" :size="21" /></button><div><p class="breadcrumb">Operaciones <span>/</span> {{ currentSection.label }}</p><h1>{{ currentSection.label }}</h1><p class="subtitle">{{ currentSection.description }} · Información operativa de Pruevia</p></div><div class="topbar-actions"><span class="system-state"><i></i>Sincronización automática</span><button class="refresh" :disabled="loading" @click="refresh"><UiIcon name="refresh" :size="17" />{{ loading ? 'Actualizando…' : 'Actualizar' }}</button></div></header>
    <nav class="tabs" :class="{ open: mobileNavOpen }" aria-label="Secciones administrativas"><div class="brand-lockup nav-brand"><span class="brand-mark"><UiIcon name="locations" :size="21" /></span><strong>Pruevia</strong><span class="admin-badge">Admin</span></div><p class="nav-heading">MENÚ PRINCIPAL</p><button v-for="entry in navigation" :key="entry.id" :class="{ active: tab === entry.id }" @click="switchTab(entry.id)"><span class="nav-icon"><UiIcon :name="entry.icon" :size="19" /></span><span class="nav-copy"><strong>{{ entry.label }}</strong><small>{{ entry.description }}</small></span><span v-if="entry.id === 'queue' && hasAccurateNormalizationCounts && dashboard?.normalization_pending" class="nav-count">{{ formatNumber(dashboard.normalization_pending) }}</span><span v-if="entry.id === 'alerts' && dashboard?.open_alerts" class="nav-dot"></span></button><div class="nav-session"><span class="avatar">{{ adminInitial }}</span><span><strong>{{ session.user.email }}</strong><small>Administrador</small></span><button type="button" title="Cerrar sesión" aria-label="Cerrar sesión" @click="signOut"><UiIcon name="logout" :size="18" /></button></div></nav>
    <TableFilters
      :query="tableFilter.query"
      :time="tableFilter.time"
      :status="tableFilter.status"
      :secondary="tableFilter.secondary"
      :placeholder="tableFilterConfig.placeholder"
      :show-time="tableFilterConfig.showTime"
      :time-options="tableFilterConfig.timeOptions"
      :status-label="tableFilterConfig.statusLabel"
      :status-options="tableFilterConfig.statusOptions"
      :secondary-label="tableFilterConfig.secondaryLabel"
      :secondary-options="tableFilterConfig.secondaryOptions"
      @update:query="tableFilter.query = $event"
      @update:time="setTableTime"
      @update:status="setTableStatus"
      @update:secondary="setTableSecondary"
    />
    <p v-if="error" class="alert error">{{ error }}</p><p v-if="notice" class="alert success">{{ notice }}</p>
    <template v-if="tab === 'overview'">
    <main v-if="tab === 'overview'"><section class="welcome-row"><div><p class="eyebrow">PANORAMA GENERAL</p><h2>Todo lo importante, en un vistazo</h2><p class="subtitle">Prioriza excepciones reales y deja el trabajo repetitivo a la automatización.</p></div><span class="live-label"><UiIcon name="refresh" :size="14" />Datos en tiempo real</span></section><section class="cards"><button v-for="card in cards" :key="card.label" type="button" class="card" :class="`tone-${card.tone}`" :disabled="!card.action" @click="activateSummaryCard(card.action)"><span class="card-icon"><UiIcon :name="card.icon" :size="20" /></span><span class="card-copy"><small>{{ card.label }}</small><strong>{{ formatNumber(card.value) }}</strong><span>{{ card.helper }}</span></span><UiIcon v-if="card.action" class="card-arrow" name="arrow" :size="16" /></button></section><section v-if="dashboard?.normalization_no_match && dashboard?.normalization_closed_no_match !== undefined" class="coverage-banner"><span class="coverage-icon"><UiIcon name="quality" :size="23" /></span><div><h3>No tienes que revisar {{ formatNumber(dashboard.normalization_no_match) }} casos uno por uno</h3><p>Representan cobertura faltante del catálogo. Primero deben reprocesarse y agruparse; la revisión humana queda sólo para decisiones reales.</p></div><button class="secondary" type="button" @click="activateSummaryCard('no_match')">Ver cobertura<UiIcon name="arrow" :size="16" /></button></section><section class="panel"><div class="panel-title"><div><p class="eyebrow">ACTIVIDAD DE INGESTA</p><h2>Corridas recientes</h2><p class="panel-description">Últimas actualizaciones recibidas de laboratorios y proveedores.</p></div><span v-if="dashboard" class="record-count">{{ dashboard.sources }} fuentes · {{ dashboard.crawl_runs }} corridas</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Estado</th><th>Recibidos</th><th>Válidos</th><th>Publicados</th><th>Inicio</th></tr></thead><tbody><tr v-for="run in dashboard?.recent_runs ?? []" :key="run.id"><td><strong>{{ run.source_name }}</strong></td><td><span class="status" :class="run.status"><i></i>{{ statusLabel(run.status) }}</span></td><td>{{ formatNumber(run.records_received) }}</td><td>{{ formatNumber(run.records_valid) }}</td><td>{{ formatNumber(run.records_published) }}</td><td>{{ formatDate(run.started_at) }}</td></tr><tr v-if="!dashboard?.recent_runs?.length"><td colspan="6" class="empty">Sin corridas todavía.</td></tr></tbody></table></div></section></main>
    <section v-if="tab === 'overview' && dashboard?.normalization_no_match && dashboard?.normalization_closed_no_match !== undefined" class="coverage-actions-panel panel"><div><p class="eyebrow">AUTOMATIZACIÓN SEGURA</p><h3>Reduce el trabajo repetitivo</h3><p class="panel-description">Primero analizamos coincidencias exactas y alias ya aprobados. Nada ambiguo se resuelve automáticamente.</p></div><div class="coverage-actions"><button class="secondary" type="button" :disabled="exactReprocessLoading" @click="previewExactReprocess"><UiIcon name="refresh" :size="16" />{{ exactReprocessLoading ? 'Analizando…' : 'Analizar coincidencias' }}</button><button v-if="exactReprocessResult?.eligible_total" class="primary" type="button" :disabled="exactReprocessLoading" @click="applyExactReprocess">Resolver {{ formatNumber(Math.min(exactReprocessResult.eligible_total, 200)) }} seguras</button><p v-if="exactReprocessResult" class="coverage-result">{{ exactReprocessResult.applied ? `Resueltas ${formatNumber(exactReprocessResult.processed)}` : `${formatNumber(exactReprocessResult.eligible_total)} coincidencias seguras disponibles` }} · {{ formatNumber(exactReprocessResult.remaining_eligible) }} restantes</p></div></section>
    <p v-if="tab === 'overview' && dashboard?.normalization_closed_no_match" class="closed-coverage-note"><UiIcon name="check" :size="16" /><span><strong>{{ formatNumber(dashboard.normalization_closed_no_match) }}</strong> registros ya están cerrados como “sin cobertura” y se conservan en la auditoría. No requieren revisión manual.</span></p>
    </template>
    <main v-else-if="tab === 'providers'" class="panel"><div class="panel-title"><div><p class="eyebrow">RED MÉDICA</p><h2>Proveedores</h2><p class="panel-description">Organizaciones disponibles para los pacientes.</p></div><span class="record-count">{{ providers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Estado</th><th>Verificación</th><th>Sucursales</th><th>Servicios</th></tr></thead><tbody><tr v-for="row in providers" :key="row.provider_id"><td><strong>{{ row.provider_name }}</strong></td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ statusLabel(row.verification_status) }}</td><td>{{ row.locations_count }}</td><td>{{ row.active_offers_count }}</td></tr><tr v-if="!providers.length"><td colspan="5" class="empty">Sin proveedores.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'locations'" class="panel"><div class="panel-title"><div><p class="eyebrow">COBERTURA GEOGRÁFICA</p><h2>Sucursales</h2><p class="panel-description">Ubicaciones donde se ofrecen los servicios.</p></div><span class="record-count">{{ locations.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Sucursal</th><th>Dirección</th><th>Localidad</th><th>Estado</th><th>Coordenadas</th></tr></thead><tbody><tr v-for="row in locations" :key="row.location_id"><td><strong>{{ row.provider_name }}</strong></td><td>{{ row.location_name }}</td><td>{{ row.address ?? '—' }}</td><td>{{ row.locality ?? '—' }}</td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ row.latitude ?? '—' }}, {{ row.longitude ?? '—' }}</td></tr><tr v-if="!locations.length"><td colspan="6" class="empty">Sin sucursales.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'offers'" class="panel"><div class="panel-title"><div><p class="eyebrow">CATÁLOGO PUBLICADO</p><h2>Servicios</h2><p class="panel-description">Oferta activa por proveedor.</p></div><span class="record-count">{{ offers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Estado</th><th>Precios vigentes</th><th>Última observación</th></tr></thead><tbody><tr v-for="row in offers" :key="row.offer_id"><td><strong>{{ row.provider_name }}</strong></td><td>{{ row.service_name }}</td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ row.current_price_count }}</td><td>{{ formatDate(row.last_seen_at) }}</td></tr><tr v-if="!offers.length"><td colspan="5" class="empty">Sin servicios.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'prices'" class="panel"><div class="panel-title"><div><p class="eyebrow">PRECIOS VIGENTES</p><h2>Precios</h2><p class="panel-description">Importes publicados y su última fuente de verificación.</p></div><span class="record-count">{{ prices.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Tipo</th><th>Importe</th><th>Última observación</th><th>Fuente</th></tr></thead><tbody><tr v-for="row in prices" :key="row.price_version_id"><td><strong>{{ row.provider_name }}</strong></td><td>{{ row.service_name }}</td><td>{{ statusLabel(row.price_type) }}</td><td><strong>{{ row.amount_minor / 100 }} {{ row.currency }}</strong></td><td>{{ formatDate(row.last_seen_at) }}</td><td><a v-if="row.source_url" :href="row.source_url" target="_blank" rel="noopener noreferrer">Abrir fuente</a><span v-else>—</span></td></tr><tr v-if="!prices.length"><td colspan="6" class="empty">Sin precios registrados.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'queue'" class="panel"><div v-if="queueStatus === 'no_match' && hasAccurateNormalizationCounts" class="queue-note"><UiIcon name="quality" :size="21" /><div><strong>Sin cobertura no significa error humano</strong><p>Estos registros necesitan catálogo, no descartes manuales. Revisa sólo los que tengan evidencia suficiente.</p></div></div><div class="panel-title"><div><p class="eyebrow">REVISIÓN CONTROLADA</p><h2>Cola de decisiones</h2><p class="hint">El resolver automático ya cerró lo seguro; aquí quedan las excepciones que necesitan contexto.</p></div><div class="panel-tools"><span class="muted">{{ queue.length }} registros</span><button v-if="queueHasMore" class="link" type="button" :disabled="queueLoadingMore" @click="loadMoreQueue">{{ queueLoadingMore ? 'Cargando…' : 'Cargar 100 más' }}</button></div></div><div class="table-wrap"><table><thead><tr><th>Entrada recibida</th><th>Origen</th><th>Fuente</th><th>Resultado</th><th>Candidatos</th><th>Fecha</th><th></th></tr></thead><tbody><tr v-for="row in queue" :key="row.normalization_run_id"><td><strong>{{ row.raw_text ?? row.normalized_input ?? '—' }}</strong><small class="block">{{ row.normalized_input ?? '—' }}</small></td><td>{{ statusLabel(row.input_type) }}</td><td>{{ row.source_name ?? '—' }}</td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ row.candidate_count }}</td><td>{{ formatDate(row.created_at) }}</td><td><button class="link" @click="openRow(row)">Revisar</button></td></tr><tr v-if="!queue.length"><td colspan="7" class="empty">No hay casos con estos filtros.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'quality'" class="panel"><div class="panel-title"><div><p class="eyebrow">CALIDAD DE DATOS</p><h2>Integridad de datos</h2><p class="panel-description">Señales que requieren seguimiento antes de publicar información.</p></div><span class="record-count">{{ qualityIssues.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Severidad</th><th>Estado</th><th>Corrida</th><th>Creado</th><th>Detalle</th><th>Acciones</th></tr></thead><tbody><tr v-for="row in qualityIssues" :key="row.issue_id"><td><strong>{{ row.issue_code }}</strong></td><td><span class="status" :class="row.severity">{{ statusLabel(row.severity) }}</span></td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ row.crawl_run_id ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td><td><pre>{{ JSON.stringify(row.details, null, 2) }}</pre></td><td class="actions" v-if="row.status === 'open' || row.status === 'acknowledged'"><button class="link" @click="updateQuality(row, 'acknowledged')">Reconocer</button><button class="link" @click="updateQuality(row, 'resolved')">Resolver</button><button class="link danger-link" @click="updateQuality(row, 'ignored')">Ignorar</button></td><td v-else>—</td></tr><tr v-if="!qualityIssues.length"><td colspan="7" class="empty">No hay incidencias de calidad.</td></tr></tbody></table></div></main>
    <main v-else-if="tab === 'alerts'" class="panel"><div class="panel-title"><div><p class="eyebrow">OPERACIÓN</p><h2>Alertas</h2><p class="panel-description">Eventos que pueden afectar la calidad o disponibilidad del servicio.</p></div><span class="record-count">{{ alerts.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Título</th><th>Severidad</th><th>Estado</th><th>Fuente</th><th>Creado</th><th>Acciones</th></tr></thead><tbody><tr v-for="row in alerts" :key="row.alert_id"><td><strong>{{ row.alert_code }}</strong></td><td><strong>{{ row.title }}</strong><small class="block">{{ row.detail ?? '' }}</small></td><td><span class="status" :class="row.severity">{{ statusLabel(row.severity) }}</span></td><td><span class="status" :class="row.status">{{ statusLabel(row.status) }}</span></td><td>{{ row.source ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td><td class="actions" v-if="row.status === 'open' || row.status === 'acknowledged'"><button class="link" @click="updateAlert(row, 'acknowledged')">Reconocer</button><button class="link" @click="updateAlert(row, 'resolved')">Resolver</button><button class="link danger-link" @click="updateAlert(row, 'ignored')">Ignorar</button></td><td v-else>—</td></tr><tr v-if="!alerts.length"><td colspan="7" class="empty">No hay alertas activas.</td></tr></tbody></table></div></main>
    <main v-else class="panel"><div class="panel-title"><div><p class="eyebrow">AUDITORÍA</p><h2>Registros fuente recientes</h2><p class="panel-description">Evidencia original recibida de cada proveedor.</p></div><span class="record-count">{{ records.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Tipo</th><th>ID externo</th><th>Procesamiento</th><th>Observado</th><th>Payload</th></tr></thead><tbody><tr v-for="record in records" :key="record.raw_record_id"><td><strong>{{ record.source_name }}</strong></td><td>{{ record.record_type }}</td><td>{{ record.external_record_id ?? '—' }}</td><td><span class="status" :class="record.parse_status">{{ statusLabel(record.parse_status) }}</span></td><td>{{ formatDate(record.observed_at) }}</td><td><details><summary>Ver JSON</summary><pre>{{ JSON.stringify(record.payload, null, 2) }}</pre></details></td></tr><tr v-if="!records.length"><td colspan="6" class="empty">Sin registros fuente cargados.</td></tr></tbody></table></div></main>
     <div v-if="selected" class="modal-backdrop" @click.self="closeReview"><section class="modal review-modal"><div class="panel-title"><div><p class="eyebrow">EVIDENCIA Y DECISIÓN</p><h2>Revisar excepción</h2></div><button class="close" @click="closeReview">×</button></div><div v-if="detail" class="review-content"><div class="review-summary"><div><span class="muted">Entrada</span><strong>{{ detail.run.raw_text ?? detail.run.normalized_input ?? '—' }}</strong></div><div><span class="muted">Origen</span><strong>{{ detail.run.input_type }}</strong></div><div><span class="muted">Motor</span><strong>{{ detail.run.engine_version ?? '—' }}</strong></div><div><span class="muted">Estado</span><span class="status" :class="detail.run.status">{{ detail.run.status }}</span></div></div><section v-if="detail.candidates.length" class="candidate-list"><h3>Candidatos del resolver</h3><label v-for="candidate in detail.candidates" :key="candidate.candidate_id" class="candidate-card" :class="{ selected: selectedCandidateId === candidate.candidate_id }"><input v-model="selectedCandidateId" type="radio" :value="candidate.candidate_id" /><span class="candidate-main"><strong>{{ candidate.display_name }}</strong><small>{{ candidate.method }} · score {{ Number(candidate.score).toFixed(3) }} · rank {{ candidate.rank }}</small><details><summary>Ver explicación</summary><pre>{{ JSON.stringify(candidate.explanation, null, 2) }}</pre></details></span></label></section><p v-else class="empty">El resolver no produjo candidatos.</p><p v-if="detail.candidates.length && !detail.run.provider_brand_id" class="hint">Esta revisión no tiene proveedor asociado; aprobarla no crea un alias global.</p><section v-if="detail.raw_record" class="evidence"><div class="section-title"><h3>Evidencia del scraper</h3><span class="muted">{{ detail.raw_record.source_name ?? 'Fuente desconocida' }} · {{ detail.raw_record.payload_bytes }} bytes</span></div><p>{{ detail.raw_record.record_type }} · {{ detail.raw_record.external_record_id ?? 'sin ID externo' }} · {{ formatDate(detail.raw_record.observed_at) }}</p><a v-if="detail.raw_record.source_url" :href="detail.raw_record.source_url" target="_blank" rel="noopener noreferrer">Abrir fuente original</a><details v-if="detail.raw_record.payload"><summary>Ver payload acotado</summary><pre>{{ JSON.stringify(detail.raw_record.payload, null, 2) }}</pre></details><button v-else class="link" @click="showPayload">Cargar payload (máximo 64 KB)</button></section><label v-if="detail.candidates.length && detail.run.provider_brand_id">Alias que se aprobará<input v-model="alias" maxlength="200" /></label><label>Motivo / notas<textarea v-model="reason" rows="3" maxlength="1000" placeholder="Explica por qué se aprueba o descarta…" /></label><div class="modal-actions"><button class="secondary" @click="closeReview">Cancelar</button><button class="danger" :disabled="loading || !reason.trim()" @click="markNoMatch">Marcar no_match</button><button class="primary" :disabled="loading || !selectedCandidateId || (aliasRequired && !alias.trim())" @click="approveCandidate">{{ loading ? 'Guardando…' : 'Aprobar candidato' }}</button></div></div><p v-else class="empty">Cargando evidencia…</p></section></div>
    <section v-if="selected && detail && !detail.candidates.length && !manualCatalogItemId" class="manual-candidate-drawer">
      <div class="panel-title"><div><p class="eyebrow">SELECCION MANUAL</p><h2>Buscar servicio canonico</h2><p class="hint">Este caso no tiene candidatos del resolver. Elige un servicio activo del catalogo; quedara registrado como candidato manual.</p></div></div>
      <form class="manual-search" @submit.prevent="searchCatalog"><input v-model="manualCatalogQuery" placeholder="Ej. biometria hematica" maxlength="200" /><button class="secondary" type="submit" :disabled="manualCatalogLoading">{{ manualCatalogLoading ? 'Buscando...' : 'Buscar' }}</button></form>
      <div v-if="manualCatalogResults.length" class="manual-results"><button v-for="item in manualCatalogResults" :key="item.item_id" type="button" class="manual-result" @click="chooseManualCatalogItem(item)"><strong>{{ item.display_name }}</strong><small>{{ item.service_type }} · {{ item.status }}</small></button></div>
       <label v-if="selected.provider_brand_id">Alias que se aprobara<input v-model="alias" maxlength="200" /></label>
    </section>
  </div>
</template>
