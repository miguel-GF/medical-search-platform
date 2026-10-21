# Cobertura de proveedores de Puebla

> Informe de cobertura con snapshots fechados; sus cantidades y cadencias recomendadas no demuestran estado actual ni jobs activos.
> Entrada: [índice vigente](README.md). Estado: [CURRENT_STATE](CURRENT_STATE.md).

## Actualización — 21-oct-2026, 05:42 UTC

**199 marcas /283 ubicaciones /234 ofertas**. Ocho identidades nuevas de centros
y unidades rurales, San Joaquín y Candia; nombres/direcciones/tipos conservados.
Discrepancia institucional IMSS/IMSS-Bienestar no resuelta como operador/red.
Sin ofertas o verificación comercial nuevas.
[Evidencia y límites](PUEBLA_REVIEW_73_AND_IDENTITIES_39_20261021.md).

## Actualización — 21-oct-2026, 05:32 UTC

**191 marcas /275 ubicaciones /234 ofertas**. Identidades37–38 añadieron cuatro
UMF numeradas y cinco establecimientos privados candidatos, sin ofertas nuevas.
Conservar verificación comercial pendiente y clases/direcciones DENUE; no inferir
red, operador, catálogo o disponibilidad. Beneficencia1001/1012 sigue retenida.
[Última incorporación y límites](PUEBLA_REVIEW_72_AND_IDENTITIES_38_20261021.md).

## Actualización — 16-oct-2026, 04:04 UTC

Registro observado:114 marcas y198 ubicaciones. Identidades25–27 agregaron
Galaviz, RVLAB, cuatro hospitales comunitarios y23 centros/consultorios públicos
pequeños. Son candidatos con verificación comercial pendiente; no se acreditan
servicios ni operación actual por una fuente histórica. Se preservan domicilio,
coordenadas, clasificación y discrepancias;234 ofertas existentes, sin nuevas.
[Investigación, aplicación y límites](PUEBLA_CATALOG_REVIEW_52_20261016.md).

## Corte histórico — 13-oct-2026

La base productiva reanudada contiene una nueva descarga oficial DENUE de Puebla
(metadatos 20-may-2026): **13,747 establecimientos de salud en 217 municipios**,
incluidos 1,249 laboratorios y 322 hospitales. Se verificaron 69,426 observaciones
de identidad/ubicación y la corrida completa en `ingest` tras 157 lotes. No
crea ofertas ni garantiza un estudio por sede. La revisión separada de identidades
añadió Gubia, ROSMA, Robert Koch, CEDITSA, Cervantes, Biomédicos, Mexica, IB, CEEAD
y Páez, GARDITEX, Betania, Hospital Angeles, MAC, Hospital Puebla y Beneficencia
Española, IMSS-Bienestar, ISSSTE, Samalab, Omega, LAC, Hospital Independencia,
Sanatorio Humboldt, Bio-Velab, Medic Scanner, Tlatlauquitepec, Unidad Hospitalaria
La Paz, Hospital Guadalupe de Puebla, Hospital Vilaseca Esparza y Laboratorio
Clínico de Tepeaca: ahora hay **68 marcas y 152 ubicaciones**, incluidas 65 nuevas sedes `pending`
sin ofertas. CEEAD y las cinco sedes hospitalarias de la revisión 05 conservan
la clase gubernamental de hospital general;
las discrepancias de domicilios se guardan sin completar números o vialidades.
La revisión 06 añadió Norte y San Andrés Cholula (IMSS-Bienestar) y Tehuacán
(ISSSTE), corroborados en una publicación federal del 14-may-2026. El directorio
estatal aporta evidencia adicional de las dos primeras unidades; conserva CP
discordantes y Osa Mayor/Menor en Cholula, sin cambiar el domicilio DENUE.
La revisión 07 añadió Hospital General de Zacatlán (DENUE `3511000`) bajo
IMSS-Bienestar existente, con nombre institucional explícito en una publicación
estatal del 22-ene-2026. Se conservó íntegra la marca y `CALLE DEL ROBLE SN`,
sin completar el exterior 7 del directorio estatal. Rollback, commit, observación
y auditoría comprobados; cero ofertas y ninguna marca duplicada.
La revisión 08 añadió Samalab (San Martín) y Omega (Puebla/San Martín):
dos marcas verification_pending y tres sedes pending. Conservar la letra A de
DENUE 3459594 (709A), el marcador SN de 8559305 y las discrepancias de
asentamiento. La revisión 09 incorporó LAC y dos sedes pending: Tlanalapan 11271977 y
San Lucas 3320300, corroboradas por el JSON público enlazado desde su directorio.
Conservar exterior 16 y SN gubernamentales; la ficha San Lucas 82 y mapa 28
son discrepancias, sin completar domicilio ni copiar coordenadas. LAC matriz
3265780 sigue retenida por nombre genérico; Omega Tehuacán 213 sigue sin ID DENUE.
Al cierre de la revisión 12 había 27 instituciones y 62 sedes nuevas bajo doce
revisiones de identidad; la revisión 13 eleva esos totales a **30 instituciones
y 65 sedes nuevas bajo trece revisiones**, todas sin ofertas nuevas.
La revisión 10 incorporó Hospital Independencia (3428590, exterior 209) y
Sanatorio Humboldt (3439799, exterior 2015, interior 22223, MIGUEL ALEMANA).
Dos hospitales pending por sitio propio/directorio estatal y DENUE. Humboldt
conserva dominio candidato estatal con sitio propio inaccesible, sin ownership
probado. Independencia 209 no se atribuyó a Omega 213. Rollback/commit y dos
auditorías/observaciones comprobados. Lab360 y Ebenezer siguen sin vínculo claro.
La revisión 11 añadió Bio-Velab (3521626/3372257/3463507) y Medic Scanner
(9425747/11824152): dos marcas en verificación y cinco sedes pendientes.
Conservar `SN`, exterior `2C`, diferencia San Alfonso/16 de Septiembre y Medic
Scanner `220A`/San Sebastián. Se verificaron sitio propio, RAW completo remoto,
rollback/commit y cinco observaciones/auditorías, sin ofertas. Innovalab Tehuacán
queda retenido por dirección primaria diferente; no atribuir un traslado.
La revisión 12 añadió Tlatlauquitepec: Reforma89 (10241460), Zaragoza5C
(3475545) y Cuetzalan AldamaSN (3492706), con directorio propio. Tres sedes
adicionales se retuvieron por números distintos o sucursal indeterminada.
Unidad Hospitalaria La Paz (6272351) conserva Acatlán24, corroborado por aviso
propio enlazado y directorio estatal; ReformaSur92 del pie/contacto es discrepancia,
sin traslado inferido. Dos marcas en verificación, cuatro ubicaciones pending,
rollback/commit y cuatro auditorías/observaciones comprobadas, sin ofertas.
La [revisión 13](../database/data/provider-identity-review-20261013-01.json),
aplicada y verificada el **13-oct-2026 a las 12:56 UTC**, añadió tres instituciones
`verification_pending` y tres sedes `pending`:

| Institución | DENUE / clase | Evidencia y límites conservados |
| --- | --- | --- |
| Hospital Guadalupe de Puebla | `6378369` / `622111` | El [directorio estatal](https://ss.puebla.gob.mx/emergencias) identifica la institución en 13 Oriente 1617, Azcárate, CP 72501. Web institucional `NULL`, con `website_uncertainty` explícita: no atribuir el dominio ofrecido en venta ni fusionar con Hospital Puebla o Laboratorios Guadalupe. |
| Hospital Vilaseca Esparza | `3441886` / `622111` | El mismo directorio confirma nombre, 12 Norte 1802 y Puebla; publica Xonaca / CP 72280. Se conservan BARRIO DE EL ALTO / CP 72290 del RAW. Web institucional `NULL`, con incertidumbre explícita; no atribuir dominio histórico inaccesible. |
| Laboratorio Clínico de Tepeaca | `6421417` / `621511` | El [micrositio de marca alojado en MiADN](https://laboratorioclinicodetepeaca.miadn.mx/) publica Cuauhtémoc Sur 110, Centro, Tepeaca, CP 75200, concordantes con DENUE. Web candidata en verificación; hosting externo no acredita ownership legal. GET nativo **403**; Chrome normal renderizó el contenido público sin desafío. Se conserva hash del DOM y estado HTTP de red desconocido, sin afirmar HTTP 200 del navegador. |

Se verificaron rollback y commit de exactamente tres marcas / tres sedes,
tres observaciones y tres auditorías, RAW completo remoto y hashes coincidentes.
Letras e interiores vacíos, domicilios, coordenadas y discrepancias gubernamentales
quedaron conservados. Las dos webs `NULL` y sus límites permanecen también en
las observaciones de identidad. Fuente estatal modificada 06-feb-2026 y leída
con HTTP 200; el recibo 403 de Tepeaca no se convirtió en una captura HTTP 200.
No hubo ofertas, migraciones ni cambios de política de fuentes; estos vínculos
no acreditan estudios, precios, horarios, disponibilidad o permisos sanitarios.
Recibos locales de aplicación y verificación:
`collectors/artifacts/puebla-expansion-20261009/identity-review-13/`.

No se infieren derechohabiencia, institución operadora de otros hospitales,
estudios, precios ni disponibilidad de ese directorio.
El filtro SCIAN 621/622 incluye consultorios y otras
especialidades, no sólo centros diagnósticos; revisar nombres/clases y vigencia.

La revisión delegada de 309 aliases exactos y 271 nuevos conceptos cerró 2,286 filas;
faltan 4,742 en 860 grupos. Hay 460 conceptos activos; 209 nuevos conservan
muestra desconocida y dos conservan muestra literal sin código específico.
Los contextos explícitos por fuente se conservan; no son cobertura comercial.
Las revisiones 30–31 añadieron trece conceptos/quince aliases y cerraron 109 filas.
Veintitrés consultas públicas completas/globales y cinco internas con proveedor
resolvieron; los cinco aliases que dependen de preparación permanecen de proveedor,
sin inferir muestra/duración en búsqueda genérica. Los 76 vecinos ambiguos conservaron
exactamente sus UUID pendientes. Memoria del corte31: 259 aliases/276 contextos, 912
trabajos y 1,924 históricos reutilizables en el plan de 1,927; no cobertura nueva.
Las revisiones 32 corregida/33 cerraron 138 filas, añadieron diecisiete conceptos
y diecinueve aliases; 33/33 consultas públicas y 3/3 internas de proveedor
resolvieron. El ensayo inicial 32 abortó por un SEMIN de Giardia adicional,
sin aplicar: se investigó, preservó original y sustituyó revisión por 74 filas.
El preparador ahora comprueba términos canónicos nuevos y conserva el mismo
guard de alcance. Los sesenta vecinos ambiguos mantuvieron sus UUID pendientes.
Memoria histórica del corte 33: 278 aliases/295 contextos, 2,062 históricos
reutilizables de 2,065; 893 trabajos pendientes. La memoria del cierre 37 tiene
309 aliases/328 contextos y 2,283 históricos reutilizables de 2,286; pendientes
4,658 necesitan evidencia y 84 tienen campos desconocidos, en 860 trabajos.
Las revisiones 34–37 cerraron 221 filas con 28 conceptos/31 aliases; 50 consultas
públicas y once internas resolvieron al ID esperado. Sólo planificación e
investigación trazable, sin tasa sobre casos nuevos ni nueva oferta comercial.
T3 libre conserva un bloqueo histórico del resolver aunque su concepto/alias y
ocho decisiones crawler están guardados; investigar la corrección del contrato
clínico antes de activarla. Calcio sin forma y testosterona sin fracción siguen
sin decisión, igual que TGO SEMIN con muestra contradictoria. Las 43 consultas
exactas de los lotes 17–18 y las 26 de 19–20 resolvieron; AFP-L3 selecciona AFP genérica y
antiendomisio IgG incluye IgA incompatible y toxoplasma IgA incluye IgG.
Sus propuestas clínicas siguen
sin activar; inmunoglobulinas ya tiene diff exacto y recuperación preparados
para 25 componentes elegibles, sin ejecutar. Estos contadores no acreditan
preservar todas las variantes.
La revisión 21 resolvió 17/17 consultas exactas y cerró 66 filas; retuvo 40
por fracción/metabolito inciertos. SEMIN sirolimus conserva sangre total en su
guard RAW y topiramato suero sólo en su decisión. Ciclosporina C2 devuelve el
analito genérico sin representar el momento C2: no afirmar todas las variantes.
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
Las fuentes comerciales
siguen `review_required`. El siguiente
trabajo usa laboratorios/hospitales como cartera, confirma dominios y sedes y
obtiene evidencia de oferta. Fuentes, recibos, código reproducible, autorización
y límites: [operación local Puebla](PUEBLA_LOCAL_OPERATION_20261009.md).

## Antecedentes de las capturas por proveedor

La cartera de proveedores se separa en dos niveles para no publicar datos sin
verificación:

* `database/fixtures/generic_provider_mappings_puebla_v1.json` contiene diez
  identidades candidatas enlazadas a registros DENUE y sus dominios públicos.
  Las identidades se guardan como `verification_pending`; sólo cinco estudios
  tienen equivalencia clínica exacta aprobada.
* `database/fixtures/salud_digna_puebla_locations_v1.json` conserva trece
  sucursales de Salud Digna confirmadas en páginas oficiales de Puebla, con
  coordenadas, domicilio y teléfono. El snapshot DENUE tenía cinco; por eso
  ocho sucursales adicionales no deben perderse por depender sólo de DENUE.
* El adaptador `pruevia-semin` captura el catálogo público de Laboratorios
  SEMIN. La corrida de control recuperó 140 estudios únicos y nueve
  sucursales (149 registros RAW). Cada precio conserva el estado
  `unverified_provider_reference`, porque el propio catálogo expone fechas de
  actualización antiguas y no prueba vigencia comercial.

* El collector `pruevia-dr-simi` consulta únicamente el archivo JSON público de
  sucursales y una página pública de campañas de Análisis Clínicos del Dr. Simi.
  La corrida de control encontró cuatro sedes de Puebla (unidades 7, 374, 180 y
  260); tres ya tienen coordenadas contrastadas con DENUE y la cuarta queda en
  revisión por discrepancia de domicilio.
* El collector dedicado de Chopo recuperó 60 registros actuales de Puebla y
  enlazó 11 ubicaciones DENUE como identidades pendientes. Sus 58 etiquetas no
  aprobadas quedaron en la cola administrativa; no se publicaron por similitud.
* Ruiz ahora recorre el catálogo completo acotado (4,617 registros en la
  corrida de control). La equivalencia revisada de `CITOMETRIA HEMATICA` (ID
  583) se publica como Biometría hemática con su enlace oficial de estudio;
  antes se perdía por truncar cada departamento a 20 filas.
* Salud Digna conserva ocho observaciones oficiales de Biometría hemática en
  sucursales de Puebla. Cada sucursal se publica como un scope concreto y el
  enlace se etiqueta como `location_only`: el sitio requiere seleccionar el
  estudio después de abrir la sede y no se inventa una URL profunda.
* Verkenlab quedó como equivalencia exacta candidata para Biometría hemática;
  su precio y página se publican sólo después de ejecutar el renderer genérico
  con el artefacto revisado.

* Se añadió `pruevia-linfolab` para la página pública de sucursales. El sitio
  enumera 19 tarjetas; el parser sólo acepta las que incluyen un domicilio
  verificable en el enlace oficial de Maps. La captura automática quedó en
  cuarentena porque el certificado TLS del dominio no pudo validarse desde el
  entorno de ejecución; no se desactivó la verificación. Una captura revisada
  permitió publicar seis filas RAW completas, sin convertirlas en estudios.

Los servicios, descripciones, indicaciones y precios de SEMIN son evidencia
del proveedor, no conceptos clínicos canónicos. No se llaman endpoints de
citas, pacientes o promociones y no se reutilizan credenciales del sitio.

## Captura del catálogo SEMIN

Desde `collectors/`:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_semin `
  --max-pages 8 --max-results 150 --max-details 150 `
  --artifact-root artifacts/semin-catalog-puebla
```

La captura respeta `https://semindigital.com/robots.txt`, limita páginas,
filas, bytes, redirecciones y tiempo de respuesta, y escribe únicamente
artefactos RAW/candidate. Si una página de detalle falla, la corrida queda
cuarentenada para que nadie confunda un catálogo parcial con cobertura
completa.

## Captura completa de Salud Digna

El collector acepta varios slugs y no llama flujos de cita, pacientes ni pago.
La corrida de control de ocho sucursales produjo 6,923 registros válidos y
34,607 observaciones. Se publicó sólo en `ingest`; 6,910 estudios quedaron en
la cola `normalization_pending` y cinco equivalencias ya aprobadas se
excluyeron para evitar duplicados.

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.cli_salud_digna `
  --location-slug puebla `
  --location-slug puebla-xilotzingo `
  --location-slug puebla-san-sebastian `
  --location-slug puebla-el-porvenir `
  --location-slug puebla-capu `
  --location-slug puebla-municipio-libre `
  --location-slug puebla-angelopolis `
  --location-slug puebla-azaleas `
  --artifact-root artifacts/salud-digna-puebla-all
```

Después de publicar el artefacto, el renderer de ubicaciones enlaza las trece
sucursales oficiales con `core.provider_locations` sin crear ofertas:

```powershell
python database/scripts/render_official_provider_locations.py `
  --fixture database/fixtures/salud_digna_puebla_locations_v1.json `
  --artifact collectors/artifacts/salud-digna-puebla-all/salud-digna-puebla/<run-id> `
  --chunk-dir collectors/artifacts/salud-digna-puebla-all/location-sql
```

## Inventario estatal de Salud Digna

El directorio público por estado/municipio devolvió 15 entradas para Puebla:
13 clínicas y dos centros diagnósticos (Centro Analítico y PET-CT), repartidos
en Puebla, San Andrés Cholula, San Martín Texmelucan, San Pedro Cholula y
Tehuacán. Trece tienen página detallada en el fixture de ubicaciones; sólo los
centros diagnósticos 293 (PET-CT) y 299 (Centro Analítico) siguen pendientes
porque el directorio no expone una página de sucursal equivalente.

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.cli_salud_digna_locations `
  --artifact-root artifacts/salud-digna-puebla-location-directory
```

La corrida sólo llama el directorio público de estados, municipios y
sucursales. No usa citas, pacientes, resultados ni pagos, y una fila sin
domicilio o coordenadas no se convierte en oferta.

## Sucursales públicas de Dr. Simi

El feed oficial de sucursales y la página pública de campaña se capturan sin
acceder a cuentas ni a flujos de citas. La fuente actual muestra cuatro sedes
de Puebla; tres se enlazaron con coordenadas DENUE y la unidad 260 permanece
como evidencia pendiente porque su domicilio oficial no coincide exactamente
con la fila DENUE disponible. No se infieren estudios ni precios por tener una
dirección.

La revalidación pública del 14-sep-2026 conservó ese alcance: Salud Digna devolvió
15/15 registros válidos (corrida `22e90c7a-4e42-41b4-a076-8dff5c7e84c4`), y Dr.
Simi devolvió 4/4 (corrida `23cc86c7-adb4-4062-a8a7-d4eae2c44e77`). La unidad 260
aparece en RAW, pero sigue fuera de la publicación hasta resolver la discrepancia.

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.cli_dr_simi `
  --artifact-root collectors/artifacts/dr-simi-puebla-live

python database/scripts/render_official_provider_locations.py `
  --fixture database/fixtures/dr_simi_puebla_locations_v1.json `
  --artifact collectors/artifacts/dr-simi-puebla-live/dr-simi-puebla/<run-id> `
  --chunk-dir collectors/artifacts/dr-simi-puebla-live/location-sql
```

## Qué falta de la red poblana

El inventario DENUE usado como punto de partida contiene 489 registros de
fuentes, de los cuales 213 son candidatos clínicos directos. Hay 47 hosts
distintos; 90 candidatos tienen sitio web y 123 no tienen URL pública, por lo
que estos últimos requieren verificación por teléfono, visita o documento del
proveedor. El inventario se puede regenerar sin escribir en Supabase:

```powershell
python database/scripts/build_puebla_source_inventory.py `
  --denue-fixture database/fixtures/denue_candidates_puebla_v1.json `
  --discovery-manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --output collectors/artifacts/puebla-source-inventory.json
```

En ese snapshot aparecen, entre otros, 5 registros de Salud Digna, 11 de
Chopo, 5 de Dr. Simi, 5 de Farmacias del Ahorro, 5 de Laboratorio Médico
Polanco, 9 de Linfolab, 11 de Exacta, 4 de Gaya y 4 de Guadalupe. Son conteos
de leads DENUE, no un censo vigente. El crawler genérico ya probó 47 hosts,
pero sólo 10 devolvieron evidencia, 10 quedaron vacíos y 27 fallaron; por eso
Dr. Simi y la mayoría de las clínicas pequeñas todavía no deben mostrarse como
oferta confirmada.

## Incorporación de identidades DENUE

Las nuevas identidades incorporadas como candidatas son Lafer, Verkenlab,
Clínica de Diagnóstico Radiología y Ultrasonido, RIEX Radiología Dental y Labo
Pat Diagnósticos, además de Family Labs, Asesores Diagnóstico Clínico,
Laboratorios Xonaca y SEMIN. La fuente de identidad sigue siendo DENUE; una
fila DENUE no demuestra por sí sola que el sitio ofrezca un estudio.

Para generar SQL idempotente se requieren los artefactos de cada `source_key` y
la revisión humana de las equivalencias. El renderer sólo publica ubicaciones
con coordenadas y ofertas explícitamente mapeadas; todas las demás etiquetas
permanecen en la cola de revisión.

Para inspeccionar la cartera sin tocar la base:

```powershell
python database/scripts/build_puebla_provider_portfolio.py `
  --manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --mapping-fixture database/fixtures/generic_provider_mappings_puebla_v1.json `
  --denue-fixture database/fixtures/denue_candidates_puebla_v1.json `
  --output collectors/artifacts/puebla-generic-depth1-hardened/puebla_provider_portfolio.json
```

La salida es sólo un informe de cobertura: no crea marcas, ubicaciones ni
ofertas en Supabase.

En el entorno enlazado de pruebas ya se cargaron las diez identidades y sus
12 ubicaciones DENUE como `verification_pending`; Salud Digna suma trece
ubicaciones oficiales, Dr. Simi tres ubicaciones oficiales (la unidad 260
permanece pendiente de verificación). Las corridas SEMIN (149
registros), Chopo (60), Salud Digna (6,923) y Linfolab (6 sucursales) se
guardaron en `ingest`. Linfolab tiene tres ubicaciones oficiales enlazadas y
tres sucursales adicionales conservadas sólo como evidencia RAW.
La cola administrativa quedó abierta con 7,028 pendientes
(`normalization_pending`) después de reprocesar 110 coincidencias exactas
seguras. La mayor parte sigue siendo Salud Digna (6,804 pendientes abiertos);
también quedan 140 estudios de SEMIN, 57 de Chopo y etiquetas de proveedores
pequeños. Los 946 casos con decisión final `no_match` se conservan como
historial, pero no se muestran como trabajo abierto. Esto permite auditar y
depurar desde el panel administrativo sin presentar estudios no confirmados a
pacientes.

El reproceso exacto se puede ejecutar por lotes desde el RPC administrativo;
sólo acepta un nombre canónico o alias aprobado idéntico y nunca convierte una
similitud difusa en una oferta:

```sql
select public.api_admin_reprocess_exact_normalizations(
  '<ADMIN_USER_UUID>', 200, true, '<REQUEST_ID_UNICO>'
);
```

Esto no significa revisar 7,028 pantallas una por una. La consulta de backlog
agrupa por proveedor y etiqueta normalizada, de modo que una decisión sobre una
etiqueta repetida puede resolver muchas filas. El camino automático seguro es:

1. colectar, limpiar, deduplicar y agrupar las etiquetas sin publicar nada;
2. aplicar por lote sólo nombres canónicos o aliases aprobados de forma exacta;
3. separar ruido, duplicados y `no_match` con una decisión auditable;
4. enviar a revisión humana únicamente conceptos nuevos o ambiguos que puedan
   cambiar muestra, modalidad, anatomía, lateralidad, contraste o composición.

La similitud fuzzy o una sugerencia de IA puede ordenar la cola, pero no aprueba
una equivalencia clínica. Por eso la automatización reduce miles de filas a
grupos y lotes repetibles, mientras la revisión humana protege los casos que sí
pueden producir una oferta incorrecta.

## Sucursales públicas de Linfolab

La página oficial muestra sedes como Gabriel Pastor, Zavaleta, Cholula, Plaza
Norte, Tolin y Mayorazgo, además de otras tarjetas cuyo enlace de Maps no
contiene una dirección. El colector conserva únicamente las seis primeras
cuando puede leer el domicilio; los estudios, precios y disponibilidad siguen
fuera de alcance. El sitio también advierte que un estudio puede no prestarse
en todas las sucursales, por lo que una sede no crea una oferta automática.

```powershell
$env:PYTHONPATH = "collectors/src"
python -m pruevia_collectors.cli_linfolab `
  --artifact-root collectors/artifacts/linfolab-puebla-live
```

Si la corrida queda en cuarentena, se debe corregir el certificado del
proveedor o validar manualmente una captura; nunca se debe usar
`--ignore-robots` ni desactivar TLS en producción.

## Cadencia operativa y puerta de liberación

La frecuencia recomendada es conservadora y depende del tipo de dato:

| Fuente | Qué actualizar | Cadencia | Regla de frescura |
| --- | --- | --- | --- |
| Salud Digna, Chopo, Ruiz y SEMIN | Catálogo/precio público | cada 24 h | cuarentena si faltan datos o supera 48 h |
| Salud Digna | Directorio estatal de sucursales | cada 7 días | abrir tarea si cambia el conteo o aparece un ID nuevo |
| Dr. Simi | Feed público de sucursales | cada 7 días | cuarentena si cambia el esquema o baja de 1 sede Puebla |
| Páginas de sucursal oficiales | domicilio, teléfono, coordenadas, horario | cada 7 días | conservar el último snapshot válido |
| DENUE | universo de negocios y altas/bajas | mensual | no elimina una sede sin confirmar cierre |
| Sitios pequeños genéricos | servicios y ubicación pública | cada 7–14 días | un host por vez, con retry al día siguiente |
| Normalización clínica | equivalencias, paneles y recetas | revisión diaria | nunca se resuelve sólo por similitud |

Antes de abrir Puebla a usuarios externos deben cumplirse: cobertura de
sucursales de cada cadena prioritaria, mappings revisados para las búsquedas
principales, tasa de `no_match` medida con consultas reales y una respuesta
segura de “requiere revisión” con alternativas. Más filas RAW por sí solas no
garantizan que una receta completa sea resoluble.

## Identidades adicionales para revisar en Puebla

Ademas de las cadenas con catalogo activo, se incorporo una cartera
`identity-only` generada desde el snapshot DENUE: 24 marcas candidatas y 30
ubicaciones con coordenadas y dominio web coincidente. Incluye ADN Examen,
CEDIC, Diagnosticos Integra, Exacta, Farmacias del Ahorro (laboratorio), Gamma
Medicina Nuclear, Grupo Medico Futura, Biquiser, Guadalupe, Qui-Rom, Castillo,
Gaya, Althe, Los Angeles, Microlab, Sveika RX, Piedad Lab, SIEMSO, Laboratorios
del Carmen, SUVEX y centros locales de ultrasonido y neurologia. Todas quedan
`verification_pending`: no se crean estudios, precios, disponibilidad ni
reservas hasta la verificacion humana.

La salida reproducible es:

```powershell
python database/scripts/build_puebla_website_identity_candidates.py `
  --denue-fixture database/fixtures/denue_candidates_puebla_v1.json `
  --output database/fixtures/generic_provider_identity_candidates_puebla_v1.json
```

El renderer permite artefactos web vacios o fallidos unicamente con
`--identities-only`; una captura fallida nunca puede publicar una oferta.
