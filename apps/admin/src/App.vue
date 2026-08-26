<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { createAdminApi, formatDate, type Dashboard, type NormalizationRow, type RawRecord } from './api';

type Tab = 'overview' | 'queue' | 'records';
const api = createAdminApi(import.meta.env.VITE_API_URL ?? 'http://localhost:8787', import.meta.env.VITE_ADMIN_TOKEN ?? '');
const tab = ref<Tab>('overview');
const loading = ref(false);
const error = ref('');
const notice = ref('');
const dashboard = ref<Dashboard | null>(null);
const queue = ref<NormalizationRow[]>([]);
const records = ref<RawRecord[]>([]);
const selected = ref<NormalizationRow | null>(null);
const selectedItemId = ref('');
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
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'No se pudo consultar la API';
  } finally { loading.value = false; }
}

async function switchTab(next: Tab) {
  tab.value = next;
  notice.value = '';
  if (next === 'queue' && !queue.value.length) queue.value = await api.normalizationQueue();
  if (next === 'records' && !records.value.length) records.value = await api.rawRecords();
}

function openRow(row: NormalizationRow) {
  selected.value = row;
  alias.value = row.raw_text;
  selectedItemId.value = '';
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

onMounted(refresh);
</script>

<template>
  <div class="shell">
    <header class="topbar">
      <div><p class="eyebrow">PRUEVIA / OPERACIONES</p><h1>Admin V1</h1><p class="subtitle">Catálogo dorado, fuentes y normalización con trazabilidad.</p></div>
      <button class="refresh" :disabled="loading" @click="refresh">{{ loading ? 'Actualizando…' : 'Actualizar' }}</button>
    </header>

    <nav class="tabs" aria-label="Secciones administrativas">
      <button :class="{ active: tab === 'overview' }" @click="switchTab('overview')">Resumen</button>
      <button :class="{ active: tab === 'queue' }" @click="switchTab('queue')">Cola de normalización</button>
      <button :class="{ active: tab === 'records' }" @click="switchTab('records')">Raw records</button>
    </nav>

    <p v-if="error" class="alert error">{{ error }}</p><p v-if="notice" class="alert success">{{ notice }}</p>

    <main v-if="tab === 'overview'">
      <section class="cards"><article v-for="card in cards" :key="card[0]" class="card"><span>{{ card[0] }}</span><strong>{{ card[1] }}</strong><small>{{ card[2] }}</small></article></section>
      <section class="panel"><div class="panel-title"><div><p class="eyebrow">INGESTA</p><h2>Corridas recientes</h2></div><span v-if="dashboard" class="muted">{{ dashboard.sources }} fuentes activas · {{ dashboard.crawl_runs }} corridas</span></div>
        <div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Estado</th><th>Recibidos</th><th>Válidos</th><th>Publicados</th><th>Inicio</th></tr></thead><tbody><tr v-for="run in dashboard?.recent_runs ?? []" :key="run.id"><td>{{ run.source_name }}</td><td><span class="status" :class="run.status">{{ run.status }}</span></td><td>{{ run.records_received }}</td><td>{{ run.records_valid }}</td><td>{{ run.records_published }}</td><td>{{ formatDate(run.started_at) }}</td></tr><tr v-if="!dashboard?.recent_runs?.length"><td colspan="6" class="empty">Sin corridas todavía.</td></tr></tbody></table></div>
      </section>
    </main>

    <main v-else-if="tab === 'queue'" class="panel"><div class="panel-title"><div><p class="eyebrow">REVISIÓN HUMANA</p><h2>Cola de normalización</h2></div><span class="muted">{{ queue.length }} registros cargados</span></div><div class="table-wrap"><table><thead><tr><th>Texto fuente</th><th>Proveedor</th><th>Estado</th><th>Candidatos</th><th>Creado</th><th></th></tr></thead><tbody><tr v-for="row in queue" :key="row.normalization_run_id"><td><strong>{{ row.raw_text }}</strong><small class="block">{{ row.normalized_input }}</small></td><td>{{ row.provider_brand_name ?? '—' }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td><td>{{ row.candidate_count }}</td><td>{{ formatDate(row.created_at) }}</td><td><button class="link" @click="openRow(row)">Revisar</button></td></tr><tr v-if="!queue.length"><td colspan="6" class="empty">No hay registros en esta cola.</td></tr></tbody></table></div></main>

    <main v-else class="panel"><div class="panel-title"><div><p class="eyebrow">AUDITORÍA</p><h2>Raw records recientes</h2></div><span class="muted">{{ records.length }} registros cargados</span></div><div class="table-wrap"><table><thead><tr><th>Fuente</th><th>Tipo</th><th>ID externo</th><th>Parse</th><th>Observado</th><th>Payload</th></tr></thead><tbody><tr v-for="record in records" :key="record.raw_record_id"><td>{{ record.source_name }}</td><td>{{ record.record_type }}</td><td>{{ record.external_record_id ?? '—' }}</td><td><span class="status" :class="record.parse_status">{{ record.parse_status }}</span></td><td>{{ formatDate(record.observed_at) }}</td><td><details><summary>ver JSON</summary><pre>{{ JSON.stringify(record.payload, null, 2) }}</pre></details></td></tr><tr v-if="!records.length"><td colspan="6" class="empty">Sin raw records cargados.</td></tr></tbody></table></div></main>

    <div v-if="selected" class="modal-backdrop" @click.self="selected = null"><section class="modal"><div class="panel-title"><div><p class="eyebrow">RESOLVER</p><h2>Asignar alias</h2></div><button class="close" @click="selected = null">×</button></div><p class="muted">{{ selected.raw_text }} · {{ selected.provider_brand_name ?? 'Proveedor desconocido' }}</p><label>UUID del servicio canónico<input v-model="selectedItemId" placeholder="81aa9f9f-…" /></label><label>Alias aprobado<input v-model="alias" /></label><label>Razón<textarea v-model="reason" rows="3" /></label><div class="modal-actions"><button class="secondary" @click="selected = null">Cancelar</button><button class="primary" :disabled="loading || !selectedItemId || !alias" @click="resolve">{{ loading ? 'Guardando…' : 'Resolver y aprobar' }}</button></div></section></div>
  </div>
</template>
