# Puebla: sitio Pasteur y revisión66

20-oct-2026. Proyecto productivo `ymtcmfgwuzdqtsbuvzqf`; operación local
autorizada por D-021/D-022. Sin despliegues, migraciones o suites formales.

## Pasteur Tecamachalco: aplicado y observado

A las **13:48:55 UTC**, un cliente independiente confirmó el enlace
`https://www.laboratorioclinico-pasteur.com/` en la marca existente. La captura
de contacto del mismo día identifica Matriz, 7 Sur 506, Tecamachalco, CP75480,
concordante con DENUE3533309. Los cuatro hashes y el domicilio fueron revisados.

Se antepuso una nota fechada a la descripción, conservando íntegro el antecedente
que decía que no se había acreditado sitio propio. Se preservaron los bytes y
recibo del borrador sin aplicar antes de revisarlo; no se reescribió una decisión
aplicada. La marca sigue `verification_pending` y la sede `pending`.

Una marca actualizada, cero marcas/sedes/ofertas nuevas. Una observación
`reviewed_website_link` y una auditoría `provider.website_evidence_review`
conservan RID, hash, captura, fecha y atribución: **referencia externa manual**.
DENUE respalda la identidad, no la URL: su campo `www` estaba vacío. No se aprobó
ingesta/licencia recurrente. Las seis categorías del sitio no prueban estudios,
composición, precios, disponibilidad, titularidad jurídica o toda una red.

El primer rollback fue rechazado por dos representaciones del mismo timestamp
del vínculo (`espacio/+00` frente a `T/+00:00`). El ledger confirmó cero eventos,
cero observaciones y URL NULL. Se corrigió la comparación con el tipo real de
tabla, conservando la fecha y todos los campos. Rollback corregido sin persistencia,
**un único envío de commit** y lectura independiente: RAW completo, vínculo,
sede, políticas y contadores conservados; sólo URL/descripción y metadatos normales
del trigger cambiaron (`row_version`1→2). Se conserva el diagnóstico anterior.

Fixture: `database/data/provider-website-review-20261020-01.json`, revisión2.
SHA256: `8ac5af11c43e576ac0d39a90786ec56f0702827e2e5b78c6c18a3bdf5550f8e6`.
Evidencia ignorada: `collectors/artifacts/puebla-expansion-20261009/website-review-20261020-01/`:
snapshots, SQL, recibos y `applied-verified.json`.

## Investigación de estudios: decisión siguiente

Revisión66 examinó **22grupos/176RAW** del corte congelado posterior a revisión64.
No encontró nueva equivalencia clara y representable en ese subconjunto; no
acredita revisión completa de los4,063 pendientes. Reutilizó evidencia primaria
previa con hashes, sin descargas repetidas ni aprobaciones por frecuencia/fuzzy.

| Bloqueo de esos22grupos | Grupos /RAW | Siguiente evidencia o trabajo |
| --- | ---: | --- |
| Requisitos insuficientemente conservados por el resolvedor | 5 /40 | INR, horarios/series, métodos, cuantificación y dirección de razones. |
| Representación de atributos explícitos | 2 /16 | Sangre completa para glutatión; método funcional de ristocetina. |
| Definición propia del producto del proveedor | 15 /120 | Ficha con actividad/antígeno, gen/enzima, fracción u otro atributo faltante. |

Biotinidasa no distingue actividad frente a genBTD; antitrombinaIII no declara
actividad frente a antígeno; vitaminaK no declara fracción. Otra definición
general no identifica el producto concreto. Se conservan24RAW de estos ejemplos
y matriz de176contextos en `clinical-research/review-66-nominal-20261020/`, bajo
expansión Puebla. Hash de matriz:
`e36dd970b886d166e4ed17037ece66ea8986995e016612d8087031b7a98fde91`.

## Propuesta FTA-ABS: sin activar

Lectura remota13:34:36UTC:16FTA-ABS sin decisión, títulos/hashes intactos;
seis definiciones de resolvedor iguales a las capturadas el15-oct. El consumidor
usa `query_lexicon → service_methods`; guardar sólo
`lab_service_definitions.method` no conserva el requisito clínico.

La propuesta aislada de importador, preparador y ledger preserva método/isotipo
por objetivo. Los55lotes actuales generan **110/110 SQL idénticos** frente al
renderer vigente. Esto acredita generación, no ejecución del método nuevo ni
seguridad con isotipo opuesto, método incompatible o negación. Sin activación,
fixture FTA o cierres nuevos. Observaciones pendientes, recuperación y aprobación
D-006 detalladas en `clinical-research/catalog-method-support-20261020/PROPOSAL.md`.

## Estado y continuidad

Lectura independiente: **174marcas/258sedes/554conceptos/3,325favorables/
4,063pendientes/946no_match históricos/234ofertas/112migraciones**. El enlace
no incrementa cobertura comercial ni resuelve estudios. PID16372 de cola observado
vivo, sin reiniciar. Continuar con fichas propias y propuestas de conservación
de requisitos; mantener pendientes hasta contar con evidencia suficiente.
Los [cambios de búsqueda y móvil](SEARCH_SELECTION_MOBILE_20261020.md) siguen
preparados por separado, sin publicación.
