# Operación y comprobaciones

Tipo: procedimientos vigentes contrastados con scripts/configuración el 14-sep-2026.
No es un registro de ejecución ni una autorización de despliegue.

## Entorno y arranque

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
| `apps/patient` | `flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8787` | Abrir `http://localhost:8080` y probar búsqueda. |

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
Cuando sea necesario iniciar un helper en segundo plano con `Start-Process`, usar
`-WindowStyle Hidden`; conservar cómo pararlo y verificar que quedó vivo.

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

El Worker tiene un trigger horario para el reproceso seguro de normalización,
pero permanece inactivo salvo que se configure explícitamente
`NORMALIZATION_REPROCESS_ENABLED=true`,
`NORMALIZATION_REPROCESS_ADMIN_USER_ID` y un límite entre 1 y 200. Ese proceso
sólo llama al RPC de coincidencias exactas/aliases aprobados; no usa fuzzy ni IA.
La primera activación requiere aprobación crítica, una ventana de monitoreo y
revisión de los logs de auditoría. Para recuperar, volver a `false` y publicar
la configuración corregida; no se borran decisiones ya auditadas.

Para cambios críticos usar la [propuesta y aprobación](DECISIONS.md#cambios-críticos-y-aprobación)
antes de ejecutarlos. Preparar recuperación según el recurso: versión previa del
Worker, corrección hacia delante de esquema y respaldo/restauración para datos.
No ejecutar una restauración que descarte escrituras sin identificar su alcance.

Referencias de detalle: [seguridad](SECURITY_HARDENING_20260904.md),
[operación histórica](DEV_OPERATIONS.md), [errores](ERROR_HANDLING.md).
