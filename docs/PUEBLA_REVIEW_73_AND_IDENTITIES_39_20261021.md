# Puebla: Bence Jones urinaria y ocho establecimientos incorporados

21-oct-2026 UTC (20-oct local). Operación local D-021/D-022 contra el proyecto
productivo `ymtcmfgwuzdqtsbuvzqf`. Sin migraciones, cambios del resolvedor,
despliegues, nuevas políticas de fuente o suites formales.

## Ocho registros de una orden identificados

**Proteína de Bence Jones en orina**, ocho registros Salud Digna. El título propio
identifica Bence Jones y la preparación íntegra declara orina, primera de la mañana
o a cualquier hora. Se conserva esa alternativa: no convertirla a restricción
matutina, duración24h, técnica, cuantificación o composición kappa/lambda.

[MedlinePlus003597](https://medlineplus.gov/ency/article/003597.htm) respalda la
denominación urinaria. Su título cuantitativo no completa la escala del producto
SD. La frase del informe inicial sobre una posible recolección24h no figura en
la referencia capturada; `SOURCE_CORRECTION.md` deja la precisión sin sobrescribir
el informe/hashes originales. La fixture ya conservaba duración y escalaNULL.
No se aprueban resultados diagnósticos o equivalencia con proteína total,
cadenas ligeras séricas, cocientes, inmunofijación o electroforesis.

Preparador existente revalidó ocho RAW completos, colisiones exactas y guarda
exclusiva de proveedor sobre `raw_study.Preparacion`, con atributo urine.
**23 consultas públicas y23 de proveedor**, observadas en rollback: canónico
resuelto en ambas, título original resuelto sólo para SD y ambiguous públicamente.
Variantes examinadas de muestra, tiempo, serie, técnica, cuantificador, fracción,
isotipo y negación no seleccionaron el concepto como resolved. Algunas quedan
ambiguous, no equivalentes. Observación acotada, no protección universal.

Fixture aplicada: `database/data/reviewed-aliases-20261021-05.json`.
Revisión `pruevia:evidence-review:20261021:05`, SHA256
`82fff576789412c2b438ae99e729af296bc2080e927ea4b7c47d3b56e7214ff5`.
Cola59→60 conservó pins anteriores; el mismo workerPID17024 aplicó el lote.
El coordinador no repitió escrituras ni reinició procesos.

**Observador independiente05:42:39UTC:** ledger already_applied, ocho decisiones,
un concepto nuevo, guarda y orina conservadas.24RAW completos/precios/labels intactos,
incluidos16registros retenidos de rotavirus/BK. Método, propiedad, escala, tiempo
y LOINC siguen desconocidos; políticas/fuentes conservadas. Cero ofertas nuevas.
API local observada: HTTP200, canónico resolved y cero ofertas. El nombre se leyó
desde la fixture UTF-8, sin introducir texto clínico real ni depender del encoding
del shell. Recibo `local-applied-observed.json`; PID17024 confirmado vivo.

## Ocho identidades incorporadas

| Nombre DENUE íntegro | DENUE / CLUES | Dirección DENUE / tipo conservados |
| --- | --- | --- |
| CENTRO DE SALUD 1 NUCLEO BASICO SAN FELIPE XOCHILTEPEC |3515989 / PLIMB003303|Calle Zacatecas12,74620 /clinic|
| CENTRO DE SALUD AHUATLAN NUCLEO BASICO MAS DENTAL |6762716 / PLIMB007380|Calle5deMayo5,74640 /office|
| CLINICA DE IMSS UMR TZICATLAN |3451618 / PLIMS001805|Calle Cuauhtémoc7,74728 /clinic|
| INSTITUTO MEXICANO DEL SEGURO SOCIAL UNIDAD MEDICA RURAL HUEYTAMALCO |3473497 / PLIMS001834|Calle Francisco Sarabia33,73580 /hospital|
| UNIDAD MEDICA RURAL DE TEOPANTLAN |3504905 / PLIMS002855|Calle16deSeptiembre3,74600 /hospital|
| UNIDAD DE SALUD XALTIPAN |3487806 / PLIMS003490|Calle Antonio Julián Zapata204,73972 /hospital|
| CLINICA SAN JOAQUIN |3531415 / PLSMP000632|Avenida Maximino Ávila Camacho206,75200 /office|
| CLINICA MEDICA QUIRURGICA CANDIA NUESTRA SEÑORA DE LOURDES |6450629 / PLSMP001460|Privada101Oriente1612,72587 /hospital|

Denominaciones específicas y domicilios completos numerados revisados
individualmente. Municipio/localidad/CP/tipo de vía/vialidad/exterior concuerdan;
interiores y letras vacíos. CLUES nombra cuatro unidades rurales por localidad
dentro de filas de establecimientos: contexto sanitario, territorio y dirección
sustentan esas candidatas; no se utiliza una coincidencia de localidad aislada.

Se conservan descriptores SAN FELIPE/NUCLEO BASICO/MATERNA INFANTIL/NUESTRA SEÑORA
DE LOURDES, formas sociales y asentamientos distintos en sus fuentes. Sin regla
automática para quitar palabras, fusionar por dirección o reclasificar hospitales
como clínicas al leer UMR. No se atribuyen servicios dentales o maternidad por nombre.

DENUE INEGI20-may/captura9-oct aporta campos licenciados; CLUESagosto es referencia
de investigación. El extractor existente confirmó64,450filas nacionales,
3,779Puebla/ocho claves exactas, sin faltantes. EN OPERACION es sólo estado mensual.

Capturas directasHTTP200 del [directorio IMSS400](https://www.imss.gob.mx/directorio?direcciongeo=&dom_estado=&page=400&tipo_de_servicio=)
corroboran nombres/domicilios de Tzicatlán y Hueytamalco; [directorio408](https://www.imss.gob.mx/directorio/?page=408)
corrobora Teopantlán. La etiqueta IMSS BIENESTAR del directorio discrepa de la
institución IMS de CLUES: se conserva la discrepancia, sin decidir operador,
sucesión o asociación a una marca existente. Xaltipan no se asigna a una red por
analogía. Ocho identidades independientes, verification_pending/pending, websiteNULL.

Renderer sin cambios, rollback sin persistencia y único commit. Observador
independiente a**05:41:19UTC**: ocho marcas/sedes/bindings/auditorías/observaciones;
**191marcas y275sedes previas íntegramente iguales**. RAW/políticas/contadores
clínicos intactos; coordenadas, tipos, nombres y direcciones exactos. Sin precios,
horarios, disponibilidad, acceso o cobertura comercial aprobados.

Fixture aplicada: `database/data/provider-identity-review-20261021-04.json`.
SHA256 `8b8ee7819b0e49f664ce1b4def61bae4dad4a8b324fa7f0536e5e629ccadbae9`.

## Retenciones y corrección del motor

Rotavirus8 declara blanco/heces, sin modalidad suficiente para decidir antígeno
o RNA. PoliomavirusBK8 no declara muestra/modalidad suficiente. Referencias
[CDC rotavirus](https://www.cdc.gov/rotavirus/hcp/clinical-overview/index.html),
[Labcorp BKplasma138962](https://www.labcorp.com/tests/138962/bk-virus-bkv-quantitative-pcr)
y [BKorina138880](https://www.labcorp.com/tests/138880/bk-virus-bkv-urine-quantitative-pcr)
demuestran distinciones que no pueden completarse desde los títulos SD. Las16filas
siguen abiertas e intactas; falta ficha propia, no otra definición general.

Se preparó y solicitó aprobación específica para una
[evaluación acotada con rollback](proposals/20261021-requirements-rollback-evaluation.md)
del cambio de calificadores. SQL con guards de definiciones, límites de bloqueo
y tiempo, sin COMMIT, **todavía no enviado**. AGENTS/D-006 exige esa aprobación;
la incorporación ordinaria de datos no depende de recibirla. Tampoco implica
permiso de publicar API/PWA ni activar después el cambio persistente.

## Estado y siguiente acción

**563conceptos /3,341registros favorables /4,047pendientes /946históricos /
199marcas /283sedes /234ofertas /112migraciones**. Nuevas identidades no acreditan
catálogo ni precios. Continuar pendientes no investigados y evidencia propia por
sucursal; conservar retenciones y confirmar consentimiento específico antes de
ejecutar la evaluación compartida. No marcar cobertura Puebla completa.

### Inventario completo y continuidad posterior

Finalizado **05:48:00UTC**:745grupos/4,047pendientes/1,349términos; memoria shadow
66revisiones/424aliases/443reglas/2,981contextos históricos reutilizables exactos.
60ledgers/hash de cola verificados,273archivos de cortes anteriores SHA256 iguales.
Contadores, fuentes y bytes de cola intactos; MD5 de la función base
`catalog.resolve_items(text,text,uuid,integer)` conservado, sin atribuir ese hash
a todas las versiones del resolvedor. Los4,047pendientes siguen requiriendo
evidencia; la memoria no realizó aprobaciones clínicas ni publicaciones.
Artefactos completos: `collectors/artifacts/normalization-memory-after-review-73-20261021-v3/`.

Relectura **12:30:16UTC** (21-oct local), después de la interrupción de uso:
mismos conteos, ledger73 already_applied y PID17024 realmente vivo; status watching,
sin revisión activa. Esta relectura confirma baseline y lote73, no una segunda
auditoría de todos los60ledgers. Recibos en `collectors/artifacts/catalog-resume-20261021-1229/`.
Los agentes se interrumpieron antes de completar identidad40/soporte moco nasal;
se retomaron sus tareas conservando artefactos y fechas. No confundir los60lotes
ya aplicados con investigadores trabajando continuamente en segundo plano.

Artefactos ignorados bajo `collectors/artifacts/puebla-expansion-20261009/`:
`clinical-research/review-73-candidates-20261021/`,
`identity-review-39-research-20261021/` y
`clinical-research/requirements-consumers-20261021/`. Fuentes, snapshots, SQL,
recibos y observaciones independientes permanecen allí; los manifiestos originales
de investigación no se presentan como inventario de los archivos posteriores del coordinador.
