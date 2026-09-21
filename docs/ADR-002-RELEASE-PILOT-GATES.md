# ADR-002 — Puerta de liberación del piloto Puebla

Estado: **propuesta**, no aprobada ni ejecutada. Fecha: 14-sep-2026.

## Contexto y evidencia

La landing está implementada como sitio estático en `apps/landing` y el Worker
API tiene un dry-run de publicación aprobado. El Admin y el paciente son
frontends distintos. El Worker conserva compatibilidad con un solo
`ALLOWED_ORIGIN` y ahora tiene una opción aditiva `ALLOWED_ORIGINS` para una
allowlist exacta; publicar dos frontends sin activar y probar esa frontera puede
dejar un CORS demasiado abierto o romper el flujo; una configuración que permita
Admin y paciente desde orígenes distintos requiere una decisión de seguridad.
El catálogo conserva 7,028 etiquetas de
proveedores en `normalization_pending`; no son equivalencias clínicas aprobadas.

No hay dominio comprado, DNS asociado ni servicio público verificado en esta
entrega. El sitio no debe indexarse hasta configurar destinos reales y revisar el
contenido legal/contacto.

## Propuesta recomendada

1. **Piloto acotado:** publicar sólo la cobertura clínica y comercial que ya
   tenga fuente, alcance, vigencia y decisión revisada. Mostrar explícitamente
   `partial`, `needs_clarification` y `requires_quote`; no usar la cola para
   rellenar páginas ni para afirmar una tasa de cobertura.
2. **Frontera web:** usar un dominio raíz para la landing y subdominios separados
   para paciente, Admin y API, pero mantenerlos no públicos hasta configurar DNS
   y probar TLS. La compra y elección del nombre quedan fuera de este ADR.
3. **CORS explícito:** activar, con aprobación, `ALLOWED_ORIGINS` como allowlist
   de orígenes exactos HTTPS para el Worker (sin comodines, listas ambiguas,
   rutas ni credenciales). El código ya valida preflight y devuelve 403 sin
   reflejar un origen no permitido; falta decidir los dominios reales y
   desplegar la configuración.
4. **Datos clínicos:** trabajar la cola por lotes pequeños priorizados por
   frecuencia y evidencia del proveedor. Cada mapping necesita equivalencia
   clínica revisada, alcance de sucursal, procedencia y prueba de vecino que debe
   quedar ambiguo/no encontrado. El lote se puede preparar en SQL/fixture, pero
   no se publica automáticamente.
5. **Indexación:** mantener `PRUEVIA_INDEXABLE=false` durante preparación.
   Activarlo sólo después de confirmar las URLs reales, destino del CTA, aviso
   legal/contacto y una revisión final del contenido; regenerar el sitio y
   comprobar sitemap, robots, headers y enlaces.

## Impacto y riesgos

- La allowlist cambia la frontera de acceso del API y puede dejar fuera un
  frontend si se configura mal; una lista demasiado amplia expone el API a
  orígenes no previstos.
- Publicar mappings equivocados puede causar una recomendación médica o
  comercial falsa; por eso el volumen de filas no es un criterio de éxito.
- La landing indexable es pública y puede recibir tráfico antes de que exista
  cobertura suficiente; el contenido debe comunicar el alcance real.
- El piloto requiere revisar frescura y disponibilidad sin prometer reserva,
  pago o convenio. No agrega por sí mismo infraestructura ni costos nuevos.

## Alternativas

- **Separar APIs por frontend:** evita una allowlist compartida, pero duplica
  configuración, despliegue y monitoreo.
- **Proxy bajo un único origen:** simplifica CORS, pero añade configuración de
  routing y un nuevo punto de fallo; requiere su propio plan de recuperación.
- **Liberar sólo landing no indexable:** permite validar contenido sin abrir el
  core; es la alternativa mientras no exista decisión de publicación.
- **Mapear toda la cola automáticamente:** se descarta por riesgo clínico y de
  trazabilidad, aunque reduzca el contador visible.

## Ejecución y aceptación (si se aprueba)

1. Registrar en `DECISIONS.md` el alcance exacto aprobado: dominio, orígenes,
   entorno y lote de datos.
2. Preparar diff de CORS y contratos de seguridad; ejecutar API/Admin/paciente,
   preflight, rechazo de origen ajeno y pruebas de sesión/MFA (la suite del
   Worker ya cubre esos casos en modo local).
3. Generar la landing con URLs reales, `INDEXABLE=true`, y revisar los artefactos
   estáticos antes de subirlos.
4. Para cada lote clínico, ejecutar dry-run, revisar diff y contrato de
   idempotencia; publicar sólo después de la aprobación de equivalencias.
5. Tras publicar, comprobar versión, salud, búsqueda, límites, Auth, una receta
   parcial y una petición sin autorización. Guardar commit, timestamps y entorno.

## Recuperación

Conservar la versión anterior del Worker y del sitio. Si CORS o la landing fallan,
volver a la versión previa y desactivar el destino público/indexación; no borrar
filas clínicas para corregir una publicación. Un mapping incorrecto se corrige
con una decisión hacia delante y auditoría del actor. Retirar DNS o la ruta
customizada no revierte por sí solo datos ya publicados.

## Aprobación solicitada

La aprobación debe indicar explícitamente: (a) dominio y destinos, (b) opción de
CORS, (c) si se abre sólo landing o también paciente/Admin/API, (d) lote clínico
con su revisor y alcance, y (e) ventana de publicación y recuperación. Hasta
recibir esa respuesta, este ADR sólo prepara el trabajo y no autoriza compras,
DNS, migraciones, mappings ni deploy real.
