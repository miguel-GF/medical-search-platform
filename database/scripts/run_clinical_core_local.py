"""Pair actual resolver functions/catalog with proposed filters on an isolated local PG.

No remote connection is implemented. Catalog values/functions are not mocked.
Constraints, indexes, JWT, geography and public wrappers are outside this check.
"""
import argparse
from collections import Counter,defaultdict
from datetime import datetime,timezone
import hashlib,json,os,secrets,socket,subprocess,sys,time
import re
from pathlib import Path
import psycopg
from psycopg.types.json import Jsonb

ROOT=Path(__file__).resolve().parents[2]
PG_BIN=Path('C:/laragon/bin/postgresql/pgsql-12.2/bin')

def quote(identifier):return '"'+identifier.replace('"','""')+'"'
def relation(name):return '.'.join(quote(part) for part in name.split('.'))
def save(path,value):
    with path.open('x',encoding='utf-8') as target:json.dump(value,target,ensure_ascii=False,indent=2)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export',type=Path,required=True)
    parser.add_argument('--requirements-dir',type=Path,required=True)
    parser.add_argument('--run-name',default='local-core-runtime')
    parser.add_argument('--pg-bin',type=Path,default=PG_BIN)
    parser.add_argument('--canonical-controls',action='store_true',help='Also compare every active primary health name and two underspecified-query controls')
    parser.add_argument('--local-reconciliation',type=Path,help='Explicit local-only SQL function/data reconciliation after the baseline; never sent remotely')
    parser.add_argument('--additional-controls',type=Path,help='Local JSON controls with explicit forbidden/expected IDs')
    args=parser.parse_args()
    source=args.export.resolve();source.relative_to(ROOT/'collectors/artifacts')
    requirements=args.requirements_dir.resolve();requirements.relative_to(ROOT/'collectors/artifacts')
    reconciliation=None
    if args.local_reconciliation:
        patch_path=args.local_reconciliation.resolve();patch_path.relative_to(ROOT/'collectors/artifacts')
        reconciliation=patch_path.read_bytes()
    extra_controls=[]
    if args.additional_controls:
        extra_path=args.additional_controls.resolve();extra_path.relative_to(ROOT/'collectors/artifacts')
        extra_controls=json.loads(extra_path.read_bytes())
        if not isinstance(extra_controls,list) or len(extra_controls)>500:raise ValueError('Bound additional controls to 500 public queries')
        for control in extra_controls:
            if not isinstance(control,dict) or set(control)-{'query','expected_item_ids','must_not_resolve_ids'} or not isinstance(control.get('query'),str) or not 1<=len(control['query'])<=500:
                raise ValueError('Invalid additional control')
            for key in ['expected_item_ids','must_not_resolve_ids']:
                if key in control and (not isinstance(control[key],list) or any(not re.fullmatch('[0-9a-f-]{36}',v) for v in control[key])):raise ValueError('Control IDs must be UUIDs')
    for version_number in (3,4,6):
        if not (requirements/f'catalog-resolve_items_v{version_number}-PROPOSED.sql').is_file():
            raise ValueError('Prepare all three candidate SQL files before starting PostgreSQL')
    receipt=json.loads((source/'export-receipt.json').read_bytes())
    for name,digest in receipt['files_sha256'].items():
        if hashlib.sha256((source/name).read_bytes()).hexdigest()!=digest:raise ValueError('Export evidence changed')
    metadata=json.loads((source/'metadata.json').read_bytes())
    if metadata['enums'] or any(c['type_schema']!='pg_catalog' for c in metadata['columns']):raise ValueError('Unsupported local type; do not substitute types')
    if not re.fullmatch('[a-z0-9-]{1,60}',args.run_name):raise ValueError('Use a simple isolated run name')
    runtime=source/args.run_name;runtime.mkdir(exist_ok=False)
    password_file=runtime/'password.local';password=secrets.token_hex(32);password_file.write_text(password,encoding='utf-8')
    env=dict(os.environ,PGPASSWORD=password,PGCLIENTENCODING='UTF8')
    creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
    def native(tool,arguments,log,timeout=60):
        with (runtime/log).open('ab') as output:
            result=subprocess.run([str(args.pg_bin/(tool+'.exe')),*arguments],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=timeout,creationflags=creationflags)
        if result.returncode:raise RuntimeError(tool+' failed; inspect local '+log)
    connection=None;start_attempted=False;summary=None
    try:
        native('initdb',['-D',str(runtime/'data'),'-A','scram-sha-256','-U','candidate_eval','--locale=C','--encoding=UTF8','--pwfile='+str(password_file)],'initdb.log')
        with socket.socket() as listener:
            listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
        start_attempted=True
        native('pg_ctl',['-D',str(runtime/'data'),'-l',str(runtime/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],'pgctl.log')
        connection=psycopg.connect(host='127.0.0.1',port=port,user='candidate_eval',password=password,dbname='postgres',autocommit=True)
        connection.execute("set timezone='UTC'")
        connection.execute("set statement_timeout='30s'")
        connection.execute('create schema extensions; create extension unaccent with schema extensions; create extension pg_trgm with schema extensions; create schema catalog; create schema health; create schema core')
        version=connection.execute('show server_version').fetchone()[0]
        for table in receipt['tables']:
            columns=[c for c in metadata['columns'] if c['table']==table]
            ddl='create table '+relation(table)+' ('+', '.join(quote(c['name'])+' '+c['type']+(' not null' if c['not_null'] else '') for c in columns)+')'
            connection.execute(ddl)
            records=json.loads((source/(table+'.json')).read_bytes())
            connection.execute('insert into '+relation(table)+' select * from jsonb_populate_recordset(null::'+relation(table)+',%s::jsonb)',[Jsonb(records)])
            compare="with expected as (select value as row_value from jsonb_array_elements(%s::jsonb)),actual as (select to_jsonb(t) as row_value from "+relation(table)+" t) select count(*) from ((select row_value from expected except all select row_value from actual) union all (select row_value from actual except all select row_value from expected)) mismatch"
            if connection.execute(compare,[Jsonb(records)]).fetchone()[0]:raise ValueError('Local table values differ: '+table)
        definitions={f['schema']+'.'+f['name']:f['definition'] for f in metadata['functions']}
        order=['core.normalized_text','catalog.resolve_items','catalog.resolve_items_v2','catalog.resolve_items_v3','catalog.resolve_items_v4','catalog.resolve_items_v5','catalog.resolve_items_v6']
        for name in order:connection.execute(definitions[name])
        print(json.dumps({'stage':'local_catalog_loaded','server_version':version,'tables':len(receipt['tables']),'functions':len(order),'semantic_row_comparison':'all exported fields equal'}),flush=True)
        contexts=json.loads((source/'pending-labels.json').read_bytes())
        groups=defaultdict(list)
        for row in contexts:groups[(row['provider_brand_id'],row['normalized_input'],row['raw_text'])].append(row['id'])
        cases=[{'kind':'pending','provider':provider,'label':label,'query':raw,'input_ids':sorted(ids)} for (provider,label,raw),ids in sorted(groups.items())]
        labels=['Biometría hemática','Biometría hemática INR','Biometría hemática x2','hematica','biometria','orina','sangre','electro','electrocardiograma','ecocardiograma','hepatica',
            'tiempo de protrombina','tiempo de protrombina con INR','tiempo de protrombina x2','sin tiempo de protrombina','cortisol en saliva','cortisol en saliva AM','cortisol en saliva x2',
            'IgE específica contra gluten','IgE específica contra gluten sin IgE','TELERADIOGRAFIA DE TORAX PA','TELERADIOGRAFIA TORAX PA Y LATERAL']
        cases.extend({'kind':'control','provider':None,'label':label,'query':label,'input_ids':[]} for label in labels)
        canonical_controls=0
        if args.canonical_controls:
            active={r['id'] for r in json.loads((source/'catalog.items.json').read_bytes()) if r['status']=='active'}
            health_ids={r['catalog_item_id'] for r in json.loads((source/'health.services.json').read_bytes())}
            expected=defaultdict(set)
            for row in json.loads((source/'catalog.item_names.json').read_bytes()):
                if row['is_primary'] and row['item_id'] in active & health_ids:
                    expected[row['name']].add(row['item_id'])
            cases.extend({'kind':'control','control_type':'canonical_primary_name','expected_item_ids':sorted(ids),
                'provider':None,'label':label,'query':label,'input_ids':[]} for label,ids in sorted(expected.items()))
            canonical_controls=len(expected)
            cases.extend({'kind':'control','control_type':'underspecified','provider':None,'label':label,'query':label,'input_ids':[]}
                for label in ['renina','Plasmodium'])
        cases.extend({'kind':'control','control_type':'additional_constraint','provider':None,'label':c['query'],'input_ids':[],**c} for c in extra_controls)
        save(runtime/'cases.json',cases)
        def run_phase(phase):
            counts=Counter();start=time.monotonic()
            with (runtime/(phase+'.jsonl')).open('x',encoding='utf-8') as output:
                for ordinal,case in enumerate(cases):
                    scopes=[('unscoped',None)]
                    if case['provider']:scopes.append(('provider',case['provider']))
                    for scope,brand in scopes:
                        payload=connection.execute("select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from catalog.resolve_items_v6(%s,'health_diagnostics',%s::uuid,10) r",[case['query'],brand]).fetchone()[0]
                        status='resolved' if any(r['resolution_status']=='resolved' for r in payload) else 'ambiguous' if payload else 'no_match'
                        result={'ordinal':ordinal,'kind':case['kind'],'scope':scope,'query':case['query'],'provider':brand,'input_ids':case['input_ids'],'status':status,'rows':payload}
                        output.write(json.dumps(result,ensure_ascii=False)+'\n');output.flush()
                        counts[(case['kind'],scope,status)]+=1
                    if ordinal%40==0:print(json.dumps({'stage':phase,'cases_done':ordinal+1,'cases_total':len(cases),'elapsed_seconds':round(time.monotonic()-start,1)}),flush=True)
            return [{'kind':k[0],'scope':k[1],'status':k[2],'cases':v} for k,v in sorted(counts.items())]
        def function_fingerprints():
            return dict(connection.execute("select n.nspname||'.'||p.proname,md5(pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname||'.'||p.proname=any(%s) order by 1",[order]).fetchall())
        functions_before=function_fingerprints()
        before=run_phase('before')
        pins={}
        for version_number in (3,4,6):
            path=requirements/f'catalog-resolve_items_v{version_number}-PROPOSED.sql'
            raw=path.read_bytes();pins[path.name]=hashlib.sha256(raw).hexdigest()
            connection.execute(raw.decode('utf-8'))
        if reconciliation is not None:
            connection.execute("set pruevia.local_evaluation='true'")
            connection.execute(reconciliation.decode('utf-8'))
        functions_after=function_fingerprints()
        after=run_phase('after')
        changed_functions=[name for name in order if functions_before[name]!=functions_after[name]]
        summary={'at':datetime.now(timezone.utc).isoformat(),'server_version':version,'host':'127.0.0.1','port':port,'catalog_tables':len(receipt['tables']),'actual_functions':7,'replaced_local_functions':len(changed_functions),
            'requirements_functions_replaced':3,'function_fingerprints_before':functions_before,'function_fingerprints_after':functions_after,'changed_function_names':changed_functions,
            'pending_contexts':len(contexts),'pending_query_groups':len(groups),'controls':sum(c['kind']=='control' for c in cases),'canonical_controls':canonical_controls,'before':before,'after':after,'requirements_source_sha256':pins,
            'local_reconciliation_sha256':hashlib.sha256(reconciliation).hexdigest() if reconciliation is not None else None,
            'additional_controls_sha256':hashlib.sha256(args.additional_controls.read_bytes()).hexdigest() if args.additional_controls else None,
            'remote_connections':0,'patient_inputs_used':False,'clinical_equivalences_approved':0,'complete_combined_candidate_tested':False,
            'limits':['Runtime version, extensions and locale are reported for this local instance','No production constraints/indexes/permissions or JWT replicated','Only clinical requirements core; panel/image wrappers excluded','Observed selections are not approvals of pending source equivalences']}
        save(runtime/'comparison-summary.json',summary)
        print(json.dumps({'stage':'comparison_complete','pending_contexts':len(contexts),'groups':len(groups),'before':before,'after':after}),flush=True)
    except Exception as error:
        save(runtime/'error.json',{'at':datetime.now(timezone.utc).isoformat(),'error_type':type(error).__name__,'sqlstate':getattr(error,'sqlstate',None),'message':str(error)[:1200],'remote_connections':0})
        raise
    finally:
        if connection:connection.close()
        if start_attempted and (runtime/'data/postmaster.pid').exists():
            native('pg_ctl',['-D',str(runtime/'data'),'-m','fast','-w','stop'],'pgctl-stop.log')
        password_file.unlink(missing_ok=True)
        if (runtime/'data/postmaster.pid').exists():raise RuntimeError('Local server may still be running; inspect the owned cluster')
        save(runtime/'shutdown.json',{'at':datetime.now(timezone.utc).isoformat(),'server_stopped':True,'password_file_removed':not password_file.exists()})

if __name__=='__main__':main()
