-- Curated OCR corrections are applied only by the image workflow.
--
-- The raw transcription is always preserved.  A rule changes the query sent
-- to the clinical resolver, but never chooses a panel when the resolver says
-- that the panel is ambiguous.

begin;

create table if not exists catalog.ocr_correction_rules (
  id uuid primary key default gen_random_uuid(),
  locale text not null default 'es-MX',
  normalized_input text not null,
  suggested_text text not null,
  normalized_suggestion text not null,
  correction_type text not null check (correction_type in (
    'character_confusion', 'spacing', 'lexical_review'
  )),
  confidence numeric(5,4) not null check (confidence >= 0 and confidence <= 1),
  status text not null default 'candidate' check (status in (
    'candidate', 'approved', 'rejected', 'deprecated'
  )),
  source_note text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (locale, normalized_input),
  check (char_length(normalized_input) between 1 and 200),
  check (char_length(suggested_text) between 1 and 200),
  check (char_length(normalized_suggestion) between 1 and 200)
);

create index if not exists catalog_ocr_correction_rules_lookup_idx
  on catalog.ocr_correction_rules(locale, normalized_input)
  where status = 'approved';

-- These are reviewed variants from the Puebla prescription acceptance image.
-- They are scoped to OCR; normal text search remains unchanged.
insert into catalog.ocr_correction_rules(
  locale, normalized_input, suggested_text, normalized_suggestion,
  correction_type, confidence, status, source_note, approved_at
)
values
  (
    'es-MX', 'obh', 'BH', 'bh', 'character_confusion', 0.9800, 'approved',
    'Observed OCR leading-O confusion for the reviewed BH abbreviation.', now()
  ),
  (
    'es-MX', 'oqs completa', 'Q S completa', 'q s completa', 'character_confusion', 0.9500, 'approved',
    'Observed OCR leading-O and abbreviation-spacing confusion; panel remains ambiguous.', now()
  ),
  (
    'es-MX', 'pertil firondle', 'Perfil tiroideo', 'perfil tiroideo', 'lexical_review', 0.8200, 'approved',
    'Reviewed OCR/handwriting variant from the acceptance image; profile composition remains ambiguous.', now()
  )
on conflict (locale, normalized_input) do update
set suggested_text = excluded.suggested_text,
    normalized_suggestion = excluded.normalized_suggestion,
    correction_type = excluded.correction_type,
    confidence = excluded.confidence,
    status = excluded.status,
    source_note = excluded.source_note,
    approved_at = excluded.approved_at;

create or replace function public.api_resolve_ocr_package(
  p_items jsonb,
  p_domain_code text default 'health_diagnostics',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_id uuid default null,
  p_limit integer default 10
)
returns jsonb
language sql
stable
parallel safe
security definer
set search_path = public, catalog, core, supply, geo, gis, extensions
as $$
with safe_items as materialized (
  select
    x.ordinality::integer as item_index,
    trim(x.value) as input,
    core.normalized_text(trim(x.value)) as normalized_input
  from jsonb_array_elements_text(
    case when jsonb_typeof(coalesce(p_items, '[]'::jsonb)) = 'array'
      then coalesce(p_items, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as x(value, ordinality)
  where x.ordinality <= 30
    and char_length(trim(x.value)) between 1 and 200
), mapped_items as materialized (
  select
    s.item_index,
    s.input,
    s.normalized_input,
    r.id as rule_id,
    r.suggested_text,
    r.correction_type,
    r.confidence as correction_confidence,
    r.source_note,
    coalesce(r.suggested_text, s.input) as resolver_input
  from safe_items s
  left join catalog.ocr_correction_rules r
    on r.locale = 'es-MX'
   and r.status = 'approved'
   and r.normalized_input = s.normalized_input
), resolver_payload as materialized (
  select public.api_resolve_package(
    coalesce((
      select jsonb_agg(to_jsonb(m.resolver_input) order by m.item_index)
      from mapped_items m
    ), '[]'::jsonb),
    p_domain_code,
    p_latitude,
    p_longitude,
    p_location_id,
    p_limit
  ) as payload
), rewritten_items as (
  select coalesce(jsonb_agg(
    case
      when m.rule_id is null then item.value
      else item.value || jsonb_build_object(
        'input', m.input,
        'normalized_query', m.normalized_input,
        'ocr_correction', jsonb_build_object(
          'suggested_text', m.suggested_text,
          'correction_type', m.correction_type,
          'confidence', m.correction_confidence,
          'source_note', m.source_note
        )
      )
    end
    order by m.item_index
  ), '[]'::jsonb) as items
  from mapped_items m
  join resolver_payload rp on true
  join jsonb_array_elements(coalesce(rp.payload->'items', '[]'::jsonb)) with ordinality as item(value, item_index)
    on item.item_index = m.item_index
), corrections as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'index', m.item_index,
    'input', m.input,
    'suggested_text', m.suggested_text,
    'correction_type', m.correction_type,
    'confidence', m.correction_confidence,
    'source_note', m.source_note
  ) order by m.item_index) filter (where m.rule_id is not null), '[]'::jsonb) as value
  from mapped_items m
)
select rp.payload
  || jsonb_build_object(
    'items', ri.items,
    'ocr_corrections', c.value,
    'ocr_correction_version', 'ocr-corrections-v1'
  )
from resolver_payload rp
cross join rewritten_items ri
cross join corrections c;
$$;

revoke all on table catalog.ocr_correction_rules from public, anon, authenticated;
revoke all on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) from public;
grant execute on function public.api_resolve_ocr_package(jsonb, text, double precision, double precision, uuid, integer) to anon, authenticated, service_role;

commit;
