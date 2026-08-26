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

El collector de DENUE requiere `DENUE_API_TOKEN` y recibe coordenadas/radio explícitos.

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
