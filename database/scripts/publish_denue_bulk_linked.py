"""Load licensed Puebla DENUE evidence into the confirmed linked project.

Reuses the existing artifact validator/SQL renderer and CLI credentials. Every
batch is transactional and replayable; a crawl remains partial until its raw
records and observations have been counted in the database. No provider, offer,
price or clinical equivalence is created by this transport.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from uuid import UUID

import httpx

try:
    from .publish_golden_catalog import chunk_transaction
    from .render_ingest_artifact import q, read_artifact, render, stable_id, validate
except ImportError:  # direct CLI entrypoint
    from publish_golden_catalog import chunk_transaction
    from render_ingest_artifact import q, read_artifact, render, stable_id, validate


DATABASE = Path(__file__).resolve().parents[1]
ARCHIVE_URL = "https://www.inegi.org.mx/contenidos/masiva/denue/denue_21_csv.zip"
LICENSE_URL = "https://www.inegi.org.mx/inegi/terminos.html"
SOURCE_KEY = "denue_puebla_bulk"


def management_token() -> str:
    token = os.getenv("SUPABASE_ACCESS_TOKEN")
    if token:
        return token
    if os.name != "nt":
        raise RuntimeError("Set SUPABASE_ACCESS_TOKEN privately or use the CLI transport")
    import ctypes
    from ctypes import wintypes

    class Credential(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD), ("Type", wintypes.DWORD), ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR), ("LastWritten", wintypes.FILETIME),
            ("Size", wintypes.DWORD), ("Blob", ctypes.POINTER(ctypes.c_byte)),
            ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p), ("TargetAlias", wintypes.LPWSTR), ("UserName", wintypes.LPWSTR),
        ]

    api = ctypes.WinDLL("advapi32", use_last_error=True)
    credential = ctypes.POINTER(Credential)()
    # Read only the credential already used by this owner's Supabase CLI.
    if not api.CredReadW("Supabase CLI:supabase", 1, 0, ctypes.byref(credential)):
        raise RuntimeError("Stored Supabase CLI credential is unavailable")
    try:
        token = ctypes.string_at(credential.contents.Blob, credential.contents.Size).decode("utf-8")
    finally:
        api.CredFree(credential)
    return token


def query(path: Path, *, client: httpx.Client | None = None, project_ref: str | None = None) -> list[dict]:
    if client is not None:
        response = client.post(f"/v1/projects/{project_ref}/database/query", json={"query": path.read_text(encoding="utf-8")})
        if response.status_code not in (200, 201):
            raise RuntimeError(f"Management query failed with HTTP {response.status_code}; batch receipt unconfirmed")
        result = response.json()
        if not isinstance(result, list) or not all(isinstance(row, dict) for row in result):
            raise RuntimeError("Management query did not return result rows")
        return result
    response = subprocess.run(
        [shutil.which("npx.cmd") or "npx.cmd", "--offline", "supabase@2.116.0",
         "db", "query", "--linked", "--file", str(path.resolve())],
        cwd=DATABASE, capture_output=True, text=True, encoding="utf-8", timeout=150,
    )
    try:
        result = json.loads(response.stdout)
    except (ValueError, TypeError) as error:
        raise RuntimeError("CLI did not return complete JSON; batch outcome must be checked before retry") from error
    if response.returncode or result.get("_tag") == "Error" or not isinstance(result.get("rows"), list):
        # SQL/file contents and upstream errors may contain private row data.
        raise RuntimeError("Linked query failed; receipt is not confirmed")
    return result["rows"]


def build_batches(artifact: Path, *, max_bytes: int = 420_000) -> tuple[list[str], dict]:
    manifest, raw, observations = read_artifact(artifact)
    validate(manifest, raw, observations)
    if (manifest.get("source_key") != SOURCE_KEY or manifest.get("source_type") != "government"
            or manifest.get("endpoint_url") != ARCHIVE_URL or manifest.get("endpoint_type") != "csv"):
        raise ValueError("Only the official Puebla DENUE bulk artifact is supported")
    run_id = str(UUID(str(manifest["run_id"])))
    hashes = set()
    ids = set()
    for record in raw:
        payload = record["payload"]
        provenance = payload.get("_source_archive", {})
        if (payload.get("cve_ent") != "21" or not payload.get("codigo_act", "").startswith(("621", "622"))
                or provenance.get("url") != ARCHIVE_URL or provenance.get("license_url") != LICENSE_URL
                or record.get("record_type") != "provider_location_discovered"
                or not re.fullmatch(r"[a-f0-9]{64}", str(provenance.get("sha256", "")))):
            raise ValueError("Unexpected geography/activity/provenance in DENUE artifact")
        if record["external_record_id"] in ids:
            raise ValueError("Duplicate DENUE identity in artifact")
        ids.add(record["external_record_id"])
        hashes.add(provenance.get("sha256"))
    if len(hashes) != 1 or not raw or len(raw) > 50_000:
        raise ValueError("DENUE artifact has inconsistent archive provenance or volume")
    if any(o.get("entity_type") != "provider_location" or o.get("entity_id") is not None
           or o.get("attribute_name") not in {"denue_id", "activity_code", "address", "name", "coordinates", "website_url"}
           for o in observations):
        raise ValueError("DENUE bulk transport supports only unlinked business identity observations")
    source_id = stable_id("ingest-source", SOURCE_KEY)
    lines = render(artifact).splitlines()
    # Approve this fixed government source from its reviewed license, rather
    # than accepting arbitrary source-policy claims from an artifact manifest.
    source_line = next(i for i, line in enumerate(lines) if line.startswith("insert into ingest.sources"))
    note = "Fuente: INEGI, DENUE; licencia verificada 2026-10-09: " + LICENSE_URL
    lines[source_line] = (
        "do $$ begin "
        f"if exists(select 1 from ingest.sources where id={q(source_id)} and usage_policy_status <> 'approved') "
        "then raise exception 'Persisted DENUE policy requires separate review'; end if; "
        f"insert into ingest.sources(id,name,source_type,trust_rank,usage_policy_status,status,notes) "
        f"values ({q(source_id)},'INEGI DENUE Puebla — descarga estatal','government',80,'approved','active',{q(note)}) "
        "on conflict(id) do nothing; end $$;"
    )
    for i, line in enumerate(lines):
        if line.startswith("insert into ingest.crawl_runs"):
            lines[i] = line.replace("'succeeded'", "'partial'")
        elif line.startswith("update ingest.crawl_runs set records_published="):
            lines[i] = (
                "do $$ begin "
                f"if (select count(*) from ingest.raw_records where crawl_run_id={q(run_id)}::uuid) <> {len(raw)} "
                f"or (select count(*) from ingest.source_observations so join ingest.raw_records rr on rr.id=so.raw_record_id "
                f"where rr.crawl_run_id={q(run_id)}::uuid and so.source_id={q(source_id)}::uuid "
                "and so.entity_type='provider_location' "
                "and so.attribute_name in ('denue_id','activity_code','address','name','coordinates','website_url')) "
                f"<> {len(observations)} "
                "then raise exception 'Incomplete DENUE load'; end if; "
                f"update ingest.crawl_runs set records_published={len(raw)},status='succeeded' where id={q(run_id)}::uuid; "
                "end $$;"
            )
            # Reviewed identity links can be added later against these RAW
            # records. They are derived evidence, not missing/extra capture
            # observations, and must not invalidate an otherwise complete replay.
    batches = chunk_transaction("\n".join(lines) + "\n", max_bytes=max_bytes)
    for i, batch in enumerate(batches):
        batches[i] = batch.replace(
            "begin;\n", "begin;\nset local lock_timeout='5s';\nset local statement_timeout='90s';\n", 1
        ).removesuffix("commit;\n") + f"select {i + 1} as confirmed_batch;\ncommit;\n"
    return batches, {"source_key": SOURCE_KEY, "run_id": run_id, "raw_records": len(raw),
                     "observations": len(observations), "archive_sha256": next(iter(hashes)), "batches": len(batches)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--expected-project-ref", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--management-api", action="store_true", help="Use the official Management API with this owner's CLI credential")
    args = parser.parse_args()
    linked = (DATABASE / "supabase/.temp/project-ref").read_text(encoding="utf-8").strip()
    if linked != args.expected_project_ref:
        parser.error("Linked project does not match the explicitly selected project")
    batches, receipt = build_batches(args.artifact)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for number, batch in enumerate(batches, 1):
        path = args.output_dir / f"part-{number:03d}.sql"
        path.write_text(batch, encoding="utf-8")
        paths.append(path)
    receipt.update({"project_ref": linked, "mode": "apply" if args.apply else "preview", "confirmed_batches": 0,
                    "sql_sha256": hashlib.sha256("".join(batches).encode("utf-8")).hexdigest()})
    receipt_path = args.output_dir / "load_receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt), flush=True)
    if not args.apply:
        return 0
    client = None
    if args.management_api:
        client = httpx.Client(base_url="https://api.supabase.com", headers={"Authorization": "Bearer " + management_token()},
                              timeout=120, follow_redirects=False)
        response = client.get(f"/v1/projects/{linked}")
        if response.status_code != 200 or response.json().get("status") != "ACTIVE_HEALTHY":
            client.close()
            raise RuntimeError("Selected project must be ACTIVE_HEALTHY before loading evidence")
    try:
        for number, path in enumerate(paths, 1):
            result = query(path, client=client, project_ref=linked)
            if result != [{"confirmed_batch": number}]:
                raise RuntimeError("Unexpected batch receipt; inspect the actual database before continuing")
            receipt["confirmed_batches"] = number
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            print(f"Confirmed batch {number}/{len(paths)}", flush=True)
    finally:
        if client is not None:
            client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
