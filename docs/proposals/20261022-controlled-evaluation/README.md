# Evaluación controlada preparada — 22 de octubre de 2026 UTC

**No ejecutada. Aprobación específica D-006 pendiente.** El paquete permite
observar el candidato combinado durante una sola transacción productiva que
termina en ROLLBACK. El objetivo de cobertura de Puebla sigue incompleto.

## Decisión concreta solicitada

Autorizar exclusivamente una ejecución del SQL de evaluación preparado contra
`ymtcmfgwuzdqtsbuvzqf`, proyecto productivo pese al nombrepruevia-dev.

- Candidato:29funciones y cuatro tablas propuestas de requisitos/paneles/imagen.
- Observaciones:23casos de catálogo, búsqueda/paquete y detalle de los cinco
  paneles históricos;46filas de observación, antes y después.
- El SQL termina obligatoriamente en ROLLBACK. Sin importaciones de estudios,
  composiciones aprobadas, cierres del crawler o publicación de API/PWA.
- SHA256 de la plantilla de evaluación:
  `7a862f2ebdd7799b3c61a58008dfbcefee2589af74fe2edee7245750d78e816d`.

AGENTS.md y [D-006](../../DECISIONS.md#cambios-críticos-y-aprobación) exigen
aprobación explícita antes de sustituir funciones que deciden coincidencias
clínicas en producción, incluso dentro de rollback. La instrucción general
de continuar no cubre ese cambio. La autorización de esta evaluación tampoco
autorizaría una activación persistente ni declararía correcto el algoritmo.

## Resultado ya preparado y revisable

El [ejecutor](../../../database/scripts/clinical_candidate_evaluation.py) ofrece:

1. `prepare`: genera SQL, plan, snapshot y ejemplo de autorización con
   approved_by_user=false. No consulta la base.
2. `capture-baseline`: captura únicamente el estado actual mediante un SELECT
   fijado por el código. No acepta un SQL de snapshot arbitrario.
3. `execute`: exige registro fiel de aprobación explícita para este proyecto,
   propósito, hashSQL y hash del ejecutor. Crea un único intento exclusivo antes
   del envío; no existe reintento automático del SQL.
4. `inspect`: consulta el mismo intento y comprueba estado con un cliente nuevo;
   nunca restaura funciones o datos desde una copia antigua.

La [diferencia de instrumentación](evaluation.diff) conserva el
[candidato combinado](../20261021-combined-clinical/README.md), agrega una tabla
temporal de observaciones y conserva ambos conjuntos en el único resultado
devuelto. Evita depender de que el API de consultas devuelva todos los SELECT
intermedios. El registro único final se obtiene antes de ROLLBACK; por sí solo
no acredita que ya se haya revertido. Eso se comprueba después independientemente.

La única sustitución de la plantilla al enviarla sería un identificador de
sesión generado con formato acotado. Sirve para localizar una evaluación que
continúe activa tras un timeout. Se registran hashes de plantilla y envío.

## Comprobación de recuperación

El [snapshot de sólo lectura](snapshot.sql) conserva definiciones completas,
permisos, propietarios y configuración de funciones de cinco esquemas;
relaciones/RLS, políticas, triggers y permisos de esquemas. Registra conteos y
huellas multiconjuntoMD5 de27grupos de datos: catálogo, identidades, ofertas,
precios, disponibilidad, fuentes, RAW de fuentes públicas, crawler, decisiones,
candidatos, observaciones públicas, auditorías de negocio y migraciones.
No extrae órdenes o entradas de pacientes. Las huellas son de comparación de
estado, no mecanismos de autorización.

Después del intento, un cliente independiente compara el snapshot protegido
completo y busca la sesión por su marcador. Sólo se registra estado restaurado
si no queda sesión marcada y ambos snapshots coinciden. Un error o timeout
conserva resultado incierto y permite únicamente inspeccionar; nunca reenvío
ciego. Una diferencia concurrente también impide declarar restauración, sin
sobrescribir cambios ajenos.

Lectura real ya realizada,22-oct04:53:33UTC:

- 127funciones y27grupos protegidos capturados correctamente.
- 205marcas,291sedes,563items de catálogo y112migraciones.
- Ningún directorio de intento creado ni aprobación registrada.

[Plan](plan.json) y [recibo de preparación](preparation-evidence.json) fijan
los hashes y el alcance. Los snapshots con definiciones completas se conservan
localmente, no se agregan a este documento.

## Riesgos, límites y alternativa

Reemplazar funciones y crear triggers puede mantener bloqueos durante el intento
y hacer esperar otras consultas. Se fijan lock_timeout250ms,
statement_timeout10s e idle_in_transaction_session_timeout15s; no constituyen
un límite total de toda la transacción. El timeout del transporte es120s:
si vence, se consulta la sesión y el estado; no se presupone que haya terminado.

Las tablas nuevas estarán vacías: las observaciones medirían también retención
de paneles sin manifiesto y de protocolos no revisados. El paquete no importa
los14RAW del piloto de tórax. Los cinco paneles históricos tienen un registro
de oferta activa; no se comprobó su visibilidad actual al paciente.

Son41invocacionesRPC por fase dentro de23sentencias de observación;82invocaciones
en total. No son46solicitudesHTTP. Las consultas se realizarían en la sesión
propietaria de Management API, no en
un recorrido HTTP/JWT ni una ejecución con role service_role. Se captura salida
para revisión manual, sin aserciones clínicas de aprobación ni suite completa
de contratos. No se añadieron o ejecutaron suites formales.

La lectura de preparación prueba el snapshot de estado; no prueba ejecución,
aceptación de PostgreSQL o corrección del SQL propuesto. No se invocó execute,
ni siquiera con el ejemplo falso. El registro de aprobación es una constancia:
el agente sólo debe crearlo después de una respuesta explícita del usuario.

Alternativa: conservar el motor actual y continuar incorporaciones ordinarias
con evidencia. No hay cambio remoto que recuperar ahora. Tras una evaluación
autorizada, ROLLBACK o desconexión deben descartar las modificaciones; el ejecutor
exige comprobarlo. Esta propuesta no incluye cancelación de otras sesiones,
rollback compensatorio ni publicación.

## Ubicación y continuidad

Paquete local vigente:
`collectors/artifacts/combined-clinical-evaluation-20261021-v2/`.
La preparación inicial sin sufijov2 quedó reemplazada porque cambió el fingerprint
del ejecutor; no debe utilizarse. El código rechaza esa divergencia.

La siguiente acción dependiente es la decisión D-006 sobre esta evaluación
concreta. Las incorporaciones ordinarias de datos siguen siendo independientes.
