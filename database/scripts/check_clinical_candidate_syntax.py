"""Check candidate SQL/body grammar locally; not clinical or database validation."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def main():
    arguments=argparse.ArgumentParser(description=__doc__)
    arguments.add_argument('--candidate',type=Path,required=True)
    arguments.add_argument('--parser-dir',type=Path,required=True)
    arguments.add_argument('--output',type=Path,required=True)
    args=arguments.parse_args()
    for path in [args.candidate,args.parser_dir,args.output]:path.resolve().relative_to(ROOT/'collectors/artifacts')
    if args.output.exists():raise ValueError('Preserve existing syntax observations')
    sys.path.insert(0,str(args.parser_dir.resolve()))
    import pglast
    from pglast import ast,parser
    from pglast.stream import RawStream
    version=parser.get_postgresql_version()
    if version[0]!=17:raise ValueError('Use a PostgreSQL 17 grammar parser')
    raw=args.candidate.read_bytes();sql=raw.decode('utf-8')
    statements=pglast.parse_sql(sql)
    observations=[]
    for ordinal,node in enumerate(statements,1):
        statement=node.stmt
        if isinstance(statement,ast.CreateFunctionStmt):
            name='.'.join(part.sval for part in statement.funcname)
            options={option.defname:option.arg for option in statement.options}
            language=options['language'].sval
            record={'statement':ordinal,'kind':'function','name':name,'language':language}
            try:
                if language=='plpgsql':pglast.parse_plpgsql(RawStream()(statement))
                elif language=='sql':pglast.parse_sql(options['as'][0].sval)
                else:raise ValueError('Unexpected candidate function language')
                record['body_grammar_parsed']=True
            except Exception as error:
                record.update(body_grammar_parsed=False,error_type=type(error).__name__,error=str(error))
            observations.append(record)
        elif isinstance(statement,ast.DoStmt):
            options={option.defname:option.arg for option in statement.args}
            body=options['as'].sval
            record={'statement':ordinal,'kind':'anonymous_block'}
            try:
                delimiter='$pruevia_syntax_body$'
                if delimiter in body:raise ValueError('Unexpected delimiter')
                pglast.parse_plpgsql('create function syntax_body() returns void language plpgsql as '+delimiter+body+delimiter+';')
                record['body_grammar_parsed']=True
            except Exception as error:
                record.update(body_grammar_parsed=False,error_type=type(error).__name__,error=str(error))
            observations.append(record)
    report={'candidate_sha256':hashlib.sha256(raw).hexdigest(),'parser_version':pglast.__version__,'postgres_grammar_version':version,'sql_statements':len(statements),
        'function_bodies':sum(r['kind']=='function' for r in observations),'anonymous_blocks':sum(r['kind']=='anonymous_block' for r in observations),
        'body_grammar_failures':sum(not r['body_grammar_parsed'] for r in observations),'observations':observations,
        'database_connections':0,'clinical_validation':False,'catalog_types_and_dependencies_validated':False}
    with args.output.open('x',encoding='utf-8') as target:json.dump(report,target,ensure_ascii=False,indent=2)
    print(json.dumps({k:v for k,v in report.items() if k!='observations'}))
    for record in observations:
        if not record['body_grammar_parsed']:print(json.dumps(record,ensure_ascii=True))
    return 0 if not report['body_grammar_failures'] else 2

if __name__=='__main__':sys.exit(main())
