import json
from pathlib import Path

import pytest

from database.scripts import artifact_io


def test_jsonl_reader_rejects_oversized_line(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    path = tmp_path / "rows.jsonl"
    monkeypatch.setattr(artifact_io, "MAX_ARTIFACT_LINE_BYTES", 8)
    path.write_bytes(b'{"value": 1}\n')

    with pytest.raises(ValueError, match="line exceeds"):
        artifact_io.read_jsonl(path)


def test_jsonl_reader_rejects_oversized_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    path = tmp_path / "rows.jsonl"
    monkeypatch.setattr(artifact_io, "MAX_ARTIFACT_BYTES", 10)
    path.write_text(json.dumps({"value": 1}) + "\n", encoding="utf-8")

    with pytest.raises(ValueError, match="artifact exceeds"):
        artifact_io.read_jsonl(path)


def test_json_file_limit_is_explicit(tmp_path: Path):
    path = tmp_path / "fixture.json"
    path.write_text(json.dumps({"value": "12345"}), encoding="utf-8")

    with pytest.raises(ValueError, match="JSON file exceeds 8 bytes"):
        artifact_io.read_json_file(path, max_bytes=8)


def test_safe_http_url_removes_signed_material_and_credentials():
    assert artifact_io.safe_http_url("https://example.test/study?token=secret#fragment") == "https://example.test/study"
    assert artifact_io.safe_http_url("https://user:pass@example.test/study") is None
