# Factor XIII en plasma y evidencia de muestra en títulos

**21-oct-2026, 05:02:40 UTC** (20-oct local). Supabase productivo
`ymtcmfgwuzdqtsbuvzqf`, operación local D-021/D-022. Sin migraciones,
despliegues, fuentes nuevas o suites formales.

## Resultado aplicado

Se incorporó una orden de Chopo17216: **Actividad del factor XIII de coagulación
en plasma**. El título original dice literalmente FACTOR XIII ACTIVIDAD EN PLASMA.
Se conserva `Coagulation factor XIII activity`, matriz Plasma y alcance de orden;
método, propiedad, escala, duración, unidades y LOINC no inferidos. Una decisión
y un concepto nuevos, sin ofertas o precios aprobados. La definición del factorVIII
anterior permanece íntegra.

Se reutilizó la [referencia primaria Labcorp086340](https://www.labcorp.com/tests/086340/factor-xiii-activity)
capturada con HTTP200 el20-oct y hash conservado. Su técnica/citrato no se
trasladan a Chopo. La evidencia de plasma es el título propio, no la referencia
externa. El RAW completo y hash se reconsultaron y quedaron intactos.

## Arreglo compatible del importador

La revisión68 había retenido la orden porque `source_attributes.specimen_code`
no admitía `provider_display_name` como guard de muestra. El mismo atributo ya
admitía muestra literal en títulos SD y campos de muestra. Se corrigió esa
limitación interna para títulos completos de laboratorio, con condiciones:

- Alias exclusivamente de proveedor y `service_type=lab_test`.
- Alias y título completo iguales tras normalización de acentos/puntuación.
- Construcción literal `en suero/plasma/orina/heces/saliva`, una sola matriz.
- Rechaza mezclas entre los marcadores de matriz admitidos y las formas de
  muestra excluidas en el helper; negación `sin/no/ni/excepto`.
- Conserva el guard del valor RAW íntegro y el atributo de muestra en la decisión.

No extrae estudios ni aprueba aliases automáticamente. El investigador sigue
decidiendo identidad por evidencia y el SQL aborta ante RAW cambiado, colisiones,
ámbito o conteos distintos. No se amplió a familia sanguínea ni a matrices nuevas.
La rama anterior y su contrato permanecen; no se alteraron funciones SQL,
permisos o políticas. Es una corrección compatible del transporte de evidencia
dentro de D-021, no una activación de propuestas clínicas retenidas por D-006.

Comparación de los **56 lotes existentes**, con sus pins: **112/112 salidas SQL
idénticas** entre renderer anterior y actual. Se analizó sintaxis Python.
Esto prueba compatibilidad de generación para esos lotes, no protección clínica
universal. No se añadieron ni ejecutaron suites formales.

## Observación clínica y aplicación

Un rollback observó24 consultas públicas y24 con alcance de Chopo. El canónico
se resolvió públicamente y en proveedor; el título de origen se resolvió en su
proveedor y puede seguir sin coincidencia pública. Otros factores romanos,
antígeno, inhibidor, subunidadA, solubilidad del coágulo, suero/orina, método,
perfil, negación y series no seleccionaron el concepto en los casos examinados.
Los vecinos que quedaron ambiguos no se contaron como estudios confirmados.

Se conservó el borrador aislado y su hash. La versión revisada sólo añadió
alcance/metadata de observación, sin cambiar conceptos o aliases. El ejecutor
completó su preview/commit/ledger y un observador independiente confirmó:

- Una decisión, con `specimen_code=plasma` y guard íntegro de `provider_display_name`.
- RAW, definición del factorVIII, políticas y demás contadores intactos.
- Atributos desconocidos conservados; resolvedor base con el mismo MD5
  `067b7a2fe0826ccaa48ece0a5dfd8d1d` del inventario previo.
- Cero ofertas nuevas. Identidad de orden no acredita cobertura comercial.

## Recarga local ordenada

El proceso anterior había importado el helper anterior. Antes de encolar el
nuevo lote se solicitó STOP entre operaciones y se observó PID1812 terminado,
estado `stopped`, sin revisión activa,56 resultados `already_applied` y lock
liberado. La cola conservó bytes/pins. Se retiró únicamente el marcador creado
por esta operación y se arrancó el ejecutor existente con el nuevo helper:
**PID17024**, confirmado vivo y después vigilando con el lote aplicado.
No hubo terminación forzada ni reinicio por timeout. API/PWA no se reiniciaron
ni se publicaron por esta operación.

## Estado y continuidad

**557 conceptos /3,328 registros favorables /4,060 pendientes /946no_match
históricos /182 marcas /266 ubicaciones /234ofertas /112migraciones**.
Cola57, pins anteriores conservados. El inventario completo de las04:48:32UTC
es previo a esta orden; no se reconstruyó la memoria por un solo registro.
CélulasLE, cortisol y propuestas de requisitos cortos siguen retenidos.
La propuesta aislada FTA-ABS del20-oct tiene pins de una versión anterior del
importador: requiere rebase y nueva comparación de compatibilidad antes de una
eventual activación, además de sus observaciones/aprobación clínica pendientes.

Fixture aplicada: `database/data/reviewed-aliases-20261021-01.json`.
SHA256: `ae3d3003b200e4c221beb7ec288f8e8fad24e0611bc33d32413626653eae76fa`.
Código: `database/scripts/reviewed_alias_batch.py`.
Evidencia ignorada: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-69-factor-xiii-title-20261021/`,
incluidos compatibilidad, fuentes, observaciones, recarga, recibos y
`applied-verified.json`. Siguiente acción: investigar otros títulos con atributos
explícitos; no convertir esta corrección en aprobación general de todos los pendientes.
