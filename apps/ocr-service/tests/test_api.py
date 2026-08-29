import base64
from dataclasses import replace

from fastapi.testclient import TestClient

from pruevia_ocr_service.app import create_app
from pruevia_ocr_service.config import settings
from pruevia_ocr_service.engine import EngineResult, RecognizedLine


PNG_1X1 = base64.b64encode(
    bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63f4fffffff009fb03fd29b8e38a0000000049454e44ae426082")
).decode()


def fake_engine_factory(_name: str, _min_confidence: float):
    class FakeEngine:
        def recognize(self, _image):
            return EngineResult(
                lines=[
                    RecognizedLine("Rx.", 0.99),
                    RecognizedLine("B.H.", 0.91),
                    RecognizedLine("EGO", 0.95),
                    RecognizedLine("Nombre: paciente", 0.99),
                ],
                confidence=0.95,
                orientation=90,
                model="fake",
            )

    return FakeEngine()


def test_health_and_order_transcription_are_non_persistent():
    app = create_app(app_settings=replace(settings, service_token="secret"), engine_factory=fake_engine_factory)
    client = TestClient(app)
    assert client.get("/health").json() == {"status": "ok", "service": "pruevia-ocr", "engine": settings.engine}
    response = client.post(
        "/v1/ocr/order",
        headers={"Authorization": "Bearer secret"},
        json={"image": f"data:image/png;base64,{PNG_1X1}"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["text"] == "B.H.\nEGO"
    assert payload["engine"] == "python_ocr"
    assert payload["orientation"] == 90
    assert payload["input_bytes"] > 0


def test_order_requires_token_when_configured():
    app = create_app(app_settings=replace(settings, service_token="secret"), engine_factory=fake_engine_factory)
    response = TestClient(app).post(
        "/v1/ocr/order",
        json={"image": f"data:image/png;base64,{PNG_1X1}"},
    )
    assert response.status_code == 401


def test_order_lines_merge_same_row_and_drop_footer():
    from pruevia_ocr_service.engine import format_order_lines

    lines = format_order_lines([
        RecognizedLine("Rx", 0.99, [[0, 0], [20, 0], [20, 10], [0, 10]]),
        RecognizedLine("OQS", 0.90, [[0, 20], [30, 20], [30, 40], [0, 40]]),
        RecognizedLine("completa", 0.88, [[34, 22], [90, 22], [90, 38], [34, 38]]),
        RecognizedLine("Horario", 0.99, [[0, 60], [50, 60], [50, 70], [0, 70]]),
        RecognizedLine("Selud Dine.", 0.99, [[0, 80], [50, 80], [50, 90], [0, 90]]),
    ])
    assert [line.text for line in lines] == ["OQS completa"]
