import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../foundation/colors.dart';
import 'patterns.dart';
import 'shapes.dart';

/// How a `KkBox` paints itself: a flat fill, a pattern on it, a rectangular
/// border, corner brackets, a glow, and an optional pattern over the child.
///
/// There is no gradient, shadow or radius here on purpose.
@immutable
class KkDecoration {
  const KkDecoration({
    this.fill,
    this.pattern,
    this.edges = KkEdges.none,
    this.brackets,
    this.glow,
    this.overlay,
  });

  /// Flat background colour.
  final Color? fill;

  /// Pattern painted on the fill, under the child.
  final KkPattern? pattern;

  /// Rectangular border. Its widths take space inside the box.
  final KkEdges edges;

  /// Corner brackets, drawn over the border and slightly outside the box.
  final KkBracketSpec? brackets;

  /// Light emitted by an active or alarm surface.
  final KkGlow? glow;

  /// Pattern painted over the child (scan lines).
  final KkPattern? overlay;

  bool get hasForeground => overlay != null || brackets != null;

  /// Paints everything that sits under the child.
  void paintBackground(Canvas canvas, Rect rect) {
    final KkGlow? g = glow;
    if (g != null) kkPaintGlow(canvas, rect, g);
    final Color? f = fill;
    if (f != null && f.a > 0) canvas.drawRect(rect, Paint()..color = f);
    final KkPattern? p = pattern;
    if (p != null) {
      canvas.save();
      canvas.clipRect(rect);
      p.paint(canvas, rect);
      canvas.restore();
    }
    edges.paint(canvas, rect);
  }

  /// Paints everything that sits over the child.
  void paintForeground(Canvas canvas, Rect rect) {
    final KkPattern? o = overlay;
    if (o != null) {
      canvas.save();
      canvas.clipRect(rect);
      o.paint(canvas, rect);
      canvas.restore();
    }
    brackets?.paint(canvas, rect);
  }

  KkDecoration copyWith({
    Color? fill,
    KkPattern? pattern,
    KkEdges? edges,
    KkBracketSpec? brackets,
    KkGlow? glow,
    KkPattern? overlay,
  }) {
    return KkDecoration(
      fill: fill ?? this.fill,
      pattern: pattern ?? this.pattern,
      edges: edges ?? this.edges,
      brackets: brackets ?? this.brackets,
      glow: glow ?? this.glow,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KkDecoration &&
      other.fill == fill &&
      other.pattern == pattern &&
      other.edges == edges &&
      other.brackets == brackets &&
      other.glow == glow &&
      other.overlay == overlay;

  @override
  int get hashCode => Object.hash(fill, pattern, edges, brackets, glow, overlay);
}
