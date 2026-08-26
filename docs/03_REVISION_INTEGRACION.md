# Pruevia — Revisión de integración

**Fecha:** 25 de agosto de 2026  
**Alcance:** documentación canónica, 7 migraciones SQL, seed y pruebas pgTAP de Database V1.  
**Veredicto:** propuesta coherente y con una base técnica fuerte; la incertidumbre principal está en validar operación de datos y demanda, no en la idea central.

## Estado operativo actualizado

La base ya no está solo en revisión estática. El proyecto Supabase enlazado (`pruevia-dev`, región `us-east-1`) recibió las 7 migraciones y el seed mediante `db push --include-seed`. La validación remota confirmó 13 schemas, 45 tablas, las extensiones `postgis`, `pg_trgm`, `unaccent` y `pgcrypto`, un dominio de salud, 9 tipos de muestra y 4 feature flags.

Las 15 pruebas estructurales/precio existentes y 10 invariantes nuevas se ejecutaron contra la base enlazada con `db query`; el runner pgTAP integrado sigue requiriendo Docker local, que no está disponible en este entorno.

El motor de collectors ya tiene artefactos RAW reproducibles, cuarentena por caídas parciales o descensos anómalos, adaptadores DENUE y Chopo Puebla, y normalización determinista. Una corrida real de Chopo produjo 116 registros válidos y 576 observaciones; esa evidencia se publicó en `ingest` como un `crawl_run` exitoso. No se crearon entidades canónicas automáticamente: esa separación es intencional hasta revisar equivalencias clínicas.

## Opinión ejecutiva

Sí existe un problema valioso: el paciente no debería necesitar conocer el nombre comercial exacto de un estudio para encontrar dónde realizarlo. La combinación de interpretación de orden, normalización clínica prudente, comparación por ubicación/precio y resolución de varios estudios es una propuesta más defendible que un comparador simple.

La mejor decisión del plan es tratar el primer MVP como un **Data Engine verificable**, no como una aplicación visual grande. Si Pruevia logra resolver búsquedas reales de Puebla con buena cobertura, frescura y pocos falsos equivalentes, habrá evidencia de producto. Si no lo logra, Flutter, OCR y SEO no corregirán el problema de fondo.

## Lo más sólido

- La separación entre concepto canónico y oferta comercial evita confundir nombres parecidos con equivalencias médicas.
- El modelo marca → mercado → sucursal permite expansión geográfica sin duplicar cadenas.
- Los precios consideran alcance, canal, horario, vigencia e historial; esto refleja casos comerciales reales.
- RAW → observación → normalización → publicación proporciona una base adecuada para trazabilidad.
- La cuarentena ante caídas anómalas de un crawler reduce el riesgo de destrucción masiva de datos.
- La IA queda como última capa de normalización, no como fuente incuestionable.
- El roadmap contiene gates de salida y pospone Big Data, reservas y billing hasta tener evidencia.
- La propuesta B2B de demanda no atendida es más convincente que cobrar solamente por aparecer.

## Riesgos que deben validarse pronto

### 1. Cobertura y costo operacional

El mayor riesgo es mantener catálogos, sucursales y precios frescos sin convertir el negocio en captura manual de datos. Deben medirse desde los primeros collectors:

- porcentaje de búsquedas con resultados útiles;
- servicios con dos o más proveedores comparables;
- antigüedad del precio mostrado;
- roturas por fuente y horas humanas por reparación;
- porcentaje de registros que requieren revisión manual.

### 2. Seguridad clínica de la normalización

Una coincidencia de texto no demuestra equivalencia clínica. Antes de automatizar resultados de alta confianza hace falta un proceso de gobierno terminológico: criterios explícitos, casos dorados, revisión por una persona con competencia clínica y registro de por qué dos conceptos se consideran iguales, variantes o no equivalentes.

### 3. Validación de usuarios y proveedores

La documentación contiene una buena investigación de escritorio y un dolor personal claro, pero todavía no registra suficiente evidencia de comportamiento real. Conviene validar en paralelo:

- si pacientes entienden y confían en el resultado;
- si completarían la búsqueda con datos reales;
- si clínicas pequeñas mantendrían precios/catálogo;
- si el dashboard de demanda cambia alguna decisión del proveedor;
- qué atribución mínima aceptarían antes de pagar.

Una prueba concierge con órdenes reales anonimizadas y resultados revisados manualmente puede validar esto antes de construir todas las interfaces.

### 4. Uso de fuentes y presentación de precios

Cada collector necesita una decisión documentada sobre permiso/política de uso, frecuencia, evidencia y mecanismo de baja. La interfaz también deberá comunicar fecha, fuente, condiciones y que el precio puede cambiar. El campo `usage_policy_status` es una buena base, pero no sustituye esa revisión por fuente.

### 5. Acceso Workers ↔ PostgreSQL

La arquitectura aún no fija el mecanismo concreto de conexión, pooling, timeouts y recuperación entre Cloudflare Workers y Supabase. Debe cerrarse con un ADR y una prueba pequeña antes de consolidar la API. El contrato REST versionado permite cambiar la implementación después, lo cual reduce el riesgo.

## Revisión de Database V1

La inspección estática confirmó:

- 45 sentencias `CREATE TABLE`, consistentes con el catálogo;
- 7 migraciones transaccionales y ordenadas por responsabilidad;
- extensiones PostGIS, `pg_trgm`, `unaccent` y `pgcrypto` declaradas;
- función `catalog.search_items()`;
- función `supply.resolve_prices()` con prioridad location > market > brand;
- seed idempotente básico;
- 15 aserciones pgTAP para estructura, seed, herencia de precios e integridad entre marcas.

Deuda técnica antes de declarar `db-v1.0.0`:

- ejecutar realmente reset → migrate → seed → test en Supabase DEV;
- ampliar pruebas para búsqueda, horarios nocturnos, días de semana, ciclos de paquetes, scopes inválidos, historial de precio y runs en cuarentena;
- decidir qué hechos publicados exigirán obligatoriamente `source_observation_id`; hoy parte de la provenance es nullable y se garantiza por proceso, no por constraint;
- definir la integridad futura de campos de revisión como `approved_by`, `reviewer_user_id` y `resolved_by`;
- documentar el modelo de credenciales del servidor y confirmar que los schemas internos permanezcan inaccesibles para clientes directos.

La deuda de despliegue de esta revisión queda resuelta para DEV enlazado. Falta repetir el flujo en CI con Docker o un runner pgTAP nativo, y mantener el mismo control de migraciones antes de declarar una versión productiva.

## Recomendación de ejecución

El orden inmediato más sensato es:

1. desplegar y endurecer Database V1;
2. construir DENUE + dos fuentes comerciales de Puebla;
3. crear un conjunto dorado de 100–200 estudios y medir normalización;
4. exponer una API mínima y un admin operativo;
5. ejecutar el Gate A con búsquedas y órdenes reales;
6. solo después acelerar la experiencia paciente, OCR y adquisición SEO.

## Conclusión

La arquitectura tiene sentido y sí apunta a resolver el problema descrito. No hay una objeción que obligue a abandonar la idea. La disciplina clave será proteger el alcance: demostrar primero que Pruevia puede producir respuestas correctas, frescas y suficientemente completas en una sola ciudad. Ese resultado es el activo central del proyecto.
