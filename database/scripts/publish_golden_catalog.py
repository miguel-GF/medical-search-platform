"""Render an auditable golden-catalog publication transaction.

The script never guesses equivalence. Its input fixture contains the reviewed
mapping set; all other collected labels become explicit normalization runs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import unicodedata
from pathlib import Path
from urllib.parse import urlparse
from uuid import NAMESPACE_URL, uuid5


def stable_id(kind: str, key: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"https://pruevia.local/{kind}/{key}"))


def normalize(value: str) -> str:
    plain = "".join(c for c in unicodedata.normalize("NFKD", value.casefold()) if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", plain).strip()


def q(value: object | None) -> str:
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def jb(value: object) -> str:
    return q(json.dumps(value, ensure_ascii=False, separators=(",", ":"))) + "::jsonb"


def sql_geography(coordinates: dict | None) -> str:
    if not coordinates:
        return "NULL"
    try:
        longitude = float(coordinates["longitude"])
        latitude = float(coordinates["latitude"])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError("provider coordinates must contain numeric latitude and longitude") from error
    if not all(math.isfinite(value) for value in (latitude, longitude)) or not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        raise ValueError("provider coordinates are outside valid geographic bounds")
    return f"gis.ST_SetSRID(gis.ST_MakePoint({longitude:.15g}, {latitude:.15g}), 4326)::gis.geography"


def artifact_record_hash(payload: object) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_url(value: object, label: str) -> None:
    if value is None:
        return
    parsed = urlparse(str(value))
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"{label} must be an absolute HTTP(S) URL")


def validate_artifact(manifest: dict, raw: list[dict], observations: list[dict], expected_source_key: str) -> None:
    if manifest.get("status") != "succeeded":
        raise ValueError(f"{expected_source_key} artifact is not succeeded")
    if manifest.get("errors"):
        raise ValueError(f"{expected_source_key} artifact contains collector errors")
    if manifest.get("source_key") != expected_source_key:
        raise ValueError(f"artifact source key mismatch for {expected_source_key}")
    if len(raw) != int(manifest.get("records_received", -1)):
        raise ValueError(f"{expected_source_key} raw record count does not match its manifest")
    parsed_hashes: set[str] = set()
    parsed_count = 0
    rejected_count = 0
    for row in raw:
        if row.get("source_key") != expected_source_key:
            raise ValueError(f"{expected_source_key} artifact contains another source")
        if row.get("parse_status") != "parsed":
            rejected_count += 1
            continue
        parsed_count += 1
        record_hash = row.get("record_hash")
        if not isinstance(record_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", record_hash):
            raise ValueError(f"{expected_source_key} artifact contains an invalid record hash")
        if artifact_record_hash(row.get("payload")) != record_hash:
            raise ValueError(f"{expected_source_key} artifact record hash mismatch")
        parsed_hashes.add(record_hash)
        validate_url(row.get("source_url"), f"{expected_source_key} source_url")
        payload = row.get("payload") or {}
        validate_url(payload.get("product_url"), f"{expected_source_key} product_url")
    if parsed_count != int(manifest.get("records_valid", -1)) or rejected_count != int(manifest.get("records_rejected", -1)):
        raise ValueError(f"{expected_source_key} artifact counts do not match its manifest")
    for row in observations:
        if row.get("record_hash") not in parsed_hashes:
            raise ValueError(f"{expected_source_key} contains an orphan observation")


def read_artifact(path: Path) -> tuple[dict, list[dict], list[dict]]:
    manifest = json.loads((path / "run_manifest.json").read_text(encoding="utf-8"))
    raw = [json.loads(line) for line in (path / "raw_records.jsonl").read_text(encoding="utf-8").splitlines() if line]
    observations = [
        json.loads(line) for line in (path / "observations.jsonl").read_text(encoding="utf-8").splitlines() if line
    ]
    return manifest, raw, observations


def render(fixture: dict, ruiz_artifact: Path, chopo_artifact: Path, salud_digna_artifact: Path | None = None) -> str:
    ruiz_manifest, ruiz_raw, ruiz_observations = read_artifact(ruiz_artifact)
    chopo_manifest, chopo_raw, chopo_observations = read_artifact(chopo_artifact)
    validate_artifact(ruiz_manifest, ruiz_raw, ruiz_observations, "ruiz_puebla")
    validate_artifact(chopo_manifest, chopo_raw, chopo_observations, "chopo_puebla")
    artifacts = {
        "ruiz_puebla": (ruiz_manifest, ruiz_raw, ruiz_observations),
        "chopo_puebla": (chopo_manifest, chopo_raw, chopo_observations),
    }
    if salud_digna_artifact:
        salud_manifest, salud_raw, salud_observations = read_artifact(salud_digna_artifact)
        validate_artifact(salud_manifest, salud_raw, salud_observations, "salud_digna_puebla")
        artifacts["salud_digna_puebla"] = (salud_manifest, salud_raw, salud_observations)
    brands = fixture["brands"]
    brand_ids = {key: stable_id("provider-brand", data["brand_key"]) for key, data in brands.items()}
    market_ids = {key: stable_id("provider-market", f"{data['brand_key']}:puebla") for key, data in brands.items()}
    item_by_key = {item["catalog_key"]: item for item in fixture["items"]}
    lines = ["begin;", "-- Generated from catalog_golden_v1.json; no fuzzy mappings are created."]

    for source_key, data in brands.items():
        brand_id = brand_ids[source_key]
        market_id = market_ids[source_key]
        lines.append(
            f"insert into core.provider_brands(id,name,normalized_name,slug,website_url) values ({q(brand_id)},{q(data['brand_name'])},{q(normalize(data['brand_name']))},{q(data['slug'])},{q({'chopo':'https://www.chopo.com.mx','ruiz':'https://laboratoriosruiz.com','salud_digna':'https://www.salud-digna.org'}[data['brand_key']])}) on conflict(id) do update set name=excluded.name, normalized_name=excluded.normalized_name, website_url=excluded.website_url;"
        )
        lines.append(
            f"insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug,market_type) values ({q(market_id)},{q(brand_id)},{q('Puebla')},{q('puebla')},{q('puebla')},'city') on conflict(id) do update set name=excluded.name, normalized_name=excluded.normalized_name;"
        )

    # Official provider locations are safe to publish as candidates.
    for source_key, (_, raw, _) in artifacts.items():
        if source_key not in brand_ids:
            continue
        for row in raw:
            if row.get("record_type") != "provider_location_discovered":
                continue
            payload = row["payload"]
            external_id = str(payload.get("provider_external_id") or row.get("external_record_id"))
            # Ruiz locations were published in V1 with the historical
            # ``ruiz:<external_id>`` key; preserve those IDs while allowing
            # additional providers to use their source key without collisions.
            location_key = f"ruiz:{external_id}" if source_key == "ruiz_puebla" else f"{source_key}:{external_id}"
            location_id = stable_id("provider-location", location_key)
            lines.append(
                f"insert into core.provider_locations(id,provider_brand_id,name,normalized_name,location_code,address_line_1,address_line_2,locality_text,postal_code,coordinates,timezone,phone,website_url,status) values ({q(location_id)},{q(brand_ids[source_key])},{q(payload.get('provider_display_name'))},{q(normalize(str(payload.get('provider_display_name') or '')))},{q(external_id)},{q(payload.get('address_line_1'))},{q(payload.get('address_line_2'))},{q(payload.get('locality_text'))},{q(payload.get('postal_code'))},{sql_geography(payload.get('coordinates'))},{q('America/Mexico_City')},{q(payload.get('phone'))},{q(payload.get('location_url'))},'active') on conflict(id) do update set name=excluded.name,address_line_1=excluded.address_line_1,coordinates=excluded.coordinates,phone=excluded.phone,updated_at=now();"
            )
            lines.append(
                f"insert into core.location_external_ids(provider_location_id,source_system,external_id,external_url) values ({q(location_id)},{q(source_key)},{q(external_id)},{q(payload.get('location_url'))}) on conflict(source_system,external_id) do nothing;"
            )
            lines.append(
                f"insert into core.provider_market_locations(provider_market_id,provider_location_id) values ({q(market_ids[source_key])},{q(location_id)}) on conflict do nothing;"
            )

    # Canonical catalog + category + health metadata.
    for item in fixture["items"]:
        item_id = item["item_id"]
        lines.append(
            f"insert into catalog.items(id,domain_id,item_type,status) select {q(item_id)},d.id,{q(item['item_type'])},{q(item['status'])} from catalog.domains d where d.code='health_diagnostics' on conflict(id) do update set item_type=excluded.item_type,status=excluded.status;"
        )
        lines.append(
            f"insert into catalog.item_names(item_id,locale,name,normalized_name,name_type,is_primary) values ({q(item_id)},'es-MX',{q(item['canonical_name'])},{q(item['normalized_name'])},'canonical',true) on conflict(item_id,locale,normalized_name) do update set name=excluded.name,is_primary=true;"
        )
        lines.append(
            f"insert into health.services(catalog_item_id,service_type,clinical_equivalence_policy) values ({q(item_id)},{q(item['service_type'])},{q(item['clinical_equivalence_policy'])}) on conflict(catalog_item_id) do update set service_type=excluded.service_type,clinical_equivalence_policy=excluded.clinical_equivalence_policy;"
        )
        lines.append(
            f"insert into catalog.item_categories(item_id,category_id,is_primary) select {q(item_id)},c.id,true from catalog.categories c join catalog.domains d on d.id=c.domain_id where d.code='health_diagnostics' and c.code={q(item['category_code'])} on conflict(item_id,category_id) do update set is_primary=true;"
        )
        for alias in item["provider_aliases"]:
            brand_id = brand_ids[alias["provider_key"]]
            lines.append(
                f"insert into catalog.item_aliases(item_id,alias,normalized_alias,alias_type,provider_brand_id,confidence,status,source_note,approved_at) values ({q(item_id)},{q(alias['alias'])},{q(normalize(alias['alias']))},{q(alias['alias_type'])},{q(brand_id)},{alias['confidence']},'approved',{q(alias['source_note'])},now()) on conflict do nothing;"
            )

    raw_by_source_hash = {}
    for source_key, (_, raw, _) in artifacts.items():
        for row in raw:
            raw_by_source_hash[(source_key, row.get("record_hash"))] = row

    # Publish only reviewed mappings; all other offers remain in ingest/normalization.
    for mapping in fixture["mappings"]:
        source_key = mapping["source_key"]
        provider_key = mapping["provider_key"]
        row = raw_by_source_hash.get((source_key, mapping["record_hash"]))
        if not row:
            raise ValueError(f"golden mapping does not exist in {source_key}: {mapping['record_hash']}")
        payload = row["payload"]
        item = item_by_key[mapping["catalog_key"]]
        brand_id = brand_ids[source_key]
        market_id = market_ids[source_key]
        offer_id = stable_id("offer", f"{provider_key}:{mapping['external_record_id']}")
        display_name = str(payload.get("provider_display_name") or item["canonical_name"])
        sku = payload.get("provider_sku") or payload.get("provider_external_id") or mapping["external_record_id"]
        lines.append(
            f"insert into supply.offers(id,provider_brand_id,catalog_item_id,provider_display_name,normalized_provider_name,provider_sku,status) values ({q(offer_id)},{q(brand_id)},{q(item['item_id'])},{q(display_name)},{q(normalize(display_name))},{q(sku)},'active') on conflict(id) do update set provider_display_name=excluded.provider_display_name,normalized_provider_name=excluded.normalized_provider_name,provider_sku=excluded.provider_sku,status='active';"
        )
        lines.append(
            f"insert into supply.offer_scopes(offer_id,scope_type,provider_market_id,status) values ({q(offer_id)},'market',{q(market_id)},'active') on conflict do nothing;"
        )
        for price_key, amount in (payload.get("prices") or {}).items():
            # Provider APIs use zero as a sentinel for an unavailable discount.
            # It is not a real free diagnostic service and must not reach search.
            if not isinstance(amount, (int, float)) or isinstance(amount, bool) or not math.isfinite(float(amount)):
                raise ValueError(f"invalid price amount for {mapping['external_record_id']}: {amount!r}")
            if int(amount) <= 0:
                continue
            if float(amount) != float(int(amount)):
                raise ValueError(f"price amount must be an integer minor-unit value: {amount!r}")
            type_map = {"regular": ("regular", "default"), "online": ("online", "default"), "promotion": ("promo", "default"), "blue_card": ("member", "blue_card"), "gold_card": ("member", "gold_card"), "prepaid": ("other", "prepaid")}
            price_type, db_price_key = type_map.get(price_key, ("other", price_key))
            obs_lookup = f"(select so.id from ingest.source_observations so join ingest.raw_records rr on rr.id=so.raw_record_id where rr.crawl_run_id={q(artifacts[source_key][0]['run_id'])}::uuid and rr.record_hash={q(mapping['record_hash'])} and so.entity_type='price' and so.attribute_name='prices' limit 1)"
            lines.append(
                f"update supply.price_versions pv set is_current=false,valid_to=now(),last_seen_at=now() from supply.offer_scopes os where pv.offer_scope_id=os.id and os.offer_id={q(offer_id)} and os.scope_type='market' and pv.price_type={q(price_type)} and pv.channel='any' and pv.price_key={q(db_price_key)} and pv.is_current and pv.amount_minor is distinct from {int(amount)};"
            )
            lines.append(
                f"insert into supply.price_versions(offer_scope_id,price_type,channel,price_key,amount_minor,currency,source_observation_id,confidence) select os.id,{q(price_type)},'any',{q(db_price_key)},{int(amount)},'MXN',{obs_lookup},1.0 from supply.offer_scopes os where os.offer_id={q(offer_id)} and os.scope_type='market' on conflict (offer_scope_id,price_type,channel,price_key) where is_current do update set last_seen_at=now(),source_observation_id=excluded.source_observation_id,is_current=true;"
            )
        lines.append(
            f"insert into supply.offer_links(offer_scope_id,link_type,url,label,status) select os.id,'details',{q(payload.get('product_url'))},{q('Provider details')},'active' from supply.offer_scopes os where os.offer_id={q(offer_id)} and not exists(select 1 from supply.offer_links l where l.offer_scope_id=os.id and l.link_type='details' and l.url={q(payload.get('product_url'))});"
        )
        normalization_id = stable_id("normalization-run", f"{source_key}:{mapping['record_hash']}")
        method = str(mapping.get("method") or ("exact" if source_key == "ruiz_puebla" else "alias"))
        mapping_reason = str(
            mapping.get("reason")
            or ("Exact normalized provider label approved in golden catalog V1" if method != "manual" else "Reviewed manual provider equivalence")
        )
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status,resolved_at) select {q(normalization_id)},'crawler',rr.id,{q(brand_id)},{q(display_name)},{q(normalize(display_name))},{q(fixture['version'])},'resolved',now() from ingest.raw_records rr where rr.crawl_run_id={q(artifacts[source_key][0]['run_id'])}::uuid and rr.record_hash={q(mapping['record_hash'])} on conflict(id) do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_candidates(normalization_run_id,catalog_item_id,rank,score,method,explanation_data) values ({q(normalization_id)},{q(item['item_id'])},1,1.0,{q(method)},{jb({'reason':mapping_reason,'source_key':source_key})}) on conflict do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(normalization_run_id,selected_item_id,decision_type,reason) select {q(normalization_id)},{q(item['item_id'])},'automatic',{q(mapping_reason)} where not exists(select 1 from ingest.normalization_decisions where normalization_run_id={q(normalization_id)} and decision_type='automatic');"
        )

    # Keep every unresolved provider label auditable in the normalization queue.
    for queue in fixture["normalization_queue"]:
        source_key = queue.get("source_key", "chopo_puebla")
        source_artifact = artifacts.get(source_key)
        if not source_artifact:
            raise ValueError(f"normalization queue source has no artifact: {source_key}")
        queue_by_external = {str(row.get("external_record_id")): row for row in source_artifact[1]}
        row = queue_by_external.get(str(queue["raw_record_id"]))
        if not row:
            raise ValueError(f"normalization queue record does not exist in {source_key} artifact: {queue['raw_record_id']}")
        run_id = stable_id("normalization-run", f"{source_key}:{row.get('record_hash')}")
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status) select {q(run_id)},'crawler',rr.id,{q(brand_ids[source_key])},{q(queue['raw_text'])},{q(queue['normalized_input'])},{q(fixture['version'])},'no_match' from ingest.raw_records rr where rr.crawl_run_id={q(source_artifact[0]['run_id'])}::uuid and rr.record_hash={q(row.get('record_hash'))} on conflict(id) do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(normalization_run_id,decision_type,reason) select {q(run_id)},'no_match',{q(queue['reason'])} where not exists(select 1 from ingest.normalization_decisions where normalization_run_id={q(run_id)} and decision_type='no_match');"
        )

    lines.append("commit;")
    return "\n".join(lines) + "\n"


def chunk_transaction(sql: str, max_bytes: int = 450_000) -> list[str]:
    """Split a rendered transaction into re-runnable linked-query batches."""
    if max_bytes < 1024:
        raise ValueError("max_bytes must be at least 1024")
    statements = sql.splitlines()
    if not statements or statements[0] != "begin;" or statements[-1] != "commit;":
        raise ValueError("SQL must start with begin; and end with commit;")
    chunks: list[str] = []
    current: list[str] = []
    overhead = len(b"begin;\ncommit;\n")
    current_bytes = overhead
    for statement in statements[1:-1]:
        statement_bytes = len(statement.encode("utf-8")) + 1
        if statement_bytes + overhead > max_bytes:
            raise ValueError("a single SQL statement exceeds max_bytes")
        if current and current_bytes + statement_bytes > max_bytes:
            chunks.append("begin;\n" + "\n".join(current) + "\ncommit;\n")
            current = []
            current_bytes = overhead
        current.append(statement)
        current_bytes += statement_bytes
    if current:
        chunks.append("begin;\n" + "\n".join(current) + "\ncommit;\n")
    return chunks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--ruiz-artifact", type=Path, required=True)
    parser.add_argument("--chopo-artifact", type=Path, required=True)
    parser.add_argument("--salud-digna-artifact", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=450_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    sql = render(json.loads(args.fixture.read_text(encoding="utf-8")), args.ruiz_artifact, args.chopo_artifact, args.salud_digna_artifact)
    if args.chunk_dir:
        chunks = chunk_transaction(sql, args.max_bytes)
        args.chunk_dir.mkdir(parents=True, exist_ok=True)
        for index, chunk in enumerate(chunks, start=1):
            (args.chunk_dir / f"part-{index:03d}.sql").write_text(chunk, encoding="utf-8")
        print(json.dumps({"chunks": len(chunks), "bytes": sum(len(chunk.encode('utf-8')) for chunk in chunks)}))
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(sql, encoding="utf-8")
        print(json.dumps({"statements": sql.count(";"), "bytes": len(sql.encode('utf-8'))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
