# Prueba interna de Admin y primer lote Puebla

## Estado de esta entrega

- El API cierra documentos por defecto (`PROVIDER_DOCUMENTS_ENABLED` debe ser
  exactamente `true` para habilitar sus rutas). Admin/catalogo conserva su contrato.
- La migracion `20260908100000_internal_document_freeze.sql` bloquea acceso
  anonimo/autenticado al bucket `provider-claims` y escrituras documentales incluso
  por RPC de servidor. Reabrir requiere otra migracion revisada, no solo una variable.
- Auth local tiene signup deshabilitado: operadores por invitacion. Esto NO cambia
  los ajustes del proyecto remoto; deben verificarse antes de la prueba interna.
- Se corrigio la comprobacion de MFA: usa `factors` de `/auth/v1/user`, igual que
  `listFactors()` del SDK instalado. No consulta una ruta PostgREST inexistente.
  Solo acepta AAL2 validado por Auth y un factor TOTP verificado vigente; no usa
  `user_metadata` como prueba. Referencia: [Supabase listFactors](https://supabase.com/docs/reference/javascript/auth-mfa-listfactors).

## Bloqueos comprobados el 8 de septiembre de 2026

- Supabase DEV enlazado: `ymtcmfgwuzdqtsbuvzqf`. Se encontraron 76 migraciones
  aplicadas de las 91 existentes; con el cierre interno nuevo quedan 16 pendientes.
- `wrangler whoami`: no hay sesion autenticada de Cloudflare. No se uso una cuenta
  temporal ni se hizo un despliegue parcial de la base.
- Faltan `apps/api/.dev.vars` y `apps/admin/.env.local`; solo hay plantillas.
  No se ha probado un login real con MFA ni se ha verificado respaldo/restauracion.
- DENUE/LOINC permanecen fuera de este lote. No se ha confirmado revocacion de
  sus credenciales anteriores: no reutilizarlas; rotarlas en sus respectivos servicios.

## Arranque local, una vez resueltos los bloqueos

1. Completar `apps/api/.dev.vars` desde su plantilla: URL DEV, clave publica,
   clave secreta exclusivamente de servidor y UUID de tu usuario en `ADMIN_USER_IDS`.
   Conservar documentos deshabilitados. No pegar claves ni codigos MFA en el chat.
2. Completar `apps/admin/.env.local` desde `.env.example`: API
   `http://localhost:8787`, misma URL Supabase y solamente clave publica.
3. En Auth remoto: deshabilitar signup publico, conservar acceso por invitacion,
   confirmar TOTP habilitado y redireccion local exacta `http://localhost:5173`.
   No deshabilitar el inicio de sesion de usuarios existentes.
4. En dos terminales, ejecutar desde cada carpeta:

```powershell
# apps/api
npm.cmd run dev -- --ip 127.0.0.1
```

```powershell
# apps/admin
npm.cmd run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Abrir `http://localhost:5173`. Las credenciales de servidor nunca van en `VITE_*`.

## Paso remoto coordinado (todavia no ejecutado)

1. Autenticar Cloudflare en `apps/api` con `npx.cmd wrangler login`; confirmar
   que la cuenta corresponde al Worker existente. No usar `--temporary`.
2. Confirmar respaldo reciente y procedimiento de restauracion probado de DEV.
   Verificar tambien que esten disponibles los secretos/origen del Worker antes de
   empezar la ventana de mantenimiento; conservar la version anterior para recuperacion.
3. Ejecutar el gate de orden y `supabase db push --dry-run`. Aplicar las 16
   pendientes en orden durante mantenimiento; no seleccionar solo algunas.
4. Ejecutar `check_runtime_schema.py` y el contrato del cierre interno. Solo con
   ambos correctos desplegar el Worker, comprobar salud, busqueda y permisos y
   levantar mantenimiento. No reabrir permisos directos para resolver un fallo.
5. Ante fallo mantener mantenimiento y corregir hacia delante; restaurar datos
   solo mediante el procedimiento de recuperacion confirmado, evitando perdida
   de escrituras. No declarar completada esta entrega por pasar pruebas con mocks.

Ensayo del cierre SQL sin persistir cambios (desde `database`, antes del despliegue):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test_pending_security.ps1 -Test internal_document_freeze_test.sql -InternalRelease
```

Los contratos historicos de documentos/scanner prueban el flujo diferido levantando
el cierre solo dentro de su transaccion con rollback. El contrato
`internal_document_freeze_test.sql` prueba el estado cerrado de esta entrega.

## Lote preparado, no publicado

Fuente local: `collectors/artifacts/puebla-generic-depth1-hardened/` y su
`puebla_generic_discovery_manifest.json`. Sus diez corridas exitosas contienen
54 registros RAW: 48 ofertas sin precio y 6 ubicaciones. No equivalen a diez
proveedores nuevos confirmados: falta comparar los identificadores con DEV.
Las diez corridas pasaron la validacion de integridad del publicador (hashes,
conteos y referencias de observaciones), sin conexion de escritura a la base.

| Fuente | Registros RAW |
| --- | ---: |
| clinicadediagnostico.com | 4 |
| exakta.mx | 1 |
| familylabs.com.mx | 14 |
| labopat.mx | 1 |
| laboratorioasesores.com | 3 |
| labxonaca.com | 5 |
| lafer.mx | 15 |
| riex.com.mx | 1 |
| semindigital.com | 6 |
| verkenlab.com | 4 |

Antes de publicar: comprobar vigencia/fuente/ubicacion, comparar run_id y claves
estables con la base, revisar equivalencias clinicas y dejar ambiguas pendientes.
Importar evidencia en ingest no es aprobar catalogo. No asignar precios a este lote.
Registrar IDs creados y modificaciones previas en una transaccion revisada para
reversion acotada; reprocesar y comprobar que no aumenten duplicados antes de abrir
otro lote. No ejecutar una publicacion amplia de todas las fuentes.

## Aceptacion final pendiente

Probar con sesiones reales: sin token o token manipulado rechazado; AAL1 rechazado;
AAL2 de no administrador rechazado; tu AAL2 puede consultar y resolver una revision;
revocar el factor impide nuevas operaciones; documentos cerrados en API y Storage.
Finalmente publicar solo el lote aprobado y comprobarlo en Admin y busqueda.
