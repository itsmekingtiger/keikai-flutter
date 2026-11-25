import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'router.dart';

/// A network layout: every node pushes the others away, every wire pulls its
/// two ends together, and the whole thing settles.
///
/// The start positions come from [seed] and the number of steps is fixed, so
/// the same diagram always settles the same way. After settling, nodes that
/// still touch are pushed apart and everything is snapped to the grid.
class KkForceLayout extends KkDiagramLayout {
  const KkForceLayout({
    this.seed = 1,
    this.iterations = 300,
    this.spacing = 96,
    this.nodeGap = 16,
    this.aspect,
  }) : assert(iterations >= 0),
       assert(spacing > 0),
       assert(nodeGap >= 0),
       assert(aspect == null || aspect > 0);

  /// Chooses the start positions. Change it to get another arrangement.
  final int seed;

  /// Number of settling steps.
  final int iterations;

  /// The length a wire wants to be.
  final double spacing;

  /// Least space between two nodes.
  final double nodeGap;

  /// The width : height the network aims for, or null to leave it the way it
  /// settles.
  ///
  /// With a value, the settled network is turned so that its long side lies
  /// along the width (1 and above) or along the height (below 1), and then
  /// stretched along that side, by no more than twice, towards the ratio. A
  /// network that is already longer than asked stays as long as it is.
  final double? aspect;

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

    // Start on a spiral, nudged by a seeded generator.
    // Park-Miller: small enough to stay exact on every platform.
    int state = seed.abs() % 2147483646 + 1;
    double next() {
      state = (state * 16807) % 2147483647;
      return state / 2147483647;
    }

    final List<double> x = List<double>.filled(n, 0);
    final List<double> y = List<double>.filled(n, 0);
    const double golden = 2.399963229728653;
    for (int i = 0; i < n; i++) {
      final double r = spacing * 0.6 * math.sqrt(i + 0.5);
      final double a = i * golden;
      x[i] = r * math.cos(a) + (next() - 0.5) * spacing * 0.1;
      y[i] = r * math.sin(a) + (next() - 0.5) * spacing * 0.1;
    }

    final Set<int> seenLinks = <int>{};
    final List<int> linkA = <int>[];
    final List<int> linkB = <int>[];
    for (final KkDiagramEdge e in diagram.edges) {
      final int a = diagram.indexOf(e.from);
      final int b = diagram.indexOf(e.to);
      if (a == b || a < 0 || b < 0) continue;
      final int key = math.min(a, b) * n + math.max(a, b);
      if (seenLinks.add(key)) {
        linkA.add(a);
        linkB.add(b);
      }
    }

    final double k = spacing;
    final List<double> dx = List<double>.filled(n, 0);
    final List<double> dy = List<double>.filled(n, 0);
    for (int step = 0; step < iterations; step++) {
      dx.fillRange(0, n, 0);
      dy.fillRange(0, n, 0);
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          double ex = x[i] - x[j];
          double ey = y[i] - y[j];
          double d2 = ex * ex + ey * ey;
          if (d2 < 0.01) {
            // Two nodes on one spot: split them along a fixed direction.
            ex = 0.1 * ((i + j).isEven ? 1 : -1);
            ey = 0.1;
            d2 = ex * ex + ey * ey;
          }
          final double f = k * k / d2;
          dx[i] += ex * f;
          dy[i] += ey * f;
          dx[j] -= ex * f;
          dy[j] -= ey * f;
        }
      }
      for (int l = 0; l < linkA.length; l++) {
        final int a = linkA[l];
        final int b = linkB[l];
        final double ex = x[a] - x[b];
        final double ey = y[a] - y[b];
        final double d = math.sqrt(ex * ex + ey * ey);
        final double f = d / k;
        dx[a] -= ex * f;
        dy[a] -= ey * f;
        dx[b] += ex * f;
        dy[b] += ey * f;
      }
      final double heat = k * 0.4 * (1 - step / iterations) + 0.5;
      for (int i = 0; i < n; i++) {
        // A weak pull to the middle keeps loose parts from drifting off.
        dx[i] -= x[i] * 0.08;
        dy[i] -= y[i] * 0.08;
        final double d = math.sqrt(dx[i] * dx[i] + dy[i] * dy[i]);
        if (d > 0) {
          final double move = math.min(d, heat);
          x[i] += dx[i] / d * move;
          y[i] += dy[i] / d * move;
        }
      }
    }

    // Boxes relative to their anchors.
    final List<Rect> rel = <Rect>[for (final KkNodeBox b in boxes) (Offset.zero - b.anchor) & b.size];
    final double gap = kkSnapUp(nodeGap);

    final double? aspect = this.aspect;
    if (aspect != null && n > 1) {
      // Turn the long side of the network to the side that was asked for.
      double mx = 0, my = 0;
      for (int i = 0; i < n; i++) {
        mx += x[i];
        my += y[i];
      }
      mx /= n;
      my /= n;
      double sxx = 0, syy = 0, sxy = 0;
      for (int i = 0; i < n; i++) {
        final double ex = x[i] - mx;
        final double ey = y[i] - my;
        sxx += ex * ex;
        syy += ey * ey;
        sxy += ex * ey;
      }
      final bool wide = aspect >= 1;
      final double major = (sxy.abs() < 1e-9 && (sxx - syy).abs() < 1e-9) ? 0 : 0.5 * math.atan2(2 * sxy, sxx - syy);
      final double turn = (wide ? 0 : math.pi / 2) - major;
      final double c = math.cos(turn);
      final double sn = math.sin(turn);
      for (int i = 0; i < n; i++) {
        final double ex = x[i] - mx;
        final double ey = y[i] - my;
        x[i] = ex * c - ey * sn;
        y[i] = ex * sn + ey * c;
      }

      // Then stretch along that side towards the ratio.
      double left = double.infinity, right = -double.infinity, top = double.infinity, bottom = -double.infinity;
      double minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
      for (int i = 0; i < n; i++) {
        left = math.min(left, x[i] + rel[i].left);
        right = math.max(right, x[i] + rel[i].right);
        top = math.min(top, y[i] + rel[i].top);
        bottom = math.max(bottom, y[i] + rel[i].bottom);
        minX = math.min(minX, x[i]);
        maxX = math.max(maxX, x[i]);
        minY = math.min(minY, y[i]);
        maxY = math.max(maxY, y[i]);
      }
      final double width = right - left;
      final double height = bottom - top;
      if (wide) {
        final double span = maxX - minX;
        if (span > 1) {
          final double f = ((aspect * height - (width - span)) / span).clamp(1.0, 2.0);
          for (int i = 0; i < n; i++) {
            x[i] *= f;
          }
        }
      } else {
        final double span = maxY - minY;
        if (span > 1) {
          final double f = ((width / aspect - (height - span)) / span).clamp(1.0, 2.0);
          for (int i = 0; i < n; i++) {
            y[i] *= f;
          }
        }
      }
    }

    bool separate({required bool onGrid}) {
      bool clean = true;
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final double ox =
              math.min(x[i] + rel[i].right, x[j] + rel[j].right) - math.max(x[i] + rel[i].left, x[j] + rel[j].left) + gap;
          final double oy =
              math.min(y[i] + rel[i].bottom, y[j] + rel[j].bottom) - math.max(y[i] + rel[i].top, y[j] + rel[j].top) + gap;
          if (ox <= 0.001 || oy <= 0.001) continue;
          clean = false;
          if (ox <= oy) {
            final double push = onGrid ? kkSnapUp(ox / 2) : ox / 2;
            final bool iLeft =
                x[i] + rel[i].center.dx < x[j] + rel[j].center.dx ||
                (x[i] + rel[i].center.dx == x[j] + rel[j].center.dx && i < j);
            x[i] += iLeft ? -push : push;
            x[j] += iLeft ? push : -push;
          } else {
            final double push = onGrid ? kkSnapUp(oy / 2) : oy / 2;
            final bool iTop =
                y[i] + rel[i].center.dy < y[j] + rel[j].center.dy ||
                (y[i] + rel[i].center.dy == y[j] + rel[j].center.dy && i < j);
            y[i] += iTop ? -push : push;
            y[j] += iTop ? push : -push;
          }
        }
      }
      return clean;
    }

    void settle({required bool onGrid}) {
      for (int round = 0; round < 40; round++) {
        for (int pass = 0; pass < 60; pass++) {
          if (separate(onGrid: onGrid)) return;
        }
        // Still tangled: give everything more room and try again.
        for (int i = 0; i < n; i++) {
          x[i] = onGrid ? kkSnap(x[i] * 1.25) : x[i] * 1.15;
          y[i] = onGrid ? kkSnap(y[i] * 1.25) : y[i] * 1.15;
        }
      }
    }

    settle(onGrid: false);
    for (int i = 0; i < n; i++) {
      x[i] = kkSnap(x[i]);
      y[i] = kkSnap(y[i]);
    }
    settle(onGrid: true);

    return KkDiagramPlacement.normalised(<String, KkNodePlacement>{
      for (int i = 0; i < n; i++) diagram.nodes[i].id: KkNodePlacement.at(boxes[i], Offset(x[i], y[i])),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is KkForceLayout &&
      other.seed == seed &&
      other.iterations == iterations &&
      other.spacing == spacing &&
      other.nodeGap == nodeGap &&
      other.aspect == aspect;

  @override
  int get hashCode => Object.hash(KkForceLayout, seed, iterations, spacing, nodeGap, aspect);
}
