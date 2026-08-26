<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { createAdminApi, formatDate, type AlertRow, type CatalogItem, type Dashboard, type LocationRow, type NormalizationRow, type OfferRow, type PriceRow, type ProviderRow, type QualityIssueRow, type RawRecord } from './api';
import { supabase } from './auth';

type Tab = 'overview' | 'providers' | 'locations' | 'offers' | 'prices' | 'queue' | 'records' | 'quality' | 'alerts';
const api = createAdminApi(import.meta.env.VITE_API_URL ?? 'http://localhost:8787', async () => (await supabase?.auth.getSession())?.data.session?.access_token ?? null);
const session = ref<import('@supabase/supabase-js').Session | null>(null);
const email = ref('');
const password = ref('');
const authError = ref('');
const authLoading = ref(false);
let authSubscription: { unsubscribe: () => void } | null = null;
const tab = ref<Tab>('overview');
const loading = ref(false);
const error = ref('');
const notice = ref('');
const dashboard = ref<Dashboard | null>(null);
const queue = ref<NormalizationRow[]>([]);
const queueStatus = ref('no_match');
const records = ref<RawRecord[]>([]);
const providers = ref<ProviderRow[]>([]);
const locations = ref<LocationRow[]>([]);
const offers = ref<OfferRow[]>([]);
const prices = ref<PriceRow[]>([]);
const qualityIssues = ref<QualityIssueRow[]>([]);
const alerts = ref<AlertRow[]>([]);
const selected = ref<NormalizationRow | null>(null);
const selectedItemId = ref('');
const catalogItems = ref<CatalogItem[]>([]);
const alias = ref('');
const reason = ref('Validación manual del catálogo dorado');

const cards = computed(() => dashboard.value ? [
  ['Catálogo activo', dashboard.value.active_catalog_items, 'servicios'],
  ['Ofertas activas', dashboard.value.active_offers, 'proveedores'],
  ['Pendientes', dashboard.value.normalization_pending, 'normalización'],
  ['Issues abiertos', dashboard.value.open_quality_issues, 'calidad'],
] : []);

async function refresh() {
  loading.value = true;
  error.value = '';
  try {
    dashboard.value = await api.dashboard();
    if (tab.value === 'queue') queue.value = await api.normalizationQueue();
    if (tab.value === 'records') records.value = await api.rawRecords();
    if (tab.value === 'providers') providers.value = await api.providers();
    if (tab.value === 'locations') locations.value = await api.locations();
    if (tab.value === 'offers') offers.value = await api.offers();
    if (tab.value === 'prices') prices.value = await api.prices();
    if (tab.value === 'quality') qualityIssues.value = await api.qualityIssues();
    if (tab.value === 'alerts') alerts.value = await api.alerts();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'No se pudo consultar la API';
  } finally { loading.value = false; }
}

async function switchTab(next: Tab) {
  tab.value = next;
  notice.value = '';
  try {
    if (next === 'queue' && !queue.value.length) queue.value = await api.normalizationQueue();
    if (next === 'records' && !records.value.length) records.value = await api.rawRecords();
    if (next === 'providers' && !providers.value.length) providers.value = await api.providers();
    if (next === 'locations' && !locations.value.length) locations.value = await api.locations();
    if (next === 'offers' && !offers.value.length) offers.value = await api.offers();
    if (next === 'prices' && !prices.value.length) prices.value = await api.prices();
    if (next === 'quality' && !qualityIssues.value.length) qualityIssues.value = await api.qualityIssues();
    if (next === 'alerts' && !alerts.value.length) alerts.value = await api.alerts();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'No se pudo cargar la sección';
  }
}

async function changeQueueStatus() {
  queue.value = await api.normalizationQueue(queueStatus.value);
}

function openRow(row: NormalizationRow) {
  selected.value = row;
  alias.value = row.raw_text;
  selectedItemId.value = '';
  catalogItems.value = [];
}

async function lookupCatalog() {
  if (selectedItemId.value.length < 2) { catalogItems.value = []; return; }
  try { catalogItems.value = await api.catalogItems(selectedItemId.value); }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'No se pudo consultar el catálogo'; }
}

function chooseCatalogItem(itemId: string) {
  selectedItemId.value = itemId;
  catalogItems.value = [];
}

async function resolve() {
  if (!selected.value || !selectedItemId.value.trim() || !alias.value.trim()) return;
  loading.value = true;
  error.value = '';
  try {
    await api.resolveNormalization(selected.value.normalization_run_id, { selected_item_id: selectedItemId.value.trim(), alias: alias.value.trim(), reason: reason.value });
    notice.value = 'Normalización resuelta y alias aprobado.';
    selected.value = null;
    queue.value = await api.normalizationQueue();
    dashboard.value = await api.dashboard();
  } catch (cause) { error.value = cause instanceof Error ? cause.message : 'No se pudo resolver'; }
  finally { loading.value = false; }
}

async function signIn() {
  if (!supabase || !email.value.trim() || !password.value) return;
  authLoading.value = true;
  authError.value = '';
  const result = await supabase.auth.signInWithPassword({ email: email.value.trim(), password: password.value });
  if (result.error) authError.value = 'No se pudo iniciar sesión.';
  else {
    session.value = result.data.session;
    password.value = '';
    await refresh();
  }
  authLoading.value = false;
}

async function signOut() {
  await supabase?.auth.signOut();
  session.value = null;
  queue.value = [];
  records.value = [];
  dashboard.value = null;
}

onMounted(async () => {
  if (!supabase) return;
  session.value = (await supabase.auth.getSession()).data.session;
  if (session.value) await refresh();
  const subscription = supabase.auth.onAuthStateChange((_event, nextSession) => {
    session.value = nextSession;
  });
  authSubscription = subscription.data.subscription;
});
onUnmounted(() => authSubscription?.unsubscribe());
</script>

<template>
  <main v-if="!supabase" class="auth-shell"><section class="auth-card"><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin no configurado</h1><p>Faltan VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY.</p></section></main>
  <main v-else-if="!session" class="auth-shell"><form class="auth-card" @submit.prevent="signIn"><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin V1</h1><p class="subtitle">Inicia sesión con una cuenta administrativa de Supabase.</p><label>Correo<input v-model="email" type="email" autocomplete="username" required /></label><label>Contraseña<input v-model="password" type="password" autocomplete="current-password" required /></label><p v-if="authError" class="alert error">{{ authError }}</p><button class="primary" type="submit" :disabled="authLoading">{{ authLoading ? 'Iniciando…' : 'Iniciar sesión' }}</button></form></main>
  <div v-else class="shell">
    <header class="topbar">
      <div><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin V1</h1><p class="subtitle">Catálogo dorado, fuentes y normalización con trazabilidad.</p></div>
      <div class="topbar-actions"><button class="refresh" :disabled="loading" @click="refresh">{{ loading ? 'Actualizando…' : 'Actualizar' }}</button><button class="secondary" @click="signOut">Cerrar sesión</button></div>
    </header>

    <nav class="tabs" aria-label="Secciones administrativas">
      <button :class="{ active: tab === 'overview' }" @click="switchTab('overview')">Resumen</button>
      <button :class="{ active: tab === 'providers' }" @click="switchTab('providers')">Providers</button>
      <button :class="{ active: tab === 'locations' }" @click="switchTab('locations')">Locations</button>
      <button :class="{ active: tab === 'offers' }" @click="switchTab('offers')">Offers</button>
      <button :class="{ active: tab === 'prices' }" @click="switchTab('prices')">Prices</button>
      <button :class="{ active: tab === 'queue' }" @click="switchTab('queue')">Cola de normalización</button>
      <button :class="{ active: tab === 'records' }" @click="switchTab('records')">Raw records</button>
      <button :class="{ active: tab === 'quality' }" @click="switchTab('quality')">Calidad</button>
      <button :class="{ active: tab === 'alerts' }" @click="switchTab('alerts')">Alertas</button>
    </nav>

    <p v-if="error" class="alert error">{{ error }}</p><p v-if="notice" class="alert success">{{ notice }}</p>

    <main v-if="tab === 'overview'">
      <section class="cards"><article v-for="card in cards" :key="card[0]" class="card"><span>{{ card[0] }}</span><strong>{{ card[1] }}</strong><small>{{ card[2] }}</small></article></section>
      <section class="panel"><div class="panel-title"><div><p class="eyebrow">INGESTA</p><h2>Corridas recientes</h2></div><span v-if="dashboard" class="muted">{{ dashboard.sources }} fuentes activas · {{ dashboard.crawl_runs }} corridas</span></div>
        <div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Estado</th><th>Recibidos</th><th>Válidos</th><th>Publicados</th><th>Inicio</th></tr></thead><tbody><tr v-for="run in dashboard?.recent_runs ?? []" :key="run.id"><td>{{ run.source_name }}</td><td><span class="status" :class="run.status">{{ run.status }}</span></td><td>{{ run.records_received }}</td><td>{{ run.records_valid }}</td><td>{{ run.records_published }}</td><td>{{ formatDate(run.started_at) }}</td></tr><tr v-if="!dashboard?.recent_runs?.length"><td colspan="6" class="empty">Sin corridas todavía.</td></tr></tbody></table></div>
      </section>
    </main>

    <main v-else-if="tab === 'providers'" class="panel"><div class="panel-title"><div><p class="eyebrow">CATÁLOGO</p><h2>Providers</h2></div><span class="muted">{{ providers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Estado</th><th>Verificación</th><th>Locations</th><th>Offers</th></tr></thead><tbody><tr v-for="row in providers" :key="row.provider_id"><td>{{ row.provider_name }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.verification_status }}</td><td>{{ row.locations_count }}</td><td>{{ row.active_offers_count }}</td></tr><tr v-if="!providers.length"><td colspan="5" class="empty">Sin providers.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'locations'" class="panel"><div class="panel-title"><div><p class="eyebrow">GEOGRAFÍA</p><h2>Locations</h2></div><span class="muted">{{ locations.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Sucursal</th><th>Dirección</th><th>Localidad</th><th>Estado</th><th>Coordenadas</th></tr></thead><tbody><tr v-for="row in locations" :key="row.location_id"><td>{{ row.provider_name }}</td><td>{{ row.location_name }}</td><td>{{ row.address ?? '—' }}</td><td>{{ row.locality ?? '—' }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.latitude ?? '—' }}, {{ row.longitude ?? '—' }}</td></tr><tr v-if="!locations.length"><td colspan="6" class="empty">Sin locations.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'offers'" class="panel"><div class="panel-title"><div><p class="eyebrow">COMERCIO</p><h2>Offers</h2></div><span class="muted">{{ offers.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Estado</th><th>Precios vigentes</th><th>Última observación</th></tr></thead><tbody><tr v-for="row in offers" :key="row.offer_id"><td>{{ row.provider_name }}</td><td>{{ row.service_name }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.current_price_count }}</td><td>{{ formatDate(row.last_seen_at) }}</td></tr><tr v-if="!offers.length"><td colspan="5" class="empty">Sin offers.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'prices'" class="panel"><div class="panel-title"><div><p class="eyebrow">PRECIOS</p><h2>Prices</h2></div><span class="muted">{{ prices.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Proveedor</th><th>Servicio</th><th>Tipo</th><th>Importe</th><th>Última observación</th><th>Fuente</th></tr></thead><tbody><tr v-for="row in prices" :key="row.price_version_id"><td>{{ row.provider_name }}</td><td>{{ row.service_name }}</td><td>{{ row.price_type }}</td><td>{{ row.amount_minor / 100 }} {{ row.currency }}</td><td>{{ formatDate(row.last_seen_at) }}</td><td><a v-if="row.source_url" :href="row.source_url" target="_blank" rel="noopener noreferrer">Abrir</a><span v-else>—</span></td></tr><tr v-if="!prices.length"><td colspan="6" class="empty">Sin prices.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'queue'" class="panel"><div class="panel-title"><div><p class="eyebrow">REVISIÓN HUMANA</p><h2>Cola de normalización</h2></div><div class="panel-tools"><select v-model="queueStatus" @change="changeQueueStatus"><option value="no_match">No match</option><option value="ambiguous">Ambiguous</option><option value="pending">Pending</option></select><span class="muted">{{ queue.length }} registros cargados</span></div></div><div class="table-wrap"><table><thead><tr><th>Texto fuente</th><th>Proveedor</th><th>Estado</th><th>Candidatos</th><th>Creado</th><th></th></tr></thead><tbody><tr v-for="row in queue" :key="row.normalization_run_id"><td><strong>{{ row.raw_text }}</strong><small class="block">{{ row.normalized_input }}</small></td><td>{{ row.provider_brand_name ?? '—' }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.candidate_count }}</td><td>{{ formatDate(row.created_at) }}</td><td><button class="link" @click="openRow(row)">Revisar</button></td></tr><tr v-if="!queue.length"><td colspan="6" class="empty">No hay registros en esta cola.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'quality'" class="panel"><div class="panel-title"><div><p class="eyebrow">CALIDAD</p><h2>Data quality issues</h2></div><span class="muted">{{ qualityIssues.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Severidad</th><th>Estado</th><th>Run</th><th>Creado</th><th>Detalle</th></tr></thead><tbody><tr v-for="row in qualityIssues" :key="row.issue_id"><td>{{ row.issue_code }}</td><td><span class="status" :class="row.severity">{{ row.severity }}</span></td><td>{{ row.status }}</td><td>{{ row.crawl_run_id ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td><td><pre>{{ JSON.stringify(row.details, null, 2) }}</pre></td></tr><tr v-if="!qualityIssues.length"><td colspan="6" class="empty">Sin issues registrados.</td></tr></tbody></table></div></main>

    <main v-else-if="tab === 'alerts'" class="panel"><div class="panel-title"><div><p class="eyebrow">OPERACIÓN</p><h2>Alerts</h2></div><span class="muted">{{ alerts.length }} registros</span></div><div class="table-wrap"><table><thead><tr><th>Código</th><th>Título</th><th>Severidad</th><th>Estado</th><th>Fuente</th><th>Creado</th></tr></thead><tbody><tr v-for="row in alerts" :key="row.alert_id"><td>{{ row.alert_code }}</td><td>{{ row.title }}</td><td><span class="status" :class="row.severity">{{ row.severity }}</span></td><td>{{ row.status }}</td><td>{{ row.source ?? '—' }}</td><td>{{ formatDate(row.created_at) }}</td></tr><tr v-if="!alerts.length"><td colspan="6" class="empty">Sin alertas registradas.</td></tr></tbody></table></div></main>

    <main v-else class="panel"><div class="panel-title"><div><p class="eyebrow">AUDITORÍA</p><h2>Raw records recientes</h2></div><span class="muted">{{ records.length }} registros cargados</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Tipo</th><th>ID externo</th><th>Parse</th><th>Observado</th><th>Payload</th></tr></thead><tbody><tr v-for="record in records" :key="record.raw_record_id"><td>{{ record.source_name }}</td><td>{{ record.record_type }}</td><td>{{ record.external_record_id ?? '—' }}</td><td><span class="status" :class="record.parse_status">{{ record.parse_status }}</span></td><td>{{ formatDate(record.observed_at) }}</td><td><details><summary>ver JSON</summary><pre>{{ JSON.stringify(record.payload, null, 2) }}</pre></details></td></tr><tr v-if="!records.length"><td colspan="6" class="empty">Sin raw records cargados.</td></tr></tbody></table></div></main>

    <div v-if="selected" class="modal-backdrop" @click.self="selected = null"><section class="modal"><div class="panel-title"><div><p class="eyebrow">RESOLVER</p><h2>Asignar alias</h2></div><button class="close" @click="selected = null">×</button></div><p class="muted">{{ selected.raw_text }} · {{ selected.provider_brand_name ?? 'Proveedor desconocido' }}</p><label>Buscar servicio canónico<input v-model="selectedItemId" placeholder="mastografía, biometría…" @input="lookupCatalog" /></label><div v-if="catalogItems.length" class="catalog-suggestions"><button v-for="item in catalogItems" :key="item.item_id" type="button" @click="chooseCatalogItem(item.item_id)"><strong>{{ item.display_name }}</strong><small>{{ item.item_id }} · {{ item.service_type }}</small></button></div><p v-else-if="selectedItemId.length >= 2" class="hint">Selecciona un servicio de la lista o pega directamente su UUID.</p><label>Alias aprobado<input v-model="alias" /></label><label>Razón<textarea v-model="reason" rows="3" /></label><div class="modal-actions"><button class="secondary" @click="selected = null">Cancelar</button><button class="primary" :disabled="loading || !selectedItemId || !alias" @click="resolve">{{ loading ? 'Guardando…' : 'Resolver y aprobar' }}</button></div></section></div>
  </div>
</template>
