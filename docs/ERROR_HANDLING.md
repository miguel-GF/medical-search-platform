# Manejo de errores

Las búsquedas y resoluciones de estudios son operaciones de lectura
deterministas. No se almacenan en caché en el navegador (`no-store`) porque
pueden contener información de salud. Un reintento manual es seguro; el API no
reintenta automáticamente mutaciones administrativas o de telemetría.

## Contrato público

Cuando falla una dependencia del servidor, la respuesta contiene:

| Campo | Propósito |
| --- | --- |
| `code` | Código estable para el cliente |
| `type` | Familia (`timeout`, `connection`, `configuration`, etc.) |
| `error_tag` | Etiqueta operativa, por ejemplo `API.SERVER.TIMEOUT` |
| `severity` | `low`, `medium` o `high` |
| `retryable` | Si volver a intentar puede ayudar |
| `operation` | `individual_search`, `package_search`, `recipe_ocr`, `admin`, etc. |
| `request_id` | Correlación con el log sin registrar la receta |

La PWA y el Admin convierten los códigos conocidos a mensajes en español y no
muestran detalles de Supabase, SQL, tokens ni respuestas de proveedores.

## Etiquetas principales

- `API.SERVER.CONFIGURATION`: falta una variable obligatoria; requiere corregir
  el entorno, no reintentar.
- `API.SERVER.TIMEOUT`: Supabase tardó más que `SUPABASE_TIMEOUT_MS`; es
  reintentable.
- `API.SERVER.CONNECTION`: no se pudo conectar con la dependencia; es
  reintentable.
- `API.SERVER.UPSTREAM` / `API.SERVER.RATE_LIMIT`: la dependencia rechazó o
  limitó la llamada.
- `API.SERVER.INTERNAL`: error inesperado; se registra con severidad alta sin
  exponer el detalle al usuario.
- `API.OCR.UNAVAILABLE` y `API.OCR.RECOGNITION`: fallas controladas del OCR;
  la receta permanece editable y nunca se inventa texto.

Los logs estructurados contienen `event`, `request_id`, `operation`, etiqueta,
severidad, estado HTTP y reintentabilidad. No contienen `q`, texto OCR,
imágenes, tokens ni cuerpos de solicitudes.
