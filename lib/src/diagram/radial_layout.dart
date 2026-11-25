import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'router.dart';
import 'tree_layout.dart';

/// A root in the middle with everything joined to it on rings around: one
/// ring per step away from the root.
///
/// Each node owns a wedge as wide as the number of leaves beneath it, and a
/// ring is pushed out until its nodes have room, so nothing overlaps. Parts
/// of the diagram that are not joined to the root get their own map, placed
/// beside the first.
class KkRadialLayout extends KkDiagramLayout {
  const KkRadialLayout({this.root, this.ringGap = 64, this.nodeGap = 16, this.startAngle = -math.pi / 2})
    : assert(ringGap >= 0),
      assert(nodeGap >= 0);

  /// Id of the node in the middle. Defaults to the first node nothing points
  /// at.
  final String? root;

  /// Least distance between two rings.
  final double ringGap;

  /// Least space between two nodes.
  final double nodeGap;

  /// Where the first wedge starts, in radians. The default is straight up.
  final double startAngle;

  @override
  KkEdgeRouter get defaultRouter => const KkEdgeRouter.octilinear();

  @override
  KkDiagramPlacement place(KkDiagram diagram, {KkNodeMetrics metrics = const KkNodeMetrics()}) {
    final int n = diagram.nodes.length;
    if (n == 0) return KkDiagramPlacement.empty;
    final bool labelRight = kkLabelRight(metrics, null);
    final List<KkNodeBox> boxes = <KkNodeBox>[
      for (final KkDiagramNode node in diagram.nodes) metrics.measure(node, labelRight: labelRight),
    ];
    // The circle around the anchor that holds the whole box.
    final List<double> reach = <double>[
      for (final KkNodeBox b in boxes)
        <Offset>[
          Offset.zero,
          Offset(b.size.width, 0),
          Offset(0, b.size.height),
          Offset(b.size.width, b.size.height),
        ].map((Offset c) => (c - b.anchor).distance).reduce(math.max),
    ];
    final KkDiagramForest forest = KkDiagramForest.of(diagram, undirected: true, breadthFirst: true, root: root);
    final double gap = nodeGap + 6;

    final Map<String, KkNodePlacement> nodes = <String, KkNodePlacement>{};
    double cursor = 0;
    for (final int top in forest.roots) {
      // The members of this map, outermost last.
      final List<int> members = <int>[top];
      for (int head = 0; head < members.length; head++) {
        members.addAll(forest.children[members[head]]);
      }
      final List<int> leaves = List<int>.filled(n, 0);
      for (int i = members.length - 1; i >= 0; i--) {
        final int m = members[i];
        int sum = 0;
        for (final int c in forest.children[m]) {
          sum += leaves[c];
        }
        leaves[m] = math.max(1, sum);
      }
      final List<double> from = List<double>.filled(n, 0);
      final List<double> sweep = List<double>.filled(n, 0);
      from[top] = startAngle;
      sweep[top] = 2 * math.pi;
      int rings = 0;
      for (final int m in members) {
        rings = math.max(rings, forest.depth[m] + 1);
        double at = from[m];
        for (final int c in forest.children[m]) {
          from[c] = at;
          sweep[c] = sweep[m] * leaves[c] / leaves[m];
          at += sweep[c];
        }
      }
      // Ring radii: far enough from the ring inside, and wide enough for
      // every node's wedge.
      final List<double> widest = List<double>.filled(rings, 0);
      for (final int m in members) {
        widest[forest.depth[m]] = math.max(widest[forest.depth[m]], reach[m]);
      }
      final List<double> radius = List<double>.filled(rings, 0);
      for (int d = 1; d < rings; d++) {
        double r = radius[d - 1] + math.max(ringGap, widest[d - 1] + widest[d] + gap);
        for (final int m in members) {
          if (forest.depth[m] != d) continue;
          final double half = math.min(sweep[m], math.pi) / 2;
          r = math.max(r, (2 * reach[m] + gap) / (2 * math.sin(half)));
        }
        radius[d] = kkSnapUp(r);
      }
      final Map<int, Offset> anchors = <int, Offset>{};
      double left = double.infinity, top0 = double.infinity, right = -double.infinity;
      for (final int m in members) {
        final double angle = from[m] + sweep[m] / 2;
        final double r = radius[forest.depth[m]];
        final Offset anchor = m == top
            ? Offset.zero
            : Offset(kkSnap(r * math.cos(angle)), kkSnap(r * math.sin(angle)));
        anchors[m] = anchor;
        final Rect bounds = (anchor - boxes[m].anchor) & boxes[m].size;
        left = math.min(left, bounds.left);
        top0 = math.min(top0, bounds.top);
        right = math.max(right, bounds.right);
      }
      final Offset by = Offset(kkSnapUp(cursor - left), kkSnapUp(-top0));
      for (final int m in members) {
        nodes[diagram.nodes[m].id] = KkNodePlacement.at(boxes[m], anchors[m]! + by);
      }
      cursor += kkSnapUp(right - left) + kkSnapUp(nodeGap * 2);
    }
    return KkDiagramPlacement.normalised(nodes);
  }

  @override
  bool operator ==(Object other) =>
      other is KkRadialLayout &&
      other.root == root &&
      other.ringGap == ringGap &&
      other.nodeGap == nodeGap &&
      other.startAngle == startAngle;

  @override
  int get hashCode => Object.hash(KkRadialLayout, root, ringGap, nodeGap, startAngle);
}
