-- Redaction of untrusted admin evidence must remove secrets and bound depth.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(3);

select extensions.is(
  ingest.redact_sensitive_json('{"password":"secret","nested":{"token":"value"}}'::jsonb),
  '{"password":"[REDACTED]","nested":{"token":"[REDACTED]"}}'::jsonb,
  'nested credential-shaped keys are redacted'
);

select extensions.ok(
  ingest.redact_sensitive_json(
    (repeat('{"nested":', 40) || 'null' || repeat('}', 40))::jsonb
  )::text like '%payload nesting exceeds inspection limit%',
  'deeply nested payloads are truncated at the inspection boundary'
);

select extensions.is(
  has_function_privilege('anon', 'ingest.redact_sensitive_json_depth(jsonb, integer)', 'execute'),
  false,
  'the depth helper is not callable by anonymous clients'
);

select * from extensions.finish();
rollback;
