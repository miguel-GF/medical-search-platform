-- Keep exact active LOINC lookups indexed without making candidate/related
-- terminology rows eligible for the public resolver.

begin;

create index if not exists catalog_item_identifiers_loinc_exact_active_idx
  on catalog.item_identifiers (lower(trim(system)), lower(trim(code)))
  where lower(trim(system)) = 'http://loinc.org'
    and mapping_type = 'exact'
    and status = 'active';

commit;
