-- Zero-valued provider prices are unavailable-price sentinels, not free services.
begin;

delete from supply.price_versions
where amount_minor <= 0;

alter table supply.price_versions
  add constraint price_versions_amount_positive check (amount_minor > 0);

commit;
