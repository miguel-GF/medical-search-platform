# Propuesta: impedir que AFP-L3 se sustituya por AFP genérica

Fecha: 11-oct-2026. **Diff aislado preparado; no aplicado.** Proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`; HTTP observado en API local `127.0.0.1:8787`.
La publicación pública sigue pausada por D-020.

## Cambio y motivo

La consulta sintética literal `alfa fetoproteina l3` devuelve HTTP200, v6,
`resolved`, con AFP genérica `4c0a6be9-12b9-5f25-ac02-d476daee48ea`, método
`word_fuzzy`, confianza `0.857143`, sin ofertas. No es sólo un candidato ambiguo:
la identidad final pierde la variante solicitada. Las 23 consultas exactas del
lote 18 funcionan, pero eso no acredita preservar AFP-L3.

[Mayo: AFP-L3% y AFP total](https://www.mayocliniclabs.com/test-catalog/overview/88878)
documenta resultados distintos y advierte que su otra prueba AFP genérica no
sirve para utilizarla con los valores AFP-L3. La orden fuente `ALFA FETOPROTEINA
--AFP--` no menciona L3; no autoriza sustituirla. No se crea AFP-L3 por inferencia.
Descarga nativa403 conservada; lectura web de la fuente primaria lograda.

El [diff SQL](20261011-afp-l3-candidate-conflict.sql) añade a `hard_conflict` de
`catalog.resolve_items` una contradicción positiva: candidato con componente
exacto revisado `Alpha-fetoprotein`, consulta que explicita familia AFP y token
completo `l3` o `l 3`. Reconoce AFP, alfa fetoproteína y alpha fetoprotein con
normalización existente; no fuzzy para la fracción. El candidato se excluye antes
de ordenar y limitar, preservando el resto de restricciones y v2–v6.

El filtro no resuelve AFP-L3, no interpreta resultados ni cambia catálogo,
aliases, decisiones, permisos, oferta, precio o flags de publicación. No aplica
a otros componentes, paneles, porcentajes o variantes por parecido textual.

## Evidencia, impacto y riesgos

`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-18/`:

- `outside-scope-resolver.json`: respuesta HTTP actual completa y fecha.
- `afp-l3-stages.json`: candidato genérico conservado en todas las capas v1–v6.
- `afp-l3-resolver-definitions.json`: definiciones, propietario, ACL, configuración
  y hashes originales. V1 MD5 `067b7a2fe0826ccaa48ece0a5dfd8d1d`.
- `afp-l3-target.json`: único componente AFP genérico vigente, matriz/duración NULL.
- `afp-l3-function.diff`: cambio acotado del cuerpo SQL.
- `afp-l3-proposal-prepared.json` y `afp-l3-source-receipt.json`: hashes y alcance.

Impacto esperado: una orden explícita AFP-L3 ya no puede seleccionar AFP genérica
por esta ruta. Riesgos: grafías OCR distintas de las previstas o nuevos componentes
podrían quedar fuera del filtro; el alcance no pretende proteger todas las
variantes. El estado final puede seguir siendo ambiguo con candidatos desconocidos.
El bloqueo existente T3 libre y la incompatibilidad IgG/IgA requieren sus propias
propuestas. No se confirma cobertura clínica por excluir un candidato.

Alternativas: bajar globalmente el mínimo de palabras significativas cambia
muchas búsquedas y no prueba identidad de fracción. Dar AFP-L3 como alias de AFP
es incompatible con la evidencia. Posponer mantiene el falso `resolved` observado.
No hay costo, infraestructura, publicación o contacto externo nuevo.

## Verificación y recuperación previstas

No se ejecutó el diff, un ensayo de ese diff ni suites. Tras autorización explícita,
revalidar proyecto, hashes, dependencias/consumidores y alcance. Preparar una nueva
migración; conservar esta propuesta fuera del directorio automático y la cola.
T3 libre e inmunoglobulinas comparten v1: cualquier cambio previo exige rebase y
revisión del diff, no ejecutar borradores sucesivamente con hashes obsoletos.

La verificación autorizada debe comprobar con el runner contractual completo y
con HTTP que AFP-L3/AFP L3%/alfa fetoproteína L3 ya no seleccionan el ID genérico,
que AFP genérica y las 43 consultas de los lotes17–18 conservan sus identidades,
y que composición, muestra, fracciones y consumidores individuales/lista/OCR
mantienen sus restricciones. Inspeccionar también la búsqueda de catálogo antes
de atribuirle esta protección. Un borrador o un mock no acredita el resultado.

El [rollback](20261011-afp-l3-candidate-conflict.rollback.sql) restaura únicamente
v1 si su hash coincide con el introducido. Tanto aplicación como recuperación
son transaccionales, con hash previo/posterior y auditoría sobre el concepto
afectado. Recuperación como nueva migración correctiva, sin reescribir aplicadas.
Volver atrás restablece el defecto AFP-L3; no borra los datos revisados.

## Aprobación crítica

[AGENTS](../../AGENTS.md) y [DECISIONS](../DECISIONS.md#cambios-críticos-y-aprobación)
exigen aprobación específica para activar este cambio de decisiones clínicas.
La autorización de investigar identidades claras D-021/D-022 cubrió los lotes y
este diagnóstico, pero no activa el nuevo filtro común. El diff, justificación,
impacto, límites, alternativas, verificación y recuperación están preparados para
esa aprobación. El resolver remoto conserva la función original.
