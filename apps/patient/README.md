# Pruevia Patient

Flutter Web/PWA, Android e iOS desde un solo codebase.

El portal de proveedores falla cerrado mediante
`--dart-define=PROVIDER_PORTAL_ENABLED=false` (valor predeterminado). Una build
centrada en pacientes no muestra el acceso ni acepta `?provider=1`; habilitarlo
es una liberación separada.

La búsqueda pública no requiere cuenta y está dirigida a adultos para la
declaración de Google Play; no se activa un bloqueo de menores. Un familiar puede
usar la app para ayudar a otra persona. La prueba cerrada de Android sólo acepta
testers de 18 años o más.

## Usar la PWA antes de Android

Publica el build web de release en un dominio HTTPS, comparte esa URL desde el
landing y ábrela desde Chrome/Edge/Safari. El aviso de instalación ofrece el
prompt nativo sólo cuando el navegador emite `beforeinstallprompt`; si no lo
emite, muestra los pasos del menú de Android o **Compartir → Agregar a pantalla
de inicio** en Safari para iPhone. No se puede forzar un prompt en cualquier
navegador o visita. Un service worker propio guarda únicamente archivos públicos
de la aplicación; jamás cachea consultas, recetas, imágenes clínicas o respuestas
del API. La búsqueda y comparación siguen requiriendo conexión, aunque el acceso
instalado y parte de la interfaz puedan abrirse sin ella.
El bundle Flutter conserva el nombre fijo `main.dart.js`: los headers de release
prohíben tratarlo como inmutable para que una actualización consulte la versión
publicada. El service worker también usa red primero para esos archivos.

Pruebas del aviso web: `node --test test_web/*.test.mjs`. Verificar además en un
teléfono real con HTTPS, en navegador normal y desde el icono instalado.
Después de `flutter build web`, `node test_web/check_installability.mjs` comprueba
el artefacto en Chrome móvil emulado: montaje de Flutter, manifiesto, iconos, service worker y aviso
o acción nativa. Para revisar producción, define `PRUEVIA_PWA_URL=https://app.pruevia.com.mx/`
antes de correr el mismo script; sólo carga la PWA, no envía búsquedas. Requiere
Chrome local y no sustituye la prueba en el teléfono.

## Ejecutar

```text
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8787
```

Los builds profile/release requieren tambien `API_ALLOWED_HOSTS` con el
hostname exacto del Worker; esto evita enviar imagenes clinicas a un host
arbitrario por una configuracion equivocada.

El feedback estructurado permanece desactivado por defecto y se habilita para
una compilación concreta con `--dart-define=PRODUCT_FEEDBACK_ENABLED=true`.
La analítica anónima y los clics salientes tienen un segundo gate de compilación,
`--dart-define=ANALYTICS_ENABLED=true`; su valor predeterminado es `false` aunque
exista una preferencia de consentimiento guardada.
El aviso usa por defecto `https://pruevia.com.mx/privacidad` cuando no se define
`PRIVACY_POLICY_URL` o está vacío. Una URL configurada distinta debe conservar
HTTPS, dominio exacto y ruta `/privacidad`, sin credenciales, query o fragmento;
una configuración inválida no abre otro destino. Ajustes sólo muestra soporte
cuando `SUPPORT_EMAIL` contiene un correo válido y operativo.

La bienvenida y el shell muestran un recordatorio informativo no modal del aviso,
con enlace permanente. **Entendido** guarda sólo versión y fecha UTC en
`pruevia.privacy_notice.acknowledgment.v1` de SharedPreferences. La versión vigente
es `pruevia-privacidad-2026-10-15-v1`; el acuse dura 180 días y se revisa también
al volver a la app y durante una sesión abierta. Cambiar de versión, borrar datos
o usar otro navegador puede mostrar el recordatorio de nuevo. No se registra IP,
identificador o evento en servidor y no concede analítica, OCR ni tratamiento de
datos médicos. El acuse no prueba lectura del documento ni sustituye los controles
de consentimiento de cada función. Los enlaces del recordatorio sólo se abren
por acción del usuario; en web usan la misma pestaña.
Para la variante cerrada de Android se usa además
`--dart-define=PRUEVIA_CHANNEL=closed_android`; esa variante permite un comentario
opcional sólo después de confirmar 18 años. El feedback público no solicita texto
libre ni incluye la búsqueda, receta, imagen, proveedor o estudio consultado.

Los clics salientes a agenda, estudio, sucursal o sitio del proveedor también
requieren ese consentimiento. Sólo se envían IDs de catálogo/oferta y el tipo de
enlace; nunca el texto buscado o una receta. Admin recibe agregados globales y el
portal de proveedor sólo agregados dentro de una membresía activa verificada.

`API_BASE_URL` debe apuntar al Worker/API desplegado. La búsqueda pública no
requiere autenticación. El botón **Acceso para proveedores** sólo existe en
compilaciones internas que habilitan explícitamente el portal.

Para probar el portal de proveedores localmente añade
`--dart-define=PROVIDER_PORTAL_ENABLED=true`, usa `?provider=1` y declara los
valores públicos de Supabase y sus allowlists exactas (nunca la clave secreta):

```text
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787 --dart-define=API_ALLOWED_HOSTS=localhost:8787 --dart-define=SUPABASE_URL=https://project.supabase.co --dart-define=SUPABASE_ALLOWED_HOSTS=project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=publishable-placeholder
```

El registro permanece cerrado mientras el API devuelva `enabled: false`. La
cuenta requiere confirmación de correo y TOTP antes de consultar o modificar un
expediente; el enlace de comprobación del correo sólo lleva el código en el
fragmento del navegador y se consume una vez.

Flutter no carga archivos `.env` automáticamente: `.env.example` documenta la
variable, pero el valor se inyecta en compilación con `--dart-define`.

## Marca e iconos

La identidad aprobada usa el libro abierto con la P y las líneas de orden de
`design/brand/pruevia-mark.svg`.
Desde la raíz del repositorio, para regenerar favicon, PWA, Android, iOS y
splash después de modificar el SVG:

```text
python design/brand/render_assets.py
```

El icono de marca no sustituye los iconos funcionales de ubicación usados para
mostrar sucursales.

## Principios del MVP

- Búsqueda y receta funcionan como visitante.
- El texto OCR se muestra para revisión antes de resolver.
- No se persisten recetas, imágenes ni resultados clínicos.
- La telemetría sólo se envía con consentimiento y usa un UUID anónimo.
- El backend, no el cliente, decide permisos de proveedor.

## Verificación

```text
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example --dart-define=API_ALLOWED_HOSTS=api.example
dart run tool/render_web_headers.dart --output build/web/_headers --allowed-hosts api.example
```
