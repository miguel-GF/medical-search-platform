# Puebla: cinco establecimientos candidatos incorporados

Fecha:19-oct-2026. Entorno: herramientas locales contra la base productiva.
Revisiones de identidad31 y32 aplicadas; lectura independiente final12:40:31UTC.

## Establecimientos añadidos

| Unidad | Municipio | Domicilio concordante | DENUE |
| --- | --- | --- | --- |
| San Sebastián | Teziutlán | Calle Vicente Lombardo Toledano, sin número |3481964|
| Nicolás Bravo | Nicolás Bravo | Calle Nacional44 |3537158|
| San Andrés Cholula | San Andrés Cholula | Avenida Maximino Ávila Camacho604 |3434721|
| Alpanocan | Tochimilco | Calle Aldama7, San Antonio Alpanocan |3278688|
| Zaragoza | Zaragoza | Avenida Morelos103 |3477224|

Son unidades públicas candidatas independientes. Los nombres específicos,
municipio, localidad, CP y domicilio concuerdan entre DENUE y el
[directorio federal histórico](https://sidof.segob.gob.mx/notas/docFuente/5735638).
DENUE añade descriptores rural/disperso/concentrado/urbano que no aparecen en los
rótulos federales; ambos nombres quedaron documentados y la sede conserva el original.

El documento federal se volvió a recuperar conHTTP200 el19-oct. En cada caso
CLUES, nombre y domicilio aparecen en una única filaHTML. Las fuentes conservan
su antigüedad: DENUE publicado20-may-2026/capturado9-oct y convenio federal2024.
La lectura nueva no convierte esa evidencia histórica en prueba de operación actual.

No se asignó una red administrativa actual ni sitio web propio: cinco websites
NULL, marcas con verificación pendiente y ubicaciones pendientes. No se añadieron
estudios, horarios, precios o disponibilidad. Una dirección no acredita un estudio.

## Diferencias conservadas

- En los cuatro domicilios numerados se exigió igualdad del componente completo
  anterior a la primera coma: tipo de vía, calle y exterior. No se aceptó una cifra
  encontrada en CP, colonia, referencia o kilómetro.
- Alpanocan conserva `numero_int` vacío y `letra_int=SN` de DENUE. El exterior
  sigue siendo7; no se trasladóSN ni se inventó un interior.
- Zaragoza conserva la clase DENUE622112 y tipo hospital, aunque la fila federal
  diceCS/primer nivel. La diferencia queda abierta; no se reclasificó la unidad.
- En Cholula apareció un laboratorio cercano, IB Laboratorios Médicos e Imagen,
  con domicilio DENUE Avenida Manuel Ávila Camacho602. El centro público nuevo
  corresponde a Maximino Ávila Camacho604. Se conservaron separados; cercanía de
  coordenadas no prueba identidad. La lectura posterior confirmó el laboratorio
  anterior íntegro, incluidos nombre, domicilio, estado y coordenadas.

## Qué permitió avanzar

La revisión31 usó domicilios explícitamente sin número y nombres específicos
con descriptores conservados. La revisión32 investigó una hipótesis adicional:
exteriores numerados, omitidos por el filtro anterior.

El agente encontró23 pares de esa hipótesis: cuatro concordantes y19 retenidos.
Los retenidos mantienen diferencias reales de calle, tipo o número; no se usó
la similitud para cerrar esos casos. Ejemplos: Atempan14 frente a12, Coatepec6
frente a17 y San Gabriel Tetzoyocan801 frente a808.

## Aplicación y comprobación

Cada lote tuvo lectura fresca de colisiones, bindings y procedencia; rollback
observado; un único intento de commit y cliente independiente posterior.
No hubo colisiones de identidad; el vecino de Cholula se revisó expresamente.
Los cinco RAW originales, direcciones y coordenadas quedaron íntegros. No
cambiaron políticas de fuente ni se ejecutaron suites formales.

| Recuento productivo confirmado12:40:31UTC | Total |
| --- | ---: |
| Instituciones o marcas registradas |139|
| Ubicaciones registradas |223|
| Conceptos activos |551|
| Registros de crawler pendientes |4,073|
| Ofertas activas |234|
| Migraciones |112|

Las223 ubicaciones incluyen candidatas pendientes; no significan223 sedes con
estudios comprobados. Esta tarea aumentó identidades, no cobertura comercial.

## Evidencia y continuidad

Fixtures aplicadas:

- `database/data/provider-identity-review-20261019-01.json`, SHA256
  `f28710ad3b2ff705a274f576c647d8b6142fbbdc7a7b351de8c03c74b7a12c48`.
- `database/data/provider-identity-review-20261019-02.json`, SHA256
  `8e8fb2f783ec47e48f3cb08574e187468b88e0d958dd18b2ba554e22a45f070a`.

Artefactos bajo `collectors/artifacts/puebla-expansion-20261009/identity-review-31/`
y `identity-review-32/`; cierre en `identity-review-32/independent-final-cut.json`.
Discovery y19 retenidos: `collectors/artifacts/identity-discovery-20261019/`.

Se localizó el [histórico oficialCLUES](https://gobi.salud.gob.mx/Bases_Clues.html),
capturadoHTTP200 el19-oct12:40:57UTC. Enlaza un
[archivo de agosto2026](https://gobi.salud.gob.mx/historico_clues/ESTABLECIMIENTO_SALUD_202608.xlsx?v=1.1),
HEAD200 de26,524,116bytes,Last-Modified23-sep2026. Se inició una observación
acotada de ese archivo para revisar encabezados y19CLUES; no se usó para aprobar
estos cinco registros ni se declaró operación actual desde su nombre de archivo.
Recibos en `collectors/artifacts/clues-source-discovery-20261019/`.

**Continuación posterior completada:** la descarga final y los campos útiles
quedaron acreditados con su hash y extractor local. Las cinco claves históricas
figuran fuera de operación por cambio de institución; no se infirió cierre
físico o sucesión ni se modificaron estas identidades. Se investigaron nuevos
pares independientes y se incorporaron 35 candidatos en el lote 33. No hubo
nueva fuente de ingesta ni cambio de políticas.
[Resultado, evidencia y límites](PUEBLA_CLUES_IDENTITIES_33_20261019.md).
