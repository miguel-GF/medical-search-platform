# Puebla: cinco establecimientos incorporados sin duplicar SEMIN

21-oct-2026,12:39:06UTC. Operación local D-021/D-022 contra el proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`. Renderer existente sin cambios, sin migraciones,
despliegues, fuentes nuevas o suites formales.

| Nombre DENUE íntegro | DENUE / CLUES | Dirección conservada |
| --- | --- | --- |
| CENTRO DE SALUD RURAL DE SAN FRANCISCO COAPAN |3446950 / PLIMB002236|Calle Matamoros2,72760,San Pedro Cholula|
| CENTRO DE SALUDE JESUS DE NAZARENO |3305491 / PLIMB006931|Calle2Sur42,75505,Palmar de Bravo|
| CONSULTORIO BINE MEDICO FAMILIAR ISSSTEP |10142978 / PLSME000365|Boulevard Hermanos Serdán203,72140,Puebla|
| CONSULTORIO MEDICO TURNO MATUTINI PROFESOR GREGORIO DE GANTE |3341943 / PLSME000423|Calle Camino Real a Tlaxcala11,72100,Puebla|
| FUNDACION BEST |11734409 / PLSMP008443|Boulevard Norte1831,72090,Puebla|

Cinco marcas/sedes/bindings/auditorías/observaciones nuevos. Todos conservan tipo
`office`, nombres íntegros y coordenadas DENUE. Marcas verification_pending,
sedes pending, websiteNULL. Sin estudios, horarios, precios, operación actual,
acceso, operador, afiliación jurídica o cobertura comercial acreditados.

## Evidencia y discrepancias

Se reconsultaron seis RAW completos y snapshots199marcas/283sedes después de
la interrupción, sin sobrescribir el discovery previo. Nombres específicos,
códigos territoriales, CP, vía y exterior completos revisados; interiores/letras
vacíos. Extracción CLUES existente:64,450filas nacionales/3,779Puebla/seis claves
exactas sin faltantes. CLUESagosto es referencia, no nueva ingesta ni operación actual.

- Coapan/Cuapan/Coapa se conservan en sus fuentes; localidad0007/municipio140,
  Matamoros2 y72760 concuerdan. No regla global de corrección ortográfica ni operador
  inferido del prefijoPLIMB.
- Jesús Nazareno conserva SALUDE/DE. La Clínica Nazareno existente tiene otro
  nombre, DENUE3305651 y3Norte86/Juquila; no se fusionan.
- [BINE institucional](https://bine.mx/nosotros/) desarrolla la sigla y corrobora
  inmueble/domicilio escolar por webtool. HTTP directo403 guardado separado;
  no se presenta como200 ni como operación médica/afiliación ISSSTEP comprobada.
  Escuela y consultorio no se convierten en la misma marca o website.
- Gregorio de Gante conserva MATUTINI sin derivar horario, y el asentamiento
  DENUE IZTATLAN TENEXTLATILOYAN frente a SAN JERÓNIMO CALERAS de CLUES. El
  [encarte institucional IEEP2022](https://www.ieepuebla.org.mx/2022/banner/PUE_ENCARTE_UBICAC_E_INTEGRAC_MDC.pdf)
  corrobora históricamente escuela/nombre/CaminoReal11/72100, no servicio médico
  actual. No se descargaron nombres de personas del documento.
- Fundación Best/A.C. se revisa para este inmueble. Farmacias Similares
  DENUE12276702 comparte dirección/CLUES, pero nombre distinto: no se incorpora
  ni se atribuye como misma entidad o red.

**SEMIN6377846 excluido:** ya tiene vínculo productivo desde agosto, aunque no
aparecía en las fixtures de estas revisiones. No se duplica ni se modifica.
Se conservó su sexto contexto y se seleccionaron únicamente cinco para el renderer.

## Comprobación y alcance

Rollback sin persistencia, único commit y observador independiente: las
**199marcas/283sedes anteriores permanecen íntegramente iguales**. Cinco RAW
seleccionados, políticas y contadores clínicos intactos. Coordenadas, nombres,
tipos y líneas de dirección exactos; cinco trazas de auditoría y fuente.

Fixture aplicada desde artefacto y luego copiada byte por byte para versionar:
`database/data/provider-identity-review-20261021-05.json`, SHA256
`c0bb0ec01a54c039723d96f56889d5fb29fa7afecd02ee9d6b00b66e53648e5a`.
Artefactos: `collectors/artifacts/puebla-expansion-20261009/identity-review-40-research-20261021/`.
Incluyen snapshots, fuentes, extracción, SQL, recibos y `applied-verified.json`.

Recuento real del conjunto discovery234hipótesis:27ya vinculadas+1retenida
(Beneficencia) dejaban206antes40; al incorporar estas cinco quedan201hipótesis
de ese conjunto sin resolver.124no tienen exterior numerado y77tienen otros
bloqueos en esa clasificación. No son201identidades aprobadas ni todo el universo
DENUE; no cerrar por direcciónS/N o parecido. La cuenta anterior208basada sólo
en fixtures era incompleta al omitir bindings anteriores, incluido SEMIN.

**204marcas /288sedes /563conceptos /3,341registros favorables /4,047pendientes /
946históricos /234ofertas /112migraciones**. Sin cobertura comercial nueva.
El inventario clínico completo05:48UTC sigue vigente como corte, sin reconstruirlo
por una incorporación exclusivamente de identidad. Continuar evidencia propia
por sede y las hipótesis restantes con criterio de identidad individual.
