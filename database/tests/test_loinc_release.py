import base64
import csv
import hashlib
import io
import json
import zipfile
from argparse import Namespace
from pathlib import Path

import pytest

from database.scripts.loinc_release import (
    INDEX_FIELDS,
    MAX_ENV_FILE_BYTES,
    _RejectRedirectHandler,
    _copy_bounded,
    _credentials,
    _load_env_file,
    _validate_download_url,
    _validate_sha256,
    _validate_version,
    build_index,
    download_release,
    extract_loinc_table,
    fetch_metadata,
    rank_candidates,
)


class _Response(io.BytesIO):
    pass


def test_fetch_metadata_uses_basic_auth_and_version():
    seen = {}

    def opener(request):
        seen["url"] = request.full_url
        seen["auth"] = request.headers["Authorization"]
        return _Response(json.dumps({"version": "2.83", "downloadUrl": "https://loinc.regenstrief.org/api/v1/Loinc/Download?version=2.83", "downloadMD5Hash": "abc"}).encode())

    metadata = fetch_metadata("user", "secret", "2.83", opener=opener)

    assert metadata["version"] == "2.83"
    assert "version=2.83" in seen["url"]
    assert seen["auth"] == "Basic " + base64.b64encode(b"user:secret").decode()


def test_download_release_verifies_md5_and_removes_bad_archive(tmp_path: Path):
    payload = b"release-bytes"
    metadata = {
        "version": "2.83",
        "downloadUrl": "https://loinc.regenstrief.org/api/v1/Loinc/Download?version=2.83",
        "downloadMD5Hash": hashlib.md5(payload).hexdigest(),
    }
    stale_metadata = tmp_path / "Loinc_2.83.metadata.json"
    stale_metadata.write_text("stale", encoding="utf-8")
    metadata["downloadMD5Hash"] = "0" * 32

    with pytest.raises(ValueError, match="checksum mismatch"):
        download_release(metadata, "user", "secret", tmp_path, opener=lambda request: _Response(payload))

    assert not (tmp_path / "Loinc_2.83.zip").exists()
    assert not stale_metadata.exists()

    metadata["downloadMD5Hash"] = hashlib.md5(payload).hexdigest()
    path = download_release(metadata, "user", "secret", tmp_path, opener=lambda request: _Response(payload))
    assert path.read_bytes() == payload
    archive_metadata = json.loads(path.with_suffix(".metadata.json").read_text(encoding="utf-8"))
    assert archive_metadata["version"] == "2.83"
    assert archive_metadata["published_md5"] == archive_metadata["verified_md5"]
    assert archive_metadata["download_sha256"] == hashlib.sha256(payload).hexdigest()


def test_download_release_removes_partial_archive_on_network_error(tmp_path: Path):
    metadata = {
        "version": "2.83",
        "downloadUrl": "https://loinc.regenstrief.org/api/v1/Loinc/Download?version=2.83",
        "downloadMD5Hash": "0" * 32,
    }

    def failing_opener(_request):
        raise OSError("connection reset")

    with pytest.raises(OSError, match="connection reset"):
        download_release(metadata, "user", "secret", tmp_path, opener=failing_opener)

    assert not (tmp_path / "Loinc_2.83.zip").exists()
    assert not (tmp_path / "Loinc_2.83.metadata.json").exists()


def test_release_metadata_rejects_path_traversal_and_untrusted_download_hosts():
    with pytest.raises(ValueError, match="Invalid LOINC release version"):
        _validate_version("2.83/../../secrets")

    with pytest.raises(ValueError, match="HTTPS on loinc.regenstrief.org"):
        _validate_download_url("https://evil.example/loinc.zip")

    with pytest.raises(ValueError, match="HTTPS on loinc.regenstrief.org"):
        _validate_download_url("http://loinc.regenstrief.org/api/v1/Loinc/Download")

    with pytest.raises(ValueError, match="64-character hexadecimal"):
        _validate_sha256("not-a-digest")


def test_loinc_requests_reject_redirects_and_downloads_are_bounded():
    with pytest.raises(ValueError, match="redirect rejected"):
        _RejectRedirectHandler().redirect_request(None, "https://evil.example", "GET", {})

    destination = io.BytesIO()
    with pytest.raises(ValueError, match="exceeds the safety limit"):
        _copy_bounded(io.BytesIO(b"0123456789"), destination, maximum=4)
    assert destination.getvalue() == b""


def test_credentials_load_from_local_env_without_overriding_process_values(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    env_file = tmp_path / ".env"
    env_file.write_text(
        "# local only\nLOINC_USERNAME=from-file\nLOINC_PASSWORD='from-file-secret'\n",
        encoding="utf-8",
    )
    monkeypatch.delenv("LOINC_USERNAME", raising=False)
    monkeypatch.delenv("LOINC_PASSWORD", raising=False)

    assert _credentials(Namespace(username=None, password=None, env_file=env_file)) == (
        "from-file",
        "from-file-secret",
    )

    monkeypatch.setenv("LOINC_USERNAME", "from-process")
    monkeypatch.setenv("LOINC_PASSWORD", "process-secret")
    assert _credentials(Namespace(username=None, password=None, env_file=env_file)) == (
        "from-process",
        "process-secret",
    )


def test_env_file_is_bounded(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_bytes(b"X" * (MAX_ENV_FILE_BYTES + 1))
    with pytest.raises(ValueError, match="env file exceeds"):
        _load_env_file(env_file)


def test_extract_loinc_table_from_nested_archive(tmp_path: Path):
    archive_path = tmp_path / "Loinc_2.83.zip"
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("LoincTable/Loinc.csv", b"LOINC_NUM,STATUS\n123-4,ACTIVE\n")

    output = extract_loinc_table(archive_path, tmp_path / "extracted")

    assert output.read_text(encoding="utf-8") == "LOINC_NUM,STATUS\n123-4,ACTIVE\n"


def test_extract_loinc_table_prefers_canonical_table_when_accessory_has_same_name(tmp_path: Path):
    archive_path = tmp_path / "Loinc_2.83.zip"
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("AccessoryFiles/PanelsAndForms/Loinc.csv", b"accessory")
        archive.writestr("LoincTable/Loinc.csv", b"canonical")

    output = extract_loinc_table(archive_path, tmp_path / "extracted")

    assert output.read_bytes() == b"canonical"


def test_download_release_enforces_optional_sha256(tmp_path: Path):
    payload = b"release-bytes"
    metadata = {
        "version": "2.83",
        "downloadUrl": "https://loinc.regenstrief.org/api/v1/Loinc/Download?version=2.83",
        "downloadMD5Hash": hashlib.md5(payload).hexdigest(),
    }

    with pytest.raises(ValueError, match="SHA-256 mismatch"):
        download_release(
            metadata,
            "user",
            "secret",
            tmp_path,
            expected_sha256="0" * 64,
            opener=lambda request: _Response(payload),
        )

    path = download_release(
        metadata,
        "user",
        "secret",
        tmp_path,
        expected_sha256=hashlib.sha256(payload).hexdigest(),
        opener=lambda request: _Response(payload),
    )
    archive_metadata = json.loads(path.with_suffix(".metadata.json").read_text(encoding="utf-8"))
    assert archive_metadata["published_sha256"] == archive_metadata["download_sha256"]


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
    stats = build_index(csv_path, output, classes={"LAB"}, active_only=False, version="2.83")

    assert stats["rows_written"] == 1
    manifest_path = output.with_suffix(output.suffix + ".manifest.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert stats["manifest"] == str(manifest_path)
    assert manifest["loinc_version"] == "2.83"
    assert manifest["rows_written"] == 1


def test_build_index_can_filter_laboratory_class_type(tmp_path: Path):
    csv_path = tmp_path / "Loinc.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as source:
        writer = csv.DictWriter(source, fieldnames=list(INDEX_FIELDS))
        writer.writeheader()
        laboratory = {field: "" for field in INDEX_FIELDS}
        laboratory.update({"LOINC_NUM": "123-4", "CLASS": "CHEM", "CLASSTYPE": "1", "STATUS": "ACTIVE"})
        clinical = {field: "" for field in INDEX_FIELDS}
        clinical.update({"LOINC_NUM": "234-5", "CLASS": "RAD", "CLASSTYPE": "2", "STATUS": "ACTIVE"})
        writer.writerows([laboratory, clinical])

    output = tmp_path / "lab-index.jsonl"
    stats = build_index(csv_path, output, class_types={"1"}, version="2.83")

    assert stats["rows_seen"] == 2
    assert stats["rows_written"] == 1
    assert json.loads(output.read_text(encoding="utf-8"))["CLASSTYPE"] == "1"


def test_rank_candidates_is_deterministic_and_review_only(tmp_path: Path):
    index_path = tmp_path / "loinc_lab_active.jsonl"
    rows = [
        {
            "LOINC_NUM": "123-4",
            "LONG_COMMON_NAME": "Glucose [Mass/volume] in Serum or Plasma",
            "SHORTNAME": "Glucose M mass/vol Ser/Plas",
            "CONSUMER_NAME": "Glucose",
            "COMPONENT": "Glucose",
            "PROPERTY": "Mass concentration",
            "TIME_ASPCT": "Point in time",
            "SYSTEM": "Ser/Plas",
            "SCALE_TYP": "Quantitative",
            "METHOD_TYP": "",
            "CLASS": "LAB",
            "STATUS": "ACTIVE",
            "ORDER_OBS": "Both",
        },
        {
            "LOINC_NUM": "234-5",
            "LONG_COMMON_NAME": "Glucose-6-phosphate dehydrogenase",
            "SHORTNAME": "G6PD",
            "CONSUMER_NAME": "",
            "COMPONENT": "Glucose-6-phosphate dehydrogenase",
            "PROPERTY": "Catalytic activity",
            "TIME_ASPCT": "Point in time",
            "SYSTEM": "Blood",
            "SCALE_TYP": "Quantitative",
            "METHOD_TYP": "",
            "CLASS": "LAB",
            "STATUS": "ACTIVE",
            "ORDER_OBS": "Both",
        },
        {
            "LOINC_NUM": "345-6",
            "LONG_COMMON_NAME": "Glucose old method",
            "SHORTNAME": "Old glucose",
            "CONSUMER_NAME": "",
            "COMPONENT": "Glucose",
            "PROPERTY": "Mass concentration",
            "TIME_ASPCT": "Point in time",
            "SYSTEM": "Ser/Plas",
            "SCALE_TYP": "Quantitative",
            "METHOD_TYP": "",
            "CLASS": "LAB",
            "STATUS": "DEPRECATED",
            "ORDER_OBS": "Both",
        },
    ]
    index_path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")

    candidates = rank_candidates(index_path, "glucose serum", limit=1)

    assert [candidate["loinc_code"] for candidate in candidates] == ["123-4"]
    assert candidates[0]["review_status"] == "candidate"
    assert candidates[0]["requires_manual_review"] is True
    assert candidates[0]["matched_tokens"] == ["glucose", "serum"]


def test_rank_candidates_prefers_ranked_common_term_over_unranked_variant(tmp_path: Path):
    index_path = tmp_path / "loinc_lab_active.jsonl"
    rows = [
        {
            "LOINC_NUM": "100000-9",
            "LONG_COMMON_NAME": "Glucose [Mass/volume] in Serum or Plasma after challenge",
            "SHORTNAME": "Glucose challenge SerPl",
            "COMPONENT": "Glucose",
            "SYSTEM": "Ser/Plas",
            "COMMON_TEST_RANK": "0",
            "STATUS": "ACTIVE",
        },
        {
            "LOINC_NUM": "2345-7",
            "LONG_COMMON_NAME": "Glucose [Mass/volume] in Serum or Plasma",
            "SHORTNAME": "Glucose SerPl-mCnc",
            "COMPONENT": "Glucose",
            "SYSTEM": "Ser/Plas",
            "COMMON_TEST_RANK": "6",
            "STATUS": "ACTIVE",
        },
    ]
    index_path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")

    candidates = rank_candidates(index_path, "glucose serum plasma", limit=2)

    assert [candidate["loinc_code"] for candidate in candidates] == ["2345-7", "100000-9"]
    assert candidates[0]["common_test_rank"] == "6"


def test_rank_candidates_rejects_empty_query_and_bad_limit(tmp_path: Path):
    index_path = tmp_path / "empty.jsonl"
    index_path.write_text("", encoding="utf-8")

    with pytest.raises(ValueError, match="searchable token"):
        rank_candidates(index_path, "de en")
    with pytest.raises(ValueError, match="between 1 and 100"):
        rank_candidates(index_path, "glucose", limit=101)
