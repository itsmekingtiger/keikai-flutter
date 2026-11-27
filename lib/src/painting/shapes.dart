import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import '../foundation/colors.dart';

enum _KkShapeKind { rect, chamfer, slant, hex, arrow }

/// The outlines of KEIKAI. Corners are square; to soften one it is cut at 45°,
/// never rounded.
@immutable
class KkShape {
  /// A plain rectangle.
  const KkShape.rect() : _kind = _KkShapeKind.rect, tl = 0, tr = 0, br = 0, bl = 0, _a = 0, _notch = false;

  /// A rectangle with any of its corners cut at 45° by the given sizes.
  const KkShape.chamfer({this.tl = 0, this.tr = 0, this.br = 0, this.bl = 0})
    : _kind = _KkShapeKind.chamfer,
      _a = 0,
      _notch = false;

  /// The button plate: top-left and bottom-right corners cut by [size].
  const KkShape.plate(double size)
    : _kind = _KkShapeKind.chamfer,
      tl = size,
      tr = 0,
      br = size,
      bl = 0,
      _a = 0,
      _notch = false;

  /// A code block: the right edge leans in by [cut] at the bottom.
  const KkShape.slant(double cut)
    : _kind = _KkShapeKind.slant,
      tl = 0,
      tr = 0,
      br = 0,
      bl = 0,
      _a = cut,
      _notch = false;

  /// A pointy-top hexagon stretched to the box.
  const KkShape.hex() : _kind = _KkShapeKind.hex, tl = 0, tr = 0, br = 0, bl = 0, _a = 0, _notch = false;

  /// A step of a mode strip: an arrow head of [head] on the right and, when
  /// [notch] is true, a matching notch on the left.
  const KkShape.arrow({double head = 12, bool notch = true})
    : _kind = _KkShapeKind.arrow,
      tl = 0,
      tr = 0,
      br = 0,
      bl = 0,
      _a = head,
      _notch = notch;

  final _KkShapeKind _kind;
  final double tl;
  final double tr;
  final double br;
  final double bl;
  final double _a;
  final bool _notch;

  /// Whether this is the plain rectangle.
  bool get isRect => _kind == _KkShapeKind.rect;

  /// The outline of this shape fitted to [r].
  Path path(Rect r) {
    final Path p = Path();
    if (r.isEmpty) return p;
    switch (_kind) {
      case _KkShapeKind.rect:
        p.addRect(r);
      case _KkShapeKind.chamfer:
        final double m = math.min(r.width, r.height) / 2;
        final double a = math.min(tl, m);
        final double b = math.min(tr, m);
        final double c = math.min(br, m);
        final double d = math.min(bl, m);
        p.moveTo(r.left + a, r.top);
        p.lineTo(r.right - b, r.top);
        if (b > 0) p.lineTo(r.right, r.top + b);
        p.lineTo(r.right, r.bottom - c);
        if (c > 0) p.lineTo(r.right - c, r.bottom);
        p.lineTo(r.left + d, r.bottom);
        if (d > 0) p.lineTo(r.left, r.bottom - d);
        p.lineTo(r.left, r.top + a);
        p.close();
      case _KkShapeKind.slant:
        final double cut = math.min(_a, r.width);
        p.moveTo(r.left, r.top);
        p.lineTo(r.right, r.top);
        p.lineTo(r.right - cut, r.bottom);
        p.lineTo(r.left, r.bottom);
        p.close();
      case _KkShapeKind.hex:
        final double q = r.height / 4;
        p.moveTo(r.center.dx, r.top);
        p.lineTo(r.right, r.top + q);
        p.lineTo(r.right, r.bottom - q);
        p.lineTo(r.center.dx, r.bottom);
        p.lineTo(r.left, r.bottom - q);
        p.lineTo(r.left, r.top + q);
        p.close();
      case _KkShapeKind.arrow:
        final double h = math.min(_a, r.width / 2);
        p.moveTo(r.left, r.top);
        p.lineTo(r.right - h, r.top);
        p.lineTo(r.right, r.center.dy);
        p.lineTo(r.right - h, r.bottom);
        p.lineTo(r.left, r.bottom);
        if (_notch) p.lineTo(r.left + h, r.center.dy);
        p.close();
    }
    return p;
  }

  /// Whether [point] is inside this shape fitted to [r].
  bool contains(Rect r, Offset point) {
    if (!r.contains(point)) return false;
    if (_kind == _KkShapeKind.rect) return true;
    return path(r).contains(point);
  }

  @override
  bool operator ==(Object other) =>
      other is KkShape &&
      other._kind == _kind &&
      other.tl == tl &&
      other.tr == tr &&
      other.br == br &&
      other.bl == bl &&
      other._a == _a &&
      other._notch == _notch;

  @override
  int get hashCode => Object.hash(_kind, tl, tr, br, bl, _a, _notch);
}

/// Paints a KEIKAI surface: an optional glow, an [edge] coloured plate in
/// [shape], and a [fill] plate inset by [edgeWidth] on top of it.
///
/// This is the two-layer construction every plated control uses, so a 1px
/// border follows the 45° cuts exactly.
void kkPaintSurface(
  Canvas canvas,
  Rect rect, {
  KkShape shape = const KkShape.rect(),
  Color? fill,
  Color? edge,
  double edgeWidth = 1,
  KkGlow? glow,
}) {
  if (rect.isEmpty) return;
  if (glow != null) kkPaintGlow(canvas, rect, glow, shape: shape);
  final bool hasEdge = edge != null && edge.a > 0 && edgeWidth > 0;
  if (hasEdge) {
    canvas.drawPath(shape.path(rect), Paint()..color = edge);
  }
  if (fill != null && fill.a > 0) {
    final Rect inner = edgeWidth > 0 ? rect.deflate(edgeWidth) : rect;
    if (!inner.isEmpty && inner.width > 0 && inner.height > 0) {
      canvas.drawPath(shape.path(inner), Paint()..color = fill);
    }
  }
}

/// Paints [glow] around [shape] fitted to [rect]: a blurred halo and a hard ring.
///
/// Like the two CSS box shadows a glow stands for, both are shadows of the
/// same outline. The halo is that outline blurred, and the ring is painted
/// over the first [KkGlow.ring] pixels of it.
void kkPaintGlow(Canvas canvas, Rect rect, KkGlow glow, {KkShape shape = const KkShape.rect()}) {
  if (glow.blur > 0 && glow.alpha > 0) {
    canvas.drawPath(
      shape.path(rect),
      Paint()
        ..color = kkFade(glow.color, glow.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glow.blur / 2),
    );
  }
  if (glow.ring > 0) {
    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(shape.path(rect.inflate(glow.ring)), Offset.zero)
      ..addPath(shape.path(rect), Offset.zero);
    canvas.drawPath(ring, Paint()..color = glow.color);
  }
}

/// One side of a rectangular border.
@immutable
class KkSide {
  const KkSide(this.color, {this.width = 1, this.dashed = false});

  /// No border on this side.
  static const KkSide none = KkSide(Color(0x00000000), width: 0);

  final Color color;
  final double width;

  /// Dashed sides mark a disabled or disconnected surface.
  final bool dashed;

  @override
  bool operator ==(Object other) =>
      other is KkSide && other.color == color && other.width == width && other.dashed == dashed;

  @override
  int get hashCode => Object.hash(color, width, dashed);
}

/// The four sides of a rectangular border. Widths take space inside the box,
/// like a CSS border under `box-sizing: border-box`.
@immutable
class KkEdges {
  const KkEdges({
    this.top = KkSide.none,
    this.right = KkSide.none,
    this.bottom = KkSide.none,
    this.left = KkSide.none,
  });

  /// The same [side] all round.
  const KkEdges.all(KkSide side) : top = side, right = side, bottom = side, left = side;

  /// A solid (or dashed) line of [color] all round.
  KkEdges.line(Color color, {double width = 1, bool dashed = false})
    : this.all(KkSide(color, width: width, dashed: dashed));

  static const KkEdges none = KkEdges();

  final KkSide top;
  final KkSide right;
  final KkSide bottom;
  final KkSide left;

  /// The space the border takes on each side.
  EdgeInsets get insets => EdgeInsets.fromLTRB(left.width, top.width, right.width, bottom.width);

  bool get isNone => top.width <= 0 && right.width <= 0 && bottom.width <= 0 && left.width <= 0;

  KkEdges copyWith({KkSide? top, KkSide? right, KkSide? bottom, KkSide? left}) =>
      KkEdges(top: top ?? this.top, right: right ?? this.right, bottom: bottom ?? this.bottom, left: left ?? this.left);

  /// Paints the border just inside [r], and never outside it: where [r] is
  /// thinner than the sides that meet in it, they share what room there is.
  ///
  /// A dashed side is fitted to its edge the way browsers fit a dashed CSS
  /// border: it starts and ends on a whole dash, so every corner is solid and
  /// both ends of a side look the same, and the dashes between are spread
  /// evenly on whole pixels. A dash is three times as long as the side is wide
  /// (3px at least) and the gaps are as close to that as the length allows. A
  /// side with no room for two dashes and a gap is solid.
  void paint(Canvas canvas, Rect r) {
    if (isNone || r.isEmpty) return;
    final Paint paint = Paint();
    // The dashes of all sides in one colour go into one path that is painted
    // once, so a translucent colour is not blended twice in a shared corner.
    Map<Color, Path>? dashes;

    // [band] is the part of [r] the side may paint.
    void side(KkSide s, Rect band, bool horizontal) {
      if (s.width <= 0 || s.color.a <= 0 || band.isEmpty) return;
      if (!s.dashed) {
        paint.color = s.color;
        canvas.drawRect(band, paint);
        return;
      }
      // The run is laid out along the whole edge of [r], corner to corner,
      // and cut to the band.
      final Path path = (dashes ??= <Color, Path>{})[s.color] ??= Path();
      final double start = horizontal ? r.left : r.top;
      final double length = horizontal ? r.width : r.height;
      void dash(double from, double to) {
        if (horizontal) {
          path.addRect(Rect.fromLTRB(start + from, band.top, start + to, band.bottom));
          return;
        }
        final double y0 = math.max(start + from, band.top);
        final double y1 = math.min(start + to, band.bottom);
        if (y1 > y0) path.addRect(Rect.fromLTRB(band.left, y0, band.right, y1));
      }

      final double on = math.max(3, s.width * 3);
      if (length <= on * 2) {
        dash(0, length);
        return;
      }
      final int count = math.max(2, ((length + on) / (on * 2)).round());
      final double step = (length - on) / (count - 1);
      for (int i = 0; i < count; i++) {
        // The second half mirrors the first, whichever way a step rounds.
        final int mirror = count - 1 - i;
        final double at = i <= mirror ? (i * step).roundToDouble() : length - on - (mirror * step).roundToDouble();
        dash(at, at + on);
      }
    }

    // A box can be laid out thinner than its own border, which a CSS box
    // cannot. It is all border then: every side gets the room that is left,
    // top and left first, so that none paints outside [r] or over another.
    final double t = math.max(0, math.min(top.width, r.height));
    final double b = math.max(0, math.min(bottom.width, r.height - t));
    final double l = math.max(0, math.min(left.width, r.width));
    final double e = math.max(0, math.min(right.width, r.width - l));

    // A solid left or right side stops at the top and bottom sides, which own
    // the corners. A dashed one runs into every corner it shares with another
    // dashed side, so both of them end there on a dash.
    Rect upright(KkSide s, double x0, double x1) =>
        Rect.fromLTRB(x0, r.top + (s.dashed && top.dashed ? 0 : t), x1, r.bottom - (s.dashed && bottom.dashed ? 0 : b));

    side(top, Rect.fromLTRB(r.left, r.top, r.right, r.top + t), true);
    side(bottom, Rect.fromLTRB(r.left, r.bottom - b, r.right, r.bottom), true);
    side(left, upright(left, r.left, r.left + l), false);
    side(right, upright(right, r.right - e, r.right), false);
    dashes?.forEach((Color color, Path path) => canvas.drawPath(path, paint..color = color));
  }

  @override
  bool operator ==(Object other) =>
      other is KkEdges && other.top == top && other.right == right && other.bottom == bottom && other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// The L-shaped corner brackets that frame a panel, a focused field or a dialog.
@immutable
class KkBracketSpec {
  const KkBracketSpec({required this.color, this.length = 12, this.width = 2, this.outset = 1});

  final Color color;

  /// Length of each arm. Only the box along its own direction cuts an arm
  /// short: where the box is narrower than two arms they meet in the middle.
  final double length;

  /// Thickness of each arm.
  final double width;

  /// How far outside the box the brackets sit. The box includes its border.
  /// The CSS of the design measures the same distance from the inner edge of
  /// the border, so a layer with `inset: -6px` on a box with a 1px border is
  /// an outset of 5.
  final double outset;

  void paint(Canvas canvas, Rect rect) {
    if (color.a <= 0 || rect.isEmpty) return;
    final Rect r = rect.inflate(outset);
    // Each arm is clamped on its own axis, like the CSS background tiles the
    // brackets are drawn with: a low, wide box keeps its horizontal arms.
    final double lx = math.min(length, r.width / 2);
    final double ly = math.min(length, r.height / 2);
    final double w = width;
    final Path p = Path()
      ..addRect(Rect.fromLTWH(r.left, r.top, lx, w))
      ..addRect(Rect.fromLTWH(r.left, r.top, w, ly))
      ..addRect(Rect.fromLTWH(r.right - lx, r.top, lx, w))
      ..addRect(Rect.fromLTWH(r.right - w, r.top, w, ly))
      ..addRect(Rect.fromLTWH(r.left, r.bottom - w, lx, w))
      ..addRect(Rect.fromLTWH(r.left, r.bottom - ly, w, ly))
      ..addRect(Rect.fromLTWH(r.right - lx, r.bottom - w, lx, w))
      ..addRect(Rect.fromLTWH(r.right - w, r.bottom - ly, w, ly));
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool operator ==(Object other) =>
      other is KkBracketSpec &&
      other.color == color &&
      other.length == length &&
      other.width == width &&
      other.outset == outset;

  @override
  int get hashCode => Object.hash(color, length, width, outset);
}

/// Cuts [source] into dashes following [pattern] (on, off, on, off …).
///
/// An odd number of lengths is read twice over with on and off swapped, as in
/// SVG: `[5]` is 5 on, 5 off. [phase] is how far into the pattern each contour
/// starts. It wraps at one whole period and may be negative.
Path kkDashPath(Path source, List<double> pattern, {double phase = 0}) {
  assert(pattern.isNotEmpty && pattern.every((double v) => v > 0));
  final Path out = Path();
  final double total = pattern.fold<double>(0, (double a, double b) => a + b);
  // A pattern that does not advance would never end: leave the path solid.
  if (pattern.isEmpty || total <= 0 || pattern.any((double v) => v <= 0)) return Path.from(source);
  // On and off swap on each pass through an odd list, so it takes two passes
  // to come round again.
  final double period = pattern.length.isOdd ? total * 2 : total;
  for (final PathMetric metric in source.computeMetrics()) {
    double distance = -(phase % period);
    int i = 0;
    bool draw = true;
    while (distance < metric.length) {
      final double len = pattern[i % pattern.length];
      if (draw) {
        final double from = math.max(0, distance);
        final double to = math.min(metric.length, distance + len);
        if (to > from) out.addPath(metric.extractPath(from, to), Offset.zero);
      }
      distance += len;
      draw = !draw;
      i++;
    }
  }
  return out;
}

/// A regular polygon outline (used for hexagon marks and radar blips).
Path kkPolygon(Offset center, double radius, int sides, {double rotation = -math.pi / 2}) {
  final Path p = Path();
  for (int i = 0; i < sides; i++) {
    final double a = rotation + i * 2 * math.pi / sides;
    final Offset pt = center + Offset(math.cos(a), math.sin(a)) * radius;
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  return p..close();
}
