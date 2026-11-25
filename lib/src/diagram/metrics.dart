import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'model.dart';

/// Where a node's text sits relative to its symbol.
enum KkLabelSide {
  /// Under the symbol for left-to-right and free layouts, to the right of it
  /// for top-to-bottom ones, so wires never run through the text.
  auto,

  /// Centred under the symbol.
  below,

  /// To the right of the symbol.
  right,
}

/// Returns a symbol size for [node], or null to use the default for its kind.
typedef KkNodeSizeHook = Size? Function(KkDiagramNode node);

/// The measured box of one node: the whole box, and where the symbol and the
/// text block sit inside it.
@immutable
class KkNodeBox {
  const KkNodeBox({required this.size, required this.shape, this.text});

  /// Size of symbol and text together.
  final Size size;

  /// The symbol, relative to the box.
  final Rect shape;

  /// The text block, relative to the box. Null when text is hidden.
  final Rect? text;

  /// The point wires aim at: the centre of the symbol.
  Offset get anchor => shape.center;
}

/// Sizes of the node symbols and of the text beside them.
///
/// Layouts measure nodes with this instead of laying text out, so a layout is
/// a pure function of the diagram: text widths are taken from the fixed
/// advance of the mono face (0.6em) and one em per CJK character.
@immutable
class KkNodeMetrics {
  const KkNodeMetrics({
    this.hub = const Size(32, 36),
    this.node = const Size(24, 24),
    this.leaf = const Size(12, 12),
    this.decision = const Size(32, 32),
    this.terminal = const Size(40, 20),
    this.codeSize = 10,
    this.labelSize = 9,
    this.textGap = 4,
    this.lineGap = 3,
    this.labelSide = KkLabelSide.auto,
    this.showText = true,
    this.textScale = 1,
    this.sizeOf,
  });

  final Size hub;
  final Size node;
  final Size leaf;
  final Size decision;
  final Size terminal;

  /// Font size of the code (10px mono semibold).
  final double codeSize;

  /// Font size of the label under it (9px mono).
  final double labelSize;

  /// Space between the symbol and the text.
  final double textGap;

  /// Space between the code and the label line.
  final double lineGap;

  final KkLabelSide labelSide;

  /// Draw the code and label at all.
  final bool showText;

  /// Multiplies the font sizes (the theme's type scale).
  final double textScale;

  /// Per-node symbol size. Return null for the default of the node's kind.
  final KkNodeSizeHook? sizeOf;

  /// Tracking of the label line, in em.
  static const double labelSpacing = 0.04;

  /// Horizontal compression of the CJK title.
  static const double cjkSqueeze = 0.8;

  /// The symbol size of [node]: its own `size`, the hook's answer, or the
  /// default for its kind.
  Size shapeSize(KkDiagramNode node) {
    final Size? own = node.size ?? sizeOf?.call(node);
    if (own != null && own.width > 0 && own.height > 0) return own;
    return switch (node.kind) {
      KkNodeKind.hub => hub,
      KkNodeKind.node => this.node,
      KkNodeKind.leaf => leaf,
      KkNodeKind.decision => decision,
      KkNodeKind.terminal => terminal,
    };
  }

  static bool _wide(int rune) =>
      (rune >= 0x1100 && rune <= 0x11FF) ||
      (rune >= 0x2E80 && rune <= 0xA4CF) ||
      (rune >= 0xAC00 && rune <= 0xD7A3) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xFE30 && rune <= 0xFE4F) ||
      (rune >= 0xFF00 && rune <= 0xFF60) ||
      (rune >= 0xFFE0 && rune <= 0xFFE6) ||
      rune >= 0x20000;

  /// Width of [text] in the mono face at [size] px.
  static double monoWidth(String text, double size, {double spacingEm = 0}) {
    double em = 0;
    for (final int rune in text.runes) {
      em += (_wide(rune) ? 1.0 : 0.6) + spacingEm;
    }
    return em * size;
  }

  /// Width of [text] in the compressed display face at [size] px.
  static double displayWidth(String text, double size) {
    double em = 0;
    for (final int rune in text.runes) {
      em += _wide(rune) ? 1.0 : 0.55;
    }
    return em * size * cjkSqueeze;
  }

  static double _ceil4(double v) => (v / 4).ceilToDouble() * 4;

  /// Font size of the code line after [textScale].
  double get codePx => codeSize * textScale;

  /// Font size of the label line after [textScale].
  double get labelPx => labelSize * textScale;

  /// Font size of the CJK title on the label line.
  double get cjkPx => (labelSize + 1) * textScale;

  /// Size of the text block of [node] (zero when it has no text to show).
  Size textSize(KkDiagramNode node) {
    if (!showText) return Size.zero;
    final double w1 = monoWidth(node.text, codePx);
    final String? cjk = node.cjk;
    final String? label = node.label;
    final bool hasCjk = cjk != null && cjk.isNotEmpty;
    final bool hasLabel = label != null && label.isNotEmpty;
    if (!hasCjk && !hasLabel) return Size(w1, codePx);
    double w2 = 0;
    if (hasCjk) w2 += displayWidth(cjk, cjkPx);
    if (hasCjk && hasLabel) w2 += 4;
    if (hasLabel) w2 += monoWidth(label, labelPx, spacingEm: labelSpacing);
    final double h2 = hasCjk ? cjkPx : labelPx;
    return Size(math.max(w1, w2), codePx + lineGap + h2);
  }

  /// Measures [node]. With [labelRight] the text goes to the right of the
  /// symbol, otherwise under it. Box sizes are rounded up to the 4px grid.
  KkNodeBox measure(KkDiagramNode node, {bool labelRight = false}) {
    final Size s = shapeSize(node);
    final Size t = textSize(node);
    if (t.isEmpty) {
      final Size box = Size(_ceil4(s.width), _ceil4(s.height));
      return KkNodeBox(
        size: box,
        shape: Rect.fromLTWH((box.width - s.width) / 2, (box.height - s.height) / 2, s.width, s.height),
      );
    }
    if (labelRight) {
      const double gap = 6;
      final Size box = Size(_ceil4(s.width + gap + t.width), _ceil4(math.max(s.height, t.height)));
      return KkNodeBox(
        size: box,
        shape: Rect.fromLTWH(0, (box.height - s.height) / 2, s.width, s.height),
        text: Rect.fromLTWH(s.width + gap, (box.height - t.height) / 2, t.width, t.height),
      );
    }
    final Size box = Size(_ceil4(math.max(s.width, t.width)), _ceil4(s.height + textGap + t.height));
    return KkNodeBox(
      size: box,
      shape: Rect.fromLTWH((box.width - s.width) / 2, 0, s.width, s.height),
      text: Rect.fromLTWH((box.width - t.width) / 2, s.height + textGap, t.width, t.height),
    );
  }

  KkNodeMetrics copyWith({
    Size? hub,
    Size? node,
    Size? leaf,
    Size? decision,
    Size? terminal,
    double? codeSize,
    double? labelSize,
    double? textGap,
    double? lineGap,
    KkLabelSide? labelSide,
    bool? showText,
    double? textScale,
    KkNodeSizeHook? sizeOf,
  }) {
    return KkNodeMetrics(
      hub: hub ?? this.hub,
      node: node ?? this.node,
      leaf: leaf ?? this.leaf,
      decision: decision ?? this.decision,
      terminal: terminal ?? this.terminal,
      codeSize: codeSize ?? this.codeSize,
      labelSize: labelSize ?? this.labelSize,
      textGap: textGap ?? this.textGap,
      lineGap: lineGap ?? this.lineGap,
      labelSide: labelSide ?? this.labelSide,
      showText: showText ?? this.showText,
      textScale: textScale ?? this.textScale,
      sizeOf: sizeOf ?? this.sizeOf,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkNodeMetrics &&
        other.hub == hub &&
        other.node == node &&
        other.leaf == leaf &&
        other.decision == decision &&
        other.terminal == terminal &&
        other.codeSize == codeSize &&
        other.labelSize == labelSize &&
        other.textGap == textGap &&
        other.lineGap == lineGap &&
        other.labelSide == labelSide &&
        other.showText == showText &&
        other.textScale == textScale &&
        other.sizeOf == sizeOf;
  }

  @override
  int get hashCode => Object.hash(
    hub,
    node,
    leaf,
    decision,
    terminal,
    codeSize,
    labelSize,
    textGap,
    lineGap,
    labelSide,
    showText,
    textScale,
    sizeOf,
  );
}

/// The outline of the symbol of [kind] fitted to [r], as a closed polygon
/// (clockwise from the top).
///
/// * hub: a pointy-top hexagon
/// * node: a plate with the top-left corner cut
/// * decision: a diamond
/// * terminal: a plate cut to a point on both ends
/// * leaf: a square
///
/// The middle of each side of [r] always lies on the outline, so wires can
/// attach there.
List<Offset> kkNodeOutline(KkNodeKind kind, Rect r) {
  switch (kind) {
    case KkNodeKind.hub:
      final double q = r.height / 4;
      return <Offset>[
        Offset(r.center.dx, r.top),
        Offset(r.right, r.top + q),
        Offset(r.right, r.bottom - q),
        Offset(r.center.dx, r.bottom),
        Offset(r.left, r.bottom - q),
        Offset(r.left, r.top + q),
      ];
    case KkNodeKind.node:
      final double c = math.min(6.0, r.shortestSide / 4);
      return <Offset>[
        Offset(r.left + c, r.top),
        r.topRight,
        r.bottomRight,
        r.bottomLeft,
        Offset(r.left, r.top + c),
      ];
    case KkNodeKind.decision:
      return <Offset>[
        Offset(r.center.dx, r.top),
        Offset(r.right, r.center.dy),
        Offset(r.center.dx, r.bottom),
        Offset(r.left, r.center.dy),
      ];
    case KkNodeKind.terminal:
      final double c = math.min(r.height / 2, r.width / 2);
      return <Offset>[
        Offset(r.left + c, r.top),
        Offset(r.right - c, r.top),
        Offset(r.right, r.center.dy),
        Offset(r.right - c, r.bottom),
        Offset(r.left + c, r.bottom),
        Offset(r.left, r.center.dy),
      ];
    case KkNodeKind.leaf:
      return <Offset>[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  }
}

/// The outline of [kkNodeOutline] as a closed [Path].
Path kkNodePath(KkNodeKind kind, Rect r) => Path()..addPolygon(kkNodeOutline(kind, r), true);

/// The shortest distance from [p] to the outline of the symbol.
double kkDistanceToOutline(KkNodeKind kind, Rect r, Offset p) {
  final List<Offset> poly = kkNodeOutline(kind, r);
  double best = double.infinity;
  for (int i = 0; i < poly.length; i++) {
    best = math.min(best, _distanceToSegment(p, poly[i], poly[(i + 1) % poly.length]));
  }
  return best;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final double t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Where the straight line from the centre of the symbol toward [toward]
/// leaves its outline.
Offset kkOutlineExit(KkNodeKind kind, Rect r, Offset toward) {
  final Offset c = r.center;
  final Offset d = toward - c;
  if (d.distanceSquared < 1e-9) return c;
  final List<Offset> poly = kkNodeOutline(kind, r);
  double best = double.infinity;
  for (int i = 0; i < poly.length; i++) {
    final Offset a = poly[i];
    final Offset e = poly[(i + 1) % poly.length] - a;
    final double det = d.dx * e.dy - d.dy * e.dx;
    if (det.abs() < 1e-12) continue;
    final Offset ac = a - c;
    final double t = (ac.dx * e.dy - ac.dy * e.dx) / det;
    final double u = (ac.dx * d.dy - ac.dy * d.dx) / det;
    if (t > 0 && u >= -1e-9 && u <= 1 + 1e-9 && t < best) best = t;
  }
  if (!best.isFinite) return c;
  return c + d * best;
}
