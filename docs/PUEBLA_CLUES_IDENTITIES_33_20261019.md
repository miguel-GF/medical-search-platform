# Puebla: 35 ubicaciones candidatas y revisión del directorio CLUES

Fecha: 19-oct-2026. Herramientas locales contra la base productiva enlazada.
Lote de identidad 33 aplicado una sola vez; lectura independiente final
**12:59:51 UTC**.

## Resultado

Se añadieron **35 ubicaciones candidatas**, cada una con nombre específico y
domicilio concordante entre DENUE y el archivo oficial CLUES de agosto de 2026.
Incluyen centros públicos, consultorios, clínicas, sanatorios y dos laboratorios:
Bioclínicos Laboratorio en Amozoc y Laboratorio Clínico Pasteur en Tecamachalco.
Hay unidades en Puebla y municipios como Coxcatlán, Cuautlancingo, Atlixco,
Tepeaca, Tehuacán, San Martín Texmelucan, Acatzingo y Venustiano Carranza.

Son candidatas independientes: marcas con `verification_pending`, ubicaciones
`pending` y sitio web NULL. No se atribuyó afiliación actual, titularidad,
sucesión institucional, estudios, precios, horarios ni disponibilidad.
Las clases y tipos originales DENUE se conservaron, incluso cuando un nombre
comercial contiene hospital o sanatorio y la clase indica consultorio.

Dos pares quedaron fuera: Salud Digna Tehuacán (DENUE 12271886) y Salud Digna
Puebla Municipio Libre (12271855). Requieren reconciliar sucursal y marca ya
registrada; no se crearon marcas independientes para esos nombres.

| Estado productivo observado | Total |
| --- | ---: |
| Instituciones o marcas | 174 |
| Ubicaciones, incluidas candidatas pendientes | 258 |
| Conceptos activos distintos | 551 |
| Registros de crawler resueltos favorablemente, corte 12:54:44 UTC | 3,315 |
| Registros de crawler pendientes | 4,073 |
| Ofertas activas | 234 |
| Migraciones | 112 |

Los registros del crawler repiten estudios por contexto de proveedor. Los
3,315 resueltos no son 3,315 estudios distintos. Las 258 ubicaciones tampoco
acreditan 258 sucursales con estudios disponibles. Este lote amplía identidades;
no cierra equivalencias clínicas ni aumenta ofertas.

## Fuente y límites temporales

El [índice oficial CLUES](https://gobi.salud.gob.mx/Bases_Clues.html) enlaza el
[archivo de agosto de 2026](https://gobi.salud.gob.mx/historico_clues/ESTABLECIMIENTO_SALUD_202608.xlsx?v=1.1).
Descarga del 19-oct: HTTP 200, TLS válido, 26,524,116 bytes. SHA256:
`5a1cfbe7062b41d9e51249aa4b5fc8a1e623e935882e97fb5f0aac797165c95b`.
El libro declara la hoja `CLUES_202608`; sus fechas internas son de septiembre.
No se interpretaron enlaces comentados de meses posteriores como archivos publicados.

El recorrido local encontró 64,450 filas nacionales únicas por CLUES y 3,779
de Puebla: 2,218 con EN OPERACION y 1,561 con FUERA DE OPERACION en ese corte.
**Esos estados mensuales no prueban operación actual al 19 de octubre.**

Se localizaron también las 19 claves históricas retenidas por discrepancias de
domicilio y las cinco usadas como referencia en las revisiones 31–32. Las 24
figuran fuera de operación por cambio de institución. Eso describe las claves;
no acredita cierre físico. No hubo referencias literales a esas 24 claves en
los dos campos administrativos examinados de las 3,779 filas. No se aprobó
sucesión ni se corrigieron los domicilios que siguen siendo incompatibles.

No se encontró licencia específica suficiente para aprobar una ingesta CLUES
recurrente. Esta operación conserva los datos de identidad de DENUE, cuya fuente
ya está aprobada, y cita CLUES como referencia de investigación. No se registró
una nueva fuente, cambió política de uso ni programó captura.

## Herramienta local reutilizable

`database/scripts/extract_clues_registry.py` extrae un archivo local con SHA256
obligatorio. Resuelve la hoja declarada por sus relaciones del libro; conserva
campos literales y coordenada de fila. Rechaza claves duplicadas, fórmulas,
archivos o XML no admitidos y tamaños superiores a los límites declarados.
Los filtros de entidad y claves afectan la salida; todo el libro se recorre
para comprobar unicidad. El resultado se escribe en un directorio nuevo bajo
`collectors/artifacts`, sin sobrescribir entrada o evidencia anterior.

No hace peticiones de red ni SQL. Omite contactos y comentarios personales;
de los campos administrativos conserva sólo IDs CLUES y coordenadas de celda.
Una referencia a otra clave no aprueba una sucesión.

Se ejecutó con el archivo real para 24 claves históricas y después para 37
candidatos nuevos, sin claves solicitadas ausentes. Los 35 pares incorporados
tienen igualdad de códigos municipio/localidad, CP, tipo de vía, calle y
exterior completo; un sin número debe estar expresamente declarado. El nombre
específico se revisó conservando variantes, sin aceptar fuzzy como aprobación.

## Comprobación y evidencia

Antes de escribir se comprobaron hashes, proyecto, procedencia, RAW remoto,
ausencia de bindings y colisiones, políticas y contadores. El rollback observado
no dejó identidades persistentes. Después del único commit, un cliente distinto
leyó las 35 marcas, ubicaciones, auditorías y observaciones aceptadas. Direcciones,
coordenadas, tipos y RAW se conservaron; políticas, fuentes, ofertas y migraciones
no cambiaron. No se ejecutaron suites formales.

Fixture aplicada: `database/data/provider-identity-review-20261019-03.json`.
SHA256: `d06201a386fb4729a75edaffd7ca5dbba00d03dd4e0812adfa42b48fd2bba7d1`.
Revisión: `pruevia:provider-identity-review:20261019:03`.

Evidencia local ignorada:

- `collectors/artifacts/puebla-expansion-20261009/identity-review-33/`:
  pares originales, retenidos, prueba de fuente, rollback, intento único,
  recibo de commit y `applied-verified.json`.
- `collectors/artifacts/clues-source-discovery-20261019/`: descarga y observación
  completa de Puebla, incluidas claves históricas y límites de sucesión.
- `collectors/artifacts/clues-reviewed-targets-20261019/` y
  `clues-new-identity-targets-20261019/`: salidas reales y manifiestos del extractor.
- `collectors/artifacts/catalog-status-20261019/counts-observed.json`:
  agregados de resolución, sin consultar texto de pacientes.

La conciliación posterior confirmó que ambos Salud Digna ya tienen sede en la
marca existente. Tehuacán coincide con Calle 1 Poniente 129 y es candidato a
vincular DENUE sin crear una sede. Municipio Libre conserva exterior 547-6 frente
a catálogo 547 Int 6: no convertir exterior en interior ni duplicar. No se
activaron vínculos en esa investigación; la consulta fresca del sitio oficial no fue accesible y la
evidencia previa conserva su fecha. Reporte local:
`collectors/artifacts/puebla-expansion-20261009/identity-review-34-research-20261019/REPORT.md`.

Continuación: el vínculo acotado de Tehuacán se aplicó conservando todos los datos
existentes; [revisión 34](PUEBLA_IDENTITY_LINK_34_20261019.md). Continúa la búsqueda
de evidencia de estudios por proveedor y sucursal; Municipio Libre y las
equivalencias clínicas ambiguas conservan sus restricciones.
[Recuento posterior e historial separado](CATALOG_STATUS_20261019.md).
