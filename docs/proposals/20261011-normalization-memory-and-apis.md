# Memoria de normalización y alternativas API

Fecha: 11-oct-2026. Entorno: herramientas locales y consultas de sólo lectura
al proyecto Supabase enlazado, usado también por producción. Investigación
solicitada por el operador; después pidió construir lo propuesto aunque la
carga inicial del catálogo sea el trabajo más costoso.

## Resultado y decisión de implementación local

Construir un catálogo clínico compartido entre estados y conservar decisiones
reutilizables tiene sentido. Cambiar de Puebla a Querétaro no requiere duplicar
un mismo analito. La investigación inicial de ese analito se puede reutilizar;
la identidad del proveedor, su definición particular, sedes, ofertas, precios
y disponibilidad siguen siendo hechos propios de cada fuente.

Se implementaron dos herramientas ejecutables:

- [normalization_memory.py](../../database/scripts/normalization_memory.py):
  compila sólo fixtures cuyo ledger remoto completo coincide con la revisión
  aplicada. Conserva hashes, fuentes, razones, proveedor, atributos revisados
  y firmas del contexto clínico observado. Planifica reutilización y agrupa
  trabajo pendiente; no escribe decisiones ni publica ofertas.
- [clinicaltables_candidates.py](../../database/scripts/clinicaltables_candidates.py):
  consulta terminología pública previamente seleccionada en NLM, guarda recibos
  y caché, y puede recuperar los atributos de los códigos desde el índice LOINC
  local comprobando su SHA-256. Ninguna respuesta se convierte en aprobación.

Estos comandos funcionan por ejecución; no se instaló un nuevo scheduler ni
se conectaron a la búsqueda paciente. La cola local anterior continúa aplicando
únicamente los lotes investigados que alguien encola explícitamente por hash.
La investigación automática de cualquier término nuevo todavía no está
implementada. En el corte inicial de 23:42 UTC las revisiones 22–23 conservaban
sólo su lectura; su aplicación posterior queda en la actualización de abajo.

## Evidencia obtenida

Artefactos locales ignorados: `collectors/artifacts/normalization-memory-20261011/`.
La memoria se compiló a las 23:42 UTC, verificando las veintiuna revisiones
contra la base antes de incorporar sus fixtures.

| Observación | Resultado | Alcance |
| --- | --- | --- |
| Memoria comprobada contra ledger | 184 aliases; 193 contextos proveedor/alias; 1,360 filas históricas | No equivale a cobertura comercial. |
| Plan sobre contexto histórico | 1,358 reutilizables; dos con campos desconocidos | Reejecución de datos ya decididos, no evaluación de casos inéditos. |
| Plan sobre toda la cola abierta | 5,583 requieren evidencia; 85 con campos de fuente desconocidos | Total 5,668; cero nuevas aprobaciones. |
| Cola de investigación agrupada | 995 trabajos con causa y siguiente acción | Evita investigar cada una de las 5,668 filas por separado. |
| NLM, vocabulario público seleccionado | Doce respuestas HTTP 200; once búsquedas con candidatos | No mide precisión clínica ni cobertura de Puebla. |
| Caché de NLM | Segunda ejecución reutilizó las doce respuestas sin consultas nuevas | Caché de siete días; fallos no se reutilizan como éxito. |
| Contadores antes/después | 346 conceptos, 234 ofertas, 5,668 pendientes, 56 marcas, 133 ubicaciones, 112 migraciones | Permanecieron iguales. |

Las dos retenciones históricas son `ultrasonido abdomen superior`, con campos
`evidence_method`, `evidence_page_url`, `provider_brand_hint`, y `ac iga anti
endomisio`, con `discount_text`, `page_number`, `price_text`, `specialty`. Algunos
son comerciales o de procedencia; `specialty` podría aportar contexto. No se
agregaron a una lista de campos ignorados para mejorar el contador.

Recibos: `memory.json`, `historical-shadow.json`, `pending-contexts.json`,
`pending-shadow.json`, `observation.json`, `nlm-observations.json`,
`nlm-with-local-details.json` y `nlm-cache/`. `observe.py` describe la lectura
remota y la ejecución local. No se ejecutaron suites ni se añadieron pruebas.

## Opciones investigadas

| Opción | Utilidad para Pruevia | Acceso y límites comprobados | Elección |
| --- | --- | --- | --- |
| Índice LOINC local existente | Buscar candidatos y consultar los seis ejes clínicos con una versión fijada | Ya existe 2.83: 64,776 términos laboratorio, SHA-256 comprobado | Base de apoyo, sin dependencia de red en cada búsqueda. |
| NLM Clinical Tables | Buscar códigos y nombres alternativos mediante JSON | Gratuito, sin registro; sin garantía mínima de disponibilidad; licencia LOINC y posibles derechos externos | Adaptador local construido, con caché y salida sólo como candidatos. |
| LOINC FHIR oficial | Consultar códigos, traducciones y conjuntos de órdenes | Cuenta gratuita; servicio documentado como beta y no recomendado por su titular para producción | Apoyo de investigación; no dependencia de la búsqueda pública. |
| UMLS REST | Buscar vocabularios y relacionar conceptos | Requiere cuenta/licencia y API key | Alternativa posterior; no se crearon cuentas ni se hicieron llamadas autenticadas. |
| IMO Precision Normalize | Normalizar términos de laboratorio usando contexto estructurado | Requiere credenciales OAuth y acceso de producto; precio y cobertura es-MX no comprobados | Alternativa especializada más directamente pertinente; no contratada ni invocada. |
| Health Language / Apelon | Gestión de terminología y mappings | Documentación comercial consultada; precio y rendimiento en nuestros datos no comprobados | No añadir una plataforma antes de medir un beneficio concreto. |
| Feed autorizado del proveedor | Obtener la definición local, muestra, composición, sede y disponibilidad | Depende de cada institución y del alcance del convenio | Mayor valor para completar información ausente; una API terminológica no reemplaza este dato. |

Fuentes primarias:

- [NLM: API LOINC](https://clinicaltables.nlm.nih.gov/apidoc/loinc/v3/doc.html)
  y [condiciones operativas](https://clinicaltables.nlm.nih.gov/faq.html).
- [LOINC FHIR](https://loinc.org/kb/api/fhir),
  [licencia](https://loinc.org/kb/license) y
  [conjuntos de órdenes](https://loinc.org/kb/api/fhir/valueset).
- [UMLS: autenticación](https://documentation.uts.nlm.nih.gov/rest/authentication.html)
  y [búsqueda](https://documentation.uts.nlm.nih.gov/rest/search/index.html).
- [IMO: guía técnica de normalización](https://developer.imohealth.com/api-catalog/imor-precision-normalize-api/classic-guide).
- [Health Language](https://www.wolterskluwer.com/en/solutions/health-language/data-quality/maintain)
  y [Apelon](https://apelon.com/).

IMO documenta un dominio Lab que recibe componente, propiedad, momento,
muestra, escala, método y unidad. Devuelve uno o varios candidatos puntuados;
sus umbrales sugeridos no son una validación en nuestro catálogo ni autorizan
equivalencias clínicas. Su endpoint Enrichment es para problemas/diagnósticos;
el endpoint Classic es el pertinente para laboratorio. No se comprobó soporte
de términos mexicanos ni un precio público aplicable a Pruevia.

Se revisó OLS de EMBL-EBI como búsqueda general de ontologías, sin establecer que
su contenido reemplaza el catálogo LOINC ni obtener mappings locales. No se
implementó un adaptador adicional por esa consulta.
[Documentación OLS](https://www.ebi.ac.uk/ols4/api-docs).

## Lo que las observaciones de NLM cambian

En este conjunto seleccionado, `calcitonina` devolvió cero candidatos mientras
`calcitonin` devolvió 60. La traducción o un diccionario bilingüe revisado son
necesarios; no atribuir cobertura automática es-MX a la API por estar abierta.

`cyclosporine 2 hours` devolvió tres códigos, incluyendo uno de dos horas y otro
de 24 horas. `digoxin free` incluyó anticuerpos inducidos por digoxina junto a
digoxina libre. `oxcarbazepine` incluyó tanto el compuesto como una combinación
con 10-hidroxicarbazepina. La primera fila de `troponin I` era un panel.
Buscar un término no equivale a elegir su orden individual correcta.

Se unieron los códigos por identidad exacta con el índice local 2.83 para
inspeccionar atributos. Un código ausente se marca como ausente: no se
completan sus atributos por parecido ni se afirma que NLM usa la misma release.
La consulta externa devuelve como máximo siete candidatos en este adaptador;
el total informado es una estimación del servicio, no un conteo de códigos
analizados por Pruevia.

La lista oficial `top-lab-orders` merece consideración para priorizar órdenes
comunes. Su existencia está documentada; no se descargó ni se importó en este
corte. Una cifra de cobertura estadounidense no demostraría cobertura de Puebla.

## Algoritmo local construido y siguiente ampliación

1. Cargar revisiones cuyo ledger coincide íntegramente y fijar bytes/hashes.
   Nunca incorporar un borrador sólo porque apareció en un directorio.
2. Comparar etiqueta exacta, proveedor y firma del contexto clínico. La firma
   conserva nombre original, preparación, descripción y muestra, entre otros
   campos; no depende del precio o del municipio. Una variante, cambio de
   contexto, campo desconocido o colisión retiene el caso.
3. Para otro proveedor, reutilizar aliases globales como candidatos. Los aliases
   limitados al proveedor permanecen limitados. No transferir su muestra,
   método, preparación o disponibilidad a una institución nueva.
4. Agrupar pendientes por proveedor, etiqueta y causa; registrar la siguiente
   acción y que debe reintentarse al cambiar definición o versión de reglas.
   El procesamiento de un caso pendiente no detiene el resto del lote.
5. Buscar candidatos externos sólo con terminología pública seleccionada,
   sin órdenes de pacientes. Usar caché y atributos de una release fijada.
6. Ampliación pendiente: recolector de evidencia nueva, reglas clínicas
   versionadas y validadas para familias concretas, y ejecución automática
   autorizada que use el renderer/ledger existentes. No aprobar mediante
   votación de modelos, score, primera fila o muestra habitual de otro laboratorio.

La memoria caduca en 24 horas y debe recompilarse para volver a comprobar
aliases activos y decisiones. Antes de una futura escritura deberán volver a
validarse contexto, estado de catálogo, conflictos, alcance, fuente, preview,
idempotencia y ledger. La firma actual es una herramienta de planificación,
no prueba de equivalencia de resultados ni de que una oferta sea publicable.

## Ejecución reproducible

Desde la raíz, con el entorno local ya configurado; no imprimir credenciales:

```powershell
python database/scripts/normalization_memory.py build `
  --project-ref ymtcmfgwuzdqtsbuvzqf `
  --output collectors/artifacts/normalization-memory-20261011/memory.json

python database/scripts/normalization_memory.py plan `
  --memory collectors/artifacts/normalization-memory-20261011/memory.json `
  --input collectors/artifacts/normalization-memory-20261011/pending-contexts.json `
  --output collectors/artifacts/normalization-memory-20261011/pending-shadow.json

python database/scripts/clinicaltables_candidates.py `
  --terms collectors/artifacts/normalization-memory-20261011/public-terms.json `
  --cache collectors/artifacts/normalization-memory-20261011/nlm-cache `
  --loinc-index database/artifacts/loinc/2.83/loinc_lab_active.jsonl `
  --output collectors/artifacts/normalization-memory-20261011/nlm-with-local-details.json
```

Los archivos de entrada y recibos son locales ignorados; `public-terms.json`
contiene exclusivamente nombres genéricos seleccionados. El marcador de
terminología pública es una declaración del autor del fixture, no un detector
automático de datos personales. No introducir datos de pacientes.

## Actualización después de las revisiones 22–23

12-oct-2026 00:04 UTC, correspondiente a 11-oct local. Se recompiló la memoria
contra 23 revisiones aplicadas: 204 aliases, 214 contextos proveedor/alias y
1,521 filas. El plan reconoce 1,519 históricos y retiene dos por campos
desconocidos. Sobre los 5,507 pendientes: 5,422 requieren evidencia y 85 tienen
campos no contemplados, agrupados en 974 trabajos. No es precisión en casos nuevos.

Artefactos: `collectors/artifacts/normalization-memory-after-review-23/`,
incluidos `memory.json`, `historical-shadow.json`, `pending-shadow.json` y
`observation.json`. Las herramientas no escribieron decisiones. Las 161 nuevas
decisiones se investigaron y aplicaron separadamente por el ejecutor anterior;
el nuevo plan no fue su autor. Los contadores antiguos de la tabla conservan
el corte inicial, no describen el último catálogo.

## Actualización después de las revisiones 24–26

12-oct 05:40 UTC, 11-oct local. Memoria **shadow v2** recompilada contra 26 ledgers:
228 aliases, 243 contextos proveedor/alias y 1,690 filas. Ahora conserva también el
título literal provider_display_name como parte clínica de la firma: v1 debe
recompilarse. Plan histórico 1,687 reutilizables/tres campos desconocidos;
Chopo Mn urinario es la tercera retención, con specialty y campos no contemplados.
No se ignoraron para mejorar el contador. Pendientes 5,338:5,254 necesitan evidencia
y 84 campos desconocidos, agrupados en 945 trabajos. No mide casos inéditos.

Artefactos `collectors/artifacts/normalization-memory-after-review-26/`:
memory/historical-shadow/pending-shadow/observation/held-contexts. Contadores
antes/después iguales: 388 conceptos, 234 ofertas, 5,338 pendientes, 59 marcas,
138 ubicaciones, 112 migraciones. Nuevos cierres 169 investigados separadamente,
no aprobados por el plan. LAC añadió dos sedes pendientes, sin ofertas.
Renderer local corrigió herencia de atributos entre proveedores: el ledger detectó
una diferencia después del commit 25; se auditó una rectificación de metadatos
sin volver a aplicar aliases. Cola activa con 20 entradas, proceso 9604 vivo.
No se activaron investigación automática inédita, contratos clínicos, scheduler
nuevo, servicio pagado ni publicación externa.

## Actualización después de las revisiones 27–29 — 12-oct

Memoria shadow v2 revalidada: 29 revisiones, 244 aliases, 259 contextos y
1,818 filas históricas. Plan: 1,815 reutilizables/tres campos desconocidos;
cola 5,210: 5,126 requieren evidencia/84 campos desconocidos, 929 trabajos.
No mide términos inéditos ni aprueba equivalencias. Contadores antes/después
iguales: 402 conceptos, 234 ofertas, 61 marcas, 140 ubicaciones, 112 migraciones.
Los 128 cierres y dos hospitales nuevos provienen de investigación/aplicación
separadas. El renderer conserva el motivo completo en auditoría cuando su nota
de referencia no cabe en el límite existente de 1,000 caracteres; constraints
intactos y hashes de fixtures sin cambios. Cola activa con 23 entradas, PID 5280.
Scl-70 IgM/GABA-A aún presentan candidatos incompatibles bajo ambiguo: no activar
el filtro clínico ni afirmar que todos los atributos están protegidos.
Artefactos `collectors/artifacts/normalization-memory-after-review-29/`.
Sin nueva API pagada, scheduler, investigación automática inédita o publicación.

## Actualización después de las revisiones 30–31 — 12-oct local / 13-oct UTC

Memoria v2 recompilada contra 31 ledgers: **259 aliases, 276 contextos y 1,927
filas históricas**. El plan reconoce 1,924 históricos y retiene tres con campos
desconocidos. Sobre 5,101 pendientes: 5,017 requieren evidencia y 84 campos
desconocidos, en 912 trabajos. Sin precisión afirmada sobre términos inéditos.
Contadores de la observación antes/después iguales: 415 conceptos, 234 ofertas,
63 marcas, 145 ubicaciones y 112 migraciones.

Los 109 cierres, trece conceptos y quince aliases nuevos proceden de investigación
y aplicación separadas. Cinco aliases conservan contexto de proveedor porque
el título omite muestra/duración que sí figura en preparación: 17-KS SD/SEMIN,
5-HIAA, VMA y cortisol libre. Los canónicos completos siguen compartidos.
Se comprobaron 23/23 consultas públicas completas/globales y 5/5 contextuales
en el resolver interno; la ruta pública no acepta `provider_brand_id`, por lo
que las cinco llamadas iniciales con ese campo sólo observaron búsqueda genérica.
Se conservan evidencia y aclaración, con `no_match` en los títulos incompletos.

La identidad 11 añadió Bio-Velab3/Medic Scanner2 pendientes, no cobertura comercial.
El helper de arranque ahora reconoce `pythonw.exe` y conserva al ejecutor vivo
PID13072 con 25 entradas; la ejecución posterior confirmó `already_running`.
Artefactos `collectors/artifacts/normalization-memory-after-review-31/` y
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-30/`.
No se activaron contratos clínicos, investigación automática inédita, servicios
pagados, publicación, scheduler nuevo o suites formales.

## Actualización después de las revisiones 32 corregida/33 — 13-oct

Memoria v2 contra33 revisiones aplicadas: **278 aliases, 295 contextos y 2,065
filas**. Plan histórico2,062 reutilizables/tres campos desconocidos. Pendientes
4,963:4,879 requieren evidencia/84 campos desconocidos, agrupados en893 trabajos.
Contadores de la observación antes/después iguales:432 conceptos,234 ofertas,
65 marcas,149 ubicaciones,112 migraciones. No mide precisión sobre casos nuevos.

Se construyó [un preparador reutilizable](../../database/scripts/prepare_researched_alias_review.py)
para generar fixtures a partir de definiciones e investigación terminadas.
Revalida RAW, pacientes, conteos, colisiones y ledger; fija hashes de informe,
definición y snapshot. No elige equivalencias nuevas por puntuación. El primer
ensayo32 abortó por un SEMIN de Giardia habilitado por el nombre canónico.
Ledger sin aplicar, cero no-crawler y RAW extra leído; fixture/hash original
preservados y revisión sustituta de74filas aplicada junto al lote33 de64.
El preparador ahora comprueba también contextos habilitados por nombres
canónicos antes de generar el fixture final; el guard del renderer sigue intacto.

Los 138 cierres, diecisiete conceptos/diecinueve aliases y las cuatro sedes
Tlatlauquitepec/La Paz proceden de investigación/aplicación separadas.
33/33 consultas públicas completas/globales y3/3 internas con proveedor
resolvieron; sesenta vecinos retuvieron sus UUID pendientes. HBe corto y MOGIgG
siguen con candidatos incompatibles o generales bajo ambiguo; Cdiff PCR/B sola
conserva candidato de toxinas conjuntas bajo no_match. No afirmar filtrado total.
Cola27entradas/PID2044 recuperada tras diagnóstico y ausencia del proceso previo.
Artefactos `collectors/artifacts/normalization-memory-after-review-33/` y
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-32-revised/`.
Sin activación clínica, investigación automática inédita, servicio pagado,
nuevo scheduler, oferta, migración, publicación o suites formales.

## Activación y recuperación

### Corte de memoria actualizado — 13-oct-2026, 13:01 UTC

37 revisiones aplicadas: **309 aliases / 328 contextos / 2,286 históricos**.
Plan histórico: 2,283 reutilizables y tres con campos desconocidos. Pendientes:
4,658 requieren evidencia y 84 conservan campos no contemplados, agrupados en
860 trabajos. Lectura completa y contadores antes/después iguales: 460 conceptos,
234 ofertas, 68 marcas, 152 ubicaciones y 112 migraciones. Artefactos:
`collectors/artifacts/normalization-memory-after-review-37/`.

Los 221 nuevos cierres de 34–37 proceden de investigación y ejecución separadas;
el plan shadow no los aprobó. SARS-CoV-2 y lactato reutilizaron identidades
existentes sin mutarlas. El preparador admite ese ID explícito sólo después de
comprobar nombre primario, dominio, estado activo y tipo lab_test; los límites
clínicos siguen requiriendo evidencia del investigador. Los aliases de proveedor
no incluyen otros proveedores; sus contextos excluidos se conservan, y nombres
canónicos/aliases globales siguen sujetos al control global de alcance.
No hay API pagada, investigación inédita automática ni modificación del resolver.

Las herramientas de memoria/candidatos no modificaron resolver, migraciones,
políticas, cron, cola ejecutable, publicación o contratos comerciales. Sólo leen y escriben
artefactos locales; retirar sus invocaciones deja la operación anterior intacta.

Activar nuevas decisiones clínicas automáticas o cambiar el resolver compartido
requiere una propuesta concreta de cambio crítico según AGENTS y D-006. Las
propuestas separadas de T3 libre, AFP-L3, inmunoglobulinas y diagnóstico C2
permanecen pendientes. Este documento no activa esos cambios ni los sustituye.

Siguiente acción: continuar la carga inicial de familias clínicas con evidencia
y conservar cada decisión en esta memoria; después medir reutilización sobre
nuevas capturas y proveedores antes de prometer una tasa de autonomía.
