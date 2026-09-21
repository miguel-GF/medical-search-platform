# Opciones de dominio de Pruevia

Estado: **investigación**, sin compra ni registro ejecutado. Última consulta:
13-sep-2026. La disponibilidad de un dominio puede cambiar entre consultas y
debe confirmarse en el registrador justo antes de pagar.

## Shortlist

| Opción | Señal observada | Uso posible | Nota |
| --- | --- | --- | --- |
| `pruevia.mx` | Parecía libre | Marca principal para México | Opción corta y clara para el piloto Puebla. |
| `pruevia.app` | Sin registro RDAP observado | Producto/app internacional | Requiere HTTPS, que Cloudflare puede gestionar. |
| `pruevia.health` | Sin registro RDAP observado | Marca orientada a salud | Puede ser una extensión premium; confirmar precio. |
| `pruevia.com.mx` | NIC México sin resultado en la consulta | Alternativa comercial mexicana | Confirmar directamente en NIC México. |
| `prueviasalud.com` | Sin registro RDAP observado | Marca descriptiva | Alternativa si la opción corta no está disponible. |
| `prueviahealth.com` | Sin registro RDAP observado | Expansión internacional | Más largo, pero conserva la marca. |
| `prueviamedica.com` | Sin registro RDAP observado | Marca descriptiva | Más largo y con una promesa de categoría más específica. |
| `pruevia-puebla.com` | Sin registro RDAP observado | Piloto geográfico | No conviene como dominio principal si se planea crecer. |

`pruevia.com` ya estaba registrado en la consulta y no forma parte de la
shortlist. Ninguna señal anterior es una reserva ni una garantía de compra.

## Arquitectura prevista

Si se aprueba un dominio raíz, la asignación propuesta es:

```text
https://pruevia.<tld>/          landing pública
https://app.pruevia.<tld>/     paciente
https://admin.pruevia.<tld>/   operaciones
https://api.pruevia.<tld>/     Worker API
```

La landing permanece independiente del API y no debe indexarse hasta configurar
los destinos reales, revisar el aviso legal/contacto y activar explícitamente
`PRUEVIA_INDEXABLE`. El Worker acepta actualmente el origen único heredado
`ALLOWED_ORIGIN`; para `app` y `admin` distintos está preparada la opción
`ALLOWED_ORIGINS`, que exige una lista exacta y HTTPS en producción. No se han
creado DNS, rutas customizadas ni certificados en esta investigación.

## Verificación y aprobación

Antes de comprar:

1. Consultar el [Domain Check de Cloudflare](https://developers.cloudflare.com/api/resources/registrar/methods/check/)
   y, para `.mx`, el [WHOIS de NIC México](https://www.whois.mx/).
2. Comparar precio de alta, renovación, privacidad, restricciones de registro
   y disponibilidad de DNSSEC/HTTPS.
3. Registrar en `DECISIONS.md` el dominio elegido, sus subdominios, cuenta
   propietaria y ventana de recuperación.

La compra, asociación DNS y publicación son cambios externos críticos. Este
documento sólo conserva la investigación del agente anterior y no los autoriza.
