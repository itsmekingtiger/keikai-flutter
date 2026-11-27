"""Merge the stage results of the fix-5 and fix-6 workflow journals into wf/stage_results.json (key: '<wf>|<label>')."""
import json, sys
J = '/root/.claude/projects/-home-user-keikai-flutter/f20da2ea-0faa-5ffb-843b-e952279df433/subagents/workflows/'
OUT = '/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad/wf/stage_results.json'
res = json.load(open(OUT))
state = {}
for w in ('wf_4338d661-03c', 'wf_7bb44fe3-8bb'):
    rows = [json.loads(l) for l in open(J + w + '/journal.jsonl') if l.strip()]
    lab = {}
    done = set()
    for r in rows:
        if r['type'] == 'started':
            lab[r.get('agentId')] = r.get('label')
        if r['type'] == 'result':
            done.add(r.get('agentId'))
            res[w + '|' + str(lab.get(r.get('agentId')))] = r['result']
    state[w] = {l: ('done' if a in done else 'stopped') for a, l in lab.items()}
json.dump(res, open(OUT, 'w'), ensure_ascii=False, indent=1)
json.dump(state, open(OUT.replace('stage_results.json', 'stage_state_1127.json'), 'w'), ensure_ascii=False, indent=1)
print(len(res), 'results;', json.dumps(state))
