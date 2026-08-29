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
python -m pip install -e ".[dev]"
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

The default engine is RapidOCR with ONNX Runtime on CPU. Its models are local
and are loaded on process start; the first inference is slower. Use
`OCR_ENGINE=rapidocr` explicitly in production. If dependencies or models are
missing, the endpoint returns `503` instead of returning guessed text.

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
will send it as a Bearer token when `OCR_SERVICE_URL` is configured. Keep this
service behind HTTPS and add provider-level rate limiting before public use.

## Testing

```powershell
pytest -q
```
