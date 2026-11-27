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
   "key": "in-text",
   "files": [
    "lib/src/inputs/field.dart",
    "lib/src/inputs/text_field.dart",
    "lib/src/inputs/text_input.dart"
   ],
   "focus": "KkTextField against .kk-field (bundle.css lines 999-1065): the label row (cjk in the display face, en 11px label 600 .14em, the required mark), the 36px box with a 1px ink-faint border, hover, focus (signal edge, the 8px corner brackets and the inner ring without moving the content), error (alert border, foot message with the status glyph), disabled (dashed, faint), icon / prefix / suffix / trailing, the mono option, multiline (72px minimum, growth, maxLines), the counter and its formatting, support text. KkTextInput editing: controller and focus node ownership and disposal (own versus given, swapped in didUpdateWidget), selection controls and the touch handles, the context menu (cut / copy / paste / select all, enabled states, clipboard access), obscureText, maxLength enforcement, inputFormatters, onChanged / onSubmitted / onEditingComplete / onTapOutside call patterns, readOnly, autofocus, IME composing, keyboard shortcuts, scrolling of long text, the cursor, semantics (text field role, label, error, obscured, enabled). KkFieldWidth / RenderKkFieldWidth (min 200, fallback 280 in unbounded parents, intrinsics, dry layout and baseline). KkFieldBox, KkFieldLabel, KkFieldFoot in a 0x0 box, in a row, in a scroll view, with very long text."
  },
  {
   "key": "in-popup",
   "files": [
    "lib/src/inputs/popup.dart",
    "lib/src/inputs/menu.dart",
    "lib/src/inputs/modality.dart",
    "lib/src/inputs/tooltip.dart"
   ],
   "focus": "KkPopup / RenderKkPopupLayout: the anchoring maths for every side and align, flipping when there is no room, the 4px clamp inside the screen, matchWidth / minAnchorWidth / minWidth, whole-pixel snapping, following the anchor when it scrolls, resizes or moves, the overlay entry lifecycle (removed on dispose, on route pop, when the anchor is unmounted while open), tap-outside closing and groupId, focus handling and restore, a popup opened from build. KkMenu against .kk-menu (lines 1113-1159): min width 232, item height and padding, the icon slot, shortcut hint, check mark, danger rows (rest and highlighted), separators and labels, hover and keyboard highlight, the 2px focus bar; keyboard (arrows, Home / End, Enter / Space, Escape, type-ahead), disabled items skipped, the .25s steps(5) wipe, maxHeight scrolling and keeping the highlighted row in view, semantics (menu and item roles, checked, enabled). KkMenuAnchor (controller ownership, onOpen / onClose pairing, restoreFocus), showKkMenu (route result, dismissal, position and anchorRect). KkInputModality (global listeners: registered once, removed, isolated between tests). KkTooltip against .kk-tip (lines 1364-1408): the plain and the rich look, the stem, the four sides, the 400ms wait and 1500ms show timers and their cancellation, hover versus keyboard focus versus focus after a click, dismissal on leave, press, wheel, scroll and Escape, the 160ms grace of the rich card, controlled `open`, timers and overlay entries after dispose, semantics. Reported by an app author, to be verified: a popup stays on screen, clamped to the window edge, after its anchor has scrolled out of its scroll view; KkMenuAnchor(initiallyOpen: true) opens in initState, takes the keyboard focus and scrolls its ancestors to itself."
  },
  {
   "key": "in-select",
   "files": [
    "lib/src/inputs/select.dart",
    "lib/src/inputs/search.dart"
   ],
   "focus": "KkSelect against the select rules in lines 999-1065: sizes md 36 / sm 32 / xs 24, the chevron, placeholder, how the chosen option is shown (cjk, label, code), the list as wide as the field, option highlight and check, disabled options, error / disabled / required; keyboard (open with Enter / Space / ArrowDown, type-ahead while closed and while open, Escape, Home / End), a value that is not among the options, empty options, value or options changed while the list is open, controller and focus node ownership, generic value equality including null, semantics (button with its value, expanded state). KkSearch against .kk-search (lines 1066-1112): the prompt, the key hint, the clear button that keeps its slot, the results list (code / title / meta columns, the match highlight, disabled results), the NO MATCH row, keyboard (arrows through results with wrap, Enter selects, Escape closes and then clears), the controlled `open`, when onQuery is called, controller ownership, closing on focus loss, results replaced while open (highlight index out of range), maxResultsHeight scrolling, clearOnSelect, semantics."
  },
  {
   "key": "in-datetime",
   "files": [
    "lib/src/inputs/date_picker.dart",
    "lib/src/inputs/time_picker.dart",
    "lib/src/inputs/time_range.dart"
   ],
   "focus": "KkDatePicker against .kk-date (lines 1570-1602): the 7 column grid and cell sizes, the week number column and kkIsoWeek / kkIsoWeekYear at every year boundary (for example 2020-12-31, 2021-01-03, 2026-12-31, 2027-01-01 to 01-03, leap years), Monday first, month and year navigation across year ends, firstDate / lastDate / selectableDayPredicate (the disabled look and what the keyboard does at a barred day), today, the selected day, days of the neighbouring months, six rows always, keyboard (arrows, PageUp / PageDown, Home / End, Enter / Space), controller ownership, date arithmetic that must not depend on the local time zone or daylight saving, value outside the range, semantics. KkTimePicker against .kk-time (lines 1603-1668): segment sizes and looks, 24h wrap without carry, the steps, typing digits (two-digit entry, auto-advance, invalid digits), wheel, drag, arrow keys, seconds, disabled, focus looks, semantics (value, increase / decrease). KkTime (comparison, fromDuration with negative or 24h-and-over input, format, copyWith). KkTimeRange against the time range rules in lines 2371-2390: the range text, the live toggle and its 1s blink, the presets select, the refresh button, disabled, overflow in narrow parents."
  },
  {
   "key": "sh-bars",
   "files": [
    "lib/src/shell/command_bar.dart",
    "lib/src/shell/toolbar.dart",
    "lib/src/shell/breadcrumbs.dart",
    "lib/src/shell/tabs.dart",
    "lib/src/shell/shell_paint.dart"
   ],
   "focus": "KkCommandBar against .kk-cmdbar (lines 125-189, including the container rule at line 186 for 600px and narrower): 48px height, the id block and its slant, the condition block in standby and alert (fill, running hazard), cells (label over mono value, level colours), what is hidden when compact, followCondition, overflow with many cells or long names, leading / trailing, semantics. KkToolbar against .kk-toolbar (lines 1271-1288): 32px, groups, hints with key caps, the status text, overflow. KkBreadcrumbs against the breadcrumb rules in lines 2371-2390: separators, the current crumb, the hover underline, crumbs without onPressed, overflow, semantics. KkTabs against .kk-tabs (lines 1160-1188): primary 40px and secondary 32px, the selected indicator, code / cjk / en / icon, disabled tabs, hover and focus looks, the keyboard model (one tab stop; arrows, Home and End move and select, skipping disabled tabs), what happens when the tabs do not fit, index out of range, the list of tabs changing length. KkTabView (the wipe on change, maintainState keeping or dropping State, index out of range)."
  },
  {
   "key": "sh-nav",
   "files": [
    "lib/src/shell/nav_rail.dart",
    "lib/src/shell/nav_drawer.dart",
    "lib/src/shell/list.dart"
   ],
   "focus": "KkNavRail against .kk-rail (lines 1189-1228) and the screen rule that turns it into a 64px bottom bar below 600px (lines 1846-1856): 72px wide, item sizes, icon and label, the current indicator, badges, the header (hidden as a bar), trailing, hover / focus / pressed looks, every destination disabled without onChanged, keyboard, semantics (selected), overflow with many items in both arrangements. KkNavDrawer against .kk-drawer (lines 1229-1270): 256px, the head, sections with their labels and codes, item height, the current item, meta text and level tags, the pinned foot, scrolling, disabled items, value equality for generic T. KkList / KkListRow against .kk-list (lines 1488-1523): 48px rows and 32px dense, separators, the leading icon or level glyph, the cjk / en / title / sub / meta / trailing layout and its truncation with long text, the current row, hover, pressed, disabled, keyboard activation, onLongPress, the builder variant (lazy building, itemCount 0), semantics."
  },
  {
   "key": "sh-overlays",
   "files": [
    "lib/src/shell/dialog.dart",
    "lib/src/shell/sheet.dart",
    "lib/src/shell/snackbar.dart"
   ],
   "focus": "KkDialog against .kk-dialog (lines 1409-1469): 520px wide and clamped to the screen, the head (code block, title, close), body padding, the actions row, the critical variant (alert frame, glow, hazard strip), the corner brackets, the 78% scrim, the wipe in and out, the body flicker; showKkDialog: focus trap and initial focus, Escape and barrier dismissal versus dismissible false, results, a tall body on a small screen (scrollable), nested dialogs, focus restore on close, semantics (dialog / alertDialog roles and label). showKkConfirm (danger look, default focus, result on dismissal). KkSheet against .kk-sheet (lines 1470-1487): side 400px and bottom up to 60% of the height, the grip, the stepped slide in and out (.42s in 7 steps), the 70% scrim, safe areas, the foot that wraps, dismissal, focus. KkSnackbar / KkMessenger against .kk-snack (lines 1327-1363): min height 40, max width 560, the code block and its slant by level, action, close, the stack position (left 24, bottom toolbar height + 16), maxVisible and which one is evicted, the duration timers (cancelled on close and dispose), KkSnackbarHandle.close and its closed future (completed exactly once in every path), clear, show after the messenger is disposed, messages during a route transition, the live region semantics. Also how lib/src/app/app.dart mounts KkMessenger. Reported by an app author, to be verified: the snackbar stack covers the nav rail's lowest button and, on a phone, the bottom navigation bar; its width limit (window width minus twice `left`) makes it impossible to put the stack on the right; the app-level stack lies above every route, dialogs and the full-screen alarm included."
  },
  {
   "key": "sh-carousel",
   "files": [
    "lib/src/shell/carousel.dart"
   ],
   "focus": "KkCarousel against .kk-carousel (lines 1524-1558): item 240 x 152, the gap, the head with the count and the previous / next buttons, captions. The snapping maths: rest positions, the end position, the target of a fling (nearest rest position to the natural stop, at least one card), a drag released without velocity, the count shown at the end. Controlled versus own index, when onChanged is called (no duplicates, no calls for programmatic moves that do not change the index), the 7-step programmatic move and motion off, keyboard (arrows, Home / End; tab stops when the cards are buttons; bringing the focused card fully into view), wheel and trackpad, items changed while scrolled (index out of range), zero items, one item, every card fitting (buttons off), unbounded width, the scroll controller lifecycle, semantics."
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
