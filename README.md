# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: 45 tablas y 7 migraciones generadas.
- Despliegue y validación física en Supabase DEV: pendiente.
- Collectors, API, admin y aplicaciones: pendientes.

## Repositorio

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). La siguiente acción técnica es ejecutar y corregir la DB V1 en un entorno Supabase DEV limpio.
