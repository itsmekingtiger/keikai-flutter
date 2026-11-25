import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

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

/// Whether [route] passes through [box] (walked a pixel at a time).
bool runsThrough(KkEdgeRoute route, Rect box) {
  for (double at = 0; at <= route.length; at += 1) {
    if (box.contains(route.pointAt(at))) return true;
  }
  return false;
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

  test('random graphs: the grammar holds and no wire is sent through another symbol', () {
    final math.Random random = math.Random(42);
    final List<KkDiagramLayout> placed = <KkDiagramLayout>[
      const KkLayeredLayout(),
      const KkLayeredLayout(direction: KkDiagramDirection.topToBottom, nodeGap: 8, layerGap: 16),
      const KkTreeLayout(),
      const KkTreeLayout(direction: KkDiagramDirection.topToBottom),
      const KkRadialLayout(),
      const KkForceLayout(),
      const KkForceLayout(seed: 9, aspect: 2.4, spacing: 40),
    ];
    const List<KkEdgeRouter> routers = <KkEdgeRouter>[
      KkOrthogonalRouter(),
      KkOrthogonalRouter(cut: 0),
      KkOrthogonalRouter(cut: 40),
      KkOctilinearRouter(),
    ];
    const List<KkNodeMetrics> metricsList = <KkNodeMetrics>[
      KkNodeMetrics(),
      KkNodeMetrics(labelSide: KkLabelSide.right, textScale: 1.3),
    ];
    for (int round = 0; round < 24; round++) {
      final int n = 1 + random.nextInt(round < 16 ? 14 : 40);
      KkDiagram d = randomDiagram(n, extra: random.nextInt(n + 2), cyclic: random.nextBool(), seed: round);
      if (round % 3 == 0) {
        // Wires to self, doubled wires and a wire back.
        d = KkDiagram(
          nodes: d.nodes,
          edges: <KkDiagramEdge>[
            ...d.edges,
            KkDiagramEdge(d.nodes.first.id, d.nodes.first.id),
            if (d.edges.isNotEmpty) d.edges.first,
            if (d.edges.isNotEmpty) KkDiagramEdge(d.edges.first.to, d.edges.first.from, label: 'BACK'),
          ],
        );
      }
      expect(KkDiagram.parse(d.toSource()).toSource(), d.toSource(), reason: 'round $round');
      for (final KkDiagramLayout layout in placed) {
        for (final KkNodeMetrics metrics in metricsList) {
          for (final KkEdgeRouter router in routers) {
            final String why = 'round $round, ${layout.runtimeType} ${placed.indexOf(layout)}, $router';
            final KkDiagramGeometry g = layout.compute(d, metrics: metrics, router: router);
            expect(g.routes, hasLength(d.edges.length), reason: why);
            for (int i = 0; i < d.edges.length; i++) {
              final KkEdgeRoute r = g.routes[i];
              final KkDiagramEdge e = d.edges[i];
              expectOctilinear(r, reason: '$why wire $i');
              expectOnBorders(g, i, reason: '$why wire $i');
              for (final Offset p in r.points) {
                expect(
                  p.dx >= -0.01 && p.dy >= -0.01 && p.dx <= g.size.width + 0.01 && p.dy <= g.size.height + 0.01,
                  isTrue,
                  reason: '$why wire $i: $p outside ${g.size}',
                );
              }
              for (final MapEntry<String, KkNodePlacement> o in g.nodes.entries) {
                if (o.key == e.from || o.key == e.to) continue;
                expect(
                  runsThrough(r, o.value.shape),
                  isFalse,
                  reason: '$why wire $i ${e.from}->${e.to} through ${o.key} ${o.value.shape}: ${r.points}',
                );
              }
            }
          }
        }
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

  group('nodes in the way (free layouts)', () {
    const Rect a = Rect.fromLTWH(0, 100, 24, 24);
    const Rect b = Rect.fromLTWH(300, 100, 24, 24);
    const List<KkEdgeRouter> house = <KkEdgeRouter>[KkOctilinearRouter(), KkOrthogonalRouter()];

    KkEdgeRoute route(KkEdgeRouter router, List<Rect> obstacles, {bool back = false}) => router.route(
      KkEdgeRequest(
        edge: const KkDiagramEdge('A', 'B'),
        from: back ? b : a,
        to: back ? a : b,
        obstacles: obstacles,
      ),
    );

    test('with nothing in the way the wire is one straight run', () {
      for (final KkEdgeRouter router in house) {
        expect(route(router, const <Rect>[]).points, const <Offset>[Offset(24, 112), Offset(300, 112)]);
        // A node beside the line is not in the way.
        expect(
          route(router, const <Rect>[Rect.fromLTWH(140, 20, 40, 40)]).points,
          const <Offset>[Offset(24, 112), Offset(300, 112)],
        );
      }
    });

    test('a node on the line is passed in a lane 12px clear of it', () {
      const Rect wall = Rect.fromLTWH(140, 92, 40, 40);
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute round = route(router, const <Rect>[wall]);
        expectOctilinear(round);
        expect(round.points.first, const Offset(24, 112));
        expect(round.points.last, const Offset(300, 112));
        expect(runsThrough(round, wall.inflate(2)), isFalse, reason: '${round.points}');
        if (router is KkOctilinearRouter) {
          // Out, a 45° step up to the lane, along it, a step back, in.
          expect(round.points, const <Offset>[
            Offset(24, 112),
            Offset(28, 112),
            Offset(60, 80),
            Offset(264, 80),
            Offset(296, 112),
            Offset(300, 112),
          ]);
        } else {
          // The same way round with right angles, each cut by 8.
          expect(round.points, const <Offset>[
            Offset(24, 112),
            Offset(28, 112),
            Offset(36, 104),
            Offset(36, 88),
            Offset(44, 80),
            Offset(280, 80),
            Offset(288, 88),
            Offset(288, 104),
            Offset(296, 112),
            Offset(300, 112),
          ]);
        }
        // The same wire drawn from the other end takes the same way.
        expect(route(router, const <Rect>[wall], back: true).points, round.points.reversed.toList());
      }
    });

    test('the lane goes to the side that is free', () {
      // Two nodes in the way, and a third above them: only the lane below is clear.
      const List<Rect> walls = <Rect>[
        Rect.fromLTWH(100, 96, 32, 32),
        Rect.fromLTWH(180, 88, 32, 48),
        Rect.fromLTWH(120, 60, 80, 24),
      ];
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute round = route(router, walls);
        expectOctilinear(round);
        for (final Rect wall in walls) {
          expect(runsThrough(round, wall), isFalse, reason: '$wall in ${round.points}');
        }
        // It passes under the lowest of them, and not far under.
        final double lowest = round.points.map((Offset p) => p.dy).reduce((double x, double y) => x > y ? x : y);
        expect(lowest, inInclusiveRange(136 + 8, 136 + 16), reason: '${round.points}');
      }
    });

    test('with no way past, the wire still joins its two symbols', () {
      const Rect wall = Rect.fromLTWH(140, -2000, 40, 4000);
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute through = route(router, const <Rect>[wall]);
        expectOctilinear(through);
        expect(through.points.first, const Offset(24, 112));
        expect(through.points.last, const Offset(300, 112));
      }
    });

    test('stacked nodes are passed sideways', () {
      const Rect top = Rect.fromLTWH(100, 0, 24, 24);
      const Rect bottom = Rect.fromLTWH(100, 300, 24, 24);
      const Rect wall = Rect.fromLTWH(92, 140, 40, 40);
      final KkEdgeRoute round = const KkOctilinearRouter().route(
        const KkEdgeRequest(edge: KkDiagramEdge('A', 'B'), from: top, to: bottom, obstacles: <Rect>[wall]),
      );
      expectOctilinear(round);
      expect(round.points.first, const Offset(112, 24));
      expect(round.points.last, const Offset(112, 300));
      expect(runsThrough(round, wall.inflate(2)), isFalse, reason: '${round.points}');
    });

    test('a wire leaves by the side rather than run under the text of its own node', () {
      // The upper node has its text underneath, the lower one stands down and to the left.
      const Rect upper = Rect.fromLTWH(200, 0, 24, 24);
      const Rect text = Rect.fromLTWH(188, 30, 48, 22);
      const Rect lower = Rect.fromLTWH(100, 200, 32, 36);
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute plain = router.route(
          const KkEdgeRequest(edge: KkDiagramEdge('A', 'B'), from: upper, to: lower),
        );
        expect(plain.points.first, const Offset(212, 24), reason: 'no text known: straight down');
        expect(runsThrough(plain, text), isTrue);

        final KkEdgeRoute clear = router.route(
          const KkEdgeRequest(edge: KkDiagramEdge('A', 'B'), from: upper, to: lower, texts: <Rect>[text]),
        );
        expectOctilinear(clear);
        expect(clear.points.first, const Offset(200, 12), reason: 'out of the side that faces the other node');
        expect(clear.points.last, const Offset(116, 200), reason: 'into the top of the lower node');
        expect(runsThrough(clear, text.inflate(2)), isFalse, reason: '${clear.points}');

        // Drawn from the other end it is the same line.
        final KkEdgeRoute back = router.route(
          const KkEdgeRequest(edge: KkDiagramEdge('B', 'A'), from: lower, to: upper, texts: <Rect>[text]),
        );
        expect(back.points, clear.points.reversed.toList());
      }
    });

    test('with no clean bend the wire stays where it was', () {
      const Rect upper = Rect.fromLTWH(200, 0, 24, 24);
      const Rect text = Rect.fromLTWH(188, 30, 48, 22);
      // Straight below: there is no side to leave by.
      const Rect below = Rect.fromLTWH(200, 200, 24, 24);
      // Down and to the left, but another node stands on the bend.
      const Rect lower = Rect.fromLTWH(100, 200, 32, 36);
      const Rect onTheBend = Rect.fromLTWH(104, 80, 24, 24);
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute straight = router.route(
          const KkEdgeRequest(edge: KkDiagramEdge('A', 'B'), from: upper, to: below, texts: <Rect>[text]),
        );
        expect(straight.points, const <Offset>[Offset(212, 24), Offset(212, 200)]);

        final KkEdgeRoute kept = router.route(
          const KkEdgeRequest(
            edge: KkDiagramEdge('A', 'B'),
            from: upper,
            to: lower,
            texts: <Rect>[text],
            obstacles: <Rect>[onTheBend],
          ),
        );
        expectOctilinear(kept);
        expect(kept.points.first, const Offset(212, 24));
        expect(runsThrough(kept, onTheBend), isFalse);
      }
    });

    test('when no simple shape gets past, a way is searched for', () {
      // A wall on the line, and two more that shut the lanes over and under it.
      const List<Rect> walls = <Rect>[
        Rect.fromLTWH(140, 92, 40, 40),
        Rect.fromLTWH(60, 60, 200, 24),
        Rect.fromLTWH(60, 140, 200, 24),
      ];
      for (final KkEdgeRouter router in house) {
        for (final bool back in <bool>[false, true]) {
          final KkEdgeRoute found = route(router, walls, back: back);
          expectOctilinear(found);
          // From the middle of a side of one symbol to the middle of a side of the other.
          final Rect first = back ? b : a;
          final Rect last = back ? a : b;
          expect(kkDistanceToOutline(KkNodeKind.node, first, found.points.first), lessThan(0.01));
          expect(kkDistanceToOutline(KkNodeKind.node, last, found.points.last), lessThan(0.01));
          expect(
            found.points.first.dx == first.center.dx || found.points.first.dy == first.center.dy,
            isTrue,
            reason: '${found.points}',
          );
          expect(
            found.points.last.dx == last.center.dx || found.points.last.dy == last.center.dy,
            isTrue,
            reason: '${found.points}',
          );
          // Eight clear along a wall, four where a cut bend rounds its corner.
          for (final Rect wall in walls) {
            expect(runsThrough(found, wall.inflate(3)), isFalse, reason: '$wall in ${found.points}');
          }
          // Over the upper wall or under the lower one, eight clear of it.
          final Iterable<double> ys = found.points.map((Offset p) => p.dy);
          final double top = ys.reduce(math.min);
          final double bottom = ys.reduce(math.max);
          expect(top == 52 || bottom == 172, isTrue, reason: '${found.points}');
        }
      }
    });

    test('a searched way keeps off the text of its own two nodes as well', () {
      const Rect textA = Rect.fromLTWH(-18, 130, 60, 22);
      const Rect textB = Rect.fromLTWH(282, 130, 60, 22);
      const List<Rect> walls = <Rect>[
        Rect.fromLTWH(140, 92, 40, 40),
        Rect.fromLTWH(60, 60, 200, 24),
      ];
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute found = router.route(
          const KkEdgeRequest(
            edge: KkDiagramEdge('A', 'B'),
            from: a,
            to: b,
            obstacles: walls,
            texts: <Rect>[textA, textB],
          ),
        );
        expectOctilinear(found);
        for (final Rect keepOff in <Rect>[...walls, textA, textB]) {
          expect(runsThrough(found, keepOff.inflate(2)), isFalse, reason: '$keepOff in ${found.points}');
        }
      }
    });

    test('walled in on every side, the wire is still drawn', () {
      const List<Rect> cage = <Rect>[
        Rect.fromLTWH(-40, 60, 104, 24),
        Rect.fromLTWH(-40, 140, 104, 24),
        Rect.fromLTWH(-40, 60, 24, 104),
        Rect.fromLTWH(40, 60, 24, 104),
      ];
      for (final KkEdgeRouter router in house) {
        final KkEdgeRoute through = route(router, cage);
        expectOctilinear(through);
        expect(through.points.length, greaterThanOrEqualTo(2));
        expect(kkDistanceToOutline(KkNodeKind.node, a, through.points.first), lessThan(0.01));
        expect(kkDistanceToOutline(KkNodeKind.node, b, through.points.last), lessThan(0.01));
      }
    });

    test('a free layout hands the other nodes to its router', () {
      final KkDiagram d = KkDiagram(
        nodes: const <KkDiagramNode>[
          KkDiagramNode('A', position: Offset(40, 100)),
          KkDiagramNode('X', code: 'IN-THE-WAY', position: Offset(200, 100)),
          KkDiagramNode('B', position: Offset(360, 100)),
        ],
        edges: const <KkDiagramEdge>[KkDiagramEdge('A', 'B'), KkDiagramEdge('A', 'X')],
      );
      const KkManualLayout layout = KkManualLayout(normalised: false);
      for (final KkEdgeRouter router in house) {
        final KkDiagramGeometry g = layout.compute(d, router: router);
        for (int i = 0; i < d.edges.length; i++) {
          expectOctilinear(g.routes[i]);
          expectOnBorders(g, i);
        }
        expect(runsThrough(g.routes[0], g.nodes['X']!.bounds), isFalse, reason: '${g.routes[0].points}');
        // The wire that ends at X is not sent round X.
        expect(g.routes[1].points, hasLength(2));
      }
      // One straight line goes through whatever stands on it.
      final KkDiagramGeometry straight = layout.compute(d, router: const KkEdgeRouter.straight());
      expect(runsThrough(straight.routes[0], straight.nodes['X']!.bounds), isTrue);
    });

    test('a layout with a flow keeps its lanes: nothing is handed over', () {
      final List<KkEdgeRequest> seen = <KkEdgeRequest>[];
      final _Recorder recorder = _Recorder(seen);
      recorder.routeAll(pipeline, const KkLayeredLayout().place(pipeline));
      expect(seen, hasLength(pipeline.edges.length));
      expect(seen.every((KkEdgeRequest r) => r.obstacles.isEmpty), isTrue);
      expect(seen.every((KkEdgeRequest r) => r.texts.isEmpty), isTrue);
      seen.clear();
      final KkDiagramPlacement free = const KkForceLayout().place(pipeline);
      recorder.routeAll(pipeline, free);
      expect(seen.every((KkEdgeRequest r) => r.obstacles.length == pipeline.nodes.length - 2), isTrue);
      for (final KkEdgeRequest r in seen) {
        expect(r.texts, <Rect>[?free.nodes[r.edge.from]!.text, ?free.nodes[r.edge.to]!.text]);
      }
    });

    test('in a network no wire runs under the text of a node it does not have to', () {
      final KkDiagram d = KkDiagram.parse('''
GA((GRID-A|MAIN BUS)) --- GB((GRID-B|AUX BUS))
S1[SEC-01|REACTOR] --- GA
S2[SEC-02|TURBINE] --- GA
GA --- S3[SEC-03|COOLANT]
GA --- S4[SEC-04|PUMP HALL]
GB --- S5[SEC-05|BATTERY]
GB --- S6[SEC-06|UPLINK]
GB --- L1>L-71]
GB --- L2>L-72]
S4 --- GB
''');
      final KkDiagramGeometry g = const KkForceLayout(spacing: 104, aspect: 1.7).compute(d);
      for (int i = 0; i < d.edges.length; i++) {
        expectOctilinear(g.routes[i]);
        expectOnBorders(g, i);
        for (final MapEntry<String, KkNodePlacement> n in g.nodes.entries) {
          if (n.key == d.edges[i].from || n.key == d.edges[i].to) continue;
          expect(runsThrough(g.routes[i], n.value.bounds), isFalse, reason: 'wire $i through ${n.key}');
        }
      }
      expect(g.coveredTexts, isEmpty);
    });
  });

  group('flow layouts', () {
    const List<KkEdgeRouter> anyCut = <KkEdgeRouter>[
      KkOrthogonalRouter(),
      KkOrthogonalRouter(cut: 0),
      KkOrthogonalRouter(cut: 40),
      KkOctilinearRouter(),
    ];

    void expectNoWireThroughANode(KkDiagramGeometry g, String why, {bool symbolsOnly = false}) {
      for (int i = 0; i < g.diagram.edges.length; i++) {
        final KkDiagramEdge e = g.diagram.edges[i];
        for (final MapEntry<String, KkNodePlacement> n in g.nodes.entries) {
          if (n.key == e.from || n.key == e.to) continue;
          expect(
            runsThrough(g.routes[i], symbolsOnly ? n.value.shape : n.value.bounds),
            isFalse,
            reason: '$why: wire $i ${e.from}->${e.to} through ${n.key} ${g.routes[i].points}',
          );
        }
      }
    }

    test('a layered layout says how far a bend may be cut, and no router cuts further', () {
      final KkDiagramPlacement p = const KkLayeredLayout().place(pipeline);
      int bent = 0;
      for (final KkEdgeHint hint in p.hints.values) {
        if (hint.maxCut.isFinite) {
          bent++;
          // A track is never nearer than 16 to the ranks beside it.
          expect(hint.maxCut, greaterThanOrEqualTo(16));
        }
      }
      expect(bent, greaterThan(0));
      expect(const KkEdgeHint(maxCut: 12), isNot(const KkEdgeHint(maxCut: 16)));
      expect(const KkEdgeHint(maxCut: 12).shift(const Offset(4, 8), horizontal: true).maxCut, 12);

      // The same wire, asked for an endless cut: the diagonals stop at maxCut.
      final KkDiagramGeometry g = const KkLayeredLayout().compute(pipeline, router: const KkEdgeRouter.octilinear());
      for (int i = 0; i < pipeline.edges.length; i++) {
        final double limit = p.hints[i]!.maxCut;
        final List<Offset> pts = g.routes[i].points;
        for (int k = 1; k < pts.length; k++) {
          final Offset leg = pts[k] - pts[k - 1];
          if (leg.dx.abs() > 0.01 && leg.dy.abs() > 0.01) {
            // Two cuts that meet make one diagonal, so twice the limit at most.
            expect(leg.dx.abs(), lessThanOrEqualTo(2 * limit + 0.01), reason: 'wire $i leg $leg limit $limit');
          }
        }
      }
    });

    test('layered: whichever house router draws them, wires pass no other symbol', () {
      final List<KkDiagram> diagrams = <KkDiagram>[
        pipeline,
        for (int seed = 0; seed < 12; seed++) randomDiagram(8 + seed * 3, extra: 6 + seed * 2, cyclic: seed.isOdd, seed: seed),
      ];
      for (final KkDiagramLayout layout in <KkDiagramLayout>[
        const KkLayeredLayout(),
        const KkLayeredLayout(direction: KkDiagramDirection.topToBottom),
        const KkLayeredLayout(nodeGap: 8, layerGap: 16),
      ]) {
        for (final KkEdgeRouter router in anyCut) {
          for (final KkDiagram d in diagrams) {
            expectNoWireThroughANode(layout.compute(d, router: router), '$layout $router', symbolsOnly: true);
          }
        }
      }
    });

    const String command = '''
flow TB
HQ((HQ-00|COMMAND)) --> OPS[OPS-10|OPERATIONS]
HQ --> ENG[ENG-20|ENGINEERING]
HQ --> COM[COM-30|SIGNALS]
OPS --> O1[OP-11|WATCH A]
OPS --> O2[OP-12|WATCH B]
ENG --> E1[EN-21|REACTOR]
ENG --> E2[EN-22|COOLANT]
COM --> C1[CM-31|UPLINK]
COM --> C2[CM-32|RELAY]
COM --> C3[CM-33|ARCHIVE]
E1 --> X1[EX-41|PUMP]
E1 --> X2[EX-42|VALVE]
OPS -.-> E2
C1 ==> HQ
O1 --- O2
HQ --> X2
O2 --> C2
X1 --> COM
''';

    test('tree: the first wire into a node names its parent, later wires are extra', () {
      final KkDiagram d = KkDiagram.parse(command);
      final KkDiagramForest f = KkDiagramForest.of(d);
      String? parent(String id) => f.parent[d.indexOf(id)] < 0 ? null : d.nodes[f.parent[d.indexOf(id)]].id;
      expect(f.roots, <int>[d.indexOf('HQ')]);
      expect(parent('HQ'), isNull);
      expect(<String?>[parent('OPS'), parent('ENG'), parent('COM')], <String?>['HQ', 'HQ', 'HQ']);
      expect(<String?>[parent('O1'), parent('O2')], <String?>['OPS', 'OPS']);
      expect(<String?>[parent('E1'), parent('E2')], <String?>['ENG', 'ENG']);
      expect(<String?>[parent('C1'), parent('C2'), parent('C3')], <String?>['COM', 'COM', 'COM']);
      expect(<String?>[parent('X1'), parent('X2')], <String?>['E1', 'E1']);
      // The twelve wires of the tree are the first twelve written.
      expect(f.treeEdge, <int>{for (int i = 0; i < 12; i++) i});
      expect(f.depth[d.indexOf('X2')], 3);
      expect(<String>[for (final int c in f.children[d.indexOf('COM')]) d.nodes[c].id], <String>['C1', 'C2', 'C3']);

      // Two trees that share a node: it goes to the wire written first.
      final KkDiagram shared = KkDiagram.parse('B --> X\nA --> X\nA --> Y');
      final KkDiagramForest two = KkDiagramForest.of(shared);
      expect(<String>[for (final int r in two.roots) shared.nodes[r].id], <String>['B', 'A']);
      expect(two.parent[shared.indexOf('X')], shared.indexOf('B'));
      expect(two.treeEdge, <int>{0, 2});

      // Followed both ways, one root takes everything joined to it.
      final KkDiagramForest both = KkDiagramForest.of(shared, undirected: true);
      expect(both.roots, hasLength(1));
      expect(both.treeEdge, <int>{0, 1, 2});

      // Breadth first, a short cut written last still pulls its node up.
      final KkDiagram cut = KkDiagram.parse('A --> B --> C --> D\nA --> D');
      expect(KkDiagramForest.of(cut).depth[cut.indexOf('D')], 3);
      expect(KkDiagramForest.of(cut, breadthFirst: true).depth[cut.indexOf('D')], 1);

      // A ring has no node nothing points at: its first node is the root.
      final KkDiagram ring = KkDiagram.parse('B --> C --> A --> B');
      final KkDiagramForest loop = KkDiagramForest.of(ring);
      expect(<String>[for (final int r in loop.roots) ring.nodes[r].id], <String>['B']);
      expect(loop.treeEdge, <int>{0, 1});
      expect(KkDiagramForest.of(KkDiagram.empty).roots, isEmpty);
    });

    test('tree: extra wires go round the nodes and their text', () {
      final KkDiagram d = KkDiagram.parse(command);
      for (final KkDiagramDirection direction in KkDiagramDirection.values) {
        for (final KkEdgeRouter router in anyCut) {
          final KkDiagramGeometry g = KkTreeLayout(direction: direction).compute(d, router: router);
          for (int i = 0; i < d.edges.length; i++) {
            expectOctilinear(g.routes[i], reason: '$direction $router wire $i');
            expectOnBorders(g, i, reason: '$direction $router wire $i');
          }
          expectNoWireThroughANode(g, '$direction $router');
        }
      }
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

class _Recorder extends KkEdgeRouter {
  const _Recorder(this.seen);

  final List<KkEdgeRequest> seen;

  @override
  KkEdgeRoute route(KkEdgeRequest request) {
    seen.add(request);
    return const KkStraightRouter().route(request);
  }
}
