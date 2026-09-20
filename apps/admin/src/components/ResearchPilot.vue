<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { AdminApi, PilotCohort } from '../api';
import { formatDate } from '../api';

const props = defineProps<{ api: AdminApi }>();
const view = ref<'feedback' | 'testers'>('feedback');
const status = ref('');
const rows = ref<Record<string, any>[]>([]);
const busy = ref(false);
const error = ref('');
const notice = ref('');
const cohort = ref<PilotCohort | null>(null);
let alive = true;
let generation = 0;

const feedbackStatuses = [['', 'Todos'], ['new', 'Nuevos'], ['reviewed', 'Revisados'], ['planned', 'Planeados'], ['resolved', 'Resueltos'], ['dismissed', 'Descartados']];
const testerStatuses = [['', 'Todos'], ['pending', 'Pendientes'], ['selected', 'Seleccionados'], ['invited', 'Invitados'], ['active', 'Activos'], ['completed', 'Completaron'], ['withdrawn', 'Retirados'], ['rejected', 'Descartados']];
const statuses = computed(() => view.value === 'feedback' ? feedbackStatuses : testerStatuses);

async function load() {
  const current = ++generation;
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    const [response, cohortResponse] = await Promise.all([
      props.api.research(view.value, status.value),
      props.api.pilotCohort(),
    ]);
    if (alive && current === generation) {
      rows.value = response.items ?? [];
      cohort.value = cohortResponse;
    }
  } catch (cause) {
    if (alive && current === generation) error.value = cause instanceof Error ? cause.message : 'No se pudo cargar el piloto.';
  } finally {
    if (alive && current === generation) busy.value = false;
  }
}

async function cohortAction(action: 'mark_invitations_released' | 'start_test') {
  if (busy.value || !cohort.value) return;
  const message = action === 'mark_invitations_released'
    ? `Confirma únicamente después de enviar el mismo enlace de Google Play a las ${cohort.value.target_count} personas. Esta acción no envía correos por sí sola.`
    : `La prueba empezará hoy y mostrará Día 1 de ${cohort.value.test_duration_days}. Confirma que las ${cohort.value.target_count} personas ya activaron el acceso en Google Play.`;
  if (typeof window !== 'undefined' && !window.confirm(message)) return;
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    cohort.value = await props.api.pilotCohortAction(action);
    await load();
    notice.value = action === 'mark_invitations_released'
      ? 'La cohorte quedó marcada como invitada. Ahora confirma cada activación real.'
      : `Prueba iniciada: Día 1 de ${cohort.value?.test_duration_days ?? 21}.`;
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'No se pudo actualizar la cohorte.';
  } finally {
    busy.value = false;
  }
}

const recruitmentPercent = computed(() => cohort.value ? Math.min(100, Math.round(cohort.value.registered_count / cohort.value.target_count * 100)) : 0);
const activationPercent = computed(() => cohort.value ? Math.min(100, Math.round(cohort.value.active_count / cohort.value.target_count * 100)) : 0);

async function switchView(next: 'feedback' | 'testers') {
  view.value = next;
  status.value = '';
  rows.value = [];
  await load();
}

async function update(row: Record<string, any>, nextStatus: string) {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    const response = await props.api.updateResearch(view.value, row.id, nextStatus, String(row.draft_note ?? ''));
    if (response.error) throw new Error('La API rechazó el cambio solicitado.');
    if (alive) {
      notice.value = 'Estado guardado y auditado.';
      await load();
    }
  } catch (cause) {
    if (alive) error.value = cause instanceof Error ? cause.message : 'No se pudo guardar el cambio.';
  } finally {
    if (alive) busy.value = false;
  }
}

function csvCell(value: unknown): string {
  let text = String(value ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ');
  if (/^[=+\-@]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}

function exportTesters() {
  const selected = rows.value.filter((row) => ['selected', 'invited', 'active', 'completed'].includes(String(row.status)));
  const lines = [
    ['correo_google_play', 'municipio', 'estado', 'android', 'dispositivo', 'fecha_registro'].map(csvCell).join(','),
    ...selected.map((row) => [row.email, row.municipality, row.status, row.android_version, row.device_model, row.created_at].map(csvCell).join(',')),
  ];
  const url = URL.createObjectURL(new Blob([lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'pruevia-testers-google-play.csv';
  link.click();
  URL.revokeObjectURL(url);
}

function answerLabel(value: string): string {
  return ({ yes: 'Sí', partly: 'Parcialmente', no: 'No', not_applicable: 'No aplica' } as Record<string, string>)[value] ?? value;
}

onMounted(load);
onUnmounted(() => { alive = false; generation++; });
</script>

<template>
  <main class="panel research-panel">
    <div class="panel-title">
      <div><p class="eyebrow">PILOTO ANDROID</p><h2>Feedback y testers</h2><p class="panel-description">Los comentarios anónimos no se relacionan con los correos de la lista cerrada.</p></div>
      <button v-if="view === 'testers'" class="secondary" type="button" :disabled="busy" @click="exportTesters">Exportar seleccionados CSV</button>
    </div>
    <section v-if="cohort" class="cohort-board" aria-label="Estado de la cohorte Android">
      <div class="cohort-kpis">
        <article><span>Registrados</span><strong>{{ cohort.registered_count }}/{{ cohort.target_count }}</strong><small>meta operativa</small></article>
        <article><span>Invitados</span><strong>{{ cohort.invited_count }}</strong><small>enlace liberado</small></article>
        <article><span>Activos</span><strong>{{ cohort.active_count }}/{{ cohort.target_count }}</strong><small>opt-in comprobado</small></article>
        <article class="day-card"><span>Prueba real</span><strong>{{ cohort.test_day ? `Día ${cohort.test_day} de ${cohort.test_duration_days}` : 'Sin iniciar' }}</strong><small>{{ cohort.test_ends_at ? `Finaliza ${formatDate(cohort.test_ends_at)}` : 'el reloj inicia con la cohorte activa' }}</small></article>
      </div>
      <div class="cohort-progress"><div><span>Reclutamiento</span><strong>{{ recruitmentPercent }}%</strong></div><progress :value="cohort.registered_count" :max="cohort.target_count" /></div>
      <div class="cohort-progress"><div><span>Activación en Google Play</span><strong>{{ activationPercent }}%</strong></div><progress :value="cohort.active_count" :max="cohort.target_count" /></div>
      <div class="cohort-actions">
        <button class="secondary" type="button" :disabled="busy || !cohort.can_release_invitations" @click="cohortAction('mark_invitations_released')">Confirmar invitación simultánea</button>
        <button class="primary" type="button" :disabled="busy || !cohort.can_start_test" @click="cohortAction('start_test')">Iniciar Día 1 de {{ cohort.test_duration_days }}</button>
      </div>
      <p class="cohort-note">Pruevia usa una meta propia de {{ cohort.target_count }} testers y {{ cohort.test_duration_days }} días como margen operativo. El botón de invitación registra una entrega hecha fuera del sistema; no envía correos automáticamente.</p>
    </section>
    <div class="research-switch" role="tablist" aria-label="Datos del piloto">
      <button type="button" role="tab" :aria-selected="view === 'feedback'" @click="switchView('feedback')">Comentarios</button>
      <button type="button" role="tab" :aria-selected="view === 'testers'" @click="switchView('testers')">Candidatos</button>
    </div>
    <div class="claim-filters">
      <button v-for="item in statuses" :key="item[0]" type="button" :aria-pressed="status === item[0]" @click="status = item[0]; load()">{{ item[1] }}</button>
    </div>
    <p v-if="error" class="alert error" role="alert">{{ error }}</p>
    <p v-if="notice" class="alert success" role="status">{{ notice }}</p>
    <p v-if="busy">Cargando información del piloto…</p>

    <div v-if="!busy" class="table-wrap">
      <table v-if="view === 'feedback'">
        <thead><tr><th>Experiencia</th><th>Ayudó</th><th>Esperado</th><th>Contexto</th><th>Comentario</th><th>Estado</th><th>Acción</th></tr></thead>
        <tbody>
          <tr v-for="row in rows" :key="row.id">
            <td>{{ answerLabel(row.experience) }}</td><td>{{ answerLabel(row.helpful) }}</td><td>{{ answerLabel(row.expected) }}</td>
            <td>{{ row.result_state }} · {{ row.result_count }} resultados<small class="block">{{ row.surface }} · {{ formatDate(row.created_at) }}</small><small class="block">{{ (row.reasons ?? []).join(', ') || 'Sin motivo adicional' }}</small></td>
            <td class="comment-cell">{{ row.comment || '—' }}</td>
            <td><span class="status" :class="row.triage_status">{{ row.triage_status }}</span></td>
            <td><textarea v-model="row.draft_note" maxlength="1000" aria-label="Nota interna del feedback" placeholder="Nota interna"></textarea><select :value="row.triage_status" @change="update(row, ($event.target as HTMLSelectElement).value)"><option v-for="item in feedbackStatuses.slice(1)" :key="item[0]" :value="item[0]">{{ item[1] }}</option></select></td>
          </tr>
          <tr v-if="!rows.length"><td colspan="7" class="empty">No hay comentarios con este estado.</td></tr>
        </tbody>
      </table>
      <table v-else>
        <thead><tr><th>Correo de Google Play</th><th>Municipio</th><th>Dispositivo</th><th>Registro</th><th>Estado</th><th>Acción</th></tr></thead>
        <tbody>
          <tr v-for="row in rows" :key="row.id">
            <td><strong>{{ row.email }}</strong><small class="block">Aviso {{ row.notice_version }}</small></td><td>{{ row.municipality }}</td><td>{{ row.android_version || '—' }}<small class="block">{{ row.device_model || 'Sin especificar' }}</small></td><td>{{ formatDate(row.created_at) }}</td><td><span class="status" :class="row.status">{{ row.status }}</span></td>
            <td><textarea v-model="row.draft_note" maxlength="1000" aria-label="Nota interna del candidato" placeholder="Nota interna"></textarea><select :value="row.status" @change="update(row, ($event.target as HTMLSelectElement).value)"><option v-for="item in testerStatuses.slice(1)" :key="item[0]" :value="item[0]">{{ item[1] }}</option></select></td>
          </tr>
          <tr v-if="!rows.length"><td colspan="6" class="empty">No hay candidatos con este estado.</td></tr>
        </tbody>
      </table>
    </div>
  </main>
</template>

<style scoped>
.research-panel { padding: 24px; }
.research-switch, .claim-filters { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0; }
.research-switch button, .claim-filters button { border-radius: 999px; }
button[aria-selected=true], button[aria-pressed=true] { font-weight: 700; text-decoration: underline; }
textarea { width: 210px; min-height: 58px; display: block; margin-bottom: 6px; }
select { max-width: 210px; }
.comment-cell { max-width: 280px; white-space: pre-wrap; }
.cohort-board { margin: 18px 0 24px; padding: 18px; border: 1px solid var(--border); border-radius: 16px; background: linear-gradient(135deg, rgba(15,118,110,.08), rgba(132,204,22,.08)); }
.cohort-kpis { display: grid; grid-template-columns: repeat(4, minmax(130px, 1fr)); gap: 12px; }
.cohort-kpis article { display: grid; gap: 4px; padding: 15px; border-radius: 12px; background: var(--surface, #fff); }
.cohort-kpis span, .cohort-kpis small, .cohort-note { color: var(--muted, #64748b); }
.cohort-kpis strong { font-size: 1.45rem; }
.day-card { grid-column: span 1; }
.cohort-progress { margin-top: 16px; }
.cohort-progress > div { display: flex; justify-content: space-between; }
.cohort-progress progress { width: 100%; height: 12px; accent-color: #0f766e; }
.cohort-actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 18px; }
.cohort-note { margin-bottom: 0; font-size: .86rem; }
@media (max-width: 850px) { .cohort-kpis { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 520px) { .cohort-kpis { grid-template-columns: 1fr; } }
</style>
