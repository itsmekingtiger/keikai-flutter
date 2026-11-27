"""Review targets for the families that have not been reviewed yet."""
T = {}

def t(key, files, focus):
    T[key] = {'key': key, 'files': files, 'focus': ' '.join(focus.split())}

t('in-text', ['lib/src/inputs/field.dart', 'lib/src/inputs/text_field.dart', 'lib/src/inputs/text_input.dart'], '''
KkTextField against .kk-field (bundle.css lines 999-1065): the label row (cjk in the display face, en 11px label 600 .14em, the
required mark), the 36px box with a 1px ink-faint border, hover, focus (signal edge, the 8px corner brackets and the inner ring
without moving the content), error (alert border, foot message with the status glyph), disabled (dashed, faint), icon / prefix /
suffix / trailing, the mono option, multiline (72px minimum, growth, maxLines), the counter and its formatting, support text.
KkTextInput editing: controller and focus node ownership and disposal (own versus given, swapped in didUpdateWidget), selection
controls and the touch handles, the context menu (cut / copy / paste / select all, enabled states, clipboard access), obscureText,
maxLength enforcement, inputFormatters, onChanged / onSubmitted / onEditingComplete / onTapOutside call patterns, readOnly,
autofocus, IME composing, keyboard shortcuts, scrolling of long text, the cursor, semantics (text field role, label, error,
obscured, enabled). KkFieldWidth / RenderKkFieldWidth (min 200, fallback 280 in unbounded parents, intrinsics, dry layout and
baseline). KkFieldBox, KkFieldLabel, KkFieldFoot in a 0x0 box, in a row, in a scroll view, with very long text.''')

t('in-popup', ['lib/src/inputs/popup.dart', 'lib/src/inputs/menu.dart', 'lib/src/inputs/modality.dart', 'lib/src/inputs/tooltip.dart'], '''
KkPopup / RenderKkPopupLayout: the anchoring maths for every side and align, flipping when there is no room, the 4px clamp inside
the screen, matchWidth / minAnchorWidth / minWidth, whole-pixel snapping, following the anchor when it scrolls, resizes or moves,
the overlay entry lifecycle (removed on dispose, on route pop, when the anchor is unmounted while open), tap-outside closing and
groupId, focus handling and restore, a popup opened from build. KkMenu against .kk-menu (lines 1113-1159): min width 232, item
height and padding, the icon slot, shortcut hint, check mark, danger rows (rest and highlighted), separators and labels, hover and
keyboard highlight, the 2px focus bar; keyboard (arrows, Home / End, Enter / Space, Escape, type-ahead), disabled items skipped,
the .25s steps(5) wipe, maxHeight scrolling and keeping the highlighted row in view, semantics (menu and item roles, checked,
enabled). KkMenuAnchor (controller ownership, onOpen / onClose pairing, restoreFocus), showKkMenu (route result, dismissal, position
and anchorRect). KkInputModality (global listeners: registered once, removed, isolated between tests). KkTooltip against .kk-tip
(lines 1364-1408): the plain and the rich look, the stem, the four sides, the 400ms wait and 1500ms show timers and their
cancellation, hover versus keyboard focus versus focus after a click, dismissal on leave, press, wheel, scroll and Escape, the
160ms grace of the rich card, controlled `open`, timers and overlay entries after dispose, semantics.''')

t('in-select', ['lib/src/inputs/select.dart', 'lib/src/inputs/search.dart'], '''
KkSelect against the select rules in lines 999-1065: sizes md 36 / sm 32 / xs 24, the chevron, placeholder, how the chosen option
is shown (cjk, label, code), the list as wide as the field, option highlight and check, disabled options, error / disabled /
required; keyboard (open with Enter / Space / ArrowDown, type-ahead while closed and while open, Escape, Home / End), a value that
is not among the options, empty options, value or options changed while the list is open, controller and focus node ownership,
generic value equality including null, semantics (button with its value, expanded state). KkSearch against .kk-search (lines
1066-1112): the prompt, the key hint, the clear button that keeps its slot, the results list (code / title / meta columns, the
match highlight, disabled results), the NO MATCH row, keyboard (arrows through results with wrap, Enter selects, Escape closes
and then clears), the controlled `open`, when onQuery is called, controller ownership, closing on focus loss, results replaced
while open (highlight index out of range), maxResultsHeight scrolling, clearOnSelect, semantics.''')

t('in-datetime', ['lib/src/inputs/date_picker.dart', 'lib/src/inputs/time_picker.dart', 'lib/src/inputs/time_range.dart'], '''
KkDatePicker against .kk-date (lines 1570-1602): the 7 column grid and cell sizes, the week number column and kkIsoWeek /
kkIsoWeekYear at every year boundary (for example 2020-12-31, 2021-01-03, 2026-12-31, 2027-01-01 to 01-03, leap years), Monday
first, month and year navigation across year ends, firstDate / lastDate / selectableDayPredicate (the disabled look and what the
keyboard does at a barred day), today, the selected day, days of the neighbouring months, six rows always, keyboard (arrows,
PageUp / PageDown, Home / End, Enter / Space), controller ownership, date arithmetic that must not depend on the local time zone
or daylight saving, value outside the range, semantics. KkTimePicker against .kk-time (lines 1603-1668): segment sizes and looks,
24h wrap without carry, the steps, typing digits (two-digit entry, auto-advance, invalid digits), wheel, drag, arrow keys,
seconds, disabled, focus looks, semantics (value, increase / decrease). KkTime (comparison, fromDuration with negative or
24h-and-over input, format, copyWith). KkTimeRange against the time range rules in lines 2371-2390: the range text, the live
toggle and its 1s blink, the presets select, the refresh button, disabled, overflow in narrow parents.''')

t('sh-bars', ['lib/src/shell/command_bar.dart', 'lib/src/shell/toolbar.dart', 'lib/src/shell/breadcrumbs.dart', 'lib/src/shell/tabs.dart', 'lib/src/shell/shell_paint.dart'], '''
KkCommandBar against .kk-cmdbar (lines 125-189, including the container rule at line 186 for 600px and narrower): 48px height,
the id block and its slant, the condition block in standby and alert (fill, running hazard), cells (label over mono value, level
colours), what is hidden when compact, followCondition, overflow with many cells or long names, leading / trailing, semantics.
KkToolbar against .kk-toolbar (lines 1271-1288): 32px, groups, hints with key caps, the status text, overflow. KkBreadcrumbs
against the breadcrumb rules in lines 2371-2390: separators, the current crumb, the hover underline, crumbs without onPressed,
overflow, semantics. KkTabs against .kk-tabs (lines 1160-1188): primary 40px and secondary 32px, the selected indicator, code /
cjk / en / icon, disabled tabs, hover and focus looks, the keyboard model (one tab stop; arrows, Home and End move and select,
skipping disabled tabs), what happens when the tabs do not fit, index out of range, the list of tabs changing length. KkTabView
(the wipe on change, maintainState keeping or dropping State, index out of range).''')

t('sh-nav', ['lib/src/shell/nav_rail.dart', 'lib/src/shell/nav_drawer.dart', 'lib/src/shell/list.dart'], '''
KkNavRail against .kk-rail (lines 1189-1228) and the screen rule that turns it into a 64px bottom bar below 600px (lines
1846-1856): 72px wide, item sizes, icon and label, the current indicator, badges, the header (hidden as a bar), trailing, hover /
focus / pressed looks, every destination disabled without onChanged, keyboard, semantics (selected), overflow with many items in
both arrangements. KkNavDrawer against .kk-drawer (lines 1229-1270): 256px, the head, sections with their labels and codes, item
height, the current item, meta text and level tags, the pinned foot, scrolling, disabled items, value equality for generic T.
KkList / KkListRow against .kk-list (lines 1488-1523): 48px rows and 32px dense, separators, the leading icon or level glyph,
the cjk / en / title / sub / meta / trailing layout and its truncation with long text, the current row, hover, pressed, disabled,
keyboard activation, onLongPress, the builder variant (lazy building, itemCount 0), semantics.''')

t('sh-overlays', ['lib/src/shell/dialog.dart', 'lib/src/shell/sheet.dart', 'lib/src/shell/snackbar.dart'], '''
KkDialog against .kk-dialog (lines 1409-1469): 520px wide and clamped to the screen, the head (code block, title, close), body
padding, the actions row, the critical variant (alert frame, glow, hazard strip), the corner brackets, the 78% scrim, the wipe in
and out, the body flicker; showKkDialog: focus trap and initial focus, Escape and barrier dismissal versus dismissible false,
results, a tall body on a small screen (scrollable), nested dialogs, focus restore on close, semantics (dialog / alertDialog
roles and label). showKkConfirm (danger look, default focus, result on dismissal). KkSheet against .kk-sheet (lines 1470-1487):
side 400px and bottom up to 60% of the height, the grip, the stepped slide in and out (.42s in 7 steps), the 70% scrim, safe
areas, the foot that wraps, dismissal, focus. KkSnackbar / KkMessenger against .kk-snack (lines 1327-1363): min height 40, max
width 560, the code block and its slant by level, action, close, the stack position (left 24, bottom toolbar height + 16),
maxVisible and which one is evicted, the duration timers (cancelled on close and dispose), KkSnackbarHandle.close and its closed
future (completed exactly once in every path), clear, show after the messenger is disposed, messages during a route transition,
the live region semantics. Also how lib/src/app/app.dart mounts KkMessenger.''')

t('sh-carousel', ['lib/src/shell/carousel.dart'], '''
KkCarousel against .kk-carousel (lines 1524-1558): item 240 x 152, the gap, the head with the count and the previous / next
buttons, captions. The snapping maths: rest positions, the end position, the target of a fling (nearest rest position to the
natural stop, at least one card), a drag released without velocity, the count shown at the end. Controlled versus own index, when
onChanged is called (no duplicates, no calls for programmatic moves that do not change the index), the 7-step programmatic move
and motion off, keyboard (arrows, Home / End; tab stops when the cards are buttons; bringing the focused card fully into view),
wheel and trackpad, items changed while scrolled (index out of range), zero items, one item, every card fitting (buttons off),
unbounded width, the scroll controller lifecycle, semantics.''')

t('ch-core', ['lib/src/charts/plot.dart', 'lib/src/charts/scale.dart', 'lib/src/charts/series.dart', 'lib/src/charts/format.dart'], '''
KkLinearScale: nice ticks for any range (zero span, negative, tiny, huge, inverted, NaN or infinite bounds), the tick count, the
mapping in both directions and its clamping. The format helpers (kkFixed and the others): rounding, negative zero, digit grouping,
units, NaN and infinity, very large numbers. KkSeries / KkSlice / KkThreshold as value objects (equality and hashCode used by
shouldRepaint). KkChartFrame against the widget frame rules (.kk-wgt-head / .kk-wgt-foot, lines 1629-1652) and .kk-chart (lines
2025-2060): head, foot, key. The plot sizing render objects (_RenderPlotSize: natural size, aspect ratio, inset, max content
width, extra height; RenderKkNaturalHeight): intrinsics, dry layout and baseline agreeing with performLayout in bounded,
unbounded and zero-size parents. KkCanvas (when it repaints). KkPlotPointer (hover and tap hit maths, nearest index, leaving the
plot, touch versus mouse). The series colour order (signal, ink, ink-dim; the fourth and later grouped as OTHER).''')

t('ch-xy', ['lib/src/charts/time_series.dart', 'lib/src/charts/bar_chart.dart', 'lib/src/charts/sparkline.dart', 'lib/src/charts/stat.dart'], '''
KkTimeSeries against .kk-chart (lines 2025-2060): axes, grid lines, line / area / step drawing, thresholds (dashed line, label,
level colour), gaps for null or NaN values, a single point, a constant series, uneven x spacing, the y range override, the hover
crosshair and readout, the entrance wipe and its timing, updates when the data changes in place, many points. KkBarChart: grouped
and stacked bars, negative values and the baseline, bar width and gap rules, labels, hover, the entrance, zero and one category.
KkSparkline against the sparkline rules in lines 1977-2024: default size, the last point marker, min / max, level colour, fill,
fewer than two points. KkStat / KkDelta against the stat rules in lines 1977-2024: the value typography, unit, the delta arrow
and sign, the level by direction (and the inverse option), the sparkline slot, the scramble on change, sizes in a grid cell.''')

t('ch-radial', ['lib/src/charts/gauge.dart', 'lib/src/charts/donut.dart', 'lib/src/charts/radar.dart'], '''
KkGauge against .kk-gauge (lines 2074-2090): the arc geometry (start and end angles, stroke widths, segments), threshold zones,
the value arc or needle for min, max, out of range and NaN, min == max, the centred value and its baseline, the stepped
transition. KkDonut against .kk-donut (lines 2091-2105): slice angles (sum zero, negative values, tiny slices, gaps), the colour
order and OTHER grouping beyond three, legend percentages (do they add up to 100?), hover hit testing by angle and radius, the
centre label. KkRadar against .kk-radar (lines 1715-1735): rings and spokes, the sweep rotation and its timing, contacts with
level glyphs and blinking, the polar to cartesian mapping (angle origin and direction), range clamping, labels, tap and hover on
contacts, size in tight and unbounded parents.''')

t('ch-bands', ['lib/src/charts/bar_list.dart', 'lib/src/charts/category_bar.dart', 'lib/src/charts/heatmap.dart', 'lib/src/charts/status_timeline.dart', 'lib/src/charts/waterfall.dart', 'lib/src/charts/trace.dart'], '''
KkBarList against the bar list rules (lines 2061-2073): row layout, bar width by value over max (max zero), ranks, value
formatting, hover. KkCategoryBar against lines 2345-2370: segment widths with the minimum width, gaps, the legend, percentages.
KkHeatmap against .kk-heat (lines 2328-2344): the colour ramp (the color-mix percentages), cell size and gap, axis labels, the
value to bucket mapping for min == max, NaN and out-of-range values, hover. KkStatusTimeline against lines 2345-2370: span widths
(weights, 2px gap, 2px minimum), the percent column, axis labels, level colours, hover and tap hit testing, keyboard focus.
KkWaterfall against .kk-wf (lines 1802-1819): how the spectrogram image is built and cached (ui.Image lifecycle and disposal,
repaint when rows change in place), scroll direction, the palette ramp, the crosshair, ragged and empty rows. KkTrace against
.kk-trace (lines 471-511): polyline scaling, the plot pattern, the glow, the level colour, live updates when the sample list
changes, empty and single samples, NaN samples.''')

t('dg-model', ['lib/src/diagram/model.dart', 'lib/src/diagram/parser.dart', 'lib/src/diagram/metrics.dart', 'lib/src/diagram/geometry.dart'], '''
KkDiagram validation (duplicate and empty ids, edges to unknown nodes, self loops, parallel edges), immutability and equality.
The text language: every node form, every wire operator, labels, class suffixes, quoted fields, positions, comments, the
direction header, error line numbers, CRLF, tabs, non-ASCII text; toSource round trips for everything it claims to keep, and
what tryParse returns for bad input. KkNodeMetrics (sizes per kind, the sizeOf hook, text measurement estimates against real
text widths: are labels clipped or do they overlap?). The outline functions (kkNodeOutline, kkNodePath, kkDistanceToOutline,
kkOutlineExit) for each node kind. Snapping (kkSnap, kkSnapUp). KkDiagramGeometry (labelAnchor, coveredTexts, wireCrosses,
nodeAt hit testing at the edges of a symbol).''')

t('dg-layouts', ['lib/src/diagram/layout.dart', 'lib/src/diagram/layered_layout.dart', 'lib/src/diagram/tree_layout.dart', 'lib/src/diagram/radial_layout.dart', 'lib/src/diagram/force_layout.dart', 'lib/src/diagram/manual_layout.dart'], '''
Each layout on: an empty diagram, one node, disconnected components, cycles (how they are broken and drawn), self loops, parallel
edges, long edges, every direction, very wide and very deep graphs. Determinism (same input, same output; the force seed). No
overlapping nodes and the minimum gaps kept. Nodes on the 8px grid. Layered: layer assignment, crossing minimisation (does it
terminate, is it stable), coordinate assignment. Tree: extra wires that are not tree edges, several roots. Radial: many children
on a ring, the root choice. Force: convergence, coincident nodes, NaN safety, the aspect option. Manual: normalised versus
absolute positions, nodes without a position. Cost for 200 nodes.''')

t('dg-router', ['lib/src/diagram/router.dart'], '''
The orthogonal, octilinear and straight routers: every leg horizontal, vertical or at 45 degrees where promised, routes that
start and end on the node outlines, the cut corners on short legs, obstacle avoidance and the path search (termination, its step
limit, the heuristic, clearance), label placement on a wire, reversed edges, the maxCut hint, wires that share a lane, self
loops, coincident endpoints, touching or overlapping nodes, numeric robustness (zero-length segments, repeated points, NaN).''')

t('dg-view', ['lib/src/diagram/painter.dart', 'lib/src/diagram/view.dart', 'lib/src/diagram/node_graph.dart', 'lib/src/diagram/sequence_diagram.dart'], '''
KkDiagramPainter against the .kk-graph paint rules (lines 1669-1714): node strokes and fills per level, the symbols, the flag
glyph, wire styles (plain, active, flow and its dash speed, reverse, offline), arrow heads, the critical halo, label backing,
text painting (TextPainter caching and disposal), shouldRepaint. KkDiagramView / RenderKkDiagramViewport: fit modes and
alignment, pan and zoom maths (zoom about the pointer, limits, the controller), gestures (drag, wheel, pinch, keys), hit testing
under the transform, selection / hover / focus, keyboard movement between nodes, the info plate placement, the entrance and
motion off, when layout and routing are recomputed (never in paint), intrinsics and dry layout, semantics. KkNodeGraph (head,
legend, footer, expand, height, minWidth). KkSequenceDiagram: participant columns, lifelines, activations, each message kind,
dividers, numbering, the time column, kkSequenceNaturalWidth and narrow parents, the entrance, its render box (dry layout,
intrinsics, baseline).''')

if __name__ == '__main__':
    import json, sys
    json.dump(T, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
    print(len(T), 'targets:', ', '.join(T))
