# Publicación privada del Admin

Estado: API publicada; Admin preparado, publicación externa pendiente de
configurar/verificar Cloudflare Access.

## Alcance aprobado

- Host: `https://admin.pruevia.com.mx`.
- Acceso exterior: Cloudflare Access, únicamente para el correo del operador aprobado.
- Acceso de aplicación: Supabase Auth, `ADMIN_USER_IDS` con el UUID exacto y MFA TOTP/AAL2.
- CORS del Worker: raíz, PWA y Admin; sólo orígenes HTTPS exactos.
- El Admin no se enlaza desde landing ni PWA.
- Proveedores, documentos de proveedores, invitaciones y notificaciones continúan cerrados.

Cloudflare Access funciona como primera barrera de red; no reemplaza la sesión
Supabase ni el MFA del Admin. La configuración de Access debe tener una política
`Allow` para el correo aprobado y ninguna política `Bypass` para este hostname.

## Artefactos preparados

- `apps/admin/wrangler.production.toml` publica los assets Vite en el custom
  domain `admin.pruevia.com.mx` como SPA.
- `apps/api/wrangler.production.toml` incluye el origen exacto del Admin en
  `ALLOWED_ORIGINS`.
- `scripts/prepare_admin_release.ps1` exige variables públicas de build,
  ejecuta typecheck/tests/build y genera headers CSP con API y Supabase exactos.

El Worker `pruevia-api` ya está publicado en producción como versión
`7c78e0bc-f538-45b1-8111-400a64dcd10a`; su health respondió `200`, el preflight
del Admin respondió `204` y un origen ajeno recibió `403`.

## Variables necesarias

El build requiere, sólo en el entorno local o CI protegido:

```text
VITE_API_URL=https://api.pruevia.com.mx
VITE_API_ALLOWED_HOSTS=api.pruevia.com.mx
VITE_SUPABASE_URL=https://<proyecto>.supabase.co
VITE_SUPABASE_ALLOWED_HOSTS=<proyecto>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<clave-publicable>
```

La clave publicable puede formar parte del bundle; nunca se compilan
`SUPABASE_SECRET_KEY`, `ADMIN_USER_IDS` ni tokens de Cloudflare.

## Secuencia externa

1. En Cloudflare Zero Trust, crear una aplicación Self-hosted para
   `admin.pruevia.com.mx`.
2. Configurar la política Allow sólo para el correo del operador aprobado; comprobar
   que no exista Bypass.
3. Confirmar que el proyecto Supabase de producción contiene la cuenta del
   operador, su UUID, contraseña inicial y factor TOTP verificado.
4. Cargar en el Worker de producción los secretos de Supabase y
   `ADMIN_USER_IDS` sin imprimirlos ni versionarlos.
5. Publicar API y Admin, comprobar DNS/TLS, preflight CORS, Access, login MFA,
   lectura del dashboard y una mutación auditable.
6. Confirmar que un origen ajeno recibe `403`, un usuario Supabase no permitido
   recibe `401/403`, AAL1 recibe `403` y las rutas de proveedor siguen cerradas.

## Estado actual y recuperación

La consulta API de Cloudflare no pudo administrar Access con el OAuth local por
falta de permisos Zero Trust; la política debe crearse en el panel de Cloudflare
o con un token que tenga sólo los permisos Access necesarios. No se expuso el
token existente.

Si falla la verificación, retirar el custom domain del Admin o desactivar su
despliegue sin tocar la base de datos. Mantener la versión previa del Worker API
y no cambiar permisos SQL para resolver un problema de acceso.
