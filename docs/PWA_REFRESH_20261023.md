# PWA instalada: recepción de la interfaz actual

23-oct-2026, hora de México; publicación 24-oct04:32:30UTC.

## Reporte y alcance

Las tres capturas del usuario muestran la web app: botones ovalados, acciones
de receta estrechas y una fila «Analítica de uso — Desactivada en esta versión».
La primera muestra expresamente `app.pruevia.com.mx`. Ninguna de las tres muestra
el aviso de actualización reportado por otra persona en el landing.

El código y el Flutter público vigente ya tenían botones con radio8px,
acciones móviles al ancho disponible y ninguna fila de analítica desactivada.
Se comprobó el SHA del JavaScript servido contra el release congelado anterior:
`37dd9775a9f7adfc8cb394bbe1b7025e3dbebbc9d4f815a100db428bd7f205c6`.
Las capturas y la lectura fresca no representan la misma interfaz. No se accedió
al teléfono ni se determinó cuál versión o controlador había allí.

## Corrección publicada

El botón de actualización recargaba la misma URL y los archivos de entrada
conservaban nombres fijos. Eso no ofrecía una identidad nueva a una instalación
que hubiera conservado esos recursos. Ahora:

- La estampación publica copias de `main.dart.js` y `flutter_bootstrap.js`
  identificadas por SHA256. El HTML apunta al bootstrap correspondiente y éste
  apunta al JavaScript correspondiente. Los nombres anteriores se conservan.
- El worker público admite esos recursos con su estrategia de red primero y
  respaldo sin conexión. Mantiene exclusiones de API, autenticación y datos clínicos.
- Al aceptar actualizar se navega a una URL con el identificador del release.
  No se fuerza el reinicio de una orden abierta ni se guarda su contenido.
- El aviso dice «Hay una nueva versión de la app Pruevia».

Se publicó sólo Patient, versión `31122ca0-2b81-49a8-a992-b1ed40346c04`.
Build: `81d2992f4a5559da83c997e3d557774b2b367b874285736898172e5c81316a7b`.
JavaScript Flutter idéntico al anterior; sin cambios SQL, API o landing.
Preparación reproducible: `scripts/prepare_pwa_refresh_release.py`.

## Comprobación y límites

Chrome real a390×844, con worker nativo y dos directorios de releases reales:
la sesión anterior detectó la publicación y pasó al nuevo build al aceptar.
No se usaron respuestasHTTP simuladas. Dos intentos conservaron sus fallos de
localizador de navegación Flutter; el tercero seleccionó la posición visible
de Ajustes y verificó que la pantalla correspondiente estuviera realmente abierta.

Después del despliegue, lectura y navegador públicos confirmaron:

- HTML, bootstrap y JavaScript con hash correctos, HTTP200, worker activo.
- Buscar, Tengo una receta, Resolver estudios y Subir receta:350px de ancho
  disponible, x20 en viewport390. Buscar50px alto; las otras acciones52px.
- Ajustes visible, sin la fila «Analítica de uso»; cero errores de página.
- `pruevia.com.mx` sin manifiestoPWA ni aviso de actualización. El nombre con
  `www` no resolvió desde este entorno y no se acredita su contenido.

No acredita la instalación particular del usuario ni una reanudación nativa en
su teléfono. Para una sesión anterior sin detector: terminar la consulta y
cerrar completamente/reabrir, o abrir la URL pública con el parámetro del release.
No se solicita borrar datos ni desinstalar. El reporte del aviso en landing queda
sin reproducir; se solicitó captura donde figure el aviso y la dirección.

Evidencia y capturas: `collectors/artifacts/pwa-refresh-20261023/`.
Recibos definitivos: `browser-local-v3.json` y `public-observed.json`.
Recuperación: volver al Patient anterior `3073f58a-f0f3-40ab-8a2b-ca823820f54b`,
sin modificar base o API. La recuperación no se ejecutó.

## Analítica: aclaración de producto

El usuario precisó que la fila pertenece a la PWA y preguntó por medición interna
sin mostrar reportes al paciente. Los reportes son administrativos; un control
del paciente sólo tendría sentido para gestionar su privacidad si la función
estuviera habilitada. La medición continúa desactivada; no se activó por esa pregunta.

El mecanismo actual requiere flag y consentimiento y envía un identificador
anónimo con el evento. No se equipara ese mecanismo con un contador agregado
sin identificadores. Propuesta pendiente: totales administrativos sin texto de
búsqueda, recetas ni identificadores de visitantes, descritos en el aviso antes
de activarse. No se cambió el aviso para afirmar una recopilación inexistente.

Referencias primarias consultadas: [actualización dePWA](https://web.dev/learn/pwa/update)
y [LFPDPPP vigente,arts.2,9,14–16](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf).
