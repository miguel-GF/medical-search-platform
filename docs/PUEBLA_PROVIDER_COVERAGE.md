# Cobertura de proveedores de Puebla

> Informe de cobertura con snapshots fechados; sus cantidades y cadencias recomendadas no demuestran estado actual ni jobs activos.
> Entrada: [índice vigente](README.md). Estado: [CURRENT_STATE](CURRENT_STATE.md).

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
