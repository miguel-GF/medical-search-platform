"""Prepare a corrected candidate locally; no HTTP or SQL execution."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ORIGINAL=ROOT/'docs/proposals/20261021-combined-clinical/combined-ROLLBACK-PROPOSED.sql'
ORIGINAL_SHA='2b0cb7cbdb72fb92f7f7388d69e96a7f0450db8ef6e76259a327cf3c50c15cad'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    out=args.output.resolve();out.relative_to(ROOT/'collectors/artifacts')
    raw=ORIGINAL.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=ORIGINAL_SHA:raise ValueError('Original candidate changed')
    original=raw.decode('utf-8')
    old='audit_event_id uuid not null references audit.events(id) on delete restrict'
    if original.count(old)!=2:raise ValueError('Unexpected audit FK scope')
    corrected=original.replace(old,'audit_event_id bigint not null references audit.events(id) on delete restrict')
    # Inner source sections must retain the limits stated for the evaluation.
    for old,new in [("set local lock_timeout='5s';","set local lock_timeout='250ms';"),("set local statement_timeout='30s';","set local statement_timeout='10s';")]:
        if corrected.count(old)!=4:raise ValueError('Unexpected timeout override scope')
        corrected=corrected.replace(old,new)
    if not corrected.endswith('rollback;\n'):raise ValueError('Rollback boundary changed')
    start=original.index('create table health.reviewed_panel_compositions (')
    end=original.index('alter table health.reviewed_panel_compositions enable row level security;',start)
    old_fragment=original[start:end]
    new_fragment=old_fragment.replace('audit_event_id uuid','audit_event_id bigint')
    out.mkdir(parents=True,exist_ok=False)
    contents={'corrected-combined-ROLLBACK-PROPOSED.sql':corrected,'panel-registry-original.sql':old_fragment,'panel-registry-corrected.sql':new_fragment,
        'correction.diff':''.join(difflib.unified_diff(original.splitlines(keepends=True),corrected.splitlines(keepends=True),fromfile='original',tofile='corrected'))}
    hashes={}
    for name,text in contents.items():
        data=text.encode('utf-8');(out/name).write_bytes(data);hashes[name]=hashlib.sha256(data).hexdigest()
    report={'original_sha256':ORIGINAL_SHA,'files':hashes,'audit_foreign_key_columns_corrected':2,'timeout_overrides_tightened':8,'clinical_function_bodies_changed':False,'remote_sql_submitted':False,'new_authorization_recorded':False}
    (out/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
