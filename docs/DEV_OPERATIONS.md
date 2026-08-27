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
python -m pruevia_collectors.cli_salud_digna --location-slug puebla-municipio-libre
python -m pruevia_collectors.cli --condition laboratorio --latitude 19.0433 --longitude -98.2011 --radius-meters 5000
```

El comando de DENUE requiere `DENUE_API_TOKEN` oficial. Los artefactos se validan antes de publicar:

```powershell
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id> --dry-run
```

Con un DSN de servidor, el artefacto se publica con `cli_publish` sin `--dry-run`.
Si sólo está disponible el proyecto enlazado de Supabase, los renderers generan
SQL idempotente en lotes (la API rechaza archivos grandes):

```powershell
python database/scripts/render_ingest_artifact.py artifacts/<source>/<run-id> `
  --chunk-dir $env:TEMP/pruevia-ingest-chunks --max-bytes 400000
Get-ChildItem $env:TEMP/pruevia-ingest-chunks/*.sql | Sort-Object Name | ForEach-Object {
  npx.cmd supabase@latest db query --linked --file $_.FullName
}

python database/scripts/build_golden_catalog.py `
  --ruiz artifacts/ruiz-puebla/<run-id>/raw_records.jsonl `
  --chopo artifacts/chopo-puebla/<run-id>/raw_records.jsonl `
  --salud-digna $env:TEMP/pruevia-salud-digna/<source>/<run-id>/raw_records.jsonl `
  --output $env:TEMP/catalog_golden_v1.json
python database/scripts/publish_golden_catalog.py `
  --fixture $env:TEMP/catalog_golden_v1.json `
  --ruiz-artifact artifacts/ruiz-puebla/<run-id> `
  --chopo-artifact artifacts/chopo-puebla/<run-id> `
  --salud-digna-artifact $env:TEMP/pruevia-salud-digna/<source>/<run-id> `
  --chunk-dir $env:TEMP/pruevia-catalog-chunks --max-bytes 400000
Get-ChildItem $env:TEMP/pruevia-catalog-chunks/*.sql | Sort-Object Name | ForEach-Object {
  npx.cmd supabase@latest db query --linked --file $_.FullName
}
```

Los lotes sólo insertan o actualizan evidencia, catálogo y decisiones exactas; no
ejecutan `DROP`, `DELETE` ni `TRUNCATE`. Los labels no exactos quedan en
`ingest.normalization_runs` con estado `no_match` para revisión clínica.

## Gate A coverage report

El reporte es de solo lectura y resume cobertura comparable, precios vigentes,
coordenadas, frescura y corridas fallidas. Usa `PRUEVIA_DATABASE_URL` con un DSN
de servidor:

Ejecuta este comando desde la raÃ­z del repositorio:

```powershell
python database/scripts/report_gate_a.py
```

Los umbrales por defecto son 30 servicios compartidos, 10 con precio vigente
en dos proveedores y 90% de sucursales con coordenadas. Un resultado distinto
de cero significa que la viabilidad aún no está demostrada.

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
npx.cmd wrangler secret put ADMIN_USER_IDS
npx.cmd wrangler deploy
```

El deploy real requiere autenticación Cloudflare; el dry-run ya está verificado.

## Admin V1

El Admin autentica operadores con Supabase Auth. El Worker valida el JWT contra Supabase y comprueba el UUID en `ADMIN_USER_IDS`; nunca se compila un token administrativo en el frontend.

Desde `apps/admin/`:

```powershell
$env:VITE_API_URL = "https://<worker>.workers.dev"
$env:VITE_SUPABASE_URL = "https://<project-ref>.supabase.co"
$env:VITE_SUPABASE_ANON_KEY = "<public-anon-key>"
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
npm.cmd run build
npm.cmd run dev
```

El workflow `.github/workflows/ci.yml` repite estas verificaciones en cada push/PR. El deploy DEV del Worker es manual o corre al hacer push de `develop` cuando estén configurados los secrets de Cloudflare y Supabase.
