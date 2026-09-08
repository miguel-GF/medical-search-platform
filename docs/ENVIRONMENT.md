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

Si una credencial aparece en un archivo local, aunque este ignorado, trátala
como expuesta: revócala y genera una nueva en el proveedor antes de volver a
usar el entorno. El repositorio no conserva copias de respaldo de esos
secretos; usa un gestor de secretos o las variables protegidas de CI.

## Aplicaciones y herramientas

| Proyecto | Ejemplo versionado | Variables | Archivo local real |
| --- | --- | --- | --- |
| API Cloudflare Worker | `apps/api/.dev.vars.example` | Supabase (publishable/secret), entorno, timeout, CORS, OCR y administradores | `apps/api/.dev.vars` |
| Admin Vue | `apps/admin/.env.example` | `VITE_API_URL`, `VITE_API_ALLOWED_HOSTS` (obligatoria en produccion), `VITE_SUPABASE_URL`, `VITE_SUPABASE_ALLOWED_HOSTS` (obligatoria en produccion), `VITE_SUPABASE_PUBLISHABLE_KEY` | `apps/admin/.env.local` |
| Patient Flutter/PWA | `apps/patient/.env.example` | `API_BASE_URL` | Flutter usa `--dart-define` (no carga `.env` por sí solo) |
| OCR FastAPI | `apps/ocr-service/.env.example` | token, motor, límites y puerto | `apps/ocr-service/.env` |
| Collectors Python | `collectors/.env.example` | DENUE, LOINC y DSN opcional de publicación | `collectors/.env` |

Para Patient, los builds profile/release deben recibir `API_ALLOWED_HOSTS` con
el hostname exacto del Worker junto con `API_BASE_URL`; el cliente rechaza
origenes no declarados antes de enviar texto o imagenes. El build web debe
generar tambien `build/web/_headers` con
`apps/patient/tool/render_web_headers.dart`; la CSP queda limitada a esos
hosts y no a cualquier HTTPS.

En el Worker, Wrangler toma los valores locales desde `.dev.vars` y los secretos
de producción deben cargarse con `wrangler secret put`. No se deben trasladar
secretos del servidor a un `.env` del frontend.
`APP_ENV` debe declararse siempre: `development` o `test` solo para entornos
locales/pruebas; cualquier valor ausente o desconocido se trata como entorno
seguro y hace fallar el Worker si falta un origen HTTPS explícito o un binding
de rate limit.
Los bindings de rate limit se definen en `apps/api/wrangler.toml`, incluido
`REVIEW_CAPTURE_RATE_LIMITER`; los cuatro deben existir en produccion.

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
