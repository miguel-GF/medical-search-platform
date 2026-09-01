# Corte de cobertura comercial verificable — 31 de agosto de 2026

Este corte alimenta únicamente evidencia obtenida de páginas oficiales. No se
inventan servicios, descripciones ni precios; un importe capturado no se
considera tarifa vigente si la fuente no garantiza su vigencia.

## Capturas reproducibles

| Fuente | Corrida | Registros válidos | Resultado |
| --- | --- | ---: | --- |
| Chopo Puebla (`chopo_puebla`) | `c30a514e-75a8-48bc-8a26-31e3d0c7aa88` | 7 | 4 coincidencias canónicas publicadas; 3 candidatos de panel/estudio aún sin concepto aprobado |
| Asesores Diagnóstico Clínico (`generic_laboratorioasesores_com`) | `b816cb46-cc39-471c-b12b-48d7b9e8a1cf` | 2 | EGO e Insulina publicados como `requires_quote=true`; los importes quedan como observaciones de captura |

Artefactos locales:

- `collectors/artifacts/chopo-coverage-20260831/chopo-puebla/c30a514e-75a8-48bc-8a26-31e3d0c7aa88`
- `collectors/artifacts/asesores-coverage-20260831-parser/generic-laboratorioasesores-com/b816cb46-cc39-471c-b12b-48d7b9e8a1cf`

## Publicación

Chopo se mapea sólo por etiqueta exacta a los conceptos LOINC ya revisados:

- `GLUCOSA EN SUERO` → `Glucosa` (`2345-7`)
- `BIOMETRÍA HEMÁTICA` → `Biometría hemática` (`58410-2`)
- `EXAMEN GENERAL DE ORINA` → `Examen general de orina` (`24356-8`)
- `INSULINA EN SUERO` → `Insulina` (`20448-7`)

Los importes de Chopo son los valores observados en la página con mercado
Puebla durante la captura; el propio sitio advierte que el precio puede variar
por ubicación. No se presentan como garantía universal de una sucursal.

La captura de Chopo también contiene `PERFIL TIROIDEO EN SUERO`,
`HEMOGLOBINA GLICOSILADA A1c` y `QUÍMICA INTEGRAL DE 45 ELEMENTOS`. No se
publican todavía: el primero es un panel cuya composición no está verificada,
el segundo aún es un hueco de catálogo en esta versión y el tercero no expone
una composición que permita una equivalencia clínica segura.

Asesores muestra `Examen General de Orina` e `Insulina` con precio visible en
su página de servicios, pero el bloque se presenta como “Precios especiales”
sin garantía de vigencia. Por eso la oferta publicada exige cotización y no
crea una fila de precio vigente. La observación cruda conserva el importe,
fecha, método de extracción y URL para auditoría.

## Regla del colector genérico

El parser reconoce `Insulina` como etiqueta clínica y puede asociar un precio
sólo al bloque visible inmediatamente contiguo al encabezado. Si existe un
precio JSON-LD, éste tiene precedencia; un número aislado, teléfono o contador
no se convierte en precio. La regresión está en
`collectors/tests/test_generic.py`.

## Fuentes oficiales

- Chopo: <https://www.chopo.com.mx/puebla/insulina-en-suero>
- Chopo: <https://www.chopo.com.mx/puebla/glucosa-en-suero>
- Chopo: <https://www.chopo.com.mx/puebla/biometria-hematica>
- Chopo: <https://www.chopo.com.mx/puebla/examen-general-de-orina>
- Chopo (paneles/candidatos): <https://www.chopo.com.mx/puebla/perfil-tiroideo-en-suero>, <https://www.chopo.com.mx/puebla/hemoglobina-glicosilada-a1c>, <https://www.chopo.com.mx/puebla/quimica-integral-de-45-elementos>
- Asesores: <https://laboratorioasesores.com/servicio/>
