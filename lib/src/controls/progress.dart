import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/patterns.dart';
import '../widgets/text.dart';
import 'scan.dart';

String _percent(double value, int digits) => (value * 100).round().toString().padLeft(digits, '0');

/// A segmented progress bar: 8px segments that light up one by one.
///
/// [value] runs from 0 to 1; the lit length snaps down to whole segments, and
/// a change of value steps there in 9 jumps over 0.45s. A null [value] is
/// indeterminate: a quarter of the bar scans across in hard steps.
class KkProgress extends StatelessWidget {
  const KkProgress({
    super.key,
    required this.value,
    this.cjk,
    this.en,
    this.level,
    this.color,
    this.showValue = true,
    this.format,
    this.unit = '%',
    this.height = 6,
    this.minWidth = 160,
    this.semanticLabel,
  });

  /// A bar with no known end.
  const KkProgress.indeterminate({
    super.key,
    this.cjk,
    this.en,
    this.level,
    this.color,
    this.height = 6,
    this.minWidth = 160,
    this.semanticLabel,
  }) : value = null,
       showValue = false,
       format = null,
       unit = '%';

  /// Progress from 0 to 1, or null when it is unknown.
  final double? value;

  /// CJK title in the head.
  final String? cjk;

  /// Latin capitals subtitle in the head.
  final String? en;

  /// Colours the lit segments.
  final KkLevel? level;

  /// Overrides the level colour (or signal).
  final Color? color;

  /// Show the value at the right of the head.
  final bool showValue;

  /// Formats the value. By default it is a three-digit percentage: `078`.
  final String Function(double value)? format;

  /// Shown small after the value.
  final String unit;

  /// Height of the bar.
  final double height;

  /// The bar is never narrower than this (when it has the room).
  final double minWidth;

  /// Names the bar for screen readers. Defaults to [en].
  final String? semanticLabel;

  /// The lit length, in px, of a bar [width] wide at [value]: snapped down to
  /// the [pitch], except that a full bar is lit to its end.
  static double litWidth(double value, double width, {double pitch = 8}) {
    if (value.isNaN || width <= 0) return 0;
    final double v = value.clamp(0.0, 1.0);
    if (v >= 1) return width;
    if (pitch <= 0) return v * width;
    return math.min(width, ((v * width) / pitch + 1e-6).floorToDouble() * pitch);
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color lit = color ?? c.level(level);
    final double? raw = value;
    final double? v = raw == null ? null : (raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0));
    final String? cjkTitle = cjk;
    final String? enTitle = en;
    final bool valueShown = showValue && v != null;
    final bool hasHead = cjkTitle != null || enTitle != null || valueShown;
    final String text = v == null ? '' : (format?.call(v) ?? _percent(v, 3));

    Widget bar({double? fraction, double? scanStart}) => CustomPaint(
      size: Size(0, height),
      painter: _ProgressPainter(
        fraction: fraction,
        scanStart: scanStart,
        lit: lit,
        track: c.signalDim,
        pitch: m.pitchFine,
        gap: m.stroke2,
      ),
    );

    final Widget track;
    if (v == null) {
      final bool motion = KeikaiTheme.motionOf(context);
      track = KkPhaseBuilder(
        period: const Duration(milliseconds: 1600),
        phases: 20,
        builder: (BuildContext context, int phase, Widget? child) =>
            bar(scanStart: motion ? kkScanOffset(phase, 20) : 0.375),
      );
    } else {
      track = KkSteppedValue(value: v, builder: (BuildContext context, double shown) => bar(fraction: shown));
    }

    return Semantics(
      container: true,
      label: semanticLabel ?? enTitle ?? cjkTitle,
      value: v == null ? null : '$text$unit',
      child: KkBox(
        minWidth: minWidth,
        child: KkColumn(
          shrinkWrap: true,
          gap: 6,
          children: <Widget>[
            if (hasHead)
              ExcludeSemantics(
                child: KkRow(
                  gap: m.space2,
                  cross: KkCrossAlign.baseline,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    if (cjkTitle != null) KkText.cjk(cjkTitle, size: 13, height: 1.55, color: c.ink, squeeze: 0.8),
                    if (enTitle != null)
                      KkText.en(
                        enTitle,
                        size: 11,
                        weight: FontWeight.w600,
                        height: 1.55,
                        spacing: 0.14,
                        color: c.inkDim,
                      ),
                    const KkSpacer(),
                    if (valueShown)
                      KkRow(
                        shrinkWrap: true,
                        cross: KkCrossAlign.baseline,
                        gap: 2,
                        children: <Widget>[
                          KkText.num(text, size: 13, weight: FontWeight.w500, color: c.ink, style: _tabular),
                          if (unit.isNotEmpty)
                            KkText.num(unit, size: 10, weight: FontWeight.w500, color: c.inkDim, style: _tabular),
                        ],
                      ),
                  ],
                ),
              ),
            track,
          ],
        ),
      ),
    );
  }
}

/// Tabular figures without the slashed zero: progress values and ring text.
const TextStyle _tabular = TextStyle(fontFeatures: <FontFeature>[FontFeature.tabularFigures()]);

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.fraction,
    required this.scanStart,
    required this.lit,
    required this.track,
    required this.pitch,
    required this.gap,
  });

  /// Lit share of the bar, or null while scanning.
  final double? fraction;

  /// Left edge of the scanning window as a share of the bar.
  final double? scanStart;
  final Color lit;
  final Color track;
  final double pitch;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    kkPaintSegments(canvas, rect, track, pitch: pitch, gap: gap);
    Rect window;
    final double? f = fraction;
    if (f != null) {
      window = Rect.fromLTWH(0, 0, KkProgress.litWidth(f, size.width, pitch: pitch), size.height);
    } else {
      // The window travels in the scan's own steps, but only whole segments
      // of the bar light up inside it.
      final double start = ((scanStart ?? 0) * size.width / pitch).floorToDouble() * pitch;
      final double width = math.max(pitch, (size.width * 0.25 / pitch).floorToDouble() * pitch);
      window = Rect.fromLTWH(start, 0, width, size.height).intersect(rect);
    }
    if (window.width <= 0 || window.height <= 0) return;
    canvas.save();
    canvas.clipRect(window);
    kkPaintSegments(canvas, rect, lit, pitch: pitch, gap: gap);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.scanStart != scanStart ||
      oldDelegate.lit != lit ||
      oldDelegate.track != track ||
      oldDelegate.pitch != pitch ||
      oldDelegate.gap != gap;
}

/// A progress ring: a 4px arc over a dim track, with the value at the centre.
///
/// A null [value] is indeterminate: a quarter arc turns in 24 hard steps
/// every 1.2s.
class KkRing extends StatelessWidget {
  const KkRing({
    super.key,
    required this.value,
    this.size = 48,
    this.strokeWidth = 4,
    this.level,
    this.color,
    this.showValue = true,
    this.label,
    this.child,
    this.semanticLabel,
  });

  /// A ring with no known end.
  const KkRing.indeterminate({
    super.key,
    this.size = 48,
    this.strokeWidth = 4,
    this.level,
    this.color,
    this.child,
    this.semanticLabel,
  }) : value = null,
       showValue = false,
       label = null;

  /// Progress from 0 to 1, or null when it is unknown.
  final double? value;

  /// Outer diameter.
  final double size;
  final double strokeWidth;

  /// Colours the arc.
  final KkLevel? level;

  /// Overrides the level colour (or signal).
  final Color? color;

  /// Show the value at the centre.
  final bool showValue;

  /// Text at the centre instead of the percentage.
  final String? label;

  /// A widget at the centre instead of text.
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final Color arc = color ?? c.level(level);
    final double? raw = value;
    final double? v = raw == null ? null : (raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0));
    final String? text = label ?? (v == null || !showValue ? null : _percent(v, 2));

    Widget ring({required double start, required double sweep}) => CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(start: start, sweep: sweep, arc: arc, track: c.signalDim, stroke: strokeWidth),
    );

    final Widget drawn = v == null
        ? KkPhaseBuilder(
            period: const Duration(milliseconds: 1200),
            phases: 24,
            builder: (BuildContext context, int phase, Widget? child) =>
                ring(start: phase * 2 * math.pi / 24, sweep: math.pi / 2),
          )
        : KkSteppedValue(
            value: v,
            builder: (BuildContext context, double shown) => ring(start: 0, sweep: shown * 2 * math.pi),
          );
    final Widget? centre =
        child ??
        (text == null ? null : KkText.num(text, size: 13, weight: FontWeight.w500, color: c.ink, style: _tabular));
    return Semantics(
      container: true,
      label: semanticLabel,
      value: v == null ? null : '${(v * 100).round()}%',
      child: ExcludeSemantics(
        excluding: child == null,
        child: KkBox(
          width: size,
          height: size,
          child: KkLayers(
            alignment: Alignment.center,
            children: <Widget>[drawn, ?centre],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.start,
    required this.sweep,
    required this.arc,
    required this.track,
    required this.stroke,
  });

  /// Start angle, clockwise from twelve o'clock.
  final double start;
  final double sweep;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.shortestSide - stroke) / 2;
    if (radius <= 0) return;
    final Offset centre = size.center(Offset.zero);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(centre, radius, line..color = track);
    if (sweep <= 0) return;
    final Rect box = Rect.fromCircle(center: centre, radius: radius);
    if (sweep >= 2 * math.pi) {
      canvas.drawCircle(centre, radius, line..color = arc);
    } else {
      canvas.drawArc(box, start - math.pi / 2, sweep, false, line..color = arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.sweep != sweep ||
      oldDelegate.arc != arc ||
      oldDelegate.track != track ||
      oldDelegate.stroke != stroke;
}
