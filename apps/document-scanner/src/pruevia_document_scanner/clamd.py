"""Bounded ClamAV INSTREAM client over a private Unix socket, never public TCP."""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone
import os
import re
import stat
import struct


MAX_BYTES = 10 * 1024 * 1024


class ScanError(Exception):
    """Only fixed, non-sensitive reason codes may cross this boundary."""


def check_version(reply: str, now: datetime) -> str:
    match = re.fullmatch(r"ClamAV (\d+)\.(\d+)\.(\d+)/(\d+)/(.{20,30})", reply)
    if not match:
        raise ScanError("scanner_version_invalid")
    version = tuple(int(match[i]) for i in (1, 2, 3))
    # Reviewed patch floors at 2026-09-04. Unknown release series require review.
    if not ((version[:2] == (1, 4) and version[2] >= 6)
            or (version[:2] == (1, 5) and version[2] >= 4)):
        raise ScanError("scanner_engine_unsupported")
    try:
        # Run clamd with TZ=UTC and LC_ALL=C. Do not trust the host timezone.
        published = datetime.strptime(match[5], "%a %b %d %H:%M:%S %Y").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise ScanError("scanner_version_invalid") from exc
    age = now - published
    if age < -timedelta(minutes=5) or age > timedelta(hours=48):
        raise ScanError("scanner_signatures_stale")
    return reply


class Clamd:
    def __init__(self, socket_path: str = "/run/clamav/clamd.sock", *, connector=None):
        if (not socket_path.startswith("/") or "\0" in socket_path
                or len(socket_path.encode("utf-8")) > 100):
            raise ScanError("scanner_socket_invalid")
        self.socket_path = socket_path
        self.connector = connector or asyncio.open_unix_connection
        self._verify_socket = connector is None

    def _check_socket(self) -> None:
        if not self._verify_socket:
            return
        try:
            metadata = os.lstat(self.socket_path)
        except OSError as exc:
            raise ScanError("scanner_socket_unavailable") from exc
        # Reject a replaceable symlink and sockets readable/writable by others.
        # The container user must be granted access through the owning group.
        if (stat.S_ISLNK(metadata.st_mode) or not stat.S_ISSOCK(metadata.st_mode)
                or metadata.st_mode & 0o007):
            raise ScanError("scanner_socket_permissions")

    async def _command(self, command: bytes, content: bytes | None = None) -> str:
        writer = None

        async def operation() -> str:
            nonlocal writer
            self._check_socket()
            reader, writer = await self.connector(self.socket_path, limit=1024)
            writer.write(command)
            if content is not None:
                for offset in range(0, len(content), 65536):
                    chunk = content[offset:offset + 65536]
                    writer.write(struct.pack("!I", len(chunk)))
                    writer.write(chunk)
                    await writer.drain()
                writer.write(b"\0\0\0\0")
            await writer.drain()
            reply = await reader.readuntil(b"\0")
            if len(reply) > 1024:
                raise ScanError("scanner_reply_invalid")
            return reply[:-1].decode("ascii")

        try:
            return await asyncio.wait_for(operation(), timeout=45)
        except (OSError, TimeoutError, asyncio.TimeoutError, asyncio.IncompleteReadError,
                asyncio.LimitOverrunError, UnicodeError) as exc:
            raise ScanError("scanner_unavailable") from exc
        finally:
            if writer is not None:
                writer.close()
                try:
                    await asyncio.wait_for(writer.wait_closed(), timeout=1)
                except (OSError, TimeoutError, asyncio.TimeoutError):
                    pass

    async def scan(self, content: bytes) -> tuple[str, str]:
        if not 0 < len(content) <= MAX_BYTES:
            raise ScanError("document_size_invalid")
        engine = check_version(await self._command(b"zVERSION\0"), datetime.now(timezone.utc))
        result = await self._command(b"zINSTREAM\0", content)
        if result == "stream: OK":
            return "clean", engine
        # Limit/encryption heuristics also produce FOUND and are never accepted.
        if re.fullmatch(r"stream: [A-Za-z0-9_.:/() -]{1,240} FOUND", result):
            return "infected", engine
        raise ScanError("scanner_incomplete")
