# Identidad explícita y nombres canónicos — evaluación local

**Propuesta local, no activada ni integrada al candidato de 29 funciones.**
23-oct-2026, PostgreSQL 17.6 aislado, catálogo público congelado del 22 de octubre.

## Hallazgo que cambia la decisión

Las 16 filas pendientes seleccionadas por la variante anterior no eran cierres
aprobados. Al revisar sus tres consultas se observó:

- Renina → actividad de renina, sin que la consulta especifique actividad.
- Plasmodium → anticuerpos IgG contra P. falciparum en suero, sin esos atributos.
- Escápula AP → una radiografía concreta, por similitud de palabras.

La fuente de Plasmodium consultada de nuevo mantiene ese título genérico;
su preparación no identifica técnica, especie ni isotipo. No se debe interpretar
que una sola sugerencia permita aprobar todos sus atributos.

## Cambio aislado

La variante mantiene las guardas literales y las sugerencias por prefijo.
En v4 exige identidad literal exacta por nombre/alias y confianza1 para resolver
automáticamente; una coincidencia sólo fuzzy sigue como sugerencia ambigua.
El camino de identificadores LOINC exactos aprobados se conserva.
Los tres SQL propuestos están en este directorio, junto a `evidence.json` con
sus SHA256, resultados agregados y recibo de apagado. No son migraciones.
No introduce aliases, conceptos ni equivalencias. La selección explícita del
usuario en la API es un mecanismo separado y esta prueba no acredita su integración.

## Comparación terminada

4,045 filas pendientes, 744 grupos, 22 controles originales, dos consultas
insuficientemente específicas y **564 nombres principales activos**.
Total: 588 controles, 2,076 invocaciones por fase y **4,152 antes/después**.
Se comprobó igualdad de todos los campos importados y apagado del servidor local.

| Resultado | Motor vigente | Variante |
| --- | ---: | ---: |
| Nombres principales con selección única del ID correcto | 548 /564 | 548 /564 |
| Nombres principales sin resultado | 16 | 16 |
| Nombres principales con selección resuelta incorrecta | 0 | 0 |
| Observaciones que resuelven por word_fuzzy, en el conjunto completo | 27 | 0 |
| Pendientes con selección única, con proveedor | 36 filas | 0 filas |
| Pendientes con sugerencias ambiguas, con proveedor | 272 filas | 72 filas |
| Pendientes sin resultado, con proveedor | 3,737 filas | 3,973 filas |

No hubo cierres ni cambios productivos. «Hematica» y «biometria» pasan a propuesta
ambigua porque su selección previa era fuzzy; sus candidatos permanecen.
«Electro» conserva sugerencias; los nombres completos comprobados de biometría
e IgE contra gluten conservan su resolución. La reducción de selecciones
automáticas no es una mejora de cobertura ni una revisión clínica completa.

## Defecto previo descubierto en 16 nombres completos

El mismo catálogo contiene 16 nombres que ya eran rechazados antes de la variante:

- Doce estudios con «con contraste» tienen `contrast_mode=not_applicable`.
- Tres estudios con extremidades/miembros no tienen las relaciones anatómicas
  requeridas por las frases del léxico.
- Triyodotironina libre tiene dos frases del léxico que fuerzan el marcador
  `__blocked_analyte_variant__`, introducido antes de incorporar ese concepto.

Estas causas se contrastaron con los datos y el SQL del resolvedor exportados.
No se ignoraron las guardas ni se cambiaron atributos para forzar resultados.
Siguiente acción: reconciliar esas identidades con sus fuentes y corregir la
representación junto con controles de variantes, no retirar protecciones globales.

## Reproducción y límites

Preparador `database/scripts/prepare_requirement_discovery_candidate.py` con
`--require-explicit-identity`; ejecutor `run_clinical_core_local.py` con
`--canonical-controls`. El resumidor valida el ID esperado para cada nombre y
permite un archivo nuevo de interpretación sin sobrescribir evidencia anterior.

Evidencia: `collectors/artifacts/clinical-core-local-20261022/`, subdirectorios
`requirements-explicit-identity-v3-20261023` y
`local-core-explicit-v3-canonical-pg17`. Este último conserva observaciones,
`review-summary-canonical-v2.json` y apagado. El catálogo no se modificó entre
las fases: sólo se reemplazaron tres funciones dentro del servidor local.
Persisten las limitaciones de [la evaluación inicial](../../ALGORITHM_LOCAL_EVALUATION_20261023.md):
sin RLS/JWT, restricciones/índices completos, envoltorios públicos de imagen/paneles
o recorrido HTTP. No hay una activación productiva que deshacer.
