-- The phrase "anticuerpos covid" also appears inside an explicit catalog
-- panel label.  Keep the broad query eligible for ambiguity handling rather
-- than hard-blocking the more specific panel.

begin;

update health.query_lexicon
set status = 'rejected',
    source_note = 'Superseded by v2 scope rule: explicit COVID antibody panels must remain eligible; broad query is tested as ambiguous.'
where locale = 'es-MX'
  and normalized_phrase = 'anticuerpos covid'
  and attribute_type = 'service_type'
  and attribute_value = '__blocked_broad_family__';

commit;
