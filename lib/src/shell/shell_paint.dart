import 'package:flutter/widgets.dart';

/// Where the "you are here" mark of a shell item sits.
enum KkItemMark {
  none,

  /// A 4×16 bar at the middle of the left edge (rail, drawer and list rows).
  left,

  /// A 24×4 bar at the middle of the top edge (the rail as a bottom bar).
  top,

  /// A bar across the bottom edge that reaches down over the line under the
  /// item (tabs).
  bottom,
}

/// Paints the ground of one shell item: an optional flat fill and the mark of
/// the current item. Shared by tabs, the nav rail, the nav drawer and list
/// rows; not part of the public API.
class KkItemGroundPainter extends CustomPainter {
  const KkItemGroundPainter({
    this.fill,
    this.mark = KkItemMark.none,
    this.markColor = const Color(0x00000000),
    this.thickness = 4,
    this.length = 16,
    this.overhang = 0,
  });

  /// Flat background; null paints none.
  final Color? fill;
  final KkItemMark mark;
  final Color markColor;

  /// The short side of the mark.
  final double thickness;

  /// The long side of a [KkItemMark.left] or [KkItemMark.top] mark.
  final double length;

  /// How far a [KkItemMark.bottom] mark reaches below the item.
  final double overhang;

  @override
  void paint(Canvas canvas, Size size) {
    final Color? f = fill;
    if (f != null && f.a > 0) canvas.drawRect(Offset.zero & size, Paint()..color = f);
    if (mark == KkItemMark.none || markColor.a <= 0) return;
    final Rect r = switch (mark) {
      KkItemMark.left => Rect.fromLTWH(0, (size.height - length) / 2, thickness, length),
      KkItemMark.top => Rect.fromLTWH((size.width - length) / 2, 0, length, thickness),
      KkItemMark.bottom => Rect.fromLTWH(0, size.height - thickness + overhang, size.width, thickness),
      KkItemMark.none => Rect.zero,
    };
    canvas.drawRect(r, Paint()..color = markColor);
  }

  @override
  bool shouldRepaint(KkItemGroundPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.mark != mark ||
      oldDelegate.markColor != markColor ||
      oldDelegate.thickness != thickness ||
      oldDelegate.length != length ||
      oldDelegate.overhang != overhang;
}

/// The index of the next enabled item after [from] in direction [delta]
/// (+1 or -1), wrapping round; [from] itself when nothing else is enabled.
int kkNextEnabled(int from, int delta, int count, bool Function(int index) enabled) {
  if (count <= 0) return from;
  int i = from;
  for (int n = 0; n < count; n++) {
    i = (i + delta) % count;
    if (i < 0) i += count;
    if (enabled(i)) return i;
  }
  return from;
}

/// The first (or, with [last], the last) enabled index, or -1.
int kkEdgeEnabled(int count, bool Function(int index) enabled, {bool last = false}) {
  if (last) {
    for (int i = count - 1; i >= 0; i--) {
      if (enabled(i)) return i;
    }
  } else {
    for (int i = 0; i < count; i++) {
      if (enabled(i)) return i;
    }
  }
  return -1;
}
