"""Render one evidence-reviewed alias batch with bounded exact reprocessing.

No model score approves an alias here: this dated fixture records the actual
terminology investigation. SQL aborts on changed targets, collisions, unrelated
eligible inputs, patient inputs, unexpected counts or source-policy changes.
The caller supplies the authorizing admin privately as a transaction setting;
the research audit identifies Codex, rather than claiming a human review.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import unicodedata
from uuid import UUID, uuid5, NAMESPACE_URL
from urllib.parse import urlparse

try:
    from .render_ingest_artifact import q
except ImportError:
    from render_ingest_artifact import q


FIXTURE = Path(__file__).resolve().parents[1] / "data/reviewed-aliases-20261009.json"


def reviewed_targets(row: dict) -> list[dict]:
    """One alias may have several independently reviewed crawler contexts."""
    extra = row.get("additional_targets", [])
    if not isinstance(extra, list) or (extra and row.get("alias_scope", "global") != "global"):
        raise ValueError("Additional targets require one global alias")
    targets = [{k: row[k] for k in ("provider_brand_id", "expected_rows", "raw_guard", "source_attributes")
                if k in row}]
    allowed = {"provider_brand_id", "expected_rows", "raw_guard", "source_attributes"}
    for target in extra:
        if not isinstance(target, dict) or set(target) - allowed:
            raise ValueError("Invalid additional target fields")
        targets.append(target)
    brands = set()
    for target in targets:
        brand = str(UUID(target["provider_brand_id"]))
        if brand in brands or type(target["expected_rows"]) is not int or target["expected_rows"] < 1:
            raise ValueError("Duplicate target brand or invalid row count")
        brands.add(brand)
        guard = target.get("raw_guard", {})
        if (guard and (not isinstance(guard.get("path"), list) or not guard["path"]
                       or any(not isinstance(p, str) or not p for p in guard["path"])
                       or not isinstance(guard.get("value"), str))) or (extra and not guard):
            raise ValueError("Each additional context requires an explicit RAW field guard")
        attributes = target.get("source_attributes", {})
        if not isinstance(attributes, dict) or set(attributes) - {"specimen_code", "specimen_family"}:
            raise ValueError("Unsupported reviewed source attributes")
        if attributes:
            if set(attributes) == {"specimen_code"}:
                specimen = attributes["specimen_code"]
                markers = {
                    "serum": ("suero", "serica", "serico"),
                    "plasma": ("plasma",),
                    "urine": ("orina", "urinaria", "urinario"),
                    "stool": ("heces", "fecal", "fecales"),
                    "saliva": ("saliva", "salival"),
                }.get(specimen)
                original = unicodedata.normalize("NFKD", guard.get("value", "").casefold())
                normalized = "".join(c for c in original if not unicodedata.combining(c))
                if (not markers or guard.get("path") not in
                        [["sample_type"], ["raw_study", "Descripcion"], ["raw_study", "Preparacion"]]
                        or not any(re.search(r"\b" + marker + r"\b", normalized) for marker in markers)):
                    raise ValueError("Source specimen requires an explicit reviewed RAW specimen marker")
            elif set(attributes) == {"specimen_family"} and attributes["specimen_family"] == "blood":
                if (guard.get("path") not in [["raw_study", "Preparacion"], ["raw_study", "Descripcion"], ["sample_type"]]
                        or not re.search(r"\bsangre\b", guard.get("value", ""), re.IGNORECASE)):
                    raise ValueError("Source blood family requires an explicit reviewed RAW blood marker")
            else:
                raise ValueError("Declare one reviewed specimen or the explicit blood family")
    return targets


def expected_rows(review: dict) -> int:
    return sum(target["expected_rows"] for row in review["aliases"] for target in reviewed_targets(row))


def render_new_concepts(review: dict, aliases: list[dict]) -> str:
    """Add researched orders without inferring analytical methods or LOINC mappings."""
    concepts = review.get("new_concepts", [])
    if not isinstance(concepts, list) or len(concepts) > 10:
        raise ValueError("At most ten researched concepts may be added per batch")
    if not concepts:
        return ""
    seen = set()
    values = []
    for concept in concepts:
        item_id = str(UUID(concept["item_id"]))
        if item_id in seen:
            raise ValueError("Duplicate researched concept")
        seen.add(item_id)
        targets = [row for row in aliases if row["item_id"] == item_id]
        if not targets or any(row["canonical_name"] != concept["canonical_name"]
                              or row["service_type"] != "lab_test" for row in targets):
            raise ValueError("Each new concept must have a matching reviewed lab alias")
        specimen = concept["specimen_code"]
        identity_scope = concept.get("identity_scope", "specimen_order")
        uncertainty = concept.get("specimen_uncertainty")
        if specimen is None:
            if (identity_scope != "analyte_order" or not isinstance(uncertainty, str)
                    or not uncertainty.strip() or concept.get("time_aspect") is not None):
                raise ValueError("An analyte order without a specimen must record uncertainty and no duration")
        elif specimen not in {"serum", "plasma", "urine", "stool", "saliva"} or identity_scope != "specimen_order" or uncertainty:
            raise ValueError("Explicit specimens require the specimen_order identity scope")
        if specimen == "saliva" and any(
            target.get("source_attributes") != {"specimen_code": "saliva"}
            for alias in targets for target in reviewed_targets(alias)
        ):
            raise ValueError("A saliva concept requires literal reviewed saliva on every source target")
        if concept.get("time_aspect") not in {None, "Pt", "24H"}:
            raise ValueError("Unsupported collection duration")
        if not concept.get("component") or not concept.get("reason"):
            raise ValueError("Concept component and research rationale are required")
        evidence = urlparse(concept["evidence_url"])
        if evidence.scheme != "https" or not evidence.hostname or evidence.username or evidence.password:
            raise ValueError("Concept evidence must be an HTTPS URL without credentials")
        values.append("(" + ",".join([
            q(item_id) + "::uuid", q(concept["canonical_name"]),
            q(concept["component"]), q(concept["specimen_code"]),
            q(concept.get("time_aspect")), q(concept["evidence_url"]), q(concept["reason"]),
            q(identity_scope), q(uncertainty)
        ]) + ")")
    extra_system_case = " when 'saliva' then 'Saliva'" if any(
        concept["specimen_code"] == "saliva" for concept in concepts
    ) else ""
    return f"""
create temporary table reviewed_new_concepts(
 item_id uuid, canonical_name text, component text, specimen_code text,
 time_aspect text, evidence_url text, reason text, identity_scope text, specimen_uncertainty text
) on commit drop;
insert into reviewed_new_concepts values {','.join(values)};
do $$ begin
 if (select count(*) from catalog.domains where code='health_diagnostics' and status='active')<>1
 then raise exception 'Diagnostic domain changed'; end if;
 if (select count(*) from catalog.categories c join catalog.domains d on d.id=c.domain_id
  where d.code='health_diagnostics' and c.code='laboratory')<>1
 then raise exception 'Laboratory category changed'; end if;
 if exists(select 1 from reviewed_new_concepts r where exists(
  select 1 from catalog.items i where i.id=r.item_id)
  or exists(select 1 from catalog.item_names n
   where n.normalized_name=core.normalized_text(r.canonical_name))
  or exists(select 1 from catalog.item_aliases a
   where a.normalized_alias=core.normalized_text(r.canonical_name) and a.status<>'rejected')
  or exists(select 1 from catalog.disambiguation_terms d
   where d.normalized_term=core.normalized_text(r.canonical_name) and d.status='approved'))
 then raise exception 'New concept already exists or collides; inspect catalogue'; end if;
 if exists(select 1 from reviewed_new_concepts r where r.specimen_code is not null and not exists(
  select 1 from health.specimen_types s where s.code=r.specimen_code and s.status='active'))
 then raise exception 'Explicit specimen unavailable'; end if;
end $$;
insert into catalog.items(id,domain_id,item_type,status)
select r.item_id,d.id,'service','active' from reviewed_new_concepts r
 cross join catalog.domains d where d.code='health_diagnostics';
insert into catalog.item_names(item_id,locale,name,normalized_name,name_type,is_primary)
select item_id,'es-MX',canonical_name,core.normalized_text(canonical_name),'canonical',true
from reviewed_new_concepts;
insert into health.services(catalog_item_id,service_type,clinical_equivalence_policy)
select item_id,'lab_test','strict' from reviewed_new_concepts;
insert into catalog.item_categories(item_id,category_id,is_primary)
select r.item_id,c.id,true from reviewed_new_concepts r cross join catalog.categories c
 join catalog.domains d on d.id=c.domain_id
 where d.code='health_diagnostics' and c.code='laboratory';
insert into health.service_specimens(service_id,specimen_type_id,is_primary,notes)
select r.item_id,s.id,true,r.reason from reviewed_new_concepts r
 join health.specimen_types s on s.code=r.specimen_code;
insert into health.lab_service_definitions(
 service_id,component,time_aspect,system,order_observation,verified,source_note)
select item_id,component,time_aspect,
 case specimen_code when 'serum' then 'Serum' when 'plasma' then 'Plasma' when 'urine' then 'Urine' when 'stool' then 'Stool'{extra_system_case} end,
 'order',false,{q(review['review_id'])} || '; ' || evidence_url || '; ' || reason ||
 '; Method/property/scale not inferred; no approved LOINC mapping' ||
 coalesce('; Specimen unspecified: ' || specimen_uncertainty,'')
from reviewed_new_concepts;
insert into audit.events(actor_type,action,entity_schema,entity_table,entity_id,request_id,metadata)
select 'system','catalog.concept_evidence_review','catalog','items',item_id,
 {q(review['review_id'])},jsonb_build_object('reviewed_by','Codex','human_review',false,
 'authorization','delegated_by_operator','canonical_name',canonical_name,'component',component,
 'specimen_code',specimen_code,'time_aspect',time_aspect,'evidence_url',evidence_url,
 'identity_scope',identity_scope,'specimen_uncertainty',specimen_uncertainty,
 'reason',reason,'loinc_mapping_approved',false,'offer_approved',false)
from reviewed_new_concepts;
"""


def render(*, apply: bool = False, fixture: Path = FIXTURE) -> str:
    review = json.loads(fixture.read_text(encoding="utf-8"))
    rows = review["aliases"]
    total = expected_rows(review)
    if not 1 <= len(rows) <= 40 or not 1 <= total <= 200:
        raise ValueError("Review must contain 1..40 aliases and 1..200 crawler rows")
    if not re.fullmatch(r"pruevia:evidence-review:[0-9]{8}:[0-9]{2}", review["review_id"]):
        raise ValueError("A dated research review ID is required")
    if not review.get("reviewed_by") or not review.get("authorization") or not review.get("scope"):
        raise ValueError("Review attribution, authorization and scope are required")
    seen = set()
    for row in rows:
        UUID(row["item_id"])
        targets = reviewed_targets(row)
        scope = row.get("alias_scope", "global")
        if scope not in {"global", "provider"} or row["expected_rows"] < 1:
            raise ValueError("Invalid alias scope or expected row count")
        key = (row["alias"], row["provider_brand_id"] if scope == "provider" else None)
        if key in seen:
            raise ValueError("Duplicate reviewed alias scope")
        seen.add(key)
        evidence = urlparse(row["evidence_url"])
        if evidence.scheme != "https" or not evidence.hostname or evidence.username or evidence.password:
            raise ValueError("Research evidence must be an HTTPS URL without credentials")
        reference_note = (review["review_id"] + "; Codex, investigación delegada; "
                          + row["evidence_url"]
                          + "; Motivo completo en audit.events: catalog.alias_evidence_review, este review_id y alias_id")
        if len(reference_note) > 1000:
            raise ValueError("Research reference exceeds the catalogue source note limit")
        guard = row.get("raw_guard", {})
        if (guard and (not isinstance(guard.get("path"), list) or not guard["path"]
                       or any(not isinstance(p, str) or not p for p in guard["path"])
                       or not isinstance(guard.get("value"), str))) or (scope == "provider" and not guard):
            raise ValueError("Contextual provider aliases require an explicit RAW field guard")
    # Every provider has its own observed attributes. An omitted additional
    # target attribute must not inherit the first provider's specimen claim.
    expanded = [{**row, **target, "source_attributes": target.get("source_attributes", {})}
                for row in rows for target in reviewed_targets(row)]
    values = ",\n".join(
        "(" + ",".join([q(row["alias"]), q(row["item_id"]) + "::uuid",
                        q(row["canonical_name"]), q(row["service_type"]),
                        q(row["provider_brand_id"]) + "::uuid", str(row["expected_rows"]),
                        q(row["evidence_url"]), q(row["reason"]),
                        q(str(uuid5(NAMESPACE_URL, review["review_id"] + ":" + row["alias"]
                          + (":" + row["provider_brand_id"] if row.get("alias_scope") == "provider" else "")))) + "::uuid",
                        q(row.get("alias_scope", "global")),
                        q(json.dumps(row.get("raw_guard", {}))) + "::jsonb",
                        q(json.dumps(row.get("source_attributes", {}))) + "::jsonb"]) + ")"
        for row in expanded
    )
    new_concepts_sql = render_new_concepts(review, rows)
    metadata = {k: v for k, v in review.items() if k not in {"aliases", "new_concepts"}}
    return f"""begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
select pg_advisory_xact_lock(hashtextextended('pruevia:admin:exact-reprocess',0));
create temporary table reviewed_aliases(
 alias text, item_id uuid, canonical_name text, service_type text,
 provider_brand_id uuid, expected_rows integer, evidence_url text, reason text, alias_id uuid,
 alias_scope text, raw_guard jsonb, source_attributes jsonb
) on commit drop;
insert into reviewed_aliases values {values};
create temporary table before_policies on commit drop as
 select id,usage_policy_status from ingest.sources;
create temporary table before_offers on commit drop as select count(*) as n from supply.offers;
{new_concepts_sql}
do $$ begin
 if exists(select 1 from reviewed_aliases r where core.normalized_text(r.alias) <> r.alias)
 then raise exception 'Fixture normalization changed'; end if;
 if exists(select 1 from reviewed_aliases r where not exists(
  select 1 from catalog.items i join catalog.domains d on d.id=i.domain_id
  join catalog.item_names n on n.item_id=i.id
  join health.services h on h.catalog_item_id=i.id
  where i.id=r.item_id and i.status='active' and d.code='health_diagnostics'
   and n.name=r.canonical_name and n.is_primary and h.service_type=r.service_type))
 then raise exception 'Canonical target changed'; end if;
 if exists(select 1 from reviewed_aliases r join catalog.item_names n
   on n.normalized_name=r.alias where n.item_id<>r.item_id)
 or exists(select 1 from reviewed_aliases r join catalog.item_aliases a
   on a.normalized_alias=r.alias where a.item_id<>r.item_id and a.status<>'rejected'
    and (r.alias_scope='global' or a.provider_brand_id is null or a.provider_brand_id=r.provider_brand_id))
 or exists(select 1 from reviewed_aliases r join catalog.disambiguation_terms d
   on d.normalized_term=r.alias where d.status='approved')
 then raise exception 'Alias collision or ambiguity'; end if;
 if exists(select 1 from reviewed_aliases r where (
  select count(*) from ingest.normalization_runs nr
  where nr.input_type='crawler' and nr.provider_brand_id=r.provider_brand_id
   and nr.normalized_input=r.alias and nr.status in ('pending','ambiguous','no_match')
   and not exists(select 1 from ingest.normalization_decisions nd
    where nd.normalization_run_id=nr.id and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match'))
 )<>r.expected_rows) then raise exception 'Reviewed crawler scope changed'; end if;
 if exists(select 1 from reviewed_aliases r join ingest.normalization_runs nr
  on nr.provider_brand_id=r.provider_brand_id and nr.normalized_input=r.alias
  left join ingest.raw_records rr on rr.id=nr.raw_record_id
  where nr.input_type='crawler' and nr.status in ('pending','ambiguous','no_match')
   and not exists(select 1 from ingest.normalization_decisions nd
    where nd.normalization_run_id=nr.id and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match'))
   and r.raw_guard<>'{{}}'::jsonb
   and (rr.payload #>> ARRAY(select jsonb_array_elements_text(r.raw_guard->'path')))
    is distinct from r.raw_guard->>'value')
 then raise exception 'Required RAW context changed or missing'; end if;
 if exists(select 1 from reviewed_aliases r join catalog.item_aliases a
  on a.normalized_alias=r.alias and a.item_id=r.item_id
  where a.status<>'rejected' and (a.provider_brand_id is null
   or (r.alias_scope='provider' and a.provider_brand_id=r.provider_brand_id)))
 then raise exception 'Alias already present; inspect receipt before replay'; end if;
end $$;
insert into catalog.item_aliases(id,item_id,alias,normalized_alias,alias_type,locale,
 provider_brand_id,confidence,status,source_note,approved_at)
select alias_id,item_id,alias,alias,'synonym','es-MX',
 case when alias_scope='provider' then provider_brand_id else null end,1,'approved',
 case when length({q(review['review_id'])} || '; Codex, investigación delegada; ' || evidence_url || '; ' || reason)<=1000
 then {q(review['review_id'])} || '; Codex, investigación delegada; ' || evidence_url || '; ' || reason
 else {q(review['review_id'])} || '; Codex, investigación delegada; ' || evidence_url ||
  '; Motivo completo en audit.events: catalog.alias_evidence_review, este review_id y alias_id'
 end,now()
from (select distinct on (alias_id) * from reviewed_aliases order by alias_id,provider_brand_id) r;
insert into audit.events(actor_type,action,entity_schema,entity_table,entity_id,request_id,metadata)
select 'system','catalog.alias_evidence_review','catalog','item_aliases',alias_id,
 {q(review['review_id'])}, {q(json.dumps(metadata, ensure_ascii=False))}::jsonb ||
 jsonb_build_object('evidence_url',evidence_url,'reason',reason,'alias',alias,'item_id',item_id,
 'alias_scope',alias_scope,'raw_guard',raw_guard,'approved_by_human',false,'offers_published',false,
 'reviewed_targets',(select jsonb_agg(jsonb_build_object('provider_brand_id',t.provider_brand_id,
  'expected_rows',t.expected_rows,'raw_guard',t.raw_guard,'source_attributes',t.source_attributes)
  order by t.provider_brand_id) from reviewed_aliases t where t.alias_id=r.alias_id))
from (select distinct on (alias_id) * from reviewed_aliases order by alias_id,provider_brand_id) r;
create temporary table reviewed_matches on commit drop as
 select m.* from ingest.admin_exact_normalization_matches() m;
do $$ declare result jsonb; begin
 if (select count(*) from reviewed_matches)<>{total} or exists(
  select 1 from reviewed_matches m join ingest.normalization_runs nr on nr.id=m.normalization_run_id
  where nr.input_type<>'crawler' or not exists(select 1 from reviewed_aliases r
   where r.alias=m.normalized_input and r.item_id=m.catalog_item_id and r.provider_brand_id=nr.provider_brand_id))
 then raise exception 'Exact reprocessing includes unexpected inputs; batch aborted'; end if;
 result := public.api_admin_reprocess_exact_normalizations(
  current_setting('pruevia.authorizing_admin')::uuid,{total},true,{q(review['review_id'])});
 if (result->>'processed')::int<>{total} or (result->>'skipped')::int<>0
  or (result->>'remaining_eligible')::int<>0
 then raise exception 'Incomplete exact reprocessing'; end if;
 if exists(select 1 from before_policies b join ingest.sources s on s.id=b.id
  where b.usage_policy_status<>s.usage_policy_status)
  or (select count(*) from supply.offers)<>(select n from before_offers)
 then raise exception 'Publication boundary changed'; end if;
end $$;
update ingest.normalization_decisions nd set metadata=nd.metadata ||
 jsonb_build_object('terminology_review_id',{q(review['review_id'])},'reviewed_by','Codex',
 'human_review',false,'authorization','delegated_by_operator','offer_approved',false,
 'reviewed_source_attributes',r.source_attributes,'reviewed_raw_guard',r.raw_guard)
from reviewed_matches m join ingest.normalization_runs nr on nr.id=m.normalization_run_id
 join reviewed_aliases r on r.alias=m.normalized_input and r.item_id=m.catalog_item_id
  and r.provider_brand_id=nr.provider_brand_id
where nd.normalization_run_id=m.normalization_run_id
 and nd.metadata->>'request_id'={q(review['review_id'])};
select jsonb_build_object('review_id',{q(review['review_id'])},'aliases',
 (select count(distinct alias_id) from reviewed_aliases),'new_concepts',{len(review.get('new_concepts', []))},'resolved',
 (select count(*) from reviewed_matches m join ingest.normalization_runs nr on nr.id=m.normalization_run_id
  where nr.status='resolved'),'applied',{'true' if apply else 'false'},'offers_created',0) as receipt;
{'commit' if apply else 'rollback'};
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, default=FIXTURE, help="Dated fixture with the actual research decisions")
    parser.add_argument("--apply", action="store_true", help="Render commit instead of rollback; does not execute SQL")
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(apply=args.apply, fixture=args.fixture), encoding="utf-8")
    print(f"Rendered evidence-reviewed aliases and bounded crawler decisions ({'commit' if args.apply else 'rollback'})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
