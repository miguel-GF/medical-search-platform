import httpx
import pytest

from pruevia_collectors.providers.http import bounded_response_bytes


class Chunks(httpx.SyncByteStream):
    def __init__(self, chunks):
        self.chunks = chunks
        self.read = 0

    def __iter__(self):
        for chunk in self.chunks:
            self.read += 1
            yield chunk


def test_bounded_reader_handles_materialized_response():
    assert bounded_response_bytes(httpx.Response(200, content=b"abc")) == b"abc"


@pytest.mark.parametrize("headers,chunks", [
    ({"content-encoding": "gzip"}, [b"small"]),
    ({"content-length": "-1"}, [b"small"]),
    ({"content-length": "99999999"}, [b"small"]),
])
def test_bounded_reader_rejects_unsafe_headers(headers, chunks):
    stream = Chunks(chunks)
    with pytest.raises(ValueError):
        bounded_response_bytes(httpx.Response(200, headers=headers, stream=stream))
    assert stream.read == 0


def test_bounded_reader_stops_before_reading_a_byte_over_limit():
    stream = Chunks([b"a" * 1024, b"b", b"must-not-read"])
    with pytest.raises(ValueError, match="byte limit"):
        bounded_response_bytes(httpx.Response(200, stream=stream), max_bytes=1024)
    assert stream.read == 2


def test_bounded_reader_rejects_truncated_content_length():
    with pytest.raises(ValueError, match="length mismatch"):
        bounded_response_bytes(httpx.Response(200, headers={"content-length": "4"}, content=b"abc"))
