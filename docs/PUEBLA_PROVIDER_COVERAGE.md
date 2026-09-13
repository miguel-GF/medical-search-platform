# Cobertura de proveedores de Puebla

La cartera de proveedores se separa en dos niveles para no publicar datos sin
verificación:

* `database/fixtures/generic_provider_mappings_puebla_v1.json` contiene diez
  identidades candidatas enlazadas a registros DENUE y sus dominios públicos.
  Las identidades se guardan como `verification_pending`; sólo cinco estudios
  tienen equivalencia clínica exacta aprobada.
* `database/fixtures/salud_digna_puebla_locations_v1.json` conserva ocho
  sucursales de Salud Digna confirmadas en páginas oficiales de Puebla, con
  coordenadas, domicilio, teléfono y horarios. El snapshot DENUE tenía cinco;
  por eso tres sucursales adicionales no deben perderse por depender sólo de
  DENUE.
* El adaptador `pruevia-semin` captura el catálogo público de Laboratorios
  SEMIN. La corrida de control recuperó 140 estudios únicos y nueve
  sucursales (149 registros RAW). Cada precio conserva el estado
  `unverified_provider_reference`, porque el propio catálogo expone fechas de
  actualización antiguas y no prueba vigencia comercial.

* El collector `pruevia-dr-simi` consulta únicamente el archivo JSON público de
  sucursales de Análisis Clínicos del Dr. Simi. La corrida de control confirmó
  una sede de Puebla (unidad 7); las otras cuatro filas DENUE de Dr. Simi siguen
  como candidatas porque el feed oficial actual no las publica.
* El collector dedicado de Chopo recuperó 60 registros actuales de Puebla y
  enlazó 11 ubicaciones DENUE como identidades pendientes. Sus 58 etiquetas no
  aprobadas quedaron en la cola administrativa; no se publicaron por similitud.

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

Después de publicar el artefacto, el renderer de ubicaciones enlaza las ocho
sucursales oficiales con `core.provider_locations` sin crear ofertas:

```powershell
python database/scripts/render_official_provider_locations.py `
  --fixture database/fixtures/salud_digna_puebla_locations_v1.json `
  --artifact collectors/artifacts/salud-digna-puebla-all/salud-digna-puebla/<run-id> `
  --chunk-dir collectors/artifacts/salud-digna-puebla-all/location-sql
```

## Sucursales públicas de Dr. Simi

El feed oficial de sucursales se captura sin acceder a cuentas ni a flujos de
citas. La corrida actual publicó sólo evidencia de ubicación para la unidad 7;
el domicilio y teléfono son del feed, mientras que las coordenadas se
contrastaron con DENUE. Las cuatro sedes DENUE restantes no se activan hasta
que el proveedor las confirme en su fuente oficial.

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
12 ubicaciones DENUE como `verification_pending`; Salud Digna suma ocho
ubicaciones oficiales y Dr. Simi una ubicación oficial. Las corridas SEMIN (149
registros), Chopo (60) y Salud Digna (6,923 registros) se guardaron en `ingest`.
La cola administrativa quedó abierta con
7,138 pendientes (`normalization_pending`): 6,910 estudios Salud Digna, 58 estudios Chopo, 140
estudios SEMIN y 30 etiquetas genéricas clínicas. Esto permite auditar y
depurar desde el panel administrativo sin presentar esos estudios como
resultados confirmados a pacientes.

## Cadencia operativa y puerta de liberación

La frecuencia recomendada es conservadora y depende del tipo de dato:

| Fuente | Qué actualizar | Cadencia | Regla de frescura |
| --- | --- | --- | --- |
| Salud Digna, Chopo, Ruiz y SEMIN | Catálogo/precio público | cada 24 h | cuarentena si faltan datos o supera 48 h |
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
