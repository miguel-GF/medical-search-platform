# Pruevia Patient

Flutter Web/PWA, Android e iOS desde un solo codebase.

La búsqueda pública no requiere cuenta y está dirigida a adultos para la
declaración de Google Play; no se activa un bloqueo de menores. Un familiar puede
usar la app para ayudar a otra persona. La prueba cerrada de Android sólo acepta
testers de 18 años o más.

## Usar la PWA antes de Android

Publica el build web de release en un dominio HTTPS, comparte esa URL desde el
landing y abrela desde Chrome/Edge/Safari. En Android, el usuario puede elegir
**Instalar aplicación** o **Agregar a pantalla principal** desde el menú del
navegador; en iPhone usa **Compartir → Agregar a pantalla de inicio**. Esto crea
un acceso independiente mientras llega el APK, pero no equivale a tener soporte
offline: Flutter ya no genera un service worker automáticamente, así que el
cacheo offline requiere una implementación posterior.

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
Para la variante cerrada de Android se usa además
`--dart-define=PRUEVIA_CHANNEL=closed_android`; esa variante permite un comentario
opcional sólo después de confirmar 18 años. El feedback público no solicita texto
libre ni incluye la búsqueda, receta, imagen, proveedor o estudio consultado.

Los clics salientes a agenda, estudio, sucursal o sitio del proveedor también
requieren ese consentimiento. Sólo se envían IDs de catálogo/oferta y el tipo de
enlace; nunca el texto buscado o una receta. Admin recibe agregados globales y el
portal de proveedor sólo agregados dentro de una membresía activa verificada.

`API_BASE_URL` debe apuntar al Worker/API desplegado. La búsqueda pública no
requiere autenticación. El botón **Acceso para proveedores** es secundario y
no convierte la pantalla inicial en un registro.

Para probar el portal de proveedores localmente usa `?provider=1` y declara los
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
