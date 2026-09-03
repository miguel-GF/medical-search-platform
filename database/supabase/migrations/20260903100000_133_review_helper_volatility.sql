-- PostgreSQL classifies the JSON traversal expressions as STABLE. Keep the
-- function declaration honest so linting does not suggest an unsafe
-- immutability promise.

begin;

create or replace function ingest.redact_sensitive_json(p_value jsonb)
returns jsonb
language plpgsql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
declare
  v_result jsonb;
  v_entry record;
begin
  if p_value is null then
    return null;
  end if;

  if jsonb_typeof(p_value) = 'object' then
    v_result := '{}'::jsonb;
    for v_entry in select key, value from jsonb_each(p_value)
    loop
      if lower(v_entry.key) ~ '(password|passphrase|secret|token|authorization|cookie|api[_-]?key|private[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret)' then
        v_result := v_result || jsonb_build_object(v_entry.key, '[REDACTED]');
      else
        v_result := v_result || jsonb_build_object(v_entry.key, ingest.redact_sensitive_json(v_entry.value));
      end if;
    end loop;
    return v_result;
  end if;

  if jsonb_typeof(p_value) = 'array' then
    select coalesce(jsonb_agg(ingest.redact_sensitive_json(entry.value) order by entry.ordinality), '[]'::jsonb)
      into v_result
    from jsonb_array_elements(p_value) with ordinality as entry(value, ordinality);
    return v_result;
  end if;

  return p_value;
end;
$$;

create or replace function ingest.bound_admin_json(p_value jsonb, p_max_bytes integer default 65536)
returns jsonb
language plpgsql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
declare
  v_redacted jsonb;
  v_limit integer := greatest(256, least(coalesce(p_max_bytes, 65536), 65536));
begin
  if p_value is null then
    return null;
  end if;
  v_redacted := ingest.redact_sensitive_json(p_value);
  if octet_length(v_redacted::text) <= v_limit then
    return v_redacted;
  end if;
  return jsonb_build_object(
    '_redacted', true,
    'reason', 'payload exceeds the administrative inspection limit',
    'payload_bytes', octet_length(v_redacted::text),
    'limit_bytes', v_limit
  );
end;
$$;

revoke all on function ingest.redact_sensitive_json(jsonb) from public, anon, authenticated;
revoke all on function ingest.bound_admin_json(jsonb, integer) from public, anon, authenticated;
grant execute on function ingest.redact_sensitive_json(jsonb) to service_role;
grant execute on function ingest.bound_admin_json(jsonb, integer) to service_role;

commit;
