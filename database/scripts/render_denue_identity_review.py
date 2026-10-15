"""Render researched DENUE business links without asserting clinical coverage.

Uses the existing core model and stable identifiers. New locations remain
pending. Existing DENUE bindings or provider identities are never reassigned or
overwritten. The input review contains specific researched IDs, not fuzzy merges.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.parse import urlparse
from uuid import UUID

try:
    from .publish_golden_catalog import normalize, q, sql_geography, stable_id
    from .render_ingest_artifact import read_artifact, validate
except ImportError:
    from publish_golden_catalog import normalize, q, sql_geography, stable_id
    from render_ingest_artifact import read_artifact, validate


FIXTURE = Path(__file__).resolve().parents[1] / "data/provider-identity-review-20261009.json"
ARCHIVE_URL = "https://www.inegi.org.mx/contenidos/masiva/denue/denue_21_csv.zip"
DIAGNOSTIC_CODES = {"621511", "621512"}
GENERAL_HOSPITAL_CODES = {"622111", "622112"}
# Additional classes inspected in the official Puebla DENUE snapshot. Keep the
# source class: a business called "Sanatorio" can still be a medical office.
SPECIALIZED_PUBLIC_HOSPITAL_CODES = {"622312"}
PRIVATE_GENERAL_MEDICAL_OFFICE_CODES = {"621111"}
IDENTITY_LOCATION_TYPES = {
    **dict.fromkeys(DIAGNOSTIC_CODES, "branch"),
    **dict.fromkeys(GENERAL_HOSPITAL_CODES | SPECIALIZED_PUBLIC_HOSPITAL_CODES, "hospital"),
    **dict.fromkeys(PRIVATE_GENERAL_MEDICAL_OFFICE_CODES, "office"),
}


def render(artifact: Path, *, apply: bool = False, fixture: Path = FIXTURE) -> str:
    review = json.loads(fixture.read_text(encoding="utf-8"))
    manifest, records, observations = read_artifact(artifact)
    validate(manifest, records, observations)
    if (manifest["source_key"] != review["source_key"] or manifest["run_id"] != review["source_run_id"]
            or manifest["endpoint_url"] != ARCHIVE_URL or manifest["source_type"] != "government"):
        raise ValueError("Reviewed identity source does not match the licensed DENUE run")
    UUID(review["source_run_id"])
    raw = {row["external_record_id"]: row for row in records}
    reviewed_ids = [external_id for provider in review["providers"] for external_id in provider["denue_record_ids"]]
    if len(set(reviewed_ids)) != len(reviewed_ids) or not 1 <= len(reviewed_ids) <= 200:
        raise ValueError("Identity review must contain 1..200 distinct researched DENUE IDs")
    brand_values, location_values, observation_lines = [], [], []
    seen_brand_ids: set[str] = set()
    reused_brands = 0
    for provider in review["providers"]:
        activity_codes = provider.get("identity_activity_codes", sorted(DIAGNOSTIC_CODES))
        if (not isinstance(activity_codes, list) or not activity_codes
                or any(not isinstance(code, str) for code in activity_codes)
                or len(set(activity_codes)) != len(activity_codes)
                or not set(activity_codes) <= IDENTITY_LOCATION_TYPES.keys()):
            raise ValueError("Declare specific supported DENUE health identity classes")
        existing = provider.get("existing_brand")
        if existing is not None:
            required = {"id", "name", "normalized_name", "slug", "website_url", "status", "verification_status"}
            if (not isinstance(existing, dict) or set(existing) != required
                    or any(not isinstance(value, str) or not value for key, value in existing.items()
                           if key != "website_url")
                    or (existing["website_url"] is not None
                        and (not isinstance(existing["website_url"], str) or not existing["website_url"]))
                    or existing["name"] != provider["name"]
                    or existing["normalized_name"] != normalize(provider["name"])
                    or existing["slug"] != provider["slug"]
                    or existing["website_url"] != provider["website_url"]
                    or existing["status"] != "active"):
                raise ValueError("Existing brand requires its exact researched identity and active state")
            brand_id = str(UUID(existing["id"]))
            reused_brands += 1
        else:
            brand_id = stable_id("provider-brand", provider["provider_key"])
        if brand_id in seen_brand_ids:
            raise ValueError("Group locations under one explicit entry per reviewed brand")
        seen_brand_ids.add(brand_id)
        # Identity evidence and the institution's own website are separate facts.
        # An explicitly absent website must stay NULL, rather than using a
        # government directory as if it were the institution's own domain.
        website = provider["website_url"]
        if website is None and (not isinstance(provider.get("website_uncertainty"), str)
                                or not provider["website_uncertainty"].strip()):
            raise ValueError("An absent institutional website needs an explicit evidence limitation")
        urls = [provider["identity_evidence_url"]]
        if website is not None:
            urls.append(website)
        for url in urls:
            if not isinstance(url, str):
                raise ValueError("Provider research URLs must be strings")
            parsed = urlparse(url)
            if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
                raise ValueError("Provider research requires a safe HTTPS URL")
        brand_values.append("(" + ",".join([
            q(brand_id) + "::uuid", q(provider["name"]), q(normalize(provider["name"])),
            q(provider["slug"]), q(provider["website_url"]), q(provider["identity_note"]),
            q(provider["identity_evidence_url"]), "true" if existing is not None else "false",
            q(json.dumps(existing or {}, ensure_ascii=False)) + "::jsonb",
        ]) + ")")
        for external_id in provider["denue_record_ids"]:
            record = raw[external_id]
            payload = record["payload"]
            if (payload["cve_ent"] != "21" or payload["codigo_act"] not in activity_codes
                    or not payload["nom_estab"] or payload.get("_quality_flags")):
                raise ValueError("Reviewed provider identity has missing or unexpected source fields")
            location_type = IDENTITY_LOCATION_TYPES[payload["codigo_act"]]
            address_1 = " ".join(filter(None, [payload["tipo_vial"], payload["nom_vial"],
                                               payload["numero_ext"] + payload["letra_ext"]]))
            address_2 = " ".join(filter(None, [payload["numero_int"] + payload["letra_int"], payload["nomb_asent"]]))
            coordinates = {"latitude": float(payload["latitud"]), "longitude": float(payload["longitud"])}
            location_id = stable_id("provider-location", f"denue:{provider['provider_key']}:{external_id}")
            raw_id = stable_id("ingest-raw-record", review["source_run_id"] + ":" + record["record_hash"])
            values = [q(location_id) + "::uuid", q(brand_id) + "::uuid", q(external_id),
                      q(payload["nom_estab"]), q(normalize(payload["nom_estab"])), q(address_1), q(address_2),
                      q(payload["municipio"] + ", Puebla"), q(payload["cod_postal"]),
                      sql_geography(coordinates), q(raw_id) + "::uuid", q(record["record_hash"]),
                      q(payload["codigo_act"]), q(location_type)]
            location_values.append("(" + ",".join(values) + ")")
            metadata = json.dumps({"denue_id": external_id, "review_id": review["review_id"],
                                   "source_release": payload["_source_archive"]["release_date"],
                                   "identity_status": "verification_pending", "offer_status": "not_established",
                                   "activity_code": payload["codigo_act"], "location_type": location_type,
                                   "reviewed_by": review["reviewed_by"], "identity_evidence_url": provider["identity_evidence_url"],
                                   "website_url": provider["website_url"],
                                   "website_uncertainty": provider.get("website_uncertainty"),
                                   "provider_brand_id": brand_id, "existing_brand_reused": existing is not None,
                                   "identity_note": provider["identity_note"]},
                                  ensure_ascii=False)
            observation_id = stable_id("ingest-observation", review["review_id"] + ":" + external_id)
            observation_lines.append(
                "insert into ingest.source_observations(id,source_id,raw_record_id,entity_type,entity_id,"
                "attribute_name,observed_value,observed_at,confidence,status) "
                f"select {q(observation_id)}::uuid,rr.source_id,rr.id,'provider_location',{q(location_id)}::uuid,"
                f"'reviewed_identity_link',{q(metadata)}::jsonb,rr.observed_at,1,'accepted' "
                f"from ingest.raw_records rr where rr.id={q(raw_id)}::uuid on conflict(id) do nothing;"
            )
    request = q(review["review_id"])
    return f"""begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
select pg_advisory_xact_lock(hashtextextended('pruevia:denue:identity-review',0));
create temporary table reviewed_brands(id uuid,name text,normalized_name text,slug text,
 website_url text,description text,evidence_url text,reuse_existing boolean,expected_existing jsonb) on commit drop;
insert into reviewed_brands values {','.join(brand_values)};
create temporary table reviewed_locations(id uuid,brand_id uuid,denue_id text,name text,
 normalized_name text,address_1 text,address_2 text,locality text,postal_code text,
 coordinates gis.geography(Point,4326),raw_id uuid,record_hash text,
 activity_code text,location_type text) on commit drop;
insert into reviewed_locations values {','.join(location_values)};
create temporary table before_policies on commit drop as select id,usage_policy_status from ingest.sources;
create temporary table before_offers on commit drop as select count(*) as n from supply.offers;
select b.id from core.provider_brands b join reviewed_brands r on r.id=b.id
 where r.reuse_existing for share of b;
create temporary table before_reused_brands on commit drop as
 select b.id,to_jsonb(b) as row_snapshot from core.provider_brands b
 join reviewed_brands r on r.id=b.id and r.reuse_existing;
do $$ begin
 if exists(select 1 from reviewed_locations l where not exists(
  select 1 from ingest.raw_records rr join ingest.sources s on s.id=rr.source_id
  join ingest.crawl_runs cr on cr.id=rr.crawl_run_id
  where rr.id=l.raw_id and rr.crawl_run_id={q(review['source_run_id'])}::uuid
   and rr.record_hash=l.record_hash and rr.external_record_id=l.denue_id
   and rr.payload->>'nom_estab'=l.name and rr.payload->>'cve_ent'='21'
   and rr.payload->>'codigo_act'=l.activity_code
   and s.source_type='government' and s.usage_policy_status='approved' and cr.status='succeeded'))
 then raise exception 'Licensed DENUE identity provenance changed'; end if;
 if exists(select 1 from reviewed_brands r where r.reuse_existing and not exists(
  select 1 from core.provider_brands b where b.id=r.id and to_jsonb(b) @> r.expected_existing))
 then raise exception 'Researched existing brand identity or state changed'; end if;
 if exists(select 1 from reviewed_brands r join core.provider_brands b
  on (b.slug=r.slug or b.normalized_name=r.normalized_name or b.id=r.id)
  where not r.reuse_existing or b.id<>r.id)
 or exists(select 1 from reviewed_locations r join core.location_external_ids e
  on e.source_system='denue' and e.external_id=r.denue_id)
 or exists(select 1 from reviewed_locations r join core.provider_locations l on l.id=r.id)
 then raise exception 'Identity already bound; inspect receipt and existing identity before replay'; end if;
end $$;
insert into core.provider_brands(id,name,normalized_name,slug,description,website_url,status,verification_status)
select id,name,normalized_name,slug,description,website_url,'active','verification_pending'
 from reviewed_brands where not reuse_existing;
insert into core.provider_locations(id,provider_brand_id,name,normalized_name,location_code,location_type,
 address_line_1,address_line_2,locality_text,postal_code,coordinates,timezone,status)
select id,brand_id,name,normalized_name,'denue:'||denue_id,location_type,address_1,address_2,
 locality,postal_code,coordinates,'America/Mexico_City','pending' from reviewed_locations;
insert into core.location_external_ids(provider_location_id,source_system,external_id,external_url)
select id,'denue',denue_id,{q(ARCHIVE_URL)} from reviewed_locations;
{chr(10).join(observation_lines)}
insert into audit.events(actor_type,action,entity_schema,entity_table,entity_id,request_id,metadata)
select 'system','provider.identity_evidence_review','core','provider_locations',id,{request},
 jsonb_build_object('reviewed_by',{q(review['reviewed_by'])},'human_review',false,'denue_id',denue_id,
 'raw_record_id',raw_id,'activity_code',activity_code,'location_type',location_type,
 'status','pending','offer_approved',false,'provider_brand_id',brand_id,
 'existing_brand_reused',(select reuse_existing from reviewed_brands b where b.id=reviewed_locations.brand_id))
 from reviewed_locations;
do $$ begin
 if (select count(*) from core.provider_locations l join reviewed_locations r on r.id=l.id
  where l.status='pending' and l.location_type=r.location_type)<>{len(reviewed_ids)}
 or (select count(*) from before_reused_brands)<>{reused_brands}
 or exists(select 1 from before_reused_brands s left join core.provider_brands b on b.id=s.id
  where to_jsonb(b) is distinct from s.row_snapshot)
 or (select count(*) from supply.offers)<>(select n from before_offers)
 or exists(select 1 from before_policies b join ingest.sources s on s.id=b.id
  where b.usage_policy_status<>s.usage_policy_status)
 then raise exception 'Identity scope or publication boundary changed'; end if;
end $$;
select jsonb_build_object('review_id',{request},'brands',{len(review['providers']) - reused_brands},
 {"'brands_reused'," + str(reused_brands) + "," if reused_brands else ""}
 'pending_locations',{len(reviewed_ids)},'offers_created',0,'applied',{'true' if apply else 'false'}) as receipt;
{'commit' if apply else 'rollback'};
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--fixture", type=Path, default=FIXTURE, help="Dated review of specific researched identities")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", action="store_true", help="Render COMMIT; does not execute SQL")
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(args.artifact, apply=args.apply, fixture=args.fixture), encoding="utf-8")
    print("Rendered specific reviewed DENUE identities; locations remain pending")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
