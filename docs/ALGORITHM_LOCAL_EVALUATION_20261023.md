# Evaluación local completa del núcleo — 23 de octubre de 2026

## Resultado

Se ejecutó el núcleo real con una copia del catálogo público del 22 de octubre:
15 tablas, sus valores y tipos originales, siete funciones vigentes y los
4,045 registros pendientes agrupados en 744 consultas. Sin datos de pacientes.
Cada comparación incluye 22 controles y 3,020 invocaciones antes/después.

El candidato literal se comparó por separado en PostgreSQL 12.22 y 17.6.
Ambas ejecuciones terminaron y dieron los mismos resultados. Una variante
corregida se comparó de nuevo por completo en PostgreSQL 17.6.

| Estado de los registros, con proveedor | Vigente | Variante local corregida |
| --- | ---: | ---: |
| Selección única observada | 36 | 16 |
| Con candidatos ambiguos | 272 | 56 |
| Sin coincidencia | 3,737 | 3,973 |

**No hubo ganancias de sin coincidencia a selección única.** Estos números
no son aprobaciones clínicas, cierres del backlog ni cobertura comercial.
La variante restringe resultados; no es un algoritmo que resuelva los pendientes.

## Correcciones observadas

- Conserva biometría hemática y las consultas «hematica» y «biometria».
- Deja de seleccionar una biometría para consultas que además piden INR o x2.
- La primera propuesta ocultaba «electro» y degradaba la coincidencia exacta
  «IgE específica contra gluten». La variante conserva las tres sugerencias
  de electro como ambiguas y recupera la coincidencia exacta de IgE.
- «Sangre» y «orina» requieren elección; «hepatica» sigue sin coincidencia.
- Los controles de conceptos ausentes no acreditan que se hayan probado sus
  protocolos: un resultado vacío no demuestra por sí solo una guarda correcta.

## Alcance y límites

Se importaron todos los campos exportados y se compararon por igualdad JSONB.
No se reprodujeron índices, restricciones, RLS, JWT, permisos, geografía ni
los envoltorios públicos de paneles e imagen. No se ejecutó el candidato completo
de 29 funciones en esta comparación. No hubo conexiones remotas del ejecutor
local ni cambios del motor clínico productivo. Cada servidor local se detuvo
y se retiró su archivo de contraseña al terminar.

El primer envío controlado a producción del 22 de octubre falló por una FK,
con reversión comprobada; no se repitió. Ese incidente y su corrección siguen
documentados en [el informe anterior](proposals/20261022-clinical-evaluation-results/README.md).

## Reproducibilidad y fallos del arnés

Scripts en `database/scripts`: `export_clinical_core_local.py`,
`run_clinical_core_local.py`, `summarize_clinical_core_local.py` y
`prepare_requirement_discovery_candidate.py`.

Evidencia ignorada: `collectors/artifacts/clinical-core-local-20261022/`.
Las comparaciones completas son `local-core-runtime-v2`,
`local-core-runtime-pg17` y `local-core-discovery-v2-pg17-complete`;
cada una conserva entrada, observaciones antes/después, resúmenes y apagado.
La exportación conserva hashes y huellas remotas antes/después sin alteración.

Se preservan dos intentos incompletos: alias SQL del arnés corregido y
preparación de variante detenida por saltos CRLF. Este último inició sólo la
fase anterior y terminó al faltar los SQL. Se normalizaron saltos de línea y
se añadió prevalidación de archivos; después se hizo una ejecución nueva completa.
Ninguno se cuenta como comparación terminada.

## Siguiente acción

Publicar las mejoras independientes de interfaz/API autorizadas por el usuario.
Mantener aislado el candidato clínico completo hasta demostrar sus contratos
y revisar las pérdidas de resultados. No convertir los 16 casos observados en
decisiones de normalización automáticamente.
