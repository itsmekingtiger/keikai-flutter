import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'router.dart';

/// Puts every node where its `position` says.
///
/// With [normalised] (the default) a position is a fraction of [size]:
/// `Offset(0.5, 0.5)` is the middle. Otherwise it is in pixels. Positions are
/// snapped to the grid. Nodes without a position are lined up under the rest.
class KkManualLayout extends KkDiagramLayout {
  const KkManualLayout({this.size = const Size(480, 320), this.normalised = true});

  /// The area the positions refer to, and the least size of the result.
  final Size size;

  /// Whether node positions are fractions of [size] rather than pixels.
  final bool normalised;

  @override
  KkEdgeRouter get defaultRouter => const KkEdgeRouter.octilinear();

  @override
  KkDiagramPlacement place(KkDiagram diagram, {KkNodeMetrics metrics = const KkNodeMetrics()}) {
    final int n = diagram.nodes.length;
    if (n == 0) return KkDiagramPlacement(size: size, nodes: const <String, KkNodePlacement>{});
    final bool labelRight = kkLabelRight(metrics, null);
    final Map<String, KkNodePlacement> nodes = <String, KkNodePlacement>{};
    final List<int> loose = <int>[];
    double bottom = size.height;
    for (int i = 0; i < n; i++) {
      final KkDiagramNode node = diagram.nodes[i];
      final Offset? p = node.position;
      if (p == null) {
        loose.add(i);
        continue;
      }
      final Offset anchor = normalised
          ? Offset(kkSnap(p.dx * size.width), kkSnap(p.dy * size.height))
          : Offset(kkSnap(p.dx), kkSnap(p.dy));
      final KkNodePlacement placed = KkNodePlacement.at(metrics.measure(node, labelRight: labelRight), anchor);
      nodes[node.id] = placed;
      bottom = math.max(bottom, placed.bounds.bottom);
    }
    // Nodes nobody placed: a row under everything else.
    double cursor = 16;
    final double row = kkSnapUp(bottom + 24);
    for (final int i in loose) {
      final KkDiagramNode node = diagram.nodes[i];
      final KkNodeBox box = metrics.measure(node, labelRight: labelRight);
      nodes[node.id] = KkNodePlacement.at(box, Offset(kkSnapUp(cursor + box.anchor.dx), kkSnapUp(row + box.anchor.dy)));
      cursor += box.size.width + 16;
    }
    double left = 0, top = 0, right = size.width, low = size.height;
    for (final KkNodePlacement p in nodes.values) {
      left = math.min(left, p.bounds.left);
      top = math.min(top, p.bounds.top);
      right = math.max(right, p.bounds.right);
      low = math.max(low, p.bounds.bottom);
    }
    final Offset by = Offset(left < 0 ? kkSnapUp(-left) : 0, top < 0 ? kkSnapUp(-top) : 0);
    return KkDiagramPlacement(
      size: Size(kkSnapUp(right + by.dx), kkSnapUp(low + by.dy)),
      nodes: by == Offset.zero
          ? nodes
          : <String, KkNodePlacement>{
              for (final MapEntry<String, KkNodePlacement> e in nodes.entries) e.key: e.value.shift(by),
            },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KkManualLayout && other.size == size && other.normalised == normalised;

  @override
  int get hashCode => Object.hash(KkManualLayout, size, normalised);
}
