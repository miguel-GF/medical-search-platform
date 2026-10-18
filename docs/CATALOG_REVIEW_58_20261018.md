# Catálogo y ubicaciones — revisión58 /18-oct-2026 UTC

Entorno: la base Supabase enlazada `ymtcmfgwuzdqtsbuvzqf` es la base pública.
Alcance D021/D022: identidades nominales claras y ubicaciones candidatas, con
evidencia y trazabilidad; sin ofertas nuevas, cambios de política o resolvedor.

## Estudios:24 registros aplicados

Revisión `pruevia:evidence-review:20261018:01`, fixture
`database/data/reviewed-aliases-20261018-01.json`, SHA256
`78a401a7c4b0e6f8c1d211bbf6d3813e3e89bdd31b1c8088015e43b0156a8a43`.

| Identidad de orden | Evidencia y límite |
| --- | --- |
| Cotinina en orina ocasional | SD escribe cotinina en el título y solicita orina al azar. No se convierte en nicotina sérica, panel de metabolitos, cociente con creatinina o colección24h. |
| Anticuerpos anti-Jo-1 | Corrección nominal trazable deJOI aJo-1, limitada al proveedor; matriz e isotipo desconocidos permanecen desconocidos. |
| Índice de tiroxina libre (ITL/FTI) | Índice explícito en el título. No se adopta una fórmula externa ni se convierte en T4 libre directa o un panel. |

Fuentes primarias: [Labcorp737919](https://www.labcorp.com/tests/737919/nicotine-cotinine-screen-and-confirmation-urine),
[MayoJO1](https://www.mayocliniclabs.com/test-catalog/Overview/800219),
[MayoFRTUP](https://www.mayocliniclabs.com/test-catalog/Overview/62583) y
[variantes FTI deLOINC](https://loinc.org/kb/users-guide/loinc-technical-briefs/free-thyroxine-index-variants).
Se preservan los403 del clienteHTTP aMayo/LOINC; sus páginas oficiales legibles
mediante la herramienta web se guardan por separado, sin inventar un200.
No se copian métodos, unidades, isotipos ni códigosLOINC al proveedor.

OchoRAW por concepto, tres aliases limitados aSD. Observación en rollback:
tres nombres canónicos y tres consultas por proveedor correctas;36 vecinos
sin resolución hacia una identidad nueva incompatible. Cola51 con fixture por
hash. Observador independiente04:29:49UTC:24 filas resueltas,80RAW intactos,
56 contextos retenidos intactos, seisHTTP públicos, tres consultas por proveedor
y39 etiquetas/variantes. Guardas, muestra y atributos exactos.

No se cerraron nicotina sérica por analogía, PM-Scl75/100, subunidadesRNP,
AQP4-IgG ni fracciones de globulina sin evidencia de esos atributos.
Frotis y eosinófilos nasales conservan pendientes sus necesidades de modalidad
y muestra. Ayuno no se utiliza para completar la muestra.

## Ubicaciones: siete candidatas incorporadas

Revisión `pruevia:provider-identity-review:20261018:01`, fixture
`database/data/provider-identity-review-20261018-01.json`, SHA256
`a3035f84a2e0c8ecb9d56784664004b5b5c8e7172f486965205cd644fb3ff5ab`.

| DENUE | Unidad | Municipio |
| --- | --- | --- |
|10098862|San Marcos Necoxtla|Tehuacán|
|8464873|Chapulco|Chapulco|
|10530853|Santa Catarina Villanueva|Quecholac|
|3448500|San Marcos Tlacoyalco|Tlacotepec de Benito Juárez|
|11067957|Tlacotepec de José Manzo|San Salvador el Verde|
|3409954|Santa María Malacatepec|Ocoyucan|
|7547222|CESSA La Libertad|Puebla|

DENUE contrastado con el [documento federal histórico](https://sidof.segob.gob.mx/notas/docFuente/5735638)
del convenio15-marzo2024. Nueva captura04:29UTC200; cada CLUES,nombre y dirección
en una misma fila única. Nombre, localidad, municipio,CP y vía concordantes;
sin número explícito en ambas fuentes. No se inventan números ni sitios web.

Tres `office`,tres `clinic` y un `hospital` según el códigoDENUE conservado.
CESSA La Libertad conserva la diferencia entre clasificaciónDENUE622112 y
denominación/nivel federal; no se reclasifica ni atribuye administración actual.
Los35 candidatos restantes de esta búsqueda local mantienen discrepancias
pendientes; no se fuerza concordancia de números o tipos de vía.

Rollback previo observado, commit único y cliente independiente04:31:05UTC:
siete vínculosDENUE, auditorías y observaciones exactos; coordenadas, direcciones,
RAW y políticas intactos. Marcas/instituciones `verification_pending`, sedes
`pending`; identidad histórica no acredita operación actual ni estudios.

## Corte y continuidad

**550 conceptos /4,082 pendientes /133 marcas o instituciones /217 ubicaciones /
234 ofertas /112 migraciones**. Las siete ubicaciones nuevas no añaden cobertura
comercial confirmada. Las capturas sin revisar siguen separadas.
No hubo migración, despliegue, cambio de resolvedor ni suites en este lote.

Corte completo04:34:31 UTC:4,082 filas en759 grupos y1,322 términos. Memoria
shadow57 revisiones,410 aliases,429 reglas y2,946 contextos históricos
reutilizables.51 entradas de cola comprobadas por ledger yhash;196 archivos de
cortes anteriores conservados. Contadores, políticas/fuentes yhash del resolvedor
sin cambios durante el corte. Esta memoria no aprueba órdenes inéditas.

Artefactos: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-58-research-20261018/`,
`identity-review-29/` y
`collectors/artifacts/normalization-memory-after-review-58-20261018-v3/`.
Siguiente acción: continuar grupos de mayor volumen con identidad y atributos
representables; preparar aparte los cambios críticos de composición/método.
