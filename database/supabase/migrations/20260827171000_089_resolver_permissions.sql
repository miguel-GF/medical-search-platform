-- Keep internal resolver functions out of the public Data API surface. Only
-- the reviewed public wrapper is callable by anon/authenticated clients.

begin;

revoke all on function catalog.resolve_items(text,text,uuid,integer) from public, anon, authenticated;
revoke all on function catalog.resolve_items_v2(text,text,uuid,integer) from public, anon, authenticated;
revoke all on function catalog.resolve_items_v3(text,text,uuid,integer) from public, anon, authenticated;
revoke all on function catalog.resolve_items_v4(text,text,uuid,integer) from public, anon, authenticated;
revoke all on function catalog.search_items(text,text,uuid,integer) from public, anon, authenticated;
revoke all on function public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer) from public, anon, authenticated;
grant execute on function public.api_resolve_search_v2(text,text,double precision,double precision,uuid,integer) to service_role;

commit;
