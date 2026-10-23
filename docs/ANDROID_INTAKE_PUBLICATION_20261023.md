# Registro Android y publicación — 23 de octubre de 2026

## Autorización y resultado

El usuario pidió publicar después de evaluar el algoritmo y abrir la convocatoria
Android con nombre y Gmail, sin versión de Android ni modelo del teléfono, con
guardado real en la base. También pidió comprobar los botones antes de cambiarlos.

La convocatoria está en [pruevia.com.mx/prueba-android](https://pruevia.com.mx/prueba-android).
Recibe nombre, Gmail y confirmaciones de mayoría de edad y privacidad. Ya no pide
municipio ni datos del teléfono; no se inventa una ubicación para cumplir el esquema.
El formulario conserva protección contra bots, límites de solicitudes y respuesta
genérica para correos repetidos. El contador se consulta al servidor tras guardar.

Aclaración del usuario confirmada por lectura productiva el23-oct: las columnas
`android_version` y `device_model` se conservan y ambas permitenNULL. Sólo se
retiraron del formulario; el RPC nuevo no borra valores anteriores al actualizar
una solicitud existente. No se necesita otra migración para conservarlas.

La configuración conserva la meta existente de 20 participantes y 21 días de
prueba. Se abrió el reclutamiento por 90 días, hasta el 21-ene-2027; esto **no inicia
los 21 días ni envía invitaciones de Google Play**. Admin y proveedores siguen
cerrados públicamente. Feedback, analítica, captura de consultas y crons del Worker
permanecen desactivados. No se publicó el candidato clínico completo.

## Publicación y evidencia real

| Superficie | Versión Cloudflare |
| --- | --- |
| API | `f8cd47d0-95a8-4bb0-ba14-badb20a213e8` |
| Landing | `fa775956-69bc-4b63-b3e5-7a817b98d8f0` |
| Patient | `19b53ac9-6dbb-4817-9ff1-16701bae51cb` |

Despliegues terminados entre 12:14 y 12:17 UTC. Patient sirve el JS congelado
`c6831834bfd228c479e137579a4b9eaad48d783c15ba24a5454656b1990b1f61`
y manifiesto `b089ecd016006a98542e562a2c53a175bc00ec932fe9ba496302ec55486a0e03`.
Se publicaron las mejoras anteriores de selección de estudios, sugerencias por
errores de escritura y navegación móvil por proveedor, conservando el motor clínico.

Una solicitud sintética desde el formulario público devolvió HTTP202. Una lectura
independiente confirmó exactamente una fila con nombre/correo y aceptación del
aviso `android-testers-2026-10-23-v2`; municipio, Android y dispositivo nulos.
Se eliminó exclusivamente esa fila y otra lectura confirmó cero registros de prueba.
No se enviaron correos ni se usaron datos reales de participantes.

Migración nueva `20261023123000_android_tester_name_email.sql`, aplicada una vez
en `ymtcmfgwuzdqtsbuvzqf`, la base productiva enlazada. Antes se ejecutó con rollback
y después se comprobó por lectura independiente. Añade nombre nullable, permite
municipio nulo, RPC v2 sólo para service_role y nombre en la proyección administrativa
existente. No altera permisos de tablas, RLS ni funciones clínicas. Ledger: 113
migraciones si no hubo otras operaciones posteriores. El cambio de Admin está
preparado localmente; no se reabrió su sitio.

## Botones: comprobación antes y después

Navegador público nuevo a 390×844, antes y después de publicar:
Buscar, Tengo una receta, Resolver estudios y Subir receta miden **350px**, x20.
Buscar tiene área semántica de 50px de alto y los otros 52px. Las capturas
inspeccionadas muestran borde rectangular con radio8px, coherente con el tema.
El radioCSS del nodo semántico Flutter no representa el dibujo del canvas.
No se modificó el diseño: la diferencia reportada no se reprodujo en esta vista.
Esto no demuestra qué versión ejecuta una PWA instalada en el teléfono del usuario.

## Artefactos, alcance y recuperación

Recibos, fuentes congeladas, hashes, captura del formulario, confirmación real y
configuración anterior en `collectors/artifacts/android-intake-release-20261023/`.
Medidas y capturas móviles en `collectors/artifacts/mobile-controls-20261018/`,
subcarpetas `review-20261023` y `after-release-20261023`.
Compilaciones Flutter/Nuxt y comprobación de tipos del paquete API terminaron0;
sin suites formales en esta publicación. El caso existente de API se actualizó
al contrato nuevo sin ejecutarlo. La comparación del núcleo está en
[su informe separado](ALGORITHM_LOCAL_EVALUATION_20261023.md).

Recuperación: cerrar primero `research.pilot_settings.tester_intake_enabled` y
restaurar los Workers previos: API `45ed6a34-fcf6-4205-8d6b-0555926072d4`,
Patient `2e1e136b-9e23-4969-9f59-ab350fb9510b`, landing
`49e394b5-2fb2-41c3-bddd-4e6f3fbf581c`. Conservar la migración aditiva y registros;
no borrar participantes ni reescribir migraciones aplicadas para volver atrás.
Los envíos remotos conservan marcador previo y no se repiten ante incertidumbre.

Pendientes operativos: administrar invitaciones en Google Play por separado,
revisar con abogado el aviso actualizado y mantener el procedimiento de retiro
y depuración; la inscripción por sí sola no acredita estos trabajos posteriores.
