# Guías de trabajo por tarea

Tipo: procedimiento vigente. Lee sólo el apartado pertinente y sus referencias.
Reglas generales: [AGENTS](../AGENTS.md). Comandos: [operación](OPERATIONS_GUIDE.md).

## Ampliar cobertura de Puebla

1. Identificar la brecha: marca faltante, sede faltante, catálogo, equivalencia,
   oferta, precio, frescura o resolución. Consultar [inventario Puebla](PUEBLA_PROVIDER_COVERAGE.md)
   y comprobar la fecha del snapshot antes de repetir discovery.
2. Contrastar identidad y sucursal con directorio oficial y DENUE. Conservar IDs,
   fuente, fecha, domicilio y coordenadas disponibles. Registrar discrepancias.
3. Reutilizar un adaptador en [providers](../collectors/src/pruevia_collectors/providers).
   El genérico sirve para descubrir; si devuelve vacíos repetidos, inspeccionar
   una muestra y decidir un adaptador dedicado o una tarea de verificación externa.
4. Para un nuevo adaptador seguir modelos/pipeline existentes: captura limitada,
   TLS, robots, restricciones de URL/redirección, límites de páginas/bytes/tiempo,
   parseo reproducible y errores explícitos. Registrar el CLI en
   [pyproject](../collectors/pyproject.toml) cuando corresponda.
5. Probar muestra válida, vacía, incompleta, cambio de esquema, duplicados y error
   de transporte que afecten al adaptador. Ejecutar un piloto acotado; inspeccionar
   conteos, observaciones y cuarentena antes de ampliar.
6. Generar SQL/cola con los [renderers existentes](../database/scripts), revisar
   diffs e idempotencia y publicar únicamente dentro del alcance autorizado.
   Verificar después identidad, enlaces, ofertas y trazabilidad según lo publicado.

Mantener artefactos en el lugar ignorado previsto; versionar fixtures mínimos
revisados, sin credenciales ni datos personales. Si un artefacto sólo existe en
otra máquina, documentar cómo regenerarlo y qué evidencia se perdió.

No fusionar marcas por parecido, no distribuir todos los estudios a todas las
sucursales y no aprobar mappings clínicos sólo para vaciar la cola.

Cadencia recomendada, aún sujeta a ejecución/scheduling verificado: catálogos y
precios cada 24 h; sucursales semanales; DENUE mensual; pequeños sitios cada 7–14
días; revisión de excepciones diaria. Ajustar por condiciones de fuente y carga.
Un plan de frecuencia no demuestra que exista un job: registrar scheduler,
última corrida, próxima ejecución y alerta al implementarlo. Las reglas detalladas
de frescura están en [cobertura](PUEBLA_PROVIDER_COVERAGE.md).

## Modificar resolver, catálogo u OCR

1. Reproducir la consulta por la ruta que usa el paciente, conservando input,
   atributos relevantes y estado esperado; utilizar datos sintéticos/desidentificados.
2. Localizar la última definición SQL y wrappers en
   [migraciones](../database/supabase/migrations), su llamada en Worker y consumidores.
   Distinguir fallo de OCR, equivalencia, catálogo, oferta, ubicación y precio.
3. Preferir mappings/aliases revisados cuando la brecha sea de datos. Si cambia
   lógica persistente, añadir migración y contratos; no editar migraciones aplicadas.
4. Comprobar caso positivo y vecino que debe abstenerse: muestra, anatomía,
   modalidad, contraste, lateralidad y composición de paneles según el cambio.
5. Ejecutar el contrato afectado mediante el runner completo. Para cambios de
   resolución transversal incluir benchmarks v1/v2, confianza y paquete; para OCR,
   reglas/correcciones, segmentación y ruta de imagen según lo afectado.
6. Confirmar que propuestas y coincidencias ambiguas no pasan a cobertura completa.

Referencias: [benchmark v1](RESOLVER_BENCHMARK_V1.md),
[benchmark de campo](REAL_QUERY_RESEARCH_V1.md), [LOINC](LOINC_INTEGRACION.md).
Los corpora existentes miden sus propios casos; no son una tasa representativa
de éxito sobre recetas reales de Puebla.

## Cambiar Admin, paciente o temas

Reutilizar [TableFilters](../apps/admin/src/components/TableFilters.vue), iconos y
estados existentes. Búsqueda y pills de periodo/estado son el patrón preferido
para filtros frecuentes; respetar paginación y alcance real de los datos cargados.
No presentar un filtro sobre una página limitada como búsqueda de toda la base.

La paleta se mantiene en [theme.css](../apps/admin/src/theme.css),
[theme.dart](../apps/patient/lib/src/theme.dart) y los tokens de la landing en
[apps/landing/app/assets/theme.css](../apps/landing/app/assets/theme.css). Son
tokens equivalentes mantenidos por tecnología, no un generador compartido.
Actualizar las tres superficies cuando cambie la identidad global; usar
variables/ThemeData en lugar de nuevos colores dispersos. En la landing, los
colores decorativos también deben entrar en `theme.css`, no quedar en
`main.css` ni en SVG inline.
La configuración de tema oscuro en código no acredita un selector visible.

Verificar en navegador claro/oscuro si aplica, escritorio/móvil, foco de teclado,
contraste, texto de botones, carga, error y vacío. Mantener español UTF-8 con
acentos. Una tabla sin resultados debe permitir entender filtros o falta de datos;
un fallo de red/autenticación no debe mostrarse como catálogo vacío.

Cambios de presentación: typecheck/build/análisis y revisión visual según el
componente. Cambios funcionales: añadir o adaptar pruebas de comportamiento;
no escribir pruebas que sólo repitan valores CSS para una edición de color.

## Investigar un 401 o fallo de conexión del Admin

1. Identificar URL/método de la petición, estado y código de error seguro; comprobar
   si falla Auth, Worker o RPC. Comparar origen del navegador con CORS/allowlists.
2. Revisar que Admin y API apunten al mismo proyecto Supabase, sin imprimir valores
   secretos. Verificar configuración realmente cargada por el proceso.
3. Verificar sesión vigente y envío Bearer; después UUID en `ADMIN_USER_IDS`
   (lista separada por comas, sin corchetes) y factor TOTP verificado.
4. Revisar [auth.ts](../apps/admin/src/auth.ts) y la validación de Auth en
   [app.ts](../apps/api/src/app.ts). El Worker consulta `/auth/v1/user`; no existe
   un arreglo válido basado en consultar factores como una tabla PostgREST pública.
5. Distinguir el 401 de autorización del 403 por MFA insuficiente usando el código
   del error. No asumir que todo 401 significa que el usuario debe volver a entrar.
6. Tras editar variables locales reiniciar sólo el proceso identificado; comprobar
   salud, petición autenticada y rechazo de una petición sin autorización.

No pedir claves, códigos TOTP ni tokens por chat; no deshabilitar MFA para depurar.
Una sesión del navegador abierta no prueba que el Worker la acepte.

## Evolucionar base, API y despliegue

Preservar privilegios y contratos Worker/RPC/cliente. Para mutaciones relevantes
conservar validación, idempotencia y auditoría de actor. Comprobar migraciones
pendientes y orden antes de aplicar; cambios coordinados con Worker/scanner usan
la ventana y recuperación descritas en [seguridad](SECURITY_HARDENING_20260904.md).

Para cambios críticos, presentar la [propuesta](DECISIONS.md#cambios-críticos-y-aprobación)
con justificación, implicaciones, alternativas y recuperación, y esperar aprobación
explícita antes de ejecutarlos. Se puede preparar el diff aislado y diagnóstico.

Antes de desplegar preparar diff, comandos, entorno exacto, pruebas, dependencias,
configuración requerida y recuperación. Reusar autorización vigente que cubra esa
operación; si no existe, la aprobación es el último paso previo a publicar.
No inferirla del nombre `dev` ni de un despliegue anterior.

Después verificar el servicio publicado y su versión, salud, una búsqueda, límites
y rechazo de acceso no autorizado. Un build o un dry-run sólo verifican su alcance.
Documentar lo no verificable y conservar la versión previa; no prometer rollback de
datos por revertir únicamente el Worker.

## Construir una capacidad independiente: ejemplo landing

Una petición explícita de landing autoriza trabajar en esa capacidad sin esperar
a completar Puebla. Consultar identidad visual y arquitectura prevista, inspeccionar
si ya existe una implementación y definir el contenido dentro del encargo. Si aún
no existe, usar la arquitectura prevista como punto de partida sin instalar un
stack alternativo por preferencia personal. Verificar versiones soportadas antes
de iniciar un proyecto nuevo; no copiar una versión antigua del roadmap sin revisión.

Reutilizar marca/tokens, separar experiencia SEO de la aplicación Flutter, enlazar
destinos reales configurados y evitar promesas de cobertura no demostradas.
Probar responsive, accesibilidad, enlaces, metadata y build. Preparar publicación
según destino y autorización; construir una página no implica comprar un dominio
ni abrir automáticamente todos los servicios a usuarios externos.

## Cerrar y transferir trabajo

Actualizar [estado](CURRENT_STATE.md) si cambian capacidades/prioridades;
[decisiones](DECISIONS.md) si cambia una regla o arquitectura; esta guía si cambia
el procedimiento; [entorno](ENVIRONMENT.md) y ejemplos si cambia configuración.

Formato de traspaso material: objetivo → cambio → evidencia/entorno/fecha → límite
pendiente → siguiente acción. Registrar handles sólo mientras se confirma que
siguen vivos; una nota de “en ejecución” no acredita un proceso activo.
No actualizar documentos ajenos a la tarea ni añadir bitácora para cada typo.
