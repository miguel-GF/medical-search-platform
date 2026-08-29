from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path

from .config import settings
from .engine import EngineUnavailableError, build_engine, format_order_lines, preprocess_image
from .image import ImageInputError, decode_image_input


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Pruevia local OCR against one image")
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    mime_type = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}.get(args.image.suffix.lower())
    if mime_type is None:
        raise SystemExit("image must have a .jpg, .jpeg, .png or .webp extension")
    try:
        raw = args.image.read_bytes()
        decoded = decode_image_input(
            base64.b64encode(raw).decode("ascii"),
            mime_type,
            max_bytes=settings.max_image_bytes,
            max_pixels=settings.max_image_pixels,
        )
        result = build_engine(settings.engine, settings.min_line_confidence).recognize(preprocess_image(decoded.image))
    except (OSError, ImageInputError, EngineUnavailableError) as exc:
        raise SystemExit(str(exc)) from exc
    lines = format_order_lines(result.lines)
    payload = {
        "text": "\n".join(line.text for line in lines),
        "engine": "python_ocr",
        "model": result.model,
        "input_bytes": len(decoded.raw),
        "confidence": result.confidence,
        "orientation": result.orientation,
        "lines": [{"text": line.text, "confidence": line.confidence} for line in lines],
    }
    print(json.dumps(payload, ensure_ascii=False) if args.as_json else payload["text"])
