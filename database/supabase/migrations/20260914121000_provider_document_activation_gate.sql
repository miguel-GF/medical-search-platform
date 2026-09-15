begin;
alter table identity.provider_intake_settings add column documents_enabled boolean not null default false,
  add column privacy_reviewed boolean not null default false,
  add column mail_processor text not null default '',
  add constraint provider_intake_legal_ready check(not enabled or (privacy_reviewed and length(mail_processor)>2));
create function public.provider_documents_open() returns boolean
language sql stable security definer set search_path=pg_catalog,identity as $$
 select coalesce((select enabled and documents_enabled from identity.provider_intake_settings where id),false);
$$;
revoke all on function public.provider_documents_open() from public,anon;
grant execute on function public.provider_documents_open() to authenticated,service_role;
-- Preserve every original scope, ownership, MFA and quota policy. Only the
-- independent internal freeze becomes an explicit, closed-by-default gate.
alter policy provider_documents_internal_freeze on storage.objects
 using (bucket_id<>'provider-claims' or public.provider_documents_open())
 with check (bucket_id<>'provider-claims' or public.provider_documents_open());
create or replace function core.reject_internal_document_write() returns trigger
language plpgsql security definer set search_path=pg_catalog,identity as $$
begin
 if not coalesce((select enabled and documents_enabled from identity.provider_intake_settings where id),false) then
   raise exception using errcode='42501',message='provider_documents_disabled';
 end if;
 return new;
end $$;
create or replace function public.api_provider_intake_info() returns jsonb
language sql stable security definer set search_path=pg_catalog,identity as $$
 select jsonb_build_object('enabled',enabled,'documents_enabled',enabled and documents_enabled,
 'controller_name',controller_name,'controller_address',controller_address,'privacy_email',privacy_email,
 'notice_version',notice_version,'mail_ready',(length(mail_processor)>2))
 from identity.provider_intake_settings where id;
$$;
create function public.api_server_provider_document_access(p_document_id uuid,p_actor_user_id uuid,p_actor_aal text,p_is_admin boolean)
returns jsonb language plpgsql security definer set search_path=pg_catalog,identity,audit as $$
declare d identity.verification_documents;
begin
 perform core.set_verified_provider_actor(p_actor_user_id,p_actor_aal);
 if not public.provider_documents_open() then return jsonb_build_object('error','provider_documents_disabled'); end if;
 select * into d from identity.verification_documents where id=p_document_id and content_verified and scan_status='clean';
 if not found or (not p_is_admin and d.submitted_by<>p_actor_user_id) then return jsonb_build_object('error','not_found'); end if;
 insert into audit.events(actor_user_id,actor_type,action,entity_schema,entity_table,entity_id)
 values(p_actor_user_id,case when p_is_admin then 'admin' else 'user' end,'provider.document_access','identity','verification_documents',d.id);
 return jsonb_build_object('object_key',d.object_key);
end $$;
revoke all on function public.api_server_provider_document_access(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.api_server_provider_document_access(uuid,uuid,text,boolean) to service_role;
commit;
