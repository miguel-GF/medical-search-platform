# Auditoria de seguridad e integridad — 2026-09-01

Este corte revisa los cambios recientes de base de datos, API, OCR y panel
administrativo. Se probaron permisos efectivos en el proyecto Supabase enlazado
(`ymtcmfgwuzdqtsbuvzqf`) y se repitieron los contratos existentes.

## Hallazgos corregidos

### RPC administrativos expuestos por ACL heredadas

Las migraciones administrativas iniciales revocaban `PUBLIC`, pero no
revocaban explicitamente `anon` y `authenticated`. En PostgreSQL esos roles
podian conservar `EXECUTE` directo sobre once funciones `api_admin_*`.

La migracion `20260901090000_124_admin_rpc_privileges.sql` revoca esos permisos
de forma explicita y deja los 16 RPC administrativos (historicos y de claims)
solamente para `service_role`. El contrato
`database/supabase/tests/security_privileges_test.sql` evita que se reintroduzca
el acceso publico. SHA-256 de la migracion: `B8B3CB2B09417FBE106EE538CA532AB76862394346B251B2539B242AE743D83A`.

### OCR abierto cuando faltaba el secreto

El servicio OCR privado aceptaba solicitudes sin autenticacion si
`OCR_SERVICE_TOKEN` estaba vacio. Ahora el endpoint de recetas responde
`503 ocr_not_configured` hasta que exista el secreto; `/health` continua
publico para health checks. Se agrego una prueba de regresion.

### ACL por defecto en funciones internas

Aunque los esquemas internos ya negaban `USAGE`, varias funciones auxiliares
conservaban el `EXECUTE` heredado de `PUBLIC`. La migracion
`20260901100000_125_internal_function_privileges.sql` revoca esos permisos y
ajusta los privilegios por defecto para nuevos helpers. La prueba de seguridad
comprueba ambos roles del Data API. Las funciones propiedad del proveedor en
`gis`/`extensions` conservan ACL del sistema, pero `extensions` ya no tiene
`USAGE` para esos roles mediante la migracion 126. SHA-256: migracion 125
`A5094AE56BD419DAA154E1182B88E3F2D3CF2B0A5D288C9B91A795A3B7C3D425`; migracion
126 `B53D6B0C004A428D51204132A37A6D4D7E307E57A5CF39B0D5E020792EE361AF`.

### Redirecciones no confiables en colectores oficiales

Chopo, Ruiz, Salud Digna y DENUE usaban redirecciones automaticas. Eso podia
contactar un host externo antes de validar la respuesta y, en DENUE, exponer el
token incluido en la ruta. Ahora cada colector sigue como maximo cinco saltos
manualmente y valida esquema, host, puerto y ausencia de credenciales antes de
emitir la siguiente peticion. Se agregaron regresiones que prueban que un salto
externo se rechaza sin solicitar el destino.

## Controles revisados

- `anon` y `authenticated` no tienen `SELECT` directo sobre tablas internas de
  identidad o de ingesta.
- Los esquemas internos no conceden `USAGE` ni `CREATE` a los roles de Data
  API; el acceso se realiza mediante RPC controlados.
- Los RPC publicos son unicamente los de busqueda, detalle y resolucion que el
  producto necesita; los RPC de servicio, confianza, ingesta y administracion
  permanecen internos.
- El OCR valida token Bearer, MIME real, firma de imagen, tamano y pixeles; no
  persiste imagenes ni interpreta equivalencias clinicas.
- Los endpoints API mantienen validacion de UUID, dominios, coordenadas,
  tamano de payload y uso de JWT de Supabase.
- Los colectores oficiales validan cada salto de redireccion y DENUE redacta el
  token en errores de transporte.
- Las pruebas de claims conservan alcance marca/sucursal, evidencia, auditoria,
  revocacion reversible e idempotencia.

## Verificacion ejecutada

- OCR Python: **13/13**.
- Collectors Python: **74/74**.
- API TypeScript/Vitest: **37/37** y `tsc --noEmit`.
- Admin TypeScript/Vitest/build: **3/3**, tipado y build correctos.
- Worker Cloudflare: bundle dry-run correcto con `wrangler deploy --dry-run
  --temporary`, sin requerir una credencial de despliegue en CI.
- Supabase dry-run: remoto actualizado, sin migraciones pendientes.
- Contratos SQL remotos: **14 suites aprobadas**, incluyendo seguridad **12/12**
  y claims **53/53**. Todas usan `BEGIN ... ROLLBACK`.

## Riesgos aun fuera de este corte

- El Storage privado, antivirus/escaneo de documentos y validacion MIME de
  archivos legales aun deben conectarse antes de aceptar documentos reales.
- El OCR debe permanecer detras de HTTPS, red privada o firewall y contar con
  rate limiting del proveedor antes de exponerlo publicamente.
- Brevo/correo no se incorpora en este cambio; no se asume costo ni entrega de
  notificaciones hasta definir ese flujo.
- No se afirma una garantia de precision clinica del OCR o del resolver: los
  casos ambiguos deben seguir mostrando incertidumbre y pedir confirmacion.
