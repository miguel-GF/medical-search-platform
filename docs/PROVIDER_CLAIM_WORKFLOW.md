# Flujo de reclamación de perfiles de proveedores

Estado de esta referencia: implementación local preparada, registro y documentos
cerrados por defecto. No abre un formulario público ni aplica migraciones remotas.

## Objetivo

Una persona que representa a un laboratorio, clínica o sucursal puede solicitar
acceso a un perfil existente sin que Pruevia publique datos nuevos ni conceda
permisos automáticamente. La solicitud queda en un expediente privado; el
personal autorizado decide el alcance (marca completa o una sucursal), la
organización jurídica y la evidencia.

## Recorrido externo

1. La persona consulta el aviso de privacidad vigente, crea o confirma su cuenta
   y activa TOTP. El API exige sesión `aal2` para leer o modificar el expediente.
2. Busca la marca/sucursal, elige el alcance, captura nombre, cargo, empresa y
   correo de trabajo y acepta expresamente la versión del aviso. Se crea un
   borrador y se entrega un folio.
3. Envía el borrador. El estado pasa a `pending`; no cambia el catálogo, no crea
   membresía y no publica documentos.
4. El equipo revisa primero una fuente oficial HTTPS y, si es posible, envía un
   enlace de comprobación al correo corporativo. El token sólo se almacena como
   hash, vence en 30 minutos, se usa una vez y tiene límites de reenvío.
5. Si el contacto no basta, el equipo pide información. Los documentos son la
   alternativa, no el camino silencioso: sólo se habilitan después de completar
   las puertas legales, de correo y de almacenamiento/escaneo.
6. La persona ve el estado y los mensajes en el portal y recibe un aviso de
   correo asíncrono. Un fallo del correo no deshace una decisión ni borra el
   historial.

## Estados y transiciones

| Estado | Significado | Siguientes acciones |
| --- | --- | --- |
| `draft` | Captura incompleta, sólo visible a la persona | guardar, enviar, cancelar |
| `pending` | Recibida y esperando revisión | tomar, pedir información, verificar contacto |
| `under_review` | Un revisor la está trabajando | pedir información, aprobar, rechazar |
| `needs_information` | Falta una respuesta o evidencia | corregir, enviar, cancelar |
| `approved` | Alcance aprobado; se activa la membresía limitada | administrar perfiles incluidos, solicitar privacidad |
| `rejected` | No se acreditó la representación | corregir y volver a enviar |
| `cancelled` | Cancelada por la persona | conservar para auditoría |
| `revoked` | Acceso previamente aprobado retirado | conservar historial, solicitar de nuevo |

La base aplica control optimista por `revision`, unicidad de solicitudes abiertas,
conflictos de alcance y auditoría de cada decisión. Una marca y una sucursal no se
mezclan; aprobar una solicitud nunca concede más alcance que el confirmado.

## Operación interna

Admin cuenta con cola, búsqueda, periodo, detalle, historial y acciones separadas:

- vincular una organización ya existente o crearla sólo con justificación;
- registrar fuente oficial y validar contacto;
- tomar revisión, pedir información, guardar nota interna, aprobar, rechazar o
  revocar;
- aceptar/rechazar evidencia después del escaneo y generar un enlace firmado de
  60 segundos, sin exponer la clave de Storage;
- consultar entrega de correo y solicitudes de derechos de datos.

El Worker de correo (`pruevia-provider-mail`) sólo reclama trabajos mediante un
lease, usa SMTP TLS autenticado, reintenta hasta cinco veces y no imprime tokens,
URLs completas ni cuerpos. Debe ejecutarse como job privado; no es una ruta HTTP.

## Privacidad y derechos

Antes de activar `provider_intake_settings.enabled` deben definirse el nombre o
razón social de la persona responsable, domicilio, correo de privacidad, versión
integral del aviso, encargados, finalidades, conservación y procedimiento ARCO.
El portal muestra esos datos y no permite registrar solicitudes mientras falte la
revisión legal. No se solicitan datos de pacientes; se recomienda ocultar datos
ajenos en cualquier evidencia.

El primer alcance es privacidad de proveedores: acceso, rectificación,
cancelación, oposición y retiro del consentimiento. Cada solicitud tiene folio,
estado, respuesta y auditoría. La cancelación puede requerir bloqueo cuando exista
una obligación legal; la respuesta debe explicar el alcance y el plazo aplicable.

## Puertas para abrir el registro

La apertura es un cambio crítico y requiere aprobación explícita. Antes deben
estar completos: responsable legal y aviso publicado, contacto de privacidad,
procesador de correo operativo, dominio permitido, límites/alertas, políticas de
Storage, scanner limpio y plan de recuperación. Después se habilita primero un
piloto pequeño, se verifica una solicitud completa y se conserva la opción de
cerrar el registro sin borrar expedientes.

Migraciones relacionadas: `20260914120000_provider_application_workflow.sql` y
`20260914121000_provider_document_activation_gate.sql`. La prueba reproducible
local es `database/scripts/test_provider_intake_local.ps1`; no sustituye una
prueba contra el proyecto remoto.
