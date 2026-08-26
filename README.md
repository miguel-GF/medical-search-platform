# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 26 de agosto de 2026

El Data Engine previo a Flutter ya esta funcionando en Supabase DEV: 143 servicios activos, 144 ofertas, collectors Chopo/Ruiz publicados, Search API V1, Admin V1 y Gate A remoto con 10/10 aserciones. La busqueda real de `mastografia unilateral` retorna resultados de ambos proveedores con precio, sucursal y distancia. DENUE queda pendiente solo de su token oficial.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md) y [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: 45 tablas y 7 migraciones generadas.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine previo a Flutter.
- Collectors Chopo/Ruiz, Search API V1 y Admin V1: implementados y probados; Flutter y DENUE live siguen condicionados por sus respectivos gates.

## Repositorio

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). La siguiente acción técnica es ejecutar y corregir la DB V1 en un entorno Supabase DEV limpio.
