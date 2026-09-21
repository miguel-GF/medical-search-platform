# ADR-003 — Publicación pacientes primero en pruevia.com.mx

Estado: **propuesta crítica preparada; pendiente de aprobación explícita**.  
Fecha: 20-sep-2026.  
Alcance: landing, PWA, API y preparación de prueba cerrada Android. No incluye
Admin público, alta de proveedores ni apertura del portal de proveedores.

## Problema y evidencia

El dominio `pruevia.com.mx` ya delega sus nameservers a Cloudflare, pero el
20-sep-2026 no resolvía registros A/CNAME para la raíz, `app` o `api`. La sesión
local de Wrangler está autenticada en la cuenta de Cloudflare que administra los
Workers; no existen proyectos de Pages listados. El Worker DEV sí está publicado,
pero sólo permite como origen su propio `workers.dev` y no es la URL pública final.

El landing y la aplicación Flutter están implementados, pero antes de este ADR
ambos podían reconstruir o aceptar el acceso de proveedores desde la URL de
pacientes. El diff preparado agrega gates explícitos y cerrados por defecto. La
convocatoria Android continúa en `0/20`, cerrada, sin enlace ni correos enviados.

El usuario informó que ya pagó la cuenta de Google Play Console. Eso elimina el
costo de registro como pendiente, pero no acredita todavía firma, ficha, Data
Safety, declaración de salud, política publicada ni un AAB aceptado por Play.

## Cambio propuesto y justificación

### Superficies públicas

| Destino | Contenido | Estado de proveedores |
| --- | --- | --- |
| `https://pruevia.com.mx` | Landing estático y página informativa del piloto. | Sin enlace ni formulario de proveedor. |
| `https://app.pruevia.com.mx` | PWA Flutter para búsqueda de pacientes. | `PROVIDER_PORTAL_ENABLED=false`; `?provider=1` no abre el portal. |
| `https://api.pruevia.com.mx` | Worker público para búsqueda, feedback y estado del piloto. | Documentos cerrados; rutas protegidas conservan Auth/RLS, sin frontend publicado. |

No se publicarán `admin.pruevia.com.mx`, un subdominio de proveedores ni una
convocatoria de proveedores. El código interno se conserva para una liberación
posterior con otra aprobación.

Se usarán Workers con Static Assets en vez de Pages: Cloudflare crea DNS y TLS al
desplegar cada Custom Domain, el landing se sirve como SSG y la PWA usa fallback
SPA. Los archivos `wrangler.production.toml` son la fuente versionada de esos
destinos. Esta ruta no añade una renta mensual durante el piloto dentro de los
límites gratuitos de la cuenta.

### Secuencia recomendada

1. Compilar y revisar landing/PWA con los destinos exactos y proveedores cerrados.
2. Respaldar el estado remoto antes de promoverlo.
3. Tratar el proyecto Supabase actualmente enlazado como la base inicial de
   producción, porque contiene el catálogo vigente; el desarrollo posterior se
   ejecutará localmente. No se crea por anticipación otro servicio pagado.
4. Publicar el Worker `pruevia-api` con secretos cargados fuera de Git y CORS
   limitado a raíz y `app`.
5. Publicar primero el landing sin enlace a la PWA; después de completar el aviso,
   publicar la PWA sin feedback ni analítica y comprobar TLS, headers, rechazo
   CORS, búsqueda, receta parcial y ausencia del portal.
6. Activar indexación del landing sólo tras comprobar todos sus enlaces.
7. Mantener cerrado el formulario Android hasta publicar responsable, domicilio,
   correo de privacidad y aviso integral revisado.
8. Generar el AAB firmado y completar la ficha cerrada de Play en paralelo; no
   iniciar Día 1 hasta reunir y activar las 20 personas según D-015.

## Impacto

- Los pacientes podrán usar el dominio real sin cuenta y podrán instalar la PWA.
- La raíz, la PWA y el API pasarán a estar expuestos públicamente con TLS.
- El catálogo remoto actual se convierte en fuente productiva; sus cambios ya no
  deben tratarse como ensayos DEV.
- El Admin seguirá local/no publicado. Los endpoints administrativos mantienen
  autenticación y MFA, pero no se enlazan desde superficies públicas.
- Proveedores no podrán registrarse ni abrir su portal desde la build pública.
- La prueba Android puede prepararse en paralelo, pero su recolección y envío de
  invitaciones dependen del aviso y contacto legítimos.
- No se introduce una suscripción nueva. Google Play ya fue pagado según el usuario.

## Riesgos y alternativas

1. **Promover la base enlazada.** Evita duplicar datos y costos, pero deja sin un
   staging remoto independiente. Alternativa: crear otro proyecto Supabase y
   migrar catálogo/secretos; aumenta operación y puede rebasar límites gratuitos.
2. **Tres Workers públicos.** Simplifica DNS y recuperación por versión, pero cada
   uno consume cuota gratuita. Alternativa: Pages para frontends; añade otra forma
   de despliegue y asociación de dominios sin aportar valor al piloto.
3. **PWA antes del aviso completo.** Se descarta: las búsquedas y OCR transitan por
   el backend aunque no se persistan como receta. Si faltan identidad/domicilio,
   sólo se publica el landing informativo, sin formulario ni enlace funcional a
   la PWA.
4. **Android simultáneo.** Es viable técnicamente, pero un AAB firmado y una cuenta
   pagada no sustituyen las declaraciones de Play ni el aviso. Posponer Android no
   bloquea validar el landing/PWA.
5. **Correo gratuito.** Cloudflare Email Routing puede reenviar
   `soporte@pruevia.com.mx` y `privacidad@pruevia.com.mx`; requiere que el usuario
   elija y verifique el buzón destinatario. No se configurará un destino supuesto.

## Ejecución y verificación

El trabajo local preparado debe pasar:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare_patient_first_release.ps1
cd apps/api
npm.cmd run typecheck
npm.cmd test
npm.cmd exec --offline -- wrangler deploy --dry-run --config wrangler.production.toml
```

Después de aprobación, la publicación se acepta sólo si:

- DNS y certificados resuelven los tres hosts exactos;
- `/health` responde con el servicio esperado;
- CORS acepta raíz/app y rechaza un origen ajeno;
- landing no contiene enlaces de proveedor y `app/?provider=1` abre pacientes;
- búsqueda y receta parcial funcionan contra `api.pruevia.com.mx`;
- CSP, HSTS, `nosniff`, permisos y caché se observan en respuestas reales;
- no hay formulario de testers activo sin los datos legales revisados;
- no se publicó Admin ni se enviaron invitaciones;
- se registra versión de cada Worker y timestamp.

Para Android, el script `scripts/build_closed_android.ps1` falla si no encuentra
las cuatro variables de firma. El AAB se revisa localmente y luego se carga
manualmente a la pista cerrada; el enlace de Play no se publica hasta que la ficha,
Data Safety, declaración de salud y política coincidan con la build.

## Recuperación

- Conservar las versiones previas de los Workers y el respaldo remoto anterior.
- Si falla landing o PWA, volver a la versión previa o retirar temporalmente su
  Custom Domain; mantener `PRUEVIA_INDEXABLE=false` durante la primera ventana.
- Si falla API/CORS, revertir `pruevia-api` a la versión anterior y no modificar
  datos clínicos para compensar un error de red.
- No borrar `pruevia-api-dev` hasta completar la ventana de verificación; después
  su retiro será una acción separada y explícita.
- Un retiro de DNS no revierte datos ya recibidos; por eso feedback y testers
  permanecen cerrados durante la primera publicación.

## Aprobación solicitada

Antes de tocar DNS, secretos o desplegar públicamente, se requiere una respuesta
que apruebe exactamente:

1. raíz = landing, `app` = PWA y `api` = Worker;
2. promover el Supabase remoto enlazado como base inicial de producción;
3. publicar primero sólo el landing; abrir después la PWA sin proveedores,
   Admin, feedback, analítica ni formulario Android cuando el aviso esté completo;
4. usar Workers Static Assets y sus Custom Domains;
5. conservar el Worker DEV sólo durante la verificación como recuperación;
6. publicar Android en paralelo únicamente hasta la pista cerrada, sin invitar
   testers todavía.

Además hacen falta, pero no forman parte de una aprobación implícita: nombre legal
del responsable, domicilio autorizado, buzón destinatario para Email Routing y
material de firma Android administrado por el usuario.
