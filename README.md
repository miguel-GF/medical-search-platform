# Pruevia — Medical Search Platform

Pruevia busca convertir el texto o la fotografía de una orden médica en una lista segura de estudios normalizados y opciones reales para realizarlos, comparando proveedor, sucursal, distancia, precio, vigencia y disponibilidad.

El piloto inicial está enfocado en Puebla, México. El nombre **Pruevia** es provisional.

## Estado ejecutado al 1 de septiembre de 2026

El Data Engine funciona en Supabase DEV y Gate A de viabilidad es positivo: hay 175 servicios activos, 226 ofertas, 7 proveedores, 44 servicios compartidos con precio vigente, 23 sucursales con coordenadas y 437 precios vigentes. La búsqueda devuelve opciones comerciales y nuevas alternativas pequeñas con `requires_quote` cuando no existe precio publicado. DENUE ya tiene una corrida live reproducible con 489 registros válidos. El vertical slice paciente de Flutter Web/PWA está integrado y preparado para Android/iOS.

Consulta el detalle y los comandos reproducibles en [docs/03_REVISION_INTEGRACION.md](docs/03_REVISION_INTEGRACION.md), [docs/02_FASES_IMPLEMENTACION.md](docs/02_FASES_IMPLEMENTACION.md) y la evidencia del flujo de proveedor en [docs/PROVIDER_CLAIMS_EVIDENCE_20260831.md](docs/PROVIDER_CLAIMS_EVIDENCE_20260831.md).
La auditoria de seguridad mas reciente y sus pruebas estan en [docs/SECURITY_AUDIT_20260901.md](docs/SECURITY_AUDIT_20260901.md).

## Estado actual

- Arquitectura de producto y software: definida.
- Base de datos V1: migraciones 001-136 aplicadas y verificadas; las migraciones 128-136 agregan segmentacion exacta de paquetes, la cola administrativa de revision, la validacion de proveedor en el flujo de alias, limites de captura publica, mutaciones idempotentes y endurecimiento de seguridad de la evidencia.
- Despliegue y validación física en Supabase DEV: completado para el Data Engine y el contrato API consumido por Flutter.
- Collectors Chopo/Ruiz/Salud Digna/DENUE (fixtures, pruebas y corridas live reproducibles), Search API V1 y Admin V1: implementados y probados. Chopo, Ruiz, Salud Digna y DENUE están publicados en Supabase DEV. El gate remoto, los invariantes de base, la API pública y la cuarentena de colectores pasan.
- Flutter Patient MVP: búsqueda, receta multi-estudio, OCR con revisión, comparación por sucursal, PWA responsive, Android/iOS preparados, consentimiento y telemetría anónima limitada. `Acceso para proveedores` es una entrada secundaria; las mutaciones de proveedor exigen MFA `aal2` en el backend.
- Collector genérico de proveedores: discovery acotado por dominio, respeto de robots.txt, JSON-LD/patrones de precio-servicio y evidencia candidata para laboratorios pequeños.
- Fan-out de discovery Puebla: agrupa los sitios web declarados por DENUE y conserva el vínculo de cada host con sus candidatos para medir cobertura sin captura manual.
- Publicación genérica revisada: cuatro coincidencias exactas enlazadas a siete sedes DENUE; 44 ofertas restantes tienen una cola de revisión auditable y no publicable. Los reintentos sólo cubren fallos transitorios.

## Corte de cobertura real 31-ago-2026

Chopo incorporo Insulina, Glucosa, BH y EGO con precios oficiales observados;
Asesores incorporo Insulina y EGO como ofertas con cotizacion obligatoria. Los
detalles, corridas y exclusiones estan en
[docs/COBERTURA_REAL_20260831.md](docs/COBERTURA_REAL_20260831.md).

## Corte Fase 9-10: OCR y resolucion por paquete

`POST /api/v1/resolve-image` transcribe una orden de forma literal mediante
el extractor Python privado o un binding opcional de Workers AI y encadena el
texto al resolver. El flujo de imagen usa reglas OCR revisadas en la base
(`OBH -> BH`, `OQS completa -> Q S completa` y `Pertil firondle -> Perfil
tiroideo`); conserva el original y nunca elige automáticamente entre paneles
ambiguos. Sin extractor responde `503` de forma segura.

El resolver tampoco publica coincidencias fuzzy debiles: por debajo de 0.75
se conserva una sugerencia con `requires_confirmation` y no se exponen sus
ofertas como cobertura.

## Corte Fase 10: resolucion por paquete

`POST /api/v1/resolve-batch` admite hasta 30 estudios arbitrarios, conserva
ambiguedades y calcula cobertura por sucursal o combinaciones de hasta tres
ubicaciones. La migracion `107` y la prueba remota del RPC estan documentadas
en `docs/02_FASES_IMPLEMENTACION.md` y `docs/DEV_OPERATIONS.md` (migraciones
107-117).

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

Comienza por el [índice de documentación](docs/README.md). El Data Engine permanece en Gate A positivo y el siguiente corte de producto será conectar el flujo de autenticación/MFA del proveedor y validar la PWA con usuarios externos.
