# Propuesta: observar la corrección de calificadores con rollback

21-oct-2026,05:37UTC. **Preparada; no ejecutada. Requiere aprobación D-006.**

## Problema y evidencia

En el catálogo productivo, `Biometría hemática INR` y `Biometría hemática x2`
devuelven la biometría simple con34ofertas. La API local llega a ready/complete.
Trigo y CélulasLE siguen retenidos porque sufren pérdidas similares. Véase
[diagnóstico de consumidores](20261021-requirements-consumer-review.md).

## Cambio que se propone evaluar

En una única transacción contra el proyecto `ymtcmfgwuzdqtsbuvzqf`, comparar11
consultas existentes antes/después del diff aislado de tres funciones
`catalog.resolve_items_v3/v4/v6`. El diff exige presencia literal normalizada
de todos los tokens de contenido de la consulta en el término coincidente y
conserva ambiguous cuando se podan candidatos. Incluye palabras cortas como INR
o x2 y ramas exact/alias. No modifica equivalencias ni aprueba registros pendientes.

La transacción termina obligatoriamente en **ROLLBACK**, sin COMMIT. La aprobación
solicitada cubre sólo esta observación, no activación persistente o publicación.

## Impacto, riesgo y alternativa

No se modifican datos de pacientes, ofertas, precios, fuentes, permisos o migraciones.
Los cambios de funciones no se publican mediante COMMIT y se revierten con la
transacción. El servidor podría necesitar bloqueos breves de catálogo; lock_timeout
250ms evita esperar más por un bloqueo, statement_timeout10s limita cada sentencia
y idle_in_transaction_session_timeout15s limita una transacción inactiva. Estos
límites no constituyen un límite total de toda la transacción ni garantizan cero
interferencia. Un fallo debe abortar el intento; no repetirlo automáticamente.

El predicado puede perder sinónimos y tolerancia a errores, incluso cuando la orden
sea válida. Tampoco demuestra por sí solo semántica de negación, cocientes,
composición o condiciones específicas ausentes de la consulta. La evaluación mide
casos concretos; no acredita todos los contratos ni autorización para producción.

Alternativa: continuar sólo investigación y datos claros, manteniendo el motor
actual y las retenciones. Una simulación textual local sirve para estimar tokens
ausentes, pero no prueba la interacción real v3/v4/v6/RPC. Posponer conserva el
defecto observado en los casos anteriores.

## Ejecución y comprobación propuestas

1. Comprobar proyecto enlazado, hashes del paquete, definiciones y permisos actuales;
   rechazar cualquier divergencia respecto a la base capturada.
2. Ejecutar una sola vez el SQL preparado: observación previa, tres reemplazos,
   observación posterior y rollback. No hay fixtures nuevas ni recolección OCR.
3. Comparar consulta/candidatos/estado/ofertas de búsqueda y paquete. Las11consultas
   incluyen biometría sola, INR/x2, hematica, biometria, orina, sangre, electro,
   electrocardiograma, IgEgluten y negación. Es una primera observación acotada;
   no sustituye corpora, contratos, medición de latencia o inspección de Worker final.
4. Con un cliente nuevo, comprobar las tres definiciones completas, ACL, propietario,
   configuración, contadores y fuentes iguales al corte inmediatamente previo.
   Si el resultado del envío es incierto, investigar únicamente por lectura.

## Recuperación y límites

Ahora no hay nada que revertir: el SQL no se ha enviado. Durante la observación,
ROLLBACK o desconexión deben descartar las modificaciones transaccionales.
Después se confirma su ausencia independientemente. Si se encuentra divergencia,
no sobrescribir cambios ajenos con un snapshot viejo; diagnosticar primero.
La copia completa previa se conserva para comparar, no como permiso de restauración
ciega. La publicación futura necesita una propuesta final, contratos y aprobación propia.

## Artefacto concreto y decisión solicitada

SQL preparado ignorado:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/requirements-consumers-20261021/evaluation-rollback.sql`.
SHA256 `4e7ccfe80701710acd3fc6dd0e6014f90efce26356545ad27d08ff91f67347fe`.
Junto a él: `prepare_evaluation.py`, `evaluation-prepared.json`,
`evaluation-definitions-before.json` y baseline. Preparador sólo ejecutó SELECT.

**Autorizar esta evaluación acotada con rollback.** AGENTS.md y D-006 exigen
aprobación explícita antes de ejecutar un cambio de aceptación clínica compartida;
la instrucción general de continuar no la reemplaza. Mientras se espera, las
incorporaciones terminológicas y de establecimientos claras siguen independientes.
