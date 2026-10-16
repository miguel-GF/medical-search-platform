# Catálogo e instituciones: cierre del 16-oct-2026 UTC

Entorno: Supabase `ymtcmfgwuzdqtsbuvzqf`, la base productiva existente.
Fecha local: noche del 15-oct. Autorización: D-021/D-022 para investigación y
datos claros; D-023 para commits locales por sección, sin push.

## Estudios aplicados

| Revisión | Filas cerradas | Conceptos nuevos | Reutilizados | Aliases |
| --- | ---: | ---: | ---: | ---: |
| 45 ajustada, `20261015:02` | 34 | 7 | 0 | 7 |
| 46, `20261015:03` | 56 | 7 | 0 | 7 |
| 47, `20261015:04` | 64 | 8 | 0 | 8 |
| 48 ajustada, `20261016:02` | 5 | 2 | 3 | 5 |
| 49, `20261016:01` | 16 | 2 | 0 | 2 |
| 50, `20261016:03` | 10 | 0 | 3 | 3 |
| Total de esta entrega | 185 | 26 | 6 | 32 |

Los tres conceptos reutilizados son AFP, anti-CCP y estriol libre. La muestra
de sus registros de origen permanece como contexto individual; no se cambió
la definición del concepto compartido. Se distinguen BNP/NT-proBNP,
tiroglobulina/anticuerpos, genotipificación/carga viral y fracciones explícitas.
Los nombres abreviados sin aprobación independiente pueden seguir sin resolver.

La revisión50 reutiliza además CA 27.29, CA 72-4 y anticuerpos ZnT8: diez filas,
ningún concepto duplicado. Su observación independiente del 16-oct 03:48 UTC
comprobó seis consultas públicas, tres de proveedor, once variantes cercanas,
59 originales conservados y 49 contextos vecinos intactos. Las tres definiciones
existentes permanecen iguales; suero SEMIN queda como atributo de origen, sin
inferir muestra o isotipo para ZnT8. Catálogo 525, pendientes 4,286; cola44.

La cola sólo ejecutó fixtures explícitas con hash, comprobación del estado
previo, guardas RAW, rollback observado y ledger. El directorio de borradores
no concede aprobación. La comprobación posterior consulta el resolver v6 y
la API pública real, conserva UUID, fuentes, originales y atributos. La función
legacy no acredita por sí sola el comportamiento público actual.

Recibos locales ignorados, bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/`:

- `review-45-antibodies-adjusted/independent-applied-verified.json`.
- `review-46-individuals/independent-applied-verified.json`.
- `review-47-individuals/independent-applied-verified.json`.
- `review-48-adjusted/` y `review-49-individuals/`: preparación, observación
  rollback, guardas y resultados públicos posteriores.
- `review-50-individuals/independent-applied-verified.json` y
  `review-50-observed-close.json`: aplicación, reutilización y línea base posterior.

## Instituciones aplicadas

Identidades 18–23 añaden ocho marcas y ocho ubicaciones, hasta **82 marcas y
166 ubicaciones**. Son Ythalia Medical, Hospital Angelopolitano, Fifty Doctors
San Manuel, Hospital para el Niño Poblano, CHRISTUS MUGUERZA Hospital UPAEP,
Hospital General de Tepeaca, Hospital General de Acatlán de Osorio y Hospital
Comunitario de Cuacnopalan. Los nombres históricos y discrepancias de código
postal, colonia o vialidad permanecen en la evidencia.

Cada identidad conserva registro DENUE, fuente independiente, auditoría y
observación; se ejecutaron rollback, commit único y observación independiente.
Las fuentes históricas de gobierno prueban identidad histórica, sin convertirlas
en garantía de operación actual. Una web no comprobada permanece NULL.
El sitio ajeno que ahora ocupa un dominio antiguo de Fifty Doctors fue excluido.

Se admitió el código DENUE existente 622311 como hospital de especialidades
privado, conservando su clasificación original y el tipo que ya permite el
modelo. No hubo migración. Recibos: `identity-review-18/` a `identity-review-23/`
en los artefactos de expansión Puebla.

Después del corte completo49 se aplicó identidad24: Hospital General Ciudad
Serdán, Hospital Integral de Ayotoxco de Guerrero con Medicina Tradicional y
Hospital Integral Guadalupe Victoria. Tres candidatos distintos, DENUE622112,
websNULL, discrepancias de asentamiento/vialidad conservadas. La evidencia
oficial de 2021 es histórica y no acredita operación actual ni servicios.
Rollback, commit único y observación independiente terminaron a las 03:49 UTC.
Recibo: `identity-review-24/applied-verified.json`. Registro final:
**85 marcas / 169 ubicaciones / 525 conceptos / 4,286 registros pendientes**,
con 234 ofertas y 112 migraciones. En total, identidades18–24 añaden once
marcas y once ubicaciones respecto del cierre17.

El primer preview de identidad24 devolvió correctamente tres instituciones,
pero el driver local aún esperaba una. Se detuvo después de rollback, antes de
enviar commit. Se conservó ese recibo, se corrigió la aserción a tres y se
revalidaron ledger vacío y línea base antes del único commit. No se cambió la
fixture ni se repitió una escritura confirmada.

**Las 234 ofertas comprobadas no aumentaron con estas identidades.** Identificar
un hospital no confirma que una sede realice un estudio ni su precio.

## Pendientes que conservan su evidencia

- El borrador original 45, `reviewed-aliases-20261015-01.json`, no se aplicó:
  FTA-ABS necesita conservar el método explícito; no se sustituyó por NULL.
- El borrador original 48, `reviewed-aliases-20261015-05.json`, no se aplicó:
  una observación real dentro de rollback mostró que «factor reumatoide IgM»
  elegía el concepto genérico propuesto. Se excluyeron las ocho filas de factor
  reumatoide; las variantes cuantitativas y semicuantitativas siguen pendientes.
  No se activó ningún cambio del resolver para ocultar ese problema.
- Cultivos con muestras fuera del vocabulario del importador y protocolos de
  imagen con proyecciones/contraste requieren conservar esos atributos antes
  de cerrar equivalencias. Las propuestas locales de método e imagen siguen
  sin activarse y sujetas a D-006.
- El cierre completo 47 quedó interrumpido: su `memory.json` aislado no acredita
  paginación ni observación final. Se conservó junto al corte45 y se completó el
  nuevo corte49 a las 03:46:45 UTC: 4,296 pendientes en 791 grupos, 1,265 términos,
  49 revisiones / 378 aliases / 397 reglas / 2,732 contextos históricos reutilizables.
  Cola43 verificada por ledger/hash, fuentes y contadores estables; resolver y
  24 archivos previos intactos. Evidencia: `collectors/artifacts/normalization-memory-after-review-49-v3/`.

No se ejecutaron suites formales, migraciones, nuevas capturas comerciales,
modificaciones de permisos ni nuevas publicaciones durante este cierre.

Siguiente trabajo: continuar conceptos con evidencia y vocabulario soportado,
cerrar el inventario completo y resolver los requisitos estructurales de muestras,
métodos e imagen mediante propuestas concretas. La memoria histórica se usa
para reutilizar evidencia; no aprueba por sí sola nuevas órdenes ambiguas.

Servicios observados HTTP200 en landing/app/API públicos y API/Admin/Paciente
locales; recibo `collectors/artifacts/local-stack/endpoints-catalog-close-20261016.json`.
Los tres agentes terminaron sus tareas de investigación e inventario; no se
presenta una investigación futura como un proceso que siga ejecutándose solo.
