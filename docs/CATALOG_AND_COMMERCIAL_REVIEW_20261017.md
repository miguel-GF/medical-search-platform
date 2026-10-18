# Catálogo y revisión comercial — 17 de octubre de 2026

## Reanudación y datos aplicados

Entorno: Supabase enlazado `ymtcmfgwuzdqtsbuvzqf`, usado por producción.
El usuario reanudó expresamente el trabajo y pidió frentes paralelos de captura
sin revisar, cierre de pendientes existentes y búsqueda más sólida.

Revisión `pruevia:evidence-review:20261017:01`:33 registros,4 conceptos y5 aliases
exclusivos de proveedor. Identidades nominales VSG, resistencia a proteína C
activada, yodo proteico y actividad de diamino oxidasa. La matriz y método
desconocidos permanecen desconocidos; el plasma explícito de SEMIN se conserva
en el contexto de fuente. Observación independiente12:41 UTC:81 RAW intactos,
48 contextos retenidos intactos,5 consultas con proveedor y10 HTTP públicos.
No se convirtieron métodos, genotipos o concentraciones en equivalencias.
El borrador original `reviewed-aliases-20261016-09.json` permanece sin aplicar.

Identidades `pruevia:provider-identity-review:20261017:01`:12 unidades públicas
candidatas,3 consultorios,8 clínicas y1 hospital según la clasificación DENUE
conservada. Fuente federal histórica de2024 contrastada con DENUE, incluyendo
direcciones sin número y discrepancias. No prueba operación actual ni servicios.
Rollback observado, commit único y lectura independiente12:44 UTC:12 bindings,
12 auditorías y12 observaciones; RAW, coordenadas y políticas conservados.
Marcas `verification_pending`, sedes `pending`,12 sitios web desconocidos.

Cierre adicional12:49 UTC: revisión `20261017:04`, ocho registros nominales
de crioglobulinas, un concepto y un alias de proveedor.24 RAW intactos y16
contextos retenidos intactos; dos HTTP públicos, una consulta con proveedor y27
variantes sin selección incompatible del nuevo concepto. No se incorporan
reflejos, método, tipificación o muestra desde una ficha externa.

Los borradores `20261017:02` y `:03` quedan **sin aplicar**: observaciones en
rollback detectaron semicuantitativo→cuantitativo para factor reumatoide y
razón globulina/albúmina→albúmina/globulina. Se retienen ambos grupos y se
documenta la corrección del core como propuesta D006; no se activó.

Corte observado: **547 conceptos,4,106 registros pendientes,126 marcas o
instituciones,210 ubicaciones,234 ofertas y112 migraciones**. Ubicaciones
candidatas y ofertas comerciales son contadores distintos.

## Capturas separadas

Samalab y Medic Scanner: capturas oficiales acotadas, artefactos con URL, fecha,
hash y alcance de sucursal.4 RAW del adaptador genérico y41 pares de
sucursal/rótulo obtenidos por extracción local, que incluyen categorías y
duplicados; **no representan41 estudios nuevos**. Comparación histórica sin
altas ni bajas en esos pares. Ambas marcas siguen sin ofertas comerciales
registradas. El bloque queda sin revisar y fuera de la cola de cierre.

Evidencia: `collectors/artifacts/commercial-source-review-20261017/REPORT.md`.

## Corrección comercial publicada

El usuario pide presentación uniforme de precios en línea y en sucursal, con
tarifas adicionales condicionadas a membresía/tarjeta identificadas aparte.
No se presupone cuenta o suscripción cuando la fuente no lo declara.
También solicita revisar destinos reales de Salud Digna, Chopo y Ruiz y ocultar
el botón de reservar por ahora. Una URL que abre el estudio o la ciudad no
acredita selección de sucursal; cookies/storage de otra web no son transferibles
desde Pruevia.

Navegador real, contexto limpio por marca,12:40–12:47 UTC: Salud Digna abre
selección de clínica y no conserva el estudio al elegir Puebla; su landing de
sucursal identifica la sede, sin configurar una cita. Chopo conserva el estudio
y mercado Puebla; Paseo Bravo sólo persiste tras selección en ese navegador,
incluido Atrás y recarga. Ruiz abre correctamente el estudio y permite consultar
sedes, sin dejar una sede seleccionada. Se conservan únicamente metadatos de
cookies/storage, sin sus valores, cuentas, compras ni citas.

La corrección mantiene enlaces informativos y el aviso de selección necesaria.
Una URL de booking duplicada como estudio deja de presentarse como ficha.
Dos URL distintas de estudio y sucursal no acreditan un destino con ambos
seleccionados. Reservas ocultas con `PATIENT_BOOKING_ENABLED=false`.
Las tarifas base son en línea/en sucursal; tarjeta azul/dorada se distinguen
por la clave recibida. Prepago y promociones conservan su condición separada.
No se añaden tarifas ni se supone que todos los visitantes tienen membresía.

API publicada12:48:00 UTC, versión `45ed6a34-fcf6-4205-8d6b-0555926072d4`.
Patient publicada12:48:25 UTC, versión `77d5af9e-d470-43a4-a2e8-921c5174cc07`.
Build congelado46 archivos, JS
`ad4d4c8f0bd0e40954decc034e929f9624a5c7de6fec5f2785ca5d0a2516db8c`.
También se filtran las sugerencias por los calificadores de la consulta:
T3 libre deja de sugerir T4 libre. No cambia el resolvedor SQL ni crea aliases.

Lectura pública posterior: seis GET200,34 ofertas de biometría con las mismas
identidades y tarifas al comparar por tipo/clave/importe/moneda/fecha. El orden
de tarifas y el campo principal `price` pueden variar; no se afirma estabilidad
de ese primer elemento. Salud Digna conserva los enlaces de sucursal y elimina
el falso estudio duplicado; Chopo/Ruiz mantienen ficha. CORS app204/ajeno403.
TypeScript y dry-run terminaron0; Flutter release0 y análisis dirigido sin
hallazgos. El análisis de todo Patient conserva un aviso previo en
`local_preferences.dart:33`; no es un resultado limpio de todo el repositorio.

Evidencia de navegación en
`collectors/artifacts/provider-navigation-review-20261017/`; publicación,
fuentes aisladas, hashes, recibos y observaciones en
`collectors/artifacts/commercial-ui-fix-20261017/`.
Recuperación independiente: API anterior `777b7a40-1785-4bb5-aa4c-1990cc7d416b`,
Patient anterior `7f63b3eb-45f0-4ae2-9ee8-0a56b546230d`; sin tocar catálogo.

## Evidencia y límites

Artefactos de catálogo bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-56-adjusted/`
y `identity-review-28/`. Reanudación y cola50 en
`collectors/artifacts/catalog-resume-20261017/`.
No se ejecutaron suites; observaciones operativas no acreditan cobertura de
recetas completa. Las propuestas críticas de composición e imagen siguen
aisladas y sin activar. Corte completo12:52 UTC:4,106 pendientes en762 grupos,
1,316 términos. Memoria shadow56 revisiones,407 aliases,426 reglas y2,922
contextos históricos reutilizables;175 archivos de cortes previos conservados.
Resolver y fuentes intactos,50 entradas de cola con ledger/hash comprobados.
Recibos: `collectors/artifacts/normalization-memory-after-review-57-20261017-v3/`.
Siguiente acción: terminar la [corrección de controles móviles](MOBILE_CONTROLS_20261018.md),
continuar grupos individuales compatibles y conservar ambigüedades demostradas.
