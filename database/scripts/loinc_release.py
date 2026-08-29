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
import json
import os
import shutil
import sys
import unicodedata
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import BinaryIO, Callable, Iterable


LOINC_API_BASE = "https://loinc.regenstrief.org/api/v1"
DEFAULT_ARTIFACT_DIR = Path("database/artifacts/loinc")
INDEX_MANIFEST_SUFFIX = ".manifest.json"
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
REQUIRED_INDEX_FIELDS = (
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
    "ORDER_OBS",
)
SEARCH_FIELDS = (
    ("LONG_COMMON_NAME", 1.00),
    ("SHORTNAME", 0.90),
    ("CONSUMER_NAME", 0.80),
    ("COMPONENT", 0.70),
    ("PROPERTY", 0.55),
    ("SYSTEM", 0.45),
    ("METHOD_TYP", 0.40),
)
SEARCH_STOPWORDS = {"a", "and", "con", "de", "del", "el", "en", "in", "la", "of", "on", "para", "por", "the", "y"}


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
    digest = hashlib.md5()
    with output_path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest().lower()
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
        missing = [field for field in REQUIRED_INDEX_FIELDS if field not in reader.fieldnames]
        if missing:
            raise ValueError(f"LOINC CSV is missing fields: {', '.join(missing)}")
        for row in reader:
            yield {field: (row.get(field) or "").strip() for field in INDEX_FIELDS}


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalize_search_text(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join("".join(char if char.isalnum() else " " for char in without_marks).split())


def _search_tokens(value: str) -> list[str]:
    return [
        token
        for token in _normalize_search_text(value).split()
        if token not in SEARCH_STOPWORDS and len(token) > 1
    ]


def _iter_index_rows(index_path: Path) -> Iterable[dict[str, str]]:
    with index_path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(f"Invalid JSONL at {index_path}:{line_number}") from error
            if not isinstance(row, dict) or not row.get("LOINC_NUM"):
                raise ValueError(f"LOINC index row {line_number} must contain LOINC_NUM")
            yield {str(key): str(value or "") for key, value in row.items()}


def rank_candidates(
    index_path: Path,
    query: str,
    *,
    limit: int = 20,
    active_only: bool = True,
) -> list[dict[str, object]]:
    """Rank local LOINC rows for review; this function never writes mappings."""

    if limit < 1 or limit > 100:
        raise ValueError("candidate limit must be between 1 and 100")
    normalized_query = _normalize_search_text(query)
    query_tokens = _search_tokens(query)
    if not query_tokens:
        raise ValueError("candidate query must contain at least one searchable token")
    query_weight = float(len(query_tokens))
    ranked: list[tuple[float, float, str, dict[str, object]]] = []
    for row in _iter_index_rows(index_path):
        status = row.get("STATUS", "").upper()
        if active_only and status not in {"ACTIVE", "TRIAL"}:
            continue
        normalized_fields = {
            field: _normalize_search_text(row.get(field, ""))
            for field, _weight in SEARCH_FIELDS
        }
        matched_tokens: list[str] = []
        evidence_fields: set[str] = set()
        weighted_hits = 0.0
        for token in query_tokens:
            matching = [
                (field, weight)
                for field, weight in SEARCH_FIELDS
                if token in normalized_fields[field].split()
            ]
            if matching:
                field, weight = max(matching, key=lambda candidate: candidate[1])
                matched_tokens.append(token)
                evidence_fields.add(field)
                weighted_hits += weight
        coverage = len(matched_tokens) / query_weight
        if coverage == 0:
            continue
        phrase_match = any(
            normalized_query and normalized_query in normalized_fields[field]
            for field, _weight in SEARCH_FIELDS[:3]
        )
        weighted_coverage = weighted_hits / query_weight
        score = min(1.0, (coverage * 0.65) + (weighted_coverage * 0.20) + (0.15 if phrase_match else 0.0))
        candidate = {
            "loinc_code": row.get("LOINC_NUM", ""),
            "long_common_name": row.get("LONG_COMMON_NAME", ""),
            "short_name": row.get("SHORTNAME", ""),
            "consumer_name": row.get("CONSUMER_NAME", ""),
            "component": row.get("COMPONENT", ""),
            "property": row.get("PROPERTY", ""),
            "time_aspect": row.get("TIME_ASPCT", ""),
            "system": row.get("SYSTEM", ""),
            "scale_type": row.get("SCALE_TYP", ""),
            "method": row.get("METHOD_TYP", ""),
            "class": row.get("CLASS", ""),
            "status": row.get("STATUS", ""),
            "order_observation": row.get("ORDER_OBS", ""),
            "score": round(score, 6),
            "matched_tokens": matched_tokens,
            "evidence_fields": sorted(evidence_fields),
            "review_status": "candidate",
            "requires_manual_review": True,
        }
        ranked.append((score, coverage, str(row.get("LOINC_NUM", "")), candidate))
    ranked.sort(key=lambda value: (-value[0], -value[1], value[2]))
    return [candidate for _score, _coverage, _code, candidate in ranked[:limit]]


def build_index(
    csv_path: Path,
    output_path: Path,
    *,
    classes: set[str] | None = None,
    active_only: bool = True,
    version: str | None = None,
) -> dict[str, object]:
    """Write a compact JSONL candidate index and return deterministic stats."""

    if version is not None and not str(version).strip():
        raise ValueError("LOINC index version cannot be empty")
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
    stats: dict[str, object] = {
        "input": str(csv_path),
        "output": str(output_path),
        "rows_seen": rows_seen,
        "rows_written": rows_written,
        "active_only": active_only,
        "classes": sorted(classes) if classes else [],
    }
    if version:
        manifest_path = output_path.with_suffix(output_path.suffix + INDEX_MANIFEST_SUFFIX)
        manifest = {
            "loinc_version": version,
            "index": str(output_path),
            "index_sha256": _sha256_file(output_path),
            "rows_seen": rows_seen,
            "rows_written": rows_written,
            "active_only": active_only,
            "classes": sorted(classes) if classes else [],
        }
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        stats["version"] = version
        stats["manifest"] = str(manifest_path)
    return stats


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
    index.add_argument("--version", required=True)

    candidates = subparsers.add_parser("candidates")
    candidates.add_argument("--index", type=Path, required=True)
    candidates.add_argument("--query", action="append", required=True)
    candidates.add_argument("--limit", type=int, default=20)
    candidates.add_argument("--include-deprecated", action="store_true")

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
            version=args.version,
        )
        print(json.dumps(stats, ensure_ascii=False, indent=2))
        return 0
    if args.command == "candidates":
        if args.limit < 1 or args.limit > 100:
            raise SystemExit("--limit must be between 1 and 100")
        results = {
            query: rank_candidates(
                args.index,
                query,
                limit=args.limit,
                active_only=not args.include_deprecated,
            )
            for query in args.query
        }
        print(json.dumps({"index": str(args.index), "results": results}, ensure_ascii=False, indent=2))
        return 0
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    sys.exit(main())
