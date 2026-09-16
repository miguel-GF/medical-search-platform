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

Para publicar, usa un DSN de servidor en `PRUEVIA_DATABASE_URL` (nunca una clave `anon` del cliente):

```powershell
python -m pruevia_collectors.cli_publish artifacts/<source>/<run-id>
```

### Catálogo público de SEMIN Puebla

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
