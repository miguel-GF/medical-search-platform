-- Display stored business addresses for branches already present in public offers.
begin;
set local lock_timeout='250ms';
set local statement_timeout='10s';
create function public.api_public_location_addresses(p_location_ids uuid[])
returns table(id uuid,address text)
language plpgsql stable security definer set search_path=pg_catalog
as $$
begin
  if coalesce(cardinality(p_location_ids),0)>500 then raise exception 'Too many branches' using errcode='22023'; end if;
  return query select l.id,
    case when nullif(btrim(l.address_line_1),'') is null then null else
      concat_ws(', ',nullif(btrim(l.address_line_1),''),nullif(btrim(l.address_line_2),''),
        nullif(btrim(l.locality_text),''),case when nullif(btrim(l.postal_code),'') is not null then 'C.P. '||btrim(l.postal_code) end)
    end
  from core.provider_locations l
  where l.id=any(p_location_ids) and l.status='active'
    -- The caller supplies only IDs already returned by the normal public
    -- search. Brand/market scopes may expand to a concrete branch there;
    -- requiring a direct location scope here would suppress its address.
    and exists(select 1 from supply.offers o
      where o.status='active' and o.provider_brand_id=l.provider_brand_id);
end;
$$;
revoke all on function public.api_public_location_addresses(uuid[]) from public,anon,authenticated;
grant execute on function public.api_public_location_addresses(uuid[]) to service_role;
insert into audit.events(actor_type,action,entity_schema,entity_table,request_id,metadata)
values('system','ui.public_branch_address_enabled','core','provider_locations','branch-address-20261023',
 '{"scope":"Existing business addresses on existing active public offer branches","new_clinical_equivalences":0,"address_records_modified":0}'::jsonb);
commit;
