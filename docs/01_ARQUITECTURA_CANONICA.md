# Pruevia — Arquitectura canónica

**Versión:** 1.0  
**Fecha:** 22 de agosto de 2026  
**Estado:** arquitectura objetivo aprobada para iniciar construcción.  
**Nombre:** Pruevia es provisional.

---

# 1. Objetivo arquitectónico

Construir una plataforma capaz de:

1. recibir texto u orden médica;
2. identificar y normalizar estudios/procedimientos;
3. relacionarlos con ofertas reales de proveedores;
4. resolver precio, ubicación, vigencia y disponibilidad;
5. mantener provenance completa de cada dato;
6. crecer de Puebla a múltiples ciudades/países sin rediseño estructural;
7. soportar B2C, B2B, analytics, marketplace y Big Data futuros;
8. reutilizar el núcleo para otros dominios futuros sin contaminar Pruevia con reglas ajenas a salud.

Principio:

> **Core reusable, domain semantics strongly typed.**

No se construirá una base universal EAV ni una mega tabla JSON.

---

# 2. Vista de alto nivel

```text
                             INTERNET
                                 │
          ┌──────────────────────┼───────────────────────┐
          │                      │                       │
          ▼                      ▼                       ▼
  marca.com / www        app.marca.com          admin.marca.com
       Nuxt 3             Flutter Web             Vue 3 + EP
     SEO público               │                       │
          │                    │                       │
          │             Android / iOS                 │
          │                    │                       │
          └────────────────────┼───────────────────────┘
                               │
                               ▼
                        api.marca.com
                     Cloudflare Workers
                         TypeScript
                               │
                ┌──────────────┼───────────────┐
                │              │               │
                ▼              ▼               ▼
        PostgreSQL         Cloudflare R2      APIs/AI
         Supabase          objects/raw        externas
                ▲
                │
          Python collectors
                │
       ┌────────┼─────────┬──────────┐
       ▼        ▼         ▼          ▼
     DENUE    Chopo      Ruiz       MAC ...
```

Portal futuro de proveedores:

```text
provider.marca.com
Vue 3 + Element Plus
        │
        └──── misma API Worker
```

---

# 3. Stack definitivo actual

## 3.1 API

- Cloudflare Workers
- TypeScript
- REST versionada (`/api/v1`)
- validación de JWT/autorización
- acceso controlado a PostgreSQL
- integración con R2 y APIs externas

### Motivo

- sin servidor persistente que administrar;
- HTTPS y edge incluidos;
- escala progresiva;
- free tier útil;
- mismo deployment puede subir de plan;
- contrato API independiente del framework futuro.

Laravel no está prohibido. Si posteriormente aparece un módulo empresarial que lo justifique, puede coexistir detrás del mismo dominio/API sin cambiar Flutter.

---

## 3.2 Base de datos

- PostgreSQL
- Supabase
- PostGIS
- `pg_trgm`
- `unaccent`
- `pgcrypto`

### Función

Fuente transaccional de verdad para:

- catálogo;
- proveedores;
- sucursales;
- ofertas;
- precios vigentes e históricos;
- ingest/normalización;
- usuarios/permisos;
- marketplace futuro.

### Regla

PostgreSQL sigue siendo el OLTP aunque Pruevia crezca a gran escala.

---

## 3.3 Archivos

Cloudflare R2 para:

- HTML RAW;
- PDFs;
- evidencia de crawlers;
- documentos de verificación;
- uploads temporales;
- backups;
- datasets Parquet futuros.

PostgreSQL solo guarda metadata/keys/hashes, no archivos binarios pesados.

---

## 3.4 Collectors

Python.

Bibliotecas previstas según fuente:

- `httpx` / `requests`;
- BeautifulSoup;
- PyMuPDF;
- Playwright para sitios dinámicos;
- parsers específicos por proveedor.

Cada proveedor tendrá un adapter independiente.

Ejemplo:

```text
collectors/providers/
  denue/
  chopo/
  ruiz/
  salud_digna/
  mac/
```

Un cambio de Chopo no debe romper Ruiz.

---

## 3.5 Admin interno

- Vue 3
- TypeScript
- Element Plus
- Pinia
- Vue Router
- Vite

Uso:

- revisar normalizaciones;
- corregir aliases;
- inspeccionar crawlers;
- administrar proveedores;
- revisar data quality;
- gestionar verificaciones;
- resolver duplicados;
- observar operaciones.

---

## 3.6 Panel de proveedores

- Vue 3
- TypeScript
- Element Plus

Compartirá componentes/tipos/cliente de API con admin cuando tenga sentido.

Debe servir a:

- dueño de marca;
- gerente regional;
- encargado de sucursal;
- analista.

---

## 3.7 App paciente

Flutter único codebase:

```text
Android
+iOS
+Web
```

Flutter Web se utilizará para experiencia app-like, no como web SEO.

---

## 3.8 Web pública SEO

Nuxt 3 + TypeScript + CSS/Tailwind/componentes propios.

No Element Plus.

Objetivos:

- HTML indexable;
- SSR/SSG/híbrido;
- Core Web Vitals;
- contenido útil;
- adquisición orgánica.

Ejemplos:

```text
/puebla/electromiografia-miembros-inferiores
/puebla/resonancia-magnetica-rodilla
/estudios/biometria-hematica
/proveedores/laboratorios-ruiz
```

---

# 4. Git y CI/CD

GitHub privado es fuente oficial del código.

Monorepo objetivo:

```text
/apps
  /api
  /admin
  /provider
  /patient
  /web

/collectors
  /core
  /providers

/database
  /migrations
  /seeds
  /tests

/docs
/packages
```

Deployment API:

```text
git push
  ↓
GitHub Actions
  ↓
lint/tests/build
  ↓
Wrangler
  ↓
Cloudflare Worker
```

Collectors programados pueden usar GitHub Actions inicialmente y migrar a containers/workers dedicados cuando el consumo lo exija.

---

# 5. Ambientes

Mínimo:

```text
DEV
PROD
```

QA se introduce solo cuando la cadencia/equipo lo justifique.

Separación obligatoria:

- PostgreSQL;
- buckets;
- secrets;
- Workers;
- URLs.

Ejemplo:

```text
api-dev...
api...
```

Nunca desarrollar directamente sobre PROD.

---

# 6. Dominio

Un solo dominio principal.

```text
marca.com
app.marca.com
api.marca.com
admin.marca.com
provider.marca.com
```

No se necesita hosting del registrador.

Se recomienda registrar solo el dominio y operar DNS/SSL/routing desde Cloudflare.

---

# 7. Arquitectura de datos

La base se separa por schemas:

| Schema | Responsabilidad |
|---|---|
| `geo` | jerarquía y geometría |
| `core` | organizaciones, marcas, sucursales, mercados |
| `catalog` | catálogo canónico reusable |
| `health` | semántica diagnóstica |
| `supply` | ofertas, scopes, precios, disponibilidad |
| `ingest` | fuentes, RAW, crawlers, normalización |
| `identity` | identidad y permisos |
| `audit` | auditoría |
| `ops` | alertas/flags |
| `analytics` | reservado para eventos/agregados |
| `marketplace` | reservado para leads/reservas |
| `sensitive` | reservado para datos sensibles |
| `billing` | reservado para PRO |

V1 ejecutable actual: **45 tablas**.

---

# 8. Core reusable vs dominio médico

## Core

Debe ser reutilizable para un producto futuro:

- organizations;
- brands;
- locations;
- catalog identity;
- offers;
- prices;
- availability;
- sources;
- ingest;
- search/analytics;
- marketplace.

## Health diagnostics

Añade:

- service type;
- lateralidad;
- contraste;
- anatomía;
- muestras;
- preparación;
- componentes;
- terminologías.

Pruevia solo consume `health_diagnostics`.

Otro producto futuro podría agregar `medications` o `auto_parts` sin introducir condicionales del otro dominio dentro de Pruevia.

---

# 9. Modelo proveedor

Separación:

```text
Legal Organization
        │
        ▼
Provider Brand
        │
        ├── Location A
        ├── Location B
        └── Location C
```

Una marca existe una vez.

Puebla/Querétaro/CDMX son ubicaciones/mercados, no marcas duplicadas.

`provider_brand_organizations` permite:

- owner;
- operator;
- franchise.

---

# 10. Mercados comerciales

`provider_markets` representa zonas comerciales/precio de una marca.

Esto permite:

```text
Chopo Puebla market
```

sin asumir que coincide exactamente con un municipio oficial.

La sucursal pertenece a un market de su misma marca.

La DB debe rechazar asignaciones cruzadas entre marcas.

---

# 11. Geografía

PostGIS.

El usuario busca por:

```text
lat/lng + radio
```

no solamente por `city='Puebla'`.

Ciudad/estado sirven para:

- SEO;
- filtros;
- analytics;
- presentación.

La distancia real usa geometría.

---

# 12. Catálogo

`catalog.items` es identidad estable.

Los nombres son atributos separados:

- canonical name;
- alias;
- abreviatura;
- provider alias;
- typo común;
- nombre histórico.

IDs externos (LOINC, etc.) son mappings.

Los conceptos pueden:

- merge;
- split;
- deprecate;
- redirect.

Nunca se destruye historia por corregir un concepto.

---

# 13. Oferta del proveedor

Un canonical item no es igual a una oferta comercial.

```text
Canonical:
Resonancia magnética de rodilla sin contraste

Offer Ruiz:
RM RODILLA SIMPLE
```

Un proveedor puede tener múltiples ofertas del mismo item.

---

# 14. Scope de oferta

Una oferta puede aplicar a:

```text
BRAND
MARKET
LOCATION
```

Esto permite herencia y excepciones.

---

# 15. Precio

Precio es una serie versionada, no `offers.price`.

Dimensiones:

- scope;
- price_type;
- channel;
- amount_minor;
- currency;
- valid_from/to;
- weekday rules;
- time windows;
- conditions;
- source observation;
- confidence;
- first_seen / last_seen.

Prioridad de resolución:

```text
LOCATION > MARKET > BRAND
```

Precios simultáneos válidos:

- regular;
- online;
- promo;
- member;
- cash;
- from.

El motor V1 incluye `supply.resolve_prices()`.

---

# 16. Historial

Si el precio no cambia:

```text
update last_seen_at
```

Si cambia:

```text
close old version
insert new current version
```

No se generan filas históricas redundantes por cada crawl.

---

# 17. Ingest / provenance

Regla:

> Ningún crawler publica directamente hechos canónicos sin evidencia.

Flujo:

```text
source
  ↓
endpoint
  ↓
crawl_run
  ↓
raw_document/raw_record
  ↓
source_observation
  ↓
normalization
  ↓
publish
```

Cada hecho debe poder rastrearse hasta evidencia.

---

# 18. Precedencia de fuentes

Orden conceptual:

1. proveedor verificado;
2. API/feed oficial;
3. sitio oficial;
4. gobierno;
5. directorio confiable;
6. reporte usuario/candidato manual.

Una fuente inferior no debe sobreescribir silenciosamente un dato verificado más confiable.

---

# 19. Seguridad de crawlers

Cada run registra:

- records_received;
- valid;
- rejected;
- published;
- previous_count;
- deviation;
- parser version;
- commit;
- errores.

Caso:

```text
ayer 1555
hoy 17
```

resultado:

```text
QUARANTINE
```

No delete masivo.

---

# 20. Normalización

Orden de resolución:

```text
exact
alias
provider alias
trigram
terminology
rules
embedding futuro
LLM último recurso
```

Cada intento genera:

- run;
- candidatos;
- scores;
- método;
- decisión;
- reviewer cuando aplique.

El feedback manual puede crear aliases aprobados.

---

# 21. OCR

Preferencia:

```text
on-device OCR
```

Cuando la imagen necesite procesamiento servidor:

```text
upload temporal R2
→ procesamiento
→ delete lifecycle
```

No persistir órdenes por defecto.

---

# 22. Seguridad y privacidad

Principios:

- secrets fuera de repositorio;
- service credentials nunca en Flutter;
- JWT + authorization server-side;
- documentos de proveedores en bucket privado;
- uploads médicos temporales;
- minimización de PII;
- analytics agregada para B2B;
- audit trail para acciones sensibles;
- separación `sensitive` para datos clínicos/personal identificable futuro.

---

# 23. Backups

Desde DEV:

```text
pg_dump
 ↓
compress/encrypt
 ↓
R2 backup bucket
```

Producción agrega backups nativos del proveedor conforme suba de plan.

Los backups deben estar separados de la base operativa.

---

# 24. API conceptual

Primeros endpoints:

```text
GET /api/v1/search
GET /api/v1/services/{id}
GET /api/v1/services/{id}/providers
GET /api/v1/providers/{id}
GET /api/v1/providers/{id}/services
```

Futuros:

```text
POST /provider/claims
POST /leads
POST /appointments
GET /provider/dashboard
```

El contrato API debe ocultar la implementación interna.

---

# 25. Analytics futuro

Eventos previstos:

- search;
- provider_impression;
- provider_view;
- compare;
- website_click;
- phone_click;
- whatsapp_click;
- lead;
- booking_start;
- booking_complete.

Los dashboards no consultarán eventos crudos masivos en tiempo real cuando crezca el sistema. Se usarán agregados diarios y, eventualmente, un almacén analítico.

---

# 26. Big Data readiness

No se implementa Big Data en MVP.

Camino futuro:

```text
Worker/events
    ↓
operational buffer
    ↓
R2 Parquet
    ↓
ClickHouse / BigQuery / equivalent
```

PostgreSQL conserva:

- current state;
- identities;
- transactions.

Warehouse/lake conserva:

- histórico masivo;
- eventos;
- tendencias;
- análisis pesado.

Kafka/Spark solo si existe evidencia operacional de necesidad.

---

# 27. Escalado geográfico

Nueva ciudad:

```text
crear/sincronizar geo
↓
DENUE / discovery
↓
match brands existentes
↓
crear locations nuevas
↓
ingest offers/prices
↓
normalizar
```

No se crea lógica especial por ciudad.

Nunca:

```text
if city == 'Puebla'
```

---

# 28. Otro dominio futuro

Ejemplo medicamentos:

```text
catalog.domain = medications
```

Añadir:

- ingredients;
- strengths;
- dosage forms;
- presentations;
- regulatory mappings;
- equivalence/interchangeability rules.

Reutilizar:

- provider brands;
- pharmacy locations;
- offers;
- prices;
- availability;
- sources;
- analytics.

Refacciones sigue el mismo principio con fitment/OEM/aftermarket.

---

# 29. No objetivos del MVP

No construir inicialmente:

- expediente clínico;
- diagnóstico IA;
- telemedicina;
- aseguradoras completas;
- pagos médicos complejos;
- marketplace nacional;
- almacenamiento permanente de órdenes;
- Kafka/Spark;
- warehouse;
- 20 ciudades;
- 100 crawlers;
- facturación B2B compleja.

---

# 30. Estado actual de arquitectura

**Aprobado:**

- stack;
- deployment model;
- multi-city model;
- reusable core;
- health module;
- price inheritance;
- provenance;
- crawler safety;
- normalización;
- privacy stance;
- Big Data evolution.

**Ya construido documentalmente/SQL:**

- DB V1 de 45 tablas;
- migraciones;
- seed;
- tests;
- documentación DB.

**Pendiente inmediato:**

- ejecutar DB V1 en Supabase DEV;
- corregir cualquier incompatibilidad real detectada por PostgreSQL/Supabase;
- crear repo/CI;
- iniciar collectors.

---

# Referencias internas

- `00_CONVERSACION_CANONICA.md`
- `02_FASES_IMPLEMENTACION.md`
- `PRUEVIA_DB_V1.zip`
- `DB_ARCHITECTURE_V1.md`
- `DB_TABLE_CATALOG_V1.md`

