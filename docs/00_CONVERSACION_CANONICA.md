# Pruevia — Conversación canónica del proyecto

**Fecha de consolidación:** 22 de agosto de 2026  
**Estado:** referencia canónica de decisiones, hipótesis, investigación y arquitectura discutidas en esta conversación.  
**Nombre del producto:** `Pruevia` se utiliza como nombre provisional; el naming definitivo sigue pendiente.

> Nota: este documento no pretende ser una exportación byte-a-byte de la interfaz de ChatGPT. Es una reconstrucción cronológica canónica de **todo el contenido sustantivo** de la conversación: preguntas, decisiones, hallazgos, alternativas descartadas y acuerdos técnicos. Cuando existan archivos ejecutables o documentación más específica, esos archivos prevalecen para el detalle técnico.

---

## 1. Punto de partida: buscar una app simple, usable y vendible

El proyecto empezó con la intención de encontrar una aplicación que pudiera construirse relativamente rápido, que resolviera una necesidad real y que tuviera posibilidad de generar ingresos con el tiempo. La idea principal era aprovechar APIs, SDKs o fuentes de datos ya existentes y darles un “punch”: convertir capacidades técnicas existentes en una experiencia fácil de usar y con valor evidente para el usuario.

Se exploraron varias direcciones:

- foto → acción;
- garantías y compras;
- tickets/gastos e inflación personal;
- inventario simple;
- cotizaciones rápidas;
- CRM para WhatsApp;
- documentos inteligentes;
- comparadores de servicios.

La app de cotizaciones ya estaba iniciada por el usuario, por lo que se decidió no centrar el nuevo proyecto en esa idea. También se concluyó que **la IA no debe ser el producto**, sino una herramienta que acelera o resuelve una parte concreta del flujo.

---

## 2. Aparece el problema de estudios médicos

El usuario señaló un dolor muy concreto vivido personalmente: cuando un médico pide un estudio, el nombre puede variar entre médicos, clínicas y laboratorios. Además:

- los médicos usan abreviaturas o escriben difícil de leer;
- las clínicas nombran el mismo estudio de formas distintas;
- las páginas son lentas o poco claras;
- los precios son difíciles de encontrar;
- muchas veces hay que llamar o preguntar por WhatsApp;
- no existe una experiencia unificada para comparar precio, ubicación y disponibilidad.

El ejemplo que se volvió representativo fue:

> “Electromiografía de extremidades inferiores”

que puede aparecer en distintos sitios como:

- EMG MI;
- EMG MMII;
- electromiografía de miembros inferiores;
- electromiografía bilateral de piernas;
- nombres parecidos que **no siempre son exactamente equivalentes**, por ejemplo electromiografía vs electromiografía + velocidades de conducción nerviosa.

A partir de ahí el producto dejó de ser “un comparador de laboratorios” y comenzó a definirse como:

> **“No necesitas saber cómo se llama el estudio. Dame la orden y yo resuelvo el resto.”**

---

## 3. Primera visión del producto

El flujo ideal para paciente quedó definido conceptualmente así:

```text
Foto de orden / texto escrito
        ↓
OCR / lectura
        ↓
normalización médica
        ↓
identificación de uno o varios estudios
        ↓
proveedores que los realizan
        ↓
precio + ubicación + disponibilidad + preparación
        ↓
comparación
        ↓
contacto / reserva / enlace externo
```

La experiencia debe funcionar también cuando la orden contiene varios estudios:

```text
BH
QS 27
TSH
T4L
EGO
USG abdominal
EMG MMII
```

La app debería poder responder:

- qué estudios detectó;
- cuáles son coincidencias seguras;
- cuáles son ambiguas y requieren confirmación;
- dónde realizar todo;
- qué combinación minimiza costo;
- qué combinación minimiza traslados;
- qué proveedor permite hacer todo en un solo lugar.

Se dejó claro que Pruevia **no diagnostica**, no prescribe y no sustituye al médico. La normalización sirve para localizar el servicio solicitado.

---

## 4. Investigación de fuentes y datos existentes

Se investigó si el proyecto podría arrancar con datos reales sin esperar que los usuarios llenen la base.

Hallazgos importantes:

### 4.1 Chopo

Se encontró que Chopo publica catálogos amplios por región, con precios normales y online. En Puebla había alrededor de 1,500+ resultados en el catálogo. Además de laboratorio, aparecen categorías como:

- rayos X;
- tomografía;
- resonancia;
- ultrasonido;
- cardiología;
- otros estudios diagnósticos.

Se confirmó que los precios pueden variar según región, por lo que el modelo de datos debe considerar:

```text
servicio + proveedor + mercado/sucursal + precio + fecha
```

no solamente `servicio + precio`.

### 4.2 Laboratorios Ruiz

Inicialmente parecía que los precios requerían llamada, pero después se comprobó que Ruiz sí publica páginas individuales con:

- precio de lista;
- precio promocional/beneficio;
- indicaciones;
- necesidad de cita;
- sucursales disponibles.

También aparecieron reglas de precio por horario, por ejemplo tomografías más baratas después de cierta hora. Esto llevó a una decisión de arquitectura clave: **los precios deben poder tener condiciones de horario, canal, día y vigencia**.

### 4.3 Salud Digna

Se confirmó cobertura relevante en Puebla y servicios como:

- laboratorio;
- resonancia;
- tomografía;
- ultrasonido;
- rayos X;
- densitometría;
- mastografía;
- ECG.

La obtención automática de precios parece requerir mayor ingeniería porque parte de la información depende de ciudad/sucursal y flujo dinámico.

### 4.4 Hospitales MAC

Se encontraron listas públicas de precios por hospital/ciudad. Esto fue particularmente útil porque permitió encontrar procedimientos más especializados, incluido el ejemplo original de electromiografía de miembros inferiores. Se detectó también el problema de vigencia de los tarifarios, por lo que la base debe registrar:

- fuente;
- fecha de observación;
- vigencia;
- `last_seen_at`;
- estado de frescura del dato.

### 4.5 LAPI / OLAB / otros

Se investigaron otras cadenas, pero se observó que no todas tienen presencia en Puebla. Esto llevó a no confundir “cadenas nacionales” con “proveedores útiles para el piloto local”.

### 4.6 LOINC

Se encontró LOINC como estándar útil para normalizar pruebas y observaciones clínicas, incluyendo disponibilidad de terminología en español y mapeos relevantes. La decisión fue:

- usar LOINC cuando aplique;
- no forzarlo para todo;
- mantener IDs internos estables;
- tratar terminologías externas como mappings, no como PK del sistema.

### 4.7 DENUE / INEGI

Se encontró una pieza especialmente importante para descubrir proveedores pequeños: la API DENUE de INEGI.

Esto permite sembrar una base inicial de establecimientos con datos como:

- nombre;
- actividad;
- dirección;
- teléfono;
- coordenadas;
- sitio web;
- tamaño aproximado.

Esto evita depender únicamente de cadenas grandes y permite que una clínica pequeña exista en Pruevia incluso antes de registrarse.

---

## 5. Competencia y validación del mercado

Se buscaron soluciones existentes y se encontraron varias piezas parciales:

- comparadores de laboratorios;
- plataformas que permiten subir receta a un proveedor concreto;
- marketplaces internacionales de procedimientos médicos;
- Doctoralia/Zocdoc como ejemplos de adquisición de pacientes y agenda;
- plataformas de comparación de estudios en México.

La conclusión fue importante:

> **El comparador simple ya existe y no sería suficiente diferenciación.**

El hueco de Pruevia quedó definido como la combinación de:

1. interpretación de orden;
2. normalización de nombres;
3. múltiples estudios en una orden;
4. comparación multi-proveedor;
5. proveedores grandes + pequeños;
6. ubicación y precios por sucursal;
7. posibilidad de contacto/reserva;
8. inteligencia de demanda para proveedores.

No se encontró un producto mexicano que, según la investigación realizada, uniera públicamente todo ese flujo de extremo a extremo.

---

## 6. Monetización: primera duda importante

El usuario planteó correctamente que si Pruevia simplemente toma precios públicos y manda al paciente mediante un link al sitio de Salud Digna, Chopo o Ruiz, **no hay una razón clara para que esos proveedores paguen**.

Esto llevó a separar cuatro niveles de atribución:

### Nivel 1 — enlace externo

```text
Usuario → click → sitio del proveedor
```

Pruevia sabe que hubo click, pero no sabe si hubo compra/reserva.

No se debe cobrar como “reserva generada” porque no puede demostrarse.

### Nivel 2 — contacto generado dentro de Pruevia

El usuario solicita contacto, llamada o WhatsApp desde un flujo atribuible.

Se puede considerar un lead, aunque no necesariamente una venta.

### Nivel 3 — reserva interna

Pruevia crea la reserva:

```text
servicio + proveedor + fecha/hora + reservation_id
```

Aquí sí existe atribución clara.

### Nivel 4 — integración externa

Un proveedor puede recibir un `ref` o conectarse por API/webhook para informar que la reserva se confirmó.

Esto permite atribución completa.

---

## 7. La verdadera propuesta B2B

La monetización se volvió mucho más clara cuando el usuario propuso algo como:

> “Este mes la búsqueda más recurrente fue X. Tú no lo tienes publicado. ¿Lo realizas?”

Ese concepto se convirtió en una de las partes más fuertes del producto B2B.

Ejemplo de dashboard de una clínica:

```text
Últimos 30 días

Tu clínica apareció:          1,284 veces
Perfil abierto:                 263
Contactos:                       47
Reservas:                        18
```

Y, sobre todo:

```text
OPORTUNIDAD

Holter 24 horas
238 búsquedas cerca de tu sucursal
Solo 4 proveedores con precio publicado

No aparece en tu catálogo.
¿Lo realizas?
[Agregar]
```

El proveedor PRO no paga “por aparecer”.

La propuesta quedó:

> **Gratis te ayudamos a que te encuentren. PRO te ayuda a convertir esas búsquedas en pacientes y te dice qué demanda estás perdiendo.**

Funciones potenciales PRO:

- solicitudes/reservas;
- disponibilidad;
- promociones;
- demanda en la zona;
- estudios buscados que no tiene publicados;
- posición de precio;
- tendencias;
- conversión del perfil;
- multi-sucursal;
- analytics;
- futuras integraciones API.

Durante el lanzamiento se consideró dar PRO gratis temporalmente a proveedores verificados para crear inventario y demostrar valor antes de cobrar.

---

## 8. Verificación de clínicas y proveedores

Se concluyó que no cualquiera debe poder reclamar una clínica o publicar servicios médicos.

Se plantearon niveles:

```text
DISCOVERED / UNCLAIMED
CLAIM_PENDING
CLAIMED
VERIFICATION_PENDING
VERIFIED
REJECTED
```

El proveedor puede demostrar control mediante mecanismos como:

- correo corporativo;
- teléfono;
- dominio;
- documentación de negocio;
- documentación sanitaria cuando corresponda.

El sello de Pruevia debe significar algo como:

> “Identidad/documentación verificada”

no:

> “Pruevia garantiza la calidad médica de esta clínica”.

---

## 9. Multi-ciudad y cadenas

El usuario planteó un caso de borde fundamental:

> Si Ruiz existe en Puebla y mañana agregamos Querétaro, ¿se crea otro Ruiz?

La respuesta quedó fijada como regla de arquitectura:

```text
PROVIDER BRAND
Laboratorios Ruiz
        │
        ├── Sucursal Puebla A
        ├── Sucursal Puebla B
        ├── Sucursal Cholula
        └── Sucursal Querétaro
```

No existe `Ruiz Puebla` y `Ruiz Querétaro` como marcas separadas.

Esto llevó a diferenciar:

- organización legal/operadora;
- marca pública;
- sucursal física;
- mercado comercial/pricing region;
- servicio/oferta;
- precio por alcance.

También se decidió que un proveedor corporativo puede administrar todas sus sucursales, mientras un gerente regional o de sucursal puede tener permisos limitados.

La expansión de Puebla a Querétaro debe ser principalmente:

> **agregar datos, no modificar arquitectura.**

---

## 10. Arquitectura de infraestructura

El usuario pidió comenzar gratis pero poder evolucionar a infraestructura de pago sin migraciones traumáticas.

La arquitectura elegida quedó:

### Backend/API

- Cloudflare Workers;
- TypeScript;
- API REST versionada.

### Base de datos

- PostgreSQL;
- Supabase como plataforma inicial.

### Objetos/archivos

- Cloudflare R2.

### Crawlers

- Python;
- inicialmente ejecutados localmente o en GitHub Actions;
- después movibles a containers/VPS si el volumen lo requiere.

### Admin interno

- Vue 3;
- TypeScript;
- Element Plus;
- Pinia;
- Vue Router;
- Vite.

### Panel proveedores

Mismo stack que admin:

- Vue 3 + Element Plus.

### App paciente

- Flutter;
- Android;
- iOS;
- Flutter Web.

### Web pública SEO

- Nuxt 3;
- TypeScript;
- CSS/Tailwind/componentes propios;
- sin Element Plus para mantenerla ligera.

---

## 11. Por qué Workers en vez de Laravel al inicio

El usuario preguntó si realmente la API viviría en Cloudflare y no en Laravel.

Se concluyó que sí es viable y apropiado para el MVP porque la API inicial será principalmente:

- búsquedas;
- consultas de catálogo;
- proveedores;
- precios;
- usuarios;
- leads/reservas futuras;
- dashboard.

El código fuente vive en GitHub; Cloudflare ejecuta el deployment.

Flujo:

```text
git push
   ↓
GitHub Actions / CI
   ↓
tests + build
   ↓
Wrangler deploy
   ↓
Cloudflare Worker
```

Laravel no queda prohibido. Si en el futuro hay procesos empresariales complejos, puede convivir detrás del mismo contrato API. Flutter solo debe conocer `/api/v1/...`, no qué framework responde.

---

## 12. Dominio

Se confirmó que técnicamente solo hace falta **un dominio principal**.

Ejemplo:

```text
marca.com              → Nuxt SEO
app.marca.com          → Flutter Web
api.marca.com          → Worker API
admin.marca.com        → Admin
provider.marca.com     → Portal de clínicas
```

Los subdominios no requieren comprar dominios separados.

Se recomendó comprar únicamente el dominio, sin hosting, correo o paquetes del registrador.

Cloudflare Registrar se consideró una buena opción para este proyecto porque el DNS/Workers/R2 ya estarán en Cloudflare.

---

## 13. Naming

Se exploraron nombres y se descartaron varios por colisiones existentes o poca escalabilidad.

El nombre provisional que más gustó fue:

# Pruevia

Asociado conceptualmente con “prueba + vía”.

Ventajas percibidas:

- corto;
- pronunciable en español;
- no limitado a laboratorios;
- puede crecer a LATAM;
- suena a marca.

No se considera definitivo hasta revisar:

- dominio;
- empresas/apps existentes;
- búsqueda preliminar de marca;
- revisión formal de marca/IMPI antes de lanzamiento serio.

---

## 14. Flutter Web y web pública

Se decidió que **la app del paciente sí puede ser el mismo Flutter para Android, iOS y web**.

Esto permite lanzar primero:

```text
app.marca.com
```

mientras se preparan Play Store y App Store.

Sin embargo, para SEO se decidió **no usar Flutter Web**.

La web pública será Nuxt 3 porque debe generar páginas indexables y rápidas como:

```text
/puebla/electromiografia-miembros-inferiores
/puebla/resonancia-magnetica-rodilla
/estudios/biometria-hematica
/proveedores/laboratorios-ruiz
```

El CTA lleva a Flutter Web para la experiencia completa.

---

## 15. Admin web

El usuario prefirió Element Plus frente a Quasar por verse más moderno.

Decisión final:

```text
Vue 3
TypeScript
Element Plus
Pinia
Vue Router
Vite
```

El admin interno funcionará como cabina de control para:

- proveedores;
- sucursales;
- precios;
- crawlers;
- normalizaciones;
- aliases;
- problemas de calidad;
- verificaciones;
- logs;
- analytics futuros.

Una de las pantallas más importantes será la revisión de normalización:

```text
Proveedor: Chopo
Original: RM COLUMNA LS SIMPLE

Candidatos:
94% RM columna lumbosacra sin contraste
71% RM lumbar sin contraste
...

[Aprobar] [Cambiar] [Rechazar]
```

---

## 16. El problema no es exclusivo de estudios médicos

El usuario observó que el mismo patrón existe en otros mercados:

### Medicamentos

Una persona recibe un nombre de marca, pero no conoce:

- ingrediente;
- dosis;
- forma;
- presentación;
- equivalentes/intercambiables;
- otras marcas;
- precios;
- stock por farmacia.

### Refacciones

Una persona pide una pieza por nombre informal o número de parte, pero existen:

- OEM;
- aftermarket;
- diferentes marcas;
- fitment por vehículo/año/versión;
- precios y stocks distintos.

### Herramientas/repuestos

También existen nombres, compatibilidades, SKUs, medidas y equivalencias.

Esto llevó a una decisión de arquitectura importante:

> **El core debe ser reusable, pero Pruevia sigue siendo un producto médico.**

No se hará una mega tabla universal EAV.

La separación será:

```text
CORE PLATFORM
  providers
  locations
  catalog
  offers
  prices
  availability
  sources
  search
  analytics

DOMAIN: HEALTH_DIAGNOSTICS
  services
  anatomy
  specimens
  preparation
  terminology
  package components
```

Otro producto futuro podría reutilizar el core y añadir un nuevo módulo de dominio.

---

## 17. Filosofía de base de datos

Se decidió diseñar PostgreSQL para:

- multi-ciudad;
- multi-país;
- multi-sucursal;
- franquicias/operadores;
- precios por marca/mercado/sucursal;
- precios por horario/canal/promoción;
- aliases globales y específicos de proveedor;
- paquetes con componentes;
- merge/split de conceptos;
- historial;
- provenance completa;
- crawlers con cuarentena;
- futuras reservas;
- analytics;
- Big Data futuro.

Principios técnicos:

- UUID para entidades estables;
- BIGINT para eventos de alto volumen;
- `TIMESTAMPTZ`;
- dinero en minor units/centavos, nunca float;
- PostGIS para distancia;
- `pg_trgm` para fuzzy search;
- RAW separado de normalized;
- R2 para HTML/PDF/imágenes, no BYTEA;
- IDs externos como mappings, no PK;
- soft-state/merge/redirect en vez de borrar historia.

---

## 18. Modelo de proveedor

Se definió:

```text
organization
    ↓
provider_brand
    ↓
provider_location
```

Con relaciones adicionales para ownership/operator/franchise.

También existen `provider_markets` para regiones comerciales de una cadena que no necesariamente coinciden con municipios oficiales.

Ejemplo:

```text
Chopo
  Puebla market
     ├─ sucursal 1
     ├─ sucursal 2
     └─ sucursal 3
```

---

## 19. Modelo canónico

El concepto buscado por el usuario vive en un catálogo estable.

Ejemplo:

```text
catalog item:
Electromiografía de miembros inferiores
```

Los nombres no son identidad.

Se modelan:

- nombre principal;
- aliases;
- abreviaturas;
- errores comunes;
- nombres históricos;
- aliases específicos de proveedor;
- identificadores externos;
- relaciones entre conceptos.

Se contemplaron estados como:

```text
active
merged
split
deprecated
hidden
```

para corregir el conocimiento sin perder historia.

---

## 20. Modelo médico

El módulo `health` extiende el catálogo con semántica fuerte:

- tipo de servicio;
- lateralidad;
- contraste;
- anatomía;
- muestras;
- preparación;
- componentes de paneles/paquetes;
- terminologías.

La regla fue no meter semántica médica peligrosa en texto libre si puede representarse estructuralmente.

---

## 21. Offers vs canonical service

Se separó claramente:

```text
CANONICAL SERVICE
RM rodilla sin contraste
```

vs

```text
PROVIDER OFFER
"RM RODILLA SIMPLE"
```

Un proveedor puede vender varias ofertas que apunten al mismo concepto canónico.

Esto evita obligar `UNIQUE(provider,item)`.

---

## 22. Precios

Los precios no viven como una simple columna en `offers`.

Se diseñaron como versiones con alcance:

```text
BRAND
MARKET
LOCATION
```

Prioridad:

```text
LOCATION > MARKET > BRAND
```

Y dimensiones como:

- regular;
- online;
- promo;
- member;
- cash;
- from;
- channel;
- vigencia;
- días de semana;
- ventana horaria;
- condiciones.

Esto resuelve casos como:

```text
Ruiz precio general        $500
Ruiz Puebla                $450
Ruiz Anzures               $420
```

Y también:

```text
Tomografía antes de 13:00   $1600
Tomografía después de 13:00 $1400
```

El histórico solo crea una nueva versión cuando el precio/regla cambia. Si sigue igual, se actualiza `last_seen_at`.

---

## 23. Provenance y crawlers

Una de las decisiones más fuertes fue que los crawlers **no escriben directamente a producción canónica**.

Flujo:

```text
source
  ↓
endpoint
  ↓
crawl run
  ↓
raw document / raw record
  ↓
observation
  ↓
normalization
  ↓
publish
```

Se decidió guardar:

- fuente;
- endpoint;
- parser version;
- git commit;
- counts;
- hashes;
- RAW en R2;
- observations;
- quality issues.

Si ayer un crawler obtuvo 1,555 registros y hoy 17:

```text
STATUS = QUARANTINE
```

No se borran automáticamente 1,538 registros.

---

## 24. Normalización

Pipeline previsto:

```text
entrada
  ↓
normalización de texto
  ↓
exact match
  ↓
alias global
  ↓
alias proveedor/contextual
  ↓
trigram
  ↓
terminología
  ↓
reglas médicas
  ↓
embeddings futuro
  ↓
LLM último recurso
```

La IA no será la primera capa.

La normalización genera candidatos y un score. Las decisiones quedan auditadas.

Una corrección manual puede generar un alias aprobado, haciendo que la próxima búsqueda sea más barata y segura sin IA.

---

## 25. Privacidad

Se acordó no convertir Pruevia en un repositorio de órdenes médicas.

Preferencia:

```text
cámara
 ↓
OCR local
 ↓
texto
 ↓
normalización
```

Si se requiere procesamiento de imagen en servidor:

```text
R2 temporal
 ↓
procesamiento
 ↓
eliminación automática
```

Los datos sensibles futuros deben vivir en un módulo/bucket separado con controles adicionales.

Para analytics B2B se prefieren datos agregados y geografía gruesa. No es necesario asociar de manera permanente una búsqueda diagnóstica a una identidad personal.

---

## 26. Big Data

El usuario preguntó si en el futuro habría que usar Big Data.

La decisión fue:

> **Big-Data-ready, no Big-Data-now.**

PostgreSQL seguirá siendo la fuente transaccional incluso si el producto crece.

Los eventos masivos pueden evolucionar a:

```text
Worker events
   ↓
R2 / Parquet
   ↓
ClickHouse / BigQuery / equivalente
```

No se meterán Kafka, Spark ni warehouses en el MVP.

Se considerará separar analytics cuando haya señales reales como:

- cientos de millones de eventos;
- dashboards presionando Postgres;
- TBs de histórico;
- necesidad de análisis near-real-time;
- clientes enterprise.

El valor futuro puede incluir inteligencia como:

- demanda diagnóstica por zona;
- zero-result demand;
- inflación de precios por procedimiento;
- oferta insuficiente;
- tendencias de demanda;
- aliases aprendidos de comportamiento agregado.

---

## 27. V1 física de base de datos

Tras diseñar el modelo conceptual, se generó una V1 ejecutable para PostgreSQL/Supabase.

El resultado final tiene **45 tablas**.

La estimación original era ~28-30, pero durante la revisión física se decidió mantener separadas responsabilidades de:

- provenance;
- integridad geográfica;
- scopes de precios;
- calidad;
- auditoría;
- RAW;
- normalización.

En lugar de ocultar todo en JSON.

Schemas V1:

```text
geo
core
catalog
health
supply
ingest
identity
audit
ops
```

Schemas reservados para fases posteriores:

```text
analytics
marketplace
sensitive
billing
```

Archivos generados:

```text
pruevia-db-v1/
├── README.md
├── docs/
│   ├── DATABASE_ARCHITECTURE.md
│   ├── TABLE_CATALOG.md
│   └── ERD.mmd
└── supabase/
    ├── migrations/
    ├── seed.sql
    └── tests/
```

Se crearon 7 migraciones SQL versionadas y tests de base.

La V1 todavía debe ejecutarse físicamente en Supabase DEV con un flujo tipo:

```text
supabase db reset
supabase test db
```

antes de considerarla desplegada.

Por eso el estado correcto es:

> **Base de datos V1 iniciada y diseñada; migraciones ejecutables generadas; despliegue/validación física en Supabase DEV pendiente.**

---

## 28. Plan maestro acordado

El orden general de construcción quedó:

```text
1. Foundation / GitHub / Cloudflare / Supabase / R2
2. Ejecutar DB V1 en DEV
3. DENUE collector
4. Chopo collector
5. Ruiz collector
6. MAC collector
7. RAW → normalization → publish
8. Admin Element Plus
9. Search API
10. validar 100-200 estudios/procedimientos
11. Flutter Web patient MVP
12. OCR de órdenes
13. Nuxt SEO
14. provider claim + verification
15. B2B analytics
16. leads / reservations
17. PRO / billing
18. Android/iOS stores
19. nuevas ciudades
20. Big Data cuando la escala lo exija
```

---

## 29. Criterio del primer milestone real

Antes de construir una experiencia visual grande, Pruevia debe poder resolver por API algo como:

```text
"electromiografia piernas"
```

Y devolver:

```text
Servicio canónico:
Electromiografía de miembros inferiores

Confianza:
alta

Proveedor A
precio
sucursal
distancia
fuente
última verificación

Proveedor B
...
```

con datos reales de Puebla.

Ese será el momento en que el proyecto deja de ser una idea y demuestra que su Data Engine funciona.

---

## 30. Principio rector

Cada nueva funcionalidad debe responder al menos una de estas preguntas:

> ¿Hace más fácil que el paciente encuentre correctamente dónde realizar lo que le pidieron?

O:

> ¿Ayuda a un proveedor a captar o entender mejor esa demanda?

Si la respuesta a ambas es no, probablemente no sea prioridad.

---

# Decisiones canónicas actuales

1. **Mercado inicial:** Puebla.
2. **Expansión:** multi-ciudad y LATAM desde el modelo de datos.
3. **Nombre:** Pruevia provisional.
4. **Paciente:** Flutter Android/iOS/Web.
5. **SEO:** Nuxt 3 ligero.
6. **Admin:** Vue 3 + Element Plus.
7. **Provider:** Vue 3 + Element Plus.
8. **API:** Cloudflare Workers + TypeScript.
9. **DB:** PostgreSQL/Supabase.
10. **Archivos/RAW/backups:** Cloudflare R2.
11. **Collectors:** Python.
12. **Data model:** reusable core + health diagnostics domain.
13. **Big Data:** preparado, no implementado todavía.
14. **Proveedor:** marca única + muchas sucursales/mercados.
15. **Precios:** versionados y resolubles por brand/market/location/channel/time.
16. **Normalización:** reglas/aliases/trigram/terminología primero; IA como última capa.
17. **Privacidad:** no persistir órdenes médicas por defecto.
18. **Monetización:** B2C gratuito; B2B PRO/analytics/leads/reservas/patrocinados en fases futuras.
19. **Proveedor gratuito:** puede reclamar y mantener catálogo/precios para mejorar cobertura.
20. **PRO:** vende adquisición + inteligencia de demanda, no solo visibilidad.
21. **Base V1:** 45 tablas, migraciones SQL ya generadas.
22. **Estado DB:** iniciada, pendiente de ejecutar/validar en Supabase DEV.

---

# Archivos canónicos relacionados

- `01_ARQUITECTURA_CANONICA.md` — arquitectura consolidada de producto, software, infraestructura y datos.
- `02_FASES_IMPLEMENTACION.md` — roadmap por fases y criterios de salida.
- `PRUEVIA_DB_V1.zip` — migraciones SQL ejecutables, seeds, tests y documentación de la V1 de PostgreSQL/Supabase.
- `DB_ARCHITECTURE_V1.md` — arquitectura específica de la base V1.
- `DB_TABLE_CATALOG_V1.md` — catálogo de las 45 tablas V1.

