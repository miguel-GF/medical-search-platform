# Moco nasal: soporte local compatible y estudio retenido

21-oct-2026,12:33–12:46UTC. Operación local contra el proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`, dentro de investigación/representación D-021/D-022.
Sin cambios persistentes de muestras, conceptos, aliases, funciones, lexicon,
esquema, permisos, migraciones o ofertas. Sin despliegue ni suites formales.

## Qué se implementó localmente

El importador y lector de ledger entienden `nasal_mucus`/sistema `Nasal mucus`.
Es un código local propuesto, no mapping LOINC/SNOMED. Para usarlo se exige:

- Alias exclusivo de proveedor, tipo lab_test y guarda de título completo
  provider_display_name, igual al alias tras normalizar.
- Construcción literal `en moco nasal`, sin negación, conjunciones o materiales/
  dispositivos distintos. Se rechazan hisopo/swab y sus plurales, secreción,
  exudados, material nasofaríngeo, lavados, aspirados, esputo y otras matrices
  enumeradas. Es una guarda acotada, no un analizador universal de lenguaje clínico.
- Source_attributes nasal_mucus obligatorio en todos los objetivos del concepto.
  La preparación `SIN ASEO NASAL` no prueba por sí sola esa muestra.
- Registro activo de esa muestra antes de aplicar; falta en la base actual,
  por lo que el soporte local no habilita automáticamente ningún lote.

La exclusión de hisopo no niega que pueda usarse como dispositivo de toma:
impide ampliar un título simple a una combinación más amplia sin revisión.
Fuentes primarias del trabajo: [CDC PPMP](https://www.cdc.gov/lab-quality/media/pdfs/2025/07/PPMP_2025_Final-508c.pdf),
[DLS eosinófilos](https://til.dlslab.com/physicians/test-directory-view-test/?test=5323)
y [Labcorp eosinófilos sanguíneos](https://www.labcorp.com/tests/005298/eosinophil-count).
Capturas HTTP200 y hashes conservados; no se trasladan tinción, microscopía,
escala, colección, finalidad diagnóstica o transporte de otro laboratorio.

**Compatibilidad observada12:39:52UTC:**76fixtures existentes/152salidas SQL
(preview y apply) byte por byte iguales antes/después. Ambos helpers se analizaron
sintácticamente. Comparación de generación, sin enviar esos SQL a la base; no
prueba de nuevas equivalencias o del Worker desplegado. El código raíz añade
rechazos más estrictos que el diff inicial del agente, conservado como antecedente.

PID17024 sigue con módulos anteriores; no se reinició ni recibió una fixture
nasal nueva. La cola continúa60lotes aplicados. Antes de un futuro lote que use
este soporte haría falta una recarga controlada, cuando su aplicación esté lista.
No basta versionar el archivo para acreditar código cargado o desplegado.

## Lectura real de dependencias

SELECT remoto12:33UTC: nueve filas en specimen_types, ninguna moco nasal;
query_lexicon es tabla, no existe v_query_lexicon. No hay triggers no internos
ni vistas dependientes observadas que propaguen una fila nueva a frases clínicas.
La consulta de frases specimen/nasales fue vacía. El resolvedor base lee
query_lexicon directamente; source_attributes de una revisión se registra como
evidencia/auditoría, no como extracción de la consulta pública.

Por ello representar una muestra y conservar sus atributos es distinto de
validar que el buscador respeta los requisitos. No se añadió frase ni se cambió
la lógica de qattrs/score. Cualquier cambio de aceptación compartida continúa
bajo D-006; el ensayo preparado de tres funciones sigue sin aprobación explícita.

## Candidato observado, no incorporado

Ocho títulos SD `EOSINOFILOS EN MOCO NASAL`, reconsultados íntegros12:43UTC e
idénticos a los investigados72. Canónico propuesto **Eosinófilos en moco nasal**,
componente Eosinophils, matriz explícita nasal_mucus; técnica, tinción,
propiedad, escala, unidades, tiempo, lateralidad y cantidad desconocidos.
No degradar a muestraNULL, sangre, hisopo u other ni inferir Hansel/Wright.

Para observarlo se insertó una fila de tipo de muestra **dentro de la misma
transacción que terminó en rollback**, antes del concepto y su guarda de datos.
No se ejecutó el SQL propuesto de alta permanente ni una migración. Ningún
cliente recibió una activación persistente de ese nuevo tipo/concepto.

**25consultas públicas y25deproveedor:** canónico/título resuelven, pero ocho
consultas distintas seleccionan indebidamente el candidato en al menos una ruta:
x2/x3/IgG, negación del analito/matriz, título original+x2, y genéricos Eosinófilos/
Eosinófilos nasales. Las dos genéricas fallan sólo dentro del proveedor; las otras
seis también públicamente. Algunas variantes de otras muestras/técnicas se
abstienen; esto no repara las pérdidas observadas.

**Decisión: retener los ocho registros.** Fixture exclusivamente en artefactos,
revisión `pruevia:evidence-review:20261021:06`, SHA256
`c38208218a6c590abd1ad3de415afe3c433bf3395164fb2dd0d7b4a8020af641`.
No se versionó en database/data ni se encoló. No se renombra para ocultar el fallo.

Cliente independiente: ledger not_applied, nueve muestras exactamente iguales,
contadores/fuentes intactos. Relectura12:46:42UTC: los ocho RAW completos,
precios y estados idénticos. Registro nasal/concepto/aliases no persistieron.
Revertir el helper local no requiere deshacer datos clínicos nuevos porque no
se aplicaron; conservar su comprensión antes de futuros lotes y revalidar pins
de propuestas antiguas que dependan de estas versiones de código.

## Evidencia y siguiente acción

Artefactos bajo `collectors/artifacts/puebla-expansion-20261009/clinical-research/`:
`nasal-mucus-support-20261021/` y `review-74-nasal-eosinophils-20261021/`.
Incluyen fuentes, datos previos, copias de helpers, comparaciónSQL, propuesta,
observación real y recibos independientes. El manifiesto inicial del agente
no se presenta como inventario de archivos posteriores del coordinador.

**563conceptos/3,341favorables/4,047pendientes/204marcas/288sedes/234ofertas/112migraciones**.
El soporte de representación queda preparado localmente. No activar el estudio
o el registro sólo para cerrar ocho filas; continuar datos claros y completar
la evaluación compartida cuando exista aprobación específica. No marcar la meta completa.
