import json,sys
J='/root/.claude/projects/-home-user-keikai-flutter/f20da2ea-0faa-5ffb-843b-e952279df433/subagents/workflows/'
for w in sys.argv[1:]:
    rows=[json.loads(l) for l in open(J+w+'/journal.jsonl') if l.strip()]
    lab={}; done=set()
    for r in rows:
        if r['type']=='started': lab[r.get('agentId')]=r.get('label')
        if r['type']=='result': done.add(r.get('agentId'))
    out=[]
    for a,l in lab.items():
        out.append(('done ' if a in done else 'RUN  ')+str(l))
    print(w, '|', ' ; '.join(out))
