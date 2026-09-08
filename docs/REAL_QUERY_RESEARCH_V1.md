# Investigación de consultas públicas y benchmark de campo

## Objetivo

Antes de tener Flutter, usamos lenguaje público como fuente de descubrimiento
para ampliar el resolver. No tratamos Reddit como fuente clínica ni como
telemetría de usuarios: sólo extraemos frases cortas que describen un estudio,
una variante de alcance o una intención de búsqueda. El corpus no contiene
usuarios, texto completo de publicaciones, diagnósticos, edades, domicilios ni
otros datos personales.

## Procedencia revisada

La revisión del 29 de agosto de 2026 encontró ejemplos de estudios, dudas de
precio, preparación, disponibilidad y cobertura de varios estudios en estos
hilos públicos:

- [AskMexico: dónde hacer varios estudios](https://www.reddit.com/r/AskMexico/comments/1ocowbs/donde_puedo_hacerme_estos_estudios/): biometría, perfil bioquímico,
  coagulación, teleradiografía y electrocardiograma, además de preguntas de
  cobertura y distancia.
- [r/mexico: costo de estudios para diabetes](https://www.reddit.com/r/mexico/comments/xc2o76/cuanto_cuesta_el_examen_de_diabetes/): glucosa, hemoglobina glicosilada,
  curva de tolerancia, insulina, EGO y preparación.
- [AskMexico: perfil tiroideo](https://www.reddit.com/r/AskMexico/comments/1sckr45/ayuda_me_diagnosticaron_sop/): uso coloquial de “perfil tiroideo” en una
  consulta personal; no se conserva el contexto clínico.
- [MexicoFinanciero: check-up y prevención](https://www.reddit.com/r/MexicoFinanciero/comments/qpkj0v/inversion_en_salud_fisica_y_mental/): biometría, triglicéridos,
  colesterol, HbA1c y resistencia a la insulina como lenguaje de prevención.
- [r/mexico: densitometría ósea](https://www.reddit.com/r/mexico/comments/qqhke0): uso de
  “densitometría” y preguntas de disponibilidad/precio.
- [Guadalajara: espirometría](https://www.reddit.com/r/Guadalajara/comments/14yydbg): nombre
  del estudio y búsqueda de un sitio que lo realice.
- [AyudaMexico: exámenes laborales](https://www.reddit.com/r/ayudamexico/comments/1umvpoc/): audiometría,
  espirometría y antidoping como conjunto de requisitos.
- [Querétaro: densitometría y estudios preventivos](https://www.reddit.com/r/queretaro/comments/1dwuc2o): “densitometría/densidad ósea” y
  estudios preventivos.
- [r/mexico: audiometría](https://www.reddit.com/r/mexico/comments/1ajars7): búsqueda de
  audiometría y auxiliares auditivos.
- [r/mexico: tomografía con contraste](https://www.reddit.com/r/mexico/comments/1hhc6kl):
  consultas sobre tomografía, resonancia y contraste.

Los enlaces son evidencia de lenguaje observado, no una recomendación clínica
ni una garantía de que un proveedor ofrezca un servicio actualmente.

## Artefactos

- `database/fixtures/public_query_research_v1.json`: 64 registros anónimos de
  descubrimiento, clasificados como `resolve`, `panel_review`, `catalog_gap`,
  `extract_intent` o `location_constraint`.
- `database/scripts/build_resolver_benchmark_v2.py`: genera el corpus de campo.
- `database/fixtures/resolver_benchmark_v2.json`: 200 casos nuevos, sin
  consultas normalizadas repetidas del benchmark v1.
- `database/supabase/tests/resolver_benchmark_v2_test.sql`: prueba pgTAP
  reproducible contra `catalog.resolve_items_v6`.

El benchmark v2 contiene 184 variantes de etiquetas completas y 16 consultas que
deben abstenerse: cuatro familias/paneles, ocho nombres incompletos y cuatro
intenciones de precio/ubicación/interpretación. Las variantes de resolución son
normalización-preservante (mayúsculas, acentos, espacios y puntuación), por lo
que no introducen equivalencias clínicas no revisadas.

## Resultado remoto

Las 184 variantes combinan normalización (mayúsculas, acentos, espacios y
puntuación) con aliases semánticos conservadores. Los aliases publicados
preservan explícitamente modalidad, anatomía, protocolo o muestra; no son
equivalencias clínicas inferidas por fuzzy matching.

Después de aplicar las migraciones `104_field_benchmark_constraints`,
`105_field_benchmark_guard_scope` y `106_field_benchmark_aliases`, la prueba
remota pasó las 10 aserciones:

- 200/200 casos presentes.
- 184/184 variantes resueltas al `item_id` esperado.
- 16/16 consultas amplias o de intención se abstienen.
- Las familias COVID y tomografía con contraste no eligen arbitrariamente una
  variante cuando falta el alcance.

La migración 104 también completa los atributos estructurados de contraste para
las variantes de tomografía probadas. La migración 105 evita bloquear un panel
explícito sólo porque contiene las palabras “anticuerpos covid”.

## Cómo repetirlo

Desde `database/`:

```powershell
npx.cmd supabase@2.116.0 db query --linked --file supabase/tests/resolver_benchmark_v2_test.sql
```

Desde la raíz del repositorio, regenerar el fixture y SQL:

```powershell
python database/scripts/build_resolver_benchmark_v2.py --output database/fixtures/resolver_benchmark_v2.json
python database/scripts/render_resolver_benchmark_sql.py --fixture database/fixtures/resolver_benchmark_v2.json --output database/supabase/tests/resolver_benchmark_v2_test.sql
```

## Próximo paso antes de Flutter

El corpus revela dos flujos distintos que no deben mezclarse:

1. Resolver un estudio completo y mostrar ofertas verificadas.
2. Capturar una intención (precio, ubicación, varios estudios, preparación o
   interpretación) y pedir los datos mínimos antes de resolver.

Para probar con usuarios reales se puede exponer temporalmente el endpoint
`/api/v1/resolve` mediante una página web mínima o Postman, con consentimiento
para registrar sólo la consulta normalizada, estado, versión del motor y una
ubicación aproximada. Esa telemetría debe entrar en las tablas de analytics de
una migración posterior, con retención y borrado definidos; los foros no deben
convertirse en un canal automático de publicación de alias.
