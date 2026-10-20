# Revisión 65: anticuerpos totales anti-Chagas y cobertura pequeña

20-oct-2026. Herramientas locales contra la base productiva enlazada.
Lote aplicado por el ejecutor existente a las 13:08 UTC y observado por un
cliente independiente a las **13:10:49 UTC**.

## Ocho registros incorporados

Los ocho títulos Salud Digna `ANTICUERPOS TOTALES ANTI CHAGAS` se identificaron
como anticuerpos totales contra Trypanosoma cruzi (Chagas), con un concepto nuevo
y alias exclusivo del proveedor. Se conserva «totales» literalmente: no se
expande a una pareja IgG/IgM ni a composición de un panel confirmatorio. Matriz,
método, duración y escala permanecen desconocidos; sin equivalencia analítica,
LOINC aprobado, oferta, precio o disponibilidad nuevos.

La [referencia Mayo 615244](https://www.mayocliniclabs.com/test-catalog/Overview/615244)
y la [información primaria CDC](https://www.cdc.gov/chagas/hcp/diagnosis-testing/index.html)
documentan la identidad serológica y el agente de Chagas. La ficha Mayo está
obsoleta/no disponible para ordenar: se usó para identidad, nunca como oferta
actual ni para trasladar suero, ELISA o composición al protocolo del proveedor.
GET directo Mayo/CDC devolvió 403; la lectura web obtuvo contenido y ambas vías
se conservaron por separado. Una carcasa HTTP 200 de Quest no sustentó decisiones.

Los 16 RAW FTA-ABS IgG/IgM ya investigados conservan su identidad e isotipo,
pero siguen retenidos hasta representar y observar el método estructurado.
No se les asignó un concepto genérico para aumentar resoluciones.

## Observación y aplicación

La lectura fresca confirmó 24 payloads completos idénticos al original y aún
pendientes: ocho Chagas y 16 FTA-ABS. Un rollback autorizado observó 25 consultas
públicas y las mismas 25 con alcance del proveedor. IgG, IgM, método, matriz,
otra especie, PCR y panel no se seleccionaron automáticamente como total.
Cuantificación y algunos requisitos cortos conservaron ambigüedad. Esto no
acredita filtrado universal de calificadores ni aprueba todos los candidatos.

La fixture definitiva sólo actualizó notas y alcance respecto del borrador.
El runner volvió a ejecutar preview, commit y ledger completos. Cola 54→55,
pins anteriores conservados. La lectura independiente confirmó ocho decisiones
e IDs correctos; 24 RAW y etiquetas íntegros, estados de los 16 FTA-ABS intactos,
fuentes/políticas sin cambios y definición con atributos desconocidos conservados.
No se ejecutaron suites formales.

| Estado productivo observado | Total |
| --- | ---: |
| Conceptos activos distintos | 554 |
| Registros favorables | 3,325 |
| Pendientes abiertos | 4,063 |
| Históricos no_match fuera de cola | 946 |
| Instituciones / ubicaciones | 174 / 258 |
| Ofertas / migraciones | 234 / 112 |

Fixture aplicada: `database/data/reviewed-aliases-20261020-01.json`.
SHA256: `b1d2c0a16d46dcb77d533506a583840e9af6dc7aad8c65825f9300f50dae4514`.
Evidencia: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-65-high-volume-20261020/`:
fuentes, contexto fresco, rollback, recibos de cola y `applied-verified.json`.
Los recibos del ejecutor permanecen en `collectors/artifacts/local-review-queue/`.

## Inventario completo anterior al lote

El corte completo posterior a revisión 64 terminó el 20-oct a las 13:04:55 UTC:
4,071 pendientes en 755 grupos proveedor+etiqueta, 553 conceptos y 1,329 términos.
Memoria shadow: 60 revisiones aplicadas, 414 aliases, 433 reglas y 2,957 contextos
históricos reutilizables. Los 4,071 pendientes seguían requiriendo evidencia.
54 ledgers/pins verificados; 235 archivos de cortes anteriores preservados,
fuentes, cola, contadores y resolvedor intactos. Es anterior a los ocho cierres
de este lote; no sustituye el recuento productivo de la tabla.

Evidencia: `collectors/artifacts/normalization-memory-after-review-64-20261020-v3/`.

## Proveedores pequeños: resultado separado

Se confirmó sitio propio de [Pasteur Tecamachalco](https://www.laboratorioclinico-pasteur.com/):
[contacto](https://www.laboratorioclinico-pasteur.com/contacto) identifica Matriz,
7 Sur 506, CP 75480, concordante con DENUE 3533309. Cuatro capturas HTTP 200 y
hashes conservados. Se preparó una revisión aislada del website, **sin aplicarla**:
`database/data/provider-website-review-20261020-01.json`.

La web sólo publica seis categorías generales; no justifican estudios concretos,
composición, precios u ofertas. No se abrió el sistema de resultados. La política
de ingesta/licencia sigue sin aprobar y no se activó un collector. La captura
inicial quedó 1.571 s por debajo del crawl-delay 10; no afirmar cumplimiento
perfecto del ritmo, ni repetir capturas sin respetar ese límite.

Bioclínicos Amozoc sigue sin catálogo primario localizado. Los homónimos de
equipos de Tijuana y laboratorio de Colombia se descartaron; no se trasladaron
sus servicios o contactos. Evidencia: `small-provider-evidence-20261020/` y
`website-review-20261020-01/`, bajo el mismo directorio de expansión Puebla.

Prioridad siguiente del usuario: corregir selección de sugerencias y navegación
móvil por proveedor/sucursal. Los cambios de UI/API se preparan y observan por
separado de estos datos; este documento no acredita su publicación.
