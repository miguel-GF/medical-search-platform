from pathlib import Path

import pytest

from pruevia_collectors.cli_chopo import (
    MAX_PRODUCT_URL_FILE_BYTES,
    MAX_PRODUCT_URL_LINE_BYTES,
    _read_product_urls,
)


def test_product_url_file_is_bounded_and_comments_are_ignored(tmp_path: Path) -> None:
    path = tmp_path / "urls.txt"
    path.write_text("# reviewed\n https://www.chopo.com.mx/puebla/a \n\nhttps://www.chopo.com.mx/puebla/b\n", encoding="utf-8")

    assert _read_product_urls(path) == [
        "https://www.chopo.com.mx/puebla/a",
        "https://www.chopo.com.mx/puebla/b",
    ]


def test_product_url_file_rejects_oversized_input(tmp_path: Path) -> None:
    path = tmp_path / "urls.txt"
    path.write_bytes(b"x" * (MAX_PRODUCT_URL_FILE_BYTES + 1))
    with pytest.raises(ValueError, match="exceeds the safety limit"):
        _read_product_urls(path)


def test_product_url_file_rejects_oversized_line_and_url_count(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    line_path = tmp_path / "long-line.txt"
    line_path.write_bytes(b"x" * (MAX_PRODUCT_URL_LINE_BYTES + 1))
    with pytest.raises(ValueError, match="line exceeds"):
        _read_product_urls(line_path)

    count_path = tmp_path / "many.txt"
    count_path.write_text("\n".join(f"https://www.chopo.com.mx/puebla/{i}" for i in range(3)), encoding="utf-8")
    monkeypatch.setattr("pruevia_collectors.cli_chopo.MAX_PRODUCT_URLS", 2)
    with pytest.raises(ValueError, match="too many URLs"):
        _read_product_urls(count_path)
