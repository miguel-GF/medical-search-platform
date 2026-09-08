"""Render reviewed generic-provider mappings as an idempotent SQL transaction.

Generic discovery is deliberately conservative: the crawler produces public
website evidence, while this renderer publishes only mappings that were
reviewed as exact catalog labels.  DENUE rows are used for candidate identity
and location provenance; they never turn an arbitrary web label into a
canonical clinical service by themselves.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Mapping
from urllib.parse import urlparse
from uuid import UUID

try:  # Package import for tests; direct import for the CLI entrypoint.
    from .publish_golden_catalog import chunk_transaction, normalize, q, sql_geography, stable_id
    from .render_ingest_artifact import read_artifact, validate
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
except ImportError:  # pragma: no cover - exercised by direct script invocation
    from publish_golden_catalog import chunk_transaction, normalize, q, sql_geography, stable_id
    from render_ingest_artifact import read_artifact, validate
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file


SOURCE_KEY_RE = re.compile(r"^[a-z0-9_]+$")
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ALLOWED_METHODS = {"manual", "exact"}


def _json(path: Path) -> object:
    try:
        return read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        raise ValueError(f"invalid JSON file: {path}: {error}") from error


def _host(value: str) -> str:
    parsed = urlparse(value)
    return (parsed.hostname or "").casefold().rstrip(".")


def _site_host(value: str) -> str:
    host = _host(value)
    return host[4:] if host.startswith("www.") else host


def _validate_url(value: object, label: str) -> str:
    raw = str(value or "").strip()
    parsed = urlparse(raw)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError(f"{label} must be an absolute HTTP(S) URL without credentials")
    try:
        port = parsed.port
    except ValueError as error:
        raise ValueError(f"{label} has an invalid port") from error
    if port not in (None, 80, 443):
        raise ValueError(f"{label} must use a standard HTTP(S) port")
    return raw


def _validate_fixture(fixture: object) -> tuple[dict[str, dict], list[dict]]:
    if not isinstance(fixture, dict):
        raise ValueError("generic mapping fixture must be an object")
    providers_value = fixture.get("providers")
    mappings_value = fixture.get("mappings")
    if not isinstance(providers_value, list) or not isinstance(mappings_value, list):
        raise ValueError("generic mapping fixture must contain providers and mappings arrays")

    providers: dict[str, dict] = {}
    provider_keys: set[str] = set()
    slugs: set[str] = set()
    for index, value in enumerate(providers_value):
        if not isinstance(value, dict):
            raise ValueError(f"provider {index} must be an object")
        required = ("source_key", "provider_key", "brand_name", "slug", "website_url", "denue_record_ids")
        if any(not str(value.get(key) or "").strip() for key in required):
            raise ValueError(f"provider {index} is missing a required field")
        source_key = str(value["source_key"]).strip()
        provider_key = str(value["provider_key"]).strip()
        slug = str(value["slug"]).strip()
        if not SOURCE_KEY_RE.fullmatch(source_key) or source_key in providers:
            raise ValueError(f"provider {index} has a duplicate or invalid source_key")
        if not SOURCE_KEY_RE.fullmatch(provider_key) or provider_key in provider_keys:
            raise ValueError(f"provider {index} has a duplicate or invalid provider_key")
        if not SLUG_RE.fullmatch(slug) or slug in slugs:
            raise ValueError(f"provider {index} has a duplicate or invalid slug")
        website_url = _validate_url(value["website_url"], f"provider {source_key} website_url")
        denue_ids = value["denue_record_ids"]
        if not isinstance(denue_ids, list) or not denue_ids or any(not str(item).strip() for item in denue_ids):
            raise ValueError(f"provider {source_key} must list at least one DENUE record")
        providers[source_key] = {
            **value,
            "source_key": source_key,
            "provider_key": provider_key,
            "slug": slug,
            "website_url": website_url,
            "denue_record_ids": tuple(sorted({str(item).strip() for item in denue_ids})),
        }
        provider_keys.add(provider_key)
        slugs.add(slug)

    mappings: list[dict] = []
    seen_records: set[tuple[str, str]] = set()
    seen_provider_items: set[tuple[str, str]] = set()
    for index, value in enumerate(mappings_value):
        if not isinstance(value, dict):
            raise ValueError(f"mapping {index} must be an object")
        required = (
            "source_key",
            "provider_key",
            "external_record_id",
            "catalog_item_id",
            "provider_alias",
            "observed_label",
            "reason",
        )
        if any(not str(value.get(key) or "").strip() for key in required):
            raise ValueError(f"mapping {index} is missing a required field")
        source_key = str(value["source_key"]).strip()
        provider_key = str(value["provider_key"]).strip()
        external_id = str(value["external_record_id"]).strip()
        if source_key not in providers or providers[source_key]["provider_key"] != provider_key:
            raise ValueError(f"mapping {index} uses an unsupported provider/source pair")
        try:
            UUID(str(value["catalog_item_id"]))
        except ValueError as error:
            raise ValueError(f"mapping {index} has an invalid catalog_item_id") from error
        method = str(value.get("method") or "manual").strip()
        if method not in ALLOWED_METHODS:
            raise ValueError(f"mapping {index} has an unsupported method")
        record_key = (source_key, external_id)
        provider_item_key = (provider_key, str(value["catalog_item_id"]))
        if record_key in seen_records:
            raise ValueError(f"duplicate generic mapping record: {source_key}:{external_id}")
        if provider_item_key in seen_provider_items:
            raise ValueError(f"provider has more than one primary mapping for catalog item: {provider_key}")
        # An exact approval can normalize accents and punctuation, but it may
        # not silently rename a provider's label to a different clinical term.
        if normalize(str(value["provider_alias"])) != normalize(str(value["observed_label"])):
            raise ValueError(f"mapping {index} provider_alias differs from observed_label")
        mappings.append({**value, "source_key": source_key, "provider_key": provider_key, "external_record_id": external_id, "method": method})
        seen_records.add(record_key)
        seen_provider_items.add(provider_item_key)
    return providers, mappings


def _denue_rows(value: object) -> dict[str, dict]:
    if not isinstance(value, dict) or not isinstance(value.get("candidates"), list):
        raise ValueError("DENUE fixture must contain a candidates array")
    rows: dict[str, dict] = {}
    for row in value["candidates"]:
        if not isinstance(row, dict):
            continue
        external_id = str(row.get("external_record_id") or "").strip()
        if external_id:
            rows[external_id] = row
    return rows


def _validate_denue(providers: Mapping[str, dict], denue: object) -> dict[str, dict]:
    rows = _denue_rows(denue)
    selected: dict[str, dict] = {}
    for source_key, provider in providers.items():
        provider_host = _site_host(str(provider["website_url"]))
        for external_id in provider["denue_record_ids"]:
            row = rows.get(external_id)
            if row is None:
                raise ValueError(f"DENUE record does not exist: {external_id}")
            if str(row.get("classification") or "") != "direct_clinical":
                raise ValueError(f"DENUE record is not a direct clinical candidate: {external_id}")
            website = str(row.get("website_url") or "").strip()
            if not website or _site_host(_validate_url(website if "://" in website else f"https://{website}", f"DENUE {external_id} website_url")) != provider_host:
                raise ValueError(f"DENUE website does not match provider site for {external_id}")
            coordinates = row.get("coordinates")
            if not isinstance(coordinates, dict):
                raise ValueError(f"DENUE record has no coordinates: {external_id}")
            try:
                latitude = float(coordinates["latitude"])
                longitude = float(coordinates["longitude"])
            except (KeyError, TypeError, ValueError) as error:
                raise ValueError(f"DENUE coordinates are invalid: {external_id}") from error
            if not all(math.isfinite(item) for item in (latitude, longitude)) or not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
                raise ValueError(f"DENUE coordinates are outside bounds: {external_id}")
            selected[external_id] = row
    return selected


def _artifact_index(artifact: Path, expected_source_key: str) -> tuple[dict, dict[str, dict]]:
    manifest, raw, observations = read_artifact(artifact)
    parsed = validate(manifest, raw, observations)
    if manifest.get("source_key") != expected_source_key:
        raise ValueError(f"artifact source key mismatch: expected {expected_source_key}")
    indexed: dict[str, dict] = {}
    for row in parsed:
        external_id = str(row.get("external_record_id") or "")
        if external_id in indexed:
            raise ValueError(f"duplicate external_record_id in {expected_source_key}: {external_id}")
        indexed[external_id] = row
    return manifest, indexed


def _address(row: Mapping[str, object]) -> tuple[str | None, str | None, str | None]:
    address = row.get("address")
    if not isinstance(address, Mapping):
        return None, None, None
    street = str(address.get("street") or "").strip()
    exterior = str(address.get("exterior_number") or "").strip()
    interior = str(address.get("interior_number") or "").strip()
    neighborhood = str(address.get("neighborhood") or "").strip()
    line_1 = " ".join(item for item in (street, exterior) if item) or None
    line_2 = " ".join(item for item in ((f"Int. {interior}" if interior and interior != "0" else ""), neighborhood) if item) or None
    locality = ", ".join(item for item in (str(address.get("locality") or "").strip(), str(address.get("municipality") or "").strip(), str(address.get("state") or "").strip()) if item) or None
    return line_1, line_2, locality


def render(fixture: object, artifacts: Mapping[str, Path], denue_fixture: object) -> str:
    providers, mappings = _validate_fixture(fixture)
    denue_rows = _validate_denue(providers, denue_fixture)
    indexed_artifacts: dict[str, tuple[dict, dict[str, dict]]] = {}
    for source_key, provider in providers.items():
        if source_key not in artifacts:
            raise ValueError(f"provider source has no artifact: {source_key}")
        indexed_artifacts[source_key] = _artifact_index(artifacts[source_key], source_key)

    for mapping in mappings:
        manifest, rows = indexed_artifacts[mapping["source_key"]]
        row = rows.get(mapping["external_record_id"])
        if row is None or row.get("record_type") not in {"provider_offer_discovered", "provider_offer_price"}:
            raise ValueError(f"mapping record is not a provider offer: {mapping['source_key']}:{mapping['external_record_id']}")
        payload = row.get("payload")
        if not isinstance(payload, dict):
            raise ValueError(f"mapping payload is not an object: {mapping['source_key']}:{mapping['external_record_id']}")
        observed = str(payload.get("provider_display_name") or "").strip()
        if normalize(observed) != normalize(str(mapping["observed_label"])):
            raise ValueError(f"mapping label changed for {mapping['source_key']}:{mapping['external_record_id']}")
        prices = payload.get("prices") or {}
        if not isinstance(prices, dict):
            raise ValueError(f"mapping prices is not an object: {mapping['source_key']}:{mapping['external_record_id']}")
        for price_key, amount in prices.items():
            if isinstance(amount, bool) or not isinstance(amount, (int, float)) or not math.isfinite(float(amount)) or int(amount) <= 0 or float(amount) != float(int(amount)):
                raise ValueError(f"mapping contains an invalid price: {mapping['source_key']}:{mapping['external_record_id']}:{price_key}")

    lines = [
        "begin;",
        "-- Generated from generic_provider_mappings_puebla_v1.json; only reviewed exact mappings are published.",
    ]
    brand_ids: dict[str, str] = {}
    market_ids: dict[str, str] = {}
    source_ids: dict[str, str] = {}
    for source_key, provider in providers.items():
        provider_key = str(provider["provider_key"])
        brand_id = stable_id("provider-brand", provider_key)
        market_id = stable_id("provider-market", f"{provider_key}:puebla")
        source_id = stable_id("ingest-source", source_key)
        brand_ids[source_key] = brand_id
        market_ids[source_key] = market_id
        source_ids[source_key] = source_id
        identity_note = str(provider.get("identity_note") or "DENUE direct clinical candidate plus matching public website domain; provider remains verification_pending.")
        lines.append(
            f"insert into core.provider_brands(id,name,normalized_name,slug,description,website_url,status,verification_status) values ({q(brand_id)},{q(provider['brand_name'])},{q(normalize(str(provider['brand_name'])))},{q(provider['slug'])},{q(identity_note)},{q(provider['website_url'])},'active','verification_pending') on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name,description=excluded.description,website_url=excluded.website_url,status='active',verification_status='verification_pending';"
        )
        lines.append(
            f"insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug,market_type,status) values ({q(market_id)},{q(brand_id)},{q('Puebla')},{q('puebla')},{q('puebla')},'city','active') on conflict (provider_brand_id,slug) do update set name=excluded.name,normalized_name=excluded.normalized_name,status='active';"
        )
        lines.append(
            f"update ingest.sources set provider_brand_id={q(brand_id)},notes={q(identity_note)},updated_at=now() where id={q(source_id)};"
        )

        for external_id in provider["denue_record_ids"]:
            row = denue_rows[external_id]
            location_id = stable_id("provider-location", f"denue:{provider_key}:{external_id}")
            line_1, line_2, locality = _address(row)
            coordinates = row["coordinates"]
            location_name = str(row.get("name") or row.get("legal_name") or provider["brand_name"]).strip()
            location_url = str(row.get("source_url") or f"https://www.inegi.org.mx/app/api/denue/v1/consulta/Ficha/{external_id}")
            lines.append(
                f"insert into core.provider_locations(id,provider_brand_id,name,normalized_name,location_code,location_type,address_line_1,address_line_2,locality_text,postal_code,coordinates,timezone,phone,website_url,status) values ({q(location_id)},{q(brand_id)},{q(location_name)},{q(normalize(location_name))},{q(f'denue:{external_id}')},'lab',{q(line_1)},{q(line_2)},{q(locality)},{q(str(row.get('postal_code') or '').strip() or None)},{sql_geography(coordinates)},{q('America/Mexico_City')},{q(str(row.get('phone') or '').strip() or None)},{q(provider['website_url'])},'active') on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name,address_line_1=excluded.address_line_1,address_line_2=excluded.address_line_2,locality_text=excluded.locality_text,postal_code=excluded.postal_code,coordinates=excluded.coordinates,phone=excluded.phone,website_url=excluded.website_url,status='active',updated_at=now();"
            )
            lines.append(
                f"insert into core.location_external_ids(provider_location_id,source_system,external_id,external_url) values ({q(location_id)},'denue',{q(external_id)},{q(location_url)}) on conflict(source_system,external_id) do update set provider_location_id=excluded.provider_location_id,external_url=excluded.external_url;"
            )
            lines.append(
                f"insert into core.provider_market_locations(provider_market_id,provider_location_id) values ({q(market_id)},{q(location_id)}) on conflict do nothing;"
            )
            denue_run_id = str((denue_fixture if isinstance(denue_fixture, dict) else {}).get("source_run_id") or "")
            denue_hash = str(row.get("record_hash") or "")
            if denue_run_id and denue_hash:
                denue_raw_id = stable_id("ingest-raw-record", f"{denue_run_id}:{denue_hash}")
                identity_observation_id = stable_id("ingest-observation", f"{denue_run_id}:{denue_hash}:generic_identity")
                identity_value = json.dumps(
                    {"denue_record_id": external_id, "provider_key": provider_key, "website": provider["website_url"]},
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
                lines.append(
                    f"insert into ingest.source_observations(id,source_id,raw_record_id,entity_type,entity_id,attribute_name,observed_value,observed_at,confidence,status) values ({q(identity_observation_id)},{q(stable_id('ingest-source','denue'))},{q(denue_raw_id)},{q('provider_location')},{q(location_id)},{q('generic_identity')},{q(identity_value)}::jsonb,now(),0.8000,'accepted') on conflict(id) do update set entity_id=excluded.entity_id,observed_value=excluded.observed_value,confidence=excluded.confidence,status='accepted';"
                )

    emitted_items: set[str] = set()
    for mapping in mappings:
        source_key = str(mapping["source_key"])
        provider = providers[source_key]
        manifest, rows = indexed_artifacts[source_key]
        row = rows[str(mapping["external_record_id"])]
        payload = row["payload"]
        provider_key = str(mapping["provider_key"])
        brand_id = brand_ids[source_key]
        market_id = market_ids[source_key]
        external_id = str(mapping["external_record_id"])
        record_hash = str(row["record_hash"])
        run_id = str(manifest["run_id"])
        raw_id = stable_id("ingest-raw-record", f"{run_id}:{record_hash}")
        offer_id = stable_id("offer", f"{provider_key}:{external_id}")
        normalization_id = stable_id("normalization-run", f"{source_key}:{record_hash}")
        display_name = str(payload.get("provider_display_name") or mapping["observed_label"]).strip()
        sku = str(payload.get("provider_sku") or payload.get("provider_external_id") or external_id)
        lines.append(
            f"insert into supply.offers(id,provider_brand_id,catalog_item_id,provider_display_name,normalized_provider_name,provider_sku,requires_quote,is_bookable,status) values ({q(offer_id)},{q(brand_id)},{q(mapping['catalog_item_id'])},{q(display_name)},{q(normalize(display_name))},{q(sku)},true,false,'active') on conflict(id) do update set catalog_item_id=excluded.catalog_item_id,provider_display_name=excluded.provider_display_name,normalized_provider_name=excluded.normalized_provider_name,provider_sku=excluded.provider_sku,requires_quote=true,is_bookable=false,status='active';"
        )
        lines.append(
            f"insert into supply.offer_scopes(offer_id,scope_type,provider_market_id,status) values ({q(offer_id)},'market',{q(market_id)},'active') on conflict (offer_id,provider_market_id) where scope_type='market' do update set status='active';"
        )
        lines.append(
            f"insert into supply.offer_links(offer_scope_id,link_type,url,label,status) select os.id,'details',{q(payload.get('product_url'))},{q('Provider details')},'active' from supply.offer_scopes os where os.offer_id={q(offer_id)} and os.scope_type='market' and not exists(select 1 from supply.offer_links l where l.offer_scope_id=os.id and l.link_type='details' and l.url={q(payload.get('product_url'))});"
        )
        lines.append(
            f"update ingest.source_observations set status='accepted' where source_id={q(source_ids[source_key])} and raw_record_id={q(raw_id)} and entity_type='offer';"
        )
        lines.append(
            f"insert into catalog.item_aliases(item_id,alias,normalized_alias,alias_type,provider_brand_id,confidence,status,source_note,approved_at) values ({q(mapping['catalog_item_id'])},{q(mapping['provider_alias'])},{q(normalize(str(mapping['provider_alias'])))},'provider_name',{q(brand_id)},1.0000,'approved',{q(mapping['reason'])},now()) on conflict (item_id,locale,provider_brand_id,normalized_alias) where provider_brand_id is not null and status <> 'rejected' do update set alias=excluded.alias,source_note=excluded.source_note,status='approved',approved_at=now();"
        )
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status,resolved_at) values ({q(normalization_id)},'crawler',{q(raw_id)},{q(brand_id)},{q(display_name)},{q(normalize(display_name))},{q(str((fixture if isinstance(fixture, dict) else {}).get('version') or 'generic-provider-mappings-puebla-v1'))},'resolved',now()) on conflict(id) do update set raw_record_id=excluded.raw_record_id,provider_brand_id=excluded.provider_brand_id,raw_text=excluded.raw_text,normalized_input=excluded.normalized_input,engine_version=excluded.engine_version,status='resolved',resolved_at=now();"
        )
        lines.append(
            f"insert into ingest.normalization_candidates(normalization_run_id,catalog_item_id,rank,score,method,explanation_data) values ({q(normalization_id)},{q(mapping['catalog_item_id'])},1,1.00000,{q(mapping['method'])},{q(json.dumps({'reason': mapping['reason'], 'source_key': source_key, 'external_record_id': external_id}, ensure_ascii=False, separators=(',', ':')))}::jsonb) on conflict (normalization_run_id,catalog_item_id) do update set score=excluded.score,method=excluded.method,explanation_data=excluded.explanation_data;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(id,normalization_run_id,selected_item_id,decision_type,reason) values ({q(stable_id('normalization-decision', normalization_id))},{q(normalization_id)},{q(mapping['catalog_item_id'])},'manual',{q(mapping['reason'])}) on conflict(id) do update set selected_item_id=excluded.selected_item_id,decision_type=excluded.decision_type,reason=excluded.reason,decided_at=now();"
        )
        emitted_items.add(str(mapping["catalog_item_id"]))
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
    parser.add_argument("--denue-fixture", type=Path, required=True)
    parser.add_argument("--artifact", action="append", type=_parse_artifact, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=400_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    fixture = _json(args.fixture)
    denue_fixture = _json(args.denue_fixture)
    artifacts = dict(args.artifact)
    sql = render(fixture, artifacts, denue_fixture)
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
