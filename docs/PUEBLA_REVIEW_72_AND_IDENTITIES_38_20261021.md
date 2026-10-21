# Puebla: dos órdenes y cinco establecimientos incorporados

21-oct-2026 UTC (20-oct por la noche en Puebla). Operación local autorizada
D-021/D-022 sobre el proyecto productivo `ymtcmfgwuzdqtsbuvzqf`.
Sin migraciones, cambios del resolvedor, despliegues o suites formales.

## Dos órdenes incorporadas

| Orden canónica | Evidencia propia | Límite conservado |
| --- | --- | --- |
| Anticuerpos contra MuSK | Chopo19577, ANTICUERPOS MUSK | Isotipo, muestra, técnica y duración desconocidos; no AChR ni gen MUSK |
| Captación de T3 en suero | SEMIN5647, T3 CAPTACION; sample_type declara Suero | Distinta de concentración T3, captación de yodo, TBG o índice de T4; técnica/escala/propiedad desconocidas |

Referencias primarias leídas y capturadas con HTTP200 y hashes:
[Chopo MuSK](https://www.chopo.com.mx/puebla/anticuerpos-musk),
[Labcorp MuSK504600](https://www.labcorp.com/tests/504600/muscle-specific-kinase-musk-antibodies),
[Labcorp T3uptake001156](https://www.labcorp.com/tests/001156/t3-uptake).
Los atributos de Labcorp no se transfieren a Chopo/SEMIN. No se aprueba RIPA,
resina, radioisótopos, ECLIA, resultado diagnóstico o mappingLOINC. El dato operativo
SEMIN duration_minutes8 no se convierte en tiempo de colección.

Preparador existente comprobó dos RAW completos actuales, colisiones, destinos
y guards. Observación real en rollback: **37 consultas públicas y37 de proveedor**.
Canónicos resueltos en ambas rutas; títulos originales sólo en su proveedor.
Los vecinos examinados de isotipo, diana, muestra, método, serie, negación, T2/T4
y concentraciones tiroideas no seleccionaron los nuevos conceptos como resolved.
Algunas variantes quedan ambiguous: no se presenta eso como equivalencia aprobada
ni como protección universal. Las definiciones vecinas anteriores quedan íntegras.

Guard Chopo de título completo provider_display_name; guard SEMIN de sample_type
completo y atributo serum explícito. Fixture incorporada:
`database/data/reviewed-aliases-20261021-04.json`, revisión `pruevia:evidence-review:20261021:04`,
SHA256 `41f3ee4a97aa6b4c46cb51f718e7c8b0f79dcb2a8d2fa2966be6e91b51824506`.
La fixture71 permanece aislada y no se ocupa su revisión03 con otro contenido.

Cola58→59 conservó todos los pins anteriores. PID17024 existente aplicó el lote,
sin restaurar/reiniciar procesos ni reenviar escrituras desde el coordinador.
**Observador independiente05:32:19UTC:** ledger already_applied, dos decisiones,
dos conceptos, RAW/precios/labels íntegros en diez entradas examinadas, incluyendo
ocho eosinófilos nasales retenidos. Métodos/propiedades/escalas/tiempos/LOINC
desconocidos siguen NULL; fuentes y definiciones previas conservadas. Cero ofertas nuevas.
API local: ambos canónicos devuelven HTTP200, resolved y cero ofertas. Captura
`local-applied-observed-v2.json` lee nombres desde la fixture UTF-8; el intento
inline previo corrompió una vocal acentuada y se conserva separado, sin usarlo
como comprobación del canónico. Worker vivo,59entradas applied_verified/already_applied,
estado watching; no se reinició para adelantar el siguiente scan.

## Cinco identidades incorporadas

| Nombre DENUE íntegro | Municipio / domicilio | DENUE / CLUES | Tipo SCIAN conservado |
| --- | --- | --- | --- |
| HOSPITAL LA SOLEDAD | Atlixco, Calle13Norte6,74250 |3411895 / PLSMP001793|hospital|
| HOSPITAL SANATORIO ANGELES DE TEHUACAN | Tehuacán, Calle2Sur721,75770 |3422643 / PLSMP002312|hospital|
| CLINICA DE ESPECIALIDADES MEDICO QUIRURGICAS SAN PEDRO | Atlixco, Calle3Sur1706,74260 |3424223 / PLSMP002353|office|
| MEDICA VENECIA | Puebla, Calle5Norte4613,72080 |3257099 / PLSMP002913|office|
| LABORATORIOS DE ANALISIS CLINICOS DIAGNOSTICA | Tehuacán, Calle3Oriente518,75700 |3415186 / PLSMP008986|branch|

Revisión individual de denominación distintiva y domicilio numerado completo:
municipio/localidad/CP/tipo de vía/vialidad/exterior concuerdan, letras e interiores
vacíos. GENERAL/HOSPITAL/CLÍNICA, QUIRURGICAS/QUIRURGICA y orden de descriptores se
conservan en ambos originales; no se activa una regla de eliminación de palabras.
Asentamientos RICARDO TREVIÑO/LA SOLEDAD y CENTRO/TEHUACÁN CENTRO no se homologan.
No se infiere relación con Hospitales Ángeles, persona jurídica o propietario.
San Pedro Atlixco no se fusiona con marcas de San Pedro Cholula.

DENUE INEGI20-may/captura9-oct aporta los campos licenciados; CLUES agosto se usa
como referencia de investigación, sin nueva política de ingesta. Extractor existente:
64,450 filas nacionales,3,779 Puebla,seis claves exactas incluidas la retenida.
EN OPERACION es mensual, no estado actual comprobado.

Renderer existente sin cambios. Rollback y único commit, seguidos por observador
independiente a**05:31:03UTC**: cinco marcas/sedes/bindings/auditorías/observaciones,
**186 marcas y270sedes previas íntegras**, RAW/políticas/contadores clínicos intactos.
Coordenadas, nombres, clases y direcciones exactos. Marcas verification_pending,
sedes pending, websiteNULL; sin precios, horarios, estudios o disponibilidad aprobados.

Fixture aplicada: `database/data/provider-identity-review-20261021-03.json`.
SHA256 `aee89e9191fc71a5a2ddd4d96eceb4196953062f81d58287c6b6514b1bfbfefc`.

## Retenciones concretas y problema del motor

- **Beneficencia Española DENUE6271529:** dirección1001 frente a identidad previa
  DENUE10470110 con exterior1012. No se duplica marca/sede ni se añade binding;
  falta aclarar si son accesos o establecimientos distintos. Identidad previa íntegra.
- **Ocho eosinófilos en moco nasal:** RAW fresco declara matriz específica; no hay
  código en registro/importador. No degradar a muestraNULL, sangre o swab. Preparar
  representación explícita y conservación de requisitos antes de incorporar.
- **SD MUSK/TUPTAKE:** fuera del alcance; sus títulos no se completan desde las
  fichas Chopo/SEMIN. Trigo71 y CélulasLE67 continúan retenidos por calificadores.

Diagnóstico adicional de sólo lectura del catálogo actual: las RPC públicas
resuelven `Biometría hemática INR` y `Biometría hemática x2` como biometría simple,
con34ofertas, aunque el segmentador no las particiona. La API local real8787 devuelve
ready/complete y10soluciones para ambas: problema observado de punta a punta local,
no sólo predicción sobre un candidato nuevo. No se comprobó aquí el Worker público.

Control positivo `Biometría hemática glucosa` sí conserva ambos fragmentos y resuelve
dos estudios; con INR adicional no_match/none. IgEgluten con negación queda ambiguous
y needs_clarification/none. Esto delimita los fallos; no todas las consultas pierden
condiciones ni toda ambigüedad representa aceptación. Detalle en la
[revisión de consumidores](proposals/20261021-requirements-consumer-review.md).

## Estado y continuidad

**562 conceptos /3,333 registros favorables /4,055 pendientes /946 históricos /
191 marcas /275 sedes /234 ofertas /112 migraciones**. La cobertura comercial
no aumenta por estas identificaciones. Cola59, mismo worker observado en ejecución.
El inventario completo04:48UTC sigue siendo un corte anterior; no se reconstruyó
por cada singleton. Continuar evidencia propia por sede y candidatos no investigados;
preparar corrección compartida y recuperación sin activar cambios críticos D-006.

Artefactos ignorados bajo `collectors/artifacts/puebla-expansion-20261009/`:
`clinical-research/review-72-candidates-20261021/`,
`identity-review-38-research-20261021/` y
`clinical-research/requirements-consumers-20261021/`. Incluyen scripts, RAW,
snapshots, SQL, recibos HTTP, rollback/commit y comprobaciones independientes.
