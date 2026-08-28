# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 27 de agosto de 2026

El Data Engine previo a Flutter funciona en Supabase DEV y Gate A de viabilidad es positivo: hay 175 servicios activos, 219 ofertas, 3 proveedores, 44 servicios compartidos con precio vigente, 16 sucursales con coordenadas y 437 precios vigentes. La búsqueda devuelve opciones de ambos proveedores para los servicios revisados. DENUE ya tiene una corrida live reproducible con 489 registros válidos. Flutter queda deliberadamente fuera de este corte.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md) y [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: migraciones 001-094 aplicadas y verificadas.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine previo a Flutter.
- Collectors Chopo/Ruiz/Salud Digna/DENUE (fixtures, pruebas y corridas live reproducibles), Search API V1 y Admin V1: implementados y probados. Chopo, Ruiz, Salud Digna y DENUE están publicados en Supabase DEV. El gate remoto, los invariantes de base, la API pública y la cuarentena de colectores pasan; no se inicia Flutter hasta un nuevo corte de producto.
- Collector genérico de proveedores: discovery acotado por dominio, respeto de robots.txt, JSON-LD/patrones de precio-servicio y evidencia candidata para laboratorios pequeños.
- Fan-out de discovery Puebla: agrupa los sitios web declarados por DENUE y conserva el vínculo de cada host con sus candidatos para medir cobertura sin captura manual.

## Repositorio

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). El Data Engine queda detenido en Gate A positivo; el siguiente trabajo de producto será planificar Flutter después de aceptar formalmente este corte.
