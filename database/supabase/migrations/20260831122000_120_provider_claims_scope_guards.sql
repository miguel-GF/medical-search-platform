-- Enforce scope/role invariants even when writes originate from privileged
-- jobs rather than the provider RPCs.

begin;

alter table identity.provider_claims
  add constraint identity_provider_claims_brand_relationship_check
  check (claim_scope_type <> 'brand' or relationship_type <> 'tenant');

alter table identity.verification_documents
  add constraint identity_verification_documents_key_prefix_check
  check (object_key ~ '^provider-claims/[0-9a-fA-F-]+/.+');

create or replace function core.validate_provider_claim_scope()
returns trigger
language plpgsql
as $$
declare
  v_location_brand uuid;
begin
  if new.claim_scope_type = 'location' then
    if new.requested_role not in ('location_manager','editor','read_only') then
      raise exception 'Invalid role for location claim';
    end if;
    select provider_brand_id into v_location_brand
    from core.provider_locations
    where id = new.provider_location_id;
    if v_location_brand is null or v_location_brand is distinct from new.provider_brand_id then
      raise exception 'Location does not belong to provider brand';
    end if;
  elsif new.requested_role not in ('brand_admin','editor','read_only') then
    raise exception 'Invalid role for brand claim';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_identity_provider_claims_validate_scope on identity.provider_claims;
create trigger trg_identity_provider_claims_validate_scope
before insert or update on identity.provider_claims
for each row execute function core.validate_provider_claim_scope();

create or replace function core.validate_provider_membership_scope()
returns trigger
language plpgsql
as $$
declare
  v_location_brand uuid;
begin
  if new.scope_type = 'organization' then
    if new.role not in ('organization_owner','organization_admin') then
      raise exception 'Invalid role for organization membership';
    end if;
  elsif new.scope_type = 'brand' then
    if new.role not in ('brand_admin','editor','read_only') then
      raise exception 'Invalid role for brand membership';
    end if;
  elsif new.scope_type = 'location' then
    if new.role not in ('location_manager','editor','read_only') then
      raise exception 'Invalid role for location membership';
    end if;
    select provider_brand_id into v_location_brand
    from core.provider_locations
    where id = new.provider_location_id;
    if v_location_brand is null or v_location_brand is distinct from new.provider_brand_id then
      raise exception 'Provider membership brand and location must match';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.api_provider_add_claim_document(
  p_claim_id uuid,
  p_document_type text,
  p_object_key text,
  p_sha256 text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, audit
as $$
declare
  v_user_id uuid := auth.uid();
  v_document identity.verification_documents;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_document_type not in ('rfc','acta_constitutiva','poder_representante','comprobante_domicilio','permiso_operacion','other') then raise exception 'Invalid document type'; end if;
  if p_object_key is null or length(p_object_key) not between 1 and 512 or position('..' in p_object_key) > 0 or p_object_key !~ '^provider-claims/[0-9a-fA-F-]+/.+' then raise exception 'Invalid document object key'; end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Invalid SHA-256'; end if;
  if jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' then raise exception 'Document metadata must be an object'; end if;
  if not exists (select 1 from identity.provider_claims where id = p_claim_id and claimant_user_id = v_user_id and status in ('pending','under_review')) then
    raise exception 'Claim is not available to this user';
  end if;
  insert into identity.verification_documents(claim_id, submitted_by, document_type, object_key, sha256, metadata)
  values (p_claim_id, v_user_id, p_document_type, p_object_key, lower(p_sha256), coalesce(p_metadata, '{}'::jsonb))
  returning * into v_document;
  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (v_user_id, 'user', 'provider.claim_document_added', 'identity', 'verification_documents', v_document.id,
    jsonb_build_object('claim_id', p_claim_id, 'document_type', p_document_type, 'sha256', lower(p_sha256)));
  return jsonb_build_object('document_id', v_document.id, 'claim_id', p_claim_id, 'status', v_document.status);
exception when unique_violation then
  raise exception 'This document has already been submitted for the claim';
end;
$$;

revoke all on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) from public;
grant execute on function public.api_provider_add_claim_document(uuid, text, text, text, jsonb) to authenticated, service_role;

commit;
