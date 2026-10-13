# Propuesta: excluir candidatos con inmunoglobulina incompatible

Fecha: 11-oct-2026. Estado: **diff exacto y recuperación preparados; no ejecutados ni activados**.
Entorno: API local `127.0.0.1:8787`, conectada al proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`. La publicación pública continúa pausada.

## Problema y evidencia

La consulta literal `anticuerpos antiendomisio igg` responde HTTP `200`, motor
`clinical-resolver-v6`, estado `ambiguous`. Entre sus candidatos aparece
**Anticuerpos antiendomisio IgA**, ID
`acd5b4eb-8d9d-5e17-88b8-8f7eaa568138`, `word_fuzzy`, confianza `0.923077`.
El estado público exige aclaración; no hay selección automática ni ofertas.
Sin embargo, permite presentar un estudio con inmunoglobulina explícitamente
incompatible con la solicitada. Elegir ese candidato podría sustituir la identidad
de la orden. La puntuación lexical no acredita equivalencia clínica.

El concepto revisado conserva `Endomysium IgA antibody` como componente y sus
aliases explícitos IgA. La identificación IgA está respaldada también por el
[catálogo primario de Mayo, EMA](https://www.mayocliniclabs.com/test-catalog/Overview/9360).
Esa referencia no autoriza trasladar su muestra o método al concepto local.

Después de las revisiones 19–20, la consulta sintética `anticuerpos toxoplasma
iga` también devuelve `ambiguous`: primero propone **Anticuerpos anti-Toxoplasma
IgG**, ID `d6a57042-fd36-5115-b38c-4b370ea0e48f`, `word_fuzzy`, confianza
`0.892857`; después el concepto IgA anterior `3f15837c-8dde-5f0c-8227-6f7effa5b009`.
La clase IgG del primer candidato está explícita en su componente revisado
`Toxoplasma Ab.IgG`; no debe sustituir IgA. No hubo selección automática ni oferta.
La [referencia Mayo TXMGP](https://www.mayocliniclabs.com/test-catalog/overview/802127)
distingue resultados IgG/IgM y no autoriza convertirlos en IgA. Respuesta completa
fechada: `clinical-research/review-20/outside-scope-resolver.json`, bajo el mismo
directorio raíz de artefactos citado abajo. Es otra dirección del conflicto
IgA/IgG, no una prueba de que todas las variantes estén protegidas.

En ese mismo recibo, nueve variantes dan `no_match`, pero algunas aún incluyen
candidatos IgG/IgM incompatibles como propuestas diagnósticas. El estado final
no demuestra que la lista de candidatos haya sido filtrada clínicamente.

Evidencia reproducible, sin datos de pacientes ni secretos, en
[`review-14`](../../collectors/artifacts/puebla-expansion-20261009/clinical-research/review-14/):

- `antibody-variant-http.json`: textos y respuestas HTTP completas con fecha UTC.
- `antibody-variant-functions.json`: definiciones remotas vigentes de v1–v6.
- `antibody-variant-stages.json`: persistencia del candidato IgA por cada capa SQL.
- `antibody-variant-concept.json`: identidad, atributos y aliases guardados;
  entradas aprobadas del léxico aplicables a la consulta.
- `read_variant_diagnostic.py`: consultas de lectura y solicitudes HTTP del diagnóstico.

## Causa confirmada y alcance

1. `catalog.resolve_items` calcula la similitud lexical sin detectar la oposición
   IgG/IgA: para este candidato informa `hard_conflict=false`, `attribute_count=0`.
2. Los filtros de v2/v3 sólo consideran palabras de longitud >=4. Omiten `igg`;
   registran dos palabras significativas y dos coincidencias. Por ello el candidato
   IgA pasa el requisito de completar las palabras significativas.
3. v5 limita coincidencias `exact`/`alias` con texto adicional, pero deja pasar
   `word_fuzzy`. v6 conserva las propuestas sin coincidencia exacta; la API
   presenta el estado `ambiguous`. El candidato sigue presente en todas las capas.

Este diagnóstico demuestra la contradicción **IgG frente a IgA**. La respuesta de
`anticuerpos anti ssa ro52` es `ambiguous` con la familia SSA/Ro. Para
`anticuerpos antimitocondriales m2`, también aparece la familia AMA bajo
`ambiguous`; otras grafías, como `AMA m2` y `anticuerpos anti mitocondriales m2`,
dan `no_match`. Las identidades familiares revisadas no afirman Ro52 o M2;
requieren aclaración y esa falta de subfracción no se clasifica aquí como fallo.
No se propone inferir Ro52/Ro60, M2, inmunoglobulinas o métodos ausentes.

## Solución candidata acotada

Se preparó un diff aislado y revisable que agrega al filtro clínico compartido
un conflicto positivo entre inmunoglobulinas explícitas. Su activación requerirá
aprobación específica y una **nueva migración**:

- Reconocer tokens completos `IgA`, `IgG`, `IgM`, `IgE`, `IgD` en la consulta,
  con comparación exacta normalizada, sin fuzzy ni equivalencia por prefijo.
- Obtener la clase del candidato de su componente clínico revisado, limitado a
  identidades individuales de anticuerpos con una sola clase explícita. El caso
  demostrado tiene `Endomysium IgA antibody`; no usar descripciones comerciales
  libres como autoridad. Inventariar primero los componentes afectados.
- Si consulta y candidato declaran una sola clase y difieren, excluir ese
  candidato **antes de ordenar, limitar y decidir el estado**, cualquiera que sea
  su puntuación o método lexical. La misma regla debe regir las rutas públicas
  que consumen candidatos; no basta ocultarlo en una pantalla.
- Mantener como desconocida una clase ausente. No convertir una familia o un
  panel en estudio de una clase; no aplicar la comparación simple a paneles
  multiclase, subclases IgG1–4 ni texto con múltiples clases sin revisión adicional.
- Conservar nombres, aliases, atributos y decisiones de la revisión 14. No crear
  antiendomisio IgG por inferencia. Excluir IgA no garantiza resolver IgG: otros
  candidatos desconocidos pueden mantener la respuesta ambigua.

El diff se concentra en `hard_conflict` de `catalog.resolve_items`, antes de
`accepted`, orden y límite, sin modificar cláusulas clínicas existentes,
contratos, permisos ni v2–v6. El inventario remoto contiene **25 componentes
elegibles**, todos con revisión de concepto registrada, individuales, sin hijos
y con una clase IgA/IgG/IgM explícita. No hay componentes IgE/IgD elegibles actuales;
reconocer esos tokens no crea identidades. Se compara el componente canónico que
contiene `Ab`, `antibody` o `antibodies`; no nombres comerciales ni confianza fuzzy.
Componentes con clases múltiples, subclases o tokens de panel quedan fuera.

El rol `service_role` no tiene `USAGE` de `audit` ni `SELECT` de `audit.events`.
Por ello el cuerpo propuesto no consulta auditoría al resolver; la lectura de
evidencia pertenece a la preparación y a los guards de la operación autorizada.
No se amplían permisos. La autoridad futura sigue siendo el componente clínico
canónico publicado mediante revisión, no una inferencia del resolver.

Preparación observada **11-oct-2026, 20:21:08 UTC**, con definición remota revalidada:

- [SQL aislado de activación](20261011-antibody-variant-candidates.sql) y
  [SQL de recuperación](20261011-antibody-variant-candidates.rollback.sql).
- MD5 actual: `067b7a2fe0826ccaa48ece0a5dfd8d1d`;
  MD5 esperado del borrador: `999a96985e1f847b51f5c685cfb80c35`.
- SHA-256 de activación: `ed022b3c4b8c2a7bcecc0d4673d8589175ebfbc96868dd103d87fc68c7248c3c`.
- SHA-256 de recuperación: `3d722f45350081d7cf99113b47d6a9ed51d5104e5edf200b7935964c486e98f5`.
- Artefactos bajo `clinical-research/antibody-filter-draft/`: `function.diff`,
  `component-inventory.json`, `resolver-definitions.json`, `sql-consumers.json`,
  `public-consumer-definitions.json`, `runtime-read-permissions.json` y
  `draft-prepared.json`.

Ambos SQL usan transacción, locks acotados, advisory lock común, guards del hash
y auditoría. Activación protege además los dos ejemplos demostrados;
recuperación restaura el original sólo desde el hash introducido. Se conservan
firma, estabilidad y configuración de la función. No se ejecutaron los scripts;
no están en migraciones ni en la cola. T3 libre y AFP-L3 parten del mismo hash
original: activar una propuesta obliga a revalidar y rehacer los otros diffs.

Las definiciones identificaron consumidores de v6 en búsqueda y resolución
individual/paquetes y de v3 en resolución v2; las envolturas públicas de búsqueda,
paquetes y OCR consumen esa cadena. Esto acredita dependencias SQL vigentes,
no comportamiento posterior a una activación inexistente. La
[referencia MedlinePlus de inmunoglobulinas](https://medlineplus.gov/lab-tests/immunoglobulins-blood-test/)
distingue las clases; no autoriza convertir Ig total en anticuerpos específicos
contra un antígeno ni inferir muestra o método.

## Impacto, riesgos y alternativas

Impacto esperado: impedir presentar una clase conocida incompatible como candidata
de una orden con clase explícita. No acredita cobertura comercial ni interpreta
resultados clínicos. No requiere servicios externos ni costos nuevos.

Riesgos: componentes antiguos incompletos, nombres con clases múltiples,
subclases, errores OCR o abreviaturas podrían perder propuestas útiles si se usa
un parser amplio. Limitarlo a contradicciones positivas simples y revisar el
inventario evita tratar desconocimiento como incompatibilidad. El estado público
debe calcularse sobre los candidatos restantes; preservar las restricciones de
muestra, método y composición sigue siendo necesario.

Alternativas: una regla específica para el ID IgA reduce el alcance inmediato,
pero deja el mismo error para otras clases. Bajar globalmente la longitud a tres
letras modifica muchas búsquedas y todavía admite comparaciones aproximadas entre
tokens; no ofrece por sí solo protección clínica. Posponer conserva el candidato
incompatible bajo `ambiguous`; debe permanecer documentado como limitación.

## Verificación prevista y recuperación

No se ejecutaron suites ni se cambiaron funciones durante diagnóstico/preparación.
Se revalidaron proyecto, función/hash, componentes, consumidores y permisos por
lecturas remotas, y se guardaron original y recuperación. Antes de activar:
revalidar estos hechos y preparar la nueva migración desde el diff autorizado.
Después de autorizar, comprobar con el runner contractual que conserva todas las
aserciones y con lecturas HTTP del entorno correspondiente:

- IgG explícito no presenta el ID IgA demostrado; IgA explícito conserva ese ID.
- Las 21 consultas exactas de la revisión 14 conservan su identidad esperada.
- Casos individuales de otras clases sólo se usan si tienen evidencia revisada.
- Clases desconocidas, paneles y subclases no se resuelven por inferencia; Ro52/M2
  siguen requiriendo aclaración.
- Búsqueda, resolución individual/lista y OCR conservan el mismo filtro y las
  restricciones existentes; ninguna oferta, permiso o publicación se altera.

Aplicar transaccionalmente después de las comprobaciones aprobadas. Recuperar
mediante una nueva migración correctiva que restaure la función original, sólo si
el hash desplegado coincide con la versión introducida; conservar auditoría y ledger.
Si hay cambios concurrentes, detener la recuperación y preparar un diff revisado.
El rollback devolvería la limitación IgG/IgA anterior; no borra el catálogo revisado.

## Autorización necesaria

[AGENTS](../../AGENTS.md) y
[DECISIONS: cambios críticos](../DECISIONS.md#cambios-críticos-y-aprobación)
exigen aprobación específica antes de activar cambios que afectan equivalencias
clínicas. D-021/D-022 permiten esta investigación y las identidades claras ya
revisadas; no sustituyen la aprobación del nuevo filtro común. La decisión pendiente
es autorizar el alcance de contradicciones positivas simples descrito arriba y su
diff exacto enlazado, con verificación y recuperación. La preparación está
terminada y es revisable; falta esa autorización específica para activar.
Esta propuesta no activa cambios.
