# Tres órdenes de anticuerpos con suero e isotipo explícitos

**21-oct-2026, 05:11:58 UTC** (20-oct por la noche en Puebla).
Proyecto productivo `ymtcmfgwuzdqtsbuvzqf`, operación local D-021/D-022.
Sin cambios de código, migraciones, despliegues, nuevas fuentes o suites formales.

## Aplicado y observado independientemente

| Orden | Fuente literal propia | Alcance conservado |
| --- | --- | --- |
| Anticuerpos IgG contra Schistosoma en suero | Chopo19467, AC IgG SCHISTOSOMA EN SUERO | Género sin especie asignada; no afirma detección de todas las especies. |
| Anticuerpos IgM contra Trypanosoma cruzi en suero | Chopo19695, AC IgM TRYPANOSOMA CRUZI EN SUERO | IgM individual, separado del concepto previo de anticuerpos totales. |
| Anticuerpos IgG contra Plasmodium falciparum en suero | Chopo19923, ANTICUERPOS IgG PLASMODIUM FALCIPARUM (MALARIA) EN SUERO | Especie falciparum e IgG, sin sustituir por diagnóstico o panel malaria. |

Tres conceptos y tres decisiones favorables nuevas. Cada alias es exclusivo de
Chopo y conserva el valor íntegro de `provider_display_name` como guard, además
de `specimen_code=serum` en su decisión. Definiciones con sistema Serum y componentes
nominales específicos; método, propiedad, escala, duración y LOINC desconocidos.
No se transfieren interpretación, sensibilidad, reactividad o preparación externa.

El soporte de títulos revisados de la [revisión69](CATALOG_REVIEW_69_20261021.md)
permitió conservar la muestra sin cambiar helpers o resolvedores en este lote.

## Fuentes y límites de recuperación

El RAW Chopo completo reconsultado identifica diana, isotipo y suero. Las páginas
propias no pudieron abrirse en webtool; no se presentaron como capturas nuevas200.
Se consultaron referencias primarias para contrastar la denominación:

- [Mayo65019](https://www.mayocliniclabs.com/test-catalog/Overview/65019): contenido
  primario leído por webtool sobre SchistosomaIgG; no se copian antígeno de
  S.mansoni, cobertura de especies o técnica del ensayo.
- [KUCRUZM](https://kuhlab.testcatalog.org/show/CRUZM): contenido primario leído
  por webtool; el directorio está desactivado y se usa sólo como referencia de
  identidad IgM, sin afirmar oferta actual o utilidad clínica.
- [LOINC108932-5](https://loinc.org/108932-5): resultado primario de búsqueda
  leído por webtool para la denominación falciparumIgG. No se aprobó mapping,
  propiedad, presencia/título, escala o método del producto Chopo.

Las tres solicitudes HTTP directas a esas referencias devolvieron **403**, con
cuerpos y hashes conservados. Se distinguen de las lecturas webtool: **cero
capturas HTTP200 primarias directas** en este lote. Sin bypass, contactos o
reintentos idénticos. El informe y recibo detallan exactamente el origen de cada
afirmación; una fuente que dice IgG no se usó para aprobar IgM.

## Observación antes de incorporar

Un rollback observó **48 consultas públicas y las mismas48 con alcance de
Chopo**. Los tres nombres canónicos se resolvieron en ambas rutas. Los títulos
de origen se resolvieron en su proveedor y pueden seguir sin coincidencia pública.

Isotipo opuesto/combinado, IgE, especie distinta o especie añadida, orina/plasma,
mezcla de muestras, método explícito, PCR, antígeno, perfil con otra prueba,
negación y seriex2 no seleccionaron automáticamente los nuevos conceptos en
los casos examinados. Algunas variantes quedaron ambiguas; no se contaron como
resueltas ni se afirma filtrado universal de todos los requisitos.

El rollback quedó sin persistencia, ledger `not_applied` y contadores/políticas
intactos. La versión revisada sólo añadió alcance y metadata de evidencia;
conceptos y aliases permanecieron iguales al borrador observado. Cola57→58
con pins anteriores íntegros. El ejecutor completó preview/commit/ledger y un
cliente independiente verificó:

- Tres decisiones, IDs, isotipos, suero y guard completo correctos.
- Tres RAW completos y precios originales intactos.
- Definición previa de anticuerpos totales contra T.cruzi íntegra.
- Atributos desconocidos conservados, fuentes/políticas sin cambios.
- Cero ofertas nuevas; identificar una orden no demuestra disponibilidad comercial.

## Estado y continuidad

**560 conceptos /3,331 registros favorables /4,057 pendientes /946no_match
históricos /182 marcas /266 ubicaciones /234ofertas /112migraciones**.
Cola58, PID17024 observado vivo y después vigilando. El inventario completo de
las04:48:32UTC es anterior a estos lotes; no se reconstruyó la memoria por cada
fila. Sin publicación nueva de UI/API.

Fixture aplicada: `database/data/reviewed-aliases-20261021-02.json`.
SHA256: `03ae2725c39440cfb7d2bcba622c2fc8912b8d0eff3ad2c57444279f52f8c35f`.
Evidencia ignorada:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-70-serum-antibodies-20261021/`:
RAW, referencias y fallos HTTP separados, SQL, observaciones, recibos y
`applied-verified.json`.

Siguiente acción: continuar por títulos con atributos inequívocos y conservar
las retenciones por composición, contradicción de fuente o requisitos perdidos.
No reabrir catecolaminas totales/metanefrinas sin el dato concreto que falta.
