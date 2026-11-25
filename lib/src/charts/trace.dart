import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/patterns.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';
import 'plot.dart';
import 'scale.dart';

/// A live waveform on a scope ground: a phosphor-green line with a soft glow
/// over a fine grid, its current value in the head.
///
/// The line is nominal green until the trace has a [level], then it takes the
/// level's colour. With [flowing] the waveform drifts to the left without
/// end, treating [samples] as one period. For real live data, rebuild with a
/// new sample list instead.
class KkTrace extends StatelessWidget {
  const KkTrace({
    super.key,
    required this.samples,
    this.cjk,
    this.en,
    this.value,
    this.level,
    this.color,
    this.min,
    this.max,
    this.frame = true,
    this.height = 96,
    this.flowing = false,
    this.flowPeriod = const Duration(seconds: 6),
    this.midline = true,
    this.glow = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// The waveform, oldest first. Null (or NaN) leaves a gap.
  final List<double?> samples;
  final String? cjk;
  final String? en;

  /// The current reading, shown at the right of the head (`048.2 Hz`).
  final String? value;

  /// Colours the line and the reading, and adds the status icon.
  final KkLevel? level;

  /// Overrides the line colour.
  final Color? color;

  /// Bottom of the scope. Defaults to the data, with a little headroom.
  final double? min;

  /// Top of the scope.
  final double? max;

  /// Draw the widget frame and head. False leaves just the scope.
  final bool frame;

  /// Height of the scope when the height is free.
  final double height;

  /// Drift the waveform to the left continuously.
  final bool flowing;

  /// Time for the whole waveform to pass once while [flowing].
  final Duration flowPeriod;

  /// Draw the centre line.
  final bool midline;

  /// Draw the phosphor glow under the line.
  final bool glow;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final Color ink = color ?? c.level(level, fallback: c.nominal);
    final KkGlow halo = level == null && color == null ? c.glowTrace : KkGlow(color: ink, ring: 0, blur: 3, alpha: 1);

    Widget paint(ValueListenable<Duration>? time) => KkCanvas(
      naturalWidth: 280,
      naturalHeight: height,
      painter: _TracePainter(
        samples: samples,
        color: ink,
        glow: glow ? halo : null,
        midColor: midline ? c.line : null,
        min: min,
        max: max,
        time: time,
        // The loop clock already runs at the theme's time scale.
        period: flowPeriod,
      ),
    );

    final Widget scope = KkBox(
      decoration: KkDecoration(
        fill: c.bg000,
        pattern: KkPattern.plot(
          minor: c.grid,
          major: c.signalDim,
          pitch: theme.metrics.pitchFine,
          majorEvery: 4,
          stroke: theme.metrics.stroke1,
        ),
      ),
      clip: true,
      child: flowing
          ? RepaintBoundary(
              child: KkLoop(builder: (BuildContext context, ValueListenable<Duration> time) => paint(time)),
            )
          : paint(null),
    );

    final String? reading = value;
    return KkChartFrame(
      frame: frame,
      cjk: cjk,
      en: en,
      boot: boot,
      semanticLabel: semanticLabel,
      semanticValue: <String>[?reading, ?level?.word].join(', '),
      trailing: reading == null
          ? null
          : KkRow(
              shrinkWrap: true,
              gap: 6,
              children: <Widget>[
                if (level != null) KkGlyph(level: level),
                KkText.num(reading, size: 13, weight: FontWeight.w500, color: ink),
              ],
            ),
      child: scope,
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.samples,
    required this.color,
    required this.glow,
    required this.midColor,
    required this.min,
    required this.max,
    required this.time,
    required this.period,
  }) : super(repaint: time);

  final List<double?> samples;
  final Color color;
  final KkGlow? glow;
  final Color? midColor;
  final double? min;
  final double? max;
  final ValueListenable<Duration>? time;
  final Duration period;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final Color? mid = midColor;
    if (mid != null) kkPaintHLine(canvas, 0, size.width, size.height / 2 - 0.5, mid);
    final int n = samples.length;
    if (n == 0) return;

    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (final double? v in samples) {
      if (v == null || !v.isFinite) continue;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    if (!lo.isFinite || !hi.isFinite) return;
    final double headroom = hi > lo ? (hi - lo) * 0.1 : 1;
    final double? pinnedMin = min;
    final double? pinnedMax = max;
    final KkLinearScale y = KkLinearScale(
      min: (pinnedMin != null && pinnedMin.isFinite) ? pinnedMin : lo - headroom,
      max: (pinnedMax != null && pinnedMax.isFinite) ? pinnedMax : hi + headroom,
      start: size.height - 1,
      end: 1,
      clamp: true,
    );

    final ValueListenable<Duration>? clock = time;
    final Path path = Path();
    if (clock == null && n == 1) {
      // A single sample is a flat line at its level.
      final double? only = samples.first;
      if (only != null && only.isFinite) {
        path
          ..moveTo(0, y.map(only))
          ..lineTo(size.width, y.map(only));
      }
    } else if (clock == null) {
      _trace(path, n, (int i) => size.width * i / (n - 1), y, wrap: false);
    } else {
      // One period of the waveform, drawn twice so the seam scrolls through.
      final double phase = kkLoopAt(clock.value, period);
      final double shift = -phase * size.width;
      _trace(path, n, (int i) => shift + size.width * i / n, y, wrap: true);
      _trace(path, n, (int i) => shift + size.width + size.width * i / n, y, wrap: true);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final KkGlow? g = glow;
    if (g != null && g.blur > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = kkFade(g.color, g.alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, g.blur / 2),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  void _trace(Path path, int n, double Function(int index) xOf, KkLinearScale y, {required bool wrap}) {
    bool pen = false;
    final int last = wrap ? n : n - 1;
    for (int i = 0; i <= last; i++) {
      final double? v = samples[i % n];
      if (v == null || !v.isFinite) {
        pen = false;
        continue;
      }
      final double x = xOf(i);
      final double py = y.map(v);
      if (pen) {
        path.lineTo(x, py);
      } else {
        path.moveTo(x, py);
        pen = true;
      }
    }
  }

  // The data lists belong to the caller and may have been changed in place,
  // so a rebuild always repaints.
  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
