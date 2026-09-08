# Benchmark del resolver V1

El corpus `database/fixtures/resolver_benchmark_v1.json` contiene 200
consultas revisadas para el buscador de Pruevia. No es una lista de aliases
publicables: cada caso expresa una política esperada y sirve para detectar
regresiones del motor.

## Composición

- 147 variantes seguras que deben resolver a un único `catalog.item`:
  laboratorios, BH/EGO, glucosa, creatinina, TSH, T4 libre, T3, EMG con
  anatomía y estudios de imagen con región/modalidad/contraste conservados.
- 18 consultas de química sanguínea y perfiles tiroideos cuya composición es
  dependiente del proveedor y deben permanecer ambiguas.
- 20 consultas incompletas (por ejemplo `EMG`, `T3 libre`, `TAC` o `RM`) que
  no deben adivinar anatomía, espécimen, lateralidad o variante.
- 15 entradas irrelevantes o adversariales que deben devolver `no_match`.

Las fuentes son los ejemplos de recetas/OCR aportados para Pruevia, las
pruebas Gate B existentes, los catálogos observados de Ruiz/Chopo/Salud Digna,
el discovery genérico de Puebla y los ocho mappings LOINC 2.83 aprobados.

## Política de resolución

Una variante segura sólo es válida si conserva el alcance clínico del concepto
revisado. La búsqueda fuzzy únicamente propone candidatos. Los paneles no se
equiparan por nombre y los conflictos explícitos se rechazan. En particular,
`T3 libre` no puede convertirse en T4 libre ni en el mapping de T3 total.

La dominancia exacta evita que una coincidencia literal sea degradada por
variantes cercanas: `electrocardiograma en reposo` y `mastografia` resuelven su
item literal, mientras que una consulta sin región o sin contraste continúa
absteniéndose cuando no existe un concepto único.

## Reproducir

Regenerar el fixture y la prueba SQL:

```powershell
python database/scripts/build_resolver_benchmark.py `
  --output database/fixtures/resolver_benchmark_v1.json
python database/scripts/render_resolver_benchmark_sql.py `
  --fixture database/fixtures/resolver_benchmark_v1.json `
  --output database/supabase/tests/resolver_benchmark_test.sql
```

Ejecutar contra Supabase DEV enlazado:

```powershell
$path = (Resolve-Path database/supabase/tests/resolver_benchmark_test.sql).Path
npx supabase@2.116.0 db query --linked --file $path
```

El gate exige 10 aserciones pgTAP, incluyendo 200/200 casos conformes,
147/147 variantes seguras con el item esperado, abstención segura de los 53
casos no resolubles y `no_match` para los 15 negativos.

## Cambios de datos relacionados

La migración `20260829110000_101_resolver_benchmark_hardening.sql` publicó
aliases conservadores y dominancia exacta. Las migraciones `102` y `103`
añadieron conflictos de analitos y atributos estructurados de imagen. Los
aliases permanecen versionados, con evidencia y sujetos a revisión; no se
publican automáticamente a partir de texto fuzzy, vectores o IA.
