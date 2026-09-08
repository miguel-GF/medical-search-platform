from __future__ import annotations

import asyncio
import secrets
from typing import Callable

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from .config import Settings, settings
from .engine import EngineResult, EngineUnavailableError, OcrEngine, build_engine, format_order_lines, preprocess_image
from .image import ImageInputError, decode_image_input
from .models import OcrRequest, OcrResponse

MIN_EXTERNAL_SERVICE_TOKEN_BYTES = 32
INSECURE_SERVICE_TOKENS = frozenset({"change-me-for-non-local-deployments"})


def _service_token_is_usable(app_settings: Settings) -> bool:
    token = app_settings.service_token
    if not token or token in INSECURE_SERVICE_TOKENS:
        return False
    # A container bound to a non-loopback interface is potentially reachable
    # by other hosts. Do not let a short development secret protect that
    # surface; local loopback tests may intentionally use a short token.
    host = app_settings.host.strip().lower().strip("[]")
    if host not in {"localhost", "127.0.0.1", "::1"} and len(token.encode("utf-8")) < MIN_EXTERNAL_SERVICE_TOKEN_BYTES:
        return False
    return True


class OcrRequestSecurityMiddleware:
    """Authenticate and cap OCR bodies before FastAPI/Pydantic buffer JSON."""

    def __init__(self, app: ASGIApp, *, app_settings: Settings) -> None:
        self.app = app
        self.settings = app_settings
        # Base64 expands input by 4/3. Keep a small allowance for the JSON
        # envelope while maintaining a deterministic upper bound.
        self.maximum = ((app_settings.max_image_bytes + 2) // 3) * 4 + 16_384

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or (scope.get("path") == "/health" and scope.get("method") == "GET"):
            await self.app(scope, receive, send)
            return

        raw_headers = [(key.lower(), value) for key, value in scope.get("headers", [])]
        if not _service_token_is_usable(self.settings):
            await self._json(
                scope,
                receive,
                send,
                503,
                {"detail": {"code": "ocr_not_configured", "message": "OCR service token is not configured"}},
            )
            return
        content_encoding_values = [value for key, value in raw_headers if key == b"content-encoding"]
        if len(content_encoding_values) > 1 or (
            content_encoding_values
            and content_encoding_values[0].strip().lower() not in (b"", b"identity")
        ):
            await self._json(
                scope,
                receive,
                send,
                415,
                {"error": {"code": "unsupported_content_encoding", "message": "compressed request bodies are not supported"}},
            )
            return
        # Different proxies/frameworks choose the first or last duplicate
        # header. Reject ambiguity before authentication or body handling so a
        # smuggled Authorization/Content-Length cannot be interpreted twice.
        authorization_values = [value for key, value in raw_headers if key == b"authorization"]
        if len(authorization_values) != 1:
            await self._json(
                scope,
                receive,
                send,
                401,
                {"detail": {"code": "unauthorized", "message": "OCR service token required"}},
            )
            return
        content_lengths = [value for key, value in raw_headers if key == b"content-length"]
        if len(content_lengths) > 1:
            await self._too_large(scope, receive, send)
            return
        headers = dict(raw_headers)
        authorization = authorization_values[0]
        scheme, _, token = authorization.partition(b" ")
        if scheme.lower() != b"bearer" or not secrets.compare_digest(token, self.settings.service_token.encode()):
            await self._json(
                scope,
                receive,
                send,
                401,
                {"detail": {"code": "unauthorized", "message": "OCR service token required"}},
            )
            return

        raw_length = headers.get(b"content-length")
        if raw_length:
            try:
                content_length = int(raw_length)
            except ValueError:
                await self._too_large(scope, receive, send)
                return
            if content_length < 0 or content_length > self.maximum:
                await self._too_large(scope, receive, send)
                return

        # Consume at most the configured cap before handing the request to
        # FastAPI. This handles chunked requests and dishonest/missing
        # Content-Length without ever accumulating an unbounded body.
        body = bytearray()
        deadline = asyncio.get_running_loop().time() + 15
        while True:
            try:
                remaining = deadline - asyncio.get_running_loop().time()
                message = await asyncio.wait_for(receive(), timeout=max(0, remaining))
            except asyncio.TimeoutError:
                await self._json(scope, receive, send, 408, {"error": {"code": "request_timeout", "message": "request body timed out"}})
                return
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(body) + len(chunk) > self.maximum:
                await self._too_large(scope, receive, send)
                return
            body.extend(chunk)
            if not message.get("more_body", False):
                break

        replayed = False

        async def replay_receive() -> Message:
            nonlocal replayed
            if not replayed:
                replayed = True
                content = bytes(body)
                body.clear()
                return {"type": "http.request", "body": content, "more_body": False}
            return {"type": "http.disconnect"}

        await self.app(scope, replay_receive, send)

    @staticmethod
    async def _json(scope: Scope, receive: Receive, send: Send, status_code: int, payload: dict) -> None:
        await JSONResponse(payload, status_code=status_code)(scope, receive, send)

    async def _too_large(self, scope: Scope, receive: Receive, send: Send) -> None:
        await self._json(
            scope,
            receive,
            send,
            413,
            {"error": {"code": "payload_too_large", "message": "request body is too large"}},
        )


def create_app(
    *,
    app_settings: Settings = settings,
    engine_factory: Callable[[str, float], OcrEngine] = build_engine,
) -> FastAPI:
    # This service is an internal sidecar. Do not publish an OpenAPI schema
    # that would advertise its authenticated OCR surface even if a proxy is
    # accidentally configured too broadly.
    application = FastAPI(
        title="Pruevia OCR Service",
        version="0.1.0",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    engine_holder: list[OcrEngine | None] = [None]
    engine_error: list[EngineUnavailableError | None] = [None]

    application.add_middleware(OcrRequestSecurityMiddleware, app_settings=app_settings)

    async def require_token(request: Request) -> None:
        if not _service_token_is_usable(app_settings):
            # This service is private by design. A missing secret must never
            # silently downgrade the endpoint to a public, unauthenticated
            # OCR oracle (which could be abused for compute and data leakage).
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={"code": "ocr_not_configured", "message": "OCR service token is not configured"},
            )
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
            # Engine initialization errors can include filesystem paths,
            # package versions, or model details. Keep those diagnostics in
            # server logs only; the sidecar response must not disclose its
            # runtime layout to callers.
            raise HTTPException(
                status_code=503,
                detail={"code": "ocr_unavailable", "message": "OCR engine is temporarily unavailable"},
            ) from exc
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
