# Pruevia: información para revisar el aviso de privacidad

**Borrador de trabajo · 15 de octubre de 2026 · Pendiente de revisión jurídica**

## 1. Para qué se entrega este documento

Buscamos que el abogado revise un aviso que corresponda al funcionamiento real de Pruevia y determine qué autorizaciones, documentos y medidas faltan. Este informe reúne hechos del proyecto y preguntas concretas. No afirma que el producto cumpla la ley ni sustituye un dictamen. **La aplicación se volvió a publicar a petición del propietario; esa publicación no significa que los pendientes jurídicos estén resueltos.**

La revisión técnica se hizo sobre archivos locales. No se consultaron recetas, búsquedas individuales, expedientes de usuarios ni secretos. Además, el 15 de octubre de 2026 a las **04:44 UTC** se capturó el estado público: el aviso y la página informativa respondieron correctamente; la dirección de la aplicación redirigió a la página informativa y el servicio de búsquedas informó que estaba fuera de servicio. La copia exacta del aviso se resguardó para entrega privada al abogado, sin trasladar datos personales a este documento.

| Superficie | Estado documentado | Alcance de esta revisión |
| --- | --- | --- |
| Página informativa y aviso | Actualizados y disponibles el 15 de octubre, 12:25 UTC | Aviso con versión del 15 de octubre y recordatorio local de 180 días |
| Buscador y aplicación para pacientes | Reabiertos por petición del propietario | La aplicación carga y el buscador responde con el catálogo existente |
| Administración y acceso de proveedores | Pausa documentada, sin nueva consulta pública específica en este corte | La autorización de reapertura del buscador no abre estas funciones |
| Comentarios, medición y convocatoria Android | Cerrados en esta reapertura | Registro y comentarios comprobados como cerrados; recepción de medición bloqueada por el servidor |

La comprobación posterior del 15 de octubre a las **12:25 UTC (06:25, hora de Puebla)** confirmó la página, el nuevo aviso y la aplicación disponibles, así como respuestas del buscador. «Sangre» y «orina» ofrecen aclaraciones sobre la muestra y «TSH» devuelve una coincidencia. No se enviaron fotografías, recetas reales ni solicitudes de registro. Tampoco se borró el antecedente histórico. El propietario debe revisar con su abogado los pendientes inmediatos señalados abajo.

## 2. Qué hace Pruevia y qué recibe del visitante

Pruevia ayuda a identificar estudios de una orden médica y encontrar opciones para realizarlos, inicialmente en Puebla. Una búsqueda pública no requiere cuenta de paciente. El usuario puede escribir un estudio, pegar una lista o elegir una fotografía de su orden. El sistema devuelve coincidencias, variantes que necesitan aclaración y opciones de proveedores cuando existen datos suficientes.

No se debe presentar este proceso como diagnóstico, interpretación de resultados ni sustitución del personal de salud. Identificar un establecimiento tampoco demuestra que allí se realice determinado estudio. La información comercial y la disponibilidad necesitan evidencia independiente.

| Acción del usuario | Información que recibe el servicio | Observación relevante |
| --- | --- | --- |
| Buscar un estudio | Palabras escritas; opcionalmente ubicación o sede seleccionada | Una consulta puede revelar salud aunque no incluya nombre |
| Pegar una orden | Lista o texto de estudios y preferencias de comparación | El texto puede contener datos personales agregados por el usuario |
| Elegir una foto | Imagen completa y texto que se obtiene de ella | Puede mostrar nombre, firma, diagnóstico u otros datos ajenos al estudio buscado |
| Abrir una opción externa | Dirección del sitio del proveedor | El destino externo tiene sus propios tratamientos y políticas |

El programa admite ubicación en ciertas consultas, pero no se comprobó un permiso activo de geolocalización en cada versión. Los servicios de internet también necesitan procesar información técnica de conexión para entregar la página y limitar abusos.

Trabajar sin cuenta reduce información solicitada; no elimina el tratamiento de datos personales. Tampoco permite concluir que una fotografía o un término médico sean anónimos.

## 3. Quiénes intervienen en el procesamiento

Los servidores de Pruevia reciben las solicitudes. Se utiliza Cloudflare para publicar la aplicación y Supabase para consultar el catálogo y guardar la información que corresponda a cada función. La versión publicada está configurada para leer imágenes con inteligencia artificial de Cloudflare. El programa admite también un servicio alternativo, que no se configuró en esta reapertura. No se envió una fotografía durante la comprobación; falta confirmar las condiciones contractuales, los lugares de procesamiento y los compromisos de conservación del prestador.

La imagen completa se envía al servicio de lectura antes de pedirle que omita nombres, fechas y firmas de la transcripción. Esa instrucción no evita la transmisión inicial ni garantiza que todos los datos ajenos al estudio desaparezcan del texto resultante. No sería correcto afirmar que la lectura ocurre exclusivamente en el teléfono o que ningún proveedor tecnológico recibe la imagen.

Si se abre una prueba Android, el correo de las personas seleccionadas podría usarse para administrar invitaciones en Google Play. En el acceso privado de proveedores hay servicios de autenticación, almacenamiento documental, revisión de archivos y envío de correo. Su instalación no acredita que estén atendiendo solicitudes reales.

El abogado necesita conocer los contratos y condiciones de cada prestador. Este informe no determina cuáles intervienen jurídicamente por cuenta de Pruevia, cuáles actúan por cuenta propia ni cuándo existe una transferencia que requiera información o consentimiento adicional.

Al salir hacia la página de una clínica, el navegador establece una conexión con ese tercero. No se encontró un envío deliberado de la receta completa como parte del enlace de salida. Sin embargo, no se revisaron las cookies o formularios de todos los destinos, por lo que no deben hacerse promesas sobre su comportamiento.

## 4. Recordatorio de privacidad y decisiones del usuario

Se preparó un recordatorio con enlace permanente al aviso, tanto en la página informativa como en la aplicación. El botón **«Entendido»** guarda una preferencia local para ocultarlo durante **180 días**, salvo cambio de versión del aviso. Puede aparecer antes si la persona borra datos, cambia de navegador o usa otro dispositivo.

La preferencia se guarda por navegador o instalación. **No se usa la dirección IP para reconocer a la persona ni coordinar esos 180 días.** La página y la aplicación pueden guardar preferencias separadas. La infraestructura puede tratar direcciones IP por motivos de conexión y seguridad; eso es un asunto distinto del recordatorio.

Pulsar «Entendido» no demuestra que alguien abrió o leyó todo el aviso. No es una firma, no crea una cuenta y no autoriza medición, lectura de recetas o tratamiento médico. No se diseñó como un expediente de consentimiento. El abogado debe indicar qué acción y constancia corresponden a cada tratamiento que sí necesite autorización.

Como referencia de diseño, la autoridad francesa CNIL recomienda recordar durante seis meses la aceptación o el rechazo de cookies. Se trata de una práctica para cookies en otro marco jurídico: **no es una regla mexicana para avisos de privacidad ni una autorización para datos de salud**. En Pruevia se eligieron 180 días para evitar repetir el recordatorio en cada visita. [Explicación de la CNIL](https://www.cnil.fr/fr/cnil-direct/question/cookies-si-jai-refuse-ses-cookies-un-site-web-peut-il-me-redemander-de-les).

La medición opcional tiene una aceptación separada en la aplicación. Cuando está desactivada o la persona no acepta, el cliente omite sus eventos de medición. Al retirarla, cambia la preferencia y elimina el identificador local para separar una futura aceptación. **No borra automáticamente los eventos anteriores del servidor.**

Los formularios de testers y proveedores tienen sus propias declaraciones y versiones de aviso. La confirmación de mayoría de edad del piloto no equivale a una restricción general que impida a menores usar el buscador. Hace falta una decisión expresa sobre acceso, acompañamiento y órdenes de otras personas.

## 5. Conservación, límites y antecedente histórico

El texto y la imagen de una orden se manejan temporalmente durante su uso. La aplicación intenta limpiar su estado al cerrar o dejar en segundo plano ese apartado y descartar la fotografía después de leerla. Esto no acredita borrado inmediato de todas las copias del sistema operativo, respaldos o registros de proveedores tecnológicos.

| Información | Lo que implementa actualmente el programa | Pendiente de cerrar |
| --- | --- | --- |
| Preferencia del recordatorio | Reaparición a los 180 días o por cambio del aviso | No confundir ese periodo con conservación de datos médicos |
| Respuestas del piloto y solicitudes Android | Vencimiento al cerrar el piloto más 90 días por defecto | Comprobar ajuste real y eliminación efectiva, incluidos respaldos |
| Retiro del registro Android | Acorta la conservación prevista del correo a un máximo de siete días | El borrado depende de que se ejecute la limpieza |
| Medición de clics | Conservación prevista de 400 días | Revisar necesidad, periodo y limpieza efectiva |
| Eventos generales, revisión de búsquedas y documentos privados | No se encontró un plazo general suficiente en la revisión | Definir plazos, responsables, excepciones y procedimiento verificable |

Parte de las limpiezas se ejecuta al recibir una nueva operación. Si el servicio no vuelve a usarse, el código revisado no garantiza que los datos desaparezcan exactamente el día previsto. Debe separarse «fecha de vencimiento» de «eliminación comprobada».

La medición de clics puede relacionar un mismo navegador con un estudio y un proveedor concretos mediante un identificador aleatorio. Aunque no guarde nombre o texto de receta, no debe describirse sin más como información totalmente anónima.

Existe un antecedente documentado el **25 de septiembre de 2026**: se detectó conservación de términos normalizados de búsquedas que no se habían resuelto claramente. El aviso de aquel momento no describía esa finalidad. Se desactivó la captura y se conservó el antecedente para decisión expresa; esta revisión no consultó el contenido ni acredita la eliminación del histórico. No se afirma una filtración externa. El abogado debe valorar qué documentación, comunicación o medidas corresponden. El aviso no debe afirmar que nunca se guardaron consultas.

## 6. Pendientes jurídicos y operativos por prioridad

| Prioridad | Decisión o trabajo necesario | Resultado que se necesita |
| --- | --- | --- |
| Inmediata: buscador y lectura de órdenes ya publicados | Validar responsable y domicilio publicados, finalidades, información sensible y forma válida de autorización | Dictamen y cambios que indique el abogado; el recordatorio no resuelve este pendiente |
| Antes de habilitar medición | Separar eventos generales de clics asociados a estudios; revisar opción de rechazo y retiro | Decisión comprensible y constancia adecuada sin condicionar la búsqueda |
| Antes de recibir testers o proveedores | Aprobar datos solicitados, documentos, destinatarios y plazos | Formularios y atención de solicitudes preparados |
| Antes de prometer eliminación | Asegurar limpieza programada y reglas de respaldos, correos y registros técnicos | Procedimiento ejecutable y verificable |
| Antes de publicar textos definitivos | Comparar archivos locales con sitio y aplicaciones reales | Misma versión de aviso y funciones efectivamente abiertas |

Los datos del responsable y su domicilio aparecen en la copia exacta del aviso que acompaña al PDF privado. Se conservaron los que ya estaban publicados; su presencia no sustituye la validación del abogado. No se incluyen en este documento editable de circulación interna ni deben sustituirse por ejemplos ficticios en el aviso definitivo.

## 7. Preguntas concretas para el abogado

La referencia de trabajo es la **Ley Federal de Protección de Datos Personales en Posesión de los Particulares** vigente consultada el 15 de octubre de 2026, con última reforma publicada el **14 de noviembre de 2025**. Se necesita revisar las reglas de consentimiento del **artículo 7**, datos sensibles del **artículo 8** y excepciones del **artículo 9**, con su numeración actual. No se presupone que una excepción de atención médica cubra un buscador. [Texto oficial de la Cámara de Diputados](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf).

1. ¿Quién debe figurar como responsable y qué domicilio y canal de atención deben publicarse?
2. ¿Qué finalidades son necesarias para la búsqueda y cuáles deben ofrecerse por separado, como medición o mejora del catálogo?
3. ¿Cuándo el término de búsqueda, la orden o la foto deben tratarse como datos sensibles y qué mecanismo válido recomienda para recibirlos?
4. ¿Qué texto y comprobante deben preceder al envío de una fotografía? ¿Cómo atender órdenes de menores o de familiares?
5. ¿Cómo clasificar a cada proveedor tecnológico y qué contratos, información sobre países y autorizaciones faltan?
6. ¿Qué conservar, bloquear o eliminar, durante cuánto tiempo y con qué justificación, incluidos respaldos y documentos de representantes?
7. ¿Cómo atender acceso, rectificación, cancelación, oposición y revocación, con qué plazos y constancias, sin pedir información excesiva o crear otra copia innecesaria de la receta?
8. ¿Qué actuación corresponde al antecedente de septiembre y cómo comunicarlo de forma proporcional y comprobable?
9. ¿Conviene separar el aviso del sitio informativo, la búsqueda médica, el piloto Android y la incorporación de proveedores? ¿Qué condiciones deben cumplirse antes de abrir cada uno?

## 8. Documentos de apoyo y entrega

El aviso público es [pruevia.com.mx/privacidad](https://pruevia.com.mx/privacidad/) y la aplicación está en [app.pruevia.com.mx](https://app.pruevia.com.mx/). La captura posterior del 15 de octubre a las 12:25 UTC incluye el aviso **pruevia-privacidad-2026-10-15-v1**. El PDF privado añade el texto visible exacto de este aviso y el anterior para compararlos. Los anexos reproducen lo publicado; no son un texto aprobado por el abogado.

Para quien necesite revisar la evidencia, se dejan como anexos de trabajo:

- [Fuente del aviso](../../apps/landing/app/pages/privacidad.vue), publicada y comparada por versión.
- [Inventario técnico de tratamientos](../../collectors/artifacts/privacy-legal-review-20261015/backend-audit.md), con referencias al programa y límites de la revisión.
- [Recibos de la captura pública previa](../../collectors/artifacts/privacy-legal-review-20261015/public-before-receipts.json), con fecha y huellas de los archivos, sin reproducir datos personales del responsable.
- [Comprobación de la reapertura y capturas posteriores](../../collectors/artifacts/privacy-release-20261015/public-after-receipts.json).
- [Registro de decisiones](../DECISIONS.md), especialmente el antecedente D-019 y la pausa pública documentada.

El PDF está en `docs/legal/privado/PRUEVIA_REVISION_PRIVACIDAD_PARA_ABOGADO_20261015.pdf`. Se mantiene fuera del repositorio porque reproduce el nombre y el domicilio del responsable que aparecen en el aviso. Compártelo deliberadamente con tu abogado; no se publicó como descarga pública. Esta entrega no declara resueltos los pendientes de operación o privacidad ni convierte la autorización del propietario en una conclusión jurídica.
