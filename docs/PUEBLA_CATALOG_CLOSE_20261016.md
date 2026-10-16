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
| Total de esta entrega | 175 | 26 | 3 | 29 |

Los tres conceptos reutilizados son AFP, anti-CCP y estriol libre. La muestra
de sus registros de origen permanece como contexto individual; no se cambió
la definición del concepto compartido. Se distinguen BNP/NT-proBNP,
tiroglobulina/anticuerpos, genotipificación/carga viral y fracciones explícitas.
Los nombres abreviados sin aprobación independiente pueden seguir sin resolver.

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
  paginación ni observación final. Se conserva y se prepara un corte nuevo 49.

No se ejecutaron suites formales, migraciones, nuevas capturas comerciales,
modificaciones de permisos ni nuevas publicaciones durante este cierre.

Siguiente trabajo: continuar conceptos con evidencia y vocabulario soportado,
cerrar el inventario completo y resolver los requisitos estructurales de muestras,
métodos e imagen mediante propuestas concretas. La memoria histórica se usa
para reutilizar evidencia; no aprueba por sí sola nuevas órdenes ambiguas.
