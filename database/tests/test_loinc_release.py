import base64
import csv
import hashlib
import io
import json
import zipfile
from pathlib import Path

from database.scripts.loinc_release import (
    INDEX_FIELDS,
    build_index,
    download_release,
    extract_loinc_table,
    fetch_metadata,
)


class _Response(io.BytesIO):
    pass


def test_fetch_metadata_uses_basic_auth_and_version():
    seen = {}

    def opener(request):
        seen["url"] = request.full_url
        seen["auth"] = request.headers["Authorization"]
        return _Response(json.dumps({"version": "2.83", "downloadUrl": "https://example.test/loinc.zip", "downloadMD5Hash": "abc"}).encode())

    metadata = fetch_metadata("user", "secret", "2.83", opener=opener)

    assert metadata["version"] == "2.83"
    assert "version=2.83" in seen["url"]
    assert seen["auth"] == "Basic " + base64.b64encode(b"user:secret").decode()


def test_download_release_verifies_md5_and_removes_bad_archive(tmp_path: Path):
    payload = b"release-bytes"
    metadata = {
        "version": "2.83",
        "downloadUrl": "https://example.test/loinc.zip",
        "downloadMD5Hash": hashlib.md5(payload).hexdigest(),
    }

    path = download_release(metadata, "user", "secret", tmp_path, opener=lambda request: _Response(payload))

    assert path.read_bytes() == payload


def test_extract_loinc_table_from_nested_archive(tmp_path: Path):
    archive_path = tmp_path / "Loinc_2.83.zip"
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("LoincTable/Loinc.csv", b"LOINC_NUM,STATUS\n123-4,ACTIVE\n")

    output = extract_loinc_table(archive_path, tmp_path / "extracted")

    assert output.read_text(encoding="utf-8") == "LOINC_NUM,STATUS\n123-4,ACTIVE\n"


def test_build_index_filters_class_and_deprecated_rows(tmp_path: Path):
    csv_path = tmp_path / "Loinc.csv"
    rows = [
        {field: "" for field in INDEX_FIELDS},
        {field: "" for field in INDEX_FIELDS},
        {field: "" for field in INDEX_FIELDS},
    ]
    rows[0].update({"LOINC_NUM": "123-4", "CLASS": "LAB", "STATUS": "ACTIVE", "LONG_COMMON_NAME": "Glucose"})
    rows[1].update({"LOINC_NUM": "234-5", "CLASS": "CLIN", "STATUS": "ACTIVE", "LONG_COMMON_NAME": "Clinical"})
    rows[2].update({"LOINC_NUM": "345-6", "CLASS": "LAB", "STATUS": "DEPRECATED", "LONG_COMMON_NAME": "Old glucose"})
    with csv_path.open("w", encoding="utf-8", newline="") as source:
        writer = csv.DictWriter(source, fieldnames=list(INDEX_FIELDS))
        writer.writeheader()
        writer.writerows(rows)

    output = tmp_path / "index.jsonl"
    stats = build_index(csv_path, output, classes={"LAB"})
    indexed = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()]

    assert stats["rows_seen"] == 3
    assert stats["rows_written"] == 1
    assert indexed[0]["LOINC_NUM"] == "123-4"


def test_build_index_can_include_deprecated_rows(tmp_path: Path):
    csv_path = tmp_path / "Loinc.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as source:
        writer = csv.DictWriter(source, fieldnames=list(INDEX_FIELDS))
        writer.writeheader()
        row = {field: "" for field in INDEX_FIELDS}
        row.update({"LOINC_NUM": "345-6", "CLASS": "LAB", "STATUS": "DEPRECATED"})
        writer.writerow(row)

    output = tmp_path / "index.jsonl"
    stats = build_index(csv_path, output, classes={"LAB"}, active_only=False)

    assert stats["rows_written"] == 1
