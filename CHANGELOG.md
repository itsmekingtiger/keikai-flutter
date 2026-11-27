## 0.1.0

First release.

* Foundation: colour roles for the standby and alert themes, the type scale,
  measurement tokens, stepped motion, levels, 104 icons, plated shapes and
  hard-stop patterns.
* Layout system written against the rendering layer: flex with gaps, box,
  layers, wrap, the 4 / 8 / 12 / 16 / 24 column panel grid, the screen
  skeleton, split panes and breakpoints.
* Controls: buttons, icon buttons, badges, the hexagonal action button,
  segmented control, chips, checkbox, radio group, switch, slider, progress
  bar and ring, status tag, key cap, divider, skeleton and empty state.
* Inputs: text field, select, search, menus, popups, tooltips, date and time
  pickers, time range.
* Shell and overlays: command bar, tabs, nav rail and drawer, toolbar,
  breadcrumbs, dialog, side and bottom sheets, snackbars, lists, carousel.
* Instruments: panel, alert bar, readout, meter, timer, hex matrix, data log,
  sequence, annunciator, consensus, mode strip, heading, full-screen alarm.
* Charts: stat and delta, sparkline, time series, bar chart, bar list, gauge,
  donut, heatmap, status timeline, category bar, radar, waterfall, trace.
* Diagram renderer: a diagram model and text language, five layouts (layered,
  tree, radial, force, manual), three wire routers, node graph and sequence
  diagram.
* Data table: sorting, filtering, selection with bulk actions, detail rows,
  inline editing, paging, change flashes, and a standalone pager.
* `KeikaiApp`, an application root that needs neither Material nor Cupertino,
  with `KkPageRoute` and `KkPage` for both navigation styles.
* One import for a whole app: `package:keikai/keikai.dart` re-exports the
  widgets layer and the keyboard, clipboard and text-input types of the
  services layer.
* An example application, the console of a small plant, built with KEIKAI
  widgets only.
* A value that changes scrambles all of its digits; `KkMotion.scrambleScope`
  (a whole app) or `KkScramble.scope` (one value) limits the scramble to the
  digits that changed, for values that change every second.
