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
npx.cmd supabase@latest db query --linked --file supabase/tests/resolver_benchmark_v2_test.sql
```

## Collectors

Desde `collectors/`:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_chopo --max-pages 4
python -m pruevia_collectors.cli_ruiz --max-records 200 --per-department 20
python -m pruevia_collectors.cli_salud_digna --location-slug puebla-municipio-libre
python -m pruevia_collectors.cli --condition laboratorio --latitude 19.0433 --longitude -98.2011 --radius-meters 5000
# Si la paginación de Chopo está limitada por el edge, usar el set revisado:
python -m pruevia_collectors.cli_chopo --product-url-file config/chopo_gate_a_urls.txt `
  --page-delay-seconds 1 --session-batch-size 5 --artifact-root artifacts/chopo-gate-a
```

El comando de DENUE carga `DENUE_API_TOKEN` desde `collectors/.env` (o desde una
variable del proceso/CI, que tiene prioridad). Los artefactos se validan antes de publicar:

```powershell
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id> --dry-run
```

Con un DSN de servidor, el artefacto se publica con `cli_publish` sin `--dry-run`.
Si sólo está disponible el proyecto enlazado de Supabase, los renderers generan
SQL idempotente en lotes (la API rechaza archivos grandes):

Desde la raíz del repositorio:

```powershell
python database/scripts/render_ingest_artifact.py collectors/artifacts/<source>/<run-id> `
  --chunk-dir $env:TEMP/pruevia-ingest-chunks --max-bytes 100000
Push-Location database/supabase
Get-ChildItem $env:TEMP/pruevia-ingest-chunks/*.sql | Sort-Object Name | ForEach-Object {
  npx.cmd supabase@latest db query --linked --file $_.FullName
}
Pop-Location

python database/scripts/build_golden_catalog.py `
  --ruiz collectors/artifacts/ruiz-full/ruiz-puebla/<run-id>/raw_records.jsonl `
  --chopo collectors/artifacts/chopo-puebla/<run-id>/raw_records.jsonl `
  --approved-mappings database/fixtures/gate_a_chopo_mappings.json `
  --baseline-fixture database/fixtures/catalog_golden_v1.json `
  --output database/fixtures/catalog_golden_gate_a.json
python database/scripts/publish_golden_catalog.py `
  --fixture database/fixtures/catalog_golden_gate_a.json `
  --ruiz-artifact collectors/artifacts/ruiz-full/ruiz-puebla/<run-id> `
  --chopo-artifact collectors/artifacts/chopo-puebla/<run-id> `
  --chunk-dir $env:TEMP/pruevia-catalog-chunks --max-bytes 100000
Push-Location database/supabase
Get-ChildItem $env:TEMP/pruevia-catalog-chunks/*.sql | Sort-Object Name | ForEach-Object {
  npx.cmd supabase@latest db query --linked --file $_.FullName
}
Pop-Location
```

Los lotes sólo insertan o actualizan evidencia, catálogo y decisiones exactas; no
ejecutan `DROP`, `DELETE` ni `TRUNCATE`. Los labels no exactos quedan en
`ingest.normalization_runs` con estado `no_match` para revisión clínica.

Para publicar una equivalencia clínica revisada contra un ítem canónico ya
existente (por ejemplo, BH o EGO), usa el fixture explícito; el renderer exige
que el `external_record_id`, el label observado y el precio sigan coincidiendo
con el artefacto descargado:

```powershell
python database/scripts/render_clinical_mappings.py `
  --fixture database/fixtures/clinical_provider_mappings_v1.json `
  --artifact chopo_puebla=collectors/artifacts/chopo-puebla/<run-id> `
  --artifact salud_digna_puebla=collectors/artifacts/salud-digna-puebla/<run-id> `
  --chunk-dir $env:TEMP/pruevia-clinical-mappings --max-bytes 100000
Push-Location database/supabase
Get-ChildItem $env:TEMP/pruevia-clinical-mappings/*.sql | Sort-Object Name | ForEach-Object {
  npx.cmd supabase@latest db query --linked --file $_.FullName
}
Pop-Location
```

Los nombres parecidos que no estén en el fixture no se publican: permanecen
en la cola de normalización para revisión humana. El artefacto DENUE sigue una
ruta separada y sirve como evidencia de identidad/ubicación para un reclamo,
no como prueba de que el proveedor ofrece un estudio o precio.

Para convertir una corrida DENUE amplia en candidatos revisables, clasifica y
deduplica por razon social + coordenadas:

```powershell
python database/scripts/classify_denue_candidates.py `
  collectors/artifacts/live/denue/<run-id> `
  --output database/fixtures/denue_candidates_puebla_v1.json
```

El resultado separa `candidates`, `review_queue` y exclusiones. Las
coincidencias de marca son unicamente una senal de identidad; los alias
abreviados (por ejemplo `L.R.`) requieren revision y no crean proveedores
canonicos automaticamente.

Para cruzar esos candidatos contra artefactos de sucursales ya recolectados:

```powershell
python database/scripts/match_denue_locations.py `
  --candidates database/fixtures/denue_candidates_puebla_v1.json `
  --provider-artifact chopo=collectors/artifacts/live/chopo-puebla/<run-id> `
  --provider-artifact ruiz=collectors/artifacts/live/ruiz-puebla/<run-id> `
  --provider-artifact salud_digna=collectors/artifacts/live/salud-digna-puebla/<run-id> `
  --output database/fixtures/denue_location_matches_puebla_v1.json
```

El matcher exige marca explÃ­cita, cercanÃ­a geogrÃ¡fica y coincidencia de
sucursal/cÃ³digo postal para un enlace automÃ¡tico. Si falta la fuente de
sucursales o el nombre es ambiguo, el resultado queda en `review_queue`.

Para descubrir proveedores pequeños desde sus páginas públicas sin un adapter
por marca:

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.cli_generic `
  --seed-url https://dominio-del-laboratorio.example/servicios `
  --max-pages 25 --max-depth 1 --artifact-root collectors/artifacts/generic
```

El collector genérico sólo sigue el host semilla, respeta `robots.txt` y
produce evidencia `candidate`. JSON-LD tiene prioridad sobre patrones visibles; un nombre o
precio extraído por patrón nunca se publica como equivalencia clínica sin
revisión.

Para aplicar esa misma regla a toda la cartera DENUE de Puebla, usa el
orquestador por host:

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.puebla_discovery `
  --fixture database/fixtures/denue_candidates_puebla_v1.json `
  --artifact-root collectors/artifacts/puebla-generic `
  --max-providers 100 --max-pages 3 --max-depth 1
```

El orquestador conserva la población DENUE original en el manifiesto y
deduplica por host las filas clasificadas seleccionadas (por ejemplo, 213
candidatos directos derivados de 489 registros RAW). También conserva los IDs
DENUE para reconciliación posterior y deja un manifiesto de cobertura. La
salida sigue siendo RAW/candidate; para publicar un servicio se requiere
evidencia, normalización clínica y revisión.

Un sitio accesible sin evidencia extraíble aparece como `empty`; un fallo de
DNS, HTTP, redirección o robots aparece como `failed`/`quarantined`. Ninguno
de esos estados debe convertirse en un precio o una equivalencia manual.

### Retry controlado y publicación de coincidencias genéricas

El retry de Puebla consume el manifiesto anterior y sólo reintenta páginas
vacías o errores transitorios (`timeout`, conexión y HTTP 408/425/429/5xx):

```powershell
python -m pruevia_collectors.puebla_retry `
  --manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --artifact-root collectors/artifacts/puebla-generic-retry `
  --max-pages 2 --max-depth 1
```

Robots, DNS no resoluble y HTTP permanente no se reintentan automáticamente.
La salida es un manifiesto separado para conservar la auditoría temporal.

Las etiquetas genéricas no se publican por similitud. El fixture revisado
`database/fixtures/generic_provider_mappings_puebla_v1.json` contiene sólo
cuatro coincidencias exactas. El renderer asociado enlaza cada sitio con sus
filas DENUE, crea sedes con procedencia y ofertas `requires_quote` sin precio.

Para separar cobertura descubierta de cobertura realmente publicada:

```powershell
python database/scripts/report_generic_coverage.py `
  --manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --mapping-fixture database/fixtures/generic_provider_mappings_puebla_v1.json `
  --retry-manifest collectors/artifacts/puebla-generic-retry/puebla_generic_retry_manifest.json `
  --denue-source-records 489
```

### Revision de labels genericos pendientes

La corrida hardened descubrio 48 ofertas: cuatro tienen mapping exacto
publicado y 44 siguen pendientes. La cola versionada vive en
`database/fixtures/generic_provider_review_puebla_v1.json`; no contiene
aprobaciones. Cada label queda en una de estas clases: `reject_noise`,
`category_not_service`, `ambiguous_modality`, `ambiguous_panel`,
`new_concept_candidate` o `possible_alias`.

El builder exige una decision para cada registro no mapeado y falla cerrado si
aparece un label nuevo, desaparece evidencia esperada o una decision intenta
publicar. El reporte conserva el id externo, proveedor, host, URL y metodo de
evidencia para que la revision clinica sea reproducible:

```powershell
python database/scripts/build_generic_review.py `
  --artifact-root collectors/artifacts/puebla-generic-depth1-hardened `
  --manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --mapping-fixture database/fixtures/generic_provider_mappings_puebla_v1.json `
  --review-fixture database/fixtures/generic_provider_review_puebla_v1.json `
  --output collectors/artifacts/generic-next/generic_review_report.json
```

En esta revision quedan 19 candidatos de concepto nuevo, ocho modalidades
ambiguas, cuatro paneles ambiguos, ocho categorias/no-servicios, cuatro textos
de ruido y un posible alias. Ninguno se publica sin composicion o validacion
clinica; en particular, no se convierte una etiqueta amplia en una oferta
canonica mediante fuzzy matching.

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

## Resolucion de paquetes (Fase 10)

El endpoint acepta texto de receta o entradas explicitas. La respuesta separa
la resolucion clinica de la cobertura comercial y nunca asume que un panel
ambiguo es un estudio concreto:

```powershell
curl.exe -X POST https://<worker>.workers.dev/api/v1/resolve-batch `
  -H "content-type: application/json" `
  -d '{"text":"1: B H\n2: Q S completa\n3: EGO\n4: Perfil toroideo"}'

curl.exe -X POST https://<worker>.workers.dev/api/v1/resolve-batch `
  -H "content-type: application/json" `
  -d '{"items":["BH","audiometria","ultrasonido renal"],"objective":"all_in_one"}'
```

Los objetivos disponibles son `all_in_one` (predeterminado), `lowest_cost`,
`nearest` y `balanced`. Las soluciones parciales incluyen
`missing_item_indexes`; un precio ausente se marca `requires_quote`.

La prueba remota del RPC se ejecuta desde `database/`:

```powershell
npx.cmd supabase@latest db query --linked --file supabase/tests/resolver_package_test.sql
```

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
