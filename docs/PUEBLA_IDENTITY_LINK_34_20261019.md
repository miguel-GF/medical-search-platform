# Tehuacán: vínculo DENUE a una sucursal existente

19-oct-2026. Herramientas locales contra la base productiva enlazada.
Lote 34 aplicado una sola vez y observado por cliente independiente a
**13:17:13 UTC**.

## Resultado

El registro DENUE **12271886**, Salud Digna Tehuacán, quedó vinculado a la
ubicación existente `627cb21a-a5f4-5884-a4c2-b9e5d9c7bd44`. Coinciden nombre de
sucursal, municipio, Calle 1 Poniente, exterior 129, colonia Centro y CP 75700.
La referencia CLUES PLSMP009896 del archivo de agosto confirma el domicilio;
no acredita operación actual ni titularidad.

No se creó una marca o ubicación nueva. Las 13 sedes de Salud Digna y todos
sus vínculos anteriores quedaron íntegros. Se conservó el identificador oficial
320, dirección, coordenadas, sitio, tipo `lab` y estado `active`. La marca sigue
`unverified`: actividad no equivale a identidad verificada. La clase DENUE
621511 sugiere `branch` en el importador; esa sugerencia se registró aparte y
no reemplazó el tipo existente.

Municipio Libre, DENUE 12271855, también tiene sede existente y sigue retenido:
exterior `547-6` en DENUE/CLUES frente a `#547 Int 6` en catálogo. No se convirtió
exterior en interior ni se duplicó la sede. La consulta fresca del sitio oficial
no fue accesible; la evidencia oficial previa mantiene su fecha original.

## Solución reutilizable y límites

El renderer local admite ahora `existing_location`, únicamente junto con una
marca existente coincidente y un registro DENUE por entrada. Exige el snapshot
JSON completo de la sede, lo bloquea con FOR SHARE y comprueba igualdad exacta
antes y después. Sólo añade el identificador, observación y auditoría; no permite
reasignar un binding, modificar una sede o convertir evidencia de identidad en
estudios, precios o disponibilidad.

Se compararon las 33 fixtures históricas sin esa opción: sus SQL de rollback y
commit conservaron exactamente los mismos bytes. La generación nueva conserva
por separado verificación de identidad, actividad de sede y tipo sugerido DENUE.
No hubo migración ni cambios de permisos, políticas, fuentes u ofertas.

## Comprobación realizada

- Procedencia aprobada DENUE, RAW remoto idéntico al local, clave y hashes fijados.
- Marca y sede existentes comprobadas mediante snapshots frescos.
- Rollback observado sin persistencia: 13 sedes y 14 bindings originales íntegros.
- Un único commit; después hay 15 bindings en la marca, uno de ellos el nuevo DENUE.
- Lectura independiente: una observación y una auditoría, toda la marca y las
  13 sedes sin cambios; RAW, políticas y contadores intactos.

No se ejecutaron suites formales. El total permaneció en 174 marcas y 258
ubicaciones; este lote es conciliación de identidad, no crecimiento comercial.

Fixture: `database/data/provider-identity-review-20261019-04.json`.
SHA256: `0fd2931681be0d511d303515893303f2b5b13ad0dac8dbc18cac09f4ed2174a7`.
Renderer SHA256: `25dcc0657eae7797b5a62e97e1fed05d64764f011951335b7e0e20993e8e2fa2`.
Evidencia: `collectors/artifacts/puebla-expansion-20261009/identity-review-34-research-20261019/`:
snapshot fresco, compatibilidad histórica, SQL y recibos, estado antes/después,
`applied-verified.json`. No repetir la aplicación; ante duda consultar ledger.

Siguiente acción: conservar Municipio Libre pendiente de aclaración del domicilio
y continuar buscando evidencia específica de estudios por proveedor y sucursal.
