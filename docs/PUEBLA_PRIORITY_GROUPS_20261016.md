# Puebla: grupos de mayor volumen y paquetes

16-oct-2026. Base productiva enlazada `ymtcmfgwuzdqtsbuvzqf`.
La sesión admite tres agentes auxiliares simultáneos y un coordinador. Se usaron
los tres; el límite impide ejecutar diez a la vez.

## Establecimientos

Último conteo remoto de este cierre: **114 marcas/instituciones y198 ubicaciones**.
El inventario oficial de Puebla contiene13,747 establecimientos de salud; esa
cantidad no equivale a sucursales incorporadas ni a cobertura de estudios.
Las instituciones nuevas siguen pendientes de verificación comercial.
Las234 ofertas existentes permanecen intactas; no se publicaron ofertas nuevas.

## Estudios incorporados

Los lotes prioritarios54 y55, identificadores de revisión terminados en
`20261016:07` y `20261016:08`, incorporaron **104 registros** de13 grupos de ocho.
El primer lote aporta48 registros y seis conceptos; el segundo56 y siete.
Conteo remoto posterior: **542 conceptos y4,147 registros pendientes**.
Cola explícita:48 entradas. No hubo cambio del resolver ni migración.

| Lote | Identidades conservadas | Límite |
| --- | --- | --- |
| 54 | HSV1/HSV2 IgM; tuberculosis IgG e IgM individuales; Epstein-Barr nuclear IgM y temprano IgM | Sin combinar isotipos ni inferir EBNA1/2/3 o EA-D/R. |
| 55 | TPA, CTX/Crosslaps, mutación de Huntington, níquel en sangre, silicio en sangre, primidona y tiempo de trombina | Sin inferir matriz exacta, método, beta-isomerización, variante genética o metabolitos. |

Los13 aliases están limitados a Salud Digna. La familia sangre literal se
conserva para níquel y silicio, sin convertirla en suero, plasma o sangre total.
El original y las guardas RAW permanecen vinculados a cada decisión.
Los nombres canónicos y las consultas con proveedor se observaron dentro de
rollback antes de incorporar los lotes. Las etiquetas públicas abreviadas o
insuficientes pueden seguir requiriendo contexto.

Comprobación independiente terminada a12:26:31 UTC:26 solicitudes a la API
pública,13 consultas con proveedor y36 observaciones de etiquetas/variantes;
cero selecciones incompatibles de los nuevos conceptos. Los176 contextos RAW
consultados permanecen íntegros y los72 retenidos no cambiaron de estado.
Muestras, guardas y atributos de fuente coinciden exactamente. Los dos ledgers
confirman aplicación única tras preview rollback. No se ejecutaron suites.
Recibo conjunto: `clinical-research/reviews-54-55-observed-close.json`.

Fixtures versionadas:
`database/data/reviewed-aliases-20261016-07.json` y
`database/data/reviewed-aliases-20261016-08.json`.
Recibos y fuentes bajo
`collectors/artifacts/puebla-expansion-20261009/clinical-research/`, carpetas
`review-54-antibodies-priority/` y `review-55-individuals-priority/`.
La numeración de carpetas no equivale al número de revisiones aplicadas: la
propuesta de paquetes06 no se aplicó.

El nuevo corte completo terminó a12:28:28 UTC:4,147 pendientes en768 grupos y
1,305 términos; memoria shadow v3 de54 revisiones,401 aliases,420 reglas y
2,881 contextos históricos reutilizables. Las48 entradas de cola coinciden con
ledger y hashes;42 archivos de cortes52/49/47 permanecen intactos. Fuentes,
contadores y resolver clínico no cambiaron durante la lectura. La memoria no
aprobó nuevos pendientes. Recibos en
`collectors/artifacts/normalization-memory-after-priority-54-55-v3/`.

## Paquetes: prioridad de mayor a menor

Lectura remota separada: **66 grupos y367 registros de laboratorio**;
43 grupos de ocho y23 de uno. Un ultrasonido de una fila quedó fuera de ese
alcance. La matriz ordena primero cada grupo por número de registros y después
su familia. Los totales familiares siguientes no cambian ese orden.

| Familia | Grupos | Registros |
| --- | ---: | ---: |
| Anticuerpos e isotipos combinados | 14 | 105 |
| Endocrino y protocolos de glucosa | 11 | 60 |
| Paneles infecciosos | 11 | 60 |
| Otros perfiles clínicos | 7 | 56 |
| Inmunología celular y subclases | 7 | 42 |
| Genética y tamiz neonatal | 6 | 27 |
| Química y proteínas | 10 | 17 |

Son **367 registros investigados, cero cerrados por esta propuesta**. Dos pilotos
de ocho registros cada uno tienen composición literal: perfil hormonal masculino
de11 componentes y metanefrinas urinarias de24horas de dos componentes.
El primero difiere del perfil de cuatro de otro proveedor; el segundo excluye
metanefrinas totales. Drogas “4” declara seis códigos y permanece retenido.
No se completa un panel desde un nombre comercial o un menú externo parecido.

## Qué falta para cerrar paquetes

La base ya tiene cinco servicios `lab_panel` y ocho enlaces de componentes,
pero el importador actual crea estudios individuales y los consumidores
observados no contrastan esa composición. Añadir sólo nombres perdería datos
que determinan la equivalencia de una orden.

Se preparan importador, almacenamiento revisado y filtros de consumidores en
archivos aislados. Modificar esta decisión clínica persistente exige presentar
el diff concreto y obtener aprobación explícita según D-006 antes de activarlo.
Esta documentación no autoriza migraciones ni selección nominal de paneles.

Artefactos locales de paquetes:
`collectors/artifacts/puebla-expansion-20261009/priority-packages-20261016/`:
`priority-matrix.md`, RAW completos, fuentes, `proposal.md`, pilotos no ejecutables
y `panel_policy_draft.py`. Ningún SQL de esa propuesta se ejecutó.

Preparación posterior:hay diff SQL/patch aislado de consumidores públicos,
proveedor, batch/OCR y detalles, con13 funciones leídas y cinco cuerpos remotos
idénticos a la base comprometida. Compilación Python correcta; no es una
comprobación de PostgreSQL. Registro de composiciones inicialmente vacío:
**activarlo así retendría los cinco paneles históricos y sus ofertas**.
Todavía falta el importador atómico completo y revisar los hijos de los pilotos.
Además, imagen y paneles comparten consumidores; se prepara su reconciliación
aislada para evitar que un reemplazo elimine la guardia del otro.
Contrato, diff y recuperación en `integration-contract.md`,
`proposed-panel-integration.patch` y `proposed-panel-recovery.sql`.

Siguiente acción: terminar integración aislada de composición y revisar los
hijos de los pilotos. Continuar por los grupos de ocho antes de los de uno,
conservando pendientes cuando falte evidencia o soporte del contrato.
