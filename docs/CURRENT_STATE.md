# Estado y prioridades de Pruevia

Tipo: punto de continuidad. Revisado el 14-sep-2026 sobre el árbol basado en
`9e7c275`. Esta entrega revalidó contratos contra Supabase DEV, pero no aplicó
migraciones ni publicó servicios.
Los datos de septiembre citados abajo son cortes de evidencia, no contadores en vivo.

## Cómo leer el estado

`Implementado` indica código presente; `verificado` exige evidencia de la prueba y
su alcance; `desplegado` exige entorno y versión comprobados; `pendiente` necesita
trabajo; `bloqueado` necesita una condición externa identificada. No son sinónimos.

| Capacidad | Estado respaldado y evidencia | Límite / siguiente acción |
| --- | --- | --- |
| Búsqueda, resolución, paquetes y OCR | Implementados: [Worker](../apps/api/src/app.ts), [tipos](../apps/api/src/types.ts), [tests](../apps/api/tests). | Revalidar el entorno de la prueba y medir recetas; tener rutas no prueba cobertura suficiente. |
| Paciente Flutter Web/PWA | Implementado: [app](../apps/patient/lib/main.dart), [comandos](../apps/patient/README.md). | Publicación actual y validación física/multiplataforma requieren evidencia propia. |
| Admin con temas, filtros y MFA | Implementado: [Admin](../apps/admin/src/App.vue), [filtros](../apps/admin/src/components/TableFilters.vue), [Auth](../apps/admin/src/auth.ts). | Probar sesión real y alcance de búsquedas/filtros cuando cambie el backend o el entorno. |
| Documentos de proveedores | Configuración versionada cerrada por defecto; ver [cierre](../database/supabase/migrations/20260908100000_internal_document_freeze.sql) y [Worker](../apps/api/wrangler.toml). | No reabrir sólo cambiando una variable; necesita propuesta crítica y revisión coordinada. |
| Collectors | Adaptadores presentes para DENUE, Chopo, Ruiz, Salud Digna, SEMIN, Dr. Simi, Linfolab y genérico. [Entrypoints](../collectors/pyproject.toml). | Eficacia y frescura varían por fuente; ver [cobertura](PUEBLA_PROVIDER_COVERAGE.md). |
| CI y despliegue DEV | Workflows presentes en [.github](../.github/workflows). | No se verificó aquí configuración de GitHub, ejecución reciente ni versión remota. |
| Landing SEO | Implementado localmente en `apps/landing` con Nuxt 4, generación estática, privacidad, robots/sitemap condicionado y headers. | El sitio aún no está publicado: compra, DNS, asociación de dominios y destino real del CTA requieren configuración y verificación. |
| Dominio Pruevia | Arquitectura definida: raíz para landing, `app`, `admin`, `api` como subdominios. | Compra, DNS y asociación de dominios no acreditados en esta entrega. |

## Corte de cobertura disponible

Fuente: [reconciliación Puebla](PUEBLA_PROVIDER_COVERAGE.md) y sus fixtures del
13–14 de septiembre. Reconsultar directorios/DB antes de tomar decisiones actuales.

- Salud Digna: inventario de 15 entradas, 13 con detalle de sucursal; centros
  293 y 299 pendientes de reconciliación. No equivale a catálogo completo por sede.
- Dr. Simi: feed con cuatro sedes, tres enlazadas; unidad 260 con discrepancia.
- Linfolab: seis registros RAW completos, tres ubicaciones enlazadas según el corte.
- DENUE: 489 registros fuente, 213 candidatos clínicos directos; 123 sin URL pública.
  Son leads del snapshot, no un censo actual ni 213 proveedores confirmados.
- Cola: último preview remoto registrado en esta sesión reportó 7,028 pendientes
  y cero elegibles adicionales para reproceso exacto; no es una tasa de fallo del paciente.
- El reporte reproducible de priorización por proveedor/etiqueta está en
  [puebla_normalization_backlog.sql](../database/reports/puebla_normalization_backlog.sql);
  agrupa esas filas para revisión sin publicar cambios.
- El medidor de experiencia sobre el corpus público anonimizado está en
  [report_query_coverage.py](../database/scripts/report_query_coverage.py);
  separa resolución estricta, preparación, ambigüedad y resoluciones inesperadas.
- Los 946 `no_match` cerrados son historial. No contar cada fila `no_match` como
  tarea abierta: comprobar decisión final con la semántica del dashboard/cola.

Los conteos históricos de README, reportes y arquitectura pueden diferir porque
corresponden a otros cortes. No sumar corridas ni versiones de precios como si
fueran estudios distintos.

## Prioridades ejecutables

Las siguientes tareas preservan el objetivo de una base útil en Puebla. No son
promesas de fecha ni nuevas autorizaciones para operaciones externas.
Son el orden por defecto cuando el usuario no indica otra tarea. Una petición
explícita, como construir el landing, tiene prioridad y no necesita esperar el
backlog del core salvo dependencia funcional real. Construir y publicar son
acciones distintas; aplicar aprobación crítica cuando corresponda.

| ID / prioridad | Resultado y siguiente acción | Dependencia / aceptación |
| --- | --- | --- |
| PUE-01 / alta | Medir cobertura desde la experiencia paciente: reutilizar corpora existentes y preparar muestra de recetas desidentificadas con procedencia y alcance. Medir resolución por estudio, ofertas por zona, precios/frescura y receta completa/parcial. | Definir muestra representativa y metas con el usuario antes de usarlas como gate; reportar denominadores, errores y límites. No llamar “datos reales” a variantes sintéticas. |
| PUE-02 / alta | Reducir las brechas que revele PUE-01: agrupar cola por etiqueta/proveedor y frecuencia observada, revisar conceptos/mappings y publicar ofertas con evidencia de alcance. | Equivalencia revisada, trazabilidad, idempotencia y prueba end-to-end que muestre la mejora sin falsos positivos. Vaciar la cola no es el criterio. |
| PUE-03 / alta | Completar directorios prioritarios Salud Digna/Dr. Simi y contrastar Ruiz, Chopo, SEMIN, Linfolab y proveedores locales con fuentes oficiales. | Registrar sede enlazada o discrepancia explícita, fuente/fecha; separar sucursal de estudios ofrecidos. Los que no tienen web requieren evidencia alternativa. |
| PUE-04 / alta | Mejorar capturas fallidas con piloto por fuente; establecer corrida programada, métricas de caída/frescura y revisión de excepciones. | Adaptador probado y job realmente verificado. La cadencia sugerida no acredita automatización. Revisar costos/servicio nuevo si aplican. |
| OPS-01 / alta | Inventariar jobs y alertas realmente activos, cubrir las brechas de [mantenimiento continuo](CONTINUOUS_IMPROVEMENT.md) y revisar CI/dependencias relevantes. | Registrar horario, entorno, ejecución real, fallo/reintento y responsable; proponer servicio/costo nuevo antes de activarlo si requiere aprobación. |
| ADM-01 / media | Verificar operación del Admin con el volumen actual: búsqueda, periodos, paginación, cola y acciones auditables. | Consulta encuentra un registro fuera de la primera página o declara claramente su alcance; estados de red, vacío y sesión distinguibles. |
| REL-01 / posterior a cobertura | Preparar prueba externa de Puebla con gate medido, revisión de seguridad pendiente, Auth, orígenes, despliegue y recuperación. | Propuesta de liberación con resultados y limitaciones; aprobación explícita antes de apertura crítica. |
| REL-02 / alta antes de integrar frontends | Resolver acceso de paciente y Admin desde orígenes distintos: el Worker actual admite un solo `ALLOWED_ORIGIN`. Proponer allowlist explícita o separación de destinos y sus pruebas. | Decisión revisada de seguridad/configuración; aprobación previa si modifica la frontera de acceso. Validar preflight y rechazo de orígenes ajenos antes de desplegar. |
| FUT-01 / posterior | Publicar y ampliar SEO del landing, expansión geográfica y capacidades comerciales según [roadmap](02_FASES_IMPLEMENTACION.md). | Landing base ya implementado; publicación requiere destino, contenido legal/contacto revisado y aprobación crítica. Datos dinámicos y cobertura no se inventan para llenar páginas. |

PUE-01 y captura acotada PUE-03 pueden avanzar sin esperar expansión del catálogo.
PUE-02 debe usar evidencia para priorizar, evitando crecer por volumen sin utilidad.

## Puerta de liberación

Ya son requisitos de producto: no inventar equivalencias ni precios, mostrar
cobertura parcial/ambigüedad, preservar trazabilidad y autorización, y verificar
el flujo paciente en el entorno que se abrirá.

Siguen pendientes de definición/aprobación: tamaño y composición representativa
de la muestra, zona exacta del piloto, tasas objetivo de cobertura y tolerancia a
datos comerciales desactualizados. El agente debe proponerlos con la medición;
no inventar un porcentaje y presentarlo como requisito aprobado.

Los benchmarks v1/v2 respaldan sus consultas. La revalidación remota del
14-sep-2026 ejecutó los 25 contratos SQL (412 aserciones) con el runner fijado a
Supabase CLI 2.116.0: todos pasaron, incluyendo las 22 aserciones clínicas y el
contrato de paquetes 10/10. La prueba de paquetes se hizo determinista por
sucursal fixture porque el catálogo real puede ordenar antes ofertas de otros
proveedores. Repetir desde `database/` con
`python scripts/run_sql_contracts.py --cli npx.cmd --package supabase@2.116.0`
antes de liberar un cambio acoplado al esquema.

## Actualización y traspaso

Validación documental del 14-sep-2026: enlaces locales y anclas de la nueva entrada,
guías, decisiones y snapshot comprobados; `git diff --check` sin errores.
`AGENTS.md` se mantiene por debajo de 150 líneas. El landing pasó sus pruebas de
configuración, typecheck, auditoría npm, generación estática y revisión visual
local; no se ejecutaron despliegues ni se verificaron DNS/servicios públicos.

Se recorrieron estos escenarios contra las referencias y código local:

| Escenario | Orientación que aporta la guía |
| --- | --- |
| Cambiar colores | Ubica ambos archivos de tokens, coordinación CSS/Dart y revisión visual. |
| Incorporar proveedor | Ubica adapter/pipeline/renderers, evidencia, revisión y aceptación sin inventar ofertas. |
| Diagnosticar 401 | Ubica Auth/Worker, formato de UUID, sesión/factor y separación de 401/403. |
| Corregir resolver | Ubica RPC/wrappers, atributos a conservar y runner de contratos completos. |
| Preparar despliegue | Ubica workflow, configuración, aprobación crítica, verificación y recuperación. |

La revisión detectó además el límite actual de un origen CORS y la selección de
credenciales desactualizada del ADR: se documentó REL-02 y se reconcilió el ADR
con el código, sin modificar permisos ni comportamiento.

Para una capacidad material registrar: fecha, commit/versión, entorno, evidencia
reproducible, resultado, límites y siguiente acción. Si un archivo/servicio no está
accesible, indicar “no verificado” y cómo comprobarlo. No almacenar datos clínicos,
credenciales o autorizaciones generales como memoria.

Actualizar esta página al cambiar prioridades/capacidades; los reportes detallados
retienen su fecha. Un pendiente terminado se retira de la tabla y se resume con
evidencia en su documento de área; no acumular un diario infinito aquí.
