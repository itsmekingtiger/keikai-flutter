import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../motion/stagger.dart';

/// Chooses a column span from the grid's current column count.
typedef KkSpanBuilder = int Function(int columns);

/// Parent data of a child of [KkGrid].
class KkGridParentData extends ContainerBoxParentData<RenderBox> {
  int span = 4;
  int rows = 4;
  KkSpanBuilder? spanBuilder;

  /// Where the last layout placed this child: first column, first row and the
  /// number of columns it spans (after clamping to the grid).
  int column = 0;
  int row = 0;
  int placedSpan = 0;
}

/// The KEIKAI panel grid.
///
/// The column count follows the grid's own width: 4 below 600px, 8 from 600,
/// 12 from 840, 16 from 1600 and 24 from 2560. Rows are [KkMetrics.rowUnit]
/// (48px) high and the gutter is a fixed 8px at every size. Cells are packed
/// densely: a later, smaller cell moves up into a hole left by an earlier one.
///
/// The columns share the width in whole logical pixels: where it does not
/// divide evenly, some columns are a pixel wider than their neighbours. A cell
/// then starts and ends on a pixel, where its 1px lines stay one pixel wide,
/// as long as the grid itself does. The gutters are the same everywhere.
///
/// Wrap children in [KkCell] to give them a column span and a row count. Each
/// cell is told its index, so panels wipe in one after another, 60ms apart.
///
/// The grid is as wide as it is allowed to be and as tall as its rows, so it
/// needs a width limit: in a `KkRow` wrap it in a `KkExpanded`, and put it in
/// a vertical scroll view rather than a horizontal one.
class KkGrid extends StatelessWidget {
  const KkGrid({
    super.key,
    this.columns,
    this.gutter,
    this.rowUnit,
    this.dense = true,
    this.stagger = true,
    required this.children,
  });

  /// Fixed column count. By default it follows the width.
  final int? columns;

  /// Gap between cells. Defaults to [KkMetrics.gridGutter].
  final double? gutter;

  /// Height of one row. Defaults to [KkMetrics.rowUnit].
  final double? rowUnit;

  /// Fill holes with later cells.
  final bool dense;

  /// Give each child its index as a stagger delay for entrance motion.
  final bool stagger;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final int base = KkStagger.of(context);
    return _KkGridLayout(
      columns: columns,
      metrics: m,
      gutter: gutter ?? m.gridGutter,
      rowUnit: rowUnit ?? m.rowUnit,
      dense: dense,
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          if (stagger) _wrap(children[i], base + i) else children[i],
      ],
    );
  }

  static Widget _wrap(Widget child, int index) {
    // The stagger scope has to sit inside the KkCell (a parent data widget must
    // be a direct child of the grid).
    if (child is KkCell) {
      return KkCell(
        key: child.key,
        span: child.span,
        rows: child.rows,
        spanBuilder: child.spanBuilder,
        child: KkStagger(index: index, child: child.child),
      );
    }
    return KkStagger(index: index, child: child);
  }
}

/// Places a child of [KkGrid]: [span] columns wide (never more than the grid
/// has) and [rows] row units tall. The child fills the cell.
class KkCell extends ParentDataWidget<KkGridParentData> {
  const KkCell({super.key, this.span = 4, this.rows = 4, this.spanBuilder, required super.child})
    : assert(span > 0),
      assert(rows > 0);

  final int span;
  final int rows;

  /// Picks the span from the current column count; overrides [span].
  final KkSpanBuilder? spanBuilder;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkGridParentData pd = renderObject.parentData! as KkGridParentData;
    bool dirty = false;
    if (pd.span != span) {
      pd.span = span;
      dirty = true;
    }
    if (pd.rows != rows) {
      pd.rows = rows;
      dirty = true;
    }
    if (pd.spanBuilder != spanBuilder) {
      pd.spanBuilder = spanBuilder;
      dirty = true;
    }
    if (dirty) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _KkGridLayout;
}

class _KkGridLayout extends MultiChildRenderObjectWidget {
  const _KkGridLayout({
    required this.columns,
    required this.metrics,
    required this.gutter,
    required this.rowUnit,
    required this.dense,
    super.children,
  });

  final int? columns;
  final KkMetrics metrics;
  final double gutter;
  final double rowUnit;
  final bool dense;

  @override
  RenderKkGrid createRenderObject(BuildContext context) =>
      RenderKkGrid(columns: columns, metrics: metrics, gutter: gutter, rowUnit: rowUnit, dense: dense);

  @override
  void updateRenderObject(BuildContext context, RenderKkGrid renderObject) {
    renderObject
      ..columns = columns
      ..metrics = metrics
      ..gutter = gutter
      ..rowUnit = rowUnit
      ..dense = dense;
  }
}

/// The render object behind [KkGrid].
class RenderKkGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkGridParentData> {
  RenderKkGrid({
    int? columns,
    KkMetrics metrics = const KkMetrics(),
    double gutter = 8,
    double rowUnit = 48,
    bool dense = true,
  }) : _columns = columns,
       _metrics = metrics,
       _gutter = gutter,
       _rowUnit = rowUnit,
       _dense = dense;

  int? _columns;
  int? get columns => _columns;
  set columns(int? value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  KkMetrics _metrics;
  KkMetrics get metrics => _metrics;
  set metrics(KkMetrics value) {
    if (value == _metrics) return;
    _metrics = value;
    markNeedsLayout();
  }

  double _gutter;
  double get gutter => _gutter;
  set gutter(double value) {
    if (value == _gutter) return;
    _gutter = value;
    markNeedsLayout();
  }

  double _rowUnit;
  double get rowUnit => _rowUnit;
  set rowUnit(double value) {
    if (value == _rowUnit) return;
    _rowUnit = value;
    markNeedsLayout();
  }

  bool _dense;
  bool get dense => _dense;
  set dense(bool value) {
    if (value == _dense) return;
    _dense = value;
    markNeedsLayout();
  }

  /// The column count used by the last layout.
  int get resolvedColumns => _resolvedColumns;
  int _resolvedColumns = 4;

  /// The number of rows used by the last layout.
  int get resolvedRows => _resolvedRows;
  int _resolvedRows = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkGridParentData) child.parentData = KkGridParentData();
  }

  int _columnsFor(double width) => math.max(1, _columns ?? _metrics.columnsFor(width));

  /// Works out a column and a row for every child, in child order, without
  /// touching the children. Returns the placements and the number of rows used.
  ({List<({int column, int row, int span, int rows})> cells, int rowCount}) _place(int cols) {
    final List<List<bool>> taken = <List<bool>>[];
    bool free(int row, int col, int span, int rows) {
      for (int r = row; r < row + rows; r++) {
        if (r >= taken.length) continue;
        for (int c = col; c < col + span; c++) {
          if (taken[r][c]) return false;
        }
      }
      return true;
    }

    void take(int row, int col, int span, int rows) {
      while (taken.length < row + rows) {
        taken.add(List<bool>.filled(cols, false));
      }
      for (int r = row; r < row + rows; r++) {
        for (int c = col; c < col + span; c++) {
          taken[r][c] = true;
        }
      }
    }

    final List<({int column, int row, int span, int rows})> cells = <({int column, int row, int span, int rows})>[];
    int cursorRow = 0;
    int cursorCol = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final KkGridParentData pd = child.parentData! as KkGridParentData;
      final int span = (pd.spanBuilder?.call(cols) ?? pd.span).clamp(1, cols);
      final int rows = math.max(1, pd.rows);
      int row = _dense ? 0 : cursorRow;
      int col = _dense ? 0 : cursorCol;
      while (true) {
        if (col + span > cols) {
          col = 0;
          row++;
          continue;
        }
        if (free(row, col, span, rows)) break;
        col++;
      }
      take(row, col, span, rows);
      cells.add((column: col, row: row, span: span, rows: rows));
      cursorRow = row;
      cursorCol = col + span;
    }
    return (cells: cells, rowCount: taken.length);
  }

  double _heightFor(int rows) => rows <= 0 ? 0 : rows * _rowUnit + (rows - 1) * _gutter;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(_place(_columnsFor(width)).rowCount);

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    return constraints.constrain(Size(width, _heightFor(_place(_columnsFor(width)).rowCount)));
  }

  /// A grid of panels has no baseline of its own.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    final int cols = _columnsFor(width);
    final ({List<({int column, int row, int span, int rows})> cells, int rowCount}) placed = _place(cols);
    _resolvedColumns = cols;
    _resolvedRows = placed.rowCount;
    // A grid narrower than its own gutters closes them up instead of letting
    // the cells spill out.
    final double gutterX = cols > 1 ? math.min(_gutter, width / (cols - 1)) : 0;
    // The columns share what the gutters leave, in whole pixels. An exact
    // share is rarely a whole number, and a cell on a fraction of a pixel has
    // its 1px lines painted across two. So the room the columns before each
    // one take is rounded: some columns are a pixel wider than others, none
    // starts more than half a pixel from its exact place, and the last one
    // ends on the grid's own edge.
    final double shared = math.max(0, width - gutterX * (cols - 1));
    // Where column [k] starts, not counting the gutters before it. Rounding
    // may not pass the end, which is a fraction when the width is one.
    double start(int k) => k >= cols ? shared : math.min((shared * k / cols).roundToDouble(), shared);
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final ({int column, int row, int span, int rows}) cell = placed.cells[i];
      final KkGridParentData pd = child.parentData! as KkGridParentData;
      pd
        ..column = cell.column
        ..row = cell.row
        ..placedSpan = cell.span;
      final double x = start(cell.column);
      final double w = start(cell.column + cell.span) - x + gutterX * (cell.span - 1);
      final double h = _heightFor(cell.rows);
      child.layout(BoxConstraints.tightFor(width: w, height: h));
      pd.offset = Offset(x + gutterX * cell.column, cell.row * (_rowUnit + _gutter));
    }
    size = constraints.constrain(Size(width, _heightFor(placed.rowCount)));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
