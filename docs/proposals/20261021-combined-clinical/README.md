# Candidato combinado: requisitos, paneles e imagen

21-oct local /22-oct-2026 UTC. **Preparado, no aplicado. Requiere aprobación
D-006 antes de cualquier evaluación que sustituya funciones productivas.**
No hay migración activa, importación, cambios del watcher o despliegue.

## Cambio concreto preparado

[SQL propuesto con ROLLBACK](combined-ROLLBACK-PROPOSED.sql), SHA256:
`2b0cb7cbdb72fb92f7f7388d69e96a7f0450db8ef6e76259a327cf3c50c15cad`.

Combina29definiciones de funciones y cuatro tablas propuestas en una transacción
que termina obligatoriamente en ROLLBACK. No contiene COMMIT ni importador.
Reemplazaría diez funciones existentes y crearía19helpers, sin insertar estudios,
aliases, composiciones aprobadas, ofertas o decisiones del crawler.

El orden conserva las tres reglas propuestas:

1. Requisitos textuales: v3/v4 y la base privada de v6 conservan todos los tokens
   de contenido, incluidos calificadores cortos. Una poda no promueve al único
   superviviente a resuelto. Esto es conservador y puede perder sinónimos válidos;
   no constituye una interpretación completa de negación, dosis o composición.
2. Paneles: v6 incorpora el filtro de composición, utilizando la versión más
   reciente del registro con auditoría inmutable y cuarentena. El estado clínico
   debe corresponder al manifiesto; desconocidos no significan compatibilidad.
3. Imagen: v7 recibe la salida anterior y contrasta el protocolo acotado de tórax.
   Los consumidores de búsqueda y paquete se encaminan a v7. Las vistas no se
   convierten en un número de exposiciones ni se infiere contraste ausente.

La función de paquete incorpora ambos filtros y conserva correspondencia con
los originales por índice. No se concatenan reemplazos que borren la regla del
otro borrador. La matriz de permisos usa la firma real de ocho argumentos del
decorador de paquete, incluidos origenOCR y array de originales.

## Evidencia de base y permisos

Se consultaron16funciones de entrada y sus permisos actuales. Después se leyó
el snapshot de127funciones en public/catalog/health/core/ingest. El recorrido
textual de llamadas calificadas detectó22funciones afectadas y una cadena de
27definiciones que se fija por fingerprint antes de modificar el candidato.
Es una inspección textual, no prueba exhaustiva de SQL dinámico, llamadas sin
calificar u otros esquemas. [Recibos y matriz](evidence.json).

Las27funciones existentes conservan propietario, ACL, security_definer y
configuración; sus cuerpos no sustituidos se comprueban también al final.
Se omitieron los REVOKE/GRANT antiguos de los wrappers porque no coincidían con
la frontera actual de permisos. Los19helpers nuevos tienen una matriz explícita:
acceso de propietario o service_role según necesidad; ningún acceso anon,
authenticated o PUBLIC. Privilegios inesperados hacen abortar el borrador.

Las cuatro tablas y los nombres de helpers deben estar ausentes antes de
instalar. Se preservan RLS y las guardas de auditoría. Los fingerprints y
permisos se comprobarían de nuevo en la propia transacción; un cambio posterior
del entorno invalida este candidato.

## API candidata

Los parches [app](app.ts.patch), [batch](batch.ts.patch) y [types](types.ts.patch)
se prepararon sobre el paquete congelado `search-flow-20261020/api-release-typo`,
que ya contiene selección explícita y corrección de sugerencias. **Ese paquete
base no está publicado.** Sus diez módulos se cotejaron por hash: sólo cambian
app/batch/types; los otros siete conservan sus bytes.

- El flag IMAGING_PROTOCOL_PILOT_ENABLED sigue ausente de la configuración.
- Una selección manual en el piloto exige que el RPC de protocolo confirme
  ese mismo estudio; no puede saltar una proyección incompatible o desconocida.
- Los originales se conservan antes de preparación, segmentación y corrección.
  Los paquetesOCR pasan por el decorador cuando el flag está habilitado.
- TypeScript terminó0. No se observó ejecución de RPC, SQL, paqueteOCR o navegador.

Se conservó cada línea no modificada incluso cuando la base tenía finales de
línea mixtos. El primer intento de preparar API se detuvo por esa diferencia
antes de generar el candidato o acceder a la base; la corrección fue local.
El código raíz del API y su configuración activa no se modificaron.

## Impacto comprobado y riesgos

Lectura22-oct04:35:47UTC: existen cinco lab_panel históricos, con **una oferta
activa** en conjunto. El registro propuesto comienza vacío: esos paneles
quedarían sin resolución/ofertas compatibles hasta revisar su composición.
No se desactiva o elimina la oferta; se retendría su exposición mediante estos
filtros. La aprobación de una activación futura debe cubrir expresamente ese
efecto. Es un registro activo en supply.offers: no se verificó aquí si se muestra
actualmente al paciente. El conteo no demuestra disponibilidad o impacto comercial.

Para imagen, instalar un registro vacío también puede retirar coincidencias
torácicas nominales que no tengan protocolo revisado. Este candidato no importa
los14registros del piloto ni resuelve los2,263pendientes de categorías de imagen.
No es una liberación completa ni debe ejecutarse como una migración preparada.

La cadena literal puede producir falsos negativos y no sustituye una política
semántica completa. El filtrado después del límite puede reducir resultados.
La comprobación de tipos no demuestra que PostgreSQL acepte o ejecute el SQL.
No se añadieron ni ejecutaron suites formales.

## Evaluación propuesta, pendiente de autorización

Destino: proyecto `ymtcmfgwuzdqtsbuvzqf`, productivo pese al nombrepruevia-dev.
La única evaluación contemplada ahora acaba con ROLLBACK, sin persistencia,
importación o publicación. El archivo fija lock_timeout250ms,
statement_timeout10s e idle_in_transaction_session_timeout15s. Son límites por
operación/inactividad, no un límite total; podrían existir bloqueos breves y
esperas de consultas públicas durante el intento.

El [paquete de evaluación controlada](../20261022-controlled-evaluation/README.md)
ya prepara observaciones antes/después y transporte de intento único, sin ejecutar
el SQL. Requiere aprobación específica. Se comprobarían después, con
cliente independiente, definiciones completas, permisos, tablas, contadores y
fuentes intactos. Si el resultado fuera incierto, sólo lectura; nunca reenvío
ciego. El archivo combinado por sí solo no contiene esas observaciones; están
en la plantilla de evaluación fijada por el plan nuevo.

Alternativa vigente: conservar la base actual y continuar datos ordinarios.
Nada requiere recuperación ahora: sólo hay archivos aislados. En una evaluación,
ROLLBACK/desconexión descarta cambios; debe confirmarse independientemente.
Una activación persistente necesita otro paquete final, importadores compatibles,
verificación, recuperación y aprobación propios. El flagAPI no revierte los
cambios globales SQL.

## Continuidad y entregables

Artefactos, generadores, snapshots y logs:
`collectors/artifacts/combined-clinical-candidate-20261021/`.
Única versión SQL vigente del candidato: `combined-v5-ROLLBACK-PROPOSED.sql`.
La salida se escribe como bytesUTF-8 para que Windows no cambie su hash mediante
conversión de finales de línea. La discrepancia del borradorv4 se detectó antes
de copiarlo al paquete versionado o enviar SQL.
Los borradoresv1/v2/v3/v4 se conservan como evidencia local, no son ejecutables
autorizados. El anterior archivo de evaluación de tres funciones también queda
retirado por falta de terminadores entre definiciones; nunca se envió.

Siguiente trabajo: obtener la decisión específica D-006 sobre la evaluación
acotada ya preparada. Aún no se solicita activar este
SQL ni desplegar la API. Para producción faltan integrar el Patient actualizado,
los importadores y los casos completos de panel, requisitos, imagen y recetas.
