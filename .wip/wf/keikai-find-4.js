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
   "key": "ch-core",
   "files": [
    "lib/src/charts/plot.dart",
    "lib/src/charts/scale.dart",
    "lib/src/charts/series.dart",
    "lib/src/charts/format.dart"
   ],
   "focus": "KkLinearScale: nice ticks for any range (zero span, negative, tiny, huge, inverted, NaN or infinite bounds), the tick count, the mapping in both directions and its clamping. The format helpers (kkFixed and the others): rounding, negative zero, digit grouping, units, NaN and infinity, very large numbers. KkSeries / KkSlice / KkThreshold as value objects (equality and hashCode used by shouldRepaint). KkChartFrame against the widget frame rules (.kk-wgt-head / .kk-wgt-foot, lines 1629-1652) and .kk-chart (lines 2025-2060): head, foot, key. The plot sizing render objects (_RenderPlotSize: natural size, aspect ratio, inset, max content width, extra height; RenderKkNaturalHeight): intrinsics, dry layout and baseline agreeing with performLayout in bounded, unbounded and zero-size parents. KkCanvas (when it repaints). KkPlotPointer (hover and tap hit maths, nearest index, leaving the plot, touch versus mouse). The series colour order (signal, ink, ink-dim; the fourth and later grouped as OTHER)."
  },
  {
   "key": "ch-xy",
   "files": [
    "lib/src/charts/time_series.dart",
    "lib/src/charts/bar_chart.dart",
    "lib/src/charts/sparkline.dart",
    "lib/src/charts/stat.dart"
   ],
   "focus": "KkTimeSeries against .kk-chart (lines 2025-2060): axes, grid lines, line / area / step drawing, thresholds (dashed line, label, level colour), gaps for null or NaN values, a single point, a constant series, uneven x spacing, the y range override, the hover crosshair and readout, the entrance wipe and its timing, updates when the data changes in place, many points. KkBarChart: grouped and stacked bars, negative values and the baseline, bar width and gap rules, labels, hover, the entrance, zero and one category. KkSparkline against the sparkline rules in lines 1977-2024: default size, the last point marker, min / max, level colour, fill, fewer than two points. KkStat / KkDelta against the stat rules in lines 1977-2024: the value typography, unit, the delta arrow and sign, the level by direction (and the inverse option), the sparkline slot, the scramble on change, sizes in a grid cell. Reported by an app author, to be verified: KkStat / KkReadout scramble all digits on every change, so a value that changes every second shows noise digits for 0.46s of each second."
  },
  {
   "key": "ch-radial",
   "files": [
    "lib/src/charts/gauge.dart",
    "lib/src/charts/donut.dart",
    "lib/src/charts/radar.dart"
   ],
   "focus": "KkGauge against .kk-gauge (lines 2074-2090): the arc geometry (start and end angles, stroke widths, segments), threshold zones, the value arc or needle for min, max, out of range and NaN, min == max, the centred value and its baseline, the stepped transition. KkDonut against .kk-donut (lines 2091-2105): slice angles (sum zero, negative values, tiny slices, gaps), the colour order and OTHER grouping beyond three, legend percentages (do they add up to 100?), hover hit testing by angle and radius, the centre label. KkRadar against .kk-radar (lines 1715-1735): rings and spokes, the sweep rotation and its timing, contacts with level glyphs and blinking, the polar to cartesian mapping (angle origin and direction), range clamping, labels, tap and hover on contacts, size in tight and unbounded parents."
  },
  {
   "key": "ch-bands",
   "files": [
    "lib/src/charts/bar_list.dart",
    "lib/src/charts/category_bar.dart",
    "lib/src/charts/heatmap.dart",
    "lib/src/charts/status_timeline.dart",
    "lib/src/charts/waterfall.dart",
    "lib/src/charts/trace.dart"
   ],
   "focus": "KkBarList against the bar list rules (lines 2061-2073): row layout, bar width by value over max (max zero), ranks, value formatting, hover. KkCategoryBar against lines 2345-2370: segment widths with the minimum width, gaps, the legend, percentages. KkHeatmap against .kk-heat (lines 2328-2344): the colour ramp (the color-mix percentages), cell size and gap, axis labels, the value to bucket mapping for min == max, NaN and out-of-range values, hover. KkStatusTimeline against lines 2345-2370: span widths (weights, 2px gap, 2px minimum), the percent column, axis labels, level colours, hover and tap hit testing, keyboard focus. KkWaterfall against .kk-wf (lines 1802-1819): how the spectrogram image is built and cached (ui.Image lifecycle and disposal, repaint when rows change in place), scroll direction, the palette ramp, the crosshair, ragged and empty rows. KkTrace against .kk-trace (lines 471-511): polyline scaling, the plot pattern, the glow, the level colour, live updates when the sample list changes, empty and single samples, NaN samples."
  },
  {
   "key": "dg-model",
   "files": [
    "lib/src/diagram/model.dart",
    "lib/src/diagram/parser.dart",
    "lib/src/diagram/metrics.dart",
    "lib/src/diagram/geometry.dart"
   ],
   "focus": "KkDiagram validation (duplicate and empty ids, edges to unknown nodes, self loops, parallel edges), immutability and equality. The text language: every node form, every wire operator, labels, class suffixes, quoted fields, positions, comments, the direction header, error line numbers, CRLF, tabs, non-ASCII text; toSource round trips for everything it claims to keep, and what tryParse returns for bad input. KkNodeMetrics (sizes per kind, the sizeOf hook, text measurement estimates against real text widths: are labels clipped or do they overlap?). The outline functions (kkNodeOutline, kkNodePath, kkDistanceToOutline, kkOutlineExit) for each node kind. Snapping (kkSnap, kkSnapUp). KkDiagramGeometry (labelAnchor, coveredTexts, wireCrosses, nodeAt hit testing at the edges of a symbol)."
  },
  {
   "key": "dg-layouts",
   "files": [
    "lib/src/diagram/layout.dart",
    "lib/src/diagram/layered_layout.dart",
    "lib/src/diagram/tree_layout.dart",
    "lib/src/diagram/radial_layout.dart",
    "lib/src/diagram/force_layout.dart",
    "lib/src/diagram/manual_layout.dart"
   ],
   "focus": "Each layout on: an empty diagram, one node, disconnected components, cycles (how they are broken and drawn), self loops, parallel edges, long edges, every direction, very wide and very deep graphs. Determinism (same input, same output; the force seed). No overlapping nodes and the minimum gaps kept. Nodes on the 8px grid. Layered: layer assignment, crossing minimisation (does it terminate, is it stable), coordinate assignment. Tree: extra wires that are not tree edges, several roots. Radial: many children on a ring, the root choice. Force: convergence, coincident nodes, NaN safety, the aspect option. Manual: normalised versus absolute positions, nodes without a position. Cost for 200 nodes."
  },
  {
   "key": "dg-router",
   "files": [
    "lib/src/diagram/router.dart"
   ],
   "focus": "The orthogonal, octilinear and straight routers: every leg horizontal, vertical or at 45 degrees where promised, routes that start and end on the node outlines, the cut corners on short legs, obstacle avoidance and the path search (termination, its step limit, the heuristic, clearance), label placement on a wire, reversed edges, the maxCut hint, wires that share a lane, self loops, coincident endpoints, touching or overlapping nodes, numeric robustness (zero-length segments, repeated points, NaN)."
  },
  {
   "key": "dg-view",
   "files": [
    "lib/src/diagram/painter.dart",
    "lib/src/diagram/view.dart",
    "lib/src/diagram/node_graph.dart",
    "lib/src/diagram/sequence_diagram.dart"
   ],
   "focus": "KkDiagramPainter against the .kk-graph paint rules (lines 1669-1714): node strokes and fills per level, the symbols, the flag glyph, wire styles (plain, active, flow and its dash speed, reverse, offline), arrow heads, the critical halo, label backing, text painting (TextPainter caching and disposal), shouldRepaint. KkDiagramView / RenderKkDiagramViewport: fit modes and alignment, pan and zoom maths (zoom about the pointer, limits, the controller), gestures (drag, wheel, pinch, keys), hit testing under the transform, selection / hover / focus, keyboard movement between nodes, the info plate placement, the entrance and motion off, when layout and routing are recomputed (never in paint), intrinsics and dry layout, semantics. KkNodeGraph (head, legend, footer, expand, height, minWidth). KkSequenceDiagram: participant columns, lifelines, activations, each message kind, dividers, numbering, the time column, kkSequenceNaturalWidth and narrow parents, the entrance, its render box (dry layout, intrinsics, baseline)."
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
