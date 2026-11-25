import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// A random but repeatable diagram of [n] nodes: a spanning tree plus [extra]
/// more wires. With [cyclic] false every wire runs from a lower to a higher
/// index.
KkDiagram randomDiagram(int n, {int extra = 0, bool cyclic = false, int seed = 7}) {
  final math.Random random = math.Random(seed);
  const List<KkNodeKind> kinds = KkNodeKind.values;
  final List<KkDiagramNode> nodes = <KkDiagramNode>[
    for (int i = 0; i < n; i++)
      KkDiagramNode(
        'N$i',
        code: 'N-${i.toString().padLeft(3, '0')}',
        label: i % 3 == 0 ? 'UNIT $i' : null,
        kind: kinds[i % kinds.length],
      ),
  ];
  final List<KkDiagramEdge> edges = <KkDiagramEdge>[
    for (int i = 1; i < n; i++) KkDiagramEdge('N${random.nextInt(i)}', 'N$i'),
  ];
  for (int k = 0; k < extra && n > 1; k++) {
    int a = random.nextInt(n);
    int b = random.nextInt(n);
    if (a == b) continue;
    if (!cyclic && a > b) {
      final int t = a;
      a = b;
      b = t;
    }
    edges.add(KkDiagramEdge('N$a', 'N$b'));
  }
  return KkDiagram(nodes: nodes, edges: edges);
}

final KkDiagram pipeline = KkDiagram.parse('''
flow LR
IN([INTAKE]) --> F1[SEC-01|FILTER]
F1 --> P1[SEC-02|PUMP A]
F1 --> P2[SEC-03|PUMP B]
P1 --> MIX((CORE|MIXER))
P2 --> MIX
MIX --> CHK{PRESSURE}
CHK -->|OK| OUT([OUTLET])
CHK -->|LOW| P1
IN --> OUT
MIX --> L1>DRAIN]
''');

void expectNoOverlap(KkDiagramPlacement placement) {
  final List<MapEntry<String, KkNodePlacement>> all = placement.nodes.entries.toList();
  for (int i = 0; i < all.length; i++) {
    for (int j = i + 1; j < all.length; j++) {
      final Rect hit = all[i].value.bounds.intersect(all[j].value.bounds);
      expect(
        hit.width > 0.001 && hit.height > 0.001,
        isFalse,
        reason: '${all[i].key} ${all[i].value.bounds} overlaps ${all[j].key} ${all[j].value.bounds}',
      );
    }
  }
}

void expectOnGrid(KkDiagramPlacement placement) {
  for (final MapEntry<String, KkNodePlacement> e in placement.nodes.entries) {
    expect(e.value.anchor.dx % 4, 0, reason: '${e.key} x ${e.value.anchor.dx}');
    expect(e.value.anchor.dy % 4, 0, reason: '${e.key} y ${e.value.anchor.dy}');
  }
}

void expectInside(KkDiagramPlacement placement) {
  for (final MapEntry<String, KkNodePlacement> e in placement.nodes.entries) {
    final Rect b = e.value.bounds;
    expect(b.left >= 0 && b.top >= 0, isTrue, reason: '${e.key} $b starts outside');
    expect(b.right <= placement.size.width && b.bottom <= placement.size.height, isTrue, reason: '${e.key} $b ends outside ${placement.size}');
  }
}

void main() {
  final Map<String, KkDiagramLayout> layouts = <String, KkDiagramLayout>{
    'layered LR': const KkLayeredLayout(),
    'layered TB': const KkLayeredLayout(direction: KkDiagramDirection.topToBottom),
    'tree LR': const KkTreeLayout(),
    'tree TB': const KkTreeLayout(direction: KkDiagramDirection.topToBottom),
    'radial': const KkRadialLayout(),
    'force': const KkForceLayout(),
    'manual': const KkManualLayout(),
  };

  for (final MapEntry<String, KkDiagramLayout> entry in layouts.entries) {
    final KkDiagramLayout layout = entry.value;
    group(entry.key, () {
      test('is deterministic', () {
        final KkDiagram d = randomDiagram(40, extra: 20, cyclic: true);
        final KkDiagramPlacement a = layout.place(d);
        final KkDiagramPlacement b = layout.place(d);
        expect(a.size, b.size);
        expect(a.nodes, b.nodes);
        expect(a.hints, b.hints);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(layout.compute(d), layout.compute(d));
      });

      test('places every node, apart, inside and on the grid', () {
        for (final KkDiagram d in <KkDiagram>[
          pipeline,
          randomDiagram(30, extra: 12),
          randomDiagram(30, extra: 30, cyclic: true, seed: 11),
        ]) {
          final KkDiagramPlacement p = layout.place(d);
          expect(p.nodes.keys.toSet(), d.nodes.map((KkDiagramNode n) => n.id).toSet());
          if (layout is! KkManualLayout) expectNoOverlap(p);
          expectOnGrid(p);
          expectInside(p);
        }
      });

      test('an empty diagram and a single node', () {
        final KkDiagramPlacement none = layout.place(KkDiagram.empty);
        expect(none.nodes, isEmpty);
        expect(none.size.width >= 0 && none.size.height >= 0, isTrue);
        expect(layout.compute(KkDiagram.empty).routes, isEmpty);

        final KkDiagram one = KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('ONLY')]);
        final KkDiagramPlacement p = layout.place(one);
        expect(p.nodes, hasLength(1));
        expectInside(p);
        expect(p.size.width > 0 && p.size.height > 0, isTrue);
      });

      test('nodes without wires, wires to self and doubled wires', () {
        final KkDiagram d = KkDiagram.parse('A --> A\nA --> B\nA --> B\nB --> A\nC\nD');
        final KkDiagramGeometry g = layout.compute(d);
        expect(g.nodes, hasLength(4));
        expect(g.routes, hasLength(4));
        for (final KkEdgeRoute r in g.routes) {
          expect(r.isEmpty, isFalse);
          for (final Offset p in r.points) {
            expect(p.dx >= 0 && p.dy >= 0 && p.dx <= g.size.width && p.dy <= g.size.height, isTrue, reason: '$p outside ${g.size}');
          }
        }
      });

      test('cycles terminate', () {
        final KkDiagram ring = KkDiagram.parse('A --> B --> C --> D --> A\nC --> A\nB --> D --> B');
        final KkDiagramPlacement p = layout.place(ring);
        expect(p.nodes, hasLength(4));
        if (layout is! KkManualLayout) expectNoOverlap(p);
      });

      test('200 nodes within the time budget', () {
        final KkDiagram d = randomDiagram(200, extra: 80, cyclic: true, seed: 3);
        final Stopwatch watch = Stopwatch()..start();
        final KkDiagramGeometry g = layout.compute(d);
        watch.stop();
        expect(g.nodes, hasLength(200));
        expect(g.routes, hasLength(d.edges.length));
        expect(watch.elapsed, lessThan(const Duration(seconds: 8)));
      });

      test('long text and tiny custom sizes', () {
        final KkDiagram d = KkDiagram(
          nodes: const <KkDiagramNode>[
            KkDiagramNode('A', code: 'A-VERY-LONG-CODE-THAT-GOES-ON-AND-ON-0123456789', label: 'WITH AN EQUALLY LONG LABEL UNDERNEATH IT'),
            KkDiagramNode('B', size: Size(2, 2)),
            KkDiagramNode('C', size: Size(160, 96), cjk: '冷却系統異常'),
          ],
          edges: const <KkDiagramEdge>[KkDiagramEdge('A', 'B'), KkDiagramEdge('B', 'C')],
        );
        final KkDiagramPlacement p = layout.place(d);
        if (layout is! KkManualLayout) expectNoOverlap(p);
        expect(p.nodes['C']!.shape.size, const Size(160, 96));
      });
    });
  }

  group('layered', () {
    test('every wire of a DAG points along the flow', () {
      for (final KkDiagramDirection dir in KkDiagramDirection.values) {
        final KkDiagram d = randomDiagram(60, extra: 40);
        final KkDiagramPlacement p = KkLayeredLayout(direction: dir).place(d);
        for (final KkDiagramEdge e in d.edges) {
          final Offset a = p.nodes[e.from]!.anchor;
          final Offset b = p.nodes[e.to]!.anchor;
          if (dir == KkDiagramDirection.leftToRight) {
            expect(b.dx, greaterThan(a.dx), reason: '${e.from} -> ${e.to}');
          } else {
            expect(b.dy, greaterThan(a.dy), reason: '${e.from} -> ${e.to}');
          }
        }
        expect(p.direction, dir);
      }
    });

    test('takes the direction of the diagram unless told otherwise', () {
      final KkDiagram d = KkDiagram.parse('flow TB\nA --> B');
      final KkDiagramPlacement p = const KkLayeredLayout().place(d);
      expect(p.direction, KkDiagramDirection.topToBottom);
      expect(p.nodes['B']!.anchor.dy, greaterThan(p.nodes['A']!.anchor.dy));
      expect(p.nodes['B']!.anchor.dx, p.nodes['A']!.anchor.dx);
    });

    test('a chain is one straight line', () {
      final KkDiagramPlacement p = const KkLayeredLayout().place(KkDiagram.parse('A --> B --> C --> D'));
      final double y = p.nodes['A']!.anchor.dy;
      for (final String id in <String>['B', 'C', 'D']) {
        expect(p.nodes[id]!.anchor.dy, y);
      }
    });

    test('a wire that skips ranks gets a lane point in each one, in a straight line', () {
      final KkDiagram d = KkDiagram.parse('A --> B --> C --> D\nA --> D');
      final KkDiagramPlacement p = const KkLayeredLayout().place(d);
      final KkEdgeHint hint = p.hints[3]!;
      expect(hint.waypoints, hasLength(2));
      expect(hint.waypoints[0].dy, hint.waypoints[1].dy);
      expect(hint.reversed, isFalse);
    });

    test('a wire that closes a cycle is laid out backwards', () {
      final KkDiagram d = KkDiagram.parse('A --> B --> C\nC --> A');
      final KkDiagramPlacement p = const KkLayeredLayout().place(d);
      expect(p.hints[2]!.reversed, isTrue);
      expect(p.hints[0]!.reversed, isFalse);
      expect(p.nodes['C']!.anchor.dx, greaterThan(p.nodes['A']!.anchor.dx));
    });

    test('two parents share a child without crossing', () {
      final KkDiagram d = KkDiagram.parse('A --> C\nB --> D\nA --> D\nB --> C');
      final KkDiagramPlacement p = const KkLayeredLayout().place(d);
      expect(p.nodes['A']!.anchor.dx, p.nodes['B']!.anchor.dx);
      expect(p.nodes['C']!.anchor.dx, p.nodes['D']!.anchor.dx);
    });

    test('gaps are respected', () {
      const KkLayeredLayout layout = KkLayeredLayout(nodeGap: 40, layerGap: 120);
      final KkDiagramPlacement p = layout.place(KkDiagram.parse('A --> B\nA --> C'));
      expect(p.nodes['B']!.bounds.left - p.nodes['A']!.bounds.right, greaterThanOrEqualTo(120));
      final Rect b = p.nodes['B']!.bounds;
      final Rect c = p.nodes['C']!.bounds;
      expect((c.top - b.bottom).abs() >= 40 || (b.top - c.bottom).abs() >= 40, isTrue);
    });

    test('text goes to the right of the symbols when the flow is vertical', () {
      final KkDiagram d = KkDiagram.parse('flow TB\nA[SEC-01|PUMP] --> B[SEC-02|VALVE]');
      final KkNodePlacement a = const KkLayeredLayout().place(d).nodes['A']!;
      expect(a.text!.left, greaterThan(a.shape.right));
      final KkNodePlacement lr = const KkLayeredLayout(direction: KkDiagramDirection.leftToRight).place(d).nodes['A']!;
      expect(lr.text!.top, greaterThan(lr.shape.bottom));
    });
  });

  group('tree', () {
    final KkDiagram tree = KkDiagram.parse('''
flow TB
HQ((HQ)) --> OPS[OPS]
HQ --> ENG[ENG]
HQ --> COM[COM]
OPS --> O1[OP-01]
OPS --> O2[OP-02]
ENG --> E1[EN-01]
COM --> C1[CM-01]
COM --> C2[CM-02]
COM --> C3[CM-03]
''');

    test('leaves keep their order and parents sit over their children', () {
      final KkDiagramPlacement p = const KkTreeLayout().place(tree);
      double x(String id) => p.nodes[id]!.anchor.dx;
      double y(String id) => p.nodes[id]!.anchor.dy;
      final List<String> leaves = <String>['O1', 'O2', 'E1', 'C1', 'C2', 'C3'];
      for (int i = 1; i < leaves.length; i++) {
        expect(x(leaves[i]), greaterThan(x(leaves[i - 1])));
      }
      expect(x('OPS'), closeTo((x('O1') + x('O2')) / 2, 2));
      expect(x('ENG'), x('E1'));
      expect(x('COM'), closeTo((x('C1') + x('C3')) / 2, 2));
      expect(x('HQ'), closeTo((x('OPS') + x('COM')) / 2, 2));
      expect(y('OPS'), y('ENG'));
      expect(y('O1'), y('C3'));
      expect(y('O1'), greaterThan(y('OPS')));
      expect(y('OPS'), greaterThan(y('HQ')));
    });

    test('several roots make a forest side by side', () {
      final KkDiagramPlacement p = const KkTreeLayout().place(KkDiagram.parse('flow TB\nA --> B\nC --> D\nE'));
      expect(p.nodes['C']!.bounds.left, greaterThan(p.nodes['A']!.bounds.right));
      expect(p.nodes['E']!.bounds.left, greaterThan(p.nodes['C']!.bounds.right));
      expect(p.nodes['A']!.anchor.dy, p.nodes['C']!.anchor.dy);
    });

    test('forest structure', () {
      final KkDiagramForest f = KkDiagramForest.of(tree);
      expect(f.roots, <int>[tree.indexOf('HQ')]);
      expect(f.depth[tree.indexOf('C3')], 2);
      expect(f.parent[tree.indexOf('E1')], tree.indexOf('ENG'));
      expect(f.treeEdge, hasLength(tree.edges.length));
      final KkDiagramForest cyclic = KkDiagramForest.of(KkDiagram.parse('A --> B --> A'));
      expect(cyclic.roots, <int>[0]);
      expect(cyclic.treeEdge, <int>{0});
    });
  });

  group('radial', () {
    test('the root is in the middle and a ring is a circle', () {
      final KkDiagram d = KkDiagram.parse('C((CORE)) --- A\nC --- B\nC --- D\nC --- E\nC --- F\nA --- A1\nA --- A2');
      final KkDiagramPlacement p = const KkRadialLayout(root: 'C').place(d);
      final Offset c = p.nodes['C']!.anchor;
      final double r = (p.nodes['A']!.anchor - c).distance;
      for (final String id in <String>['B', 'D', 'E', 'F']) {
        expect((p.nodes[id]!.anchor - c).distance, closeTo(r, 4));
      }
      expect((p.nodes['A1']!.anchor - c).distance, greaterThan(r + 30));
    });

    test('wires are followed both ways from the root', () {
      final KkDiagramPlacement p = const KkRadialLayout(root: 'B').place(KkDiagram.parse('A --> B --> C'));
      final Offset b = p.nodes['B']!.anchor;
      expect((p.nodes['A']!.anchor - b).distance, closeTo((p.nodes['C']!.anchor - b).distance, 4));
    });

    test('separate parts get separate maps', () {
      final KkDiagramPlacement p = const KkRadialLayout().place(KkDiagram.parse('A --> B\nA --> C\nX --> Y'));
      final double rightOfFirst = <String>['A', 'B', 'C'].map((String id) => p.nodes[id]!.bounds.right).reduce(math.max);
      expect(p.nodes['X']!.bounds.left, greaterThanOrEqualTo(rightOfFirst));
      expect(p.nodes['Y']!.bounds.left, greaterThanOrEqualTo(rightOfFirst));
    });
  });

  group('force', () {
    test('the seed changes the arrangement, the same seed repeats it', () {
      final KkDiagram d = randomDiagram(16, extra: 8, cyclic: true);
      final KkDiagramPlacement a = const KkForceLayout(seed: 1).place(d);
      final KkDiagramPlacement b = const KkForceLayout(seed: 2).place(d);
      final KkDiagramPlacement c = const KkForceLayout(seed: 1).place(d);
      expect(a.nodes, c.nodes);
      expect(a.nodes, isNot(b.nodes));
    });

    test('joined nodes end up nearer than unjoined ones on average', () {
      final KkDiagram d = KkDiagram.parse('A --- B --- C --- D --- E --- F --- G --- H');
      final KkDiagramPlacement p = const KkForceLayout().place(d);
      double dist(String a, String b) => (p.nodes[a]!.anchor - p.nodes[b]!.anchor).distance;
      expect(dist('A', 'B'), lessThan(dist('A', 'H')));
      expect(dist('D', 'E'), lessThan(dist('A', 'H')));
    });

    test('zero iterations still separates the nodes', () {
      final KkDiagramPlacement p = const KkForceLayout(iterations: 0, spacing: 4).place(randomDiagram(25));
      expectNoOverlap(p);
    });

    test('aspect turns the long side of the network and stretches it towards the ratio', () {
      for (final KkDiagram d in <KkDiagram>[
        randomDiagram(16, extra: 8, cyclic: true),
        randomDiagram(40, extra: 20),
        pipeline,
      ]) {
        double shape(double? aspect) {
          final KkDiagramPlacement p = KkForceLayout(aspect: aspect).place(d);
          expectNoOverlap(p);
          expectOnGrid(p);
          expectInside(p);
          return p.size.width / p.size.height;
        }

        // Wide panels get a wide network, tall panels a tall one.
        for (final double wide in <double>[1.5, 1.7, 2]) {
          expect(shape(wide), inInclusiveRange(wide * 0.8, wide * 1.25), reason: 'aspect $wide');
          expect(shape(1 / wide), inInclusiveRange(1 / wide / 1.25, 1 / wide / 0.8), reason: 'aspect ${1 / wide}');
        }
        // Asking for a square turns the network but never squeezes it.
        expect(shape(1), greaterThanOrEqualTo(0.99));
      }
    });

    test('a network that is longer than asked keeps its length, lying the way that was asked', () {
      final KkDiagram chain = KkDiagram.parse('A --- B --- C --- D --- E --- F --- G --- H');
      final Size wide = const KkForceLayout(aspect: 1.5).place(chain).size;
      final Size tall = const KkForceLayout(aspect: 0.75).place(chain).size;
      expect(wide.width, greaterThan(wide.height * 2.5));
      expect(tall.height, greaterThan(tall.width * 2.5));
      // The stretch stops at twice: two nodes do not fly apart to fill a banner.
      final KkDiagramPlacement pair = const KkForceLayout(aspect: 40).place(KkDiagram.parse('A --- B'));
      final double apart = (pair.nodes['A']!.anchor - pair.nodes['B']!.anchor).distance;
      expect(apart, lessThanOrEqualTo(2 * 96 + 8));
      expect((pair.nodes['A']!.anchor.dy - pair.nodes['B']!.anchor.dy).abs(), lessThanOrEqualTo(4));
    });

    test('without an aspect the network is left the way it settles', () {
      final KkDiagram d = randomDiagram(16, extra: 8, cyclic: true);
      expect(const KkForceLayout().aspect, isNull);
      expect(const KkForceLayout().place(d).nodes, isNot(const KkForceLayout(aspect: 1).place(d).nodes));
      // One node has no long side to turn.
      final KkDiagram one = KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('ONLY')]);
      expect(const KkForceLayout(aspect: 3).place(one), const KkForceLayout().place(one));
    });
  });

  test('layouts compare by their settings', () {
    final List<KkDiagramLayout Function()> same = <KkDiagramLayout Function()>[
      () => const KkLayeredLayout(direction: KkDiagramDirection.topToBottom, nodeGap: 20, layerGap: 40, sweeps: 4),
      () => const KkTreeLayout(direction: KkDiagramDirection.topToBottom, nodeGap: 20, layerGap: 40),
      () => const KkRadialLayout(root: 'A', ringGap: 80, nodeGap: 20, startAngle: 1),
      () => const KkForceLayout(seed: 3, iterations: 50, spacing: 80, nodeGap: 20, aspect: 1.5),
      () => const KkManualLayout(size: Size(200, 100), normalised: false),
    ];
    for (final KkDiagramLayout Function() make in same) {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    }
    final List<KkDiagramLayout> different = <KkDiagramLayout>[
      const KkLayeredLayout(),
      const KkLayeredLayout(direction: KkDiagramDirection.leftToRight),
      const KkLayeredLayout(nodeGap: 20),
      const KkLayeredLayout(layerGap: 40),
      const KkLayeredLayout(sweeps: 4),
      const KkTreeLayout(),
      const KkTreeLayout(direction: KkDiagramDirection.topToBottom),
      const KkTreeLayout(nodeGap: 20),
      const KkTreeLayout(layerGap: 40),
      const KkRadialLayout(),
      const KkRadialLayout(root: 'A'),
      const KkRadialLayout(ringGap: 80),
      const KkRadialLayout(nodeGap: 20),
      const KkRadialLayout(startAngle: 1),
      const KkForceLayout(),
      const KkForceLayout(seed: 3),
      const KkForceLayout(iterations: 50),
      const KkForceLayout(spacing: 80),
      const KkForceLayout(nodeGap: 20),
      const KkForceLayout(aspect: 1.5),
      const KkManualLayout(),
      const KkManualLayout(size: Size(200, 100)),
      const KkManualLayout(normalised: false),
    ];
    for (int i = 0; i < different.length; i++) {
      for (int j = 0; j < different.length; j++) {
        expect(different[i] == different[j], i == j, reason: '$i ${different[i]} / $j ${different[j]}');
      }
    }
    // The named constructors on the base class build the same things.
    expect(const KkDiagramLayout.layered(), const KkLayeredLayout());
    expect(const KkDiagramLayout.tree(), const KkTreeLayout());
    expect(const KkDiagramLayout.radial(), const KkRadialLayout());
    expect(const KkDiagramLayout.force(aspect: 1.5), const KkForceLayout(aspect: 1.5));
    expect(const KkDiagramLayout.manual(), const KkManualLayout());
    // Each layout names the router its wires look right with.
    expect(const KkLayeredLayout().defaultRouter, const KkEdgeRouter.orthogonal());
    expect(const KkTreeLayout().defaultRouter, const KkEdgeRouter.orthogonal());
    expect(const KkRadialLayout().defaultRouter, const KkEdgeRouter.octilinear());
    expect(const KkForceLayout().defaultRouter, const KkEdgeRouter.octilinear());
    expect(const KkManualLayout().defaultRouter, const KkEdgeRouter.octilinear());
  });

  test('routers compare by their settings', () {
    expect(const KkEdgeRouter.orthogonal(), const KkOrthogonalRouter());
    expect(const KkEdgeRouter.orthogonal(cut: 4), const KkOrthogonalRouter(cut: 4));
    expect(const KkEdgeRouter.orthogonal(cut: 4), isNot(const KkOrthogonalRouter()));
    expect(const KkEdgeRouter.orthogonal(cut: 4).hashCode, const KkOrthogonalRouter(cut: 4).hashCode);
    expect(const KkEdgeRouter.octilinear(), const KkOctilinearRouter());
    expect(const KkEdgeRouter.straight(), const KkStraightRouter());
    expect(const KkEdgeRouter.octilinear(), isNot(const KkEdgeRouter.straight()));
    expect(const KkEdgeRouter.octilinear(), isNot(const KkEdgeRouter.orthogonal()));
    expect(const KkEdgeRouter.octilinear().hashCode, const KkOctilinearRouter().hashCode);
    expect(const KkEdgeRouter.straight().hashCode, const KkStraightRouter().hashCode);
  });

  group('geometry', () {
    KkDiagramGeometry build(List<Offset> wire) => KkDiagramGeometry(
      diagram: KkDiagram.parse('A --- B\nC'),
      size: const Size(200, 100),
      nodes: const <String, KkNodePlacement>{
        'A': KkNodePlacement(
          shape: Rect.fromLTWH(0, 40, 24, 24),
          bounds: Rect.fromLTWH(0, 40, 24, 40),
          text: Rect.fromLTWH(0, 68, 24, 12),
        ),
        'B': KkNodePlacement(shape: Rect.fromLTWH(176, 40, 24, 24), bounds: Rect.fromLTWH(176, 40, 24, 24)),
        'C': KkNodePlacement(
          shape: Rect.fromLTWH(88, 16, 24, 24),
          bounds: Rect.fromLTWH(80, 16, 40, 44),
          text: Rect.fromLTWH(80, 46, 40, 12),
        ),
      },
      routes: <KkEdgeRoute>[KkEdgeRoute(wire)],
    );

    test('a text block with a wire under it is listed as covered', () {
      final KkDiagramGeometry level = build(const <Offset>[Offset(24, 52), Offset(176, 52)]);
      expect(level.coveredTexts, <String>{'C'});
      expect(level.wireCrosses(const Rect.fromLTWH(90, 50, 4, 4)), isTrue);
      expect(level.wireCrosses(const Rect.fromLTWH(90, 60, 4, 4)), isFalse);
      // A diagonal leg counts as much as a level one.
      expect(level.wireCrosses(const Rect.fromLTWH(0, 0, 4, 4)), isFalse);
      final KkDiagramGeometry slanted = build(const <Offset>[Offset(24, 52), Offset(60, 88), Offset(176, 88)]);
      expect(slanted.coveredTexts, isEmpty);
      expect(slanted.wireCrosses(const Rect.fromLTWH(40, 68, 4, 4)), isTrue);
      // Text is told apart from symbols: B has none and is never listed.
      final KkDiagramGeometry onB = build(const <Offset>[Offset(24, 52), Offset(188, 52)]);
      expect(onB.coveredTexts, <String>{'C'});
    });

    test('the node under a point', () {
      final KkDiagramGeometry g = build(const <Offset>[Offset(24, 52), Offset(176, 52)]);
      expect(g.nodeAt(const Offset(12, 52)), 'A');
      expect(g.nodeAt(const Offset(12, 74)), 'A');
      expect(g.nodeAt(const Offset(100, 50)), 'C');
      expect(g.nodeAt(const Offset(150, 52)), isNull);
    });

    test('value equality', () {
      expect(build(const <Offset>[Offset(24, 52), Offset(176, 52)]), build(const <Offset>[Offset(24, 52), Offset(176, 52)]));
      expect(
        build(const <Offset>[Offset(24, 52), Offset(176, 52)]),
        isNot(build(const <Offset>[Offset(24, 52), Offset(176, 56)])),
      );
    });

    test('the layouts of the house keep wires off the text of other nodes', () {
      for (final KkDiagramLayout layout in <KkDiagramLayout>[
        const KkLayeredLayout(),
        const KkLayeredLayout(direction: KkDiagramDirection.topToBottom),
        const KkTreeLayout(),
      ]) {
        final KkDiagram tree = KkDiagram.parse('''
flow LR
A[SEC-01|INTAKE] --> B[SEC-02|FILTER]
A --> C[SEC-03|PUMP]
B --> D[SEC-04|MIXER]
B --> E[SEC-05|DRAIN]
C --> F[SEC-06|OUTLET]
''');
        expect(layout.compute(tree).coveredTexts, isEmpty, reason: '$layout');
      }
    });
  });

  group('manual', () {
    test('fractions of the size, snapped to the grid', () {
      final KkDiagram d = KkDiagram(
        nodes: const <KkDiagramNode>[
          KkDiagramNode('A', position: Offset(0.5, 0.5)),
          KkDiagramNode('B', position: Offset(0.25, 0.26)),
        ],
      );
      final KkDiagramPlacement p = const KkManualLayout(size: Size(400, 200)).place(d);
      expect(p.nodes['A']!.anchor, const Offset(200, 100));
      expect(p.nodes['B']!.anchor, const Offset(100, 52));
      expect(p.size, const Size(400, 200));
    });

    test('pixels when not normalised', () {
      final KkDiagram d = KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('A', position: Offset(101, 59))]);
      final KkDiagramPlacement p = const KkManualLayout(size: Size(300, 200), normalised: false).place(d);
      expect(p.nodes['A']!.anchor, const Offset(100, 60));
    });

    test('nodes without a position line up under the rest, and nothing is cut off', () {
      final KkDiagram d = KkDiagram(
        nodes: const <KkDiagramNode>[
          KkDiagramNode('A', position: Offset(0, 0)),
          KkDiagramNode('B', position: Offset(1.2, 1.1)),
          KkDiagramNode('C'),
          KkDiagramNode('D'),
        ],
      );
      final KkDiagramPlacement p = const KkManualLayout(size: Size(200, 100)).place(d);
      expectInside(p);
      expect(p.nodes['C']!.bounds.top, greaterThan(p.nodes['B']!.anchor.dy));
      expect(p.nodes['D']!.bounds.left, greaterThan(p.nodes['C']!.bounds.right));
      expect(p.size.width, greaterThan(200));
    });
  });

  group('metrics', () {
    test('default symbol sizes and the size hook', () {
      const KkNodeMetrics m = KkNodeMetrics();
      expect(m.shapeSize(const KkDiagramNode('A', kind: KkNodeKind.hub)), const Size(32, 36));
      expect(m.shapeSize(const KkDiagramNode('A', size: Size(50, 60))), const Size(50, 60));
      final KkNodeMetrics hooked = KkNodeMetrics(sizeOf: (KkDiagramNode n) => n.id == 'BIG' ? const Size(64, 64) : null);
      expect(hooked.shapeSize(const KkDiagramNode('BIG')), const Size(64, 64));
      expect(hooked.shapeSize(const KkDiagramNode('A')), const Size(24, 24));
    });

    test('boxes land on the grid and hold the symbol and the text', () {
      const KkNodeMetrics m = KkNodeMetrics();
      for (final bool right in <bool>[false, true]) {
        final KkNodeBox box = m.measure(const KkDiagramNode('A', code: 'SEC-01', label: 'PUMP A', cjk: '冷却'), labelRight: right);
        expect(box.size.width % 4, 0);
        expect(box.size.height % 4, 0);
        final Rect all = Offset.zero & box.size;
        expect(all.contains(box.shape.topLeft) && box.shape.right <= all.right && box.shape.bottom <= all.bottom, isTrue);
        expect(box.text!.right <= all.right + 0.01 && box.text!.bottom <= all.bottom + 0.01, isTrue);
        expect(box.shape.overlaps(box.text!), isFalse);
      }
      expect(m.copyWith(showText: false).measure(const KkDiagramNode('A')).text, isNull);
    });

    test('the mono estimate is 0.6em a letter and one em a CJK glyph', () {
      expect(KkNodeMetrics.monoWidth('SEC-01', 10), closeTo(36, 0.001));
      expect(KkNodeMetrics.monoWidth('冷却', 10), closeTo(20, 0.001));
    });

    test('outlines pass through the middle of every side', () {
      const Rect r = Rect.fromLTWH(10, 20, 40, 24);
      for (final KkNodeKind kind in KkNodeKind.values) {
        for (final Offset port in <Offset>[r.centerLeft, r.centerRight, r.topCenter, r.bottomCenter]) {
          expect(kkDistanceToOutline(kind, r, port), lessThan(0.001), reason: '$kind $port');
        }
        expect(kkDistanceToOutline(kind, r, r.center), greaterThan(1));
        final Offset exit = kkOutlineExit(kind, r, r.center + const Offset(100, 37));
        expect(kkDistanceToOutline(kind, r, exit), lessThan(0.001), reason: '$kind exit');
      }
    });
  });
}
