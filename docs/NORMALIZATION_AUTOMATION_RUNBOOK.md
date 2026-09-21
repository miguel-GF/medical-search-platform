# Runbook: reducir la cola de normalización

## Qué significa el número

El número que aparece en Admin es un conteo de registros de proveedores que
todavía no tienen una decisión final. No representa el número de pacientes,
estudios clínicos únicos ni pantallas que una persona deba abrir una por una.

La consulta remota de sólo lectura del 18-sep-2026 reportó 7,028 registros
abiertos: 6,804 de Salud Digna, 140 de SEMIN, 57 de Chopo y el resto de
proveedores pequeños. Esas filas están agrupadas en 1,188 combinaciones
proveedor+etiqueta de 8 proveedores: 967 grupos de Salud Digna, 140 de SEMIN,
57 de Chopo y 24 grupos de los demás proveedores. Los registros ya cerrados como
`no_match` se conservan para auditoría pero no forman parte del trabajo abierto.

## Qué es automático y qué no

1. El collector captura la fuente y conserva la evidencia original.
2. La normalización limpia, deduplica y agrupa por proveedor y etiqueta.
3. El reproceso exacto resuelve por lotes sólo cuando hay un único nombre
   canónico o un alias previamente aprobado.
4. Una aprobación manual de un alias de proveedor se reutiliza en futuros
   registros equivalentes; después el lote exacto puede resolver todas las filas
   que correspondan.
5. Una similitud fuzzy o una sugerencia de IA sólo ordena candidatos. No puede
   aprobar una equivalencia clínica.

La primera carga puede tener una cola grande porque el catálogo canónico todavía
no contiene las etiquetas observadas por cada proveedor. La automatización crece
con cada alias aprobado y con cada nueva corrida; no es seguro inventar esos
aliases sólo para hacer desaparecer el contador.

## Procedimiento operativo

### 1. Medir antes de tocar datos

Usar el reporte de sólo lectura:

```text
database/reports/puebla_normalization_backlog.sql
```

El resultado es una fila por proveedor y etiqueta normalizada, ordenada por el
número de registros que puede desbloquear una decisión.

### 2. Ejecutar el camino seguro

Desde el resumen del Admin:

- **Analizar coincidencias** hace un preview y no modifica datos.
- **Resolver seguras** aplica como máximo 200 coincidencias exactas o aliases
  aprobados, con auditoría e idempotencia.
- Repetir en lotes sólo después de revisar el preview y la evidencia.

El RPC es `public.api_admin_reprocess_exact_normalizations`. Los casos ambiguos,
los nombres no únicos y los conceptos clínicamente distintos permanecen en la
cola.

En el entorno actual el reproceso manual se ejecuta desde el Admin. El scheduler
ya está desplegado en `pruevia-api-dev`, con trigger horario, pero permanece
deshabilitado porque `NORMALIZATION_REPROCESS_ENABLED` no está configurada.
Además, el Worker necesita `ALLOWED_ORIGINS`/`ALLOWED_ORIGIN` con orígenes HTTPS
reales para responder tráfico de producción; no se debe resolver configurando `*`.
Para activarlo debe existir un actor administrativo configurado, límite por
corrida, idempotencia, auditoría y una ventana de monitoreo. El scheduler sólo
aplica exactos/aliases aprobados; nunca aprueba fuzzy matching.

### 3. Revisar por impacto

Priorizar etiquetas repetidas que tengan una fuente oficial y una equivalencia
clara. Al aprobar un alias se debe conservar el proveedor, el estudio canónico,
la razón y la evidencia. Si no existe equivalencia segura, marcar `no_match` con
motivo; eso evita publicar una oferta inventada.

La migración y cualquier aplicación remota del lote deben revisarse y aprobarse
antes de ejecutarse en Supabase. El contrato del piloto Android ya fue ejecutado
en DEV y pasó `22/22`; este documento no autoriza por sí mismo nuevas escrituras
remotas ni la activación del scheduler.

## Correo de soporte con Cloudflare

Cloudflare Email Routing permite crear una dirección como
`soporte@tudominio.com` y reenviar el correo entrante a una dirección verificada
de Gmail u Outlook. No crea por sí solo un buzón completo con IMAP, contraseña o
una bandeja independiente.

Pasos:

1. Agregar el dominio a Cloudflare y verificar que sus DNS estén activos.
2. En Email Routing, agregar y verificar la dirección de destino personal.
3. Crear la regla `soporte@tudominio.com` → destino verificado.
4. Configurar el landing con `PRUEVIA_SUPPORT_EMAIL`.
5. Si Pruevia debe enviar correos automáticos, contratar/configurar un servicio
   de envío separado; el reenvío de entrada no sustituye SMTP o una API de correo.

No guardar contraseñas ni tokens en `apps/landing/.env` versionado. El valor de
`PRUEVIA_SUPPORT_EMAIL` sí puede ser público porque sólo es una dirección de
contacto.
