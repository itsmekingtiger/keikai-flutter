"""Monday continuation of the fix workflows that were stopped on 11-27.

Usage: python3 make_fix7.py <dir for the two scripts>
Writes keikai-fix-7a.js (foundation and layout groups) and keikai-fix-7b.js (HUD and control groups).
Every group starts at the stage it had reached: fix, attack (a report is given) or repair (problems are given).
It takes the group definitions from the two scripts that were running (fix-5 and fix-6) and the stage results
from stage_results.json, so both must be next to this file (wf/).
"""
import json, os, sys
S = '/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad'
tpl = open(S + '/wf/fix_template4.js').read()
stage = json.load(open(S + '/wf/stage_results.json'))

def args_of(script):
    s = open(S + '/wf/' + script).read()
    i = s.index('const a = ') + len('const a = ')
    return json.JSONDecoder().raw_decode(s, i)[0]

old5, old6 = args_of('keikai-fix-5.js'), args_of('keikai-fix-6.js')
G = {g['key']: g for a in (old5, old6) for lane in a['lanes'] for g in lane}

def snaps(group):
    gd = f'{S}/fixes/{group}'
    out = []
    for n in sorted(os.listdir(gd)):
        d = os.path.join(gd, n)
        if os.path.isdir(d):
            out.append({'snapshot': n, 'whatWasDone': open(os.path.join(d, 'message.txt')).read().strip()})
    return out

def fixed(key, run, nxt):
    """The fix stage is done: the group goes on with the attack."""
    g = G[key]
    g['allFindings'] = g.get('allFindings') or g['findings']
    g['findings'] = []
    g['report'] = {'report': stage[f'{run}|fix:{key}'], 'snapshots': snaps(key)}
    g['note'] = g.get('note', '') + f' Number new snapshots from {nxt}.'

def attacked(key, run, nxt, extra=''):
    """Fix and attack are done: the group goes on with the repair."""
    g = G[key]
    g['allFindings'] = g.get('allFindings') or g['findings']
    g['findings'] = []
    g['problems'] = stage[f'{run}|attack:{key}']['problems']
    g['note'] = g.get('note', '') + f' Number new snapshots from {nxt}.' + extra

fixed('effects', 'wf_4338d661-03c', '07')
fixed('ctl-plates', 'wf_7bb44fe3-8bb', '09')
attacked('hud-panel', 'wf_7bb44fe3-8bb', '11')
# grid: its problems are already in the fix-5 definition. The repair agent was stopped in the middle of its work.
G['grid']['note'] = ('An earlier repair agent was stopped in the middle of the first problem (the column ruler of the grid specimen). '
    'Its unfinished work was taken out of the tree and kept as patches: ' + S + '/partial/grid-repair/ (a patch of '
    'example/lib/sheets/layout_sheet.dart, a patch of test/layout/grid_test.dart and the scratch test p1_ruler_test.dart.txt). '
    'Read them before you start; the sheet patch used a LayoutBuilder, which test/example_keikai_only_test.dart does not allow '
    'in the example, so find another way. Number new snapshots from 03. ') + G['grid'].get('note', '')
# box-layers: what is left of finding 24 (pixel snapping) after the painting group.
G['box-layers']['note'] = G['box-layers'].get('note', '') + (' Also yours, from the painting group that could not edit your files: a KkBox that hugs '
    'its child keeps the fraction of the child (a shrink-wrapped box around the text COOLANT TEMP is 81.8 wide), so its 1px border '
    'and background end between pixels at pixel ratio 1. Consider rounding the hug size up to a whole logical pixel in RenderKkBox '
    '(layout, dry layout and the four intrinsics alike, the way RenderKkWholeWidth in lib/src/controls does) and placing an aligned '
    'child on a whole offset; it moves every test that pins a fractional hug size, so weigh it, and report what you decided.')

LANES = {
    'keikai-fix-7a': [['effects', 'tokens-colors', 'text-frame', 'box-layers'], ['grid', 'screen-split', 'flex']],
    'keikai-fix-7b': [['hud-panel', 'hud-matrix-log', 'hud-alarms'], ['ctl-plates', 'ctl-choice', 'ctl-slider', 'ctl-feedback']],
}
base = {k: old5[k] for k in ('root', 'repo', 'stage', 'tokens', 'css', 'readme')}
for name, lanes in LANES.items():
    args = dict(base, lanes=[[G[k] for k in lane] for lane in lanes])
    out = os.path.join(sys.argv[1], name + '.js')
    open(out, 'w').write(tpl.replace('__ARGS__', json.dumps(args, ensure_ascii=False, indent=1)))
    print(name, 'groups', sum(len(l) for l in lanes), 'bytes', os.path.getsize(out),
          [(k, 'repair' if G[k].get('problems') else 'attack' if G[k].get('report') else 'fix') for lane in lanes for k in lane])
