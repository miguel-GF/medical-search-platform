<script setup lang="ts">
const config = useRuntimeConfig();
const publication = config.public.publication;
const patientUrl = String(publication.patientUrl || '');
const providerOrigin = String(publication.providerUrl || '');
const providerUrl = providerOrigin ? `${providerOrigin}/?provider=1` : '';
const supportEmail = String(publication.supportEmail || '');
const ctaUrl = patientUrl || '#como-funciona';
const ctaText = patientUrl ? 'Explorar la app' : 'Conoce cómo funciona';
const shareStatus = ref('');
const menuOpen = ref(false);
const selected = ref('laboratorio');
const examples = {
  laboratorio: { name: 'Biometría hemática', category: 'Análisis clínicos', detail: 'Identifica el estudio y revisa las opciones disponibles para realizarlo.' },
  imagen: { name: 'Ultrasonido abdominal', category: 'Estudios de imagen', detail: 'Revisa la región y las características que indica tu orden antes de comparar.' },
  receta: { name: 'Varios estudios, una búsqueda', category: 'Tu orden médica', detail: 'Distingue qué estudios están cubiertos y cuáles necesitan una aclaración.' },
};
const example = computed(() => examples[selected.value as keyof typeof examples]);
async function shareApp() {
  if (!patientUrl || typeof navigator === 'undefined') return;
  try {
    if (typeof navigator.share === 'function') {
      await navigator.share({ title: 'Pruevia', text: 'Compara estudios médicos con Pruevia.', url: patientUrl });
      return;
    }
    await navigator.clipboard.writeText(patientUrl);
    shareStatus.value = 'Enlace copiado';
    window.setTimeout(() => { shareStatus.value = ''; }, 2500);
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return;
    shareStatus.value = 'Copia el enlace de la app desde el navegador';
  }
}
const faqs = [
  { question: '¿Qué es Pruevia?', answer: 'Es una plataforma para identificar los estudios de tu orden médica y explorar opciones para realizarlos. Estamos construyendo nuestra cobertura inicial en Puebla.' },
  { question: '¿Puedo buscar varios estudios de una receta?', answer: 'La app permite revisar varios estudios y comparar la cobertura por sucursal. Cuando falta información o un estudio no está cubierto, lo indica para que puedas decidir tu siguiente paso.' },
  { question: '¿Los precios y estudios son iguales en todas las sucursales?', answer: 'No necesariamente. Los precios, condiciones y estudios pueden cambiar entre sucursales. Revisa la fuente y vigencia de cada opción y confirma con el proveedor antes de acudir. Si no hay un precio publicado, se indica que requiere cotización.' },
  { question: '¿Necesito crear una cuenta para buscar?', answer: 'La búsqueda de pacientes está pensada para usarse sin registro. El acceso administrativo y el de proveedores son espacios separados y protegidos.' },
  { question: '¿Quién puede usar la app?', answer: 'Pruevia se declara dirigida a adultos en Google Play, pero la consulta pública no exige cuenta ni activa un bloqueo de edad. Un familiar puede usarla para ayudar a otra persona; la prueba cerrada de Android sí requiere tener 18 años o más.' },
  { question: '¿Cómo uso Pruevia mientras llega Android?', answer: 'Puedes abrir la app web desde cualquier navegador. En Android, usa el menú del navegador y elige “Instalar aplicación” o “Agregar a pantalla principal”; en iPhone usa Compartir y “Agregar a inicio”.' },
  ...(providerUrl ? [{ question: '¿Cómo entra un proveedor?', answer: 'El acceso de proveedores es independiente de la búsqueda pública y requiere cuenta, confirmación de correo y segundo factor. Usa el enlace de proveedores del landing cuando esté configurado.' }] : []),
  { question: '¿Pruevia interpreta mi receta o mis resultados?', answer: 'Pruevia ayuda a identificar los nombres de los estudios y a encontrar opciones. No sustituye a tu profesional de salud ni interpreta resultados. Si una indicación es ambigua, te pediremos que la aclares.' },
];
const description = 'Entiende qué estudios necesitas y encuentra opciones para realizarlos. Conoce Pruevia, la plataforma de búsqueda de estudios médicos que comienza en Puebla.';
useSeoMeta({ title: 'Pruevia — Tu próximo paso, más claro', description, ogTitle: 'Tu próximo paso, más claro · Pruevia', ogDescription: description, ogType: 'website', ogLocale: 'es_MX', twitterCard: 'summary' });
if (publication.siteUrl) useHead({ link: [{ rel: 'canonical', href: String(publication.siteUrl) }] });
</script>

<template>
  <div>
    <a class="skip-link" href="#contenido">Saltar al contenido</a>
    <header class="site-header">
      <div class="container header-inner">
        <NuxtLink to="/" class="brand" aria-label="Pruevia, inicio"><BrandMark /><span>Pruevia<span class="brand-dot">.</span></span></NuxtLink>
        <button class="menu-toggle" type="button" :aria-expanded="menuOpen" aria-controls="navigation" @click="menuOpen = !menuOpen">{{ menuOpen ? 'Cerrar menú' : 'Menú' }} <span aria-hidden="true">☰</span></button>
        <nav id="navigation" :class="{ open: menuOpen }" aria-label="Navegación principal">
          <a href="#como-funciona" @click="menuOpen = false">Cómo funciona</a>
          <a href="#puebla" @click="menuOpen = false">Comenzamos en Puebla</a>
          <a href="#preguntas" @click="menuOpen = false">Preguntas frecuentes</a>
          <a v-if="patientUrl" :href="patientUrl" @click="menuOpen = false">Abrir app web</a>
          <a v-if="providerUrl" :href="providerUrl" @click="menuOpen = false">Proveedores</a>
          <NuxtLink to="/prueba-android" @click="menuOpen = false">Prueba Android</NuxtLink>
          <a class="button button-small" :href="ctaUrl" @click="menuOpen = false">{{ ctaText }} <span aria-hidden="true">↗</span></a>
        </nav>
      </div>
    </header>

    <main id="contenido">
      <section class="hero container" aria-labelledby="hero-title">
        <div class="hero-copy">
          <span class="eyebrow"><span class="status-dot" /> NACEMOS EN PUEBLA</span>
          <h1 id="hero-title">Tu orden médica.<br>Tu próximo paso,<br><span>más claro.</span></h1>
          <p class="hero-description">Entre una receta y tu siguiente estudio hay muchas preguntas. Pruevia te ayuda a encontrar opciones y decidir dónde dar el siguiente paso.</p>
          <div class="hero-actions"><a class="button" :href="ctaUrl">{{ ctaText }} <span aria-hidden="true">↗</span></a><a class="text-link" href="#explora">Descubre Pruevia <span aria-hidden="true">↓</span></a></div>
          <p class="hero-note"><span aria-hidden="true">✓</span> Búsqueda sin registro <span class="note-divider">·</span> Tú tienes el control</p>
        </div>

        <div class="hero-art" aria-label="Vista ilustrativa del recorrido de una orden médica a opciones de estudios">
          <span class="orbit orbit-one" /><span class="orbit orbit-two" />
          <div class="floating-tag"><span aria-hidden="true">✧</span> Menos vueltas. Más claridad.</div>
          <div class="order-card">
            <div class="card-heading"><span class="mini-icon" aria-hidden="true">≡</span><span>Tu orden médica<small>El punto de partida</small></span><span class="card-dots" aria-hidden="true">•••</span></div>
            <div class="order-line"><span>01</span><strong>Biometría hemática</strong><span class="line-check" aria-hidden="true">✓</span></div>
            <div class="order-line"><span>02</span><strong>Examen general de orina</strong><span class="line-check" aria-hidden="true">✓</span></div>
            <div class="order-line"><span>03</span><strong>Glucosa</strong><span class="line-check" aria-hidden="true">✓</span></div>
            <div class="card-rule" /><p>Una búsqueda. Un panorama más claro.</p>
          </div>
          <div class="connection-arrow" aria-hidden="true">↓</div>
          <div class="destination-card"><BrandMark /><div><small>EXPLORA TUS OPCIONES</small><strong>Encuentra tu siguiente paso</strong><p>Estudios · Sucursales · Condiciones</p></div><span aria-hidden="true">↗</span></div>
          <span class="illustration-note">Ejemplo ilustrativo. No representa una oferta real.</span>
          <span class="art-spark" aria-hidden="true">✳</span>
        </div>
      </section>

      <section class="principles" aria-label="Lo que hace diferente a Pruevia"><div class="container principles-inner"><p>Información que te acompaña.</p><span><i aria-hidden="true">◎</i> Estudios con claridad</span><span><i aria-hidden="true">⌖</i> Opciones por ubicación</span><span><i aria-hidden="true">◇</i> Condiciones a la vista</span></div></section>

      <section v-if="patientUrl || providerUrl || supportEmail" id="accesos" class="section container access-section" aria-labelledby="access-title">
        <div class="access-grid">
          <div><span class="eyebrow">ENTRA A PRUEVIA</span><h2 id="access-title">La búsqueda, donde la necesitas.</h2><p class="section-copy">Usa la app web sin crear una cuenta. En Android puedes instalarla desde el navegador como PWA mientras terminamos la aplicación de Google Play.</p></div>
          <div class="access-card"><div class="access-actions"><a v-if="patientUrl" class="button" :href="patientUrl">Abrir app web <span aria-hidden="true">↗</span></a><button v-if="patientUrl" class="text-link link-button" type="button" @click="shareApp">Compartir app <span aria-hidden="true">↗</span></button><a v-if="providerUrl" class="text-link" :href="providerUrl">Acceso para proveedores <span aria-hidden="true">↗</span></a><a v-if="supportEmail" class="text-link" :href="`mailto:${supportEmail}`">Contactar soporte <span aria-hidden="true">✉</span></a></div><p class="access-note">En Android: menú del navegador → Instalar aplicación. En iPhone: Compartir → Agregar a pantalla de inicio.</p><p v-if="shareStatus" class="share-status" role="status">{{ shareStatus }}</p></div>
        </div>
      </section>

      <section id="como-funciona" class="section container">
        <div class="section-heading"><div><span class="eyebrow">DE LA ORDEN A LA DECISIÓN</span><h2>Una cosa menos<br>de qué preocuparte.</h2></div><p>No necesitas conocer todos los nombres médicos. Comienza con lo que tienes y avanza con información más clara.</p></div>
        <div class="steps">
          <article><div class="step-top"><span class="step-number">01</span><span class="step-symbol" aria-hidden="true">≡</span></div><h3>Comparte lo que buscas</h3><p>Escribe un estudio o revisa el texto de una fotografía de tu orden en la app.</p><span class="step-caption">TU PUNTO DE PARTIDA</span></article>
          <article><div class="step-top"><span class="step-number">02</span><span class="step-symbol" aria-hidden="true">◎</span></div><h3>Entiende tus opciones</h3><p>Identifica los estudios y aclara las variantes que necesitan un poco más de información.</p><span class="step-caption">SIN ADIVINAR LO IMPORTANTE</span></article>
          <article><div class="step-top"><span class="step-number">03</span><span class="step-symbol" aria-hidden="true">↗</span></div><h3>Elige tu siguiente paso</h3><p>Compara las opciones disponibles por sucursal y revisa precios, fuentes y condiciones.</p><span class="step-caption">UNA DECISIÓN INFORMADA</span></article>
        </div>
      </section>

      <section id="explora" class="explore-section"><div class="container explore-grid">
        <div><span class="eyebrow">HECHO PARA LA VIDA REAL</span><h2>Una receta no debería<br>ser un rompecabezas.</h2><p class="section-copy">Un estudio, varios nombres. Diferentes sucursales y condiciones. Reunimos las piezas para ayudarte a ver tus opciones.</p><ul class="feature-list"><li><span aria-hidden="true">✓</span> Revisa estudios individuales o una orden con varios.</li><li><span aria-hidden="true">✓</span> Distingue lo cubierto de lo que falta aclarar.</li><li><span aria-hidden="true">✓</span> Identifica cuándo necesitas una cotización.</li></ul></div>
        <div class="demo-panel"><div class="demo-top"><span class="eyebrow">EXPLORA UN EJEMPLO</span><span class="demo-badge">Demostración</span></div><div class="demo-tabs" role="group" aria-label="Tipo de ejemplo"><button v-for="(label, key) in { laboratorio: 'Laboratorio', imagen: 'Imagen', receta: 'Varios estudios' }" :key="key" type="button" :aria-pressed="selected === key" @click="selected = key">{{ label }}</button></div><div class="demo-result" aria-live="polite"><span class="result-icon" aria-hidden="true">⌕</span><small>{{ example.category }}</small><h3>{{ example.name }}</h3><p>{{ example.detail }}</p></div><div class="demo-footer"><span aria-hidden="true">ⓘ</span> Ejemplo de uso. Consulta la cobertura real en la app.</div></div>
      </div></section>

      <section id="puebla" class="section container puebla-grid">
        <div class="puebla-art" aria-hidden="true"><svg viewBox="0 0 500 350" fill="none"><path d="M-20 70 520 210M-10 150 490 290M90-20 200 380M220-20 320 380M360-20 440 350M-20 300 510 50" stroke="currentColor" stroke-width="22"/><path d="M80 180 220 220 300 123 400 148" stroke="var(--brand-primary)" stroke-width="3" stroke-dasharray="6 8"/><circle cx="80" cy="180" r="11" fill="var(--brand-primary)"/><circle cx="400" cy="148" r="11" fill="var(--brand-primary)"/></svg><div class="map-label"><BrandMark /><strong>Puebla<small>Aquí comienza Pruevia</small></strong></div><span class="map-note">Una ciudad. Muchas posibilidades.</span></div>
        <div><span class="eyebrow">CERCA DE TU SIGUIENTE PASO</span><h2>Empezamos aquí.<br>Empezamos en Puebla.</h2><p class="section-copy">Estamos construyendo una red de información sobre laboratorios y centros de diagnóstico en Puebla. Con cada fuente revisada, buscamos que encuentres opciones más útiles.</p><p class="coverage-note">La cobertura está en construcción. Los estudios y las condiciones disponibles pueden variar según la sucursal.</p><a class="text-link" href="#preguntas">Conoce los detalles <span aria-hidden="true">↗</span></a></div>
      </section>

      <section id="preguntas" class="section faq-section container"><div><span class="eyebrow">RESOLVAMOS LAS DUDAS</span><h2>Más claridad,<br>desde el principio.</h2><p>Lo que conviene saber<br>antes de empezar.</p></div><div class="faq-list"><details v-for="faq in faqs" :key="faq.question"><summary>{{ faq.question }}<span aria-hidden="true">+</span></summary><p>{{ faq.answer }}</p></details></div></section>

      <section class="container closing-section"><div class="closing-card"><span class="eyebrow">TU SALUD MERECE CLARIDAD</span><h2>El siguiente paso<br>empieza por entender tus opciones.</h2><a class="button button-light" :href="ctaUrl">{{ ctaText }} <span aria-hidden="true">↗</span></a><p>Pruevia · Hecho para acompañar tu búsqueda.</p><span class="closing-decoration" aria-hidden="true">✳</span></div></section>
      <section class="container tester-callout"><div><span class="eyebrow">PRÓXIMAMENTE EN ANDROID</span><h2>Ayúdanos a probar Pruevia.</h2><p>Estamos formando un grupo cerrado de personas adultas de Puebla y municipios cercanos.</p></div><NuxtLink class="button" to="/prueba-android">Conocer la prueba <span aria-hidden="true">↗</span></NuxtLink></section>
    </main>

    <footer class="container site-footer"><div><NuxtLink to="/" class="brand"><BrandMark /><span>Pruevia.</span></NuxtLink><p>Tu próximo paso, más claro.</p></div><div class="footer-links"><a href="#como-funciona">Cómo funciona</a><a v-if="patientUrl" :href="patientUrl">App web</a><a v-if="providerUrl" :href="providerUrl">Proveedores</a><NuxtLink to="/prueba-android">Prueba Android</NuxtLink><a v-if="supportEmail" :href="`mailto:${supportEmail}`">Soporte</a><NuxtLink to="/privacidad">Privacidad</NuxtLink><a href="#puebla">Puebla, México</a></div><div class="footer-bottom"><span>© {{ new Date().getFullYear() }} Pruevia</span><p>Pruevia no sustituye la orientación de un profesional de salud.</p></div></footer>
  </div>
</template>
