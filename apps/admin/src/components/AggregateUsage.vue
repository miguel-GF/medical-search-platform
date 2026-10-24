<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import type { AdminApi } from '../api';
const props = defineProps<{ api: AdminApi }>();
const data = ref<Awaited<ReturnType<AdminApi['usageTotals']>> | null>(null);
const error = ref('');
const days = ref(30);
let generation = 0;
const labels: Record<string,string> = { study_search: 'Búsquedas', study_selection: 'Selecciones de estudio', order_resolution: 'Órdenes', order_batch: 'Órdenes combinadas', order_image: 'Órdenes con imagen' };
async function load() {
  const current = ++generation;
  error.value = '';
  try { const value = await props.api.usageTotals(days.value); if (current === generation) data.value = value; }
  catch { if (current === generation) error.value = 'No se pudieron cargar los conteos. Intenta actualizar.'; }
}
onMounted(load);
onUnmounted(() => { generation++; });
</script>
<template>
  <section class="panel usage-panel">
    <div class="panel-title"><div><p class="eyebrow">USO GENERAL</p><h2>Solicitudes atendidas</h2><p>Totales diarios UTC, sin búsquedas médicas ni identificadores de visitantes. Las repeticiones cuentan; no representa personas únicas.</p></div><label>Periodo<select v-model.number="days" @change="load"><option :value="7">7 días</option><option :value="30">30 días</option><option :value="90">90 días</option><option :value="365">365 días</option></select></label><button type="button" @click="load">Actualizar</button></div>
    <p v-if="error" role="alert">{{ error }}</p>
    <template v-else-if="data"><p><strong>{{ Number(data.total_requests).toLocaleString('es-MX') }}</strong> solicitudes registradas</p><div class="table-scroll"><table><thead><tr><th>Día UTC</th><th>Acción</th><th>Solicitudes</th></tr></thead><tbody><tr v-for="row in data.daily" :key="`${row.day}:${row.action}`"><td>{{ row.day }}</td><td>{{ labels[row.action] ?? row.action }}</td><td>{{ row.requests }}</td></tr><tr v-if="!data.daily.length"><td colspan="3">Sin solicitudes registradas en este periodo.</td></tr></tbody></table></div><p>Conteo aproximado: puede incluir automatizaciones y reintentos; una falla de medición no interrumpe la búsqueda.</p></template>
  </section>
</template>
<style scoped>.usage-panel{padding:24px;margin-bottom:20px}.panel-title label{display:grid;gap:6px}.panel-title p{max-width:650px}</style>
