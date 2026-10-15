# Decisiones vigentes y aprobación de cambios

Tipo: registro de reglas y decisiones. Establecido el 14-sep-2026.
Complementa [AGENTS](../AGENTS.md); no crea autorización para acciones externas.

## Cambios críticos y aprobación

Preferencia explícita del usuario: antes de cambios muy críticos, informar qué
implican, por qué se proponen y cómo se resolverían, y someterlos a aprobación.

Considerar crítico un cambio que pueda afectar seguridad/permisos, equivalencias
clínicas con riesgo de falsos resultados, datos persistentes de forma destructiva,
continuidad del servicio, contratos incompatibles, arquitectura principal,
exposición pública, privacidad o costos/obligaciones nuevos importantes. Incluye
reabrir documentos, relajar MFA/RLS, restaurar/borrar datos, migrar infraestructura
y abrir una versión a usuarios externos. Un cambio pequeño de código puede ser crítico.

No requieren aprobación adicional por esta regla los diagnósticos de sólo lectura,
documentación, correcciones visuales y arreglos rutinarios compatibles dentro de
la tarea autorizada. Una migración aditiva tampoco es automáticamente crítica:
evaluar permisos, bloqueos, volumen, reversibilidad y entorno; respetar la autorización
remota aplicable. Ante duda concreta de impacto, explicar esa duda al usuario.

Antes de ejecutar o activar un cambio crítico, presentar:

1. **Problema y evidencia:** qué falla o limita al producto, dónde y en qué entorno.
2. **Cambio propuesto y justificación:** qué se modifica y por qué esa solución.
3. **Impacto:** usuarios, datos, compatibilidad, disponibilidad y costos afectados.
4. **Riesgos y alternativas:** opción recomendada, alternativa viable y consecuencia
   de posponer, con incertidumbres explícitas.
5. **Ejecución y verificación:** pasos, alcance y pruebas que demostrarán el resultado.
6. **Recuperación:** cómo deshacer o corregir, límites y respaldo si es necesario.
7. **Aprobación solicitada:** decisión concreta que debe autorizar el usuario.

Esperar una respuesta explícita que cubra esa propuesta antes de ejecutarla.
“Continúa”, “mejora todo” o el permiso de un despliegue antiguo no autorizan por sí
solos un cambio crítico nuevo. Si ya existe aprobación explícita de la misma
propuesta y su alcance sigue igual, no volver a solicitarla. Si cambia materialmente,
presentar la diferencia y renovar aprobación.

Se puede investigar, preparar el diseño y un diff aislado o ensayo seguro sin
activar el cambio crítico. Explicar qué está preparado y qué espera aprobación;
no ejecutar primero y avisar después. Avanzar tareas independientes mientras tanto.

## Registro inicial

| ID | Decisión / fundamento | Estado y evidencia |
| --- | --- | --- |
| D-001 | Puebla primero; éxito medido por opciones útiles y recetas, no volumen RAW. | Vigente; objetivo del usuario. [Estado](CURRENT_STATE.md). |
| D-002 | Separar evidencia, catálogo y oferta; equivalencia clínica determinista/revisada. | Vigente; [arquitectura](01_ARQUITECTURA_CANONICA.md), [migraciones](../database/supabase/migrations). |
| D-003 | Flutter paciente, Vue Admin, Worker API, Supabase y collectors Python. | Implementación actual; [mapa](PROJECT_GUIDE.md). Cambiar stack principal requiere propuesta. |
| D-004 | Búsqueda pública sin cuenta; Admin/proveedor con autorización de servidor y AAL2. | Vigente; [seguridad](SECURITY_HARDENING_20260904.md), [rutas](../apps/api/src/app.ts). |
| D-005 | Identidad visual coherente y temas fáciles de modificar. | Preferencia del usuario; tokens separados CSS/Dart, coordinados manualmente. [Guía UI](WORK_GUIDE.md). |
| D-006 | Autonomía mixta con aprobación previa de cambios críticos. | Aprobado por el usuario en esta tarea; procedimiento arriba. |
| D-007 | Documentación breve de entrada, referencias por tarea y estado con evidencia. | Aprobado mediante “Implement the plan”; establecido en esta entrega. |
| D-008 | Dominio raíz para landing y subdominios para app/admin/API. | Organización vigente; no prueba compra ni DNS configurado. Landing base implementado localmente en `apps/landing`. |
| D-009 | Mantener HTTPS/RPC con frontera pública en Worker; llamadas normales RPC con clave de servidor. | Reconciliación de comportamiento ya existente, no cambio de seguridad en esta entrega. Reemplaza el uso histórico de clave pública para búsqueda del [ADR-001](ADR-001-WORKER-SUPABASE-REST.md). |
| D-010 | Detectar mantenimiento, discovery y escalabilidad con iniciativa, sin esperar recordatorios; conservar aprobación crítica. | Preferencia explícita del usuario en esta entrega. [Política y cadencias](CONTINUOUS_IMPROVEMENT.md); los jobs requieren implementación y verificación separadas. |
| D-011 | La vigilancia del core no bloquea tareas independientes solicitadas, como el landing; el encargo explícito tiene prioridad. | Aclaración del usuario en esta entrega. Escalar sólo dependencias reales y cambios críticos. [Guía](WORK_GUIDE.md#construir-una-capacidad-independiente-ejemplo-landing). |
| D-012 | La liberación de Puebla se decide por una puerta conjunta de datos, orígenes y publicación, no por el número de filas. | Propuesta no aprobada. Ver [ADR-002](ADR-002-RELEASE-PILOT-GATES.md); no autoriza compras, DNS, mappings ni deploy. |
| D-013 | La app pública de Pruevia se declara dirigida a adultos (18+) en Google Play, pero no activa `Restrict Minor Access`: no hay cuentas de paciente ni un bloqueo de edad en la consulta pública. La inscripción a la prueba cerrada de Android sí exige confirmar 18+. | Implementada localmente en el contrato de piloto, landing y formulario de testers; requiere revisión legal/configuración antes de activar la convocatoria. Un menor puede descargarla y ayudar a un familiar, sujeto a las reglas de su cuenta y dispositivo. |
| D-014 | El landing es la puerta pública: enlaza a la app web/PWA, al acceso separado de proveedores y a la prueba cerrada Android; el feedback de producto vive dentro de la app y llega al Admin. Soporte atiende acceso/operación, no recibe recetas por correo. | Implementado localmente como destinos y gates `PRUEVIA_*`. La publicación pacientes primero mantiene PWA/proveedores cerrados hasta completar sus requisitos; falta correo verificado y activación. |
| D-015 | La cohorte Android usa una meta operativa propia de 20 personas y 21 días. Se cierra el registro al llegar a 20, la invitación se libera para el grupo completo y el Día 1 sólo puede iniciar cuando 20 testers estén marcados como activos tras comprobar su opt-in en Google Play. | Aprobada explícitamente por el usuario y aplicada en DEV el 19-sep-2026. Es un margen de Pruevia, no se presenta como requisito de Google. La cohorte permanece cerrada en `0/20`; no se enviaron notificaciones y la entrega seguirá manual hasta configurar un canal real. |
| D-016 | Medir intención comercial mediante clics estructurados a agenda/estudio/sucursal/sitio, nunca mediante texto clínico. Admin ve agregados globales; cada proveedor ve únicamente agregados dentro de sus membresías activas y nunca IDs anónimos o competidores. | Aprobada explícitamente por el usuario y aplicada en DEV el 19-sep-2026 con consentimiento, validación de oferta y alcance de servidor. Contratos remotos: cohorte/clics `22/22` y privilegios `30/30`. Falta comprobar visualmente con sesiones reales. |
| D-017 | Mantener el lanzamiento patient-first en `pruevia.com.mx`, PWA en `app` y API en `api`; proveedores y reclutamiento Android permanecen cerrados. | El 24-sep-2026 el usuario autorizó y se completó el despliegue de Landing `d5cd3120-e60a-4a54-863e-2e0db4101e21`, PWA `303acaac-c5d0-4f39-a9ae-7e63ea1b5d31`, Admin privado `4b16c144-bca9-4518-91c7-514036130181` y API `f412ae67-dab4-4200-97b1-edb5027a1fc0`. Smoke: landing/PWA/manifest/SW/API `200`, Admin anónimo `302` a Access; Chrome móvil emulado confirmó PWA instalable y landing sin overflow. No hubo cambios de DNS/Access ni apertura de proveedores/piloto. |
| D-018 | Reducir la cola del crawler agrupando proveedor+etiqueta, reutilizar sólo exactos/aliases aprobados y mantener observaciones privadas separadas de equivalencias y ofertas. Fuzzy/LOINC sólo sugieren; un ID externo no se presume SKU estable. | [ADR-004](ADR-004-NORMALIZATION-AUTONOMY.md): cinco migraciones aditivas aplicadas; ledger `112/112`, contratos SQL `531/531`, API `150/150`. El cron exacto productivo sigue apagado (preview 25-sep: 0 elegibles); collectors comerciales apagados por política. DENUE mensual desplegado pero `DENUE_COLLECTION_ENABLED=false` y sin token secreto. No hubo scraping ni publicación automática de equivalencias/ofertas. |
| D-019 | La búsqueda pública no debe enviar a revisión interna términos de salud sin consentimiento explícito. | El 25-sep se detectó que producción había guardado consultas normalizadas `ambiguous`/`no_match` por `api_record_resolution_review` (sin texto original ni IP); conteo agregado previo: 11 filas, sin consultar su contenido. El aviso publicado no describía esa captura. El usuario autorizó tocar producción para completar el trabajo; se desplegó `PUBLIC_SEARCH_REVIEW_CAPTURE_ENABLED=false` en `pruevia-api` versión `c07c62a6-0c08-4226-a141-9f909e4445c8`, impidiendo nuevas capturas. API `150/150`, typecheck, `/health` `200`, CORS app `204` y origen ajeno `403`. No se borró el histórico; borrar o modificar esas filas requiere decisión explícita. Corregir el aviso para transparentar el periodo histórico antes de afirmar que nunca se guardaron consultas. Reactivar captura exige consentimiento explícito y aviso coherente. |

| D-020 | Pausar API, app y Admin en producción mientras se revisa el lanzamiento; mantener sólo el landing disponible. | Aprobado explícitamente por el usuario el 25-sep-2026. Desplegados API pausa `d8090ae6-dc38-4575-9cfe-0ced6b6826a9` (`503`, `crons=[]`), Patient `928c5957-4457-470f-b765-cd96a86e87ea` (redirect al landing), Admin `62fe579e-55d7-4021-bb7b-3c0c915989a0` (redirect tras Access) y Landing `fdbd3693-c018-4ef6-a02c-ce77cd15a6ca` (enlaces de app ocultos; indexación conservada). Smoke: landing `200`, CTA de app ausente, sitemap `200`, app `302`, API `503`, Admin anónimo `302` a Access. No se modificó DNS, Access, Supabase ni datos. Reanudar es un cambio crítico separado; versiones previas para recuperación: API `c07c62a6-0c08-4226-a141-9f909e4445c8`, Patient `303acaac-c5d0-4f39-a9ae-7e63ea1b5d31`, Admin `4b16c144-bca9-4518-91c7-514036130181`, Landing `d5cd3120-e60a-4a54-863e-2e0db4101e21`. Ver historial en [CURRENT_STATE](CURRENT_STATE.md). |

## Operación local delegada — 9-oct-2026

| ID | Decisión / fundamento | Estado y evidencia |
| --- | --- | --- |
| D-021 | Operación local con base productiva y crecimiento estatal de Puebla; el agente investiga fuentes y decide equivalencias terminológicas claras por evidencia, sin esperar confirmación rutinaria del operador. Conserva ambigüedad clínica, atribución, muestras y modalidades; no aprueba por fuzzy/IA aislada. | Autorización expresa en sesión 9-oct-2026. Corte 13-oct, 13:01 UTC: DENUE 13,747 establecimientos; 37 revisiones aplicadas, 309 aliases (286 globales/23 proveedor), 271 conceptos nuevos (60 con código de muestra; 209 desconocida y dos muestras literales sin código) y 2,286 filas cerradas; quedan 4,742 filas/860 grupos. Catálogo 460; 30 instituciones/65 sedes nuevas bajo trece revisiones de identidad; 68 marcas/152 ubicaciones y cero ofertas nuevas. Revisiones 34–37: 221 cierres, 50/50 consultas públicas y 11/11 internas de proveedor. SARS-CoV-2 y lactato reutilizan canónicos sin modificarlos. El preparador revalida RAW, identidad existente activa, colisiones, scope de proveedor, conteos, nombres canónicos globales y hashes. Giardia original 32 permanece sin aplicar; sustituta aplicada con guard conservado. Identidad 13 conserva dos websites NULL y evidencia/403/discrepancias separadas. Cola local: 31 entradas por hash; PID 2044/session 31415 existente, rollback/commit/ledger completos. Memoria v2: 309 aliases/328 contextos, 2,283 históricos reutilizables/tres campos desconocidos; planificación, sin aprobación automática de órdenes inéditas. Propuestas del resolver y muestras combinadas no activadas conforme D-006. No autoriza costos nuevos, licencias ajenas, contactos o reapertura pública. [Evidencia, límites y cortes históricos](PUEBLA_LOCAL_OPERATION_20261009.md). Complementa D-018 sin activar su cron. |
| D-022 | Reanudar el mismo proyecto Supabase productivo para la operación local autorizada; conservar la pausa de las superficies públicas de D-020. | Aprobación explícita del usuario el 9-oct-2026 para reanudar esa base. Proyecto `ymtcmfgwuzdqtsbuvzqf`, encontrado `INACTIVE`, restaurado por Management API y confirmado `ACTIVE_HEALTHY`; PostgreSQL 17.6 / 112 migraciones. No hubo nueva base, migración ni despliegue de Workers. [Operación](PUEBLA_LOCAL_OPERATION_20261009.md). |
| D-023 | Guardar en commits locales por sección los cambios terminados y revisados, preservando trabajo ajeno y diferenciando datos aplicados de propuestas. | Autorización expresa del usuario el 13-oct-2026 para commitear por secciones. Primeros commits: `8948671` herramientas locales y protección de hashes; `724e183` 45 fixtures históricas aplicadas. Los nuevos lotes se incluyen tras confirmar sus recibos; las propuestas críticas conservan su estado sin activar. No amplía permisos de push, publicación o despliegue. [Cierre y evidencia](PUEBLA_LOCAL_OPERATION_20261009.md). |

## Privacidad y reapertura — 15-oct-2026

| ID | Decisión / fundamento | Estado y evidencia |
| --- | --- | --- |
| D-024 | Reabrir landing/enlace de paciente, PWA y API con la misma base después de actualizar privacidad; recordatorio por navegador durante 180 días, sin identificar por IP ni asumir lectura o consentimiento médico. | Autorización explícita del usuario en esta sesión para volver a levantar la app en producción con su base y entregar documentación/PDF al abogado. Publicado 15-oct 12:25 UTC: landing `18d3718c-1e45-4054-8859-26bf6c25c6ca`, API `72bc81ed-f6a5-4dde-a834-15ae2dc30b63`, Patient `5bda3d31-f3b4-4fae-8f07-41c8339c5350`. D-020 se reemplaza sólo para API/Paciente; Admin sigue pausado. Captura D-019 y analítica false, sin crons; proveedores/documentos/feedback/testers cerrados. Sin nueva DB, migraciones, borrado histórico o reactivación de finalidades opcionales. La publicación no acredita aprobación jurídica. [Evidencia y recuperación](PRIVACY_PUBLICATION_20261015.md). |

## Cómo registrar o reemplazar una decisión

Crear una entrada con ID estable, fecha, estado (`propuesta`, `aprobada`,
`implementada`, `reemplazada`), contexto, decisión, motivo, alternativas relevantes,
impacto y verificación. Para críticas añadir alcance exacto de aprobación y
referencia/fecha de la instrucción del usuario, sin transcribir secretos ni datos
personales. No registrar como aprobada una suposición del agente.

Usar esta tabla para decisiones breves; para una decisión extensa crear un ADR
en docs y enlazarlo aquí. Conservar [ADR-001](ADR-001-WORKER-SUPABASE-REST.md).
Al reemplazar una decisión, enlazar su sucesora y actualizar los documentos
normativos afectados. No borrar motivos históricos útiles ni exigir ADR para un typo.
