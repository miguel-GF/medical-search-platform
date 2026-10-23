"""Prepare a source-backed, loopback-only reconciliation; no network or DB writes."""
import argparse,difflib,hashlib,json,re,unicodedata
from pathlib import Path
from publish_golden_catalog import q
ROOT=Path(__file__).resolve().parents[2]
RUIZ='ab44ecd3-3bbd-5171-920b-7f0d47861db3'
T3='ee4001a7-229d-5b99-bbbf-9c44aca29fe8'
LEX_IDS=['6c6f85f6-9591-48e6-aa44-a2a9fbcc5ba5','bfd58a97-636b-411a-a25b-1c25037c61f1','0426f984-aefc-4ee1-b9b6-c4d1d2e353c9']
def load(path):return json.loads(path.read_bytes())
def norm(text):return re.sub('[^a-z0-9]+',' ',''.join(c for c in unicodedata.normalize('NFKD',text.casefold()) if not unicodedata.combining(c))).strip()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--export',type=Path,required=True);p.add_argument('--ruiz-artifact',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 for path in [a.export,a.ruiz_artifact,a.output]:path.resolve().relative_to(ROOT/'collectors/artifacts')
 receipt=load(a.export/'export-receipt.json')
 for name,pin in receipt['files_sha256'].items():
  if hashlib.sha256((a.export/name).read_bytes()).hexdigest()!=pin:raise ValueError('Export changed')
 manifest=load(a.ruiz_artifact/'run_manifest.json');assert manifest['status']=='succeeded' and manifest['source_key']=='ruiz_puebla'
 sourcefile=a.ruiz_artifact/'raw_records.jsonl';rows=[json.loads(s) for s in sourcefile.read_text(encoding='utf-8').splitlines()]
 rejected=load(ROOT/'docs/proposals/20261023-explicit-identity/evidence.json')['canonical_incomplete_after']
 services={r['catalog_item_id']:r for r in load(a.export/'health.services.json')}
 names=load(a.export/'catalog.item_names.json');aliases=load(a.export/'catalog.item_aliases.json')
 anatomy={r['code']:r for r in load(a.export/'health.anatomical_sites.json') if r['status']=='active'}
 existing_edges=load(a.export/'health.service_anatomy.json');definitions=load(a.export/'health.lab_service_definitions.json')
 controls=[];changes=[]
 sql=["-- LOCAL EVALUATION ONLY. Not a migration or approved production operation.","begin;",
 "do $$ begin if current_setting('pruevia.local_evaluation',true) is distinct from 'true' or inet_server_addr() <> '127.0.0.1'::inet then raise exception 'This reconciliation is restricted to the isolated loopback evaluation'; end if; end $$;"]
 for case in rejected:
  label=case['query'];ids=case['expected_item_ids'];assert len(ids)==1;item=ids[0]
  if item==T3:continue
  source=[r for r in rows if r['record_type']=='provider_offer_price' and r['payload']['provider_display_name']==label]
  assert len(source)==1 and services[item]['service_type']=='imaging'
  assert any(n['item_id']==item and n['is_primary'] and n['name']==label for n in names)
  assert any(x['item_id']==item and x['provider_brand_id']==RUIZ and x['status']=='approved' and x['alias']==label and x['confidence']==1 for x in aliases)
  source=source[0];text=norm(label);before=services[item];after={}
  after['modality']={'resonancia-magnetica':'magnetic_resonance','tomografia':'tomography','ultrasonido':'ultrasound'}[source['payload']['department_slug']]
  if 'con contraste' in text:
   assert 'sin contraste' not in text and before['contrast_mode']=='not_applicable';after['contrast_mode']='with'
  sides=[value for pattern,value in [(r'\bderech[oa]\b','right'),(r'\bizquierd[oa]\b','left'),(r'\bbilateral\b','bilateral')] if re.search(pattern,text)]
  assert len(sides)<=1
  if sides:after['laterality']=sides[0]
  checks=' and '.join(k+' is not distinct from '+q(before[k]) for k in after)
  setters=','.join(k+'='+q(v) for k,v in after.items())
  sql.append(f"do $$ begin update health.services set {setters} where catalog_item_id={q(item)}::uuid and {checks}; if not found then raise exception 'Reviewed service attributes changed'; end if; end $$;")
  site=None
  for phrase,code in [('extremidades inferiores','lower_extremity'),('miembros inferiores','lower_extremity'),('miembros superiores','upper_extremity')]:
   if phrase in text:site=anatomy[code]
  if site:
   assert not any(e['service_id']==item for e in existing_edges)
   sql.append(f"insert into health.service_anatomy(service_id,anatomical_site_id,role,laterality_override,created_at) values ({q(item)}::uuid,{q(site['id'])}::uuid,'target',NULL,now());")
  changes.append({'item_id':item,'name':label,'before':{k:before[k] for k in after},'after':after,'anatomy_code_added':site['code'] if site else None,'source_external_id':source['external_record_id'],'source_url':source['source_url'],'source_record_hash':source['record_hash']})
  for altered in ['sin '+label,label+' x2',label+' x3']:
   controls.append({'query':altered,'must_not_resolve_ids':[item]})
  if 'CON CONTRASTE' in label:
   controls.extend({'query':label.replace('CON CONTRASTE',replacement),'must_not_resolve_ids':[item]} for replacement in ['SIN CONTRASTE','CON Y SIN CONTRASTE'])
  if sides and sides[0] in ['left','right']:
   swapped=re.sub(r'DERECH([OA])',r'IZQUIERD\1',label) if sides[0]=='right' else re.sub(r'IZQUIERD([OA])',r'DERECH\1',label)
   assert swapped!=label;controls.append({'query':swapped,'must_not_resolve_ids':[item]})
 assert len(changes)==15 and sum(c['anatomy_code_added'] is not None for c in changes)==3
 assert sum(c['after'].get('contrast_mode')=='with' for c in changes)==12
 assert any(d['service_id']==T3 and d['component']=='Triiodothyronine.free' and d['system'] is None and d['time_aspect'] is None for d in definitions)
 metadata=load(a.export/'metadata.json');base=next(f for f in metadata['functions'] if f['name']=='resolve_items');original=base['definition'].replace('\r\n','\n')
 modified=original.replace("      )) or (qa.attribute_type = 'method' and exists (", "      )) or (qa.attribute_type = 'component' and exists (\n        select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value\n      )) or (qa.attribute_type = 'method' and exists (",1)
 marker="      or (qa.attribute_type = 'method' and not exists ("
 assert modified.count(marker)==1
 modified=modified.replace(marker,"      or (qa.attribute_type = 'component' and not exists (select 1 from health.lab_service_definitions ld where ld.service_id = b.item_id and ld.component = qa.attribute_value))\n"+marker,1)
 draft=(ROOT/'docs/proposals/20261011-free-t3-component-constraint.sql').read_text(encoding='utf-8')
 end=draft.index('$function$',draft.index('AS $function$')+len('AS $function$'))+len('$function$')
 proposed=draft[draft.index('CREATE OR REPLACE FUNCTION catalog.resolve_items('):end]
 assert modified.strip().rstrip(';').strip()==proposed.strip(),'Do not change the existing component proposal silently'
 lex=load(a.export/'health.query_lexicon.json');selected=[r for r in lex if r['id'] in LEX_IDS]
 assert len(selected)==3 and not any(r['status']=='approved' and r['attribute_type']=='component' for r in lex)
 assert all(r['attribute_type']=='service_type' and r['attribute_value']=='__blocked_analyte_variant__' and r['status']=='approved' for r in selected)
 sql.append(modified.rstrip().rstrip(';')+';')
 sql.append("update health.query_lexicon set attribute_type='component',attribute_value='Triiodothyronine.free' where id in ("+','.join(q(v)+'::uuid' for v in LEX_IDS)+");")
 sql.append('commit;')
 for query in ['t3 libre','Triyodotironina libre (T3 libre)']:
  controls.append({'query':query,'expected_item_ids':[T3]})
 for query in ['T3 total','T4 libre','T3 reversa','Captación de T3','T3 libre total','T3 libre x2','sin T3 libre','T3 libre en orina']:
  controls.append({'query':query,'must_not_resolve_ids':[T3]})
 a.output.mkdir(parents=True,exist_ok=False)
 (a.output/'reconciliation-LOCAL-ONLY.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8')
 (a.output/'controls.json').write_text(json.dumps(controls,ensure_ascii=False,indent=2),encoding='utf-8')
 (a.output/'component-function.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),modified.splitlines(True),fromfile='actual',tofile='local-component-support')),encoding='utf-8')
 report={'scope':'loopback-only evaluation, no production activation','source_run_id':manifest['run_id'],'source_sha256':hashlib.sha256(sourcefile.read_bytes()).hexdigest(),'imaging_changes':changes,'positive_component_lexicon_ids':LEX_IDS,'base_function_md5':base['md5'],'additional_controls':len(controls),'clinical_equivalences_approved':0,'remote_writes':0}
 (a.output/'preparation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'imaging_services':len(changes),'contrast_repairs':12,'anatomy_relations':3,'positive_component_constraints':3,'additional_controls':len(controls),'remote_writes':0}))
if __name__=='__main__':main()
