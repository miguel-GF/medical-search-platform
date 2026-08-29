from __future__ import annotations

import os
from dataclasses import dataclass


def _int_env(name: str, default: int, minimum: int, maximum: int) -> int:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return default
    try:
        parsed = int(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer") from exc
    if not minimum <= parsed <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return parsed


def _float_env(name: str, default: float, minimum: float, maximum: float) -> float:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return default
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be a number") from exc
    if not minimum <= parsed <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return parsed


@dataclass(frozen=True)
class Settings:
    service_token: str = os.getenv("OCR_SERVICE_TOKEN", "").strip()
    engine: str = os.getenv("OCR_ENGINE", "rapidocr").strip().lower() or "rapidocr"
    min_line_confidence: float = _float_env("OCR_MIN_LINE_CONFIDENCE", 0.30, 0.0, 1.0)
    max_image_bytes: int = _int_env("OCR_MAX_IMAGE_BYTES", 5 * 1024 * 1024, 1, 20 * 1024 * 1024)
    max_image_pixels: int = _int_env("OCR_MAX_IMAGE_PIXELS", 25_000_000, 1, 100_000_000)
    host: str = os.getenv("OCR_HOST", "127.0.0.1")
    port: int = _int_env("OCR_PORT", 8000, 1, 65_535)


settings = Settings()
