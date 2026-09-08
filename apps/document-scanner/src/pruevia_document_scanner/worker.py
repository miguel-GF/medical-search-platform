"""Private one-batch worker. No public HTTP server; no document bytes in logs."""
from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass
import hashlib
import json
import os
import re
from urllib.parse import urlsplit
from uuid import UUID

import httpx

from .clamd import Clamd, MAX_BYTES, ScanError


# Supabase's private-object route uses the literal `authenticated` access
# segment before the bucket name. Keep the bucket coupled to the database
# migrations so a future rename cannot silently read another object class.
PROVIDER_CLAIMS_BUCKET = "provider-claims"
PRIVATE_OBJECT_ROUTE = "authenticated"


@dataclass(frozen=True)
class Job:
    document_id: str
    claim_id: str
    object_key: str
    submitted_sha256: str

    @classmethod
    def parse(cls, value: object) -> Job:
        try:
            if not isinstance(value, dict):
                raise ValueError
            document_id = str(UUID(value["document_id"]))
            claim_id = str(UUID(value["claim_id"]))
            key, digest = value["object_key"], value["submitted_sha256"]
            # Storage object keys are canonical lowercase UUID paths. Reject
            # alternate-case spellings here as well, so queue validation,
            # download authorization and quota accounting share one identity.
            if not isinstance(key, str) or not re.fullmatch(
                    rf"provider-claims/{claim_id}/[0-9a-f-]{{36}}\.(?:pdf|jpg|jpeg|png)", key):
                raise ValueError
            UUID(key.rsplit("/", 1)[1].split(".")[0])
            if not isinstance(digest, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", digest):
                raise ValueError
            return cls(document_id, claim_id, key, digest.lower())
        except (KeyError, ValueError, TypeError, AttributeError) as exc:
            raise ScanError("scan_job_invalid") from exc


def detect_mime(content: bytes) -> str | None:
    """Recognize allowed byte signatures, not user MIME/extension declarations.

    This is NOT a full format validator or content disarm/reconstruction. A
    clean AV result does not make a PDF safe to render in a privileged origin.
    """
    if re.match(rb"%PDF-(?:1\.[0-7]|2\.0)(?:\r|\n)", content[:10]):
        return "application/pdf"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if content.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    return None


class Supabase:
    def __init__(self, url: str, secret: str, client: httpx.AsyncClient):
        parsed = urlsplit(url)
        if (parsed.scheme != "https" or not parsed.hostname or parsed.username
                or parsed.password or parsed.path not in ("", "/") or parsed.query
                or parsed.fragment or parsed.port not in (None, 443)
                or not secret or secret != secret.strip()):
            raise ScanError("supabase_configuration_invalid")
        self.base = url.rstrip("/")
        self.headers = {"apikey": secret, "Authorization": f"Bearer {secret}", "Accept-Encoding": "identity"}
        self.client = client

    async def _request(self, method: str, path: str, *, body=None, limit: int) -> bytes:
        async def operation() -> bytes:
            async with self.client.stream(method, self.base + path, headers=self.headers,
                                          json=body, follow_redirects=False) as response:
                if response.status_code != 200:
                    raise ScanError("supabase_request_failed")
                if response.headers.get("content-encoding", "identity").lower() not in ("", "identity"):
                    raise ScanError("upstream_encoding_rejected")
                length = response.headers.get("content-length")
                if length is not None and (not re.fullmatch(r"[0-9]{1,10}", length) or int(length) > limit):
                    raise ScanError("upstream_size_rejected")
                if response.is_stream_consumed:
                    # Mock transports may materialize the response before the
                    # stream context is entered. Production responses remain
                    # incremental; both paths enforce the same cap.
                    content = bytearray(response.content)
                    if len(content) > limit:
                        raise ScanError("upstream_size_rejected")
                else:
                    content = bytearray()
                    async for chunk in response.aiter_raw():
                        if len(content) + len(chunk) > limit:
                            raise ScanError("upstream_size_rejected")
                        content.extend(chunk)
                if length is not None and len(content) != int(length):
                    raise ScanError("upstream_size_mismatch")
                return bytes(content)

        try:
            return await asyncio.wait_for(operation(), timeout=30)
        except (httpx.HTTPError, TimeoutError, asyncio.TimeoutError) as exc:
            raise ScanError("supabase_unavailable") from exc

    async def rpc(self, name: str, body: dict):
        content = await self._request("POST", "/rest/v1/rpc/" + name, body=body, limit=65536)
        try:
            return json.loads(content)
        except (ValueError, UnicodeError) as exc:
            raise ScanError("supabase_response_invalid") from exc

    async def jobs(self, limit: int) -> list[Job]:
        rows = await self.rpc("api_server_document_scan_queue", {"p_limit": limit})
        if not isinstance(rows, list) or len(rows) > limit:
            raise ScanError("scan_queue_invalid")
        return [Job.parse(row) for row in rows]

    async def download(self, job: Job) -> bytes:
        # Revalidate even an internally supplied Job; URLs never come from an upload.
        job = Job.parse(vars(job))
        return await self._request(
            "GET",
            f"/storage/v1/object/{PRIVATE_OBJECT_ROUTE}/{job.object_key}",
            limit=MAX_BYTES,
        )

    async def record(self, job: Job, *, digest: str | None, mime: str | None,
                     size: int | None, status: str, engine: str | None = None, reason: str | None = None) -> None:
        result = await self.rpc("api_server_record_provider_document_scan", {
            "p_document_id": job.document_id, "p_server_sha256": digest,
            "p_detected_mime": mime, "p_size_bytes": size, "p_scan_status": status,
            "p_engine_version": engine, "p_error_code": reason,
        })
        expected_verified = status == "clean" and digest == job.submitted_sha256
        if (not isinstance(result, dict) or result.get("document_id") != job.document_id
                or result.get("scan_status") != status or result.get("content_verified") is not expected_verified):
            raise ScanError("scan_record_invalid")


async def scan_one(job: Job, store: Supabase, antivirus: Clamd) -> dict:
    digest, mime, size = None, None, None
    try:
        content = await store.download(job)
        if not content:
            raise ScanError("document_empty")
        size = len(content)
        digest = hashlib.sha256(content).hexdigest()
        mime = detect_mime(content)
        if mime is None:
            raise ScanError("document_type_rejected")
        expected_mime = {"pdf": "application/pdf", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}
        if mime != expected_mime[job.object_key.rsplit(".", 1)[1]]:
            raise ScanError("document_extension_mismatch")
        if digest != job.submitted_sha256:
            raise ScanError("document_hash_mismatch")
        status, engine = await antivirus.scan(content)
        if status not in ("clean", "infected"):
            raise ScanError("scanner_incomplete")
    except ScanError as exc:
        # Missing data stays NULL; never fabricate a hash, MIME or size merely
        # to satisfy an audit record. An error is eligible for bounded retry.
        await store.record(job, digest=digest, mime=mime, size=size, status="error", reason=str(exc))
        return {"document_id": job.document_id, "status": "error", "reason": str(exc)}
    await store.record(job, digest=digest, mime=mime, size=size, status=status, engine=engine)
    return {"document_id": job.document_id, "status": status}


async def run_batch(limit: int) -> int:
    if not 1 <= limit <= 25:
        raise ScanError("scan_limit_invalid")
    antivirus = Clamd(os.environ.get("CLAMD_SOCKET", "/run/clamav/clamd.sock"))
    # Never inherit proxy settings which could receive the privileged API key.
    async with httpx.AsyncClient(trust_env=False, timeout=10,
                                 limits=httpx.Limits(max_connections=1, max_keepalive_connections=1)) as client:
        store = Supabase(os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_SECRET_KEY", ""), client)
        jobs = await store.jobs(limit)
        failed = False
        for job in jobs:
            result = await scan_one(job, store, antivirus)
            print(json.dumps(result))
            failed = failed or result["status"] == "error"
        return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    try:
        return asyncio.run(run_batch(args.limit))
    except ScanError as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}))
        return 1
    except Exception:
        # Transport/library exceptions can embed request headers or URLs.
        print(json.dumps({"status": "error", "reason": "scanner_internal_error"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
