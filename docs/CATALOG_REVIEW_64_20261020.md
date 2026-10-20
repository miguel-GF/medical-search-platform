# Revisión 64: calcio ionizado sérico y PlGF individual

Aplicación: 19-oct-2026, 13:19 UTC. Observación independiente: 13:20 UTC.
Relectura productiva: **20-oct, 12:59:09 UTC**, ledger aplicado y mismo hash.
Herramientas locales contra la base productiva enlazada; no nuevo despliegue.

## Qué se incorporó

| Etiqueta de origen | Decisión | Alcance conservado |
| --- | --- | --- |
| Calcio Ionizado, SEMIN 5401 | Calcio ionizado en suero | Muestra literal `2 ml Suero. Refrigerado`; fracción ionizada. |
| FACTOR DE CRECIMIENTO PLACENTARIO HUMANO, Chopo 19884 | Factor de crecimiento placentario humano (PlGF) | Analito individual; muestra, método y duración desconocidos. |

Dos conceptos nuevos y dos aliases limitados al proveedor cerraron **dos registros**.
No se importó técnica ISE desde otro laboratorio, ajuste de pH, calcio calculado,
equivalencia con calcio total o muestra urinaria. El texto de PlGF menciona uso
conjunto con sFlt-1; eso no demuestra que esta orden incluya el cociente o panel.
No se creó alias global PIGF desde la grafía del proveedor.

### Fuentes primarias

- [Ficha SEMIN 5401](https://semindigital.com/semin-api/api/v3/catalog/informacion-catalogo/5401):
  identidad y muestra explícitas; HTTP 200 el 19-oct.
- [Labcorp, calcio ionizado](https://www.labcorp.com/tests/004804/calcium-ionized):
  identidad del analito; no se transfirió su protocolo a SEMIN.
- [Chopo Puebla, factor placentario](https://www.chopo.com.mx/puebla/factor-de-crecimiento-placentario-humano):
  título y descripción del factor individual; HTTP 200 el 19-oct.

La investigación conserva RAW del 13-sep y capturas primarias del 19-oct con
sus fechas distintas. Las variaciones de precio observadas en la ficha SEMIN
no se ingirieron ni se publicaron como parte de esta revisión.

## Qué permanece retenido

- Ocho RAW de nicotina sérica: falta definición primaria accesible de composición;
  no convertir nicotina a cotinina o panel de metabolitos.
- Talio en sangre: conservar familia sanguínea sin inventar fracción sérica,
  plasmática o sangre completa; la representación canónica necesita revisión.
- Cortisol salival, TP/TPT y propuestas previas de requisitos cortos siguen fuera
  de cola cuando corresponda; este lote no activa cambios del resolvedor.

## Observaciones y límites

La lectura fresca confirmó los 11 contextos elegidos todavía abiertos, íntegros,
y una fila histórica adicional fuera de alcance. La observación en rollback
incluyó 19 consultas públicas y 16 contextos directos del core v6 con/sin proveedor.
Los nombres canónicos exactos se resolvieron; las variantes de pH, AM y x2
examinadas conservaron ambigüedad. Cociente sFlt-1/PlGF, calcio total y otros
contextos incompatibles no se aprobaron como los conceptos nuevos.

Esto no prueba conservación universal de calificadores. Algunos candidatos
ambiguos aún muestran el concepto individual: no son cobertura confirmada ni
equivalencia analítica. La etiqueta pública sin muestra puede requerir aclaración;
el alias del proveedor usa su contexto RAW explícito.

El primer rollback se rechazó por falta del principal local que exige el RPC;
la lectura posterior confirmó ledger vacío y contadores intactos. Se corrigió
la configuración de sesión usando el mismo principal del runner existente,
sin alterar permisos. Una observación de la API usó su quinto argumento como
si fuera proveedor; ese argumento es ubicación. No se acreditó alcance de
proveedor con ella: se realizó otra observación directa de `resolve_items_v6`.

La fixture definitiva sólo cambia atribución, notas y alcance respecto del
borrador observado. El runner ordinario volvió a ejecutar su preview y después
commit, con sus aserciones completas de contexto, alcance y publicación.
La cola creció de 53 a 54 entradas, conservando los hashes anteriores.

## Resultado independiente

Dos decisiones seleccionan los IDs previstos con guards y atributos correctos.
Los 12 contextos observados y los payloads completos de los dos RAW seleccionados
quedaron íntegros; estados ajenos, fuentes y políticas sin cambios. Definiciones
sin método, escala o LOINC inferidos. Cero ofertas nuevas y 112 migraciones.
No se ejecutaron suites formales.

| Estado confirmado el 20-oct | Total |
| --- | ---: |
| Conceptos activos distintos | 553 |
| Registros resueltos favorablemente | 3,317 |
| Pendientes abiertos | 4,071 |
| Históricos no_match fuera de cola | 946 |
| Instituciones / ubicaciones | 174 / 258 |
| Ofertas activas | 234 |

Las ubicaciones incluyen candidatas pendientes; no equivalen a disponibilidad
comercial. El proceso local de cola observado vivo es PID 16372, en vigilancia
con 54 revisiones ya aplicadas; no se reinició en esta relectura.

Fixture: `database/data/reviewed-aliases-20261019-02.json`.
SHA256: `c0eabd4d374cdaaeb68b7d4f7bef4146eb738c1c42ee334783f5ee1b616a6296`.
Evidencia en `collectors/artifacts/puebla-expansion-20261009/clinical-research/review-64-discovery-20261019/`:
fuentes, contexto fresco, rollback, observaciones por alcance, cola, lectura
independiente `applied-verified.json` y `applied-reobserved-20261020.json`.
Recibos del ejecutor en `collectors/artifacts/local-review-queue/pruevia-evidence-review-20261019-02/`.

Siguiente acción: investigar grupos de mayor volumen conservando especie,
isotipo y método, y ampliar evidencia comercial de proveedores pequeños.
