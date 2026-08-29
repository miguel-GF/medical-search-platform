from __future__ import annotations

import uvicorn

from .config import settings


def main() -> None:
    uvicorn.run("pruevia_ocr_service.app:app", host=settings.host, port=settings.port, reload=False)
