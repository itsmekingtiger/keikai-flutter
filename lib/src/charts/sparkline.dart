import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../motion/entrances.dart';
import '../painting/shapes.dart';
import 'plot.dart';
import 'scale.dart';

/// A small line of recent values, without axes: the trend beside a KPI or in
/// a table cell.
///
/// The line is 1.5px with round joins, the optional area under it is at 16%,
/// the last value is marked with a 5px square, and an optional [reference]
/// value is a dashed line. It fills the box it is given ([width] × [height],
/// 64 × 32 when free). Nulls are gaps. The line wipes in from the left.
class KkSparkline extends StatelessWidget {
  const KkSparkline({
    super.key,
    required this.values,
    this.color,
    this.level,
    this.area = true,
    this.dot = true,
    this.reference,
    this.min,
    this.max,
    this.width,
    this.height,
    this.animate = true,
    this.semanticLabel,
  });

  /// The values, oldest first. Null and non-finite values are gaps.
  final List<double?> values;

  /// Line colour. Defaults to the level colour, or series-1.
  final Color? color;

  /// Colours the line by a status level when no [color] is given.
  final KkLevel? level;

  /// Fill under the line.
  final bool area;

  /// Mark the last value.
  final bool dot;

  /// A value drawn as a dashed line (a target, a previous period).
  final double? reference;

  /// Bottom of the value range. Defaults to the smallest value.
  final double? min;

  /// Top of the value range. Defaults to the largest value.
  final double? max;

  /// Fixed width. By default it fills the width it is given (64 when free).
  final double? width;

  /// Fixed height. By default it fills the height it is given (32 when free).
  final double? height;

  /// Play the wipe-in when first shown.
  final bool animate;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final Color c = color ?? (level != null ? theme.colors.level(level) : theme.colors.series1);
    // A size that cannot be used (negative, NaN, infinite) is ignored.
    double? usable(double? v) => (v != null && v.isFinite && v >= 0) ? v : null;
    final double? width = usable(this.width);
    final double? height = usable(this.height);
    Widget child = KkOneShot(
      duration: KkMotion.wipe,
      delay: const Duration(milliseconds: 300),
      enabled: animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkCanvas(
          naturalWidth: width ?? 64,
          naturalHeight: height ?? 32,
          painter: _SparkPainter(
            values: values,
            color: c,
            referenceColor: theme.colors.line,
            area: area,
            dot: dot,
            reference: reference,
            min: min,
            max: max,
            progress: progress,
          ),
        );
      },
    );
    if (width != null || height != null) child = KkBox(width: width, height: height, child: child);
    final String? label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: child);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: child),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.referenceColor,
    required this.area,
    required this.dot,
    required this.reference,
    required this.min,
    required this.max,
    required this.progress,
  }) : super(repaint: progress);

  final List<double?> values;
  final Color color;
  final Color referenceColor;
  final bool area;
  final bool dot;
  final double? reference;
  final double? min;
  final double? max;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final int n = values.length;
    final double padV = math.min(2.5, size.height / 4);
    final double padL = math.min(0.75, size.width / 4);
    final double padR = math.min(dot ? 2.5 : 0.75, size.width / 4);
    final double? ref = reference;
    final KkLinearScale y = KkLinearScale.of(
      <double?>[...values, if (ref != null && ref.isFinite) ref],
      start: size.height - padV,
      end: padV,
      min: min,
      max: max,
      clamp: true,
    );
    double xOf(int i) => n <= 1 ? size.width - padR : padL + (size.width - padL - padR) * i / (n - 1);

    if (ref != null && ref.isFinite) {
      final Path dash = kkDashPath(
        Path()
          ..moveTo(0, y.map(ref))
          ..lineTo(size.width, y.map(ref)),
        const <double>[2, 2],
      );
      canvas.drawPath(
        dash,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = referenceColor,
      );
    }

    final double t = const KkSteps(KkMotion.wipeSteps).transform(progress.value.clamp(0.0, 1.0));
    if (t <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, -4, t >= 1 ? size.width + 4 : size.width * t, size.height + 4));

    final Path line = Path();
    final Path fill = Path();
    final Paint mark = Paint()..color = color;
    Offset? last;
    int runStart = -1;
    int runLength = 0;
    void closeRun(int endIndex) {
      if (runLength == 0) return;
      if (runLength == 1) {
        final Offset p = Offset(xOf(runStart), y.map(values[runStart]!));
        canvas.drawRect(Rect.fromCenter(center: p, width: 1.5, height: 1.5), mark);
      } else if (area) {
        fill
          ..lineTo(xOf(endIndex), size.height)
          ..lineTo(xOf(runStart), size.height)
          ..close();
      }
      runLength = 0;
    }

    for (int i = 0; i < n; i++) {
      final double? v = values[i];
      if (v == null || !v.isFinite) {
        closeRun(i - 1);
        continue;
      }
      final Offset p = Offset(xOf(i), y.map(v));
      if (runLength == 0) {
        runStart = i;
        line.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
        fill.lineTo(p.dx, p.dy);
      }
      runLength++;
      last = p;
    }
    closeRun(n - 1);

    if (area) canvas.drawPath(fill, Paint()..color = color.withValues(alpha: color.a * 0.16));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    final Offset? end = last;
    if (dot && end != null) {
      canvas.drawRect(Rect.fromCenter(center: end, width: 5, height: 5), mark);
    }
    canvas.restore();
  }

  // The data lists belong to the caller and may have been changed in place,
  // so a rebuild always repaints.
  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => true;
}
