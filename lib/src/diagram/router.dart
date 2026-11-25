import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'geometry.dart';
import 'metrics.dart';
import 'model.dart';

/// One wire to route: the two symbols it joins and what the layout knows
/// about the way between them.
@immutable
class KkEdgeRequest {
  const KkEdgeRequest({
    required this.edge,
    required this.from,
    required this.to,
    this.fromKind = KkNodeKind.node,
    this.toKind = KkNodeKind.node,
    this.hint,
    this.direction,
  });

  final KkDiagramEdge edge;

  /// Symbol rectangle of the wire's `from` node.
  final Rect from;

  /// Symbol rectangle of the wire's `to` node.
  final Rect to;
  final KkNodeKind fromKind;
  final KkNodeKind toKind;
  final KkEdgeHint? hint;

  /// The flow axis of the layout, or null for a free layout.
  final KkDiagramDirection? direction;
}

/// Turns placed nodes into wire paths.
///
/// KEIKAI draws with straight lines and 45° diagonals only, so the two house
/// routers never produce any other angle:
///
/// * [KkEdgeRouter.orthogonal]: right-angle routes whose bends are cut at 45°.
///   The router for layered and tree layouts.
/// * [KkEdgeRouter.octilinear]: the same routes with every bend cut as far as
///   it will go, so most wires become run, diagonal, run. The router for free
///   layouts (radial, force, manual).
/// * [KkEdgeRouter.straight]: one straight line from border to border, at any
///   angle. For when a diagram really is a web.
///
/// Every route starts and ends on the outline of a symbol.
abstract class KkEdgeRouter {
  const KkEdgeRouter();

  const factory KkEdgeRouter.orthogonal({double cut}) = KkOrthogonalRouter;

  const factory KkEdgeRouter.octilinear() = KkOctilinearRouter;

  const factory KkEdgeRouter.straight() = KkStraightRouter;

  /// The route of one wire, from the border of `request.from` to the border
  /// of `request.to`.
  KkEdgeRoute route(KkEdgeRequest request);

  /// Routes every wire of [diagram] over [placement], in edge order.
  List<KkEdgeRoute> routeAll(KkDiagram diagram, KkDiagramPlacement placement) {
    final List<KkEdgeRoute> out = <KkEdgeRoute>[];
    for (int i = 0; i < diagram.edges.length; i++) {
      final KkDiagramEdge edge = diagram.edges[i];
      final KkNodePlacement? a = placement.nodes[edge.from];
      final KkNodePlacement? b = placement.nodes[edge.to];
      if (a == null || b == null) {
        out.add(KkEdgeRoute.none);
        continue;
      }
      out.add(
        route(
          KkEdgeRequest(
            edge: edge,
            from: a.shape,
            to: b.shape,
            fromKind: diagram.nodeById(edge.from)?.kind ?? KkNodeKind.node,
            toKind: diagram.nodeById(edge.to)?.kind ?? KkNodeKind.node,
            hint: placement.hints[i],
            direction: placement.direction,
          ),
        ),
      );
    }
    return out;
  }
}

/// Right-angle routes with the bends cut at 45° by [cut] px.
class KkOrthogonalRouter extends KkEdgeRouter {
  const KkOrthogonalRouter({this.cut = 8}) : assert(cut >= 0);

  /// Size of the 45° cut at each bend. A bend with less room gets a smaller
  /// cut.
  final double cut;

  @override
  KkEdgeRoute route(KkEdgeRequest request) => _routeLegs(request, cut);

  @override
  bool operator ==(Object other) => other is KkOrthogonalRouter && other.cut == cut;

  @override
  int get hashCode => Object.hash(KkOrthogonalRouter, cut);
}

/// Routes made of horizontal and vertical runs joined by the longest 45°
/// diagonals that fit.
class KkOctilinearRouter extends KkEdgeRouter {
  const KkOctilinearRouter();

  @override
  KkEdgeRoute route(KkEdgeRequest request) => _routeLegs(request, double.infinity);

  @override
  bool operator ==(Object other) => other is KkOctilinearRouter;

  @override
  int get hashCode => (KkOctilinearRouter).hashCode;
}

/// One straight line between the two symbols (through the layout's waypoints
/// when it gives any).
class KkStraightRouter extends KkEdgeRouter {
  const KkStraightRouter();

  @override
  KkEdgeRoute route(KkEdgeRequest request) {
    if (request.edge.from == request.edge.to) return _loop(request.from, 4);
    final KkEdgeHint? hint = request.hint;
    final bool reversed = hint?.reversed ?? false;
    final List<Offset> way = hint == null
        ? const <Offset>[]
        : (reversed ? hint.waypoints.reversed.toList() : hint.waypoints);
    final Offset first = way.isEmpty ? request.to.center : way.first;
    final Offset last = way.isEmpty ? request.from.center : way.last;
    final Offset start = kkOutlineExit(request.fromKind, request.from, first);
    final Offset end = kkOutlineExit(request.toKind, request.to, last);
    if ((start - end).distance < 0.5 && way.isEmpty) return KkEdgeRoute.none;
    return KkEdgeRoute(<Offset>[start, ...way, end]);
  }

  @override
  bool operator ==(Object other) => other is KkStraightRouter;

  @override
  int get hashCode => (KkStraightRouter).hashCode;
}

/// The straight piece every wire keeps where it meets a symbol.
const double _stub = 4;

/// Coordinates along and across a flow axis.
class _Axis {
  const _Axis(this.horizontal);

  final bool horizontal;

  double m(Offset p) => horizontal ? p.dx : p.dy;
  double c(Offset p) => horizontal ? p.dy : p.dx;
  Offset pt(double main, double cross) => horizontal ? Offset(main, cross) : Offset(cross, main);
  double lo(Rect r) => horizontal ? r.left : r.top;
  double hi(Rect r) => horizontal ? r.right : r.bottom;
  double crossLo(Rect r) => horizontal ? r.top : r.left;
  double crossHi(Rect r) => horizontal ? r.bottom : r.right;
}

KkEdgeRoute _routeLegs(KkEdgeRequest request, double cut) {
  if (request.edge.from == request.edge.to) return _loop(request.from, math.min(cut, 4));
  final KkEdgeHint? hint = request.hint;
  final KkDiagramDirection? direction = request.direction;

  // A layout with a flow axis: follow its lanes.
  if (direction != null && hint != null) {
    final _Axis axis = _Axis(direction == KkDiagramDirection.leftToRight);
    final Rect a = hint.reversed ? request.to : request.from;
    final Rect b = hint.reversed ? request.from : request.to;
    final List<Offset> points = _forward(axis, a, b, hint.waypoints, hint.jogs);
    final List<Offset> cutPoints = _cutCorners(points, cut);
    return KkEdgeRoute(hint.reversed ? cutPoints.reversed.toList(growable: false) : cutPoints);
  }

  final Rect a = request.from;
  final Rect b = request.to;
  final Offset d = b.center - a.center;
  final double adx = d.dx.abs();
  final double ady = d.dy.abs();

  // A flow axis but no hint (an extra wire of a tree, say): stay on the axis.
  if (direction != null) {
    final _Axis axis = _Axis(direction == KkDiagramDirection.leftToRight);
    return KkEdgeRoute(_cutCorners(_axial(axis, a, b), cut));
  }

  final double gapX = adx - (a.width + b.width) / 2;
  final double gapY = ady - (a.height + b.height) / 2;
  const _Axis h = _Axis(true);
  const _Axis v = _Axis(false);
  if (gapX >= ady + 2 * _stub) return KkEdgeRoute(_cutCorners(_axial(h, a, b), cut));
  if (gapY >= adx + 2 * _stub) return KkEdgeRoute(_cutCorners(_axial(v, a, b), cut));

  // Diagonal neighbours: one bend. The upper symbol is left sideways and the
  // lower one entered from the top.
  final bool aUpper = a.center.dy <= b.center.dy;
  final Rect upper = aUpper ? a : b;
  final Rect lower = aUpper ? b : a;
  final double runH = (lower.center.dx - upper.center.dx).abs() - upper.width / 2;
  final double runV = (lower.center.dy - upper.center.dy) - lower.height / 2;
  if (runH >= 2 * _stub && runV >= 2 * _stub) {
    final bool right = lower.center.dx > upper.center.dx;
    final List<Offset> elbow = <Offset>[
      Offset(right ? upper.right : upper.left, upper.center.dy),
      Offset(lower.center.dx, upper.center.dy),
      Offset(lower.center.dx, lower.top),
    ];
    final List<Offset> cutPoints = _cutCorners(elbow, cut);
    return KkEdgeRoute(aUpper ? cutPoints : cutPoints.reversed.toList(growable: false));
  }
  return KkEdgeRoute(_cutCorners(_axial(gapX >= gapY ? h : v, a, b), cut));
}

/// A route along [axis] between two symbols in either order.
List<Offset> _axial(_Axis axis, Rect a, Rect b) {
  if (axis.m(b.center) >= axis.m(a.center)) return _forward(axis, a, b, const <Offset>[], const <double>[]);
  return _forward(axis, b, a, const <Offset>[], const <double>[]).reversed.toList(growable: false);
}

/// Right-angle points from the far side of [a] to the near side of [b] along
/// [axis], through [waypoints], changing lane at [jogs].
List<Offset> _forward(_Axis axis, Rect a, Rect b, List<Offset> waypoints, List<double> jogs) {
  final Offset start = axis.pt(axis.hi(a), axis.c(a.center));
  final Offset end = axis.pt(axis.lo(b), axis.c(b.center));

  // The target does not lie ahead: go round.
  if (waypoints.isEmpty && axis.m(end) < axis.m(start) + 2 * _stub) {
    const double out = 12;
    final double m1 = axis.m(start) + out;
    final double m2 = axis.m(end) - out;
    double lane;
    if (axis.crossHi(a) + 8 <= axis.crossLo(b)) {
      lane = (axis.crossHi(a) + axis.crossLo(b)) / 2;
    } else if (axis.crossHi(b) + 8 <= axis.crossLo(a)) {
      lane = (axis.crossHi(b) + axis.crossLo(a)) / 2;
    } else {
      lane = math.max(axis.crossHi(a), axis.crossHi(b)) + 16;
    }
    return <Offset>[
      start,
      axis.pt(m1, axis.c(start)),
      axis.pt(m1, lane),
      axis.pt(m2, lane),
      axis.pt(m2, axis.c(end)),
      end,
    ];
  }

  final List<Offset> points = <Offset>[start];
  Offset prev = start;
  final List<Offset> legs = <Offset>[...waypoints, end];
  for (int i = 0; i < legs.length; i++) {
    final Offset next = legs[i];
    final double dc = axis.c(next) - axis.c(prev);
    if (dc.abs() < 0.01) {
      points.add(axis.pt(axis.m(next), axis.c(prev)));
    } else {
      final double lo = math.min(axis.m(prev), axis.m(next));
      final double hi = math.max(axis.m(prev), axis.m(next));
      double jog = i < jogs.length ? jogs[i] : double.nan;
      if (!jog.isFinite || jog <= lo || jog >= hi) jog = (lo + hi) / 2;
      points
        ..add(axis.pt(jog, axis.c(prev)))
        ..add(axis.pt(jog, axis.c(next)))
        ..add(next);
    }
    prev = points.last;
  }
  return points;
}

/// A small square loop off the top right of [shape], for a wire from a node
/// to itself.
KkEdgeRoute _loop(Rect shape, double cut) {
  const double out = 12;
  final List<Offset> points = <Offset>[
    Offset(shape.right, shape.center.dy),
    Offset(shape.right + out, shape.center.dy),
    Offset(shape.right + out, shape.top - out),
    Offset(shape.center.dx, shape.top - out),
    Offset(shape.center.dx, shape.top),
  ];
  return KkEdgeRoute(_cutCorners(points, cut));
}

/// Replaces every right-angle bend of [points] with a 45° diagonal of at most
/// [cut] px. A leg shared by two bends gives each half its length; the first
/// and last legs keep a short straight piece at the symbol.
List<Offset> _cutCorners(List<Offset> points, double cut) {
  // Drop repeated points and points in the middle of a straight run.
  final List<Offset> p = <Offset>[];
  for (final Offset pt in points) {
    if (p.isNotEmpty && (pt - p.last).distance < 0.01) continue;
    while (p.length >= 2) {
      final Offset a = p[p.length - 1] - p[p.length - 2];
      final Offset b = pt - p[p.length - 1];
      final double cross = a.dx * b.dy - a.dy * b.dx;
      final double dot = a.dx * b.dx + a.dy * b.dy;
      if (cross.abs() < 0.01 && dot > 0) {
        p.removeLast();
      } else {
        break;
      }
    }
    p.add(pt);
  }
  if (p.length < 3 || cut <= 0) return p;

  final int legs = p.length - 1;
  double available(int leg) {
    final double len = (p[leg + 1] - p[leg]).distance;
    final bool outer = leg == 0 || leg == legs - 1;
    if (legs == 2) return math.max(0, len - _stub);
    return outer ? math.max(0, len - _stub) : len / 2;
  }

  final List<Offset> out = <Offset>[p.first];
  for (int i = 1; i < p.length - 1; i++) {
    final Offset a = p[i] - p[i - 1];
    final Offset b = p[i + 1] - p[i];
    final double la = a.distance;
    final double lb = b.distance;
    final double dot = a.dx * b.dx + a.dy * b.dy;
    // Only right angles are cut; anything else is kept as it is.
    if (dot.abs() > 0.01 * la * lb) {
      out.add(p[i]);
      continue;
    }
    final double c = math.min(cut, math.min(available(i - 1), available(i)));
    if (c < 0.5) {
      out.add(p[i]);
      continue;
    }
    final Offset before = p[i] - a / la * c;
    final Offset after = p[i] + b / lb * c;
    if ((before - out.last).distance > 0.01) out.add(before);
    out.add(after);
  }
  if ((p.last - out.last).distance > 0.01) out.add(p.last);
  // Two cuts that meet on a short leg form one diagonal: drop the joint.
  final List<Offset> merged = <Offset>[];
  for (final Offset pt in out) {
    while (merged.length >= 2) {
      final Offset a = merged[merged.length - 1] - merged[merged.length - 2];
      final Offset b = pt - merged[merged.length - 1];
      final double cross = a.dx * b.dy - a.dy * b.dx;
      final double dot = a.dx * b.dx + a.dy * b.dy;
      if (cross.abs() < 0.01 && dot > 0) {
        merged.removeLast();
      } else {
        break;
      }
    }
    merged.add(pt);
  }
  return merged;
}
