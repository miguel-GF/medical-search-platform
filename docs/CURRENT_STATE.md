# Estado y prioridades de Pruevia

Tipo: punto de continuidad. Revisado el 19-sep-2026 sobre el árbol local, el
ledger remoto enlazado y el Worker DEV. Las migraciones de feedback, cohorte y
analítica de clics están aplicadas en DEV. El Worker está publicado con el
scheduler fail-closed y CORS restringido temporalmente a su propio origen; aún
no existe un frontend HTTPS DEV publicado.
Los datos de septiembre citados abajo son cortes de evidencia, no contadores en vivo.

## Cómo leer el estado

`Implementado` indica código presente; `verificado` exige evidencia de la prueba y
su alcance; `desplegado` exige entorno y versión comprobados; `pendiente` necesita
trabajo; `bloqueado` necesita una condición externa identificada. No son sinónimos.

| Capacidad | Estado respaldado y evidencia | Límite / siguiente acción |
| --- | --- | --- |
| Búsqueda, resolución, paquetes y OCR | Implementados: [Worker](../apps/api/src/app.ts), [tipos](../apps/api/src/types.ts), [tests](../apps/api/tests). El resolver conserva sufijos explícitos como `en ayuno` en `preparation_note` sin inferencia clínica. | Revalidar el entorno de la prueba y medir recetas; tener rutas no prueba cobertura suficiente. |
| Paciente Flutter Web/PWA | Implementado: [app](../apps/patient/lib/main.dart), [comandos](../apps/patient/README.md). | Publicación actual y validación física/multiplataforma requieren evidencia propia. |
| Feedback y prueba cerrada Android | Implementados en DEV: endpoints Worker, esquema aislado `research`, formulario de testers, feedback estructurado en Patient y cola/triage en Admin. La cohorte está cerrada y en `0/20`; al abrirla seguirá `registro → invitación simultánea → 20 activos → Día N/21`. No envía correos automáticamente ni inicia el reloj al registrarse. La prueba cubre Puebla, San Andrés Cholula, San Pedro Cholula, Cuautlancingo, Coronango y Amozoc. Las migraciones `20260918100000` y `20260919100000` están aplicadas; sus contratos remotos pasaron `22/22` cada uno. | Faltan el nombre legal completo y domicilio real autorizados, enlace real de Google Play, mecanismo de envío, activación de la convocatoria y orígenes HTTPS reales. No se enviaron notificaciones ni invitaciones. La audiencia de Play es 18+ sin bloquear menores; el registro de testers exige 18+. |
| Clics hacia proveedores | Implementado y desplegado en DEV: evento estructurado por oferta/estudio/sucursal/acción, consentimiento de analítica del paciente, agregados globales en Admin y panel limitado por membresía en Proveedores. No se guardan consultas, recetas ni diagnósticos; los proveedores no reciben IDs anónimos ni datos de competidores. El contrato remoto pasó `22/22` y privilegios `30/30`; el tablero inicia en cero. | Falta validar visualmente ambos paneles con sesiones reales Admin/proveedor y publicar frontends HTTPS DEV. La prueba SQL acredita el aislamiento por membresía, no una sesión real de interfaz. |
| Admin con temas, filtros y MFA | Implementado: [Admin](../apps/admin/src/App.vue), [filtros](../apps/admin/src/components/TableFilters.vue), [Auth](../apps/admin/src/auth.ts). | Probar sesión real y alcance de búsquedas/filtros cuando cambie el backend o el entorno. |
| Documentos de proveedores | Configuración versionada cerrada por defecto; ver [cierre](../database/supabase/migrations/20260908100000_internal_document_freeze.sql) y [Worker](../apps/api/wrangler.toml). | No reabrir sólo cambiando una variable; necesita propuesta crítica y revisión coordinada. |
| Reclamación de perfiles | Flujo local implementado: expediente privado, estados, revisión Admin, comprobación de contacto, outbox de correo, solicitudes de privacidad y control de revisión; [referencia](PROVIDER_CLAIM_WORKFLOW.md). Contrato SQL local pasó. | `provider_intake_settings.enabled` y documentos siguen cerrados; faltan responsable legal, aviso integral, SMTP y verificación del destino antes de abrir. No se aplicaron estas migraciones al proyecto remoto. |
| Collectors | Adaptadores presentes para DENUE, Chopo, Ruiz, Salud Digna, SEMIN, Dr. Simi, Linfolab y genérico. [Entrypoints](../collectors/pyproject.toml). | Eficacia y frescura varían por fuente; ver [cobertura](PUEBLA_PROVIDER_COVERAGE.md). |
| CI y despliegue DEV | Workflows presentes en [.github](../.github/workflows). | No se verificó aquí configuración de GitHub, ejecución reciente ni versión remota. |
| Landing SEO | Implementado localmente en `apps/landing` con Nuxt 4, generación estática, privacidad, robots/sitemap condicionado, headers y accesos configurables a app web/PWA, proveedores, soporte y testers. | El sitio aún no está publicado: compra, DNS, URLs reales, correo de soporte y destino real del CTA requieren configuración y verificación. |
| Identidad visual | Implementada localmente: libro abierto con P y líneas de orden, favicon de landing/admin, marca inline en Vue/Flutter, iconos PWA, Android/iOS y splash del paciente; [fuentes y renderer](../design/brand/README.md). | No se publicaron aplicaciones; iOS no se compiló en este entorno Windows. Los iconos funcionales de ubicación se conservaron deliberadamente. |
| Dominio Pruevia | Arquitectura definida: raíz para landing, `app`, `admin`, `api` como subdominios; shortlist investigada en [opciones de dominio](DOMAIN_OPTIONS.md). | Compra, DNS y asociación de dominios no acreditados en esta entrega. |

## Estado del ledger remoto

La consulta `npx.cmd supabase@2.116.0 migration list --linked` del
19-sep-2026 confirmó `107/107` migraciones aplicadas hasta `20260919100000`.
Los contratos remotos de feedback y cohorte/clics pasaron `22/22` cada uno, y
el contrato de privilegios pasó `30/30`. El Worker `pruevia-api-dev` se publicó
con versión `1dae2f0f-655d-40f0-abab-3fbcedb4abe4` y trigger `17 * * * *`.
`NORMALIZATION_REPROCESS_ENABLED` no está configurada, por lo que no ejecuta
escrituras automáticas. Mientras no exista un frontend HTTPS DEV,
`ALLOWED_ORIGINS` permite sólo el origen exacto del propio Worker: health y el
estado público del piloto responden `200`, un origen ajeno recibe `403` y las
rutas Admin/proveedor responden `401` sin token. El piloto devuelve cohorte
cerrada, `0/20`, duración 21 días y sin fecha de inicio; no se enviaron avisos.

## Corte de cobertura disponible

Fuente: [reconciliación Puebla](PUEBLA_PROVIDER_COVERAGE.md) y sus fixtures del
13–14 de septiembre. Reconsultar directorios/DB antes de tomar decisiones actuales.

- Salud Digna: inventario de 15 entradas, 13 con detalle de sucursal; centros
  293 y 299 pendientes de reconciliación. No equivale a catálogo completo por sede.
- Dr. Simi: feed con cuatro sedes, tres enlazadas; unidad 260 con discrepancia.
- Linfolab: seis registros RAW completos, tres ubicaciones enlazadas según el corte.
- DENUE: 489 registros fuente, 213 candidatos clínicos directos; 123 sin URL pública.
  Son leads del snapshot, no un censo actual ni 213 proveedores confirmados.
- Cola: la consulta remota de sólo lectura del 18-sep-2026 reportó 7,028 filas
  abiertas, pero agrupadas en 1,188 combinaciones proveedor+etiqueta de 8
  proveedores. Salud Digna concentra 6,804 filas en 967 etiquetas; SEMIN 140,
  Chopo 57 y el resto 27. El dashboard reportó 0 ambiguas, 7,028 sin
  cobertura abierta y 946 `no_match` ya cerradas en historial. El preview exacto
  no encontró coincidencias nuevas; no es una tasa de fallo del paciente.
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
| REL-02 / alta antes de integrar frontends | Implementada en el Worker la opción opt-in `ALLOWED_ORIGINS`: lista exacta, preflight por origen y 403 sin reflejo para orígenes ajenos; conserva `ALLOWED_ORIGIN` por compatibilidad. | Elegir dominios reales, revisar la frontera de seguridad y aprobar la activación/configuración antes de desplegar. |
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

La propuesta de puerta conjunta para publicación, CORS y reducción controlada de
la cola está en [ADR-002](ADR-002-RELEASE-PILOT-GATES.md); permanece sin aprobar
y no autoriza acciones externas.

## Actualización y traspaso

Validación documental y de implementación del 18-sep-2026: enlaces locales y anclas de la nueva entrada,
guías, decisiones y snapshot comprobados; `git diff --check` sin errores.
`AGENTS.md` se mantiene por debajo de 150 líneas. El landing pasó sus pruebas de
configuración, typecheck, auditoría npm, generación estática y revisión visual
local; la suite Python raíz pasó `357` pruebas con el `pytest.ini` versionado. El
símbolo de libro con P y líneas de orden se integró en las tres aplicaciones
visuales y se regeneraron 29 derivados PNG; la validación comprobó sus dimensiones
y ausencia de assets vacíos. El paciente pasó `flutter analyze`, 25 pruebas y `flutter build web`;
el Admin pasó 23 pruebas, typecheck y build con placeholders HTTPS. El build
sin configuración continúa rechazando la publicación como medida fail-closed.
También pasó un build debug Android con el package `com.pruevia.app`,
`targetSdk 36` y los flags del piloto. El release exige la
firma configurada y no se relajaron esas protecciones; no se subió ningún
artefacto a Google Play.
El Worker local, usando `.dev.vars` sin imprimir secretos, respondió `200` en health
y resolvió una orden de dos estudios con sufijos explícitos de ayuno, conservando
ambas notas y cobertura completa. No se ejecutaron despliegues ni se verificaron
DNS/servicios públicos. La variante indexable de la landing se
generó con destinos HTTPS de ejemplo y produjo sitemap/robots; los destinos reales
siguen sin verificarse.
El Worker actual fue desplegado como `pruevia-api-dev`, versión
`1dae2f0f-655d-40f0-abab-3fbcedb4abe4`, después de pasar 139 pruebas Vitest y
la validación de allowlist CORS exacta. `ALLOWED_ORIGINS` usa temporalmente el
origen HTTPS del propio Worker; debe sustituirse por los dominios exactos cuando
se publiquen los frontends DEV.
El corte de cohorte y clics pasó 139 pruebas del Worker, 23 del Admin, 8 del
landing, typecheck en las tres superficies, `flutter analyze` y 26 pruebas
Flutter. La migración se ensayó primero en PostgreSQL 12 efímero, donde se
detectó y corrigió un alias SQL incompatible; después se aplicó a DEV y su
contrato remoto pasó `22/22`. Falta la revisión visual con sesiones reales.
El corpus anonimizado de 64 consultas, medido contra el Worker HTTP local con
UTF-8, obtuvo 7/7 resoluciones estrictas y 9/9 resoluciones esperadas incluyendo
preparación, sin resoluciones inesperadas; 51 casos permanecen correctamente en
`no_match` y 4 en `ambiguous` según su intención no resoluble.
Los colores decorativos de la landing quedaron centralizados en sus tokens, sin
hexadecimales dispersos en CSS/SVG.

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
con el código. La opción plural está preparada y probada, sin modificar permisos
remotos ni activar una frontera nueva.

Para una capacidad material registrar: fecha, commit/versión, entorno, evidencia
reproducible, resultado, límites y siguiente acción. Si un archivo/servicio no está
accesible, indicar “no verificado” y cómo comprobarlo. No almacenar datos clínicos,
credenciales o autorizaciones generales como memoria.

Actualizar esta página al cambiar prioridades/capacidades; los reportes detallados
retienen su fecha. Un pendiente terminado se retira de la tabla y se resume con
evidencia en su documento de área; no acumular un diario infinito aquí.
