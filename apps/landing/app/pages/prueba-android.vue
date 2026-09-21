<script setup lang="ts">
const config = useRuntimeConfig();
const publication = config.public.publication;
const municipalities = ['Puebla', 'San Andrés Cholula', 'San Pedro Cholula', 'Cuautlancingo', 'Coronango', 'Amozoc'];
const form = reactive({ play_email: '', municipality: 'Puebla', android_version: '', device_model: '', age_confirmed: false, notice_accepted: false, website: '' });
const checking = ref(Boolean(publication.apiUrl));
const available = ref(false);
const noticeVersion = ref(String(publication.testerNoticeVersion));
const pilotEndsAt = ref('');
const phase = ref('closed');
const registeredCount = ref(0);
const activeCount = ref(0);
const targetCount = ref(20);
const testDurationDays = ref(21);
const testDay = ref<number | null>(null);
const submitting = ref(false);
const submitted = ref(false);
const error = ref('');

useSeoMeta({
  title: 'Prueba cerrada Android · Pruevia',
  description: 'Conoce y solicita participar en la prueba cerrada de Pruevia para Android en Puebla y municipios cercanos.',
});
if (publication.siteUrl) useHead({ link: [{ rel: 'canonical', href: `${publication.siteUrl}/prueba-android` }] });

const progress = computed(() => Math.min(100, Math.round((registeredCount.value / Math.max(1, targetCount.value)) * 100)));
const activeProgress = computed(() => Math.min(100, Math.round((activeCount.value / Math.max(1, targetCount.value)) * 100)));

onMounted(async () => {
  if (!publication.apiUrl) return;
  try {
    const response = await fetch(`${publication.apiUrl}/api/v1/android-pilot`, { cache: 'no-store', redirect: 'error' });
    if (!response.ok) throw new Error('pilot unavailable');
    const data = await response.json() as { enabled?: boolean; notice_version?: string; pilot_ends_at?: string | null; phase?: string; registered_count?: number; active_count?: number; target_count?: number; test_duration_days?: number; test_day?: number | null };
    available.value = publication.testerIntakeEnabled && data.enabled === true;
    phase.value = typeof data.phase === 'string' ? data.phase : 'closed';
    registeredCount.value = Number.isInteger(data.registered_count) ? Number(data.registered_count) : 0;
    activeCount.value = Number.isInteger(data.active_count) ? Number(data.active_count) : 0;
    targetCount.value = Number.isInteger(data.target_count) && Number(data.target_count) > 0 ? Number(data.target_count) : 20;
    testDurationDays.value = Number.isInteger(data.test_duration_days) ? Number(data.test_duration_days) : 21;
    testDay.value = Number.isInteger(data.test_day) ? Number(data.test_day) : null;
    if (typeof data.notice_version === 'string') noticeVersion.value = data.notice_version;
    if (typeof data.pilot_ends_at === 'string' && !Number.isNaN(Date.parse(data.pilot_ends_at))) {
      pilotEndsAt.value = new Intl.DateTimeFormat('es-MX', { dateStyle: 'long' }).format(new Date(data.pilot_ends_at));
    }
  } catch {
    error.value = 'No pudimos comprobar si la convocatoria está abierta. Inténtalo más tarde.';
  } finally {
    checking.value = false;
  }
});

async function submit() {
  if (!available.value || submitting.value || !publication.apiUrl) return;
  submitting.value = true;
  error.value = '';
  try {
    const response = await fetch(`${publication.apiUrl}/api/v1/tester-interest`, {
      method: 'POST',
      cache: 'no-store',
      redirect: 'error',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ ...form, notice_version: noticeVersion.value }),
    });
    if (!response.ok) throw new Error('request rejected');
    submitted.value = true;
    registeredCount.value = Math.min(targetCount.value, registeredCount.value + 1);
  } catch {
    error.value = 'No pudimos registrar tu solicitud. Revisa los datos o inténtalo más tarde.';
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <div>
    <header class="site-header"><div class="container header-inner"><NuxtLink to="/" class="brand"><BrandMark /><span>Pruevia<span class="brand-dot">.</span></span></NuxtLink><NuxtLink class="text-link" to="/">Volver al inicio</NuxtLink></div></header>
    <main class="container pilot-page">
      <section class="pilot-intro">
        <span class="eyebrow">PRUEBA CERRADA · ANDROID</span>
        <h1>Ayúdanos a probar<br><span>Pruevia en la vida real.</span></h1>
        <p>Buscamos un grupo pequeño de personas de Puebla y municipios cercanos para detectar qué información realmente ayuda antes de publicar la aplicación.</p>
        <ul class="pilot-facts"><li>Aplicación gratuita y sin cuenta de paciente.</li><li>Participación exclusiva para personas de 18 años o más.</li><li>Piloto de aproximadamente 21 días mediante Google Play.</li><li>Área inicial: Puebla, ambas Cholulas, Cuautlancingo, Coronango y Amozoc.</li></ul>
        <section class="pilot-progress" aria-labelledby="pilot-progress-title">
          <div class="progress-heading"><div><span class="eyebrow">COHORTE ACTUAL</span><h2 id="pilot-progress-title">{{ registeredCount }} de {{ targetCount }} personas</h2></div><strong>{{ progress }}%</strong></div>
          <div class="progress-track" role="progressbar" :aria-valuenow="registeredCount" aria-valuemin="0" :aria-valuemax="targetCount"><span :style="{ width: `${progress}%` }" /></div>
          <p v-if="phase === 'recruiting'">Reuniremos al grupo completo antes de enviar el enlace de Google Play.</p>
          <p v-else-if="phase === 'cohort_ready'">Ya reunimos la cohorte. Estamos preparando una invitación simultánea para todos.</p>
          <p v-else-if="phase === 'inviting'">Invitaciones liberadas: {{ activeCount }} de {{ targetCount }} testers ya activaron el acceso.</p>
          <template v-else-if="phase === 'testing'"><p><strong>Día {{ testDay }} de {{ testDurationDays }}</strong> · prueba real en curso.</p><div class="progress-track active" role="progressbar" :aria-valuenow="activeCount" aria-valuemin="0" :aria-valuemax="targetCount"><span :style="{ width: `${activeProgress}%` }" /></div></template>
          <p v-else-if="phase === 'completed'">La cohorte completó su periodo de prueba.</p>
          <p v-else>La convocatoria todavía no está abierta.</p>
          <a v-if="publication.patientUrl" class="web-pilot-link" :href="publication.patientUrl">Mientras esperas, usa Pruevia desde la web <span aria-hidden="true">↗</span></a>
        </section>
        <p v-if="pilotEndsAt" class="privacy-summary">Convocatoria abierta hasta el {{ pilotEndsAt }}.</p>
      </section>

      <section class="pilot-form-card" aria-labelledby="tester-form-title">
        <template v-if="submitted"><span class="success-symbol" aria-hidden="true">✓</span><h2 id="tester-form-title">Solicitud recibida</h2><p>Ya formas parte de la lista. Cuando reunamos {{ targetCount }} personas enviaremos el mismo enlace de Google Play a la cohorte; los {{ testDurationDays }} días comenzarán cuando las {{ targetCount }} hayan activado el acceso.</p><a v-if="publication.patientUrl" class="button" :href="publication.patientUrl">Usar la app web mientras espero <span aria-hidden="true">↗</span></a></template>
        <template v-else-if="checking"><h2 id="tester-form-title">Comprobando convocatoria…</h2><p>Estamos verificando si todavía hay lugares disponibles.</p></template>
        <form v-else @submit.prevent="submit">
          <h2 id="tester-form-title">Quiero participar</h2>
          <p>Usaremos estos datos únicamente para organizar la prueba cerrada. No escribas estudios, diagnósticos ni información de salud.</p>
          <p v-if="!available" class="form-closed-notice" role="status"><strong>Vista previa:</strong> el registro todavía está cerrado. Los campos se habilitarán cuando publiquemos el domicilio del responsable y las fechas definitivas.</p>
          <fieldset class="form-fields" :disabled="!available || submitting">
            <label>Correo asociado con Google Play<input v-model.trim="form.play_email" type="email" autocomplete="email" maxlength="254" required></label>
            <label>Municipio<select v-model="form.municipality" required><option v-for="municipality in municipalities" :key="municipality" :value="municipality">{{ municipality }}</option></select></label>
            <div class="form-grid"><label>Versión de Android <span>(opcional)</span><input v-model.trim="form.android_version" maxlength="80" placeholder="Ej. Android 15"></label><label>Modelo del teléfono <span>(opcional)</span><input v-model.trim="form.device_model" maxlength="120" placeholder="Ej. Samsung A54"></label></div>
            <input v-model="form.website" class="honeypot" tabindex="-1" autocomplete="off" aria-hidden="true">
            <label class="check-label"><input v-model="form.age_confirmed" type="checkbox" required><span>Confirmo que tengo 18 años o más.</span></label>
            <label class="check-label"><input v-model="form.notice_accepted" type="checkbox" required><span>Leí el <NuxtLink to="/privacidad">aviso de privacidad</NuxtLink> y acepto el tratamiento necesario para administrar el piloto.</span></label>
          </fieldset>
          <p v-if="publication.privacyEmail" class="privacy-summary">Puedes retirar tu solicitud escribiendo a {{ publication.privacyEmail }}. El correo se eliminará en un máximo de 7 días después del retiro; los registros restantes se eliminarán o anonimizarán 90 días después de cerrar el piloto.</p>
          <p v-if="error" class="form-error" role="alert">{{ error }}</p>
          <button class="button" type="submit" :disabled="!available || submitting">{{ !available ? 'Registro aún no disponible' : submitting ? 'Enviando…' : 'Solicitar participación' }} <span aria-hidden="true">↗</span></button>
        </form>
      </section>
    </main>
    <footer class="container site-footer"><div><NuxtLink to="/" class="brand"><BrandMark /><span>Pruevia.</span></NuxtLink><p>Tu próximo paso, más claro.</p></div><div class="footer-links"><NuxtLink to="/privacidad">Privacidad</NuxtLink><NuxtLink to="/">Inicio</NuxtLink></div></footer>
  </div>
</template>
