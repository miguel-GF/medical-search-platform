"""Summarize complete local paired observations; never approve source equivalences."""
import argparse
from collections import Counter
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def outcome(row):
    resolved={candidate['item_id'] for candidate in row['rows'] if candidate['resolution_status']=='resolved'}
    # A resolved row among several candidates is not unique confirmed coverage.
    status='resolved' if len(row['rows'])==1 and len(resolved)==1 else 'ambiguous' if row['rows'] else 'no_match'
    return status,sorted(resolved)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True)
    parser.add_argument('--output-name',default='review-summary.json')
    args=parser.parse_args();runtime=args.runtime.resolve();runtime.relative_to(ROOT/'collectors/artifacts')
    if not re.fullmatch('[a-z0-9-]{1,80}\\.json',args.output_name):raise ValueError('Use a simple JSON receipt filename')
    destination=runtime/args.output_name
    if destination.exists():raise ValueError('Preserve the prior interpretation')
    complete=json.loads((runtime/'comparison-summary.json').read_bytes())
    if not json.loads((runtime/'shutdown.json').read_bytes())['server_stopped']:raise ValueError('Run has not finished')
    cases=json.loads((runtime/'cases.json').read_bytes())
    expected={(ordinal,scope) for ordinal,case in enumerate(cases) for scope in (['unscoped','provider'] if case['provider'] else ['unscoped'])}
    phases={}
    for phase in ['before','after']:
        records=[json.loads(line) for line in (runtime/(phase+'.jsonl')).read_text(encoding='utf-8').splitlines()]
        values={(row['ordinal'],row['scope']):row for row in records}
        if set(values)!=expected or len(values)!=len(records):raise ValueError('Incomplete or duplicate observations')
        phases[phase]=values
    weighted={};grouped={};changes=[];controls=[]
    for phase,values in phases.items():
        totals=Counter();groups=Counter()
        for row in values.values():
            if row['kind']!='pending':continue
            status,ids=outcome(row)
            totals[(row['scope'],status)]+=len(row['input_ids']);groups[(row['scope'],status)]+=1
        weighted[phase]=[{'scope':key[0],'status':key[1],'rows':count} for key,count in sorted(totals.items())]
        grouped[phase]=[{'scope':key[0],'status':key[1],'groups':count} for key,count in sorted(groups.items())]
    transitions=Counter()
    for key,before in phases['before'].items():
        after=phases['after'][key]
        old,old_ids=outcome(before);new,new_ids=outcome(after)
        if before['kind']=='pending':
            transitions[(before['scope'],old,new)]+=len(before['input_ids'])
            if (old,old_ids)!=(new,new_ids):changes.append({'query':before['query'],'scope':before['scope'],'provider':before['provider'],'occurrences':len(before['input_ids']),'before_status':old,'after_status':new,'before_selected_ids':old_ids,'after_selected_ids':new_ids})
        else:
            controls.append({'query':before['query'],'before_status':old,'after_status':new,'before_selected_ids':old_ids,'after_selected_ids':new_ids,
                'before_candidates':[{'name':r['display_name'],'status':r['resolution_status']} for r in before['rows']],
                'after_candidates':[{'name':r['display_name'],'status':r['resolution_status']} for r in after['rows']]})
    inputs=[identifier for case in cases if case['kind']=='pending' for identifier in case['input_ids']]
    if len(inputs)!=len(set(inputs)) or len(inputs)!=complete['pending_contexts']:raise ValueError('Pending denominator differs')
    canonical={}
    canonical_incomplete=[]
    constraint_comparison={}
    for phase,observations in phases.items():
        checked=[]
        constrained=[]
        for row in observations.values():
            case=cases[row['ordinal']]
            if case.get('control_type')=='additional_constraint':
                status,selected=outcome(row)
                forbidden=set(selected)&set(case.get('must_not_resolve_ids',[]))
                positive_ok=('expected_item_ids' not in case or
                    (status=='resolved' and set(selected)<=set(case['expected_item_ids'])))
                constrained.append({'query':case['query'],'passed':not forbidden and positive_ok,
                    'forbidden_selected_ids':sorted(forbidden),'expected_positive_satisfied':positive_ok})
            if case.get('control_type')=='canonical_primary_name':
                status,selected=outcome(row)
                correct=status=='resolved' and set(selected)<=set(case['expected_item_ids'])
                checked.append((row,case,correct))
                if phase=='after' and not correct:
                    canonical_incomplete.append({'query':case['query'],'expected_item_ids':case['expected_item_ids'],'observed':row['rows']})
        if checked:
            canonical[phase]={'names':len(checked),'unique_correct':sum(ok for _,_,ok in checked),
                'absent':sum(not row['rows'] for row,_,_ in checked),
                'incorrect_resolved':sum(any(c['resolution_status']=='resolved' and c['item_id'] not in case['expected_item_ids'] for c in row['rows']) for row,case,_ in checked),
                'resolved_by_word_fuzzy_in_all_observations':sum(any(c['resolution_status']=='resolved' and c['match_method']=='word_fuzzy' for c in row['rows']) for row in observations.values())}
        if constrained:
            constraint_comparison[phase]={'cases':len(constrained),'passed':sum(c['passed'] for c in constrained),
                'failed':[c for c in constrained if not c['passed']]}
    report={'server_version':complete['server_version'],'pending_contexts':len(inputs),'pending_groups':sum(c['kind']=='pending' for c in cases),'controls':len(controls),
        'observations_per_phase':len(expected),'core_invocations_total':len(expected)*2,'weighted_rows_by_status':weighted,'groups_by_status':grouped,
        'weighted_transitions':[{'scope':k[0],'before':k[1],'after':k[2],'rows':v} for k,v in sorted(transitions.items())],
        'changed_pending_cases':changes,'control_observations':controls,'canonical_comparison':canonical,'canonical_incomplete_after':canonical_incomplete,
        'additional_constraint_comparison':constraint_comparison,
        'clinical_equivalences_approved':0,'production_changes':0,'complete_combined_candidate_tested':False}
    with destination.open('x',encoding='utf-8') as target:json.dump(report,target,ensure_ascii=False,indent=2)
    print(json.dumps({k:v for k,v in report.items() if k not in ['changed_pending_cases','control_observations','canonical_incomplete_after']}))

if __name__=='__main__':main()
