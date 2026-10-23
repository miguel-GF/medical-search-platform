"""Prepare a local-only requirements experiment from pinned SQL sources."""
import argparse,difflib,hashlib,json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--requirements-dir',type=Path,required=True)
    parser.add_argument('--baseline-receipt',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    for path in [args.requirements_dir,args.baseline_receipt,args.output]:path.resolve().relative_to(ROOT/'collectors/artifacts')
    proof=json.loads(args.baseline_receipt.read_bytes())
    sources={}
    for version in (3,4,6):
        name=f'catalog-resolve_items_v{version}-PROPOSED.sql';raw=(args.requirements_dir/name).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=proof['requirements_source_sha256'][name]:raise ValueError('Requirements source changed')
        sources[name]=raw.decode('utf-8').replace('\r\n','\n')
    originals=dict(sources)
    def replace(text,old,new):
        if text.count(old)!=1:raise ValueError('Unexpected SQL layout: '+old[:80])
        return text.replace(old,new)
    key='catalog-resolve_items_v3-PROPOSED.sql';text=sources[key]
    text=replace(text,') as literal_requirements_present\n  from lexical_accepted a',") as literal_requirements_present,\n    (a.term_source in ('name','alias') and a.match_method in ('exact','alias')\n      and a.confidence = 1\n      and core.normalized_text(a.matched_term)=core.normalized_text(p_query)) as exact_identity_literal,\n    (core.normalized_text(p_query) ~ '^[a-z]{4,40}$'\n      and not (core.normalized_text(p_query) = any(string_to_array(core.normalized_text(a.matched_term),' ')))\n      and exists(select 1 from unnest(string_to_array(core.normalized_text(a.matched_term),' ')) mt(token)\n                 where mt.token like core.normalized_text(p_query)||'%')) as prefix_discovery\n  from lexical_accepted a")
    text=replace(text,'exists (select 1 from requirement_checked x where not x.literal_requirements_present) as requirements_pruned',
        '(not a.exact_identity_literal and exists (select 1 from requirement_checked x where not x.literal_requirements_present)) as requirements_pruned')
    text=replace(text,'where a.literal_requirements_present','where a.literal_requirements_present or a.prefix_discovery')
    text=replace(text,"case when r.requirements_pruned or r.candidate_count > 1 then 'ambiguous'", "case when r.prefix_discovery or r.requirements_pruned or r.candidate_count > 1 then 'ambiguous'")
    text=replace(text,"'requirements_policy', 'literal-content-v1-PROPOSED'", "'prefix_discovery', r.prefix_discovery,\n    'exact_identity_literal', r.exact_identity_literal,\n    'requirements_policy', 'literal-content-v2-LOCAL-EXPERIMENT'")
    sources[key]=text
    key='catalog-resolve_items_v4-PROPOSED.sql'
    sources[key]=replace(sources[key],"or r.safe_count > 1 or r.term_source = 'disambiguation'", "or coalesce((r.explanation_data->>'prefix_discovery')::boolean,false)\n                 or r.safe_count > 1 or r.term_source = 'disambiguation'")
    args.output.mkdir(parents=True,exist_ok=False)
    diffs=[];pins={}
    for name,text in sources.items():
        raw=text.encode('utf-8');(args.output/name).write_bytes(raw);pins[name]=hashlib.sha256(raw).hexdigest()
        diffs.extend(difflib.unified_diff(originals[name].splitlines(keepends=True),text.splitlines(keepends=True),fromfile='original/'+name,tofile='local-experiment/'+name))
    (args.output/'candidate.diff').write_text(''.join(diffs),encoding='utf-8')
    report={'source_sha256':proof['requirements_source_sha256'],'candidate_sha256':pins,'changes':['Exact approved name/alias with all literal requirements no longer downgraded solely by rejected fuzzy alternatives','Single alphabetic token prefix proposals retained as ambiguous discovery only'],
        'production_authorization':False,'remote_sql_submitted':False,'complete_combined_candidate_integrated':False}
    (args.output/'preparation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
