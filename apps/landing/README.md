# Landing de Pruevia

Nuxt 4 + Vue/TypeScript, HTML prerenderizado para hosting estático. Esta app es
independiente del Admin/paciente y sólo habla con el Worker para consultar el
estado de la convocatoria y, cuando está activada, registrar interés en la prueba
cerrada de Android. Nunca acepta órdenes, diagnósticos ni otra información médica.
El prototipo local no publica ningún servicio ni acredita preparación del core.
La página del piloto muestra el progreso agregado hacia 20 personas y, una vez
iniciada la cohorte completa, `Día N de 21`; nunca publica correos ni el enlace
privado de Google Play. Mientras se reúne el grupo ofrece la app web configurada.

## Desarrollo

Desde `apps/landing`, Node compatible con Nuxt 4.5.2 (Node 24.11+ recomendado):

```powershell
npm.cmd ci
npm.cmd run dev
```

Abrir `http://localhost:3000`. La demostración cambia por categoría, los enlaces
internos navegan a secciones, las preguntas se expanden y el menú es adaptable.
La página de privacidad describe sólo este sitio informativo; no sustituye un
aviso legal integral para futuros registros, formularios o tratamiento de datos.

## Configuración y revisión previa a publicación

`.env.example` documenta `PRUEVIA_SITE_URL`, el gate
`PRUEVIA_PATIENT_APP_ENABLED`, `PRUEVIA_PATIENT_URL`, el gate
`PRUEVIA_PROVIDER_ACCESS_ENABLED`, `PRUEVIA_PROVIDER_URL`,
`PRUEVIA_SUPPORT_EMAIL`, `PRUEVIA_API_URL`, `PRUEVIA_INDEXABLE` y el gate de
testers junto con los datos del aviso. Se
toman al compilar; en hosting estático hay que regenerar
para cambiar destinos. Sólo URLs HTTPS revisadas, sin credenciales, fragmentos
ni parámetros. SITE_URL es un origen, no una subruta.

Sin destinos, los CTA explican el producto dentro del sitio. `noindex` y robots
impiden solicitar indexación del borrador, pero no son control de acceso. Con
el sitio comprobado, `INDEXABLE=true` genera sitemap.
El acceso de proveedores falla cerrado. Definir una URL no basta para mostrarlo:
también debe habilitarse explícitamente `PRUEVIA_PROVIDER_ACCESS_ENABLED=true`.
La primera publicación centrada en pacientes debe conservarlo en `false`.
La PWA usa el mismo patrón: su enlace sólo aparece con
`PRUEVIA_PATIENT_APP_ENABLED=true`, una URL HTTPS y los tres datos de
privacidad completos. Esto permite publicar primero un landing informativo sin
abrir prematuramente el tratamiento de búsquedas u órdenes.

Antes de publicación externa, presentar destino, configuración, contenido,
implicaciones y resultados al usuario y esperar aprobación crítica. Comprobar
también la información legal/contacto necesaria para el sitio público. No
incluir números de cobertura, testimonios ni ofertas sin evidencia actual.

## Verificación

```powershell
npm.cmd test
npm.cmd run typecheck
npm.cmd run generate
```

Salida estática: `.output/public`, con home, privacidad, recursos y robots. El
`sitemap.xml` sólo aparece cuando `PRUEVIA_INDEXABLE=true` y el destino del sitio
está revisado.
`public/_headers` contiene headers para un host que soporte ese formato, como
Cloudflare Pages. Verificar su aplicación real después del despliegue. CSP permite
inline para hidratación Nuxt y limita `connect-src` al API configurado cuando el
formulario está activado. No copiar esa política a Admin o al Worker.

El theme de marketing está en `app/assets/theme.css`; colores de marca coordinados
con Admin y paciente. CSS de presentación en `app/assets/main.css`; contenido en
`app/pages/index.vue`. No se cargan fuentes, imágenes ni analytics de terceros.

Se eligió Nuxt 4 para esta app nueva: [Nuxt 3 finalizó mantenimiento](https://nuxt.com/docs/3.x/community/roadmap).
La [generación estática](https://nuxt.com/docs/4.x/getting-started/deployment)
permite SEO sin un servidor persistente para este contenido.
