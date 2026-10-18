# Revisión 62: FSH y precisión de sugerencias administrativas

Fecha:18-oct-2026 UTC /17-oct local. Entorno: base productiva enlazada para el
lote terminológico; archivos locales para la mejora de triage.

## Equivalencia aplicada sin duplicar el catálogo

Se incorporó un alias exclusivo de SEMIN: «hormona foliculo estimulante» hacia
el concepto existente **Hormona foliculoestimulante (FSH)**. La separación
ortográfica no cambia la hormona. La muestra de suero se conserva como atributo
literal del alias y en RAW; la matriz desconocida del concepto común no cambia.

[MedlinePlus documenta FSH](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-niveles-de-la-hormona-foliculoestimulante-fsh/).
Fuente capturada directamente con HTTP200 yhash. No se importó técnica, unidad,
serie, estímulo, muestra de otra institución o instrucción de día del ciclo.

Aplicación por la cola existente, seguida de lectura independiente05:10:06UTC:

- Un registro resuelto y dos RAW investigados íntegros.
- Concepto, nombres y definición completa de FSH idénticos antes/después.
- Dos consultas públicas HTTP200 y una consulta con proveedor correctas.
- 17 etiquetas/variantes observadas sin selección incompatible del concepto.
- Cero conceptos, ofertas, migraciones o cambios de política nuevos.

El alias es de proveedor: no se promete resolver esa grafía sin contexto de
SEMIN en búsqueda pública. El nombre canónico público sí conserva su resolución.

Fixture aplicada `database/data/reviewed-aliases-20261018-05.json`, SHA256
`b1594da7861d3a50de08d0bdbcdecfaba2e308d06da916941a12357c3f49871d`.
Recibos bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-62-reused-20261018/`.
Cola53 entradas. Recuento confirmado: **551 conceptos,4,073 pendientes,
134 instituciones,218 ubicaciones,234 ofertas y112 migraciones**.

## Discrepancia conservada

Otro RAW SEMIN titulado «transaminasa glutámico oxalacética» declara literalmente
«Orina / Recipiente esteril». La [referencia primaria de AST](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-ast/)
describe la prueba sanguínea; no permite corregir el origen a suero ni ignorar
la muestra. Este registro sigue pendiente y conserva texto y muestra originales.
Siguiente acción: obtener evidencia actual propia del proveedor que aclare el dato.

## Mejora local de triage

Un agente investigó seis sugerencias incompatibles del inventario61:

| Entrada | Sugerencia anterior |
| --- | --- |
| Factores II,VII,XII yXIII | Actividad del factor VIII |
| PM-Scl/PM-1 | Anti-Scl-70 IgG |
| Dermatophagoides pteronyssi | Dermatophagoides farinae |

Son seis grupos de ocho registros, **48RAW**, no48 equivalencias aprobadas.
La cobertura de palabras perdía tokens cortos o aceptaba una cobertura parcial
sin comparar estas dimensiones de identidad.

Se integró un filtro limitado al triage administrativo local. Compara el numeral
romano inmediatamente posterior a `factor`, las secuencias literales de esos
autoantígenos y el epíteto posterior a `Dermatophagoides`. Registra conflictos
o especificidad ausente usando los arrays existentes y retira sugerencias.
No aprueba correspondencias, no cambia políticas ni modifica el motor SQL/API.
Por su alcance de sugerencias administrativas de lectura se trató como arreglo
rutinario compatible, sin activar las propuestas clínicas sujetas aD006.

Los límites siguen explícitos: no convierte números arábigos oFVIII, no parsea
toda una lista «factores II yVII», no expandeD., ni corrige pteronyssi a
pteronyssinus o PM-1 a PM-Scl. Incluso una equivalencia posteriormente demostrada
puede quedar retenida si su nombre canónico está abreviado. La revisión clínica
sigue siendo necesaria. Retirar candidatos también puede cambiar outcomes
derivados; no basta con observar el número de sugerencias.

Compilación sintáctica correcta. Reanálisis completo del inventario congelado61
terminado05:11:16UTC:758 grupos y4,074RAW representados, con archivos originales
intactos porSHA256. Sólo cambiaron esos seis grupos/48RAW: sugerencias de30 a24,
cero candidatos nuevos. La revisión adicional de outcomes y acciones confirmó
que no hubo candidatos exactos únicos nuevos, cambios de acciones ni pérdida de
holds; sólo seis outcomes pasaron a brecha de catálogo sin sugerencias.
Este corte congelado incluye el registroFSH que después se resolvió; no sustituye
el recuento productivo posterior de4,073. No se añadieron ni ejecutaron suites formales.

Artefactos locales: `collectors/artifacts/triage-specificity-20261018/` contiene
investigación original, propuesta aislada, inventario reanalizado y recibos.
Los documentos de propuesta inicial conservan su estado histórico de preparación;
esta sección registra la integración posterior por el agente principal.
