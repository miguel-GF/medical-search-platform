# Controles móviles — 18-oct-2026 UTC /17-oct local

## Problema reportado

El usuario seguía viendo acciones compactas y demasiado redondeadas en producción,
incluidas «Tengo una receta», «Resolver estudios» y «Subir receta».
La revisión anterior acreditó sólo acciones concretas, no todos los controles.

Observación pública04:12 UTC,390px: la portada conserva «Explorar la app» de
189.6px de ancho y radio9px. La app muestra Buscar y Tengo una receta a350px;
el formulario de orden añade18px de margen interior por lado, reduciendo las
acciones respecto del contenido principal. La captura pública se conserva;
no se atribuye la diferencia reportada a caché sin evidencia.

## Cambio publicado

- Radio compartido de botones8px en paciente y portada.
- Altura mínima52px para botones principales y acciones agrupadas del paciente.
- Acciones de resolver/subir receta fuera del margen adicional de la tarjeta,
  con el mismo ancho de contenido que Buscar.
- Enlaces de proveedor y acciones informativas agrupados en columna móvil.
- CTAs de portada al100% de su contenedor hasta800px; enlaces secundarios
  de las mismas secciones con área de interacción amplia.

Se conserva margen lateral de la página para que los botones no peguen al borde
del dispositivo. Los iconos de navegación y controles de menú conservan su uso
propio; no se transforman en acciones principales de pantalla completa.

## Evidencia

`collectors/artifacts/mobile-controls-20261018/`: capturas anteriores, medidas,
compilaciones y siguientes recibos de publicación/observación. No se añaden ni
ejecutan suites. El estado publicado debe acreditarse con la versión y el
contenido servido; un cambio local o un build terminado no lo sustituye.

La revisión comercial anterior publicó API
`45ed6a34-fcf6-4205-8d6b-0555926072d4`. El aviso de alcance por sede se publicó
después en Patient `361dff4c-af7d-449f-989b-434ffdbbe66e` a04:11 UTC18-oct,
con JS `d0d82b6d474b5cdd9f90412355b99020fb21db71abd0faafa3c04d23fbd342ce`.
Las correcciones móviles son posteriores y conservan reservas ocultas,
privacidad y controles administrativos cerrados.

Patient publicado04:19:29 UTC, versión
`5e55a765-f670-42d6-a2fe-2d6bec17dd28`, JS congelado
`8a04162ed051a9ef42a0069417db465ede470831df9f0c8f32687db542681aaa`.
Portada publicada04:19:30 UTC, versión
`49e394b5-2fb2-41c3-bddd-4e6f3fbf581c`.
Compilación Flutter y generación Nuxt terminadas0; análisis dirigido de
main/theme/models sin hallazgos.46 archivos Patient y24 archivos landing
congelados antes de publicar. Sin suites.

Navegador público04:19–04:20 UTC,390px: Buscar,Tengo una receta,Resolver estudios
ySubir receta **350px de ancho**, x20. Los botones de receta se observan52px de
alto; el área semántica de Buscar mide50px, por lo que no se afirma igualdad
exacta de todas las alturas. Capturas inspeccionadas: contorno rectangular con
radio8px, botones de receta fuera del margen adicional de la tarjeta, sin
recorte. El radio Flutter se acredita por fuente congelada e imagen, no por el
radioCSS0 del nodo semántico, que no es el borde dibujado en canvas.
Portada: Explorar la app pasa de189.6 a354px, x18, radio computado8px.
Abrir app web ocupa298px, todo el ancho disponible dentro de su tarjeta.
Evidencia en `after/observed.json` y capturas home/order.

Recuperación: Patient anterior `361dff4c-af7d-449f-989b-434ffdbbe66e`,
landing anterior `18d3718c-1e45-4054-8859-26bf6c25c6ca`.

Local también refrescado: debug terminado0 a04:22 UTC; servidor existente8080
conservado. API yJS locales200; hash servido idéntico al último build
`bb0be9b760170518667567c4f278c6d9f713fd1a32daf0fff65b5849d635ac9e`.
Recibos `local-refresh-receipt.json` y `local-observed.json` en el artefacto.
