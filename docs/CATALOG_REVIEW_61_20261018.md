# Revisión 61 e identidad 30 — Puebla

Fecha: 18-oct-2026 UTC /17-oct local. Entorno: herramientas locales contra la
base productiva enlazada. Ambos lotes aplicados y observados independientemente.

## Ocho registros incorporados

Se incorporó **glutatión peroxidasa** como identidad nominal de estudio, con un
concepto y un alias limitado a Salud Digna. Los ocho registros originales sólo
declaran el nombre; la preparación está vacía. Muestra, técnica, escala y unidad
permanecen desconocidas.

La [ficha del Hospital Clínic](https://cdb.clinicbarcelona.org/es/node/22647)
documenta esa identidad de orden. Se capturó directamente con HTTP 200 y hash;
el lector web no pudo abrirla, circunstancia distinta de la captura directa.
No se importaron sangre total, tubos, técnica, unidad por hemoglobina ni LOINC
desde esa institución. No se eligió GPX1, GPX3, GPX4, genotipo o expresión.

La observación con rollback conservó los contrastes frente a glutatión total,
reducido, oxidado, reductasa, sintetasa, isoenzimas, genética y muestras explícitas.
Tras aplicar por la cola existente se observaron:

- Ocho registros resueltos; los 64 RAW investigados permanecen idénticos.
- Los otros 56 contextos mantienen su estado previo.
- Dos consultas públicas HTTP 200 y una consulta específica de proveedor correctas.
- 25 etiquetas/variantes observadas, sin selección incompatible del nuevo concepto.

Esto acredita identidad de orden, sin establecer equivalencia analítica ni una
oferta comercial nueva. No se ejecutaron suites formales.

Los otros siete grupos siguen retenidos por motivos concretos: cortisol salival
y glutatión total en sangre completa necesitan conservar muestras que el
importador actual no representa; renina requiere distinguir concentración de
actividad; biotinidasa, aclarar tipo de estudio; antiestreptolisinas, conservar
escala/método; cofactor de ristocetina, representar su ensayo funcional; TGF beta1
MBL, aclarar el calificador MBL. No se eliminaron atributos para cerrar esos RAW.

## Un establecimiento candidato incorporado

**Centro de Salud Atenayuca, Juan N. Méndez**, DENUE 3385384, CLUES PLSSA015616.
Nombre, municipio, localidad, CP, avenida Ixcaquixtla y ausencia explícita de
número concuerdan entre DENUE y el anexo federal histórico de 2024.

La [fuente federal SIDOF](https://sidof.segob.gob.mx/notas/docFuente/5735638)
se volvió a capturar con HTTP 200. Nombre, CLUES y domicilio figuran juntos en
una única fila HTML. DENUE conserva el asentamiento Tercera, que no aparece
literalmente en la fila federal; esa diferencia se documentó sin corregir datos.

Se registró una institución candidata independiente y una ubicación de tipo
consultorio, con verificación pendiente y sitio web desconocido. La evidencia
histórica no confirma operación actual, estudios, precios, horarios ni pertenencia
administrativa actual. Dirección y coordenadas originales quedaron intactas.

Hubo rollback observado, un único intento de commit y lectura independiente de
la identidad, vínculo DENUE, observación y auditoría. Las políticas no cambiaron.

## Recuento confirmado

Al cierre de identidad, 05:02:35 UTC:

| Dato | Total |
| --- | ---: |
| Conceptos activos |551|
| Registros de crawler pendientes |4,074|
| Instituciones o marcas |134|
| Ubicaciones registradas |218|
| Ofertas activas |234|
| Migraciones |112|

Las 218 ubicaciones incluyen candidatos pendientes; no son 218 sedes con estudios
comprobados. La cola tiene 52 revisiones fijadas por hash. Los borradores 02 y03
de TP/TPT siguen sin aplicar y fuera de cola; la propuesta INR no se ejecutó.

## Evidencia y continuidad

Fixtures aplicadas:

- `database/data/reviewed-aliases-20261018-04.json`, SHA256
  `9cc5037af9d4a9a7dd37536e5c6b13b300cda263186d5dbc773fa60e23cceaa3`.
- `database/data/provider-identity-review-20261018-02.json`, SHA256
  `0de0aa7e1647762240787cd3b75cfa665e36ba780c76da139c3bc57bbf5d3820`.

Artefactos bajo `collectors/artifacts/puebla-expansion-20261009/`:
`clinical-research/review-61-individuals-20261018/` e `identity-review-30/`.
Se conserva el primer intento del observador clínico que encontró el ledger aún
sin aplicar mientras el proceso existente seguía escaneando; se esperó al mismo
proceso y después se obtuvo la verificación final. No se duplicó el ejecutor.

Inventario completo y memoria shadow finalizados **05:05:55 UTC**, bajo
`collectors/artifacts/normalization-memory-after-review-61-20261018-v3/`.
`observation.json` acredita paginación completa: **758 grupos,4,074 pendientes,
551 conceptos y1,324 términos**. Las52 entradas de cola se comprobaron contra
ledger/hash. Memoria:58 revisiones aplicadas,411 aliases,430 reglas y2,954
contextos históricos reutilizables; los nueve borradores sin aplicar se excluyen.
Los4,074 pendientes siguen requiriendo evidencia; no se aprobaron por memoria.

Se compararon217 archivos de cortes anteriores sin cambios. Fuentes, contadores,
cola y resolvedor permanecieron iguales durante la lectura. El resolvedor general
conservaMD5`067b7a2fe0826ccaa48ece0a5dfd8d1d`; esto no equivale al hash de
`resolve_items_v6`, que es otra función. No hubo suites formales.
Siguiente trabajo: investigar grupos con atributos representables y mejorar
cobertura comercial con evidencia de sede y política de fuente revisada.
