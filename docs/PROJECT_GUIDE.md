# Producto y lógica vigente

Tipo: guía normativa de producto y mapa de implementación.
Base revisada: árbol local del 14-sep-2026. Estado operativo: [CURRENT_STATE](CURRENT_STATE.md).

## Qué construimos

Pruevia ayuda a una persona a identificar los estudios de su orden médica y
comparar opciones reales por proveedor, sucursal, ubicación, precio y condiciones.
El piloto es Puebla. El éxito es que el usuario pueda tomar una decisión con
información útil, conservando las aclaraciones necesarias cuando su orden o la
oferta no sean suficientemente específicas.

No se garantiza resolver cualquier receta ni se interpreta un resultado clínico.
Tampoco se considera implementada una reserva, pago, convenio o capacidad comercial
por aparecer en la arquitectura de largo plazo.

| Usuario | Necesidad y límite |
| --- | --- |
| Paciente/visitante | Buscar, revisar OCR, aclarar variantes y comparar cobertura sin registro obligatorio. |
| Administrador | Revisar excepciones, evidencia, identidades, equivalencias y datos operativos con trazabilidad. |
| Proveedor | Gestionar los recursos para los que está autorizado; una cuenta o MFA por sí solos no prueban propiedad. |

## Responsabilidades del software

| Componente | Responsabilidad y entrada de código |
| --- | --- |
| Paciente Flutter | Presentación, captura, confirmación y consumo del contrato: [main.dart](../apps/patient/lib/main.dart), [cliente](../apps/patient/lib/src/api_client.dart), [modelos](../apps/patient/lib/src/models.dart). |
| Admin Vue/Vite | Operación interna: [App.vue](../apps/admin/src/App.vue), [API](../apps/admin/src/api.ts), [Auth](../apps/admin/src/auth.ts). |
| Landing Nuxt | Sitio informativo/SEO independiente: [app](../apps/landing/app/pages/index.vue), [configuración](../apps/landing/nuxt.config.ts). No recoge datos médicos. |
| API Worker TypeScript | HTTP, validación, permisos, límites y coordinación: [rutas](../apps/api/src/app.ts), [tipos](../apps/api/src/types.ts), [RPC](../apps/api/src/supabase.ts). |
| Supabase/PostgreSQL | Catálogo, equivalencias, reglas de resolución, oferta, precios, auditoría y permisos. [Migraciones](../database/supabase/migrations) y [contratos](../database/supabase/tests). |
| Collectors Python | Captura acotada, parseo, observaciones y artefactos: [pipeline](../collectors/src/pruevia_collectors/pipeline.py), [adaptadores](../collectors/src/pruevia_collectors/providers). |
| OCR | Extracción literal y calidad de lectura: [coordinación Worker](../apps/api/src/ocr.ts), [servicio](../apps/ocr-service/README.md). |
| Scanner documental | Validación de documentos de proveedor; su existencia no habilita el flujo cerrado. [Servicio](../apps/document-scanner/README.md). |

El frontend no implementa su propio resolvedor ni decide permisos. El Worker
valida la frontera pública y usa RPC del servidor; la base mantiene reglas y
restricciones persistentes. La selección de combinaciones de sucursales está en
[batch.ts](../apps/api/src/batch.ts). Un cambio transversal debe comprobar ambos
lados del contrato y sus consumidores.

La lista histórica de stack del Admin menciona Element Plus, Pinia y Vue Router;
no son dependencias del [package actual](../apps/admin/package.json). No instalarlas
para cumplir ese texto antiguo. La landing Nuxt y almacenamiento R2 amplio son
arquitectura prevista, no capacidades desplegadas acreditadas por esta guía.

## Conceptos que no deben mezclarse

| Concepto | Significado |
| --- | --- |
| Marca / organización / sucursal | Identidad comercial, entidad operadora y sede física; abrir otra ciudad no duplica la marca. |
| Estudio canónico | Concepto revisado independiente del nombre comercial; conserva atributos clínicos. |
| Alias | Nombre equivalente aprobado, global o limitado al proveedor según su alcance. |
| Oferta | Evidencia de que un proveedor ofrece un estudio, con alcance comercial definido. |
| Precio | Importe en unidades menores, moneda, tipo/canal, condiciones, alcance y vigencia; no es sólo un número. |
| Disponibilidad | Hecho que requiere evidencia para su alcance; no se deduce de precio o dirección. |
| Evidencia RAW | Registro observado que puede ser incompleto o pendiente; no equivale a una oferta publicable. |

La herencia de precios está descrita en [base de datos](../database/README.md):
sucursal > mercado > marca, respetando reglas y vigencia. Verificar la función
vigente y sus contratos antes de cambiar esa precedencia.

## Flujos y contratos

```text
fuente → corrida → RAW/observaciones → normalización/revisión → publicación
                                                                  ↓
texto u OCR revisado → estudios/candidatos → ofertas → opciones por sucursal
```

Las rutas existentes se consultan en `apps/api/src/app.ts`; las formas de respuesta
en `types.ts` son referencia ejecutable, no se copiarán completas en esta guía.

| Ruta | Uso y comportamiento que debe conservarse |
| --- | --- |
| `POST /api/v1/resolve` | Resolución individual con `resolved`, `ambiguous` o `no_match`. |
| `POST /api/v1/resolve-batch` | Receta/lista; estado del paquete y cobertura son campos distintos. |
| `POST /api/v1/resolve-image` | Extrae texto y coordina resolución; conserva revisión y correcciones. |
| `GET /api/v1/search` y detalles de servicios/proveedores | Búsqueda y consulta de opciones. |
| `/api/v1/admin/*` | Operación interna: sesión verificada, UUID autorizado y AAL2. |
| `/api/v1/provider/*` | Sesión verificada, AAL2 y autorización por recurso. |

No cambiar nombres ni semántica del contrato sin actualizar consumidores y pruebas.
`package_status` admite `ready`, `needs_clarification`, `partial`, `no_match`;
`coverage_status` admite `complete`, `partial`, `none`. Estudio reconocido no
significa necesariamente una oferta disponible en la zona.

Ejemplos de comportamiento:

- “Biometría hemática”: devolver el concepto correcto si se reconoce; comprobar
  separadamente las ofertas y sus condiciones. No prometer un número fijo de sedes.
- “Perfil tiroideo”: si existen composiciones incompatibles, pedir aclaración.
- “Creatinina en orina”: conservar la muestra; no sustituir por creatinina sérica.
- Receta de tres estudios con dos cubiertos: mostrar 2/3, faltante y alternativas
  verificadas; no declarar cobertura completa por encontrar dos ofertas.
- Oferta sin importe vigente: solicitar cotización, sin sumar cero al total.
- OCR ilegible: conservar texto original y revisión; no completar palabras con
  una supuesta intención clínica.
- Sufijo textual explícito como "en ayuno de 8 horas": resolver sólo el nombre
  base y devolver el sufijo como `preparation_note`; no afirmar que el estudio
  requiere ayuno ni convertir la nota en una instrucción médica.

## Invariantes y evolución

Fuzzy, embeddings o IA sólo proponen cuando no existe una equivalencia aprobada.
El recorrido público usa la familia unificada del resolver; funciones históricas
pueden coexistir en migraciones. Revisar la definición final y los wrappers antes
de diagnosticar o modificar una función de versión anterior.

Los hechos publicados requieren procedencia. Fuentes de diferente confianza no
se sobreescriben silenciosamente. Un cambio de esquema, caída de conteo o error TLS
de una fuente exige investigación y la cuarentena correspondiente.

Admin busca automatización de operaciones seguras y revisión humana de excepciones.
El reproceso exacto existente reutiliza catálogo/aliases aprobados; no crea una
oferta por el simple hecho de resolver una etiqueta. Toda automatización nueva
debe aclarar qué datos modifica y qué evidencia autoriza esa modificación.

La [arquitectura de referencia](01_ARQUITECTURA_CANONICA.md) conserva el diseño
amplio; sus secciones futuras no acreditan implementación. Para cambiar una
decisión vigente usa [DECISIONS](DECISIONS.md) y para elegir el próximo trabajo
usa [CURRENT_STATE](CURRENT_STATE.md).
