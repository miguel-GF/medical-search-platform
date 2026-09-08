-- Storage is a direct Supabase surface, so it must enforce the same current
-- MFA-factor condition as the Worker and provider RPC wrappers. A signed
-- aal2 JWT can remain valid briefly after a factor is removed; do not let that
-- stale session upload or read provider evidence.
begin;

create or replace function public.provider_can_access_claim_storage(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, identity, auth
as $$
declare
  v_claim_id uuid;
begin
  if p_name is null or p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png)$' then
    return false;
  end if;
  begin
    v_claim_id := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return auth.uid() is not null
    and auth.jwt()->>'aal' = 'aal2'
    and exists (
      select 1
      from auth.mfa_factors f
      where f.user_id = auth.uid() and f.status = 'verified'
    )
    and exists (
      select 1
      from identity.provider_claims c
      where c.id = v_claim_id and c.claimant_user_id = auth.uid()
        and c.status in ('pending','under_review')
    );
end;
$$;

revoke all on function public.provider_can_access_claim_storage(text)
  from public, anon, authenticated, service_role;
grant execute on function public.provider_can_access_claim_storage(text)
  to authenticated;

commit;
