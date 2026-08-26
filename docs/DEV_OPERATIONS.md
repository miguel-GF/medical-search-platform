# Operacion DEV antes de Flutter

Este documento deja reproducible el entorno que ya se puede operar sin desplegar Flutter.

## Supabase

Desde `database/`:

```powershell
npx.cmd supabase@latest db push --linked --include-seed
npx.cmd supabase@latest db push --linked --dry-run
npx.cmd supabase@latest db query --linked --file supabase/tests/database_v1_test.sql
npx.cmd supabase@latest db query --linked --file supabase/tests/database_v1_invariants.sql
npx.cmd supabase@latest db query --linked --file supabase/tests/public_api_test.sql
npx.cmd supabase@latest db query --linked --file supabase/tests/gate_a_test.sql
```

## Collectors

Desde `collectors/`:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_chopo --max-pages 4
python -m pruevia_collectors.cli_ruiz --max-records 200 --per-department 20
python -m pruevia_collectors.cli --condition laboratorio --latitude 19.0433 --longitude -98.2011 --radius-meters 5000
```

El tercer comando requiere `DENUE_API_TOKEN` oficial. Los artefactos se validan antes de publicar:

```powershell
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id> --dry-run
```

## API Worker

Desde `apps/api/`:

```powershell
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
npx.cmd wrangler deploy --dry-run
npx.cmd wrangler login
npx.cmd wrangler secret put SUPABASE_URL
npx.cmd wrangler secret put SUPABASE_ANON_KEY
npx.cmd wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx.cmd wrangler secret put ADMIN_TOKEN
npx.cmd wrangler deploy
```

El deploy real requiere autenticación Cloudflare; el dry-run ya está verificado.

## Admin V1

Desde `apps/admin/`:

```powershell
$env:VITE_API_URL = "https://<worker>.workers.dev"
$env:VITE_ADMIN_TOKEN = "<admin-token>"
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
npm.cmd run build
npm.cmd run dev
```

El workflow `.github/workflows/ci.yml` repite estas verificaciones en cada push/PR. El deploy DEV del Worker es manual o corre al hacer push de `develop` cuando estén configurados los secrets de Cloudflare y Supabase.
