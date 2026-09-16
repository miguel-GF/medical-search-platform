-- Salud Digna's catalog is observed per branch.  Any old brand/market scope
-- is unsafe because it can manufacture availability at every clinic.

begin;

update supply.offer_scopes os
set status = 'inactive'
from supply.offers o
join core.provider_brands b on b.id = o.provider_brand_id
where os.offer_id = o.id
  and b.slug = 'salud-digna'
  and os.scope_type in ('brand', 'market')
  and os.status = 'active';

commit;
