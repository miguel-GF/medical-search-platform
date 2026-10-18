# Actualizaciones de la PWA —18-oct-2026 UTC /17-oct local

## Problema y cambio

El usuario vio la versión nueva en navegador y una interfaz antigua desde el
icono instalado. El código tenía instalación y caché público con red primero,
pero no detector de nueva versión para una sesión que permanece abierta.
Una sesión cargada no cambia su JavaScript sólo por publicar otros archivos.

Se añade identificación por contenido de cada build público y comprobación al
iniciar, recuperar visibilidad/conexión y cada cinco minutos si está visible.
Si cambia la versión, aparece **Actualizar y reiniciar / Más tarde**. El aviso
explica la pérdida del estado abierto al reiniciar; no se fuerza la recarga ni
se persisten recetas. La persona puede terminar su consulta antes de actualizar.
Posponer dura30min en memoria. La detección no necesita cuenta, push ni permisos.

`render_web_headers.dart` estampa los archivos generados mediante
`stamp_web_release.dart`: fingerprint de archivos, meta HTML y`app-version.json`.
El JSON contiene únicamente schema, build global yhash del JavaScript público;
no es un identificador de usuario. Usa solicitudes anónimas sin credenciales,
sin datos de búsqueda, cachéHTTP persistente o CacheStorage para ese endpoint.
El registroSW usa `updateViaCache: none`; se conserva el caché público existente
y las exclusiones de API, autorizaciones, queries, recetas e imágenes clínicas.

## Publicación y evidencia

Patient publicado04:46:45UTC, versión `2e1e136b-9e23-4969-9f59-ab350fb9510b`.
Build público `f6361e0b0fe3a789486cc8dc4b79aeae31d9837f2f1d89c4685c6707913e3925`.
Empaquetado de49 archivos sobre el Flutter publicado: JavaScript compilado y
fuentesDart `lib/` idénticos al release anterior, hash
`8a04162ed051a9ef42a0069417db465ede470831df9f0c8f32687db542681aaa`.
Sólo cambian shell web, detector, metadata, registroSW yheaders. SintaxisJS y
análisis de las herramientasDart correctos. No hubo suites, SQL o cambioAPI.

Observación local con navegador y service worker reales, sesiónA abierta y
publicaciónC en el mismo origen de loopback: el aviso apareció, conservó el
texto sintético y no volvió a pedir main.dart.js hasta pulsar actualizar.
Después del clic, la meta coincidió con el manifiesto nuevo y el aviso desapareció.
No hubo errores de página. El primer intento de cambio de pestaña en Chrome
headless no generó el recorrido esperado; se conservó su timeout. La observación
posterior disparó el eventoonline desde el driver: **no acredita la reanudación
nativa de una PWA en un teléfono físico**. No se simularon respuestas del servidor.

Lectura pública04:47UTC: HTML, manifiesto yworker200; meta yJSON coinciden con
el build congelado. Headers `no-cache,no-store,must-revalidate` en los recursos
observados. ControladorSW activo, `updateViaCache: none`, JS remoto idéntico,
aviso ausente cuando ya es la versión vigente y cero errores de página.
Recibos/capturas en `collectors/artifacts/pwa-updates-20261018/`.

## Primera recepción y límites

Una instalación anterior no tiene este detector en su sesión ya abierta. Tras
terminar una orden, cerrar completamente desde las apps recientes y reabrir una
vez permite recibir el cambio. No se solicita desinstalar o borrar datos.
Las actualizaciones siguientes se detectan en la sesión nueva mediante el aviso.
Falta observación en teléfono físico del usuario; no se afirma haberla realizado.
Actualizar los iconos/nombre de un WebAPK sigue su propio ciclo del navegador.
Sin conexión no se ofrece una actualización que no pudo comprobarse en red.

Referencias oficiales: [ciclo de actualización](https://web.dev/learn/pwa/update),
[service worker lifecycle](https://web.dev/articles/service-worker-lifecycle),
[Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).

Recuperación: Patient anterior `5e55a765-f670-42d6-a2fe-2d6bec17dd28`, sin tocar
la API, la base o preferencias del navegador. La versión anterior no conserva
el detector. Mantener la estampación en el proceso de los siguientes releases.
