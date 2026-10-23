"""Read current public offer scopes and compare exact source identities, never publish."""
import argparse,json,hashlib
from collections import Counter
from pathlib import Path
from datetime import datetime,timezone
import httpx
from publish_denue_bulk_linked import management_token
from run_local_review_queue import query
ROOT=Path(__file__).resolve().parents[2];REF='ymtcmfgwuzdqtsbuvzqf'
BRANDS={'f86e479a-548d-5ef9-a689-ee7cf8b78a05':'salud_digna_puebla','ab44ecd3-3bbd-5171-920b-7f0d47861db3':'ruiz_puebla'}
KEYS={('regular','default'):'regular',('online','default'):'online',('promo','default'):'promotion',('member','blue_card'):'blue_card',('member','gold_card'):'gold_card',('other','prepaid'):'prepaid'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifact',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 a.output.resolve().relative_to(ROOT/'collectors/artifacts');a.output.mkdir(parents=True,exist_ok=False)
 sources={};files=[]
 for folder in a.artifact:
  folder=folder.resolve()
  folder.resolve().relative_to(ROOT/'collectors/artifacts')
  manifest=json.loads((folder/'run_manifest.json').read_bytes());assert manifest['status']=='succeeded'
  f=folder/'raw_records.jsonl';files.append({'path':f.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
  for line in f.read_text(encoding='utf-8').splitlines():
   row=json.loads(line)
   if row['record_type']!='provider_offer_price':continue
   key=(manifest['source_key'],row['external_record_id'])
   if key in sources:raise ValueError('Do not collapse different source captures of one external identity')
   sources[key]=row
 sql="""select coalesce(jsonb_agg(to_jsonb(r) order by r.offer_id,r.scope_id,r.price_id),'[]'::jsonb) as rows from (
 select o.id offer_id,o.provider_brand_id,b.name provider_name,o.catalog_item_id,o.provider_display_name,o.provider_sku,
 s.id scope_id,s.scope_type,s.provider_location_id,s.provider_market_id,l.location_code,
 p.id price_id,p.price_type,p.price_key,p.channel,p.amount_minor,p.currency,p.conditions,p.valid_from,p.valid_to,
 rr.external_record_id,rr.observed_at source_observed_at,rr.payload->>'location_external_id' raw_location_external_id
 from supply.offers o join core.provider_brands b on b.id=o.provider_brand_id
 left join supply.offer_scopes s on s.offer_id=o.id and s.status='active'
 left join core.provider_locations l on l.id=s.provider_location_id
 left join supply.price_versions p on p.offer_scope_id=s.id and p.is_current
 left join ingest.source_observations so on so.id=p.source_observation_id
 left join ingest.raw_records rr on rr.id=so.raw_record_id
 where o.status='active') r"""
 assert (ROOT/'database/supabase/.temp/project-ref').read_text().strip()==REF
 with httpx.Client(base_url='https://api.supabase.com',headers={'Authorization':'Bearer '+management_token()},timeout=60) as client:
  rows=query(client,REF,sql)[0]['rows']
  count=query(client,REF,"select count(*) as rows from supply.offers where status='active'")[0]['rows']
  api_keys=query(client,REF,"select jsonb_object_keys(public.api_resolve_search('biometria hematica','health_diagnostics',null,null,null,10)) as key")
 if len({r['offer_id'] for r in rows})!=count:raise ValueError('Current offer inventory incomplete')
 results=[]
 for row in rows:
  source=BRANDS.get(row['provider_brand_id']);key=(source,row['external_record_id']);fresh=sources.get(key)
  entry={**row,'state':'unmatched_source','fresh_amount_minor':None}
  if fresh is not None:
   field=KEYS.get((row['price_type'],row['price_key']))
   location_ok=source!='salud_digna_puebla' or (row['scope_type']=='location' and row['raw_location_external_id']==fresh['payload'].get('location_external_id') and row['location_code']==fresh['payload'].get('location_external_id'))
   amount=fresh['payload'].get('prices',{}).get(field)
   entry.update(fresh_external_id=fresh['external_record_id'],fresh_record_hash=fresh['record_hash'],fresh_source_url=fresh['source_url'],fresh_amount_minor=amount)
   if not location_ok:entry['state']='location_binding_requires_review'
   elif row['price_id'] is None or field is None or row['channel']!='any' or row['currency']!='MXN':entry['state']='contract_not_comparable'
   elif amount is None:entry['state']='source_price_missing'
   else:entry['state']='amount_same' if amount==row['amount_minor'] else 'amount_changed_requires_review'
  results.append(entry)
 report={'at':datetime.now(timezone.utc).isoformat(),'project_ref':REF,'offers':count,'price_scope_rows':len(rows),'states':dict(Counter(r['state'] for r in results)),
  'rows':results,'source_files':files,'api_search_keys':api_keys,'database_writes':0,'prices_published':0,
  'limits':['Same amount is not proof that conditions, validity, channel or location are commercially verified','An unmatched source is not a missing offer or permission to infer its price','No patient records read']}
 with (a.output/'comparison.json').open('x',encoding='utf-8') as f:json.dump(report,f,ensure_ascii=False,indent=2)
 print(json.dumps({k:report[k] for k in ['at','offers','price_scope_rows','states','api_search_keys','database_writes']}))
if __name__=='__main__':main()
