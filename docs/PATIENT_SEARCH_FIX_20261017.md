# Corrección de búsqueda y controles de paciente

17-oct-2026 UTC / 16-oct en Puebla. Encargo posterior a la pausa del catálogo.
Checkpoint anterior: `1e33c46`; conserva los cambios locales acumulados.
El marcador `collectors/artifacts/local-review-queue/STOP` sigue presente.

## Problemas observados

Las consultas públicas «biometría», «electrocardiograma» y «ecocardiograma»
devolvían candidatos, pero la interfaz los colocaba en «sin oferta» sin permitir
buscar su nombre completo. Los nombres específicos sí devolvían ofertas:
biometría hemática13, electrocardiograma en reposo12 y ecocardiograma
transtorácico15 en esas consultas con el límite predeterminado. La interfaz pide
hasta100 resultados y puede mostrar más ofertas; estos números no son un
inventario completo. La sugerencia ortográfica comparaba nombres enteros y fallaba
con «ecocoardigorama».

«Hepática» tiene una limitación distinta: no hay un perfil hepático verificado
en este catálogo. No se creó un panel ni se cambió la equivalencia clínica.

## Cambios realizados

- Botones con token central de radio10px. Acciones principales ocupan el ancho
  disponible en móvil; se conserva la distribución de escritorio.
- La versión actual sin analítica no muestra su tarjeta técnica en Ajustes.
- Los candidatos por confirmar permiten «Buscar este estudio» por elección
  explícita del visitante. Se distinguen de un estudio reconocido sin oferta.
- Las respuestas de búsquedas anteriores no reemplazan una consulta nueva.
- Sugerencias desde nombres y aliases globales aprobados del catálogo, con
  caché del lado servidor y comprobación actual de nombre/ID antes de mostrarse.
  Son opciones de navegación; no cambian estados de resolución ni publican ofertas.
- «Hepática» muestra un aviso sobre el perfil ausente y opciones individuales
  relacionadas, que no sustituyen la composición de una orden. La relación se
  contrastó con [MedlinePlus](https://medlineplus.gov/spanish/pruebas-de-laboratorio/pruebas-funcionales-hepaticas/).
  No se ofrecen esas opciones si la consulta añade muestra, isotipo o tiempo.
- El cliente envía `notice_supported=1`: los clientes antiguos que no pueden
  mostrar el aviso no reciben la lista de componentes. El contrato es aditivo.

La búsqueda orienta hacia nombres existentes; no elige reposo frente a esfuerzo,
no sustituye ecocardiografía por electrocardiografía y no transforma «hepática»
en «hemática». No hubo SQL de escritura, migración ni cambios de catálogo.

## API publicada

17-oct04:29:27 UTC: Worker `777b7a40-1785-4bb5-aa4c-1990cc7d416b`.
El candidato se extrajo de las fuentes conservadas de la publicación anterior:
cambian dos funciones de búsqueda, un import y un módulo nuevo. Las otras81
funciones, ocho módulos y configuración permanecen idénticos.
No se publicó todo el árbol API del checkpoint, que incluye trabajo separado.

TypeScript y Wrangler dry-run terminaron0. Once observaciones HTTP públicas
confirmaron200, sugerencia de ecocardiograma para la errata, variantes explícitas,
listas hepáticas negociadas y13/12/15 ofertas para nombres completos.
`/health` devolvió200. Eventos/clics siguen devolviendo503 `analytics_disabled`;
captura, analítica, DENUE y normalización permanecenfalse, con `crons=[]`.

## Patient y alcance de las comprobaciones

Análisis Dart dirigido sin incidencias. Build debug local terminado0, con
HTTP sólo para loopback conforme a la política existente. Se observa en el
directorio que realmente sirve el launcher: `patient-web-debug`.
El primer navegador apuntó al servidor anterior; ese resultado se conservó
como diagnóstico y no acredita la UI nueva. No se debilitó HTTPS para usar
un build release con una URL HTTP.

Observación local en390 y1280px: elegir Biometría hemática y ecocardiograma
transtorácico mostró ofertas. En320px los botones no se recortan; el CTA de
receta ocupa280×48px. Aviso hepático y cinco opciones observados, con captura
corregida que espera la respuesta de la consulta exacta. Las capturas iniciales
con temporización incorrecta se conservan identificadas y no se usan como prueba.

Release HTTPS terminado0, encabezados generados y46 archivos congelados con
hashes; las fuentes no cambiaron durante ese build. Patient publicado a las
04:36:43 UTC, versión `7f63b3eb-45f0-4ae2-9ee8-0a56b546230d`. A04:37 UTC
la app y su JS devolvieron200 y el bundle remoto coincidió con el congelado:
`45a9d6d7217a5acc656fcc600dfd9fc23839c9360d6640756d345bb4f4557246`.
CSP presente, HTML/JS sin caché persistente, origen app204 y origen ajeno403.
No se ejecutaron suites de pruebas.

Observación final en Chrome público:390 y1280px completaron selección de
Biometría hemática y ecocardiograma transtorácico hasta sus ofertas, búsqueda
con errata y aviso hepático con cinco opciones. La interfaz, que solicita100
resultados, mostró34 ofertas para biometría y15 para ecocardiograma en esas
respuestas. Ajustes no muestra analítica; no aparece el mensaje de cero estudios
«sin oferta» y el texto de confirmación es legible. El JS observado por navegador
coincide con el release congelado; no hubo errores de página observados.

En320px el CTA de receta ocupa280×48px y las acciones de receta244×48px,
sin recorte. El primer intento fue interceptado por el aviso de instalación;
el recibo corregido conserva la observación después de cerrarlo. No se usó ese
primer intento como evidencia de éxito. Recibos finales en `public-current/`,
`browser-observed.json` y `narrow-mobile-corrected.json`.

La compilación debug local se refrescó también después de los últimos cambios
de texto, foco y navegación. Terminó0; a04:41 UTC el JS servido por8080 coincide
con ese output final, API local devuelve200 y el aviso hepático conserva cinco
opciones con el contrato nuevo. No se reinició el servidor ni la cola.

Corrección guardada en `007eac3`; el checkpoint previo es `1e33c46`.

Evidencia privada de herramientas, fuentes de candidato, hashes, recibos y
capturas en `collectors/artifacts/patient-search-fix-20261017/`.

## Recuperación

Versiones anteriores: API `72bc81ed-f6a5-4dde-a834-15ae2dc30b63` y Patient
`5bda3d31-f3b4-4fae-8f07-41c8339c5350`. Se pueden restaurar las superficies
por separado conservando configuración y secretos existentes. Una reversión
no necesita borrar ni modificar estudios, RAW, ofertas o preferencias privadas.
No se hizo push ni se reanudó la cola del catálogo.
