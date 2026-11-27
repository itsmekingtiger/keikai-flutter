import json,os,re,sys
S='/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad'
P=S+'/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project'
tpl=open(S+'/wf/fix_template3.js').read()
ALLT='flutter test test/foundation test/foundation_sheet_test.dart test/layout test/controls test/hud test/charts test/inputs test/shell test/diagram test/table test/example test/readme_test.dart test/example_keikai_only_test.dart'
n=0
for old in ["\\`flutter test test/foundation test/layout test/controls test/hud test/charts test/inputs test/shell\\`; leave test/diagram and test/table alone, other agents are still writing them",
            "\\`flutter test test/foundation test/layout test/controls test/hud test/charts test/inputs test/shell\\`"]:
    c=tpl.count(old); n+=c
    tpl=tpl.replace(old, "the test files of what you touched after each fix, and ONCE before you finish the whole suite: \\`"+ALLT+"\\` (it takes several minutes and queues for a slot: give it a 20 minute timeout)")
print('test instructions replaced:',n)
tpl=tpl.replace("Other agents are working in ${root} at the same time (new families under lib/src/table and lib/src/diagram, and fixes to other files).","Other agents are working in ${root} at the same time (fixes to other files).")
a=tpl[tpl.index("async function runGroup(g) {"):tpl.index("const results = await parallel(")]
b='''async function runGroup(g) {
  let fix = g.report || null
  let problems = g.problems || null
  let attack = null
  if (!problems) {
    if (g.findings.length) {
      const made = await agent(fixPrompt(g), { label: `fix:${g.key}`, phase: 'Fix', schema: FIX })
      if (!made) {
        log(`${g.key}: the fix agent returned nothing`)
        if (!fix) return { group: g.key, fix: null }
      } else {
        const fixed = made.verdicts.filter((v) => v.fixed).length
        log(`${g.key}: ${fixed} fixed, ${made.verdicts.filter((v) => !v.real).length} refuted or already fixed, of ${g.findings.length}`)
        fix = fix ? { earlier: fix, now: made } : made
      }
    }
    attack = await agent(attackPrompt(g, fix), { label: `attack:${g.key}`, phase: 'Attack', schema: ATTACK })
    problems = (attack && attack.problems) || []
    log(`${g.key}: ${attack ? 'the attack found ' + problems.length + ' problem(s)' : 'the attack agent returned nothing'}`)
  }
  let repair = null
  if (problems.length) {
    repair = await agent(repairPrompt(g, problems), { label: `repair:${g.key}`, phase: 'Repair', schema: REPAIR })
    log(`${g.key}: ${repair ? repair.repaired.filter((r) => r.done).length + ' repaired of ' + problems.length : 'the repair agent returned nothing'}`)
  }
  return { group: g.key, fix, attack, repair }
}

'''
tpl=tpl.replace(a,b)
open(S+'/wf/fix_template4.js','w').write(tpl)
found=json.load(open(S+'/wf/found.json')); found2=json.load(open(S+'/wf/found2.json'))
stage=json.load(open(S+'/wf/stage_results.json'))
def F(i, scope=None):
    f=found[i] if i<100 else found2[i-100]
    d={'id':i,'file':f['file'],'line':f.get('line'),'title':f['title'],'severity':f['severity'],'category':f['category'],
       'explanation':f['explanation'],'evidence':f['evidence'],'suggestedFix':f['suggestedFix']}
    if scope: d['scope']=scope
    return d
def snaps(group):
    gd=f'{S}/fixes/{group}'; out=[]
    for n in sorted(os.listdir(gd)):
        d=os.path.join(gd,n)
        if os.path.isdir(d): out.append({'snapshot':n,'whatWasDone':open(os.path.join(d,'message.txt')).read().strip()})
    return out
R=lambda run,label: stage[f'{run}|{label}']
INT='An earlier agent worked on this group and was cut off. '
APP=' The example app (example/lib, tests in test/example) is built on these widgets.'
G={}
G['motion-core']=dict(
  files=['lib/src/motion/loops.dart','lib/src/motion/scramble.dart','lib/src/motion/entrances.dart','lib/src/motion/stagger.dart','lib/src/foundation/motion.dart','lib/src/charts/plot.dart','lib/src/charts/gauge.dart'],
  tests=['test/foundation/motion_math_test.dart','test/foundation/motion_widgets_test.dart','test/foundation/scramble_test.dart','test/charts/gauge_donut_test.dart','test/charts/toolkit_test.dart'],
  note=INT+"Its only finished repair is snapshot 10 (read its message.txt: KkScramble.builder exists now, so that the KkScrambleBuilder of the gauge in lib/src/charts/plot.dart can be made of it; check whether that second half is done). It also left new tests for the paused-loop problem at the end of the KkLoop group in test/foundation/motion_widgets_test.dart WITHOUT the fix in lib/src/motion/loops.dart: they probably fail now. Number your snapshots from 11. Fixes 01 to 09 of this group are already released, so the paused-loop regression is live: do it first. In lib/src/charts/plot.dart and gauge.dart only the scramble of a painted value is yours.",
  findings=[], problems=R('wf_6593c07c-e8d','attack:motion-core')['problems'])
G['scroll']=dict(
  files=['lib/src/layout/scroll.dart','lib/src/layout/conveniences.dart'],
  tests=['test/layout/scroll_test.dart','test/layout/scroll_platform_test.dart'],
  note='In lib/src/layout/conveniences.dart only what KkListView hands to its scroll view is yours. KkScreen, KkDataLog, KkList, KkDataTable (which uses RawScrollbar directly), the menus, the search results and the example app (example/lib, tests in test/example) all scroll through these classes. Number your snapshots from 03.',
  findings=[], problems=R('wf_59f0e0c2-6a9','attack:scroll')['problems'])
pp=R('wf_59f0e0c2-6a9','attack:painting')['problems']
gp=R('wf_59f0e0c2-6a9','attack:grid')['problems']
G['painting']=dict(
  files=['lib/src/painting/shapes.dart','lib/src/painting/patterns.dart','lib/src/painting/decoration.dart','lib/src/painting/svg_path.dart','lib/src/painting/text.dart','lib/src/widgets/icon.dart','lib/src/foundation/icons.dart','lib/src/shell/dialog.dart','lib/src/inputs/field.dart'],
  tests=['test/foundation/painting_test.dart','test/foundation/widgets_test.dart','test/shell/dialog_test.dart','test/inputs/text_field_test.dart'],
  note=INT+'It was in the middle of the first problem: lib/src/painting/shapes.dart and test/foundation/painting_test.dart hold its unfinished change (whole-pixel fitting of a dashed side of fractional length). Read the diff against snapshots 09 and 08 of your snapshot directory, then finish or redo it. Number your snapshots from 11. Never regenerate goldens; for the problem about which sheets change, just list in your notes every sheet golden test that fails after your work and why. The last problem in the list comes from the review of the grid group and is about painters: it belongs to you.',
  findings=[], problems=pp+[gp[0]])
G['grid']=dict(
  files=['lib/src/layout/grid.dart','example/lib/sheets/layout_sheet.dart'],
  tests=['test/layout/grid_test.dart'],
  note='In example/lib/sheets/layout_sheet.dart only the column ruler of the grid specimen is yours (it must line up with the snapped tracks again); never regenerate goldens. The part of the pixel-snapping finding that is about painters and text-sized boxes belongs to another group. Number your snapshots from 03.',
  findings=[], problems=gp[1:])
G['hud-readouts']=dict(
  files=['lib/src/hud/meter.dart','lib/src/hud/readout.dart','lib/src/hud/timer.dart','lib/src/hud/alert_bar.dart'],
  tests=['test/hud/meter_test.dart','test/hud/readout_test.dart','test/hud/timer_test.dart','test/hud/alert_bar_test.dart'],
  note='Number new snapshots from 09.'+APP,
  findings=[], allFindings=[F(i) for i in (35,36,37,38,39,40,41,42)], report={'report':R('wf_2f3e4e0d-25b','fix:hud-readouts'),'snapshots':snaps('hud-readouts')})
G['theme-app']=dict(
  files=['lib/src/foundation/theme.dart','lib/src/app/app.dart'],
  tests=['test/foundation/theme_test.dart','test/foundation/app_test.dart'],
  note='lib/src/app/app.dart mounts KkMessenger from lib/src/shell/snackbar.dart around the app content; keep that. The example app (example/lib, tests in test/example) switches the condition and the motion of a running app. Number new snapshots from 05.',
  findings=[], allFindings=[F(0),F(1),F(2),F(7),F(22)], report={'report':R('wf_2f3e4e0d-25b','fix:theme-app'),'snapshots':snaps('theme-app')})
G['screen-split']=dict(
  files=['lib/src/layout/screen.dart','lib/src/layout/split.dart'],
  tests=['test/layout/screen_test.dart','test/layout/split_test.dart'],
  note='KkScreen is the skeleton of the example app (example/lib, tests in test/example) and of test/shell/shell_app_test.dart. Use testChecked (test/layout/layout_util.dart) for layout tests. Number new snapshots from 11.',
  findings=[], allFindings=[F(i) for i in (112,113,114,121,122,111,115,116,117,118)], report={'report':R('wf_63bc395d-c65','fix:screen-split'),'snapshots':snaps('screen-split')})
G['pressable']=dict(
  files=['lib/src/widgets/pressable.dart'],
  tests=[], newTests='test/foundation/pressable_test.dart',
  note=INT+'Six fixes are snapshotted (folders 01 to 06 of your snapshot directory: read each message.txt to see which findings are done) and the files are exactly as snapshot 06 left them. Go through all six findings again, record the ones already fixed, and fix what is left; number your snapshots from 07. KkPressable and KkFocusRing are the base of every interactive widget in the package and of the example app (tests in test/example): the whole suite must still pass. pressable.dart belongs to the widgets layer: it must not import lib/src/inputs or any later layer. Many existing tests set FocusHighlightStrategy.alwaysTraditional to see hover looks.',
  findings=[F(123),F(124),F(125),F(126),F(127),F(134)])
G['text-frame']=dict(
  files=['lib/src/widgets/text.dart','lib/src/widgets/frame.dart'],
  tests=[], newTests='test/foundation/text_frame_test.dart',
  note='Put your new tests in the new file, and touch test/foundation/widgets_test.dart only where an existing test pinned a defect (say so in your notes). KkTate is the vertical text of panel spines and headings; for the vertical glyph forms check what the bundled fonts offer (fonts/ZenOldMincho-Black.ttf and fonts/NotoSerifKR-Black.ttf: the OpenType `vert` feature through FontFeature, or the presentation forms block) before choosing an approach, and test with real glyph pixels, not only with widths. KkWidgetHead, KkWidgetFoot and KkWidgetKey frame every chart, the status timeline and the node graph: a change of spacing changes many sheet goldens on purpose; list them.',
  findings=[F(128),F(129),F(133),F(130),F(131),F(132)])
G['effects']=dict(
  files=['lib/src/motion/effects.dart'],
  tests=['test/foundation/motion_widgets_test.dart'], newTests='test/foundation/effects_test.dart',
  note='lib/src/motion/loops.dart was changed by other agents (KkLoop starts on the shared clock now, and a loop paused by TickerMode was repaired); read it as it is. KkHazard, KkMarquee, KkCrt and KkGlitch are used by lib/src/app/app.dart, lib/src/hud, lib/src/shell and the example app.',
  findings=[F(6),F(16),F(17),F(18),F(19),F(20)])
G['tokens-colors']=dict(
  files=['lib/src/foundation/tokens.dart','lib/src/foundation/colors.dart','lib/src/charts/trace.dart'],
  tests=['test/foundation/tokens_test.dart','test/charts/scopes_test.dart'],
  note='Findings 5 and 34 describe the same thing. For the glow, compare with how every user of KkGlow turns blur into a sigma (grep kkPaintGlow and maskFilter in lib/) before choosing where to put the factor; kkPaintGlow itself was changed by another agent (it blurs the outline itself now, not the outline plus its ring).',
  findings=[F(3),F(4),F(5),F(34)])
G['box-layers']=dict(
  files=['lib/src/layout/box.dart','lib/src/layout/layers.dart'],
  tests=['test/layout/box_test.dart','test/layout/layers_test.dart'],
  note='KkBox and KkLayers are used by almost every widget. Before changing where KkBox clips, grep lib/ for every KkBox with a clip and a border (edges or decoration) and decide per the CSS (overflow clips at the padding box) whether any of them relies on the present behaviour; list in your notes the sheet goldens you expect to change. For KkLayers.expand, keep the behaviour for the bounded and the fully unbounded case exactly as it is.',
  findings=[F(104),F(105)])
G['flex']=dict(
  files=['lib/src/layout/flex.dart'],
  tests=['test/layout/flex_test.dart','test/layout/measure_test.dart'],
  note='RenderKkFlex lays out every row and column of the package: run the whole suite after any change, and use testChecked for new tests.',
  diffNote='These five fixes were released before the copy in /home/user/keikai-before was taken, so there is nothing to diff. Read them with `git -C /home/user/keikai-flutter log --oneline 27b1ef9..d511d51 -- lib/src/layout/flex.dart` and `git -C /home/user/keikai-flutter show <commit>` (read-only git commands are fine), and read lib/src/layout/flex.dart as it is now.',
  findings=[], allFindings=[F(i) for i in (106,107,108,109,110)],
  report={'fixesMade':[
     {'commit':'9339df2','whatWasDone':"Measure the dry baseline of a flex child at the constraints it is laid out with (finding 106)."},
     {'commit':'bcfb0dd','whatWasDone':'Make KkGap measure again when its flex turns or it moves to another parent (finding 107): the direction setter marks gap children dirty; RenderKkGap.attach marks itself dirty.'},
     {'commit':'ddb1a3d','whatWasDone':"Share the free space of a flex again after the stretch pass (finding 108): pass 4 redistributes the flexible children when a child that keeps its own main size changed it in the stretch pass (laid out without a forced cross size so the line can follow), pass 5 re-stretches the stretch children at the main size they have."},
     {'commit':'4fdb10a','whatWasDone':'Count the baseline extent in the intrinsic height of a row (finding 109).'},
     {'commit':'d511d51','whatWasDone':'Clip a flex child that its baseline moves out of the row (finding 110): overflow across the line is decided from where each child is placed.'}],
     'notes':'All tests of the package passed after these changes, and no sheet golden changed.'})
lanes=[sys.argv[2].split(','), sys.argv[3].split(',')] if len(sys.argv)>3 else [['motion-core','scroll','hud-readouts','theme-app','effects','tokens-colors'],['pressable','painting','grid','screen-split','text-frame','box-layers','flex']]
args={'root':'/home/user/keikai','repo':'/home/user/keikai-before','stage':S+'/fixes',
      'tokens':P+'/tokens.json','css':P+'/components/bundle.css','readme':P+'/README.md',
      'lanes':[[dict(key=k,**G[k]) for k in lane] for lane in lanes]}
out=S+'/wf/'+(sys.argv[1] if len(sys.argv)>1 else 'keikai-fix-5')+'.js'
open(out,'w').write(tpl.replace('__ARGS__', json.dumps(args, ensure_ascii=False, indent=1)))
print('groups',sum(len(l) for l in lanes), 'bytes', os.path.getsize(out))
