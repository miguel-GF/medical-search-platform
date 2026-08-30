# Documentación de Pruevia

Este directorio reúne la documentación canónica importada el 25 de agosto de 2026 y una revisión de integración. Los archivos originales se conservaron en UTF-8 y sin reescribir su contenido.

## Orden recomendado de lectura

1. [Conversación canónica](00_CONVERSACION_CANONICA.md) — origen del problema, investigación y decisiones.
2. [Arquitectura canónica](01_ARQUITECTURA_CANONICA.md) — arquitectura objetivo de producto, software, infraestructura y datos.
3. [Fases de implementación](02_FASES_IMPLEMENTACION.md) — roadmap, gates y Definition of Done.
4. [Arquitectura de base de datos V1](DB_ARCHITECTURE_V1.md) — decisiones físicas y evolución del modelo.
5. [Catálogo de tablas V1](DB_TABLE_CATALOG_V1.md) — inventario de las 45 tablas.
6. [ERD](ERD.mmd) — diagrama Mermaid de relaciones principales.
7. [Revisión de integración](03_REVISION_INTEGRACION.md) — evaluación, riesgos y recomendaciones actuales.

La implementación ejecutable está en [`database/`](../database/README.md),
[`apps/api/`](../apps/api/) y el extractor local [`apps/ocr-service/`](../apps/ocr-service/README.md).

8. [Integración LOINC](LOINC_INTEGRACION.md) - descarga versionada, mapeo seguro y criterios de publicación.

9. [Benchmark del resolver V1](RESOLVER_BENCHMARK_V1.md) - 200 variantes revisadas, métricas y gate reproducible.

10. [Investigación de consultas públicas y benchmark de campo](REAL_QUERY_RESEARCH_V1.md) - 64 frases anonimizadas y corpus v2 de 200 casos nuevos.

11. [Corpus público para OCR](OCR_PUBLIC_CORPUS.md) - fuentes sintéticas,
    licencias, checksum y prueba local sin persistencia.

## Precedencia documental

Cuando haya una diferencia, se aplica este orden:

1. Las migraciones describen el esquema físico que realmente se intenta desplegar.
2. La arquitectura DB explica la intención del modelo físico.
3. La arquitectura canónica define las decisiones transversales del producto.
4. El plan por fases define orden y criterios de salida, no el estado real por sí solo.
5. La conversación canónica conserva contexto e hipótesis históricas.

Ninguna V1 debe considerarse desplegada hasta que un reset completo, el seed y las pruebas terminen sin errores en Supabase DEV.
