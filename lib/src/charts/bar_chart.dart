import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../motion/entrances.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/frame.dart';
import 'plot.dart';
import 'scale.dart';
import 'series.dart';

/// How several series share a category.
enum KkBarMode {
  /// One bar per series, side by side.
  grouped,

  /// One bar per category, the series stacked on each other.
  stacked,
}

/// Vertical bars from a zero baseline, one group per category.
///
/// Edges are crisp (no anti-aliased sides), negative values hang below the
/// baseline, and bars grow from the baseline on entry (0.5s in 10 steps,
/// 30ms apart). Hovering a category dims the others to 35% and opens the
/// tooltip; the arrow keys do the same from the keyboard.
class KkBarChart extends StatefulWidget {
  const KkBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.mode = KkBarMode.grouped,
    this.levels,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.thresholds = const <KkThreshold>[],
    this.yMin,
    this.yMax,
    this.showValues = false,
    this.height = 140,
    this.legend,
    this.axes = true,
    this.plotPadding,
    this.barGap = 2,
    this.groupPadding = 0.24,
    this.yFormat,
    this.valueFormat,
    this.interactive = true,
    this.focusable = true,
    this.onBarHover,
    this.onBarTap,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// One label per category, under the bars.
  final List<String> labels;

  /// One value per category in each series. A null value leaves the bar out.
  final List<KkSeries> series;
  final KkBarMode mode;

  /// A status level per category. A bar with a level takes that level's
  /// colour instead of its series colour (meant for a single series).
  final List<KkLevel?>? levels;

  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the chart bare.
  final bool frame;
  final List<KkThreshold> thresholds;

  /// Pins the bottom of the y axis. By default it includes 0 and the data.
  final double? yMin;

  /// Pins the top of the y axis.
  final double? yMax;

  /// Write each bar's value at its end (the total, for stacked bars).
  final bool showValues;

  /// Height of the plot when the height is free.
  final double height;

  /// Show the legend. Defaults to true when there is more than one series.
  final bool? legend;

  /// Draw the grid, the axis lines and the tick labels.
  final bool axes;

  /// Insets of the plot area inside the canvas. Measured from the tick labels
  /// by default.
  final EdgeInsets? plotPadding;

  /// Space between the bars of one group.
  final double barGap;

  /// Share of each category's width left empty around its bars (0 to 0.9).
  final double groupPadding;
  final String Function(double y)? yFormat;
  final String Function(double value)? valueFormat;

  /// React to hover, touch and taps.
  final bool interactive;

  /// Let the plot take keyboard focus (arrow keys move between categories).
  final bool focusable;

  /// The hovered category, or null when the pointer leaves.
  final ValueChanged<int?>? onBarHover;
  final ValueChanged<int>? onBarTap;

  /// Play the grow-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkBarChart> createState() => _KkBarChartState();
}

class _Bar {
  const _Bar(this.rect, this.color, this.value, this.order);

  /// The bar at full height.
  final Rect rect;
  final Color color;
  final double value;

  /// Position in the entrance cascade.
  final int order;
}

class _BarData {
  const _BarData(this.names, this.colors, this.values, this.count);

  final List<String> names;
  final List<Color> colors;

  /// values[series][category]
  final List<List<double?>> values;
  final int count;

  static _BarData from(KkBarChart w, KkColors colors) {
    final int n = w.labels.length;
    return _BarData(
      <String>[for (final KkSeries s in w.series) s.name],
      <Color>[for (int k = 0; k < w.series.length; k++) w.series[k].color ?? kkSeriesColor(colors, k)],
      <List<double?>>[
        for (final KkSeries s in w.series)
          <double?>[
            for (int i = 0; i < n; i++) (i < s.values.length && kkIsFinite(s.values[i])) ? s.values[i] : null,
          ],
      ],
      n,
    );
  }
}

class _BarGeometry {
  const _BarGeometry({
    required this.plot,
    required this.y,
    required this.yTicks,
    required this.yStep,
    required this.band,
    required this.baseline,
    required this.bars,
    required this.totals,
  });

  final Rect plot;
  final KkLinearScale y;
  final List<double> yTicks;
  final double yStep;
  final double band;
  final double baseline;

  /// bars[category] holds that category's bars.
  final List<List<_Bar>> bars;

  /// Sum of each category (stacked) for the value label.
  final List<double?> totals;

  int? categoryAt(double dx) {
    if (bars.isEmpty || !(band > 0)) return null;
    return ((dx - plot.left) / band).floor().clamp(0, bars.length - 1);
  }

  static _BarGeometry? compute(
    Size size,
    _BarData data, {
    required KkBarMode mode,
    required List<KkLevel?>? levels,
    required KkColors colors,
    required List<KkThreshold> thresholds,
    required double? yMin,
    required double? yMax,
    required bool axes,
    required EdgeInsets? plotPadding,
    required double barGap,
    required double groupPadding,
    required String Function(double y, double step) yLabel,
    required TextStyle tickStyle,
    required TextScaler scaler,
  }) {
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) return null;
    final int n = data.count;
    final int m = data.values.length;
    final bool stacked = mode == KkBarMode.stacked;

    final List<double?> domain = <double?>[0, for (final KkThreshold t in thresholds) t.value];
    final List<double?> totals = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      double up = 0;
      double down = 0;
      bool any = false;
      for (int k = 0; k < m; k++) {
        final double? v = data.values[k][i];
        if (v == null) continue;
        any = true;
        if (v >= 0) {
          up += v;
        } else {
          down += v;
        }
        if (!stacked) domain.add(v);
      }
      if (any) totals[i] = up + down;
      if (stacked && any) {
        domain
          ..add(up)
          ..add(down);
      }
    }

    const double top = 14;
    const double right = 12;
    final double bottom = axes ? 22 : 6;
    final double roughHeight = math.max(0, size.height - (plotPadding?.vertical ?? top + bottom));
    final int tickCount = (roughHeight / 36).floor().clamp(2, 8);
    final KkLinearScale niced = KkLinearScale.of(domain).nice(tickCount);
    final bool pinMin = yMin != null && yMin.isFinite;
    final bool pinMax = yMax != null && yMax.isFinite;
    KkLinearScale ys = KkLinearScale(min: pinMin ? yMin : niced.min, max: pinMax ? yMax : niced.max);
    if (ys.min >= ys.max) {
      final double v = math.min(ys.min, ys.max);
      ys = KkLinearScale(min: v, max: v).nice(tickCount);
    }
    final List<double> yTicks = ys.ticks(tickCount);
    final double yStep = ys.tickStep(tickCount);

    Rect plot;
    if (plotPadding != null) {
      plot = plotPadding.deflateRect(Offset.zero & size);
    } else {
      double labelWidth = 0;
      if (axes) {
        for (final double t in yTicks) {
          labelWidth = math.max(labelWidth, kkMeasureText(yLabel(t, yStep), tickStyle, scaler: scaler));
        }
      }
      plot = Rect.fromLTRB(axes ? 8 + labelWidth + 6 : 6, top, size.width - right, size.height - bottom);
    }
    if (!(plot.width > 0) || !(plot.height > 0)) return null;
    ys = ys.withRange(plot.bottom, plot.top);
    final double baseline = ys.map(0).clamp(plot.top, plot.bottom).roundToDouble();

    final double band = n > 0 ? plot.width / n : 0;
    final double pad = groupPadding.clamp(0.0, 0.9);
    final List<List<_Bar>> bars = <List<_Bar>>[];
    for (int i = 0; i < n; i++) {
      final List<_Bar> group = <_Bar>[];
      final double inner = math.max(1, band * (1 - pad));
      final double start = plot.left + i * band + (band - inner) / 2;
      final KkLevel? level = (levels != null && i < levels.length) ? levels[i] : null;
      if (stacked) {
        double up = 0;
        double down = 0;
        for (int k = 0; k < m; k++) {
          final double? v = data.values[k][i];
          if (v == null || v == 0) continue;
          final double from = v > 0 ? up : down;
          final double to = from + v;
          if (v > 0) {
            up = to;
          } else {
            down = to;
          }
          final double y0 = ys.map(from).clamp(plot.top, plot.bottom);
          final double y1 = ys.map(to).clamp(plot.top, plot.bottom);
          group.add(
            _Bar(
              _crisp(start, start + inner, y0, y1),
              level != null ? colors.level(level) : data.colors[k],
              v,
              i,
            ),
          );
        }
      } else {
        final double gap = (m > 1 && (inner - barGap * (m - 1)) / m >= 2) ? barGap : 0;
        final double width = m > 0 ? (inner - gap * (m - 1)) / m : inner;
        for (int k = 0; k < m; k++) {
          final double? v = data.values[k][i];
          if (v == null) continue;
          final double left = start + k * (width + gap);
          final double y1 = ys.map(v).clamp(plot.top, plot.bottom);
          group.add(
            _Bar(
              _crisp(left, left + width, baseline, y1),
              level != null ? colors.level(level) : data.colors[k],
              v,
              i * m + k,
            ),
          );
        }
      }
      bars.add(group);
    }
    return _BarGeometry(
      plot: plot,
      y: ys,
      yTicks: yTicks,
      yStep: yStep,
      band: band,
      baseline: baseline,
      bars: bars,
      totals: totals,
    );
  }

  static Rect _crisp(double left, double right, double y0, double y1) {
    double l = left.roundToDouble();
    double r = right.roundToDouble();
    if (r - l < 1) r = l + 1;
    double t = math.min(y0, y1).roundToDouble();
    double b = math.max(y0, y1).roundToDouble();
    if (b - t < 1) {
      // A value too small to show still gets one pixel on its own side.
      if (y1 <= y0) {
        t = b - 1;
      } else {
        b = t + 1;
      }
    }
    if (l.isNaN || r.isNaN || t.isNaN || b.isNaN) {
      l = r = t = b = 0;
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}

class _KkBarChartState extends State<KkBarChart> {
  final ValueNotifier<int?> _active = ValueNotifier<int?>(null);
  _BarData? _data;

  TextStyle _tickStyle(KeikaiThemeData theme) => theme.type.mono(10, color: theme.colors.inkFaint);

  String _yLabel(double v, double step) => widget.yFormat?.call(v) ?? kkFormatTick(v, step);

  _BarGeometry? _geometry(Size size) {
    final _BarData? data = _data;
    if (data == null) return null;
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    return _BarGeometry.compute(
      size,
      data,
      mode: widget.mode,
      levels: widget.levels,
      colors: theme.colors,
      thresholds: widget.thresholds,
      yMin: widget.yMin,
      yMax: widget.yMax,
      axes: widget.axes,
      plotPadding: widget.plotPadding,
      barGap: widget.barGap,
      groupPadding: widget.groupPadding,
      yLabel: _yLabel,
      tickStyle: _tickStyle(theme),
      scaler: MediaQuery.textScalerOf(context),
    );
  }

  void _setActive(int? index) {
    if (_active.value == index) return;
    _active.value = index;
    widget.onBarHover?.call(index);
  }

  void _onMove(Offset? position, Size size) {
    if (position == null) {
      _setActive(null);
      return;
    }
    _setActive(_geometry(size)?.categoryAt(position.dx));
  }

  void _onTap(Offset position, Size size) {
    final int? index = _geometry(size)?.categoryAt(position.dx);
    if (index != null) widget.onBarTap?.call(index);
  }

  void _step(int dx, int dy) {
    final int n = widget.labels.length;
    if (n == 0 || dx == 0) return;
    final int? current = _active.value;
    _setActive(current == null ? (dx > 0 ? 0 : n - 1) : (current + dx).clamp(0, n - 1));
  }

  @override
  void didUpdateWidget(KkBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? active = _active.value;
    if (active != null && active >= widget.labels.length) {
      _active.value = widget.labels.isEmpty ? null : widget.labels.length - 1;
    }
  }

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final _BarData data = _BarData.from(widget, theme.colors);
    _data = data;
    final int m = data.values.length;
    final KkCascade cascade = KkCascade(
      count: widget.mode == KkBarMode.stacked ? data.count : data.count * math.max(1, m),
      item: KkMotion.barGrow,
      step: const Duration(milliseconds: 30),
    );

    Widget plot = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 200),
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkCanvas(
          naturalHeight: widget.height,
          painter: _BarPainter(
            data: data,
            labels: widget.labels,
            mode: widget.mode,
            levels: widget.levels,
            thresholds: widget.thresholds,
            yMin: widget.yMin,
            yMax: widget.yMax,
            axes: widget.axes,
            plotPadding: widget.plotPadding,
            barGap: widget.barGap,
            groupPadding: widget.groupPadding,
            showValues: widget.showValues,
            theme: theme,
            scaler: scaler,
            tickStyle: _tickStyle(theme),
            yLabel: _yLabel,
            valueFormat: widget.valueFormat,
            cascade: cascade,
            progress: progress,
            active: _active,
          ),
        );
      },
    );
    if (widget.interactive) {
      plot = KkPlotPointer(onMove: _onMove, onTap: _onTap, child: plot);
      plot = KkPlotFocus(
        enabled: widget.focusable,
        onStep: _step,
        onJump: (bool toEnd) {
          if (data.count > 0) _setActive(toEnd ? data.count - 1 : 0);
        },
        onActivate: () {
          final int? index = _active.value;
          if (index != null) widget.onBarTap?.call(index);
        },
        onDismiss: () => _setActive(null),
        child: plot,
      );
    }

    final bool showLegend = widget.legend ?? m > 1;
    final List<String> summary = <String>[
      for (int i = 0; i < data.count; i++)
        for (int k = 0; k < m; k++)
          if (data.values[k][i] != null)
            '${widget.labels[i]}${m > 1 ? ' ${data.names[k]}' : ''} '
                '${widget.valueFormat?.call(data.values[k][i]!) ?? data.values[k][i]!.toStringAsFixed(1)}',
    ];
    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: summary.isEmpty ? 'no data' : summary.take(24).join(', '),
      legend: showLegend
          ? <Widget>[
              for (int k = 0; k < m; k++) KkWidgetKey(label: data.names[k], color: data.colors[k], box: true),
            ]
          : null,
      child: plot,
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.data,
    required this.labels,
    required this.mode,
    required this.levels,
    required this.thresholds,
    required this.yMin,
    required this.yMax,
    required this.axes,
    required this.plotPadding,
    required this.barGap,
    required this.groupPadding,
    required this.showValues,
    required this.theme,
    required this.scaler,
    required this.tickStyle,
    required this.yLabel,
    required this.valueFormat,
    required this.cascade,
    required this.progress,
    required this.active,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, active]));

  final _BarData data;
  final List<String> labels;
  final KkBarMode mode;
  final List<KkLevel?>? levels;
  final List<KkThreshold> thresholds;
  final double? yMin;
  final double? yMax;
  final bool axes;
  final EdgeInsets? plotPadding;
  final double barGap;
  final double groupPadding;
  final bool showValues;
  final KeikaiThemeData theme;
  final TextScaler scaler;
  final TextStyle tickStyle;
  final String Function(double y, double step) yLabel;
  final String Function(double value)? valueFormat;
  final KkCascade cascade;
  final Animation<double> progress;
  final ValueNotifier<int?> active;

  String _value(double v, double step) {
    final String Function(double value)? f = valueFormat;
    if (f != null) return f(v);
    final String s = v.toStringAsFixed(kkTickDecimals(step / 10));
    return double.tryParse(s) == 0 ? s.replaceFirst('-', '') : s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final KkColors c = theme.colors;
    final _BarGeometry? g = _BarGeometry.compute(
      size,
      data,
      mode: mode,
      levels: levels,
      colors: c,
      thresholds: thresholds,
      yMin: yMin,
      yMax: yMax,
      axes: axes,
      plotPadding: plotPadding,
      barGap: barGap,
      groupPadding: groupPadding,
      yLabel: yLabel,
      tickStyle: tickStyle,
      scaler: scaler,
    );
    if (g == null) return;
    final Rect plot = g.plot;

    if (axes) {
      for (final double t in g.yTicks) {
        final double y = g.y.map(t);
        if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
        kkPaintHLine(canvas, plot.left, plot.right, y, c.grid);
        kkPaintText(
          canvas,
          yLabel(t, g.yStep),
          tickStyle,
          Offset(plot.left - 6, y),
          align: Alignment.centerRight,
          scaler: scaler,
        );
      }
      kkPaintVLine(canvas, plot.left, plot.top, plot.bottom, c.line);
    }

    final int? hover = active.value;
    final Paint paint = Paint()..isAntiAlias = false;
    final TextStyle valueStyle = theme.type.mono(10, weight: FontWeight.w500, color: c.ink);
    for (int i = 0; i < g.bars.length; i++) {
      final bool dim = hover != null && hover != i;
      double extentTop = g.baseline;
      double extentBottom = g.baseline;
      double grown = 1;
      for (final _Bar bar in g.bars[i]) {
        final double t = cascade.at(progress.value, bar.order, steps: KkMotion.barGrowSteps);
        grown = math.min(grown, t);
        if (t <= 0) continue;
        final double top = g.baseline + (bar.rect.top - g.baseline) * t;
        final double bottom = g.baseline + (bar.rect.bottom - g.baseline) * t;
        if (bottom - top < 0.5) continue;
        paint.color = dim ? bar.color.withValues(alpha: bar.color.a * 0.35) : bar.color;
        canvas.drawRect(Rect.fromLTRB(bar.rect.left, top.roundToDouble(), bar.rect.right, bottom.roundToDouble()), paint);
        extentTop = math.min(extentTop, bar.rect.top);
        extentBottom = math.max(extentBottom, bar.rect.bottom);
        if (showValues && mode == KkBarMode.grouped && t >= 1) {
          _paintValue(canvas, g, bar.rect, bar.value, valueStyle, dim);
        }
      }
      if (showValues && mode == KkBarMode.stacked && grown >= 1 && g.bars[i].isNotEmpty) {
        final double? total = g.totals[i];
        if (total != null) {
          final Rect column = Rect.fromLTRB(g.bars[i].first.rect.left, extentTop, g.bars[i].first.rect.right, extentBottom);
          _paintValue(canvas, g, column, total, valueStyle, dim);
        }
      }
    }

    if (axes) {
      kkPaintHLine(canvas, plot.left, plot.right, plot.bottom, c.line);
      if (g.baseline < plot.bottom - 0.5) kkPaintHLine(canvas, plot.left, plot.right, g.baseline, c.line);
      _paintXLabels(canvas, size, g);
    }
    _paintThresholds(canvas, g, c);

    if (hover != null && hover >= 0 && hover < g.bars.length) {
      final List<KkTipRow> rows = <KkTipRow>[
        for (int k = 0; k < data.values.length; k++)
          KkTipRow(
            color: (levels != null && hover < levels!.length && levels![hover] != null)
                ? c.level(levels![hover])
                : data.colors[k],
            name: data.names[k],
            value: data.values[k][hover] == null ? '--' : _value(data.values[k][hover]!, g.yStep),
            box: true,
          ),
      ];
      kkPaintChartTip(
        canvas,
        Offset.zero & size,
        Offset(plot.left + (hover + 0.5) * g.band, plot.top + plot.height / 2),
        title: hover < labels.length ? labels[hover] : null,
        rows: rows,
        theme: theme,
        scaler: scaler,
        gap: g.band / 2 + 6,
      );
    }
  }

  void _paintValue(Canvas canvas, _BarGeometry g, Rect bar, double value, TextStyle style, bool dim) {
    final TextStyle s = dim ? style.copyWith(color: style.color!.withValues(alpha: 0.35)) : style;
    final TextPainter tp = kkLayoutText(_value(value, g.yStep), s, scaler: scaler);
    // Leave the label out rather than let neighbours collide.
    if (tp.width <= math.max(bar.width, g.band - 4) + 0.5) {
      final double x = bar.center.dx - tp.width / 2;
      final double y = value >= 0 ? bar.top - tp.height - 3 : bar.bottom + 3;
      tp.paint(canvas, Offset(x, y));
    }
    tp.dispose();
  }

  void _paintXLabels(Canvas canvas, Size size, _BarGeometry g) {
    final Rect plot = g.plot;
    final int n = math.min(labels.length, g.bars.length);
    if (n == 0) return;
    final List<TextPainter> painters = <TextPainter>[
      for (int i = 0; i < n; i++) kkLayoutText(labels[i], tickStyle, scaler: scaler),
    ];
    double widest = 0;
    for (final TextPainter tp in painters) {
      widest = math.max(widest, tp.width);
    }
    final int every = g.band > 0 ? math.max(1, ((widest + 8) / g.band).ceil()) : 1;
    for (int i = 0; i < n; i++) {
      final TextPainter tp = painters[i];
      if (i % every == 0) {
        final double x = plot.left + (i + 0.5) * g.band - tp.width / 2;
        tp.paint(canvas, Offset(x.clamp(0.0, math.max(0.0, size.width - tp.width)), plot.bottom + 6));
      }
      tp.dispose();
    }
  }

  void _paintThresholds(Canvas canvas, _BarGeometry g, KkColors c) {
    final Rect plot = g.plot;
    for (final KkThreshold t in thresholds) {
      if (!t.value.isFinite) continue;
      final double y = g.y.map(t.value);
      if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
      final Color color = t.color ?? (t.level == null ? c.inkDim : c.level(t.level));
      final double crisp = y.roundToDouble() + 0.5;
      canvas.drawPath(
        kkDashPath(
          Path()
            ..moveTo(plot.left, crisp)
            ..lineTo(plot.right, crisp),
          const <double>[5, 3],
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      );
      final String label = t.label ?? t.level?.word ?? kkFormatTick(t.value, g.yStep);
      final bool above = crisp - 12 >= plot.top;
      final TextPainter tp = kkLayoutText(
        label,
        theme.type.mono(9, weight: FontWeight.w700, spacingEm: 0.04, color: color),
        scaler: scaler,
      );
      final Offset origin = Offset(plot.right - 4 - tp.width, above ? crisp - 3 - tp.height : crisp + 3);
      // A plate in the panel colour keeps the label readable over the bars.
      canvas.drawRect((origin & tp.size).inflate(2), Paint()..color = c.bg100);
      tp.paint(canvas, origin);
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.labels != labels ||
      oldDelegate.mode != mode ||
      oldDelegate.levels != levels ||
      oldDelegate.thresholds != thresholds ||
      oldDelegate.yMin != yMin ||
      oldDelegate.yMax != yMax ||
      oldDelegate.axes != axes ||
      oldDelegate.plotPadding != plotPadding ||
      oldDelegate.barGap != barGap ||
      oldDelegate.groupPadding != groupPadding ||
      oldDelegate.showValues != showValues ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler ||
      oldDelegate.progress != progress;
}
