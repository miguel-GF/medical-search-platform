# Pruevia OCR Service

Servicio FastAPI privado para OCR local de órdenes médicas. Vive dentro del
monorepo, pero se ejecuta como proceso Python separado del Worker Cloudflare.
No guarda imágenes ni decide equivalencias clínicas: devuelve texto y
confianza para que el Worker lo entregue al resolver v6.

## Desarrollo local

Desde esta carpeta:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --constraint constraints.txt -e ".[dev]"
$env:OCR_SERVICE_TOKEN = "dev-secret"
python -m uvicorn pruevia_ocr_service.app:app --host 127.0.0.1 --port 8000
```

Health:

```powershell
curl.exe http://127.0.0.1:8000/health
```

Para probar una receta local sin levantar HTTP:

```powershell
pruevia-ocr-scan --image "C:\ruta\orden.jpg" --json
```

The default engine is RapidOCR `3.9.2` with ONNX Runtime on CPU. Production
images pre-bundle the three required ONNX models into `/opt/pruevia/models`
and load them read-only; a missing model returns `503` and never triggers a
runtime download. For local development, set `OCR_MODEL_ROOT` to the
`rapidocr/models` directory inside the active virtualenv. Use
`OCR_ENGINE=rapidocr` explicitly in production. If dependencies or models are
missing, the endpoint returns `503` instead of returning guessed text.
The checked-in `constraints.txt` pins the runtime and test dependency graph;
update it only with a vulnerability review.

## Contract

`POST /v1/ocr/order` accepts:

```json
{
  "image": "data:image/jpeg;base64,...",
  "mime_type": "image/jpeg"
}
```

`mime_type` is only needed for raw base64. The response contains `text`,
per-line confidence, selected orientation, engine and model. The service
accepts JPEG, PNG and WebP, limits images to 5 MiB by default and rejects
content whose bytes do not match the declared MIME type.

Set `OCR_SERVICE_TOKEN` for every non-local deployment. The Cloudflare Worker
will send it as a Bearer token when `OCR_SERVICE_URL` is configured. If the
secret is missing, `/v1/ocr/order` fails closed with `503 ocr_not_configured`;
only `/health` remains public. A non-loopback deployment also rejects the
placeholder and tokens shorter than 32 UTF-8 bytes. Keep this service behind
HTTPS and add provider-level rate limiting before public use.

## Testing

```powershell
pytest -q
```
