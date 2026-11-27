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

const a = {
 "root": "/home/user/keikai",
 "tokens": "/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project/tokens.json",
 "css": "/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project/components/bundle.css",
 "readme": "/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project/README.md",
 "importNote": "keikai.dart exports every finished family: foundation, layout, controls, inputs, shell, hud, charts and diagram. Other agents may be fixing defects in the files you review, or in files they depend on: judge what is on disk when you read it.",
 "targets": [
  {
   "key": "tb-core",
   "files": [
    "lib/src/table/column.dart",
    "lib/src/table/widths.dart",
    "lib/src/table/layout.dart",
    "lib/src/table/frame.dart",
    "lib/src/table/rows.dart"
   ],
   "focus": "The column model (KkTableColumn, KkTableWidth fixed / content / flex with min and max, KkTableSort, kkCompareTableValues with nulls, NaN, mixed types and stable order) and the ONE width resolution (kkResolveTableWidths, KkTableGeometry) shared by header, rows, summary and detail: fixed, flex and content columns together, available width smaller than the minimums (horizontal scroll), zero columns, one column, snapping to whole pixels, the running maximum of content widths. The render objects (RenderKkTableCells, RenderKkTableFrame, RenderKkTableGrid, the rows sliver): layout protocol, intrinsics, dry layout and dry baseline agreeing with performLayout (testChecked in test/layout/layout_util.dart), hit testing, paint of row grounds (hover, selected, row fill, critical) and separators, lazy building of rows (how many are built for 10 000 rows), scroll extent estimates with detail rows of unknown height, the free-height case, sticky header and summary, horizontal scrolling of header, body and summary together. Compare every size with .kk-table (bundle.css lines 2106-2326): 32 / 24px rows, 30 / 42 / 24 / 36px header, 8px cell padding, checkbox 36, number 40 and expander 28 columns."
  },
  {
   "key": "tb-interaction",
   "files": [
    "lib/src/table/data_table.dart",
    "lib/src/table/header.dart",
    "lib/src/table/edit.dart"
   ],
   "focus": "KkDataTable state: controlled versus own sort, filter, selection, expanded, page and page size (a non-null value is controlled) and what happens when the owner changes them or the rows under them; the sort cycle and its stability; filtering (filterPredicate, searchable columns, the no-match state); selection (single, multi, the tri-state header checkbox on the page, Shift range, selection that names rows that are gone, selection across pages); paging (page beyond the last page after a filter, page size change, totalRows for server paging and which callbacks fire then); detail rows (canExpand, controlled set); change tracking (a changed cell flashes once for 0.9s in 6 steps, a row whose level changed strobes three times in 1.2s; never on first build, sort, filter or paging; values compared by column value; flashChanges false); the keyboard model (rows as one tab stop; arrows, Home / End, Page keys, Enter, Space, Shift+Space, Ctrl+A, Left / Right for the detail) and scrolling the focused row into view; inline editing (opening, text selection, Enter, Escape, blur with and without commitOnBlur, validator and its error look, formatters, editing a row that scrolls away or is removed, initiallyEditing); header sort buttons and their semantics; lifecycle (controllers, focus nodes, tickers, timers, listeners disposed; no setState after dispose); cost of a rebuild with many rows."
  },
  {
   "key": "tb-chrome",
   "files": [
    "lib/src/table/band.dart",
    "lib/src/table/cells.dart",
    "lib/src/table/pagination.dart"
   ],
   "focus": "The band against lines 2114-2186: 40px, the code block and its slant, title (cjk 17px, en 11px), meta, the filter field (the .kk-table__filter look, clear button that keeps its slot, focus), actions, how the row gives way when it is too narrow; the selecting band (solid signal, the count block, the label, bulk buttons, the close button, the .25s wipe, same height and no shift), danger bulk actions that arm on the first press (blink at 1s, timeout, Escape, focus loss, a press elsewhere, selection change) and fire on the second, the live announcement of the count. The cell kinds against lines 2245-2265: level word with glyph, code, value with level and glyph slot, the 72 x 6 bar, the segmented meter (5 x 10 segments, 1px gap, percent), the 80 x 18 sparkline, summary cells; their looks inside a critical row (ink on alert-deep) through KkTableRowScope, dense rows, NaN and out-of-range values. KkPagination and the footer against lines 2313-2321: 36px, the range text, the per-page select, first / previous / next / last buttons and their enabled states at the ends, page count 0 and 1, keyboard, semantics."
  }
 ]
}
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
