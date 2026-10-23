# Pruevia collectors

Núcleo reproducible para descubrir fuentes, guardar evidencia RAW y producir observaciones candidatas. Los collectors no escriben directamente en `catalog` ni `supply`: primero dejan un artefacto auditable que una etapa posterior puede validar y publicar.

## Flujo

```text
adapter
  → SourceRecord
  → validación + hash
  → raw_records.jsonl
  → observations.jsonl
  → run_manifest.json
  → normalización/publicación posterior
```

Cada ejecución queda bajo:

```text
artifacts/<source-slug>/<run-id>/
  run_manifest.json
  raw_records.jsonl
  observations.jsonl
```

Una caída anómala de volumen se marca `quarantined`; sus observaciones no se consideran publicables. Los hashes hacen que un mismo registro repetido dentro del run no se procese dos veces.

## Ejecutar pruebas

Desde `collectors/`:

```powershell
python -m pytest
```

Smoke run de Chopo Puebla (solo escribe artefactos locales):

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_chopo --max-pages 1
```

Smoke run de Salud Digna Puebla (sucursal + estudios por sucursal):

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_salud_digna --location-slug puebla-municipio-libre
```

Para varias sucursales repite `--location-slug`. `--no-catalog` permite hacer
solo discovery de sucursales cuando el endpoint de estudios está temporalmente
indisponible; ese artefacto no debe usarse para publicar ofertas.
La base del servicio puede cambiarse con `--services-base-url` solo cuando el
proveedor publique oficialmente otro endpoint.

El adapter de Laboratorios Ruiz recorre por defecto el catálogo acotado completo
(hasta 10,000 ofertas entre todos los departamentos). `--per-department` sólo
debe usarse para un piloto explícito; dejarlo omitido evita perder estudios que
aparecen después de las primeras filas del endpoint, como Citometría hemática.

Recuperación SD del23-oct-2026: el transporte con IP pública acepta el contexto
TLS verificado configurado por el proveedor; pasarlo sólo a `httpx.Client` no
configura un transporte personalizado. El helper de redirecciones solicita
`Accept-Encoding: identity`, conforme al lector que rechaza compresión.
Certificado, hostname, IP pública y límites siguen siendo obligatorios.
[Captura real en ocho sucursales y alcance](../docs/PUEBLA_SOURCE_REFRESH_20261023.md).

El collector de DENUE requiere `DENUE_API_TOKEN` y recibe coordenadas/radio explícitos.

Para recorrer automáticamente los sitios web declarados por los candidatos
DENUE de Puebla, usa el fan-out reproducible (agrupa por host y no repite una
misma marca/sitio):

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.puebla_discovery `
  --fixture ../database/fixtures/denue_candidates_puebla_v1.json `
  --artifact-root artifacts/puebla-generic `
  --max-providers 100 --max-pages 3 --max-depth 1
```

El comando escribe `puebla_generic_discovery_manifest.json` con la población
DENUE original (por ejemplo, 489 registros), las filas clasificadas que se
consideraron (por ejemplo, 213 candidatos directos), sitios sin URL, hosts
seleccionados, candidatos DENUE por host y conteos de ubicaciones/servicios/precios.
Por defecto sólo procesa
los candidatos clínicos directos; `--include-review` añade la cola de posibles
proveedores relacionados. Un bloqueo por `robots.txt`, DNS o HTTP queda como
salto auditable y no cancela los demás hosts.

### Collector genérico de proveedores

`pruevia-generic` permite descubrir un proveedor pequeño sin escribir un
adapter dedicado. Recibe una o más páginas semilla del mismo host, sigue un
presupuesto acotado de enlaces internos y extrae, en este orden:

1. JSON-LD de schema.org (`MedicalClinic`, `DiagnosticLab`, `Product`,
   `Service`, `Offer`);
2. headings y precios con patrones deterministas (`$`, `MXN`, precio/costo);
3. domicilio, teléfono, código postal y coordenadas cuando están publicados.

Reconoce tanto Biometría hemática como Citometría hemática. Algunos CMS colocan
el nombre del estudio en el `alt` de una imagen de tarjeta y el precio en un
encabezado vecino; ese patrón se conserva como evidencia candidata, igual que
los demás resultados del collector, y no constituye por sí solo una aprobación.

Ejemplo:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_generic `
  --seed-url https://laboratorio-pequeno.example/servicios `
  --max-pages 25 --max-depth 1 --artifact-root artifacts/generic
```

#### Catálogo SEMIN (Puebla)

SEMIN tiene un adapter dedicado (`pruevia-semin`) para recuperar el catálogo
estructurado y sus sucursales. Para una captura rápida de páginas públicas
también se puede usar el collector genérico:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_generic `
  --seed-url https://semindigital.com/ `
  --seed-url https://semindigital.com/servicios `
  --seed-url https://semindigital.com/sucursales `
  --max-pages 25 --max-depth 1 --artifact-root artifacts/semin-generic
```

La corrida sólo produce candidatos auditables. Las modalidades sin estudio
específico (por ejemplo, "ultrasonido", "tomografía" o "resonancia") no se
publican automáticamente; primero deben aportar protocolo, región anatómica y
la equivalencia clínica correspondiente. Verifica `robots.txt` y los términos
vigentes antes de cada corrida; una autorización para desarrollar el collector
no sustituye el permiso contractual del proveedor.

El adapter `pruevia-dr-simi` consume el archivo JSON público de sucursales
(`assets/data/sucursalesMAPA.json`) y la página pública de campaña del mismo
dominio. No llama endpoints de citas, pacientes, resultados ni promociones.
La corrida de Puebla confirmó cuatro sedes; tres tienen coordenadas contrastadas
con DENUE y una queda pendiente por discrepancia de domicilio. Las coordenadas
y cualquier catálogo de estudios se verifican por separado.

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_dr_simi --artifact-root artifacts/dr-simi-puebla
```

El adapter `pruevia-linfolab` lee la página pública de sucursales, respeta
`robots.txt` y conserva sólo tarjetas con domicilio publicado en el enlace de
Maps. No infiere estudios ni precios. Si el certificado TLS del proveedor no
se puede validar, la corrida queda en cuarentena; no se debe desactivar TLS ni
usar `--ignore-robots` en producción.

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_linfolab --artifact-root artifacts/linfolab-puebla
```

El crawler está limitado al host semilla, respeta `robots.txt`, rechaza
credenciales, redirecciones externas y hosts privados, limita el tamaño de
respuesta y conserva un ritmo entre páginas. Los registros salen como `provider_location_discovered`,
`provider_offer_discovered` o `provider_offer_price`, todos con estado
`candidate`; no crean ítems, proveedores ni precios canónicos automáticamente.
Los precios visibles sólo se aceptan cuando hay encabezado clínico y contexto
explícito de moneda/precio; cifras de navegación, teléfonos o marketing quedan
fuera. Los fallos por página se reflejan como `failed`/`quarantined`, nunca como
una corrida vacía exitosa.
Para una clínica reclamada se puede añadir después un adapter dedicado, pero
el flujo genérico sigue siendo la puerta de entrada global.

Para una segunda oportunidad sólo se reintentan corridas `empty` o fallos de
transporte transitorios; los bloqueos de robots, DNS no resoluble y HTTP
permanente se dejan fuera:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.puebla_retry `
  --manifest artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --artifact-root artifacts/puebla-generic-retry `
  --max-pages 2 --max-depth 1
```

El retry crea otro manifiesto y otro conjunto de RAW; nunca sobrescribe la
corrida original.

Las coincidencias exactas revisadas se publican con el renderer de mapeos
genéricos. La transacción crea marcas/sedes con `verification_pending`, enlaces
DENUE y ofertas `requires_quote`; no inventa precios. El fixture sólo aprueba
cuatro etiquetas exactas; el resto permanece en RAW para revisión clínica.

### Configuración local

Para desarrollo, copia `.env.example` como `.env` y completa `DENUE_API_TOKEN`.
El archivo `.env` está ignorado por Git; nunca pongas el token en el código, en
un commit ni en una clave `anon` del cliente. Las variables definidas en el
proceso (CI/producción) tienen prioridad sobre `.env`.

```powershell
Copy-Item .env.example .env
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli --latitude 19.0437 --longitude -98.1982
```

Para publicación, el mismo `.env` puede contener `PRUEVIA_DATABASE_URL`; usa
un DSN de servidor y no una credencial pública del frontend.

## Normalización V1

`pruevia_collectors.normalization` comparte la regla de normalización de `core.normalized_text`.
Los nombres canónicos y alias aprobados se resuelven de forma determinista; una coincidencia
difusa solo produce candidatos y queda `ambiguous` para revisión. Esto evita convertir por
similitud textual dos servicios clínicos que no sean equivalentes.

El triage administrativo (`normalization_triage`) conserva identificadores literales
al filtrar sugerencias: numeral romano tras `factor`, secuencias PM-Scl/PM-1/Scl-70
y epíteto tras `Dermatophagoides`. Una diferencia o identificador ausente se registra
como conflicto o especificidad perdida. Este filtro sólo restringe candidatos:
no corrige truncaciones, no aprueba equivalencias, no revalida fuentes ni modifica
el resolvedor público. Los números arábigos, `FVIII`, `D.` y listas de varios factores
requieren investigación adicional. Véase [evidencia y límites](../docs/CATALOG_REVIEW_62_20261018.md).

## Contrato de un adapter

Un adapter debe separar descubrimiento/recuperación de la persistencia:

```python
class Adapter:
    source: SourceSpec

    def collect(self) -> Iterable[SourceRecord]:
        ...
```

La implementación de cada fuente será responsable de respetar sus políticas de acceso, ritmo de solicitudes y evidencia disponible. El núcleo solo controla integridad, trazabilidad y seguridad del run.

## Publicar un artefacto

La publicación se detiene en `ingest`; no crea ítems canónicos ni ofertas comerciales. Primero valida el artefacto:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id> --dry-run
```

El `--dry-run` comprueba recuentos, hashes, límites y enlaces entre observaciones
y RAW sin conectarse a la base. El manifiesto no puede aprobar su propia fuente:
una fuente nueva se registra siempre como `review_required`; la política de una
fuente existente se conserva en la base y sólo puede cambiarse mediante revisión
administrativa separada. Una validación local no autoriza rastrear un sitio ni
activa el reproceso clínico.

### DENUE estatal local — operativo desde 9-oct-2026

La [descarga estatal oficial](https://www.inegi.org.mx/contenidos/masiva/denue/denue_21_csv.zip)
permite investigar todo Puebla sin token del API. `pruevia-denue-bulk` valida ZIP,
metadatos, licencia, esquema, estado, IDs y límites; selecciona SCIAN 621/622 y
conserva sólo evidencia de identidad/ubicación. No crea conceptos, ofertas ni
sedes canónicas. Excluye teléfono, correo y representante legal. Las filas sin
nombre/coordenadas válidas conservan señales de calidad y no se completan por
inferencia. Atribuir “Fuente: INEGI, DENUE”, fecha del corte y transformación de
Pruevia conforme a los [términos oficiales](https://www.inegi.org.mx/inegi/terminos.html).

Desde `collectors/`, con el ZIP oficial descargado en la carpeta ignorada:

```powershell
python -m pruevia_collectors.cli_denue_bulk `
  --archive artifacts/puebla-expansion-20261009/denue_21_csv.zip `
  --artifact-root artifacts/puebla-expansion-20261009/denue-bulk
```

El manifiesto impreso proporciona la carpeta exacta de la corrida. Desde
`database/`, preparar los lotes sin escribir en remoto:

```powershell
python scripts/publish_denue_bulk_linked.py <carpeta-exacta-de-la-corrida> `
  --output-dir ../collectors/artifacts/puebla-expansion-20261009/ingest-sql `
  --expected-project-ref <referencia-confirmada>
```

Agregar `--apply` sólo dentro de una operación remota autorizada sobre esa base;
`--management-api` usa el token privado existente del CLI (Windows Credential
Manager o `SUPABASE_ACCESS_TOKEN`) para el API oficial, sin imprimirlo. El
transporte sólo acepta este origen gubernamental con licencia revisada;
un manifiesto arbitrario no obtiene permiso. Una corrida queda `partial` hasta
confirmar RAW y observaciones completos; cada lote actualiza `load_receipt.json`.
Ante un fallo inspeccionar ese recibo y el estado remoto antes de reintentar.

La carga del 9-oct confirmó 13,747 establecimientos, 217 municipios y 69,426
observaciones en 157 lotes. No equivale a cobertura comercial de estudios ni a
que todos los negocios sigan abiertos. [Evidencia y siguiente trabajo](../docs/PUEBLA_LOCAL_OPERATION_20261009.md).

### DENUE mensual por API (preparado, apagado)

La API oficial del [DENUE](https://www.inegi.org.mx/servicios/api_denue.html)
requiere token y limita `Buscar` a radios de 5 km. El runner preparado consulta
dos términos en cinco centros del piloto (Puebla, San Pedro y San Andrés
Cholula, Amozoc y Tlaxcala), deduplica establecimientos por ID y guarda sólo
evidencia de `provider_location` en `ingest`. Es una cobertura por puntos, no un
censo exhaustivo municipal. No crea marcas, sucursales verificadas, estudios,
ofertas, precios ni disponibilidad. Si los datos se muestran públicamente,
debe acreditarse “Fuente: INEGI, DENUE” y su actualización, indicar que la
transformación es de Pruevia y no aparentar aval del Instituto, conforme a sus
[términos de libre uso](https://www.inegi.org.mx/inegi/terminos.html).

El Worker `pruevia-api` comprueba en cada corrida que la base mantenga
exactamente la fuente y endpoint activos, `usage_policy_status=approved` y que
el gobierno no esté ligado a una marca. La RPC vuelve a validar estas
condiciones al escribir. Sólo conserva ID DENUE, nombre del establecimiento,
actividad, dirección y coordenadas; excluye teléfono, correo y sitio web. La
migración/RPC y el cron mensual del Worker ya están desplegados, pero
`DENUE_COLLECTION_ENABLED=false` y aún falta el secreto `DENUE_API_TOKEN` en
Cloudflare; no ha ocurrido una corrida ni está activa la recolección. El token
se solicita en el [portal oficial del API](https://www.inegi.org.mx/servicios/api_denue.html)
y debe guardarse como secreto del Worker, nunca en Git ni en el chat.

Al habilitarse, el Worker vuelve a comprobar la política dentro de la RPC,
serializa corridas mensuales e idempotentes y escribe sólo en `ingest`. La
captura no procesa el backlog clínico y no autoriza los collectors comerciales
de Chopo, Salud Digna, SEMIN o sitios genéricos. El cron sólo registra la
captura dirigida por puntos; no afirma un censo municipal ni actualiza sedes
canónicas.

Antes de programar Chopo, Salud Digna o SEMIN, el preflight de sólo lectura
puede comprobar la política y el endpoint persistidos, con
`PRUEVIA_DATABASE_URL` configurado en el entorno local:

```powershell
python -m pruevia_collectors.automation_preflight chopo_puebla
```

Sólo acepta una fuente oficial activa, ligada a un proveedor, con política
`approved` y endpoint activo que coincida con el adaptador. Hoy no activa
ningún collector ni cambia políticas. El resultado del preflight no basta por
sí solo para afirmar que existe un horario, que el sitio permite la captura o
que se publicó una oferta; esa revisión y el job siguen pendientes.

Hay además un runner local preparado para una sola captura acotada del catálogo
SEMIN. Requiere `PRUEVIA_DATABASE_URL`, pasa el preflight antes de abrir red,
obtiene un bloqueo por fuente, limita la ejecución a 15 minutos, valida el
artefacto, vuelve a comprobar la política y sólo entonces guarda evidencia en
`ingest`. No crea equivalencias ni ofertas. Si el collector falla o queda en
cuarentena, no ingiere ese lote. La base actual mantiene esa fuente en
`review_required`, por lo que el comando se detendrá antes de capturar:

```powershell
python -m pruevia_collectors.scheduled_runner semin_catalog_puebla
```

Esto no es un scheduler activo. Antes de conectarlo a un horario faltan la
revisión de condiciones de fuente, un ensayo real aprobado, alertas y recuperación
operativa. Los demás adaptadores necesitan además un plan de captura completa
para no marcar una muestra parcial como fuente fresca.

Para publicar, usa un DSN de servidor en `PRUEVIA_DATABASE_URL` (nunca una clave `anon` del cliente):

```powershell
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id>
```

### Revisión de identidades DENUE ya capturadas

Desde la raíz del repositorio, el renderer reutiliza la corrida gubernamental
licenciada y un fixture fechado con IDs investigados. No captura un catálogo
comercial ni deduce ofertas a partir de una dirección:

```powershell
python database/scripts/render_denue_identity_review.py <carpeta-exacta-de-la-corrida-DENUE> `
  --fixture database/data/provider-identity-review-20261011-02.json `
  --output collectors/artifacts/identity-review/preview.sql
```

Por defecto genera una transacción con `ROLLBACK`; `--apply` genera `COMMIT`,
pero el comando no ejecuta SQL. Las sedes nuevas permanecen `pending` y las
marcas `verification_pending`; el SQL aborta si una identidad ya está enlazada
o existe colisión. Conservar recibos antes de reintentar. Las observaciones
derivadas `reviewed_identity_link` no se cuentan como los seis atributos
originales de captura al comprobar integridad de una recarga DENUE.

El fixture puede declarar `identity_activity_codes` por marca. Sin ese campo
se admiten sólo 621511/621512; la lista explícita también admite hospitales
generales 622111/622112. Cada ID conserva su clase exacta del RAW: hospitales
se guardan como `hospital` y establecimientos diagnósticos como `branch`.
La transacción vuelve a comprobar esa clase, hash, corrida y licencia; conserva
`pending`, auditoría y cero ofertas. La revisión del 11-oct enlazó ocho sedes,
incluida la matriz hospitalaria CEEAD, después de rollback y commit comprobados.
Las diferencias de domicilio permanecen en el fixture y no se rellenan.

`existing_brand` permite reutilizar explícitamente una marca activa investigada
sin crearla ni actualizarla. Debe contener exactamente `id`, `name`,
`normalized_name`, `slug`, `website_url`, `status`, `verification_status`, con
identidad y estado iguales a los leídos en la base. La transacción bloquea la
fila y exige que su snapshot completo permanezca idéntico. El recibo separa
`brands` nuevas y `brands_reused` cuando corresponde; no permite replay de una
sede enlazada. La revisión 07 de Zacatlán conserva `CALLE DEL ROBLE SN` y añade
una sede `pending` bajo IMSS-Bienestar existente, con rollback/commit y ledger
comprobados, cero ofertas y políticas sin cambios.

### Catálogo público de SEMIN Puebla

Desde parser `0.2.1`, el detalle conserva `provider_detail_evidence.sinAcro`
y los IDs declarados en `available_sucursales`, limitados a 100 sedes y 4,000
caracteres por referencia textual. Marcadores explícitos indican captura parcial
o inválida. Son referencias no verificadas: no crean aliases ni disponibilidad.
Observación pública 21-oct: `precioApoyo` corresponde a Precio sucursal y
`precioVenta` a Precio online en la tarjeta examinada; no se demostró membresía
ni el canal de `precioNormal`. Los tipos históricos de precio se conservan.
Véase `docs/PUEBLA_IDENTITIES_41_AND_SEMIN_EVIDENCE_20261021.md` para límites.

El adaptador dedicado captura estudios, categoría, muestra, preparación,
tiempo de entrega, referencia de precio y sucursales sin llamar operaciones de
citas. Respeta `robots.txt` y deja todos los registros como `candidate`:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_semin `
  --max-pages 8 --max-results 150 --max-details 150 `
  --artifact-root artifacts/semin-catalog-puebla
```

Los precios se marcan como referencia no verificada. La cartera de diez
identidades candidatas de Puebla y el flujo de revisión están documentados en
`docs/PUEBLA_PROVIDER_COVERAGE.md`.
