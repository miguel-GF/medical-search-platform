# Pruevia — Medical Search Platform

Pruevia convierte texto o fotografías de órdenes médicas en estudios identificados
y opciones verificables para realizarlos. El foco actual es construir cobertura
útil en Puebla y una operación administrativa mantenible.

## Comenzar

- Agentes de IA: [reglas de trabajo](AGENTS.md).
- Producto, lógica y componentes: [guía del proyecto](docs/PROJECT_GUIDE.md).
- Capacidades, evidencia y siguiente trabajo: [estado actual](docs/CURRENT_STATE.md).
- Arranque y comprobaciones: [operación](docs/OPERATIONS_GUIDE.md).
- Referencias según la tarea: [índice documental](docs/README.md).

## Estructura

| Directorio | Responsabilidad |
| --- | --- |
| `apps/api` | API Cloudflare Worker y coordinación de servicios. |
| `apps/admin` | Panel Vue de operación y revisión. |
| `apps/landing` | Landing SEO pública, independiente de la app paciente. |
| `apps/patient` | Flutter Web/PWA y clientes móviles. |
| `apps/ocr-service`, `apps/document-scanner` | Extracción y validación de documentos. |
| `database` | Migraciones, contratos SQL, fixtures y scripts. |
| `collectors` | Captura, evidencia y adaptadores de fuentes. |
| `docs` | Guías vigentes, decisiones y cortes históricos. |

Las capacidades implementadas, pruebas aprobadas y despliegues son estados
distintos. No uses un conteo antiguo como situación actual: consulta su fecha,
entorno y evidencia en el estado del proyecto.

El contenido anterior de este README se conserva como
[snapshot histórico](docs/PROJECT_SNAPSHOT_20260914.md).
