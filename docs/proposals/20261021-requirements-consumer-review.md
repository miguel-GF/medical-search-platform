# Calificadores: revisión de consumidores del motor

21-oct-2026. Diagnóstico local de definiciones productivas; **sin instalar SQL**,
sin migración, sin suite formal y sin aprobación de cambio compartido D-006.
Complementa la [propuesta INR](20261018-preserve-inr-requirement.md).

## Evidencia nueva

La revisión71 de IgE contra trigo confirma que no basta revisar títulos clínicos:
el nombre inequívoco puede producir selecciones incompatibles si el motor pierde
IgG/IgA, x2 o negación. Siete variantes incorrectas observadas por dos rutas, sin
persistir el candidato. [Resultado y retención](../PUEBLA_IDENTITIES_37_AND_REVIEW_71_20261021.md).

Se leyeron127 funciones de `public/catalog/health/core/ingest` a05:15:40UTC.
La clausura inversa textual de llamadas calificadas contiene22 rutinas; una
búsqueda adicional de nombres de esas rutinas usados como llamadas sin esquema
en los cuerpos de las127 no encontró nuevas referencias. Es un análisis textual:
no acredita ausencia de SQL dinámico, llamadas desde otros esquemas, jobs o clientes.
No se presenta como un inventario semántico completo de PostgreSQL.

Las definiciones productivas de v3/v4/v6 son idénticas, salvo espacio final,
a las bases de la propuesta aislada19-oct. Eso permite continuar revisando el
diff; no demuestra que el diff sea correcto ni autoriza ejecutarlo.

## Propagación observada por lectura del código

| Consumidor | Tratamiento actual | Consecuencia para el cambio preparado |
| --- | --- | --- |
| catalog.resolve_items_v3 | Aceptación léxica omite tokens cortos y permite prefijos/fuzzy; ramas exact/alias tienen excepciones | Requiere conservar requisitos incluso en esas ramas; una lista cerrada de abreviaturas no resuelve el problema |
| catalog.resolve_items_v4 | Recalcula resolved por número de filas y origen disambiguation | Un filtro aislado puede promover el único superviviente; debe preservar procedencia de poda |
| catalog.resolve_items_v6 | Dominancia exacta y nuevo cálculo de estados | Debe conservar ambigüedad por requisitos; LOINC exige código entero, exacto, activo, verificado y aprobado |
| public.api_resolve_search_v4 | No_match con cero; ambiguous si más de uno o cualquier candidato ambiguous; adjunta ofertas por ID candidato | Conserva ambiguous si llega del core, pero las ofertas de candidatos aún existen en payload y el cliente debe respetar el estado |
| public.apply_resolution_confidence_guard | Recalcula status; preserva ambiguous en candidatos seguros y marca fuzzy débil ambiguous | No debe inferirse seguridad sólo por confianza alta; inspección no sustituye observación extremo a extremo |
| public.api_resolve_package_links_legacy | Estado por conteo o bool_or(ambiguous); sólo resolved_items únicos y todos resolved alimentan ofertas | El flag debe convertirse en estado antes de esta capa; no basta metadata desconocida para ella |
| public.api_resolve_package_internal | Añade links y filtra scopes concretos; conserva items | No crea resolución clínica nueva en este cuerpo |
| public.apply_package_confidence_guard | Conserva items ambiguous y deja ofertas sólo para índices resolved | Mantiene abstención si llega correctamente del motor |
| public.api_resolve_ocr_package_internal | Aplica correcciones OCR aprobadas y llama paquete | Observar conservación del original y calificadores tras corrección, además de la respuesta final |
| Worker search/suggestions/guidance | Consumen api_resolve_search | Revisar sugerencias y selección explícita además de búsqueda normal |
| Worker receta/OCR | Segmentación previa; RPC paquete; normalize/build/sanitize | Es una dependencia adicional: revisar segmentación, cobertura y soluciones; no queda probada sólo por las funciones SQL |

Las dos funciones de confidence guard son transformadores del resultado; no
aparecen en una clausura que busque sólo quién llama al resolver. Se inspeccionaron
sus cuerpos por separado. En `apps/api/src/app.ts`, la ruta de paquete pasa por
`segmentFreeFormPackageText` y `api_segment_package_text` antes de resolver;
después llama `normalizeBatchRpcPayload`, `buildPackageResolution` y
`sanitizePackageResolution`. Estos pasos requieren revisión específica.

## Próximo trabajo autorizado y límites

### Observación adicional del catálogo y Worker local

A05:27UTC se observaron12consultas existentes por tres RPC: búsqueda, paquete y
segmentación. `Biometría hemática INR` y `Biometría hemática x2` se resuelven como
biometría simple con34ofertas; el segmentador devuelve no_match y no elimina esas
palabras. Seis peticionesHTTP reales al Worker local8787 confirman ready/complete,
un item cuyo input aún contiene INR/x2 y10soluciones: el problema llega a cobertura.
No se observó el Worker público ni se instaló el diff de tres funciones.

`Biometría hemática glucosa` se segmenta exactamente en dos y el Worker resuelve
ambas; al añadir INR queda no_match/none. IgEgluten con IgG/IgA/x2/negación queda
ambiguous en estas observaciones; no afirmar que sea equivalente al caso trigo
aislado ni que todas las órdenes con calificadores fallen igual. Los conteos y
fuentes antes/después de las lecturas SQL permanecieron iguales.

Por lectura de código, `readCatalogSegments` exige reconstrucción normalizada
completa y método exacto; si falla conserva input previo. `buildPackageResolution`
produce needs_clarification y no soluciones ante cualquier item ambiguous; sólo
índices resolved alimentan ofertas. `normalizeBatchRpcPayload` limita forma y
tamaño, sin validar equivalencia; `sanitizePackageResolution` conserva esos estados.
Por tanto metadata nueva por sí sola no protege cobertura: debe propagarse como
estado antes de construir soluciones. Extracción de ayuno es un camino separado,
acotado y trazable; no se modifica en esta tarea.

Artefactos adicionales: `existing-behavior.json`, `existing-read-receipt.json`,
`local-package-observed.json` y `local-package-read-receipt.json`. Consultas
sintéticas, sólo observación; no suites formales ni prueba de solución propuesta.

Preparar una matriz de llamadas externas, segmentación, normalización y cobertura;
revisar las rutinas transitivas fuera de los cinco esquemas capturados, jobs y
consumidores de RAW. Conservar las retenciones existentes. Preparar el diff final,
impacto y recuperación sin activarlo. No prometer que el predicado literal
resuelva semántica de negación, cocientes, composición, multiplicidad o condiciones
del candidato ausentes en la consulta.

La propuesta actual todavía no está lista para publicación: falta observar sus
efectos, pérdidas de cobertura y latencia con autorización aplicable, cerrar
consumidores y preparar nueva migración/recuperación. El cambio de aceptación
clínica compartida necesita aprobación explícita D-006, según AGENTS/DECISIONS;
la autorización de equivalencias terminológicas no lo reemplaza.

## Reproducibilidad

Artefactos ignorados:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/requirements-consumers-20261021/`:
`read_closure.py`, `functions-current.json`, `reference-closure.json`, baseline y
recibo de lectura. SHA256 del snapshot127funciones:
`16ec8b36c9eb21663fa4104e7a6185b4fb57584cdc1b5b1e5d5380adaea7436c`.
Las observaciones adicionales de esta nota son lectura local de ese snapshot y
del árbol actual; no una nueva comprobación remota del código después de05:15UTC.
