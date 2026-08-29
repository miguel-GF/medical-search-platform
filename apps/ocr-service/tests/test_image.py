import base64

import pytest

from pruevia_ocr_service.image import ImageInputError, decode_image_input


PNG_1X1 = base64.b64encode(
    bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63f4fffffff009fb03fd29b8e38a0000000049454e44ae426082")
).decode()


def test_decode_data_url_and_apply_format_limits():
    decoded = decode_image_input(
        f"data:image/png;base64,{PNG_1X1}",
        None,
        max_bytes=1024,
        max_pixels=10,
    )
    assert decoded.mime_type == "image/png"
    assert decoded.image.size == (1, 1)
    assert decoded.raw.startswith(b"\x89PNG")


@pytest.mark.parametrize(
    ("image", "mime_type"),
    [
        ("not-base64", "image/png"),
        ("AAE=", "image/png"),
        (PNG_1X1, "image/jpeg"),
    ],
)
def test_decode_rejects_invalid_image_contents(image, mime_type):
    with pytest.raises(ImageInputError):
        decode_image_input(image, mime_type, max_bytes=1024, max_pixels=10)
