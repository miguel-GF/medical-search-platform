# Puebla: dos sedes y conservación de evidencia SEMIN

21-oct-2026. Operación local contra el proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`; sin despliegue ni migraciones.

## Identidades 41 aplicadas

A las 12:59:02 UTC, después de rollback observado, un único intento de commit
y consulta independiente, quedaron incorporadas dos sedes:

- DENUE 3346935, CMF Q ISSSTE Puebla, Pino Suárez 25, CP 72010.
  Reutiliza la marca ISSSTE existente sin modificar su fila. Conserva el
  interior literal `SN`, el asentamiento DENUE y la clase hospital de origen.
  CLUES PLIST000212 y boletín gubernamental histórico corroboran la identidad;
  no acreditan acceso, operación actual ni estudios disponibles.
- DENUE 8428765, Consultorio Médico Best, Plaza de la Constitución 120,
  CP 73080, Xicotepec; CLUES PLSMP008822. Nueva marca candidata específica,
  sin fusionar con Best Puebla ni atribuir una red jurídica. Website NULL.

Las 204 marcas y 288 sedes anteriores permanecen íntegramente iguales,
incluida la fila completa de ISSSTE. RAW y políticas sin cambios; cero ofertas
nuevas. Hospital Los Pilares y Laboratorios Calidad y Ahorro siguen retenidos
por falta de un puente de identidad suficiente con sus candidatos CLUES.

**Corte verificado: 205 marcas / 290 sedes / 563 conceptos / 3,341 registros
favorables / 4,047 pendientes / 946 históricos no_match / 234 ofertas activas /
112 migraciones.** Las sedes incorporadas están pendientes de verificación
comercial; registrarlas no acredita cobertura de estudios.

Fixture `database/data/provider-identity-review-20261021-06.json`, SHA256
`2a879f6c8bfd2c282d95360dd577c28a8ba6b37f1d24a51ffdf7aee695192d49`.
Recibo independiente y snapshots completos:
`collectors/artifacts/puebla-expansion-20261009/identity-review-41-research-20261021/applied-verified.json`.

## Collector SEMIN: evidencia conservada localmente

El adapter ahora conserva `sinAcro` y el vínculo declarado producto → IDs de
`available_sucursales`, con límites de tamaño y marcadores de contenido parcial
o inválido. No conserva contactos anidados ni convierte las referencias en
aliases, disponibilidad comprobada u ofertas. Los precios y campos previos
mantienen su significado; no se añadieron solicitudes de red.

A las 13:03–13:05 UTC se derivaron tres registros locales desde cuerpos HTTP reales
capturados a las 12:49:51 UTC: productos 5391, 5507 y 5536. Se verificaron hashes
de origen, sintaxis AST y conservación íntegra de los campos anteriores,
observaciones e identificadores; sólo se excluyó la hora automática de creación
al comparar objetos. Cada producto conserva nueve IDs declarados y su `sinAcro`
literal. No se ejecutaron suites ni se ingresó este bloque en la base.

Artefactos, script reproducible y bloque para evaluación posterior:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/semin-evidence-preservation-20261021/`.
`derived-records.json` conserva fecha y SHA de captura separados de la derivación;
no representa una nueva captura de la fuente.

## Significado comercial observado

La observación pública en navegador y código de SEMIN de 12:55–12:56 UTC mostró
Microalbuminuria Ocasional: **323 MXN sucursal (`precioApoyo`) y 306 MXN online
(`precioVenta`)**. No se observó membresía. El campo `precioNormal` no aparece
en la tarjeta examinada; no se demostró su vínculo con agenda online.

Ver más llevó al inicio de sesión; no se observó selector de dos sucursales.
Los tres productos contienen la misma lista de nueve sedes: eso no demuestra
disponibilidad selectiva. El recorrido se detuvo antes del acceso autenticado,
sin alterar storage ni enviar formularios. Hubo errores React de hidratación,
aunque la tarjeta y navegación funcionaron.

Capturas, recibos y límites:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/semin-commercial-scope-20261021/REPORT.md`.

## Continuidad

Evaluar el bloque de evidencia sin perder los originales. Antitrombina III e
inhibidor C1 aún no distinguen actividad de antígeno; microalbuminuria no aclara
concentración frente a cociente. No cerrar esas diferencias por coincidencia
de nombre. La evaluación propuesta del resolvedor compartido sigue pendiente
de aprobación específica D-006; no se ejecutó ni activó con este trabajo.
