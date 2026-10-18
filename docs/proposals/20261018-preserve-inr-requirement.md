# Conservar INR al resolver una orden — propuesta D006

Estado: **preparada, sin ejecutar ni aprobar**.18-oct-2026 UTC.

## Cambio y justificación

Las revisiones59 y60 observaron en transacciones terminadas conrollback que
«tiempo de protrombina con INR» y «tiempo parcial de tromboplastina con INR»
pueden resolverse como el estudio simple recién propuesto. Los RAW no prueban
que incluyan INR. Ambos borradores quedaron fuera de cola y sin aplicar.

Se leyó la definición real de`catalog.resolve_items_v3`: su comprobación de
palabras significativas sólo cuenta tokens de cuatro caracteres o más. **INR
tiene tres**, por lo que esa condición no exige conservarlo. Este hallazgo
explica los dos casos observados; no demuestra que sea la única vía del problema.

Propuesta acotada: cuando la consulta contiene el token literalINR, exigir que
también aparezca en el término que produjo el candidato antes de aceptarlo.
El resto de condiciones existentes permanece dentro de un paréntesis para que
la condición adicional se aplique a todas las ramas de aceptación de esta capa.

Diff preparado contra la función realmente leída:

```diff
 ), accepted as (
   select g.*
   from guarded g
-  where g.match_method in ('exact','alias','disambiguation')
-     or (g.meaningful_token_count > 0 and g.meaningful_token_matches = g.meaningful_token_count)
+  where (
+    g.match_method in ('exact','alias','disambiguation')
+    or (g.meaningful_token_count > 0 and g.meaningful_token_matches = g.meaningful_token_count)
+  )
+  and (
+    not ('inr' = any(string_to_array(core.normalized_text(p_query), ' ')))
+    or 'inr' = any(string_to_array(core.normalized_text(g.matched_term), ' '))
+  )
 ), ranked as (
```

## Impacto y límites

Es un cambio compartido de resolución clínica, sujeto a aprobación explícita
segúnD006 de[DECISIONS](../DECISIONS.md). No se ha instalado una función nueva,
ejecutado la propuesta, creado una migración aplicada ni publicado el borrador.
Preparar este diff no acredita que ya corrija los recorridos completos.

Puede reducir candidatos legítimos cuyo término no contenga literalmenteINR,
por ejemplo si está escrito comoIIN o «índice internacional normalizado».
La propuesta inicial es deliberadamente explícita sobre esta limitación: debe
investigarse la equivalencia nominal y su representación antes de activar.
Tampoco cubreI.N.R., abreviaturas separadas por puntuación, INR en otra capa,
mezclas, escalas, proporciones invertidas ni protocolos especializados.
No cambia permisos, esquema, ofertas, muestras o precios; no amplía equivalencias.

Alternativas: mantener TP/TPT retenidos mientras se investiga; ampliar el léxico
de atributos con evidencia y conflictos; o introducir un contrato más general
de requisitos de la orden. Bajar globalmente el mínimo de cuatro caracteres
tendría un alcance mayor que el problema investigado y no está propuesto aquí.

## Verificación pendiente antes de pedir activación

1. Confirmar nombres equivalentes deINR y qué evidencia puede satisfacerlos.
2. Reconciliar este cambio con las propuestas de paneles, imagen, escalas yA/G.
3. Observar el diff en un entorno aislado, preservando todas las aserciones del
   runnerSQL existente cuando se autorice verificarlo. Esta sesión no corrió suites.
4. Comprobar consultas nominales, variantes deINR, identificadoresLOINC,
   aliases por proveedor y rutas públicas/crawler; no sólo los dos casos encontrados.
5. Preparar nueva migración con precondición de definición y recuperación exacta;
   volver a observar los lotes59/60 antes de decidir si pueden aplicarse.

Sólo entonces solicitar la aprobación concreta de activación requerida porD006.
El objetivo general sigue activo y permite investigar otros grupos y proveedores.

## Evidencia y recuperación

Artefactos privados del workspace bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/`:

- `review-60-tpt-20261018/`: definición,RAW, fuentes reutilizadas con fecha original,
  observación rollback y lectura independiente de cierre.
- `proposal-inr-guard-20261018/`: definición original real, SQLpropuesto,
  diff, SQLde recuperación y recibo con hashes. Ninguno fue ejecutado.

Lectura independiente de cierre:74RAW completos intactos, ambos ledgers
`not_applied`, funciónv3 idéntica a la capturada;550 conceptos,4,082 pendientes,
133 instituciones,217 ubicaciones,234 ofertas y112 migraciones.
No se necesita recuperación ahora porque no se activó el cambio. Si se autoriza
más adelante, guardar de nuevo la definición inmediatamente anterior y evitar
restaurar una captura vieja sobre cambios concurrentes.
