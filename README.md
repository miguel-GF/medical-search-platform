# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 27 de agosto de 2026

El Data Engine previo a Flutter funciona en Supabase DEV y Gate A de viabilidad es positivo: hay 175 servicios activos, 226 ofertas, 7 proveedores, 44 servicios compartidos con precio vigente, 23 sucursales con coordenadas y 437 precios vigentes. La búsqueda devuelve opciones comerciales y nuevas alternativas pequeñas con `requires_quote` cuando no existe precio publicado. DENUE ya tiene una corrida live reproducible con 489 registros válidos. Flutter queda deliberadamente fuera de este corte.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md) y [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: migraciones 001-108 aplicadas y verificadas.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine previo a Flutter.
- Collectors Chopo/Ruiz/Salud Digna/DENUE (fixtures, pruebas y corridas live reproducibles), Search API V1 y Admin V1: implementados y probados. Chopo, Ruiz, Salud Digna y DENUE están publicados en Supabase DEV. El gate remoto, los invariantes de base, la API pública y la cuarentena de colectores pasan; no se inicia Flutter hasta un nuevo corte de producto.
- Collector genérico de proveedores: discovery acotado por dominio, respeto de robots.txt, JSON-LD/patrones de precio-servicio y evidencia candidata para laboratorios pequeños.
- Fan-out de discovery Puebla: agrupa los sitios web declarados por DENUE y conserva el vínculo de cada host con sus candidatos para medir cobertura sin captura manual.
- Publicación genérica revisada: cuatro coincidencias exactas enlazadas a siete sedes DENUE; 44 ofertas restantes tienen una cola de revisión auditable y no publicable. Los reintentos sólo cubren fallos transitorios.

## Corte Fase 9-10: OCR y resolucion por paquete

`POST /api/v1/resolve-image` transcribe una orden de forma literal mediante
un binding opcional de Workers AI y encadena el texto al resolver; sin binding
responde `503` de forma segura.

## Corte Fase 10: resolucion por paquete

`POST /api/v1/resolve-batch` admite hasta 30 estudios arbitrarios, conserva
ambiguedades y calcula cobertura por sucursal o combinaciones de hasta tres
ubicaciones. La migracion `107` y la prueba remota del RPC estan documentadas
en `docs/02_FASES_IMPLEMENTACION.md` y `docs/DEV_OPERATIONS.md` (migraciones
107-108).

## Repositorio

El resolver clínico v6 ya cuenta con benchmarks v1 y v2 reproducibles (400
consultas; 331 variantes seguras y 69 abstenciones). El benchmark v2 cubre
estudios de imagen, funcionales, cardiología, COVID y ginecología que no se
habían probado antes. La investigación pública y el corpus de campo están en
[docs/REAL_QUERY_RESEARCH_V1.md](docs/REAL_QUERY_RESEARCH_V1.md).

```text
docs/       Decisiones canónicas, arquitectura, roadmap y revisión
database/   Migraciones, seed y pruebas ejecutables de PostgreSQL/Supabase
```

Comienza por el [índice de documentación](docs/README.md). El Data Engine queda detenido en Gate A positivo; el siguiente trabajo de producto será planificar Flutter después de aceptar formalmente este corte.
