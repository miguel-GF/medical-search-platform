# Revisión79 retenida: tinción de Gram

**No aplicada ni encolada.** Consulta real del 22-oct-2026; transacción provisional
terminada en ROLLBACK e inspección independiente a las 12:50:15 UTC.

Ocho RAW públicos SD declaran TINCION DE GRAM. La [referencia primaria de
MedlinePlus](https://medlineplus.gov/lab-tests/gram-stain/) aclara el significado
y que la muestra depende del sitio/fluidos. No se transfirió una matriz de esa
referencia a los RAW que no la escriben. La propuesta conserva muestra y duración
desconocidas; no equivale a cultivo ni a otras tinciones.

La lectura fresca no encontró nombres activos relacionados con Gram/tinción/
stain en nombres principales y secundarios. El preparador comprobó colisiones
exactas de nombres, aliases y diccionario, ocho contextos y ledger no aplicado.
Esas comprobaciones no bastan para aprobar su comportamiento clínico.

## Resultado que impide incorporar

Se observaron 22 consultas mediante RPC público SQL y 22 en el core con proveedor,
con el concepto provisional y un alias completo exclusivo SD:

| Consulta | RPC público | Core con proveedor | Decisión |
| --- | --- | --- | --- |
| Tinción de Gram | Seleccionó el nuevo concepto | Seleccionó el nuevo concepto | Identidad nominal reconocida. |
| tincion de gram x2 | Lo seleccionó como resuelto | Lo seleccionó como resuelto | Pierde cantidad/serie. |
| sin tincion de gram | Lo seleccionó como resuelto | Lo seleccionó como resuelto | Pierde negación. |
| tincion KOH | No seleccionó el concepto | Seleccionó Gram como resuelto | Confunde métodos distintos en ese consumidor. |

Las demás variantes observadas —matrices explícitas, Gram modificado, Hucker,
fluorescente, otras tinciones, cultivo y serie de tres muestras— no seleccionaron
el concepto como resuelto. Eso no acredita protección universal. El resultado
del core no se presenta como respuesta HTTP anónima: son consumidores distintos.

**Cero cierres, aliases o conceptos persistentes.** Los ocho RAW siguen pendientes.
Un cliente nuevo confirmó que las funciones/permisos, relaciones, políticas,
triggers y 27 grupos de datos protegidos coincidían antes/después, sin sesión
marcada activa. Ledger `not_applied`. No se ejecutaron suites formales ni se
modificaron funciones compartidas. La evaluación combinada D-006 conserva su
plantilla y autorización pendiente: este hallazgo no modifica silenciosamente
su alcance ni autoriza ejecutarla.

## Evidencia conservada y recuperación

[Fixture candidata archivada](gram-candidate.json), SHA256
`d1ffb7295826d41e7a27bd48dbac69636cc44805a2d88ad3fe131e29f49d8b3f`.
Se trasladó sin cambiar bytes desde `database/data/reviewed-aliases-20261022-02.json`
para que una propuesta retenida no se confunda con fixtures aplicadas. No reenviar
sus scripts de observación: ya tienen marcador de envío único.

Directorio ignorado:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-79-gram-20261022/`.
Conserva RAW, investigación, definiciones, preparación, plantilla del observador,
SQL provisional, resultado completo, resumen y comparación protegida. El SQL
contenía sólo datos de esta revisión y tablas temporales, sin sustituciones de
funciones. No hay una activación persistente que deshacer.

Siguiente acción: incorporar estos casos a la revisión de conservación de serie,
negación y método por consumidor antes de volver a considerar la orden. Evitar
repetir el mismo ensayo sin cambio concreto de fuente o implementación. No
resolver el lote ampliando aliases o ignorando calificadores.

## Investigación independiente de establecimientos44

Una nueva lectura de los bindings DENUE contrastó las 234 parejas históricas de
domicilio del corte35: quedan **194 parejas /186 IDs DENUE sin vínculo**, dentro
de ese archivo de hipótesis. La comparación estricta de nombre idéntico y exterior
numerado, sin interiores o letras, no produjo candidatos. Esto no demuestra que
los 186 establecimientos sean inexistentes o imposibles de incorporar; tampoco
es un inventario de todos los lugares de Puebla.

Muchos pares comparten domicilio sin compartir identidad: centros de salud y
laboratorios privados, consultorios o almacenes. Mantenerlos separados.
Atzala3437657 y Naupan3415832 tienen domicilios numerados concordantes con CLUES,
pero nombres DENUE genéricos; quedan como siguiente investigación de denominación,
posibles duplicados y titularidad, sin vincularlos automáticamente a IMSS-Bienestar
ni a una marca genérica existente.

Recibos locales:
`collectors/artifacts/puebla-expansion-20261009/identity-review-44-research-20261022/`.
La primera consulta de sólo lectura usó un nombre de columna incorrecto y fue
rechazada; se corrigió según el renderer existente. Ningún intento escribió datos.

El último corte clínico aplicado sigue siendo [revisión78](../../CATALOG_REVIEW_78_20261022.md):
205 marcas,291 sedes,564 conceptos,3,343 favorables y4,045 pendientes. Este ensayo
no añade crecimiento comercial ni clínico a esos números.
