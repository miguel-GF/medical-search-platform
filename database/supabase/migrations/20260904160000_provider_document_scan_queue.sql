-- A bounded, service-only queue; no URL, secret, or job actor is client-selected.
begin;

create index identity_verification_documents_scan_queue_idx
on identity.verification_documents(created_at, id)
where status = 'pending' and scan_status in ('pending','error') and scan_attempts < 5;

drop function if exists public.api_server_record_provider_document_scan(uuid, text, text, integer, text);

create or replace function public.api_server_document_scan_queue(p_limit integer default 10)
returns table(document_id uuid, claim_id uuid, object_key text, submitted_sha256 text)
language plpgsql
volatile
security definer
set search_path = pg_catalog, identity
as $$
begin
  if p_limit is null or p_limit not between 1 and 25 then raise exception 'Scan batch limit must be between 1 and 25'; end if;
  return query
  -- Claim the rows before returning them. Without this lease, two scanner
  -- processes can download and inspect the same document concurrently, wasting
  -- resources and racing the bounded attempt counter. A crashed worker is
  -- eligible again after the 15-minute lease expires.
  with candidates as (
    select d.id
    from identity.verification_documents d
    join identity.provider_claims c on c.id = d.claim_id
    where d.status = 'pending' and d.scan_status in ('pending','error') and d.scan_attempts < 5
      and (d.scanned_at is null or d.scanned_at < now() - interval '15 minutes')
      and c.status in ('pending','under_review')
    order by d.created_at, d.id
    limit p_limit
    for update skip locked
  )
  update identity.verification_documents d
  set scan_status = 'error', scan_error_code = 'scan_in_progress',
      scan_attempts = scan_attempts + 1, scanned_at = now()
  from candidates
  where d.id = candidates.id
  returning d.id, d.claim_id, d.object_key, d.sha256::text;
end;
$$;
revoke all on function public.api_server_document_scan_queue(integer) from public, anon, authenticated, service_role;
grant execute on function public.api_server_document_scan_queue(integer) to service_role;

commit;
