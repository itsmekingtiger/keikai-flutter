import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../layout/layers.dart';
import '../painting/text.dart';
import 'format.dart';
import 'plot.dart';

/// What the crosshair of a [KkWaterfall] is over.
@immutable
class KkWaterfallProbe {
  const KkWaterfallProbe({required this.bin, required this.row, required this.frequency, required this.level});

  /// Column under the crosshair, from 0.
  final int bin;

  /// Row under the crosshair: 0 is the newest sweep.
  final int row;

  /// The frequency of [bin], when the waterfall was given a frequency span.
  final double? frequency;

  /// The level in that cell; null where there is no data.
  final double? level;

  @override
  bool operator ==(Object other) =>
      other is KkWaterfallProbe &&
      other.bin == bin &&
      other.row == row &&
      other.frequency == frequency &&
      other.level == level;

  @override
  int get hashCode => Object.hash(bin, row, frequency, level);

  @override
  String toString() => 'KkWaterfallProbe(bin: $bin, row: $row, frequency: $frequency, level: $level)';
}

/// A spectrum waterfall: the newest sweep as a line across the top, and under
/// it the recent sweeps as a pixelated spectrogram, newest row first, each
/// cell quantised to the six ramp steps.
///
/// A crosshair follows the pointer and reports the bin, the sweep and the
/// level under it. While the pointer rests and new sweeps arrive, the reading
/// follows the data and [onProbe] is called again.
class KkWaterfall extends StatefulWidget {
  const KkWaterfall({
    super.key,
    required this.rows,
    this.spectrum,
    this.capacity,
    this.min,
    this.max,
    this.startFrequency,
    this.endFrequency,
    this.axisLabels,
    this.frequencyFormat,
    this.levelFormat,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.height = 160,
    this.spectrumHeight = 32,
    this.legend = true,
    this.lowLabel,
    this.highLabel,
    this.onProbe,
    this.boot = true,
    this.semanticLabel,
  });

  /// The sweeps, newest first. Each sweep is one level per frequency bin.
  final List<List<double?>> rows;

  /// The line across the top. Defaults to the newest sweep.
  final List<double?>? spectrum;

  /// How many sweeps the spectrogram has room for. Defaults to the number of
  /// [rows] (at least 24).
  final int? capacity;

  /// The level of the darkest ramp step. Defaults to the smallest level.
  final double? min;

  /// The level of the hottest ramp step. Defaults to the largest level.
  final double? max;

  /// Frequency of the first bin, for the axis and the probe.
  final double? startFrequency;

  /// Frequency of the last bin.
  final double? endFrequency;

  /// Labels spread evenly under the spectrogram. By default five frequencies
  /// between [startFrequency] and [endFrequency].
  final List<String>? axisLabels;
  final String Function(double frequency)? frequencyFormat;
  final String Function(double level)? levelFormat;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the waterfall bare.
  final bool frame;

  /// Height of the spectrogram when the height is free.
  final double height;

  /// Height of the spectrum strip.
  final double spectrumHeight;

  /// Show the ramp with its end levels in the foot.
  final bool legend;

  /// Label at the dark end of the ramp. Defaults to the lowest level.
  final String? lowLabel;

  /// Label at the hot end of the ramp. Defaults to the highest level.
  final String? highLabel;

  /// The cell under the crosshair, or null when the pointer leaves.
  final ValueChanged<KkWaterfallProbe?>? onProbe;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkWaterfall> createState() => _KkWaterfallState();
}

class _WfGeometry {
  const _WfGeometry(this.spec, this.grid, this.bins, this.capacity);

  static const double axisHeight = 4 + 10 + 4;

  final Rect spec;
  final Rect grid;
  final int bins;
  final int capacity;

  double get cellWidth => bins > 0 ? grid.width / bins : 0;
  double get cellHeight => capacity > 0 ? grid.height / capacity : 0;

  static _WfGeometry? compute(
    Size size, {
    required int bins,
    required int capacity,
    required double spectrumHeight,
    required bool axis,
  }) {
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) return null;
    final double specHeight = math.min(spectrumHeight, size.height / 3);
    final double bottom = size.height - (axis ? axisHeight : 0);
    final Rect spec = Rect.fromLTWH(0, 0, size.width, specHeight);
    final Rect grid = Rect.fromLTRB(0, specHeight + 1, size.width, math.max(specHeight + 1, bottom));
    return _WfGeometry(spec, grid, bins, capacity);
  }
}

class _KkWaterfallState extends State<KkWaterfall> {
  final ValueNotifier<KkWaterfallProbe?> _probe = ValueNotifier<KkWaterfallProbe?>(null);

  int get _bins {
    int n = widget.spectrum?.length ?? 0;
    for (final List<double?> row in widget.rows) {
      n = math.max(n, row.length);
    }
    return n;
  }

  int get _capacity => math.max(1, widget.capacity ?? math.max(24, widget.rows.length));

  double get _spectrumHeight =>
      (widget.spectrumHeight.isFinite && widget.spectrumHeight > 0) ? widget.spectrumHeight : 0;

  List<String> _axis() {
    final List<String>? given = widget.axisLabels;
    if (given != null) return given;
    final double? a = widget.startFrequency;
    final double? b = widget.endFrequency;
    if (a == null || b == null || !a.isFinite || !b.isFinite) return const <String>[];
    String text(double v) => !v.isFinite ? '--' : (widget.frequencyFormat?.call(v) ?? kkPlain(v));
    return <String>[for (int i = 0; i < 5; i++) text(a + (b - a) * i / 4)];
  }

  double? _frequency(int bin, int bins) {
    final double? a = widget.startFrequency;
    final double? b = widget.endFrequency;
    if (a == null || b == null || !a.isFinite || !b.isFinite || bins <= 0) return null;
    return bins == 1 ? a : a + (b - a) * bin / (bins - 1);
  }

  void _setProbe(KkWaterfallProbe? probe) {
    if (_probe.value == probe) return;
    _probe.value = probe;
    widget.onProbe?.call(probe);
  }

  /// The reading of cell ([bin], [row]) as the data stands now.
  KkWaterfallProbe? _read(int bin, int row) {
    final int bins = _bins;
    if (bins == 0) return null;
    final int b = bin.clamp(0, bins - 1);
    final int r = row.clamp(0, _capacity - 1);
    double? level;
    if (r < widget.rows.length && b < widget.rows[r].length) {
      final double? v = widget.rows[r][b];
      if (v != null && v.isFinite) level = v;
    }
    return KkWaterfallProbe(bin: b, row: r, frequency: _frequency(b, bins), level: level);
  }

  KkWaterfallProbe? _probeAt(Offset position, Size size) {
    final int bins = _bins;
    final _WfGeometry? g = _WfGeometry.compute(
      size,
      bins: bins,
      capacity: _capacity,
      spectrumHeight: _spectrumHeight,
      axis: _axis().isNotEmpty,
    );
    if (g == null || bins == 0 || !(g.cellWidth > 0) || !(g.cellHeight > 0)) return null;
    if (position.dy < g.grid.top || position.dy >= g.grid.bottom) return null;
    return _read((position.dx / g.cellWidth).floor(), ((position.dy - g.grid.top) / g.cellHeight).floor());
  }

  @override
  void didUpdateWidget(KkWaterfall oldWidget) {
    super.didUpdateWidget(oldWidget);
    final KkWaterfallProbe? probe = _probe.value;
    if (probe == null) return;
    // The sweeps moved on under a resting crosshair: read its cell again.
    final KkWaterfallProbe? fresh = _read(probe.bin, probe.row);
    if (fresh != probe) {
      _probe.value = fresh;
      kkNotifyAfterFrame(this, () => widget.onProbe?.call(_probe.value));
    }
  }

  @override
  void dispose() {
    _probe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final int bins = _bins;
    final int capacity = _capacity;
    final List<String> axis = _axis();

    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (final List<double?> row in widget.rows) {
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
    final double low = (widget.min != null && widget.min!.isFinite) ? widget.min! : lo;
    final double high = (widget.max != null && widget.max!.isFinite) ? widget.max! : hi;
    String levelText(double v) => !v.isFinite ? '--' : (widget.levelFormat?.call(v) ?? kkPlain(v));
    String frequencyText(double v) => !v.isFinite ? '--' : (widget.frequencyFormat?.call(v) ?? kkPlain(v));

    final double spectrumHeight = _spectrumHeight;
    final double natural = spectrumHeight + 1 + widget.height + (axis.isEmpty ? 0 : _WfGeometry.axisHeight);
    final Widget plot = KkPlotPointer(
      cursor: SystemMouseCursors.precise,
      onMove: (Offset? position, Size size) => _setProbe(position == null ? null : _probeAt(position, size)),
      child: KkLayers(
        expand: true,
        children: <Widget>[
          RepaintBoundary(
            child: KkCanvas(
              naturalWidth: 300,
              naturalHeight: natural,
              isComplex: true,
              painter: _WaterfallPainter(
                rows: widget.rows,
                spectrum: widget.spectrum ?? (widget.rows.isEmpty ? const <double?>[] : widget.rows.first),
                bins: bins,
                capacity: capacity,
                low: low,
                high: high,
                spectrumHeight: spectrumHeight,
                axis: axis,
                theme: theme,
                scaler: scaler,
              ),
            ),
          ),
          KkPositioned.fill(
            child: CustomPaint(
              painter: _ProbePainter(
                probe: _probe,
                bins: bins,
                capacity: capacity,
                spectrumHeight: spectrumHeight,
                hasAxis: axis.isNotEmpty,
                levelText: levelText,
                frequencyText: frequencyText,
                theme: theme,
                scaler: scaler,
              ),
            ),
          ),
        ],
      ),
    );

    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: widget.rows.isEmpty
          ? 'no data'
          : '${widget.rows.length} sweeps, $bins bins, levels ${levelText(low)} to ${levelText(high)}',
      legend: widget.legend
          ? <Widget>[KkRampKey(low: widget.lowLabel ?? levelText(low), high: widget.highLabel ?? levelText(high))]
          : null,
      child: plot,
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  const _WaterfallPainter({
    required this.rows,
    required this.spectrum,
    required this.bins,
    required this.capacity,
    required this.low,
    required this.high,
    required this.spectrumHeight,
    required this.axis,
    required this.theme,
    required this.scaler,
  });

  final List<List<double?>> rows;
  final List<double?> spectrum;
  final int bins;
  final int capacity;
  final double low;
  final double high;
  final double spectrumHeight;
  final List<String> axis;
  final KeikaiThemeData theme;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final KkColors c = theme.colors;
    canvas.drawRect(Offset.zero & size, Paint()..color = c.bg000);
    final _WfGeometry? g = _WfGeometry.compute(
      size,
      bins: bins,
      capacity: capacity,
      spectrumHeight: spectrumHeight,
      axis: axis.isNotEmpty,
    );
    if (g == null) return;

    // Spectrum strip.
    kkPaintHLine(canvas, 0, size.width, g.spec.bottom, c.line);
    if (spectrum.isNotEmpty && g.spec.height > 2) {
      final int n = spectrum.length;
      final Path line = Path();
      bool pen = false;
      for (int i = 0; i < n; i++) {
        final double? v = spectrum[i];
        if (v == null || !v.isFinite) {
          pen = false;
          continue;
        }
        final double t = high > low ? ((v - low) / (high - low)).clamp(0.0, 1.0) : 0.5;
        final double x = n == 1 ? size.width / 2 : size.width * (i + 0.5) / n;
        final double y = g.spec.bottom - 2 - (g.spec.height - 4) * t;
        if (pen) {
          line.lineTo(x, y);
        } else {
          line.moveTo(x, y);
          pen = true;
        }
      }
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.signal,
      );
    }

    // Spectrogram: one rectangle per run of equal steps, no anti-aliasing.
    if (bins > 0 && g.grid.height > 0) {
      final List<Color> ramp = c.ramp;
      final Paint cell = Paint()..isAntiAlias = false;
      final double ch = g.cellHeight;
      final double cw = g.cellWidth;
      canvas.drawRect(g.grid, cell..color = ramp[0]);
      for (int r = 0; r < math.min(rows.length, capacity); r++) {
        final List<double?> row = rows[r];
        final double top = (g.grid.top + r * ch).floorToDouble();
        final double bottom = (g.grid.top + (r + 1) * ch).floorToDouble();
        if (bottom <= top) continue;
        int runStart = 0;
        int runStep = -1;
        for (int b = 0; b <= bins; b++) {
          final int step = b < bins ? kkRampStep(b < row.length ? row[b] : null, low, high) : -2;
          if (step == runStep) continue;
          if (runStep > 0) {
            canvas.drawRect(
              Rect.fromLTRB((runStart * cw).floorToDouble(), top, (b * cw).floorToDouble(), bottom),
              cell..color = ramp[runStep],
            );
          }
          runStart = b;
          runStep = step;
        }
      }
    }

    if (axis.isNotEmpty) {
      final TextStyle style = theme.type.mono(10, color: c.inkFaint);
      final double y = g.grid.bottom + 4;
      const double inset = 12;
      final double span = math.max(0, size.width - inset * 2);
      for (int i = 0; i < axis.length; i++) {
        final double t = axis.length == 1 ? 0.5 : i / (axis.length - 1);
        kkPaintText(
          canvas,
          axis[i],
          style,
          Offset(inset + span * t, y),
          align: Alignment(t * 2 - 1, -1),
          scaler: scaler,
        );
      }
    }
  }

  // The data lists belong to the caller and may have been changed in place,
  // so a rebuild always repaints.
  @override
  bool shouldRepaint(_WaterfallPainter oldDelegate) => true;
}

class _ProbePainter extends CustomPainter {
  _ProbePainter({
    required this.probe,
    required this.bins,
    required this.capacity,
    required this.spectrumHeight,
    required this.hasAxis,
    required this.levelText,
    required this.frequencyText,
    required this.theme,
    required this.scaler,
  }) : super(repaint: probe);

  final ValueNotifier<KkWaterfallProbe?> probe;
  final int bins;
  final int capacity;
  final double spectrumHeight;
  final bool hasAxis;
  final String Function(double level) levelText;
  final String Function(double frequency) frequencyText;
  final KeikaiThemeData theme;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final KkWaterfallProbe? p = probe.value;
    if (p == null) return;
    final _WfGeometry? g = _WfGeometry.compute(
      size,
      bins: bins,
      capacity: capacity,
      spectrumHeight: spectrumHeight,
      axis: hasAxis,
    );
    if (g == null || !(g.cellWidth > 0) || !(g.cellHeight > 0)) return;
    final KkColors c = theme.colors;
    final double x = (p.bin + 0.5) * g.cellWidth;
    final double y = g.grid.top + (p.row + 0.5) * g.cellHeight;
    kkPaintVLine(canvas, x, 0, g.grid.bottom, c.inkDim);
    kkPaintHLine(canvas, 0, size.width, y, c.inkDim);
    final double? frequency = p.frequency;
    final double? level = p.level;
    kkPaintChartTip(
      canvas,
      Offset.zero & size,
      Offset(x, y),
      title: 'SWEEP -${p.row.toString().padLeft(2, '0')}',
      rows: <KkTipRow>[
        KkTipRow(name: 'FREQ', value: frequency == null ? 'BIN ${p.bin}' : frequencyText(frequency)),
        KkTipRow(name: 'LEVEL', value: level == null ? '--' : levelText(level)),
      ],
      theme: theme,
      scaler: scaler,
    );
  }

  @override
  bool shouldRepaint(_ProbePainter oldDelegate) =>
      oldDelegate.probe != probe ||
      oldDelegate.bins != bins ||
      oldDelegate.capacity != capacity ||
      oldDelegate.spectrumHeight != spectrumHeight ||
      oldDelegate.hasAxis != hasAxis ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler;
}
