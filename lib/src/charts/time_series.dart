import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../motion/entrances.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/frame.dart';
import 'format.dart';
import 'plot.dart';
import 'scale.dart';
import 'series.dart';

/// How a line joins its points.
enum KkLineShape {
  /// Straight segments from point to point.
  linear,

  /// Hold each value until the next point, then jump: for states and counts
  /// that change in steps.
  step,
}

/// Lines and areas over time (or over any numeric x).
///
/// Up to three series take the fixed series colours; fold more into OTHER
/// with `kkGroupOther`. Grid lines sit on round y values, tick labels are 10px
/// faint mono, limit lines ([thresholds]) are dashed in their level's colour.
/// Hovering, dragging a finger along the plot, or the arrow keys move a
/// crosshair that marks each series and opens a tooltip.
///
/// Each line wipes in from the left (0.8s in 16 steps, 90ms apart). The plot
/// is [height] tall when the height is free and fills a fixed-height parent.
///
/// To link the crosshairs of charts that share an x axis, pass the index one
/// chart reports through [onPointHover] to the [cursor] of the others.
class KkTimeSeries extends StatefulWidget {
  const KkTimeSeries({
    super.key,
    required this.series,
    this.times,
    this.x,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.thresholds = const <KkThreshold>[],
    this.yMin,
    this.yMax,
    this.includeZero = false,
    this.shape = KkLineShape.linear,
    this.height = 140,
    this.legend,
    this.axes = true,
    this.plotPadding,
    this.xFormat,
    this.yFormat,
    this.valueFormat,
    this.interactive = true,
    this.focusable = true,
    this.cursor,
    this.onPointHover,
    this.onPointTap,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// The lines. Null and non-finite values are gaps.
  final List<KkSeries> series;

  /// The instant of each point. Gives a UTC time axis with round ticks.
  final List<DateTime>? times;

  /// The x position of each point when it is not a time. Without [times] and
  /// [x] the points are evenly spaced and numbered from 0.
  final List<double>? x;

  final String? cjk;
  final String? en;

  /// Short mono text at the right of the head (a unit, a window).
  final String? meta;

  /// Draw the widget frame and head. False leaves the chart bare.
  final bool frame;

  /// Dashed limit lines across the plot; the y axis stretches to show them.
  final List<KkThreshold> thresholds;

  /// Pins the bottom of the y axis. By default it follows the data.
  final double? yMin;

  /// Pins the top of the y axis.
  final double? yMax;

  /// Stretch the y axis to include 0.
  final bool includeZero;

  /// How the points of a line are joined.
  final KkLineShape shape;

  /// Height of the plot when the height is free.
  final double height;

  /// Show the legend. Defaults to true when there is more than one series.
  final bool? legend;

  /// Draw the grid, the axis lines and the tick labels.
  final bool axes;

  /// Insets of the plot area inside the canvas. By default they are measured
  /// from the tick labels.
  final EdgeInsets? plotPadding;

  /// Labels an x value on the axis and in the tooltip.
  final String Function(double x)? xFormat;

  /// Labels a y tick.
  final String Function(double y)? yFormat;

  /// Formats a value in the tooltip.
  final String Function(double value)? valueFormat;

  /// React to hover, touch and taps.
  final bool interactive;

  /// Let the plot take keyboard focus (arrow keys move the crosshair).
  final bool focusable;

  /// Where to hold the crosshair while neither the pointer nor the keyboard
  /// has it on this chart: the index of a point, or null for none. An index
  /// with no point is ignored.
  final int? cursor;

  /// The index under the crosshair, or null when it leaves.
  final ValueChanged<int?>? onPointHover;

  /// The index that was tapped (or activated with Enter).
  final ValueChanged<int>? onPointTap;

  /// Play the wipe-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkTimeSeries> createState() => _KkTimeSeriesState();
}

class _Line {
  const _Line(this.name, this.values, this.color, this.area, this.line);

  final String name;
  final List<double?> values;
  final Color color;
  final bool area;
  final bool line;
}

class _TsData {
  const _TsData(this.lines, this.xs, this.isTime, this.isIndex);

  final List<_Line> lines;
  final List<double> xs;
  final bool isTime;
  final bool isIndex;

  int get count => xs.length;

  static _TsData from(KkTimeSeries w, KkColors colors) {
    int n = 0;
    for (final KkSeries s in w.series) {
      n = math.max(n, s.values.length);
    }
    List<double>? given;
    bool isTime = false;
    if (w.times != null) {
      given = <double>[for (final DateTime t in w.times!) kkEpochSeconds(t)];
      isTime = true;
    } else if (w.x != null) {
      given = w.x;
    }
    if (given != null) n = math.min(n, given.length);
    final bool usable = given != null && given.take(n).every((double v) => v.isFinite);
    final List<double> xs = usable ? given.sublist(0, n) : <double>[for (int i = 0; i < n; i++) i.toDouble()];
    return _TsData(
      <_Line>[
        for (int k = 0; k < w.series.length; k++)
          _Line(
            w.series[k].name,
            <double?>[
              for (int i = 0; i < n; i++)
                (i < w.series[k].values.length && kkIsFinite(w.series[k].values[i])) ? w.series[k].values[i] : null,
            ],
            w.series[k].color ?? kkSeriesColor(colors, k),
            w.series[k].area,
            w.series[k].line,
          ),
      ],
      xs,
      isTime && usable,
      !usable,
    );
  }
}

class _TsGeometry {
  const _TsGeometry({
    required this.plot,
    required this.y,
    required this.yTicks,
    required this.yStep,
    required this.px,
    required this.xTicks,
    required this.xStep,
  });

  final Rect plot;
  final KkLinearScale y;
  final List<double> yTicks;
  final double yStep;

  /// The x pixel of every point.
  final List<double> px;
  final List<double> xTicks;
  final double xStep;

  int? indexAt(double dx) {
    if (px.isEmpty) return null;
    int best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < px.length; i++) {
      final double d = (px[i] - dx).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  static _TsGeometry? compute(
    Size size,
    _TsData data, {
    required List<KkThreshold> thresholds,
    required double? yMin,
    required double? yMax,
    required bool includeZero,
    required bool axes,
    required EdgeInsets? plotPadding,
    required String Function(double y, double step) yLabel,
    required TextStyle tickStyle,
    required TextScaler scaler,
  }) {
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) return null;
    final KkLinearScale raw = KkLinearScale.of(<double?>[
      for (final _Line l in data.lines) ...l.values,
      for (final KkThreshold t in thresholds) t.value,
    ], zero: includeZero);
    const double top = 10;
    const double right = 12;
    final double bottom = axes ? 22 : 6;
    final double roughHeight = math.max(0, size.height - (plotPadding?.vertical ?? top + bottom));
    final int tickCount = (roughHeight / 36).floor().clamp(2, 8);
    final KkLinearScale niced = raw.nice(tickCount);
    final bool pinMin = yMin != null && yMin.isFinite;
    final bool pinMax = yMax != null && yMax.isFinite;
    KkLinearScale ys = KkLinearScale(min: pinMin ? yMin : niced.min, max: pinMax ? yMax : niced.max);
    if (ys.min >= ys.max) {
      // Pinned ends that leave no extent: open the axis up around the lower one.
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
      final double left = axes ? 8 + labelWidth + 6 : 6;
      plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    }
    if (!(plot.width > 0) || !(plot.height > 0)) return null;
    ys = ys.withRange(plot.bottom, plot.top);

    final int n = data.count;
    double xMin = double.infinity;
    double xMax = double.negativeInfinity;
    for (final double v in data.xs) {
      xMin = math.min(xMin, v);
      xMax = math.max(xMax, v);
    }
    final List<double> px = <double>[
      for (int i = 0; i < n; i++)
        if (n == 1)
          plot.center.dx
        else if (xMax > xMin)
          plot.left + (data.xs[i] - xMin) / (xMax - xMin) * plot.width
        else
          plot.left + plot.width * i / (n - 1),
    ];

    List<double> xTicks = const <double>[];
    double xStep = 1;
    if (n > 0 && xMax > xMin) {
      final int count = (plot.width / 80).floor().clamp(2, 12);
      if (data.isTime) {
        xStep = kkTimeStep(xMax - xMin, count);
        xTicks = kkTimeTicks(xMin, xMax, count: count);
      } else {
        xStep = kkNiceStep(xMax - xMin, count);
        if (data.isIndex && xStep < 1) xStep = 1;
        xTicks = kkNiceTicks(xMin, xMax, count);
        if (data.isIndex) {
          xTicks = <double>[
            for (final double t in xTicks)
              if (t == t.roundToDouble()) t,
          ];
        }
      }
    } else if (n == 1) {
      xTicks = <double>[data.xs.first];
    }
    return _TsGeometry(plot: plot, y: ys, yTicks: yTicks, yStep: yStep, px: px, xTicks: xTicks, xStep: xStep);
  }
}

class _KkTimeSeriesState extends State<KkTimeSeries> {
  final ValueNotifier<int?> _active = ValueNotifier<int?>(null);
  _TsData? _data;

  TextStyle _tickStyle(KeikaiThemeData theme) => theme.type.mono(10, color: theme.colors.inkFaint);

  String _yLabel(double v, double step) => widget.yFormat?.call(v) ?? kkFormatTick(v, step);

  _TsGeometry? _geometry(Size size) {
    final _TsData? data = _data;
    if (data == null) return null;
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    return _TsGeometry.compute(
      size,
      data,
      thresholds: widget.thresholds,
      yMin: widget.yMin,
      yMax: widget.yMax,
      includeZero: widget.includeZero,
      axes: widget.axes,
      plotPadding: widget.plotPadding,
      yLabel: _yLabel,
      tickStyle: _tickStyle(theme),
      scaler: MediaQuery.textScalerOf(context),
    );
  }

  void _setActive(int? index) {
    if (_active.value == index) return;
    _active.value = index;
    widget.onPointHover?.call(index);
  }

  void _onMove(Offset? position, Size size) {
    if (position == null) {
      _setActive(null);
      return;
    }
    _setActive(_geometry(size)?.indexAt(position.dx));
  }

  void _onTap(Offset position, Size size) {
    final int? index = _geometry(size)?.indexAt(position.dx);
    if (index != null) widget.onPointTap?.call(index);
  }

  void _step(int dx, int dy) {
    final int n = _data?.count ?? 0;
    if (n == 0 || dx == 0) return;
    // Start from where the crosshair is shown, be it ours or the linked one.
    final int? linked = widget.cursor;
    final int? current = _active.value ?? ((linked != null && linked >= 0 && linked < n) ? linked : null);
    _setActive(current == null ? (dx > 0 ? 0 : n - 1) : (current + dx).clamp(0, n - 1));
  }

  @override
  void didUpdateWidget(KkTimeSeries oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? active = _active.value;
    if (active == null) return;
    if (!widget.interactive) {
      // Nothing can move the crosshair away any more: let go of it.
      _active.value = null;
      kkNotifyAfterFrame(this, () => widget.onPointHover?.call(_active.value));
      return;
    }
    int n = 0;
    for (final KkSeries s in widget.series) {
      n = math.max(n, s.values.length);
    }
    if (active >= n) {
      // The data shrank under the crosshair: move it to the last point.
      _active.value = n == 0 ? null : n - 1;
      kkNotifyAfterFrame(this, () => widget.onPointHover?.call(_active.value));
    }
  }

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  String _summary(_TsData data) {
    final List<String> parts = <String>[];
    for (final _Line l in data.lines) {
      double? last;
      for (final double? v in l.values) {
        if (v != null) last = v;
      }
      parts.add('${l.name} ${last == null ? 'no data' : (widget.valueFormat?.call(last) ?? last.toStringAsFixed(1))}');
    }
    return parts.isEmpty ? 'no data' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final _TsData data = _TsData.from(widget, theme.colors);
    _data = data;
    final KkCascade cascade = KkCascade(
      count: data.lines.length,
      item: KkMotion.wipe,
      step: const Duration(milliseconds: 90),
    );

    Widget plot = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 300),
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkCanvas(
          naturalHeight: widget.height,
          painter: _TsPainter(
            data: data,
            thresholds: widget.thresholds,
            yMin: widget.yMin,
            yMax: widget.yMax,
            includeZero: widget.includeZero,
            axes: widget.axes,
            plotPadding: widget.plotPadding,
            shape: widget.shape,
            theme: theme,
            scaler: scaler,
            tickStyle: _tickStyle(theme),
            yLabel: _yLabel,
            xFormat: widget.xFormat,
            valueFormat: widget.valueFormat,
            cascade: cascade,
            progress: progress,
            active: _active,
            cursor: widget.cursor,
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
          final int n = data.count;
          if (n > 0) _setActive(toEnd ? n - 1 : 0);
        },
        onActivate: () {
          final int? index = _active.value;
          if (index != null) widget.onPointTap?.call(index);
        },
        onDismiss: () => _setActive(null),
        child: plot,
      );
    }

    final bool showLegend = widget.legend ?? data.lines.length > 1;
    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: _summary(data),
      legend: showLegend
          ? <Widget>[for (final _Line l in data.lines) KkWidgetKey(label: l.name, color: l.color, box: !l.line)]
          : null,
      child: plot,
    );
  }
}

class _TsPainter extends CustomPainter {
  _TsPainter({
    required this.data,
    required this.thresholds,
    required this.yMin,
    required this.yMax,
    required this.includeZero,
    required this.axes,
    required this.plotPadding,
    required this.shape,
    required this.theme,
    required this.scaler,
    required this.tickStyle,
    required this.yLabel,
    required this.xFormat,
    required this.valueFormat,
    required this.cascade,
    required this.progress,
    required this.active,
    required this.cursor,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, active]));

  final _TsData data;
  final List<KkThreshold> thresholds;
  final double? yMin;
  final double? yMax;
  final bool includeZero;
  final bool axes;
  final EdgeInsets? plotPadding;
  final KkLineShape shape;
  final KeikaiThemeData theme;
  final TextScaler scaler;
  final TextStyle tickStyle;
  final String Function(double y, double step) yLabel;
  final String Function(double x)? xFormat;
  final String Function(double value)? valueFormat;
  final KkCascade cascade;
  final Animation<double> progress;
  final ValueNotifier<int?> active;

  /// Where the crosshair is held while [active] is null.
  final int? cursor;

  String _xLabel(double x, double step) {
    final String Function(double x)? f = xFormat;
    if (f != null) return f(x);
    if (data.isTime) return kkTimeTickLabel(x, step);
    if (data.isIndex) return x.round().toString();
    return kkFormatTick(x, step);
  }

  String _xTitle(double x, double step) {
    final String Function(double x)? f = xFormat;
    if (f != null) return f(x);
    // Down to the millisecond when the axis itself is finer than seconds.
    if (data.isTime) return '${step < 1 ? kkTimeTickLabel(x, 0.001) : kkTimeLabel(x, seconds: true)}Z';
    if (data.isIndex) return x.round().toString();
    return kkFormatTick(x, step / 10);
  }

  String _value(double v, double step) {
    final String Function(double value)? f = valueFormat;
    if (f != null) return f(v);
    return v.toStringAsFixed(math.min(kkTickDecimals(step) + 1, 4));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _TsGeometry? g = _TsGeometry.compute(
      size,
      data,
      thresholds: thresholds,
      yMin: yMin,
      yMax: yMax,
      includeZero: includeZero,
      axes: axes,
      plotPadding: plotPadding,
      yLabel: yLabel,
      tickStyle: tickStyle,
      scaler: scaler,
    );
    if (g == null) return;
    final KkColors c = theme.colors;
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
      kkPaintHLine(canvas, plot.left, plot.right, plot.bottom, c.line);
      _paintXLabels(canvas, size, g);
    }

    _paintThresholds(canvas, g, c, labels: false);

    final double baseline = g.y.min <= 0 && g.y.max >= 0 ? g.y.map(0) : (g.y.min > 0 ? plot.bottom : plot.top);
    for (int k = 0; k < data.lines.length; k++) {
      final double t = cascade.at(progress.value, k, steps: KkMotion.wipeSteps);
      if (t <= 0) continue;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          plot.left - 2,
          plot.top - 2,
          t >= 1 ? plot.right + 2 : plot.left + plot.width * t,
          plot.bottom + 2,
        ),
      );
      _paintLine(canvas, g, data.lines[k], baseline);
      canvas.restore();
    }
    // Labels go over the series so a line crossing one cannot strike it out.
    _paintThresholds(canvas, g, c, labels: true);

    final int? index = active.value ?? cursor;
    if (index != null && index >= 0 && index < g.px.length) {
      final double x = g.px[index];
      kkPaintVLine(canvas, x, plot.top, plot.bottom, c.inkDim);
      final List<KkTipRow> rows = <KkTipRow>[];
      for (final _Line l in data.lines) {
        final double? v = l.values[index];
        rows.add(KkTipRow(color: l.color, name: l.name, value: v == null ? '--' : _value(v, g.yStep), box: !l.line));
        if (v == null) continue;
        final Offset p = Offset(x, g.y.map(v).clamp(plot.top, plot.bottom));
        canvas.drawCircle(p, 4.5, Paint()..color = c.bg100);
        canvas.drawCircle(p, 2.5, Paint()..color = l.color);
      }
      kkPaintChartTip(
        canvas,
        Offset.zero & size,
        Offset(x, plot.top + plot.height / 2),
        title: _xTitle(data.xs[index], g.xStep),
        rows: rows,
        theme: theme,
        scaler: scaler,
      );
    }
  }

  void _paintXLabels(Canvas canvas, Size size, _TsGeometry g) {
    if (g.px.isEmpty || data.xs.isEmpty) return;
    final Rect plot = g.plot;
    double xMin = double.infinity;
    double xMax = double.negativeInfinity;
    for (final double v in data.xs) {
      xMin = math.min(xMin, v);
      xMax = math.max(xMax, v);
    }
    double lastRight = double.negativeInfinity;
    for (final double tick in g.xTicks) {
      final double x = xMax > xMin ? plot.left + (tick - xMin) / (xMax - xMin) * plot.width : plot.center.dx;
      final TextPainter tp = kkLayoutText(_xLabel(tick, g.xStep), tickStyle, scaler: scaler);
      final double left = (x - tp.width / 2).clamp(0.0, math.max(0.0, size.width - tp.width));
      if (left >= lastRight + 8) {
        tp.paint(canvas, Offset(left, plot.bottom + 6));
        lastRight = left + tp.width;
      }
      tp.dispose();
    }
  }

  /// The dashed limit lines ([labels] false, under the series) or their labels
  /// ([labels] true, over the series).
  void _paintThresholds(Canvas canvas, _TsGeometry g, KkColors c, {required bool labels}) {
    final Rect plot = g.plot;
    for (final KkThreshold t in thresholds) {
      if (!t.value.isFinite) continue;
      final double y = g.y.map(t.value);
      if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
      final Color color = t.color ?? (t.level == null ? c.inkDim : c.level(t.level));
      final double crisp = y.roundToDouble() + 0.5;
      if (!labels) {
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
        continue;
      }
      final String label = t.label ?? t.level?.word ?? kkFormatTick(t.value, g.yStep);
      final TextStyle style = theme.type.mono(9, weight: FontWeight.w700, spacingEm: 0.04, color: color);
      final bool above = crisp - 12 >= plot.top;
      final TextPainter tp = kkLayoutText(label, style, scaler: scaler);
      final Offset origin = Offset(plot.right - 4 - tp.width, above ? crisp - 3 - tp.height : crisp + 3);
      // A plate in the panel colour keeps the label readable over the lines.
      canvas.drawRect((origin & tp.size).inflate(2), Paint()..color = c.bg100);
      tp.paint(canvas, origin);
      tp.dispose();
    }
  }

  void _paintLine(Canvas canvas, _TsGeometry g, _Line l, double baseline) {
    final Path line = Path();
    final Path fill = Path();
    final Paint dot = Paint()..color = l.color;
    int runStart = -1;
    int runLength = 0;
    double lastX = 0;
    double lastY = 0;

    void closeRun() {
      if (runLength == 0) return;
      if (runLength == 1) {
        if (l.line) canvas.drawRect(Rect.fromCenter(center: Offset(lastX, lastY), width: 3, height: 3), dot);
        if (l.area) {
          canvas.drawRect(
            Rect.fromLTRB(lastX - 1, math.min(lastY, baseline), lastX + 1, math.max(lastY, baseline)),
            Paint()..color = l.color.withValues(alpha: l.color.a * 0.14),
          );
        }
      } else if (l.area) {
        fill
          ..lineTo(lastX, baseline)
          ..lineTo(g.px[runStart], baseline)
          ..close();
      }
      runLength = 0;
    }

    for (int i = 0; i < g.px.length; i++) {
      final double? v = l.values[i];
      if (v == null) {
        closeRun();
        continue;
      }
      final double x = g.px[i];
      // A value far off a pinned axis must not put an infinity into the path.
      final double y = g.y.map(v).clamp(g.plot.top - 1e5, g.plot.bottom + 1e5);
      if (runLength == 0) {
        runStart = i;
        line.moveTo(x, y);
        fill.moveTo(x, y);
      } else {
        if (shape == KkLineShape.step) {
          line.lineTo(x, lastY);
          fill.lineTo(x, lastY);
        }
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
      runLength++;
      lastX = x;
      lastY = y;
    }
    closeRun();

    if (l.area) canvas.drawPath(fill, Paint()..color = l.color.withValues(alpha: l.color.a * 0.14));
    if (l.line) {
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = l.color,
      );
    }
  }

  @override
  bool shouldRepaint(_TsPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.thresholds != thresholds ||
      oldDelegate.yMin != yMin ||
      oldDelegate.yMax != yMax ||
      oldDelegate.includeZero != includeZero ||
      oldDelegate.axes != axes ||
      oldDelegate.plotPadding != plotPadding ||
      oldDelegate.shape != shape ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler ||
      oldDelegate.progress != progress ||
      oldDelegate.cascade.count != cascade.count;
}
