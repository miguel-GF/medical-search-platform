"""Render candidate provider labels as an admin normalization queue.

This transport creates only ``no_match`` normalization runs.  It never adds a
catalog candidate or an offer, so an administrator must explicitly add and
approve a canonical item later.  Unknown labels fail closed unless the caller
opts into a newly introduced source (for example the structured SEMIN API).
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Mapping

try:
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
    from .publish_golden_catalog import chunk_transaction, q, stable_id
    from .render_ingest_artifact import read_artifact, validate
except ImportError:  # pragma: no cover
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file
    from publish_golden_catalog import chunk_transaction, q, stable_id
    from render_ingest_artifact import read_artifact, validate


SAFE_REVIEW_CLASSES = frozenset({"new_concept_candidate", "ambiguous_modality", "ambiguous_panel", "possible_alias"})


def normalize(value: object) -> str:
    plain = "".join(char for char in unicodedata.normalize("NFKD", str(value or "").casefold()) if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def _json(path: Path) -> Mapping[str, Any]:
    value = read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    if not isinstance(value, Mapping):
        raise ValueError(f"JSON must be an object: {path}")
    return value


def _artifact_arg(value: str) -> tuple[str, Path]:
    source, separator, path = value.partition("=")
    if not separator or not source or not path:
        raise ValueError("artifact must use source_key=path")
    return source.strip(), Path(path)


def _brand_keys(mapping_fixture: Mapping[str, Any]) -> dict[str, str]:
    providers = mapping_fixture.get("providers")
    if not isinstance(providers, list):
        raise ValueError("mapping fixture providers must be an array")
    result: dict[str, str] = {}
    for row in providers:
        if not isinstance(row, Mapping):
            raise ValueError("mapping fixture providers must contain objects")
        source = str(row.get("source_key") or "").strip()
        key = str(row.get("provider_key") or "").strip()
        if not source or not key:
            raise ValueError("mapping provider source_key/provider_key is required")
        result[source] = stable_id("provider-brand", key)
    return result


def _approved(mapping_fixture: Mapping[str, Any]) -> set[tuple[str, str]]:
    mappings = mapping_fixture.get("mappings")
    if not isinstance(mappings, list):
        raise ValueError("mapping fixture mappings must be an array")
    return {
        (str(row.get("source_key") or "").strip(), str(row.get("external_record_id") or "").strip())
        for row in mappings
        if isinstance(row, Mapping)
    }


def _decisions(review_fixture: Mapping[str, Any] | None) -> dict[tuple[str, str], Mapping[str, Any]]:
    if review_fixture is None:
        return {}
    if review_fixture.get("version") != "generic-provider-review-puebla-v1":
        raise ValueError("unsupported generic review fixture version")
    rows = review_fixture.get("decisions")
    if not isinstance(rows, list):
        raise ValueError("review fixture decisions must be an array")
    result: dict[tuple[str, str], Mapping[str, Any]] = {}
    for row in rows:
        if not isinstance(row, Mapping):
            raise ValueError("review decisions must contain objects")
        source = str(row.get("source_key") or "").strip()
        label = str(row.get("label_key") or "").strip()
        if source and label:
            result[(source, label)] = row
    return result


def render_queue(
    artifacts: Mapping[str, Path],
    mapping_fixture: Mapping[str, Any],
    review_fixture: Mapping[str, Any] | None = None,
    *,
    include_unclassified_sources: set[str] | None = None,
    brand_overrides: Mapping[str, str] | None = None,
) -> tuple[str, dict[str, int]]:
    brands = _brand_keys(mapping_fixture)
    approved = _approved(mapping_fixture)
    decisions = _decisions(review_fixture)
    unclassified = include_unclassified_sources or set()
    statements: list[str] = [
        "begin;",
        "-- Candidate provider labels only; no catalog item or supply offer is created.",
    ]
    counts = {"artifacts": 0, "queued": 0, "skipped_approved": 0, "skipped_noise": 0}
    seen_runs: set[str] = set()
    for source_key, artifact in sorted(artifacts.items()):
        manifest, raw, observations = read_artifact(artifact)
        parsed = validate(manifest, raw, observations)
        if manifest.get("source_key") != source_key:
            raise ValueError(f"artifact source mismatch: {source_key}")
        brand_id = brands.get(source_key)
        if brand_id is None and brand_overrides and source_key in brand_overrides:
            brand_id = stable_id("provider-brand", brand_overrides[source_key])
        if brand_id is None:
            raise ValueError(f"source has no provider brand mapping: {source_key}")
        counts["artifacts"] += 1
        run_id = str(manifest["run_id"])
        for row in parsed:
            if str(row.get("record_type") or "") not in {"provider_offer_discovered", "provider_offer_price"}:
                continue
            external_id = str(row.get("external_record_id") or "").strip()
            payload = row.get("payload")
            if not external_id or not isinstance(payload, Mapping):
                raise ValueError(f"offer row is missing id/payload: {source_key}")
            key = (source_key, external_id)
            if key in approved:
                counts["skipped_approved"] += 1
                continue
            label = str(payload.get("provider_display_name") or "").strip()
            if not label:
                raise ValueError(f"offer has no provider label: {source_key}:{external_id}")
            decision = decisions.get((source_key, normalize(label)))
            if decision is None and source_key not in unclassified:
                raise ValueError(f"unclassified generic label: {source_key}:{normalize(label)}")
            if decision is not None and str(decision.get("classification") or "") not in SAFE_REVIEW_CLASSES:
                counts["skipped_noise"] += 1
                continue
            record_hash = str(row.get("record_hash") or "")
            if not re.fullmatch(r"[0-9a-f]{64}", record_hash):
                raise ValueError(f"offer has an invalid record hash: {source_key}:{external_id}")
            normalization_id = stable_id("normalization-run", f"{source_key}:{record_hash}")
            if normalization_id in seen_runs:
                raise ValueError(f"duplicate normalization run: {normalization_id}")
            seen_runs.add(normalization_id)
            raw_id = stable_id("ingest-raw-record", f"{run_id}:{record_hash}")
            statements.append(
                f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status) "
                f"select {q(normalization_id)},'crawler',rr.id,{q(brand_id)},{q(label)},{q(normalize(label))},{q('generic-review-puebla-v1')},'no_match' "
                f"from ingest.raw_records rr where rr.id={q(raw_id)} on conflict(id) do nothing;"
            )
            counts["queued"] += 1
    statements.append("commit;")
    return "\n".join(statements) + "\n", counts


def main() -> int:
    parser = argparse.ArgumentParser(description="Render generic provider evidence into the admin review queue")
    parser.add_argument("--mapping-fixture", type=Path, required=True)
    parser.add_argument("--review-fixture", type=Path)
    parser.add_argument("--artifact", action="append", required=True, metavar="SOURCE=PATH")
    parser.add_argument("--unclassified-source", action="append", default=[], help="allow a new source whose labels have no review fixture")
    parser.add_argument("--source-provider", action="append", default=[], metavar="SOURCE=PROVIDER", help="map a new source to an existing provider brand")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=350_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    try:
        artifacts = dict(_artifact_arg(value) for value in args.artifact)
        overrides: dict[str, str] = {}
        for value in args.source_provider:
            source, separator, provider = value.partition("=")
            if not separator or not source.strip() or not provider.strip():
                raise ValueError("source-provider must use source_key=provider_key")
            overrides[source.strip()] = provider.strip()
        sql, counts = render_queue(
            artifacts,
            _json(args.mapping_fixture),
            _json(args.review_fixture) if args.review_fixture else None,
            include_unclassified_sources={str(value).strip() for value in args.unclassified_source if str(value).strip()},
            brand_overrides=overrides,
        )
        if args.chunk_dir:
            chunks = chunk_transaction(sql, args.max_bytes)
            args.chunk_dir.mkdir(parents=True, exist_ok=True)
            for index, chunk in enumerate(chunks, start=1):
                (args.chunk_dir / f"part-{index:03d}.sql").write_text(chunk, encoding="utf-8")
            result = {**counts, "chunks": len(chunks), "bytes": sum(len(chunk.encode("utf-8")) for chunk in chunks)}
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(sql, encoding="utf-8")
            result = {**counts, "statements": sql.count(";"), "bytes": len(sql.encode("utf-8"))}
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    print(json.dumps({"status": "succeeded", **result}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
