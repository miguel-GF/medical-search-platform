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
npx.cmd supabase@latest db query --linked --file supabase/tests/provider_claims_test.sql
```

### Acceso administrativo y MFA

Para desarrollo local, el Admin Vite usa `http://localhost:5173`. En la
configuración Auth del proyecto Supabase enlazado, `Site URL` y una URL de
redirección permitida deben apuntar exactamente a esa dirección. No uses
`localhost:3000` ni `https://127.0.0.1:3000`: una invitación con otra URL puede
terminar en un puerto sin servicio o expirar antes de llegar al panel.

El panel administrativo usa Supabase Auth con correo/contraseÃ±a y TOTP MFA
(Google Authenticator, Authy o 1Password). No se implementa un generador de
cÃ³digos propio. El backend exige que el JWT tenga `aal2` en todas las rutas
`/api/v1/admin/*`; ademÃ¡s, el usuario debe estar incluido en `ADMIN_USER_IDS`.

Para habilitarlo en el proyecto enlazado:

1. Crea o invita la cuenta administrativa en Supabase Auth.
2. Configura `ADMIN_USER_IDS` con los UUID de las cuentas permitidas.
3. Abre el enlace de invitaciÃ³n en el panel local; la primera pantalla permite
   definir la contraseÃ±a. DespuÃ©s muestra el QR de TOTP y exige confirmar un
   cÃ³digo de seis dÃ­gitos.
4. En accesos posteriores, el panel solicita el cÃ³digo TOTP antes de cargar
   datos o permitir decisiones.

La API no recibe ni almacena secretos TOTP: Supabase genera, guarda y verifica
el factor. La documentaciÃ³n de referencia es
<https://supabase.com/docs/guides/auth/auth-mfa/totp> y
<https://supabase.com/docs/guides/auth/auth-mfa>.

El QR de inscripcion contiene el secreto compartido del factor. Muestralo una
sola vez, escanealo unicamente en el autenticador del operador y no conserves
capturas ni lo envies por chat. Si el QR o la clave se expone, elimina el
factor y registralo de nuevo. Los retos y verificaciones MFA de Supabase
tambien tienen limites de frecuencia documentados. La clave manual queda
oculta por defecto en el panel para reducir exposiciones accidentales.

La cola de revisiÃ³n sÃ³lo conserva resultados `ambiguous` o `no_match` del
resolver, con candidatos y evidencia acotada. Aprobar exige seleccionar un
candidato producido por esa corrida; si un `no_match` de scraper no trae
candidatos, el panel permite buscar un servicio clÃ­nico activo y agregarlo como
candidato `manual` antes de aprobar. `no_match` exige motivo. Ambas decisiones
se ejecutan en una sola RPC transaccional y generan un evento en `audit.events`.
Las aprobaciones sin proveedor asociado no crean aliases globales; los aliases
se guardan únicamente cuando la revisión trae contexto de proveedor.

Rutas administrativas nuevas:

```text
GET  /api/v1/admin/normalization-queue
GET  /api/v1/admin/normalization/{run_id}
POST /api/v1/admin/normalization/{run_id}/candidates
POST /api/v1/admin/normalization/{run_id}/review
POST /api/v1/admin/alerts/{alert_id}/status
POST /api/v1/admin/quality-issues/{issue_id}/status
```

La Fase 12 usa estas rutas protegidas por el JWT del proveedor:

```text
GET  /api/v1/provider/claims
POST /api/v1/provider/claims
GET  /api/v1/provider/memberships
POST /api/v1/provider/memberships/{membership_id}/accept
POST /api/v1/provider/claims/{claim_id}/documents
POST /api/v1/provider/claims/{claim_id}/members
PATCH /api/v1/provider/locations/{location_id}/profile
GET  /api/v1/admin/provider-claims
POST /api/v1/admin/provider-claims/{claim_id}/review
POST /api/v1/admin/provider-claims/{claim_id}/revoke
GET  /api/v1/admin/provider-change-requests
POST /api/v1/admin/provider-change-requests/{request_id}/review
```

Los documentos se cargan en almacenamiento privado por el servicio de subida;
la API sólo recibe la referencia interna y su SHA-256. Las tablas `identity`
no están expuestas directamente por PostgREST. La aprobación de un reclamo
crea la relación legal y la membresía únicamente en el alcance solicitado.

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
npx.cmd wrangler secret put SUPABASE_PUBLISHABLE_KEY
npx.cmd wrangler secret put SUPABASE_SECRET_KEY
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

### OCR de ordenes

`POST /api/v1/resolve-image` recibe una imagen JPEG, PNG o WebP como data URL
(o base64 con `mime_type`). El Worker usa el servicio Python privado cuando
`OCR_SERVICE_URL` existe y, en su defecto, el binding opcional `AI`; ambos
transcriben literalmente y envian el texto al resolver de paquete. El flujo
de imagen aplica despues las reglas aprobadas de `api_resolve_ocr_package` y
conserva cada correccion junto al texto original. No guarda la imagen ni
permite que el modelo elija equivalencias clinicas: un perfil o panel sigue
marcandose como ambiguo. Si no existe
ningun extractor, responde `503` en lugar de fingir que hizo OCR.
Cuando el extractor Python devuelve confianza por linea, la respuesta incluye
`ocr.lines`, `ocr.review_required` y `ocr.low_confidence_lines` para que la UI
pida confirmacion de escritura dudosa antes de buscar.

```powershell
$img = [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\orden.jpg"))
curl.exe -X POST https://<worker>.workers.dev/api/v1/resolve-image `
  -H "content-type: application/json" `
  -d "{\"image\":\"data:image/jpeg;base64,$img\"}"
```

El modelo predeterminado es `@cf/moondream/moondream3.1-9B-A2B` y puede
cambiarse con `OCR_AI_MODEL`. Moondream se usa con la tarea `query`, salida
literal y `reasoning=false`; LLaVA sigue disponible como alternativa compatible
si se configura `@cf/llava-hf/llava-1.5-7b-hf`. Para desarrollo sin binding se
puede probar el contrato con los mocks de `apps/api/tests`; una respuesta `503`
es el comportamiento seguro esperado.

La alternativa local está en `apps/ocr-service/`. Es un servicio FastAPI
privado que usa RapidOCR + ONNX Runtime en CPU, rota la imagen en cuatro
orientaciones, conserva confianza por línea y elimina metadatos obvios del
formato. No persiste imágenes. Para usarlo desde el Worker, configura
`OCR_SERVICE_URL` y `OCR_SERVICE_TOKEN`; el servicio Python tendrá prioridad
sobre Workers AI. No se necesita comprar un dominio: una URL HTTPS privada del
proveedor es suficiente, y en desarrollo se usa `http://127.0.0.1:8000`.

Desde `apps/ocr-service/`:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
$env:OCR_SERVICE_TOKEN = "dev-secret"
python -m uvicorn pruevia_ocr_service.app:app --host 127.0.0.1 --port 8000
```

Para verificar la correccion OCR contra la base enlazada:

```powershell
cd database
npx.cmd supabase@latest db query --linked --file supabase/tests/ocr_correction_test.sql
npx.cmd supabase@latest db query --linked --file supabase/tests/resolution_confidence_guard_test.sql
```

La tabla `catalog.ocr_correction_rules` es pequena y revisada. Las variantes
observadas no se publican automaticamente: una nueva regla queda como
candidata hasta que un operador la aprueba. La respuesta siempre expone el
texto original y la sugerencia aplicada.

La variante humana `GlurOsO e INUliUA` se conserva como `Glucosa e Insulina`,
pero permanece auditable: la linea contiene dos estudios independientes. La
migracion 117 publica el ensayo generico serico/plasmatico con LOINC 20448-7;
no se confunde con `AC ANTI INSULINA (M)`, ni con insulina basal o de desafio.
La ausencia de una oferta comercial sigue siendo valida hasta verificar una
etiqueta real del proveedor.

El extractor tambien separa conjunciones explicitas (`e`/`y`) cuando forman
estudios independientes. La separación no decide equivalencias: conserva cada
token para que el resolver clínico lo confirme o se abstenga.

Workers AI incluye 10,000 Neurons diarios sin costo. En el plan Paid, el uso
que exceda esa asignación cuesta $0.011 por 1,000 Neurons; el consumo se debe
medir en el dashboard porque el número de tokens de imagen varía por foto.
Moondream publica como referencia $0.30 por millón de tokens de entrada y
$1.00 por millón de salida. El límite de salida de Pruevia es 384 tokens y la
respuesta normal suele ser mucho menor. La API aplica límites nativos
opcionales de Cloudflare por IP y ruta: el panel, OCR y búsqueda tienen
bindings separados en `apps/api/wrangler.toml`. En producción se deben
reservar namespaces únicos para esos bindings y revisar sus contadores en
Cloudflare; el límite de red es una barrera de costo, no un sustituto de Auth,
`ADMIN_USER_IDS` o `aal2`. La base también tiene un circuit-breaker de 10,000
revisiones abiertas para que una falla temporal del limiter no haga crecer la
cola sin límite.

Para producción configura obligatoriamente:

```powershell
$env:APP_ENV = "production"
$env:ALLOWED_ORIGIN = "https://admin.<tu-dominio>"
```

El Worker rechaza producción sin un origen HTTPS explícito. Las URLs de
Supabase y OCR también deben ser HTTPS; HTTP sólo se permite para loopback en
desarrollo.

## Admin V1

El Admin autentica operadores con Supabase Auth. El Worker valida el JWT contra Supabase y comprueba el UUID en `ADMIN_USER_IDS`; nunca se compila un token administrativo en el frontend.

Desde `apps/admin/`:

```powershell
$env:VITE_API_URL = "https://<worker>.workers.dev"
$env:VITE_SUPABASE_URL = "https://<project-ref>.supabase.co"
$env:VITE_SUPABASE_PUBLISHABLE_KEY = "<publishable-key>"
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
npm.cmd run build
npm.cmd run dev
```

El workflow `.github/workflows/ci.yml` repite estas verificaciones en cada push/PR. El deploy DEV del Worker es manual o corre al hacer push de `develop` cuando estén configurados los secrets de Cloudflare y Supabase.
