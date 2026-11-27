import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The repeating patterns of KEIKAI. All of them use hard stops only: no
/// smooth gradients anywhere in the language.
@immutable
sealed class KkPattern {
  const KkPattern();

  /// The 24px screen background grid.
  const factory KkPattern.grid({required Color color, double pitch, double stroke}) = KkGridPattern;

  /// The plot ground of traces and charts: a fine grid with a major grid on top.
  const factory KkPattern.plot({
    required Color minor,
    required Color major,
    double pitch,
    int majorEvery,
    double stroke,
  }) = KkPlotPattern;

  /// 45° stripes: the hazard band, and the hatches that mark offline surfaces.
  const factory KkPattern.stripes({
    required Color a,
    Color? b,
    double width,
    double? period,
    double shift,
    bool tiled,
  }) = KkStripePattern;

  /// The hexagon field behind alarm zones.
  const factory KkPattern.hex({required Color color, double pitch, double opacity}) = KkHexPattern;

  /// CRT scan lines over large display panels.
  const factory KkPattern.scanlines({required Color color, double on, double off}) = KkScanPattern;

  /// The segmented bar of meters, sliders and progress.
  const factory KkPattern.segments({required Color color, double pitch, double gap}) = KkSegmentPattern;

  /// A ruler of 1px ticks.
  const factory KkPattern.ticks({required Color color, double pitch, double stroke}) = KkTickPattern;

  /// Paints the pattern clipped to [rect].
  ///
  /// The patterns made of straight lines (grid, plot, scan lines, segments and
  /// ticks) count their lines from the whole pixel nearest to the top-left
  /// corner of [rect]. A rectangle that starts between two pixels still gets
  /// lines of full strength then, not lines smeared over two rows or columns.
  void paint(Canvas canvas, Rect rect);
}

/// The whole pixel nearest to [v], and the inner one where two are equally
/// near, give or take the last digit of the sums that placed the rectangle.
/// The line patterns start to count there.
double _wholePixel(double v) => (v + 0.5 + 1e-6).floorToDouble();

class KkGridPattern extends KkPattern {
  const KkGridPattern({required this.color, this.pitch = 24, this.stroke = 1});

  final Color color;
  final double pitch;
  final double stroke;

  @override
  void paint(Canvas canvas, Rect rect) => kkPaintGrid(canvas, rect, color, pitch, stroke: stroke);

  @override
  bool operator ==(Object other) =>
      other is KkGridPattern && other.color == color && other.pitch == pitch && other.stroke == stroke;

  @override
  int get hashCode => Object.hash(color, pitch, stroke);
}

class KkPlotPattern extends KkPattern {
  const KkPlotPattern({
    required this.minor,
    required this.major,
    this.pitch = 8,
    this.majorEvery = 8,
    this.stroke = 1,
  });

  final Color minor;
  final Color major;
  final double pitch;
  final int majorEvery;
  final double stroke;

  @override
  void paint(Canvas canvas, Rect rect) {
    kkPaintGrid(canvas, rect, minor, pitch, stroke: stroke);
    kkPaintGrid(canvas, rect, major, pitch * majorEvery, stroke: stroke);
  }

  @override
  bool operator ==(Object other) =>
      other is KkPlotPattern &&
      other.minor == minor &&
      other.major == major &&
      other.pitch == pitch &&
      other.majorEvery == majorEvery &&
      other.stroke == stroke;

  @override
  int get hashCode => Object.hash(minor, major, pitch, majorEvery, stroke);
}

class KkStripePattern extends KkPattern {
  const KkStripePattern({
    required this.a,
    this.b,
    this.width = 12,
    this.period,
    this.shift = 0,
    this.tiled = false,
  });

  /// Stripe colour.
  final Color a;

  /// Colour between stripes; null leaves it clear.
  final Color? b;

  /// Width of one [a] stripe, measured across the stripe.
  final double width;

  /// Distance from one [a] stripe to the next. Defaults to twice [width].
  final double? period;

  /// Horizontal shift in px (a running hazard animates this).
  final double shift;

  /// Anchor the stripes to the top-left tile grid instead of the bottom-right
  /// corner. Running hazards are tiled so the loop has no seam.
  final bool tiled;

  @override
  void paint(Canvas canvas, Rect rect) =>
      kkPaintStripes(canvas, rect, a: a, b: b, width: width, period: period ?? width * 2, shift: shift, tiled: tiled);

  @override
  bool operator ==(Object other) =>
      other is KkStripePattern &&
      other.a == a &&
      other.b == b &&
      other.width == width &&
      other.period == period &&
      other.shift == shift &&
      other.tiled == tiled;

  @override
  int get hashCode => Object.hash(a, b, width, period, shift, tiled);
}

class KkHexPattern extends KkPattern {
  const KkHexPattern({required this.color, this.pitch = 24, this.opacity = 0.2});

  final Color color;

  /// The grid pitch the field is locked to; one hexagon is 7/6 × 2 pitches.
  final double pitch;
  final double opacity;

  @override
  void paint(Canvas canvas, Rect rect) => kkPaintHexField(canvas, rect, color, pitch: pitch, opacity: opacity);

  @override
  bool operator ==(Object other) =>
      other is KkHexPattern && other.color == color && other.pitch == pitch && other.opacity == opacity;

  @override
  int get hashCode => Object.hash(color, pitch, opacity);
}

class KkScanPattern extends KkPattern {
  const KkScanPattern({required this.color, this.on = 1, this.off = 2});

  final Color color;

  /// Height of each dark line.
  final double on;

  /// Clear height between lines.
  final double off;

  @override
  void paint(Canvas canvas, Rect rect) {
    if (rect.isEmpty || color.a <= 0 || on <= 0 || off < 0) return;
    final Path p = Path();
    for (double y = _wholePixel(rect.top) + off; y < rect.bottom; y += on + off) {
      final double top = math.max(y, rect.top);
      final double bottom = math.min(y + on, rect.bottom);
      if (bottom > top) p.addRect(Rect.fromLTRB(rect.left, top, rect.right, bottom));
    }
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool operator ==(Object other) =>
      other is KkScanPattern && other.color == color && other.on == on && other.off == off;

  @override
  int get hashCode => Object.hash(color, on, off);
}

class KkSegmentPattern extends KkPattern {
  const KkSegmentPattern({required this.color, this.pitch = 8, this.gap = 2});

  final Color color;

  /// Segment plus gap.
  final double pitch;
  final double gap;

  @override
  void paint(Canvas canvas, Rect rect) => kkPaintSegments(canvas, rect, color, pitch: pitch, gap: gap);

  @override
  bool operator ==(Object other) =>
      other is KkSegmentPattern && other.color == color && other.pitch == pitch && other.gap == gap;

  @override
  int get hashCode => Object.hash(color, pitch, gap);
}

class KkTickPattern extends KkPattern {
  const KkTickPattern({required this.color, this.pitch = 8, this.stroke = 1});

  final Color color;
  final double pitch;
  final double stroke;

  @override
  void paint(Canvas canvas, Rect rect) {
    if (rect.isEmpty || color.a <= 0 || pitch <= 0 || stroke <= 0) return;
    final Path p = Path();
    for (double x = _wholePixel(rect.left); x < rect.right; x += pitch) {
      final double left = math.max(x, rect.left);
      final double right = math.min(x + stroke, rect.right);
      if (right > left) p.addRect(Rect.fromLTRB(left, rect.top, right, rect.bottom));
    }
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool operator ==(Object other) =>
      other is KkTickPattern && other.color == color && other.pitch == pitch && other.stroke == stroke;

  @override
  int get hashCode => Object.hash(color, pitch, stroke);
}

/// Paints a square grid of [stroke]-wide lines every [pitch], starting at the
/// whole pixel nearest to the top-left corner of [rect] and cut to [rect].
void kkPaintGrid(Canvas canvas, Rect rect, Color color, double pitch, {double stroke = 1}) {
  if (rect.isEmpty || color.a <= 0 || pitch <= 0 || stroke <= 0) return;
  final Path p = Path();
  for (double y = _wholePixel(rect.top); y < rect.bottom; y += pitch) {
    final double top = math.max(y, rect.top);
    final double bottom = math.min(y + stroke, rect.bottom);
    if (bottom > top) p.addRect(Rect.fromLTRB(rect.left, top, rect.right, bottom));
  }
  for (double x = _wholePixel(rect.left); x < rect.right; x += pitch) {
    final double left = math.max(x, rect.left);
    final double right = math.min(x + stroke, rect.right);
    if (right > left) p.addRect(Rect.fromLTRB(left, rect.top, right, rect.bottom));
  }
  // Non-zero fill so the crossings are painted once.
  canvas.drawPath(p..fillType = PathFillType.nonZero, Paint()..color = color);
}

/// Paints segments of ([pitch] − [gap]) px separated by [gap] px across
/// [rect], counted from the whole pixel nearest to its left edge and cut to
/// [rect].
void kkPaintSegments(Canvas canvas, Rect rect, Color color, {double pitch = 8, double gap = 2}) {
  if (rect.isEmpty || color.a <= 0 || pitch <= 0) return;
  final Path p = Path();
  for (double x = _wholePixel(rect.left); x < rect.right; x += pitch) {
    final double start = math.max(x, rect.left);
    final double end = math.min(x + pitch - gap, rect.right);
    if (end > start) p.addRect(Rect.fromLTRB(start, rect.top, end, rect.bottom));
  }
  canvas.drawPath(p, Paint()..color = color);
}

/// Paints 45° stripes (rising to the right) clipped to [rect].
///
/// [width] and [period] are measured across the stripes. Without [tiled] the
/// first stripe starts at the bottom-right corner, as a CSS
/// `repeating-linear-gradient(-45deg, …)` does.
void kkPaintStripes(
  Canvas canvas,
  Rect rect, {
  required Color a,
  Color? b,
  double width = 12,
  double period = 24,
  double shift = 0,
  bool tiled = false,
}) {
  if (rect.isEmpty || period <= 0 || width <= 0) return;
  canvas.save();
  canvas.clipRect(rect);
  if (b != null && b.a > 0) canvas.drawRect(rect, Paint()..color = b);
  if (a.a > 0) {
    // Work in s = x + y. A stripe is the band between two lines of constant s.
    const double root2 = math.sqrt2;
    final double ps = period * root2;
    final double ws = width * root2;
    final double sMin = rect.left + rect.top;
    final double sMax = rect.right + rect.bottom;
    // Upper edge (in s) of one stripe.
    final double anchor = (tiled ? sMin : sMax) + shift;
    // First stripe whose band can reach the rect from above.
    final double k0 = ((anchor - sMax) / ps).floorToDouble();
    final Path p = Path();
    for (double hi = anchor - k0 * ps; hi > sMin; hi -= ps) {
      final double lo = hi - ws;
      p.moveTo(lo - rect.top, rect.top);
      p.lineTo(hi - rect.top, rect.top);
      p.lineTo(hi - rect.bottom, rect.bottom);
      p.lineTo(lo - rect.bottom, rect.bottom);
      p.close();
    }
    canvas.drawPath(p, Paint()..color = a);
  }
  canvas.restore();
}

/// Paints the hexagon outline field clipped to [rect].
void kkPaintHexField(Canvas canvas, Rect rect, Color color, {double pitch = 24, double opacity = 0.2}) {
  if (rect.isEmpty || color.a <= 0 || opacity <= 0 || pitch <= 0) return;
  final double k = pitch / 24;
  final double tw = 28 * k;
  final double th = 48 * k;
  final Path tile = Path()
    ..moveTo(14 * k, 0)
    ..lineTo(28 * k, 8 * k)
    ..lineTo(28 * k, 24 * k)
    ..lineTo(14 * k, 32 * k)
    ..lineTo(0, 24 * k)
    ..lineTo(0, 8 * k)
    ..close()
    ..moveTo(14 * k, 32 * k)
    ..lineTo(14 * k, 48 * k);
  final Path all = Path();
  for (double y = rect.top; y < rect.bottom; y += th) {
    for (double x = rect.left; x < rect.right; x += tw) {
      all.addPath(tile, Offset(x, y));
    }
  }
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawPath(
    all,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * k
      ..color = color.withValues(alpha: color.a * opacity),
  );
  canvas.restore();
}
