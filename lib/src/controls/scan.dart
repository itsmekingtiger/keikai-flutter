import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../motion/loops.dart';

/// Where the left edge of a scanning bar sits at [phase] of [steps], as a
/// fraction of the track width.
///
/// The bar is [widthFactor] of the track wide; it starts fully off the left
/// edge and ends fully off the right one (`translateX(-100%)` to
/// `translateX(400%)` of its own width for a quarter-width bar).
double kkScanOffset(int phase, int steps, {double widthFactor = 0.25}) {
  final double travel = 1 + widthFactor;
  return -widthFactor + travel * (phase % steps) / steps;
}

/// A bar that crosses its track in hard steps: the indeterminate motion of
/// progress bars, skeleton lines and loading rails.
///
/// It paints only the moving bar, clipped to its own box; give it a
/// background by placing it in a filled [KkBox]. With motion off the bar
/// rests at [restAt] (a fraction of the track width).
class KkScanBar extends StatelessWidget {
  const KkScanBar({
    super.key,
    required this.color,
    this.period = const Duration(milliseconds: 1600),
    this.steps = 20,
    this.widthFactor = 0.25,
    this.restAt = 0,
    this.height,
    this.enabled = true,
  }) : assert(steps > 0),
       assert(widthFactor > 0 && widthFactor <= 1);

  final Color color;

  /// Time for one crossing.
  final Duration period;

  /// Number of jumps per crossing.
  final int steps;

  /// Width of the bar as a fraction of the track.
  final double widthFactor;

  /// Left edge of the bar, as a fraction of the track, when motion is off.
  final double restAt;

  /// Height of the bar; by default it fills the height it is given.
  final double? height;

  /// Stops the scan (the bar rests) without removing it.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool motion = enabled && KeikaiTheme.motionOf(context);
    return KkPhaseBuilder(
      period: period,
      phases: steps,
      enabled: enabled,
      builder: (BuildContext context, int phase, Widget? child) {
        return CustomPaint(
          size: Size(0, height ?? 0),
          painter: _ScanPainter(
            color: color,
            start: motion ? kkScanOffset(phase, steps, widthFactor: widthFactor) : restAt,
            widthFactor: widthFactor,
          ),
        );
      },
    );
  }
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter({required this.color, required this.start, required this.widthFactor});

  final Color color;
  final double start;
  final double widthFactor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect bar = Rect.fromLTWH(start * size.width, 0, widthFactor * size.width, size.height);
    final Rect visible = bar.intersect(Offset.zero & size);
    if (visible.width <= 0 || visible.height <= 0) return;
    canvas.drawRect(visible, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.start != start || oldDelegate.widthFactor != widthFactor;
}
