"""Run explicitly queued terminology reviews against the confirmed linked DB.

Research and clinical judgment happen before enqueueing. A queue entry pins the
review's bytes; directory discovery never makes a draft executable. The existing
renderer owns SQL guards, the bounded crawler scope and publication invariants.
Only --execute-reviewed allows a rollback preview followed by a guarded commit.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import time
from uuid import NAMESPACE_URL, UUID, uuid5

import httpx
from dotenv import dotenv_values

from publish_denue_bulk_linked import management_token
from render_ingest_artifact import q
from reviewed_alias_batch import expected_rows, render, reviewed_targets


ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / "collectors/artifacts/local-review-queue"
DATA = ROOT / "database/data"


class StopRequested(Exception):
    """A local stop marker prevents the next transaction from being submitted."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def wait_for_queue_update(path: Path, stamp: int, seconds: int) -> None:
    """Wake for a reviewed queue change or stop, retaining the normal scan limit."""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if (ARTIFACTS / "STOP").exists():
            raise StopRequested()
        if path.stat().st_mtime_ns != stamp:
            return
        time.sleep(min(1.0, max(0.0, deadline - time.monotonic())))


def save(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def inside(path: Path, parent: Path) -> Path:
    resolved = path.resolve()
    resolved.relative_to(parent.resolve())
    return resolved


@contextmanager
def process_lock():
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    with (ARTIFACTS / "worker.lock").open("a+b") as handle:
        handle.seek(0, 2)
        if handle.tell() == 0:
            handle.write(b"0")
            handle.flush()
        handle.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def query(client: httpx.Client, ref: str, sql: str) -> list[dict]:
    response = client.post(f"/v1/projects/{ref}/database/query", json={"query": sql})
    if response.status_code not in {200, 201}:
        # Upstream SQL errors may include private identifiers; never log bodies.
        raise RuntimeError(f"Management SQL HTTP {response.status_code}; inspect remote ledger before retry")
    rows = response.json()
    if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
        raise RuntimeError("Management SQL returned an invalid receipt")
    return rows


def read_ledger(client: httpx.Client, ref: str, sql: str) -> list[dict]:
    """Retry only the generated read-only ledger after a transport interruption."""
    for attempt in range(3):
        try:
            return query(client, ref, sql)
        except (httpx.RemoteProtocolError, httpx.ConnectError, httpx.ReadTimeout):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    raise RuntimeError('Ledger observation did not finish')


def load_queue(path: Path, ref: str) -> list[dict]:
    queue = json.loads(inside(ROOT / path, ROOT).read_text(encoding="utf-8"))
    if (queue.get("version") != 1 or queue.get("project_ref") != ref
            or queue.get("authorization") != "D-021/D-022"
            or not isinstance(queue.get("reviews"), list) or len(queue["reviews"]) > 200):
        raise ValueError("Queue version, destination or delegated authorization is invalid")
    reviews = []
    seen = set()
    for entry in queue["reviews"]:
        fixture = inside(ROOT / entry["fixture"], DATA)
        raw = fixture.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if not re.fullmatch(r"[a-f0-9]{64}", str(entry.get("sha256", ""))) or digest != entry["sha256"]:
            raise ValueError("Queued fixture changed; research must be reviewed before enqueueing again")
        review = json.loads(raw.decode("utf-8"))
        if (review.get("review_id") != entry.get("review_id") or review["review_id"] in seen
                or review.get("human_review") is not False
                or not str(review.get("reviewed_by", "")).startswith("Codex,")
                or "D-021" not in str(review.get("authorization", ""))
                or "D-022" not in str(review.get("authorization", ""))
                or any(not target.get("raw_guard") for alias in review.get("aliases", [])
                       for target in reviewed_targets(alias))):
            raise ValueError("Queued review attribution, scope or RAW guards are invalid")
        # Run the same complete fixture validation used by the SQL transport.
        sql = render(fixture=fixture)
        seen.add(review["review_id"])
        reviews.append({"review": review, "fixture": fixture, "sha256": digest, "preview_sql": sql})
    return reviews


def ledger(client: httpx.Client, ref: str, review: dict) -> str:
    review_id = q(review["review_id"])
    expected = []
    for alias in review["aliases"]:
        scoped = alias.get("alias_scope") == "provider"
        identity = review["review_id"] + ":" + alias["alias"]
        if scoped:
            identity += ":" + alias["provider_brand_id"]
        alias_id = str(uuid5(NAMESPACE_URL, identity))
        provider = q(alias["provider_brand_id"]) + "::uuid" if scoped else "null::uuid"
        expected.append("(" + ",".join([q(alias_id) + "::uuid", q(alias["item_id"]) + "::uuid",
                                       q(alias["alias"]), provider, q(alias["canonical_name"]),
                                       q(alias["evidence_url"]), q(alias["reason"])]) + ")")
    valid_concepts = "0"
    if review.get("new_concepts"):
        extra_system_case = " when 'saliva' then 'Saliva'" if any(
            concept["specimen_code"] == "saliva" for concept in review["new_concepts"]
        ) else ""
        if any(c["specimen_code"] == "nasal_mucus" for c in review["new_concepts"]):
            extra_system_case += " when 'nasal_mucus' then 'Nasal mucus'"
        concepts = ",".join("(" + ",".join([q(c["item_id"]) + "::uuid", q(c["component"]),
                                            q(c["specimen_code"]), q(c.get("time_aspect")),
                                            q(c["evidence_url"]), q(c["reason"])]) + ")"
                            for c in review["new_concepts"])
        valid_concepts = f"""(select count(*) from (values {concepts})
          e(id,component,specimen,time_aspect,url,reason)
          join health.lab_service_definitions d on d.service_id=e.id
          where d.component=e.component and d.time_aspect is not distinct from e.time_aspect
          and d.system is not distinct from case e.specimen
            when 'serum' then 'Serum' when 'plasma' then 'Plasma' when 'urine' then 'Urine' when 'stool' then 'Stool'{extra_system_case} end
          and ((e.specimen is null and not exists(select 1 from health.service_specimens ss
                 where ss.service_id=e.id))
            or exists(select 1 from health.service_specimens ss join health.specimen_types s
              on s.id=ss.specimen_type_id where ss.service_id=e.id and ss.is_primary and s.code=e.specimen))
          and exists(select 1 from audit.events ev where ev.entity_id=e.id
            and ev.action='catalog.concept_evidence_review' and ev.request_id={review_id}
            and ev.metadata->>'evidence_url'=e.url and ev.metadata->>'reason'=e.reason
            and (e.specimen is not null or (ev.metadata->>'identity_scope'='analyte_order'
              and nullif(ev.metadata->>'specimen_uncertainty','') is not null))))"""
    targets = []
    for alias in review["aliases"]:
        for target in reviewed_targets(alias):
            targets.append("(" + ",".join([q(alias["item_id"]) + "::uuid", q(alias["alias"]),
                q(target["provider_brand_id"]) + "::uuid",
                q(json.dumps(target.get("source_attributes", {}))) + "::jsonb"]) + ")")
    attribute_guard = ""
    if any(target.get("source_attributes") for alias in review["aliases"] for target in reviewed_targets(alias)):
        attribute_guard = "and nd.metadata->'reviewed_source_attributes'=t.source_attributes"
    sql = f"""with expected(id,item_id,alias,provider_id,name,url,reason) as (values {','.join(expected)})
select jsonb_build_object(
 'alias_audits',(select count(*) from audit.events where request_id={review_id}
   and action='catalog.alias_evidence_review'),
 'concept_audits',(select count(*) from audit.events where request_id={review_id}
   and action='catalog.concept_evidence_review'),
 'valid_concepts',{valid_concepts},
 'decisions',(select count(*) from ingest.normalization_decisions nd
   join ingest.normalization_runs nr on nr.id=nd.normalization_run_id
   join (values {','.join(targets)}) t(item_id,alias,provider_id,source_attributes)
    on t.alias=nr.normalized_input and t.provider_id=nr.provider_brand_id and t.item_id=nd.selected_item_id
   where nd.metadata->>'terminology_review_id'={review_id} and nr.status='resolved'
    and nr.input_type='crawler' {attribute_guard}),
 'valid_aliases',(select count(*) from expected e join catalog.item_aliases a on a.id=e.id
   join catalog.items i on i.id=a.item_id and i.status='active'
   join catalog.item_names n on n.item_id=i.id and n.is_primary
   where a.item_id=e.item_id and a.normalized_alias=e.alias and a.status='approved'
    and a.provider_brand_id is not distinct from e.provider_id and n.name=e.name
    and exists(select 1 from audit.events ev where ev.entity_id=a.id
      and ev.action='catalog.alias_evidence_review' and ev.request_id={review_id}
      and ev.metadata->>'evidence_url'=e.url and ev.metadata->>'reason'=e.reason))
) as ledger;
"""
    data = read_ledger(client, ref, sql)[0]["ledger"]
    counts = {"alias_audits": len(review["aliases"]), "concept_audits": len(review.get("new_concepts", [])),
              "valid_concepts": len(review.get("new_concepts", [])),
              "decisions": expected_rows(review), "valid_aliases": len(review["aliases"])}
    if data == counts:
        return "already_applied"
    if all(value == 0 for value in data.values()):
        return "not_applied"
    raise RuntimeError("Remote review ledger differs from the queued scope; batch stopped")


def execute(client: httpx.Client, ref: str, queued: dict) -> dict:
    review = queued["review"]
    local = ARTIFACTS / review["review_id"].replace(":", "-")
    local.mkdir(parents=True, exist_ok=True)
    authorizer = str(UUID(dotenv_values(ROOT / "apps/api/.dev.vars")["ADMIN_USER_IDS"].split(",")[0].strip()))
    expected = {"review_id": review["review_id"], "aliases": len(review["aliases"]),
                "new_concepts": len(review.get("new_concepts", [])),
                "resolved": expected_rows(review), "offers_created": 0}
    for apply, phase in [(False, "preview"), (True, "apply")]:
        if (ARTIFACTS / "STOP").exists():
            raise StopRequested()
        # Revalidate exact bytes immediately before either transaction.
        if hashlib.sha256(queued["fixture"].read_bytes()).hexdigest() != queued["sha256"]:
            raise RuntimeError("Queued fixture changed during execution")
        sql = queued["preview_sql"] if not apply else render(apply=True, fixture=queued["fixture"])
        (local / f"{phase}.sql").write_text(sql, encoding="utf-8")
        save(local / "state.json", {"review_id": review["review_id"], "sha256": queued["sha256"],
                                     "phase": phase + "_submitted", "updated_at": now()})
        # Keep the authorizing principal out of artifacts, stdout and logs.
        sql = sql.replace("begin;", "begin;\nset local pruevia.authorizing_admin=" + q(authorizer) + ";", 1)
        rows = query(client, ref, sql)
        save(local / f"{phase}.json", rows)
        if len(rows) != 1 or rows[0].get("receipt") != {**expected, "applied": apply}:
            raise RuntimeError("Unexpected transaction receipt; inspect remote ledger before retry")
        state = ledger(client, ref, review)
        if state != ("already_applied" if apply else "not_applied"):
            raise RuntimeError("Remote ledger does not confirm transaction outcome")
    save(local / "state.json", {**expected, "sha256": queued["sha256"], "phase": "applied_verified", "updated_at": now()})
    return {"review_id": review["review_id"], "status": "applied_verified", "resolved": expected["resolved"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--queue", type=Path, required=True)
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--execute-reviewed", action="store_true")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval-seconds", type=int, default=300)
    args = parser.parse_args()
    ref = (ROOT / "database/supabase/.temp/project-ref").read_text(encoding="utf-8").strip()
    if ref != args.project_ref or not re.fullmatch(r"[a-z]{20}", ref) or not 60 <= args.interval_seconds <= 3600:
        parser.error("Linked destination or interval is invalid")
    status = {"project_ref": ref, "pid": os.getpid(), "execution_enabled": args.execute_reviewed,
              "interval_seconds": args.interval_seconds, "status": "starting", "reviews": []}
    lock_acquired = False
    try:
        with process_lock(), httpx.Client(base_url="https://api.supabase.com",
                headers={"Authorization": "Bearer " + management_token()}, timeout=90) as client:
            lock_acquired = True
            while True:
                if (ARTIFACTS / "STOP").exists():
                    status.update(status="stopped", updated_at=now(), next_scan_at=None)
                    save(ARTIFACTS / "status.json", status)
                    print(json.dumps({"status": "stopped", "reason": "local_stop_marker"}), flush=True)
                    return 0
                results = []
                connection_wait = False
                queue_path = ROOT / args.queue
                queue_stamp = queue_path.stat().st_mtime_ns
                for queued in load_queue(args.queue, ref):
                    if (ARTIFACTS / "STOP").exists():
                        raise StopRequested()
                    review = queued["review"]
                    status.update(status="scanning", active_review=review["review_id"], updated_at=now(), next_scan_at=None)
                    save(ARTIFACTS / "status.json", status)
                    try:
                        state = ledger(client, ref, review)
                    except (httpx.RemoteProtocolError, httpx.ConnectError, httpx.ReadTimeout) as error:
                        if not args.watch:
                            raise
                        # This catch covers the read-only ledger only. A transport
                        # failure from execute() still stops for outcome inspection.
                        status.update(status="waiting_for_connection", error_type=type(error).__name__,
                                      last_rpc="read_only_ledger", updated_at=now(),
                                      next_scan_at=datetime.fromtimestamp(
                                          time.time() + args.interval_seconds, timezone.utc).isoformat())
                        save(ARTIFACTS / "status.json", status)
                        print(json.dumps({"status":"waiting_for_connection",
                                          "error_type":type(error).__name__,
                                          "transaction_submitted":False}), flush=True)
                        connection_wait = True
                        break
                    if state == "not_applied" and args.execute_reviewed:
                        results.append(execute(client, ref, queued))
                    else:
                        results.append({"review_id": review["review_id"], "status": state})
                if connection_wait:
                    time.sleep(args.interval_seconds)
                    continue
                status.pop("error_type", None)
                status.pop("last_rpc", None)
                next_scan = datetime.fromtimestamp(time.time() + args.interval_seconds, timezone.utc).isoformat() if args.watch else None
                status.update(status="watching" if args.watch else "completed", reviews=results,
                              active_review=None, updated_at=now(), next_scan_at=next_scan)
                save(ARTIFACTS / "status.json", status)
                print(json.dumps({"status": status["status"], "reviews": results, "next_scan_at": next_scan}), flush=True)
                if not args.watch:
                    return 0
                wait_for_queue_update(queue_path, queue_stamp, args.interval_seconds)
    except (KeyboardInterrupt, StopRequested):
        status.update(status="stopped", updated_at=now(), next_scan_at=None)
        if lock_acquired:
            save(ARTIFACTS / "status.json", status)
        print(json.dumps({"status": "stopped", "reason": "local_interrupt"}), flush=True)
        return 0
    except Exception as error:
        # Report the exception class only; upstream errors can embed secrets.
        status.update(status="stopped_error", error_type=type(error).__name__, updated_at=now(), next_scan_at=None)
        if lock_acquired:
            save(ARTIFACTS / "status.json", status)
        print(json.dumps({"status": "stopped_error", "error_type": type(error).__name__,
                          "reason": "Inspect pinned queue, local receipts and remote ledger before restarting"}), flush=True)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
