# Puebla: seis identidades privadas incorporadas

**21-oct-2026, 04:54:37 UTC** (20-oct por la noche en Puebla).
Proyecto productivo `ymtcmfgwuzdqtsbuvzqf`, operación local D-021/D-022.
Sin migraciones, despliegues, nuevas fuentes de ingesta o suites formales.

## Resultado aplicado

| Nombre DENUE conservado | Municipio | Domicilio numerado | DENUE / CLUES |
| --- | --- | --- | --- |
| CLINICA URBAJ | Puebla | Privada9B Sur4740, CP72430 | 11462988 / PLSMP001332 |
| INSTITUTO MEXICANO DE ONCOLOGIA | Puebla | Calle3Sur3309, CP72420 | 3410355 / PLSMP002370 |
| CENTRAL GINECO OBSTETRICA | Puebla | Calle13Sur1905, CP72410 | 3407461 / PLSMP002382 |
| HOSPITAL MALDONADO | Puebla | Avenida18Oriente401, CP72000 | 3274215 / PLSMP002761 |
| SANATORIO SAGRADO CORAZON DE TEHUACAN | Tehuacán | Avenida Reforma Sur302, CP75700 | 6378273 / PLSMP002295 |
| POLICLÍNICA ÓPTIMA | Teziutlán | Calle La Mesilla6, CP73885 | 6378802 / PLSMP002662 |

Se incorporaron **seis marcas, seis ubicaciones y seis vínculos DENUE**, cada
uno con auditoría y observación de fuente. Marcas `verification_pending`, sedes
`pending`, websiteNULL. No se aprobaron estudios, horarios, precios, disponibilidad,
propietarios u operadores jurídicos. Cero ofertas nuevas.

La denominación distintiva de cada par coincide; CLUES añade sufijos como
S.C., S.A. o S.A. de C.V. Se revisaron los seis pares individualmente y se
conservaron ambos nombres íntegros en la evidencia. No se afirmó identidad de
persona jurídica ni se activó una regla automática para quitar sufijos o fusionar.

## Procedencia y diferencias conservadas

Se reutilizó DENUE INEGI20-may-2026, capturado9-oct, y el XLSX oficial CLUES
de agosto ya disponible. El extractor existente recorrió64,450 filas nacionales,
3,779 Puebla y devolvió las seis claves exactas, sin faltantes ni duplicados.
SHA256 del XLSX:
`5a1cfbe7062b41d9e51249aa4b5fc8a1e623e935882e97fb5f0aac797165c95b`.

Municipio, localidad, CP, tipo de vía, vía y exterior completos concuerdan;
interiores y letras están vacíos en ambas referencias. Se mantienen diferencias
de asentamiento: CENTRO frente a TEHUACÁN CENTRO; COLONIA BARRIO DE SANTIAGO frente
a BARRIO SANTIAGO; CENTRO frente a SAN FRANCISCO. No se homologan descriptores
ni se reemplaza el domicilio DENUE. La variante9B/9-B se conserva en los originales.

Hospital Maldonado tiene clase DENUE621111 y tipo `office`; no se reclasificó
como hospital por su nombre. Sus cinco compañeros conservan tipo `hospital`
derivado de sus propias clases. El sitio declarado por Maldonado en DENUE,
WWW.HOSPITALMALDONADO.COM, no pudo abrirse mediante webtool; queda en RAW y en
la nota de incertidumbre, sin presentarlo como sitio actual verificado.

Una ubicación existente, ADN EXAMEN, está cerca de Urbaj pero tiene otro nombre
y dirección:49Poniente4901, interior5. No se fusionó. Tampoco se atribuyeron a
los hospitales los consultorios o laboratorios distintos que comparten domicilio.

CLUES es referencia de investigación; sólo se incorporan campos licenciados DENUE.
EN OPERACION es un estado mensual, no prueba de operación actual. Sin política
de fuente, collector recurrente, contacto o costo nuevo.

## Comprobación y límites

Lectura fresca confirmó los seis RAW remotos completos y sus hashes, fuente
government/approved, corrida succeeded y ausencia de bindings o marcas nominales
previas. El renderer versionado existente no cambió. Rollback observado sin
persistencia, **un único envío de commit** y cliente independiente confirmaron:

- Las176 marcas y260 ubicaciones anteriores permanecen íntegramente iguales.
- Nuevos nombres, coordenadas, tipos y líneas de dirección coinciden exactamente
  con los datos DENUE revisados; notas y diferencias de fuente conservadas.
- Seis observaciones y seis auditorías, sin aprobación comercial u ofertas.
- RAW, políticas y contadores clínicos conservados.

Fixture aplicada: `database/data/provider-identity-review-20261021-01.json`.
SHA256:
`cea8ba007d9db305a55dc0557175843e763c6ae78f475e9397ea3476e92be2ab`.
Evidencia ignorada:
`collectors/artifacts/puebla-expansion-20261009/identity-review-36-research-20261021/`:
fuentes, extracción, SQL, snapshots y `applied-verified.json`.

## Estado y siguiente acción

**182 instituciones /266 ubicaciones /556 conceptos /3,327 registros favorables /
4,061 pendientes /946no_match históricos /234ofertas /112migraciones**.
La cola clínica sigue con56 lotes; PID1812 observado vivo. El inventario clínico
completo de las04:48:32UTC permanece como corte previo, no se reconstruyó por
estas seis identidades. Este lote no aumenta cobertura comercial.

Continuar por identidades no incorporadas y evidencia propia de estudios por
sucursal; no convertir los restantes pares de domicilio en coincidencias por
compartir edificio. Los defectos clínicos de calificadores siguen retenidos según
la [revisión68](PUEBLA_REVIEW_68_AND_IDENTITIES_35_20261021.md).
