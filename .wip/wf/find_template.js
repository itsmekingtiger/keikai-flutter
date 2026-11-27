export const meta = {
  name: 'keikai-find',
  description: 'Reviewers read keikai source files completely and prove defects with throwaway tests',
  whenToUse: 'Find real defects in a set of keikai source files; the findings feed the keikai-fix workflow',
  phases: [{ title: 'Find', detail: 'one reviewer per target reads the files and proves defects with throwaway tests' }],
}

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string', description: 'path relative to the package root' },
          line: { type: 'integer' },
          title: { type: 'string' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          category: { type: 'string', enum: ['logic', 'framework', 'fidelity', 'edge-case', 'accessibility'] },
          explanation: { type: 'string' },
          evidence: { type: 'string', description: 'failing test output or the exact lines and a concrete failing input' },
          suggestedFix: { type: 'string' },
        },
        required: ['file', 'title', 'severity', 'category', 'explanation', 'evidence', 'suggestedFix'],
      },
    },
  },
  required: ['findings'],
}

const a = __ARGS__
const root = a.root

const context = `Project: ${root} is a Flutter package named \`keikai\` (Flutter 3.50.1, Dart 3.14; run \`export PATH=/opt/sdk/flutter/bin:$PATH\` and \`cd ${root}\` first). It is "KEIKAI 警戒", a dark HQ/HUD design language implemented from the widgets and rendering layers up: it never imports package:flutter/material.dart or cupertino.dart. Motion is stepped (CSS steps()) with no easing; with motion off (KeikaiTheme.motionOf(context) false) every widget must show its final state. Colours come from the theme (KeikaiTheme.of(context).colors), never from literals. The design source of truth is a web design system whose files are on disk: tokens ${a.tokens}, component CSS ${a.css}, principles ${a.readme}. CSS inheritance matters when you compare sizes: body line-height is 1.55, an element with a \`font:\` shorthand sets its own.

Several other agents are editing this directory right now (other directories under lib/src, tests, example). It is a plain working directory, not a git checkout. These rules are absolute:
- Do NOT create, edit, move or delete anything except inside your own scratch directory (given below; it is git-ignored). Delete that directory before you finish.
- Do NOT run project-wide commands: no \`flutter analyze\`, no \`flutter test\` without a path, no \`flutter pub get\`, \`flutter clean\`, \`dart format\` or \`dart fix\`. You may run \`dart analyze <specific files>\` and \`flutter test <your scratch directory>\` (give test runs a generous timeout: they queue for one of three slots).
- Throwaway tests may import package:flutter_test/flutter_test.dart, Flutter framework libraries, '../../support/harness.dart' (helpers loadKkFonts, pumpKk, kkHarness; motion is off in the harness unless \`motion: true\`; with motion on, pump explicit durations and never call pumpAndSettle) and package:keikai/keikai.dart. ${a.importNote}
- Files may change under you (another agent may be fixing bugs in them). Always judge the content that is on disk now.`

function findPrompt(t) {
  const scratch = `${root}/test/_review/${t.key}/`
  return `${context}

Your scratch directory: ${scratch}

TASK: review these files completely, reading every line:
${t.files.map((f) => `- ${root}/${f}`).join('\n')}

What to look at hardest: ${t.focus}

Report REAL defects only:
1. Logic errors: wrong maths, off-by-one, wrong conditions, inverted or unreachable branches, state that is never reset.
2. Flutter framework misuse that throws, asserts or leaks at runtime: render-object protocol (reading size before layout, parentUsesSize, constraints handed to children, intrinsics or dry layout that disagree with performLayout, markNeedsLayout versus markNeedsPaint, hit testing through offsets and transforms, LayerHandle use, compositing bits), State lifecycle (listeners not removed, controllers / tickers / timers / text painters not disposed, setState after dispose, work in the wrong lifecycle method), InheritedWidget dependency mistakes, layout overflow or unbounded-constraint errors in ordinary parents (inside a scroll view, a row, a tight grid cell, a 0x0 box).
3. Deviations from the design system: any size, padding, gap, font, colour token, state or animation timing that disagrees with the CSS lines named above or with tokens.json.
4. Edge cases that crash or misrender: empty lists, null or empty strings, zero / negative / NaN / huge values, very long text, both themes (standby and alert).
5. Accessibility and keyboard gaps in interactive widgets (missing semantics, focus that cannot be reached or seen, callbacks unreachable by keyboard).

Prove what you can: write a focused throwaway test in your scratch directory that fails because of the defect, run it, and quote the relevant output as evidence. A finding you could not run must cite the exact lines and a concrete input that makes the code misbehave.

Do NOT report style or naming opinions, missing features, documentation wording, hypothetical concerns you could not ground in the code, or anything that would merely be cleaner.

Severity: high = wrong output or an exception in normal use; medium = wrong in a plausible edge case, or a leak; low = minor inaccuracy.

Before finishing, delete ${scratch}. Return every finding through the structured output; an empty list is a valid answer.`
}


const results = await pipeline(a.targets, (t) =>
  agent(findPrompt(t), { label: `find:${t.key}`, phase: 'Find', schema: FINDINGS }).then((r) => {
    const findings = (r && r.findings) || []
    log(`${t.key}: ${r ? findings.length + ' finding(s)' : 'the reviewer returned nothing'}`)
    return { target: t.key, files: t.files, lost: !r, findings }
  })
)

return results.filter(Boolean)
