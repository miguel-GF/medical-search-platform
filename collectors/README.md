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

## Contrato de un adapter

Un adapter debe separar descubrimiento/recuperación de la persistencia:

```python
class Adapter:
    source: SourceSpec

    def collect(self) -> Iterable[SourceRecord]:
        ...
```

La implementación de cada fuente será responsable de respetar sus políticas de acceso, ritmo de solicitudes y evidencia disponible. El núcleo solo controla integridad, trazabilidad y seguridad del run.
