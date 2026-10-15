# Operación y comprobaciones

Tipo: procedimientos vigentes contrastados con scripts/configuración el 14-sep-2026.
No es un registro de ejecución ni una autorización de despliegue.

Última observación de datos: **14-oct-2026, 12:55 UTC**. Supabase productivo
enlazado: 474 conceptos, 234 ofertas, 4,636 pendientes en 845 grupos, 68 marcas,
152 ubicaciones y 112 migraciones. Cola local: 34 entradas explícitas por hash
verificadas; recuperación sólo lectura tras una caída DNS y vigilancia con
ejecución de lotes revisados restaurada a las 13:03 UTC, sin repetir escrituras.
Son un corte
fechado, no una garantía de que un puerto abierto demuestre salud futura.
Revisiones 34–37 e identidad 13 conservan rollback/commit/ledger y RAW;
50 consultas públicas y once internas de proveedor dieron el ID esperado.
Suites formales no ejecutadas en esta operación.
[Evidencia y límites](PUEBLA_LOCAL_OPERATION_20261009.md).

Actualización de cierre **14-oct, 13:15 UTC**: 475 conceptos, 4,635 pendientes
en 844 grupos, 69 marcas y 153 ubicaciones; ofertas 234 y migraciones 112
intactas. Cola 35 entradas con ledger/hash confirmado, worker único en vigilancia
con ejecución de lotes investigados. Memoria shadow v3 reconstruida, v2 intacta:
2,393 históricos reutilizables y ningún pendiente aprobado por esa herramienta.

## Entorno y arranque

Recuperación observada **15-oct-2026 04:27 UTC (14-oct local)**: el inicio de
sesión Windows arrancó Paciente y cola, pero API/Admin se detuvieron al heredar
Node 14.17.3. El launcher ahora selecciona Node >=22.12 ya instalado (en esta
máquina 24.19.0 de Laragon) y npm del mismo directorio; antepone ese runtime
sólo al PATH de los procesos hijo. No instala software ni cambia el PATH global.
Después del arranque real, API 8787, Admin 5173 y Paciente 8080 respondieron 200.
Una nueva invocación con PATH de perfil que seleccionaba Node14 eligió Node24,
conservó los tres puertos y el único worker existente. Recibo:
`collectors/artifacts/local-stack/startup-profile-recovery.json`. La selección
del runtime en un recibo no sustituye comprobar los endpoints después del arranque.

Desde la raíz, usar `git status --short` antes de modificar. Los comandos siguientes
asumen herramientas instaladas y dependencias disponibles. Para instalación Node
usar `npm.cmd ci` dentro de cada app con su lockfile. Las versiones de CI están en
[ci.yml](../.github/workflows/ci.yml); no actualizarlas como efecto secundario.

Preparar archivos locales desde [ENVIRONMENT](ENVIRONMENT.md) y ejemplos
versionados. No imprimir su contenido. Flutter recibe `--dart-define` y no carga
`.env` automáticamente. API/Admin local pueden usar Supabase remoto: confirmar el
proyecto antes de mutaciones, aunque la URL de la app sea localhost.

Ejecutar cada servicio en una terminal independiente:

| Directorio | Comando PowerShell | Comprobación |
| --- | --- | --- |
| `apps/api` | `npm.cmd run dev -- --ip 127.0.0.1` | `http://localhost:8787/health`; confirmar puerto real mostrado por Wrangler. |
| `apps/admin` | `npm.cmd run dev -- --host 127.0.0.1 --port 5173 --strictPort` | Abrir `http://localhost:5173`; Auth, MFA y carga de datos. |
| Raíz | `python scripts/run_pruevia_patient_local.py` | Compila Flutter debug y sirve en `http://localhost:8080`; abrir búsqueda. |

El script API local acepta `ALLOWED_ORIGINS` para los tres frontends
(`http://localhost:3000`, `http://localhost:5173` y `http://localhost:8080`).
En producción deben sustituirse por orígenes HTTPS exactos revisados. Para una
prueba aislada también puede usarse un único `ALLOWED_ORIGIN` compatible. Para
probar paciente desde 8080, detener la instancia API identificada y arrancarla
desde `apps/api` con el ejecutable instalado:

```powershell
npm.cmd exec --offline -- wrangler dev --ip 127.0.0.1 --var APP_ENV:development --var ALLOWED_ORIGIN:http://localhost:8080
```

En ese modo sólo Patient en 8080 tiene el origen permitido. Para probar varios
frontends simultáneamente, declarar la lista exacta en el archivo local de
variables; nunca sustituirla por un wildcard.

No reiniciar servicios a ciegas: identificar PID/puerto y proceso de este proyecto.
El servidor paciente local usa una compilación debug en artefactos ignorados,
CanvasKit y fuentes incluidos; no necesita DWDS ni descargar fuentes al abrir.
Conserva la restricción del cliente: HTTP sólo para loopback en debug. Sirve
únicamente archivos compilados, sin listados de directorios ni logs de consultas.
Un cambio de fuentes requiere volver a compilar antes de servirlo.
Cuando sea necesario iniciar un helper en segundo plano con `Start-Process`, usar
`-WindowStyle Hidden`; conservar cómo pararlo y verificar que quedó vivo.

### Arranque local al iniciar sesión en Windows

El [launcher local](../scripts/start_pruevia_local.py) reutiliza npm, Flutter,
Python y las configuraciones privadas existentes. Exige el proyecto enlazado
autorizado `ymtcmfgwuzdqtsbuvzqf`; no cambia flags ni políticas remotas.

```powershell
# Arrancar únicamente componentes ausentes.
python scripts/start_pruevia_local.py

# Instalar también PrueviaLocal.lnk en Inicio del usuario actual.
python scripts/start_pruevia_local.py --install-startup
```

El acceso usa `pythonw.exe`, sin ventanas, al iniciar sesión; no funciona antes
del login ni mientras el equipo está apagado. Se instaló el 11-oct-2026 y se
ejecutó el launcher con los cuatro componentes ya vivos. Otro inicio de sesión y
el arranque de componentes ausentes no se han observado todavía. `started`
significa proceso lanzado: comprobar después HTTP y PID/estado de la cola.
No es un watchdog ni inicia una sesión del agente para investigar términos.

Un puerto ocupado se conserva; identificar su dueño si la app no responde.
La cola no se duplica si su proceso existe y conserva `STOP`. Si falta el proceso
pero quedó `starting`, `scanning` o `stopped_error`, registra
`ledger_inspection_required` y requiere inspeccionar el ledger antes de reanudar.
Los recibos, logs y lock están en `collectors/artifacts/local-stack/`, ignorados.
Se usa Python porque la política local bloquea archivos PowerShell; esa política
no se desactivó. Para desinstalar sólo el arranque automático:

```powershell
$prueviaShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'PrueviaLocal.lnk'
Remove-Item -LiteralPath $prueviaShortcut
```

Esto no detiene procesos existentes; usar el marcador de cola siguiente y detener
sólo los PID identificados de las apps cuando corresponda.

### Cola local de revisiones investigadas

El [ejecutor](../database/scripts/run_local_review_queue.py) usa la base enlazada
y las credenciales privadas existentes del CLI. No requiere otra plataforma ni
un despliegue. La autorización de [D-021/D-022](DECISIONS.md) cubre los lotes
terminológicos investigados; la cola no otorga permisos de captura/publicación.

Desde la raíz, la cola local ignorada `collectors/artifacts/local-review-queue/queue.json`
declara `version: 1`, el `project_ref` confirmado, `authorization: "D-021/D-022"`
y `reviews`. Cada entrada fija `fixture`, `review_id` y `sha256` del archivo
UTF-8 completo. El agente encola sólo investigación terminada, con atribución,
fuentes y guards RAW; guardar un borrador en `database/data` no lo ejecuta.
Conservar las entradas anteriores al añadir otra y actualizar la cola de forma
atómica para que el observador no lea un JSON parcial.

```powershell
# Una lectura del ledger; no aplica lotes pendientes.
python database/scripts/run_local_review_queue.py --queue collectors/artifacts/local-review-queue/queue.json --project-ref ymtcmfgwuzdqtsbuvzqf

# Ejecución local autorizada, en terminal/proceso independiente.
python database/scripts/run_local_review_queue.py --queue collectors/artifacts/local-review-queue/queue.json --project-ref ymtcmfgwuzdqtsbuvzqf --execute-reviewed --watch --interval-seconds 300
```

Antes de escribir compara hash, destino, RAW requerido y ledger remoto. Un lote
completo y vigente se reconoce como `already_applied`; un ledger parcial o distinto
detiene el proceso. Para uno pendiente ejecuta el renderer existente: ensayo con
rollback, comprobación de que no quedó aplicado, commit acotado y lectura final.
El SQL conserva pacientes/OCR, políticas y ofertas fuera del lote. Cada revisión
admite hasta 200 filas y diez conceptos nuevos. El lock de archivo evita dos
ejecutores locales; el SQL conserva además su lock transaccional existente.

Un alias global puede declarar `additional_targets`: marca, conteo y guard RAW
independientes para cada contexto adicional. Se crea un solo alias, se auditan
todos los contextos y el límite de 200 filas incluye su suma. `source_attributes`
conserva `specimen_code` explícito de una entrada sólo con su guard `sample_type`.
También admite `{"specimen_family":"blood"}` cuando el texto exacto guardado
en `raw_study.Preparacion` contiene la palabra `sangre`; no permite convertir esa
familia en suero, plasma o sangre total.
Ese dato queda en la decisión de esa entrada y no completa la muestra de otro
proveedor ni acredita equivalencia de resultados.

Un concepto sin muestra debe declarar `specimen_code: null`,
`identity_scope: "analyte_order"`, `time_aspect: null` y una explicación en
`specimen_uncertainty`. Se reconoce la orden por analito; no se crean filas de
muestra ni `system`, método, propiedad, escala o mapping LOINC. Usar ese modo
sólo si el analito es inequívoco; conservar paneles, fracciones o analitos ambiguos
sin aprobar. Los conceptos con muestra explícita conservan su comportamiento.

El estado y recibos viven en `collectors/artifacts/local-review-queue/`, sin tokens
ni principal autorizante en los archivos. `status.json` incluye PID, última/próxima
lectura y revisión activa. Corroborar el PID/comando vivo; el archivo o lock solos
no acreditan ejecución. Un fallo escribe `stopped_error` y no reintenta por sí solo;
inspeccionar cola/recibos/ledger antes de reiniciar, especialmente tras perder una
respuesta de commit. No borrar evidencia para forzar un replay.

Para parar, usar Ctrl+C en esa terminal o crear este marcador local:

```powershell
New-Item -ItemType File -Path collectors/artifacts/local-review-queue/STOP -Force
```

El marcador impide la siguiente transacción al detectarse entre lotes/fases;
no cancela una solicitud SQL ya enviada. En reposo se comprueba al terminar el
intervalo de cinco minutos. Tras confirmar la parada y decidir reanudar, retirar
únicamente ese marcador y usar el mismo comando. El helper requiere el equipo
encendido y el proceso vivo; el launcher anterior lo recupera al iniciar sesión,
respetando paradas/errores, y no lo vuelve investigador autónomo.
El agente sigue preparando la evidencia de casos nuevos.
El cron remoto, la pausa pública y los collectors comerciales conservan sus gates.
Ejecuciones reales y alcance: [operación Puebla](PUEBLA_LOCAL_OPERATION_20261009.md).

## Revisión de identidades DENUE

El [renderer](../database/scripts/render_denue_identity_review.py) genera SQL
desde una corrida capturada y un fixture de IDs investigados; no ejecuta SQL.
Seguir el [comando y límites](../collectors/README.md#revisión-de-identidades-denue-ya-capturadas).
`identity_activity_codes` permite declarar por marca las clases diagnósticas
621511/621512 o de hospital general 622111/622112; el valor por defecto admite
sólo diagnóstico. No convierte un hospital en laboratorio: verifica la clase
exacta del RAW y conserva `location_type=hospital`, ubicación `pending` y marca
`verification_pending`. Mantiene hash, corrida licenciada y observación/auditoría.
Comprobar ledger sin vínculos previos, ejecutar primero rollback y volver a leer
ledger, después commit y recibo exacto. Tras una respuesta perdida, inspeccionar
ledger antes de reintentar; los guards abortan ante identidades ya enlazadas.
Las ocho sedes de la revisión 04 se comprobaron así el 11-oct: cero ofertas,
políticas y migraciones conservadas. Recuperar un vínculo candidato aplicado
requiere una revisión compensatoria acotada; no borrar su evidencia o replay.

Para añadir sedes bajo una marca existente, el fixture admite `existing_brand`
con exactamente `id`, `name`, `normalized_name`, `slug`, `website_url`, `status`
y `verification_status`. UUID y campos deben coincidir con la fila investigada;
el estado debe ser `active`. El renderer no actualiza ni duplica esa marca:
bloquea su fila durante la operación y compara al terminar su snapshot completo.
El recibo `brands` cuenta sólo marcas nuevas y, si hay reutilización, añade
`brands_reused`. Un enlace o colisión previos abortan, también en esta ruta.
Zacatlán se aplicó así el 11-oct: rollback sin vínculo y commit con un hospital
`pending`, cero marcas nuevas, una reutilizada íntegra y cero ofertas.
Evidencia: `identity-review-07/` bajo los artefactos de expansión Puebla.

## Comprobaciones por cambio

| Directorio | Comandos | Alcance de la evidencia |
| --- | --- | --- |
| `apps/api` | `npm.cmd run typecheck`; `npm.cmd test` | Tipos y comportamiento del Worker con sus pruebas. |
| `apps/admin` | `npm.cmd run typecheck`; `npm.cmd test`; `npm.cmd run build` | Tipos, pruebas y bundle; build requiere configuración válida de producción. |
| `apps/patient` | `flutter analyze`; `flutter test` | Análisis y comportamiento cubierto por tests. |
| `collectors` | `python -m pytest -q` | Parsers/pipeline/transportes cubiertos por fixtures. |
| raíz | `python -m pytest -q` | Suite Python de database, collectors, scanner y OCR; no ejecuta por sí sola contratos en Supabase. |
| `apps/ocr-service`, `apps/document-scanner` | `python -m pytest -q` en cada directorio | Servicio afectado con sus dependencias instaladas. |
| raíz | `git diff --check` | Errores de espacios del diff, no calidad funcional. |

Para build web y headers de paciente usar [su README](../apps/patient/README.md).
Para Admin usar `npm.cmd run render:headers` con los mismos orígenes revisados del
build. No publicar un bundle compilado con `api.example`; CI usa placeholders
únicamente para comprobar los controles de configuración.

Verificar interfaz manualmente cuando cambie presentación. Para documentación,
verificar enlaces, rutas, ejemplos, UTF-8 y escenarios de uso; no repetir todas las
pruebas funcionales si no se modificó código ni existe un hallazgo que lo justifique.

## Base enlazada y contratos SQL

Desde `database`, con CLI Supabase instalado/autenticado y enlace al proyecto
correcto. Verificar identidad del entorno sin revelar tokens antes de usarlo.

```powershell
supabase migration list --linked
supabase db push --dry-run
python scripts/check_migration_order.py
python scripts/check_runtime_schema.py
python scripts/run_sql_contracts.py --cli npx.cmd --package supabase@2.116.0 --test clinical_resolver_test.sql
```

El resultado esperado del runner es `PASS <archivo>: N/N` y salida exitosa. Sin
`--test` ejecuta todos los contratos. Admite `--cli` para un ejecutable instalado.
Los contratos usan transacciones con rollback, pero ejecutan SQL en la base
enlazada: comprobar entorno y dependencias antes de iniciarlos.

No acreditar una suite usando únicamente `supabase db query --file ...`: la API
puede devolver sólo el último result set. El runner conserva y valida todas las
aserciones, rechaza errores, resultados truncados, skips y planes incompletos.

Un dry-run no aplica migraciones. Un reset local sí destruye/recrea la base local;
no usarlo sobre datos valiosos sin autorización y recuperación definida. No ejecutar
`supabase init` como rutina en este repositorio ya configurado.

## Publicación y recuperación

[deploy-api-dev.yml](../.github/workflows/deploy-api-dev.yml) contiene un workflow
para `develop` protegida y entorno `development`. Su presencia no demuestra que
protecciones, secretos o ejecución estén configurados en GitHub.

[wrangler.toml](../apps/api/wrangler.toml) usa `pruevia-api-dev` y
`APP_ENV=production`: el sufijo del nombre no rebaja los controles. Verificar
cuenta, versión, origen y bindings del destino. `wrangler secret put` escribe
configuración remota; no usarlo como diagnóstico.

El Worker de producción tiene un trigger horario para el reproceso exacto de
normalización y llama a la RPC exclusiva
`api_admin_reprocess_exact_crawler_normalizations`. La migración está aplicada y
los contratos SQL completos pasaron. El flag permanece explícitamente en
`NORMALIZATION_REPROCESS_ENABLED=false`; no se ha ejecutado `apply`. Mantenerlo
así hasta revisar políticas de fuente, preview/canaria y monitoreo. La activación
también requiere actor auditable y un límite entre 1 y 200. Ninguna ruta usa
fuzzy/IA para aprobar equivalencias.
Para comprobar sintaxis y comportamiento aislado de esta migración sin tocar
Supabase: desde `database/`, ejecutar
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_exact_crawler_pg12_smoke.ps1`.
Usa PostgreSQL 12 de Laragon en una carpeta temporal y la elimina al terminar;
no sustituye `run_sql_contracts.py` sobre el esquema remoto real.
La primera activación requiere aprobación crítica, una ventana de monitoreo y
revisión de los logs de auditoría. Para recuperar, volver a `false` y publicar
la configuración corregida; no se borran decisiones ya auditadas.

Para cambios críticos usar la [propuesta y aprobación](DECISIONS.md#cambios-críticos-y-aprobación)
antes de ejecutarlos. Preparar recuperación según el recurso: versión previa del
Worker, corrección hacia delante de esquema y respaldo/restauración para datos.
No ejecutar una restauración que descarte escrituras sin identificar su alcance.

### Pausa temporal de producción (25-sep-2026)

La pausa aprobada mantiene el Worker `pruevia-landing` disponible, devuelve `503`
en todas las rutas del API con `crons = []`, y redirige los Workers Patient/Admin
al landing. Configuraciones temporales: `apps/api/wrangler.paused.production.toml`,
`apps/patient/wrangler.paused.production.toml` y
`apps/admin/wrangler.paused.production.toml`. La configuración normal queda
intacta. La PWA ya instalada puede conservar recursos locales; no puede consultar
el API.

No se debe reanudar sin una aprobación nueva. Para una recuperación aprobada,
Wrangler permite volver a versiones concretas mediante `wrangler rollback
<version-id> --name <worker> --yes`. Versiones funcionales anteriores: API
`c07c62a6-0c08-4226-a141-9f909e4445c8`, Patient
`303acaac-c5d0-4f39-a9ae-7e63ea1b5d31`, Admin
`4b16c144-bca9-4518-91c7-514036130181` y Landing
`d5cd3120-e60a-4a54-863e-2e0db4101e21`. Tras recuperar el API, verificar sus dos
triggers originales (`17 * * * *` y `17 14 1 * *`) además del estado HTTP; no
asumir que rollback restauró schedules. El cron mensual DENUE y el horario de
normalización deben seguir sin ejecutar sus acciones mientras sus gates estén
apagados. Evitar un deploy completo desde un árbol local con cambios pendientes.

Referencias de detalle: [seguridad](SECURITY_HARDENING_20260904.md),
[operación histórica](DEV_OPERATIONS.md), [errores](ERROR_HANDLING.md).
