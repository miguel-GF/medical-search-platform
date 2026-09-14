<script setup lang="ts">
useSeoMeta({ title: 'Privacidad de este sitio · Pruevia', description: 'Información sobre el funcionamiento de la página informativa de Pruevia.' });
const config = useRuntimeConfig();
if (config.public.siteUrl) useHead({ link: [{ rel: 'canonical', href: `${config.public.siteUrl}/privacidad` }] });
</script>
<template>
  <main class="container privacy-page"><NuxtLink to="/" class="brand"><BrandMark /><span>Pruevia.</span></NuxtLink><span class="eyebrow">INFORMACIÓN DE ESTE SITIO</span><h1>Tu privacidad<br>también importa.</h1><p>Esta página presenta Pruevia y explica su funcionamiento. No contiene formularios de registro ni permite subir órdenes médicas.</p><h2>Qué ocurre al navegar</h2><p>Esta versión no integra herramientas de analítica publicitaria, píxeles de seguimiento ni cookies de marketing. El servicio de alojamiento puede procesar datos técnicos de conexión para entregar el sitio y mantener su seguridad.</p><h2>La aplicación es un espacio separado</h2><p>Si accedes a la aplicación, revisa la información de privacidad y consentimiento que corresponda a sus funciones antes de compartir información. No envíes datos médicos a través de los ejemplos de esta página.</p><h2>Sobre esta información</h2><p>Esta descripción corresponde a la versión informativa del sitio. La información del responsable y el medio de contacto para ejercer derechos deberán estar definidos antes de habilitar nuevos flujos de recopilación de datos.</p><NuxtLink class="button" to="/">Volver al inicio <span aria-hidden="true">↗</span></NuxtLink></main>
</template>
