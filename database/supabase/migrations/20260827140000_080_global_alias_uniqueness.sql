-- Global aliases must not resolve to more than one canonical item.

begin;

create unique index if not exists catalog_item_aliases_global_term_uq
  on catalog.item_aliases(locale, normalized_alias)
  where provider_brand_id is null and status <> 'rejected';

commit;
