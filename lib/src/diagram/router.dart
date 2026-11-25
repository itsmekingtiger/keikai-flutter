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
    this.obstacles = const <Rect>[],
    this.texts = const <Rect>[],
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

  /// The boxes of the other nodes. In a free layout the house routers go
  /// round them when the plain route would run through one.
  final List<Rect> obstacles;

  /// The text blocks of the two nodes the wire joins. In a free layout the
  /// house routers leave a symbol by its side, when one clean bend gets there,
  /// rather than run under its own text.
  final List<Rect> texts;
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
///
/// A wire the layout has laid a way for (every wire of a layered layout,
/// the wires of a tree) follows it, and its bends are never cut further than
/// the layout allows ([KkEdgeHint.maxCut]). Any other wire (all of them in a
/// free layout, the extra ones of a tree) is drawn by the two house routers
/// with a look at what is around it: they leave a symbol by its side rather
/// than run under its own text when one bend gets there cleanly, take a lane
/// past a node that stands on the line, and search for a way between the
/// nodes when no simple shape gets past. Only where there is no way at all
/// (nodes packed against each other) does a wire cross a node.
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
      // A wire the layout has laid a way for follows it. Any other wire (all
      // of them in a free layout, the extra ones of a tree) finds its own
      // way, and is told what stands around it.
      final bool free = (placement.direction == null || placement.hints[i] == null) && edge.from != edge.to;
      final List<Rect> others = free
          ? <Rect>[
              for (final MapEntry<String, KkNodePlacement> o in placement.nodes.entries)
                if (o.key != edge.from && o.key != edge.to) o.value.bounds,
            ]
          : const <Rect>[];
      final List<Rect> texts = free ? <Rect>[?a.text, ?b.text] : const <Rect>[];
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
            obstacles: others,
            texts: texts,
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
    // Never further than the space between two ranks allows.
    final List<Offset> cutPoints = _cutCorners(points, math.min(cut, hint.maxCut));
    return KkEdgeRoute(hint.reversed ? cutPoints.reversed.toList(growable: false) : cutPoints);
  }

  final Rect a = request.from;
  final Rect b = request.to;
  final Offset d = b.center - a.center;
  final double adx = d.dx.abs();
  final double ady = d.dy.abs();


  final double gapX = adx - (a.width + b.width) / 2;
  final double gapY = ady - (a.height + b.height) / 2;
  const _Axis h = _Axis(true);
  const _Axis v = _Axis(false);

  // Diagonal neighbours take one bend: the upper symbol is left sideways and
  // the lower one entered from the top (or the other way about).
  final bool aUpper = a.center.dy <= b.center.dy;
  final Rect upper = aUpper ? a : b;
  final Rect lower = aUpper ? b : a;
  final bool right = lower.center.dx > upper.center.dx;
  List<Offset>? elbow({required bool sideFirst}) {
    final double runH = (lower.center.dx - upper.center.dx).abs() - (sideFirst ? upper.width : lower.width) / 2;
    final double runV = (lower.center.dy - upper.center.dy) - (sideFirst ? lower.height : upper.height) / 2;
    if (runH < 2 * _stub || runV < 2 * _stub) return null;
    final List<Offset> points = sideFirst
        ? <Offset>[
            Offset(right ? upper.right : upper.left, upper.center.dy),
            Offset(lower.center.dx, upper.center.dy),
            Offset(lower.center.dx, lower.top),
          ]
        : <Offset>[
            Offset(upper.center.dx, upper.bottom),
            Offset(upper.center.dx, lower.center.dy),
            Offset(right ? lower.left : lower.right, lower.center.dy),
          ];
    final List<Offset> cutPoints = _cutCorners(points, cut);
    return aUpper ? cutPoints : cutPoints.reversed.toList(growable: false);
  }

  List<Offset> plain;
  if (direction != null) {
    // A flow axis but no hint (an extra wire of a tree, say): along the axis.
    plain = _cutCorners(_axial(direction == KkDiagramDirection.leftToRight ? h : v, a, b), cut);
  } else if (gapX >= ady + 2 * _stub) {
    plain = _cutCorners(_axial(h, a, b), cut);
  } else if (gapY >= adx + 2 * _stub) {
    plain = _cutCorners(_axial(v, a, b), cut);
  } else {
    plain = elbow(sideFirst: true) ?? _cutCorners(_axial(gapX >= gapY ? h : v, a, b), cut);
  }
  final List<Rect> obstacles = request.obstacles;
  final List<Rect> texts = request.texts;
  final List<Offset>? sideFirst = elbow(sideFirst: true);
  final List<Offset>? dropFirst = elbow(sideFirst: false);
  if (_hits(plain, obstacles) == 0) {
    if (_hits(plain, texts) == 0) return KkEdgeRoute(plain);
    // The plain route runs under the text of one of its own two nodes: leave
    // by the side instead, when one bend does it without touching anything.
    for (final List<Offset>? bend in <List<Offset>?>[sideFirst, dropFirst]) {
      if (bend != null && _hits(bend, obstacles) == 0 && _hits(bend, texts) == 0) return KkEdgeRoute(bend);
    }
    return KkEdgeRoute(plain);
  }

  // The plain route runs through another node: try the other shapes, a lane
  // past whatever is in the way, and a searched route, and keep the one that
  // hits the least (other nodes first, then its own text). Among equals the
  // shortest and plainest wins.
  final List<Offset>? found = _maze(a, b, obstacles, texts);
  final List<List<Offset>> options = <List<Offset>>[
    plain,
    _cutCorners(_axial(h, a, b), cut),
    _cutCorners(_axial(v, a, b), cut),
    ?sideFirst,
    ?dropFirst,
    ..._bypass(h, a, b, obstacles, cut),
    ..._bypass(v, a, b, obstacles, cut),
    // A bend of the searched route is cut by no more than its clearance, so
    // the diagonal stays well off the corner it turns round.
    if (found != null) _cutCorners(found, math.min(cut, _clear)),
  ];
  List<Offset> best = plain;
  int least = 1 << 30;
  double cheapest = double.infinity;
  for (int k = 0; k < options.length; k++) {
    final List<Offset> option = options[k];
    final int n = _hits(option, obstacles) * 4 + _hits(option, texts);
    // Length, a little for every point, and a handicap on the searched route
    // so that a simple shape of about the same length is kept.
    double price = 8.0 * option.length + (found != null && k == options.length - 1 ? 32 : 0);
    for (int i = 1; i < option.length; i++) {
      price += (option[i] - option[i - 1]).distance;
    }
    if (n < least || (n == least && price < cheapest - 0.01)) {
      least = n;
      cheapest = price;
      best = option;
    }
  }
  return KkEdgeRoute(best);
}

/// The distance the searched routes keep from every node.
const double _clear = 8;

/// A right-angle route from a side of [a] to a side of [b] that stays
/// [_clear] px off [walls] (the other nodes), off the two symbols and off
/// their own [texts], or null when there is no such way near the two nodes.
///
/// The search runs along the lines that pass each node at that distance and
/// the centre lines of the two symbols, shortest way first with a price on
/// every bend. It is only asked when the simple shapes all run into
/// something, and gives up on a search that grows too large.
List<Offset>? _maze(Rect a, Rect b, List<Rect> walls, List<Rect> texts) {
  final Rect window = a.expandToInclude(b).inflate(120);
  final List<Rect> blocks = <Rect>[
    a.inflate(_clear),
    b.inflate(_clear),
    for (final Rect t in texts) t.inflate(_clear / 2),
    for (final Rect w in walls)
      if (w.overlaps(window)) w.inflate(_clear),
  ];
  final Set<double> xSet = <double>{a.center.dx, b.center.dx};
  final Set<double> ySet = <double>{a.center.dy, b.center.dy};
  for (final Rect r in blocks) {
    xSet
      ..add(r.left)
      ..add(r.right);
    ySet
      ..add(r.top)
      ..add(r.bottom);
  }
  final List<double> xs = <double>[
    for (final double x in xSet)
      if (x >= window.left && x <= window.right) x,
  ]..sort();
  final List<double> ys = <double>[
    for (final double y in ySet)
      if (y >= window.top && y <= window.bottom) y,
  ]..sort();
  final int nx = xs.length;
  final int ny = ys.length;
  if (nx * ny > 60000) return null;
  final Map<double, int> xi = <double, int>{for (int i = 0; i < nx; i++) xs[i]: i};
  final Map<double, int> yi = <double, int>{for (int j = 0; j < ny; j++) ys[j]: j};

  // Whether the level or upright run from p to q stays out of every block
  // (but [skip], the block of the symbol it starts at).
  bool clear(Offset p, Offset q, {int skip = -1}) {
    final double left = math.min(p.dx, q.dx);
    final double right = math.max(p.dx, q.dx);
    final double top = math.min(p.dy, q.dy);
    final double bottom = math.max(p.dy, q.dy);
    for (int k = 0; k < blocks.length; k++) {
      if (k == skip) continue;
      final Rect r = blocks[k];
      if (top == bottom) {
        if (r.top < top && top < r.bottom && r.left < right && left < r.right) return false;
      } else {
        if (r.left < left && left < r.right && r.top < bottom && top < r.bottom) return false;
      }
    }
    return true;
  }

  // Directions: 0 east, 1 south, 2 west, 3 north.
  const List<int> stepX = <int>[1, 0, -1, 0];
  const List<int> stepY = <int>[0, 1, 0, -1];

  // The ways out of a symbol: the point on its border, the grid point one
  // clearance out, and the direction.
  List<(Offset, int, int, int)> exits(Rect r, int self) {
    final List<(Offset, int, int, int)> out = <(Offset, int, int, int)>[];
    for (int d = 0; d < 4; d++) {
      final Offset border = switch (d) {
        0 => Offset(r.right, r.center.dy),
        1 => Offset(r.center.dx, r.bottom),
        2 => Offset(r.left, r.center.dy),
        _ => Offset(r.center.dx, r.top),
      };
      final Offset exit = border + Offset(stepX[d] * _clear, stepY[d] * _clear);
      final int? i = xi[exit.dx];
      final int? j = yi[exit.dy];
      if (i == null || j == null) continue;
      if (!clear(border, exit, skip: self)) continue;
      out.add((border, i, j, d));
    }
    return out;
  }

  final List<(Offset, int, int, int)> starts = exits(a, 0);
  final List<(Offset, int, int, int)> goals = exits(b, 1);
  if (starts.isEmpty || goals.isEmpty) return null;

  const double bend = 24;
  double ahead(int i, int j) {
    double least = double.infinity;
    for (final (Offset _, int gi, int gj, int _) in goals) {
      least = math.min(least, (xs[i] - xs[gi]).abs() + (ys[j] - ys[gj]).abs());
    }
    return least + _clear;
  }

  // A state is a grid point and the direction it was reached in; a negative
  // state is the border of [b] at one of the goals.
  final Map<int, double> cost = <int, double>{};
  final Map<int, int> from = <int, int>{};
  final _Heap heap = _Heap();
  void reach(int state, double g, int source, double h) {
    final double? known = cost[state];
    if (known != null && known <= g + 1e-9) return;
    cost[state] = g;
    from[state] = source;
    heap.add(g + h + h * 1e-6, g, state);
  }

  // A side that faces away from the other symbol costs extra, so a wire
  // only leaves by the back when the front is shut.
  double away(int d, Rect self, Rect other) {
    final Offset to = other.center - self.center;
    return stepX[d] * to.dx + stepY[d] * to.dy > 0 ? 0 : bend;
  }

  const int none = 0x10000000;
  for (int k = 0; k < starts.length; k++) {
    final (Offset _, int i, int j, int d) = starts[k];
    reach(((j * nx + i) << 2) | d, _clear + away(d, a, b), none + k, ahead(i, j));
  }
  int end = 0;
  int pops = 0;
  while (true) {
    if (heap.isEmpty) return null;
    final (double g, int state) = heap.removeFirst();
    if (g > (cost[state] ?? double.infinity) + 1e-9) continue;
    if (state < 0) {
      end = state;
      break;
    }
    if (++pops > 8000) return null;
    final int d = state & 3;
    final int cell = state >> 2;
    final int i = cell % nx;
    final int j = cell ~/ nx;
    for (int k = 0; k < goals.length; k++) {
      final (Offset _, int gi, int gj, int gd) = goals[k];
      // Arriving while heading out of the symbol cannot happen.
      if (gi != i || gj != j || d == gd) continue;
      reach(-1 - k, g + _clear + (d == (gd + 2) % 4 ? 0 : bend) + away(gd, b, a), state, 0);
    }
    for (int nd = 0; nd < 4; nd++) {
      if (nd == (d + 2) % 4) continue;
      final int ni = i + stepX[nd];
      final int nj = j + stepY[nd];
      if (ni < 0 || nj < 0 || ni >= nx || nj >= ny) continue;
      final Offset here = Offset(xs[i], ys[j]);
      final Offset there = Offset(xs[ni], ys[nj]);
      if (!clear(here, there)) continue;
      reach(
        ((nj * nx + ni) << 2) | nd,
        g + (there - here).distance + (nd == d ? 0 : bend),
        state,
        ahead(ni, nj),
      );
    }
  }

  // Walk back from the border of b to the border of a.
  final List<Offset> back = <Offset>[goals[-1 - end].$1];
  int state = from[end]!;
  while (true) {
    final int cell = state >> 2;
    back.add(Offset(xs[cell % nx], ys[cell ~/ nx]));
    final int source = from[state]!;
    if (source >= none) {
      back.add(starts[source - none].$1);
      break;
    }
    state = source;
  }
  return back.reversed.toList(growable: false);
}

/// A small binary heap of (key, cost, state), least key first.
class _Heap {
  final List<double> _keys = <double>[];
  final List<double> _costs = <double>[];
  final List<int> _states = <int>[];

  bool get isEmpty => _keys.isEmpty;

  void add(double key, double cost, int state) {
    _keys.add(key);
    _costs.add(cost);
    _states.add(state);
    int i = _keys.length - 1;
    while (i > 0) {
      final int up = (i - 1) >> 1;
      if (_keys[up] <= _keys[i]) break;
      _swap(i, up);
      i = up;
    }
  }

  (double, int) removeFirst() {
    final (double, int) first = (_costs.first, _states.first);
    final int last = _keys.length - 1;
    _swap(0, last);
    _keys.removeLast();
    _costs.removeLast();
    _states.removeLast();
    int i = 0;
    while (true) {
      final int l = 2 * i + 1;
      final int r = l + 1;
      int least = i;
      if (l < _keys.length && _keys[l] < _keys[least]) least = l;
      if (r < _keys.length && _keys[r] < _keys[least]) least = r;
      if (least == i) break;
      _swap(i, least);
      i = least;
    }
    return first;
  }

  void _swap(int a, int b) {
    final double k = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = k;
    final double c = _costs[a];
    _costs[a] = _costs[b];
    _costs[b] = c;
    final int s = _states[a];
    _states[a] = _states[b];
    _states[b] = s;
  }
}

/// How many of [obstacles] the polyline [points] runs through.
int _hits(List<Offset> points, List<Rect> obstacles) {
  int count = 0;
  for (final Rect o in obstacles) {
    final Rect r = o.inflate(2);
    for (int i = 1; i < points.length; i++) {
      if (_segmentHitsRect(points[i - 1], points[i], r)) {
        count++;
        break;
      }
    }
  }
  return count;
}

bool _segmentHitsRect(Offset a, Offset b, Rect r) {
  if (r.contains(a) || r.contains(b)) return true;
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

/// Routes along [axis] that leave the straight line for a lane just past the
/// obstacles in the way: out, a step to the lane, along it, a step back, in.
/// One for each side that has room. The steps are 45° diagonals when [cut] has
/// no limit, right angles cut by [cut] otherwise.
List<List<Offset>> _bypass(_Axis axis, Rect a, Rect b, List<Rect> obstacles, double cut) {
  final bool forward = axis.m(b.center) >= axis.m(a.center);
  final Rect first = forward ? a : b;
  final Rect second = forward ? b : a;
  final Offset start = axis.pt(axis.hi(first), axis.c(first.center));
  final Offset end = axis.pt(axis.lo(second), axis.c(second.center));
  if (axis.m(end) - axis.m(start) < 4 * _stub) return const <List<Offset>>[];
  // What stands between the two ports.
  double lo = double.infinity;
  double hi = -double.infinity;
  final Rect corridor = Rect.fromPoints(start, end).inflate(2);
  for (final Rect o in obstacles) {
    if (!o.overlaps(corridor)) continue;
    lo = math.min(lo, axis.crossLo(o));
    hi = math.max(hi, axis.crossHi(o));
  }
  if (!lo.isFinite) return const <List<Offset>>[];
  final List<List<Offset>> out = <List<Offset>>[];
  for (final double lane in <double>[kkSnap(lo - 12), kkSnap(hi + 12)]) {
    final List<Offset> points;
    if (cut.isFinite) {
      // A stub and room for the cut before each turn.
      final double m1 = axis.m(start) + 3 * _stub;
      final double m2 = axis.m(end) - 3 * _stub;
      if (m1 > m2) continue;
      points = _cutCorners(<Offset>[
        start,
        axis.pt(m1, axis.c(start)),
        axis.pt(m1, lane),
        axis.pt(m2, lane),
        axis.pt(m2, axis.c(end)),
        end,
      ], cut);
    } else {
      final double up = (lane - axis.c(start)).abs();
      final double down = (lane - axis.c(end)).abs();
      final double m1 = axis.m(start) + _stub;
      final double m2 = axis.m(end) - _stub;
      if (m1 + up > m2 - down) continue;
      points = _cutCorners(<Offset>[
        start,
        axis.pt(m1, axis.c(start)),
        axis.pt(m1 + up, lane),
        axis.pt(m2 - down, lane),
        axis.pt(m2, axis.c(end)),
        end,
      ], 0);
    }
    out.add(forward ? points : points.reversed.toList(growable: false));
  }
  return out;
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
