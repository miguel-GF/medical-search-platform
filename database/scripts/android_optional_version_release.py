"""Release the explicitly requested optional Android field without replaying writes."""
import argparse,hashlib,json
from datetime import datetime,timezone
from pathlib import Path
import httpx
from publish_denue_bulk_linked import management_token
from run_local_review_queue import query
from publish_golden_catalog import q
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'collectors/artifacts/android-optional-version-20261023'
REF='ymtcmfgwuzdqtsbuvzqf';VERSION='20261023140000'
MIGRATION=ROOT/f'database/supabase/migrations/{VERSION}_android_tester_optional_version.sql'
def save(name,data):
 with (OUT/name).open('x',encoding='utf-8') as f:json.dump(data,f,ensure_ascii=False,indent=2)
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['inspect','preview','migrate','notice']);args=parser.parse_args()
 assert (ROOT/'database/supabase/.temp/project-ref').read_text().strip()==REF
 OUT.mkdir(exist_ok=True,parents=True)
 with httpx.Client(base_url='https://api.supabase.com',headers={'Authorization':'Bearer '+management_token()},timeout=60) as client:
  if args.action=='inspect':
   result=query(client,REF,"select jsonb_build_object('migration_applied',exists(select 1 from supabase_migrations.schema_migrations where version='20261023140000'),'migration_count',(select count(*) from supabase_migrations.schema_migrations),'rpc_present',to_regprocedure('public.api_submit_tester_interest_v3(text,text,boolean,text,text)') is not null,'pilot',public.api_android_pilot_info(),'columns',(select jsonb_agg(jsonb_build_object('name',column_name,'nullable',is_nullable)) from information_schema.columns where table_schema='research' and table_name='tester_candidates' and column_name in ('android_version','device_model')),'v2_md5',md5(pg_get_functiondef('public.api_submit_tester_interest_v2(text,text,boolean,text)'::regprocedure))) as state")
   save('inspect-'+datetime.now(timezone.utc).strftime('%H%M%S')+'.json',result)
   print(json.dumps({'saved':True,'migration_applied':result[0]['state']['migration_applied'],'rpc_present':result[0]['state']['rpc_present'],'columns':result[0]['state']['columns']}));return
  sql=MIGRATION.read_text(encoding='utf-8')
  if args.action=='preview':
   sql=sql.replace('commit;',"select to_regprocedure('public.api_submit_tester_interest_v3(text,text,boolean,text,text)') is not null as rpc_present; rollback;")
  elif args.action=='migrate':
   if json.loads((OUT/'preview-result.json').read_bytes())!=[{'rpc_present':True}]:raise ValueError('Preview failed')
   sql=sql.replace('commit;',f"insert into supabase_migrations.schema_migrations(version,name,statements) values ({q(VERSION)},'android_tester_optional_version',ARRAY[{q(sql)}]); commit;")
  else:
   sql="""begin;set local lock_timeout='250ms';set local statement_timeout='10s';
do $$ begin
 if to_regprocedure('public.api_submit_tester_interest_v3(text,text,boolean,text,text)') is null then raise exception 'Optional-version migration missing'; end if;
 update research.pilot_settings set notice_version='android-testers-2026-10-23-v3',updated_at=now()
   where id and notice_version='android-testers-2026-10-23-v2' and tester_intake_enabled;
 if not found then raise exception 'Pilot settings changed; inspect before continuing'; end if;
end $$;
select public.api_android_pilot_info() as info;commit;"""
  save(args.action+'-send.json',{'at':datetime.now(timezone.utc).isoformat(),'sha256':hashlib.sha256(sql.encode()).hexdigest(),'project':REF,'authorization':'User: model must not be requested; Android version must be optional; retain nullable columns','single_attempt':True})
  result=query(client,REF,sql);save(args.action+'-result.json',result)
  print(json.dumps({'action':args.action,'response_received':True}))
if __name__=='__main__':main()
