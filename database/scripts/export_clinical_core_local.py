"""Export public catalog inputs for local core evaluation. Remote SELECTs only."""
import argparse
from datetime import datetime,timezone
import hashlib,json,re,sys
from pathlib import Path
import httpx
from publish_denue_bulk_linked import management_token
from run_local_review_queue import query
from publish_golden_catalog import q

ROOT=Path(__file__).resolve().parents[2]
TABLES=['catalog.disambiguation_candidates','catalog.disambiguation_terms','catalog.domains',
 'catalog.item_aliases','catalog.item_descriptions','catalog.item_identifiers','catalog.item_names','catalog.items',
 'health.anatomical_sites','health.query_lexicon','health.service_anatomy','health.service_methods',
 'health.service_specimens','health.services','health.specimen_types']
FUNCTIONS=['core.normalized_text','catalog.resolve_items','catalog.resolve_items_v2','catalog.resolve_items_v3',
 'catalog.resolve_items_v4','catalog.resolve_items_v5','catalog.resolve_items_v6']

def write(path,value):
    with path.open('x',encoding='utf-8') as f:json.dump(value,f,ensure_ascii=False,indent=2)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    out=parser.parse_args().output.resolve();out.relative_to(ROOT/'collectors/artifacts')
    ref=(ROOT/'database/supabase/.temp/project-ref').read_text().strip()
    if ref!='ymtcmfgwuzdqtsbuvzqf':raise ValueError('Wrong project')
    out.mkdir(parents=True,exist_ok=False)
    write(out/'started.json',{'at':datetime.now(timezone.utc).isoformat(),'project_ref':ref,'remote_writes':False})
    table_values=','.join(q(t) for t in TABLES)
    fingerprint='select jsonb_build_object('+','.join(q(t)+",(select jsonb_build_object('rows',count(*),'md5',md5(coalesce(string_agg(h,'' order by h),''))) from (select md5(to_jsonb(t)::text) h from "+t+' t) x)' for t in TABLES)+') as state'
    columns="select jsonb_agg(jsonb_build_object('table',ns.nspname||'.'||c.relname,'name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'type_schema',tn.nspname,'type_name',ty.typname,'type_kind',ty.typtype,'not_null',a.attnotnull,'generated',a.attgenerated) order by ns.nspname,c.relname,a.attnum) as columns from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace ns on ns.oid=c.relnamespace join pg_type ty on ty.oid=a.atttypid join pg_namespace tn on tn.oid=ty.typnamespace where a.attnum>0 and not a.attisdropped and ns.nspname||'.'||c.relname in ("+table_values+')'
    enums="select ns.nspname as schema,t.typname as name,jsonb_agg(e.enumlabel order by e.enumsortorder) as labels from pg_type t join pg_namespace ns on ns.oid=t.typnamespace join pg_enum e on e.enumtypid=t.oid where t.oid in (select a.atttypid from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace ns on ns.oid=c.relnamespace where a.attnum>0 and not a.attisdropped and ns.nspname||'.'||c.relname in ("+table_values+')) group by ns.nspname,t.typname order by ns.nspname,t.typname'
    functions="select n.nspname as schema,p.proname as name,pg_get_function_identity_arguments(p.oid) as arguments,pg_get_functiondef(p.oid) as definition,md5(pg_get_functiondef(p.oid)) as md5 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname||'.'||p.proname in ("+','.join(q(f) for f in FUNCTIONS)+') order by n.nspname,p.proname'
    pending="select nr.id,nr.provider_brand_id,nr.normalized_input,nr.raw_text from ingest.normalization_runs nr join ingest.raw_records rr on rr.id=nr.raw_record_id join ingest.sources s on s.id=rr.source_id where nr.input_type='crawler' and s.source_type in ('government','provider_official','public_website') and coalesce(rr.payload->'raw_study'->>'IdPaciente','') in ('','0') and coalesce(rr.payload->'raw_study'->>'IdPacienteSisPrev','') in ('','0') and nr.status in ('pending','ambiguous','no_match') and not exists(select 1 from ingest.normalization_decisions nd where nd.normalization_run_id=nr.id and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match')) order by nr.id"
    with httpx.Client(base_url='https://api.supabase.com',headers={'Authorization':'Bearer '+management_token()},timeout=120) as db:
        before=query(db,ref,fingerprint)[0]['state'];write(out/'catalog-before.json',before)
        if any(v['rows']>50000 for v in before.values()):raise ValueError('Catalog export bound exceeded')
        metadata={'columns':query(db,ref,columns)[0]['columns'],'enums':query(db,ref,enums),'functions':query(db,ref,functions)}
        if len(metadata['functions'])!=7:raise ValueError('Unexpected resolver overloads')
        write(out/'metadata.json',metadata)
        for table in TABLES:
            records=query(db,ref,'select coalesce(jsonb_agg(to_jsonb(t)),\'[]\'::jsonb) as rows from '+table+' t')[0]['rows']
            if len(records)!=before[table]['rows']:raise ValueError('Incomplete catalog export')
            write(out/(table+'.json'),records)
        # One aggregate row avoids Management API row caps; total is checked independently.
        contexts=query(db,ref,"select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) as rows from ("+pending+') p')[0]['rows']
        count=query(db,ref,"select count(*) as rows from ingest.normalization_runs nr where nr.input_type='crawler' and nr.status in ('pending','ambiguous','no_match') and not exists(select 1 from ingest.normalization_decisions nd where nd.normalization_run_id=nr.id and nd.decision_type in ('automatic','manual','ambiguous','rejected','no_match'))")[0]['rows']
        if len(contexts)!=count or len({r['id'] for r in contexts})!=count:raise ValueError('Pending export is not complete public crawler data')
        write(out/'pending-labels.json',contexts)
        after=query(db,ref,fingerprint)[0]['state'];write(out/'catalog-after.json',after)
        if before!=after:raise ValueError('Catalog changed during export')
    receipt={'at':datetime.now(timezone.utc).isoformat(),'project_ref':ref,'tables':before,'functions':7,'pending_contexts':len(contexts),'catalog_unchanged':True,'remote_writes':False,'patient_inputs_exported':False,
       'files_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.glob('*.json'))}}
    write(out/'export-receipt.json',receipt)
    print(json.dumps({'catalog_tables':len(TABLES),'functions':7,'pending_contexts':len(contexts),'remote_writes':False}))

if __name__=='__main__':main()
