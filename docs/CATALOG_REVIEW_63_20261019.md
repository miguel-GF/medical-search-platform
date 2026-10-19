# Revisión 63: muestras explícitas y calificadores cortos

Actualización:19-oct-2026,12:32UTC. Investigación primaria original del18-oct
conservada con su fecha; relectura productiva e integración local del19-oct.

## Cambio local realizado

Se amplió el importador de revisiones para representar el código existente
**saliva** como sistema `Saliva`. La base ya tenía ese tipo activo desde agosto.
No se añadió una muestra, lexicon, migración ni función clínica remota.

Para un nuevo concepto salival se exigen atributos de muestra en cada objetivo
y un marcador literal saliva/salival en el campo RAW permitido. Se mantienen
las guardas de origen, conteos, colisiones, auditoría, política y aprobación.
El lector de ledger entiende el mismo sistema; no basta la existencia del alias.

Compilación sintáctica correcta. Los **53 lotes ya fijados en cola producen
exactamente los mismos bytes de SQL** antes/después. La rama adicional sólo se
genera para fixtures con saliva. El proceso ya abierto conserva sus módulos
anteriores; no se reinició ni se le encoló una fixture nueva de saliva.

## Fuentes y propuesta investigada

El agente conservó16RAW: ocho de cortisol en saliva y ocho de glutatión total
en sangre completa. Relectura productiva19-oct12:29:03UTC: ambos grupos seguían
pendientes;551 conceptos y774aliases.

Fuentes primarias capturadas el18-oct con cuerposHTTP200 yhash:

- [Labcorp500179](https://specialtytesting.labcorp.com/tests/500179/salivary-cortisol-lc-ms-ms): cortisol salival; no demuestra horario o técnica de Salud Digna.
- [Labcorp502124](https://www.labcorp.com/tests/502124/salivary-cortisol-four-specimens-ms-endocrine-sciences): orden específica de cuatro muestras, distinta del rótulo genérico.
- [Labcorp007700](https://www.labcorp.com/tests/007700/glutathione-total): glutatión total en sangre completa; no permite degradar esa muestra a sangre genérica.
- [LOINC91685-8](https://loinc.org/91685-8): no explicita total; no se asignó a la orden total de Salud Digna.

La captura directa de Mayo608409 respondió403 y se conservó separada de la
lectura web legible; no se presentó comoHTTP200 ni se trasladó su fracción
reducida o reporte por eritrocitos al glutatión total.

Sólo cortisol salival llegó a fixture preparada: muestra explícita conservada,
sin inferir hora, número de muestras, cortisona, método, unidad o fracción libre.
Glutatión total queda retenido: el registro de muestras tiene `blood` como
familia, pero no un código específico de sangre completa. No se usó NULL,
suero o eritrocitos para eludir esa limitación.

## Resultado: lote retenido antes de aplicar

La observación transaccional terminó conrollback. Se revisaron31 etiquetas,
incluido el nombre nominal correcto y30 contrastes. El alias del proveedor y
el nombre canónico resolvieron hacia el concepto propuesto, pero seis variantes
también lo seleccionaron pese a perder una condición explícita:

- Cortisol en saliva AM.
- Cortisol en saliva PM.
- Cortisol en saliva8AM.
- Cortisol en saliva x2.
- Cortisol en saliva x4.
- Cortisol en saliva LC MS MS.

No consta hora, serie o método en el RAW. Es el mismo tipo de pérdida de tokens
cortos que se observó conINR; un arreglo limitado aINR no cubriría estos casos.
Por eso **no se encoló ni aplicó** el borrador `20261019:01`.
No se activó ninguna modificación del resolvedor público.

La lectura independiente12:31:59UTC confirmó:

- Ledger `not_applied`,16RAW íntegros y registro de muestras idéntico.
- Cola53, sin entrada para este borrador.
- Resolvedor generalMD5 `067b7a2fe0826ccaa48ece0a5dfd8d1d`, sin cambio.
- **551 conceptos,4,073 pendientes,134 instituciones,218 ubicaciones,
  234 ofertas y112 migraciones**.

No se ejecutaron suites ni se aprobó una equivalencia por similitud. La extensión
del importador quedó preparada, pero la incorporación de este estudio necesita
resolver antes la pérdida de condiciones en el motor conformeD006.

## Evidencia y siguiente acción

Artefactos en
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-63-specimens-20261018/`:
informe del agente, fuentes y recibos originales, lectura nueva, definición,
compatibilidadSQL, observación rollback y lectura independiente de retención.
La fecha18 del directorio corresponde al inicio; los recibos del19 conservan
su fecha real. Fixture inmutable `database/data/reviewed-aliases-20261019-01.json`,
SHA256 `747a8ff9f89152cf35ea2a4fe33cd98a96541247d1f5a41c9d688980cdb8d6ef`.

Siguiente acción: ampliar la investigación de requisitos explícitos de la orden
para tratar INR, horarios, series y métodos abreviados de forma coherente antes
de pedir activación del cambio clínico. Mientras tanto puede continuar la
investigación de otros grupos y proveedores; el objetivo general no está cerrado.

## PWA: comprobación de estado del19-oct

El endpoint público `app-version.json` respondió200 con build
`f6361e0b0fe3a789486cc8dc4b79aeae31d9837f2f1d89c4685c6707913e3925`
yheadersno-store, igual al detector publicado el18-oct. No se observó un teléfono
físico ni se repitió el despliegue. Véase[actualizaciones PWA](PWA_UPDATES_20261018.md).
