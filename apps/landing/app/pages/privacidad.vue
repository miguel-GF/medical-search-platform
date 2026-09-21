<script setup lang="ts">
useSeoMeta({ title: 'Privacidad de este sitio · Pruevia', description: 'Información sobre el funcionamiento de la página informativa de Pruevia.' });
const config = useRuntimeConfig();
const publication = config.public.publication;
if (publication.siteUrl) useHead({ link: [{ rel: 'canonical', href: `${publication.siteUrl}/privacidad` }] });
</script>
<template>
  <main class="container privacy-page">
    <NuxtLink to="/" class="brand"><BrandMark /><span>Pruevia.</span></NuxtLink>
    <span class="eyebrow">AVISO DE PRIVACIDAD INTEGRAL</span>
    <h1>Tu privacidad<br>también importa.</h1>

    <template v-if="publication.privacyReady">
      <h2>Responsable y contacto</h2>
      <p><strong>{{ publication.privacyController }}</strong>, con domicilio en {{ publication.privacyAddress }}, es responsable del uso y protección de los datos descritos en este aviso.</p>
      <p>Para limitar el uso, retirar tu solicitud o ejercer derechos de acceso, rectificación, cancelación u oposición (ARCO), escribe a <a :href="`mailto:${publication.privacyEmail}`">{{ publication.privacyEmail }}</a>.</p>
    </template>
    <template v-else>
      <h2>Activación pendiente</h2>
      <p>La PWA, el feedback y la recopilación para testers permanecen desactivados hasta publicar y revisar la identidad y el domicilio real del responsable y el medio de contacto. La existencia de esta página no significa que esos flujos estén abiertos.</p>
    </template>

    <h2>Búsquedas y órdenes en la aplicación</h2>
    <p>Cuando la PWA o la aplicación móvil estén habilitadas, el texto que escribas y las fotografías de órdenes que elijas se enviarán cifrados al API de Pruevia para identificar estudios y devolver opciones. Pueden revelar información de salud aunque no incluyan tu nombre.</p>
    <p>Pruevia no crea una cuenta de paciente ni guarda deliberadamente la búsqueda, la receta o la imagen original en su base de datos. La fotografía se mantiene temporalmente en el dispositivo durante el OCR y se descarta al terminar. La infraestructura de alojamiento puede procesar datos técnicos de conexión para entregar y proteger el servicio.</p>

    <h2>Datos que recopilaremos</h2>
    <p>Cuando la convocatoria esté activa, el formulario solicitará el correo asociado con Google Play, municipio y confirmación de mayoría de edad. La versión de Android y el modelo del dispositivo serán opcionales.</p>
    <p>Este formulario de testers no solicita datos de salud ni datos personales sensibles. No escribas ni adjuntes estudios, diagnósticos, recetas, resultados médicos o imágenes.</p>

    <h2>Finalidades necesarias</h2>
    <p>Usaremos los datos exclusivamente para revisar la solicitud, formar el grupo de prueba, contactar a las personas seleccionadas, administrar invitaciones, prestar soporte operativo y evaluar compatibilidad técnica. No se utilizarán para publicidad, venta de datos, prospección comercial ni decisiones clínicas.</p>
    <p>El consentimiento se manifiesta al marcar la aceptación del aviso y enviar voluntariamente el formulario. Puedes omitir los datos técnicos opcionales.</p>

    <h2>Google Play y terceros</h2>
    <p>Si eres seleccionado, el correo proporcionado podrá registrarse en Google Play Console para gestionar el acceso a la prueba cerrada. Google tratará ese dato conforme a sus propios términos y avisos. No realizaremos otras transferencias que requieran consentimiento sin informarlo previamente.</p>

    <h2>Feedback dentro de la aplicación</h2>
    <p>El feedback y la analítica están apagados en la primera publicación. Si se habilitan después, requieren un gate de compilación y consentimiento. Las respuestas de utilidad se almacenan separadas de la lista de correos; no guardamos junto al feedback la búsqueda, la receta, imágenes, proveedor o estudio consultado.</p>
    <p>La analítica permitida usa un identificador aleatorio que puedes rotar al retirar el consentimiento y sólo admite eventos y conteos acotados. Los clics de salida, si se habilitan, guardan IDs de catálogo, oferta y sucursal, no el texto clínico.</p>

    <h2>Conservación y retiro</h2>
    <p>Los registros individuales del piloto se eliminarán o anonimizarán 90 días después de su cierre. Si retiras tu solicitud, el correo se programará para eliminación en un máximo de 7 días. Las métricas agregadas sin identificadores podrán conservarse para evaluar el producto.</p>

    <h2>Cómo ejercer tus derechos</h2>
    <p>Envía un correo con el asunto “Derechos ARCO — piloto Android”, indicando el correo con el que te registraste, el derecho que deseas ejercer y una descripción clara de tu solicitud. Sólo solicitaremos información adicional cuando sea necesaria para confirmar que eres la persona titular. La respuesta se enviará al mismo correo.</p>

    <h2>Cambios al aviso</h2>
    <p>Los cambios se publicarán en esta misma página indicando una nueva versión. Si cambian de forma material las finalidades o el tratamiento que requiere consentimiento, solicitaremos una nueva aceptación antes de aplicarlos.</p>

    <h2>Qué ocurre al navegar</h2>
    <p>Este sitio no integra analítica publicitaria, píxeles de seguimiento ni cookies de marketing. El alojamiento puede procesar datos técnicos de conexión para entregar el sitio y mantener su seguridad.</p>

    <p>Versión del aviso: {{ publication.testerNoticeVersion }}.</p>
    <template v-if="publication.supportEmail">
      <h2>Soporte</h2>
      <p>Para problemas de acceso o uso de la aplicación escribe a <a :href="`mailto:${publication.supportEmail}`">{{ publication.supportEmail }}</a>. No envíes recetas, diagnósticos ni imágenes por correo.</p>
    </template>
    <NuxtLink class="button" to="/">Volver al inicio <span aria-hidden="true">↗</span></NuxtLink>
  </main>
</template>
