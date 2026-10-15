<script setup lang="ts">
import { PRIVACY_NOTICE_VERSION } from '~/utils/privacyNotice';
useSeoMeta({ title: 'Aviso de privacidad · Pruevia', description: 'Información sobre búsquedas, órdenes, fotografías y preferencias de privacidad en Pruevia.' });
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
      <p>Para consultas de privacidad, limitar el uso de tus datos, revocar una autorización o ejercer derechos de acceso, rectificación, cancelación u oposición (ARCO), escribe a <a :href="`mailto:${publication.privacyEmail}`">{{ publication.privacyEmail }}</a>.</p>
    </template>
    <template v-else>
      <h2>Activación pendiente</h2>
      <p>El acceso a la aplicación y los formularios que requieran datos personales permanecen desactivados hasta completar y revisar la identidad, el domicilio y el contacto del responsable. Publicar este texto no activa por sí solo esos servicios.</p>
    </template>

    <h2>Búsquedas y órdenes en la aplicación</h2>
    <p>La búsqueda pública no requiere una cuenta de paciente. Para identificar estudios y mostrar opciones, el texto que escribas o pegues se envía mediante una conexión cifrada a la API de Pruevia y se procesa con su infraestructura de Cloudflare y Supabase. Si proporcionas una ubicación o eliges una sede, también se utiliza ese contexto para la consulta. El texto puede revelar información de salud aunque no incluya tu nombre; evita añadir datos que no sean necesarios para buscar los estudios.</p>
    <p>Usar el sitio, abrir este aviso o cerrar su recordatorio no constituye por sí solo consentimiento para cualquier tratamiento de datos. Las decisiones que requieran autorización específica se presentan por separado. Pruevia identifica estudios; no diagnostica ni interpreta resultados médicos.</p>

    <h2>Fotografías y lectura de órdenes</h2>
    <p>Antes de enviar una fotografía para lectura automática (OCR), la aplicación solicita una autorización específica para ese envío. Es independiente del recordatorio del aviso y de cualquier preferencia de medición. Puedes escribir los nombres de los estudios si prefieres no enviar una imagen.</p>
    <p>La imagen completa seleccionada, incluidos los nombres, firmas u otros datos que contenga, se transmite a la API y al servicio de OCR configurado por Pruevia o a Cloudflare Workers AI. Pedir que se omitan identificadores de la transcripción ocurre después del envío y no garantiza que desaparezcan todos. La lectura no sucede exclusivamente en tu dispositivo.</p>
    <p>El procesamiento revisado no crea un archivo permanente de la imagen en la base de datos de Pruevia. La aplicación intenta liberar la imagen y limpiar archivos temporales durante el flujo; esto no garantiza la eliminación inmediata de todas las copias, cachés, registros técnicos o respaldos de los servicios que intervienen. El archivo original que elegiste no se borra de tu dispositivo. Revisa el texto reconocido antes de utilizarlo.</p>

    <h2>Captura de consultas y antecedente</h2>
    <p>La captura interna de búsquedas no resueltas para mejorar el catálogo está desactivada en esta apertura. Es independiente de la medición de uso y no se habilita al pulsar «Entendido».</p>
    <p>El 25 de septiembre de 2026 se detectó que una versión anterior había conservado términos normalizados de algunas consultas no resueltas para revisión interna. Esa captura se desactivó. No afirmamos que nunca se hayan guardado consultas ni que el histórico haya sido eliminado; puedes consultar al contacto de privacidad sobre este antecedente y tus derechos.</p>

    <h2>Medición y comentarios</h2>
    <p>La medición de uso y los comentarios de producto permanecen desactivados en esta apertura. Si se habilitan, se informará qué datos se utilizan, con qué finalidad y qué decisión separada corresponde. La búsqueda no se condiciona a aceptar medición opcional.</p>
    <p>La implementación de medición utiliza un identificador aleatorio para relacionar eventos de un mismo navegador o instalación. Los clics podrían asociarlo con el estudio, oferta, proveedor o sede seleccionados: eso no equivale a anonimato completo. Retirar una preferencia local detiene los futuros envíos del cliente, pero no elimina por sí solo registros anteriores.</p>

    <h2>Convocatoria Android y proveedores</h2>
    <p>La recopilación de solicitudes para testers y el acceso público de proveedores permanecen cerrados. Si se abre una convocatoria Android, se informarán sus datos y finalidades antes de recibir solicitudes. El correo asociado con Google Play podría utilizarse para administrar invitaciones; Google aplicará también sus propios términos y avisos.</p>
    <p>No envíes recetas, diagnósticos, resultados ni imágenes médicas por formularios de testers o por correo de soporte. Un aviso publicado no activa esos formularios ni autoriza usos futuros.</p>

    <h2>Servicios externos y datos técnicos</h2>
    <p>Cloudflare, Supabase y el servicio de lectura que corresponda intervienen en el procesamiento descrito. El alojamiento y los servicios de seguridad pueden tratar direcciones IP y otros datos técnicos de conexión para entregar el servicio y limitar abusos. Es un tratamiento distinto de la preferencia local del recordatorio.</p>
    <p>Al abrir el sitio de un laboratorio o clínica, tu navegador se conecta con ese tercero y se aplican sus propias políticas. El enlace no constituye una reserva dentro de Pruevia. Consulta sus condiciones antes de proporcionar datos.</p>

    <h2>Conservación y retiro</h2>
    <p>No se establece aquí una promesa de eliminación inmediata o ausencia absoluta de conservación. Los plazos y procedimientos dependen del tratamiento, las obligaciones aplicables y los servicios de infraestructura. Antes de habilitar nuevos registros se informarán sus condiciones de conservación y retiro. Puedes solicitar información sobre los datos que te conciernan por el canal de privacidad.</p>

    <h2>Cómo ejercer tus derechos</h2>
    <p>Utiliza el contacto de privacidad indicado arriba con el asunto «Privacidad y derechos — Pruevia». Describe el derecho o la petición y la información que permita localizar el tratamiento, sin adjuntar datos de salud que no sean necesarios. No necesitas haber participado en el piloto Android. Se podrá solicitar la información proporcional necesaria para acreditar tu identidad o representación y tramitar la petición; no envíes documentos de identidad hasta recibir indicaciones por un canal adecuado.</p>

    <h2>Recordatorio y almacenamiento local</h2>
    <p>El enlace al aviso permanece disponible. «Entendido» sólo cierra un recordatorio: no acredita lectura, firma ni aceptación de un tratamiento médico. Se guardan localmente la versión del aviso, la fecha y una caducidad de 180 días, sin usar tu IP para reconocerte ni enviar ese cierre al servidor.</p>
    <p>El recordatorio vuelve a mostrarse al vencer el plazo o cambiar la versión. Puede aparecer antes si borras preferencias, cambias de navegador o dispositivo. Si el almacenamiento está bloqueado, el cierre sólo se conserva durante la sesión actual. La página y la aplicación pueden guardar preferencias separadas.</p>

    <h2>Cambios al aviso</h2>
    <p>Los cambios se publicarán en esta misma página indicando una nueva versión. Los cambios que requieran autorización se presentarán con la decisión específica correspondiente; cerrar el recordatorio no la sustituye.</p>

    <h2>Qué ocurre al navegar</h2>
    <p>Este sitio no integra analítica publicitaria, píxeles de seguimiento ni cookies de marketing. El alojamiento puede procesar datos técnicos de conexión para entregar el sitio y mantener su seguridad.</p>

    <p>Versión del aviso: {{ PRIVACY_NOTICE_VERSION }}. Actualizado el 15 de octubre de 2026.</p>
    <template v-if="publication.supportEmail">
      <h2>Soporte</h2>
      <p>Para problemas de acceso o uso de la aplicación escribe a <a :href="`mailto:${publication.supportEmail}`">{{ publication.supportEmail }}</a>. No envíes recetas, diagnósticos ni imágenes por correo.</p>
    </template>
    <NuxtLink class="button" to="/">Volver al inicio <span aria-hidden="true">↗</span></NuxtLink>
  </main>
</template>
