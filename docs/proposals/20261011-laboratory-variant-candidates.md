# Diagnóstico: variantes cortas y fragmentos de laboratorio

Corte: 11-oct-2026 local; observaciones de cierre 12-oct-2026, 00:04 UTC.
Entorno: API localhost 8787 contra la base Supabase productiva enlazada.
Estado: diagnóstico de lectura; no contiene una migración activada ni sustituye
las propuestas separadas de T3 libre, AFP-L3, inmunoglobulinas o el diagnóstico C2.

## Evidencia actual

Las revisiones 22–23 resolvieron los 40 aliases/nombres exactos con su primer ID
esperado. Se observaron además consultas sintéticas de vecinos y se inspeccionó
la familia SQL vigente v1–v6. Los siguientes casos conservan candidatos sin
representar una diferencia explícita:

| Consulta | Estado API y candidato | Límite |
| --- | --- | --- |
| `cromogranina b` | `ambiguous`; Cromogranina A, `e9525625-33ca-5a5c-b522-b2629b87433d` | B/A son analitos distintos; la ambigüedad no acredita filtrar el candidato incompatible. |
| `troponina t` | `ambiguous`; Troponina I, `7aacb89d-f6b9-5ad5-a939-0693a88660ea` | T/I son distintas proteínas; no ofrecer I como alternativa equivalente. |
| `osteocalcina n mid` | `resolved`; Osteocalcina genérica, `5ebd776e-0834-5ecc-bfb3-1a8ee3912497` | Identifica el analito general sin representar el fragmento/ensayo solicitado. No acredita equivalencia de resultados. |
| `proteina c reactiva cualitativa` | `ambiguous`; incluye las variantes cuantitativa y ultrasensible | El estado no demuestra que la escala o sensibilidad sean compatibles. |
| `apolipoproteina b48` | `ambiguous`; incluye candidatos generales de apolipoproteínas | La isoforma explícita no queda acreditada por ese conjunto de sugerencias. |

Para los tres primeros casos el candidato general sobrevive a las seis etapas;
ninguna frase aprobada del lexicon coincide. No se añadió una equivalencia para
los vecinos ni se modificó el algoritmo SQL al cargar el catálogo.

El diagnóstico previo C2 mostró una limitación análoga con el momento posdosis.
No significa automáticamente que se trate de otro fármaco o que todos los
ensayos de osteocalcina sean incompatibles: indica que Pruevia no representa ni
verifica todavía el calificador explícito. El dato no puede heredarse desde una
ficha extranjera cuyo método sí detecte esos fragmentos.

## Interpretación técnica y clínica

El ranking léxico puede retener un nombre general aunque el texto añada un
calificador. Los guards actuales no modelan estas variantes en el lexicon.
Las etapas v2/v3 descartan tokens cortos en partes del guard léxico; I/T y A/B
necesitan tratamiento dentro de su familia clínica, conservando su significado.
La ausencia de conflicto reconocido no prueba igualdad clínica.

Referencias primarias para la distinción:

- [MedlinePlus, troponina](https://medlineplus.gov/lab-tests/troponin-test/):
  identifica troponinas I y T por separado.
- [Mayo, cromogranina A](https://www.mayocliniclabs.com/test-catalog/overview/34641):
  identidad de A; no acredita B para el RAW local.
- [Mayo, osteocalcina](https://www.mayocliniclabs.com/test-catalog/overview/80579):
  su ensayo incluye intacta/N-MID; no se importó ese método a Pruevia.
- [Labcorp, CRP cuantitativa](https://www.labcorp.com/tests/006627/c-reactive-protein-crp-quantitative)
  y [Mayo, hs-CRP](https://www.mayocliniclabs.com/test-catalog/overview/606909):
  referencias individuales de variantes conservadas separadamente.

## Observaciones tras revisiones 27–29 — 12-oct-2026

Las 30 consultas exactas de estas revisiones devolvieron el primer ID esperado,
pero dos vecinos explícitos conservan candidatos incompatibles bajo `ambiguous`:

| Consulta sintética | Candidato observado | ID / alcance |
| --- | --- | --- |
| `anticuerpos anti scl 70 igm` | Anticuerpos anti-Scl-70 IgG | `fec0a9ac-b1e1-5f06-aedb-fa8d1411578e`, IgG explícita en componente `Scl-70 IgG antibody` |
| `anticuerpos contra receptor gaba a en suero` | Anticuerpos contra receptor GABA-B en suero | `b883b440-8207-5719-bcfa-e4e09a79759c`, receptor B explícito en componente y RAW |

No hubo selección automática u ofertas en esas respuestas. El estado ambiguo
no acredita excluir el conflicto IgM/IgG o receptor A/B. Las propuestas se
guardaron en `clinical-research/review-27/outside-scope-resolver.json` y
`review-28/outside-scope-resolver.json`, bajo el directorio local Puebla.
Músculo liso siguió resolviendo al canónico previo, distinto del estriado nuevo;
actividad de fosfolipasa A2 dio `no_match` sin candidatos. Esos casos no prueban
todas las variantes. IA2 beta también dio `no_match` con una propuesta DNasa B
irrelevante, documentada en la respuesta íntegra; no se aprobó esa equivalencia.

Los catorce componentes añadidos exigen revalidar el alcance de la propuesta
conjunta. El diff anterior de inmunoglobulinas describe sus 25 elegibles en su
corte; no afirmar que protege el nuevo Scl-70 ni todos los receptores. Resolver
v1 sigue con MD5 `067b7a2fe0826ccaa48ece0a5dfd8d1d`, sin cambios activados.

## Observación adicional después de32 corregida/33 — 13-oct-2026

Se observaron 33/33 exactos públicos y3/3 aliases internos con proveedor al ID
esperado. Esto no prueba variantes fuera de esas consultas. Respuestas completas
en `clinical-research/review-32-revised/outside-scope-resolver.json` y
`review-33/outside-scope-resolver.json`, bajo el artefacto Puebla vigente.

- `clostridium difficile toxina b` y `clostridium difficile pcr`: no_match con
  candidato conjunto A+B `cdea5fe2-9639-5b49-9738-c524b37c4642`. No es equivalente
  a B sola o gen/PCR; la abstención no elimina ese candidato de la respuesta.
- `antigeno e hepatitis b`: ambiguous con HBeAg
  `4dc09a38-731a-5887-a434-abcffe0b608e`, HBsAg
  `dcb710ec-6bb2-5d97-ae3a-631a5bfa227a`, anti-HBe
  `cb4f532e-7972-57e5-9f48-20469a665b7d` y anti-HBs
  `a16d546a-64d8-5ba9-8d8a-21e2e39a8e54`. Conservar e/s y antígeno/anticuerpo
  cuando una futura corrección clínica revise tokens y atributos.
- `anticuerpos mog igg`: ambiguous con MOG genérico
  `6620d628-be01-5a62-a7c9-3b63426210d9` y candidatos IHQ/otras dianas. No afirmar
  que ese genérico acredita IgG o que la lista completa es clínicamente compatible.
- Reticulina/ASCA IgM, ANCA PR3, ANA panel ENA y citología mamaria izquierda no
  resolvieron. No se añadieron sus calificadores al canónico para forzar búsqueda.

Se añadieron cuatro componentes con clase escrita y familias sin clase;
revalidar el alcance del diff antiguo de25elegibles y la propuesta conjunta
antes de cualquier activación. MD5v1 sigue `067b7a2fe0826ccaa48ece0a5dfd8d1d`.
Sin cambios del resolver clínico o suites formales en este corte.

## Alcance de una corrección pendiente

Preparar un filtro con reglas por familia y calificadores explícitos, separado
del ranking. Debe excluir variantes demostrablemente distintas y abstenerse
cuando un candidato general no acredita fragmento, fracción o momento. No
eliminar componentes del catálogo ni inventar nuevos mappings por ese filtro.

Antes de proponer activación debe conservar:

1. Casos exactos actuales y todos los atributos originales.
2. Casos vecinos A/B, I/T, inmunoglobulinas, AFP-L3, libre/total, fragmentos y C2.
3. Reglas clínicas versionadas, alcance e IDs/atributos comprobados.
4. Función anterior, hash, diff aislado, compatibilidad, verificación y recuperación.

La implementación de una corrección compartida requiere el procedimiento de
cambio crítico de [D-006](../DECISIONS.md). Aquí sólo se registró el diagnóstico;
no se activaron filtros o prioridades nuevos, ni se ejecutaron suites.

## Artefactos y continuidad

Directorio local ignorado:
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-22/`:
`outside-scope-resolver.json`, `read_variant_diagnostic.py`,
`variant-diagnostic.json`, `variant-resolver-definitions.json`.
Los vecinos de CRP/apolipoproteínas están en el `outside-scope-resolver.json`
de `review-23`. Las respuestas guardan consulta original y candidatos; no son
órdenes de pacientes. El MD5 de `catalog.resolve_items(text,text,uuid,integer)`
continúa `067b7a2fe0826ccaa48ece0a5dfd8d1d`.

Siguiente acción: preparar una propuesta clínica conjunta coherente con los
diffs existentes y observar recetas/cobertura, además de continuar el catálogo.
