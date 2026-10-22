# Revisión 77: fichas oficiales de colesterol y renina

## Resultado

El 22-oct-2026, 12:31 UTC (07:31 de Puebla), se consultaron dos fichas
públicas de SEMIN. Ambas respondieron HTTP 200. El campo antes omitido
`sinAcro` aporta abreviaturas, pero no resuelve la identificación pendiente.
**Cero equivalencias aprobadas, cero cierres y cero escrituras en la base.**

| Producto oficial | Información observada | Decisión y condición de revisión |
| --- | --- | --- |
| [5726, COLESTEROL](https://semindigital.com/semin-api/api/v3/catalog/informacion-catalogo/5726) | `sinAcro: (COL/ CHOL)`; suero; título genérico. El proveedor declara última actualización 12-oct-2026. | No asignar una fracción ni colesterol total a partir de esas abreviaturas. Revisar cuando una descripción del mismo producto explicite el componente medido. |
| [5563, Renina](https://semindigital.com/semin-api/api/v3/catalog/informacion-catalogo/5563) | `sinAcro: NA/`; plasma con EDTA congelado; descripción «Investigacion de la hipertension». Última actualización declarada 12-oct-2026. | No asignar el canónico existente «Actividad de renina»: la ficha no declara actividad frente a concentración. Revisar cuando el proveedor especifique esa medición. |

La fecha declarada por el proveedor no acredita que haya cambiado la definición
clínica. Las abreviaturas no se incorporaron como aliases. La evidencia pertenece
exclusivamente a esos productos SEMIN; no completa fichas de otros proveedores.
Tampoco acredita disponibilidad por sucursal o precios publicables.

## Evidencia y alcance

Directorio local ignorado:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-77-provider-details-20261021/`.

- Lectura SQL anterior: `read-receipt.json`, 22-oct 05:06:54 UTC; dos filas
  abiertas del proveedor y cuatro conceptos relacionados. Sólo lectura.
- Intento Python: `capture-official-v1/receipt.json`; el cliente devolvió
  `ValueError` sin obtener los detalles. No demuestra ausencia de fichas ni
  prohibición efectiva del sitio. El acceso mediante herramienta web tampoco
  obtuvo contenido; esos intentos no se usan como evidencia clínica.
- Hipótesis de transporte alternativa: conexión nativa Windows con validación
  de certificados, sin excepciones TLS. `robots.txt` respondió 200 y contiene
  `User-Agent: * / Allow: /`; SHA256
  `dde15d1a26288da7c53b4cdddf6614a54b776de38ddde74cf6ee9d0dc4cef629`.
- Capturas originales: `capture-native-v1/5726.body` (5,559 bytes), SHA256
  `65fd65985e06a8b21c84bd6165d0cf7fc8bf5db3230711c2b7bd9dcdd048851c`;
  `5563.body` (5,280 bytes), SHA256
  `909608df568d625d125315028f93ffa27099ae84f291b6b19d402ab380ab50f5`.
- `details-receipts.json` conserva URL, hora, estado y hashes. El script local
  admite sólo esos dos IDs; desactiva redirecciones y limita cada respuesta
  a 4 MiB, con timeouts de conexión y lectura. No consulta cuentas ni pacientes.

No se ejecutaron suites formales, migraciones ni propuestas D-006. Los contadores
globales no se reconsultaron: el último corte agregado sigue siendo el de
[identidad 43](PUEBLA_IDENTITY_43_AND_SOURCE_ROUTING_20261021.md).

## Siguiente acción

Conservar ambos casos pendientes sin repetir esta consulta mientras no exista
una hipótesis nueva o una revisión programada de fuente. Continuar con otros
grupos del inventario o identidades con evidencia suficiente. Este resultado
descarta que recuperar únicamente `sinAcro` permita cerrar estos dos casos.
La evaluación combinada del motor conserva su aprobación específica pendiente.
