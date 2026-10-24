# Dirección de la sucursal en los resultados

23-oct-2026 local; publicación 24-oct04:53UTC. El usuario señaló que se mostraba
el nombre de las sucursales sin su dirección y pidió incluirla.

## Diagnóstico y cambio

La base conserva `address_line_1`, `address_line_2`, localidad y código postal,
pero el contrato de búsqueda y los modelos del paciente no presentaban dirección.
Se agregó una lectura acotada de direcciones comerciales existentes. La API sólo
consulta IDs de ubicaciones que ya aparecen en su respuesta normal y añade
`location.address` o `locations[].address`, sin alterar precios o cobertura.

El RPC nuevo es de lectura, acepta hasta500 IDs, filtra sucursales activas de
proveedores con ofertas activas y tiene permiso exclusivamente para el servidor.
No tiene una ruta pública de enumeración ni permisos para anon/authenticated.
No se modificaron direcciones, identidades, estudios, aliases, ofertas o precios.

La PWA muestra la dirección bajo el nombre de la tarjeta de sucursal, en su
detalle móvil, en tarjetas de ofertas y en opciones de solución de órdenes.
Si no hay calle registrada, muestra «Dirección no disponible». Una oferta de
red sin ubicación no recibe una dirección atribuida; conserva la aclaración de
sucursal por confirmar. La dirección no acredita disponibilidad del estudio.

## Ensayo, aplicación y comprobación

El primer ensayo con reversión no obtuvo la dirección de la sucursal de prueba:
el filtro exigía una oferta con scope directo de ubicación. Una lectura
independiente confirmó que el Chopo Plaza Circuito tiene dirección y aparece en
la búsqueda normal, pero cero scopes directos de esa clase. No se repitió aquel
intento. Estado protegido restaurado, función inexistente y ledger116 conservado.

La propuesta corregida conserva la elegibilidad de la búsqueda normal, incluidos
los scopes de red/mercado que ésta expande a una sede. Se ensayó en una carpeta
nueva: dirección existente, sucursal desconocida vacía, límite de IDs y permisos
comprobados; reversión independiente. Migración117 aplicada una sola vez:
`20261024053000_public_branch_addresses.sql`. Filas de ubicaciones con el mismo
hash, mismos conteos de conceptos/ofertas y mismas cuatro funciones clínicas.

Verificación HTTP real: búsqueda de biometría hemática,13 sucursales,13 direcciones
presentes y correspondencia exacta por ID con el RPC. Combinación de órdenes
HTTP200, tres opciones de sede con dirección. No acredita todas las direcciones
de las293 ubicaciones ni que cada oferta esté comercialmente verificada.

Navegador público390×844: búsqueda, selección de Chopo y dirección de Plaza
Circuito visible. Texto observado: «JUAN PABLO II510, BOULEVARES, Puebla,
C.P.72440», con el formato completo de la fuente en la captura. Sin errores de
página y build correcto. No se accedió al teléfono físico del usuario.

## Versiones y recuperación

- API: `ae3c96ba-42e5-42c4-81dc-f577a976dbd0`.
- Patient: `faa1b79e-b58c-4142-8e38-9476ecc54fea`.
- Build: `0de0628899533733f1141caddc484ae3922587c548943993a59988b4f938cf34`.
- SHA256JS: `5b9cec1f82b6859367152efd7422513b59cabb25c01af7fec51d28641195eac8`.

Conteos agregados, aviso globalv4, Android opcional y gates anteriores conservados.
Landing y Admin no se volvieron a desplegar para este cambio. TypecheckAPI y
compilaciónFlutter correctos; observaciones reales, sin suite formal adicional.

Evidencia: `collectors/artifacts/branch-address-release-20261023/`, con primer
intento preservado, `address-scope-v2/` para la propuesta corregida y recibos
`api-live-verification.json`/`mobile-observed.json`. Captura:
`public-mobile-address.png`. Sin secretos ni datos de pacientes.

Recuperación: API `6398935d-4b7c-4b71-b181-6841b8c5ee1c` y Patient
`28e7a8c6-6790-4770-9d7d-5339439d2763`; conservar la migración aplicada y el RPC
sin uso. No borrar ledger ni modificar direcciones para revertir la presentación.
La recuperación no se ejecutó. Queda pendiente la comprobación de recepción en
la instalación particular del usuario y la depuración comercial del catálogo.
