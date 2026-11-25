import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/src/diagram/diagram.dart';

import 'layout_test.dart' show pipeline, randomDiagram;

/// Every leg is horizontal, vertical or exactly 45°.
void expectOctilinear(KkEdgeRoute route, {String? reason}) {
  for (int i = 1; i < route.points.length; i++) {
    final Offset d = route.points[i] - route.points[i - 1];
    final bool ok = d.dx.abs() < 1e-6 || d.dy.abs() < 1e-6 || (d.dx.abs() - d.dy.abs()).abs() < 1e-6;
    expect(ok, isTrue, reason: '${reason ?? ''} leg $i of ${route.points} is $d');
    expect(d.distance, greaterThan(0.009), reason: '${reason ?? ''} empty leg $i in ${route.points}');
  }
}

/// The route starts on the outline of its `from` symbol and ends on the
/// outline of its `to` symbol.
void expectOnBorders(KkDiagramGeometry g, int edge, {String? reason}) {
  final KkDiagramEdge e = g.diagram.edges[edge];
  final KkEdgeRoute r = g.routes[edge];
  expect(r.points.length, greaterThanOrEqualTo(2), reason: reason);
  final KkDiagramNode from = g.diagram.nodeById(e.from)!;
  final KkDiagramNode to = g.diagram.nodeById(e.to)!;
  expect(
    kkDistanceToOutline(from.kind, g.nodes[e.from]!.shape, r.points.first),
    lessThan(0.01),
    reason: '${reason ?? ''} ${e.from}->${e.to} starts at ${r.points.first}, symbol ${g.nodes[e.from]!.shape}',
  );
  expect(
    kkDistanceToOutline(to.kind, g.nodes[e.to]!.shape, r.points.last),
    lessThan(0.01),
    reason: '${reason ?? ''} ${e.from}->${e.to} ends at ${r.points.last}, symbol ${g.nodes[e.to]!.shape}',
  );
}

void main() {
  final Map<String, KkDiagramLayout> layouts = <String, KkDiagramLayout>{
    'layered LR': const KkLayeredLayout(),
    'layered TB': const KkLayeredLayout(direction: KkDiagramDirection.topToBottom),
    'tree LR': const KkTreeLayout(),
    'tree TB': const KkTreeLayout(direction: KkDiagramDirection.topToBottom),
    'radial': const KkRadialLayout(),
    'force': const KkForceLayout(),
  };
  final Map<String, KkEdgeRouter> houseRouters = <String, KkEdgeRouter>{
    'orthogonal': const KkEdgeRouter.orthogonal(),
    'orthogonal cut 0': const KkEdgeRouter.orthogonal(cut: 0),
    'octilinear': const KkEdgeRouter.octilinear(),
  };
  final List<KkDiagram> diagrams = <KkDiagram>[
    pipeline,
    randomDiagram(40, extra: 30, cyclic: true, seed: 5),
    randomDiagram(25, extra: 10, seed: 9),
    KkDiagram.parse('A --> A\nA --> B\nB --> A\nA --> B'),
  ];

  for (final MapEntry<String, KkDiagramLayout> layout in layouts.entries) {
    for (final MapEntry<String, KkEdgeRouter> router in houseRouters.entries) {
      test('${layout.key} + ${router.key}: straight lines and 45° only, border to border', () {
        for (final KkDiagram d in diagrams) {
          final KkDiagramGeometry g = layout.value.compute(d, router: router.value);
          for (int i = 0; i < d.edges.length; i++) {
            final String why = '${layout.key}/${router.key} edge $i';
            expectOctilinear(g.routes[i], reason: why);
            expectOnBorders(g, i, reason: why);
          }
        }
      });
    }

    test('${layout.key} + straight: border to border', () {
      for (final KkDiagram d in diagrams) {
        final KkDiagramGeometry g = layout.value.compute(d, router: const KkEdgeRouter.straight());
        for (int i = 0; i < d.edges.length; i++) {
          expectOnBorders(g, i, reason: '${layout.key}/straight edge $i');
        }
      }
    });
  }

  test('200 nodes: every route keeps the grammar', () {
    final KkDiagram d = randomDiagram(200, extra: 80, cyclic: true, seed: 3);
    for (final KkDiagramLayout layout in <KkDiagramLayout>[const KkLayeredLayout(), const KkForceLayout()]) {
      final KkDiagramGeometry g = layout.compute(d);
      for (int i = 0; i < d.edges.length; i++) {
        expectOctilinear(g.routes[i]);
        expectOnBorders(g, i);
      }
    }
  });

  group('orthogonal', () {
    test('a straight wire between neighbours in a rank line is two points', () {
      final KkDiagramGeometry g = const KkLayeredLayout().compute(KkDiagram.parse('A --> B'));
      expect(g.routes.single.points, hasLength(2));
      expect(g.routes.single.points.first.dy, g.routes.single.points.last.dy);
    });

    test('a bend is cut by the given size', () {
      final KkEdgeRoute r = const KkOrthogonalRouter(cut: 8).route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(200, 100, 24, 24),
          direction: KkDiagramDirection.leftToRight,
        ),
      );
      // run, cut, drop, cut, run
      expect(r.points, hasLength(6));
      expect(r.points[2] - r.points[1], const Offset(8, 8));
      expect(r.points[4] - r.points[3], const Offset(8, 8));
      expect(r.points.first, const Offset(24, 12));
      expect(r.points.last, const Offset(200, 112));
    });

    test('with no cut the bends stay square', () {
      final KkEdgeRoute r = const KkOrthogonalRouter(cut: 0).route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(200, 100, 24, 24),
          direction: KkDiagramDirection.leftToRight,
        ),
      );
      expect(r.points, hasLength(4));
    });

    test('a target behind the source is entered from its far side', () {
      final KkEdgeRoute r = const KkOrthogonalRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(200, 0, 24, 24),
          to: Rect.fromLTWH(0, 100, 24, 24),
          direction: KkDiagramDirection.leftToRight,
        ),
      );
      expectOctilinear(r);
      expect(r.points.first, const Offset(200, 12));
      expect(r.points.last, const Offset(24, 112));
    });

    test('a target in the same rank is reached by going round', () {
      final KkEdgeRoute r = const KkOrthogonalRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(0, 100, 24, 24),
          direction: KkDiagramDirection.leftToRight,
        ),
      );
      expectOctilinear(r);
      expect(r.points.first, const Offset(24, 12));
      expect(r.points.last, const Offset(0, 112));
      // Out to the right, back between the two symbols, in from the left.
      expect(r.points.any((Offset p) => p.dx > 24), isTrue);
      expect(r.points.any((Offset p) => p.dx < 0), isTrue);
    });

    test('a short jog becomes one diagonal', () {
      final KkEdgeRoute r = const KkOrthogonalRouter(cut: 8).route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(100, 8, 24, 24),
          direction: KkDiagramDirection.leftToRight,
        ),
      );
      // run, one 8px diagonal, run
      expect(r.points, hasLength(4));
      expect(r.points[2] - r.points[1], const Offset(8, 8));
    });
  });

  group('octilinear', () {
    test('side by side: run, diagonal, run', () {
      final KkEdgeRoute r = const KkOctilinearRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(200, 40, 24, 24),
        ),
      );
      expect(r.points, hasLength(4));
      expect(r.points[2] - r.points[1], const Offset(40, 40));
      expect(r.points.first, const Offset(24, 12));
      expect(r.points.last, const Offset(200, 52));
    });

    test('stacked: drop, diagonal, drop', () {
      final KkEdgeRoute r = const KkOctilinearRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(20, 200, 24, 24),
        ),
      );
      expect(r.points.first, const Offset(12, 24));
      expect(r.points.last, const Offset(32, 200));
      expectOctilinear(r);
    });

    test('diagonal neighbours: one bend, the lower symbol entered from the top', () {
      final KkEdgeRoute down = const KkOctilinearRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(0, 0, 24, 24),
          to: Rect.fromLTWH(100, 90, 24, 24),
        ),
      );
      expect(down.points.first, const Offset(24, 12));
      expect(down.points.last, const Offset(112, 90));
      expectOctilinear(down);
      final KkEdgeRoute up = const KkOctilinearRouter().route(
        const KkEdgeRequest(
          edge: KkDiagramEdge('A', 'B'),
          from: Rect.fromLTWH(100, 90, 24, 24),
          to: Rect.fromLTWH(0, 0, 24, 24),
        ),
      );
      expect(up.points.first, const Offset(112, 90));
      expect(up.points.last, const Offset(24, 12));
      expect(up.points, down.points.reversed.toList());
    });
  });

  group('wires to self and wires that close a cycle', () {
    test('a self wire is a small loop on the symbol', () {
      final KkDiagramGeometry g = const KkLayeredLayout().compute(KkDiagram.parse('A --> A'));
      final KkEdgeRoute r = g.routes.single;
      final Rect shape = g.nodes['A']!.shape;
      expect(r.points.first, shape.centerRight);
      expect(r.points.last, shape.topCenter);
      expectOctilinear(r);
      expect(r.endDirection, const Offset(0, 1));
    });

    test('a wire laid out backwards still runs from its own start to its own end', () {
      final KkDiagram d = KkDiagram.parse('A --> B --> C --> D\nD --> A');
      final KkDiagramGeometry g = const KkLayeredLayout().compute(d);
      final KkEdgeRoute back = g.routes[3];
      expect(kkDistanceToOutline(KkNodeKind.node, g.nodes['D']!.shape, back.points.first), lessThan(0.01));
      expect(kkDistanceToOutline(KkNodeKind.node, g.nodes['A']!.shape, back.points.last), lessThan(0.01));
      expectOctilinear(back);
    });
  });

  group('KkEdgeRoute', () {
    const KkEdgeRoute route = KkEdgeRoute(<Offset>[Offset(0, 0), Offset(10, 0), Offset(10, 30)]);

    test('length, points along it and directions', () {
      expect(route.length, 40);
      expect(route.pointAt(0), Offset.zero);
      expect(route.pointAt(5), const Offset(5, 0));
      expect(route.pointAt(25), const Offset(10, 15));
      expect(route.pointAt(999), const Offset(10, 30));
      expect(route.startDirection, const Offset(1, 0));
      expect(route.endDirection, const Offset(0, 1));
      expect(route.labelAnchor, const Offset(10, 15));
      expect(route.turned.points.first, const Offset(10, 30));
    });

    test('trimming', () {
      expect(route.trimmed(0), isEmpty);
      expect(route.trimmed(5), <Offset>[Offset.zero, const Offset(5, 0)]);
      expect(route.trimmed(10), <Offset>[Offset.zero, const Offset(10, 0)]);
      expect(route.trimmed(20), <Offset>[Offset.zero, const Offset(10, 0), const Offset(10, 10)]);
      expect(route.trimmed(99), route.points);
    });

    test('an empty route is harmless', () {
      expect(KkEdgeRoute.none.isEmpty, isTrue);
      expect(KkEdgeRoute.none.length, 0);
      expect(KkEdgeRoute.none.pointAt(3), Offset.zero);
      expect(KkEdgeRoute.none.labelAnchor, Offset.zero);
      expect(KkEdgeRoute.none.trimmed(4), isEmpty);
    });
  });

  test('the geometry grows to hold wires that leave the node box', () {
    final KkDiagramGeometry g = const KkLayeredLayout().compute(KkDiagram.parse('A --> A'));
    for (final Offset p in g.routes.single.points) {
      expect(p.dx >= 0 && p.dy >= 0, isTrue);
      expect(p.dx <= g.size.width && p.dy <= g.size.height, isTrue);
    }
    expect(g.nodeAt(g.nodes['A']!.anchor), 'A');
    expect(g.nodeAt(const Offset(-50, -50)), isNull);
  });
}
