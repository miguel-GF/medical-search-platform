# Propuesta acotada: restricción positiva de T3 libre

Fecha: 11-oct-2026. Entorno: proyecto productivo enlazado
`ymtcmfgwuzdqtsbuvzqf`. Estado: **preparada, no aplicada**; fuera de la cola clínica.

## Problema y evidencia

La revisión `pruevia:evidence-review:20261011:02` creó el concepto correcto
`ee4001a7-229d-5b99-bbbf-9c44aca29fe8`, componente `Triiodothyronine.free`, con
muestra/duración desconocidas y alias exacto aprobado `t3 libre`. El resolver
remoto sigue devolviendo cero candidatos porque las tres frases T3 libre,
Triyodotironina libre y Triiodotironina libre tienen un bloqueo universal anterior.
`t3-live-constraints.json`, `t3-live-functions.json` y `t3-live-layer-results.json`
conservan las lecturas reales. La fuente terminológica primaria es
[Mayo Clinic Laboratories, T3 libre](https://www.mayocliniclabs.com/test-catalog/Overview/621815).

El atributo `component` existe en el esquema del lexicón, pero el resolver v1
no lo compara. Una modificación de sólo tres registros no puede añadir una
restricción positiva efectiva con el código actual.

## Cambio propuesto y solución

Draft SQL aislado:
[20261011-free-t3-component-constraint.sql](20261011-free-t3-component-constraint.sql).

Está fuera del directorio de migraciones y del ejecutor de cola. Después de la
aprobación concreta y de revalidar el origen remoto se crearía una nueva migración
operativa desde este draft; no hay una migración pendiente que pueda ejecutarse
por bootstrap o por rutina.

1. Comprobar hash MD5 de la definición remota v1 examinada y ausencia de otros
   lexemas de componente aprobados, para impedir cambios fuera del alcance.
2. Conservar exactamente la función remota `catalog.resolve_items`, añadiendo
   sólo dos ramas: coincidencia de componente y conflicto duro por componente
   distinto/desconocido. `component-function.diff` muestra tres líneas añadidas.
3. Sustituir los tres bloqueos imposibles por `component=Triiodothyronine.free`,
   conservando sus UUID, aprobación, texto original de fuente y auditoría antes/después.
4. Abortar la transacción si los dos exactos revisados no recuperan el concepto
   correcto, o si las tres frases devuelven algún concepto diferente.

No cambia v2–v6, firma, permisos, `search_path`, puntuaciones, preparación,
matriz, duración, mappings LOINC ni publicación. CREATE OR REPLACE conserva
el propietario y las ACL existentes; se debe comprobar esto antes/después de activar.

## Impacto

La búsqueda local de T3 libre podrá recuperar el concepto investigado. Las
restricciones positivas seguirán rechazando T3 total (`Triiodothyronine`) y
T4 libre (`Thyroxine.free`). Los aliases y 82 decisiones ya aplicados permanecen.
La base cambia de forma persistente y los futuros lectores públicos consumirían
la regla después de una reapertura separada. Las superficies públicas continúan
pausadas; no hay despliegue, gasto ni oferta nueva.

## Riesgos y alternativas

- La comparación de componente se vuelve efectiva en v1. El guard exige que no
  existan otras frases aprobadas de ese atributo, para limitar el impacto actual
  a las tres filas. Una aparición futura de otras frases necesita su propia revisión.
- La definición copiada debe coincidir con el origen por hash antes de reemplazarla.
  Si cambió, se vuelve a inspeccionar y se prepara un nuevo diff; no se fuerza.
- El script está vinculado a la identidad revisada existente en esta base. Un
  bootstrap sin ese dato abortará: no se presenta como migración universal de seed.
- Desactivar el bloqueo o reducirlo a `lab_test` recuperaría coincidencias con
  variantes incorrectas por similitud. No es una alternativa clínica aceptable.
- Cambiar únicamente a `component` sin soporte en v1 mantiene `no_match`.
- Posponer conserva el bloqueo seguro, aunque el catálogo siga reconociendo el
  nombre en el reproceso exacto del crawler.

## Ejecución y verificación previstas

Después de la aprobación específica: confirmar proyecto, función/ACL, las tres
filas, catálogo y ofertas; ejecutar primero el mismo SQL con rollback y observar
todas sus aserciones/recibos. Ejecutar commit sólo después de ese resultado y
releer la definición/lexicón/auditoría/ledger. Consultar HTTP localhost para ambos
exactos y las variantes T3 total/T4 libre, conservando resultados e IDs.
Confirmar que muestra y duración del concepto genérico siguen NULL y que no
cambian aliases, decisiones previas, ofertas, permisos ni banderas.

**No se ejecutó el SQL de propuesta ni suites.** Las lecturas de diagnóstico
acreditan la causa, no acreditan todavía el comportamiento corregido.

## Recuperación acotada

[20261011-free-t3-component-constraint.rollback.sql](20261011-free-t3-component-constraint.rollback.sql) restaura la definición remota original v1 y
los tres bloqueos originales bajo guard del hash posterior y de los tres IDs,
con nueva auditoría. No borra conceptos, aliases, decisiones ni auditoría previa.
Si la migración ya quedó registrada, la recuperación debe registrarse como nueva
migración correctiva; no borrar ni reescribir el ledger aplicado. La recuperación
restaura el `no_match` conocido de T3 libre. Si hubo cambios posteriores de función
o lexicón, los guards abortan y exigen revisión del nuevo estado.

## Motivo de aprobación crítica

AGENTS.md, «Autoridad y autonomía», y
`docs/DECISIONS.md#cambios-críticos-y-aprobación` exigen aprobación explícita de
una propuesta que cambia equivalencias clínicas con riesgo de falsos resultados.
Este cambio modifica el filtro clínico común v1 sobre la base productiva; la
autorización de investigar términos claros D-021 no acredita por sí sola aprobar
esta evolución concreta de función. Preparar el diff aislado está permitido.

La decisión pendiente es autorizar **exactamente** el cambio de este draft y
crear/aplicar una nueva migración después de revalidar el origen, con sus
tres lexemas, verificación transaccional y recuperación descritas. Mientras se
resuelve esa decisión se puede continuar investigación y otros lotes independientes.
