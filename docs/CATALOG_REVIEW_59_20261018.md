# Revisión59: coagulación y estudios frecuentes

Fecha:18-oct-2026,04:53–04:57UTC /17-oct local. Entorno: lectura de la base
productiva enlazada y observación transaccional con rollback; sin aplicación.

## Resultado observable

Se investigaron **74 registros de nueve grupos**, conservando los RAW completos.
El catálogo leído contiene550 conceptos y772 aliases activos/no rechazados.
La cola local fue comprobada mediante proceso15656 vivo; esta revisión no se
agregó a su manifiesto. El último inventario completo sigue siendo4,082 pendientes,
133 instituciones y217 ubicaciones; no se presenta como un recuento nuevo.

Se preparó un borrador de dos conceptos nominales, TP yTPT, con16 registros de
Salud Digna. La documentación primaria de MedlinePlus respalda las expansiones:

- [Tiempo de protrombina](https://medlineplus.gov/spanish/ency/article/003652.htm).
- [Tiempo parcial de tromboplastina](https://medlineplus.gov/spanish/pruebas-de-laboratorio/prueba-de-tpt-tiempo-parcial-de-tromboplastina/).

No se infirió muestra, tubo, técnica, INR ni oferta comercial a partir del ayuno.
Las referencias se capturaron directamente conHTTP200 yhash. Un PDF histórico
del dominio salud-digna.com también se conservó, pero no acredita protocolo
actual ni propiedad actual del dominio. Su portada redirige medianteJavaScript
a.org; la conexión directa a.org falló. No se utilizó para completar atributos.

## Fallo encontrado antes de aplicar

En una transacción terminada con **rollback**, los dos aliases de proveedor y
los dos nombres canónicos resolvieron correctamente. Sin embargo, la consulta
**«tiempo de protrombina con INR»** quedó resuelta hacia el nuevo TP simple.
No hay evidencia en el RAW de que ese estudio incluya INR. Esa resolución
perdería una condición explícita de la orden.

Por eso el borrador completo **20261018:02 quedó sin aplicar y fuera de la cola**.
El ledger se comprobó como`not_applied` antes y después. Los restantes24 casos
de contraste no eligieron un concepto nuevo incompatible. Es una observación
acotada del comportamiento real dentro de rollback, no una suite ni evidencia
de cobertura comercial. Los aliases cortos siguen siendo específicos del
proveedor: su resolución pública sin proveedor no se promete.

## Otros58 registros

| Grupo | Registros | Aclaración pendiente |
| --- | ---: | --- |
| Calcio |8| Total o ionizado; matriz no declarada. |
| Colesterol |9| Dos proveedores; confirmar total y conservar la muestra propia de cada uno. |
| Bilirrubinas |8| Composición del panel. |
| Microalbuminuria |8| Orina matutina ocasional explícita; concentración o cociente con creatinina sin confirmar. |
| PTH |8| Intacta, fragmentos y generación sin declarar. |
| Prueba de embarazo |9| Dos proveedores; muestra y escala sin confirmar. |
| Cuantificación HGC |8| Fracción/subunidad sin declarar; no equivale a beta libre. |

## Evidencia y siguiente acción

Artefactos locales bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/review-59-research-20261018/`:
lectura completa, fuentes, recibos, informe, definición, SQL de preparación,
observación de variantes y recibo de ledger. Fixture inmutable:
`database/data/reviewed-aliases-20261018-02.json`,SHA256
`cab9e92e08cba56b0256576bf6712c10c034a5d9b6129aa353819e0ff98f3711`.

Siguiente acción: investigar TPT por separado con sus variantes especializadas
y preparar la conservación explícita deINR en el resolvedor. Una modificación
de core debe seguirD006; este hallazgo no activa una corrección crítica. La
investigación de otros grupos y proveedores puede continuar mientras tanto.
No hubo ofertas, precios, fuentes aprobadas, migraciones ni despliegues nuevos.

## Seguimiento: revisión60

Se separó TPT en el borrador20261018:03 (ochoRAW). Una observación más amplia
también encontró pérdida deINR en «tiempo parcial de tromboplastina con INR».
Por ello tampoco se encoló. La lectura independiente posterior conservó74RAW
intactos y ambos ledgers`not_applied`; el nuevo recuento confirma550 conceptos,
4,082 pendientes,133 instituciones,217 ubicaciones,234 ofertas y112 migraciones.

La definición real dev3 omite tokens de menos de cuatro caracteres en su guardia
de palabras significativas. Se preparó un diff aislado para conservar el tokenINR,
con sus límites y recuperación, sin ejecutarlo ni cambiar el core. Véase la
[propuesta concreta y pendientes de verificación](proposals/20261018-preserve-inr-requirement.md).
