from __future__ import annotations

import base64
import binascii
import re
from dataclasses import dataclass
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError


ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
_DATA_URL_RE = re.compile(r"^data:(image/(?:jpeg|png|webp));base64,([a-z0-9+/=\s]+)$", re.IGNORECASE)


class ImageInputError(ValueError):
    """The client sent an invalid or unsafe image."""


@dataclass(frozen=True)
class DecodedImage:
    raw: bytes
    mime_type: str
    image: Image.Image


def decode_image_input(
    image: str,
    mime_type: str | None,
    *,
    max_bytes: int,
    max_pixels: int,
) -> DecodedImage:
    encoded = image.strip()
    declared_mime = (mime_type or "").strip().lower()
    match = _DATA_URL_RE.fullmatch(encoded)
    if match:
        declared_mime = match.group(1).lower()
        encoded = match.group(2)
    if declared_mime not in ALLOWED_MIME_TYPES:
        raise ImageInputError("mime_type must be image/jpeg, image/png or image/webp")
    encoded = re.sub(r"\s+", "", encoded)
    if not encoded or len(encoded) > ((max_bytes + 2) // 3) * 4 + 64:
        raise ImageInputError("image base64 is invalid or exceeds the 5 MiB limit")
    if not re.fullmatch(r"[a-z0-9+/]+={0,2}", encoded, re.IGNORECASE) or len(encoded) % 4 == 1:
        raise ImageInputError("image base64 is invalid")
    try:
        raw = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ImageInputError("image base64 is invalid") from exc
    if not 1 <= len(raw) <= max_bytes:
        raise ImageInputError(f"image must be between 1 byte and {max_bytes} bytes")
    if not _has_signature(raw, declared_mime):
        raise ImageInputError("image bytes do not match the declared MIME type")
    try:
        with Image.open(BytesIO(raw)) as opened:
            width, height = opened.size
            if width < 1 or height < 1 or width * height > max_pixels:
                raise ImageInputError("image dimensions exceed the configured safety limit")
            opened.load()
            normalized = ImageOps.exif_transpose(opened).convert("RGB")
    except ImageInputError:
        raise
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError) as exc:
        raise ImageInputError("image contents could not be decoded") from exc
    return DecodedImage(raw=raw, mime_type=declared_mime, image=normalized)


def _has_signature(raw: bytes, mime_type: str) -> bool:
    if mime_type == "image/jpeg":
        return len(raw) >= 3 and raw[:3] == b"\xff\xd8\xff"
    if mime_type == "image/png":
        return raw.startswith(b"\x89PNG\r\n\x1a\n")
    return len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP"
