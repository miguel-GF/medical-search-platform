# ADR-001: conexión del Worker con Supabase

**Estado:** aceptado 26 de agosto de 2026

## Decisión

`apps/api` se conecta a Supabase mediante HTTPS y las funciones RPC públicas (`/rest/v1/rpc/{name}`). No se abre una conexión PostgreSQL desde Cloudflare Workers.

- Búsqueda y detalle usan `SUPABASE_ANON_KEY`.
- Dashboard, cola y resolución manual usan `SUPABASE_SERVICE_ROLE_KEY`; el Worker valida el JWT de Supabase Auth y exige que el usuario esté en `ADMIN_USER_IDS`.
- El timeout por llamada es configurable con `SUPABASE_TIMEOUT_MS` y vale 5 segundos por defecto.
- Las funciones SQL son `security definer`, tienen `search_path` explícito y exponen solo los campos del contrato API.
- Supabase gestiona pooling, TLS y disponibilidad de PostgreSQL; el Worker permanece stateless.

## Motivos

Workers no mantienen conexiones TCP persistentes de forma confiable entre invocaciones. HTTPS hacia PostgREST evita pooling propio, reduce secretos en el cliente y permite versionar la superficie pública con migraciones SQL.

## Consecuencias

La latencia incluye una llamada HTTP por RPC y debe medirse en producción. Los errores HTTP y timeouts se convierten en errores controlados del API; no se reintentan automáticamente operaciones Admin para evitar duplicar escrituras.

## Verificación

```powershell
cd apps/api
npm.cmd run typecheck
npm.cmd test
npx.cmd wrangler deploy --dry-run
```
