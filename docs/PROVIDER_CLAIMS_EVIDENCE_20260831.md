# Evidencia de claims de proveedores — 2026-08-31

Este corte documenta la implementación y la verificación del flujo empresa/marca,
sucursal y representantes. La fuente canónica sigue siendo el catálogo de
proveedores; un claim sólo puede crear una relación jurídica/membresía después
de revisión administrativa y evidencia documental referenciada.

Este documento conserva el corte del 31 de agosto. La corrección posterior de
ACL de RPC administrativos y su regresión de seguridad están documentadas en
`docs/SECURITY_AUDIT_20260901.md` y en la migración 124.

## Cambios aplicados

- `118_provider_claims`: claims, verificaciones, documentos referenciados,
  membresías y RPC base.
- `119_provider_claims_verification_fix`: revisión de claim y verificación
  determinista.
- `120_provider_claims_scope_guards`: invariantes de alcance marca/sucursal,
  claves de objetos privados y protección contra mezcla de scopes.
- `121_provider_profile_change_requests`: cambios de perfil de sucursal por
  propuesta, revisión y observación con provenance.
- `122_provider_lifecycle_hardening`: aprobación condicionada a evidencia,
  aceptación de invitaciones, revocación reversible, límites de metadata y
  cierre de relaciones/membresías sin borrar historia.
- `123_provider_rpc_privileges`: ACL explícitas; autoservicio sólo para
  `authenticated` y funciones administrativas sólo para `service_role`.

Los documentos no se almacenan en las tablas de identidad: se conserva una
referencia de objeto privada, SHA-256, tipo y metadata acotada. El backend de
almacenamiento/escaneo queda fuera de este corte.

## Verificación remota

Proyecto Supabase enlazado: `ymtcmfgwuzdqtsbuvzqf`.

Comandos ejecutados desde `database/supabase`:

```text
npx.cmd supabase@latest db push --linked --skip-vault --yes
npx.cmd supabase@latest db push --linked --dry-run --skip-vault
npx.cmd supabase@latest migration list --linked
npx.cmd supabase@latest db query --linked --file supabase/tests/provider_claims_test.sql
```

Resultados observados:

- dry-run: `Remote database is up to date`;
- migraciones 118–123 presentes local y remotamente;
- `provider_claims_test.sql`: **53/53**;
- `database_v1_invariants.sql`: **10/10**;
- `database_v1_test.sql`: **15/15**;
- `public_api_test.sql`: **21/21**;
- `gate_a_test.sql`: **10/10**;
- `clinical_resolver_test.sql`: **18/18**;
- `loinc_integration_test.sql`: **16/16**;
- `ocr_correction_test.sql`: **21/21**;
- `resolution_confidence_guard_test.sql`: **12/12**;
- `resolver_benchmark_test.sql`: **10/10**;
- `resolver_benchmark_v2_test.sql`: **10/10**;
- `resolver_package_test.sql`: **10/10**;
- `resolver_unification_test.sql`: **25/25**;
- API TypeScript: `tsc --noEmit` sin errores;
- API Vitest: **35/35**.

Las pruebas SQL se ejecutan dentro de `BEGIN … ROLLBACK`; el estado operativo
posterior queda limpio (`claim_rows = 0`, `membership_rows = 0`,
`change_request_rows = 0`).

## Controles de seguridad e integridad comprobados

- `anon` no puede ejecutar RPC de proveedor ni de administración.
- `authenticated` puede ejecutar sólo autoservicio; no puede ejecutar RPC de
  administración.
- `service_role` conserva el acceso de backend a administración.
- `anon` y `authenticated` no tienen `SELECT` directo sobre
  `identity.provider_claims`.
- Un claim de marca no puede incluir sucursal; un claim de sucursal debe
  pertenecer a la marca indicada.
- No se puede aprobar sin al menos un documento pendiente/aceptado.
- Rechazo y revocación exigen motivo auditable.
- Las invitaciones sólo puede aceptarlas el usuario invitado.
- Revocar cierra relaciones/membresías y conserva observaciones, eventos y
  documentos históricos.
- Las claves de documentos deben quedar bajo el prefijo del claim y la
  metadata tiene límite de 8 KiB.
- Los cambios de perfil no pueden modificar directamente el estado canónico;
  requieren revisión y registran provenance.

## Hashes SHA-256 de migraciones del corte

| Migración | SHA-256 |
|---|---|
| 118 | `E69E5EF6FFCB066D6590140C2ED1C72EAEA970BE75EE75CD4F066B199D888D36` |
| 119 | `7DBC38BE73CE71D6C2772A223A6C9EAD28B01CA28A7EF1BC9402981F2B42BCA7` |
| 120 | `85694B2D187E710DCD8107C85620E6BDB24A3ACEFE0E264227E84B9AEA16B1C2` |
| 121 | `99ED608E15F40E8D98D0B59DDDFC19797E642638DC55DEE44EBDA64712C7FF5A` |
| 122 | `F398789BE5E9C08E7A195E50D0C73C8A58B64CDC4FD52A49BEF750E27D831B32` |
| 123 | `E931FE08D5C6822C312D0DE7CC4A7F904ADB83D5359962053136838CE6D8D8C5` |

## Pendientes explícitos

Este corte no afirma verificación externa automática. Aún faltan el flujo de
subida a Storage privado, antivirus/validación MIME, correo de invitación,
verificación de dominio/teléfono o visita física y las pantallas Flutter de
proveedor/admin. Esos componentes deben consumir estos RPC sin saltarse la
revisión ni escribir tablas internas directamente.
