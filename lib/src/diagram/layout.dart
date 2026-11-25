import 'dart:math' as math;
import 'dart:ui';

import 'force_layout.dart';
import 'geometry.dart';
import 'layered_layout.dart';
import 'manual_layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'radial_layout.dart';
import 'router.dart';
import 'tree_layout.dart';

/// Decides where the nodes of a diagram go.
///
/// A layout is a pure function: the same diagram and metrics always give the
/// same placement, and every position lands on the 4px grid.
///
/// * [KkDiagramLayout.layered]: flow charts. Nodes in ranks along the flow,
///   wires kept short and straight, crossings reduced.
/// * [KkDiagramLayout.tree]: hierarchies. Leaves in order, parents centred.
/// * [KkDiagramLayout.radial]: a root in the middle, rings around it.
/// * [KkDiagramLayout.force]: networks with no natural order.
/// * [KkDiagramLayout.manual]: positions you supply on the nodes.
abstract class KkDiagramLayout {
  const KkDiagramLayout();

  const factory KkDiagramLayout.layered({
    KkDiagramDirection? direction,
    double nodeGap,
    double layerGap,
    int sweeps,
  }) = KkLayeredLayout;

  const factory KkDiagramLayout.tree({KkDiagramDirection? direction, double nodeGap, double layerGap}) = KkTreeLayout;

  const factory KkDiagramLayout.radial({String? root, double ringGap, double nodeGap, double startAngle}) =
      KkRadialLayout;

  const factory KkDiagramLayout.force({int seed, int iterations, double spacing, double nodeGap, double? aspect}) =
      KkForceLayout;

  const factory KkDiagramLayout.manual({Size size, bool normalised}) = KkManualLayout;

  /// The router wires are drawn with unless the view is given another.
  KkEdgeRouter get defaultRouter;

  /// Places the nodes of [diagram], measured with [metrics].
  KkDiagramPlacement place(KkDiagram diagram, {KkNodeMetrics metrics = const KkNodeMetrics()});

  /// Places [diagram] and routes its wires.
  KkDiagramGeometry compute(
    KkDiagram diagram, {
    KkNodeMetrics metrics = const KkNodeMetrics(),
    KkEdgeRouter? router,
  }) {
    final KkDiagramPlacement placement = place(diagram, metrics: metrics);
    List<KkEdgeRoute> routes = (router ?? defaultRouter).routeAll(diagram, placement);
    Map<String, KkNodePlacement> nodes = placement.nodes;

    // Wires may leave the box the nodes fill (loops, detours): grow to fit.
    double left = 0, top = 0, right = placement.size.width, bottom = placement.size.height;
    for (final KkEdgeRoute route in routes) {
      for (final Offset p in route.points) {
        left = math.min(left, p.dx - 4);
        top = math.min(top, p.dy - 4);
        right = math.max(right, p.dx + 4);
        bottom = math.max(bottom, p.dy + 4);
      }
    }
    if (left < 0 || top < 0) {
      final Offset by = Offset(
        left < 0 ? (-left / kkDiagramGrid).ceilToDouble() * kkDiagramGrid : 0,
        top < 0 ? (-top / kkDiagramGrid).ceilToDouble() * kkDiagramGrid : 0,
      );
      nodes = <String, KkNodePlacement>{
        for (final MapEntry<String, KkNodePlacement> e in nodes.entries) e.key: e.value.shift(by),
      };
      routes = <KkEdgeRoute>[
        for (final KkEdgeRoute r in routes) KkEdgeRoute(<Offset>[for (final Offset p in r.points) p + by]),
      ];
      right += by.dx;
      bottom += by.dy;
    }
    return KkDiagramGeometry(
      diagram: diagram,
      size: Size(kkSnapUp(right), kkSnapUp(bottom)),
      nodes: nodes,
      routes: routes,
      direction: placement.direction,
    );
  }
}

/// Whether text goes to the right of the symbols for [metrics] in a layout
/// that flows along [direction] (null for a free layout).
bool kkLabelRight(KkNodeMetrics metrics, KkDiagramDirection? direction) => switch (metrics.labelSide) {
  KkLabelSide.right => true,
  KkLabelSide.below => false,
  KkLabelSide.auto => direction == KkDiagramDirection.topToBottom,
};
