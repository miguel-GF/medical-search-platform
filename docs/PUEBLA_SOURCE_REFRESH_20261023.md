# Puebla: inventario y nueva captura de Salud Digna

## Inventario productivo comprobado

Corte del 23-oct-2026, 12:25 UTC, proyecto `ymtcmfgwuzdqtsbuvzqf`.
Lectura completa por páginas y UUID; estado y cola iguales antes/después.

| Indicador | Total |
| --- | ---: |
| Marcas / sedes | 207 / 293 |
| Conceptos activos | 564 |
| Filas favorables / pendientes abiertas | 3,343 / 4,045 |
| Grupos pendientes | 744 |
| Ofertas activas / migraciones | 234 / 113 |
| Históricos no_match separados | 946 |

Memoria reconstruida con 67 revisiones aplicadas y 1,351 términos. Ninguno de
los pendientes se acreditó como reutilización exacta aprobada. Por categorías
escritas en la fuente: laboratorio 1,639; rayos X 1,546; tomografía 268;
resonancia 240; ultrasonido 167; el resto corresponde a otras categorías.
Las categorías no prueban equivalencia clínica ni disponibilidad.

## Recolector recuperado y ejecutado

La nueva captura de [Salud Digna Puebla](https://www.salud-digna.org/puebla-municipio-libre)
usa el mismo adapter y sus endpoints públicos existentes, sin sesión de paciente.
El primer intento falló por certificado; el segundo, después de corregir su
contexto TLS, por negociación de compresión. Ambos quedaron como fallidos y sin
registros. La tercera ejecución terminó con 828 registros válidos. Otra ejecución
recorrió las siete sucursales restantes y terminó con 6,088 registros válidos.

Cambios rutinarios del transporte:

- El contexto TLS configurado por Salud Digna, SEMIN, Linfolab y Dr. Simi se
  transmite al transporte que abre la conexión. Antes se entregaba al cliente
  externo y el transporte personalizado construía otro contexto.
- El transporte exige verificar certificado y nombre de servidor. Conserva
  validación de IP pública, conexión a la IP validada, Host/SNI y límites de redirección.
- Las solicitudes compartidas piden `Accept-Encoding: identity`, conforme al
  lector que rechaza compresión y conserva sus límites de bytes y tiempo.

La ejecución real acredita Salud Digna en ocho sucursales; **no** acredita una
ejecución nueva de SEMIN, Linfolab o Dr. Simi. Sin suites formales.

## Bloque nuevo separado para evaluación

| Sucursal | Registros válidos, incluida su identidad |
| --- | ---: |
| Municipio Libre | 828 |
| Puebla | 981 |
| Xilotzingo | 982 |
| San Sebastián | 828 |
| El Porvenir | 894 |
| Capu | 976 |
| Angelópolis | 828 |
| Azaleas | 599 |
| **Total** | **6,916** |

Son ocho identidades de sede y 6,908 registros de oferta/precio capturados,
no 6,908 estudios distintos ni ofertas aprobadas. El bloque quedó guardado
localmente, sin importación remota. Se comprobaron los campos de paciente/cita
de todos los registros: sólo placeholders vacíos o cero.

Comparación por tipo e identificador externo contra las capturas históricas de
esas ocho sucursales, 6,923 registros anteriores:

- 16 identificadores añadidos respecto de aquellas capturas.
- 23 identificadores ausentes; no se borró ningún registro vigente.
- 15 diferencias de precio y 32 cambios de contexto clínico/preparación.
- Las 32 diferencias corresponden a cuatro títulos en ocho sucursales: ácido
  valproico, HLA B27, ácido úrico en orina ocasional y MTHFR. No se adoptaron sus
  instrucciones como recomendación clínica ni como prueba de disponibilidad.

En Municipio Libre, 448 grupos pendientes conservan el mismo contexto clínico;
el único cambio de un grupo pendiente fue una preparación de MTHFR que no
aclara su variante genética. La captura no resuelve esa ambigüedad. Las diferencias
de precio quedan para revisión comercial, sin publicación automática.

## Evidencia y siguiente trabajo

`collectors/artifacts/catalog-refresh-20261023/` conserva inventario, memoria,
paginación, huellas, planificación y comparaciones `sd-source-comparison.json`
y `sd-eight-branches-comparison.json`. Las retenciones vencidas vuelven a revisión;
no se renovó artificialmente la fecha de fuentes antiguas.

Capturas completas:

- `salud-digna-refresh-20261023/salud-digna-puebla/be7590fc-c288-4825-9298-c2d3f063cdfe`.
- `salud-digna-refresh-other-branches-20261023/salud-digna-puebla/ad1dd33d-4dca-4239-9105-bab497b3e250`.

Ambas bajo `collectors/artifacts/`, con manifiesto, RAW, observaciones y hashes.
Siguiente acción: evaluar las diferencias antes de ingerir el bloque y contrastar
precios con ofertas aprobadas y sus condiciones; avanzar la conservación de
atributos del motor para los grupos clínicos retenidos. No se reactivó la cola
ni se iniciaron bloques de agentes.
