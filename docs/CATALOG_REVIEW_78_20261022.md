# Revisión 78: dos órdenes urinarias Lafer incorporadas

## Resultado confirmado

Aplicación única del 22-oct-2026; comprobación independiente de sólo lectura
terminada a las **12:45:29 UTC** (07:45 de Puebla), contra Supabase productivo
`ymtcmfgwuzdqtsbuvzqf`. Operación ordinaria autorizada por D-021/D-022.

Se incorporó **Búsqueda de espermatozoides en orina posterior a eyaculación**,
con un alias completo limitado a Lafer. Cerró dos registros que procedían de
capturas de dos páginas del proveedor; no representan dos sucursales ni ofertas.
El nombre y componente conservan la condición posterior a eyaculación.
Muestra explícita: orina. No se infirieron duración exacta, 24 horas, método,
cuantificación, escala, LOINC o preparación farmacológica.

Fuente primaria: [ficha oficial Lafer](https://lafer.mx/laboratorio-de-andrologia/evaluacion-de-orina-post-eyaculado-eyaculacion-retrograda/),
consultada el 22-oct. La ficha describe la búsqueda en esa orina. La decisión
identifica una orden; no diagnostica eyaculación retrógrada ni equipara el estudio
a examen general de orina, seminograma, cultivo o recuperación terapéutica.

| Indicador después del lote | Total |
| --- | ---: |
| Marcas / sedes | 205 / 291 |
| Conceptos activos | 564 |
| Registros resueltos favorablemente | 3,343 |
| Pendientes abiertos | 4,045 |
| Ofertas activas / migraciones | 234 / 112 |
| Históricos no_match separados | 946 |

La memoria de 66 revisiones y el inventario de 745 grupos del corte anterior
describen el estado previo a este lote. No se presentan como inventario posterior
reconstruido ni como autorización para reutilizar datos automáticamente.

## Cambio local y observación

El renderer admite la construcción literal «de orina», además de «en orina»,
para una muestra declarada en el título completo. Conserva igualdad completa
de alias/título, alcance de proveedor, exclusión de negación y matriz única.
No se cambiaron funciones SQL compartidas, permisos ni el motor de búsqueda.

Antes de aplicar, la preparación releyó los RAW, verificó los dos contextos,
colisiones exactas, conceptos y ledger. La operación provisional terminó en
ROLLBACK: un cliente nuevo confirmó igualdad del estado protegido y ausencia
de sesiones marcadas. Se observaron **16 consultas públicas SQL y 16 del core
con proveedor**. El nombre canónico completo resolvió; el alias del proveedor
resolvió en su core y no tuvo coincidencia pública sin proveedor.

Las variantes examinadas sin condición, anteriores a eyaculación, de 24 horas,
con serie/isotipo, otras matrices, negación y otros estudios no seleccionaron
el nuevo concepto como resuelto. Algunas devolvieron candidatos ambiguos;
eso no constituye equivalencia aprobada. La observación es acotada y no acredita
protección universal ni un recorrido HTTP/JWT de paciente. No se ejecutaron
suites formales.

## Aplicación y comprobación posterior

El SQL auditado se envió **una sola vez**. Confirmó un concepto, un alias y dos
decisiones. El verificador inicial omitió en su lista de cambios permitidos
las dos filas de candidatos exactos que crea el reprocesador existente y se
detuvo después del commit. **No se repitió la escritura.**

La inspección de sólo lectura confirmó ledger `already_applied`, ambos IDs
resueltos al concepto previsto, dos candidatos exactos de puntuación 1 y
ninguna sesión marcada. El hash multiconjunto de todos los candidatos ajenos
a esas dos órdenes coincide con el anterior. RAW completo y hashes originales,
las otras cuatro órdenes Lafer, funciones, permisos, triggers, políticas,
fuentes, identidades, precios, disponibilidad y ofertas permanecen conservados
dentro de la comparación protegida documentada. No se restauraron datos antiguos.

El ejecutor automático sigue detenido; no se retiró STOP ni se modificó su cola.
La propuesta combinada D-006 sigue sin ejecutar. No hubo publicación de API/PWA.

## Evidencia y siguiente acción

Fixture aplicada: [reviewed-aliases-20261022-01.json](../database/data/reviewed-aliases-20261022-01.json),
SHA256 `b17954e4969eeaf76b6fbed45981ca8b38130108f0e0466248df08032c839a64`.
ID canónico: `84180f29-555d-5217-8147-7e97e5b3311e`.

Directorio local ignorado:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-78-lafer-20261022/`.
Conserva investigación, definición, RAW, preparación, observaciones, marcador de
único envío, respuesta, snapshots y `candidate-inspection.json` /
`applied-verified.json`. El primer verificador y su límite permanecen registrados.

Prueba hiposmótica y postcoital (cuatro filas) siguen fuera del lote: requieren
representación revisada de muestra/protocolo. No usar una muestra desconocida
para omitir información ya conocida. Siguiente trabajo: actualizar memoria e
inventario tras este lote y continuar grupos o establecimientos con evidencia
suficiente; no volver a aplicar la fixture.
