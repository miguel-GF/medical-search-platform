# Variables de entorno

## Secretos de CI/CD

Los workflows de GitHub no leen un `.env` del repositorio. Requieren estos
secretos configurados en GitHub Actions: `SUPABASE_ACCESS_TOKEN`,
`SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
`SUPABASE_SECRET_KEY`, `CLOUDFLARE_API_TOKEN` y
`CLOUDFLARE_ACCOUNT_ID`. Se mantienen fuera del árbol de trabajo porque son
credenciales de automatización, no configuración de una app local.

Los archivos de ejemplo (`.env.example` y `.dev.vars.example`) sí se versionan.
Los archivos reales (`.env`, `.env.local`, `.dev.vars`) están ignorados por Git y
nunca deben contenerse en un commit. Los valores de ejemplo son nombres y
placeholders, no credenciales funcionales.

Guardar una credencial en el archivo local ignorado previsto no demuestra por
sí solo una exposición. Si apareció en Git, un bundle público, logs compartidos,
capturas o un canal no autorizado, identificar el alcance y coordinar su rotación.
No imprimirla para diagnosticar. El repositorio no conserva copias de respaldo
de secretos; usa un gestor de secretos o las variables protegidas de CI.

## Aplicaciones y herramientas

| Proyecto | Ejemplo versionado | Variables | Archivo local real |
| --- | --- | --- | --- |
| API Cloudflare Worker | `apps/api/.dev.vars.example` | Supabase (publishable/secret), entorno, timeout, CORS, OCR y administradores | `apps/api/.dev.vars` |
| Admin Vue | `apps/admin/.env.example` | `VITE_API_URL`, `VITE_API_ALLOWED_HOSTS` (obligatoria en produccion), `VITE_SUPABASE_URL`, `VITE_SUPABASE_ALLOWED_HOSTS` (obligatoria en produccion), `VITE_SUPABASE_PUBLISHABLE_KEY` | `apps/admin/.env.local` |
| Patient Flutter/PWA | `apps/patient/.env.example` | `API_BASE_URL` | Flutter usa `--dart-define` (no carga `.env` por sí solo) |
| Landing Nuxt | `apps/landing/.env.example` | destinos públicos, `NUXT_PUBLIC_API_URL`, `NUXT_PUBLIC_SUPPORT_EMAIL`, gate de testers y datos revisados del aviso | `apps/landing/.env` |
| OCR FastAPI | `apps/ocr-service/.env.example` | token, motor, límites y puerto | `apps/ocr-service/.env` |
| Collectors Python | `collectors/.env.example` | DENUE, LOINC y DSN opcional de publicación | `collectors/.env` |
| Correo de solicitudes de proveedores | `apps/document-scanner/.env.mail.example` | SMTP TLS, origen HTTPS del portal y Supabase secreto | gestor de secretos del job privado |

Para Patient, los builds profile/release deben recibir `API_ALLOWED_HOSTS` con
el hostname exacto del Worker junto con `API_BASE_URL`; el cliente rechaza
origenes no declarados antes de enviar texto o imagenes. El build web debe
generar tambien `build/web/_headers` con
`apps/patient/tool/render_web_headers.dart`; la CSP queda limitada a esos
hosts y no a cualquier HTTPS.

Para una compilación local del paciente con feedback visible, añadir
`--dart-define=PRODUCT_FEEDBACK_ENABLED=true`. La variante cerrada de Android
añade `--dart-define=PRUEVIA_CHANNEL=closed_android`; ambas son fail-closed si el
Worker o el gate remoto no están activados. No poner datos legales inventados en
el landing: `NUXT_PUBLIC_TESTER_INTAKE_ENABLED=true` sólo después de revisar
responsable, domicilio, correo y versión del aviso.

En el Worker, Wrangler toma los valores locales desde `.dev.vars` y los secretos
de producción deben cargarse con `wrangler secret put`. No se deben trasladar
secretos del servidor a un `.env` del frontend.
`APP_ENV` debe declararse siempre: `development` o `test` solo para entornos
locales/pruebas; cualquier valor ausente o desconocido se trata como entorno
seguro y hace fallar el Worker si falta un origen HTTPS explícito o un binding
de rate limit.
Los bindings de rate limit se definen en `apps/api/wrangler.toml`: público,
captura de revisión, OCR, Admin y proveedor. Verificar los cinco junto con los
requisitos del Worker vigente antes de publicar.

Para integrar más de un frontend, `ALLOWED_ORIGINS` acepta una lista separada
por comas de orígenes exactos y toma precedencia sobre `ALLOWED_ORIGIN`. En
producción todos deben ser HTTPS, sin rutas, credenciales, query ni fragmentos;
un origen que no esté en la lista recibe 403 y nunca se refleja en CORS. La
variable es opt-in: mientras no se configure, el contrato existente de
`ALLOWED_ORIGIN` permanece vigente. En local se permiten origenes HTTP para
`localhost`/127.0.0.1 mediante `APP_ENV=development`.

La configuracion iOS `Release` usa firma manual `Apple Distribution` y no puede
caer en una identidad de desarrollo. El pipeline debe proporcionar
`PRUEVIA_IOS_TEAM_ID` y `PRUEVIA_IOS_PROVISIONING_PROFILE` como ajustes de build
protegidos (junto con el certificado/perfil efimeros); nunca los guardes en el
repositorio ni en un bundle de la app.

## Qué es público y qué es secreto

- `VITE_SUPABASE_PUBLISHABLE_KEY`/`SUPABASE_PUBLISHABLE_KEY` es una clave pública
  con políticas RLS; aun así se configura mediante los ejemplos para evitar
  valores dispersos.
- `SUPABASE_SECRET_KEY`/`SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_USER_IDS`, `DENUE_API_TOKEN`,
  `OCR_SERVICE_TOKEN`, `SUPABASE_ACCESS_TOKEN` y `CLOUDFLARE_API_TOKEN` son
  secretos. Se mantienen sólo en la máquina local, secretos de Wrangler o
  secretos del proveedor de CI.
- Nunca se imprimen tokens en logs, URLs, artefactos ni mensajes de error.

El job `pruevia-provider-mail` requiere `SMTP_HOST`, `SMTP_PORT` (465 por
defecto), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `PROVIDER_PORTAL_ORIGIN`,
`SUPABASE_URL` y `SUPABASE_SECRET_KEY`. Debe correr sin proxy, redirecciones ni
endpoint público; valida que el portal y Supabase sean HTTPS y procesa como
máximo diez mensajes por tanda. No habilitarlo con un buzón personal ni guardar
el secreto SMTP en `.env` del frontend.

Las variables nuevas `SUPABASE_PUBLISHABLE_KEY` y `SUPABASE_SECRET_KEY` son
preferidas por el Worker; las variables `SUPABASE_ANON_KEY` y
`SUPABASE_SERVICE_ROLE_KEY` quedan sólo como compatibilidad temporal. El
workflow de DEV acepta ambas nomenclaturas durante la migración. La clave
secret nunca debe llegar al frontend.

## Desarrollo local

1. Copia el ejemplo correspondiente al archivo local indicado en la tabla.
2. Sustituye únicamente los placeholders en tu máquina.
3. Para Flutter, ejecuta por ejemplo:

   ```text
   flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8787
   ```

4. Para el Admin Vue, ejecuta `npm.cmd run dev` (Vite usa el puerto 5173 por
   defecto); para el API, ejecuta `npx wrangler dev`; Wrangler leerá
   `apps/api/.dev.vars`.

Antes de subir cambios, comprueba que `git status` no muestre archivos `.env`,
`.env.local` ni `.dev.vars` y que los ejemplos sólo contengan placeholders.
