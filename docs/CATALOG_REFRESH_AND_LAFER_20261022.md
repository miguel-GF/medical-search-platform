# Inventario actualizado y siguiente revisión Lafer

## Corte real: 22-oct-2026, 12:36:52 UTC

Consulta de sólo lectura al proyecto Supabase productivo enlazado
`ymtcmfgwuzdqtsbuvzqf`. Exportación completa por páginas y UUID, sin pacientes.

| Indicador | Total |
| --- | ---: |
| Marcas / sedes | 205 / 291 |
| Conceptos activos | 563 |
| Registros resueltos favorablemente | 3,341 |
| Registros pendientes abiertos | 4,047 |
| Grupos proveedor + nombre | 745 |
| Términos del catálogo | 1,349 |
| Ofertas activas / migraciones | 234 / 112 |
| Históricos no_match separados | 946 |

La memoria se reconstruyó consultando el ledger de las fixtures locales:
66 revisiones aplicadas. Los 4,047 contextos pendientes requieren evidencia;
ninguno es una reutilización exacta automáticamente aprobada. El estado agregado
y fuentes coinciden antes/después, y la cola local no cambió.
No se reinició el ejecutor ni se ejecutaron suites formales.

## Memoria de investigación ejecutada

El planificador existente se ejecutó sobre el inventario fresco, con cuatro
retenciones anteriores y las dos fichas SEMIN de la revisión77. Resultado:

- 739 grupos / 4,034 filas por investigar.
- 6 grupos / 13 filas esperando cambios documentados, sin cierre ni aprobación.

Las retenciones incluyen hashes de evidencia, contexto exacto y caducidad.
Las nuevas de SEMIN vencen el 23-oct a las 12:31 UTC; las anteriores conservan
su fecha original. El vencimiento o cambio de contexto/evidencia devuelve el caso
a investigación. No se renovó silenciosamente la fecha de evidencia antigua.
Estas cifras describen la planificación local, no disponibilidad comercial.

## Lafer: tres definiciones aclaradas, seis filas aún abiertas

Las páginas oficiales permiten entender las órdenes sin equipararlas al
seminograma completo ni a un examen general de orina:

| Orden | Significado documentado por el proveedor | Pendiente técnico |
| --- | --- | --- |
| [Prueba hiposmótica](https://lafer.mx/laboratorio-de-andrologia/prueba-hiposmotica/) | Revisa la respuesta funcional de la membrana del espermatozoide a un medio hiposmótico. | Representar muestra y procedimiento sin reducirlo a un analito genérico. |
| [Postcoital, Sims-Huhner](https://lafer.mx/laboratorio-de-andrologia/prueba-post-coital-sims-huhner/) | Examina la interacción entre espermatozoides y moco cervical después del coito. | Conservar sitio y momento de obtención; no registrarlo como muestra convencional de semen eyaculado. |
| [Orina posterior a eyaculación](https://lafer.mx/laboratorio-de-andrologia/evaluacion-de-orina-post-eyaculado-eyaculacion-retrograda/) | Busca espermatozoides en esa orina para la evaluación que describe el proveedor. | Mantener la condición posterior a eyaculación y revisar colisiones/consumidores antes de incorporar. |

Una lectura nueva de los seis RAW confirmó que siguen abiertos. No aparecieron
canónicos activos con los patrones espermático/semen/hiposmótico/coital/Huhner/
eyaculación en el nombre principal. Esta búsqueda acotada no descarta por sí sola
duplicados con otros nombres. El catálogo tiene nueve tipos de muestra activos;
no tiene semen ni moco cervical como códigos específicos. No se añadieron códigos
ni se usó una muestra desconocida para ocultar esos atributos conocidos.

Siguiente acción: revisar nombres secundarios y definiciones, preparar la orden
urinaria sólo si el contrato conserva su condición, y aislar la representación
faltante de las otras dos. No hay fixtures nuevas, aliases aprobados, cierres,
ofertas ni cambios del motor en esta revisión. La evaluación combinada D-006
permanece sin ejecutar y conserva su autorización pendiente.

## Evidencia local

Directorio `collectors/artifacts/catalog-refresh-20261022/`:

- `observation.json`, SHA256 `1f69caa257ae7fce51435bce0f18f52d3ffe44248091060c83f47c38a43d38b0`.
- `pending-contexts.json`, SHA256 `e09f563b5ea6ea8ce58d81685ef25ef55e0ab479cf270b4cf3935e4a7d01fc4d`.
- `research-queue.json`, SHA256 `274ca5505c0dc6ac3c273639b7d04c5d8a843f52f796afb6edffffad9b57f055`.
- `lafer-findings.json`, SHA256 `1a681b40349a0ca609302ce81aa8f336d25a09af629f2c090809575685d9db70`.

`refresh.py` conserva paginación, memoria, fuentes y estado antes/después.
`prepare_research.py` genera la planificación y hallazgos sin escritura remota.
El primer intento de preparación rechazó una fecha con siete decimales no
admitida por Python; se corrigió a seis sin modificar el instante de captura
significativo. No había generado resultados y no se repitió ninguna escritura.

Los RAW y muestras recién consultados están en
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-78-lafer-20261022/`.
Las descripciones de las páginas se conservaron como paráfrasis identificadas;
no se presentan como capturas originales HTTP ni como recomendaciones médicas.
