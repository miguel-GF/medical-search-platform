# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 27 de agosto de 2026

El Data Engine previo a Flutter funciona técnicamente en Supabase DEV, pero Gate A de viabilidad sigue abierto: hay 143 servicios activos, 147 ofertas (143 Ruiz, 1 Chopo y 3 Salud Digna) y 4 servicios con dos proveedores. Hay 16 sucursales activas con coordenadas y 293 precios vigentes. La búsqueda ya prioriza diversidad de proveedores, pero todavía falta ampliar cobertura clínica y comercial antes de Flutter. DENUE queda pendiente de su token oficial.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md) y [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: migraciones 001-081 aplicadas y verificadas.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine previo a Flutter.
- Collectors Chopo/Ruiz y el adapter Salud Digna (fixtures, pruebas y corrida live reproducible), Search API V1 y Admin V1: implementados y probados. Salud Digna ya está publicado en Supabase DEV (830 registros válidos y 4,150 observaciones); puede usarse DSN de servidor o el renderer por lotes para la API enlazada de Supabase. DENUE live sigue requiriendo su token oficial.

## Repositorio

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). La siguiente acción técnica es ampliar la cobertura multi-proveedor (DENUE/MAC y revisión de labels) y cerrar Gate A antes de construir Flutter.
