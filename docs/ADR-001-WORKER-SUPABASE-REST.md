# ADR-001: conexión del Worker con Supabase

**Estado:** aceptado 26 de agosto de 2026

Reconciliado con el transporte y endurecimiento actuales el 14-sep-2026. La
decisión HTTPS/RPC se conserva; la selección de credenciales original fue
reemplazada por el aislamiento Worker descrito abajo.

## Decisión

`apps/api` se conecta a Supabase mediante HTTPS y las funciones RPC públicas (`/rest/v1/rpc/{name}`). No se abre una conexión PostgreSQL desde Cloudflare Workers.

- Las llamadas RPC normales del Worker, incluidas búsqueda y detalle, usan
  `SUPABASE_SECRET_KEY` en servidor. La frontera Worker evita eludir validaciones
  y límites a través de RPC anónimas directas; comprobar privilegios desplegados.
- La clave pública se utiliza para Auth y para el carril explícito de token de
  usuario del transporte; nunca sustituir una sesión inválida por credenciales
  privilegiadas. Ver [supabase.ts](../apps/api/src/supabase.ts).
- Dashboard, cola y revisión exigen usuario validado por Auth, pertenencia a
  `ADMIN_USER_IDS` y AAL2 con factor verificado. Las RPC reciben el contexto validado.
- `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` sólo se mantienen como fallback temporal durante la migración de secretos.
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
