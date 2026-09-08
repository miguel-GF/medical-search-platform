-- Bound recursive redaction of untrusted provider evidence.
--
-- Raw provider payloads are capped by the ingest pipeline, but a compact JSON
-- document can still be deeply nested.  A privileged admin inspection must
-- fail closed instead of exhausting the PostgreSQL stack while redacting it.
begin;

create or replace function ingest.redact_sensitive_json_depth(
  p_value jsonb,
  p_depth integer default 0
)
returns jsonb
language plpgsql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
declare
  v_result jsonb;
  v_entry record;
  v_depth integer := greatest(coalesce(p_depth, 0), 0);
begin
  if p_value is null then
    return null;
  end if;

  -- Keep this below the database stack limit. The marker is itself safe to
  -- display and makes truncation visible to the reviewer.
  if v_depth >= 32 then
    return jsonb_build_object(
      '_redacted', 'payload nesting exceeds inspection limit'
    );
  end if;

  if jsonb_typeof(p_value) = 'object' then
    v_result := '{}'::jsonb;
    for v_entry in select key, value from jsonb_each(p_value)
    loop
      if lower(v_entry.key) ~ '(password|passphrase|secret|token|authorization|cookie|api[_-]?key|private[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret)' then
        v_result := v_result || jsonb_build_object(v_entry.key, '[REDACTED]');
      else
        v_result := v_result || jsonb_build_object(
          v_entry.key,
          ingest.redact_sensitive_json_depth(v_entry.value, v_depth + 1)
        );
      end if;
    end loop;
    return v_result;
  end if;

  if jsonb_typeof(p_value) = 'array' then
    select coalesce(
      jsonb_agg(
        ingest.redact_sensitive_json_depth(entry.value, v_depth + 1)
        order by entry.ordinality
      ),
      '[]'::jsonb
    )
      into v_result
    from jsonb_array_elements(p_value) with ordinality as entry(value, ordinality);
    return v_result;
  end if;

  return p_value;
end;
$$;

create or replace function ingest.redact_sensitive_json(p_value jsonb)
returns jsonb
language sql
stable
parallel safe
set search_path = pg_catalog, ingest
as $$
  select ingest.redact_sensitive_json_depth(p_value, 0);
$$;

-- Internal helper: callers use the one-argument wrapper. Close PostgreSQL's
-- implicit PUBLIC EXECUTE grant explicitly, including Data API roles.
revoke all on function ingest.redact_sensitive_json_depth(jsonb, integer) from public, anon, authenticated, service_role;
grant execute on function ingest.redact_sensitive_json_depth(jsonb, integer) to service_role;
revoke all on function ingest.redact_sensitive_json(jsonb) from public, anon, authenticated;
grant execute on function ingest.redact_sensitive_json(jsonb) to service_role;

commit;
