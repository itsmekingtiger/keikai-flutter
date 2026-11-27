"""make_find.py <out name> <import note file or -> <target key>... : writes a find-only review workflow script."""
import json, sys, os
S = '/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad'
P = S + '/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project'
old = json.load(open(S + '/wf/targets_old.json'))
new = json.load(open(S + '/wf/targets_new.json'))
extra = json.load(open(S + '/wf/targets_extra.json')) if os.path.exists(S + '/wf/targets_extra.json') else {}
ALL = {}
for d in (old['old'], old['hud'], old['ctl'], new, extra):
    ALL.update(d)
name, note_file, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
note = ('keikai.dart exports every finished family: foundation, layout, controls, inputs, shell, hud, charts and diagram. '
        'Other agents may be fixing defects in the files you review, or in files they depend on: judge what is on disk when you read it.')
if note_file != '-':
    note = open(note_file).read().strip()
args = {'root': '/home/user/keikai', 'tokens': P + '/tokens.json', 'css': P + '/components/bundle.css',
        'readme': P + '/README.md', 'importNote': note, 'targets': [ALL[k] for k in keys]}
tpl = open(S + '/wf/find_template.js').read()
out = f'{S}/wf/{name}.js'
open(out, 'w').write(tpl.replace('__ARGS__', json.dumps(args, ensure_ascii=False, indent=1)))
print(out, [t['key'] for t in args['targets']])
