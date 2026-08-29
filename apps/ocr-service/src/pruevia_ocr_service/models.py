from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class OcrRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    image: str = Field(min_length=1, description="Base64 data URL or base64-encoded image")
    mime_type: str | None = Field(default=None, description="Required for raw base64")


class OcrLine(BaseModel):
    text: str
    confidence: float = Field(ge=0.0, le=1.0)
    box: list[list[float]] | None = None


class OcrResponse(BaseModel):
    text: str
    engine: str
    model: str
    input_bytes: int = Field(ge=1)
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    orientation: int = Field(ge=0, le=270)
    lines: list[OcrLine]


class ErrorResponse(BaseModel):
    error: dict[str, str]
