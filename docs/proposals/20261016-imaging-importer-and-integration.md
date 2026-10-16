# Imagen: importador e integración pendientes de aprobación

Estado: propuesta D-006 aislada, **sin activar**. Fecha:16-oct-2026.
La autorización ordinaria para investigar estudios no activa este cambio clínico.
No se solicita aprobación todavía: falta completar el candidato de integración.

## Avance posterior: candidatos aislados,16-oct12:31 UTC

El candidato API ya parte de nueve archivos comprometidos que coinciden por
bytes con las fuentes conservadas de la publicación. Cambian app, batch y types;
la compilación TypeScript terminó con salida0. Conserva originales por entrada
antes de retirar preparación, desactiva segmentación para el piloto y pasa todos
los paquetes OCR por el decorador cuando el flag está activo. El flag sigue sin
activar. El decorador SQL exige correspondencia textual e índices1..N y filtra
ofertas por índice y estudio; si pierde alineación devuelve aclaración.

Se escribieron guardas diferidas de definición completa auditada para servicio,
anatomía, protocolo y vistas; los cambios clínicos requieren otra identidad
revisada. El importador incorpora ese snapshot, fija funciones y bindings de
triggers y fuerza las guardas antes del recibo también en rollback. Cantidad de
vistas continúaNULL; no se deriva de la lista de proyecciones. Se generaron las
dos variantes SQL, **sin ejecutar SQL**.

El candidato Flutter cambia sólo dos bloques sobre el commit base4ed8442.
Análisis dirigido y compilación release terminaron0. No hay snapshot de fuentes
Patient idéntico al publicado: la publicación incluyó mejoras previas del árbol
revisado. Por tanto, este build no acredita conservarlas y no está listo para
desplegarse. Hay que reconstruir esa base antes de una propuesta de activación.

Artefactos nuevos bajo la misma carpeta raíz:
`integration-candidate-20261016/` y `patient-candidate-20261016/`, con fuentes,
parches, manifests, recibos y límites. Los SQL no pasaron por PostgreSQL ni se
observó flujo integrado en navegador. No hubo suites ni publicación.

La propuesta de paneles y la de imagen modifican consumidores comunes. Copiar
sus reemplazos por separado podría borrar filtros del otro cambio. Se prepara
un candidato combinado aislado antes de considerar activación; no se aplican
ambos paquetes consecutivamente como si fueran independientes.

## Avance concreto

Se completó un importador local para dos títulos de Salud Digna: teleradiografía
de tórax PA y PA+lateral. Lectura productiva de 12:02 UTC:14 UUID pendientes,
siete por título, originales íntegros por hash, guardas exactas y cero colisiones.
Las tablas de protocolos aún no existen.

El renderer no tiene ejecutor de base. Genera SQL con rollback y una variante
con commit y pin de alcance; ese pin no prueba aprobación del usuario. Conserva
modalidad, anatomía, variante y proyecciones. Cantidad de vistas, postura, lado,
ángulo y comparativo siguen NULL; contraste `unknown`. No añade léxico global
ni ofertas. Hay guardas de dependencias/evidencia por hash, colisiones, fuentes,
contextos ajenos, ledger, auditoría y reprocesamiento acotado.

Artefactos locales revisables bajo
`collectors/artifacts/proposal-imaging-protocols-20261015/importer-20261016/`:
`read_live.py`, `read-receipt.json`, `render_import.py`,
`rollback-PROPOSED.sql`, `commit-PROPOSED.sql`, manifests y `DELIVERY.md`.
Compilación Python y generación completadas; ningún SQL propuesto se ejecutó.
La completitud de los conjuntos de proyecciones continúa como regla propuesta,
sin aceptación clínica por el hecho de haber escrito el importador.

## Brechas detectadas al inicio;estado posterior arriba

1. Rebasar app/types sobre las fuentes comprometidas que coinciden por bytes
   con el código conservado de la publicación. El parche anterior parte del
   árbol sucio e incluiría cambios administrativos ajenos.
2. Conservar originales por entrada antes de retirar preparación, segmentar
   o corregir OCR. El texto global no demuestra que cada calificador permanezca
   unido al estudio. Se necesitan índices únicos, cantidad y orden verificables.
3. Los wrappers usan ordinalidad desde uno y pueden filtrar entradas inválidas
   antes de formar arrays. El decorador debe detectar pérdida de correspondencia
   y no ofrecer una radiografía parcialmente interpretada.
4. Proteger cambios posteriores de modalidad, anatomía y vistas del protocolo,
   además de comprobar su inserción inicial.

Evidencia estática de diez funciones actuales y cuatro archivos API:
`collectors/artifacts/proposal-imaging-protocols-20261015/integration-audit-20261016/`:
`MAP.md`, comparación de fuentes, cuerpos SQL y `function-manifest.json`.
La inspección y la compilación no acreditan ejecución correcta en PostgreSQL,
paquete, OCR o interfaz. No hubo suites formales ni cambios de API/productivo.

Siguiente acción: completar esas brechas en archivos aislados y presentar el
diff con impacto, riesgos, alternativas, verificación y recuperación antes de
solicitar aprobación explícita D-006. El importador por sí solo no autoriza una
migración, publicar la API ni cerrar los 14 registros.

El inventario anterior identificó1,382 filas con marcadores de proyección y 302
con contraste, con solapamiento posible. Son oportunidades de investigación
de un corte histórico; no son cierres prometidos ni aprobaciones extrapolables.
