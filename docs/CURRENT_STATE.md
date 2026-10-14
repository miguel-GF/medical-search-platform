# Estado y prioridades de Pruevia

Tipo: punto de continuidad. Actualizado el 14-oct-2026 para operación local y datos;
el corte de publicación siguiente corresponde al 25-sep-2026 sobre el árbol local, el
ledger Supabase y los Workers de producción. El proyecto enlazado se llama
`pruevia-dev`, pero también es la base inicial de producción: las migraciones
aplicadas allí afectan el catálogo público. Landing, PWA, API y Admin privado se
habían publicado en sus dominios finales. Desde el 25-sep-2026 la API, la PWA y
el Worker Admin están pausados; sólo el landing permanece activo. Proveedores,
feedback, analítica y registro Android continúan cerrados.
Los datos de septiembre citados abajo son cortes de evidencia, no contadores en vivo.
Advertencia de entorno: el proyecto Supabase enlazado se llama `pruevia-dev`, pero
la [decisión de publicación](ADR-003-PATIENT-FIRST-PUBLICATION.md) lo usa como
base inicial de producción. Una escritura o migración allí afecta datos que
podría consultar el sitio público; el nombre DEV no ofrece aislamiento.

## Cómo leer el estado

**Corte completo vigente, 14-oct 13:15 UTC:** 41 revisiones aplicadas,
325 aliases, 344 reglas/contextos y 2,393 filas históricas cerradas. Paginación
íntegra: 475 conceptos, 4,635 pendientes en 844 grupos y 1,162 términos;
69 marcas, 153 ubicaciones, 234 ofertas y 112 migraciones. Memoria shadow v3
reconstruida con los 35 ledgers/hashes de cola: los 2,393 contextos históricos
son reutilizables; los 4,635 pendientes requieren evidencia, ninguno fue
aprobado por la memoria. Se reconocieron seis metadatos administrativos de los
collectors y se preservó `specialty` como contexto literal, sin inferir modalidad,
muestra ni composición. Los 84 pendientes antes bloqueados por esquema pasan
a investigación; los tres históricos antes bloqueados se reconocen exactamente.
Los ocho artefactos principales v2 permanecen intactos. Evidencia en
`collectors/artifacts/normalization-memory-after-review-41-v3/`; sólo lecturas
y planificación, sin cambios del resolver, ofertas o permisos ni suites formales.

**Última revisión aplicada, 14-oct 13:12 UTC:** ASO SEMIN cerró una fila,
con suero, aglutinación y escala semicuantitativa explícitos. Catálogo 475;
pendientes 4,635. El alias es exclusivo de SEMIN: correcto con scope de
proveedor; su forma sin scope no se presenta como resuelta públicamente.
Canónico público correcto, 16 vecinos SD pendientes y anti-DNasa B íntegros.
La cola conserva 35 revisiones por hash, worker único observado tras verificar
su predecesor idle y terminal. Evidencia en
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-41-semin-aso/`.

**Corte completo anterior, 14-oct-2026 12:55 UTC:** 40 revisiones clínicas aplicadas,
324 aliases investigados y 2,392 filas históricas cerradas. Paginación completa:
474 conceptos activos y 4,636 pendientes en 845 grupos; 234 ofertas, 68 marcas,
152 ubicaciones y 112 migraciones. Las revisiones 38–40 cerraron 106 filas con
14 conceptos nuevos. El original `reviewed-aliases-20261014-02.json` no se aplicó;
su sustituta `20261014-04` conserva el suero explícito del Western blot VIH-1
de SEMIN. Memoria: 343 reglas/contextos, 2,389 contextos históricos reutilizables
y tres con campos no reconocidos. Ningún pendiente tiene reutilización exacta
aprobada: 4,552 requieren evidencia y 84 tienen campos no reconocidos. Los
recibos están en `collectors/artifacts/normalization-memory-after-review-40/`
y `collectors/artifacts/puebla-expansion-20261009/clinical-research/`
(`review-39-revised/`, `review-40/`).
La recuperación sólo lectura confirmó los 34 ledgers por hash; no repitió
commits durante la caída de DNS. Después de verificar ese cierre y detener el
único observador, la cola volvió a vigilancia con ejecución de lotes revisados
habilitada a las 13:03 UTC: 34 `already_applied`, ninguna escritura repetida.
El resolver clínico permanece sin cambios. Las cifras del 13-oct que
siguen son antecedentes fechados, no el inventario actual.

**Paciente local, 14-oct:** búsquedas generales «sangre» y «orina» muestran
opciones para precisar el estudio, diferenciando examen general, cultivo y
recolecciones de 24 horas. No seleccionan estudios de una orden ni afirman
ofertas. GET reales y capturas de escritorio/móvil están en
`collectors/artifacts/specimen-search-20261014/`; cero errores de página en la
observación. El servidor local compila Flutter debug y sirve sólo loopback con
CanvasKit y Roboto incluidos. Cuando falla la consulta remota, las opciones
previamente verificadas se etiquetan como catálogo revisado el 14-oct, sin
afirmar proveedores disponibles. Los fallos de permisos/configuración no usan
esa alternativa. Sin publicación ni suites formales.

**Identidad 14, 14-oct:** Sanatorio Gutiérrez (DENUE 3441877) incorporado con
una marca `verification_pending` y un hospital `pending`: 69 marcas y 153
ubicaciones. Dirección 12 Norte 1805A y coordenadas DENUE conservadas;
el directorio estatal omite la letra A, sin borrar ese dato. Sitio propio no
acreditado, `website_url=NULL` con incertidumbre explícita. Rollback, commit
único, vínculo DENUE, auditoría, observación y RAW íntegro comprobados en
`collectors/artifacts/puebla-expansion-20261009/identity-review-14/`.
Ofertas 234 y migraciones 112 intactas; no acredita cobertura comercial.

**Casos con estructura adicional preparados, sin activar:** ocho RAW de
clearance SD requieren sangre y orina, con 24 horas sólo para la recolección
urinaria; un cotesting Chopo requiere padre de panel y dos componentes.
SQL rollback v2, ledgers completos, guardas y excepciones explícitas de hijos
sin alias están en `clinical-research/ambiguity-resolution-20261013/model-draft/`
dentro de `collectors/artifacts/puebla-expansion-20261009/`. Son nueve filas
preparadas, no cierres. No se afirma que el resolver o paciente ya represente
todos esos requisitos; contrato clínico y ejecución siguen separados bajo D-006.

**Operación local y datos (13-oct-2026):** con autorización expresa se reanudó
la misma base productiva enlazada, encontrada `INACTIVE`; quedó `ACTIVE_HEALTHY`,
PostgreSQL 17.6, ledger 112. API/Admin/Paciente corren en localhost
8787/5173/8080 y respondieron `200`. Se cargó la descarga oficial DENUE Puebla
del 20-may-2026: 13,747 establecimientos de salud, 217 municipios y 69,426
observaciones, comprobados en la base tras 157 lotes. Es evidencia de identidad,
no cobertura de estudios. Se investigaron y aprobaron 309 aliases exactos y 271
conceptos ausentes, cerrando 2,286 filas del crawler; quedan 4,742 filas en 860 grupos.
Se añadieron treinta marcas/instituciones en verificación y 65 sedes pendientes: Gubia, ROSMA,
Robert Koch, CEDITSA, Cervantes, Biomédicos, Mexica, IB, CEEAD, Páez, GARDITEX,
Betania, Hospital Angeles, MAC, Hospital Puebla, Beneficencia Española,
IMSS-Bienestar, ISSSTE, Samalab, Omega, LAC, Hospital Independencia, Sanatorio Humboldt,
Bio-Velab, Medic Scanner, Tlatlauquitepec, Unidad Hospitalaria La Paz, Hospital
Guadalupe de Puebla, Hospital Vilaseca Esparza y Laboratorio Clínico de Tepeaca.
Ahora hay 68 marcas y 152 ubicaciones registradas. Zacatlán
se enlazó a IMSS-Bienestar existente, conservando íntegra esa marca. No hubo
nuevas ofertas, capturas comerciales, migraciones ni despliegues de Workers.
Un ejecutor local vigila cada cinco minutos la cola de lotes investigados fijados
por hash; aplicó y verificó las revisiones 08–37, incluida la sustituta de 32.
209 conceptos nuevos conservan muestra desconocida; dos conservan secreción
mamaria o exudado uretral literales sin código específico. Sesenta tienen código
de muestra. Veintinueve entradas de SEMIN conservan su suero explícito y 232
entradas de Salud Digna la familia sangre en RAW/decisión.
Cuatro entradas SEMIN conservan sangre total en su guard RAW: sirolimus, mercurio
con su cadena original `Sngre`, Coombs directo y HLA-B27; las dos últimas registran
sólo la familia sangre. Sin código de sangre total ni suero inferido.
Una entrada TGO/AST de SEMIN continúa abierta por contradicción de muestra;
también ocho entradas calcio sin forma y una testosterona sin fracción.
Cuarenta filas de digoxina, valproato, carbamazepina, fenitoína y oxcarbazepina
siguen abiertas por fracción libre/total o analito/metabolito sin precisar.
Se conserva su RAW sin corregirlo por inferencia. T3 libre tiene concepto y
decisiones guardados, pero un guard histórico sigue bloqueando su búsqueda;
la corrección del contrato se prepara por separado sin activarla. Las revisiones
14–16 resolvieron 61/61 consultas locales exactas; antiendomisio IgG devuelve
`ambiguous` con un candidato IgA incompatible, registrado para corregir el
filtro clínico antes de afirmar que todas las variantes están conservadas.
El [diagnóstico y propuesta de inmunoglobulinas](proposals/20261011-antibody-variant-candidates.md)
documenta la causa en v1–v6 y contiene diff exacto y recuperación preparados,
sin ejecutar, para 25 componentes canónicos elegibles. Las revisiones 17–18 resolvieron 43/43 consultas
exactas. Las revisiones 19–20 resolvieron 26/26 exactos; toxoplasma IgA
incluye IgG incompatible bajo estado ambiguo. La revisión 21 cerró 66 filas y
resolvió 17/17 consultas exactas; ciclosporina C2 selecciona el analito genérico
sin representar el momento C2. La variante AFP-L3 selecciona
erróneamente AFP genérica: el
[diff y recuperación](proposals/20261011-afp-l3-candidate-conflict.md) están
preparados, sin activar el cambio crítico. No se activó ningún cambio del resolver.
El ejecutor se detuvo al encontrar un contexto histórico ya cerrado de PSA;
se corrigió el guard del renderer para comprobar sólo crawler sin decisión final,
se confirmó rollback de exactamente 83 filas y después commit/ledger del lote 18.
El 11-oct se recuperaron los procesos detenidos: las tres apps respondieron `200`
y se confirmó el PID/comando vivo de la cola. Se instaló un acceso de inicio de
sesión Windows para el usuario actual; no se ha observado aún otro inicio de sesión.
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
Ocho AChR genéricos y ocho GAD sin isoforma siguen pendientes; MOG y aquaporina
requieren investigación propia. Scl-70 IgM incluye IgG y GABA-A incluye GABA-B
bajo estado ambiguo: diagnóstico guardado, sin activar el filtro clínico.
El renderer respeta el límite existente de nota de alias de 1,000 caracteres:
si el motivo completo excede ese espacio, la nota referencia la auditoría, que
conserva íntegramente la razón investigada. Hashes, SQL, controles y ledger se
revalidaron antes de reiniciar el ejecutor terminal; no se debilitó la restricción.
Las revisiones 30–31 cerraron 109 filas con trece conceptos y quince aliases.
Cinco aliases de proveedor conservan muestra/duración presentes sólo en preparación:
17-KS, 5-HIAA, VMA y cortisol libre. Los nombres completos y aliases globales
resolvieron 23/23 consultas públicas; los cinco contextualizados resolvieron 5/5
en el resolver interno con proveedor. La ruta pública no acepta ese contexto y
conserva `no_match` para esos títulos incompletos; no cambiar el contrato para
forzar cobertura. VMA no elige adulto 24H o niño casual; renina conserva actividad,
LDL/VLDL método desconocido y Coombs directo no se convierte a columna.
Setenta y seis vecinos retienen sus UUID pendientes por variante, fracción o panel.
Bio-Velab añadió tres sedes y Medic Scanner dos con discrepancias gubernamentales
conservadas; Innovalab sigue retenido por domicilio incompatible.
Se recuperaron las tres apps (HTTP 200) y la cola viva PID 13072. El arranque ahora
detecta también `pythonw.exe`, evitando lanzar otro ejecutor sin ventana.
Las revisiones 32 corregida/33 cerraron 138 filas con diecisiete conceptos y
diecinueve aliases. Se preservan citologías, cultivo genérico, toxinas A+B
conjuntas, antígenos frente a anticuerpos y reticulina/ASCA IgA/IgG escritos.
33/33 consultas públicas completas/globales y 3/3 internas con proveedor
resolvieron. Sesenta vecinos conservaron exactamente sus UUID pendientes.
El ensayo inicial 32 se detuvo: el nombre nuevo de Giardia habilitaba un SEMIN
no investigado. Ledger sin aplicar; se leyó ese contexto, se preservó el fixture
original y una revisión sustituta de 74 filas pasó rollback/commit/ledger.
El preparador reutilizable comprueba nombres canónicos nuevos además de aliases,
sin retirar el guard de alcance. Tlatlauquitepec añadió tres sedes y La Paz una:
5C/SN y Acatlán 24 frente a Reforma Sur 92 conservados, todas pending.
Cola recuperada tras causa identificada y proceso anterior ausente: PID 2044,
27 entradas fijadas por hash; sin cambios del resolver. HBe abreviado aún incluye
superficie y anticuerpos bajo ambiguo; Cdiff PCR/B sola conserva candidatos
toxinasA+B bajo no_match. No afirmar protección completa de variantes.
La investigación sigue a cargo del
agente: el ejecutor no decide casos nuevos por una puntuación ni aprueba borradores.
El usuario delegó investigar y decidir equivalencias claras; conservar y escalar
la ambigüedad real. Detalle, fuentes, límites y siguiente trabajo:
[operación Puebla](PUEBLA_LOCAL_OPERATION_20261009.md), [D-021/D-022](DECISIONS.md).

**Memoria y APIs, 13-oct local/UTC:** memoria shadow v2 recompilada contra
37 revisiones: 309 aliases, 328 contextos proveedor/alias y 2,286 filas.
El plan reconoce 2,283 históricos y conserva tres con campos desconocidos.
Pendientes: 4,742 filas en 860 trabajos, 4,658 necesitan evidencia y 84 tienen
campos no contemplados. No mide éxito en términos inéditos. El título literal
de proveedor forma parte de la firma clínica; no se activó investigación
automática inédita ni API comercial. API/Admin/Paciente HTTP 200 y cola PID 2044
con comando vivo comprobados; treinta y una entradas explícitas fijadas por hash.
El catálogo se puede reutilizar entre estados; cada fuente/sede/oferta conserva
su contexto y evidencia comercial propios.
[Implementación, alternativas, recibos y límites](proposals/20261011-normalization-memory-and-apis.md).

**Último cierre, revisiones 34–37 e identidad 13 (13-oct, 13:01 UTC):** 221 filas,
28 conceptos y 31 aliases nuevos; antígeno SARS-CoV-2 y lactato reutilizaron
identidades existentes sin modificar sus metadatos. Cincuenta consultas públicas
y once internas de proveedor resolvieron al ID esperado. Se conservan VIH/VPH
sin definición, CA21.1/S100 sin diana/subtipo y clearance de dos muestras sin
representación suficiente; no se completan con referencias externas. Inhibina A
y SCC conservan suero literal; creatinina matutina no se convierte en 24 horas.
El helper respeta el alcance por proveedor y conserva los ocho RAW Salud Digna
de sangre oculta que carecen de definición, aunque el contexto SEMIN se resolvió.
Guadalupe/Vilaseca conservan website NULL con incertidumbre explícita; Tepeaca
conserva GET 403 y DOM público, sin atribuirle HTTP 200 ni propiedad legal.
Triages completos: 828 brechas, 32 sugerencias, 860 retenciones por política y
26 fuentes oficiales sin verificar. Sin ofertas, migraciones o cambios del resolver.
Commits locales por sección autorizados por el usuario: herramientas y datos
históricos ya guardados; las fixtures conservan bytes LF/CRLF mediante Git.

**Pausa de producción (25-sep-2026):** aprobación explícita del usuario. El
landing `pruevia.com.mx` permanece activo; `app.pruevia.com.mx` redirige al
landing; todas las rutas de `api.pruevia.com.mx` responden `503`; Admin conserva
Cloudflare Access y su Worker redirige después de autenticarse. No se tocaron
Supabase ni sus datos. Las versiones, límites y recuperación están en
[D-020](DECISIONS.md) y en el historial de despliegue de abajo.

`Implementado` indica código presente; `verificado` exige evidencia de la prueba y
su alcance; `desplegado` exige entorno y versión comprobados; `pendiente` necesita
trabajo; `bloqueado` necesita una condición externa identificada. No son sinónimos.

| Capacidad | Estado respaldado y evidencia | Límite / siguiente acción |
| --- | --- | --- |
| Búsqueda, resolución, paquetes y OCR | Implementados: [Worker](../apps/api/src/app.ts), [tipos](../apps/api/src/types.ts), [tests](../apps/api/tests). El resolver conserva sufijos explícitos como `en ayuno` en `preparation_note` sin inferencia clínica. | Revalidar el entorno de la prueba y medir recetas; tener rutas no prueba cobertura suficiente. |
| Paciente Flutter Web/PWA | La versión funcional anterior era `303acaac-c5d0-4f39-a9ae-7e63ea1b5d31`. Desde el 25-sep el Worker `pruevia-patient` está en `928c5957-4457-470f-b765-cd96a86e87ea` y redirige todas las rutas a `https://pruevia.com.mx/`; no sirve Flutter, manifest ni assets. El shell previamente instalado puede persistir en caché del dispositivo, pero la API está pausada. | Al reanudar, restaurar la versión anterior. No se puede borrar remotamente el caché ya instalado; solicitudes nuevas de API siguen sin servicio. |
| Normalización autónoma | Corte 12-oct: 244 aliases investigados, 213 nuevos conceptos y 1,818 decisiones exactas aplicadas bajo revisión delegada; cola 5,210 filas / 929 grupos. Catálogo: 402 conceptos activos. Incluye cuatro aliases limitados al proveedor radiográfico, con contexto RAW comprobado al aplicar. De los conceptos nuevos, 44 conservan muestra explícita y 169 reconocen sólo el analito con muestra desconocida; los atributos explícitos de cada fuente se conservan en RAW/decisión. Sin mappings LOINC ni métodos inferidos. T3 libre sigue bloqueado; 41/43 consultas de las revisiones 12–13, 61/61 de 14–16, 43/43 de 17–18 y 26/26 de 19–20 y 17/17 de 21 y 40/40 de 22–23 y 46/46 de 24–26 y 30/30 de 27–29 resolvieron el ID esperado. Antiendomisio IgG incluye IgA incompatible y toxoplasma IgA incluye IgG; AFP-L3 selecciona erróneamente AFP genérica; ciclosporina C2 devuelve el analito genérico sin representar el momento C2. Cuarenta filas de fármacos siguen abiertas por fracción/metabolito inciertos. Cromogranina B incluye A y troponina T incluye I bajo estado ambiguo; osteocalcina N-MID pierde especificidad de fragmento. Scl-70 IgM incluye IgG y GABA-A incluye GABA-B bajo ambiguo. Propuestas clínicas separadas, sin activar. Ejecutor local activo: cola explícita por hash, ledger remoto, rollback y commit acotado; revisiones 08–29 aplicadas y verificadas. Suite remota previa: 31 contratos / 531 aserciones; no se repitió en este corte. [Revisión, recibos y alcance](PUEBLA_LOCAL_OPERATION_20261009.md). | Investigar y encolar siguientes lotes; conservar diferencias clínicas y fuentes. El ejecutor necesita el equipo/proceso activos y no investiga términos nuevos. Cron remoto apagado; políticas comerciales continúan `review_required`. |
| Feedback y prueba cerrada Android | Backend, esquema `research`, formulario y triage están implementados en el proyecto enlazado. Antes de la pausa, el registro de testers y feedback estaban desactivados y el API confirmaba cohorte cerrada `0/20`; hoy el API no está disponible. No se enviaron correos ni invitaciones ni inició el reloj. | Falta enlace real de Play, upload key, AAB, ficha/declaraciones y aprobación separada para abrir reclutamiento. Audiencia Android: 18+; la futura app pública no activa bloqueo de menores. |
| Clics y captura de búsqueda | El registro de clics/proveedores sigue cerrado. La versión funcional anterior del API `c07c62a6-0c08-4226-a141-9f909e4445c8` tenía `PUBLIC_SEARCH_REVIEW_CAPTURE_ENABLED=false`; la versión de pausa actual `d8090ae6-dc38-4575-9cfe-0ced6b6826a9` devuelve `503`, por lo que la PWA no puede enviar nuevas búsquedas. Antes del kill switch, una consulta agregada read-only contó 11 filas históricas (8 `no_match`, 2 `ambiguous`, 1 ya resuelta); no se leyeron términos ni se borraron filas. | No borrar las 11 filas ni reactivar captura sin decisión explícita; antes de volver a operar, revisar que el aviso describa con precisión el periodo histórico. Ver D-019 y D-020. |
| Admin con temas, filtros y MFA | El Worker anterior era `4b16c144-bca9-4518-91c7-514036130181`. Desde el 25-sep está en `62fe579e-55d7-4021-bb7b-3c0c915989a0`; tras Cloudflare Access redirige al landing y no sirve assets Admin. El acceso sigue protegido por Access. | Restaurar la versión anterior sólo con aprobación para reanudar la operación. La solicitud anónima aún responde `302` al login de Access porque el control se aplica antes del Worker. |
| Documentos de proveedores | Configuración versionada cerrada por defecto; ver [cierre](../database/supabase/migrations/20260908100000_internal_document_freeze.sql) y [Worker](../apps/api/wrangler.toml). | No reabrir sólo cambiando una variable; necesita propuesta crítica y revisión coordinada. |
| Reclamación de perfiles | Flujo local implementado: expediente privado, estados, revisión Admin, comprobación de contacto, outbox de correo, solicitudes de privacidad y control de revisión; [referencia](PROVIDER_CLAIM_WORKFLOW.md). Contrato SQL local pasó. | `provider_intake_settings.enabled` y documentos siguen cerrados; faltan responsable legal, aviso integral, SMTP y verificación del destino antes de abrir. No se aplicaron estas migraciones al proyecto remoto. |
| Collectors | Corte 12-oct: ZIP oficial DENUE, sin token; 13,747 registros / 69,426 observaciones capturadas en `ingest`, fuente aprobada por licencia, corrida `succeeded`. Incluye 1,249 laboratorios y 322 hospitales. Diez revisiones separadas enlazaron 53 sedes pendientes de veintitrés nuevas marcas/instituciones, conservando 53 observaciones derivadas; no crearon ofertas. La revisión 07 conservó íntegra IMSS-Bienestar al añadir Zacatlán; la 08 incorporó Samalab y Omega con tres sedes pending, manteniendo 709 A y SN originales. La 09 incorporó LAC con dos sedes pending (11271977/3320300), conservando SN y discrepancias web 82/mapa 28. La 10 añadió Independencia y Humboldt, conservando 209, interior 22223 y MIGUEL ALEMANA; sitio Humboldt sólo candidato estatal. Rollback/commit, observaciones y auditoría comprobados. [Cobertura](PUEBLA_PROVIDER_COVERAGE.md). | Reconciliar siguientes identidades y comprobar estudios/sedes; 61 marcas y 140 ubicaciones no equivalen a cobertura comercial. Se conservan discrepancias de domicilio/CP; no se completaron por inferencia. El cron mensual continúa desactivado; fuentes comerciales permanecen `review_required`. |
| CI y despliegue DEV | Workflows presentes en [.github](../.github/workflows). | No se verificó aquí configuración de GitHub, ejecución reciente ni versión remota. |
| Landing SEO | Sigue publicado como `pruevia-landing`, versión `fdbd3693-c018-4ef6-a02c-ce77cd15a6ca`, y respondió `200` después de la pausa. Se ocultaron los enlaces a la app en el HTML, se mantuvo la llamada de explicación, privacidad y sitemap. | El formulario de testers permanece desactivado y la cohorte en `0/20`; revisar móvil real y Search Console. Indexación habilitada no garantiza aparición inmediata. |
| Identidad visual | Implementada localmente: libro abierto con P y líneas de orden, favicon de landing/admin, marca inline en Vue/Flutter, iconos PWA, Android/iOS y splash del paciente; Android incluye recursos heredados, adaptativos y monocromáticos dentro de la zona segura; [fuentes y renderer](../design/brand/README.md). | La variante Android compiló en debug; no se publicaron aplicaciones e iOS no se compiló en este entorno Windows. Los iconos funcionales de ubicación se conservaron deliberadamente. |
| Dominio Pruevia | Después de la pausa: landing `200`; `app` `302` a landing; API `503` tanto en `/health` como en una ruta de búsqueda; Admin anónimo `302` a Cloudflare Access. No se modificaron DNS ni políticas Access. | El API permanece fuera de servicio; no se verificó Admin con sesión autenticada del operador. |
| Aviso de privacidad | `https://pruevia.com.mx/privacidad/` responde `200`; usa identidad y domicilio cargados desde variables locales ignoradas por Git. El contenido publicado debe revisarse desde el navegador antes de compartirlo; no copiar los valores personales a logs/docs. | El operador expresó preocupación previa por hacer público su domicilio. La página ya está publicada; si decide retirarlo, preparar una corrección explícita y volver a desplegar. |
| Correo de contacto | Cloudflare Email Routing está activo para `pruevia.com.mx`; `contacto@pruevia.com.mx` reenvía a un destino privado verificado. El catch-all permanece desactivado con acción `drop`; los tres MX y los TXT SPF/DKIM se publicaron. | Falta enviar una prueba desde una cuenta distinta y confirmar recepción real antes de presentarlo como canal comprobado. No hay buzón saliente, notificaciones ni automatizaciones. |

## Estado del ledger remoto

La consulta `npx.cmd supabase@2.116.0 migration list --linked` del
19-sep-2026 confirmó `107/107` migraciones aplicadas hasta `20260919100000`.
El 21-sep-2026 se publicó `pruevia-api` en producción con versión
`7c78e0bc-f538-45b1-8111-400a64dcd10a`; `/health` respondió `200` mediante el
custom domain y la prueba real aceptó raíz, PWA y Admin, rechazando un origen
ajeno con `403`. El 22-sep-2026 el operador creó manualmente la aplicación Access
para `admin.pruevia.com.mx`, asociada a la política `Solo Miguel`, y se publicó
`pruevia-admin`; la revisión actual de interfaz corresponde a la versión
`fb7e18c8-5a2e-40df-8448-6ff172932597`. DNS público resolvió
el custom domain y una petición anónima obtuvo `302` hacia Cloudflare Access antes
de recibir assets. El operador completó después la sesión interactiva y mostró el
Admin con datos del API; la primera carga presentó un aviso transitorio de conexión
que se recuperó y no impidió la lectura. La PWA se publicó como `pruevia-patient`
y su corrección CSP/explorador corresponde a `eb00d88e-598f-4955-a1ea-6f6570829d6e`; el landing indexable quedó como
`pruevia-landing` versión `9562dd9e-f363-4bc1-b10a-65173a9f013c`. Las respuestas
públicas comprobaron enlaces, aviso, headers, sitemap y el piloto cerrado.
Los contratos remotos de feedback y cohorte/clics pasaron `22/22` cada uno, y
el contrato de privilegios pasó `30/30`. El Worker `pruevia-api-dev` se publicó
con versión `1dae2f0f-655d-40f0-abab-3fbcedb4abe4` y trigger `17 * * * *`.
`NORMALIZATION_REPROCESS_ENABLED` no está configurada, por lo que no ejecuta
escrituras automáticas. Mientras no exista un frontend HTTPS DEV,
`ALLOWED_ORIGINS` permite sólo el origen exacto del propio Worker: health y el
estado público del piloto responden `200`, un origen ajeno recibe `403` y las
rutas Admin/proveedor responden `401` sin token. El piloto devuelve cohorte
cerrada, `0/20`, duración 21 días y sin fecha de inicio; no se enviaron avisos.
El 24-sep-2026 se aplicaron en `pruevia-dev` las cuatro migraciones aditivas
preparadas para esta fase: grupos/cola de normalización, sugerencias ortográficas,
reprocesamiento exacto para el crawler y sugerencias de abreviaturas como `BH`.
El dry-run remoto confirmó `111/111` y ninguna migración pendiente. Los 30
contratos SQL pasan `518/518` aserciones; el contrato final de privilegios se
repitió dirigido después de actualizar su conteo a 35 RPC administrativas. La
suite API local pasa `143/143`; el smoke PostgreSQL 12 y typecheck también pasan.
Las RPC exactas sólo materializan evidencia ya elegible y reutilizan exactos o
aliases aprobados; ninguna ejecución `apply` se hizo en esta liberación.

Con autorización del usuario, el mismo día se publicaron los cuatro Workers:
API `pruevia-api` `f412ae67-dab4-4200-97b1-edb5027a1fc0`, Patient
`pruevia-patient` `303acaac-c5d0-4f39-a9ae-7e63ea1b5d31`, Admin privado
`pruevia-admin` `4b16c144-bca9-4518-91c7-514036130181` y Landing
`pruevia-landing` `d5cd3120-e60a-4a54-863e-2e0db4101e21`. El smoke de producción
obtuvo `200` en landing, PWA, manifest, service worker y `/health`; Admin anónimo
recibió `302` a Cloudflare Access. Chrome emulado contra producción verificó que
el landing no desborda en 320/360/390/430 px y que la PWA Android muestra la
acción nativa de instalación con manifest standalone y service worker activo.
Esto no sustituye comprobar el teléfono real ni volver a abrir la sesión Admin
autenticada después de este deploy.

El Worker de producción mantiene `NORMALIZATION_REPROCESS_ENABLED=false`; el
trigger horario no reprocesa. El preview remoto read-only del 25-sep devolvió
7,028 pendientes, 0 elegibles, 0 materializados y 0 procesados. No se activó el
cron de normalización ni se escribieron equivalencias u ofertas. El único
collector fuente aprobado encontrado es el directorio oficial DENUE. Su tarea
mensual está implementada como ruta del Worker API y la ingesta tiene una RPC
interna acotada. La migración está aplicada y el Worker está desplegado; la
captura sigue apagada (`DENUE_COLLECTION_ENABLED=false`) y requiere el token de
API de INEGI como secreto Cloudflare. No recolecta contactos ni publica sedes.
Las nueve fuentes comerciales de la cola continúan
`review_required`. El piloto Android continúa cerrado en `0/20`, sin fecha de
inicio ni notificaciones. Proveedores, feedback y analítica siguen cerrados en
la publicación patient-first; Admin no está enlazado públicamente.

El 25-sep-2026 se aplicó la migración aditiva `20260925100000` a la misma base
productiva; una consulta read-only al ledger confirmó `112` migraciones y última
`20260925100000`. El contrato DENUE pasó `13/13`; la suite completa quedó en
`31` contratos, `531/531` aserciones. API: `148/148` y typecheck limpio; smoke
PostgreSQL 12 pasó. Se desplegó `pruevia-api` versión
`780589b1-6b62-4789-8f40-9c90d9f323fa`; `/health` respondió `200`, CORS al app
permitido `204` y origen ajeno bloqueado `403`. El cron mensual está registrado,
pero `DENUE_COLLECTION_ENABLED=false` y no existe aún el secreto
`DENUE_API_TOKEN`: no hubo consulta externa ni captura DENUE. El cron de
normalización sigue apagado; el preview de 7,028 filas/0 elegibles no cambió y
no se modificaron equivalencias ni ofertas.

El 25-sep-2026, tras autorización del usuario para los cambios necesarios en
producción, se publicó `pruevia-api` versión
`c07c62a6-0c08-4226-a141-9f909e4445c8`. El bundle pasó API `150/150`, typecheck
y dry-run. Incluye el kill switch de captura pública de búsquedas, endpoints
agrupados para Admin y sugerencias de escritura separadas de resultados. Se
conservaron las banderas `PUBLIC_SEARCH_REVIEW_CAPTURE_ENABLED=false`,
`NORMALIZATION_REPROCESS_ENABLED=false` y `DENUE_COLLECTION_ENABLED=false`.
Verificación posterior: `/health` `200`, preflight CORS de la app `204` y origen
ajeno `403`. En Chrome móvil, Patient cargó Flutter con service worker activo y
acción nativa de instalación; el landing no desbordó horizontalmente en
320/360/390/430 px. También pasaron `flutter analyze`, las 39 pruebas Patient,
10 pruebas/typecheck del landing y `collectors/tests`. No se enviaron búsquedas ni
se hizo una prueba en teléfono físico. Las 11 filas históricas de revisión no se
borraron; revisar el aviso y resolver ese histórico antes de afirmar que nunca
se guardaron consultas.

Con autorización explícita del usuario del 25-sep-2026 para dejar sólo el landing
activo, se sustituyeron temporalmente los Workers de API, Patient y Admin sin
cambiar sus configuraciones normales ni tocar Supabase. API `pruevia-api` versión
`d8090ae6-dc38-4575-9cfe-0ced6b6826a9` responde `503` en todas sus rutas y declara
`crons = []`; Wrangler confirmó el despliegue de triggers. Patient
`pruevia-patient` versión `928c5957-4457-470f-b765-cd96a86e87ea` redirige a la
raíz del landing; Admin `pruevia-admin` versión
`62fe579e-55d7-4021-bb7b-3c0c915989a0` hace lo mismo después de la capa Access.
Landing `pruevia-landing` se actualizó a `fdbd3693-c018-4ef6-a02c-ce77cd15a6ca`:
los CTA de la app ya no aparecen, la página sigue indexable y el sitemap continúa
publicado. Pasaron sus 10 tests, typecheck, generación estática y dry-run.
La verificación HTTP obtuvo landing `200`, app `302` a landing, API `/health` y
`/v1/search` `503`, y Admin anónimo `302` a Access. No se verificó la redirección
Admin con una sesión autenticada. Cloudflare advierte que retirar crons puede
tardar hasta 15 minutos en propagarse; el API ya no tiene lógica programada y
DENUE/normalización estaban desactivados. PWA instalada puede conservar su shell
local; no conserva datos de búsqueda por su política de caché. Recuperación:
restaurar versiones funcionales anteriores API `c07c62a6-0c08-4226-a141-9f909e4445c8`,
Patient `303acaac-c5d0-4f39-a9ae-7e63ea1b5d31` y Admin
`4b16c144-bca9-4518-91c7-514036130181`; Landing anterior
`d5cd3120-e60a-4a54-863e-2e0db4101e21`; revalidar API y sus crons antes de reanudar.

## Corte de cobertura disponible

Fuente: [reconciliación Puebla](PUEBLA_PROVIDER_COVERAGE.md) y sus fixtures del
13–14 de septiembre. Reconsultar directorios/DB antes de tomar decisiones actuales.

- Salud Digna: inventario de 15 entradas, 13 con detalle de sucursal; centros
  293 y 299 pendientes de reconciliación. No equivale a catálogo completo por sede.
- Dr. Simi: feed con cuatro sedes, tres enlazadas; unidad 260 con discrepancia.
- Linfolab: seis registros RAW completos, tres ubicaciones enlazadas según el corte.
- DENUE: 489 registros fuente, 213 candidatos clínicos directos; 123 sin URL pública.
  Son leads del snapshot, no un censo actual ni 213 proveedores confirmados.
- Cola: la consulta remota de sólo lectura del 18-sep-2026 reportó 7,028 filas
  abiertas, pero agrupadas en 1,188 combinaciones proveedor+etiqueta de 8
  proveedores. Salud Digna concentra 6,804 filas en 967 etiquetas; SEMIN 140,
  Chopo 57 y el resto 27. El dashboard reportó 0 ambiguas, 7,028 sin
  cobertura abierta y 946 `no_match` ya cerradas en historial. El preview exacto
  no encontró coincidencias nuevas; no es una tasa de fallo del paciente.
- El reporte reproducible de priorización por proveedor/etiqueta está en
  [puebla_normalization_backlog.sql](../database/reports/puebla_normalization_backlog.sql);
  agrupa esas filas para revisión sin publicar cambios.
- El medidor de experiencia sobre el corpus público anonimizado está en
  [report_query_coverage.py](../database/scripts/report_query_coverage.py);
  separa resolución estricta, preparación, ambigüedad y resoluciones inesperadas.
- Los 946 `no_match` cerrados son historial. No contar cada fila `no_match` como
  tarea abierta: comprobar decisión final con la semántica del dashboard/cola.

Los conteos históricos de README, reportes y arquitectura pueden diferir porque
corresponden a otros cortes. No sumar corridas ni versiones de precios como si
fueran estudios distintos.

## Prioridades ejecutables

Las siguientes tareas preservan el objetivo de una base útil en Puebla. No son
promesas de fecha ni nuevas autorizaciones para operaciones externas.
Son el orden por defecto cuando el usuario no indica otra tarea. Una petición
explícita, como construir el landing, tiene prioridad y no necesita esperar el
backlog del core salvo dependencia funcional real. Construir y publicar son
acciones distintas; aplicar aprobación crítica cuando corresponda.

| ID / prioridad | Resultado y siguiente acción | Dependencia / aceptación |
| --- | --- | --- |
| PUE-01 / alta | Medir cobertura desde la experiencia paciente: reutilizar corpora existentes y preparar muestra de recetas desidentificadas con procedencia y alcance. Medir resolución por estudio, ofertas por zona, precios/frescura y receta completa/parcial. | Definir muestra representativa y metas con el usuario antes de usarlas como gate; reportar denominadores, errores y límites. No llamar “datos reales” a variantes sintéticas. |
| PUE-02 / alta | Reducir las brechas que revele PUE-01: agrupar cola por etiqueta/proveedor y frecuencia observada, revisar conceptos/mappings y publicar ofertas con evidencia de alcance. | Equivalencia revisada, trazabilidad, idempotencia y prueba end-to-end que muestre la mejora sin falsos positivos. Vaciar la cola no es el criterio. |
| PUE-03 / alta | Completar directorios prioritarios Salud Digna/Dr. Simi y contrastar Ruiz, Chopo, SEMIN, Linfolab y proveedores locales con fuentes oficiales. | Registrar sede enlazada o discrepancia explícita, fuente/fecha; separar sucursal de estudios ofrecidos. Los que no tienen web requieren evidencia alternativa. |
| PUE-04 / alta | Mejorar capturas fallidas con piloto por fuente; establecer corrida programada, métricas de caída/frescura y revisión de excepciones. | Adaptador probado y job realmente verificado. La cadencia sugerida no acredita automatización. Revisar costos/servicio nuevo si aplican. |
| OPS-01 / alta | Inventariar jobs y alertas realmente activos, cubrir las brechas de [mantenimiento continuo](CONTINUOUS_IMPROVEMENT.md) y revisar CI/dependencias relevantes. | Registrar horario, entorno, ejecución real, fallo/reintento y responsable; proponer servicio/costo nuevo antes de activarlo si requiere aprobación. |
| ADM-01 / media | Verificar operación del Admin con el volumen actual: búsqueda, periodos, paginación, cola y acciones auditables. | Consulta encuentra un registro fuera de la primera página o declara claramente su alcance; estados de red, vacío y sesión distinguibles. |
| REL-01 / posterior a cobertura | Preparar prueba externa de Puebla con gate medido, revisión de seguridad pendiente, Auth, orígenes, despliegue y recuperación. | Propuesta de liberación con resultados y limitaciones; aprobación explícita antes de apertura crítica. |
| REL-02 / alta antes de integrar frontends | Implementada en el Worker la opción opt-in `ALLOWED_ORIGINS`: lista exacta, preflight por origen y 403 sin reflejo para orígenes ajenos; conserva `ALLOWED_ORIGIN` por compatibilidad. | Elegir dominios reales, revisar la frontera de seguridad y aprobar la activación/configuración antes de desplegar. |
| FUT-01 / posterior | Publicar y ampliar SEO del landing, expansión geográfica y capacidades comerciales según [roadmap](02_FASES_IMPLEMENTACION.md). | Landing base ya implementado; publicación requiere destino, contenido legal/contacto revisado y aprobación crítica. Datos dinámicos y cobertura no se inventan para llenar páginas. |

PUE-01 y captura acotada PUE-03 pueden avanzar sin esperar expansión del catálogo.
PUE-02 debe usar evidencia para priorizar, evitando crecer por volumen sin utilidad.

## Puerta de liberación

Ya son requisitos de producto: no inventar equivalencias ni precios, mostrar
cobertura parcial/ambigüedad, preservar trazabilidad y autorización, y verificar
el flujo paciente en el entorno que se abrirá.

Siguen pendientes de definición/aprobación: tamaño y composición representativa
de la muestra, zona exacta del piloto, tasas objetivo de cobertura y tolerancia a
datos comerciales desactualizados. El agente debe proponerlos con la medición;
no inventar un porcentaje y presentarlo como requisito aprobado.

Los benchmarks v1/v2 respaldan sus consultas. La revalidación remota del
14-sep-2026 ejecutó los 25 contratos SQL (412 aserciones) con el runner fijado a
Supabase CLI 2.116.0: todos pasaron, incluyendo las 22 aserciones clínicas y el
contrato de paquetes 10/10. La prueba de paquetes se hizo determinista por
sucursal fixture porque el catálogo real puede ordenar antes ofertas de otros
proveedores. Repetir desde `database/` con
`python scripts/run_sql_contracts.py --cli npx.cmd --package supabase@2.116.0`
antes de liberar un cambio acoplado al esquema.

La propuesta de puerta conjunta para publicación, CORS y reducción controlada de
la cola está en [ADR-002](ADR-002-RELEASE-PILOT-GATES.md); permanece sin aprobar
y no autoriza acciones externas.

## Actualización y traspaso

22-sep-2026: identidad y domicilio indicados por el operador permanecen en
`apps/landing/.env`, excluido de Git, y se incorporaron al artefacto público del
aviso junto con `contacto@pruevia.com.mx`. El perfil versionado conserva esos
campos vacíos. Landing/PWA/Admin se publicaron y comprobaron en sus dominios;
el landing está indexable. Proveedores, feedback, analítica y registro Android
permanecen cerrados. Esta verificación técnica no sustituye revisión jurídica.

Validación documental y de implementación del 18-sep-2026: enlaces locales y anclas de la nueva entrada,
guías, decisiones y snapshot comprobados; `git diff --check` sin errores.
`AGENTS.md` se mantiene por debajo de 150 líneas. El landing pasó sus pruebas de
configuración, typecheck, auditoría npm, generación estática y revisión visual
local; la suite Python raíz pasó `357` pruebas con el `pytest.ini` versionado. El
símbolo de libro con P y líneas de orden se integró en las tres aplicaciones
visuales y se regeneraron 29 derivados PNG; la validación comprobó sus dimensiones
y ausencia de assets vacíos. El paciente pasó `flutter analyze`, 25 pruebas y `flutter build web`;
el Admin pasó 23 pruebas, typecheck y build con placeholders HTTPS. El build
sin configuración continúa rechazando la publicación como medida fail-closed.
También pasó un build debug Android con el package `com.pruevia.app`,
`targetSdk 36` y los flags del piloto. El release exige la
firma configurada y no se relajaron esas protecciones; no se subió ningún
artefacto a Google Play.
El Worker local, usando `.dev.vars` sin imprimir secretos, respondió `200` en health
y resolvió una orden de dos estudios con sufijos explícitos de ayuno, conservando
ambas notas y cobertura completa. No se ejecutaron despliegues ni se verificaron
DNS/servicios públicos. La variante indexable de la landing se
generó con destinos HTTPS de ejemplo y produjo sitemap/robots; los destinos reales
siguen sin verificarse.
El Worker actual fue desplegado como `pruevia-api-dev`, versión
`1dae2f0f-655d-40f0-abab-3fbcedb4abe4`, después de pasar 139 pruebas Vitest y
la validación de allowlist CORS exacta. `ALLOWED_ORIGINS` usa temporalmente el
origen HTTPS del propio Worker; debe sustituirse por los dominios exactos cuando
se publiquen los frontends DEV.
El corte de cohorte y clics pasó 139 pruebas del Worker, 23 del Admin, 8 del
landing, typecheck en las tres superficies, `flutter analyze` y 26 pruebas
Flutter. La migración se ensayó primero en PostgreSQL 12 efímero, donde se
detectó y corrigió un alias SQL incompatible; después se aplicó a DEV y su
contrato remoto pasó `22/22`. Falta la revisión visual con sesiones reales.
El corpus anonimizado de 64 consultas, medido contra el Worker HTTP local con
UTF-8, obtuvo 7/7 resoluciones estrictas y 9/9 resoluciones esperadas incluyendo
preparación, sin resoluciones inesperadas; 51 casos permanecen correctamente en
`no_match` y 4 en `ambiguous` según su intención no resoluble.
Los colores decorativos de la landing quedaron centralizados en sus tokens, sin
hexadecimales dispersos en CSS/SVG.

Se recorrieron estos escenarios contra las referencias y código local:

| Escenario | Orientación que aporta la guía |
| --- | --- |
| Cambiar colores | Ubica ambos archivos de tokens, coordinación CSS/Dart y revisión visual. |
| Incorporar proveedor | Ubica adapter/pipeline/renderers, evidencia, revisión y aceptación sin inventar ofertas. |
| Diagnosticar 401 | Ubica Auth/Worker, formato de UUID, sesión/factor y separación de 401/403. |
| Corregir resolver | Ubica RPC/wrappers, atributos a conservar y runner de contratos completos. |
| Preparar despliegue | Ubica workflow, configuración, aprobación crítica, verificación y recuperación. |

La revisión detectó además el límite actual de un origen CORS y la selección de
credenciales desactualizada del ADR: se documentó REL-02 y se reconcilió el ADR
con el código. La opción plural está preparada y probada, sin modificar permisos
remotos ni activar una frontera nueva.

Para una capacidad material registrar: fecha, commit/versión, entorno, evidencia
reproducible, resultado, límites y siguiente acción. Si un archivo/servicio no está
accesible, indicar “no verificado” y cómo comprobarlo. No almacenar datos clínicos,
credenciales o autorizaciones generales como memoria.

Actualizar esta página al cambiar prioridades/capacidades; los reportes detallados
retienen su fecha. Un pendiente terminado se retira de la tabla y se resume con
evidencia en su documento de área; no acumular un diario infinito aquí.
