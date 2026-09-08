from pathlib import Path

import pytest

from pruevia_ocr_service.image import ImageInputError
from pruevia_ocr_service.scan import _read_image_bounded


def test_local_scan_reader_rejects_oversized_file_without_unbounded_read(tmp_path: Path):
    image_path = tmp_path / "oversized.png"
    image_path.write_bytes(b"x" * 11)

    with pytest.raises(ImageInputError, match="between 1 byte and 10 bytes"):
        _read_image_bounded(image_path, 10)


def test_local_scan_reader_accepts_file_at_limit(tmp_path: Path):
    image_path = tmp_path / "image.png"
    image_path.write_bytes(b"x" * 10)

    assert _read_image_bounded(image_path, 10) == b"x" * 10
