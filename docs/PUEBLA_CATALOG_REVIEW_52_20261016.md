# Puebla: revisiones 51–52 y ampliación de centros públicos

Entorno: Supabase productivo existente `ymtcmfgwuzdqtsbuvzqf`.
Trabajo autorizado por D-021/D-022 y commits locales por D-023.
Fecha: 16-oct-2026 UTC, noche del 15-oct en Puebla.

## Estudios aplicados y observados

Las revisiones 51 y 52 cerraron **35 registros**, con cuatro conceptos nuevos,
dos reutilizados y siete aliases limitados al proveedor. El catálogo pasó de
525 a 529 conceptos y de 4,286 a 4,251 registros pendientes.

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
v 6 con proveedor y API pública real. Dieciséis solicitudes HTTP, siete consultas
con proveedor y 26 observaciones de etiquetas y variantes. Los nombres canónicos
resuelven; las etiquetas genéricas que requieren proveedor o muestra conservan
su respuesta sin resolución pública concluyente. No se presenta la resolución
de un registro de proveedor como una aprobación global de su nombre.

Recibos independientes:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-51-individuals/`,
`review-52-reused/` y `reviews-51-52-observed-close.json`.
Las 52 revisiones son investigación de órdenes, no cobertura comercial nueva.

## Laboratorios e instituciones

Identidad 25: Laboratorios Galaviz y RVLAB, dos marcas y dos sedes pendientes.
Se contrastó el directorio municipal histórico con DENUE: Galaviz conserva
exterior 1612/interior 4A; RVLAB conserva su número desconocido frente a 5015L 1
del documento, sin rellenarlo. No se usaron promociones como ofertas.

Identidad 26: Tlaola, Cuyoaco, Zacapala y Ajalpan, cuatro instituciones
comunitarias candidatas. Fuente federal histórica y DENUE; clasificación 622112,
domicilios, coordenadas y discrepancias conservados. La errata HOPITAL permanece
en la sede RAW de Ajalpan; corregir el nombre de la marca no corrige la fuente.
El anexo documental correcto es Anexo 2: se preservó el borrador previo y se
corrigió esa referencia antes de ejecutar el único commit.

Después de ambas aplicaciones:91 marcas y 175 ubicaciones, con 529 conceptos,
4,251 pendientes,234 ofertas y 112 migraciones. Hubo rollback, commit único y
observación independiente para cada lote; websNULL sin sitio propio acreditado.
Recibos: `identity-review-25/` y `identity-review-26/` en los artefactos de Puebla.

## Fuente federal y centros pequeños

Se recuperó con HTTP 200 y TLS el [convenio federal](https://sidof.segob.gob.mx/notas/docFuente/5735638),
cuyo Anexo 2 corresponde al convenio de 15-marzo-2024. Se conserva el cuerpo
original, su hash y las filas documentales. No se acredita por ello operación
en 2026 ni una dependencia administrativa actual de cada unidad.

Discovery:594 filas de centros/CESSA revisadas;23 candidatas contrastadas con
nombre específico, municipio, localidad, CP, vialidad y número;571 retenciones.
La búsqueda de nombres sólo omite acentos, puntuación y partículas gramaticales
para proponer candidatos. La aprobación de cada caso conserva los pares fuente/RAW
y discrepancias de tipo vial, colonia, letras e interiores; no se infieren
equivalencias viales ni se fusionan unidades colocalizadas.

Las clases DENUE 621112 (consultorios públicos de medicina general) y 621116
(clínicas públicas de consultorios) se admiten como `office` y `clinic`, tipos
existentes del modelo. Se conserva el código fuente. No hay migración ni cambio
del resolver. El renderer mantuvo idéntico por bytes el SQL de los lotes 25 y 26.
Identidad 27 se aplicó y terminó su observación independiente a las 04:03:50 UTC:
23 marcas y 23 ubicaciones nuevas,18 de tipo `clinic` y 5 de tipo `office`;
23 vínculos DENUE,23 auditorías y 23 observaciones aceptadas. RAW, coordenadas,
domicilios y discrepancias intactos; las 23 webs permanecenNULL. Se observó
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

La revisión 51 ya conservaba correctamente suero sólo en SEMIN. Una auditoría
local de 14 destinos de proveedor con definiciones disponibles no encontró
diferencias entre atributos declarados y fixtures; su alcance no cubre toda la
historia remota. Recibo `clinical-research/provider-source-attributes-audit-20261016.json`.
La comprobación posterior de 51 también encontró guardas/atributos exactos.

Vitamina D TOTAL, PTH sin fracción y nicotina frente a cotinina siguen retenidas.
Se conservaron cultivos con matrices no soportadas, paneles, métodos y protocolos
de imagen pendientes. No se activó una propuesta crítica para aumentar cierres.
Ofertas 234 y migraciones 112 se mantienen; identificar una unidad no confirma
un estudio, su precio, disponibilidad, permisos sanitarios o condiciones de acceso.
Sin suites formales, capturas comerciales nuevas, contactos, push o despliegues.

## Inventario completo 52 y revalidación posterior

El cierre final terminó a las 04:06:54 UTC: **4,251 registros pendientes en 781
grupos,529 conceptos y 1,279 términos**. Memoria v3 con 52 revisiones,388 aliases,
407 reglas y 2,777 históricos reutilizables. Paginación completa por UUID;
cola 46 verificada por ledger/hash y 24 archivos previos preservados. Fuentes,
contadores y resolver se mantuvieron antes/después; ningún pendiente recibió
aprobación nueva por esa memoria. Informe y recibo:
`collectors/artifacts/normalization-memory-after-review-52-v3/`.

A las 12:00 UTC una lectura nueva confirmó los mismos contadores, el hash de
cola y los artefactos completos. Landing, app, API y tres servicios locales
respondieron 200. La pérdida del handle no motivó repetir el proceso terminado.
Recibo: `collectors/artifacts/catalog-resume-20261016/live-baseline-and-endpoints.json`.

Los agentes alcanzaron su límite durante la preparación posterior de imagen.
El agente principal completó la lectura de 14 RAW y el importador aislado, y
registró los límites reales de integración. Eso no cierra esas 14 filas ni
activa el modelo de imagen; [estado de la propuesta](proposals/20261016-imaging-importer-and-integration.md).
