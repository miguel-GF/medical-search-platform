from __future__ import annotations

import asyncio
import secrets
from typing import Callable

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse

from .config import Settings, settings
from .engine import EngineResult, EngineUnavailableError, OcrEngine, build_engine, format_order_lines, preprocess_image
from .image import ImageInputError, decode_image_input
from .models import OcrRequest, OcrResponse


def create_app(
    *,
    app_settings: Settings = settings,
    engine_factory: Callable[[str, float], OcrEngine] = build_engine,
) -> FastAPI:
    application = FastAPI(title="Pruevia OCR Service", version="0.1.0", docs_url=None, redoc_url=None)
    engine_holder: list[OcrEngine | None] = [None]
    engine_error: list[EngineUnavailableError | None] = [None]

    @application.middleware("http")
    async def body_limit(request: Request, call_next):
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > app_settings.max_image_bytes * 2:
                    return JSONResponse({"error": {"code": "payload_too_large", "message": "request body is too large"}}, status_code=413)
            except ValueError:
                pass
        return await call_next(request)

    async def require_token(request: Request) -> None:
        if not app_settings.service_token:
            return
        header = request.headers.get("authorization", "")
        scheme, _, value = header.partition(" ")
        if scheme.lower() != "bearer" or not secrets.compare_digest(value, app_settings.service_token):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "unauthorized", "message": "OCR service token required"})

    @application.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "pruevia-ocr", "engine": app_settings.engine}

    @application.post("/v1/ocr/order", response_model=OcrResponse, dependencies=[Depends(require_token)])
    async def recognize_order(payload: OcrRequest) -> OcrResponse:
        try:
            decoded = decode_image_input(
                payload.image,
                payload.mime_type,
                max_bytes=app_settings.max_image_bytes,
                max_pixels=app_settings.max_image_pixels,
            )
        except ImageInputError as exc:
            raise HTTPException(status_code=400, detail={"code": "invalid_image", "message": str(exc)}) from exc
        try:
            if engine_error[0] is not None:
                raise engine_error[0]
            if engine_holder[0] is None:
                try:
                    engine_holder[0] = engine_factory(app_settings.engine, app_settings.min_line_confidence)
                except EngineUnavailableError as exc:
                    engine_error[0] = exc
                    raise
            engine = engine_holder[0]
            result = await asyncio.to_thread(engine.recognize, preprocess_image(decoded.image))
        except EngineUnavailableError as exc:
            raise HTTPException(status_code=503, detail={"code": "ocr_unavailable", "message": str(exc)}) from exc
        except Exception as exc:
            raise HTTPException(status_code=502, detail={"code": "ocr_failed", "message": "image could not be transcribed safely"}) from exc
        lines = format_order_lines(result.lines)
        text = "\n".join(line.text for line in lines).strip()
        if not text:
            raise HTTPException(status_code=422, detail={"code": "ocr_unusable", "message": "no readable order text was found"})
        return _response(text, decoded.raw, result, lines)

    return application


def _response(text: str, raw: bytes, result: EngineResult, lines) -> OcrResponse:
    from .models import OcrLine

    return OcrResponse(
        text=text[:4000],
        engine="python_ocr",
        model=result.model,
        input_bytes=len(raw),
        confidence=result.confidence,
        orientation=result.orientation,
        lines=[OcrLine(text=line.text, confidence=line.confidence, box=line.box) for line in lines],
    )


app = create_app()
