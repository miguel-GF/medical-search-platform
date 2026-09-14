# Pruevia: instrucciones permanentes para agentes

## Entrada y objetivo

Pruevia convierte una búsqueda o una orden médica en estudios identificados y
opciones comprobables para realizarlos. El foco vigente es lograr cobertura útil
en Puebla y una operación administrativa mantenible.

Antes de trabajar, lee [estado y prioridades](docs/CURRENT_STATE.md) y elige la
ruta correspondiente en [el índice](docs/README.md). Consulta
[producto y lógica](docs/PROJECT_GUIDE.md) al incorporarte o cambiar comportamiento.
No es necesario releer la conversación original ni todo el roadmap en cada tarea.

## Autoridad y autonomía

- Respeta las instrucciones aplicables de la sesión y la petición del usuario.
  Esta guía no amplía permisos ni sustituye instrucciones de mayor prioridad.
- Resuelve implementación, errores y mejoras internas dentro del alcance autorizado.
  No solicites de nuevo autorizaciones que ya cubren exactamente esa operación.
- Conserva contratos, equivalencias clínicas, permisos y evidencia. Para modificar
  decisiones importantes sigue el [registro de decisiones](docs/DECISIONS.md).
- Cambios de producto, arquitectura principal, costos nuevos, publicación externa
  o acciones irreversibles requieren autorización que cubra su alcance concreto.
  Prepara primero el cambio y su evidencia cuando sea posible.
- Antes de ejecutar un cambio crítico, informa y espera aprobación explícita del
  usuario para esa propuesta: cambio, justificación, impacto, riesgos, alternativas,
  solución, verificación y recuperación. Consulta los criterios de
  [cambios críticos](docs/DECISIONS.md#cambios-críticos-y-aprobación).
  Una instrucción genérica de continuar o mejorar el proyecto no cubre ese permiso.
  Investigar y preparar un diff aislado sigue permitido; no activar el cambio.
- No interpretes permisos históricos como autorización permanente para cualquier
  migración, compra, publicación o contacto con terceros.
- Delega solamente cuando las instrucciones de la sesión o del usuario lo permitan.
  Cuando corresponda, asigna tareas acotadas y evita ediciones simultáneas del mismo archivo.

## Forma de trabajar

1. Revisa el estado del árbol de trabajo y conserva cambios ajenos.
2. Define el resultado observable de la tarea y localiza código, contratos y pruebas.
3. Verifica sólo los hechos necesarios: documentación para intención, código para
   implementación y entorno consultado para estado desplegado.
4. Implementa una solución completa dentro del alcance; reutiliza componentes y
   scripts existentes. No añadas plataformas ni refactors amplios por anticipación.
5. Ejecuta las comprobaciones pertinentes de [operación](docs/OPERATIONS_GUIDE.md).
   Un resultado incompleto o una prueba con mocks no acredita despliegue real.
6. Actualiza la documentación afectada junto al cambio. Entrega qué cambió,
   cómo se verificó y qué falta, sin confundir trabajo propuesto con ejecutado.

Usa búsquedas dirigidas (`rg`), lectura UTF-8 y comandos compatibles con el shell
activo. En Windows PowerShell antiguo, no uses `&&`. Edita mediante parches,
respeta archivos ignorados y no ejecutes resets ni limpiezas amplias para desbloquearte.
No hagas commit/push por rutina si la tarea o las instrucciones no lo autorizan.

## Reglas del producto y los datos

- La búsqueda pública es utilizable sin cuenta. Admin y proveedor requieren
  autorización de servidor; MFA no reemplaza permisos sobre cada recurso.
- Identidad DENUE, sucursal, estudio canónico, oferta, precio y disponibilidad
  son hechos diferentes. Una dirección no prueba que allí se realice un estudio.
- Toda publicación de datos debe conservar fuente, observación y decisión.
  Los collectors producen evidencia; un scrape exitoso no aprueba equivalencias.
- OCR transcribe y propone correcciones trazables. Conserva el original y la
  revisión necesaria; no infieras estudios ausentes en la orden.
- Fuzzy/IA pueden proponer candidatos; nunca son por sí solos aprobación clínica.
  Preserva muestra, modalidad, anatomía, lateralidad, contraste y composición.
- Una receta parcialmente cubierta debe mostrar faltantes y aclaraciones. No
  conviertas un precio desconocido en cero ni una sugerencia en cobertura confirmada.
- No elijas un panel ambiguo para mejorar artificialmente la tasa de resolución.
- No elimines registros canónicos porque una captura disminuyó o falló.
  Conserva el último dato válido y aplica revisión/cuarentena según la fuente.

## Seguridad y operación

- Nunca incluyas claves de servidor en frontend, Git, logs o respuestas. Usa
  plantillas sin valores reales y la [guía de entorno](docs/ENVIRONMENT.md).
- Un secreto en su archivo local ignorado no está automáticamente comprometido.
  Si existe exposición real, identifica alcance y sigue el procedimiento de rotación.
- No debilites JWT/MFA, RLS, permisos, TLS, límites o controles de origen para
  hacer pasar un flujo. Diagnostica la capa que falla.
- Cambios de esquema van en nuevas migraciones; no reescribas migraciones aplicadas.
  Antes de una operación remota identifica proyecto, alcance, dependencias y recuperación.
- Distingue flags locales, configuración versionada y estado remoto. El nombre
  de un Worker o un archivo de configuración no acredita un despliegue.
- Los contratos SQL deben revisarse con el runner que conserva todas las
  aserciones; la última línea “ok” y el código de salida del CLI no bastan.

## UI y crecimiento

Mantén una identidad Pruevia coherente entre paciente y admin, con tokens de tema
centralizados en cada tecnología; consulta la [guía de trabajo](docs/WORK_GUIDE.md).
Usa español legible con acentos, estados de error útiles y filtros reutilizables.

Prioriza brechas de cobertura demostradas y experiencia del paciente. Las métricas
de RAW, aliases o pruebas aprobadas no sustituyen cobertura comercial ni una
medición de recetas. El futuro descrito en el roadmap no autoriza construirlo hoy.
Una petición explícita del usuario sí fija la tarea y su prioridad: por ejemplo,
construir el landing no requiere terminar primero el catálogo de Puebla. Mantén
la iniciativa del core sin bloquear encargos independientes; sólo eleva una
dependencia real o un cambio crítico con sus implicaciones.

## Investigación y continuidad

Trabaja con iniciativa: detecta datos vencidos, fallos de collectors, fuentes
nuevas, dependencias y brechas de cobertura sin esperar a que el usuario identifique
cada pendiente. Sigue [mantenimiento y discovery](docs/CONTINUOUS_IMPROVEMENT.md).
En tareas de mantenimiento/crecimiento elige y ejecuta el siguiente trabajo útil
autorizado. En tareas puntuales, termina el encargo y registra hallazgos ajenos al
alcance; no lo sustituyas por una investigación general.

Investiga una pregunta concreta. Reutiliza evidencia vigente, verifica información
externa cambiante cuando corresponda y registra qué cambió la siguiente decisión.
No repitas intentos iguales sin una hipótesis nueva; conserva proceso/handle si sigue
activo. Si falta acceso o decisión externa, deja un bloqueo reproducible y avanza
en trabajo independiente dentro del alcance.

Al cerrar una tarea material, actualiza el estado o la decisión correspondiente.
Incluye fecha, entorno, evidencia, límites y siguiente acción. No guardes secretos,
datos de pacientes ni transcripciones extensas como memoria del proyecto.
