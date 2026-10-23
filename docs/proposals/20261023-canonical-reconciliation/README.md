# Reconciliación de 16 nombres rechazados: resultado local

**Evaluada en local, no activada en producción.** Continúa la
[comparación de identidad explícita](../20261023-explicit-identity/README.md).

## Evidencia que permite corregir los atributos

El recolector Ruiz completo terminó el23-oct-2026 con **4,617 registros válidos**:
15 identidades de sede y4,602 registros de estudio/precio de la zona configurada.
La comparación con la captura del15-sep conserva los mismos identificadores y
precios: cero añadidos, ausentes o diferencias de precio. No hubo ingestión remota.

Los15 títulos de imagen investigados aparecen exactamente una vez en el catálogo
oficial actual, conservan alias Ruiz aprobado y coinciden con el nombre canónico
activo. Los IDs, URLs y hashes de esos registros están en `preparation.json`.
El preparador no acepta una coincidencia fuzzy ni un título distinto.

T3 libre conserva el concepto y componente aprobados en la revisión
`20261011:02`. Se reconsultó la [referencia primaria de Mayo](https://www.mayocliniclabs.com/test-catalog/Overview/621815),
que identifica la fracción libre. No se transfieren muestra, método ni otros
atributos de ese laboratorio a los proveedores locales.

## Cambio ensayado

- 15 servicios de imagen: modalidad escrita por el departamento oficial.
- 12 de ellos: `contrast_mode=with` porque el título declara con contraste.
- 9 de ellos: lateralidad explícita derecha, izquierda o bilateral.
- 3 relaciones anatómicas para extremidades/miembros superiores o inferiores,
  usando los códigos existentes. No se inventan regiones nuevas.
- 3 frases de T3 libre: restricción positiva al componente aprobado
  `Triiodothyronine.free` en lugar de un tipo de servicio imposible.
- Soporte de comparación/conflicto de componente en el resolvedor base: coincide
  con las tres líneas de la [propuesta del11-oct](../20261011-free-t3-component-constraint.md).
- Se conservan las guardas literales y la identidad explícita de v3/v4/v6.

Se cambian cuatro funciones en la instancia local: base,v3,v4,v6. Una conexión
independiente de sólo lectura comprobó sus MD5 y las tres restricciones positivas.
El campo antiguo `replaced_local_functions=3` del recibo inicial cuenta sólo las
tres sustituciones de requisitos; la inspección independiente acredita las cuatro.
El ejecutor ahora registra esa diferencia directamente para futuras ejecuciones.

El SQL conserva una guarda que exige la sesión local marcada y conexión loopback.
**No es una migración ni SQL aprobado para producción.** No cambia identidades,
aliases, composición, métodos, muestra, duración, códigosLOINC, ofertas o precios.
Los atributos no expresados por las fuentes no se completan.

## Evaluación terminada

Exportación nueva de16 tablas públicas de catálogo, siete funciones reales y
4,045 pendientes; comparación de todos sus campos importados. PostgreSQL17.6.
744 grupos pendientes,564 nombres principales,24 controles generales y86 controles
adicionales: **2,162 invocaciones por fase,4,324 en total**.

| Medida | Antes | Después local |
| --- | ---: | ---: |
| Nombres principales con selección única del ID correcto |548 /564|564 /564|
| Nombres principales ausentes |16|0|
| Nombres principales con selección resuelta de otro ID |0|0|
| Controles adicionales que satisfacen su condición |84 /86|86 /86|
| Observaciones resueltas por word_fuzzy en el conjunto completo |28|0|

Los controles incluyen T3 libre frente a T3 total/reversa,T4 libre,captación,
orina,negación y serie; además lado contrario, sin contraste y contraste combinado
para las identidades revisadas. Una respuesta vacía satisface un control negativo,
pero no se presenta como cobertura positiva. Los dos controles que fallaban antes
eran precisamente las dos búsquedas positivas de T3 libre.

Los4,045 pendientes **no se cerraron**. En la variante quedan72 filas con propuestas
ambiguas y3,973 sin resultado, por cada alcance observado. Resolver nombres ya
incorporados no equivale a aprobar equivalencias nuevas del backlog.

## Límites, recuperación y siguiente acción

El servidor se detuvo y se retiró su archivo de contraseña al terminar.
No hubo conexiones remotas del ejecutor, cambios productivos o suites de otras apps.
No reproduce restricciones/índices completos,RLS,JWT,geografía ni el recorridoHTTP;
no valida los envoltorios nuevos de paneles/imagen. No acredita una integración
clínica completa por tener todos los nombres del catálogo reconocidos.

Preparador: `database/scripts/prepare_clinical_reconciliation_local.py`.
El SQL y controles de este directorio reproducen el ensayo con el ejecutor local.
Primera preparación se detuvo antes de escribir archivos porque el delimitador
final del draft histórico separaba el punto y coma en otra línea; se corrigió
la extracción y se exigió igualdad con la propuesta original. No se repitió SQL.

Artefactos: `collectors/artifacts/clinical-core-reconciled-local-20261023/`, con
exportación, `reconciliation-v1/` y `reconciled-v1-runtime-pg17/`; resumen,
observaciones y apagado completos. Fuente Ruiz:
`collectors/artifacts/ruiz-refresh-20261023/ruiz-puebla/8de158da-1cab-4a96-96bd-f2cb5cce8768/`.
`evidence.json` conserva métricas,inspección,apagado y hashes sin credenciales.

Siguiente acción: componer la propuesta con los consumidores públicos y preparar
su comprobación con reversión y snapshot ampliado del lexicón. Una activación
persistente cambia decisiones clínicas compartidas y requiere el alcance concreto
de D-006; este ensayo no sustituye esa aprobación ni el recorrido real del servidor.
