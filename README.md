# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 26 de agosto de 2026

El Data Engine previo a Flutter funciona técnicamente en Supabase DEV, pero Gate A de viabilidad sigue abierto: hay 143 servicios activos, 144 ofertas (143 Ruiz y 1 Chopo), y sólo 1 servicio con dos proveedores. La búsqueda por defecto ya prioriza diversidad de proveedores, pero todavía falta ampliar cobertura clínica y comercial antes de Flutter. DENUE queda pendiente de su token oficial.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md) y [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: migraciones 001-081 aplicadas y verificadas.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine previo a Flutter.
- Collectors Chopo/Ruiz, Search API V1 y Admin V1: implementados y probados; el Admin usa Supabase Auth y Flutter/DENUE live siguen condicionados por sus respectivos gates.

## Repositorio

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). La siguiente acción técnica es ejecutar y corregir la DB V1 en un entorno Supabase DEV limpio.
