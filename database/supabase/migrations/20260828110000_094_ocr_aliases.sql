-- Add conservative OCR/handwriting variants observed in the Puebla recipe
-- acceptance cases.  BH is an exact abbreviation; QS remains ambiguous
-- because providers publish different panel compositions.

begin;

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status, source_note, approved_at
)
values (
  '00000000-0000-0000-0000-000000001103',
  'B H',
  'b h',
  'ocr_variant',
  1.0000,
  'approved',
  'Resolver Gate B OCR/handwritten spacing variant of BH',
  now()
)
on conflict do nothing;

insert into catalog.disambiguation_terms(term, normalized_term, source_note)
values (
  'Q S completa',
  'q s completa',
  'Resolver Gate B OCR/handwritten spacing variant; panel composition remains provider-specific.'
)
on conflict (locale, normalized_term) do update
set term = excluded.term, source_note = excluded.source_note;

insert into catalog.disambiguation_candidates(term_id, item_id, priority, reason)
select t.id, x.item_id, x.priority, x.reason
from catalog.disambiguation_terms t
join (values
  ('00000000-0000-0000-0000-000000001105'::uuid, 1, 'Panel básico; confirmar componentes.'),
  ('00000000-0000-0000-0000-000000001106'::uuid, 2, 'Panel ampliado; confirmar componentes.')
) x(item_id, priority, reason) on true
where t.normalized_term = 'q s completa'
on conflict (term_id, item_id) do update
set priority = excluded.priority, reason = excluded.reason;

commit;
