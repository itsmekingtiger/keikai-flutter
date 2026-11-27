import json,os,sys
S='/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad'
P=S+'/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project'
tpl=open(S+'/wf/fix_template4.js').read()
found=json.load(open(S+'/wf/'+sys.argv[2]))
def F(f):
    return {'id':f['_id'],'file':f['file'],'line':f.get('line'),'title':f['title'],'severity':f['severity'],'category':f['category'],
            'explanation':f['explanation'],'evidence':f['evidence'],'suggestedFix':f['suggestedFix']}
order={'high':0,'medium':1,'low':2}
def of(target): return [F(f) for f in sorted((x for x in found if x['_target']==target), key=lambda x: order[x['severity']])]
APP=' The example app (example/lib, tests in test/example) and the catalogue sheets (example/lib/sheets) use these widgets: a change of pixels changes sheet goldens on purpose; never regenerate them, list them in your report.'
SPEC=json.load(open(S+'/wf/'+sys.argv[3]))
G={}
for k,v in SPEC['groups'].items():
    G[k]=dict(files=v['files'],tests=v.get('tests',[]),note=v.get('note','')+APP,findings=of(k))
    if v.get('newTests'): G[k]['newTests']=v['newTests']
args={'root':'/home/user/keikai','repo':'/home/user/keikai-before','stage':S+'/fixes',
      'tokens':P+'/tokens.json','css':P+'/components/bundle.css','readme':P+'/README.md',
      'lanes':[[dict(key=k,**G[k]) for k in lane] for lane in SPEC['lanes']]}
out=sys.argv[1]
open(out,'w').write(tpl.replace('__ARGS__', json.dumps(args, ensure_ascii=False, indent=1)))
print('groups',sum(len(l) for l in SPEC['lanes']),'findings',sum(len(G[k]['findings']) for l in SPEC['lanes'] for k in l),'bytes',os.path.getsize(out))
