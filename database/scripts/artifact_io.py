"""Bounded readers for collector artifacts used by offline renderers."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from urllib.parse import urlparse, urlunparse


MAX_ARTIFACT_ROWS = 100_000
MAX_ARTIFACT_LINE_BYTES = 2 * 1024 * 1024
# A row/line cap alone still permits a multi-gigabyte artifact. Keep offline
# renderers fail-closed before their parsed object graph can exhaust memory.
MAX_ARTIFACT_BYTES = 256 * 1024 * 1024
MAX_MANIFEST_BYTES = 256 * 1024
MAX_FIXTURE_BYTES = 8 * 1024 * 1024


def iter_jsonl(path: Path):
    """Yield JSONL rows with independent line, file and row ceilings."""

    total_bytes = 0
    row_count = 0
    with path.open("rb") as handle:
        while True:
            raw_line = handle.readline(MAX_ARTIFACT_LINE_BYTES + 1)
            if not raw_line:
                break
            total_bytes += len(raw_line)
            if total_bytes > MAX_ARTIFACT_BYTES:
                raise ValueError(f"artifact exceeds {MAX_ARTIFACT_BYTES} bytes")
            if len(raw_line) > MAX_ARTIFACT_LINE_BYTES:
                raise ValueError(f"artifact line exceeds {MAX_ARTIFACT_LINE_BYTES} bytes")
            line = raw_line.decode("utf-8").strip()
            if not line:
                continue
            if row_count >= MAX_ARTIFACT_ROWS:
                raise ValueError(f"artifact exceeds {MAX_ARTIFACT_ROWS} rows")
            row = json.loads(line)
            if not isinstance(row, dict):
                raise ValueError("artifact rows must be JSON objects")
            row_count += 1
            yield row


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    """Read JSONL without buffering unbounded lines, files or row counts."""

    return list(iter_jsonl(path))


def read_json_file(path: Path, *, max_bytes: int = MAX_MANIFEST_BYTES) -> Any:
    """Read a small JSON manifest/fixture with an explicit byte cap."""

    if max_bytes < 1 or max_bytes > MAX_FIXTURE_BYTES:
        raise ValueError("invalid JSON file safety limit")
    with path.open("rb") as handle:
        raw = handle.read(max_bytes + 1)
    if len(raw) > max_bytes:
        raise ValueError(f"JSON file exceeds {max_bytes} bytes")
    return json.loads(raw.decode("utf-8"))


def safe_http_url(value: object, *, max_length: int = 2048) -> str | None:
    """Keep only credential-free HTTP(S) origins/paths from untrusted data."""

    if not isinstance(value, str) or not value.strip() or len(value) > max_length:
        return None
    try:
        parsed = urlparse(value.strip())
        hostname = parsed.hostname
        username = parsed.username
        password = parsed.password
    except ValueError:
        return None
    if parsed.scheme not in {"http", "https"} or not hostname or username or password:
        return None
    return urlunparse(parsed._replace(query="", fragment=""))
