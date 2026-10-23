# Reparación del reconocimiento publicada — 23 de octubre de 2026

## Alcance autorizado

El usuario confirmó que la base local enlazada es la misma de producción y dio
permiso para publicar. Se acotó la operación a la reparación descrita y ensayada:
cuatro funciones del resolvedor, atributos expresos de 15 estudios de imagen,
tres relaciones anatómicas y tres restricciones positivas de T3 libre.
La expansión del catálogo sigue pausada. Este permiso no activa la propuesta
anterior de 29 funciones, registros de paneles o protocolos nuevos.

## Qué cambia para quien busca

Los nombres completos de los 15 estudios de imagen afectados conservan contraste,
modalidad, lado y región expresados por sus fuentes. T3 libre se distingue por
su componente aprobado. Una semejanza de palabras propone opciones; por sí sola
no confirma una variante clínica que la persona no escribió.

No se incorporaron conceptos, aliases, proveedores, ofertas o precios. Los
4,045 registros pendientes conservan su situación. El trabajo recupera el
reconocimiento de conceptos existentes, sin acreditar disponibilidad comercial
de cada uno de ellos.

## Comprobación y aplicación reales

- Proyecto compartido: `ymtcmfgwuzdqtsbuvzqf`, nombre `pruevia-dev`.
- Evaluación enviada una sola vez, terminada en `ROLLBACK`: 256 observaciones,
  128 casos antes y después. Los 101 controles clínicos especificados pasaron;
  se capturaron 27 respuestas de búsqueda y paquete por fase.
- A las 13:24:15 UTC, una conexión independiente confirmó igualdad completa
  de funciones, permisos, configuración, políticas y 33 grupos de datos
  protegidos, sin sesión de evaluación activa. No hubo reenvío del SQL.
- Aplicación persistente enviada una sola vez: migración
  `20261023160000_clinical_identity_canonical_reconciliation.sql`, número 115.
- A las 13:26:10 UTC, una conexión independiente confirmó el ledger, las cuatro
  sustituciones y exclusivamente los grupos de datos previstos. Propietarios,
  permisos, configuración de funciones, relaciones, triggers y políticas iguales.
- Auditoría: `catalog.clinical_reconciliation_approved`, solicitud
  `canonical-reconciliation-20261023`, con datos anteriores/posteriores y
  referencia al permiso y al respaldo de funciones.
- Comprobación posterior: **564/564 nombres completos** seleccionan el ID
  correcto en el núcleo productivo. **30/30 comprobaciones HTTP** satisfechas:
  27 búsquedas y tres selecciones explícitas de candidatos de hemática,
  biometría y electro. Los 16 nombres afectados devuelven la identidad prevista;
  no se presentan renina, Plasmodium, INR añadido o x2 como variante confirmada.
- Inventario posterior: **207 marcas,293 sedes,564 conceptos,234 ofertas**,
  115 migraciones y una auditoría de esta aplicación.

El primer evaluador HTTP supuso que todas las respuestas incluían
`resolution_status`. La respuesta histórica con ofertas omite ese campo opcional;
los 15 estudios de imagen sí estaban presentes con el ID exacto. Se corrigió
la comprobación para exigir identidad exacta y validar cualquier estado expreso.
Se reevaluaron las mismas respuestas reales guardadas: cero peticiones nuevas,
sin cambiar la API y conservando el informe inicial. Resultado definitivo:
`public-verification/summary-reassessed.json`.

Estas comprobaciones son observaciones y aserciones reales sobre la base
compartida; no se presentan como una ejecución de toda la suite de contratos.
La comparación local previa de 4,324 invocaciones conserva sus límites y evidencia
en la [propuesta histórica](proposals/20261023-canonical-reconciliation/README.md).

## Evidencia y recuperación

Artefacto inmutable de esta operación:
`collectors/artifacts/canonical-reconciliation-release-20261023-v1/`.
Incluye plan, hashes, autorización, snapshots, SQL efectivamente enviado,
respuestas completas y evaluación de cada control. No contiene credenciales
ni registros de pacientes.

Preparación/evaluación/aplicación:
`database/scripts/release_clinical_reconciliation.py`.
Verificación posterior de catálogo y HTTP:
`database/scripts/verify_clinical_reconciliation_release.py`.

Se conservan las cuatro definiciones originales y los datos anteriores en
auditoría. `recovery-v2-PREPARED-DO-NOT-AUTO-RUN.sql` verifica que las funciones,
servicios, frases y anatomía no hayan cambiado antes de restaurar el alcance.
Es una recuperación preparada, no ejecutada. Debe revisarse y registrarse como
una migración nueva; no se borra la migración aplicada ni la auditoría original.
La versión inicial de recuperación también se preserva como evidencia histórica.

Una respuesta incierta exige consultar el ledger y el estado protegido. Los
ejecutores crean el marcador de intento antes de enviar SQL y rechazan repetir
el mismo intento; no se usa un reenvío para averiguar qué sucedió.

## Hallazgo comercial independiente que queda pendiente

Se preservó un comparador de sólo lectura de identidades de origen y precios:
`database/scripts/compare_current_source_prices.py`. Su ejecución previa comparó
691 filas de precio/alcance de 234 ofertas: 369 importes iguales, 321 sin fuente
emparejada y una diferencia que necesita revisión. No publicó precios ni tomó
una ausencia de fuente como ausencia de oferta.

La diferencia es mastografía de Salud Digna Municipio Libre: precio guardado
$285 y captura oficial reciente $250, mismo ID de origen. Debe revisarse y
registrarse con sus condiciones, vigencia y alcance antes de actualizarse.
La expansión pausada no se reanudó para aplicar ese hallazgo.

Siguiente acción: conservar el corte; retomar los pendientes y el bloque de
capturas nuevas únicamente cuando el usuario reanude esa tarea.
