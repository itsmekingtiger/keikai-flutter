import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'metrics.dart';
import 'model.dart';

/// The grid every diagram position is snapped to.
const double kkDiagramGrid = 4;

/// [v] rounded to the nearest multiple of the diagram grid.
double kkSnap(double v) => (v / kkDiagramGrid).roundToDouble() * kkDiagramGrid;

/// [v] rounded up to a multiple of the diagram grid.
double kkSnapUp(double v) => (v / kkDiagramGrid - 1e-9).ceilToDouble() * kkDiagramGrid;

/// Where one node ended up.
@immutable
class KkNodePlacement {
  const KkNodePlacement({required this.shape, required this.bounds, this.text});

  /// Places [box] so that the centre of its symbol sits on [anchor].
  factory KkNodePlacement.at(KkNodeBox box, Offset anchor) {
    final Offset origin = anchor - box.anchor;
    return KkNodePlacement(shape: box.shape.shift(origin), bounds: origin & box.size, text: box.text?.shift(origin));
  }

  /// The symbol.
  final Rect shape;

  /// Symbol and text together.
  final Rect bounds;

  /// The text block, when there is one.
  final Rect? text;

  /// The centre of the symbol, where wires aim.
  Offset get anchor => shape.center;

  KkNodePlacement shift(Offset by) =>
      KkNodePlacement(shape: shape.shift(by), bounds: bounds.shift(by), text: text?.shift(by));

  @override
  bool operator ==(Object other) =>
      other is KkNodePlacement && other.shape == shape && other.bounds == bounds && other.text == text;

  @override
  int get hashCode => Object.hash(shape, bounds, text);

  @override
  String toString() => 'KkNodePlacement($shape)';
}

/// What a layout tells the router about one wire.
@immutable
class KkEdgeHint {
  const KkEdgeHint({
    this.waypoints = const <Offset>[],
    this.jogs = const <double>[],
    this.reversed = false,
  });

  /// Points the wire passes on its way, in layout order (from the earlier
  /// layer to the later). A layered layout puts one in every layer the wire
  /// skips.
  final List<Offset> waypoints;

  /// For each leg (there is one more than [waypoints]), the position along
  /// the flow axis where the wire changes lane, or NaN to let the router pick.
  final List<double> jogs;

  /// The layout ran this wire backwards (it closes a cycle), so the route is
  /// built from the wire's `to` node to its `from` node and then turned round.
  final bool reversed;

  KkEdgeHint shift(Offset by, {required bool horizontal}) => KkEdgeHint(
    waypoints: <Offset>[for (final Offset p in waypoints) p + by],
    jogs: <double>[for (final double j in jogs) j + (horizontal ? by.dx : by.dy)],
    reversed: reversed,
  );

  @override
  bool operator ==(Object other) =>
      other is KkEdgeHint &&
      other.reversed == reversed &&
      listEquals(other.waypoints, waypoints) &&
      _sameJogs(other.jogs, jogs);

  static bool _sameJogs(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i] && !(a[i].isNaN && b[i].isNaN)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(reversed, Object.hashAll(waypoints), jogs.length);
}

/// The result of placing a diagram: a rectangle for every node, the total
/// size, and routing hints.
@immutable
class KkDiagramPlacement {
  const KkDiagramPlacement({
    required this.size,
    required this.nodes,
    this.hints = const <int, KkEdgeHint>{},
    this.direction,
  });

  /// A placement with nothing in it.
  static const KkDiagramPlacement empty = KkDiagramPlacement(size: Size.zero, nodes: <String, KkNodePlacement>{});

  final Size size;

  /// Placement of each node, by id.
  final Map<String, KkNodePlacement> nodes;

  /// Routing hints by index into the diagram's edges.
  final Map<int, KkEdgeHint> hints;

  /// The flow axis, for layouts that have one. Free layouts leave it null.
  final KkDiagramDirection? direction;

  /// Moves everything so the node bounds start at the origin (keeping the
  /// grid) and sizes the placement to fit them.
  static KkDiagramPlacement normalised(
    Map<String, KkNodePlacement> nodes, {
    Map<int, KkEdgeHint> hints = const <int, KkEdgeHint>{},
    KkDiagramDirection? direction,
    Size minSize = Size.zero,
  }) {
    if (nodes.isEmpty) return KkDiagramPlacement(size: minSize, nodes: nodes, direction: direction);
    double left = double.infinity, top = double.infinity, right = -double.infinity, bottom = -double.infinity;
    for (final KkNodePlacement n in nodes.values) {
      left = math.min(left, n.bounds.left);
      top = math.min(top, n.bounds.top);
      right = math.max(right, n.bounds.right);
      bottom = math.max(bottom, n.bounds.bottom);
    }
    for (final KkEdgeHint h in hints.values) {
      for (final Offset p in h.waypoints) {
        left = math.min(left, p.dx);
        top = math.min(top, p.dy);
        right = math.max(right, p.dx);
        bottom = math.max(bottom, p.dy);
      }
    }
    final Offset by = Offset(
      -(left / kkDiagramGrid).floorToDouble() * kkDiagramGrid,
      -(top / kkDiagramGrid).floorToDouble() * kkDiagramGrid,
    );
    final bool horizontal = direction != KkDiagramDirection.topToBottom;
    return KkDiagramPlacement(
      size: Size(
        math.max(minSize.width, kkSnapUp(right + by.dx)),
        math.max(minSize.height, kkSnapUp(bottom + by.dy)),
      ),
      nodes: <String, KkNodePlacement>{
        for (final MapEntry<String, KkNodePlacement> e in nodes.entries) e.key: e.value.shift(by),
      },
      hints: <int, KkEdgeHint>{
        for (final MapEntry<int, KkEdgeHint> e in hints.entries) e.key: e.value.shift(by, horizontal: horizontal),
      },
      direction: direction,
    );
  }
}

/// The path of one wire: a polyline from the border of one symbol to the
/// border of another.
@immutable
class KkEdgeRoute {
  const KkEdgeRoute(this.points);

  /// A route with no points (a wire that could not be drawn).
  static const KkEdgeRoute none = KkEdgeRoute(<Offset>[]);

  final List<Offset> points;

  bool get isEmpty => points.length < 2;

  /// Total length of the polyline.
  double get length {
    double l = 0;
    for (int i = 1; i < points.length; i++) {
      l += (points[i] - points[i - 1]).distance;
    }
    return l;
  }

  /// The point [distance] along the route from its start.
  Offset pointAt(double distance) {
    if (points.isEmpty) return Offset.zero;
    double left = distance;
    for (int i = 1; i < points.length; i++) {
      final double seg = (points[i] - points[i - 1]).distance;
      if (left <= seg && seg > 0) return Offset.lerp(points[i - 1], points[i], left / seg)!;
      left -= seg;
    }
    return points.last;
  }

  /// Unit direction of the last leg, for the arrow head.
  Offset get endDirection {
    for (int i = points.length - 1; i > 0; i--) {
      final Offset d = points[i] - points[i - 1];
      if (d.distanceSquared > 1e-9) return d / d.distance;
    }
    return const Offset(1, 0);
  }

  /// Unit direction of the first leg.
  Offset get startDirection {
    for (int i = 1; i < points.length; i++) {
      final Offset d = points[i] - points[i - 1];
      if (d.distanceSquared > 1e-9) return d / d.distance;
    }
    return const Offset(1, 0);
  }

  /// Where a label sits: the middle of the longest leg.
  Offset get labelAnchor {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;
    double best = -1;
    Offset at = points.first;
    for (int i = 1; i < points.length; i++) {
      final double seg = (points[i] - points[i - 1]).distance;
      if (seg > best + 1e-6) {
        best = seg;
        at = (points[i] + points[i - 1]) / 2;
      }
    }
    return at;
  }

  /// The part of the route from its start up to [distance].
  List<Offset> trimmed(double distance) {
    if (points.length < 2 || distance <= 0) return const <Offset>[];
    final List<Offset> out = <Offset>[points.first];
    double left = distance;
    for (int i = 1; i < points.length; i++) {
      final double seg = (points[i] - points[i - 1]).distance;
      if (left >= seg) {
        out.add(points[i]);
        left -= seg;
      } else {
        if (seg > 0 && left > 0) out.add(Offset.lerp(points[i - 1], points[i], left / seg)!);
        break;
      }
    }
    return out;
  }

  /// The same route walked from its end.
  KkEdgeRoute get turned => KkEdgeRoute(points.reversed.toList(growable: false));

  @override
  bool operator ==(Object other) => other is KkEdgeRoute && listEquals(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'KkEdgeRoute($points)';
}

/// A diagram that has been placed and routed: everything the painter needs.
@immutable
class KkDiagramGeometry {
  KkDiagramGeometry({
    required this.diagram,
    required this.size,
    required this.nodes,
    required this.routes,
    this.direction,
  });

  final KkDiagram diagram;
  final Size size;

  /// Placement of each node, by id.
  final Map<String, KkNodePlacement> nodes;

  /// One route per wire, in the order of the diagram's edges.
  final List<KkEdgeRoute> routes;
  final KkDiagramDirection? direction;

  late final List<Offset?> _labelPoints = _placeLabels();

  /// Where the label of wire [edge] goes: the middle of a leg of its route,
  /// chosen so that the label sits on its own wire only and off the nodes,
  /// the other wires and the labels placed before it.
  Offset labelAnchor(int edge) {
    if (edge < 0 || edge >= routes.length) return Offset.zero;
    return (edge < _labelPoints.length ? _labelPoints[edge] : null) ?? routes[edge].labelAnchor;
  }

  /// The box a wire label of [text] takes (9px mono on a 4px backing).
  static Size labelSize(String text, {double textScale = 1}) =>
      Size(KkNodeMetrics.monoWidth(text, 9 * textScale, spacingEm: 0.04) + 8, 9 * textScale + 4);

  List<Offset?> _placeLabels() {
    final List<Offset?> out = List<Offset?>.filled(routes.length, null);
    final List<Rect> placed = <Rect>[];
    for (int i = 0; i < routes.length && i < diagram.edges.length; i++) {
      final String? label = diagram.edges[i].label;
      final KkEdgeRoute route = routes[i];
      if (label == null || label.isEmpty || route.isEmpty) continue;
      final Size box = labelSize(label);
      double bestScore = double.infinity;
      Rect? best;
      for (int k = 1; k < route.points.length; k++) {
        final Offset a = route.points[k - 1];
        final Offset b = route.points[k];
        final double len = (b - a).distance;
        if (len < 0.5) continue;
        final Rect rect = Rect.fromCenter(center: (a + b) / 2, width: box.width, height: box.height);
        final bool flat = (a.dy - b.dy).abs() < 0.01;
        double score = flat ? 0 : 1;
        if (len < (flat ? box.width : box.height) + 8) score += 2;
        for (int j = 0; j < routes.length; j++) {
          if (j == i) continue;
          final List<Offset> other = routes[j].points;
          for (int m = 1; m < other.length; m++) {
            if (_segmentHitsRect(other[m - 1], other[m], rect.inflate(1))) {
              score += 6;
              break;
            }
          }
        }
        for (final KkNodePlacement n in nodes.values) {
          if (rect.overlaps(n.bounds)) score += 8;
        }
        for (final Rect r in placed) {
          if (rect.overlaps(r)) score += 8;
        }
        score -= math.min(len, 200) / 200;
        if (score < bestScore) {
          bestScore = score;
          best = rect;
        }
      }
      if (best != null) {
        out[i] = best.center;
        placed.add(best);
      }
    }
    return out;
  }

  static bool _segmentHitsRect(Offset a, Offset b, Rect r) {
    if (r.contains(a) || r.contains(b)) return true;
    // Liang-Barsky clipping of the segment against the rectangle.
    double t0 = 0, t1 = 1;
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    bool clip(double p, double q) {
      if (p == 0) return q >= 0;
      final double t = q / p;
      if (p < 0) {
        if (t > t1) return false;
        if (t > t0) t0 = t;
      } else {
        if (t < t0) return false;
        if (t < t1) t1 = t;
      }
      return true;
    }

    return clip(-dx, a.dx - r.left) && clip(dx, r.right - a.dx) && clip(-dy, a.dy - r.top) && clip(dy, r.bottom - a.dy) && t0 <= t1;
  }

  /// The id of the node whose symbol or text is under [point], topmost first,
  /// or null.
  String? nodeAt(Offset point) {
    for (int i = diagram.nodes.length - 1; i >= 0; i--) {
      final KkDiagramNode node = diagram.nodes[i];
      final KkNodePlacement? p = nodes[node.id];
      if (p != null && p.bounds.contains(point)) return node.id;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkDiagramGeometry &&
        other.diagram == diagram &&
        other.size == size &&
        other.direction == direction &&
        mapEquals(other.nodes, nodes) &&
        listEquals(other.routes, routes);
  }

  @override
  int get hashCode => Object.hash(diagram, size, direction, nodes.length, Object.hashAll(routes));
}
