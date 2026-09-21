# Prueba cerrada Android de Pruevia

Tipo: runbook de preparación; no acredita una publicación en Google Play.  
Revisado: 20-sep-2026.  
Package Android: `com.pruevia.app`.  
Versión inicial prevista: `1.0.0 (1)`.

## Estado comprobado

- El usuario informó que la cuenta de Play Console ya fue pagada.
- La aplicación compila en debug y el proyecto exige firma real para release.
- El icono Android incluye variante heredada, adaptativa y monocromática generada
  desde la marca aprobada; la build debug verificó que los recursos compilan.
- La build muestra `contacto@pruevia.com.mx` como soporte y enlaza el aviso público;
  Email Routing recibe en un destino privado, sin envíos automáticos.
- No existen en este entorno las cuatro variables de firma del upload key.
- No se generó ni subió un AAB de release.
- La cohorte DEV está cerrada en `0/20`; no se enviaron invitaciones.
- Proveedores, analítica y clics quedan apagados en la build pública/cerrada.
- El feedback cerrado está preparado en código, pero el API lo rechaza mientras
  el gate remoto permanezca cerrado.

La regla propia de Pruevia es reunir 20 testers y medir 21 días. Google exige a
las cuentas personales nuevas que apliquen a producción al menos 12 testers con
opt-in continuo durante 14 días; 20/21 es margen operativo de Pruevia, no una
cita del requisito de Google. La condición exacta aplicable debe confirmarse en
el Dashboard de la cuenta.

Fuentes oficiales:

- [Requisitos de prueba para cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465?hl=es).
- [Preparar y desplegar una versión](https://support.google.com/googleplay/android-developer/answer/9859348?hl=es).
- [Declaración de aplicaciones de salud](https://support.google.com/googleplay/android-developer/answer/14738291?hl=es-419).
- [Seguridad de los datos](https://support.google.com/googleplay/android-developer/answer/10787469?hl=es).
- [Política de contenido y servicios de salud](https://support.google.com/googleplay/android-developer/answer/16679511?hl=es-419).

## Orden de preparación en Play Console

1. Crear la aplicación como **Pruevia**, tipo aplicación, gratuita y sin anuncios.
2. Confirmar nombre del desarrollador, correo/teléfono verificados y tipo de
   cuenta. No inventar datos distintos a los verificados por Play.
3. Configurar Play App Signing y crear/conservar un upload key fuera de Git.
4. Generar el AAB con el script versionado.
5. Completar ficha principal, acceso a la app, anuncios, audiencia 18+, rating de
   contenido, Data Safety, declaración de salud y política de privacidad.
6. Subir primero a prueba interna si se desea una comprobación técnica rápida.
7. Crear la pista cerrada, cargar el mismo AAB aprobado y preparar la lista de
   correos; no liberar el enlace hasta reunir la cohorte según D-015.
8. Marcar cada opt-in activo en Admin. Día 1 sólo comienza con 20 activos.

## Firma y generación del AAB

La clave de carga pertenece al usuario. Debe guardarse en una ruta privada con
respaldo separado y nunca en el repositorio, nube pública, capturas o mensajes.
Configurar sólo en la terminal que hará el build:

```powershell
$env:PRUEVIA_RELEASE_STORE_FILE = 'C:\ruta-privada\pruevia-upload.jks'
$env:PRUEVIA_RELEASE_STORE_PASSWORD = '<secreto>'
$env:PRUEVIA_RELEASE_KEY_ALIAS = '<alias>'
$env:PRUEVIA_RELEASE_KEY_PASSWORD = '<secreto>'
powershell -ExecutionPolicy Bypass -File scripts/build_closed_android.ps1 -BuildName 1.0.0 -BuildNumber 1
```

El script valida el keystore/alias sin imprimir contraseñas, ejecuta análisis,
pruebas y `flutter build appbundle --release`, y verifica la firma del AAB. Falla
si la firma está incompleta, fija el API a `api.pruevia.com.mx` y compila con:

- `PRUEVIA_CHANNEL=closed_android`;
- `PROVIDER_PORTAL_ENABLED=false`;
- `ANALYTICS_ENABLED=false`;
- `PRODUCT_FEEDBACK_ENABLED=true`.

Cada AAB posterior necesita un `BuildNumber` mayor. El script crea junto al AAB
`app-release.evidence.json` con SHA-256, tamaño, versión, commit, estado limpio o
sucio del árbol y gates de compilación. No contiene contraseñas y deja
`uploaded_to_google_play=false`; cambiar ese estado requiere evidencia posterior
de Play Console, no editar el archivo para simular una carga.

## Ficha propuesta

Nombre: **Pruevia**

Descripción corta:

> Compara estudios médicos, sucursales y condiciones en Puebla.

Descripción base:

> Pruevia te ayuda a identificar los estudios indicados en una orden médica y a
> explorar opciones para realizarlos. Puedes buscar un estudio, revisar una orden
> con varios renglones y comparar información disponible por proveedor y sucursal.
>
> La cobertura comienza en Puebla y está en construcción. Los precios, servicios
> y condiciones pueden variar; revisa la fuente y confirma directamente con el
> proveedor antes de acudir. Pruevia no interpreta resultados, no diagnostica y no
> sustituye la orientación de un profesional de salud.

Categoría sugerida: **Medicina**. País inicial: **México**. Precio: **gratis**.
La ficha no debe afirmar reserva, pago, cobertura total, diagnóstico, convenio ni
actualización en tiempo real porque esas capacidades no están acreditadas.

## Declaraciones de datos: hoja de trabajo

Esta tabla es una base para contestar Play Console, no una declaración ya enviada.
Debe reconciliarse con el AAB final y la configuración remota activa.

| Flujo | Dato | Manejo previsto | Respuesta de trabajo |
| --- | --- | --- | --- |
| Buscar/escribir orden | Texto que puede revelar salud | Se transmite por HTTPS, se procesa en memoria para responder y no se guarda deliberadamente. | Incluir en el formulario como **información de salud**, procesamiento efímero, funcionalidad de la app, requerido para esa acción. |
| Foto de orden | Imagen/documento que puede revelar salud | Selección voluntaria, HTTPS, OCR en tiempo real, descarte del archivo local temporal y sin persistencia en DB. | Incluir como **fotos** e **información de salud**, procesamiento efímero, funcionalidad, opcional porque se puede escribir. |
| Feedback cerrado | Respuestas estructuradas y comentario opcional | Sin búsqueda/receta adjunta; retención hasta fin del piloto + 90 días. | **Otro contenido generado por usuarios**, funcionalidad/analítica, opcional. |
| Analítica/clics | UUID aleatorio, eventos y IDs de catálogo | Gate apagado en el primer AAB. | No declarar como activo para ese AAB; actualizar formulario antes de compilar con `ANALYTICS_ENABLED=true`. |
| Registro de testers | Correo, municipio y dispositivo | Ocurre en el sitio web, no dentro del AAB; retención del piloto. | Cubrir en el aviso web. Revalidar si la app futura incorpora registro. |

Google indica que el procesamiento efímero transmitido fuera del dispositivo debe
incluirse al responder el formulario aunque, si cumple su estándar, puede no
mostrarse como recopilación en la ficha pública. No marcar “no recopilamos datos”
sin recorrer las preguntas de procesamiento efímero.

Pruevia no comparte estos datos para publicidad, venta o scoring. Cloudflare,
Supabase y los servicios necesarios operan como infraestructura/procesadores;
deben revisarse conforme a las definiciones de Play antes de enviar el formulario.

## Declaración de salud

La declaración es obligatoria incluso en prueba cerrada. Pruevia ofrece funciones
relacionadas con estudios médicos, por lo que no debe elegir “sin funciones de
salud”. En Play Console se debe seleccionar la opción médica que mejor describa
la navegación/gestión de servicios de diagnóstico según las opciones que muestre
el formulario vigente.

No declarar **Clinical Decision Support**, diagnóstico ni dispositivo médico: la
app identifica texto, compara oferta comercial y muestra aclaraciones; no interpreta
resultados ni recomienda tratamiento. Mantener visible el aviso de que no sustituye
a un profesional.

## Privacidad y acceso del revisor

URL prevista: `https://pruevia.com.mx/privacidad`.

Antes de cargar la pista cerrada, esa URL debe estar pública, sin geobloqueo ni
PDF, y contener:

- responsable, domicilio y correo reales;
- búsquedas/fotos como procesamiento de información potencialmente sensible;
- no persistencia deliberada de receta/imagen original;
- feedback, conservación y retiro;
- infraestructura y Google Play;
- mecanismo ARCO y versión del aviso.

La búsqueda no exige cuenta. En “Acceso a la aplicación” se puede indicar que el
revisor abre directamente el flujo paciente y no necesita credenciales.

## Evidencia durante los 21 días

Conservar sin datos clínicos:

- opt-ins activos y fechas de entrada/salida;
- versión/build instalada y tipos de dispositivo;
- escenarios probados: búsqueda, receta, OCR, cobertura parcial y errores de red;
- feedback estructurado, fallos reproducibles y correcciones publicadas;
- fecha de inicio/fin mostrada por el estado de cohorte;
- cambios de AAB con build number y notas de versión.

No pedir capturas de recetas reales para demostrar uso. Usar casos públicos o
sintéticos y comentarios sin diagnósticos.

## Puerta antes de invitar

- API y política públicas verificadas.
- AAB firmado aceptado por Play y pre-launch report revisado.
- Data Safety y Salud sin pendientes.
- 20 correos con aceptación válida y lista cargada.
- Enlace de opt-in comprobado con una cuenta de control.
- Canal de soporte operativo.
- Backup del upload key confirmado.
- Proveedores y Admin ausentes de la build.

Sólo entonces se libera el enlace al grupo completo. Instalar un AAB local o
crear la pista no inicia el contador interno de Pruevia.
