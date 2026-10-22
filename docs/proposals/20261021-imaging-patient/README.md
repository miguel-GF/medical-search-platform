# Imagen: base publicada de Patient recuperada

Propuesta D-006 aislada.21-oct local /22-oct-2026 UTC. **Sin activación,
despliegue ni escrituras SQL.** Cierra la brecha de procedencia de fuentes del
candidato Flutter documentada el16-oct; no completa toda la integración clínica.

## Evidencia nueva

Los recibos de móvil y PWA del18-oct conservaban30 hashes de entradas de runtime:
fuentes Dart, shell web, pubspec/lock y herramientas de estampación. Se buscaron
bytes idénticos en Git y en archivos locales: todas las entradas se recuperaron,
incluido el conjunto completo de archivos Dart de lib. La procedencia de cada
archivo y cualquier transformación de saltos de línea están fijadas en
[source-provenance.json](source-provenance.json). No se supone que un único commit
represente aquel árbol de publicación.

Lecturas HTTPS nativas de Windows, sin alterar TLS:

- 22-oct04:09:55 UTC: `app-version.json` público HTTP200, build
  `f6361e0b0fe3a789486cc8dc4b79aeae31d9837f2f1d89c4685c6707913e3925`.
- 22-oct04:11:25 UTC: `main.dart.js` público HTTP200, SHA256
  `8a04162ed051a9ef42a0069417db465ede470831df9f0c8f32687db542681aaa`,
  idéntico al bundle del recibo publicado y al hash anunciado por el manifiesto.

El intento anterior mediante webtool no pudo acceder al manifiesto; se conserva
separado del resultado nativo200. No se reconsultó el UUID de despliegue del Worker:
el identificador2e1e136b del manifiesto de procedencia es histórico. La evidencia
actual verifica contenido servido, no afirma una consulta de Management API.

## Diff concreto

El candidato se construyó en otra carpeta. Sólo dos archivos de la base
recuperada cambian:

1. [models.dart.patch](models.dart.patch): reconocer guía de imagen únicamente
   con kind `imaging_projection` y specimen `imaging`; conservar las condiciones
   y límites existentes de las guías de sangre/orina.
2. [main.dart.patch](main.dart.patch): explicar que las proyecciones requieren
   confirmación y no se sustituyen entre sí. Las opciones conservan la acción
   explícita de búsqueda; no se añade una selección automática.

El resto de archivos del candidato conserva bytes idénticos a la base recuperada.
Se mantienen las fuentes del tema, shell de PWA, privacidad y demás entradas
publicadas. Los templates auxiliares del proyecto parten de36f6a80 y no tienen
la misma prueba de hash contra el release; se distinguen de las30 entradas
recuperadas. No se afirma reproducción binaria del compilador histórico.

Este candidato parte de la versión pública, no del HEAD actual: las mejoras de
selección y navegación móvil del20-oct siguen en su paquete local separado.
Una integración futura deberá conservar ambos cambios y presentar su alcance
combinado. No reemplazar las fuentes activas por esta carpeta ni desplegarla
como si incorporara todas las correcciones posteriores.

## Comprobación y límites

Análisis dirigido de ambos archivos: salida0, sin hallazgos. Compilación release:
salida0,117.4s; feedback, analítica, portal proveedor y reservas deshabilitados.
Las124entradas de fuente del candidato permanecieron sin cambios durante el build.
La estampación PWA también terminó0: manifiesto, HTML y hashJS coinciden; headers
generados con el hostAPI autorizado. Recibos en [build-evidence.json](build-evidence.json).

Bundle candidato SHA256
`d71279b2614cf25a6b10a6b99965dd068f1a45d6fec82df47b1c96a2b23eda07`;
build candidato `9712b597dff75014655ee2775540aa7d65dfa895e40bf35308b256d263cc46cc`.
Son artefactos locales; no identifican una versión pública desplegada.

La compilación no acredita
la cadena SQL/API/OCR ni el comportamiento del nuevo mensaje en un navegador.
No se añadieron o ejecutaron suites formales. Los recibos finales de compilación
y estampación están junto al candidato, sin sustituir intentos anteriores.

Artefactos locales:
`collectors/artifacts/proposal-imaging-protocols-20261015/patient-source-recovery-20261021/`.
Incluyen scripts de recuperación, parches, fuentes recuperadas/candidatas,
manifiestos por archivo, lecturas HTTPS y logs de compilación.

## Lo que sigue pendiente

- Completar el candidato combinado de API/SQL con paneles y conservación de
  requisitos; comprobar sus bases actuales y los consumidores reales.
- Observar la integración con PostgreSQL, paquete/OCR y navegador dentro del
  alcance autorizado; ninguna consulta de esta tarea sustituyó funciones remotas.
- Presentar cambio final, impacto, riesgos, alternativas, verificación y
  recuperación antes de solicitar aprobación de activación D-006.

No se aprobaron equivalencias nuevas ni se cerraron los14 registros del piloto
por recuperar fuentes. Los2,263 pendientes en categorías de imagen tampoco
quedan cubiertos por un piloto de dos títulos de tórax.
