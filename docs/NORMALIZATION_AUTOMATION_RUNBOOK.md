# Runbook: reducir la cola de normalización

## Operación delegada vigente — 13-oct-2026

**Corte vigente 14-oct, 13:15 UTC:** 41 revisiones, 325 aliases, 344 reglas
y 2,393 filas históricas; 4,635 pendientes / 844 grupos. Memoria shadow v3
reconstruida tras revalidar 35 entradas de cola: 2,393 contextos históricos
reutilizables y todos los pendientes requieren fuente. Se reconocen seis
metadatos de precio/extracción y se conserva `specialty` literalmente en la
firma, sin inferir atributos clínicos desde categorías inconsistentes. Los
84 pendientes con campos antes desconocidos pasan a investigación; no se
aprueba ninguno. Versiones v2 y v3 no son intercambiables: reconstruir memoria
y exportar contextos con la misma versión. Los controles sobre pacientes y
campos nuevos desconocidos siguen bloqueando. Recibos y comparación por UUID
en `collectors/artifacts/normalization-memory-after-review-41-v3/`; v2 intacta.

**Actualización 14-oct-2026, 12:55 UTC:** 40 revisiones aplicadas, 324 aliases,
343 reglas/contextos y 2,392 filas cerradas. Paginación completa de pendientes:
4,636 filas / 845 grupos; 4,552 requieren evidencia y 84 conservan campos
no reconocidos. Memoria y recibos en
`collectors/artifacts/normalization-memory-after-review-40/`. Ningún pendiente
coincide exactamente con una decisión reutilizable aprobada. La cola confirmó
34 ledgers por hash en recuperación sólo lectura tras una caída de DNS;
a las 13:03 UTC volvió al modo de ejecución de lotes revisados fijados por hash,
con 34 `already_applied` y ninguna escritura repetida.
El watcher reintenta únicamente consultas de ledger; nunca reenvía preview o
commit ante un fallo de conexión de resultado desconocido. Los cortes del 13-oct
que siguen conservan su fecha y no sustituyen esta actualización.

El usuario autorizó investigar nombres pendientes y decidir los casos claros sin
esperar confirmación rutinaria. Primero contrastar RAW, atributos canónicos y
fuentes primarias; después guardar alias, motivo, fecha y auditoría que identifique
al agente. Reutilizar el reproceso exacto acotado y comprobar que sólo seleccione
los registros revisados del crawler. Conservar pacientes/OCR fuera de ese lote.
La autorización no transforma una sugerencia fuzzy en equivalencia ni acredita
licencias comerciales o disponibilidad por sede.

Para reutilización entre estados se construyeron las herramientas locales
[de memoria y candidatos API](proposals/20261011-normalization-memory-and-apis.md).
Compilan únicamente revisiones con ledger completo y planifican sobre RAW
clínico conservado. El plan del corte 37 agrupa 4,742 filas en 860 trabajos de
investigación: 4,658 requieren evidencia y 84 conservan campos desconocidos.
Registra la siguiente acción y conserva pendientes sin detener
el resto. No tienen `apply`, no aprueban conceptos nuevos y no sustituyen el
ejecutor vigente. El adaptador NLM usa terminología pública seleccionada, caché
y un índice LOINC local con hash; no introducir órdenes de pacientes.

Las treinta y siete revisiones cerraron **2,286 filas** mediante 309 aliases
(286 globales y 23 de proveedor) y 271 nuevos conceptos de laboratorio. Sesenta
conceptos tienen código de muestra, 209 mantienen muestra desconocida y dos
conservan muestra literal sin código admitido: secreción mamaria y exudado
uretral. Quedan **4,742 filas / 860 grupos pendientes**; el catálogo tiene 460
conceptos.
El triage de sólo lectura distingue 828 brechas y 32 grupos con sugerencias;
los 860 conservan la puerta de política de fuente y 26, además, fuente oficial
sin verificar. Una sugerencia no aprueba equivalencia ni permisos comerciales.
Los atributos explícitos de cada fuente se conservan en RAW y decisión, sin
transferirlos a otras fuentes. Los 23 aliases limitados al proveedor conservan
su alcance clínico y de contexto; no ampliarlos a globales para aumentar la
resolución pública. Trece revisiones de identidad añadieron treinta marcas o
instituciones y 65 sedes pending; totales: 68 marcas / 152 ubicaciones.
Identidad, oferta, precio y disponibilidad siguen siendo hechos distintos.
Fixture, renderer, ensayo, recibos, límites y siguiente acción:
[operación Puebla](PUEBLA_LOCAL_OPERATION_20261009.md). El renderer fechado se
detiene si el lote ya se aplicó; revisar primero su recibo, no volver a ejecutar
para forzar el contador. El cron remoto y las capturas comerciales continúan apagados.
El [ejecutor local de revisiones](../database/scripts/run_local_review_queue.py)
vigila una cola explícita por hash cada cinco minutos y evita repetir lotes
aplicados al contrastar el ledger remoto. Completó las revisiones 08–37, con 32
corregida en una revisión nueva después de ensayo abortado; rollback,
commit acotado y comprobación posterior por revisión. Las revisiones 34, 35 y
37 cerraron 187 filas con 23 conceptos y 25 aliases; se observaron 44/44 consultas
públicas y 5/5 internas con proveedor. La revisión 36 cerró otras 34 filas y
se observaron 6/6 consultas públicas y 6/6 internas con proveedor; ledger
`applied_verified`. No se extrapolan esas consultas a variantes o recetas.
En el corte 37, las decisiones conservan familia sangre en 234 entradas
(232 SD y dos SEMIN), serum en 61 (32 SD y 29 SEMIN), plasma en dos, stool en
60 y urine en 76. Son atributos por entrada, no matrices heredadas del concepto.
La búsqueda local confirmó 41/43 aliases/nombres de las revisiones 12–13 y
61/61 de las revisiones 14–16, 43/43 de 17–18, 26/26 de 19–20 y 17/17 de 21 y 40/40 de 22–23 y 46/46 de 24–26 y 30/30 de 27–29;
T3 libre sigue excluido por un guard histórico del contrato clínico, registrado
para una corrección separada. Antiendomisio IgG devuelve `ambiguous` pero incluye
un candidato IgA incompatible: se registra para revisión del filtro clínico;
toxoplasma IgA también incluye IgG incompatible. Algunos `no_match` conservan
propuestas incompatibles; ese estado no acredita filtrar candidatos clínicamente.
No se interpreta como cobertura aprobada. Cerrar el crawler no acredita esa resolución pública.
El [diagnóstico de inmunoglobulinas](proposals/20261011-antibody-variant-candidates.md)
conserva respuestas y funciones vigentes; la propuesta sigue sin activar.
AFP-L3 seleccionó AFP genérica en HTTP local: [diff, alcance y recuperación](proposals/20261011-afp-l3-candidate-conflict.md)
preparados, pendientes de aprobación crítica; no se activaron funciones clínicas.
El lote 18 se detuvo antes del commit: el guard RAW incluía una fila PSA con
decisión terminal previa. Se corrigió el renderer para usar la misma elegibilidad
que el conteo (crawler sin decisión final). Diagnóstico rollback HTTP201: 83
selecciones, cero fuera de alcance; ledger aún vacío antes de reiniciar y luego
`applied_verified`. Conservar el handle/PID; si termina, comprobar ledger y causa
antes de reiniciar. No repetir el SQL para forzar un contador.
La revisión 21 añadió ocho analitos y conservó 40 filas abiertas por fracción o
metabolito inciertos. Ciclosporina C2 devuelve el analito genérico sin representar
estructuralmente el momento C2; no acredita equivalencia de resultados o valle.
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
Ante una discrepancia del ledger, conservar handle/estado y comprobar si el
commit existe antes de reiniciar. En el lote 25 el commit de 83 filas existía;
una sola decisión heredó familia sangre del targetSD a SEMIN. Se retiró únicamente
ese atributo, guardando su valor anterior y auditoría de corrección; el fixture
por hash, guardRAW, decisión y destino quedaron intactos. La cola terminal se
reinició después de corregir la causa y continuó sin reinsertar aliases.
La memoria v2 incluye el título de proveedor en la firma clínica; tres contextos
históricos permanecen retenidos por campos desconocidos. No ignorar `specialty`
para mejorar el contador. Los planes siguen sin apply.
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
Las revisiones 30–31 conservaron exactamente 109 contextos resueltos y 76 vecinos
pendientes. Veintitrés consultas públicas completas/globales resolvieron; cinco
aliases contextualizados resolvieron en el resolver interno con proveedor.
La ruta pública ignora el campo no soportado `provider_brand_id`: no usarlo en
una observación para atribuir contexto ni alterar su contrato. Los títulos
incompletos conservaron `no_match`. Memoria v2: 259 aliases/276 contextos y
1,924 históricos reutilizables de 1,927, con tres campos desconocidos retenidos.
No es una tasa sobre términos nuevos. PID 13072 con 25 entradas comprobado.
El arranque detecta `pythonw.exe` además de `python.exe`, preservando el ejecutor
existente; operación posterior devuelve `already_running`. Suites no ejecutadas.
El ejecutor no investiga ni aprueba nuevos
términos por sí mismo; el agente prepara y encola la investigación concluida.
Arranque, parada y límites: [operación local](OPERATIONS_GUIDE.md#cola-local-de-revisiones-investigadas).

### Preparar nuevos lotes investigados

[prepare_researched_alias_review.py](../database/scripts/prepare_researched_alias_review.py)
reutiliza el renderer y el ledger vigentes. Recibe definiciones investigadas, el
snapshot RAW completo y el informe de fuentes primarias; no investiga o decide
equivalencias por puntuación. Revalida RAW actual, pacientes, colisiones,
conteos y estado no aplicado antes de generar un fixture inmutable y SQL rollback.
Registra hashes de informe, definición y snapshot dentro de la revisión.
No sobrescribe un fixture existente ni añade entradas a la cola.

Para reutilizar una identidad investigada y ya existente, la definición puede
declarar `existing_catalog_item_id`. El preparador exige un ítem activo del dominio
de diagnóstico, tipo `lab_test` y nombre primario exactamente igual al investigado;
guarda `reused-identities-before.json` y no lo inserta en `new_concepts`. El agente
debe contrastar también componente, matriz, tiempo y variantes del concepto: el
control de nombre/tipo no acredita por sí solo equivalencia clínica. El recibo
separa `concepts` nuevos de `reused_concepts`; reutilizar no cambia atributos del
concepto ni autoriza crear un duplicado para eludir una colisión.

Los aliases `provider` sólo seleccionan los pares etiqueta/proveedor declarados.
El preparador conserva los contextos homónimos de otras fuentes en
`provider-contexts-outside-scope-before.json`, sin resolverlos con ese alias.
Los aliases globales y los nombres canónicos completos siguen comprobándose
contra todos sus contextos elegibles: si habilitan un registro no investigado,
el preparador se detiene. `source_attributes` pertenece a cada target; no copiar
suero, sangre, heces, orina o duración de un proveedor a otro.

### Conservar los bytes de la revisión en Git

El SHA256 del fixture identifica sus bytes exactos en la cola y en el ledger.
La regla `/database/data/*.json -text` de [.gitattributes](../.gitattributes)
evita que Git convierta LF/CRLF al guardar o recuperar estos archivos. Antes de
incluir una revisión en un commit, comparar los bytes/hash del fixture con su
recibo y con la versión que se vaya a versionar. No volver a serializar, cambiar
finales de línea o regenerar un fixture aplicado para eliminar una discrepancia;
conservar el original y resolver la causa. Esta regla no aprueba ni activa
decisiones clínicas, y no modifica archivos locales ignorados con secretos.
Los commits `8948671` y `724e183` conservan esta protección y la evidencia
versionada del corte; no acreditan cambios del resolver o una publicación remota.

### Ejecutar la preparación

Comando usado para preparar la revisión 32; conservar sus artefactos y elegir
otra fecha/sufijo para un lote nuevo, pues repetirlo debe detenerse:

```powershell
python -X utf8 database/scripts/prepare_researched_alias_review.py --project-ref ymtcmfgwuzdqtsbuvzqf --definition collectors/artifacts/puebla-expansion-20261009/clinical-research/review-32/definition.json --snapshot collectors/artifacts/puebla-expansion-20261009/clinical-research/review-32/all-raw-contexts-before.json --research-report collectors/artifacts/puebla-expansion-20261009/clinical-research/review-32/agent-research.md --fixture database/data/reviewed-aliases-20261012-03.json --artifacts collectors/artifacts/puebla-expansion-20261009/clinical-research/review-32
```

`definition.json` requiere `review_id`, `research_date`, `scope` y `definitions`.
Cada concepto declara nombre, componente, muestra/tiempo, fuente y motivo; sus
aliases declaran etiqueta, alcance y targets con proveedor, conteo y path RAW.
El preparador extrae la cadena completa del snapshot y comprueba atributos con
el renderer. Los casos con muestra/duración sólo en preparación conservan alias
de proveedor; incluir esos calificadores en el nombre canónico completo.
Para muestra literal sin código admitido, explicar la limitación en
`specimen_uncertainty`; no sustituirla por otra matriz.
Después revisar fixture/SQL/recibo y encolar por hash en el ejecutor existente.
Los 73 y 64 contextos iniciales de las revisiones 32–33 pasaron esta preparación.
El ensayo posterior 32 encontró un SEMIN de Giardia habilitado por el nombre
canónico completo: 74 elegibles frente a 73, cero no-crawler y ledger sin aplicar.
Se conservó el fixture original y se investigó ese contexto, creando una
revisión sustituta de 74 filas que pasó rollback/commit/ledger; el lote 33 aplicó 64.
El preparador ahora comprueba también contextos habilitados por los términos
canónicos nuevos antes de guardar el fixture final, y se detiene con su artefacto
si alguno no fue investigado. No retirar el guard de alcance del renderer.
Memoria del corte 37: 309 aliases / 328 contextos proveedor-alias / 2,286
históricos; 2,283 reutilizables y tres con campos desconocidos. En los 860 trabajos
pendientes, 4,658 filas requieren evidencia y 84 tienen campos desconocidos.
La observación shadow conservó exactamente los contadores 460 conceptos, 234
ofertas, 68 marcas, 152 ubicaciones y 112 migraciones antes y después. No modificó
cola o resolver clínico. Evidencia local ignorada:
`collectors/artifacts/normalization-memory-after-review-37/observation.json`.
El worker PID 2044 quedó `watching`; las tres apps locales respondieron HTTP 200.
Recibos de contadores, baseline, triage y operación:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-34/closing-*`.
La cola de 27 entradas mencionada en el corte 33 es histórica; no usarla como
contador actual ni inferir entradas desde el número de revisiones aplicadas.
No se ejecutaron suites formales ni se activó un nuevo algoritmo clínico.
Los conteos de septiembre abajo son antecedentes.

## Qué significa el número

El número que aparece en Admin es un conteo de registros de proveedores que
todavía no tienen una decisión final. No representa el número de pacientes,
estudios clínicos únicos ni pantallas que una persona deba abrir una por una.

La consulta remota de sólo lectura del 18-sep-2026 reportó 7,028 registros
abiertos: 6,804 de Salud Digna, 140 de SEMIN, 57 de Chopo y el resto de
proveedores pequeños. Esas filas están agrupadas en 1,188 combinaciones
proveedor+etiqueta de 8 proveedores: 967 grupos de Salud Digna, 140 de SEMIN,
57 de Chopo y 24 grupos de los demás proveedores. Los registros ya cerrados como
`no_match` se conservan para auditoría pero no forman parte del trabajo abierto.

## Qué es automático y qué no

1. El collector captura la fuente y conserva la evidencia original.
2. La normalización limpia, deduplica y agrupa por proveedor y etiqueta.
3. El reproceso exacto resuelve por lotes sólo cuando hay un único nombre
   canónico o un alias previamente aprobado.
4. Una aprobación manual de un alias de proveedor se reutiliza en futuros
   registros equivalentes; después el lote exacto puede resolver todas las filas
   que correspondan.
5. Una similitud fuzzy o una sugerencia de IA sólo ordena candidatos. No puede
   aprobar una equivalencia clínica.

La primera carga puede tener una cola grande porque el catálogo canónico todavía
no contiene las etiquetas observadas por cada proveedor. La automatización crece
con cada alias aprobado y con cada nueva corrida; no es seguro inventar esos
aliases sólo para hacer desaparecer el contador.

El corte read-only del proyecto enlazado `pruevia-dev` (base inicial productiva)
del 23-sep-2026 confirmó 7,028 filas y 1,188 grupos;
en los 100 grupos de mayor repetición, 94 no tenían candidato del resolvedor.
El [reporte](../database/reports/normalization_autonomy_opportunities.sql) reproduce
ese diagnóstico. La [ADR-004](ADR-004-NORMALIZATION-AUTONOMY.md) separa el triage
automático seguro de la creación de conceptos, equivalencias y publicación.
El script `pruevia-normalization-triage` es de sólo lectura; sus RPC se aplicaron
en `pruevia-dev` el 24-sep-2026 (proyecto que también sirve de base inicial
productiva) y pasaron dentro de la suite de contratos `518/518`. Puede generar
un JSON de revisión con `--output` y credenciales de servidor en
el entorno local ignorado, nunca en la línea de comandos ni en Git.
Ejemplo, desde `collectors`: `python -m pruevia_collectors.cli_normalization_triage
--env-file ../apps/api/.dev.vars --output artifacts/normalization-triage.json`.
La carpeta `artifacts/` está
ignorada. El reporte DEV del 24-sep produjo 1,188 grupos: 1,127 huecos de
catálogo, 61 con sugerencias léxicas útiles y cero coincidencias exactas. Los
1,188 grupos tienen política de fuente por revisar en su muestra representativa;
no son aprobaciones clínicas ni ofertas publicadas.
El [reporte por fuente](../database/reports/normalization_source_policy.sql)
verificó sobre todas las 7,028 filas que nueve fuentes permanecen en
`review_required`: 6,804 filas de Salud Digna, 137 de SEMIN, 57 de Chopo y 30
de seis fuentes adicionales. Todas tienen RAW, algún identificador externo y
URL con prefijo HTTPS, pero esa
presencia no equivale a permiso de uso ni a disponibilidad en cada sede. El
triage distingue 27 grupos de sitios clasificados como `public_website` de una
URL HTTPS ausente; no inferir una fuente oficial por el dominio sin revisarlo.
El [probe de identidad](../database/reports/normalization_sku_identity_probe.sql)
mostró que los 7,028 identificadores son distintos; la mayoría de Salud Digna
proviene de `provider_external_id`, no del campo `provider_sku`. El triage ya no
genera una clave de borrador por identificador: entrega un grupo de revisión
por proveedor+etiqueta y conserva el ID externo sólo como evidencia.

El 24-sep se endureció localmente `pruevia-publish`: su `--dry-run` valida
integridad del artefacto sin conexión a la base, y un manifiesto nuevo no puede
autodeclarar su fuente como `approved`. La fuente nace `review_required`; sólo
la política persistida y revisada en la base puede habilitar el camino exacto.
Esto no autoriza ni programa la captura: las nueve fuentes actuales siguen por
revisar antes de activar collectors automáticos.
El módulo local `pruevia-collector-preflight` está preparado para las fuentes
Chopo, Salud Digna y SEMIN: comprueba en la base, sin escribir ni rastrear, que
exista un único endpoint activo cuyo URL coincida con el adaptador, ligado a un
proveedor y con `usage_policy_status = approved`. Sus pruebas aisladas pasan;
falta probarlo con un DSN de sólo lectura o de operación en el entorno correcto.
No se activó el workflow ni hay scheduler de collectors ejecutándose.
Un runner local para SEMIN realiza una sola captura acotada únicamente si el
preflight acepta la fuente; usa bloqueo por fuente, timeout, validación y segunda
comprobación de política antes de guardar RAW en `ingest`. Permanece sin
activación remota. No se debe interpretar este piloto como cobertura o
automatización de todas las fuentes.
El [workflow preparado](../.github/workflows/collector-semin.yml) define una
ventana diaria a las 08:17 de Puebla, 20 minutos máximos, concurrencia por
fuente y permisos de repositorio de sólo lectura. Sólo ejecutaría el runner si
la variable de repositorio `PRUEVIA_COLLECTOR_SCHEDULE_ENABLED` fuera `true` y
existiera el secreto `PRUEVIA_COLLECTOR_DATABASE_URL`. No se configuraron ni
se probaron esas opciones externas; el archivo local no acredita una corrida.

La migración aplicada cierra también el puente entre RAW y la cola de
normalización: en un lote `apply`, materializa sólo ofertas `parsed` de
crawls exitosos, con endpoint/fuente activos, fuente oficial aprobada y una
única observación `offer.provider_display_name` que coincide con el texto del
RAW. Omite registros ya encolados, fuentes `review_required` y etiquetas de
ubicación; no crea ofertas, alias ni equivalencias. El preview no materializa.
Después, el mismo lote resuelve únicamente coincidencias exactas únicas y
aliases ya aprobados; lo demás queda en la cola Admin. El smoke aislado local
PostgreSQL 12 y el contrato remoto `26/26` prueban captura → cola → exacto,
abstención y replay. El Worker `pruevia-api` ya incluye esta ruta; el flag sigue
en `false`, por lo que no se ha ejecutado en producción. Hoy las nueve fuentes
siguen `review_required` y el corte no encontró exactos aprobados: el código no
va a vaciar por sí solo las 7,028 excepciones.

El preview read-only repetido el 25-sep-2026 en la base enlazada `pruevia-dev`
(base inicial productiva) volvió a reportar `backlog_total=7028`,
`eligible_total=0`, `materialized=0` y `processed=0`. No activar el cron mientras
no existan datos elegibles: el handler aplica y audita incluso un lote vacío.
El directorio DENUE sí aparece como fuente gubernamental `active/approved`, pero
su captura sólo añade ubicaciones RAW y no resuelve etiquetas de estudios. La
migración/RPC está aplicada y el Worker mensual está desplegado. Sigue apagado
(`DENUE_COLLECTION_ENABLED=false`) y requiere el token de API de INEGI como
secreto de Cloudflare antes de capturar. No recolecta teléfonos, correos ni sitios
web del directorio. El preview clínico permanece en cero elegibles; su cron
separado tampoco se activa.
Véase [Collectors: DENUE mensual](../collectors/README.md#denue-mensual-preparado-apagado).

## Triage ampliado de producción — 29-sep-2026

Se verificó que `apps/api/.dev.vars` apuntara al mismo ref enlazado de Supabase
de producción y se ejecutó `pruevia-normalization-triage` contra sus RPC de sólo
lectura. El archivo resultante está en
`collectors/artifacts/normalization-triage-production-readonly-20260929.json`
(artefacto local ignorado por Git). No se escribió en Supabase, no se aprobó un
alias y no se capturó ninguna fuente.

El corte sigue en 7,028 filas y 1,188 grupos: cero candidatos exactos únicos;
1,139 huecos de catálogo (6,805 filas) y 49 grupos con sugerencias fuzzy
(223 filas). Las 1,188 muestras de grupo siguen con `source_policy_not_approved`.
Por tanto, el reprocesamiento seguro sigue en cero elegibles.

El triage local ahora conserva el término/alias que produjo cada candidato,
cobertura de tokens y términos centrales, detalle que falta en el candidato,
conflictos detectables de modalidad, muestra, dirección anatómica, lateralidad,
clase de inmunoglobulina, vía y contraste. Excluye de `suggestions` y conserva
en `rejected_candidates` un fuzzy si detecta un conflicto explícito o si no
comparte ningún término central; eso sólo descarta ese candidato, no afirma que
la observación no tenga equivalencia ni la marca `no_match`.

En este corte, el triage apartó candidatos para 14 grupos únicos (87 filas):
16 candidatos sin término central compartido y 7 con contradicción explícita;
hay solapamiento entre esos motivos, por lo que no se suman como grupos. Casos
detectados incluyen RM frente a TAC, orina frente a suero y abdomen inferior
frente a superior. Las 49 sugerencias restantes siguen siendo pistas para
investigar, no decisiones ni equivalencias publicables. Se verificaron los
collectors: 185 pruebas pasan.

Esta iteración ayuda a rechazar propuestas obviamente incompatibles, pero no
puede crear el conocimiento que falta en 1,139 grupos: el catálogo actual no
contiene candidato suficiente y los IDs externos no son SKU estables. El camino
para minimizar revisión humana es obtener una fuente/feed autorizado con códigos
estables y atributos clínicos; mapear por código cuando exista una equivalencia
canónica verificada; reutilizar decisiones proveedor-etiqueta aprobadas; y
abstenerse cuando el nombre omita anatomía, muestra, protocolo o composición.
LOINC puede aportar candidatos para revisar, pero no sustituye una equivalencia
aprobada ni resuelve la política de uso de la fuente.

Antes de activarlo hay que revisar la fuente y ensayar la ingesta en el entorno
correcto, además de acordar alerta y responsable de fallos. Para detenerlo,
poner la variable en `false`; los registros ya capturados no se borran.

## Procedimiento operativo

### 1. Medir antes de tocar datos

Usar el reporte de sólo lectura:

```text
database/reports/puebla_normalization_backlog.sql
```

El resultado es una fila por proveedor y etiqueta normalizada, ordenada por el
número de registros que puede desbloquear una decisión.

### 2. Ejecutar el camino seguro

Desde el resumen del Admin:

- **Analizar coincidencias** hace un preview y no modifica datos.
- **Resolver seguras** aplica como máximo 200 coincidencias exactas o aliases
  aprobados, con auditoría e idempotencia.
- Repetir en lotes sólo después de revisar el preview y la evidencia.

El RPC manual es `public.api_admin_reprocess_exact_normalizations`. Los casos ambiguos,
los nombres no únicos y los conceptos clínicamente distintos permanecen en la
cola.

El reproceso manual está disponible en el Admin local autorizado; las revisiones
investigadas usan además el ejecutor local por hash y ledger descrito arriba.
Admin/API públicos permanecen pausados desde el 25-sep-2026. El scheduler
preparado en `pruevia-api` tiene trigger horario, pero permanece
deshabilitado por `NORMALIZATION_REPROCESS_ENABLED=false`. El Worker llama
exclusivamente a
`public.api_admin_reprocess_exact_crawler_normalizations`, con filtro de fuente
aprobada. La migración y su contrato ya están aplicados/verificados. No encender
el flag hasta revisar las políticas de las fuentes, hacer preview/canaria y
acordar monitoreo; ninguna fuente se autoriza por el solo hecho de desplegar.
Además, el Worker necesita `ALLOWED_ORIGINS`/`ALLOWED_ORIGIN` con orígenes HTTPS
reales para responder tráfico de producción; no se debe resolver configurando `*`.
Para activarlo debe existir un actor administrativo configurado, límite por
corrida, idempotencia, auditoría y una ventana de monitoreo. El scheduler sólo
aplica exactos/aliases aprobados; nunca aprueba fuzzy matching.

### 3. Revisar por impacto

Priorizar etiquetas repetidas que tengan una fuente oficial y una equivalencia
clara. Al aprobar un alias se debe conservar el proveedor, el estudio canónico,
la razón y la evidencia. Si faltan datos para decidir, conservar el pendiente o
la ambigüedad con el dato faltante; `no_match` requiere evidencia que respalde
esa decisión, no sólo ausencia de un candidato seguro. No publicar una oferta
a partir de la aprobación terminológica.

La migración está aplicada. D-021/D-022 y la instrucción concreta de la sesión
cubren los lotes claros investigados dentro de su alcance; no volver a pedir la
misma autorización rutinaria. Un cambio del contrato clínico común, de permisos,
de políticas comerciales o la activación del scheduler requiere su aprobación
crítica específica. El contrato del piloto Android pasó `22/22` en septiembre en
la base enlazada `pruevia-dev` (base inicial productiva); ese antecedente no
acredita una nueva activación.

## Correo de soporte con Cloudflare

Cloudflare Email Routing permite crear una dirección como
`soporte@tudominio.com` y reenviar el correo entrante a una dirección verificada
de Gmail u Outlook. No crea por sí solo un buzón completo con IMAP, contraseña o
una bandeja independiente.

Pasos:

1. Agregar el dominio a Cloudflare y verificar que sus DNS estén activos.
2. En Email Routing, agregar y verificar la dirección de destino personal.
3. Crear la regla `soporte@tudominio.com` → destino verificado.
4. Configurar el landing con `PRUEVIA_SUPPORT_EMAIL`.
5. Si Pruevia debe enviar correos automáticos, contratar/configurar un servicio
   de envío separado; el reenvío de entrada no sustituye SMTP o una API de correo.

No guardar contraseñas ni tokens en `apps/landing/.env` versionado. El valor de
`PRUEVIA_SUPPORT_EMAIL` sí puede ser público porque sólo es una dirección de
contacto.
