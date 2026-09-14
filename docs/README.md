# Documentación de Pruevia

Entrada para agentes: [AGENTS](../AGENTS.md). Después lee
[estado y prioridades](CURRENT_STATE.md) y la referencia de tu tarea.
La conversación original no es lectura obligatoria para incorporarse.

## Documentos vigentes

| Documento | Responsabilidad |
| --- | --- |
| [Producto y lógica](PROJECT_GUIDE.md) | Objetivos, usuarios, conceptos, componentes y contratos. |
| [Guías de trabajo](WORK_GUIDE.md) | Procedimientos por tipo de cambio y traspaso. |
| [Operación](OPERATIONS_GUIDE.md) | Directorios, comandos, comprobaciones y alcance de resultados. |
| [Estado y prioridades](CURRENT_STATE.md) | Capacidades y pendientes con evidencia fechada. |
| [Decisiones](DECISIONS.md) | Autonomía, aprobación de cambios críticos y evolución de reglas. |
| [Mantenimiento y discovery](CONTINUOUS_IMPROVEMENT.md) | Iniciativa, cadencias, actualización del código y crecimiento medido. |
| [Entorno](ENVIRONMENT.md) | Variables, ejemplos y límites de exposición de credenciales. |

## Qué leer según la tarea

| Voy a… | Referencia inicial | Profundizar sólo si corresponde |
| --- | --- | --- |
| Cambiar colores, filtros o pantallas | [Guía UI](WORK_GUIDE.md#cambiar-admin-paciente-o-temas) | [Paciente](../apps/patient/README.md), componentes y tokens enlazados. |
| Añadir un laboratorio o sucursal | [Cobertura](WORK_GUIDE.md#ampliar-cobertura-de-puebla) | [Inventario Puebla](PUEBLA_PROVIDER_COVERAGE.md), [collectors](../collectors/README.md). |
| Corregir resolución u OCR | [Resolver](WORK_GUIDE.md#modificar-resolver-catálogo-u-ocr) | [Benchmark v1](RESOLVER_BENCHMARK_V1.md), [v2](REAL_QUERY_RESEARCH_V1.md), [LOINC](LOINC_INTEGRACION.md), [corpus OCR](OCR_PUBLIC_CORPUS.md). |
| Diagnosticar login/401 | [Diagnóstico Admin](WORK_GUIDE.md#investigar-un-401-o-fallo-de-conexión-del-admin) | [Errores](ERROR_HANDLING.md), [entorno](ENVIRONMENT.md), pruebas Auth. |
| Cambiar API/esquema o desplegar | [Operación](OPERATIONS_GUIDE.md) | [Database](../database/README.md), [seguridad](SECURITY_HARDENING_20260904.md), [ADR Worker](ADR-001-WORKER-SUPABASE-REST.md). |
| Decidir qué construir después | [Prioridades](CURRENT_STATE.md) | [Decisiones](DECISIONS.md), roadmap como referencia de largo plazo. |
| Mantener datos/código al día y detectar crecimiento | [Mantenimiento y discovery](CONTINUOUS_IMPROVEMENT.md) | [Cobertura Puebla](PUEBLA_PROVIDER_COVERAGE.md), corridas, alertas y CI del área. |
| Construir el landing u otra tarea independiente | [Guía de capacidad independiente](WORK_GUIDE.md#construir-una-capacidad-independiente-ejemplo-landing) | [Producto](PROJECT_GUIDE.md), identidad visual y arquitectura prevista. El backlog del core no es un bloqueo automático. |

## Autoridad y discrepancias

- Las instrucciones aplicables de la sesión y las decisiones aprobadas definen
  el alcance. Los documentos no otorgan permisos externos por sí mismos.
- Las guías vigentes describen intención y reglas; código, tipos y migraciones
  describen implementación versionada; inspeccionar el destino acredita lo desplegado.
- Una diferencia se registra y se resuelve: no aceptar un bug porque está en código
  ni afirmar que una función existe porque está prevista en arquitectura.
- Los reportes conservan fecha y entorno. Una afirmación sin evidencia suficiente
  queda como no verificada.
- Toda decisión crítica requiere la [propuesta y aprobación](DECISIONS.md#cambios-críticos-y-aprobación)
  del usuario antes de ejecutarse. Las tareas rutinarias conservan autonomía.

## Referencias y archivo

Estos documentos retienen detalle técnico o antecedentes. Sus fechas y secciones
propuestas deben respetarse; no sustituyen el estado actual.

| Referencia | Uso |
| --- | --- |
| [Arquitectura canónica](01_ARQUITECTURA_CANONICA.md) | Diseño transversal; mezcla implementación y destino futuro. |
| [Arquitectura DB](DB_ARCHITECTURE_V1.md), [tablas](DB_TABLE_CATALOG_V1.md), [ERD](ERD.mmd) | Modelo de referencia; contrastar esquema final. |
| [Fases](02_FASES_IMPLEMENTACION.md) | Roadmap y cortes acumulados; no backlog activo. |
| [Conversación original](00_CONVERSACION_CANONICA.md) | Origen y razones históricas, por consulta dirigida. |
| [Revisión de integración](03_REVISION_INTEGRACION.md) | Evaluación del corte documentado. |
| [Operación anterior](DEV_OPERATIONS.md) | Comandos detallados por fase; validar precondiciones actuales. |
| [Prueba interna Admin](INTERNAL_ADMIN_RELEASE.md) | Plan y evidencia de su corte; bloqueos antiguos pueden estar resueltos. |
| [Auditoría septiembre](SECURITY_AUDIT_20260901.md), [endurecimiento](SECURITY_HARDENING_20260904.md) | Hallazgos, revalidaciones y pendientes; no garantía general de seguridad. |
| [Cobertura agosto](COBERTURA_REAL_20260831.md), [evidencia proveedores](PROVIDER_CLAIMS_EVIDENCE_20260831.md) | Resultados históricos con procedencia. |
| [README anterior](PROJECT_SNAPSHOT_20260914.md) | Snapshot archivado al reorganizar esta documentación. |

## Mantenimiento

Actualizar reglas/guías cuando cambia el comportamiento y el estado cuando cambia
una capacidad comprobada. Registrar decisiones materiales con motivo y alcance;
mantener una sola referencia responsable por cada procedimiento y enlazar el resto.
No agregar contadores vivos al README ni diarios extensos al archivo de reglas.
