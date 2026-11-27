import json, sys, time
J='/root/.claude/projects/-home-user-keikai-flutter/f20da2ea-0faa-5ffb-843b-e952279df433/subagents/workflows/'
targets=[a.split('|') for a in sys.argv[2:]]   # wf|label
deadline=time.time()+int(sys.argv[1])
def done(w,label):
    rows=[json.loads(l) for l in open(J+w+'/journal.jsonl') if l.strip()]
    ids=[r.get('agentId') for r in rows if r['type']=='started' and r.get('label')==label]
    fin={r.get('agentId') for r in rows if r['type']=='result'}
    return any(i in fin for i in ids)
while True:
    st=[(w,l,done(w,l)) for w,l in targets]
    if any(d for _,_,d in st) or time.time()>deadline:
        print(' ; '.join(f"{l}={'DONE' if d else 'running'}" for _,l,d in st)); break
    time.sleep(15)
