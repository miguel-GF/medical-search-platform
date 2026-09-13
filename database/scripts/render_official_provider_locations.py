"""Render first-party provider location evidence into canonical location rows."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any, Mapping

try:
    from .artifact_io import MAX_FIXTURE_BYTES, read_json_file
    from .publish_golden_catalog import chunk_transaction, normalize, q, sql_geography, stable_id
    from .render_ingest_artifact import read_artifact, validate
except ImportError:  # pragma: no cover
    from artifact_io import MAX_FIXTURE_BYTES, read_json_file
    from publish_golden_catalog import chunk_transaction, normalize, q, sql_geography, stable_id
    from render_ingest_artifact import read_artifact, validate


DEFAULT_SOURCE_KEY = "salud_digna_puebla"
DEFAULT_SOURCE_SYSTEM = "salud_digna_official"
MAX_LOCATIONS = 100
MAX_TEXT_CHARS = 4_000


def _json(path: Path) -> Mapping[str, Any]:
    value = read_json_file(path, max_bytes=MAX_FIXTURE_BYTES)
    if not isinstance(value, Mapping):
        raise ValueError(f"JSON must be an object: {path}")
    return value


def _text(value: object, field: str, *, required: bool = False) -> str:
    result = " ".join(str(value or "").split()).strip()
    if len(result) > MAX_TEXT_CHARS:
        raise ValueError(f"{field} exceeds the text limit")
    if required and not result:
        raise ValueError(f"{field} is required")
    return result


def _validate_fixture(fixture: Mapping[str, Any]) -> tuple[dict[str, str], list[dict[str, Any]], str, str]:
    if fixture.get("version") != "official-provider-locations-v1":
        raise ValueError("unsupported official location fixture version")
    source_key = _text(fixture.get("source_key") or DEFAULT_SOURCE_KEY, "source_key", required=True)
    source_system = _text(fixture.get("source_system") or DEFAULT_SOURCE_SYSTEM, "source_system", required=True)
    if not re.fullmatch(r"[a-z0-9_]+", source_key) or not re.fullmatch(r"[a-z0-9_]+", source_system):
        raise ValueError("source_key or source_system is invalid")
    provider = fixture.get("provider")
    if not isinstance(provider, Mapping):
        raise ValueError("fixture provider must be an object")
    provider_key = _text(provider.get("provider_key"), "provider.provider_key", required=True)
    provider_name = _text(provider.get("name"), "provider.name", required=True)
    provider_slug = _text(provider.get("slug"), "provider.slug", required=True)
    website_url = _text(provider.get("website_url"), "provider.website_url", required=True)
    if not re.fullmatch(r"[a-z0-9_]+", provider_key) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", provider_slug):
        raise ValueError("provider key or slug is invalid")
    if not re.fullmatch(r"https://[A-Za-z0-9.-]+(?:/[^\s]*)?", website_url):
        raise ValueError("provider.website_url must be an HTTPS URL")
    rows = fixture.get("locations")
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_LOCATIONS:
        raise ValueError("fixture locations must contain between 1 and 100 rows")
    locations: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, value in enumerate(rows):
        if not isinstance(value, Mapping):
            raise ValueError(f"location {index} must be an object")
        external_id = _text(value.get("external_id"), f"location {index}.external_id", required=True)
        if external_id in seen or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", external_id):
            raise ValueError(f"location {index} has a duplicate or invalid external_id")
        slug = _text(value.get("slug"), f"location {index}.slug", required=True)
        page_url = _text(value.get("url"), f"location {index}.url", required=True)
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) or not re.fullmatch(r"https://[A-Za-z0-9.-]+/[^\s]+", page_url):
            raise ValueError(f"location {index} has an invalid slug or URL")
        coords = value.get("coordinates")
        if not isinstance(coords, Mapping):
            raise ValueError(f"location {index}.coordinates is required")
        try:
            latitude, longitude = float(coords["latitude"]), float(coords["longitude"])
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError(f"location {index}.coordinates is invalid") from error
        if not all(math.isfinite(item) for item in (latitude, longitude)) or not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
            raise ValueError(f"location {index}.coordinates are outside bounds")
        locations.append({
            "external_id": external_id,
            "slug": slug,
            "name": _text(value.get("name"), f"location {index}.name", required=True),
            "address_line_1": _text(value.get("address_line_1"), f"location {index}.address_line_1", required=True),
            "postal_code": _text(value.get("postal_code"), f"location {index}.postal_code"),
            "phone": _text(value.get("phone"), f"location {index}.phone"),
            "url": page_url,
            "location_code": _text(value.get("location_code"), f"location {index}.location_code") or external_id,
            "coordinates": {"latitude": latitude, "longitude": longitude},
            "coordinate_source": _text(value.get("coordinate_source"), f"location {index}.coordinate_source"),
        })
        seen.add(external_id)
    return {"provider_key": provider_key, "name": provider_name, "slug": provider_slug, "website_url": website_url}, locations, source_key, source_system


def _artifact_locations(artifact: Path, expected_source_key: str) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    manifest, raw, observations = read_artifact(artifact)
    parsed = validate(manifest, raw, observations)
    if manifest.get("source_key") != expected_source_key:
        raise ValueError(f"artifact source_key must be {expected_source_key}")
    indexed: dict[str, dict[str, Any]] = {}
    for row in parsed:
        if row.get("record_type") != "provider_location_discovered":
            continue
        external_id = _text(row.get("external_record_id"), "artifact external_record_id", required=True)
        if external_id in indexed:
            raise ValueError(f"duplicate artifact location: {external_id}")
        indexed[external_id] = row
    return manifest, indexed


def render(fixture: Mapping[str, Any], artifact: Path) -> str:
    provider, locations, source_key, source_system = _validate_fixture(fixture)
    manifest, artifact_rows = _artifact_locations(artifact, source_key)
    for location in locations:
        row = artifact_rows.get(location["external_id"])
        if row is None:
            raise ValueError(f"fixture location is missing from artifact: {location['external_id']}")
        payload = row.get("payload")
        if not isinstance(payload, Mapping):
            raise ValueError(f"artifact payload is invalid: {location['external_id']}")
        if normalize(str(payload.get("provider_display_name") or "")) != normalize(location["name"]):
            raise ValueError(f"location name changed for {location['external_id']}")
        if str(payload.get("location_url") or "") != location["url"]:
            raise ValueError(f"location URL changed for {location['external_id']}")
        payload_coordinates = payload.get("coordinates")
        if isinstance(payload_coordinates, Mapping):
            try:
                if abs(float(payload_coordinates["latitude"]) - location["coordinates"]["latitude"]) > 0.01 or abs(float(payload_coordinates["longitude"]) - location["coordinates"]["longitude"]) > 0.01:
                    raise ValueError(f"location coordinates changed for {location['external_id']}")
            except (KeyError, TypeError, ValueError) as error:
                raise ValueError(f"artifact coordinates are invalid: {location['external_id']}") from error
        elif not location["coordinate_source"]:
            raise ValueError(f"location {location['external_id']} needs coordinate_source when artifact has no coordinates")
    brand_id = stable_id("provider-brand", provider["provider_key"])
    market_id = stable_id("provider-market", f"{provider['provider_key']}:puebla")
    source_id = stable_id("ingest-source", source_key)
    lines = [
        "begin;",
        "-- Official provider locations only; no offers, prices or clinical concepts are created.",
        f"insert into core.provider_brands(id,name,normalized_name,slug,website_url,status) values ({q(brand_id)},{q(provider['name'])},{q(normalize(provider['name']))},{q(provider['slug'])},{q(provider['website_url'])},'active') on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name,website_url=excluded.website_url,status='active';",
        f"insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug,market_type,status) values ({q(market_id)},{q(brand_id)},{q('Puebla')},{q('puebla')},{q('puebla')},'city','active') on conflict(provider_brand_id,slug) do update set name=excluded.name,normalized_name=excluded.normalized_name,status='active';",
        f"update ingest.sources set provider_brand_id={q(brand_id)},updated_at=now() where id={q(source_id)};",
    ]
    for location in locations:
        location_id = stable_id("provider-location", f"official:{provider['provider_key']}:{location['external_id']}")
        # A prior DENUE/clinical import may already own this provider/location
        # code (notably Municipio Libre). Update that row first, then insert a
        # new deterministic row only when the code is not present.
        lines.append(
            f"update core.provider_locations set name={q(location['name'])},normalized_name={q(normalize(location['name']))},address_line_1={q(location['address_line_1'])},postal_code={q(location['postal_code'] or None)},coordinates={sql_geography(location['coordinates'])},phone={q(location['phone'] or None)},website_url={q(location['url'])},status='active',updated_at=now() where provider_brand_id={q(brand_id)} and location_code={q(location['location_code'])};"
        )
        lines.append(
            f"insert into core.provider_locations(id,provider_brand_id,name,normalized_name,location_code,location_type,address_line_1,postal_code,coordinates,timezone,phone,website_url,status) select {q(location_id)},{q(brand_id)},{q(location['name'])},{q(normalize(location['name']))},{q(location['location_code'])},'lab',{q(location['address_line_1'])},{q(location['postal_code'] or None)},{sql_geography(location['coordinates'])},{q('America/Mexico_City')},{q(location['phone'] or None)},{q(location['url'])},'active' where not exists (select 1 from core.provider_locations where provider_brand_id={q(brand_id)} and location_code={q(location['location_code'])}) on conflict(id) do update set name=excluded.name,normalized_name=excluded.normalized_name,address_line_1=excluded.address_line_1,postal_code=excluded.postal_code,coordinates=excluded.coordinates,phone=excluded.phone,website_url=excluded.website_url,status='active',updated_at=now();"
        )
        lines.append(
            f"insert into core.location_external_ids(provider_location_id,source_system,external_id,external_url) select l.id,{q(source_system)},{q(location['external_id'])},{q(location['url'])} from core.provider_locations l where l.provider_brand_id={q(brand_id)} and l.location_code={q(location['location_code'])} on conflict(source_system,external_id) do update set provider_location_id=excluded.provider_location_id,external_url=excluded.external_url;"
        )
        lines.append(
            f"insert into core.provider_market_locations(provider_market_id,provider_location_id) select {q(market_id)},l.id from core.provider_locations l where l.provider_brand_id={q(brand_id)} and l.location_code={q(location['location_code'])} on conflict do nothing;"
        )
        raw_id = stable_id("ingest-raw-record", f"{manifest['run_id']}:{artifact_rows[location['external_id']]['record_hash']}")
        lines.append(
            f"update ingest.source_observations set entity_id=(select l.id from core.provider_locations l where l.provider_brand_id={q(brand_id)} and l.location_code={q(location['location_code'])}),status='accepted' where raw_record_id={q(raw_id)} and entity_type='provider_location';"
        )
    lines.append("commit;")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render official provider locations into canonical location tables")
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chunk-dir", type=Path)
    parser.add_argument("--max-bytes", type=int, default=400_000)
    args = parser.parse_args()
    if bool(args.output) == bool(args.chunk_dir):
        raise SystemExit("exactly one of --output or --chunk-dir is required")
    try:
        sql = render(_json(args.fixture), args.artifact)
        if args.chunk_dir:
            chunks = chunk_transaction(sql, args.max_bytes)
            args.chunk_dir.mkdir(parents=True, exist_ok=True)
            for index, chunk in enumerate(chunks, start=1):
                (args.chunk_dir / f"part-{index:03d}.sql").write_text(chunk, encoding="utf-8")
            result = {"chunks": len(chunks), "bytes": len(sql.encode("utf-8"))}
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(sql, encoding="utf-8")
            result = {"statements": sql.count(";"), "bytes": len(sql.encode("utf-8"))}
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    print(json.dumps({"status": "succeeded", **result}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
