# Cobertura de proveedores de Puebla

La cartera de proveedores se separa en dos niveles para no publicar datos sin
verificación:

* `database/fixtures/generic_provider_mappings_puebla_v1.json` contiene nueve
  identidades candidatas enlazadas a registros DENUE y sus dominios públicos.
  Las identidades se guardan como `verification_pending`; sólo cinco estudios
  tienen equivalencia clínica exacta aprobada.
* El adaptador `pruevia-semin` captura el catálogo público de Laboratorios
  SEMIN. La corrida de control recuperó 140 estudios únicos y nueve
  sucursales (149 registros RAW). Cada precio conserva el estado
  `unverified_provider_reference`, porque el propio catálogo expone fechas de
  actualización antiguas y no prueba vigencia comercial.

Los servicios, descripciones, indicaciones y precios de SEMIN son evidencia
del proveedor, no conceptos clínicos canónicos. No se llaman endpoints de
citas, pacientes o promociones y no se reutilizan credenciales del sitio.

## Captura del catálogo SEMIN

Desde `collectors/`:

```powershell
$env:PYTHONPATH = "src"
python -m pruevia_collectors.cli_semin `
  --max-pages 8 --max-results 150 --max-details 150 `
  --artifact-root artifacts/semin-catalog-puebla
```

La captura respeta `https://semindigital.com/robots.txt`, limita páginas,
filas, bytes, redirecciones y tiempo de respuesta, y escribe únicamente
artefactos RAW/candidate. Si una página de detalle falla, la corrida queda
cuarentenada para que nadie confunda un catálogo parcial con cobertura
completa.

## Incorporación de identidades DENUE

Las nuevas identidades incorporadas como candidatas son Lafer, Verkenlab,
Clínica de Diagnóstico Radiología y Ultrasonido, RIEX Radiología Dental y Labo
Pat Diagnósticos, además de Family Labs, Asesores Diagnóstico Clínico,
Laboratorios Xonaca y SEMIN. La fuente de identidad sigue siendo DENUE; una
fila DENUE no demuestra por sí sola que el sitio ofrezca un estudio.

Para generar SQL idempotente se requieren los artefactos de cada `source_key` y
la revisión humana de las equivalencias. El renderer sólo publica ubicaciones
con coordenadas y ofertas explícitamente mapeadas; todas las demás etiquetas
permanecen en la cola de revisión.

Para inspeccionar la cartera sin tocar la base:

```powershell
python database/scripts/build_puebla_provider_portfolio.py `
  --manifest collectors/artifacts/puebla-generic-depth1-hardened/puebla_generic_discovery_manifest.json `
  --mapping-fixture database/fixtures/generic_provider_mappings_puebla_v1.json `
  --denue-fixture database/fixtures/denue_candidates_puebla_v1.json `
  --output collectors/artifacts/puebla-generic-depth1-hardened/puebla_provider_portfolio.json
```

La salida es sólo un informe de cobertura: no crea marcas, ubicaciones ni
ofertas en Supabase.

En el entorno enlazado de pruebas ya se cargaron las nueve identidades y sus
12 ubicaciones DENUE como `verification_pending`, y la corrida SEMIN de control
se guardó en `ingest` (149 registros). La cola administrativa quedó abierta con
170 pendientes (`normalization_pending`): 140 estudios SEMIN y 30 etiquetas
genéricas clínicas. Esto permite auditar y depurar desde el panel
administrativo sin presentar esos estudios como resultados confirmados a
pacientes.
