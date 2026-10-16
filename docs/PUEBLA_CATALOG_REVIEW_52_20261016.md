# Puebla: revisiones51–52 y ampliación de centros públicos

Entorno: Supabase productivo existente `ymtcmfgwuzdqtsbuvzqf`.
Trabajo autorizado por D-021/D-022 y commits locales por D-023.
Fecha: 16-oct-2026 UTC, noche del 15-oct en Puebla.

## Estudios aplicados y observados

Las revisiones51 y52 cerraron **35 registros**, con cuatro conceptos nuevos,
dos reutilizados y siete aliases limitados al proveedor. El catálogo pasó de
525 a529 conceptos y de4,286 a4,251 registros pendientes.

- Estrógenos totales: nueve registros; suero sólo en el contexto SEMIN que lo
  declara. No se presume la muestra de Salud Digna ni un fraccionamiento.
- Anticuerpos contra Histoplasma capsulatum, Aspergillus fumigatus y
  fosfatidilserina: ocho registros de cada blanco. Conservan el isotipo y la
  composición desconocidos. No equivalen a IgG, IgM, IgA, IgE, anticuerpos
  totales ni a un panel; sólo se identifica la orden nominal de ese proveedor.
- Hierro en suero y azúcares reductores en heces: dos registros SEMIN;
  se reutilizan definiciones existentes sin modificarlas y se guarda la
  muestra literal de cada origen.

La aplicación se contrastó con originales, UUID, guardas y atributos, resolver
v6 con proveedor y API pública real. Dieciséis solicitudes HTTP, siete consultas
con proveedor y26 observaciones de etiquetas y variantes. Los nombres canónicos
resuelven; las etiquetas genéricas que requieren proveedor o muestra conservan
su respuesta sin resolución pública concluyente. No se presenta la resolución
de un registro de proveedor como una aprobación global de su nombre.

Recibos independientes:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-51-individuals/`,
`review-52-reused/` y `reviews-51-52-observed-close.json`.
Las52 revisiones son investigación de órdenes, no cobertura comercial nueva.

## Laboratorios e instituciones

Identidad25: Laboratorios Galaviz y RVLAB, dos marcas y dos sedes pendientes.
Se contrastó el directorio municipal histórico con DENUE: Galaviz conserva
exterior1612/interior4A; RVLAB conserva su número desconocido frente a5015L1
del documento, sin rellenarlo. No se usaron promociones como ofertas.

Identidad26: Tlaola, Cuyoaco, Zacapala y Ajalpan, cuatro instituciones
comunitarias candidatas. Fuente federal histórica y DENUE; clasificación622112,
domicilios, coordenadas y discrepancias conservados. La errata HOPITAL permanece
en la sede RAW de Ajalpan; corregir el nombre de la marca no corrige la fuente.
El anexo documental correcto es Anexo2: se preservó el borrador previo y se
corrigió esa referencia antes de ejecutar el único commit.

Después de ambas aplicaciones:91 marcas y175 ubicaciones, con529 conceptos,
4,251 pendientes,234 ofertas y112 migraciones. Hubo rollback, commit único y
observación independiente para cada lote; websNULL sin sitio propio acreditado.
Recibos: `identity-review-25/` y `identity-review-26/` en los artefactos de Puebla.

## Fuente federal y centros pequeños

Se recuperó con HTTP200 y TLS el [convenio federal](https://sidof.segob.gob.mx/notas/docFuente/5735638),
cuyo Anexo2 corresponde al convenio de15-marzo-2024. Se conserva el cuerpo
original, su hash y las filas documentales. No se acredita por ello operación
en2026 ni una dependencia administrativa actual de cada unidad.

Discovery:594 filas de centros/CESSA revisadas;23 candidatas contrastadas con
nombre específico, municipio, localidad, CP, vialidad y número;571 retenciones.
La búsqueda de nombres sólo omite acentos, puntuación y partículas gramaticales
para proponer candidatos. La aprobación de cada caso conserva los pares fuente/RAW
y discrepancias de tipo vial, colonia, letras e interiores; no se infieren
equivalencias viales ni se fusionan unidades colocalizadas.

Las clases DENUE621112 (consultorios públicos de medicina general) y621116
(clínicas públicas de consultorios) se admiten como `office` y `clinic`, tipos
existentes del modelo. Se conserva el código fuente. No hay migración ni cambio
del resolver. El renderer mantuvo idéntico por bytes el SQL de los lotes25 y26.
Identidad27 se aplicó y terminó su observación independiente a las04:03:50UTC:
23 marcas y23 ubicaciones nuevas,18 de tipo `clinic` y5 de tipo `office`;
23 vínculos DENUE,23 auditorías y23 observaciones aceptadas. RAW, coordenadas,
domicilios y discrepancias intactos; las23 webs permanecenNULL. Se observó
rollback sin persistencia, seguido por un único commit y lectura independiente.
Totales finales: **114 marcas / 198 ubicaciones / 529 conceptos / 4,251
registros pendientes / 234 ofertas / 112 migraciones**. Recibo:
`collectors/artifacts/puebla-expansion-20261009/identity-review-27/applied-verified.json`.

## Corrección del preparador y límites

El preparador copiaba el primer destino dentro de la base común de un alias;
al expandirlo por proveedor, un atributo del primero podía sobrevivir cuando
otro destino no declaraba ese atributo. Se construye ahora la base sin destino
y se incorporan únicamente los atributos propios de cada proveedor. Para alias
globales se conserva el primer destino y los adicionales explícitos.

La revisión51 ya conservaba correctamente suero sólo en SEMIN. Una auditoría
local de14 destinos de proveedor con definiciones disponibles no encontró
diferencias entre atributos declarados y fixtures; su alcance no cubre toda la
historia remota. Recibo `clinical-research/provider-source-attributes-audit-20261016.json`.
La comprobación posterior de51 también encontró guardas/atributos exactos.

Vitamina D TOTAL, PTH sin fracción y nicotina frente a cotinina siguen retenidas.
Se conservaron cultivos con matrices no soportadas, paneles, métodos y protocolos
de imagen pendientes. No se activó una propuesta crítica para aumentar cierres.
Ofertas234 y migraciones112 se mantienen; identificar una unidad no confirma
un estudio, su precio, disponibilidad, permisos sanitarios o condiciones de acceso.
Sin suites formales, capturas comerciales nuevas, contactos, push o despliegues.
