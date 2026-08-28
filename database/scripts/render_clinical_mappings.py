"""Render reviewed provider-to-clinical mappings as idempotent SQL.

The renderer joins already ingested provider artifacts to stable canonical
clinical item IDs. It rejects missing records, changed labels, duplicate
mapping keys and invalid prices. It never creates a fuzzy equivalence.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Mapping
from uuid import UUID

try:  # Package import for tests; direct import for the CLI entrypoint.
    from .publish_golden_catalog import (
        artifact_record_hash,
        chunk_transaction,
        normalize,
        q,
        stable_id,
    )
    from .render_ingest_artifact import read_artifact, validate
except ImportError:  # pragma: no cover - exercised by the direct script command
    from publish_golden_catalog import (
        artifact_record_hash,
        chunk_transaction,
        normalize,
        q,
        stable_id,
    )
    from render_ingest_artifact import read_artifact, validate


PROVIDERS = {
    "chopo_puebla": {
        "provider_key": "chopo",
        "brand_key": "chopo",
        "brand_name": "Laboratorio Médico del Chopo",
        "slug": "laboratorio-medico-del-chopo",
        "website_url": "https://www.chopo.com.mx",
    },
    "salud_digna_puebla": {
        "provider_key": "salud_digna",
        "brand_key": "salud_digna",
        "brand_name": "Salud Digna",
        "slug": "salud-digna",
        "website_url": "https://www.salud-digna.org",
    },
}

PRICE_TYPES = {
    "regular": ("regular", "default"),
    "online": ("online", "default"),
    "promotion": ("promo", "default"),
    "blue_card": ("member", "blue_card"),
    "gold_card": ("member", "gold_card"),
    "prepaid": ("other", "prepaid"),
}


def _json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON file: {path}: {error}") from error


def _validate_fixture(fixture: object) -> list[dict]:
    if not isinstance(fixture, dict) or not isinstance(fixture.get("mappings"), list):
        raise ValueError("clinical mapping fixture must contain a mappings list")
    mappings: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for index, value in enumerate(fixture["mappings"]):
        if not isinstance(value, dict):
            raise ValueError(f"mapping {index} must be an object")
        required = ("source_key", "provider_key", "external_record_id", "catalog_item_id", "provider_alias", "reason")
        if any(not str(value.get(key) or "").strip() for key in required):
            raise ValueError(f"mapping {index} is missing a required field")
        source_key = str(value["source_key"])
        provider_key = str(value["provider_key"])
        if source_key not in PROVIDERS or PROVIDERS[source_key]["provider_key"] != provider_key:
            raise ValueError(f"mapping {index} uses an unsupported provider/source pair")
        try:
            UUID(str(value["catalog_item_id"]))
        except ValueError as error:
            raise ValueError(f"mapping {index} has an invalid catalog_item_id") from error
        key = (source_key, str(value["external_record_id"]))
        if key in seen:
            raise ValueError(f"duplicate mapping key: {key[0]}:{key[1]}")
        seen.add(key)
        mappings.append(value)
    return mappings


def _artifact_index(artifact: Path, source_key: str) -> tuple[dict, dict[str, dict]]:
    manifest, raw, observations = read_artifact(artifact)
    parsed = validate(manifest, raw, observations)
    if manifest.get("source_key") != source_key:
        raise ValueError(f"artifact source key mismatch: expected {source_key}")
    indexed: dict[str, dict] = {}
    for row in parsed:
        external_id = str(row.get("external_record_id") or "")
        if not external_id:
            continue
        if external_id in indexed:
            raise ValueError(f"duplicate external_record_id in {source_key}: {external_id}")
        indexed[external_id] = row
    return manifest, indexed


def _price_rows(payload: Mapping[str, object], *, mapping_key: str) -> list[tuple[str, str, int]]:
    prices = payload.get("prices")
    if prices is None:
        return []
    if not isinstance(prices, dict):
        raise ValueError(f"prices must be an object for {mapping_key}")
    rows: list[tuple[str, str, int]] = []
    for key, value in prices.items():
        if key not in PRICE_TYPES:
            continue
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
            raise ValueError(f"invalid price for {mapping_key}: {key}")
        amount = int(value)
        if amount <= 0:
            continue
        if float(value) != float(amount):
            raise ValueError(f"price must use integer minor units for {mapping_key}: {key}")
        price_type, price_key = PRICE_TYPES[key]
        rows.append((price_type, price_key, amount))
    return rows


def render(fixture: object, artifacts: Mapping[str, Path]) -> str:
    mappings = _validate_fixture(fixture)
    indexed_artifacts: dict[str, tuple[dict, dict[str, dict]]] = {}
    for source_key, artifact in artifacts.items():
        indexed_artifacts[source_key] = _artifact_index(artifact, source_key)

    lines = [
        "begin;",
        "-- Generated from clinical_provider_mappings_v1.json; only reviewed exact mappings are published.",
    ]
    emitted_sources: set[str] = set()
    for mapping in mappings:
        source_key = str(mapping["source_key"])
        if source_key not in indexed_artifacts:
            raise ValueError(f"mapping source has no artifact: {source_key}")
        manifest, rows = indexed_artifacts[source_key]
        external_id = str(mapping["external_record_id"])
        row = rows.get(external_id)
        if row is None:
            raise ValueError(f"mapping record does not exist in {source_key}: {external_id}")
        payload = row.get("payload")
        if not isinstance(payload, dict):
            raise ValueError(f"mapping payload is not an object: {source_key}:{external_id}")
        observed_name = str(payload.get("provider_display_name") or "").strip()
        provider_alias = str(mapping["provider_alias"]).strip()
        expected_observed_name = str(mapping.get("observed_label") or "").strip()
        if expected_observed_name:
            if observed_name != expected_observed_name:
                raise ValueError(f"mapping label changed for {source_key}:{external_id}")
        elif not observed_name or normalize(observed_name) != normalize(provider_alias):
            raise ValueError(f"mapping label changed for {source_key}:{external_id}")
        record_hash = str(row["record_hash"])
        if artifact_record_hash(payload) != record_hash:
            raise ValueError(f"mapping payload hash mismatch for {source_key}:{external_id}")

        provider = PROVIDERS[source_key]
        provider_key = str(mapping["provider_key"])
        brand_id = stable_id("provider-brand", provider["brand_key"])
        market_id = stable_id("provider-market", f"{provider['brand_key']}:puebla")
        item_id = str(mapping["catalog_item_id"])
        offer_id = stable_id("offer", f"{provider_key}:{external_id}")
        normalization_id = stable_id("normalization-run", f"clinical:{source_key}:{record_hash}")
        price_rows = _price_rows(payload, mapping_key=f"{source_key}:{external_id}")

        if source_key not in emitted_sources:
            lines.append(
                f"insert into core.provider_brands(id,name,normalized_name,slug,website_url) values ({q(brand_id)},{q(provider['brand_name'])},{q(normalize(provider['brand_name']))},{q(provider['slug'])},{q(provider['website_url'])}) on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name,website_url=excluded.website_url;"
            )
            lines.append(
                f"insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug,market_type) values ({q(market_id)},{q(brand_id)},{q('Puebla')},{q('puebla')},{q('puebla')},'city') on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name;"
            )
            emitted_sources.add(source_key)

        reason = str(mapping["reason"])
        method = str(mapping.get("method") or "manual")
        lines.append(
            f"insert into catalog.item_aliases(item_id,alias,normalized_alias,alias_type,provider_brand_id,confidence,status,source_note,approved_at) values ({q(item_id)},{q(provider_alias)},{q(normalize(provider_alias))},'provider_name',{q(brand_id)},1.0,'approved',{q(reason)},now()) on conflict (item_id,locale,provider_brand_id,normalized_alias) where provider_brand_id is not null and status <> 'rejected' do update set alias=excluded.alias,source_note=excluded.source_note,status='approved',approved_at=now();"
        )
        sku = str(payload.get("provider_sku") or payload.get("provider_external_id") or external_id)
        lines.append(
            f"insert into supply.offers(id,provider_brand_id,catalog_item_id,provider_display_name,normalized_provider_name,provider_sku,status) values ({q(offer_id)},{q(brand_id)},{q(item_id)},{q(observed_name)},{q(normalize(observed_name))},{q(sku)},'active') on conflict(id) do update set catalog_item_id=excluded.catalog_item_id,provider_display_name=excluded.provider_display_name,normalized_provider_name=excluded.normalized_provider_name,provider_sku=excluded.provider_sku,status='active';"
        )
        lines.append(
            f"insert into supply.offer_scopes(offer_id,scope_type,provider_market_id,status) values ({q(offer_id)},'market',{q(market_id)},'active') on conflict (offer_id,provider_market_id) where scope_type='market' do update set status='active';"
        )
        observation_lookup = f"(select so.id from ingest.source_observations so join ingest.raw_records rr on rr.id=so.raw_record_id where rr.crawl_run_id={q(manifest['run_id'])}::uuid and rr.record_hash={q(record_hash)} and so.entity_type='price' and so.attribute_name='prices' order by so.created_at desc limit 1)"
        for price_type, price_key, amount in price_rows:
            lines.append(
                f"update supply.price_versions pv set is_current=false,valid_to=now(),last_seen_at=now() from supply.offer_scopes os where pv.offer_scope_id=os.id and os.offer_id={q(offer_id)} and os.scope_type='market' and pv.price_type={q(price_type)} and pv.channel='any' and pv.price_key={q(price_key)} and pv.is_current and pv.amount_minor is distinct from {amount};"
            )
            lines.append(
                f"insert into supply.price_versions(offer_scope_id,price_type,channel,price_key,amount_minor,currency,source_observation_id,confidence) select os.id,{q(price_type)},'any',{q(price_key)},{amount},'MXN',{observation_lookup},1.0 from supply.offer_scopes os where os.offer_id={q(offer_id)} and os.scope_type='market' on conflict (offer_scope_id,price_type,channel,price_key) where is_current do update set amount_minor=excluded.amount_minor,last_seen_at=now(),source_observation_id=excluded.source_observation_id,is_current=true;"
            )
        lines.append(
            f"insert into supply.offer_links(offer_scope_id,link_type,url,label,status) select os.id,'details',{q(payload.get('product_url'))},{q('Provider details')},'active' from supply.offer_scopes os where os.offer_id={q(offer_id)} and not exists(select 1 from supply.offer_links l where l.offer_scope_id=os.id and l.link_type='details' and l.url={q(payload.get('product_url'))});"
        )
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status,resolved_at) select {q(normalization_id)},'crawler',rr.id,{q(brand_id)},{q(observed_name)},{q(normalize(observed_name))},{q(str(fixture.get('version','clinical-provider-mappings-v1')) if isinstance(fixture, dict) else 'clinical-provider-mappings-v1')},'resolved',now() from ingest.raw_records rr where rr.crawl_run_id={q(manifest['run_id'])}::uuid and rr.record_hash={q(record_hash)} on conflict(id) do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_candidates(normalization_run_id,catalog_item_id,rank,score,method,explanation_data) values ({q(normalization_id)},{q(item_id)},1,1.0,{q(method)},{q(json.dumps({'reason': reason, 'source_key': source_key, 'external_record_id': external_id}, ensure_ascii=False, separators=(',', ':')))}::jsonb) on conflict do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(normalization_run_id,selected_item_id,decision_type,reason) values ({q(normalization_id)},{q(item_id)},'manual',{q(reason)}) on conflict do nothing;"
        )
    lines.append("commit;")
    return "\n".join(lines) + "\n"


def _parse_artifact(value: str) -> tuple[str, Path]:
    source_key, separator, path = value.partition("=")
    if not separator or not source_key or not path:
        raise argparse.ArgumentTypeError("artifact must use source_key=path")
    return source_key, Path(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--artifact", action="append", type=_parse_artifact, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=400_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    fixture = _json(args.fixture)
    artifacts = dict(args.artifact)
    sql = render(fixture, artifacts)
    if args.chunk_dir:
        chunks = chunk_transaction(sql, args.max_bytes)
        args.chunk_dir.mkdir(parents=True, exist_ok=True)
        for index, chunk in enumerate(chunks, start=1):
            (args.chunk_dir / f"part-{index:03d}.sql").write_text(chunk, encoding="utf-8")
        print(json.dumps({"chunks": len(chunks), "bytes": len(sql.encode("utf-8"))}))
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(sql, encoding="utf-8")
        print(json.dumps({"statements": sql.count(";"), "bytes": len(sql.encode("utf-8"))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
