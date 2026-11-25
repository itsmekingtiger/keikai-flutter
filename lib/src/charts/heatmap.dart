import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../motion/entrances.dart';
import '../painting/text.dart';
import 'format.dart';
import 'plot.dart';
import 'series.dart';

/// One cell of a [KkHeatmap].
@immutable
class KkHeatCell {
  const KkHeatCell(this.row, this.column, this.value);

  final int row;
  final int column;

  /// Null where there is no data.
  final double? value;

  @override
  bool operator ==(Object other) => other is KkHeatCell && other.row == row && other.column == column;

  @override
  int get hashCode => Object.hash(row, column);
}

/// A grid of values shown as intensity: load by sector and hour, errors by
/// channel and day.
///
/// Cells are 18px tall with 2px gaps and take one of the six ramp steps, from
/// nearly black to hot. Row labels sit at the left, column labels under the
/// grid. Hovering a cell (or moving to it with the arrow keys) outlines it
/// and opens a tooltip. Cells flicker in on entry, 5ms apart. In a parent
/// that fixes the height the cells stretch or shrink to fill it.
class KkHeatmap extends StatefulWidget {
  const KkHeatmap({
    super.key,
    required this.values,
    this.rowLabels = const <String>[],
    this.columnLabels = const <String>[],
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.min,
    this.max,
    this.cellHeight = 18,
    this.gap = 2,
    this.legend = true,
    this.lowLabel,
    this.highLabel,
    this.format,
    this.showTooltip = true,
    this.focusable = true,
    this.onCellHover,
    this.onCellTap,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// The rows, top to bottom; each row left to right. Null (or NaN) is a cell
  /// without data. Rows may differ in length.
  final List<List<double?>> values;

  /// One label per row, at the left.
  final List<String> rowLabels;

  /// One label per column, under the grid. Use empty strings to label only
  /// some columns.
  final List<String> columnLabels;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the map bare.
  final bool frame;

  /// The value of the darkest step. Defaults to 0, or the smallest value when
  /// that is negative.
  final double? min;

  /// The value of the hottest step. Defaults to the largest value.
  final double? max;

  /// Height of a cell when the height is free.
  final double cellHeight;
  final double gap;

  /// Show the ramp with its end values in the foot.
  final bool legend;

  /// Label at the low end of the ramp. Defaults to the formatted minimum.
  final String? lowLabel;

  /// Label at the high end of the ramp.
  final String? highLabel;

  /// Formats a value in the tooltip and the legend.
  final String Function(double value)? format;

  /// Open a tooltip on the hovered cell.
  final bool showTooltip;

  /// Let the map take keyboard focus (arrow keys move between cells).
  final bool focusable;

  /// The hovered cell, or null when the pointer leaves.
  final ValueChanged<KkHeatCell?>? onCellHover;
  final ValueChanged<KkHeatCell>? onCellTap;

  /// Play the flicker-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkHeatmap> createState() => _KkHeatmapState();
}

class _HeatGeometry {
  const _HeatGeometry(this.left, this.top, this.cellWidth, this.cellHeight, this.gap, this.rows, this.columns);

  static const double padding = 12;
  static const double labelGap = 8;
  static const double columnLabelGap = 4;
  static const double columnLabelHeight = 10;

  final double left;
  final double top;
  final double cellWidth;
  final double cellHeight;
  final double gap;
  final int rows;
  final int columns;

  double get gridBottom => top + rows * cellHeight + math.max(0, rows - 1) * gap;

  Rect cell(int row, int column) =>
      Rect.fromLTWH(left + column * (cellWidth + gap), top + row * (cellHeight + gap), cellWidth, cellHeight);

  ({int row, int column})? at(Offset p) {
    if (rows == 0 || columns == 0 || !(cellWidth > 0) || !(cellHeight > 0)) return null;
    final double x = p.dx - left;
    final double y = p.dy - top;
    if (x < -gap || y < -gap) return null;
    final int column = (x / (cellWidth + gap)).floor();
    final int row = (y / (cellHeight + gap)).floor();
    if (column < 0 || column >= columns || row < 0 || row >= rows) return null;
    return (row: row, column: column);
  }

  static double naturalHeight(int rows, double cellHeight, double gap, bool columnLabels) =>
      padding * 2 +
      rows * cellHeight +
      math.max(0, rows - 1) * gap +
      (columnLabels ? columnLabelGap + columnLabelHeight : 0);

  static _HeatGeometry? compute(
    Size size, {
    required int rows,
    required int columns,
    required double rowLabelWidth,
    required bool columnLabels,
    required double gap,
  }) {
    if (rows <= 0 || columns <= 0 || size.width <= 0 || size.height <= 0 || !size.isFinite) return null;
    final double left = padding + (rowLabelWidth > 0 ? rowLabelWidth + labelGap : 0);
    final double width = size.width - left - padding;
    final double g = math.max(0, gap);
    final double cellWidth = (width - g * (columns - 1)) / columns;
    final double height = size.height - padding * 2 - (columnLabels ? columnLabelGap + columnLabelHeight : 0);
    final double cellHeight = (height - g * (rows - 1)) / rows;
    if (!(cellWidth > 0) || !(cellHeight > 0)) return null;
    return _HeatGeometry(left, padding, cellWidth, cellHeight, g, rows, columns);
  }
}

class _KkHeatmapState extends State<KkHeatmap> {
  final ValueNotifier<KkHeatCell?> _active = ValueNotifier<KkHeatCell?>(null);
  double _rowLabelWidth = 0;

  int get _rows => widget.values.length;

  int get _columns {
    int n = 0;
    for (final List<double?> row in widget.values) {
      n = math.max(n, row.length);
    }
    return n;
  }

  bool get _hasColumnLabels => widget.columnLabels.any((String s) => s.isNotEmpty);

  double? _valueAt(int row, int column) {
    if (row < 0 || row >= widget.values.length) return null;
    final List<double?> r = widget.values[row];
    if (column < 0 || column >= r.length) return null;
    final double? v = r[column];
    return (v != null && v.isFinite) ? v : null;
  }

  _HeatGeometry? _geometry(Size size) => _HeatGeometry.compute(
    size,
    rows: _rows,
    columns: _columns,
    rowLabelWidth: _rowLabelWidth,
    columnLabels: _hasColumnLabels,
    gap: widget.gap,
  );

  void _setActive(KkHeatCell? cell) {
    if (_active.value == cell) return;
    _active.value = cell;
    widget.onCellHover?.call(cell);
  }

  KkHeatCell? _cellAt(Offset position, Size size) {
    final ({int row, int column})? hit = _geometry(size)?.at(position);
    return hit == null ? null : KkHeatCell(hit.row, hit.column, _valueAt(hit.row, hit.column));
  }

  void _step(int dx, int dy) {
    final int rows = _rows;
    final int columns = _columns;
    if (rows == 0 || columns == 0) return;
    final KkHeatCell? current = _active.value;
    final int row = current == null ? 0 : (current.row + dy).clamp(0, rows - 1);
    final int column = current == null ? 0 : (current.column + dx).clamp(0, columns - 1);
    _setActive(KkHeatCell(row, column, _valueAt(row, column)));
  }

  @override
  void didUpdateWidget(KkHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final KkHeatCell? cell = _active.value;
    if (cell != null && (cell.row >= _rows || cell.column >= _columns)) _active.value = null;
  }

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final int rows = _rows;
    final int columns = _columns;
    final TextStyle rowStyle = theme.type.mono(10, weight: FontWeight.w500, color: c.inkDim);
    double labelWidth = 0;
    for (int r = 0; r < math.min(rows, widget.rowLabels.length); r++) {
      labelWidth = math.max(labelWidth, kkMeasureText(widget.rowLabels[r], rowStyle, scaler: scaler));
    }
    _rowLabelWidth = labelWidth.ceilToDouble();

    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (final List<double?> row in widget.values) {
      for (final double? v in row) {
        if (v == null || !v.isFinite) continue;
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    if (!lo.isFinite || !hi.isFinite) {
      lo = 0;
      hi = 0;
    }
    final double low = (widget.min != null && widget.min!.isFinite) ? widget.min! : math.min(0, lo);
    final double high = (widget.max != null && widget.max!.isFinite) ? widget.max! : hi;
    String text(double v) => !v.isFinite ? '--' : (widget.format?.call(v) ?? kkPlain(v));

    final KkCascade cascade = KkCascade(
      count: rows * columns,
      item: const Duration(milliseconds: 350),
      step: const Duration(milliseconds: 5),
    );
    final bool hasColumnLabels = _hasColumnLabels;

    Widget plot = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 200),
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkCanvas(
          naturalHeight: _HeatGeometry.naturalHeight(rows, widget.cellHeight, widget.gap, hasColumnLabels),
          painter: _HeatPainter(
            values: widget.values,
            rows: rows,
            columns: columns,
            rowLabels: widget.rowLabels,
            columnLabels: widget.columnLabels,
            rowLabelWidth: _rowLabelWidth,
            hasColumnLabels: hasColumnLabels,
            gap: widget.gap,
            low: low,
            high: high,
            format: text,
            showTooltip: widget.showTooltip,
            theme: theme,
            scaler: scaler,
            rowStyle: rowStyle,
            cascade: cascade,
            progress: progress,
            active: _active,
          ),
        );
      },
    );
    plot = KkPlotPointer(
      onMove: (Offset? position, Size size) => _setActive(position == null ? null : _cellAt(position, size)),
      onTap: (Offset position, Size size) {
        final KkHeatCell? cell = _cellAt(position, size);
        if (cell != null) widget.onCellTap?.call(cell);
      },
      child: plot,
    );
    plot = KkPlotFocus(
      enabled: widget.focusable,
      onStep: _step,
      onActivate: () {
        final KkHeatCell? cell = _active.value;
        if (cell != null) widget.onCellTap?.call(cell);
      },
      onDismiss: () => _setActive(null),
      child: plot,
    );

    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: rows == 0 || columns == 0
          ? 'no data'
          : '$rows rows, $columns columns, from ${text(low)} to ${text(high)}',
      legend: widget.legend
          ? <Widget>[KkRampKey(low: widget.lowLabel ?? text(low), high: widget.highLabel ?? text(high))]
          : null,
      child: plot,
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.values,
    required this.rows,
    required this.columns,
    required this.rowLabels,
    required this.columnLabels,
    required this.rowLabelWidth,
    required this.hasColumnLabels,
    required this.gap,
    required this.low,
    required this.high,
    required this.format,
    required this.showTooltip,
    required this.theme,
    required this.scaler,
    required this.rowStyle,
    required this.cascade,
    required this.progress,
    required this.active,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, active]));

  final List<List<double?>> values;
  final int rows;
  final int columns;
  final List<String> rowLabels;
  final List<String> columnLabels;
  final double rowLabelWidth;
  final bool hasColumnLabels;
  final double gap;
  final double low;
  final double high;
  final String Function(double value) format;
  final bool showTooltip;
  final KeikaiThemeData theme;
  final TextScaler scaler;
  final TextStyle rowStyle;
  final KkCascade cascade;
  final Animation<double> progress;
  final ValueNotifier<KkHeatCell?> active;

  static const List<double> _stops = <double>[0, 0.2, 0.3, 0.45, 0.55, 0.7, 1];
  static const List<double> _opacity = <double>[0, 0.9, 0.1, 1, 0.35, 1, 1];

  @override
  void paint(Canvas canvas, Size size) {
    final _HeatGeometry? g = _HeatGeometry.compute(
      size,
      rows: rows,
      columns: columns,
      rowLabelWidth: rowLabelWidth,
      columnLabels: hasColumnLabels,
      gap: gap,
    );
    if (g == null) return;
    final KkColors c = theme.colors;
    final List<Color> ramp = c.ramp;
    final Paint paint = Paint();
    final double p = progress.value;
    final bool settled = p >= 1;

    for (int r = 0; r < rows; r++) {
      final List<double?> row = values[r];
      for (int col = 0; col < columns; col++) {
        final double? v = col < row.length ? row[col] : null;
        final Color color = ramp[kkRampStep(v, low, high)];
        double alpha = 1;
        if (!settled) {
          alpha = kkKeyframes(cascade.at(p, r * columns + col), _stops, _opacity, steps: 4);
          if (alpha <= 0) continue;
        }
        paint.color = alpha >= 1 ? color : color.withValues(alpha: color.a * alpha);
        canvas.drawRect(g.cell(r, col), paint);
      }
      if (r < rowLabels.length && rowLabelWidth > 0) {
        kkPaintText(
          canvas,
          rowLabels[r],
          rowStyle,
          Offset(g.left - _HeatGeometry.labelGap, g.top + r * (g.cellHeight + g.gap) + g.cellHeight / 2),
          align: Alignment.centerRight,
          scaler: scaler,
        );
      }
    }

    if (hasColumnLabels) {
      final TextStyle style = theme.type.mono(10, color: c.inkFaint);
      double lastRight = double.negativeInfinity;
      for (int col = 0; col < math.min(columns, columnLabels.length); col++) {
        if (columnLabels[col].isEmpty) continue;
        final double x = g.left + col * (g.cellWidth + g.gap);
        if (x < lastRight + 4) continue;
        final Rect drawn = kkPaintText(
          canvas,
          columnLabels[col],
          style,
          Offset(x, g.gridBottom + _HeatGeometry.columnLabelGap),
          scaler: scaler,
        );
        lastRight = drawn.right;
      }
    }

    final KkHeatCell? cell = active.value;
    if (cell != null && cell.row < rows && cell.column < columns) {
      final Rect rect = g.cell(cell.row, cell.column);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = theme.metrics.stroke2
          ..color = c.focus,
      );
      if (showTooltip) {
        final double? v = cell.value;
        final String rowName = cell.row < rowLabels.length ? rowLabels[cell.row] : 'ROW ${cell.row + 1}';
        String columnName = 'COL ${cell.column + 1}';
        for (int i = math.min(cell.column, columnLabels.length - 1); i >= 0; i--) {
          if (columnLabels[i].isNotEmpty) {
            columnName = i == cell.column ? columnLabels[i] : '${columnLabels[i]} +${cell.column - i}';
            break;
          }
        }
        kkPaintChartTip(
          canvas,
          Offset.zero & size,
          rect.center,
          title: '$rowName · $columnName',
          rows: <KkTipRow>[
            KkTipRow(
              color: ramp[kkRampStep(v, low, high)],
              name: 'VALUE',
              value: v == null ? '--' : format(v),
              box: true,
            ),
          ],
          theme: theme,
          scaler: scaler,
          gap: g.cellWidth / 2 + 8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.rows != rows ||
      oldDelegate.columns != columns ||
      oldDelegate.rowLabels != rowLabels ||
      oldDelegate.columnLabels != columnLabels ||
      oldDelegate.rowLabelWidth != rowLabelWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.showTooltip != showTooltip ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler ||
      oldDelegate.progress != progress;
}
