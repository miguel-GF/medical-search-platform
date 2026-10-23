"""Bounded Android registration release authorized by the user on 2026-10-23.

One send per mutation; inspect independently after any uncertain response.
No clinical functions, grants on existing tables, or patient data are changed.
"""
import argparse, hashlib, json, sys
from datetime import datetime, timezone
from pathlib import Path
import httpx
from publish_denue_bulk_linked import management_token
from run_local_review_queue import query
from publish_golden_catalog import q

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'collectors/artifacts/android-intake-release-20261023'
REF='ymtcmfgwuzdqtsbuvzqf'
VERSION='20261023123000'
MIGRATION=ROOT/f'database/supabase/migrations/{VERSION}_android_tester_name_email.sql'

def save(name,value):
    with (OUT/name).open('x',encoding='utf-8') as f: json.dump(value,f,ensure_ascii=False,indent=2)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['inspect','preview','migrate','enable'])
    action=parser.parse_args().action
    assert (ROOT/'database/supabase/.temp/project-ref').read_text().strip()==REF
    OUT.mkdir(parents=True,exist_ok=True)
    with httpx.Client(base_url='https://api.supabase.com',headers={'Authorization':'Bearer '+management_token()},timeout=60) as client:
        if action=='inspect':
            result=query(client,REF,"select jsonb_build_object('settings',(select to_jsonb(s) from research.pilot_settings s),'migration_applied',exists(select 1 from supabase_migrations.schema_migrations where version='20261023123000'),'candidate_count',(select count(*) from research.tester_candidates),'rpc_present',to_regprocedure('public.api_submit_tester_interest_v2(text,text,boolean,text)') is not null,'columns',(select jsonb_agg(jsonb_build_object('name',column_name,'nullable',is_nullable)) from information_schema.columns where table_schema='research' and table_name='tester_candidates'),'admin_definition',pg_get_functiondef('public.api_admin_research(uuid,text,uuid,jsonb)'::regprocedure)) as state")
            save('inspect-'+datetime.now(timezone.utc).strftime('%H%M%S')+'.json',result)
            print(json.dumps({'inspection_saved':True,'migration_applied':result[0]['state']['migration_applied'],'rpc_present':result[0]['state']['rpc_present'],'candidate_count':result[0]['state']['candidate_count']}));return
        sql=MIGRATION.read_text(encoding='utf-8')
        if action in ('preview','migrate'):
            if action=='preview':
                sql=sql.replace('commit;',"select jsonb_build_object('name_nullable',(select is_nullable='YES' from information_schema.columns where table_schema='research' and table_name='tester_candidates' and column_name='name'),'rpc_present',to_regprocedure('public.api_submit_tester_interest_v2(text,text,boolean,text)') is not null) as verification; rollback;")
            else:
                if not (OUT/'preview-result.json').exists(): raise ValueError('Preview required')
                if json.loads((OUT/'preview-result.json').read_bytes()) != [{'verification':{'rpc_present':True,'name_nullable':True}}]:
                    raise ValueError('Preview assertions failed; inspect before applying')
                sql=sql.replace('commit;',f"insert into supabase_migrations.schema_migrations(version,name,statements) values ({q(VERSION)},'android_tester_name_email',ARRAY[{q(MIGRATION.read_text(encoding='utf-8'))}]); commit;")
        else:
            if not query(client,REF,f"select exists(select 1 from supabase_migrations.schema_migrations where version={q(VERSION)}) as applied")[0]['applied']:raise ValueError('Migration missing')
            legal={}
            for line in (ROOT/'apps/landing/.env').read_text(encoding='utf-8-sig').splitlines():
                if '=' in line and not line.lstrip().startswith('#'):
                    key,value=line.split('=',1);legal[key.strip()]=value.strip().strip('\"').strip("'")
            controller=legal['PRUEVIA_PRIVACY_CONTROLLER'];address=legal['PRUEVIA_PRIVACY_ADDRESS'];email=legal['PRUEVIA_PRIVACY_EMAIL']
            if len(controller)<3 or len(address)<11 or '@' not in email:raise ValueError('Reviewed privacy contact missing')
            save('settings-before.json',query(client,REF,'select to_jsonb(s) as settings from research.pilot_settings s'))
            sql=f"begin; set local lock_timeout='250ms'; set local statement_timeout='10s'; update research.pilot_settings set tester_intake_enabled=true, controller_name={q(controller)}, controller_address={q(address)}, privacy_email={q(email)}, notice_version='android-testers-2026-10-23-v2', pilot_starts_at=now(), pilot_ends_at=now()+interval '90 days', updated_at=now() where id and test_started_at is null and not tester_intake_enabled; select public.api_android_pilot_info() as info; commit;"
        save(action+'-send.json',{'at':datetime.now(timezone.utc).isoformat(),'project_ref':REF,'sha256':hashlib.sha256(sql.encode()).hexdigest(),'authorization':'User 2026-10-23: activate closed Android recruitment with name and Gmail stored in our database','action':action})
        result=query(client,REF,sql)
        save(action+'-result.json',result)
        print(json.dumps({'action':action,'response_received':True}))

if __name__=='__main__':main()
