# Puebla: cuatro UMF incorporadas y trigo retenido

21-oct-2026 UTC (20-oct por la noche en Puebla). Operación local contra el
proyecto productivo `ymtcmfgwuzdqtsbuvzqf`, autorizada por D-021/D-022.
Sin migraciones, despliegues, nuevas políticas de fuente ni suites formales.

## Identidades incorporadas

| Nombre DENUE conservado | DENUE / CLUES | Domicilio conservado |
| --- | --- | --- |
| IMSS UNIDAD MEDICINA FAMILIAR 34 | 3417474 / PLIMS000031 | Avenida Manuel Ávila Camacho 1102, Atlixco, 74200 |
| UNIDAD DE MEDICINA FAMILIAR NUMERO 3 IMSS | 3254599 / PLIMS000335 | Calle 5 de Febrero Oriente 206, Puebla, 72030 |
| CLINICA IMSS UMF4 | 3471377 / PLIMS000340 | Boulevard Esteban de Antuñano 6, Puebla, 72110 |
| UNIDAD MEDICA FAMILIAR N 30 | 3510464 / PLIMS000410 | Avenida Independencia Poniente 200, Tehuacán, 75700 |

Nombres, números y municipios corroborados con el
[catálogo institucional UMF](https://www.imss.gob.mx/sites/all/statics/pdf/informes/catalogo_UMF.pdf).
Los domicilios numerados completos concuerdan entre DENUE y CLUES. El directorio
IMSS aporta además domicilio de 3/30 y, en captura directa, 34; no se atribuye una
tercera captura de domicilio a 4. La discrepancia entre captura directa y webtool
de la página177 queda registrada. CLUES agosto sigue siendo referencia de
investigación, no fuente nueva de ingesta ni prueba de operación vigente.

Se conservan diferencias de asentamiento, MEDICA/MEDICINA y nombres abreviados.
SCIAN621116 conserva tipo `clinic`. Cuatro identidades individuales: no se reutiliza
IMSS-Bienestar ni se afirma persona jurídica, propiedad o red comercial. WebsiteNULL;
los dominios declarados en RAW no se presentan como URL vigente de sucursal.
Marcas `verification_pending`, sedes `pending`; sin acceso sin derechohabiencia,
horarios, estudios, precios o disponibilidad acreditados.

### Comprobación independiente

Rollback sin persistencia, único envío de commit y nuevo cliente confirmaron a
**05:21:23 UTC** cuatro marcas/sedes/bindings/auditorías/observaciones nuevos.
Las **182 marcas y 266 sedes anteriores permanecen íntegramente iguales**;
cuatro RAW completos, políticas y contadores clínicos intactos. Nombres,
coordenadas, tipos y líneas de dirección coinciden con DENUE. Cero ofertas nuevas.

Fixture aplicada: `database/data/provider-identity-review-20261021-02.json`.
SHA256: `65f9a505d41d48c4e03cd3f697761ba697f657d1a2295fd7072ba16d95b009de`.
Renderer existente sin cambios, SHA256:
`25dcc0657eae7797b5a62e97e1fed05d64764f011951335b7e0e20993e8e2fa2`.
Artefactos ignorados: `collectors/artifacts/puebla-expansion-20261009/identity-review-37-research-20261021/`:
fuentes, extracción, snapshots íntegros, SQL, recibos y `applied-verified.json`.

## IgE contra trigo: evidencia clara, incorporación retenida

Chopo SKU19820, título propio `AC IGE A TRIGO`, una fila. Capturas primarias
directas HTTP200 de [Chopo](https://www.chopo.com.mx/puebla/ac-ige-a-trigo) y
[Labcorp602459](https://www.labcorp.com/tests/602459/wheat), con recibos y hashes.
El título sustenta IgE contra trigo; no muestra, método, escala, unidades,
LOINC ni composición de otro proveedor. No se confunde con IgE contra gluten.

El preparador existente verificó RAW actual, aliases y colisiones. Se observó
el borrador en una transacción con rollback mediante la RPC pública y el core
con scope Chopo: **30 consultas por cada ruta**. Nombre canónico resuelto en ambas;
alias original sólo dentro del proveedor. Siete variantes seleccionaron indebidamente
el nuevo concepto en ambas rutas: sustituciones IgG/IgA, x2, añadidos IgG/IgM/IgA,
y negación `sin IgE`. Por ello **no se incorporó, no se versionó la fixture ni
se encoló**. No se cambia el nombre para ocultar el problema.

Un cliente independiente confirmó ledger `not_applied`, contadores y fuentes
intactos después del rollback. La observación demuestra un defecto de aceptación
de requisitos, no ambigüedad del título original. Otros seis grupos/48 contextos
del corte68 investigados siguen retenidos por composición o población no definida;
no representan una revisión fresca de toda la cola.

Artefactos ignorados: `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-71-candidates-20261021/`:
RAW, referencias, propuesta aislada, `observations.json` y `observation-receipt.json`.

## Estado y siguiente acción

**186 marcas /270 sedes /560 conceptos /3,331 registros favorables /
4,057 pendientes /946 no_match históricos /234 ofertas /112 migraciones**.
Identidades registradas no equivalen a cobertura comercial comprobada.

Continuar identidades y evidencia comercial por sede. Para desbloquear trigo,
Células LE, INR y horarios/series de cortisol, preparar la corrección compartida
de aceptación de calificadores y su propagación; activación requiere propuesta
concreta y aprobación D-006. No alterar equivalencias para aumentar cierres.
[Revisión actual de consumidores](proposals/20261021-requirements-consumer-review.md).
