"""Download and build a local, versioned LOINC candidate index.

The script deliberately keeps the LOINC release outside Git and outside the
runtime resolver.  It is an operator tool for obtaining an authenticated
release, checking its checksum, and producing a compact local index that can
be reviewed before any mapping is published to Supabase.
"""

from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import io
import json
import os
import shutil
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import BinaryIO, Callable, Iterable


LOINC_API_BASE = "https://loinc.regenstrief.org/api/v1"
DEFAULT_ARTIFACT_DIR = Path("database/artifacts/loinc")
INDEX_FIELDS = (
    "LOINC_NUM",
    "COMPONENT",
    "PROPERTY",
    "TIME_ASPCT",
    "SYSTEM",
    "SCALE_TYP",
    "METHOD_TYP",
    "CLASS",
    "STATUS",
    "LONG_COMMON_NAME",
    "SHORTNAME",
    "CONSUMER_NAME",
    "ORDER_OBS",
    "EXTERNAL_COPYRIGHT_NOTICE",
)


UrlOpener = Callable[..., BinaryIO]


def _auth_header(username: str, password: str) -> str:
    token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    return f"Basic {token}"


def _request(
    url: str,
    *,
    username: str,
    password: str,
    opener: UrlOpener = urllib.request.urlopen,
) -> BinaryIO:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "Authorization": _auth_header(username, password),
            "User-Agent": "pruevia-loinc-import/1.0",
        },
    )
    return opener(request)


def fetch_metadata(
    username: str,
    password: str,
    version: str | None = None,
    *,
    opener: UrlOpener = urllib.request.urlopen,
) -> dict:
    """Fetch release metadata from the authenticated LOINC Download API."""

    query = ""
    if version:
        query = "?" + urllib.parse.urlencode({"version": version})
    url = f"{LOINC_API_BASE}/Loinc{query}"
    with _request(url, username=username, password=password, opener=opener) as response:
        payload = json.load(response)
    required = ("version", "downloadUrl", "downloadMD5Hash")
    missing = [field for field in required if not payload.get(field)]
    if missing:
        raise ValueError(f"LOINC metadata is missing required fields: {', '.join(missing)}")
    return payload


def download_release(
    metadata: dict,
    username: str,
    password: str,
    output_dir: Path,
    *,
    opener: UrlOpener = urllib.request.urlopen,
) -> Path:
    """Download a release and verify the MD5 published by LOINC."""

    version = str(metadata["version"])
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"Loinc_{version}.zip"
    with _request(
        str(metadata["downloadUrl"]),
        username=username,
        password=password,
        opener=opener,
    ) as response, output_path.open("wb") as destination:
        shutil.copyfileobj(response, destination)

    expected = str(metadata["downloadMD5Hash"]).lower()
    actual = hashlib.md5(output_path.read_bytes()).hexdigest().lower()
    if actual != expected:
        output_path.unlink(missing_ok=True)
        raise ValueError(
            f"LOINC checksum mismatch for {version}: expected {expected}, got {actual}"
        )
    return output_path


def _find_member(archive: zipfile.ZipFile, filename: str) -> str:
    matches = [
        name
        for name in archive.namelist()
        if Path(name).name.casefold() == filename.casefold()
    ]
    if not matches:
        raise ValueError(f"LOINC archive does not contain {filename}")
    if len(matches) > 1:
        raise ValueError(f"LOINC archive contains multiple {filename} files: {matches}")
    return matches[0]


def extract_loinc_table(zip_path: Path, output_dir: Path) -> Path:
    """Extract the canonical Loinc.csv table from a release archive."""

    output_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        member = _find_member(archive, "Loinc.csv")
        destination = output_dir / "Loinc.csv"
        with archive.open(member) as source, destination.open("wb") as target:
            shutil.copyfileobj(source, target)
    return destination


def _iter_rows(csv_path: Path) -> Iterable[dict[str, str]]:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        if not reader.fieldnames:
            raise ValueError(f"LOINC CSV has no header: {csv_path}")
        missing = [field for field in INDEX_FIELDS if field not in reader.fieldnames]
        if missing:
            raise ValueError(f"LOINC CSV is missing fields: {', '.join(missing)}")
        for row in reader:
            yield {field: (row.get(field) or "").strip() for field in INDEX_FIELDS}


def build_index(
    csv_path: Path,
    output_path: Path,
    *,
    classes: set[str] | None = None,
    active_only: bool = True,
) -> dict[str, int | str]:
    """Write a compact JSONL candidate index and return deterministic stats."""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    rows_seen = 0
    rows_written = 0
    with output_path.open("w", encoding="utf-8", newline="\n") as target:
        for row in _iter_rows(csv_path):
            rows_seen += 1
            if classes and row["CLASS"].upper() not in {value.upper() for value in classes}:
                continue
            if active_only and row["STATUS"].upper() not in {"ACTIVE", "TRIAL"}:
                continue
            target.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
            rows_written += 1
    return {
        "input": str(csv_path),
        "output": str(output_path),
        "rows_seen": rows_seen,
        "rows_written": rows_written,
        "active_only": active_only,
        "classes": sorted(classes) if classes else [],
    }


def _credentials(args: argparse.Namespace) -> tuple[str, str]:
    username = args.username or os.getenv("LOINC_USERNAME")
    password = args.password or os.getenv("LOINC_PASSWORD")
    if not username or not password:
        raise SystemExit(
            "LOINC credentials are required. Set LOINC_USERNAME and LOINC_PASSWORD "
            "or pass --username/--password."
        )
    return username, password


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--username")
    common.add_argument("--password")

    metadata = subparsers.add_parser("metadata", parents=[common])
    metadata.add_argument("--version")

    download = subparsers.add_parser("download", parents=[common])
    download.add_argument("--version")
    download.add_argument("--output-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)

    extract = subparsers.add_parser("extract")
    extract.add_argument("--zip", dest="zip_path", type=Path, required=True)
    extract.add_argument("--output-dir", type=Path, required=True)

    index = subparsers.add_parser("index")
    index.add_argument("--csv", dest="csv_path", type=Path, required=True)
    index.add_argument("--output", dest="output_path", type=Path, required=True)
    index.add_argument("--class", dest="classes", action="append")
    index.add_argument("--include-deprecated", action="store_true")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.command == "metadata":
        username, password = _credentials(args)
        print(json.dumps(fetch_metadata(username, password, args.version), ensure_ascii=False, indent=2))
        return 0
    if args.command == "download":
        username, password = _credentials(args)
        metadata = fetch_metadata(username, password, args.version)
        path = download_release(metadata, username, password, args.output_dir)
        print(json.dumps({"version": metadata["version"], "path": str(path)}, ensure_ascii=False))
        return 0
    if args.command == "extract":
        path = extract_loinc_table(args.zip_path, args.output_dir)
        print(json.dumps({"path": str(path)}, ensure_ascii=False))
        return 0
    if args.command == "index":
        stats = build_index(
            args.csv_path,
            args.output_path,
            classes=set(args.classes or []),
            active_only=not args.include_deprecated,
        )
        print(json.dumps(stats, ensure_ascii=False, indent=2))
        return 0
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    sys.exit(main())
