"""Fail-closed gate for deploying code coupled to the Supabase schema.

The command only reads metadata from the linked database. It must pass after a
staged migration and before publishing the Worker. No table data is returned.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


DATABASE = Path(__file__).resolve().parents[1]
SQL = r"""
select jsonb_build_object(
  'internal_document_storage_freeze', (select count(*)::integer from pg_policy
    where polrelid = 'storage.objects'::regclass and polname = 'provider_documents_internal_freeze'
      and not polpermissive and polcmd = '*'
      and polroles @> array['anon'::regrole::oid, 'authenticated'::regrole::oid]
      and pg_get_expr(polqual, polrelid) = '(bucket_id <> ''provider-claims''::text)'
      and pg_get_expr(polwithcheck, polrelid) = '(bucket_id <> ''provider-claims''::text)'),
  'internal_document_write_freeze', (select count(*)::integer from pg_trigger
    where tgrelid = 'identity.verification_documents'::regclass
      and tgname = 'internal_document_write_freeze' and tgenabled = 'O'
      and tgtype = 22 and not tgisinternal
      and tgfoid = to_regprocedure('core.reject_internal_document_write()')),
  'provider_wrappers', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'api_server_provider_%'),
  'provider_wrappers_service_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'api_server_provider_%' and has_function_privilege('service_role', p.oid, 'execute')),
  'provider_wrappers_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'api_server_provider_%' and has_function_privilege('anon', p.oid, 'execute')),
  'provider_wrappers_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'api_server_provider_%' and has_function_privilege('authenticated', p.oid, 'execute')),
  'provider_legacy_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_provider_create_claim','api_provider_my_claims','api_provider_add_claim_document',
      'api_provider_invite_member','api_provider_submit_location_change','api_provider_accept_membership','api_provider_my_memberships')
      and has_function_privilege('anon', p.oid, 'execute')),
  'provider_legacy_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_provider_create_claim','api_provider_my_claims','api_provider_add_claim_document',
      'api_provider_invite_member','api_provider_submit_location_change','api_provider_accept_membership','api_provider_my_memberships')
      and has_function_privilege('authenticated', p.oid, 'execute')),
  'provider_legacy_service_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_provider_create_claim','api_provider_my_claims','api_provider_add_claim_document',
      'api_provider_invite_member','api_provider_submit_location_change','api_provider_accept_membership','api_provider_my_memberships')
      and has_function_privilege('service_role', p.oid, 'execute')),
  'worker_rpc_service_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
      'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
      and has_function_privilege('service_role', p.oid, 'execute')),
  'worker_rpc_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
      'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
      and has_function_privilege('anon', p.oid, 'execute')),
  'worker_rpc_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('api_search','api_resolve_search','api_resolve_package','api_resolve_ocr_package',
      'api_segment_package_text','api_record_analytics_event','api_service_detail','api_provider_detail')
      and has_function_privilege('authenticated', p.oid, 'execute')),
  -- No public function should be callable by anon after the Worker trust
  -- boundary. The only authenticated exceptions are the two Storage
  -- ownership helpers, which Supabase Storage evaluates for claimant-owned
  -- objects (one for reads and one for bounded uploads).
  'public_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute')),
  'public_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('authenticated', p.oid, 'execute')),
  'public_authenticated_storage_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in ('provider_can_access_claim_storage', 'provider_can_upload_claim_storage')
      and pg_get_function_identity_arguments(p.oid) = 'text'
      and has_function_privilege('authenticated', p.oid, 'execute')),
  'unexpected_public_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('authenticated', p.oid, 'execute')
      and not (p.proname in ('provider_can_access_claim_storage', 'provider_can_upload_claim_storage')
        and pg_get_function_identity_arguments(p.oid) = 'text')),
  'scan_queue_service_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_document_scan_queue'
      and pg_get_function_identity_arguments(p.oid) = 'integer' and has_function_privilege('service_role', p.oid, 'execute')),
  'scan_queue_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_document_scan_queue'
      and pg_get_function_identity_arguments(p.oid) = 'integer' and has_function_privilege('anon', p.oid, 'execute')),
  'scan_queue_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_document_scan_queue'
      and pg_get_function_identity_arguments(p.oid) = 'integer' and has_function_privilege('authenticated', p.oid, 'execute')),
  'scan_attestation_service_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_record_provider_document_scan'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, integer, text, text, text'
      and has_function_privilege('service_role', p.oid, 'execute')),
  'scan_attestation_anon_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_record_provider_document_scan'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, integer, text, text, text'
      and has_function_privilege('anon', p.oid, 'execute')),
  'scan_attestation_authenticated_exec', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_record_provider_document_scan'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, integer, text, text, text'
      and has_function_privilege('authenticated', p.oid, 'execute')),
  'obsolete_scan_attestation', (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'api_server_record_provider_document_scan'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, text, text, integer, text')
) as security_schema;
"""
EXPECTED = {
    "internal_document_storage_freeze": 1,
    "internal_document_write_freeze": 1,
    "provider_wrappers": 7,
    "provider_wrappers_service_exec": 7,
    "provider_wrappers_anon_exec": 0,
    "provider_wrappers_authenticated_exec": 0,
    "provider_legacy_anon_exec": 0,
    "provider_legacy_authenticated_exec": 0,
    "provider_legacy_service_exec": 0,
    "worker_rpc_service_exec": 8,
  "worker_rpc_anon_exec": 0,
  "worker_rpc_authenticated_exec": 0,
  "public_anon_exec": 0,
  "public_authenticated_exec": 2,
  "public_authenticated_storage_exec": 2,
  "unexpected_public_authenticated_exec": 0,
    "scan_queue_service_exec": 1,
    "scan_queue_anon_exec": 0,
    "scan_queue_authenticated_exec": 0,
    "scan_attestation_service_exec": 1,
    "scan_attestation_anon_exec": 0,
    "scan_attestation_authenticated_exec": 0,
    "obsolete_scan_attestation": 0,
}


def _find_json(stdout: str) -> object:
    decoder = json.JSONDecoder()
    for match in re.finditer(r"\{", stdout):
        try:
            value, end = decoder.raw_decode(stdout[match.start():])
        except json.JSONDecodeError:
            continue
        if not stdout[match.start() + end:].strip():
            return value
    raise ValueError("Supabase did not return a complete JSON response")


def validate_payload(stdout: str, returncode: int) -> dict[str, int]:
    if returncode != 0:
        raise ValueError("Supabase schema query failed")
    payload = _find_json(stdout)
    if not isinstance(payload, dict) or payload.get("_tag") == "Error":
        raise ValueError("Supabase schema query returned an error")
    rows = payload.get("rows")
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        raise ValueError("Supabase schema query returned an unexpected shape")
    value = rows[0].get("security_schema")
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError as exc:
            raise ValueError("Schema metadata is not JSON") from exc
    if not isinstance(value, dict):
        raise ValueError("Runtime schema is not the tested, least-privilege shape")
    if value != EXPECTED:
        mismatches = {
            key: {"expected": expected, "actual": value.get(key)}
            for key, expected in EXPECTED.items()
            if value.get(key) != expected
        }
        raise ValueError(
            "Runtime schema is not the tested, least-privilege shape: "
            + json.dumps(mismatches, sort_keys=True)
        )
    return EXPECTED.copy()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", default="supabase")
    parser.add_argument(
        "--package",
        help="Optional package/version argument when invoking through npx (for example supabase@2.116.0)",
    )
    args = parser.parse_args()
    cli = shutil.which(args.cli)
    if not cli:
        parser.error("Supabase CLI executable is not installed")
    artifact: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".sql", prefix="pruevia-schema-", delete=False, encoding="utf-8") as handle:
            handle.write(SQL)
            artifact = Path(handle.name)
        response = subprocess.run([cli, *([args.package] if args.package else []), "db", "query", "--linked", "--file", str(artifact)],
                                  cwd=DATABASE, capture_output=True, text=True, encoding="utf-8",
                                  timeout=60, check=False)
        validate_payload(response.stdout, response.returncode)
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL runtime schema gate: {exc}")
        return 1
    finally:
        if artifact is not None:
            artifact.unlink(missing_ok=True)
    print("PASS runtime schema gate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
