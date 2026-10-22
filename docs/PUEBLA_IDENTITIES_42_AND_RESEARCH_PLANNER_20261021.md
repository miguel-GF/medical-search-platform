# Puebla: cinco vínculos de identidad y planificación con memoria de investigación

21-oct-2026, hora local de México; verificación final22-oct03:53:02 UTC.
Reanudación posterior al corte solicitado. Trabajo del coordinador;
los agentes no se reactivaron ni abrieron nuevos bloques. Proyecto productivo
`ymtcmfgwuzdqtsbuvzqf`; sin migraciones, despliegues ni nuevas políticas clínicas.

## Cinco vínculos aplicados, sin duplicar sedes

Las microrevisiones `pruevia:provider-identity-review:20261021:07` a `:11`
enlazan DENUE con cinco ubicaciones de Salud Digna ya existentes:

| DENUE | Sede | Exterior conservado |
| --- | --- | --- |
| 6700174 | Puebla | 909 |
| 12271871 | Puebla Azcárate | 6 |
| 9417056 | San Martín Texmelucan | 208 |
| 9447121 | San Andrés Cholula | 3532 |
| 12271887 | Puebla Azaleas | 907 |

Cada revisión pasó por rollback, un único intento de commit y una observación
con un cliente independiente. Se cotejaron nombres, direcciones completas y
snapshots existentes con las fixtures preparadas, RAW DENUE íntegros, procedencia
oficial histórica y referencia CLUES mensual. No se atribuye captura oficial
nueva: el acceso a las páginas actuales había fallado en la investigación.

Las 205 marcas y 290 ubicaciones anteriores quedaron íntegramente iguales,
incluidos estado active, tipo lab y verificación unverified de Salud Digna.
Los bindings anteriores, RAW y políticas de fuentes no cambiaron. Se añadieron
exactamente cinco bindings DENUE, cinco observaciones aceptadas y cinco auditorías.
Ninguna oferta, estudio, precio o disponibilidad aprobados por estos vínculos.
Porvenir sigue retenido por exterior 5001 frente a 4815; no se fusionó.

**Contadores conservados: 205 marcas / 290 sedes / 563 conceptos / 3,341
favorables / 4,047 pendientes / 946 históricos no_match / 234 ofertas /
112 migraciones.**

Fixtures aplicadas y copiadas con bytes idénticos:
`database/data/provider-identity-review-20261021-07.json` a `-11.json`.
Hashes, recibos por fase, snapshots y observaciones independientes:
`collectors/artifacts/puebla-expansion-20261009/identity-review-42-research-20261021/root-resume/`.
El recibo final es `applied-verified.json`. No reejecutar el applier: contiene
marcas de envío único; cualquier duda se investiga leyendo los ledgers.

## Algoritmo local de planificación de investigación

Nuevo comando: [plan_normalization_research.py](../database/scripts/plan_normalization_research.py).
Reutiliza la memoria de equivalencias existente, sin cambiar sus criterios.
Ordena grupos por cantidad de registros y permite conservar un bloqueo
documentado con motivo, firmas exactas de contexto, evidencia fijada por SHA256,
dependencias locales y fecha de vencimiento. Así evita volver a enviar un caso
idéntico a investigación en cada pasada.

Un cambio de contexto, evidencia o dependencia, o el vencimiento, vuelve a
poner el grupo en investigación. Los recibos no pueden aplazar la revisión más
de siete días; los cuatro usados aquí vencen en 24 horas. Los contextos con
campos desconocidos mantienen revisión de esquema y no se ocultan por un recibo.
Se rechazan entradas fuera de crawler y contextos marcados con datos de pacientes.
La memoria original conserva su vencimiento y sus comprobaciones de ledger.

El comando no consulta internet ni la base, no programa procesos y no aprueba
equivalencias, ofertas o cierres. Un contexto reutilizable se presenta como
propuesta; todavía necesita su ruta de aplicación autorizada y guardada.
Los archivos de salida se crean sin sobrescribir evidencia previa.

### Ejecución real sobre el inventario guardado

Se usó el corte completo73 de 4,047 registros / 745 grupos, no una nueva
paginación remota. Los contextos de los cuatro grupos anotados coinciden con
las lecturas RAW posteriores de revisiones75 y76.

- 741 grupos / 4,036 registros: investigación pendiente.
- Cuatro grupos / 11 registros: espera de cambio documentada. Antitrombina III,
  inhibidor C1 esterasa y microalbuminuria ocasional necesitan definición propia
  más explícita; Rosa de Bengala requiere soporte que conserve su método.
- Cero registros nuevos aprobados y cero solicitudes HTTP o escrituras SQL.

No se confunden once casos aplazados con once casos resueltos. Estos cuatro
recibos son una primera carga de memoria de investigación; no incluyen todas
las retenciones históricas. El algoritmo no deduce bloqueos leyendo frases de
informes ni convierte una coincidencia de nombre en una decisión clínica.

Artefactos y recibos:
`collectors/artifacts/research-planner-20261021/`.

```powershell
python database/scripts/plan_normalization_research.py `
  --memory collectors/artifacts/normalization-memory-after-review-73-20261021-v3/memory.json `
  --input collectors/artifacts/normalization-memory-after-review-73-20261021-v3/pending-contexts.json `
  --research-receipt collectors/artifacts/research-planner-20261021/research-receipt.json `
  --output collectors/artifacts/research-planner-20261021/queue-next.json
```

No se añadieron ni ejecutaron suites formales. Se observó la ejecución con datos
reales guardados, se comprobó sintaxis AST y se revisó el diff. Esto acredita
esa planificación y los vínculos concretos; no acredita autonomía clínica total.

## Continuidad

La meta está activa. El watcher clínico continúa detenido y STOP sigue presente:
no hay lotes nuevos encolados. No se activó la propuesta de resolvedor compartido
pendiente de aprobación D-006. La investigación automática de cualquier caso
nuevo y su aprobación completa siguen siendo trabajo pendiente.
