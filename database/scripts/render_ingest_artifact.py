"""Render an idempotent ingest publication transaction for a collector artifact.

This is a transport fallback for environments where a direct Postgres DSN is
not available but the Supabase CLI can execute a linked SQL file. It publishes
only source evidence (raw records and observations); canonical catalog writes
remain the responsibility of ``publish_golden_catalog.py``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from uuid import NAMESPACE_URL, UUID, uuid5

try:
    from .artifact_io import read_json_file, read_jsonl
except ImportError:  # pragma: no cover - supports `python scripts/foo.py`
    from artifact_io import read_json_file, read_jsonl


# ``provider_discovered`` was used by the first generic collector prototype;
# the database contract names this evidence source ``public_website``.
SOURCE_TYPE_ALIASES = {"provider_discovered": "public_website"}


def stable_id(kind: str, key: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"https://pruevia.local/{kind}/{key}"))


def q(value: object | None) -> str:
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def jb(value: object) -> str:
    return q(json.dumps(value, ensure_ascii=False, separators=(",", ":"))) + "::jsonb"


def canonical_hash(payload: object) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def read_artifact(path: Path) -> tuple[dict, list[dict], list[dict]]:
    manifest = read_json_file(path / "run_manifest.json")
    if not isinstance(manifest, dict):
        raise ValueError("run manifest must be a JSON object")
    raw = read_jsonl(path / "raw_records.jsonl")
    observations = read_jsonl(path / "observations.jsonl")
    return manifest, raw, observations


def validate(manifest: dict, raw: list[dict], observations: list[dict]) -> list[dict]:
    source_key = manifest.get("source_key")
    if not isinstance(source_key, str) or not re.fullmatch(r"[a-z0-9_]+", source_key):
        raise ValueError("manifest source_key must be lowercase snake case")
    if manifest.get("status") != "succeeded" or manifest.get("errors"):
        raise ValueError("only succeeded artifacts without errors can be published")
    try:
        UUID(str(manifest["run_id"]))
    except (KeyError, ValueError) as error:
        raise ValueError("manifest run_id must be a UUID") from error
    try:
        records_received = int(manifest.get("records_received", -1))
        records_valid = int(manifest.get("records_valid", -1))
        records_rejected = int(manifest.get("records_rejected", -1))
    except (TypeError, ValueError) as error:
        raise ValueError("manifest record counts must be integers") from error
    if min(records_received, records_valid, records_rejected) < 0 or records_valid + records_rejected > records_received:
        raise ValueError("manifest record counts are inconsistent")
    if len(raw) != records_received:
        raise ValueError("raw record count does not match manifest")
    parsed: list[dict] = []
    seen_hashes: set[str] = set()
    for row in raw:
        if not isinstance(row, dict):
            raise ValueError("raw artifact rows must be JSON objects")
        if row.get("source_key") != source_key or row.get("parse_status") != "parsed":
            raise ValueError("artifact contains non-parsed or foreign raw records")
        record_hash = row.get("record_hash")
        if not isinstance(record_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", record_hash):
            raise ValueError("raw record has an invalid record hash")
        payload = row.get("payload")
        if not isinstance(payload, dict):
            raise ValueError("raw record payload must be an object")
        if len(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")) > 512 * 1024:
            raise ValueError("raw record payload exceeds the safety limit")
        if canonical_hash(payload) != record_hash:
            raise ValueError("raw record hash does not match payload")
        if record_hash in seen_hashes:
            raise ValueError("artifact contains duplicate record hashes")
        seen_hashes.add(record_hash)
        parsed.append(row)
    if len(parsed) != records_valid or records_rejected != 0:
        raise ValueError("artifact record counts do not match manifest")
    for row in observations:
        if not isinstance(row, dict) or row.get("source_key") != source_key or row.get("record_hash") not in seen_hashes:
            raise ValueError("observations contain a foreign or unknown record hash")
    return parsed


def render(artifact: Path) -> str:
    manifest, raw, observations = read_artifact(artifact)
    parsed = validate(manifest, raw, observations)
    source_key = manifest["source_key"]
    source_type = SOURCE_TYPE_ALIASES.get(manifest.get("source_type"), manifest.get("source_type"))
    source_id = stable_id("ingest-source", source_key)
    endpoint_id = stable_id("ingest-endpoint", source_key)
    run_id = str(manifest["run_id"])
    source_name = manifest["source_name"]
    endpoint_name = f"{source_name} collector endpoint"
    lines = ["begin;", "-- Generated from a succeeded collector artifact; evidence only."]
    lines.append(
        f"insert into ingest.sources(id,name,source_type,trust_rank,usage_policy_status,status) values ({q(source_id)},{q(source_name)},{q(source_type)},80,{q(manifest.get('usage_policy_status','review_required'))},'active') on conflict(id) do update set name=excluded.name,source_type=excluded.source_type,usage_policy_status=excluded.usage_policy_status,status='active';"
    )
    lines.append(
        f"insert into ingest.source_endpoints(id,source_id,name,endpoint_type,parser_name,parser_version,url,expected_min_records,expected_max_records,max_negative_deviation_pct,status) values ({q(endpoint_id)},{q(source_id)},{q(endpoint_name)},{q(manifest.get('endpoint_type','other'))},'pruevia_collectors',{q(manifest.get('parser_version','0.1.0'))},{q(manifest.get('endpoint_url'))},NULL,NULL,50.00,'active') on conflict(id) do update set source_id=excluded.source_id,name=excluded.name,endpoint_type=excluded.endpoint_type,parser_version=excluded.parser_version,url=excluded.url,status='active';"
    )
    lines.append(
        f"insert into ingest.crawl_runs(id,source_endpoint_id,started_at,finished_at,status,records_received,records_valid,records_rejected,records_published,previous_success_count,deviation_percentage,error_summary,metadata) values ({q(run_id)},{q(endpoint_id)},{q(manifest['finished_at'])},{q(manifest['finished_at'])},{q(manifest['status'])},{int(manifest['records_received'])},{int(manifest['records_valid'])},{int(manifest['records_rejected'])},0,{q(manifest.get('previous_success_count'))},{q(manifest.get('deviation_percentage'))},NULL,{jb({'artifact_directory': str(artifact), 'transport': 'supabase_cli_linked'})}) on conflict(id) do update set source_endpoint_id=excluded.source_endpoint_id,finished_at=excluded.finished_at,status=excluded.status,records_received=excluded.records_received,records_valid=excluded.records_valid,records_rejected=excluded.records_rejected,metadata=excluded.metadata;"
    )
    raw_ids: dict[str, str] = {}
    for row in parsed:
        record_hash = row["record_hash"]
        raw_id = stable_id("ingest-raw-record", f"{run_id}:{record_hash}")
        raw_ids[record_hash] = raw_id
        lines.append(
            f"insert into ingest.raw_records(id,crawl_run_id,source_id,external_record_id,record_type,payload,record_hash,observed_at,parse_status) values ({q(raw_id)},{q(run_id)},{q(source_id)},{q(row.get('external_record_id'))},{q(row['record_type'])},{jb(row['payload'])},{q(record_hash)},{q(row.get('observed_at'))},{q(row.get('parse_status','parsed'))}) on conflict(id) do update set payload=excluded.payload,external_record_id=excluded.external_record_id,record_type=excluded.record_type,observed_at=excluded.observed_at,parse_status=excluded.parse_status;"
        )
    for index, row in enumerate(observations):
        raw_id = raw_ids[row["record_hash"]]
        observation_id = stable_id("ingest-observation", f"{run_id}:{row['record_hash']}:{index}")
        lines.append(
            f"insert into ingest.source_observations(id,source_id,raw_record_id,entity_type,entity_id,attribute_name,observed_value,observed_at,confidence,status) values ({q(observation_id)},{q(source_id)},{q(raw_id)},{q(row['entity_type'])},{q(row.get('entity_id'))},{q(row.get('attribute_name'))},{jb(row.get('observed_value'))},{q(row.get('observed_at'))},{float(row.get('confidence',1.0))},{q(row.get('status','candidate'))}) on conflict(id) do update set raw_record_id=excluded.raw_record_id,observed_value=excluded.observed_value,observed_at=excluded.observed_at,confidence=excluded.confidence,status=excluded.status;"
        )
    lines.append(
        f"update ingest.crawl_runs set records_published={len(parsed)} where id={q(run_id)};"
    )
    lines.append(f"update ingest.source_endpoints set last_success_at=now(),updated_at=now() where id={q(endpoint_id)};")
    lines.append("commit;")
    return "\n".join(lines) + "\n"


def render_chunks(artifact: Path, max_bytes: int) -> list[str]:
    if max_bytes < 1024:
        raise ValueError("max_bytes must be at least 1024")
    statements = render(artifact).splitlines()
    if statements[0] != "begin;" or statements[-1] != "commit;":
        raise ValueError("rendered SQL must be a transaction")
    chunks: list[str] = []
    current: list[str] = []
    current_bytes = len(b"begin;\ncommit;\n")
    for statement in statements[1:-1]:
        statement_bytes = len(statement.encode("utf-8")) + 1
        if statement_bytes + len(b"begin;\ncommit;\n") > max_bytes:
            raise ValueError("a single SQL statement exceeds max_bytes")
        if current and current_bytes + statement_bytes > max_bytes:
            chunks.append("begin;\n" + "\n".join(current) + "\ncommit;\n")
            current = []
            current_bytes = len(b"begin;\ncommit;\n")
        current.append(statement)
        current_bytes += statement_bytes
    if current:
        chunks.append("begin;\n" + "\n".join(current) + "\ncommit;\n")
    return chunks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=450_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    manifest = read_json_file(args.artifact / "run_manifest.json")
    if not isinstance(manifest, dict) or "source_key" not in manifest:
        raise SystemExit("run manifest must contain a source_key")
    source_key = manifest["source_key"]
    if args.chunk_dir:
        chunks = render_chunks(args.artifact, args.max_bytes)
        args.chunk_dir.mkdir(parents=True, exist_ok=True)
        for index, chunk in enumerate(chunks, start=1):
            (args.chunk_dir / f"part-{index:03d}.sql").write_text(chunk, encoding="utf-8")
        print(json.dumps({"source_key": source_key, "chunks": len(chunks), "bytes": sum(len(chunk.encode('utf-8')) for chunk in chunks)}, ensure_ascii=False))
        return 0
    sql = render(args.artifact)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8")
    print(json.dumps({"source_key": source_key, "records": sql.count("insert into ingest.raw_records"), "bytes": len(sql.encode('utf-8'))}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
