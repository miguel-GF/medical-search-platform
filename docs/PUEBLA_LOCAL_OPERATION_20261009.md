# Operación local y crecimiento Puebla — 9-oct-2026

## Alcance autorizado y entorno

El usuario autorizó ejecutar Paciente, Admin y API localmente usando su base
productiva, alimentar Puebla incluyendo establecimientos pequeños e investigar
los términos pendientes para decidir equivalencias claras sin esperar revisión
humana rutinaria. La incertidumbre clínica real se conserva y se escala.
Autorizó expresamente reanudar el mismo proyecto Supabase, encontrado `INACTIVE`.
Referencia: [D-021 y D-022](DECISIONS.md).

El proyecto enlazado `ymtcmfgwuzdqtsbuvzqf` (`pruevia-dev`) quedó
`ACTIVE_HEALTHY`; conserva PostgreSQL 17.6 y 112 migraciones. No se creó otra
base ni se aplicaron migraciones. La operación local escribe en la base inicial
productiva. No se desplegaron Workers ni se cambió la pausa pública de D-020.

| Servicio local | Dirección | Evidencia 9-oct |
| --- | --- | --- |
| API | `http://127.0.0.1:8787/health` | HTTP 200; resolución real contra Supabase |
| Admin | `http://127.0.0.1:5173/` | HTTP 200; autenticación/permisos de servidor conservados |
| Paciente | `http://127.0.0.1:8080/` | Flutter Web compilado y HTTP 200 |

Los procesos requieren que el equipo siga encendido. Para arrancarlos de nuevo,
usar los comandos de [operación](OPERATIONS_GUIDE.md#entorno-y-arranque). Paciente
usa `--dart-define=API_BASE_URL=http://localhost:8787`; el script `dev` de API ya
permite exactamente los orígenes locales de estos puertos. Los archivos reales
de entorno y los artefactos permanecen ignorados por Git.

## Inventario estatal guardado y comprobado

**Corte vigente 14-oct-2026, 12:55 UTC:** 40 revisiones clínicas aplicadas,
324 aliases y 2,392 filas históricas cerradas. Paginación completa: 474 conceptos
activos y 4,636 pendientes en 845 grupos. Permanecen 234 ofertas, 68 marcas,
152 ubicaciones y 112 migraciones; ningún despliegue público nuevo.
La revisión 38 cerró 72 filas IgE específicas de Salud Digna. La 39 cerró diez
Western blot VIH conservando tipo conjunto frente a VIH-1 y el suero SEMIN;
se usó la sustituta `reviewed-aliases-20261014-04.json`, nunca el original `-02`.
La 40 cerró 24 filas HbA1c, ABO/Rh y urocultivo, sin inventar muestra para
HbA1c/ABO-Rh ni añadir antibiograma. Observación independiente de 39/40:
34 UUID/RAW/guardas exactos, diez consultas públicas y seis de proveedor con
el ID esperado, vecinos congelados intactos. Recibos en
`collectors/artifacts/puebla-expansion-20261009/clinical-research/`
(`review-39-revised/` y `review-40/`).
La memoria después de 40 registra 343 reglas/contextos y verifica los hashes
de las 34 entradas de cola. Sus sombras son sólo lectura: 2,389 contextos
históricos reutilizables y tres campos no reconocidos; pendientes 4,552 con
necesidad de evidencia y 84 campos no reconocidos. Cero coincidencias exactas
pendientes reutilizables. Recibos completos en
`collectors/artifacts/normalization-memory-after-review-40/`.
Una caída de DNS detuvo el worker de escritura; la recuperación sólo lectura
confirmó todos los ledgers sin reenviar commits. El watcher reintenta únicamente
la consulta de ledger y declara `transaction_submitted=false` cuando falla.
Suites formales no ejecutadas; resolver clínico, esquema y permisos sin cambios.

**Corte revalidado el 13-oct local/UTC tras treinta y siete revisiones aplicadas:**
309 aliases (286 globales y 23 de proveedor), 271 conceptos nuevos y
**2,286 filas cerradas**; quedan **4,742 filas / 860 grupos**.
Treinta nuevas marcas/instituciones y 65 sedes `pending` elevan el registro a
68 marcas / 152 ubicaciones; el catálogo tiene 460 conceptos y 234 ofertas activas.
209 conceptos nuevos conservan muestra desconocida; dos conservan secreción
mamaria o exudado uretral literales sin código específico; sesenta tienen código
de muestra. El contexto explícito de cada fuente
se conserva en RAW/decisión. Las
secciones de primera carga/revisión siguientes conservan su corte inicial.

### Revisiones 34–37 e identidad 13 — 13-oct-2026, 13:01 UTC

Se aplicaron las fixtures `reviewed-aliases-20261013-02.json` a `-05.json`:
34 (59 filas), 35 (63), 36 (34) y 37 (65). **221 cierres / 28 conceptos / 31 aliases**.
Rollback, commit, ledger, todos los UUID, RAW íntegros y guardas/atributos
comprobados. Las consultas positivas dieron **50/50 públicas y 11/11 internas
de proveedor**. No acreditan por sí solas el filtro completo de variantes.
MD5 del resolver v1 permanece `067b7a2fe0826ccaa48ece0a5dfd8d1d`.

34 conserva hormonas individuales; IGFBP-3 tiene alias Salud Digna documentado
por la denominación completa, sin panel ni aprobación fuzzy. Inhibina A sólo
tiene SEMIN con suero literal: canónico en suero y alias de proveedor.
35 conserva PCR/carga viral y órdenes masculinas individuales; Chlamydia
conserva exudado uretral escrito, sin inventar swab ni un código de espécimen.
El consentimiento propio en blanco sustenta antígeno SARS-CoV-2 rápido general:
se reutiliza el existente, sin copiar muestra o instrucciones históricas del PDF.
VIH sin tipo y VPH sin cobertura siguen retenidos.

36 conserva bilirrubina indirecta, reticulocitos, CK y creatinina en primera
orina matutina. SEMIN escribe Hb humana cualitativa fecal y lactato plasmático;
este último reutiliza un canónico existente sin mutarlo. Los 33 UUID retenidos
siguen íntegros: clearance de dos muestras (9), TIBC/UIBC (8), CK-MB masa/actividad
(8) y sangre oculta SD sin método/blanco (8). El catálogo propio SD de 2018 no
acredita método vigente en 2026. El preparador conserva esos ocho contextos fuera
del alias SEMIN de proveedor; nombres canónicos y aliases globales siguen teniendo
control global de alcance, sin retirar el guard de reprocessing.

37 preserva SCC en suero, CA72-4, beta-hCG libre, pTau217, HLA-B27 y tres clases
Candida albicans. CA21.1/S100 y beta-hCG SEMIN sin libre permanecen fuera.
HLA SEMIN conserva sangre total literal y familia blood, sin código total.
Acumulado de atributos por entrada: sangre 234 (232 SD/2 SEMIN), serum 61
(32 SD/29 SEMIN), plasma 2, stool 60 y urine 76.

Identidad 13 incorporó Guadalupe `6378369`, Vilaseca `3441886` y Tepeaca `6421417`:
3 marcas en verificación / 3 sedes pending, 3 auditorías y 3 observaciones.
Los dos hospitales no tienen website acreditado: NULL e incertidumbre explícita
quedan separados de la URL gubernamental de identidad. Vilaseca conserva
asentamiento/CP discordantes. Tepeaca conserva micrositio candidato, GET nativo
403 y DOM de Chrome normal; no se declara HTTP 200 ni propiedad legal.
Esquema existente admite website NULL; no hubo migración.

Memoria shadow v2: **37 revisiones / 309 aliases / 328 contextos / 2,286 históricos**.
Plan: 2,283 reutilizables / 3 campos desconocidos; pendientes 4,658 necesitan
evidencia / 84 campos desconocidos, agrupados en 860 trabajos. Contadores
antes/después iguales: 460 conceptos / 234 ofertas / 68 marcas / 152 ubicaciones /
112 migraciones. Triages completos: 828 brechas / 32 sugerencias, 860 retenciones
por política y 26 por fuente oficial sin verificar. No mide éxito en términos nuevos.

Artefactos: `clinical-research/review-34/` a `review-37/`, `identity-review-13/`
y `collectors/artifacts/normalization-memory-after-review-37/`. Cola existente
PID 2044 / session 31415, 31 entradas por hash; no reiniciada para estos lotes.
No se ejecutaron suites formales, nuevas capturas comerciales, ofertas,
migraciones o despliegues. El usuario autorizó commits locales por sección:
`8948671` herramientas y `724e183` 45 fixtures históricas aplicadas; protección
de bytes `.gitattributes` conserva LF/CRLF y hashes. `e2542cc` guarda el alcance
por proveedor del preparador; `73e184f` guarda los cuatro lotes nuevos y la
identidad 13, cinco fixtures con recibos y bytes Git iguales a sus hashes.
La propuesta original 32 se conserva por separado como historia sustituida,
sin incluirla en el inventario de cincuenta fixtures aplicadas. Las propuestas
no se activan. Otros cambios de apps/collectors/esquema siguen en el árbol local
y requieren su propia revisión; no se mezclaron con estas secciones.
Siguiente acción: continuar familias claras y obtener definiciones de los casos
retenidos; resolver y representación de muestras combinadas requieren propuesta
con alcance clínico antes de cambiar sus contratos.

### Revisiones 32 corregida/33 e identidad 12 — corte histórico 13-oct-2026

La cola aplicó [32 corregida](../database/data/reviewed-aliases-20261013-01.json)
y [33](../database/data/reviewed-aliases-20261012-04.json): **138 cierres**, diecisiete
conceptos y diecinueve aliases. Se confirmaron rollback, commit, ledger completo,
UUID, destino, guard RAW y atributos de exactamente 74/64 contextos. Sesenta
vecinos retuvieron el conjunto de UUID pendientes, incluidas dieciséis
antiestreptolisinas sin definición local de diana. No publicar datos comerciales.

La primera [revisión32](../database/data/reviewed-aliases-20261012-03.json) quedó
sin aplicar: su nuevo nombre canónico de Giardia habilitó un contexto SEMIN
no incluido. El guard de alcance abortó el ensayo con 74 elegibles frente a73;
diagnóstico rollback, cero no-crawler y ledger not_applied. Se leyó el RAW completo
SEMIN `f080e821-e6fa-5a94-9807-308e46328c9a`: título antígeno en heces y sample_type
`10 g Heces Recientes. Refrigerado`. Sala Sang no se usó como muestra; ocho
minutos son administrativos. Ese alias completo es global, con atributo stool
propio. SD sigue con alias de proveedor porque la muestra sólo figura en preparación.
Fixture inicial, hash, SQL y errores conservados; la entrada se sustituyó por
una revisión nueva después de confirmar ledger no aplicado y PID13072 ausente.
No se retiró el guard ni se repitió un commit. El executor nuevo PID2044,
session31415, confirmó ambas revisiones y quedó vigilando 27 entradas por hash.

[prepare_researched_alias_review.py](../database/scripts/prepare_researched_alias_review.py)
reutiliza renderer/ledger para preparar decisiones investigadas. Comprueba RAW
actual, pacientes, conteos, colisiones, fechas y destinos; conserva hashes de
informe/definición/snapshot. Ahora comprueba también registros habilitados por
los nombres canónicos nuevos antes de guardar el fixture final. El plan no decide
por modelo o fuzzy; el agente sigue investigando. La lectura de adicionales es
SQL sin escrituras; los diagnósticos de candidatos fueron transacciones rollback.
No se añadieron ni ejecutaron suites formales.

Seis conceptos32 conservan muestra estructurada: citología orina, moco fecal,
coprocultivo, Cdiff toxinasA+B y Giardia en heces, galactomanano en suero.
Citología de secreción mamaria conserva la muestra/anatomía literal sin código,
sin sustituir tejido, pezón más específico o lateralidad. HBe/HBs conservan
muestra desconocida y se distinguen de anti-HBe/anti-HBs. Coprocultivo no importa
lista de organismos, antibiograma, toxina Shiga o panel de la referencia.
Cdiff conserva una orden conjunta A+B, sin B sola, PCR/GDH o reflejos inferidos.
ANA/ANCA conservan familias, no ENA, MPO/PR3 o patrón; reticulina y ASCA conservan
cuatro clases IgA/IgG; MOG/islotes no copian IgG, método o matriz externa.

**33/33** consultas públicas completas/globales y **3/3** internas de proveedor
resolvieron al ID esperado. Las negativas no acreditan filtrado completo:
Cdiff PCR/B sola quedan no_match con candidato A+B; Giardia sin muestra es
ambiguous; HBe abreviado incluye HBs y ambos anticuerpos bajo ambiguo. MOG IgG
incluye su orden genérica e IHQ/otros anticuerpos bajo ambiguo. Diagnóstico
guardado y [registrado](proposals/20261011-laboratory-variant-candidates.md),
sin activar funciones clínicas; MD5v1 sigue `067b7a2fe0826ccaa48ece0a5dfd8d1d`.

La [identidad12](../database/data/provider-identity-review-20261012-02.json)
añadió **Laboratorios Clínicos Tlatlauquitepec (tres sedes)** y **Unidad Hospitalaria
La Paz (una)**. Tlatlauquitepec Reforma89, Zaragoza5C y Cuetzalan AldamaSN,
con directorio propio; otras tres sedes quedaron fuera por exterior incompatible
o dos direcciones oficiales posibles. La Paz Acatlán24 coincide con DENUE,
aviso propio enlazado de2020 y directorio estatal actualizado2026; conservar
ReformaSur92 del pie/contacto como discrepancia sin inferir traslado.
RAW/payload remoto exactos, dos marcas en verificación, tres branches y un
hospital pending; cuatro auditorías/observaciones, rollback/commit comprobados.
Guadalupe/Vilaseca tienen evidencia estatal, sin dominio propio acreditado:
quedan como candidatos, sin fabricar website institucional.

Memoria v2: **33 revisiones, 278 aliases, 295 contextos y 2,065 filas**;
2,062 históricos reutilizables/tres campos desconocidos. Pendientes 4,879 necesitan
evidencia/84 campos desconocidos, en 893 trabajos. Contadores antes/después iguales:
432 conceptos, 234 ofertas, 65 marcas, 149 ubicaciones, 112 migraciones. Los nuevos
cierres provienen de investigación y aplicación separadas, no del plan.
Sin nueva captura comercial, oferta, migración, API pagada, scheduler o publicación.

Artefactos `collectors/artifacts/puebla-expansion-20261009/clinical-research/`:
`review-32/` (diagnóstico original y cierre), `review-32-revised/` (sustituta y
recuperación), `review-33/`; `identity-review-12/`, `provider-research-next-12/`
y `collectors/artifacts/normalization-memory-after-review-33/`.
Siguiente trabajo: continuar familias claras, incorporar definiciones locales
faltantes y preparar el filtro clínico conjunto con alcance actual antes de
activar cambios críticos. Las cantidades no acreditan cobertura comercial Puebla.

### Revisiones 30–31 e identidad 11 — 12-oct local / 13-oct UTC

La cola aplicó [30](../database/data/reviewed-aliases-20261012-01.json) y
[31](../database/data/reviewed-aliases-20261012-02.json): **109 cierres**, trece
conceptos y quince aliases. Rollback, commit y ledger completos comprobados;
UUID, destino, guard RAW y atributos coinciden con las 109 filas investigadas.
Cinco conceptos conservan orina: 17-KS, 5-HIAA y cortisol libre con 24H explícitas;
VMA con duración desconocida (adulto 24H/niño casual en mismo RAW), adrenalina sin
duración escrita. Ocho conceptos mantienen matriz desconocida: 17-OH-CS, actividad
de renina, HDL/LDL/VLDL, Coombs directo/indirecto y carboxihemoglobina.
SD conserva 24 nuevas familias sangre; SEMIN una familia sangre (DAT) y dos sueros.
No copiar método directo/calculado, columna, IgG/C3 o matriz externa.

Cinco aliases son de proveedor porque su título omite muestra o duración presente
en preparación: 17-KS SD/SEMIN, 5-HIAA, VMA y cortisol libre SD. Los estudios completos
siguen compartidos entre estados. Se observaron **23/23** nombres completos/aliases
globales públicos y **5/5** aliases con proveedor en `catalog.resolve_items_v6`.
La ruta pública `resolveResponse` no admite `provider_brand_id`; las primeras cinco
llamadas con ese campo ejercieron búsqueda sin contexto y dieron `no_match`.
Se conserva la observación original y su aclaración en `resolver-scope-receipt.json`,
sin presentar 28 consultas públicas exitosas ni modificar el contrato.
Los títulos públicos incompletos siguen sin seleccionar una muestra/duración.
Los vecinos observados LDL directo/calculado, cortisol libre suero/total orina y
renina concentración no resolvieron; Coombs columna mantuvo su destino previo.
Algunos `no_match` conservan candidatos: no equivale a filtrado clínico completo.

**76 filas vecinas permanecen pendientes**, con el conjunto exacto de UUID conservado:
renina sin tipo/activada/cuantificación o panel, catecolaminas, metanefrinas/paneles,
colesterol sin fracción, biotinidasa sin actividad/genética y CTX sin variante.
Catecolaminas totales en plasma contradice su propia preparación, que excluye totales;
no se renombró como fraccionado para cerrar. No se activaron funciones clínicas.

La [identidad 11](../database/data/provider-identity-review-20261012-01.json) añadió
**Bio-Velab (tres sedes)** y **Medic Scanner (dos)**, todas `pending` y marcas
`verification_pending`. Sitios propios y DENUE corroborados; hashes RAW/payloads
remotos exactos, rollback/commit, cinco auditorías y cinco observaciones comprobados.
Conservar matriz Bio-Velab `SN`, exterior `2C`, diferencia San Alfonso/16 de Septiembre,
Zapata Laguna Tamiahua6 y Medic Scanner `903`/`220A`; San Sebastián/San Antonio no
corrige el RAW. El dominio actual `medic-scanner.com` resolvió una hipótesis distinta
del antiguo inaccesible. Innovalab queda retenido por 7 Norte107-1 frente a DENUE
Independencia Oriente535. No se crean ofertas por domicilio o toma de muestra.

Se recuperó operación local: API/Admin/Paciente HTTP200 y ejecutor `pythonw.exe`
PID13072 con 25 entradas fijadas por hash. El helper ahora detecta `python.exe`
y `pythonw.exe`; una ejecución posterior devolvió `already_running` con el mismo
PID y preservó los tres puertos. No se instaló otro acceso de inicio de sesión.
La memoria v2 se recompiló contra 31 ledgers: **259 aliases/276 contextos/1,927 filas**;
plan histórico 1,924 reutilizables/tres campos desconocidos; pendientes 5,017 requieren
evidencia/84 campos desconocidos, **912 trabajos**. Sólo planificación, no tasa sobre
términos inéditos. Contadores antes/después iguales: 415 conceptos, 234 ofertas,
63 marcas, 145 ubicaciones, 112 migraciones. Sin API pagada, captura comercial,
publicación, nuevo scheduler o suites formales.

Artefactos: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-30/`
y `review-31/` (investigación, preparación, cola, ledger, decisiones y consultas),
`identity-review-11/`, `provider-research-next-11/`,
`collectors/artifacts/normalization-memory-after-review-31/` y
`collectors/artifacts/local-stack/startup.json`.
Siguiente trabajo: ampliar las familias pendientes con evidencia propia y medir
reutilización sobre nuevas capturas antes de activar aprobaciones automáticas.

### Revisiones 27–29 e identidad 10 — 12-oct-2026

Se aplicaron [27](../database/data/reviewed-aliases-20261011-17.json),
[28](../database/data/reviewed-aliases-20261011-18.json) y
[29](../database/data/reviewed-aliases-20261011-19.json): **128 cierres**, catorce
conceptos y dieciséis aliases, 48/40/40 filas. RAW revalidado completo y colisiones
ausentes antes de encolar. IA-2: dos aliases comparten identidad; Scl-70 IgG conserva
su clase escrita. GABA-B conserva suero por Descripcion; trece conceptos nuevos
mantienen matriz desconocida. AChR distingue unión/bloqueo/modulación explícitos,
sin trasladar subunidad muscular/ganglionar, isotipo, método o muestra de referencias.
Paul–Bunnell conserva denominación heterófila: no VCA-IgM, diagnóstico o panel.
Su bibliografía PMID 2831918 se corroboró mediante EuropePMC HTTP 200; el 203 nativo
de PubMed no es captura exitosa. NHS primario HTTP 200 respalda identidad, sin
trasladar suero/EDTA, método o duración. No añadir aliases genéricos Monospot.

Treinta consultas exactas HTTP 200 devolvieron el primer ID esperado. No acredita
todas las variantes: Scl-70 IgM incluye Scl-70 IgG bajo ambiguous y GABA-A incluye
GABA-B. IA-2 beta ofrece DNasa B irrelevante bajo no_match. Respuestas íntegras y
[límites del filtro](proposals/20261011-laboratory-variant-candidates.md) guardados,
sin modificar v1–v6; MD5 v1 `067b7a2fe0826ccaa48ece0a5dfd8d1d`.
Ocho AChR sin función y ocho GAD sin isoforma siguen abiertos; MOG y aquaporina
no fueron absorbidos. Los tres lotes no aprueban resultados, ofertas ni métodos.

**Recuperación:** PID 9604 terminó exit 1 antes del commit 27. Ledger de 27/28/29
vacío; diagnóstico rollback HTTP 400 confirmó límite existente de source_note de 1,000 caracteres.
Se ajustó exclusivamente el renderer: conservar nota completa cuando cabe y,
si no, poner referencia al audit.events de ese review/alias; motivo íntegro en
metadata. No cambiar trigger/SQLconstraints ni hashes de fixtures. Se preservaron
previews anteriores, se regeneraron los nuevos y se revalidó ledger/cola antes
de arrancar PID 5280, session 53082; viejo PID confirmado terminal/ausente.
La cola verificó los anteriores y aplicó los tres. Las seis razones de 27 coinciden
íntegras con fixture en auditoría, notas de 199–946 caracteres, tres notas de
referencia. No se reinició ningún proceso por timeout. Cola: 23 entradas explícitas,
intervalo 300 s, proceso/comando vivos comprobados.

La identidad [10](../database/data/provider-identity-review-20261011-08.json)
añadió **Hospital Independencia—Tehuacán** y **Sanatorio Humboldt de Puebla**,
dos hospitales pending. [Independencia](https://hospitalindependencia.mx/)
coincide con DENUE 3428590/209, distinto de Omega 213. El
[directorio estatal](https://ss.puebla.gob.mx/emergencias), modificado 06-feb-2026,
corrobora Humboldt/DENUE 3439799/2015. Conservar interior 22223 y MIGUEL ALEMANA.
El sitio propio nuevo de Humboldt sólo se guarda como candidato referido por el
directorio: HTTP 403/desafío, sin contenido ni ownership acreditados. No cambiar
RAW del dominio antiguo. Ambas primarias institucional/estatal dieron 200; el
HTML estatal cambió su hash pero la sección Humboldt guardada coincide exactamente.
Rollback/commit, dos auditorías, dos observaciones y campos completos comprobados.
Lab360: 603-D y Ebenezer: SN siguen pendientes; no asignar IDs o coordenadas ficticias.

**Corte 12-oct, 06:12 UTC:** 29 revisiones, 244 aliases (240 globales/cuatro proveedor), 213 conceptos
nuevos (44 con muestra/169 sin matriz), **1,818 filas cerradas**. Catálogo 402,
**5,210 filas/929 grupos** pendientes. Diez revisiones de identidad:
23 instituciones/53 sedes nuevas; **61 marcas/140 ubicaciones**. Ofertas 234,
migraciones 112 y políticas comerciales sin cambios. API/Admin/Paciente HTTP 200.
Sin suites, contactos, capturas comerciales, costos nuevos o Workers publicados.

Fuente acumulada: 40 serum (24 SEMIN+16 SD), 1 plasma, 25 stool, 10 urine;
200 familia sangre SD. Dos SEMIN de sangre total siguen sólo en guard RAW, sin
código whole_blood. Memoria shadow v2: 29 ledgers/244 aliases/259 contextos,
1,815 históricos reutilizables y tres campos no contemplados. Pendientes:
5,126 necesitan evidencia/84 campos desconocidos, 929 trabajos; sólo planificación,
sin nuevas decisiones o investigación inédita autónoma. Artefactos:
`clinical-research/review-27/`–`review-29/`, `identity-review-10/` y
`collectors/artifacts/normalization-memory-after-review-29/`.
Los snapshots anteriores conservan sus fechas; no son contadores actuales.

### Revisiones 24–26 e identidad 09 — 11-oct local / 12-oct 05:40 UTC

Las revisiones [24](../database/data/reviewed-aliases-20261011-14.json),
[25](../database/data/reviewed-aliases-20261011-15.json) y
[26](../database/data/reviewed-aliases-20261011-16.json) añadieron 22 conceptos,
24 aliases y **169 cierres**: 84, 83 y 2 filas. Todos los RAW se releyeron en remoto
y coincidieron con el snapshot investigado, sin colisiones exactas. Tres agentes
aportaron investigación; sus tareas posteriores fallaron por límite de uso,
y el agente principal terminó la preparación/aplicación sin nuevos servicios.

Diez órdenes generales: EPO, SHBG, glucagón, NSE, C5, CH50, IgD, Se, Al y Mn.
CH50 conserva función/vía clásica; C5 sólo identifica el componente, sin elegir
actividad o concentración. Al genérico no se enlazó a ALUMINIO EN SUERO previo.
Tres órdenes fecales: calprotectina, antígeno H. pylori y azúcares reductores;
cinco metales sanguíneos conservan familia sangre SD sin elegir matriz exacta.
Osmolaridad sérica/urinaria reconoce denominación literal: no equivalencia
con osmolalidad, unidades, cantidad masa/volumen o método. Mn/Hg urinarios
mantienen orina explícita sin 24 horas o relación creatinina. SEMIN Hg conserva
aleatoria; su `duration_minutes=8` no se tomó como duración de recolección.

Siete conceptos explícitos (3 heces, 3 orina, 1 suero), quince de matriz desconocida.
Fuente total: 32 serum (24 SEMIN+8 SD), 1 plasma, 25 stool, 10 urine;200 familia sangre SD.
Chopo Mn conserva orina por título/guard, sin atributo extra inventado. Dos RAW
SEMIN de sangre total, sirolimus y mercurio con `Sngre`, no crean un código
whole_blood ni transfieren matriz al canónico. Originales/preparaciones intactos.

**Incidencia y recuperación:** se detuvo PID 5608 con marcador STOP propio para
cargar soporte stool y guards de muestra explícita, confirmado terminal exit 0
y ausente antes de reemplazarlo. PID 8420 verificó 17 lotes previos y aplicó 24/25,
pero terminó exit 1 porque el ledger 25 no coincidía: un target adicional sin
atributos heredó `specimen_family=blood` de SD. El commit de 83 filas existía; no se repitió.
El renderer ahora asigna atributos de cada target o {}, sin herencia. Una única
decisión SEMIN fue rectificada mediante rollback/commit acotados y auditoría
`pruevia:evidence-correction:20261011:01`, conservando atributo anterior,
destino, guard, tipo, RAW y hash de fixture. El ledger 25 quedó exacto. Confirmado
PID 8420 terminal/ausente antes de reiniciar; PID 9604 verificó los aplicados y cerró 26.
La cola continúa con 20 entradas por hash, intervalo 300 s; proceso/comando vivos
comprobados. No se reinició un proceso por timeout.

Las 46 consultas sintéticas de aliases/nombres devolvieron resolved y primer ID
correcto. Once vecinos dieron no_match; sólo acredita esos once, sin resolver
los defectos clínicos previamente diagnosticados. v1 MD5 permanece
`067b7a2fe0826ccaa48ece0a5dfd8d1d`; no hubo funciones/migraciones nuevas.

La identidad [09](../database/data/provider-identity-review-20261011-07.json)
añadió LAC y dos sedes pending: 11271977 Tlanalapan/3320300 San Lucas. Su
[directorio](https://labolac.com/pages/sucursales.html) enlaza script y
[JSON público](https://labolac.com/json/sucursales.json), observados en Chrome
normal con perfil temporal, sin cookies/credenciales/evasión. Se guardaron DOM
y hashes: no representan HTTP 200 observado. Rollback/commit, dos observaciones
aceptadas, dos auditorías y campos DENUE comprobados. San Lucas conserva SN:
web 82/mapa 28 no completan RAW. Matriz LAC 3265780 y Omega Tehuacán 213 siguen sin
vínculo DENUE inequívoco. Una toma de muestra no acredita estudios disponibles.

**Corte 12-oct 05:40:44 UTC (11-oct local):** 26 revisiones, 228 aliases
(224 globales/cuatro de proveedor), 199 conceptos nuevos (43 con muestra/156 por analito),
**1,690 filas cerradas**. Catálogo 388; pendientes **5,338 filas/945 grupos**,
913 brechas/32 sugerencias. Nueve revisiones de identidad: 21 instituciones/51 sedes
nuevas; **59 marcas/138 ubicaciones**. Ofertas 234/migraciones 112/políticas iguales.
API/Admin/Paciente HTTP 200. No se ejecutaron suites ni nuevas capturas comerciales,
publicaciones de Workers, contactos o servicios de pago.

Memoria **shadow v2**, 26 ledgers/228 aliases/243 contextos proveedor-alias:
1,687 históricos reutilizables, tres retenidos por campos no contemplados,
incluido Chopo Mn (`specialty` y otros). Pendientes 5,254 necesitan evidencia/84 campos
desconocidos, 945 trabajos. La firma incluye provider_display_name clínico;
memorias v1 deben recompilarse. No escribe decisiones ni investiga términos
inéditos automáticamente. Recibos: `clinical-research/review-24/`–`review-26/`,
`identity-review-09/`, `normalization-memory-after-review-26/`.
Capturas clínicas nativas: 9 HTTP 200/13 HTTP 403; las referencias se leyeron mediante
web previamente, sin declarar 403 como contenido capturado exitosamente.

### Memoria inicial y APIs — 11-oct, 23:42 UTC

El operador pidió investigar otro camino y construir la automatización local,
reutilizando el catálogo al incorporar estados como Querétaro. Se implementaron
un compilador de decisiones verificadas y un adaptador de candidatos NLM con
caché y atributos LOINC locales. El ledger confirmó las 21 revisiones antes de
compilar: 184 aliases, 193 contextos proveedor/alias y 1,360 filas. El plan
reconoce 1,358 contextos históricos y retiene dos por campos desconocidos. En
la cola actual, 5,583 filas requieren evidencia y 85 tienen campos de fuente
no contemplados, agrupadas en 995 trabajos; cero nuevos cierres. Doce consultas
públicas NLM dieron HTTP 200 y se reutilizaron desde caché. Los contadores
remotos permanecieron iguales; no se modificaron resolver, queue, migraciones,
políticas ni publicación. No se ejecutaron suites. No se instaló un nuevo
scheduler ni una investigación automática completa de términos inéditos.
En ese corte las revisiones 22–23 tenían sólo la lectura inicial; la aplicación
posterior se documenta a continuación.
[Código, alternativas, recibos, límites y siguiente acción](proposals/20261011-normalization-memory-and-apis.md).

### Revisiones 22–23 e identidades 08 — 11-oct local / 12-oct UTC

Las [revisiones 22](../database/data/reviewed-aliases-20261011-12.json) y
[23](../database/data/reviewed-aliases-20261011-13.json) añadieron diez conceptos
y diez aliases cada una. La cola PID 5608 aplicó rollback/commit y ledger exactos:
80 filas SD en 22; 80 SD y una SEMIN en 23. Total **161 cierres adicionales**.
Los conceptos conservan muestra/system/time_aspect NULL. Ocho proteínas totales
SD conservan familia sangre; SEMIN fosfatasa ácida total conserva su suero propio.
Ahora hay 160 decisiones sangre SD, 21 suero SEMIN y un guard de sangre total
SEMIN previo, sin transferir muestras al concepto global.

Se observaron 40/40 aliases/nombres exactos con el primer ID correcto. No demuestra
filtrar todas las variantes: cromogranina B incluye A y troponina T incluye I
bajo `ambiguous`; osteocalcina N-MID devuelve el analito general sin estructurar
fragmento. El diagnóstico v1–v6 y lexicon quedó guardado;
[límites y siguiente corrección](proposals/20261011-laboratory-variant-candidates.md).
No se modificaron funciones; MD5 v1 `067b7a2fe0826ccaa48ece0a5dfd8d1d`.

Cuatro grupos de ocho SD siguen pendientes: factor VIII antigénico, fosfatasa
ácida total+fracción prostática, proteínas totales+relación A/G y APOE asociado
con Alzheimer. La ambigüedad de factor VIII es real: [Labcorp 086015](https://www.labcorp.com/tests/086015/factor-viii-antigen)
mide FVIII, pero [086280](https://www.labcorp.com/tests/086280/von-willebrand-factor-vwf-antigen)
mide vWF y usa `Antigenic Factor VIII` como alias. No elegir el analito sin
aclaración de la definición propia del proveedor. Originales intactos.

La [revisión de identidades 08](../database/data/provider-identity-review-20261011-06.json),
request `pruevia:provider-identity-review:20261011:06`, añadió **Samalab y Omega**
y tres sedes pending (DENUE 11090755, 3459594, 8559305). [Samalab](https://www.lmsamalab.com.mx/sucursal-san-martin-texmelucan-2/)
corrobora Libertad 311; [Omega](https://omegalaboratorio.com.mx/contacto.html)
corrobora Puebla/San Martín. DENUE Puebla conserva exterior 709 y letra A; una
tarjeta web abreviada no permite borrar A. San Martín conserva exterior vacío
con marcador SN; no completar kilómetro ni asentamiento desde la web. La primera
nota del agente sobre letra ausente fue corregida al leer los campos RAW remotos.
Rollback/commit, tres observaciones aceptadas y tres auditorías se comprobaron.
LAC conserva su enlace físico abierto; no se incorporó por coincidencia de domicilio.

**Corte 12-oct 00:04:19 UTC (11-oct local):** 23 revisiones, 204 aliases
(200 globales/cuatro de proveedor), 177 conceptos nuevos (36 con muestra/141 por
analito) y **1,521 filas cerradas**. Catálogo 366; pendientes **5,507 filas/974
grupos**, con 940 brechas/34 con sugerencias. Ocho revisiones de identidad suman
20 instituciones/49 sedes nuevas: **58 marcas/136 ubicaciones**. Se conservan
234 ofertas, 112 migraciones y las políticas comerciales. API/Admin/Paciente
respondieron 200; PID/comando de la cola comprobados. No se ejecutaron suites.

La memoria se recompiló contra los 23 ledgers: 204 aliases/214 contextos,
1,519 históricos reutilizables y dos con campos desconocidos. La cola actual
necesita evidencia para 5,422 filas y mantiene 85 por campos no contemplados;
974 trabajos agrupados. Artefactos `normalization-memory-after-review-23/`.
El plan continúa sin escritura o investigación autónoma de términos inéditos.
Los recibos clínicos están en `clinical-research/review-22/` y `review-23/`;
los de proveedores en `identity-review-08/`, bajo el directorio local Puebla.
Las capturas nativas de referencias dieron nueve HTTP 200 y once 403; las
decisiones se respaldan por contenido primario leído mediante web, sin sortear
el bloqueo. No confundir 403 con copia exitosa. No hubo nueva captura comercial,
oferta, migración o publicación de Workers.

Se descargó la [distribución oficial de Puebla](https://www.inegi.org.mx/contenidos/masiva/denue/denue_21_csv.zip),
con metadatos del **20-may-2026**, y se verificaron los
[términos de libre uso del INEGI](https://www.inegi.org.mx/inegi/terminos.html).
Fuente: INEGI, DENUE. Transformación Pruevia: estado 21, clases SCIAN 621/622,
sólo campos de identidad/ubicación. No implica aval del Instituto.

| Conteo | Resultado comprobado en Supabase |
| --- | ---: |
| Establecimientos de salud / IDs DENUE distintos | 13,747 |
| Municipios representados | 217 |
| Laboratorios diagnósticos, clases 621511/621512 | 1,249 |
| Hospitales, clases 622 | 322 |
| Observaciones de identidad/ubicación | 69,426 |
| Lotes confirmados | 157/157 |

La corrida `f406e330-28ad-47de-9bf4-77debaa55cff` está `succeeded` y la
fuente específica `denue_puebla_bulk` tiene política `approved` por esa licencia.
El SHA-256 del ZIP es
`814aea797a6fa3d9ed0307d14eeda516806ea765fcaa4fb4f7192c40029210af`.
El adaptador conserva metadatos, hash y señales de calidad, excluye teléfono,
correo y representante legal; 35 registros no traen nombre y se conservan como
evidencia con esa falta explícita. No se inventaron nombres ni se fusionaron marcas.

La carga está en `ingest`, con observaciones de sucursal sin enlazar. **No acredita
que todos los establecimientos sigan abiertos, atiendan personas o realicen un
estudio determinado.** El directorio también contiene consultorios dentales y
otras especialidades; los nombres/clases requieren revisión para separar casos
veterinarios. No incorpora clases 623/624 de asistencia residencial/social.
No es una garantía de que DENUE incluya todo negocio existente.

No creó ofertas, precios ni sucursales canónicas: permanecen 38 marcas, 87
ubicaciones, 189 conceptos activos y 234 ofertas activas. La base pasó de
96,865,427 a 139,250,835 bytes en este corte. La carga marca una corrida `partial`
hasta comprobar todos los registros y observaciones; cada lote es transaccional
y conserva un recibo. No cambió las políticas de las fuentes comerciales.

Implementación: [adaptador](../collectors/src/pruevia_collectors/providers/denue_bulk.py),
[CLI](../collectors/src/pruevia_collectors/cli_denue_bulk.py) y
[transporte enlazado](../database/scripts/publish_denue_bulk_linked.py).
Los comandos reproducibles están en [collectors](../collectors/README.md).

## Continuidad comprobada — 11-oct-2026

### Revisión clínica 10: once aliases y 83 filas

La [revisión 10](../database/data/reviewed-aliases-20261009-10.json), investigada
y aplicada el 9-oct, añadió diez órdenes por analito con muestra desconocida.
El ledger reconsultado el 11-oct confirma `already_applied`: 83 decisiones,
24 contextos de familia sangre, tres de suero y cero identificadores nuevos.

| Concepto nuevo | Filas | Fuente primaria de la revisión |
| --- | ---: | --- |
| Albúmina | 8 | [MedlinePlus](https://medlineplus.gov/lab-tests/albumin-blood-test/) |
| Amilasa | 9 | [MedlinePlus](https://medlineplus.gov/lab-tests/amylase-test/) |
| Lipasa | 8 | [MedlinePlus](https://medlineplus.gov/lab-tests/lipase-tests/) |
| Androstenediona | 9 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/9709) |
| Inmunoglobulina E (IgE) | 9 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/8159) |
| Inmunoglobulina G (IgG) | 8 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/8160) |
| Péptido C | 8 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/8804) |
| Prealbúmina (transtiretina) | 8 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/9005) |
| Complemento C3 | 8 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/8174) |
| Complemento C4 | 8 | [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/800020) |

Salud Digna aporta 80 filas y SEMIN tres. Los textos de preparación de albúmina,
amilasa y lipasa mencionan sangre: se conserva esa familia por decisión y con
guard exacto, sin afirmar suero/plasma/sangre total. SEMIN declara suero en
amilasa, androstenediona e IgE; se conserva por entrada. Las definiciones nuevas
siguen con muestra/sistema/tiempo desconocidos, sin métodos, unidades o LOINC
inferidos. El concepto previo `AMILASA EN SUERO` conserva su identidad separada.
IgG total no se convierte en subclases ni IgE en pruebas de alérgenos específicos.

El ejecutor completó rollback y commit acotados de 83 filas. Las 21 consultas
HTTP de aliases/nombres canónicos guardadas resolvieron los IDs esperados;
`amilasa en suero` resolvió el concepto previo, mientras `albumina en suero`,
`complemento c3 en suero` y la orden de subclases IgG quedaron `no_match`.
Es evidencia de resolución terminológica, no disponibilidad ni oferta comercial.
No se ejecutó una nueva suite de pruebas en este corte.

Recibos: `collectors/artifacts/local-review-queue/pruevia-evidence-review-20261009-10/`.
Lecturas: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-10/`,
incluyendo `verified.json`, `local-resolver.json` y la base revalidada el 11-oct.
SHA-256 fijado en cola:
`17c473c91001f00c7d8b09d871ea681961f5e9e5b026f8e079573b447228f2a2`.

### Identidad 03: Laboratorio Mexica

La [revisión del 11-oct](../database/data/provider-identity-review-20261011.json)
vinculó dos identidades DENUE con las páginas oficiales de
[Chignahuapan](https://laboratoriomexica.mx/sucursal-chignahuapan/) y
[Tetela de Ocampo](https://laboratoriomexica.mx/sucursal-tetela-de-ocampo/).
Rollback y commit devolvieron una marca y dos sedes; la lectura posterior
confirmó marca `verification_pending` y ambas sedes `pending`.

Se conservan las direcciones gubernamentales: ID `8612162`, Segunda Calle de
Abasolo sin número, Chignahuapan; ID `12272393`, 2 Sur sin número, Tetela.
La fuente oficial de Chignahuapan describe Guillermo Prieto esquina con Abasolo;
la de Tetela incluye numeración 2-22. Son referencias guardadas para verificación;
no se sustituyeron calles/números ni se afirmó equivalencia postal completa.
No se crearon ofertas ni se validaron precios, acreditaciones o estudios por sede.

El navegador de investigación permitió leer ambas páginas primarias; las
descargas nativas posteriores devolvieron `403`, conservado en
`identity-review-03/source-snapshots.json`. Esas respuestas no acreditan una nueva
captura exitosa ni se sortearon controles de acceso. Los recibos y verificación
SQL están en `collectors/artifacts/puebla-expansion-20261009/identity-review-03/`.

Continúan candidatos sin vinculación aprobada: Sierra & Co tiene una
[página oficial de Chignahuapan](https://labsierra.com/contacto-laboratorio-chignahuapan/),
pero no se encontró una identidad DENUE nominativa equivalente; Treviño tiene
[contacto oficial en Tetela](https://trevinolaboratorio.com/contacto), con diferencias
de numeración respecto al inventario. No se fusionaron negocios de procesamiento,
radiología o tomografía que comparten domicilio. Santa María sigue sin evidencia
primaria suficiente de sus sedes. Siguiente acción: investigar esas identidades
y el siguiente lote de grupos clínicos, conservando las discrepancias.

### Revisión clínica 11: doce aliases y 82 filas

La [revisión del 11-oct](../database/data/reviewed-aliases-20261011.json), ID
`pruevia:evidence-review:20261011:01`, añadió diez órdenes por analito.
Se leyeron sus 80 contextos Salud Digna completos y dos entradas SEMIN.
La cola fijada por hash ejecutó rollback, commit de 82 filas y comprobación del
ledger `already_applied`, conservando los cuatro lotes anteriores en la cola.

| Concepto nuevo | Filas | Evidencia terminológica primaria |
| --- | ---: | --- |
| Ácido úrico | 8 | [MedlinePlus](https://medlineplus.gov/lab-tests/uric-acid-test/) |
| Aspartato aminotransferasa (AST/TGO) | 8 | [MedlinePlus: AST/TGO](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-ast/) |
| Alanina aminotransferasa (ALT/TGP) | 8 | [MedlinePlus: ALT/TGP](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-sangre-de-alt/) |
| Fosfatasa alcalina (ALP) | 9 | [MedlinePlus](https://medlineplus.gov/lab-tests/alkaline-phosphatase/) |
| Gammaglutamil transferasa (GGT) | 9 | [MedlinePlus](https://medlineplus.gov/lab-tests/gamma-glutamyl-transferase-ggt-test/) |
| Lactato deshidrogenasa (LDH) | 8 | [MedlinePlus](https://medlineplus.gov/lab-tests/lactate-dehydrogenase-ldh-test/) |
| Bilirrubina total | 8 | [MedlinePlus: fracciones](https://medlineplus.gov/ency/article/003479.htm) |
| Bilirrubina directa | 8 | [MedlinePlus: fracciones](https://medlineplus.gov/ency/article/003479.htm) |
| Triglicéridos | 8 | [MedlinePlus](https://medlineplus.gov/lab-tests/triglycerides-test/) |
| Cistatina C | 8 | [Mayo: resultado individual](https://www.mayocliniclabs.com/test-catalog/overview/614154) |

Nueve órdenes Salud Digna mencionan extracción de sangre en preparación:
72 decisiones conservan esa familia mediante guard exacto, sin inferir suero,
plasma o sangre total. Cistatina C sólo especifica ayuno; la muestra permanece
desconocida. SEMIN conserva suero explícito para ALP y GGT en dos decisiones.
Las diez definiciones nuevas mantienen muestra/sistema/tiempo desconocidos y
no se añadieron identificadores, métodos, propiedades, escalas, unidades o LOINC.
No se convirtió una orden individual en panel ni se añadió eGFR a cistatina C.

**Discrepancia real conservada:** la entrada SEMIN
`7b74db4c-ad5c-5760-a16f-d8a939b12f90`, “TRANSAMINASA GLUTAMICO OXALACETICA”,
declara `Orina / Recipiente esteril`, con área `QUIMICA CLINICA`, categoría
de análisis sanguíneos y sala `Sang`. No se cambió a suero ni se aprobó esa
entrada por el nombre. La lectura posterior confirmó `no_match` y cero
decisiones terminales. Se informó la contradicción al usuario; queda fuera del
lote y guardada en `review-11/open-source-specimen-conflict.json`.

Las 22 consultas HTTP locales de aliases/nombres canónicos devolvieron los IDs
esperados. La consulta de ácido úrico en orina de 24 horas resolvió el concepto
previo `fec16ef4-4e7e-5fd3-8d69-3d9ab8924e94`, distinto del nuevo genérico;
bilirrubinas sin fracción, ALP ósea, isoenzimas LDH, cistatina C con eGFR y
TGO en orina quedaron `no_match`. No se ejecutó una nueva suite de pruebas.

La base posterior contiene 255 conceptos activos, 6,411 filas pendientes y
1,099 grupos. Ofertas: 234; marcas/sedes: 45/115; ledger de migraciones: 112.
La lista de políticas de fuentes coincide exactamente con la anterior al lote.
Las ocho páginas MedlinePlus devolvieron `200` en descarga nativa; Mayo permitió
la lectura en el navegador, pero la descarga nativa devolvió `403`, conservado
sin sortear controles. Fuentes y resultados están en
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-11/`;
recibos transaccionales en
`collectors/artifacts/local-review-queue/pruevia-evidence-review-20261011-01/`.
SHA-256 del fixture:
`897d58f202101720fe97087e4367ecf8c3a475c3cfe0609bec98d99db25f1e21`.

### Trabajo con tres agentes: revisiones 12–13 e identidad 04

El operador pidió expresamente tres agentes el 11-oct. Dos investigaron grupos
clínicos distintos y uno las identidades regionales; sólo el coordinador encoló
los fixtures revisados y ejecutó la revisión de identidad. No hubo ediciones
simultáneas de un archivo, pruebas nuevas, commits, publicación ni contactos.

| Lote aplicado | Conceptos | Aliases | Filas crawler |
| --- | ---: | ---: | ---: |
| [12: hormonas](../database/data/reviewed-aliases-20261011-02.json) | 10 | 11 | 82 |
| [13: metabolismo](../database/data/reviewed-aliases-20261011-03.json) | 10 | 12 | 84 |

El ejecutor PID 14680 aplicó la revisión 12 a las 14:18:51 UTC y la 13 a las
14:24:02 UTC. Cada lote conservó el hash aprobado, rollback, commit y consulta
posterior `already_applied`; la consulta independiente confirmó aliases,
conceptos y decisiones exactos. Los SHA-256 de los fixtures son respectivamente
`76ca40e111250bfa3eb5298fae747ba1cb109ab12514a12eec599d06ae837fd6` y
`4297bc9375be362309ac27494936875d9c4588a0facd414cf57675fb8cec0173`.
Recibos reales: `collectors/artifacts/local-review-queue/`, subdirectorios
`pruevia-evidence-review-20261011-02` y `pruevia-evidence-review-20261011-03`.
Los previews de los agentes, por separado, sólo fueron preparación.

Hormonas conserva estradiol, cortisol, DHEA, DHEA-S, testosterona libre y total,
T3 libre, T3 reversa, T4 total y ACTH como identidades distintas. No infiere
fracción biodisponible, protocolo de cortisol, método ni muestra desde la ficha
de referencia. ACTH conserva la preparación RAW de toma matutina por entrada.
Las fuentes primarias de Mayo y
[NIH: fracciones de testosterona](https://medlineplus.gov/lab-tests/testosterone-levels-test/)
se guardan en cada concepto y en `clinical-research/review-12/`.

Metabolismo conserva cloruro, potasio, sodio, fósforo, magnesio, urea, nitrógeno
ureico, homocisteína, fructosamina y lipoproteína(a). Urea y BUN siguen separados,
sin conversión de resultados; Lp(a) no se une a apolipoproteína A-I/II o perfil
lipídico. Referencias y lecturas completas: `clinical-research/review-13/` y
los enlaces de cada concepto en el fixture. Los dos lotes mantienen veinte
definiciones genéricas con muestra/sistema/tiempo NULL; preservan seis contextos
SEMIN con suero y 56 Salud Digna con familia sangre en RAW/decisión, sin
transferir esos atributos a los demás. No se añadieron identificadores o LOINC.

La lectura real por HTTP local confirmó **19/21** consultas de hormonas y
**22/22** de metabolismo con el ID esperado. T3 libre y su nombre canónico
quedan `no_match`: el lexicón de agosto contiene tres constraints universales
`__blocked_analyte_variant__` para impedir selección de T3 total/T4 libre cuando
T3 libre aún no existía. Las funciones actuales tampoco evalúan el atributo
`component`; cambiar sólo los datos a ese atributo no resuelve el fallo y
quitar la restricción pierde el guard clínico. Se prepara una corrección aislada
del contrato, sin activarla ni presentar las ocho decisiones crawler de T3 libre
como búsquedas públicas funcionales. La
[propuesta revisable](proposals/20261011-free-t3-component-constraint.md)
contiene el diff SQL y recuperación; permanece fuera del directorio automático
de migraciones y de la cola. AGENTS/D-006 exigen aprobación específica antes de
modificar este filtro clínico común en la base productiva. El permiso para
investigar/aprobar términos claros no activa ese cambio de función.
Evidencia: `review-12/local-resolver.json`.

La consulta fuera del alcance conservó `no_match` para calcio sin forma/ionizado,
magnesio eritrocitario, cortisol salival, testosterona biodisponible y urea
urinaria de 24 horas. Testosterona sin fracción quedó `no_match` con candidatos,
sin seleccionar uno. Fósforo urinario de 24 horas resolvió el concepto previo
`c1eebd27-328e-5fe9-bef2-7bc2c5f3d442`, distinto del nuevo fósforo genérico.
La lectura de decisiones confirmó **diez filas aún abiertas**: ocho de calcio
sin forma, una testosterona SEMIN sin fracción y la TGO SEMIN con muestra
contradictoria. No se eligió total/ionizado/libre por frecuencia.

La [identidad 04](../database/data/provider-identity-review-20261011-02.json)
registró **tres marcas y ocho sedes**, después de rollback sin auditorías/vínculos
persistentes, commit y consulta independiente de ocho auditorías/vínculos.

| Marca | IDs DENUE | Evidencia primaria vigente |
| --- | --- | --- |
| IB | 3326473, 9719873, 11747173 | [Sucursales oficiales](https://iblaboratorios.com.mx/sucursales/) |
| CEEAD | 9955322, 10827014, 3323894 | [Contacto](https://cdttexmelucan.com/contacto/) y [vínculo de razón social/matriz](https://cdttexmelucan.com/aviso-de-privacidad/) |
| Páez | 8150259, 10613366 | [Contacto oficial](https://paezlaboratorios.com/contacto/) |

Las capturas primarias dieron HTTP 200 y conservan hashes. La matriz CEEAD
3323894 coincide en Libertad Norte 306, Centro, San Martín Texmelucan y conserva
SCIAN 622111 / `location_type=hospital`. El renderer ahora admite clases de
hospital general explícitas por marca, comprobando la clase exacta en el RAW;
su valor por defecto sigue diagnóstico. No modifica esquema ni vínculos previos.
Las ocho sedes están `pending`, las tres marcas `verification_pending`.
Se conservan municipio/colonia/vialidad gubernamentales aunque IB, CEEAD y Páez
describan localidades o calles distintas; no se completan números/interiores.
El dominio común, marca y referencia de sede respaldan sólo identidad candidata,
sin afirmar dirección postal completa, habilitación ni estudio disponible.
Recibos, verificación y fuentes: `identity-review-04/`;
descubrimientos y holds: `identity-research-regional-06/`.

El corte remoto final confirmó **275 conceptos, 6,245 filas pendientes, 1,073
grupos, 48 marcas, 123 ubicaciones, 234 ofertas y 112 migraciones**. Políticas
de fuentes y ofertas no cambiaron. API/Admin/Paciente respondieron HTTP 200;
el ejecutor sigue vigilando la cola explícita cada 300 segundos.
El triage directo por PostgREST falló con error HTTP; se produjo el reporte
mediante las mismas RPC paginadas de sólo lectura y el canal Management ya
autorizado, sin cambiar claves o permisos:
`collectors/artifacts/normalization-triage-production-readonly-20261011-after-review-13.json`.
Resultado: 1,046 grupos `catalog_gap`, 27 con sugerencias, 26 con fuente oficial
de proveedor sin verificar y 1,073 con publicación comercial retenida.
Siguiente acción: revisar la corrección aislada T3 libre y continuar con grupos
clínicos/identidades que tengan evidencia suficiente. Los pendientes comerciales
y las ambigüedades impiden declarar terminada la operación autónoma completa.

### Continuidad posterior: revisiones 14–16 e identidad 05

El 11-oct se reutilizaron los tres agentes autorizados: autoanticuerpos,
vitaminas e identidades regionales. El coordinador investigó además serología
viral. Cada investigador preparó su fixture y evidencia; sólo después de leer
los resultados completos se fijaron sus hashes en la cola autorizada.

| Revisión aplicada | Conceptos / aliases | Filas | Distinciones conservadas |
| --- | ---: | ---: | --- |
| [14: autoanticuerpos](../database/data/reviewed-aliases-20261011-04.json) | 10 / 11 | 83 | SSA/Ro frente a SSB/La; anti-dsDNA, anti-21-hidroxilasa, centrómero, endomisio IgA, factor intrínseco, histona, GBM y AMA. |
| [15: vitaminas](../database/data/reviewed-aliases-20261011-05.json) | 10 / 10 | 80 | A/retinol, B1/tiamina, B12/cobalamina, B3/niacina, B6/piridoxina, C/ascórbico, D 25-hidroxi, D 1, 25-dihidroxi, E/tocoferol y folatos. |
| [16: anticuerpos virales](../database/data/reviewed-aliases-20261011-06.json) | 10 / 10 | 80 | HAV IgG/IgM/total, HBV core IgM/total, anti-HBe, anti-HBs, HCV total y CMV IgG/IgM. |

La cola ejecutó primero la revisión 16, después 14 y 15 según su orden de entrada,
con rollback, commit y ledger exacto para cada una. Terminó a las 14:44:39 UTC;
la consulta independiente confirmó los tres estados `already_applied`.
No hubo migraciones, ofertas nuevas, reproceso de pacientes/OCR ni nuevas suites.
Las treinta definiciones mantienen muestra/sistema/duración NULL: ninguna
entrada explicita una matriz y no se traslada el suero de las referencias.
Los once aliases de autoanticuerpos cubren 82 Salud Digna y uno Chopo; las
vitaminas y los anticuerpos virales cubren 80 Salud Digna cada uno.

Autoanticuerpos conserva nueve entradas con IgA explícita, sin elegir Ro52/Ro60,
M2, CENP-B, métodos, isotipos o variantes bloqueantes/de unión ausentes. La
corrección `GLUMERULAR` → glomerular mantiene el RAW intacto y el motivo trazable.
Fuentes primarias Mayo/ARUP/NHS y todos los RAW: `clinical-research/review-14/`.
Vitaminas no infiere B1 difosfato, B6 PLP, alfa-tocoferol ni composición D2+D3.
La etiqueta Chopo «25-hidroxi total» queda separada del D25OH genérico Salud
Digna; fuentes NIH y RAW: `clinical-research/review-15/`.

Serología viral separa anticuerpos de antígenos y pruebas moleculares, blancos
core/e/superficie, clases IgG/IgM y total. La fuente
[CDC: marcadores HAV](https://www.cdc.gov/hepatitis-a/hcp/diagnosis-testing/index.html)
distingue las tres formas; [CDC: HBV](https://www.cdc.gov/hepatitis-b/hcp/diagnosis-testing/index.html)
distingue anti-HBc IgM/total y anti-HBs del HBsAg, y
[su apéndice](https://www.cdc.gov/hepatitis/php/surveillance-guidance/appendices.html)
identifica anti-HBe. [CDC: HCV](https://www.cdc.gov/hepatitis-c/hcp/diagnosis-testing/index.html)
separa anti-HCV de RNA. La referencia
[Mayo CMV](https://www.mayocliniclabs.com/test-catalog/overview/621833)
identifica resultados IgG e IgM distintos; no se incorporó su prueba combinada,
método, suero, precio o LOINC. No se interpreta un resultado como infección ni
se añade una prueba refleja por una recomendación de diagnóstico. Las cuatro
descargas CDC dieron HTTP 200; Mayo se leyó por web y su descarga nativa devolvió
403, conservado sin evadir controles. Evidencia: `clinical-research/review-16/`.

La [identidad 05](../database/data/provider-identity-review-20261011-03.json)
añadió seis marcas candidatas y seis establecimientos, con rollback sin vínculos
persistentes, commit y seis auditorías/vínculos comprobados:

| Institución | DENUE | Evidencia oficial y discrepancia conservada |
| --- | --- | --- |
| GARDITEX | 3264716 | [Contacto](https://garditex.com/contacto/): Libertad Norte 211, Centro, Texmelucan coinciden; no se enlazan otros Garditex sin corroborar sede. |
| CHRISTUS MUGUERZA Betania | 6377334 | [Sede](https://www.christusmuguerza.com.mx/hospital-betania/): número DENUE 1828 frente a 1826 oficial. |
| Hospital Angeles Puebla | 6272674 | [Sede](https://hospitalangeles.com/puebla): vialidad Acuario frente a Kepler; mismo dominio, institución y exterior 2143. |
| Hospital MAC Puebla | 9278020 | [Sede](https://hospitalesmac.com/hospitales/hospital/puebla): CP DENUE 72810 frente a 72820; Periférico 3507 y municipio coinciden. |
| Hospital Puebla | 6378398 | [Contacto](https://hospitalpuebla.com.mx/es/pacientes-internacionales-contacto): vialidad DENUE NINGUNO frente a Ramblas; assets públicos enlazados corroboran exterior 4/CP72197. |
| Beneficencia Española | 10470110 | [Página institucional](https://maternidad.beneficenciaespanola.com.mx/): número DENUE 1012 frente a 1001; conserva institución, vialidad 19 Norte, colonia y CP. |

Todas las capturas oficiales utilizadas dieron HTTP 200 con hashes. Las cinco
sedes hospitalarias conservan SCIAN 622111 / `hospital`; GARDITEX conserva
621511 / `branch`. Las seis ubicaciones siguen `pending` y marcas
`verification_pending`, sin completar domicilios ni acreditar servicios/licencias.
La revisión de variantes confirmó que no había marcas CHRISTUS/Ángeles/MAC
previas; Laboratorio Clínico Especializado Los Ángeles es una institución y
dominio distintos. Recibos reales: `identity-review-05/`; snapshots y decisiones:
`identity-research-regional-07/`. BIOSCAN queda retenido por domicilio actual
totalmente distinto; el dominio DENUE de FiftyDoctors ahora sirve otra empresa.
Los dominios que fallaron se registran sin repetir intentos iguales.

Los hashes de las revisiones 14/15/16 son respectivamente:
`044af80ffb6ccddcda5a4f06f5e0c18971d5fd149c64f1e1977f16dacaa3aba9`,
`fcb7f6cb4b241485ed863f4e95b2880494fd72c0f954d41ba30e819cd64663c4` y
`122feab2eb731363b3a93d064dae7c3da489d121b510902eeb762e79f2ccb4ac`.
Recibos reales en los subdirectorios `pruevia-evidence-review-20261011-04`,
`-05` y `-06` de `collectors/artifacts/local-review-queue/`; los previews locales
de los agentes siguen conservando su estado histórico de preparación.

La resolución local confirmó **21/21** consultas exactas de autoanticuerpos,
**20/20** de vitaminas y **20/20** de serología viral. Una primera pasada de
serología se interrumpió por una respuesta HTTP no exitosa; la nueva pasada
completa guardó las veinte respuestas exitosas. No se atribuye una causa sin
diagnóstico. Las tres apps volvieron a responder HTTP 200.

Variantes con forma ausente permanecieron `no_match` para D25OH total, B12
activa, B6 PLP, tiamina difosfato y CMV PCR. SSA/Ro52 y AMA/M2 devolvieron
`ambiguous` hacia la familia sin escoger la subfracción. HAV sin clase quedó
`ambiguous`. Antígeno de superficie HBV y DNA HBV quedaron `no_match`, sin
seleccionar anti-HBs o anti-HBc. T3 libre conserva el bloqueo anterior.

**Hallazgo de candidatos incompatibles:** antiendomisio IgG devolvió
`ambiguous`, pero incluyó el nuevo concepto antiendomisio IgA. No hubo selección
automática ni decisión persistente de esa consulta sintética; aun así, presentar
IgA como candidato de IgG requiere corregir el filtro de variantes. No se afirma
que todas las variantes clínicas están preservadas por funcionar los exactos.
Evidencia: `review-16/local-resolver-outside-scope.json`; diagnóstico/propuesta
separados de la cola de aliases, sin activar cambios clínicos.
El [diagnóstico de inmunoglobulinas](proposals/20261011-antibody-variant-candidates.md)
confirmó que v1 no marca conflicto IgG/IgA y v2/v3 omiten el token de tres letras
`igg`. Las respuestas por capa y las definiciones vigentes están en
`review-14/antibody-variant-*.json`. La propuesta preserva clases desconocidas,
paneles y subclases; requiere preparar un diff aislado y revisable antes de
solicitar la aprobación crítica de AGENTS/DECISIONS. No se activó el filtro.

El corte remoto estable contiene **305 conceptos, 6,002 filas / 1,042 grupos,
54 marcas, 129 ubicaciones, 234 ofertas y 112 migraciones**. Fuente/políticas,
ofertas y ledger de migraciones coinciden con el estado anterior. Triage final:
`collectors/artifacts/normalization-triage-production-readonly-20261011-after-review-16.json`:
1,014 brechas, 28 grupos con sugerencias y 1,042 con publicación comercial
retenida. La consulta directa de RPC por PostgREST volvió a responder 200;
el CLI terminó un snapshot histórico previo de 1,073 grupos/6,245 filas.
El reporte final se obtuvo después de los commits mediante las mismas RPC
paginadas por Management y se contrastó con el baseline estable. No se cambió
credencial o permiso para hacerlo funcionar.
Siguiente acción de ese corte: continuar identidades y grupos clínicos con evidencia;
revisar las propuestas de filtros clínicos bajo la aprobación crítica correspondiente.

### Continuidad posterior: revisiones 17–18 e identidad 06 — 11-oct

Se retomaron los tres agentes autorizados para autoanticuerpos,
marcadores/metabolismo e identidad pública. Los tres terminaron con límite de uso;
el agente principal continuó desde sus artefactos, releyó contexto/catálogo vigente
y completó los lotes. No se atribuyen aplicaciones a los agentes detenidos.

| Revisión | Identidades aprobadas | Alias / conceptos / filas |
| --- | --- | --- |
| [17](../database/data/reviewed-aliases-20261011-07.json) | Beta-2 glicoproteína IgA/IgG/IgM, cardiolipina IgA/IgG/IgM, anti-TPO, anti-CCP, anti-Sm y músculo liso; clases explícitas y órdenes individuales. | 10 / 10 / 80 Salud Digna |
| [18](../database/data/reviewed-aliases-20261011-08.json) | AFP, alfa-1 antitripsina, CEA, CA125, CA15-3, CA19-9, CA27.29, PSA total, PSA libre y ácidos biliares totales. | 13 / 10 / 80 Salud Digna + 3 SEMIN |

Los veinte conceptos son órdenes por analito con muestra y duración NULL.
Los tres RAW de SEMIN explicitan suero para CEA, CA125 y CA19-9: guard exacto y
atributos conservados en sus decisiones, sin trasladarlos a Salud Digna ni al
concepto. El acumulado tiene 36 conceptos con muestra explícita y cien órdenes
genéricas; 18 decisiones SEMIN conservan suero y 152 Salud Digna la familia
sangre de revisiones previas. No se infieren paneles, métodos, LOINC, composición,
dominio I, F-actina, Sm/RNP, CCP2/3, genotipo, AFP-L3, fracciones ni cocientes PSA.
El texto promocional SEMIN sobre diagnóstico no se adopta como afirmación clínica.

Fuentes y límites: `clinical-research/reviews-17-18-research.md` y
`reviews-17-18-source-snapshots/receipts.json`: diecisiete descargas, siete HTTP200
MedlinePlus y diez HTTP403 Mayo, cuyas páginas se leyeron por web. Hashes 17/18:
`c18c0624c65864fc34e9c28227e597a9f2e4788d7c3ba7defb4d2a5414299f63` y
`74ce7ee040c3edce4d2101142f95b20948a90d206dd996be6a757b1abae137d5`.

**Detención y recuperación:** el lote 17 cerró 80 filas. El preview 18 dio
HTTP400; el proceso terminó y el ledger seguía vacío. El guard RAW comprobaba
una fila histórica PSA total con decisión terminal, fuera de las 83 elegibles.
Se corrigió [el renderer](../database/scripts/reviewed_alias_batch.py) para
usar la misma elegibilidad que el conteo: crawler sin decisión final. El nuevo
diagnóstico rollback dio HTTP201, exactamente 83 selecciones y cero fuera de
alcance; ledger aún vacío antes de reiniciar una sola cola. Después completó
rollback, commit y ledger de 83. No se alteraron decisiones históricas ni
funciones clínicas para desbloquearlo. Evidencia: `review-18/stopped-preview-diagnostic.json`,
`executor-stop-before-restart.json` y recibos del ejecutor en
`collectors/artifacts/local-review-queue/pruevia-evidence-review-20261011-07/`
y `-08/`. La cola tiene doce entradas explícitas, revisiones 07–18.

HTTP local confirmó **20/20** consultas exactas del lote 17 y **23/23** del 18.
Nueve de diez variantes fuera de alcance quedaron `no_match`; **`alfa
fetoproteina l3` seleccionó erróneamente AFP genérica**, confianza 0.857143,
`word_fuzzy`. Todas las capas v1–v6 conservaron el candidato. El
[diff AFP-L3 y recuperación](proposals/20261011-afp-l3-candidate-conflict.md)
están preparados fuera de migraciones/cola, sin ejecutarlos. AGENTS/D-006 exige
aprobación crítica específica del nuevo filtro clínico común. T3 libre y el
candidato IgA para IgG siguen pendientes; no se afirma preservar todas las variantes.

La [identidad 06](../database/data/provider-identity-review-20261011-04.json)
añadió dos instituciones candidatas y tres hospitales `pending`, SCIAN 622112:

| Institución / sede | DENUE | Corroboración y discrepancia conservada |
| --- | --- | --- |
| IMSS-Bienestar / General del Norte | 3254170 | Fuente federal y estatal corroboran sede territorial; CP72200 DENUE frente a CP72430 estatal. |
| IMSS-Bienestar / General San Andrés Cholula | 3339593 | Institución, municipio/zona corroborados; DENUE Periférico sin número/CP72820 frente a estatal Osa Mayor 2 y federal Osa Menor 2/CP72810. |
| ISSSTE / Clínica Hospital Tehuacán | 3258609 | Doctor Manuel Pereyra Mejía 1009/Cerritos coinciden; CP75731 DENUE frente a CP75730 federal. |

Se conserva la dirección DENUE original, incluso número ausente/CP discordante.
[Publicación federal del 14-may-2026](https://www.gob.mx/salud/es/articulos/recomendaciones-de-salud-durante-los-eventos-del-mundial-en-mexico-2026?idiom=es):
HTTP200 nativo, once hospitales Puebla con institución explícita.
[Directorio estatal](https://ss.puebla.gob.mx/directorio-hospitales-y-c-de-salud):
HTTP200, actualizado 16-dic-2025; sus recursos públicos enlazados dieron 635
unidades y cinco consultas acotadas HTTP200. JSONP parseado como JSON con
wrapper fijo, sin `eval`. Se utilizaron identidad, dirección/coordenadas y CLUES;
no se importó personal ni se infirieron estudios, acceso o derechohabiencia.
IMSS-Bienestar no se fusiona con IMSS ordinario, ISSSTE o ISSSTEP. SCIAN solo
incluye también bodegas y no prueba hospital ni institución operadora.

Rollback/commit y tres vínculos/auditorías comprobados: `identity-review-06/`.
Fixture aplicado SHA256 `0618c0c911745d20af5c527ccf16ae60fae482009dc27ac1ac8367857f9bee8f`.
`prepared.json` conserva el hash anterior a corregir la fecha primaria 13 a 14
de mayo, antes de ejecutar; preparación histórica sustituida por
`applied-verified.json`. Snapshots: `identity-research-regional-08/`.
Huauchinango/Teziutlán ISSSTE siguen retenidos por identidad/domicilio insuficientes;
Tepeaca, Zacatlán y Teziutlán regionales requieren institución vigente corroborada,
sin deducirla del prefijo CLUES. No se reaplicó el lote ni se generaron ofertas.

**Cierre observado a las 19:54 UTC:** 18 revisiones clínicas, 162 aliases
(158 globales/cuatro de proveedor), 136 conceptos y 1,189 filas crawler resueltas;
325 conceptos activos, 5,839 pendientes / 1,019 grupos, 56 marcas y 132 ubicaciones.
Seis revisiones de identidad suman 18 instituciones y 45 sedes nuevas pendientes.
Continúan 234 ofertas / 112 migraciones y las mismas políticas de fuentes.
El triage completo `normalization-triage-production-readonly-20261011-after-review-18.json`
contiene 990 brechas y 29 grupos con sugerencias; los 1,019 mantienen bloqueo
comercial. API/Admin/Paciente respondieron HTTP200. PID5608/comando del ejecutor
confirmados, vigilancia cada 300 segundos; handle65554. Evidencia:
`clinical-research/closing-baseline-after-review-18.json`,
`closing-counters-after-review-18.json`, `closing-triage-receipt.json`
y `closing-local-operation.json`. Se comprobaron hashes del fixture de identidad
y del diff clínico. No se ejecutaron suites ni el diff clínico, migraciones,
despliegues, nuevas capturas comerciales o contactos.

Siguiente acción: investigar términos pendientes y reconciliar instituciones
regionales; preparar el diff de inmunoglobulinas y conservar las propuestas
clínicas aisladas hasta su autorización específica.

### Continuidad posterior: revisiones 19–20 — 11-oct

Se investigaron trece órdenes serológicas individuales, con RAW completo, nombres,
aliases, componentes y colisiones del catálogo vigente consultados de nuevo.
La [revisión 19](../database/data/reviewed-aliases-20261011-09.json) añadió nueve
conceptos/aliases: EBV VCA IgG/IgM, EBNA IgG, EA IgG, VZV IgG, HSV tipo1/tipo2
IgG y rubéola IgG/IgM. Cerró 73 filas, 72 Salud Digna y una SEMIN.
La [revisión 20](../database/data/reviewed-aliases-20261011-10.json) añadió cuatro
conceptos/aliases: parvovirus B19 IgG/IgM y toxoplasma IgG/IgM; cerró 32 filas SD.
Todos los conceptos son órdenes por analito con muestra/system/duración NULL;
SEMIN varicela IgG conserva suero sólo en metadata de su propia decisión y guard
`2 ml Suero. Refrigerado`. No se trasladó a Salud Digna ni al concepto genérico.

[CDC EBV](https://www.cdc.gov/epstein-barr/php/laboratories/index.html),
[Mayo EBVAB](https://www.mayocliniclabs.com/test-catalog/overview/621373) y
[EAEBV](https://www.mayocliniclabs.com/test-catalog/overview/621374) distinguen los
blancos/clases; no se importó el perfil, heterófilos, DNA, EBNA-1 o subfracción EA.
[Mayo HSVG](https://www.mayocliniclabs.com/test-catalog/overview/84429) y
[VZPG](https://www.mayocliniclabs.com/test-catalog/overview/34944) permiten distinguir
tipos HSV de VZV sin inferir método o muestra.
[CDC rubéola](https://www.cdc.gov/rubella/php/laboratories/serology-testing.html) y
[MedlinePlus español](https://medlineplus.gov/spanish/rubella.html) identifican
rubéola como Rubella, sin confundirla con el inglés rubeola/sarampión.
[Mayo PARVS](https://www.mayocliniclabs.com/test-catalog/overview/48395) y
[TXMGP](https://www.mayocliniclabs.com/test-catalog/overview/802127) separan clases.
Las referencias de perfiles sustentan identidades individuales, no disponibilidad
por sede ni composición comercial. No TORCH, avidez, PCR, diagnóstico, inmunidad
o recomendación de screening inferidos. Ocho EBNA IgM siguen pendientes por
evidencia insuficiente; no se corrigió esa clase a IgG ni se la declaró inválida.

Un borrador inicial de trece conceptos fue rechazado por el límite existente de
diez por lote. Se confirmó que no estaba en cola ni aplicado, se conservó el
borrador y se dividió en nueve/cuatro; no se alteró el límite. Contextos,
investigación y recibo de partición: `clinical-research/review-19/`. Las nueve
fuentes fueron leídas por web; capturas nativas: tres HTTP200 y seis Mayo HTTP403,
con fecha/hash conservados sin evadir el acceso. El documento `research.md`
diferencia alcance conjunto y límites por identidad.

Hashes fijados de los lotes 19/20:
`16a8c39851e340dd1db68639e3af08f860c1b1649a0f526a5d83233d72711ded` y
`c3fd950d81e8ba468118fa7be86740c0d67f1c8cc493f2a1834b2136bd45b848`.
La cola existente PID5608/handle65554 completó rollback, commit y ledger:
73/32 resueltos, cero ofertas, estado `applied_verified` a las 20:08 UTC.
Recibos reales: `collectors/artifacts/local-review-queue/pruevia-evidence-review-20261011-09/`
y `-10/`. Cola explícita de catorce entradas, revisiones 07–20; sin proceso duplicado.
HTTP posterior confirmó **18/18 + 8/8 consultas exactas**, con ID esperado.

Diez variantes sintéticas fuera de alcance: nueve `no_match` y una `ambiguous`.
Algunas `no_match` siguen devolviendo candidatos incompatibles; el estado no
acredita filtrado clínico de toda la lista. **Toxoplasma IgA incluye el nuevo
IgG** (`d6a57042-fd36-5115-b38c-4b370ea0e48f`, confianza 0.892857), por delante
del concepto IgA previo. No hubo selección automática ni oferta. Evidencia:
`review-20/outside-scope-resolver.json`; añadido a la
[propuesta de inmunoglobulinas](proposals/20261011-antibody-variant-candidates.md).
T3 libre y AFP-L3 permanecen sin corregir. No se activaron funciones clínicas.

**Corte remoto/localhost a las 20:10 UTC:** 20 revisiones, 175 aliases
(171 globales/cuatro de proveedor), 149 conceptos nuevos (36 con muestra y 113
por analito), 1,294 filas cerradas. Hay 338 conceptos activos; quedan 5,734 filas
en 1,005 grupos, 976 brechas y 29 con sugerencias. Las 19 entradas SEMIN con
suero y 152 SD con familia sangre se conservan por fuente. Continúan 56 marcas,
132 ubicaciones, 234 ofertas, 112 migraciones y las mismas políticas.
API/Admin/Paciente respondieron HTTP200; PID/comando vivo de la cola comprobados.
Triage completo: `normalization-triage-production-readonly-20261011-after-review-20.json`.
Recibos baseline/contadores/paginación/procesos: `clinical-research/review-20/closing-*.json`.
No suites, migraciones, despliegues, capturas comerciales o contactos nuevos.

**Discovery regional 09:** la
[fuente estatal del 22-ene-2026](https://www.puebla.gob.mx/index.php/noticias/item/22235-gobierno-de-puebla-contribuye-a-salvar-vidas-con-traslado-aereo-de-higado-a-ciudad-de-mexico)
confirma Hospital General de Zacatlán del IMSS-Bienestar. GET nativo HTTP200
confirmó institución y fecha, aunque lectura web devolvió502. DENUE3511000 y
directorio estatal unidad11/CLUES PLSSA015551 coinciden en nombre, Roble/San
Bartolo/CP73310; se conserva exterior ausente DENUE frente a 7 estatal. Sólo se
guardó fragmento institucional, fecha/hash, sin narrativa de pacientes. Ya existe
una única marca IMSS-Bienestar; el renderer actual crea marcas nuevas y no permite
reusar ésta. Evidencia y siguiente trabajo: `identity-research-regional-09/research.md`.
No se duplicó la marca ni se vinculó aún esta sede.

Siguiente acción: preparar el diff clínico de inmunoglobulinas y continuar datos
claros; ampliar el renderer para añadir sedes a una marca existente con identidad
exacta protegida y auditoría, sin reescribir marca ni publicar ofertas.

### Revisión de identidad 07 y diff de inmunoglobulinas — 11-oct-2026

Se completó el siguiente trabajo del corte anterior. El renderer admite
`existing_brand` con siete campos exactos de identidad/estado, lock de fila y
comparación del snapshot completo. No actualiza la marca existente; separa en
el recibo marcas nuevas y reutilizadas y conserva los guards de colisión/replay.
La [revisión 07](../database/data/provider-identity-review-20261011-05.json),
request `pruevia:provider-identity-review:20261011:05`, añadió una sede hospitalaria
`pending` para DENUE3511000 bajo IMSS-Bienestar existente. La evidencia institucional
estatal y territorial está en `identity-research-regional-09/`. Conserva
`CALLE DEL ROBLE SN`, San Bartolo/73310; no infiere el número7 del directorio.

Rollback devolvió cero marcas nuevas, una reutilizada y una sede ensayada;
la lectura posterior confirmó cero vínculo/ledger. Commit y lectura confirmaron
un vínculo, una observación aceptada y una auditoría, con evidencia/reason
persistidos y **fila completa de la marca idéntica** antes/después. Artefactos:
`identity-review-07/preview-receipt.json`, `apply-receipt.json`, `verified.json`,
`observations.json`, `audit-receipt.json`, `full-brand-before.json`,
`full-brand-after.json`, `after-baseline.json`, `applied-verified.json`.
Fixture SHA-256: `0d846fd7704c7fdf2b297c2948ce46665b020fadc3b5d5e2f72387541f244be5`.
Siete revisiones de identidad suman 18 instituciones nuevas /46 sedes pendientes;
ahora hay **56 marcas /133 ubicaciones**. Commit y verificación: 20:24:45 UTC.
Permanecen 338 conceptos, 5,734 filas
pendientes, 234 ofertas activas, 112 migraciones y las mismas políticas comerciales.
No suites, migraciones, despliegues, costos ni contactos nuevos.

A las **20:27:55 UTC**, API/Admin/Paciente volvieron a responder HTTP200. La
cola informó `watching` y el PID5608 fue comprobado vivo con su comando de
ejecutor. El hash remoto del resolver sigue siendo el original: ningún borrador
clínico fue activado. Recibos: `identity-review-07/closing-baseline.json` y
`closing-local-operation.json`. Los tres agentes delegados continúan en error
por límite de uso; el trabajo anterior lo ejecutó el agente principal.

También se prepararon el [diff exacto y recuperación de inmunoglobulinas](proposals/20261011-antibody-variant-candidates.md),
sin ejecutar. Inventario: 25 componentes individuales canónicos con una clase
explícita y revisión registrada. Compara contradicciones positivas antes de
orden/estado; desconocidos, paneles y subclases quedan fuera. La lectura de
permisos mostró que `service_role` no lee `audit.events` directamente; se quitó
esa dependencia del cuerpo del borrador sin ampliar permisos. MD5 remoto actual
`067b7a2fe0826ccaa48ece0a5dfd8d1d`, esperado del borrador
`999a96985e1f847b51f5c685cfb80c35`. Recibos de lectura/inventario/consumidores/diff
en `clinical-research/antibody-filter-draft/`. La activación requiere aprobación
específica por AGENTS/D-006 y nueva migración; T3/AFP-L3 comparten el hash base y
deben revalidarse al activar cualquier propuesta. Ningún filtro clínico se activó.

Siguiente acción independiente: investigar el próximo lote clínico claro y
nuevas sedes con fuentes suficientes. El ejecutor sigue vigilando únicamente
fixtures aprobados y fijados por hash; no decide nuevas identidades por sí solo.

### Revisión clínica 21: fármacos, 66 filas — 11-oct-2026

La [revisión 21](../database/data/reviewed-aliases-20261011-11.json), request
`pruevia:evidence-review:20261011:11`, añadió ocho órdenes por analito y nueve
aliases exactos. Cerró 64 filas SD y dos SEMIN mediante la cola existente,
rollback/commit y ledger `applied_verified` a las **20:34:21 UTC**.

| Orden | Fuente primaria de identidad | Filas |
| --- | --- | ---: |
| Ciclosporina | [Mayo CYSPR](https://www.mayocliniclabs.com/test-catalog/overview/35143) | 8 SD |
| Fenobarbital | [Mayo PBR](https://www.mayocliniclabs.com/test-catalog/overview/37049) | 8 SD |
| Lamotrigina | [Mayo LAMO](https://www.mayocliniclabs.com/test-catalog/overview/80999) | 8 SD |
| Levetiracetam | [Mayo LEVE](https://www.mayocliniclabs.com/test-catalog/overview/83140) | 8 SD |
| Litio | [Mayo LITH](https://www.mayocliniclabs.com/test-catalog/overview/37046) | 8 SD |
| Sirolimus (rapamicina), Rapamune | [Mayo SIIRO](https://www.mayocliniclabs.com/test-catalog/overview/35144) | 8 SD +1 SEMIN |
| Tacrolimus | [Mayo TAKRO](https://www.mayocliniclabs.com/test-catalog/overview/35145) | 8 SD |
| Topiramato | [Mayo TOPI](https://www.mayocliniclabs.com/test-catalog/overview/81546) | 8 SD +1 SEMIN |

Se reconoce sólo la orden individual por analito; muestra/system/time_aspect
quedan NULL. No interpretar concentraciones, dosis, toxicidad o tratamiento;
no importar método, unidades, LOINC o intervalos del laboratorio de referencia.
El ayuno y horario de dosis no prueban muestra ni se reinterpretan como valle.
Los originales y preparaciones conservan su alcance por fuente.

SEMIN topiramato declara `4 ml de Suero Refrigerado`: suero sólo en metadata
de su decisión/guard. SEMIN sirolimus declara `4 ml Sangre Total. Refrigerado`:
texto exacto en RAW/`reviewed_raw_guard` y razón; no convertir a suero, inferir
EDTA o trasladar a SD. El renderer no declara un código de sangre total nuevo.
Los 66 guards y las dos decisiones SEMIN se releyeron en remoto.

**Ambigüedad retenida:** 40 filas, ocho por etiqueta. Digoxina, ácido valproico,
carbamazepina y fenitoína no declaran fracción libre/total; oxcarbazepina no
declara si el analito final es fármaco o metabolito. Fuentes primarias:
[FRDIG](https://www.mayocliniclabs.com/test-catalog/overview/82130),
[VALPG](https://www.mayocliniclabs.com/test-catalog/overview/37067),
[CARTF](https://www.mayocliniclabs.com/test-catalog/overview/37037),
[PNYF](https://www.mayocliniclabs.com/test-catalog/overview/37052),
[OMHC](https://www.mayocliniclabs.com/test-catalog/Overview/81030).
No se elige una fracción o metabolito por costumbre; lectura posterior confirmó
las 40 aún abiertas. Falta evidencia de esas variantes por la fuente.

El lector web consultó fuentes primarias; las 15 descargas HTML nativas Mayo
devolvieron403, conservadas con fecha/URL/hash en recibos. Los HTML son esas
respuestas, no capturas comerciales exitosas. No se sortearon controles ni se
aprobó disponibilidad o política comercial por la lectura de identidad.

**Lecturas localhost:** 17/17 aliases/nombres exactos resolvieron el ID esperado.
Doce vecinos dieron `no_match`. `ciclosporina c2` dio HTTP200/`resolved` con
Ciclosporina genérica, ID `850af085-2f39-5cd5-b2ef-2962bc3789ea`, confianza0.88,
`word_fuzzy`, sin ofertas. La consulta original persiste; C2 no se representa
como atributo estructurado. CYSPR admite C2 dos horas después de dosis, pero
sus intervalos de valle no aplican allí. Es el mismo analito: no afirmar droga
equivocada ni equivalencia de resultados entre momentos. La lectura de v1–v6
confirmó candidato retenido, cero atributos y sólo un token significativo
en v2/v3; componente/muestra/time_aspect no declaran C2 o valle. Registrar y
preparar el alcance del momento de toma antes de cambiar contrato clínico.
No se activó una corrección del resolver ni se reinterpretó preparación SD.

**Corte 20:36:52 UTC:** 21 revisiones/184 aliases (180 globales/cuatro de proveedor),
157 conceptos nuevos (36 con muestra/121 por analito), 1,360 filas cerradas.
Quedan **5,668 filas/995 grupos**; 346 conceptos activos, 966 brechas/29 con
sugerencias, todos los grupos con hold comercial. Se conservan 20 sueros SEMIN,
152 familias sangre SD y un guard SEMIN de sangre total. Continúan 56 marcas,
133 ubicaciones, 234 ofertas, 112 migraciones y mismas políticas. API/Admin/Paciente
HTTP200; PID/comando de la cola confirmado vivo. No suites, nuevas ofertas,
migraciones, cambios de funciones, costos, contactos o despliegues.

Artefactos: `clinical-research/review-21/research.md`, `prepared.json`,
`enqueue-receipt.json`, `ledger-after.json`, `local-resolver.json`,
`outside-scope-resolver.json`, `source-context-decisions.json`,
`held-neighbors-after.json`, `applied-verified.json`, `timing-*.json`,
`closing-baseline-after-review-21.json`, `closing-counters-after-review-21.json`,
`closing-triage-receipt.json` y `closing-local-operation.json`.
Fixture SHA-256 `8ff8487f98d9784273db8f9d45da622af362a4fb22b93ea6616fc0de8b89fe43`.
Recibos del ejecutor:
`collectors/artifacts/local-review-queue/pruevia-evidence-review-20261011-11/`.
Triage completo: `normalization-triage-production-readonly-20261011-after-review-21.json`.

Siguiente acción: investigar el próximo lote claro y nuevas sedes con evidencia;
conservar las variantes inciertas y las propuestas clínicas sin activar.
La cola tiene quince fixtures explícitos por hash; no investiga casos nuevos.

### Discovery regional 05: faltan fuentes vigentes

Se revisaron candidatos DENUE de Cuauhtémoc (Xicotepec), Galenus (Palmar de
Bravo), Pasteur (Acatzingo) y de la Hoz (Sierra Nororiental). Las lecturas actuales
fallaron: Cuauhtémoc respondió `404`; los otros tres dominios produjeron
`ConnectError` en la descarga nativa. El navegador tampoco permitió abrir los
dominios con/sin `www`; no se desactivaron TLS ni controles de acceso.

La [página indexada de de la Hoz](https://laboratoriosdelahoz.mx/) conserva una
lista histórica, con antigüedad indicada de 8.1 años. Se encontraron coincidencias
de calle/número con seis registros DENUE: La Mesilla 6 y Juan C. Bonilla 200 en
Teziutlán, Reforma 157 en Tlatlauquitepec, 3 Sur sin número en Zaragoza,
José María Morelos 20 en Hueytamalco y 3 Poniente 9 en Atempan. Se conservaron
como candidatos; no se aplicaron nuevas vinculaciones con esa lectura histórica
como única evidencia primaria. Zacapoaxtla y otra sede de Teziutlán tienen calles
distintas respecto al índice. No se fusionó el grupo de la Hoz & Cristal de
Puebla/Cholula ni sedes omitidas en la página por compartir nombre.

Evidencia y decisiones: `collectors/artifacts/puebla-expansion-20261009/identity-research-regional-05/`.
Siguiente acción: localizar dominios/canales primarios vigentes y resolver
afiliaciones y diferencias de domicilio; no repetir las mismas capturas fallidas.

### Recuperación y arranque local

El 11-oct no existían los procesos anteriores ni listeners en 8787/5173/8080.
Se recuperaron usando los comandos existentes, y las tres rutas locales
respondieron `200`; se confirmó el PID/comando de la cola y sus cuatro revisiones
07–10 `already_applied`. Los archivos de estado antiguos no se tomaron como
evidencia de ejecución viva.

Se instaló `PrueviaLocal.lnk` en Inicio del usuario Windows actual mediante
el [launcher Python](../scripts/start_pruevia_local.py). La ejecución efectiva
del launcher conservó los tres puertos ocupados y el worker ya vivo, sin duplicarlos.
El acceso fue leído después de instalarse; todavía no se observó otro login
ni el arranque de un componente ausente. No se alteró la política de ejecución
PowerShell que impedía usar un archivo `.ps1`. Recuperación, paradas y límites:
[arranque local](OPERATIONS_GUIDE.md#arranque-local-al-iniciar-sesión-en-windows).
La cola necesita el equipo encendido y sólo procesa investigación concluida;
no se convirtió en un investigador permanente de casos nuevos.

## Primera revisión delegada aplicada

Se comparó el RAW existente con el concepto canónico y se investigaron fuentes
primarias. Sólo se aprobaron las seis cadenas exactas de la
[revisión fechada](../database/data/reviewed-aliases-20261009.json).

| Término revisado | Concepto conservado | Filas cerradas | Evidencia terminológica |
| --- | --- | ---: | --- |
| Anticuerpos anti Mycoplasma pneumoniae IgG | AC Mycoplasma pneumoniae IgG (L) | 8 | [Mayo: IgG](https://www.mayocliniclabs.com/test-catalog/Overview/802228) |
| Anticuerpos anti Mycoplasma pneumoniae IgM | AC Mycoplasma pneumoniae IgM (L) | 8 | [Mayo: IgM](https://www.mayocliniclabs.com/test-catalog/overview/48318) |
| Anticuerpos anti tiroglobulina | AC ANTI TIROGLOBULINA | 8 | [MedlinePlus: anticuerpos antitiroideos](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-anticuerpos-antitiroideos/) |
| Dihidrotestosterona DHT | 5 alfa dihidrotestosterona | 8 | [Mayo: nombres de DHT](https://www.mayocliniclabs.com/test-catalog/overview/81479) |
| Hormona estimulante de la tiroides | TSH | 1 | [MedlinePlus: TSH](https://medlineplus.gov/spanish/ency/article/003684.htm) |
| Ultrasonido abdomen superior | ULTRASONIDO ABDOMINAL SUPERIOR | 1 | [RSNA/ACR: ecografía abdominal](https://www.radiologyinfo.org/es/info/abdominus) |

Son equivalencias de nombre; no se trasladaron métodos, preparación, muestras
ni rangos de los laboratorios externos. IgG/IgM y el panel combinado siguen
separados; anti-tiroglobulina no se convirtió en tiroglobulina ni anti-TPO;
ultrasonido superior no se amplió a pelvis, Doppler ni abdomen completo.
La ausencia de muestra/anatomía estructurada en estos conceptos queda explícita
en el artefacto de revisión, no se completó por inferencia.

El [renderer acotado](../database/scripts/reviewed_alias_batch.py) comprobó
concepto/nombre/tipo activo, colisiones, términos de desambiguación, marca y
conteo de las filas. Tras insertar los aliases dentro de la misma transacción,
exigió que la RPC exacta sólo pudiera seleccionar esas **34 filas del crawler**;
ninguna búsqueda de pacientes u OCR se reprocesó. El ensayo con rollback devolvió
34 resueltas y se comprobó que no dejó aliases. La aplicación posterior confirmó
seis aliases y 34 decisiones, sin ofertas nuevas ni políticas alteradas.
La auditoría identifica investigación delegada de Codex y `human_review=false`;
no atribuye una revisión clínica humana al operador.

La cola quedó en **6,994 filas / 1,182 grupos**. El nuevo triage tiene 1,162
grupos sin candidato útil y 20 con sugerencias. Los seis términos respondieron
`resolved` mediante la API local; los registros de comprobación están junto a
los recibos. Antes de las escrituras, el runner completo de contratos remotos
conservó y aprobó **31 contratos / 531 aserciones**. Esa suite precede a esta
carga/revisión; no se presenta como una ejecución posterior a los cambios.

## Evidencia local y continuidad

### Segunda y tercera revisión aplicadas

La [revisión 02](../database/data/reviewed-aliases-20261009-02.json) añadió seis
aliases y cerró 37 filas: MHPG, 17-alfa-hidroxiprogesterona y cuatro nombres de
radiografías. [PubChem CID 10805](https://pubchem.ncbi.nlm.nih.gov/compound/Methoxyhydroxyphenylglycol)
respalda la equivalencia phenylglycol/phenylethyleneglycol; no se extendió a
aldehídos, conjugados ni muestras específicas. [Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/9231)
respalda el nombre de 17-alfa-hidroxiprogesterona; no se eligió su variante en
lactantes. Las cuatro etiquetas radiográficas conservan anatomía, AP/lateral,
posición de pie/decúbito y comparación. Se limitaron al proveedor Salud Digna y
se comprobó `raw_study.Estudio=RAYOS X` en las 28 filas seleccionadas al aplicar.
La categoría RAW acredita la modalidad en este lote; no se amplía a consultas
genéricas sin proveedor. Referencias:
[RSNA/ACR, radiografía abdominal](https://www.radiologyinfo.org/es/info/abdominrad) y
[NCBI, radiografías del antebrazo](https://www.ncbi.nlm.nih.gov/books/NBK574580/).

La [revisión 03](../database/data/reviewed-aliases-20261009-03.json) cerró otras
ocho filas de `17 alfa hidroxi progesterona`, variación de separación de palabras
del analito ya investigado. Los ensayos de ambos lotes conservaron sus recibos
y comprobaron rollback antes de aplicar; las aplicaciones confirmaron 37 y ocho
decisiones respectivamente, sin seleccionar búsquedas/OCR ni crear ofertas.
Los dos nuevos nombres globales de la revisión 02 respondieron `resolved` con
el ID canónico esperado desde la API local. El renderer ahora admite fixtures
fechados, scopes global/proveedor y guardas de contexto RAW; se detiene ante
colisión, un lote ya aplicado o filas distintas de las investigadas.

Se corrigió además el triage: `sin contraste` ya no agrega una afirmación de
contraste positivo; conserva ambos componentes si se piden simple y contrastado.
Los modificadores `comparativo` y de población neonatal/pediátrica se conservan
al filtrar candidatos incompletos. No se activó aprobación fuzzy ni scheduler.

### Cuarta revisión: conceptos ausentes con muestra explícita

La [revisión 04](../database/data/reviewed-aliases-20261009-04.json) creó seis
conceptos de laboratorio y seis aliases, cerrando otras 48 filas de Salud Digna:

| Concepto independiente del proveedor | Filas | Evidencia principal |
| --- | ---: | --- |
| Paracetamol en suero | 8 | [Mayo, acetaminofén sérico](https://www.mayocliniclabs.com/test-catalog/Overview/37030) y [MedlinePlus, sinónimos](https://medlineplus.gov/lab-tests/acetaminophen-level/) |
| Ácido láctico en plasma | 8 | [Mayo, lactato en plasma](https://www.mayocliniclabs.com/test-catalog/overview/601685) |
| Ácido úrico en orina de 24 horas | 8 | [Mayo, recolección de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/614044) |
| Ácido úrico en orina ocasional | 8 | [UChicago, orden urinaria ocasional](https://uchicagomedlabs.testcatalog.org/show/RUR-1) |
| Etanol en orina | 8 | [LOINC, analito y matriz](https://loinc.org/5645-7) |
| Etanol en suero | 8 | [ARUP, alcohol etílico en suero](https://ltd.aruplab.com/Tests/Pub/0090120) |

Los seis órdenes conservan su muestra en `health.service_specimens` y los dos
estudios urinarios de ácido úrico conservan tiempo `24H`/`Pt` en su definición.
El resto no infiere tiempo, método, propiedad ni escala; se reconoce la orden,
sin interpretar resultados ni sustituir componentes/paneles. No se eligió una
unidad de resultado ni un mapping LOINC exacto por la puntuación del candidato.
Las definiciones analíticas permanecen `verified=false`, con fuente y motivo;
no hay identificadores LOINC nuevos. El reporte ligado a LOINC2.83 conserva
`publication_allowed=false` y sirve exclusivamente como investigación.

El renderer reutilizado ahora admite un máximo de diez conceptos nuevos
investigados por lote, exige aliases revisados que correspondan y se detiene ante
colisión de identidad/nombre/muestra/categoría. La transacción crea catálogo,
categoría, muestra y auditoría; sólo reprocesa filas del crawler investigadas.
El recibo con rollback confirmó seis conceptos / 48 decisiones y la lectura
posterior conservó 189 conceptos activos. La aplicación confirmó seis / 48;
el catálogo quedó en 195 y la cola en 6,901. Las 12 consultas HTTP locales
(nombre original y canónico de cada estudio) respondieron `resolved` con el ID
correcto. Ofertas activas: 234; políticas comerciales intactas; sin migración.

### Quinta revisión: analitos urinarios y duración

La [revisión 05](../database/data/reviewed-aliases-20261009-05.json) añadió diez
conceptos y aliases, cerrando 80 filas de Salud Digna. Se investigaron seis
órdenes individuales de 24 horas (calcio, cloruro, fósforo, magnesio, potasio y
sodio) y cuatro de orina ocasional (cloruro, magnesio, potasio y sodio).
El [catálogo Mayo de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/616180)
identifica esos analitos y su disponibilidad individual dentro del panel;
se usaron los componentes para estudiar las órdenes, no el panel completo como
equivalencia. [Mayo, magnesio de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/610768)
y las órdenes de muestra puntual de
[cloruro](https://www.mayocliniclabs.com/test-catalog/Overview/610607),
[potasio](https://www.mayocliniclabs.com/test-catalog/Overview/610696),
[sodio](https://www.mayocliniclabs.com/test-catalog/Overview/610785) y
[Michigan Medicine, magnesio urinario](https://mlabs.umich.edu/tests/magnesium-urine)
respaldan la separación. El nombre clínico comercial «cloro» se normalizó a
cloruro; no se interpretó como cloro molecular.

Cada concepto conserva orina y tiempo `24H`/`Pt`. No implica cociente con
creatinina, excreción fraccional, suero/plasma, método, propiedad o unidad del
resultado. Las diez definiciones permanecen sin mapping LOINC verificado y no
se añadieron identificadores. La ejecución con rollback confirmó diez / 80 y
conservó el catálogo previo de 195 conceptos. La aplicación dejó 205 conceptos
y 6,821 pendientes. Las 20 consultas HTTP locales por nombre original/canónico
devolvieron `resolved` y el ID esperado; la lectura SQL posterior confirmó 80
decisiones, diez definiciones urinarias y cero identificadores nuevos.

### Sexta revisión: analitos individuales y muestra

La [revisión 06](../database/data/reviewed-aliases-20261009-06.json) añadió diez
conceptos y aliases, cerrando otras 80 filas de Salud Digna. Los originales RAW
identifican laboratorio, analito y muestra; se conservó la duración explícita.

| Concepto | Filas | Evidencia principal |
| --- | ---: | --- |
| Citrato en orina de 24 horas | 8 | [Mayo, componentes de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/616180) |
| Citrato en orina ocasional | 8 | [Mayo, componente CITR2](https://www.mayocliniclabs.com/test-catalog/Overview/606637) |
| Oxalato en orina de 24 horas | 8 | [Mayo, componentes de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/616180) |
| Oxalato en orina ocasional | 8 | [Mayo, componente OXCO1](https://www.mayocliniclabs.com/test-catalog/overview/606748) |
| Cobre en orina de 24 horas | 8 | [Mayo, cobre urinario de 24 horas](https://www.mayocliniclabs.com/test-catalog/Overview/8590) |
| Cobre en suero | 8 | [Mayo, cobre sérico](https://www.mayocliniclabs.com/test-catalog/overview/616155) |
| Creatinina en orina de 24 horas | 8 | [Mayo, componentes de 24 horas](https://www.mayocliniclabs.com/test-catalog/overview/616180) |
| Hierro en suero | 8 | [Labcorp, hierro](https://www.labcorp.com/tests/001339/iron) |
| Lisozima en suero | 8 | [Labcorp, lisozima sérica](https://www.labcorp.com/tests/080713/lysozyme) |
| Zinc en suero | 8 | [Mayo, zinc sérico](https://www.mayocliniclabs.com/test-catalog/Overview/7735) |

CITR2 y OXCO1 acreditan el componente analítico; son componentes no ordenables
individualmente en ese catálogo. No se adoptó el panel ni el cociente con
creatinina como equivalencia, ni se acreditó disponibilidad comercial por esa
referencia. Creatinina urinaria permanece separada de la creatinina sérica
existente y de la depuración; cobre sérico no implica cobre libre/lábil, e hierro
no equivale a ferritina, TIBC ni saturación de transferrina.

El ensayo transaccional confirmó diez conceptos / 80 decisiones y el rollback
conservó 205 conceptos activos. La aplicación y lectura posterior confirmaron
215 conceptos, 6,741 pendientes y 80 decisiones atribuidas a esta revisión.
Las 20 consultas HTTP por nombre original/canónico devolvieron `resolved` con
el ID esperado. Las diez definiciones conservan muestra y duración sin inferir
método, propiedad, escala ni mapping LOINC; no se añadieron identificadores.
Ofertas activas: 234; políticas intactas; ledger 112. API, Admin y Paciente
respondieron HTTP 200. Estos recibos acreditan operación local contra la misma
base autorizada, sin afirmar despliegue público ni una revisión médica humana.

### Séptima revisión: proteínas, hormonas y otros analitos

La [revisión 07](../database/data/reviewed-aliases-20261009-07.json) añadió diez
conceptos y aliases. Cerró 72 filas de Salud Digna y una de SEMIN, cuyo nombre
original y `sample_type` indican orina de 24 horas:

| Concepto | Filas | Evidencia principal |
| --- | ---: | --- |
| Calcio en orina ocasional | 8 | [Mayo, componente CALC5](https://www.mayocliniclabs.com/test-catalog/overview/610591) |
| Proteínas en orina ocasional | 8 | [LOINC, identidad del analito urinario](https://loinc.org/2888-6) |
| Proteínas en orina de 24 horas | 8 | [Mayo, proteínas urinarias de 24 horas](https://www.mayocliniclabs.com/test-catalog/Overview/614002) |
| Albúmina en orina de 24 horas | 8 | [Mayo, albúmina/microalbuminuria](https://www.mayocliniclabs.com/test-catalog/Overview/606718) |
| Beta-2 microglobulina en suero | 8 | [Mayo, beta-2 microglobulina sérica](https://www.mayocliniclabs.com/test-catalog/Overview/9234) |
| Beta-2 microglobulina en orina de 24 horas | 8 | [MedlinePlus, muestra de 24 horas](https://medlineplus.gov/lab-tests/beta-2-microglobulin-b2m-tumor-marker-test/) y [LOINC, matriz/duración](https://loinc.org/10873-8) |
| Clonazepam en suero | 8 | [Labcorp, clonazepam](https://www.labcorp.com/tests/071712/clonazepam) |
| Estrona en suero | 8 | [Mayo, estrona E1](https://www.mayocliniclabs.com/test-catalog/Overview/81418) |
| Noradrenalina en orina de 24 horas | 8 | [Labcorp, componente norepinefrina urinaria](https://www.labcorp.com/tests/004176/catecholamines-fractionated-urinary-free-24-hour-urine) |
| Adrenalina en orina de 24 horas | 1 | [Labcorp, componente epinefrina urinaria](https://www.labcorp.com/tests/004176/catecholamines-fractionated-urinary-free-24-hour-urine) |

Las referencias de componentes/paneles no acreditan orden individual disponible
en esos proveedores; no se adoptó el cociente con creatinina ni el perfil entero.
Proteínas y albúmina permanecen separadas; beta-2 microglobulina urinaria de
24 horas no se transforma en la muestra ocasional de ARUP. Clonazepam no se
sustituye por 7-aminoclonazepam, y estrona no por estradiol/estriol. Las órdenes
de adrenalina/noradrenalina conservan analito y tiempo, sin inferir fracción
libre/conjugada, propiedad, escala, unidad ni un mapping de resultados.

El rollback confirmó diez conceptos / 73 decisiones y conservó 215 conceptos
y 6,741 pendientes. La aplicación y lectura final confirmaron 225 / 6,668,
73 decisiones, diez definiciones con muestra explícita y cero identificadores
nuevos. Las 20 consultas HTTP locales devolvieron el ID correcto. El corte de
triage 07 confirmó 1,139 grupos, 1,121 brechas y 18 con sugerencias.

### Octava revisión y ejecución local de la cola

La [revisión 08](../database/data/reviewed-aliases-20261009-08.json) expandió
«AC» a anticuerpos en `anticuerpos anti insulina`: ocho filas de Salud Digna
con categoría RAW `LABORATORIO`. [Michigan Medicine](https://mlabs.umich.edu/tests/insulin-antibody)
documenta el sinónimo; la [ficha primaria Ruiz](https://laboratoriosruiz.com/estudios/analisis-clinicos/ac-anti-insulina-m)
corresponde al canónico existente `AC ANTI INSULINA (M)`, cuyo nombre se conserva.
No se atribuyó IgM al sufijo comercial, ni se añadieron muestra, método o clase de
inmunoglobulina. Tampoco equivale a concentración de insulina, insulina libre/total
o un panel de autoanticuerpos. La [actualización de Michigan Medicine](https://mlabs.umich.edu/2025/08/06/test-update-918)
identifica que el ensayo histórico Mayo INAB fue discontinuado en 2025; no se
presenta como oferta/método vigente.

El [ejecutor local](../database/scripts/run_local_review_queue.py) completó esta
revisión desde una cola explícita fijada por SHA-256. Reconoció la revisión 07
como ya aplicada, ejecutó rollback/commit de la 08 y verificó alias, auditoría y
ocho decisiones en el ledger. Las dos consultas HTTP locales por nombre original
y canónico resolvieron correctamente. La línea base quedó en 225 conceptos,
6,660 pendientes, 234 ofertas activas y 112 migraciones; API/Admin/Paciente HTTP 200.
El acumulado de ocho revisiones es 50 aliases / 36 conceptos nuevos / 368 filas.

Quedó un proceso local vivo en modo `--watch`, con intervalo de 300 segundos;
la primera lectura del proceso final reconoció ambos lotes como `already_applied`.
Su PID, última y próxima lectura están en el estado local ignorado. El lock no
acredita vida por sí solo. Se verificó una aplicación real y una lectura del
observador; no se ejecutó una suite ni se simularon todos sus fallos.
Los controles programados detienen un lote por hash cambiado, ledger parcial,
conteos inesperados o marcador STOP; un error detiene el helper sin replay ciego.
El proceso requiere el equipo encendido. No hay nuevo servicio de Windows,
cron remoto ni investigación de términos dentro del helper: el agente investiga
y encola la siguiente revisión terminada. [Arranque, parada y recuperación](OPERATIONS_GUIDE.md#cola-local-de-revisiones-investigadas).

Dos dudas investigadas permanecen abiertas. Salud Digna dice `adrenalina en
orina` sin duración ni preparación; no se asignó al concepto de 24 horas por
parecerse. La panorámica de columna total AP tiene RAW radiográfico, pero el
canónico candidato carece de modalidad/anatomía estructuradas para acreditar
su extensión; se conservó pendiente en vez de asumir el alcance. Los snapshots
de estos candidatos se guardaron como investigación, no como revisión encolada.

### Novena revisión: identidad del analito y contexto por proveedor

La [revisión 09](../database/data/reviewed-aliases-20261009-09.json) añadió diez
conceptos y doce aliases, cerrando **84 filas**: 80 de Salud Digna y cuatro de
SEMIN. Se revisaron los 14 grupos y sus RAW representativos. Salud Digna no
especifica muestra; SEMIN sí declara suero para IgA, IgM, progesterona y prolactina.
El catálogo general reconoce la identidad de la orden por analito. Sus diez
definiciones conservan `system`, muestra y duración sin especificar, con alcance
`analyte_order` y explicación de incertidumbre en la auditoría. El suero de SEMIN
queda en `reviewed_source_attributes` de sus cuatro decisiones y en el RAW original;
no se transfiere a Salud Digna ni se aprueba una equivalencia de resultados.

| Orden reconocida | Filas | Referencia primaria para el analito |
| --- | ---: | --- |
| Ceruloplasmina | 8 | [Mayo CERS](https://www.mayocliniclabs.com/test-catalog/Overview/614504) |
| Ferritina | 8 | [Mayo FERR1](https://www.mayocliniclabs.com/test-catalog/Overview/619953) |
| Haptoglobina | 8 | [Mayo HAPT](https://www.mayocliniclabs.com/test-catalog/Overview/9168) |
| Hormona foliculoestimulante (FSH) | 8 | [Mayo FSH](https://www.mayocliniclabs.com/test-catalog/Overview/602753) |
| Hormona luteinizante (LH) | 8 | [Mayo LH](https://www.mayocliniclabs.com/test-catalog/Overview/602762) |
| Inmunoglobulina A (IgA) | 9 | [Mayo IGA](https://www.mayocliniclabs.com/test-catalog/Overview/800052) |
| Inmunoglobulina M (IgM) | 9 | [Mayo IGM](https://www.mayocliniclabs.com/test-catalog/Overview/800054) |
| Progesterona | 9 | [Mayo PGSN](https://www.mayocliniclabs.com/test-catalog/Overview/8141) |
| Prolactina | 9 | [Mayo PRL](https://www.mayocliniclabs.com/test-catalog/Overview/85670) |
| Transferrina | 8 | [Mayo TRSF](https://www.mayocliniclabs.com/test-catalog/Overview/34623) |

Las referencias acreditan el nombre del analito, sin adoptar su muestra, método,
unidad, rango o preparación para el proveedor local. FSH desambigua la errata
«folico estimulante». IgA/IgM corresponden a clases individuales y conservan
su diferencia; no se añadieron patógenos, subclases ni paneles. Progesterona
se conserva separada de 17-hidroxiprogesterona; prolactina de macroprolactina;
transferrina de saturación, capacidad de fijación y receptor soluble.

El renderer ahora admite `additional_targets` para una misma etiqueta global:
progesterona/prolactina tienen conteos y guards independientes por marca, pero
un solo alias cada una. Las dos variantes singular/plural de IgA/IgM son aliases
distintos hacia el mismo analito. El SQL exige el total y el contexto de todas
las entradas, conserva el límite de 200 filas y audita todos los targets.
El ejecutor suma esos contextos y comprueba la ausencia de muestra global
y la preservación del atributo explícito por decisión en el ledger.

Se detuvo el proceso anterior tras comprobar su PID/comando y se inició la
versión actualizada con la revisión 09 fijada por hash. Completó rollback y commit
de 84 filas, verificó el ledger y quedó vivo en modo `--watch` cada cinco minutos.
Lecturas posteriores confirmaron diez definiciones sin muestra, cuatro decisiones
con suero explícito, cero identificadores nuevos y **235 conceptos / 6,576
pendientes / 234 ofertas / 112 migraciones**. El triage leído completo devuelve
**1,124 grupos**: 1,103 brechas y 21 con sugerencias.

Las 22 consultas locales por nombre original/canónico reconocieron los IDs
previstos. `ferritina en suero`, `prolactina en suero` y `progesterona en orina`
devolvieron `no_match`: no se inventó una muestra para resolverlas. Reconocer
el analito no acredita que una orden con atributos adicionales esté cubierta.
API/Admin/Paciente respondieron HTTP 200. No se ejecutaron suites formales.

### Identidades regionales aplicadas

La [revisión de identidades](../database/data/provider-identity-review-20261009.json)
y su [renderer](../database/scripts/render_denue_identity_review.py) enlazaron
exclusivamente estos IDs DENUE investigados:

| Marca | Sedes nuevas `pending` | Fundamento y límite |
| --- | ---: | --- |
| Laboratorios Gubia | 19 | Nombre explícito DENUE; [dominio oficial](https://www.gubia.mx/inicio.aspx) y domicilio corporativo coincidente en Zacatlán. No prueba vigencia por sede ni significa que las 24 sedes anunciadas estén todas en Puebla. |
| Laboratorio Robert Koch — Tlachichuca | 1 | Nombre/dominio/domicilio DENUE y [contacto oficial indexado](https://laboratoriokoch.com/contacto/). Acceso directo actual `403`; no se eludió ni se vinculó a otros negocios llamados Koch. |
| Laboratorios ROSMA | 2 | DENUE y [sitio oficial actual](https://www.rosmalab.com/) coinciden en Degollado 509 y Miguel Hidalgo 9. Se preserva Huaquechula como municipio de Cacaloxúchitl; Axocopan y Tianguismanalco requieren otra revisión. |

Todas las marcas quedaron `verification_pending`, con cero ofertas nuevas y
ninguna sede nueva `active`. La RPC Admin expone las tres marcas, contando cero
sedes activas; las 22 ubicaciones pendientes están en su lista de ubicaciones.
Esto no acredita una sesión interactiva autenticada del operador. El ensayo
devolvió tres marcas / 22 sedes y se comprobó que no dejó marcas; la aplicación y
la lectura posterior confirmaron los mismos estados. Ninguna identidad DENUE
preexistente fue reasignada ni se sobrescribieron marcas/sedes ajenas.

Hay 22 nuevas observaciones `reviewed_identity_link` que conservan RAW, decisión
y fuente de identidad. Las **69,426 observaciones originales de captura** siguen
intactas; ahora hay además esos 22 vínculos derivados. El transporte DENUE cuenta
sólo los seis atributos capturados al comprobar integridad, para que añadir una
revisión de identidad no haga fallar un futuro replay completo. Se prepararon
los lotes y se contrastaron ambos conteos en remoto; no se recargó todo el ZIP.

La investigación de dominios detectó `503` en CEDIC y una respuesta de sólo
60 bytes en el antiguo dominio de Castillo; un `200` vacío no acredita contenido
vigente. San Antonio/de la Hoz dieron fallo de conexión en este entorno. Estos
hallazgos no eliminan identidades anteriores ni convierten dominios antiguos en
fuentes frescas. Próximo trabajo: reconfirmar esas fuentes con una hipótesis nueva
o buscar otro canal público oficial, conservar el último dato válido y ampliar
la cartera regional.

### Segunda revisión regional: Tehuacán, Tlacotepec y Atlixco

La [revisión de identidades 02](../database/data/provider-identity-review-20261009-02.json)
creó tres marcas en verificación y cuatro sedes pendientes:

| Marca | Sedes DENUE enlazadas | Evidencia y límite |
| --- | --- | --- |
| CEDITSA Laboratorios | Tehuacán `6271803`, Tlacotepec `9106247` | [Sitio actual](https://ceditsa.com.mx/sucursales/) confirma 10 Oriente 108 y Tabasco 5. No fusionar DENUE 3401693 del número 103. El domicilio Ajalpan publicado difiere de DENUE 6272691: queda sin enlace. Altepexi requiere confirmar la identidad del nombre completo. |
| Laboratorio Clínico Cervantes — Tehuacán | `9873311` | [Sitio oficial](https://laboratorioclinicocervantes.com/) confirma 2 Poniente 427, Ignacio Zaragoza. No se enlazó el otro Cervantes de 11 Sur ni se aprobó su permiso/calidad por aparecer en la página. |
| Biomedicos Group — Atlixco | `3424260` | [Sitio oficial](https://www.biomedicos.mx/) y DENUE comparten marca, dominio, localidad, número 1161 y Prado Sur. La vialidad difiere: Av. Encino/Miguel Negrete. El registro conserva dirección DENUE y queda `pending`, sin afirmar domicilio vigente. |

El ensayo dejó cero marcas nuevas después del rollback. Aplicación y lectura
remota confirmaron tres marcas / cuatro sedes, todas `pending`, cero ofertas.
Ahora hay 44 marcas / 113 ubicaciones y 26 vínculos derivados DENUE en total;
las 69,426 observaciones originales de captura conservan su alcance. La API,
Admin y Paciente respondieron HTTP 200 en localhost después de ambos lotes.

La investigación directa de dominios guardó fallo de conexión en Galenus y
Pasteur Acatzingo, `404` en Cuauhtémoc Xicotepec y `200` con contenido en
Biomédicos. No se repitieron capturas ni se borraron identidades por esos fallos;
los negocios llamados Pasteur/Galenus en distintas ciudades no se fusionaron.

Otra lectura pública guardó HTTP 200 en Grupo Santa María, pero el HTML es un
shell JavaScript sin domicilios de sucursales comprobables. AB y Mycrolab
(Tehuacán), y Relevant Lab (San Andrés Cholula), dieron `ConnectError` en este
entorno; se conservan como candidatos DENUE, sin enlaces canónicos nuevos.
Un resultado de directorio secundario no sustituye la evidencia oficial para
agrupar los negocios llamados Santa María. Siguiente paso: buscar información
pública de sucursales del sitio actual o un canal oficial distinto, sin repetir
los mismos fallos ni inferir asociaciones por nombre.

Artefactos ignorados bajo `collectors/artifacts/puebla-expansion-20261009/`:
`verified-load.json`, `ingest-sql/load_receipt.json`, el ZIP, manifiesto/RAW,
`healthcare-directory.jsonl`, `website-candidates.json`, snapshots de línea base
y `clinical-research/`; las aplicaciones posteriores están en `review-02/`,
`review-03/`, `review-04/`, `review-05/`, `review-06/`, `review-07/`, `review-08/`, `review-09/`, `identity-review-01/` e
`identity-review-02/`; `new-concepts-01/` conserva RAW de proveedor, inventario
canónico y candidatos LOINC. `new-concepts-02/` conserva RAW e inventario para
las diez órdenes urinarias; `new-concepts-03/` conserva los originales RAW y el
inventario previo a la revisión 06; `new-concepts-04/` conserva los de la revisión 07;
`new-concepts-05/` conserva los 14 RAW e inventario previo a la revisión 09.
Ninguno generó mappings LOINC. Los recibos de preview/apply de las revisiones 08/09
viven en `collectors/artifacts/local-review-queue/pruevia-evidence-review-20261009-08/`
y el directorio equivalente terminado en `-09/`,
junto a la cola fijada y el estado del ejecutor. Snapshot tras la segunda revisión:
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review-02.json`
(1,176 grupos / 6,957 filas). La lectura SQL posterior a revisión 03 confirmó
1,175 / 6,949; nuevo triage con los modificadores corregidos:
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review-03.json`.
El corte tras revisión 04 queda en
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review-04.json`:
1,169 grupos / 6,901 filas, 1,148 brechas de catálogo y 21 con sugerencias.
La lectura remota confirmó 48 decisiones de la revisión 04, seis definiciones
analíticas sin mapping verificado y cero identificadores nuevos. Que aumenten
las sugerencias al añadir conceptos no acredita equivalencias adicionales.
El snapshot posterior a revisión 05 es
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review-05.json`:
1,159 grupos / 6,821 filas, 1,135 brechas de catálogo y 24 con sugerencias.
El corte posterior a revisión 06 está en
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review-06.json`:
1,149 grupos / 6,741 filas, 1,129 brechas de catálogo y 20 con sugerencias;
215 conceptos activos. El corte 07 está en el archivo del mismo prefijo con
sufijo `after-review-07.json`: 1,139 grupos / 6,668 filas. El corte tras
revisión 08 queda en `after-review-08.json`, con 1,138 grupos / 6,660 filas y
225 conceptos activos: 1,120 brechas de catálogo y 18 con sugerencias.
El corte histórico `after-review-09.json` contiene 1,124 grupos / 6,576 filas y
235 conceptos: 1,103 brechas y 21 con sugerencias. El corte histórico
`after-review-10.json` contiene 1,111 grupos / 6,493 filas y 245 conceptos:
1,089 brechas y 22 con sugerencias. El corte histórico de la revisión 11 está en
`collectors/artifacts/normalization-triage-production-readonly-20261011-after-review-11.json`:
1,099 grupos / 6,411 filas y 255 conceptos; 1,073 brechas y 26 con sugerencias.
El corte posterior a la revisión 13 es `normalization-triage-production-readonly-20261011-after-review-13.json`:
1,073 grupos / 6,245 filas / 275 conceptos, 1,046 brechas y 27 con sugerencias.
El corte posterior a la revisión 16 es `normalization-triage-production-readonly-20261011-after-review-16.json`:
1,042 grupos / 6,002 filas / 305 conceptos, 1,014 brechas y 28 con sugerencias.
El corte posterior a la revisión 18 es `normalization-triage-production-readonly-20261011-after-review-18.json`:
1,019 grupos / 5,839 filas / 325 conceptos, 990 brechas y 29 con sugerencias.
El corte posterior a la revisión 20 es `normalization-triage-production-readonly-20261011-after-review-20.json`:
1,005 grupos / 5,734 filas / 338 conceptos, 976 brechas y 29 con sugerencias.
El corte anterior 23 es `normalization-triage-production-readonly-20261011-after-review-23.json`:
974 grupos /5,507 filas /366 conceptos, 940 brechas y 34 con sugerencias.
El corte anterior 26 es `normalization-triage-production-readonly-20261011-after-review-26.json`:
945 grupos /5,338 filas /388 conceptos, 913 brechas y 32 con sugerencias.
El corte 29 es `normalization-triage-production-readonly-20261011-after-review-29.json`:
929 grupos /5,210 filas /402 conceptos, 895 brechas y 34 con sugerencias.
El corte 31 es `normalization-triage-production-readonly-20261012-after-review-31.json`:
912 grupos /5,101 filas /415 conceptos, 877 brechas y 35 con sugerencias.
El vigente 33 es `normalization-triage-production-readonly-20261012-after-review-33.json`:
893 grupos / 4,963 filas / 432 conceptos, 858 brechas y 35 con sugerencias.
Paginación completa, 893 retenciones por política comercial y 26 por fuente
oficial no corroborada; no son rechazos de la identidad terminológica investigada.
El conteo por estado RAW sin
excluir decisiones históricas es más alto; el triage y la línea base excluyen
esas decisiones y son la referencia para la cola pendiente.
Los reportes son de sólo lectura y no aprueban sugerencias.
Todos los grupos conservan el bloqueo de publicación por política comercial;
esa condición no impide investigar la terminología histórica bajo D-021.
El snapshot de la primera revisión es:
`collectors/artifacts/normalization-triage-production-readonly-20261009-after-review.json`.
No guardar secretos ni entradas de pacientes en estos reportes.

Siguiente trabajo autorizado:

1. Usar los 1,249 laboratorios y 322 hospitales como cartera de investigación.
   Hay 120 hosts candidatos entre ellos, extraídos del directorio; un dominio
   escrito en DENUE aún requiere comprobar identidad, vigencia y condiciones.
2. Enlazar sedes sólo con evidencia suficiente. Medir ofertas comprobables por
   estudio/sede y faltantes de recetas, además del inventario de establecimientos.
3. Investigar los grupos con sugerencias y los conceptos ausentes. Separar
   aldosterona sin muestra, ECG sin modalidad y paneles incompletos antes de
   aprobar; no resolver por la puntuación fuzzy ni por un ID externo.
4. Conservar el cron de normalización apagado mientras las fuentes comerciales
   sigan `review_required`. La revisión de terminología ya almacenada no concede
   licencia para nuevas capturas ni publicación comercial de una fuente.

Recuperación: si un lote de carga falla, inspeccionar el estado y el recibo antes
de reintentar; sus IDs son estables y no borra el último dato válido. Si una
equivalencia resulta incorrecta, deprecar el alias identificado por esta revisión
y corregir decisiones explícitamente preservando auditoría. Para un concepto
nuevo erróneo, corregir o deprecar específicamente su identidad/definición y
los aliases/decisiones afectados; conservar vínculos y evidencia del incidente.
No borrar RAW ni
revertir toda la base para corregir una equivalencia. Reanudar publicaciones,
activar capturas comerciales o contactar proveedores tiene alcance separado.
