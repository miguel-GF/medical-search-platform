# Recuento del catálogo y separación del historial

Fecha: 19-oct-2026. Base productiva enlazada, observaciones locales de sólo
lectura entre 12:54 y 13:04 UTC. No se consultaron entradas de pacientes.

| Categoría de registros del crawler | Total | Interpretación |
| --- | ---: | --- |
| Resueltos favorablemente | 3,315 | Estado resolved y una decisión con estudio seleccionado. |
| Pendientes abiertos | 4,073 | Sin decisión terminal; cola administrativa vigente. |
| Históricos sin coincidencia | 946 | Estado no_match y decisión no_match antigua; fuera de la cola abierta. |
| Total de registros | 8,334 | Suma de las tres categorías, no estudios distintos. |

Los 551 conceptos activos son estudios distintos del catálogo. Ni los registros
resueltos ni los pendientes se deben presentar como cantidades de estudios únicos.
Contar todo no_match da 5,019, pero mezcla 4,073 tareas abiertas con 946 decisiones
históricas. Los 946 no son resultados favorables ni se presentan como pendientes
abiertos. Esta separación ya estaba prevista en la cola y documentación histórica;
la observación de hoy confirma su estado y origen.

## Origen de los 946 históricos

Cada uno tiene exactamente una decisión no_match, sin estudio seleccionado ni
ID de revisión terminológica. Son decisiones del 26–28 de agosto cuyo motivo
es falta de término exacto y necesidad de revisión clínica de candidatos fuzzy:

- Chopo: 119 registros en dos capturas (115 y 4).
- Salud Digna, reconciliación de sucursales: 827 en dos capturas (826 y 1).

No se borraron, reabrieron ni sustituyeron esas decisiones. El importador ordinario
de revisiones excluye correctamente filas con decisión terminal previa; no debe
alterarse ese guard para aumentar el contador.

## Reobservación local, sin aplicar decisiones

Se compiló memoria shadow fresca con verificación remota de ledger y hashes:
59 revisiones aplicadas, 412 aliases, 431 reglas y 2,955 contextos históricos
resueltos por revisión. Los borradores no aplicados permanecen excluidos.
La comparación de los 946 contextos con esa memoria dio:

| Clasificación local | Filas |
| --- | ---: |
| Contexto exacto reutilizable según revisión posterior | 360 |
| Requieren evidencia de fuente | 580 |
| Campos de fuente no reconocidos | 4 |
| Contexto de fuente cambiado | 2 |

Los 360 son candidatos de investigación, **no 360 nuevas resoluciones**. Para
revisarlos hace falta una operación separada que conserve la decisión anterior,
acredite contexto y vigencia del destino, y registre la nueva revisión. No se
activó reproceso, se cambiaron decisiones ni se contó esa proyección como avance
productivo. El resultado cambia la siguiente tarea: estudiar una reevaluación
auditable de esos casos, sin borrar historial ni usar similitud como aprobación.

## Evidencia y siguiente acción

`database/reports/puebla_growth_baseline.sql` incluye ahora agregados explícitos
de resueltos y no_match terminales, además de pendientes abiertos. Es un reporte
de sólo lectura; no modifica esquema, funciones o el contrato de la cola. Se
ejecutó contra la base real después del cambio, sin suites formales.

Recibos bajo `collectors/artifacts/catalog-status-20261019/`:

- `counts-observed.json`: totales agregados; última lectura 13:04:34 UTC.
- `terminal-decisions-origins-observed.json`: estados, tipos y origen histórico.
- `terminal-shadow/observation.json`: comparación completa de 946 contextos,
  finalizada 13:04:36 UTC; memoria y plan conservados en la misma carpeta.

El directorio tiene 174 marcas y 258 ubicaciones, incluidas candidatas pendientes;
las ofertas activas siguen siendo 234. Continúa la investigación de la cola
abierta. Calcio ionizado, talio en sangre y factor de crecimiento placentario
tienen evidencia nominal nueva; las condiciones de muestra y la conservación
de calificadores necesitan revisión antes de incorporarlos.

También se preparó un diff aislado para requisitos cortos y propagación de
ambigüedad: `collectors/artifacts/puebla-expansion-20261009/clinical-research/short-requirements-proposal-20261019/`.
No está activado ni listo para despliegue: faltan consumidores transitivos,
observaciones amplias y medición de pérdida de cobertura. Su activación sería
un cambio clínico compartido sujeto a D-006; la investigación y preparación
local pueden continuar.
