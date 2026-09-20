<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { AdminApi, ClickMetrics } from '../api';

const props = defineProps<{ api: AdminApi }>();
const days = ref(30);
const data = ref<ClickMetrics | null>(null);
const busy = ref(false);
const error = ref('');
let alive = true;
let generation = 0;

const maxDaily = computed(() => Math.max(1, ...(data.value?.daily.map((item) => Number(item.clicks)) ?? [1])));
const formatter = new Intl.NumberFormat('es-MX');
const linkLabels: Record<string, string> = { booking: 'Agendar', study: 'Ver estudio', location: 'Ver sucursal', provider: 'Sitio del proveedor' };

async function load() {
  const current = ++generation;
  busy.value = true;
  error.value = '';
  try {
    const response = await props.api.clickMetrics(days.value);
    if (alive && current === generation) data.value = response;
  } catch (cause) {
    if (alive && current === generation) error.value = cause instanceof Error ? cause.message : 'No se pudieron cargar los clics.';
  } finally {
    if (alive && current === generation) busy.value = false;
  }
}

onMounted(load);
onUnmounted(() => { alive = false; generation++; });
</script>

<template>
  <main class="panel analytics-panel">
    <div class="panel-title">
      <div><p class="eyebrow">INTERÉS COMERCIAL</p><h2>Clics hacia proveedores</h2><p class="panel-description">Agregados por estudio y sucursal. No se guardan búsquedas, recetas ni diagnósticos.</p></div>
      <label class="period">Periodo<select v-model.number="days" :disabled="busy" @change="load"><option :value="7">7 días</option><option :value="30">30 días</option><option :value="90">90 días</option><option :value="365">12 meses</option></select></label>
    </div>
    <p v-if="error" class="alert error" role="alert">{{ error }}</p>
    <p v-if="busy && !data">Cargando indicadores…</p>
    <template v-if="data">
      <section class="metric-grid" aria-label="Indicadores principales">
        <article><span>Clics totales</span><strong>{{ formatter.format(data.summary.total_clicks) }}</strong><small>últimos {{ data.period_days }} días</small></article>
        <article><span>Visitantes aproximados</span><strong>{{ formatter.format(data.summary.unique_visitors) }}</strong><small>identificadores anónimos únicos</small></article>
        <article><span>Intentos de agenda</span><strong>{{ formatter.format(data.summary.booking_clicks) }}</strong><small>botón “Agendar estudio”</small></article>
        <article><span>Oferta con interés</span><strong>{{ data.summary.services_with_clicks }} estudios</strong><small>{{ data.summary.locations_with_clicks }} sucursales</small></article>
      </section>

      <section class="trend-card">
        <div class="section-title"><div><p class="eyebrow">TENDENCIA</p><h3>Clics por día</h3></div></div>
        <div v-if="data.daily.length" class="bars" role="img" aria-label="Gráfica de clics diarios">
          <div v-for="item in data.daily" :key="item.day" class="bar-column" :title="`${item.day}: ${item.clicks} clics`"><strong>{{ item.clicks }}</strong><span :style="{ height: `${Math.max(6, Number(item.clicks) / maxDaily * 120)}px` }" /><small>{{ new Date(`${item.day}T12:00:00`).toLocaleDateString('es-MX', { day: '2-digit', month: 'short' }) }}</small></div>
        </div>
        <p v-else class="empty">Todavía no hay clics en este periodo.</p>
      </section>

      <div class="analytics-columns">
        <section class="ranking"><h3>Estudios con más interés</h3><ol><li v-for="item in data.by_service.slice(0, 10)" :key="`${item.provider_brand_id}-${item.service_id}`"><span><strong>{{ item.service_name }}</strong><small>{{ item.provider_name }}</small></span><b>{{ item.clicks }}</b></li></ol><p v-if="!data.by_service.length" class="empty">Sin datos.</p></section>
        <section class="ranking"><h3>Sucursales con más interés</h3><ol><li v-for="item in data.by_location.slice(0, 10)" :key="`${item.provider_brand_id}-${item.location_id}`"><span><strong>{{ item.location_name }}</strong><small>{{ item.provider_name }}</small></span><b>{{ item.clicks }}</b></li></ol><p v-if="!data.by_location.length" class="empty">Sin datos.</p></section>
      </div>
      <section class="link-types"><h3>Acciones realizadas</h3><div><span v-for="item in data.by_link_type" :key="item.link_type"><strong>{{ item.clicks }}</strong>{{ linkLabels[item.link_type] ?? item.link_type }}</span></div></section>
    </template>
  </main>
</template>

<style scoped>
.analytics-panel { padding: 24px; }
.period { display: grid; gap: 5px; min-width: 130px; font-size: .8rem; }
.metric-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin: 20px 0; }
.metric-grid article, .trend-card, .ranking, .link-types { padding: 18px; border: 1px solid var(--border, #dbe3e1); border-radius: 16px; background: var(--surface, #fff); }
.metric-grid article { display: grid; gap: 5px; background: linear-gradient(145deg, #fff, rgba(15,118,110,.07)); }
.metric-grid span, .metric-grid small, .ranking small { color: var(--muted, #64748b); }
.metric-grid strong { font-size: 1.8rem; color: #0f5f59; }
.bars { display: flex; align-items: flex-end; gap: 10px; min-height: 175px; overflow-x: auto; padding-top: 20px; }
.bar-column { min-width: 46px; display: grid; justify-items: center; align-items: end; gap: 5px; font-size: .72rem; }
.bar-column > span { width: 28px; border-radius: 8px 8px 3px 3px; background: linear-gradient(#83cf9a, #0f766e); }
.analytics-columns { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 16px; }
.ranking ol { margin: 0; padding: 0; list-style: none; }
.ranking li { display: flex; justify-content: space-between; gap: 16px; padding: 11px 0; border-bottom: 1px solid var(--border, #e2e8f0); }
.ranking li span { display: grid; }
.ranking li b { color: #0f766e; font-size: 1.15rem; }
.link-types { margin-top: 16px; }
.link-types > div { display: flex; flex-wrap: wrap; gap: 10px; }
.link-types span { display: inline-flex; align-items: center; gap: 7px; padding: 9px 12px; border-radius: 999px; background: rgba(15,118,110,.08); }
@media (max-width: 900px) { .metric-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 650px) { .metric-grid, .analytics-columns { grid-template-columns: 1fr; } }
</style>
