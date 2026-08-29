from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Protocol

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


@dataclass(frozen=True)
class RecognizedLine:
    text: str
    confidence: float
    box: list[list[float]] | None = None


@dataclass(frozen=True)
class EngineResult:
    lines: list[RecognizedLine]
    confidence: float | None
    orientation: int
    model: str


class OcrEngine(Protocol):
    name: str

    def recognize(self, image: Image.Image) -> EngineResult:
        ...


class EngineUnavailableError(RuntimeError):
    """The configured OCR engine is not installed or cannot initialize."""


class RapidOcrEngine:
    name = "rapidocr"

    def __init__(self, min_line_confidence: float = 0.30) -> None:
        try:
            import numpy as np
            from rapidocr import RapidOCR
        except ImportError as exc:
            raise EngineUnavailableError("rapidocr and onnxruntime are required") from exc
        self._np = np
        try:
            self._engine = RapidOCR()
        except Exception as exc:
            raise EngineUnavailableError("rapidocr models could not be initialized") from exc
        self._min_line_confidence = min_line_confidence

    def recognize(self, image: Image.Image) -> EngineResult:
        candidates: list[EngineResult] = []
        for angle in (0, 90, 180, 270):
            rotated = image.rotate(angle, expand=True) if angle else image
            result = self._engine(self._np.asarray(rotated), use_det=True, use_cls=True, use_rec=True)
            lines = _result_lines(result, self._min_line_confidence)
            if lines:
                candidates.append(EngineResult(
                    lines=lines,
                    confidence=_mean_confidence(lines),
                    orientation=angle,
                    model="PP-OCRv6_rec_small",
                ))
        if not candidates:
            return EngineResult(lines=[], confidence=None, orientation=0, model="PP-OCRv6_rec_small")
        return max(candidates, key=_orientation_score)


def preprocess_image(image: Image.Image) -> Image.Image:
    """Apply cheap, deterministic cleanup before OCR without changing semantics."""
    normalized = ImageOps.exif_transpose(image).convert("RGB")
    width, height = normalized.size
    scale = min(2.0, max(1.0, 1600 / max(width, height)))
    if scale > 1:
        normalized = normalized.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    gray = ImageOps.grayscale(normalized)
    gray = ImageOps.autocontrast(gray, cutoff=1)
    gray = ImageEnhance.Sharpness(gray).enhance(1.25)
    return gray.filter(ImageFilter.MedianFilter(size=3))


def build_engine(engine_name: str, min_line_confidence: float) -> OcrEngine:
    if engine_name == "rapidocr":
        return RapidOcrEngine(min_line_confidence=min_line_confidence)
    raise EngineUnavailableError(f"unsupported OCR_ENGINE: {engine_name}")


def format_order_lines(lines: list[RecognizedLine]) -> list[RecognizedLine]:
    """Drop obvious form metadata while preserving uncertain study text."""
    metadata = re.compile(
        r"^(?:nombre|fecha|m[eé]dico|especialista|egresado|post[- ]?graduado|c[eé]dula|"
        r"s\.s\.a\.?|d\.g\.p\.?|consulta|consultorio|horario|domicilio|tel[eé]fono|"
        r"centro|hospital|universidad|imss|"
        r"firma|(?:salud|selud)\s+d\w*|de\s+lunes|de\s+\d|a\s+\d)\b",
        re.IGNORECASE,
    )
    marker = re.compile(r"^(?:rx|receta|estudios?|solicitud)\b", re.IGNORECASE)
    marker_index = next((index for index, line in enumerate(lines) if marker.search(line.text.strip())), None)
    selected = lines[marker_index + 1:] if marker_index is not None else lines
    return [line for line in _merge_lines(selected) if line.text.strip() and not metadata.search(line.text.strip())]


def _merge_lines(lines: list[RecognizedLine]) -> list[RecognizedLine]:
    """Join tokens detected on the same handwritten/printed row."""
    merged: list[RecognizedLine] = []
    for line in lines:
        if not merged or not _same_row(merged[-1], line):
            merged.append(line)
            continue
        previous = merged.pop()
        previous_x = _box_x(previous.box)
        current_x = _box_x(line.box)
        ordered = (previous, line) if previous_x <= current_x else (line, previous)
        box = _union_boxes(previous.box, line.box)
        merged.append(RecognizedLine(
            text=" ".join(part.text for part in ordered),
            confidence=round(min(part.confidence for part in ordered), 4),
            box=box,
        ))
    return merged


def _same_row(left: RecognizedLine, right: RecognizedLine) -> bool:
    if not left.box or not right.box:
        return False
    left_top, left_bottom = _box_y(left.box)
    right_top, right_bottom = _box_y(right.box)
    shortest_height = min(left_bottom - left_top, right_bottom - right_top)
    if shortest_height <= 0:
        return False
    left_center = (left_top + left_bottom) / 2
    right_center = (right_top + right_bottom) / 2
    return abs(left_center - right_center) <= shortest_height * 0.45


def _box_x(box: list[list[float]] | None) -> float:
    return sum(point[0] for point in box) / len(box) if box else float("inf")


def _box_y(box: list[list[float]]) -> tuple[float, float]:
    ys = [point[1] for point in box]
    return min(ys), max(ys)


def _union_boxes(left: list[list[float]] | None, right: list[list[float]] | None) -> list[list[float]] | None:
    if not left:
        return right
    if not right:
        return left
    points = left + right
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return [[min(xs), min(ys)], [max(xs), min(ys)], [max(xs), max(ys)], [min(xs), max(ys)]]


def _result_lines(result: Any, min_line_confidence: float) -> list[RecognizedLine]:
    raw_texts = getattr(result, "txts", None)
    raw_scores = getattr(result, "scores", None)
    raw_boxes = getattr(result, "boxes", None)
    texts = list(raw_texts) if raw_texts is not None else []
    scores = list(raw_scores) if raw_scores is not None else []
    boxes = list(raw_boxes) if raw_boxes is not None else []
    lines: list[RecognizedLine] = []
    for index, text in enumerate(texts):
        value = str(text).strip()
        confidence = float(scores[index]) if index < len(scores) else 0.0
        if not value or confidence < min_line_confidence:
            continue
        box = boxes[index].tolist() if index < len(boxes) and hasattr(boxes[index], "tolist") else None
        lines.append(RecognizedLine(text=value, confidence=max(0.0, min(confidence, 1.0)), box=box))
    return _sort_lines(lines)


def _sort_lines(lines: list[RecognizedLine]) -> list[RecognizedLine]:
    def position(line: RecognizedLine) -> tuple[float, float]:
        if not line.box:
            return (float("inf"), float("inf"))
        y = sum(point[1] for point in line.box) / len(line.box)
        x = sum(point[0] for point in line.box) / len(line.box)
        return (y, x)

    return sorted(lines, key=position)


def _orientation_score(result: EngineResult) -> float:
    text = " ".join(line.text for line in result.lines).lower()
    study_signals = re.findall(
        r"\b(?:rx|bh|b\s*h|qs|q\s*s|ego|orina|perfil|glucosa|hemograma|qu[ií]m|"
        r"electro|ultra|eco|resonancia|tomograf|biometr)\w*\b",
        text,
    )
    metadata = re.findall(r"\b(?:nombre|fecha|horario|consulta|c[eé]dula|m[eé]dico)\b", text)
    return len(study_signals) * 4 + len(result.lines) * 0.05 + (result.confidence or 0) - len(metadata) * 0.2


def _mean_confidence(lines: list[RecognizedLine]) -> float | None:
    return round(sum(line.confidence for line in lines) / len(lines), 4) if lines else None
