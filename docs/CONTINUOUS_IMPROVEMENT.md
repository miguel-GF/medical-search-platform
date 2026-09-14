# Mantenimiento, discovery y crecimiento con iniciativa

Tipo: política vigente. Preferencia explícita del usuario del 14-sep-2026:
mantener código y recolectores al día, descubrir oportunidades y preparar crecimiento
sin esperar a que él señale cada actualización o problema.

## Responsabilidad del agente

El agente es responsable de detectar y atender el siguiente trabajo útil dentro
del objetivo autorizado. El usuario decide producto y cambios críticos; no debe
actuar como detector manual de fallos, catálogos vencidos o dependencias rotas.

Al iniciar mantenimiento, cobertura o crecimiento:

1. Leer [estado](CURRENT_STATE.md), revisar cambios y ubicar última evidencia útil.
2. Comprobar salud/frescura del área: corridas, alertas, errores, límites, backlog,
   contratos y cambios de fuente según la tarea y el acceso disponible.
3. Escoger el siguiente problema por impacto sobre usuarios, urgencia y evidencia.
   Priorizar datos incorrectos/permisos rotos; luego fuentes caídas/datos vencidos;
   después brechas frecuentes de cobertura; después expansión y optimización.
4. Ejecutar diagnósticos y correcciones rutinarias autorizadas, con comprobación
   posterior. Para un cambio crítico, preparar propuesta y esperar aprobación.
5. Registrar resultado, nueva evidencia y siguiente acción; actualizar prioridad
   si el hallazgo cambia lo que conviene hacer después.

En un encargo puntual, como corregir un botón, limitar esta revisión al área
afectada. Registrar problemas adyacentes para continuidad; no retrasar la entrega
por abrir una auditoría de todo el proyecto.

Esta iniciativa aplica especialmente al core de datos, collectors, resolución y
operación. No convierte su backlog en requisito previo para cualquier tarea.
Si el usuario pide un landing, una pantalla u otra capacidad independiente, ese
encargo pasa a ser la prioridad de la sesión y autoriza su implementación dentro
del alcance solicitado. Usar marca, arquitectura y contratos existentes; escalar
sólo dependencias reales y cambios críticos. Una página puede construirse mientras
se completa la cobertura, pero sus afirmaciones comerciales deben tener respaldo.

## Rutina de vigilancia a implementar y verificar

La tabla define la política deseada. **No declara que exista un scheduler activo.**

| Área | Disparador / frecuencia inicial | Respuesta esperada |
| --- | --- | --- |
| Captura de catálogo y precio | Cada 24 h donde la fuente lo permita; tras cambio de parser | Verificar resultado, comparación con último snapshot válido y campos esenciales. Tratar >48 h como alerta de frescura según fuente. |
| Sucursales oficiales | Semanal o detección de un ID nuevo | Reconciliar altas/cambios y abrir discrepancias; no eliminar por una desaparición aislada. |
| DENUE y discovery de proveedores | DENUE mensual; revisar fuentes nuevas semanalmente | Actualizar leads/dominios, deduplicar y priorizar por zona/modalidad sin cobertura. |
| Sitios pequeños | Cada 7–14 días, con carga acotada por host | Capturar evidencia y verificar utilidad; escalar vacíos reiterados a adapter dedicado o verificación externa. |
| Normalización y Admin | Diaria cuando exista operación programada; en cada sesión de cobertura | Revisar pendientes abiertos y errores; aplicar sólo automatización exacta aprobada. Proponer equivalencias nuevas con evidencia. |
| Dependencias y CI | En cada PR y revisión semanal de alertas | Examinar avisos/compatibilidad, actualizar de forma controlada y ejecutar pruebas pertinentes. |
| Cobertura del paciente | Tras lote relevante y revisión semanal durante piloto | Comparar consultas/recetas y zonas; priorizar faltantes frecuentes y falsos resultados. |
| Escalabilidad/costos | Tras aumentos de carga, errores por límites o cambio de volumen | Medir latencia, fallos, duración de corridas, paginación y gasto antes de proponer infraestructura. |

Adaptar frecuencias a límites, condiciones de fuente y volatilidad observada;
documentar motivo. No hacer un crawl completo diario de un directorio estable
sólo porque otros datos tengan cadencia diaria.

Para cada automatización registrar servicio/job, comando, entorno, horario/zona,
última y próxima ejecución, timeout, reintento acotado, prevención de solapamientos,
alerta, responsable de revisión y forma de detenerla. Verificar una ejecución real
y el manejo de fallos antes de declararla operativa.

Una sesión de agente terminada no sigue trabajando en segundo plano por tener
estas instrucciones. En ausencia de jobs, el estado debe indicar la brecha y la
tarea concreta de automatización. No afirmar “lo monitoreo” sin mecanismo activo.

## Discovery que produzca crecimiento útil

Buscar nuevas fuentes con una pregunta: qué zona, estudio, modalidad o proveedor
falta y cómo mejoraría la experiencia. Usar primero inventario y resultados
anteriores; revisar fuentes oficiales y conservar procedencia/fecha.

Toda exploración termina en uno de estos resultados verificables: fuente candidata
con alcance, corrida de evidencia, mejora de adapter, brecha confirmada, descarte
justificado o tarea externa concreta. Una lista extensa de dominios sin relación
con cobertura no acredita crecimiento.

Reintentar un fallo con causa: backoff en errores transitorios; revisar estructura
en parseo; investigar certificados/red en TLS; respetar restricciones de acceso.
Ante un mismo resultado repetido sin nueva evidencia, cambiar hipótesis o registrar
la dependencia externa. No repetir indefinidamente la misma captura.

Ampliar geografía con datos reutilizables y mercados/sucursales, conservando una
identidad de marca. La apertura comercial de otra ciudad requiere su propuesta,
cobertura medida y aprobación; discovery de candidatos no equivale a lanzamiento.

## Código actualizado y escalabilidad

Mantener compatibilidad, contratos y versiones soportadas con evidencia actual.
Revisar [Dependabot](../.github/dependabot.yml) y [CI](../.github/workflows/ci.yml);
la existencia de sus archivos no acredita ejecuciones ni ausencia de avisos.

“Al día” no significa instalar automáticamente todas las versiones más recientes.
Investigar avisos relevantes, compatibilidad y cambios de API antes de actualizar.
Los cambios de seguridad sensibles, saltos de arquitectura y costos nuevos siguen
el proceso de [aprobación crítica](DECISIONS.md#cambios-críticos-y-aprobación).

Optimizar a partir de mediciones: consultas lentas, índices, límites/paginación,
duplicados, duración/volumen por corrida y recursos utilizados. Agotar mejoras
compatibles del diseño actual antes de proponer servicios nuevos; presentar el
beneficio esperado, evidencia, costo y recuperación cuando el cambio sea crítico.

## Continuidad sin depender de recordatorios

Cada hallazgo material debe tener prioridad, evidencia, acción siguiente,
dependencia y criterio de aceptación en [CURRENT_STATE](CURRENT_STATE.md) o en su
reporte de área enlazado. El siguiente agente puede actuar desde ese registro.
No esperar una instrucción nueva para tareas rutinarias ya incluidas en un objetivo
activo; tampoco inventar autorización crítica ni convertir una sugerencia en mandato.
