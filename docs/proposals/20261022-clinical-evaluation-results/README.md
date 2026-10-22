# Evaluación autorizada: resultado y corrección preparada

## Qué se ejecutó

El usuario autorizó la evaluación con «adelante con el permiso no hay tema»,
después de la explicación D-006. Se registró autorización para el plan preparado
y se envió **una sola transacción** al proyecto productivo `ymtcmfgwuzdqtsbuvzqf`,
el 22-oct-2026 a las13:05:58UTC. No se reenvió ese SQL.

La evaluación falló con **SQLSTATE42804**: la clave foránea
`reviewed_panel_compositions_audit_event_id_fkey` no puede implementarse porque
el candidato declara UUID y `audit.events.id` es bigint. Se confirmó el tipo
real mediante una consulta de sólo lectura. El error se obtuvo de los logs de
esa misma sesión, no reproduciendo la escritura. Los filtros de atributos del
servicio de logs devolvieron error de backend; se usó una ventana de seis segundos
y se conservaron únicamente los eventos de la sesión identificada.

**No hay46observaciones clínicas completas ni una aprobación del algoritmo.**
La evaluación no importaba estudios nuevos y no cerró registros pendientes.
No se desplegó API/PWA ni se dejó activo el candidato.

## Recuperación comprobada

A las13:06:15UTC, un cliente independiente confirmó:

- Cero sesiones activas con el marcador del intento.
- Igualdad de funciones, permisos, relaciones, políticas, triggers y esquemas.
- Igualdad de los27grupos protegidos de datos, incluidos catálogo, identidades,
  ofertas, precios, disponibilidad, RAW públicos, crawler, auditorías y migraciones.
- Ninguna escritura de recuperación ni restauración de datos antiguos.

Las27funciones del guard de baseline coinciden además con la captura real previa.
El archivo histórico `outcome-uncertain.json` refleja el error del transporte en
ese momento; la inspección y el diagnóstico posteriores aclaran el resultado.
Se preserva, sin reescribirlo como si la ejecución hubiera sido exitosa.

## Corrección local preparada

La [diferencia revisable](correction.diff) hace sólo estos cambios:

1. Dos columnas `audit_event_id` pasan de UUID a bigint para referenciar la clave
   existente. No se modifica `audit.events`, su clave ni datos productivos.
2. Cuatro secciones internas dejaban lock_timeout5s y statement_timeout30s,
   sobreescribiendo los límites iniciales anunciados. Las ocho instrucciones
   quedan en250ms/10s. El intento ya realizado alcanzó una de esas secciones;
   esa diferencia del borrador original queda registrada aquí.

Los cuerpos de las29funciones clínicas, las cuatro tablas propuestas, las reglas
y los23casos de observación conservan su alcance. No se incluyó Gram, nuevos
manifiestos, protocolos aprobados o importaciones de estudios en esta corrección.

Preparador reproducible:
[prepare_clinical_audit_fk_correction.py](../../../database/scripts/prepare_clinical_audit_fk_correction.py).
No tiene acceso HTTP ni ejecuta SQL. Conserva el candidato original y genera
una nueva versión con hashes distintos.

## Qué se comprobó localmente

- **Claves foráneas:** PostgreSQL local12.22, instancia desechable en127.0.0.1,
  autenticación aleatoria y puerto independiente. El fragmento original reprodujo
  el error UUID/bigint; el corregido creó ambas tablas y terminó en ROLLBACK.
  El servidor se detuvo y se retiró su archivo de contraseña. Se usaron tablas
  padre vacías con los tipos de clave confirmados; esto no simula el catálogo
  completo ni certifica compatibilidad integral con producción17.6.
- **Sintaxis PostgreSQL17:** pglast7.21 con gramática17.7 analizó124sentencias
  del candidato,29cuerpos de función y4bloques anónimos, sin errores de gramática.
  La evaluación instrumentada también analizó173sentencias, con los mismos
 29cuerpos/4bloques. No valida dependencias de catálogo, comportamiento clínico,
  permisos efectivos de un usuario ni el recorrido HTTP.
- Se confirmaron por sólo lectura los tres tipos de clave externa relevantes:
  `audit.events.id` bigint; `core.provider_brands.id` y
  `health.services.catalog_item_id` UUID.

[Comprobador local de FK](../../../database/scripts/check_clinical_audit_fk_local.ps1) y
[comprobador de sintaxis](../../../database/scripts/check_clinical_candidate_syntax.py).
El parser se instaló sólo dentro del directorio local ignorado, sin dependencia
nueva en la aplicación. [Documentación del parser](https://pglast.readthedocs.io/en/v7/introduction.html).

## Siguiente evaluación concreta, aún sin enviar

Se preparó otro plan con23casos/46observaciones,29funciones y cuatro tablas,
reversión obligatoria y comprobación independiente mediante el mismo ejecutor.
Su ejemplo de autorización sigue enfalse y no existe un directorio de intento.

- SQL del candidato corregido SHA256:
  `22b9efd6a894690ab50a361fd243433d13fca1efac92fba8968e25b1050e59a1`.
- Plantilla de evaluación nueva SHA256:
  `b107d4b4819ab3f70447d8a567177038c0a4b581446c16f61cd906325aec2ff8`.
- Ejecutable sin cambios SHA256:
  `a3642b3e34bcafc25007752dbae95fc1ba3011d6e90f8aab0dc5fd41f350e927`.

La autorización anterior cubría un intento del plan anterior, ya terminado.
AGENTS/D-006 requieren aprobar este segundo intento con su corrección concreta;
no se registra como autorizado por suposición. Sigue existiendo riesgo de esperas
breves por bloqueos; los límites no son un tiempo máximo de toda la transacción.
No se solicita activación persistente o publicación. Alternativa: continuar
comprobaciones locales; no permiten declarar validación clínica completa.

## Evidencia local

Primer intento:
`collectors/artifacts/combined-clinical-evaluation-20261021-v2/attempt/`.
Conserva autorización, marcador, snapshot previo, inspección, diagnóstico de logs
acotado a la sesión y lectura del tipo real. Marcador:
`pruevia-eval-2c3bdec65a0d432e`.

Corrección:
`collectors/artifacts/combined-clinical-fk-correction-20261022/`.
Conserva SQL corregido, fragmentos original/corregido, logs y recibo local,
comprobaciones de sintaxis, tipos externos y subdirectorio `evaluation/` con el
nuevo plan. Los [recibos resumidos](evidence.json) no contienen órdenes de pacientes
ni credenciales. No ejecutar otra vez el plan original.
