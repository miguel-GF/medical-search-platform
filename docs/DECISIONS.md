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
