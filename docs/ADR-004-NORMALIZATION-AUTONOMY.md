# ADR-004: crecimiento autónomo y seguro de la normalización

**Actualización 13-oct-2026:** [D-021/D-022](DECISIONS.md) autorizan al agente a investigar
fuentes primarias y decidir equivalencias claras con trazabilidad; la intervención
humana rutinaria deja de ser necesaria para esos casos. Fuzzy/IA aislada siguen
sin aprobar conceptos. Treinta y siete revisiones aplicadas: 309 aliases exactos
(286 globales y 23 de proveedor), 271 conceptos ausentes investigados y 2,286
filas del crawler, sin nueva oferta ni política comercial alterada. Quedan
4,742 filas / 860 grupos pendientes; el catálogo tiene 460 conceptos. Sesenta
conceptos nuevos
tienen código de muestra, 209 mantienen matriz desconocida y dos conservan
muestra literal sin código admitido: secreción mamaria y exudado uretral.
Por entrada, se conservan familia sangre en 234 contextos (232 SD y dos SEMIN),
serum en 61 (32 SD y 29 SEMIN), plasma en dos, stool en 60 y urine en 76;
no se atribuyen esos contextos a otra fuente o al concepto sin evidencia.
Los 23 aliases de proveedor conservan su alcance; no usar títulos incompletos
para inferir contexto en otras fuentes. Trece revisiones de identidad añadieron
treinta marcas o instituciones y 65 sedes pending: 68 marcas / 152 ubicaciones.
El cron remoto sigue apagado; el ejecutor local vigila sólo la cola
explícita de revisiones ya investigadas, con hash, ensayo y recibos. Las revisiones
08–37 se aplicaron mediante ese ejecutor, incluida la sustituta de 32, y se
confirmaron en remoto. Las revisiones 34, 35 y 37 cerraron 187 filas con 23
conceptos y 25 aliases; se observaron 44/44 consultas públicas y 5/5 internas
con proveedor. La revisión 36 cerró otras 34 filas, quedó `applied_verified` y
se observaron 6/6 consultas públicas y 6/6 internas con proveedor. El triage
de sólo lectura conserva 828 brechas, 32 grupos con sugerencias, 860 puertas
de política de fuente y 26 grupos con fuente oficial sin verificar.
T3 libre permanece bloqueado en el resolver por un guard histórico; se conserva la
distinción entre decisiones crawler aplicadas y búsquedas que funcionan.
Los 61 exactos de las revisiones 14–16 funcionan en la API local; antiendomisio
IgG conserva un candidato IgA incompatible bajo estado ambiguo. La propuesta
de filtro debe revisarse antes de cambiar el contrato clínico común. Los 43
exactos de 17–18 y los 26 de 19–20 funcionan; toxoplasma IgA incluye IgG
incompatible bajo estado ambiguo. AFP-L3 selecciona AFP genérica. Su
[diff clínico y recuperación](proposals/20261011-afp-l3-candidate-conflict.md)
están preparados, sin activarlos. La revisión 21 resolvió 17/17 consultas exactas y cerró 66 filas; conserva 40
pendientes por fracción o metabolito. Ciclosporina C2 devuelve el analito genérico
sin representar el momento C2. La sangre total SEMIN sirolimus queda en su guard
RAW; no se convierte a suero ni se traslada a SD. El guard RAW del renderer se corrigió para
excluir decisiones terminales históricas, conservando alcance crawler: rollback
83 filas, cero fuera de alcance, commit y ledger completos del lote 18.
[Fuentes y evidencia](PUEBLA_LOCAL_OPERATION_20261009.md).
Las revisiones 22–23 cerraron 161 filas con veinte conceptos/aliases y
resolvieron 40/40 consultas exactas. Treinta y dos filas permanecen abiertas
por factor VIII antigénico, órdenes combinadas y APOE sin tipo de medición.
Cromogranina B incluye A y troponina T incluye I bajo estado ambiguo;
osteocalcina N-MID selecciona el analito genérico sin representar el fragmento.
[Diagnóstico de variantes](proposals/20261011-laboratory-variant-candidates.md),
sin activar cambios del resolver.
Las revisiones 24–26 añadieron 22 conceptos y 24 aliases, cerraron 169 filas
y resolvieron 46/46 consultas exactas locales. Siete conceptos conservan muestra
explícita (tres heces, tres orina y uno suero); quince mantienen matriz exacta
desconocida. CH50 conserva naturaleza funcional; C5 no elige actividad/concentración.
Osmolaridad mantiene la denominación literal de la fuente: propiedad, método y
equivalencia con osmolalidad no aprobados. SEMIN conserva suero/plasma/heces/orina
por contexto; mercurio conserva `Sngre total con EDTA. Refrigerado` literalmente.
Se corrigió y auditó una herencia accidental de atributo entre proveedores, sin
repetir el lote ni modificar su destino. Renderer: atributos independientes por
target y soporte de heces ya existentes. Resolver clínico sin cambios.
Las revisiones 27–29 añadieron catorce conceptos y dieciséis aliases, cerraron
128 filas y resolvieron 30/30 consultas exactas. IA-2 comparte sus dos etiquetas;
Scl-70 conserva IgG explícita; GABA-B conserva suero y AChR conserva unión,
bloqueo o modulación escritos. Trece conceptos mantienen matriz desconocida.
En el corte 29, ocho AChR genéricos y ocho GAD sin isoforma seguían pendientes;
MOG y aquaporina requerían investigación propia. La revisión 33 incorporó MOG
sin inferir IgG, método o matriz; aquaporina conserva su pendiente.
Scl-70 IgM incluye IgG y GABA-A incluye GABA-B
bajo estado ambiguo: diagnóstico guardado, sin activar el filtro clínico.
El renderer respeta el límite existente de nota de alias de 1,000 caracteres:
si el motivo completo excede ese espacio, la nota referencia la auditoría, que
conserva íntegramente la razón investigada. Hashes, SQL, controles y ledger se
revalidaron antes de reiniciar el ejecutor terminal; no se debilitó la restricción.
Los cortes de septiembre siguientes se conservan como antecedentes.

**Memoria y alternativas API, corte 37 del 13-oct:** el operador pidió investigar y construir
una vía de reutilización entre estados. Se implementaron un compilador de
memoria con ledger remoto y un adaptador NLM con caché/consulta del índice LOINC
local. Ambos producen planes/candidatos y no escriben decisiones. La memoria
conserva 309 aliases y 328 contextos proveedor-alias; reconoce 2,283 de los 2,286
contextos históricos y retiene tres por campos desconocidos. Los 4,742 pendientes
se agrupan en 860 trabajos: 4,658 requieren evidencia y 84 conservan campos
desconocidos. No se infieren los grupos a partir del número de filas cerradas.
La observación shadow dejó iguales los contadores antes/después: 460 conceptos,
234 ofertas, 68 marcas, 152 ubicaciones y 112 migraciones. Recibo local ignorado:
`collectors/artifacts/normalization-memory-after-review-37/observation.json`.
La memoria v2 incluye el título literal y retiene tres históricos con campos
no contemplados; no declara precisión sobre casos nuevos. No es una tasa de autonomía sobre casos nuevos. La
[investigación e implementación](proposals/20261011-normalization-memory-and-apis.md)
compara NLM, LOINC FHIR, UMLS e IMO, documenta doce respuestas reales y distingue
catálogo compartido de contexto/oferta del proveedor. Revisiones 30–31: 109 cierres
por investigación separada, 23/23 consultas públicas completas/globales y 5/5
aliases internos con proveedor. La ruta pública no admite proveedor en `resolve`;
sus títulos incompletos siguen `no_match`. No se activó el algoritmo
clínico, un scheduler ni un servicio comercial.
El preparador reutilizable genera fixtures con hashes de investigación y
comprueba RAW, colisiones, conteos y nombres canónicos nuevos antes de encolar.
No añade por sí mismo entradas a la cola. Puede reutilizar un concepto mediante
`existing_catalog_item_id` después de comprobar nombre primario exacto, dominio
de diagnóstico, estado activo y tipo `lab_test`; registra la identidad y separa
conceptos nuevos de reutilizados en el recibo. El investigador debe comprobar
componente, matriz, tiempo y variantes antes de elegir ese destino. No se
modifican atributos del concepto existente ni se amplía una equivalencia por
similitud. Los aliases limitados a proveedor sólo cubren los pares declarados;
los homónimos externos se conservan fuera del lote. Los términos globales y
nombres canónicos completos siguen bajo el guard de contextos adicionales.
La regla `-text` de [.gitattributes](../.gitattributes) conserva los bytes de los
fixtures JSON versionados y evita alterar su SHA256 por conversión LF/CRLF.
Recibo, cola, ledger y versión en Git deben conservar la misma evidencia; un
fixture aplicado no se regenera para corregir un hash. Los commits `8948671` y
`724e183` conservan la protección y la evidencia versionada. Estas mejoras son de
preparación y trazabilidad, sin activar el filtro o algoritmo clínico común.
El ensayo 32 reveló un contexto SEMIN de Giardia adicional; ledger sin aplicar,
guard conservado, RAW investigado y revisión nueva de 74 filas aplicada junto
al lote 33 de 64. 33/33 consultas públicas y 3/3 internas observadas; sesenta
vecinos mantuvieron sus UUID pendientes. No equivale a investigación automática
inédita o precisión sobre recetas. En el corte 33, la cola recuperada tenía 27
entradas / PID 2044; el worker 2044 aplicó también 36, sin extrapolar el número
actual de entradas. Los recibos `closing-*` de
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-34/`
confirman contadores, baseline, triage completo y las tres apps locales HTTP 200;
el worker PID 2044 quedó `watching`. No se activó una función clínica ni se
ejecutaron suites formales en este corte.

**Antecedente del 24-sep-2026:** consultas y reproceso exacto acotado aplicados;
Admin/API publicados entonces en producción. El usuario autorizó ese día
aplicar las migraciones aditivas y
desplegar las superficies de esta tarea, manteniendo el cron y collectors
desactivados. Los 30 contratos SQL pasaron `518/518`; la aprobación no incluye
políticas de fuente ni captura automática. Corte: 24-sep-2026, proyecto Supabase
enlazado `pruevia-dev`, usado también como base inicial productiva según
[ADR-003](ADR-003-PATIENT-FIRST-PUBLICATION.md). Esta ADR no contiene datos de
pacientes. La aprobación de publicación no activa el scheduler ni autoriza
decisiones clínicas automáticas.

Admin/API/Paciente públicos permanecen pausados desde el 25-sep-2026; sólo el
landing continúa activo. La operación de octubre usa las apps locales contra
la misma base inicial productiva. La revisión delegada autorizada de casos
claros no activa el filtro clínico común ni la investigación por puntuación.

## Problema y evidencia

La cola abierta del crawler tiene 7,028 filas, pero sólo 1,188 pares
proveedor+etiqueta. El preview del reproceso exacto encuentra **0** filas listas.
Hay 189 ítems activos y 362 aliases aprobados; ningún identificador de esas 7,028 filas
coincide con una oferta activa del mismo proveedor. En los 100 grupos más
repetidos, 94 no tienen candidato del resolvedor, cuatro tienen uno y dos más
de uno. Fuente reproducible: [reporte SQL](../database/reports/normalization_autonomy_opportunities.sql).
Son conteos de la base enlazada a esa fecha, no promesas de cobertura ni
aprobaciones clínicas.
El triage read-only del 24-sep recorrió los 1,188 grupos: 1,127 huecos sin
sugerencia léxica útil, 61 con sugerencia, 0 exactos; los 1,188 tienen política
de fuente `review_required` en su muestra representativa. El informe completo
está en un artefacto local ignorado, no en Git.
El [corte por fuente](../database/reports/normalization_source_policy.sql) del
24-sep comprobó las **7,028 filas**, no sólo representantes: las nueve fuentes
están en `review_required`; ninguna fila carece de RAW, identificador externo
o URL con prefijo HTTPS. El
triage separa 27 grupos cuya fuente está clasificada `public_website` y no
`provider_official`/`official_api`; eso no significa que falte la URL. Hay 968
grupos con más de un identificador externo para su etiqueta. Eso no equivale a
968 estudios distintos. El [probe de identidad](../database/reports/normalization_sku_identity_probe.sql)
encontró **7,028 identificadores distintos para 7,028 filas**, mientras sólo hay
1,188 grupos proveedor+etiqueta. El [probe de origen](../database/reports/normalization_sku_origin_probe.sql)
mostró que Salud Digna usa `provider_external_id` en sus 6,804 filas y no
`provider_sku`; SEMIN mezcla campos. Por tanto, la clave anterior por supuesto
SKU generaría un borrador por fila y se descartó antes de cualquier escritura.

El corte vivo del 24-sep agrupó esas filas en nueve fuentes: Salud Digna (6,804),
SEMIN (137), Chopo (57) y seis sitios clasificados como `public_website`:
familylabs.com.mx (12), lafer.mx (6), labxonaca.com (5), semindigital.com (3),
verkenlab.com (3) y riex.com.mx (1). Los seis últimos no están acreditados como
fuentes oficiales del proveedor, aunque tengan URL HTTPS y datos RAW.

La mayoría no son errores de escritura que un umbral fuzzy arregle: el catálogo
carece de conceptos de proveedor. Abrir una equivalencia por parecido puede
confundir muestra, método, anatomía, contraste, lateralidad o composición.
Además, las fuentes principales están en `usage_policy_status=review_required`.
Un identificador externo y una URL identifican una **observación de origen**, no un
estudio canónico, una sede que lo realiza ni un precio publicable.
La revisión de fuentes es una puerta independiente del despliegue de la web. Los
términos visibles de [Salud Digna](https://www.salud-digna.org/terminos-condiciones-servicios)
declaran que los contenidos son de la institución/proveedores y que su
reproducción o explotación requiere autorización previa por escrito. No contamos
con ese permiso ni con una licencia de API; por tanto, mantener su captura y uso
automatizado en `review_required`. Además, durante la consulta pública de fuentes
aparecieron resultados indexados del subdominio fiscal que parecen incluir datos
identificables y de salud de terceros. No se descargaron ni se incorporaron esos
datos; no recolectar comprobantes ni usar ese subdominio como fuente. Es razonable
avisar este hallazgo al proveedor por un canal oficial, sin adjuntar ni republicar
la información expuesta.

Como evidencia del límite de sede, [Chopo indica en sus términos](https://www.chopo.com.mx/terminosycondiciones)
que sus estudios publicados pueden no prestarse en todas las sucursales; la
información es informativa y promociones/precios pueden cambiar. [SEMIN señala](https://semindigital.com/terminosUso)
que precios pueden cambiar y que algunos estudios no están disponibles en todas
las sucursales. En los términos visibles de ninguno de los dos encontramos una
autorización expresa de extracción automatizada o republicación. Eso no prueba
que estén prohibidas: deja sin acreditarse la autorización requerida por nuestro
gate. No marcar `approved` sin permiso verificable o una API/licencia con alcance
explícito. Los seis sitios `public_website` también quedan pendientes de validar
identidad del titular, términos, alcance y autorización. El adaptador de SEMIN
respeta `robots.txt` y su User-Agent identifica la web pública de Pruevia; esos
controles técnicos no equivalen a permiso de uso.

### Revalidación de fuentes — 25-sep-2026

Se volvió a consultar únicamente información legal pública de los dominios
oficiales; no se descargaron catálogos ni se inició scraping. La versión visible
de los [términos de Salud Digna](https://www.salud-digna.org/terminos-condiciones-servicios)
reserva la propiedad del contenido y prohíbe su uso, reproducción o explotación
sin autorización previa y por escrito. La puerta `review_required` debe mantenerse
hasta obtener ese permiso o un feed/API con licencia y alcance explícitos.

Los [términos de Chopo](https://www.chopo.com.mx/terminosycondiciones) reiteran
que los estudios publicados pueden no prestarse en todas las sucursales; su web
pide elegir ubicación/sucursal para precios y disponibilidad. Los [términos de
SEMIN](https://semindigital.com/terminosUso) dicen que los precios pueden cambiar
sin aviso y que algunos estudios no están disponibles en todas las sucursales.
En las páginas legales consultadas no se encontró una concesión expresa de
extracción automatizada o republicación. Las búsquedas en dominios oficiales
tampoco mostraron documentación pública de API; esto no demuestra que no exista
un convenio/feed privado. No llamar a endpoints internos ni activar esos
collectors: solicitar al titular autorización escrita, feed/API documentado,
campos permitidos, cadencia, retención y atribución. No se contactó a proveedores
ni se cambió ninguna política remota.

## Camino propuesto

1. Ingerir sólo fuentes cuya política de uso, alcance y cadencia se hayan
   revisado. Registrar corrida, URL, fecha, contenido, SKU y fallos. No borrar
   datos válidos por una corrida vacía; cuarentena y alerta ante caída brusca.
2. Agrupar filas `crawler` por proveedor+etiqueta, con inspección de SKU y
   procedencia por fila. Los RPC read-only están aplicados en el proyecto
   enlazado `pruevia-dev`, que también sirve de base inicial productiva; la vista
   Admin/API ya está publicada. El [triage](../collectors/src/pruevia_collectors/normalization_triage.py)
   produce clases, sugerencias y una clave de **grupo de revisión** por proveedor
   y etiqueta; los IDs externos quedan como evidencia, no como estudios ni
   borradores. No escribe ni aprueba nada.
3. Reprocesar de forma automática **sólo** nombres exactos únicos y aliases
   previamente aprobados, respetando su alcance global o de proveedor y excluyendo términos de
   desambiguación. Requiere preview, lote acotado, actor, auditoría, idempotencia,
   alertas y kill switch. La ruta separada para `crawler` está aplicada y
   desplegada, pero el flag productivo permanece `false`; no se ejecutó. La
   función interactiva existente también contempla otros `input_type`.
4. Si una fuente demuestra que un identificador es un SKU comercial estable,
   podrá crearse en el futuro un **borrador privado de observación** ligado a él;
   si sólo es un ID de captura, conservarlo como evidencia dentro del grupo de
   revisión. Ninguno es oferta visible ni equivalencia con otro concepto.
   Deduplicar según la semántica comprobada de cada fuente, no por un fallback
   genérico; cambios de nombre/composición van a revisión. Esta escritura aún
   no está implementada.
5. Fuzzy, abreviaturas, LOINC e investigación de URL oficial generan candidatos
   ordenados con evidencia. Sólo reglas aprobadas o revisión clínica pueden
   establecer equivalencias; nunca elegir el primer panel ambiguo. El índice
   local LOINC existente es material de apoyo, no una licencia para autovincular:
   el [término LOINC](https://loinc.org/kb/users-guide/major-parts-of-a-loinc-term)
   separa componente, muestra, método y escala; su
   [licencia](https://loinc.org/kb/license) tiene condiciones de uso.
6. Publicar por separado concepto, oferta, sede, precio y disponibilidad, cada
   uno con fuente/fecha/alcance y sus propias puertas. Una fila RAW no prueba que
   todas las sucursales hagan el estudio.

## Implementado y verificado en esta fase

- Reporte SQL de oportunidades y consulta read-only en `pruevia-dev`, base inicial de producción.
- RPC de grupos y exportación acotada de términos, sólo `service_role`, aplicados
  en el proyecto enlazado; Admin/API ya publicados. El dry-run remoto confirma
  `111/111` migraciones y la suite de contratos SQL pasó `518/518`.
- Triage CLI read-only con fixtures, clases `approved_term_reprocess_preview`,
  `exact_collision_review` y huecos de catálogo; una sugerencia fuzzy nunca sale
  como decisión.
- La búsqueda paciente explica que “sangre” no identifica un estudio único.
  Los acrónimos generados como `BH` se muestran sólo como sugerencias explícitas
  para volver a buscar; no se agregan como alias aprobados ni seleccionan un
  estudio. La ampliación de `api_search_spelling_suggestions` está en la
  migración aditiva
  [`20260924110000_search_initialism_suggestions.sql`](../database/supabase/migrations/20260924110000_search_initialism_suggestions.sql),
  contrato público `53/53` y API `143/143` aprobados; aplicada y publicada. Las
  sugerencias siguen separadas de resultados confirmados.
- Corrección local del resolvedor Python: dos ítems con alias exacto idéntico
  quedan ambiguos, no gana el ID menor.
- [Migración aplicada](../database/supabase/migrations/20260924100000_exact_approved_crawler_reprocessing.sql)
  y [contrato](../database/supabase/tests/admin_exact_crawler_reprocessing_test.sql)
  para una RPC exclusiva del cron: sólo `crawler` con RAW analizado, corrida
  exitosa, fuente oficial activa y `usage_policy_status=approved`, actor,
  lote máximo 200, idempotencia y auditoría. En `apply`, la migración materializa
  primero hasta el límite las ofertas nuevas aprobadas en `normalization_runs`;
  el preview no escribe, y ubicaciones/fuentes sin aprobación quedan fuera. No
  crea conceptos, alias ni ofertas. El Worker local ya apunta a esa RPC y falla
  cerrado si no existe. El [ensayo local PostgreSQL 12](../database/scripts/run_exact_crawler_pg12_smoke.ps1)
  pasó captura RAW → cola → reproceso exacto, abstención y replay en un esquema
  mínimo desechable. Su contrato remoto pasa `26/26`; la migración está aplicada
  y `pruevia-api` versión `c07c62a6-0c08-4226-a141-9f909e4445c8` llama esta RPC
  acotada. El trigger horario permanece inerte por
  `NORMALIZATION_REPROCESS_ENABLED=false`; no se ha hecho `apply`.

## Actualización operativa: 25-sep-2026

El preview remoto de sólo lectura en la base enlazada `pruevia-dev` volvió a
reportar 7,028 filas pendientes, cero elegibles, cero materializadas y cero
procesadas. El Worker horario no se activó porque, con esos conteos, sólo
escribiría eventos de auditoría vacíos. La fuente INEGI DENUE sí está
`active/approved`; el collector mensual fue desplegado en `pruevia-api`
(`780589b1-6b62-4789-8f40-9c90d9f323fa`) y su migración/RPC `20260925100000`
está aplicada. El lote guarda sólo ubicaciones RAW minimizadas y no procesa
etiquetas clínicas. El flag queda deshabilitado (`DENUE_COLLECTION_ENABLED=false`)
hasta guardar el token DENUE como secreto. Contrato remoto `13/13`, suite SQL
completa `531/531`, API `148/148`, typecheck y smoke local PostgreSQL 12 pasan.

Esta ruta de DENUE no habilita capturas de proveedores comerciales ni suple las
fuentes de nombres de estudios/precios. Las nueve fuentes vinculadas a la cola
clínica continúan `review_required`; no se modificaron. Más detalle y referencias
en [Collectors](../collectors/README.md#denue-mensual-preparado-apagado).

El 25-sep-2026 el usuario autorizó realizar en producción los cambios necesarios
para cerrar el trabajo. Se publicó `pruevia-api` versión
`c07c62a6-0c08-4226-a141-9f909e4445c8`, con la captura pública de búsquedas
apagada y las tareas de normalización y DENUE aún desactivadas. El Worker pasó
API `150/150`, typecheck y dry-run; `/health` respondió `200` y CORS devolvió
`204` para la app y `403` para un origen ajeno. El preview de normalización no
cambió: 7,028 filas, cero elegibles. No se aprobaron mappings ni se publicaron
ofertas; las fuentes comerciales permanecen sin autorización de uso verificada.

## Triage conservador read-only — 29-sep-2026

El usuario pidió maximizar decisiones automáticas. Se volvió a leer el proyecto
Supabase enlazado de producción y se confirmó el mismo total: 7,028 filas, 1,188
grupos, 0 exactos únicos y 1,188 grupos con `source_policy_not_approved`. No
hubo escritura remota, captura de fuentes ni cambio de alias.

El triage Python local ahora conserva `matched_term`, cobertura léxica y de
términos centrales, y banderas para modalidad, muestra, dirección anatómica,
lateralidad, clase de inmunoglobulina, vía y contraste. Un candidato fuzzy con
contradicción explícita o sin término central compartido sale de la lista de
sugerencias y permanece en `rejected_candidates` con motivo auditable. Nunca se
convierte automáticamente en `no_match` ni se interpreta el filtro como prueba
de inexistencia del estudio. Las 49 sugerencias que sobreviven (223 filas) aún
requieren evidencia de equivalencia; el cambio sólo eleva la precisión del
triage. En la muestra en vivo filtró candidatos de 14 grupos/87 filas únicas;
los subtotales de motivos se solapan.

La suite de collectors pasó `185/185`. El reporte actualizado se guardó sólo en
el artefacto local ignorado
`collectors/artifacts/normalization-triage-production-readonly-20260929.json`.
El lote seguro sigue en cero: toda fuente permanece `review_required` y no hay
coincidencias exactas únicas. Esto no autoriza activar el cron, cambiar la
política de ninguna fuente ni publicar ofertas.

## Impacto, riesgos, alternativas y recuperación

Agrupar baja el trabajo aparente a etiquetas accionables; no convierte 1,188
grupos en 1,188 aprobaciones automáticas. El coste inicial es ejecución limitada
de consultas/collectors, sin servicio nuevo contratado. Una fuente oficial puede
cambiar o prohibir cierto uso; un SKU puede reciclarse; un catálogo muy amplio
puede crear falsos positivos. Por eso hay cuarentena, límites y revisión separada.
Alternativa: sólo mantener la cola agrupada y el reproceso exacto manual, sin
collector programado ni borradores privados; es más lenta pero segura. Posponer
todo deja los mismos 7,028 registros y la cobertura estancada.

La recuperación de un scheduler es desactivar el flag/trigger y conservar el
ledger de decisiones; no borrar observaciones. Una migración aditiva se corrige
hacia delante; antes de activar escrituras verificar respaldo, versión previa del
Worker y la reversibilidad del lote. Una publicación incorrecta se retira por
estado y se audita; no se reescribe la evidencia original.

## Puerta de ejecución y aceptación

Antes de cualquier activación remota: identificar proyecto/entorno, revisar
permisos de fuente, migración y contratos completos, ejecutar preview y una
canaria limitada, comprobar auditoría, 401/403, conteos antes/después, exactitud
de una muestra y tasa de errores. Monitorizar varias corridas y detener ante
duplicados, caída de captura, colisiones o aumento de decisiones ambiguas.

**Aprobación concreta pendiente para la fase crítica siguiente:** activar un
scheduler de `crawler` exacto con filtro de fuente aprobada, actor auditable,
lote máximo 200, preview/canaria y kill switch. La
creación automática de borradores, recolección periódica y cualquier publicación
de ofertas requieren una aprobación posterior con sus fuentes, límites y pruebas.
Esta ADR no presume que una instrucción general de continuar cubra esas fases.
