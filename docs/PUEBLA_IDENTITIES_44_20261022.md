# Identidad44: centros de salud de Atzala y Naupan

Aplicación única y lectura independiente terminada el **22-oct-2026 a las
13:03:03 UTC**. Herramientas locales contra Supabase productivo
`ymtcmfgwuzdqtsbuvzqf`, operación ordinaria D-021/D-022.

## Incorporación

| DENUE | Sede literal | Domicilio DENUE | Referencia CLUES |
| --- | --- | --- | --- |
| 3437657 | CENTRO DE SALUD | Calle Emiliano Zapata6, Atzala, CP74590 | PLIMB000322 |
| 3415832 | CENTRO DE SALUD UN NUCLEO BASICO NORMAL | Calle Guadalupe Victoria54, Naupan, CP73140 | PLIMB001594 |

Dos sedes nuevas, tipo `clinic` por clase DENUE621116, estado `pending`.
Sus agrupaciones candidatas independientes añaden el municipio DENUE al nombre
genérico para distinguirlas; quedan `verification_pending`. La sede conserva
su nombre literal. No se asignó operador actual ni se reutilizó una marca genérica
o institucional IMSS/IMSS-Bienestar/SSA. Website NULL en ambas.

Municipio/localidad/entidad, código postal, tipo de vía, vía y exterior numerado
coinciden con las referencias. Letras e interiores vacíos se conservaron. Los
asentamientos diferentes de las fuentes no se homologaron. La lectura productiva
no encontró bindings DENUE ni sedes existentes en el entorno de coordenadas
revisado. Se compararon las205marcas y291sedes existentes, sin alterarlas.

La extracción local del XLSX CLUES de agosto2026 fijado por hash recorrió
64,450filas nacionales/3,779Puebla, devolvió las dos claves sin faltantes y
confirmó los valores investigados. Sólo campos DENUE se incorporaron como
identidad/domicilio; CLUES se usó como corroboración investigativa. La institución
o estado mensual declarado por CLUES no acredita titularidad, continuidad,
operación actual, acceso a pacientes ni disponibilidad comercial.

Los resultados web de documentos históricos federales/estatales no se trataron
como capturas verificadas: las aperturas de dos PDF fallaron403/502. El formulario
público de inventario IMSS-Bienestar tampoco acredita operador o dirección de estas
sedes y no se enviaron datos a ese formulario. Esas consultas no sustituyeron el
registro local fijado ni se utilizaron para agregar cobertura.

## Ejecución y recuperación

Una operación provisional con ROLLBACK confirmó el recibo esperado. El primer
comparador se detuvo **antes del commit** porque exigía igualdad también del
tamaño físico de la base. Una inspección nueva, sólo lectura, confirmó que ése
era el único campo distinto; funciones, permisos, relaciones, políticas, triggers
y27grupos de datos protegidos coincidían, sin sesión provisional activa.
No se repitió la operación provisional.

Se preparó una continuación que comprueba el mismo estado lógico y excluye sólo
el tamaño físico como criterio de recuperación. Esa continuación envió **un
único commit**, sin replay. Un cliente independiente confirmó dos marcas,
sedes, bindings, observaciones y auditorías nuevas; nombres, coordenadas,
direcciones, tipo y estados exactos. Todos los registros anteriores de marcas
y sedes están íntegros. RAW, funciones, permisos, fuentes y demás grupos
protegidos conservados. No hubo nuevas ofertas, estudios o migraciones.

| Estado posterior verificado | Total |
| --- | ---: |
| Marcas / sedes | 207 / 293 |
| Conceptos activos | 564 |
| Registros favorables / pendientes | 3,343 / 4,045 |
| Ofertas activas / migraciones | 234 / 112 |

No se reactivó la cola clínica ni se ejecutaron suites formales en esta operación.
Estos números no demuestran cobertura comercial por sede ni evaluación del
algoritmo clínico nuevo; esa tarea es independiente.

## Evidencia

Fixture aplicada: [provider-identity-review-20261022-01.json](../database/data/provider-identity-review-20261022-01.json),
SHA256 `2c6420ee4d114d9f9345e854c28e24f47ff676b272e1ac5475f40f69c4d02ba6`.
XLSX CLUES SHA256 `5a1cfbe7062b41d9e51249aa4b5fc8a1e623e935882e97fb5f0aac797165c95b`.

Directorio local ignorado:
`collectors/artifacts/puebla-expansion-20261009/identity-review-44-research-20261022/`.
Conserva descubrimiento, fuentes, extracción, lecturas completas, comparación
provisional, marcadores, SQL, recibos y `applied-verified.json`. No ejecutar
nuevamente los scripts de aplicación. La siguiente prioridad de la sesión es
la evaluación autorizada del candidato del algoritmo.
