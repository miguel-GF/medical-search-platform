# Puebla: dos estudios y dos establecimientos incorporados

Investigación del 20-oct-2026; aplicación y observación independiente del
**21-oct, 04:43–04:46 UTC** (noche del 20-oct en Puebla). Proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`, operación local autorizada por D-021/D-022.
Sin migraciones, despliegues, fuentes nuevas de ingesta ni suites formales.

## Revisión68: estudios aplicados

| Orden identificada | Procedencia y alcance |
| --- | --- |
| Vitamina D 25-hidroxi total | Chopo22211 declara total. Concepto separado del anterior sin fracción especificada; matriz exacta desconocida. |
| Actividad de proteína C de coagulación en plasma | SEMIN5556 declara actividad y plasma con citrato. No se infiere método cromogénico o coagulométrico. |

Son dos conceptos y dos registros favorables nuevos. La definición anterior de
vitamina D genérica permanece íntegra. Los tres RAW examinados conservan payload,
hash, título y preparación; el tercero, factorXIII, sigue pendiente. No se aprueban
equivalencia de resultados, LOINC, propiedad, escala, método o duración no escritos.

Las referencias primarias capturadas con HTTP200 y SHA256 fueron
[Labcorp081950](https://www.labcorp.com/tests/081950/vitamin-d-25-hydroxy),
[086340](https://www.labcorp.com/tests/086340/factor-xiii-activity) y
[117705](https://www.labcorp.com/tests/117705/protein-c-functional).
El [título propio de Chopo](https://www.chopo.com.mx/puebla/25-hidroxi-vitamina-d-total-calciferol)
se consultó por webtool; también se conserva su captura anterior. La recuperación
fresca de factorXIII y del endpointSEMIN falló en webtool: sus títulos/muestras
proceden del RAW completo reconsultado, sin presentar ese fallo como captura200.

Una transacción rollback observó **28 consultas públicas y las mismas28 con
alcance de proveedor**. Los nombres canónicos se resolvieron; los nombres de
origen se resolvieron en su proveedor y pueden seguir sin coincidencia pública.
Fracciones D2/D3, otros metabolitos, libre, fraccionada, antígeno, proteínaS,
proteínaCreactiva, genPROC, métodos explícitos, otras muestras, series y perfiles
no seleccionaron automáticamente los nuevos conceptos en los casos examinados.
Esto no acredita conservación universal de calificadores.

El borrador aislado y su evidencia se conservaron; la versión revisada añadió
únicamente alcance/metadata de observación, sin cambiar conceptos o aliases.
La cola55→56 conservó todos los pins anteriores. El ejecutor completó sus propios
preview/commit/ledger; un cliente independiente confirmó dos decisiones correctas,
RAW intactos, definición genérica anterior y políticas conservadas.

Fixture aplicada: `database/data/reviewed-aliases-20261020-03.json`.
SHA256: `95a5c4ddf57e95107f919ca5a7a9f7286ddfd4475a6801402602b44115cc15fb`.
Evidencia ignorada en expansión Puebla:
`clinical-research/review-68-explicit-singletons-20261020/`, especialmente
`observations.json`, `observation-receipt.json`, `queue-enqueued.json` y
`applied-verified.json`.

La API local real devolvió ambos nombres como resueltos, **con cero ofertas**.
Identificar estas órdenes no crea cobertura comercial, precios o disponibilidad.

## Retenciones nuevas y causa concreta

- **FactorXIII, una fila Chopo:** título explícito de actividad/plasma, identidad
  nominal respaldada. El importador no admite `provider_display_name` como guard
  del atributo de muestra. No se eliminó plasma ni el marcador para eludir el
  contrato. Candidato y motivo conservados fuera de cola.
- **CélulasLE, ocho filas SD, revisión67:** título y fenómeno celular respaldados
  por tres capturas primarias200; no se infieren muestra o técnica. Lectura fresca
  confirmó los ocho RAW completos. Un rollback de25 consultas públicas y25 de
  proveedor demostró que el nombre canónico seguido de **IgG** o **x2** selecciona
  incorrectamente la orden genérica. Se conservaron borrador/evidencia fuera de
  `database/data` y cola; ledger `not_applied`, contadores intactos. No se cambió
  el nombre para hacer desaparecer el fallo. ANA se resolvió como ANA, no comoLE.

Evidencia LE: `clinical-research/review-67-candidates-20261020/` bajo expansión
Puebla: capturas, RAW, `observations.json` y `observation-receipt.json`.
Las ocho filas no se contabilizan como resueltas. Los otros ocho grupos/64RAW
examinados por el agente tienen retenciones individuales, no aprobaciones nuevas.
El siguiente trabajo clínico es conservar requisitos cortos/series en la propuesta
aislada del resolvedor antes de aprobar estas órdenes.

## Identidad35: dos establecimientos candidatos

| Establecimiento | Identidad y domicilio propios conservados |
| --- | --- |
| LABORATORIO DE ANALISIS CLINICOS BIO-TECK | DENUE8559379; Tepeaca, calle3Sur123, CP75200. Referencia CLUES PLSMP009814, fila44745. |
| HOSPITAL MEDICA NORTE | DENUE3494076; Acatzingo de Hidalgo, avenida16deSeptiembre1231, CP75150. Referencia CLUES PLSMP001723, fila43936. |

Los nombres de referencia contienen las mismas palabras completas en otro orden;
se revisaron estos dos pares, sin aprobar una regla automática por tokens/fuzzy.
Municipio, localidad, CP, tipo de vía, vía, exterior completo e interiores vacíos
concuerdan. BIO-TECK conserva BARRIO CENTRO de DENUE y deja documentado COLONIA
TEPEACA CENTRO de CLUES, sin sustituir u homologar esos descriptores.

Se reutilizaron el XLSX de agosto y el extractor existente con hash fijado:
64,450 filas nacionales, 3,779 Puebla y una clave exacta por extracción. El
estado mensual no acredita operación actual. Los datos incorporados son identidad
DENUE licenciada; CLUES es referencia de investigación, no fuente nueva aprobada.
Ambas marcas quedan `verification_pending`, sedes `pending`, websiteNULL.
Se conservan clases DENUE y tipos branch/hospital. Sin estudios u ofertas nuevos.

Rollback, un único envío de commit y observación independiente confirmaron dos
marcas/sedes/bindings/auditorías/observaciones nuevas. Las174 marcas y258 sedes
anteriores permanecen byte a byte iguales como filas JSON; RAW, políticas y
contadores clínicos intactos. El primer observador esperaba contadores opcionales
de reutilización que este lote nuevo no emite: se corrigió el observador,
conservando el recibo y comprobando ledger vacío antes de la operación definitiva.

Fixture: `database/data/provider-identity-review-20261020-01.json`.
SHA256: `9964cc3f7cd7d19b842455266adc4b6c7011a666f23162d3e5cc5f2ddb8d81b0`.
Evidencia: `identity-review-35-research-20261020/` bajo expansión Puebla;
fuentes, extracciones, snapshots, SQL y `applied-verified.json`.

## Operación local recuperada y estado

Al reanudar el21-oct se confirmó que PID16372 ya no existía, aunque el archivo
de estado conservaba un escaneo anterior. No se reinició por timeout: se buscaron
procesos reales, se verificó ausencia de STOP y se leyeron **55ledgers remotos**,
todos `already_applied`, con hashes íntegros y lock liberado. Sólo entonces se
restauró el ejecutor existente, PID1812. Aplicó el lote revisado y quedó vigilando.

API8787, Admin5173 y Paciente8080 respondieronHTTP200 a las04:46:21UTC. Es salud
HTTP local observada; no acredita publicación nueva o todos los flujos privados.
Recibos: `collectors/artifacts/local-review-queue/recovery-20261021/`.

| Estado independiente tras las dos operaciones | Total |
| --- | ---: |
| Conceptos activos | 556 |
| Registros favorables | 3,327 |
| Pendientes abiertos | 4,061 |
| Históricos no_match fuera de cola | 946 |
| Marcas / ubicaciones | 176 /260 |
| Ofertas / migraciones | 234 /112 |

Continúa pendiente completar la cobertura estatal y obtener evidencia comercial
por estudio/sucursal. Búsqueda y navegación móvil nuevas siguen preparadas
localmente, sin publicación adicional.

## Inventario completo posterior

Terminó a las **04:48:32 UTC**, con paginación completa: **4,061 pendientes en
752 grupos**, 556 conceptos y1,335 términos. La memoria shadow contiene62
revisiones aplicadas,417aliases,436reglas/contextos y2,967 filas históricas
reutilizables por contexto exacto. Las56 entradas de cola quedaron verificadas
por ledger y hash, conservando los pins anteriores.

Todos los4,061 pendientes siguen requiriendo evidencia según esa herramienta;
la memoria no aprobó ninguno. Contadores, fuentes y cola iguales antes/después,
resolvedor conservado por MD5 y253archivos de cortes previos idénticos por SHA256.
No atribuir crecimiento o cierres a esta lectura. Evidencia completa:
`collectors/artifacts/normalization-memory-after-review-68-20261021-v3/`,
incluidos `observation.json`, páginas, contextos, memoria y recibo de cola.
