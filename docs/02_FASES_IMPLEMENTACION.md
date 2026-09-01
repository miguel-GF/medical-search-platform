# Pruevia — Plan de implementación por fases

**Versión:** 1.0  
**Fecha:** 22 de agosto de 2026  
**Estado general:** fases 1–7 tienen implementación técnica verificada en Supabase DEV; Gate A de viabilidad es positivo con cobertura multi-proveedor y precios vigentes comprobados. Flutter queda deliberadamente después de este corte.

---

# Convención de estado

- ✅ Terminado / decisión cerrada
- 🟢 En curso / siguiente trabajo inmediato
- ⏳ Pendiente
- 🧪 Gate de validación
- 🚫 Deliberadamente fuera de alcance por ahora

---

# Fase -1 — Descubrimiento del problema

**Estado:** ✅

Objetivos completados:

- identificar problema real de estudios médicos;
- investigar fuentes públicas;
- revisar cadenas y procedimientos;
- validar que existen precios/catálogos recuperables;
- descubrir DENUE como fuente de proveedores pequeños;
- revisar competidores;
- descartar comparador simple como diferenciador suficiente;
- definir B2C + B2B;
- explorar monetización.

Resultado:

> Pruevia no será un simple comparador. Será un motor de interpretación/normalización + descubrimiento/comparación + marketplace/inteligencia de demanda futura.

---

# Fase 0 — Arquitectura de producto y software

**Estado:** ✅

Definido:

- Flutter Android/iOS/Web;
- Nuxt 3 SEO;
- Vue 3 + Element Plus admin/provider;
- Cloudflare Workers + TypeScript API;
- PostgreSQL/Supabase;
- Cloudflare R2;
- Python collectors;
- GitHub CI/CD;
- reusable core + health domain;
- Big-Data-ready/no Big-Data-now;
- dominio único + subdominios.

Entregable:

- `01_ARQUITECTURA_CANONICA.md`

---

# Fase 1 — Base de datos V1

**Estado:** ✅ migrada, seed aplicada y pruebas remotas verdes

## Ya realizado ✅

- modelo conceptual completo;
- separación por schemas;
- 45 tablas V1;
- migraciones PostgreSQL/Supabase;
- PostGIS;
- pg_trgm;
- provenance;
- RAW ingest;
- normalización;
- scope brand/market/location;
- precio versionado;
- función de resolución de precios;
- integridad para mercados/sucursales;
- package component cycle guard;
- audit/ops básicos;
- seeds;
- tests SQL;
- README y documentación.

Archivo:

- `PRUEVIA_DB_V1.zip`

## Falta ⏳

1. crear Supabase DEV;
2. ejecutar todas las migraciones desde cero;
3. ejecutar tests;
4. resolver incompatibilidades reales si aparecen;
5. repetir `db reset` hasta obtener ejecución limpia;
6. marcar tag Git `db-v1.0.0`.

## Criterio de salida 🧪

```text
fresh database
↓
all migrations
↓
seed
↓
tests
↓
0 errors
```

No avanzar con ingest masivo hasta tener esta fase verde.

---

# Fase 2 — Fundación de repositorio e infraestructura DEV

**Estado:** 🟢 base de repositorio y configuraciones DEV listas; despliegue Cloudflare queda condicionado a credenciales de la cuenta

## Entregables

Repositorio privado con:

```text
/apps/api
/apps/admin
/apps/provider
/apps/patient
/apps/web
/collectors
/database
/docs
/packages
```

Infra DEV:

- Cloudflare account/project;
- Worker DEV;
- R2 buckets DEV;
- Supabase DEV;
- GitHub secrets;
- CI/CD API;
- CI de migraciones/tests;
- backup automático inicial.

## Buckets previstos

```text
raw-dev
transient-dev
provider-docs-dev
backups-dev
```

## Criterio de salida 🧪

Un push a `develop` debe:

```text
lint
→ tests
→ build
→ deploy Worker DEV
```

Y la DB DEV debe poder reconstruirse por migraciones.

---

# Fase 3 — Collector DENUE / discovery de proveedores

**Estado:** ✅ adapter, CLI y corrida live verificados; 489 registros válidos en Puebla y publicados en la evidencia de ingest

Objetivo:

Crear el universo inicial de proveedores/sucursales en Puebla.

## Construir

- cliente DENUE;
- mapeo actividad económica;
- deduplicación inicial;
- `provider_external_ids`;
- `location_external_ids`;
- ingest RAW;
- observations;
- publisher controlado.

## Resultado esperado

```text
Puebla
→ providers/locations descubiertos
→ coordenadas
→ datos oficiales básicos
```

## Criterio de salida 🧪

- run reproducible;
- no duplicados obvios;
- provenance disponible;
- registros aparecen en admin/raw.

---

# Fase 4 — Collectors de proveedores reales

**Estado:** ✅ Chopo, Ruiz y Salud Digna ejecutados en vivo, publicados y repetibles

La implementación mantiene Chopo y Ruiz publicados y añade el adapter dedicado
de Salud Digna (`salud_digna_puebla`), con CLI, fixtures, deduplicación de filas
idénticas y pruebas. La corrida live canónica produjo 830 registros válidos,
0 rechazados y 4,150 observaciones; se publicó en `ingest` y en el catálogo
revisado de Supabase DEV. Los artefactos no crean equivalencias clínicas
automáticas: los labels no exactos permanecen en la cola de normalización.

Orden recomendado:

1. Chopo;
2. Ruiz;
3. Salud Digna;
4. MAC u otros proveedores según cobertura.

Cada adapter debe implementar conceptualmente:

```text
discover()
fetch()
parse()
validate()
observe()
publish_candidate()
```

## Crawler safety obligatorio

Si el volumen cae por encima del umbral:

```text
QUARANTINE
```

No publicar deletes.

## Criterio de salida 🧪

Para cada fuente:

- catálogo recuperado;
- URLs/evidencia;
- precios cuando existan;
- branches/markets;
- `first_seen_at` / `last_seen_at`;
- repeat run idempotente.

---

# Fase 5 — Normalization Engine V1

**Estado:** ✅ catálogo dorado y decisiones conservadoras publicados

Orden:

```text
normalized text
→ exact
→ aliases
→ provider aliases
→ pg_trgm
→ terminology
→ rules
→ manual review
```

IA todavía no es requisito principal.

## Construir

- servicio de normalización;
- scoring;
- candidatos;
- decisiones;
- alias creation workflow;
- ambigüedad explícita.

## Conjunto inicial de prueba

100–200 estudios/procedimientos reales y variados:

- laboratorio;
- imagen;
- neurología;
- cardiología;
- otros especializados.

## Criterio de salida 🧪

Medir:

- exact/high confidence rate;
- manual review rate;
- ambiguous rate;
- false match rate.

No aceptar falsos equivalentes médicos por presión de cobertura.

---

# Fase 6 — Admin interno V1

**Estado:** ✅ Admin V1 operativo y probado; las diez vistas operativas están disponibles y protegidas por Supabase Auth

Tecnología:

```text
Vue 3 + TypeScript + Element Plus
```

Pantallas mínimas:

1. dashboard técnico;
2. providers;
3. locations;
4. offers;
5. prices;
6. crawl runs;
7. raw evidence;
8. normalization queue;
9. data quality issues;
10. alerts.

## Criterio de salida 🧪

Un operador debe poder:

- revisar un mapping;
- corregirlo;
- aprobar alias;
- ver fuente;
- detectar crawler fallido;
- revisar precio y evidencia;

sin tocar SQL manualmente.

---

# Fase 7 — Search API V1

**Estado:** ✅ Search API V1, RPCs y pruebas de contrato verdes

Endpoints iniciales:

```text
GET /api/v1/search
POST /api/v1/resolve
GET /api/v1/services/{id}
GET /api/v1/services/{id}/providers
GET /api/v1/providers/{id}
GET /api/v1/providers/{id}/services
```

`POST /api/v1/resolve` recibe `{ "text": "..." }` y devuelve el estado
determinista (`resolved`, `ambiguous` o `no_match`), la explicación de cada
candidato y sus ofertas/precios. Las variantes ambiguas se conservan separadas
para que el paciente pueda confirmar la composición indicada.

## Primer milestone técnico 🧪

Request:

```text
/search?q=electromiografia+pierrnas&lat=...&lng=...
```

Response:

- canonical service;
- confidence;
- providers;
- branch;
- distance;
- price(s);
- source/freshness;
- contact URL.

Todo con información real de Puebla.

---

# Gate A — Viabilidad del Data Engine

**Estado:** ✅ Gate A positivo: 44 servicios compartidos, 44 compartidos con precio, 16/16 ubicaciones con coordenadas y 0 corridas fallidas/cuarentenadas

Antes de Flutter completo, evaluar:

- cobertura real;
- 2+/3+ proveedores por servicio;
- precios vigentes;
- zero-result rate;
- precisión de normalización;
- frecuencia de rotura de fuentes;
- costo operacional.

### Continuar si

El sistema resuelve de forma útil una masa suficiente de búsquedas reales.

### Detener/replantear si

La cobertura depende demasiado de trabajo manual o los mappings son clínicamente inseguros.

---

# Fase 8 — Patient MVP: Flutter Web

**Estado:** ⏳

Primero web para validar sin esperar tiendas.

URL futura:

```text
app.marca.com
```

Pantallas:

1. inicio;
2. texto de búsqueda;
3. resultados normalizados;
4. providers;
5. compare;
6. provider detail;
7. map;
8. website/phone/WhatsApp.

No login obligatorio para la búsqueda básica.

## Criterio de salida 🧪

Una persona externa debe resolver una búsqueda sin ayuda del equipo.

---

# Fase 9 — OCR / orden médica

**Estado:** ✅ extractor integrado en API; falta conectar la pantalla Flutter.

Después de estabilizar texto.

Flow:

```text
camera/file
→ OCR local cuando sea posible
→ extracted text
→ normalization
→ detected items
```

Fallback visual/IA solo cuando sea necesario. La ruta
`POST /api/v1/resolve-image` usa primero el extractor local FastAPI de
`apps/ocr-service/` si `OCR_SERVICE_URL` existe y, en su defecto, el binding
opcional de Workers AI; si no existe ningún extractor, falla cerrado con
`503`. El texto extraído siempre pasa por `resolve-batch`, por lo que el
modelo no publica alias ni selecciona estudios. En imagen se consulta ademas
`api_resolve_ocr_package`: sus reglas aprobadas conservan el texto original,
proponen correcciones observadas (por ejemplo `OBH -> BH`) y dejan los paneles
ambiguos para confirmacion. Ningun extractor persiste
imágenes ni decide equivalencias.

El formateador OCR descarta metadatos frecuentes en español e inglés (nombre,
identificadores, teléfonos, domicilio, hospital y narrativa de informes) y
recorta sufijos de institución fusionados a una línea de estudio. Los casos
externos de estrés se documentan en `docs/OCR_PUBLIC_CORPUS.md`; no se copian
imágenes al repositorio.

## Criterio de salida 🧪

- detectar varios estudios;
- marcar ambigüedades;
- no almacenar permanentemente imagen por defecto.

---

# Fase 10 — Optimización multi-estudio

**Estado:** ✅ implementada en el Data Engine; Flutter queda pendiente.

Resolver una orden completa.

Opciones:

- menor costo;
- menos establecimientos;
- más cercano;
- todo en uno;
- balance costo/distancia.

El endpoint `POST /api/v1/resolve-batch` resuelve cada entrada de forma
independiente y el solver determinista calcula cobertura por sucursal. Intenta
una ubicación única primero y combinaciones de hasta tres cuando es necesario;
las ambigüedades y los estudios faltantes se mantienen explícitos. El detalle
operativo y las pruebas están en el corte de implementación al final de este
documento.

---

# Fase 11 — Web pública SEO

**Estado:** ⏳

Tecnología:

```text
Nuxt 3
```

Crear páginas únicamente cuando tengan valor real.

Tipos:

- servicio + ciudad;
- servicio general;
- provider;
- location.

## Criterio de salida 🧪

- HTML indexable;
- sitemap;
- canonical URLs;
- metadata;
- velocidad;
- CTA a Flutter Web.

No crear SEO programático vacío.

---

# Fase 12 — Provider Claim / Verification

**Estado:** ⏳

Construir:

- memberships;
- claims;
- verification workflow;
- provider documents;
- roles brand/region/location.

Perfil gratuito puede:

- corregir información;
- publicar catálogo;
- precios;
- horarios;
- contacto;
- availability básica.

## Criterio de salida 🧪

Primer proveedor externo reclama su perfil y actualiza datos sin intervención SQL.

---

# Fase 13 — Analytics B2B V1

**Estado:** ⏳

Agregar eventos:

- search;
- impression;
- provider_view;
- click;
- WhatsApp;
- phone;
- compare.

Tablas previstas:

- search requests;
- search items;
- impressions;
- engagement events;
- daily provider metrics;
- daily demand metrics.

## Dashboard provider

Mostrar:

- impresiones;
- visitas;
- contactos;
- demanda por servicio;
- servicios buscados no publicados;
- posición de precios cuando sea confiable.

## Criterio de salida 🧪

Poder decir a un proveedor con datos reales:

> “X personas buscaron esto alrededor de tu sucursal y tú no apareces.”

---

# Fase 14 — Leads

**Estado:** ⏳

Introducir flujo atribuible:

```text
usuario
→ solicitar contacto
→ lead_id
→ provider
```

Separar PII de entidad operativa.

Consentimiento y retention definidos.

---

## Estado ejecutado antes de Flutter (27 de agosto de 2026)

Las fases previas a Flutter tienen implementación técnica en DEV: base Supabase enlazada con migraciones 001-113; collectors Chopo, Ruiz, Salud Digna y DENUE con RAW/observaciones/runs reproducibles; catálogo dorado de 175 servicios, 219 ofertas y 41 equivalencias Chopo↔Ruiz revisadas explícitamente; Admin V1 en `apps/admin` con Supabase Auth y búsqueda de servicios canónicos; Search API V1 en `apps/api`; y pruebas remotas de base, API y Gate A con todas las aserciones verdes. La viabilidad queda cerrada en este corte: 44 servicios tienen dos proveedores y 44 tienen precio vigente en ambos; Flutter no se inicia dentro de esta fase.

## Corte Gate B y lote comercial (28 de agosto de 2026)

Se ejecutó una recolección acotada de Puebla y se cargó primero en `ingest`:

- 489 establecimientos DENUE para evidencia de identidad y ubicación;
- 15 sucursales Ruiz y 143 estudios con precios;
- 30 estudios Chopo;
- 1 sucursal Salud Digna y 829 estudios con precios.

La normalización publicó únicamente 7 mapeos clínicos revisados (BH, EGO,
glucosa, creatinina y TSH). Las etiquetas restantes, incluido `PERFIL
TIROIDEO EN SUERO`, no se equiparan automáticamente a un panel básico o
ampliado: permanecen en la cola para revisión de composición. DENUE tampoco
verifica por sí solo que un proveedor realice un estudio; su uso correcto en
claims es aportar evidencia independiente de identidad, razón social y
ubicación.

---

### Clasificacion del lote DENUE

El clasificador reproducible `database/scripts/classify_denue_candidates.py`
se ejecuto contra el run `49e31077-8cbc-438a-9d08-eccad850f30e` y genero
`database/fixtures/denue_candidates_puebla_v1.json`:

- 489 registros de entrada;
- 214 registros con actividad de laboratorio medico y diagnostico;
- 213 candidatos fisicos despues de deduplicar identidad legal + coordenadas;
- 27 registros clinicos relacionados en cola de revision;
- 248 registros excluidos por actividad no diagnostica;
- 10 coincidencias explicitas Chopo, 5 Salud Digna y 1 Ruiz;
- 4 posibles Ruiz por abreviatura `L.R.` quedan con `review_required`.

El fixture es una lista de candidatos y evidencia, no una publicacion en
`core.provider_locations`: antes de crear una sede canonica se debe confirmar
la identidad y la oferta con una fuente del proveedor.

El cruce de este fixture contra las corridas comerciales de Ruiz, Chopo y
Salud Digna produjo 0 enlaces automÃ¡ticos, 20 sedes en revisiÃ³n y 193 sin
marca conocida. Las cuatro sedes `L.R.` de Ruiz tienen proximidad y nombre de
sucursal compatibles, pero la abreviatura no es suficiente para publicarlas;
Chopo no aportÃ³ un artefacto de sucursales en esa corrida y Salud Digna sÃ³lo
aportÃ³ una sede que no coincide geogrÃ¡ficamente con las cinco filas DENUE.

---

# Fase 14.1 — Discovery genérico de proveedores pequeños

**Estado:** ✅ implementación técnica y primer lote de publicación revisado;
la ampliación de cobertura continúa antes de Flutter.

El collector genérico opera por dominio, no por marca: respeta `robots.txt`,
sigue enlaces internos con presupuesto acotado, extrae JSON-LD y patrones de precio/servicio, y
publica únicamente evidencia RAW en `ingest`. Los nombres y precios quedan
como candidatos; la normalización clínica sigue siendo determinista y separada.
Un proveedor que reclame su perfil podrá aportar mejores URLs o contratar un
adapter dedicado en una iteración posterior, sin convertirlo en requisito de
entrada.

**Corte de cobertura Puebla (28 de agosto de 2026):** 48 hosts directos de
DENUE quedaron agrupados en 47 sitios apex/www; 63 páginas respondieron y se
obtuvieron 54 evidencias candidatas (48 servicios sin precio y 6 ubicaciones).
Los fallos se separan por DNS, HTTP, redirección, robots o contenido vacío.
La primera corrida ruidosa (107 registros) permanece en RAW histórico y fue
marcada `quarantined`; solo la corrida endurecida se cargó a `ingest`.

En la iteración siguiente se aprobaron sólo cuatro coincidencias exactas:
`Examen general de orina`, `Mastografía`, `Ultrasonido abdomen completo` y
`Ultrasonido obstétrico`. Se crearon cuatro marcas con estado
`verification_pending`, siete sedes sustentadas por DENUE y cuatro ofertas
activas con `requires_quote=true`; al no existir precios explícitos confiables,
la API devuelve precio nulo y conserva el enlace público del proveedor. Los
44 registros de servicio restantes siguen como candidatos para revisión; no se
aprobó ningún panel, modalidad amplia ni similitud fuzzy.

El retry posterior cubrió los 11 hosts vacíos o transitorios (20 páginas, 0
nuevas evidencias). Los 26 hosts restantes no se reintentaron porque el
manifiesto los clasificó como robots, DNS no resoluble, redirección o HTTP
permanente; así se evita convertir una política de acceso o un dominio muerto
en ruido operacional.

---

# Fase 15 — Reservas

**Estado:** ⏳

Crear:

- appointments;
- status history;
- idempotency;
- attribution;
- external booking references;
- webhooks futuros.

## Criterio de salida 🧪

Una reserva creada desde Pruevia puede atribuirse de extremo a extremo.

---

# Fase 16 — PRO beta

**Estado:** ⏳

Primeros proveedores:

```text
Founding Provider
PRO gratuito temporal
```

Objetivo:

- demostrar valor;
- obtener feedback;
- medir demanda;
- validar disposición de pago.

No cobrar antes de que el proveedor vea actividad suficiente.

---

# Fase 17 — Monetización

**Estado:** ⏳

Opciones a validar, no asumir:

### SaaS PRO

- analytics;
- demanda;
- opportunities;
- reservations;
- multi-location;
- herramientas.

### Performance

Lead/reserva atribuible bajo modelo jurídico/comercial validado.

### Sponsored

Claramente etiquetado.

El ranking orgánico no se corrompe por pago.

### Enterprise futuro

- API;
- aseguradoras;
- empresas;
- redes médicas;
- intelligence.

---

# Fase 18 — Android / iOS stores

**Estado:** ⏳

Una vez validado Flutter Web:

- Android;
- iOS;
- deep links;
- universal/app links;
- store compliance.

Mismo codebase paciente.

---

# Fase 19 — Expansión geográfica

**Estado:** ⏳

Orden tentativo después de Puebla según datos/mercado:

- Querétaro;
- CDMX;
- Guadalajara;
- Monterrey;
- otras.

No se crea código especial por ciudad.

Proceso:

```text
geo
→ DENUE/discovery
→ provider matching
→ locations
→ collectors
→ normalize
→ publish
```

---

# Fase 20 — Big Data / Data Platform

**Estado:** 🚫 no ahora / preparado

Trigger para evaluarla:

- 100M+ eventos;
- Postgres presionado por analytics;
- TBs de histórico;
- enterprise analytics;
- necesidad de near-real-time.

Camino posible:

```text
events
→ R2 Parquet
→ ClickHouse / BigQuery
```

Solo introducir streaming/Kafka/Spark si las métricas operativas lo justifican.

---

# Orden inmediato de trabajo desde HOY

## Paso 1 — Supabase DEV

Crear proyecto y aplicar `PRUEVIA_DB_V1`.

## Paso 2 — Validar DB

```text
migrate
seed
test
reset
test
```

## Paso 3 — GitHub monorepo

Subir DB como primera pieza versionada.

## Paso 4 — Cloudflare DEV + R2

Preparar API mínima y buckets.

## Paso 5 — DENUE

Primer collector real.

## Paso 6 — Chopo Puebla

Primer proveedor comercial con catálogo/precios.

## Paso 7 — Ruiz Puebla

Segundo proveedor; validar reglas más complejas.

## Paso 8 — Admin mínimo

Visualizar RAW/normalized/crawls.

## Paso 9 — Search API

Primer `/search` real.

---

# Estado del proyecto al 26/08/2026

| Componente | Estado |
|---|---|
| Idea/problema | ✅ |
| Investigación de mercado | ✅ inicial fuerte |
| Monetización conceptual | ✅ |
| Arquitectura de software | ✅ |
| Arquitectura DB | ✅ |
| **DB V1 SQL** | **✅ migrada y verificada en DEV** |
| Supabase DEV | ✅ |
| Cloudflare DEV | 🟢 configuración lista; deploy requiere credenciales |
| GitHub monorepo | ✅ CI versionado |
| DENUE collector | ✅ live publicado; 489 registros válidos |
| Chopo collector | ✅ live publicado |
| Ruiz collector | ✅ live publicado |
| Salud Digna collector | ✅ live publicado; 830 registros válidos |
| Admin | ✅ V1 operativo; diez vistas y Supabase Auth |
| API Search | ✅ V1 probado |
| Flutter Web | ⏳ |
| OCR | ✅ extractor API + correcciones OCR auditables; Flutter pendiente |
| Nuxt SEO | ⏳ |
| Provider portal | ⏳ |
| Analytics B2B | ⏳ |
| Marketplace | ⏳ |
| PRO/Billing | ⏳ |
| Big Data | 🚫 futuro |

---

# Definition of Done del primer MVP técnico

Pruevia V0 técnica se considera funcional cuando:

1. DB se reconstruye completamente por migraciones;
2. DENUE + mínimo 2 proveedores comerciales ingieren correctamente (DENUE, Chopo, Ruiz y Salud Digna están publicados);
3. RAW → observation → canonical funciona;
4. 100–200 estudios seleccionados están normalizados;
5. `/search` devuelve proveedores reales;
6. precio incluye fuente y frescura;
7. ubicación usa PostGIS;
8. admin permite corregir mappings;
9. crawler roto entra a quarantine;
10. todo está versionado y reproducible.

Solo entonces se acelera la construcción del producto paciente.

---

# Fase 14.2 - Integracion LOINC y resolver unificado

**Estado:** ✅ resolver unificado desplegado; release oficial LOINC 2.83
descargada/verificada y ocho mappings exactos publicados en DEV. El índice
local conserva 64,776 términos de laboratorio y la publicación exige
`verified=true` y `approved_at`; la prueba de integración remota cubre 16
aserciones.

Antes de Flutter, el motor debe usar una sola ruta de resolucion para
`/search` y `/resolve`. La migracion `095_unified_clinical_resolver.sql`
introduce `clinical-resolver-v6` y conserva los contratos publicos existentes.

La integracion LOINC se ejecuta por etapas:

1. descargar y verificar una release oficial fuera de Git;
2. construir un indice local compacto para candidatos;
3. mapear manualmente los servicios canonicos de mayor uso;
4. guardar codigo, version, atributos y evidencia;
5. publicar solo mappings revisados;
6. medir paridad, precision y abstencion antes de ampliar cobertura.

El catalogo LOINC completo no se sube a Supabase en esta fase. Los detalles
operativos estan en `docs/LOINC_INTEGRACION.md`.

---

## Corte benchmark y endurecimiento del resolver (29 de agosto de 2026)

Se construyó `resolver-benchmark-v1` con 200 consultas derivadas de las
recetas/OCR de aceptación, pruebas Gate B, catálogos oficiales de Puebla,
discovery genérico y mappings LOINC. El corpus contiene 147 variantes seguras
y 53 casos que deben abstenerse (paneles, entradas incompletas, irrelevantes o
adversariales).

La migración `20260829110000_101_resolver_benchmark_hardening.sql` añade
aliases conservadores y dominancia exacta; `102` bloquea contradicciones como
`T3 libre` y `103` publica atributos de modalidad/contraste para imagenología.
La prueba remota `tests/resolver_benchmark_test.sql` pasa las 10 aserciones:
200/200 casos conformes, 147/147 variantes seguras con su item canónico y
0 falsos positivos en los 15 negativos. Los paneles y consultas sin alcance
clínico no se fuerzan a una respuesta.

El siguiente gate es medir este corpus con consultas reales de usuarios y
ampliarlo únicamente cuando exista evidencia de cobertura; no se introduce
una base vectorial ni una interpretación automática por IA en esta etapa.

---

# Corte de campo: consultas públicas y benchmark v2 (29 de agosto de 2026)

Se revisaron hilos públicos de Reddit como fuente de descubrimiento de
lenguaje, sin conservar PII ni contexto clínico. El inventario anonimizado
(`database/fixtures/public_query_research_v1.json`) contiene 64 frases con
intenciones de estudio, panel, precio, ubicación, preparación y cobertura.
Los foros no son autoridad clínica y no publican alias automáticamente.

El corpus `resolver-benchmark-v2` añade 200 consultas nuevas frente a v1:
184 variantes seguras de estudios no cubiertos (densitometría, audiometría,
espirometría, cardiología, COVID, ultrasonido, resonancia, tomografía,
radiografía y colposcopia) y 16 casos que deben abstenerse. La prueba remota
`tests/resolver_benchmark_v2_test.sql` pasa 10/10 aserciones, incluyendo
184/184 resoluciones al `item_id` esperado y 16/16 abstenciones.

Las migraciones `104_field_benchmark_constraints.sql`,
`105_field_benchmark_guard_scope.sql` y `106_field_benchmark_aliases.sql`
completan contraste estructurado de las tomografías, corrigen la frontera
entre familias amplias y paneles explícitos, y publican sólo aliases semánticos
conservadores.
El siguiente paso pre-Flutter es habilitar una página de prueba del endpoint
con consentimiento y telemetría mínima; la tabla de analytics y su retención
se implementarán antes de registrar consultas de usuarios reales.

## Corte de implementacion Fase 10 - Resolucion de multiples estudios (29 de agosto de 2026)

**Estado:** implementada en el Data Engine; pendiente la integracion visual en
Flutter.

La ruta `POST /api/v1/resolve-batch` acepta una receta como texto (renglones,
numeracion o separadores seguros) o una lista explicita de hasta 30 estudios.
Cada entrada se resuelve de forma independiente con `clinical-resolver-v6`:
`resolved`, `ambiguous` y `no_match` son estados explicitos. Un panel amplio o
una variante incompleta no se convierte en una equivalencia por similitud.

Cuando todas las entradas estan resueltas, el motor cruza sus ofertas con
sucursales concretas y devuelve soluciones ordenadas. `all_in_one` es el
objetivo por defecto: primero intenta una sola sucursal, despues combinaciones
de dos o tres, y siempre lista los estudios faltantes. Tambien soporta
`lowest_cost`, `nearest` y `balanced`; los precios desconocidos quedan como
`requires_quote` y no se suman como si fueran cero.

Las entradas de texto y las líneas OCR separan conjunciones explícitas (`e` y
`y`) únicamente cuando ambos fragmentos parecen estudios conocidos. La
separación conserva los tokens originales para que cada uno pase por el mismo
resolver y pueda quedar en `resolved`, `ambiguous` o `no_match` de forma
independiente.

Las migraciones `20260829150000_107_package_resolution.sql` y
`20260829151000_108_package_rpc_guard.sql` agregan el RPC publico
`api_resolve_package` y su limite de 30 entradas incluso en llamadas directas.
Las migraciones `20260829160000_109_ocr_correction_rules.sql`,
`20260829161000_110_ocr_correction_domain_guard.sql` y
`20260829162000_111_ocr_correction_response_shape.sql` agregan el RPC
`api_resolve_ocr_package`. Este aplica solo reglas OCR aprobadas dentro de
`health_diagnostics`, conserva el texto crudo y nunca resuelve paneles
ambiguos por su cuenta.
Las migraciones `20260829170000_112_resolution_confidence_guard.sql` y
`20260829171000_113_package_guard_offer_filter.sql` cierran el caso de fuzzy
debil: una similitud menor a `0.75` queda como sugerencia con confirmacion y
no puede aportar ofertas a una solucion.
La migracion `20260829172000_114_resolution_guard_ambiguity_preservation.sql`
conserva el estado ambiguo cuando existe una alternativa debil; nunca lo
degrada a resuelto por descartar esa alternativa.
La migracion `20260830100000_115_ocr_confirmed_glucose_insulin.sql` agrega la
transcripcion humana revisada `GlurOsO e INUliUA -> Glucosa e Insulina`. Se
conserva como sugerencia auditable y se resuelve por tokens independientes.
La migracion 117 cierra el hueco de catalogo de `Insulina` con el concepto
serico/plasmatico LOINC 20448-7; no infiere condicion basal, desafio,
anticuerpos ni cobertura de proveedor.
La migracion `20260830101000_116_ocr_confirmed_glucose_insulin_tokens.sql`
publica las variantes OCR de cada token despues de separar la conjuncion:
`GlurOsO -> Glucosa` e `INUliUA -> Insulina`. Ambas resuelven clinicamente de
forma independiente; la cobertura comercial de Insulina puede seguir vacia.
SQL se limita a resolver conceptos y expandir alcances
de proveedor (marca/mercado/sucursal); la seleccion de cobertura es un solver
determinista en `apps/api/src/batch.ts`. No se almacena la receta permanente ni
se usa una IA para inventar equivalencias.

La prueba `database/supabase/tests/resolver_package_test.sql` verifica listas
arbitrarias, cobertura de una sucursal, precios ausentes y la receta de cuatro
entradas (`B H`, `Q S completa`, `EGO`, `perfil toroideo`): dos se resuelven y
dos solicitan aclaracion, sin producir un paquete falso.

# Corte de cobertura real — 31 de agosto de 2026

Se agregaron mappings exactos y evidencia oficial para Insulina, Glucosa,
Biometria hematica y EGO en Chopo, además de Insulina y EGO en Asesores. Las
ofertas de Asesores conservan `requires_quote=true` porque el sitio no garantiza
vigencia de sus precios especiales. Perfil tiroideo, HbA1c y QS45 de Chopo
permanecen en revisión por falta de composición/concepto canónico aprobado.
La corrida y las URLs están en `docs/COBERTURA_REAL_20260831.md`.

# Referencias

- `00_CONVERSACION_CANONICA.md`
- `01_ARQUITECTURA_CANONICA.md`
- `PRUEVIA_DB_V1.zip`
- `DB_ARCHITECTURE_V1.md`
- `DB_TABLE_CATALOG_V1.md`
