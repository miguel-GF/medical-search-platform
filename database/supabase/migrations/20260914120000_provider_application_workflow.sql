-- Additive intake. Activation is separate from installation; no real intake by default.
begin;
create table identity.provider_intake_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  controller_name text not null default '', controller_address text not null default '',
  privacy_email text not null default '', notice_version text not null default 'providers-2026-09-v1',
  check (not enabled or (length(controller_name)>2 and length(controller_address)>10
    and privacy_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'))
);
insert into identity.provider_intake_settings(id) values(true);

create table identity.provider_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  brand_id uuid not null references core.provider_brands(id),
  location_id uuid references core.provider_locations(id),
  scope text not null check(scope in ('brand','location')),
  name text not null check(length(name) between 2 and 160),
  position text not null check(length(position) between 2 and 160),
  organization_name text not null check(length(organization_name) between 2 and 240),
  work_email text not null check(length(work_email)<=254 and work_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  method text not null default 'email' check(method in ('email','documents')),
  status text not null default 'draft' check(status in ('draft','pending','under_review','needs_information','approved','rejected','cancelled','revoked')),
  notice_version text not null, consent_at timestamptz not null default now(),
  organization_id uuid references core.organizations(id),
  legacy_claim_id uuid unique references identity.provider_claims(id),
  contact_confirmed_at timestamptz, contact_reviewed_by uuid references auth.users(id),
  contact_source text, challenge_hash text, challenge_expires_at timestamptz,
  last_challenge_at timestamptz, challenge_count integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  revision integer not null default 0,
  check ((scope='brand' and location_id is null) or (scope='location' and location_id is not null))
);
create unique index provider_applications_open on identity.provider_applications(user_id,brand_id,coalesce(location_id,'00000000-0000-0000-0000-000000000000'::uuid))
where status not in ('cancelled','revoked');
create index provider_applications_queue on identity.provider_applications(status,created_at,id);

create table identity.provider_application_events (
  id uuid primary key default gen_random_uuid(), application_id uuid not null references identity.provider_applications(id),
  actor_id uuid not null references auth.users(id), action text not null,
  message text not null default '' check(length(message)<=2000),
  internal boolean not null default false, created_at timestamptz not null default now()
);
create table identity.provider_mail_outbox (
  id uuid primary key default gen_random_uuid(), application_id uuid not null references identity.provider_applications(id),
  recipient text not null, kind text not null check(kind in ('status','verification')),
  verification_code text, status text not null default 'pending' check(status in ('pending','sending','sent','failed','expired')),
  attempts integer not null default 0, available_at timestamptz not null default now(),
  lease_id uuid, lease_until timestamptz, expires_at timestamptz,
  created_at timestamptz not null default now(), sent_at timestamptz
);
create table identity.provider_privacy_requests (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
  kind text not null check(kind in ('access','rectification','cancellation','opposition','withdrawal')),
  message text not null check(length(message) between 1 and 2000),
  status text not null default 'received' check(status in ('received','under_review','answered')),
  response text, created_at timestamptz not null default now(), answered_at timestamptz
);
alter table identity.provider_intake_settings enable row level security;
alter table identity.provider_applications enable row level security;
alter table identity.provider_application_events enable row level security;
alter table identity.provider_mail_outbox enable row level security;
alter table identity.provider_privacy_requests enable row level security;
revoke all on identity.provider_intake_settings,identity.provider_applications,identity.provider_application_events,
identity.provider_mail_outbox,identity.provider_privacy_requests from public,anon,authenticated;

create function public.api_provider_intake_info() returns jsonb
language sql stable security definer set search_path=pg_catalog,identity as $$
 select jsonb_build_object('enabled',enabled,'controller_name',controller_name,'controller_address',controller_address,
 'privacy_email',privacy_email,'notice_version',notice_version) from identity.provider_intake_settings where id;
$$;

-- One service-only workflow boundary. The Worker supplies actor and is_admin after verification.
create function public.api_server_provider_application(
 p_actor_user_id uuid, p_actor_aal text, p_is_admin boolean,
 p_action text, p_id uuid default null, p_data jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,identity,core,public,extensions,audit as $$
declare
 a identity.provider_applications; settings identity.provider_intake_settings;
 v_id uuid; v_claim uuid; v_source text; v_token text; v_org uuid; v_result jsonb;
 v_message text:=coalesce(p_data->>'message',''); v_kind text; v_status text;
begin
 perform core.set_verified_provider_actor(p_actor_user_id,p_actor_aal);
 if p_is_admin is null or p_action is null or p_data is null or jsonb_typeof(p_data)<>'object' or pg_column_size(p_data)>16384
   or length(v_message)>2000 then return jsonb_build_object('error','invalid_request'); end if;
 select * into settings from identity.provider_intake_settings where id;
 if p_action='privacy_request' then
   -- Rights requests remain available even while new provider intake is closed.
   -- Closing registration is not a reason to close an existing data-rights channel.
   if (select count(*) from identity.provider_privacy_requests where user_id=p_actor_user_id and status<>'answered')>=5
     then return jsonb_build_object('error','request_limit'); end if;
   insert into identity.provider_privacy_requests(user_id,kind,message) values(p_actor_user_id,p_data->>'kind',v_message) returning id into v_id;
   return jsonb_build_object('id',v_id,'status','received');
 end if;
 if p_action='privacy_list' then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from
     (select * from identity.provider_privacy_requests where p_is_admin or user_id=p_actor_user_id order by created_at desc limit 100) r),'[]'::jsonb));
 end if;
 if p_action='privacy_answer' and p_is_admin then
   if length(trim(v_message))<5 then return jsonb_build_object('error','reason_required'); end if;
   update identity.provider_privacy_requests set status='answered',response=v_message,answered_at=now() where id=p_id and status<>'answered';
   if not found then return jsonb_build_object('error','not_found'); end if;
   insert into audit.events(actor_user_id,actor_type,action,entity_schema,entity_table,entity_id,after_data)
     values(p_actor_user_id,'admin','provider.privacy_request_answered','identity','provider_privacy_requests',p_id,jsonb_build_object('response_length',length(v_message)));
   return jsonb_build_object('status','answered');
 end if;
 if p_action='list' then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from (
     select x.id,x.scope,x.status,x.name,x.organization_name,x.created_at,x.updated_at,x.revision,b.name as provider_name,l.name as location_name
     from identity.provider_applications x join core.provider_brands b on b.id=x.brand_id left join core.provider_locations l on l.id=x.location_id
     where (p_is_admin or x.user_id=p_actor_user_id)
       and (coalesce(p_data->>'status','')='' or x.status=p_data->>'status')
       and (coalesce(p_data->>'q','')='' or concat_ws(' ',x.name,x.organization_name,b.name,l.name) ilike '%' || left(p_data->>'q',160) || '%')
       and (coalesce(p_data->>'days','')='' or x.created_at>=now()-make_interval(days=>least(365,greatest(1,(p_data->>'days')::integer))))
     order by x.created_at desc,x.id limit 50 offset least(10000,greatest(0,coalesce((p_data->>'offset')::integer,0)))
   ) r),'[]'::jsonb));
 end if;
 if p_action='targets' then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from (
     select b.id brand_id,b.name provider_name,l.id location_id,l.name location_name
     from core.provider_brands b left join core.provider_locations l on l.provider_brand_id=b.id and l.status<>'closed'
     where b.status<>'closed' and length(trim(coalesce(p_data->>'q','')))>=2
       and concat_ws(' ',b.name,l.name) ilike '%' || left(p_data->>'q',160) || '%'
     order by b.name,l.name limit 50) r),'[]'::jsonb));
 end if;
 if p_action='organizations' and p_is_admin then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from (
     select id,legal_name from core.organizations where status='active' and legal_name ilike '%'||left(coalesce(p_data->>'q',''),160)||'%' order by legal_name limit 50) r),'[]'::jsonb));
 end if;
 if p_action='profiles' and not p_is_admin then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from (
    select distinct a.legacy_claim_id as claim_id,l.id,l.name,l.phone,l.email,l.website_url
    from identity.provider_applications a join core.provider_locations l on l.provider_brand_id=a.brand_id
    join identity.provider_memberships m on m.user_id=p_actor_user_id and m.organization_id=a.organization_id and m.provider_brand_id=a.brand_id and m.status='active'
    where a.user_id=p_actor_user_id and a.status='approved' and (a.scope='brand' or a.location_id=l.id)
     and (m.scope_type='brand' or m.provider_location_id=l.id) order by l.name limit 100) r),'[]'::jsonb));
 end if;
 if p_action='changes' and not p_is_admin then
   return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)) from
     (select id,provider_location_id,changes,status,created_at,review_reason from identity.provider_change_requests where submitted_by=p_actor_user_id order by created_at desc limit 100) r),'[]'::jsonb));
 end if;
 if p_action='create' and not p_is_admin then
   if not settings.enabled then return jsonb_build_object('error','intake_disabled'); end if;
   if not exists(select 1 from auth.users where id=p_actor_user_id and email is not null and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
     then return jsonb_build_object('error','account_email_required'); end if;
   if p_data->>'notice_version' is distinct from settings.notice_version or p_data->>'authorized' is distinct from 'true'
     then return jsonb_build_object('error','consent_required'); end if;
   if (select count(*) from identity.provider_applications where user_id=p_actor_user_id and status not in ('revoked','cancelled','rejected'))>=10
     then return jsonb_build_object('error','request_limit'); end if;
   if p_data->>'scope'='location' and not exists(select 1 from core.provider_locations where id=(p_data->>'location_id')::uuid and provider_brand_id=(p_data->>'brand_id')::uuid and status<>'closed')
     then return jsonb_build_object('error','invalid_scope'); end if;
   if not exists(select 1 from core.provider_brands where id=(p_data->>'brand_id')::uuid and status<>'closed') then return jsonb_build_object('error','invalid_scope'); end if;
   insert into identity.provider_applications(user_id,brand_id,location_id,scope,name,position,organization_name,work_email,method,notice_version)
   values(p_actor_user_id,(p_data->>'brand_id')::uuid,(p_data->>'location_id')::uuid,p_data->>'scope',trim(p_data->>'name'),trim(p_data->>'position'),trim(p_data->>'organization_name'),lower(trim(p_data->>'work_email')),coalesce(p_data->>'method','email'),settings.notice_version)
   returning * into a;
 else
   select * into a from identity.provider_applications where id=p_id and (p_is_admin or user_id=p_actor_user_id) for update;
   if not found then return jsonb_build_object('error','not_found'); end if;
 end if;
 if p_action='detail' then
   v_result:=to_jsonb(a)-array['challenge_hash','challenge_expires_at','challenge_count','last_challenge_at'];
   if not p_is_admin then
     -- Reviewer identity and the canonical organization key are internal
     -- relationship data; the applicant only needs the public folio/status.
     v_result:=v_result-array['contact_reviewed_by','organization_id']
       || jsonb_build_object('contact_reviewed',a.contact_reviewed_by is not null);
   end if;
   return v_result || jsonb_build_object('events',coalesce((select jsonb_agg(to_jsonb(e)-'actor_id' order by e.created_at,e.id)
     from identity.provider_application_events e where application_id=a.id and (p_is_admin or not internal)),'[]'::jsonb),
     'documents',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'type',d.document_type,'status',d.status,'scan_status',d.scan_status,'reason',d.review_reason))
       from identity.verification_documents d where d.claim_id=a.legacy_claim_id),'[]'::jsonb),
     'mail',case when p_is_admin then coalesce((select jsonb_agg(jsonb_build_object('kind',m.kind,'status',m.status,'attempts',m.attempts,'created_at',m.created_at))
       from identity.provider_mail_outbox m where application_id=a.id),'[]'::jsonb) else '[]'::jsonb end);
 end if;
 if p_action<>'create' and p_action<>'verify' and coalesce((p_data->>'revision')::integer,-1)<>a.revision then return jsonb_build_object('error','stale_revision'); end if;
 if not settings.enabled and not p_is_admin and p_action not in ('cancel','verify') then return jsonb_build_object('error','intake_disabled'); end if;
 v_status:=a.status;
 if p_action='create' then null;
 elsif p_action='save' and not p_is_admin and a.status in ('draft','needs_information') then
   update identity.provider_applications set name=trim(p_data->>'name'),position=trim(p_data->>'position'),organization_name=trim(p_data->>'organization_name'),
   work_email=lower(trim(p_data->>'work_email')),
   contact_reviewed_by=case when lower(trim(p_data->>'work_email'))=work_email then contact_reviewed_by else null end,
   contact_confirmed_at=case when lower(trim(p_data->>'work_email'))=work_email then contact_confirmed_at else null end,
   challenge_hash=null,challenge_expires_at=null where id=a.id;
 elsif p_action='submit' and not p_is_admin and a.status in ('draft','needs_information','rejected') then
   v_status:='pending';
 elsif p_action='cancel' and not p_is_admin and a.status in ('draft','pending','needs_information','under_review') then
   v_status:='cancelled';
 elsif p_action='take' and p_is_admin and a.status='pending' then v_status:='under_review';
 elsif p_action='request_information' and p_is_admin and a.status in ('pending','under_review') and length(trim(v_message))>0 then v_status:='needs_information';
 elsif p_action='note' and p_is_admin and length(trim(v_message))>0 then null;
 elsif p_action='create_organization' and p_is_admin and a.organization_id is null and length(trim(v_message))>=10 and a.status in ('pending','under_review','needs_information') then
   if exists(select 1 from core.organizations where lower(legal_name)=lower(a.organization_name)) then return jsonb_build_object('error','scope_conflict'); end if;
   insert into core.organizations(legal_name,organization_type) values(a.organization_name,'company') returning id into v_org;
   insert into identity.provider_claims(claim_scope_type,provider_brand_id,provider_location_id,organization_id,claimant_user_id,requested_role,relationship_type)
     values(a.scope,a.brand_id,a.location_id,v_org,a.user_id,case when a.scope='brand' then 'brand_admin' else 'location_manager' end,'operator') returning id into v_claim;
   update identity.provider_applications set organization_id=v_org,legacy_claim_id=v_claim where id=a.id;
 elsif p_action='bind_organization' and p_is_admin and a.status in ('pending','under_review','needs_information') and a.legacy_claim_id is null then
   v_org:=(p_data->>'organization_id')::uuid;
   -- Existing canonical organization only. Missing legal identity stays in review.
   if not exists(select 1 from core.organizations where id=v_org and status='active') then return jsonb_build_object('error','organization_required'); end if;
   if exists(select 1 from identity.provider_claims where provider_brand_id=a.brand_id and provider_location_id is not distinct from a.location_id and organization_id=v_org and status in ('pending','under_review','approved'))
     then return jsonb_build_object('error','scope_conflict'); end if;
   insert into identity.provider_claims(claim_scope_type,provider_brand_id,provider_location_id,organization_id,claimant_user_id,requested_role,relationship_type)
     values(a.scope,a.brand_id,a.location_id,v_org,a.user_id,case when a.scope='brand' then 'brand_admin' else 'location_manager' end,'operator') returning id into v_claim;
   update identity.provider_applications set organization_id=v_org,legacy_claim_id=v_claim where id=a.id;
 elsif p_action='verify_contact' and p_is_admin and a.status in ('pending','under_review','needs_information') then
   v_source:=p_data->>'source_url';
   if v_source is null or v_source !~ '^https://[^/@[:space:]]+(/[^[:space:]]*)?$' or length(v_source)>1000 or length(trim(v_message))<10
     then return jsonb_build_object('error','contact_source_required'); end if;
   if split_part(a.work_email,'@',2) in ('gmail.com','hotmail.com','outlook.com','yahoo.com','icloud.com','live.com','proton.me','protonmail.com') then return jsonb_build_object('error','corporate_contact_required'); end if;
   update identity.provider_applications set contact_reviewed_by=p_actor_user_id,contact_source=v_source where id=a.id;
 elsif p_action='send_verification' and (p_is_admin or a.user_id=p_actor_user_id) and a.status in ('pending','under_review','needs_information') then
   if a.contact_reviewed_by is null then return jsonb_build_object('error','contact_review_required'); end if;
   if a.last_challenge_at>now()-interval '1 minute' or a.challenge_count>=10 then return jsonb_build_object('error','verification_limit'); end if;
   v_token:=encode(extensions.gen_random_bytes(32),'hex');
   update identity.provider_applications set challenge_hash=encode(extensions.digest(v_token,'sha256'),'hex'),challenge_expires_at=now()+interval '30 minutes',last_challenge_at=now(),challenge_count=challenge_count+1 where id=a.id;
   update identity.provider_mail_outbox set status='expired',verification_code=null where application_id=a.id and kind='verification' and status in ('pending','failed');
   insert into identity.provider_mail_outbox(application_id,recipient,kind,verification_code,expires_at) values(a.id,a.work_email,'verification',v_token,now()+interval '30 minutes');
 elsif p_action='verify' and not p_is_admin then
   if a.challenge_hash is null or a.challenge_expires_at<=now() or encode(extensions.digest(coalesce(p_data->>'code',''),'sha256'),'hex')<>a.challenge_hash
     then return jsonb_build_object('error','verification_expired'); end if;
   update identity.provider_applications set contact_confirmed_at=now(),challenge_hash=null,challenge_expires_at=null where id=a.id;
   update identity.provider_mail_outbox set status='expired',verification_code=null where application_id=a.id and kind='verification' and status in ('pending','sending','failed');
 elsif p_action='approve' and p_is_admin and a.status in ('pending','under_review') then
   if a.legacy_claim_id is null then return jsonb_build_object('error','organization_required'); end if;
   if not ((a.contact_reviewed_by is not null and a.contact_confirmed_at is not null) or exists(select 1 from identity.verification_documents where claim_id=a.legacy_claim_id and status='accepted' and content_verified and scan_status='clean'))
     then return jsonb_build_object('error','evidence_required'); end if;
   if p_data->>'scope_confirmed' is distinct from 'true' or length(trim(v_message))<10 then return jsonb_build_object('error','scope_confirmation_required'); end if;
   -- Serialize competing claims across organizations, including brand/location overlap.
   perform 1 from core.provider_brands where id=a.brand_id for update;
   if exists(select 1 from identity.provider_memberships where provider_brand_id=a.brand_id and status='active'
     and (a.scope='brand' or scope_type='brand' or provider_location_id=a.location_id)) then return jsonb_build_object('error','scope_conflict'); end if;
   perform set_config('pruevia.application_write',a.id::text,true);
   perform ingest.admin_review_provider_claim_core(a.legacy_claim_id,'approved',p_actor_user_id,v_message);
   v_status:='approved';
 elsif p_action='reject' and p_is_admin and a.status in ('pending','under_review','needs_information') and length(trim(v_message))>0 then
   v_status:='rejected';
 elsif p_action='revoke' and p_is_admin and a.status='approved' and length(trim(v_message))>0 then
   perform set_config('pruevia.application_write',a.id::text,true);
   perform ingest.admin_revoke_provider_claim_core(a.legacy_claim_id,p_actor_user_id,v_message);
   v_status:='revoked';
 else return jsonb_build_object('error','invalid_transition');
 end if;
 if a.legacy_claim_id is not null and p_action in ('submit','cancel','reject') then
   perform set_config('pruevia.application_write',a.id::text,true);
   update identity.provider_claims set status=case when p_action='submit' then 'pending' else 'rejected' end where id=a.legacy_claim_id;
 end if;
 if p_action in ('cancel','reject','revoke') then
   update identity.provider_applications set challenge_hash=null,challenge_expires_at=null where id=a.id;
 end if;
 update identity.provider_applications set status=v_status,revision=revision+1,updated_at=now() where id=a.id returning * into a;
 insert into identity.provider_application_events(application_id,actor_id,action,message,internal) values(a.id,p_actor_user_id,p_action,v_message,p_action in ('note','bind_organization','create_organization','verify_contact'));
 if p_action in ('submit','request_information','approve','reject','revoke') then
   insert into identity.provider_mail_outbox(application_id,recipient,kind)
     select a.id,email,'status' from auth.users where id=a.user_id;
 end if;
 return jsonb_build_object('id',a.id,'status',a.status,'revision',a.revision);
exception
 when unique_violation then return jsonb_build_object('error','scope_conflict');
 when check_violation or not_null_violation or invalid_text_representation or foreign_key_violation then return jsonb_build_object('error','invalid_request');
end; $$;

create function core.guard_application_claim_status() returns trigger language plpgsql security definer
set search_path=pg_catalog,identity as $$ declare application_id uuid; begin
 select id into application_id from identity.provider_applications where legacy_claim_id=new.id;
 if application_id is not null and new.status is distinct from old.status
   and current_setting('pruevia.application_write',true) is distinct from application_id::text then
   raise exception using errcode='42501',message='use_application_workflow';
 end if;
 return new;
end $$;
revoke all on function core.guard_application_claim_status() from public,anon,authenticated,service_role;
create trigger provider_application_claim_status before update of status on identity.provider_claims
for each row execute function core.guard_application_claim_status();

-- Contact evidence is accepted only for an intake record whose official contact
-- was independently reviewed and challenged. Legacy claims retain their document rule.
-- Keep this override static and auditable: using pg_get_functiondef/replace here
-- would make a future migration depend on incidental formatting of another one.
create or replace function ingest.admin_review_provider_claim_core(
  p_claim_id uuid,
  p_decision text,
  p_reviewer_user_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, identity, core, audit
as $$
declare
  v_claim identity.provider_claims;
  v_updated integer;
begin
  if p_reviewer_user_id is null then raise exception 'Reviewer is required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is not null and length(p_reason) > 2000 then raise exception 'Review reason is too long'; end if;
  if p_decision = 'rejected' and nullif(trim(p_reason), '') is null then raise exception 'Rejection reason is required'; end if;
  select * into v_claim from identity.provider_claims where id = p_claim_id for update;
  if not found then raise exception 'Provider claim does not exist'; end if;
  if v_claim.status not in ('pending','under_review') then raise exception 'Claim is not awaiting review'; end if;

  if p_decision = 'approved'
    and not exists (
      select 1 from identity.provider_applications a
      where a.legacy_claim_id = v_claim.id
        and a.status in ('pending','under_review')
        and a.contact_reviewed_by is not null
        and a.contact_confirmed_at is not null
    )
    and not exists (
      select 1 from identity.verification_documents
      where claim_id = v_claim.id and status in ('pending','accepted')
    ) then
    raise exception 'Claim requires at least one verification document or confirmed official contact';
  end if;

  update identity.provider_claims
  set status = p_decision, reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = nullif(trim(p_reason), '')
  where id = p_claim_id
  returning * into v_claim;

  if p_decision = 'approved' then
    if v_claim.claim_scope_type = 'brand' then
      insert into core.provider_brand_organizations(provider_brand_id, organization_id, relationship_type, claim_id)
      values (v_claim.provider_brand_id, v_claim.organization_id, v_claim.relationship_type, v_claim.id)
      on conflict (provider_brand_id, organization_id, relationship_type, valid_from)
      do update set claim_id = coalesce(core.provider_brand_organizations.claim_id, excluded.claim_id);
      insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, role, status, activated_at)
      values (v_claim.claimant_user_id, v_claim.organization_id, 'brand', v_claim.provider_brand_id, v_claim.requested_role, 'active', now())
      on conflict do nothing;
    else
      insert into core.provider_location_organizations(provider_location_id, organization_id, relationship_type, claim_id)
      values (v_claim.provider_location_id, v_claim.organization_id, v_claim.relationship_type, v_claim.id)
      on conflict (provider_location_id, organization_id, relationship_type, valid_from)
      do update set claim_id = coalesce(core.provider_location_organizations.claim_id, excluded.claim_id);
      insert into identity.provider_memberships(user_id, organization_id, scope_type, provider_brand_id, provider_location_id, role, status, activated_at)
      values (v_claim.claimant_user_id, v_claim.organization_id, 'location', v_claim.provider_brand_id, v_claim.provider_location_id, v_claim.requested_role, 'active', now())
      on conflict do nothing;
    end if;

    update identity.provider_verifications
    set status = 'passed', completed_at = now(), reviewer_user_id = p_reviewer_user_id, notes = 'Claim approved'
    where claim_id = v_claim.id and status = 'pending';
    get diagnostics v_updated = row_count;
    if v_updated = 0 then
      insert into identity.provider_verifications(claim_id, method, status, completed_at, reviewer_user_id, notes)
      values (v_claim.id, 'manual', 'passed', now(), p_reviewer_user_id, 'Claim approved');
    end if;
    update identity.verification_documents
    set status = 'accepted', reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = 'Claim approved'
    where claim_id = v_claim.id and status = 'pending';
  else
    update identity.verification_documents
    set status = 'rejected', reviewer_user_id = p_reviewer_user_id, reviewed_at = now(), review_reason = p_reason
    where claim_id = v_claim.id and status = 'pending';
  end if;

  insert into audit.events(actor_user_id, actor_type, action, entity_schema, entity_table, entity_id, after_data)
  values (p_reviewer_user_id, 'admin', 'provider.claim_reviewed', 'identity', 'provider_claims', v_claim.id,
    jsonb_build_object('decision', p_decision, 'reason', p_reason, 'scope_type', v_claim.claim_scope_type,
      'provider_brand_id', v_claim.provider_brand_id, 'provider_location_id', v_claim.provider_location_id,
      'organization_id', v_claim.organization_id));
  return jsonb_build_object('claim_id', v_claim.id, 'status', v_claim.status, 'reviewed_at', v_claim.reviewed_at);
end;
$$;

create function public.api_server_provider_mail(p_action text,p_id uuid default null,p_lease uuid default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog,identity as $$
declare m identity.provider_mail_outbox;
begin
 if p_action='lease' then
   update identity.provider_mail_outbox set status='expired',verification_code=null where expires_at<=now() and status<>'sent';
   select * into m from identity.provider_mail_outbox where (status='pending' or status='sending' and lease_until<now()) and available_at<=now() and attempts<5 order by created_at limit 1 for update skip locked;
   if not found then return null; end if;
   update identity.provider_mail_outbox set status='sending',lease_id=extensions.gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1 where id=m.id returning * into m;
   return to_jsonb(m);
 elsif p_action in ('sent','retry') then
   update identity.provider_mail_outbox set status=case when p_action='sent' then 'sent' when attempts>=5 then 'failed' else 'pending' end,
   verification_code=case when p_action='sent' or attempts>=5 then null else verification_code end,
   sent_at=case when p_action='sent' then now() else sent_at end, available_at=now()+interval '5 minutes',lease_until=null
   where id=p_id and lease_id=p_lease and status='sending';
   return jsonb_build_object('updated',found);
 end if;
 raise exception 'Invalid mail action';
end $$;
revoke all on function public.api_provider_intake_info() from public,anon,authenticated;
revoke all on function public.api_server_provider_application(uuid,text,boolean,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.api_server_provider_mail(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.api_provider_intake_info(),public.api_server_provider_application(uuid,text,boolean,text,uuid,jsonb),public.api_server_provider_mail(text,uuid,uuid) to service_role;
commit;
