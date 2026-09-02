# Variables de entorno

## Secretos de CI/CD

Los workflows de GitHub no leen un `.env` del repositorio. Requieren estos
secretos configurados en GitHub Actions: `SUPABASE_ACCESS_TOKEN`,
`SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY`, `CLOUDFLARE_API_TOKEN` y
`CLOUDFLARE_ACCOUNT_ID`. Se mantienen fuera del árbol de trabajo porque son
credenciales de automatización, no configuración de una app local.

Los archivos de ejemplo (`.env.example` y `.dev.vars.example`) sí se versionan.
Los archivos reales (`.env`, `.env.local`, `.dev.vars`) están ignorados por Git y
nunca deben contenerse en un commit. Los valores de ejemplo son nombres y
placeholders, no credenciales funcionales.

## Aplicaciones y herramientas

| Proyecto | Ejemplo versionado | Variables | Archivo local real |
| --- | --- | --- | --- |
| API Cloudflare Worker | `apps/api/.dev.vars.example` | Supabase, timeout, CORS, OCR y administradores | `apps/api/.dev.vars` |
| Admin Vue | `apps/admin/.env.example` | `VITE_API_URL`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` | `apps/admin/.env.local` |
| Patient Flutter/PWA | `apps/patient/.env.example` | `API_BASE_URL` | Flutter usa `--dart-define` (no carga `.env` por sí solo) |
| OCR FastAPI | `apps/ocr-service/.env.example` | token, motor, límites y puerto | `apps/ocr-service/.env` |
| Collectors Python | `collectors/.env.example` | DENUE, LOINC y DSN opcional de publicación | `collectors/.env` |

En el Worker, Wrangler toma los valores locales desde `.dev.vars` y los secretos
de producción deben cargarse con `wrangler secret put`. No se deben trasladar
secretos del servidor a un `.env` del frontend.

## Qué es público y qué es secreto

- `VITE_SUPABASE_ANON_KEY`/`SUPABASE_ANON_KEY` es una clave pública con políticas
  RLS; aun así se configura mediante los ejemplos para evitar valores dispersos.
- `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_USER_IDS`, `DENUE_API_TOKEN`,
  `OCR_SERVICE_TOKEN`, `SUPABASE_ACCESS_TOKEN` y `CLOUDFLARE_API_TOKEN` son
  secretos. Se mantienen sólo en la máquina local, secretos de Wrangler o
  secretos del proveedor de CI.
- Nunca se imprimen tokens en logs, URLs, artefactos ni mensajes de error.

## Desarrollo local

1. Copia el ejemplo correspondiente al archivo local indicado en la tabla.
2. Sustituye únicamente los placeholders en tu máquina.
3. Para Flutter, ejecuta por ejemplo:

   ```text
   flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8787
   ```

4. Para el API, ejecuta `npx wrangler dev`; Wrangler leerá `apps/api/.dev.vars`.

Antes de subir cambios, comprueba que `git status` no muestre archivos `.env`,
`.env.local` ni `.dev.vars` y que los ejemplos sólo contengan placeholders.
