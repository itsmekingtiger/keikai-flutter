import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../painting/patterns.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// One cell of a [KkHexMatrix].
@immutable
class KkHexCell {
  const KkHexCell({required this.id, this.value, this.level, this.semanticLabel}) : isVoid = false;

  /// An empty position: a hexagon outline on the screen ground.
  const KkHexCell.empty() : id = '', value = null, level = null, semanticLabel = null, isVoid = true;

  /// The identifier, such as `N-07`.
  final String id;

  /// A short value under the id, such as `42%`.
  final String? value;
  final KkLevel? level;

  /// Read by screen readers instead of id, value and level.
  final String? semanticLabel;
  final bool isVoid;

  @override
  bool operator ==(Object other) =>
      other is KkHexCell &&
      other.id == id &&
      other.value == value &&
      other.level == level &&
      other.semanticLabel == semanticLabel &&
      other.isVoid == isVoid;

  @override
  int get hashCode => Object.hash(id, value, level, semanticLabel, isVoid);
}

/// A honeycomb of status cells: nodes, sectors, channels.
///
/// Each cell is a hexagon framed in its level's colour with the status icon,
/// an id and a value. Critical cells are filled; offline cells are hatched.
/// Rows interlock, every second row shifted by half a cell.
///
/// With [columns] null the matrix wraps to the width it is given. On entry
/// the cells pop in one after another, 22ms apart.
class KkHexMatrix extends StatelessWidget {
  const KkHexMatrix({
    super.key,
    required this.cells,
    this.columns,
    this.cellWidth,
    this.gap,
    this.showGlyph = true,
    this.onCellTap,
    this.onCellHover,
    this.entrance = true,
  });

  final List<KkHexCell> cells;

  /// Cells per row. By default as many as fit the width (8 when the width is
  /// not limited).
  final int? columns;

  /// Width of one cell; the height is 1.155 times this. Defaults to the
  /// theme's hex pitch (64).
  final double? cellWidth;

  /// Space between cells. Defaults to 4.
  final double? gap;

  /// Show the status icon in cells that have a level.
  final bool showGlyph;

  /// Makes cells focusable and pressable.
  final ValueChanged<KkHexCell>? onCellTap;

  /// Called with the cell under the pointer, and with null when it leaves.
  final ValueChanged<KkHexCell?>? onCellHover;

  /// Pop the cells in when first shown.
  final bool entrance;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final double w = cellWidth ?? theme.metrics.pitchHex;
    final double h = w * 1.155;
    return _HexLayout(
      columns: columns,
      cellWidth: w,
      cellHeight: h,
      gap: gap ?? theme.metrics.space1,
      children: <Widget>[
        for (int i = 0; i < cells.length; i++)
          _HexCellView(
            cell: cells[i],
            index: i,
            showGlyph: showGlyph,
            entrance: entrance,
            onTap: onCellTap,
            onHover: onCellHover,
          ),
      ],
    );
  }
}

class _HexCellView extends StatelessWidget {
  const _HexCellView({
    required this.cell,
    required this.index,
    required this.showGlyph,
    required this.entrance,
    required this.onTap,
    required this.onHover,
  });

  final KkHexCell cell;
  final int index;
  final bool showGlyph;
  final bool entrance;
  final ValueChanged<KkHexCell>? onTap;
  final ValueChanged<KkHexCell?>? onHover;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkLevel? level = cell.level;
    final bool critical = level == KkLevel.critical;
    final bool offline = level == KkLevel.offline;
    final Color edge = (cell.isVoid || level == null) ? c.line : c.level(level);
    final Color fill = cell.isVoid
        ? c.bg000
        : critical
        ? c.alert
        : c.bg100;
    final Color ink = critical
        ? c.onFill
        : level != null
        ? c.level(level)
        : c.inkDim;
    final Color idInk = critical
        ? c.onFill
        : offline
        ? c.offline
        : c.ink;
    final String? value = cell.value;

    Widget plate(bool focused) => CustomPaint(
      painter: _HexPainter(
        edge: edge,
        fill: fill,
        hatch: offline && !cell.isVoid ? c.bg200 : null,
        focus: focused ? c.focus : null,
        stroke: theme.metrics.stroke2,
      ),
      child: cell.isVoid
          ? null
          : KkBox(
              alignment: Alignment.center,
              child: KkColumn(
                shrinkWrap: true,
                gap: 3,
                cross: KkCrossAlign.center,
                children: <Widget>[
                  if (showGlyph && level != null) KkGlyph(level: level, size: 10, color: ink),
                  KkText.num(cell.id, size: 11, weight: FontWeight.w600, spacing: 0.02, color: idInk),
                  if (value != null) KkText.num(value, size: 10, weight: FontWeight.w500, color: ink),
                ],
              ),
            ),
    );

    final String label =
        cell.semanticLabel ?? <String>[cell.id, ?value, ?level?.word].join(' ');
    final ValueChanged<KkHexCell>? tap = onTap;
    Widget view;
    if (tap != null && !cell.isVoid) {
      view = KkPressable(
        onPressed: () => tap(cell),
        semanticLabel: label,
        excludeSemantics: true,
        builder: (BuildContext context, KkStates states) => plate(states.focused),
      );
    } else {
      view = cell.isVoid
          ? ExcludeSemantics(child: plate(false))
          : Semantics(label: label, child: ExcludeSemantics(child: plate(false)));
    }
    final ValueChanged<KkHexCell?>? hover = onHover;
    if (hover != null && !cell.isVoid) {
      view = MouseRegion(onEnter: (_) => hover(cell), onExit: (_) => hover(null), child: view);
    }
    // Pointer events only land inside the hexagon, so interlocking rows do
    // not steal each other's taps.
    view = KkSurface(shape: const KkShape.hex(), child: view);
    if (!entrance) return view;
    return KkOneShot(
      duration: const Duration(milliseconds: 320),
      delay: Duration(milliseconds: 200 + 22 * index),
      child: view,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) {
        return AnimatedBuilder(
          animation: progress,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final double t = progress.value;
            return Opacity(
              opacity: kkKeyframes(t, const <double>[0, 0.5, 1], const <double>[0, 1, 1], steps: 4),
              child: Transform.scale(
                scale: kkKeyframes(t, const <double>[0, 0.5, 1], const <double>[0.5, 1.08, 1], steps: 4),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

class _HexPainter extends CustomPainter {
  const _HexPainter({
    required this.edge,
    required this.fill,
    required this.hatch,
    required this.focus,
    required this.stroke,
  });

  final Color edge;
  final Color fill;

  /// Second colour of the offline hatch; null paints a flat fill.
  final Color? hatch;
  final Color? focus;
  final double stroke;

  static const KkShape _hex = KkShape.hex();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (rect.isEmpty) return;
    canvas.drawPath(_hex.path(rect), Paint()..color = edge);
    final Rect inner = rect.deflate(stroke);
    if (inner.width > 0 && inner.height > 0) {
      final Path innerPath = _hex.path(inner);
      final Color? second = hatch;
      if (second == null) {
        canvas.drawPath(innerPath, Paint()..color = fill);
      } else {
        canvas.save();
        canvas.clipPath(innerPath);
        kkPaintStripes(canvas, inner, a: fill, b: second, width: 3, period: 6);
        canvas.restore();
      }
    }
    final Color? ring = focus;
    if (ring != null) {
      canvas.drawPath(
        _hex.path(rect.inflate(2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(_HexPainter oldDelegate) =>
      oldDelegate.edge != edge ||
      oldDelegate.fill != fill ||
      oldDelegate.hatch != hatch ||
      oldDelegate.focus != focus ||
      oldDelegate.stroke != stroke;
}

class _HexParentData extends ContainerBoxParentData<RenderBox> {}

class _HexLayout extends MultiChildRenderObjectWidget {
  const _HexLayout({
    required this.columns,
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
    super.children,
  });

  final int? columns;
  final double cellWidth;
  final double cellHeight;
  final double gap;

  @override
  RenderKkHexMatrix createRenderObject(BuildContext context) =>
      RenderKkHexMatrix(columns: columns, cellWidth: cellWidth, cellHeight: cellHeight, gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderKkHexMatrix renderObject) {
    renderObject
      ..columns = columns
      ..cellWidth = cellWidth
      ..cellHeight = cellHeight
      ..gap = gap;
  }
}

/// The honeycomb layout behind [KkHexMatrix]: rows of fixed-size cells, every
/// second row shifted right by half a cell, rows overlapping by a quarter of
/// the cell height.
class RenderKkHexMatrix extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _HexParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _HexParentData> {
  RenderKkHexMatrix({int? columns, double cellWidth = 64, double cellHeight = 73.92, double gap = 4})
    : _columns = columns,
      _cellWidth = cellWidth,
      _cellHeight = cellHeight,
      _gap = gap;

  int? _columns;
  int? get columns => _columns;
  set columns(int? value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  double _cellWidth;
  double get cellWidth => _cellWidth;
  set cellWidth(double value) {
    if (value == _cellWidth) return;
    _cellWidth = value;
    markNeedsLayout();
  }

  double _cellHeight;
  double get cellHeight => _cellHeight;
  set cellHeight(double value) {
    if (value == _cellHeight) return;
    _cellHeight = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// The number of cells per row used by the last layout.
  int get resolvedColumns => _resolvedColumns;
  int _resolvedColumns = 1;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HexParentData) child.parentData = _HexParentData();
  }

  double get _unit => _cellWidth + _gap;
  double get _rowStep => _cellHeight * 0.75 + _gap * 0.866;

  int _columnsFor(double maxWidth, int count) {
    final int? fixed = _columns;
    if (fixed != null) return math.max(1, fixed);
    if (count <= 0) return 1;
    if (!maxWidth.isFinite) return math.min(count, 8);
    final int oneRow = math.max(1, ((maxWidth + _gap) / _unit).floor());
    if (oneRow >= count) return count;
    // Several rows: the shifted rows need half a cell more.
    return math.max(1, ((maxWidth + _gap - _unit / 2) / _unit).floor());
  }

  Size _sizeFor(int count, int cols) {
    if (count <= 0) return Size.zero;
    final int rows = (count / cols).ceil();
    double width = math.min(cols, count) * _unit - _gap;
    if (rows > 1) {
      final int second = math.min(cols, count - cols);
      width = math.max(width, second * _unit - _gap + _unit / 2);
    }
    return Size(width, _cellHeight + (rows - 1) * _rowStep);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _sizeFor(childCount, _columnsFor(double.infinity, childCount)).width;

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _sizeFor(childCount, _columnsFor(width, childCount)).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_sizeFor(childCount, _columnsFor(constraints.maxWidth, childCount)));

  @override
  void performLayout() {
    final int count = childCount;
    final int cols = _columnsFor(constraints.maxWidth, count);
    _resolvedColumns = cols;
    final BoxConstraints cell = BoxConstraints.tightFor(width: _cellWidth, height: _cellHeight);
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      child.layout(cell);
      final int row = i ~/ cols;
      final int col = i % cols;
      (child.parentData! as _HexParentData).offset = Offset(col * _unit + (row.isOdd ? _unit / 2 : 0), row * _rowStep);
    }
    size = constraints.constrain(_sizeFor(count, cols));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
