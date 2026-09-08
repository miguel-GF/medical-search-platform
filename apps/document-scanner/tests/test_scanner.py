import asyncio
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import hashlib
import json
import struct
from unittest.mock import AsyncMock

import httpx
import pytest

from pruevia_document_scanner.clamd import Clamd, MAX_BYTES, ScanError, check_version
from pruevia_document_scanner.worker import Job, Supabase, detect_mime, scan_one


PDF = b"%PDF-1.7\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n"
JOB = Job("00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002",
          "provider-claims/00000000-0000-0000-0000-000000000002/00000000-0000-0000-0000-000000000003.pdf",
          hashlib.sha256(PDF).hexdigest())


def engine(at=None, version="1.5.4"):
    at = at or datetime.now(timezone.utc)
    return f"ClamAV {version}/99999/{at.strftime('%a %b %d %H:%M:%S %Y')}"


class Chunks(httpx.AsyncByteStream):
    def __init__(self, chunks):
        self.chunks = chunks
        self.read = 0
        self.closed = False

    async def __aiter__(self):
        for chunk in self.chunks:
            self.read += 1
            yield chunk

    async def aclose(self):
        self.closed = True


def test_job_rejects_path_escape_and_foreign_claim_before_download():
    for key in ("https://evil.invalid/file.pdf", JOB.object_key.replace("000002/", "000004/"),
                JOB.object_key.replace(".pdf", ".pdf?x=y"), "provider-claims/../x.pdf",
                JOB.object_key.replace("000003.pdf", "------.pdf"),
                JOB.object_key.replace("000000000003.pdf", "00000000000A.pdf")):
        with pytest.raises(ScanError, match="scan_job_invalid"):
            Job.parse(vars(replace(JOB, object_key=key)))


@pytest.mark.parametrize("data,mime", [
    (PDF, "application/pdf"), (b"%PDF-2.0\r", "application/pdf"),
    (b"\x89PNG\r\n\x1a\nmore", "image/png"), (b"\xff\xd8\xffrest", "image/jpeg"),
    (b"<html>fake.pdf</html>", None), (b"%PDF-9.9\n", None), (b"", None),
])
def test_mime_comes_from_bytes(data, mime):
    assert detect_mime(data) == mime


@pytest.mark.parametrize("url", ["", "http://project.supabase.co", "https://user:pass@project.supabase.co",
                                  "https://project.supabase.co/path", "https://project.supabase.co?key=secret",
                                  "https://project.supabase.co#x", "https://project.supabase.co:444"])
def test_invalid_configuration_rejected(url):
    with pytest.raises(ScanError):
        Supabase(url, "secret", None)


def test_download_hash_mime_antivirus_and_record_are_connected():
    async def scenario():
        recorded = []
        av = AsyncMock()
        av.scan.return_value = ("clean", engine())

        async def handler(request):
            assert request.url.host == "project.supabase.co"
            assert request.headers["apikey"] == "private-test-key"
            assert request.headers["accept-encoding"] == "identity"
            if request.method == "GET":
                assert str(request.url).endswith("/storage/v1/object/authenticated/" + JOB.object_key)
                # HTTP MIME is deliberately wrong; only bytes determine MIME.
                return httpx.Response(200, headers={"content-type": "text/html"}, stream=Chunks([PDF[:10], PDF[10:]]))
            body = json.loads(request.content)
            recorded.append(body)
            return httpx.Response(200, json={"document_id": JOB.document_id, "scan_status": "clean", "content_verified": True})

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            result = await scan_one(JOB, Supabase("https://project.supabase.co", "private-test-key", client), av)
        assert result == {"document_id": JOB.document_id, "status": "clean"}
        av.scan.assert_awaited_once_with(PDF)
        assert recorded == [{"p_document_id": JOB.document_id, "p_server_sha256": hashlib.sha256(PDF).hexdigest(),
                             "p_detected_mime": "application/pdf", "p_size_bytes": len(PDF), "p_scan_status": "clean",
                             "p_engine_version": av.scan.return_value[1], "p_error_code": None}]
    asyncio.run(scenario())


@pytest.mark.parametrize("content,job,reason", [
    (b"", JOB, "document_empty"),
    (b"<html>not a PDF</html>", JOB, "document_type_rejected"),
    (PDF + b"tampered", JOB, "document_hash_mismatch"),
    (PDF, replace(JOB, object_key=JOB.object_key.replace(".pdf", ".png")), "document_extension_mismatch"),
])
def test_invalid_content_never_reaches_clean_attestation(content, job, reason):
    async def scenario():
        store, av = AsyncMock(), AsyncMock()
        store.download.return_value = content
        result = await scan_one(job, store, av)
        assert result["reason"] == reason
        assert store.record.call_args.kwargs["status"] == "error"
        av.scan.assert_not_awaited()
    asyncio.run(scenario())


def test_unavailable_antivirus_records_error_not_clean():
    async def scenario():
        store, av = AsyncMock(), AsyncMock()
        store.download.return_value = PDF
        av.scan.side_effect = ScanError("scanner_unavailable")
        assert (await scan_one(JOB, store, av))["status"] == "error"
        assert store.record.call_args.kwargs["reason"] == "scanner_unavailable"
    asyncio.run(scenario())


def test_infected_result_does_not_become_verified():
    async def scenario():
        store, av = AsyncMock(), AsyncMock()
        store.download.return_value = PDF
        av.scan.return_value = ("infected", engine())
        assert (await scan_one(JOB, store, av))["status"] == "infected"
        assert store.record.call_args.kwargs["status"] == "infected"
    asyncio.run(scenario())


@pytest.mark.parametrize("headers,chunks,reason", [
    ({"content-encoding": "gzip"}, [b"bomb"], "upstream_encoding_rejected"),
    ({"content-length": str(MAX_BYTES + 1)}, [b"a"], "upstream_size_rejected"),
    ({"content-length": "-1"}, [b"a"], "upstream_size_rejected"),
    ({"content-length": "1"}, [b"a", b"b"], "upstream_size_mismatch"),
    ({}, [b"a" * MAX_BYTES, b"b", b"must not read"], "upstream_size_rejected"),
])
def test_stream_limits_before_decoding(headers, chunks, reason):
    async def scenario():
        stream = Chunks(chunks)
        async with httpx.AsyncClient(transport=httpx.MockTransport(
                lambda request: httpx.Response(200, headers=headers, stream=stream))) as client:
            store = Supabase("https://project.supabase.co", "secret", client)
            with pytest.raises(ScanError, match=reason):
                await store.download(JOB)
        assert stream.closed
        if len(chunks) == 3:
            assert stream.read == 2
    asyncio.run(scenario())


def test_redirect_does_not_forward_privileged_key():
    async def scenario():
        requests = []
        def handler(request):
            requests.append(request)
            return httpx.Response(302, headers={"location": "https://evil.invalid/"})
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler), follow_redirects=True) as client:
            with pytest.raises(ScanError, match="supabase_request_failed"):
                await Supabase("https://project.supabase.co", "secret", client).download(JOB)
        assert len(requests) == 1
    asyncio.run(scenario())


@pytest.mark.parametrize("reply", [[], {"content_verified": True},
    {"document_id": JOB.document_id, "scan_status": "error", "content_verified": True}])
def test_invalid_rpc_acknowledgment_fails(reply):
    async def scenario():
        async with httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(200, json=reply))) as client:
            with pytest.raises(ScanError, match="scan_record_invalid"):
                await Supabase("https://project.supabase.co", "secret", client).record(
                    JOB, digest=None, mime=None, size=None, status="error", reason="scanner_unavailable")
    asyncio.run(scenario())


@pytest.mark.parametrize("version", ["1.4.5", "1.5.3", "0.103.0", "9.0.0"])
def test_unreviewed_or_vulnerable_engine_rejected(version):
    with pytest.raises(ScanError, match="scanner_engine_unsupported"):
        check_version(engine(version=version), datetime.now(timezone.utc))


@pytest.mark.parametrize("offset", [timedelta(days=-3), timedelta(hours=1)])
def test_stale_or_future_signatures_rejected(offset):
    now = datetime.now(timezone.utc)
    with pytest.raises(ScanError, match="scanner_signatures_stale"):
        check_version(engine(now + offset), now)


class Writer:
    def __init__(self):
        self.data = bytearray()
        self.closed = False
    def write(self, data):
        self.data.extend(data)
    async def drain(self):
        pass
    def close(self):
        self.closed = True
    async def wait_closed(self):
        pass


def connector(replies, writers):
    async def connect(path, limit):
        assert path == "/run/clamav/clamd.sock"
        reader = asyncio.StreamReader(limit=limit)
        reader.feed_data(replies.pop(0))
        reader.feed_eof()
        writer = Writer()
        writers.append(writer)
        return reader, writer
    return connect


def test_clamd_receives_exact_framed_bytes_and_checks_version():
    async def scenario():
        writers = []
        client = Clamd(connector=connector([engine().encode() + b"\0", b"stream: OK\0"], writers))
        assert (await client.scan(PDF))[0] == "clean"
        assert writers[0].data == b"zVERSION\0"
        assert writers[1].data == b"zINSTREAM\0" + struct.pack("!I", len(PDF)) + PDF + b"\0\0\0\0"
        assert all(w.closed for w in writers)
    asyncio.run(scenario())


@pytest.mark.parametrize("reply", [b"stream: scan skipped ERROR\0", b"stream: OK", b"unknown\0", b"x" * 2048 + b"\0"])
def test_clamd_incomplete_or_malformed_result_never_passes(reply):
    async def scenario():
        writers = []
        client = Clamd(connector=connector([engine().encode() + b"\0", reply], writers))
        with pytest.raises(ScanError):
            await client.scan(PDF)
        assert all(w.closed for w in writers)
    asyncio.run(scenario())


@pytest.mark.parametrize("reply", [b"stream: Test-Signature FOUND\0", b"stream: Heuristics.Limits.Exceeded FOUND\0"])
def test_clamd_detection_and_exceeded_limits_both_block(reply):
    async def scenario():
        client = Clamd(connector=connector([engine().encode() + b"\0", reply], []))
        assert (await client.scan(PDF))[0] == "infected"
    asyncio.run(scenario())
