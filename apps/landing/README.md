# Landing de Pruevia

Nuxt 4 + Vue/TypeScript, HTML prerenderizado para hosting estático. Esta app es
independiente del Admin/paciente y no consulta Supabase ni acepta información médica.
El prototipo local no publica ningún servicio ni acredita preparación del core.

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

`.env.example` documenta `NUXT_PUBLIC_SITE_URL`, `NUXT_PUBLIC_PATIENT_URL` y
`NUXT_PUBLIC_INDEXABLE`. Se toman al compilar; en hosting estático hay que
regenerar para cambiar destinos. Sólo URLs HTTPS revisadas, sin credenciales,
fragmentos ni parámetros. SITE_URL es un origen, no una subruta.

Sin destinos, los CTA explican el producto dentro del sitio. `noindex` y robots
impiden solicitar indexación del borrador, pero no son control de acceso. Con
destinos comprobados, `INDEXABLE=true` requiere ambas URLs y genera sitemap.
No asumir que `pruevia.com.mx` o `app.pruevia.com.mx` están comprados/publicados.

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
`sitemap.xml` sólo aparece cuando `NUXT_PUBLIC_INDEXABLE=true` y ambas URLs son
destinos HTTPS revisados.
`public/_headers` contiene headers para un host que soporte ese formato, como
Cloudflare Pages. Verificar su aplicación real después del despliegue. CSP permite
inline para hidratación Nuxt; sin llamadas a servicios externos ni formularios.
No copiar esa política a Admin o al Worker.

El theme de marketing está en `app/assets/theme.css`; colores de marca coordinados
con Admin y paciente. CSS de presentación en `app/assets/main.css`; contenido en
`app/pages/index.vue`. No se cargan fuentes, imágenes ni analytics de terceros.

Se eligió Nuxt 4 para esta app nueva: [Nuxt 3 finalizó mantenimiento](https://nuxt.com/docs/3.x/community/roadmap).
La [generación estática](https://nuxt.com/docs/4.x/getting-started/deployment)
permite SEO sin un servidor persistente para este contenido.
