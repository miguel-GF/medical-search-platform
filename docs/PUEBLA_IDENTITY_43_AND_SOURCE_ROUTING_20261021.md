# Puebla: clínica ISSSTE y planificación por categoría de origen

21-oct-2026 local /22-oct04:02:33 UTC. Operación local D-021/D-022 contra
`ymtcmfgwuzdqtsbuvzqf`, base productiva. Sin agentes nuevos, migraciones,
despliegues ni cambios de aceptación clínica compartida.

## Identidad43 aplicada

DENUE9123577, Clínica de Medicina Familiar del ISSSTE en San Martín Texmelucan,
se incorporó bajo la marca ISSSTE existente, cuya fila completa quedó intacta.
Se conserva el nombre DENUE completo y su domicilio: Calle Cofre de Perote1600,
CP74042; clase621116/tipo clinic. No se creó otra marca ISSSTE ni se fusionó
con ISSSTEP, IMSS o IMSS-Bienestar.

CLUES PLIST000125 identifica CMF San Martín Texmelucan y declara expresamente
la misma institución; municipio/localidad, CP, tipo de vía, vía y exterior
coinciden. Las letras e interiores están vacíos en ambas fuentes. Se conservaron
asentamientos literales, sin homologarlos. El XLSX local fijado por SHA256 se
extrajo con el script existente:64,450filas nacionales/3,779Puebla/dos claves
solicitadas, sin faltantes. La segunda corresponde al candidato de Libres retenido.

RAW productivo íntegro comparado con el registro investigado, ausencia de binding
previo, revisión de las205marcas/290sedes y de ubicaciones cercanas. Rollback,
un único intento de commit y observación independiente confirmaron:

- Una sede, binding DENUE, observación y auditoría nuevos; cero marcas/ofertas.
- Las205marcas y290sedes anteriores íntegramente iguales, incluida marca ISSSTE.
- RAW, políticas, nombres, coordenadas y dirección conservados.
- **205 marcas /291 sedes /563 conceptos /3,341favorables /4,047pendientes /
  946históricos no_match /234ofertas /112migraciones.**

La sede queda pending. La identidad histórica y el estado mensual de CLUES no
acreditan operación actual, acceso, operador, estudios o disponibilidad comercial.
El website existente de marca se conserva; no se presenta como enlace con la
sucursal ya seleccionada.

Fixture aplicada `database/data/provider-identity-review-20261021-12.json`, SHA256
`e4a78b1c76d3e7ff7e63347f6dea9a2ea464a56bf1a476e496f8fe219b1c3a6e`.
Recibos, snapshots y extracción:
`collectors/artifacts/puebla-expansion-20261009/identity-review-43-research-20261021/`.
No reejecutar `apply.py`: ya existe marca de envío único y recibo independiente.

## Tres candidatos retenidos

- Centro Médico Tecamachalco, DENUE3536219: CLUESPLSMP002201 tiene interiorA,
  ausente en DENUE. Otro CLUES del mismo inmueble corresponde a un hemocentro,
  con interior2. No son equivalentes por compartir exterior104; no crear
  una asociación entre hospital, laboratorio y hemocentro sin evidencia.
- Consultorio Fundación Best de Tehuacán, DENUE11786412: CLUESPLSMP008752
  declara interiorA, DENUE lo deja vacío. No se copia el interior ni se afirma
  pertenencia a una red jurídica por similitud nominal.
- Consultorio de Libres, DENUE3488294: DENUE/CLUES coinciden en2Oriente885/73783,
  pero el [directorio oficial ISSSTEP de mayo2024](https://issstep.puebla.gob.mx/images/directorio/Directorio_ISSSTEP_Serv-Med-may-24.pdf),
  página2, utiliza Hidalgo885/73780. Documento leído por webtool, sin atribuir
  captura HTTP directa. Podría existir cambio de denominación o domicilio;
  no se comprobó. No declarar dos calles equivalentes ni ubicación actual.

Estas retenciones no implican que los establecimientos no existan. Registran
exactamente la evidencia faltante antes de resolver su identidad.

## Algoritmo: categoría declarada y procedencia

Se extendió [plan_normalization_research.py](../database/scripts/plan_normalization_research.py)
para conservar por tarea la categoría declarada y el campo que la originó:
primero `raw_study.Estudio`, después `area` y `category`; si no existe texto,
queda `not_declared`. No se infiere especialidad canónica del nombre del estudio.
El resumen incluye filas y grupos por categoría, manteniendo volumen como orden
de prioridad. Un grupo puede figurar en más de una categoría de origen; los
conteos de grupos por categoría no se deben sumar como grupos únicos.

Ejecución local real sobre el inventario completo73, no una nueva exportación
clínica:4,047filas/745grupos;741grupos por investigar y4grupos/11filas en espera,
sin cambios respecto al plan previo ni aprobaciones nuevas.

| Categoría literal de origen | Filas del inventario guardado |
| --- | ---: |
| LABORATORIO | 1,642 |
| RAYOS X | 1,546 |
| TOMOGRAFIA | 268 |
| RESONANCIA MAGNETICA | 240 |
| ULTRASONIDO | 167 |
| Otras | 184 |

La suma de las categorías declaradas de imagen —incluyendo densitometría,
ultrasonografía y variantes simples/contrastadas— es2,263filas. **No significa
2,263cierres posibles con un único cambio:** cada definición conserva anatomía,
modalidad, proyecciones, contraste, lateralidad y evidencia que corresponda.
Sí demuestra que investigar sólo nombres de analitos deja sin atender la mayor
parte del backlog. Los candidatos de integración de imagen siguen aislados y
pendientes de aprobación conforme su propuesta; esta clasificación no los activa.

Salida nueva, sin sobrescribir el primer plan:
`collectors/artifacts/research-planner-20261021/queue-by-source-category.json`.
La planificación es local, sin solicitudes HTTP ni escrituras SQL. Se conservan
vencimiento de memoria y recibos de investigación; no habilita uso indefinido de
snapshots antiguos. Sin suites formales añadidas o ejecutadas.

## Siguiente acción

Continuar desde los grupos y dependencias que muestra esta cola; para imagen,
completar el candidato de integración y su evidencia antes de solicitar la
aprobación crítica. Para los tres establecimientos retenidos hace falta evidencia
de interior o equivalencia/cambio de domicilio. El watcher clínico sigue detenido
y STOP presente; no se encolaron revisiones nuevas ni se reactivaron agentes.
