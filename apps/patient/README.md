# Pruevia Patient

Flutter Web/PWA, Android e iOS desde un solo codebase.

## Ejecutar

```text
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8787
```

Los builds profile/release requieren tambien `API_ALLOWED_HOSTS` con el
hostname exacto del Worker; esto evita enviar imagenes clinicas a un host
arbitrario por una configuracion equivocada.

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
