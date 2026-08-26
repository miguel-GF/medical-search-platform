"""Render an auditable golden-catalog publication transaction.

The script never guesses equivalence. Its input fixture contains the reviewed
mapping set; all other collected labels become explicit normalization runs.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path
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
    return f"gis.ST_SetSRID(gis.ST_MakePoint({coordinates['longitude']}, {coordinates['latitude']}), 4326)::gis.geography"


def read_artifact(path: Path) -> tuple[dict, list[dict], list[dict]]:
    manifest = json.loads((path / "run_manifest.json").read_text(encoding="utf-8"))
    raw = [json.loads(line) for line in (path / "raw_records.jsonl").read_text(encoding="utf-8").splitlines() if line]
    observations = [
        json.loads(line) for line in (path / "observations.jsonl").read_text(encoding="utf-8").splitlines() if line
    ]
    return manifest, raw, observations


def render(fixture: dict, ruiz_artifact: Path, chopo_artifact: Path) -> str:
    ruiz_manifest, ruiz_raw, ruiz_observations = read_artifact(ruiz_artifact)
    chopo_manifest, chopo_raw, chopo_observations = read_artifact(chopo_artifact)
    artifacts = {
        "ruiz_puebla": (ruiz_manifest, ruiz_raw, ruiz_observations),
        "chopo_puebla": (chopo_manifest, chopo_raw, chopo_observations),
    }
    brands = fixture["brands"]
    brand_ids = {key: stable_id("provider-brand", data["brand_key"]) for key, data in brands.items()}
    market_ids = {key: stable_id("provider-market", f"{data['brand_key']}:puebla") for key, data in brands.items()}
    source_ids = {key: stable_id("source", key) for key in brands}
    item_by_key = {item["catalog_key"]: item for item in fixture["items"]}
    lines = ["begin;", "-- Generated from catalog_golden_v1.json; no fuzzy mappings are created."]

    for source_key, data in brands.items():
        brand_id = brand_ids[source_key]
        market_id = market_ids[source_key]
        lines.append(
            f"insert into core.provider_brands(id,name,normalized_name,slug,website_url) values ({q(brand_id)},{q(data['brand_name'])},{q(normalize(data['brand_name']))},{q(data['slug'])},{q('https://www.chopo.com.mx' if data['brand_key']=='chopo' else 'https://laboratoriosruiz.com')}) on conflict(id) do update set name=excluded.name, normalized_name=excluded.normalized_name, website_url=excluded.website_url;"
        )
        lines.append(
            f"insert into core.provider_markets(id,provider_brand_id,name,normalized_name,slug,market_type) values ({q(market_id)},{q(brand_id)},{q('Puebla')},{q('puebla')},{q('puebla')},'city') on conflict(id) do update set name=excluded.name, normalized_name=excluded.normalized_name;"
        )

    # Ruiz locations are official API observations and are safe to publish as candidates.
    for row in ruiz_raw:
        if row.get("record_type") != "provider_location_discovered":
            continue
        payload = row["payload"]
        external_id = str(payload.get("provider_external_id") or row.get("external_record_id"))
        location_id = stable_id("provider-location", f"ruiz:{external_id}")
        lines.append(
            f"insert into core.provider_locations(id,provider_brand_id,name,normalized_name,location_code,address_line_1,address_line_2,locality_text,postal_code,coordinates,timezone,phone,website_url,status) values ({q(location_id)},{q(brand_ids['ruiz_puebla'])},{q(payload.get('provider_display_name'))},{q(normalize(str(payload.get('provider_display_name') or '')))},{q(external_id)},{q(payload.get('address_line_1'))},{q(payload.get('address_line_2'))},{q(payload.get('locality_text'))},{q(payload.get('postal_code'))},{sql_geography(payload.get('coordinates'))},{q('America/Mexico_City')},{q(payload.get('phone'))},{q(payload.get('location_url'))},'active') on conflict(id) do update set name=excluded.name,address_line_1=excluded.address_line_1,coordinates=excluded.coordinates,phone=excluded.phone,updated_at=now();"
        )
        lines.append(
            f"insert into core.location_external_ids(provider_location_id,source_system,external_id,external_url) values ({q(location_id)},{q('ruiz_puebla')},{q(external_id)},{q(payload.get('location_url'))}) on conflict(source_system,external_id) do nothing;"
        )
        lines.append(
            f"insert into core.provider_market_locations(provider_market_id,provider_location_id) values ({q(market_ids['ruiz_puebla'])},{q(location_id)}) on conflict do nothing;"
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
            continue
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
            if not isinstance(amount, (int, float)) or isinstance(amount, bool) or int(amount) <= 0:
                continue
            type_map = {"regular": ("regular", "default"), "online": ("online", "default"), "promotion": ("promo", "default"), "blue_card": ("member", "blue_card"), "gold_card": ("member", "gold_card"), "prepaid": ("other", "prepaid")}
            price_type, db_price_key = type_map.get(price_key, ("other", price_key))
            obs_lookup = f"(select so.id from ingest.source_observations so join ingest.raw_records rr on rr.id=so.raw_record_id where rr.crawl_run_id={q(artifacts[source_key][0]['run_id'])}::uuid and rr.record_hash={q(mapping['record_hash'])} and so.entity_type='price' and so.attribute_name='prices' limit 1)"
            lines.append(
                f"insert into supply.price_versions(offer_scope_id,price_type,channel,price_key,amount_minor,currency,source_observation_id,confidence) select os.id,{q(price_type)},'any',{q(db_price_key)},{int(amount)},'MXN',{obs_lookup},1.0 from supply.offer_scopes os where os.offer_id={q(offer_id)} and os.scope_type='market' on conflict (offer_scope_id,price_type,channel,price_key) where is_current do update set amount_minor=excluded.amount_minor,last_seen_at=now(),source_observation_id=excluded.source_observation_id,is_current=true;"
            )
        lines.append(
            f"insert into supply.offer_links(offer_scope_id,link_type,url,label,status) select os.id,'details',{q(payload.get('product_url'))},{q('Provider details')},'active' from supply.offer_scopes os where os.offer_id={q(offer_id)} and not exists(select 1 from supply.offer_links l where l.offer_scope_id=os.id and l.link_type='details' and l.url={q(payload.get('product_url'))});"
        )
        normalization_id = stable_id("normalization-run", f"{source_key}:{mapping['record_hash']}")
        method = "alias" if source_key == "chopo_puebla" else "exact"
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status,resolved_at) select {q(normalization_id)},'crawler',rr.id,{q(brand_id)},{q(display_name)},{q(normalize(display_name))},{q(fixture['version'])},'resolved',now() from ingest.raw_records rr where rr.crawl_run_id={q(artifacts[source_key][0]['run_id'])}::uuid and rr.record_hash={q(mapping['record_hash'])} on conflict(id) do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_candidates(normalization_run_id,catalog_item_id,rank,score,method,explanation_data) values ({q(normalization_id)},{q(item['item_id'])},1,1.0,{q(method)},{jb({'reason':'golden exact mapping','source_key':source_key})}) on conflict do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(normalization_run_id,selected_item_id,decision_type,reason) select {q(normalization_id)},{q(item['item_id'])},'automatic',{q('Exact normalized provider label approved in golden catalog V1')} where not exists(select 1 from ingest.normalization_decisions where normalization_run_id={q(normalization_id)} and decision_type='automatic');"
        )

    # Keep every unresolved Chopo label auditable in the normalization queue.
    queue_by_external = {str(row.get("external_record_id")): row for row in chopo_raw}
    for queue in fixture["normalization_queue"]:
        row = queue_by_external.get(str(queue["raw_record_id"]))
        if not row:
            continue
        run_id = stable_id("normalization-run", f"chopo_puebla:{row.get('record_hash')}")
        lines.append(
            f"insert into ingest.normalization_runs(id,input_type,raw_record_id,provider_brand_id,raw_text,normalized_input,engine_version,status) select {q(run_id)},'crawler',rr.id,{q(brand_ids['chopo_puebla'])},{q(queue['raw_text'])},{q(queue['normalized_input'])},{q(fixture['version'])},'no_match' from ingest.raw_records rr where rr.crawl_run_id={q(chopo_manifest['run_id'])}::uuid and rr.record_hash={q(row.get('record_hash'))} on conflict(id) do nothing;"
        )
        lines.append(
            f"insert into ingest.normalization_decisions(normalization_run_id,decision_type,reason) select {q(run_id)},'no_match',{q(queue['reason'])} where not exists(select 1 from ingest.normalization_decisions where normalization_run_id={q(run_id)} and decision_type='no_match');"
        )

    lines.append("commit;")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--ruiz-artifact", type=Path, required=True)
    parser.add_argument("--chopo-artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    sql = render(json.loads(args.fixture.read_text(encoding="utf-8")), args.ruiz_artifact, args.chopo_artifact)
    args.output.write_text(sql, encoding="utf-8")
    print(json.dumps({"statements": sql.count(";"), "bytes": len(sql.encode('utf-8'))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
