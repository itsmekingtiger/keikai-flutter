import 'dart:math' as math;
import 'dart:ui';

import '../foundation/level.dart';
import 'geometry.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'router.dart';

/// The flow-chart layout (after Sugiyama): nodes are ranked along the flow,
/// ordered inside each rank to reduce crossings, and positioned so wires run
/// short and long wires run straight.
///
/// Wires that close a cycle are laid out backwards and drawn turned round.
/// Wires that skip ranks are given a lane in every rank they pass, and wires
/// that change lane between two ranks each get their own track.
class KkLayeredLayout extends KkDiagramLayout {
  const KkLayeredLayout({this.direction, this.nodeGap = 24, this.layerGap = 48, this.sweeps = 24})
    : assert(nodeGap >= 0),
      assert(layerGap >= 0),
      assert(sweeps >= 0);

  /// The flow axis. Defaults to the diagram's own direction.
  final KkDiagramDirection? direction;

  /// Space between neighbours in a rank.
  final double nodeGap;

  /// Least space between two ranks. A gap with many wires changing lane is
  /// made wider.
  final double layerGap;

  /// How many ordering sweeps to run at most.
  final int sweeps;

  @override
  KkEdgeRouter get defaultRouter => const KkEdgeRouter.orthogonal();

  @override
  KkDiagramPlacement place(KkDiagram diagram, {KkNodeMetrics metrics = const KkNodeMetrics()}) {
    final KkDiagramDirection dir = direction ?? diagram.direction;
    if (diagram.isEmpty) {
      return KkDiagramPlacement(size: Size.zero, nodes: const <String, KkNodePlacement>{}, direction: dir);
    }
    return _Layered(diagram, metrics, dir, nodeGap, layerGap, sweeps).run();
  }

  @override
  bool operator ==(Object other) =>
      other is KkLayeredLayout &&
      other.direction == direction &&
      other.nodeGap == nodeGap &&
      other.layerGap == layerGap &&
      other.sweeps == sweeps;

  @override
  int get hashCode => Object.hash(KkLayeredLayout, direction, nodeGap, layerGap, sweeps);
}

/// A vertex of the ranked graph: a real node, or a lane point of a long wire.
class _V {
  _V(this.real, this.edge, this.layer);

  /// Index into the diagram's nodes, or -1 for a lane point.
  final int real;

  /// Index into the acyclic wire list for a lane point, else -1.
  final int edge;
  int layer;
  int order = 0;

  /// Cross-axis coordinate of the anchor.
  double pos = 0;
  double before = 0;
  double after = 0;
  double mainBefore = 0;
  double mainAfter = 0;
  final List<int> up = <int>[];
  final List<int> down = <int>[];

  /// How much each wire in [up] and [down] matters: live wires pull harder
  /// and are kept straight first.
  final List<double> upGain = <double>[];
  final List<double> downGain = <double>[];

  bool get dummy => real < 0;
}

/// A wire after cycle breaking: it always runs from a lower to a higher rank.
class _Wire {
  _Wire(this.a, this.b, this.index, this.reversed);

  final int a;
  final int b;

  /// Index into the diagram's edges.
  final int index;
  final bool reversed;

  /// The vertices of the wire in rank order, ends included.
  final List<int> chain = <int>[];
}

class _Layered {
  _Layered(this.diagram, this.metrics, this.dir, this.nodeGap, this.layerGap, this.sweeps);

  final KkDiagram diagram;
  final KkNodeMetrics metrics;
  final KkDiagramDirection dir;
  final double nodeGap;
  final double layerGap;
  final int sweeps;

  final List<_V> v = <_V>[];
  final List<_Wire> wires = <_Wire>[];
  List<List<int>> layers = <List<int>>[];

  bool get horizontal => dir == KkDiagramDirection.leftToRight;

  KkDiagramPlacement run() {
    final int n = diagram.nodes.length;
    final bool labelRight = kkLabelRight(metrics, dir);
    final List<KkNodeBox> boxes = <KkNodeBox>[
      for (final KkDiagramNode node in diagram.nodes) metrics.measure(node, labelRight: labelRight),
    ];

    _breakCycles(n);
    final List<int> rank = _rank(n);
    _buildVertices(n, rank, boxes);
    _order();
    _coordinates();
    final List<double> centre = _mainAxis();
    final Map<int, List<double>> jogs = _tracks(centre);

    Offset pt(double main, double cross) => horizontal ? Offset(main, cross) : Offset(cross, main);

    final Map<String, KkNodePlacement> nodes = <String, KkNodePlacement>{};
    for (int i = 0; i < n; i++) {
      nodes[diagram.nodes[i].id] = KkNodePlacement.at(boxes[i], pt(centre[v[i].layer], v[i].pos));
    }
    final Map<int, KkEdgeHint> hints = <int, KkEdgeHint>{};
    for (int w = 0; w < wires.length; w++) {
      final _Wire wire = wires[w];
      hints[wire.index] = KkEdgeHint(
        waypoints: <Offset>[
          for (int i = 1; i < wire.chain.length - 1; i++) pt(centre[v[wire.chain[i]].layer], v[wire.chain[i]].pos),
        ],
        jogs: jogs[w] ?? const <double>[],
        reversed: wire.reversed,
        maxCut: _cutRoom[w] ?? double.infinity,
      );
    }
    return KkDiagramPlacement.normalised(nodes, hints: hints, direction: dir);
  }

  // ── 1. cycles ───────────────────────────────────────────────────────────

  void _breakCycles(int n) {
    final List<(int, int, int)> raw = <(int, int, int)>[];
    for (int i = 0; i < diagram.edges.length; i++) {
      final int a = diagram.indexOf(diagram.edges[i].from);
      final int b = diagram.indexOf(diagram.edges[i].to);
      if (a != b && a >= 0 && b >= 0) raw.add((a, b, i));
    }
    final List<List<int>> out = List<List<int>>.generate(n, (_) => <int>[]);
    for (int k = 0; k < raw.length; k++) {
      out[raw[k].$1].add(k);
    }
    final List<int> state = List<int>.filled(n, 0);
    final List<bool> reversed = List<bool>.filled(raw.length, false);
    final List<int> stackNode = <int>[];
    final List<int> stackNext = <int>[];
    for (int s = 0; s < n; s++) {
      if (state[s] != 0) continue;
      state[s] = 1;
      stackNode.add(s);
      stackNext.add(0);
      while (stackNode.isNotEmpty) {
        final int node = stackNode.last;
        final int next = stackNext.last;
        if (next < out[node].length) {
          stackNext[stackNext.length - 1] = next + 1;
          final int k = out[node][next];
          final int to = raw[k].$2;
          if (state[to] == 1) {
            reversed[k] = true;
          } else if (state[to] == 0) {
            state[to] = 1;
            stackNode.add(to);
            stackNext.add(0);
          }
        } else {
          state[node] = 2;
          stackNode.removeLast();
          stackNext.removeLast();
        }
      }
    }
    for (int k = 0; k < raw.length; k++) {
      final (int a, int b, int index) = raw[k];
      wires.add(reversed[k] ? _Wire(b, a, index, true) : _Wire(a, b, index, false));
    }
  }

  // ── 2. ranks ────────────────────────────────────────────────────────────

  List<int> _rank(int n) {
    final List<int> rank = List<int>.filled(n, 0);
    final List<int> indegree = List<int>.filled(n, 0);
    final List<List<int>> out = List<List<int>>.generate(n, (_) => <int>[]);
    for (final _Wire w in wires) {
      indegree[w.b]++;
      out[w.a].add(w.b);
    }
    final List<int> queue = <int>[
      for (int i = 0; i < n; i++)
        if (indegree[i] == 0) i,
    ];
    final List<int> left = List<int>.of(indegree);
    for (int head = 0; head < queue.length; head++) {
      final int a = queue[head];
      for (final int b in out[a]) {
        if (rank[b] < rank[a] + 1) rank[b] = rank[a] + 1;
        if (--left[b] == 0) queue.add(b);
      }
    }
    // A source sits right before its nearest target instead of at rank 0.
    for (int i = 0; i < n; i++) {
      if (indegree[i] == 0 && out[i].isNotEmpty) {
        int nearest = rank[out[i].first];
        for (final int b in out[i]) {
          nearest = math.min(nearest, rank[b]);
        }
        rank[i] = nearest - 1;
      }
    }
    return rank;
  }

  // ── 3. lanes ────────────────────────────────────────────────────────────

  void _buildVertices(int n, List<int> rank, List<KkNodeBox> boxes) {
    for (int i = 0; i < n; i++) {
      final KkNodeBox box = boxes[i];
      final _V vertex = _V(i, -1, rank[i]);
      if (horizontal) {
        vertex
          ..before = box.anchor.dy
          ..after = box.size.height - box.anchor.dy
          ..mainBefore = box.anchor.dx
          ..mainAfter = box.size.width - box.anchor.dx;
      } else {
        vertex
          ..before = box.anchor.dx
          ..after = box.size.width - box.anchor.dx
          ..mainBefore = box.anchor.dy
          ..mainAfter = box.size.height - box.anchor.dy;
      }
      v.add(vertex);
    }
    for (int w = 0; w < wires.length; w++) {
      final _Wire wire = wires[w];
      final KkDiagramEdge edge = diagram.edges[wire.index];
      final double gain = (edge.active || edge.flow != KkEdgeFlow.none)
          ? 3
          : (edge.level == KkLevel.offline ? 0.5 : 1);
      int prev = wire.a;
      wire.chain.add(prev);
      for (int l = rank[wire.a] + 1; l < rank[wire.b]; l++) {
        final _V lane = _V(-1, w, l)
          ..before = 4
          ..after = 4;
        v.add(lane);
        final int id = v.length - 1;
        v[prev].down.add(id);
        v[prev].downGain.add(gain);
        lane.up.add(prev);
        lane.upGain.add(gain);
        wire.chain.add(id);
        prev = id;
      }
      v[prev].down.add(wire.b);
      v[prev].downGain.add(gain);
      v[wire.b].up.add(prev);
      v[wire.b].upGain.add(gain);
      wire.chain.add(wire.b);
    }
    int count = 0;
    for (final _V vertex in v) {
      count = math.max(count, vertex.layer + 1);
    }
    layers = List<List<int>>.generate(count, (_) => <int>[]);

    // First order: depth first from the sources, so connected runs stay
    // together.
    final List<bool> seen = List<bool>.filled(v.length, false);
    void visit(int start) {
      final List<int> stack = <int>[start];
      while (stack.isNotEmpty) {
        final int id = stack.removeLast();
        if (seen[id]) continue;
        seen[id] = true;
        layers[v[id].layer].add(id);
        for (int i = v[id].down.length - 1; i >= 0; i--) {
          if (!seen[v[id].down[i]]) stack.add(v[id].down[i]);
        }
      }
    }

    for (int i = 0; i < n; i++) {
      if (v[i].up.isEmpty) visit(i);
    }
    for (int i = 0; i < v.length; i++) {
      if (!seen[i]) visit(i);
    }
    _reindex();
  }

  void _reindex() {
    for (final List<int> layer in layers) {
      for (int i = 0; i < layer.length; i++) {
        v[layer[i]].order = i;
      }
    }
  }

  // ── 4. order ────────────────────────────────────────────────────────────

  int _crossings() {
    int total = 0;
    for (int l = 0; l + 1 < layers.length; l++) {
      final List<int> upper = layers[l];
      final int width = layers[l + 1].length;
      if (width < 2) continue;
      // Wires in order of their upper end, then count inversions below.
      final List<int> lower = <int>[];
      for (final int id in upper) {
        final List<int> ends = <int>[for (final int d in v[id].down) v[d].order]..sort();
        lower.addAll(ends);
      }
      final List<int> tree = List<int>.filled(width + 1, 0);
      int seen = 0;
      for (final int o in lower) {
        // Count earlier wires that end strictly after this one.
        int notAfter = 0;
        for (int i = o + 1; i > 0; i -= i & -i) {
          notAfter += tree[i];
        }
        total += seen - notAfter;
        for (int i = o + 1; i <= width; i += i & -i) {
          tree[i]++;
        }
        seen++;
      }
    }
    return total;
  }

  void _sweep(bool down) {
    final Iterable<int> range = down
        ? Iterable<int>.generate(layers.length - 1, (int i) => i + 1)
        : Iterable<int>.generate(layers.length - 1, (int i) => layers.length - 2 - i);
    for (final int l in range) {
      final List<int> layer = layers[l];
      final List<int?> next = List<int?>.filled(layer.length, null);
      final List<(double, int, int)> movable = <(double, int, int)>[];
      for (int i = 0; i < layer.length; i++) {
        final _V vertex = v[layer[i]];
        final List<int> near = down ? vertex.up : vertex.down;
        if (near.isEmpty) {
          next[i] = layer[i];
        } else {
          double sum = 0;
          for (final int id in near) {
            sum += v[id].order;
          }
          movable.add((sum / near.length, i, layer[i]));
        }
      }
      movable.sort(((double, int, int) a, (double, int, int) b) {
        final int c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
      int m = 0;
      for (int i = 0; i < next.length; i++) {
        next[i] ??= movable[m++].$3;
      }
      for (int i = 0; i < layer.length; i++) {
        layer[i] = next[i]!;
        v[layer[i]].order = i;
      }
    }
  }

  int _pairCrossings(_V left, _V right) {
    int count = 0;
    for (final int p in left.up) {
      for (final int q in right.up) {
        if (v[p].order > v[q].order) count++;
      }
    }
    for (final int p in left.down) {
      for (final int q in right.down) {
        if (v[p].order > v[q].order) count++;
      }
    }
    return count;
  }

  void _order() {
    List<List<int>> best = <List<int>>[for (final List<int> l in layers) List<int>.of(l)];
    int bestCount = _crossings();
    for (int i = 0; i < sweeps && bestCount > 0; i++) {
      _sweep(i.isEven);
      final int count = _crossings();
      if (count < bestCount) {
        bestCount = count;
        best = <List<int>>[for (final List<int> l in layers) List<int>.of(l)];
      }
    }
    layers = best;
    _reindex();
    // Swap neighbours while that removes crossings.
    for (int pass = 0; pass < 8 && bestCount > 0; pass++) {
      bool improved = false;
      for (final List<int> layer in layers) {
        for (int i = 0; i + 1 < layer.length; i++) {
          final int ia = layer[i];
          final int ib = layer[i + 1];
          final _V a = v[ia];
          final _V b = v[ib];
          if (_pairCrossings(b, a) < _pairCrossings(a, b)) {
            layer[i] = ib;
            layer[i + 1] = ia;
            a.order = i + 1;
            b.order = i;
            improved = true;
          }
        }
      }
      if (!improved) break;
    }
    _reindex();
  }

  // ── 5. cross-axis coordinates ───────────────────────────────────────────

  double _separation(_V a, _V b) {
    final double gap = a.dummy && b.dummy ? 0 : (a.dummy || b.dummy ? nodeGap / 2 : nodeGap);
    return kkSnapUp(a.after + gap + b.before);
  }

  static double _weight(_V a, _V b) => a.dummy && b.dummy ? 8 : (a.dummy || b.dummy ? 2 : 1);

  /// Moves the vertices of [layer] as close to [wanted] as their order and
  /// separations allow (weighted least squares by pooling neighbours).
  void _solve(List<int> layer, List<double> wanted, List<double> weight) {
    final int k = layer.length;
    final List<double> offset = List<double>.filled(k, 0);
    for (int i = 1; i < k; i++) {
      offset[i] = offset[i - 1] + _separation(v[layer[i - 1]], v[layer[i]]);
    }
    // Blocks of (weight, weighted sum, count); each block shares one value.
    final List<double> bw = <double>[];
    final List<double> bs = <double>[];
    final List<int> bn = <int>[];
    for (int i = 0; i < k; i++) {
      bw.add(weight[i]);
      bs.add(weight[i] * (wanted[i] - offset[i]));
      bn.add(1);
      while (bw.length > 1 && bs[bs.length - 2] / bw[bw.length - 2] > bs.last / bw.last) {
        final double w = bw.removeLast();
        final double s = bs.removeLast();
        final int c = bn.removeLast();
        bw[bw.length - 1] += w;
        bs[bs.length - 1] += s;
        bn[bn.length - 1] += c;
      }
    }
    int i = 0;
    for (int b = 0; b < bw.length; b++) {
      final double value = bs[b] / bw[b];
      for (int c = 0; c < bn[b]; c++, i++) {
        v[layer[i]].pos = value + offset[i];
      }
    }
  }

  void _pull(int l, {required bool up, required bool down}) {
    final List<int> layer = layers[l];
    final List<double> wanted = List<double>.filled(layer.length, 0);
    final List<double> weight = List<double>.filled(layer.length, 0);
    for (int i = 0; i < layer.length; i++) {
      final _V vertex = v[layer[i]];
      double sum = 0;
      double total = 0;
      if (up) {
        for (int k = 0; k < vertex.up.length; k++) {
          final int id = vertex.up[k];
          final double w = _weight(vertex, v[id]) * vertex.upGain[k];
          sum += w * v[id].pos;
          total += w;
        }
      }
      if (down) {
        for (int k = 0; k < vertex.down.length; k++) {
          final int id = vertex.down[k];
          final double w = _weight(vertex, v[id]) * vertex.downGain[k];
          sum += w * v[id].pos;
          total += w;
        }
      }
      if (total == 0) {
        wanted[i] = vertex.pos;
        weight[i] = 0.05;
      } else {
        wanted[i] = sum / total;
        weight[i] = total;
      }
    }
    _solve(layer, wanted, weight);
  }

  void _coordinates() {
    for (final List<int> layer in layers) {
      double at = 0;
      for (int i = 0; i < layer.length; i++) {
        if (i > 0) at += _separation(v[layer[i - 1]], v[layer[i]]);
        v[layer[i]].pos = at;
      }
    }
    final int count = layers.length;
    for (int round = 0; round < 8; round++) {
      for (int l = 1; l < count; l++) {
        _pull(l, up: true, down: false);
      }
      for (int l = count - 2; l >= 0; l--) {
        _pull(l, up: false, down: true);
      }
    }
    for (int round = 0; round < 4; round++) {
      for (int l = 0; l < count; l++) {
        _pull(l, up: true, down: true);
      }
      for (int l = count - 1; l >= 0; l--) {
        _pull(l, up: true, down: true);
      }
    }
    if (!_placeBlocks(_align())) {
      _straighten();
      _snap();
    }
  }

  /// Chains vertices of neighbouring ranks that should share one coordinate:
  /// every vertex is tied to a median neighbour in the rank before, as long as
  /// the ties between two ranks never cross. Lane points of long wires are
  /// tied first, so a wire that skips ranks runs straight.
  ///
  /// Returns the block of every vertex.
  List<int> _align() {
    final int n = v.length;
    final List<int> up = List<int>.filled(n, -1);
    final List<int> down = List<int>.filled(n, -1);
    for (int l = 1; l < layers.length; l++) {
      final List<int> layer = layers[l];
      // For each position in this rank, the order of the vertex it is tied
      // to in the rank before (or -1).
      final List<int> tied = List<int>.filled(layer.length, -1);
      int last = -1;
      for (int i = 0; i < layer.length; i++) {
        final _V vertex = v[layer[i]];
        if (!vertex.dummy) continue;
        for (final int u in vertex.up) {
          if (v[u].dummy && down[u] < 0 && v[u].order > last) {
            tied[i] = v[u].order;
            up[layer[i]] = u;
            down[u] = layer[i];
            last = v[u].order;
            break;
          }
        }
      }
      // The rest, vertices with a live wire first so the live line is the
      // one that stays straight.
      double liveliest(int id) {
        double g = 0;
        for (final double gain in v[id].upGain) {
          g = math.max(g, gain);
        }
        return g;
      }

      final List<int> turn = List<int>.generate(layer.length, (int i) => i)
        ..sort((int a, int b) {
          final int c = liveliest(layer[b]).compareTo(liveliest(layer[a]));
          return c != 0 ? c : a.compareTo(b);
        });
      for (final int i in turn) {
        final int id = layer[i];
        final _V vertex = v[id];
        if (up[id] >= 0 || vertex.up.isEmpty) continue;
        int lo = -1;
        int hi = 1 << 30;
        for (int j = i - 1; j >= 0; j--) {
          if (tied[j] >= 0) {
            lo = tied[j];
            break;
          }
        }
        for (int j = i + 1; j < layer.length; j++) {
          if (tied[j] >= 0) {
            hi = tied[j];
            break;
          }
        }
        // Candidates: the liveliest wire first, then the median neighbours,
        // the nearer one first.
        final List<int> ups = List<int>.of(vertex.up)..sort((int a, int b) => v[a].order.compareTo(v[b].order));
        final int m0 = (ups.length - 1) ~/ 2;
        final int m1 = ups.length ~/ 2;
        double best = 0;
        for (final double g in vertex.upGain) {
          best = math.max(best, g);
        }
        double gainOf(int u) {
          double g = 0;
          for (int k = 0; k < vertex.up.length; k++) {
            if (vertex.up[k] == u) g = math.max(g, vertex.upGain[k]);
          }
          return g;
        }

        final List<int> medians = <int>[
          for (final int u in ups)
            if (gainOf(u) >= best && (best > 1 || u == ups[m0] || u == ups[m1])) u,
        ];
        medians.sort((int a, int b) {
          final int c = (v[a].pos - vertex.pos).abs().compareTo((v[b].pos - vertex.pos).abs());
          return c != 0 ? c : v[a].order.compareTo(v[b].order);
        });
        for (final int u in <int>[ups[m0], ups[m1]]) {
          if (!medians.contains(u)) medians.add(u);
        }
        for (final int u in medians) {
          if (down[u] < 0 && v[u].order > lo && v[u].order < hi) {
            tied[i] = v[u].order;
            up[id] = u;
            down[u] = id;
            break;
          }
        }
      }
    }
    final List<int> block = List<int>.filled(n, -1);
    int count = 0;
    for (int i = 0; i < n; i++) {
      if (up[i] >= 0) continue;
      for (int j = i; j >= 0; j = down[j]) {
        block[j] = count;
      }
      count++;
    }
    _blockCount = count;
    return block;
  }

  int _blockCount = 0;

  /// Gives every block one coordinate: as close as it can get to the middle
  /// of what it is wired to, without breaking the order or the gaps inside
  /// any rank. Returns false when the blocks cannot be ordered (which the
  /// alignment rules should never allow), so the caller can fall back.
  bool _placeBlocks(List<int> block) {
    final int count = _blockCount;
    final List<List<(int, double)>> before = List<List<(int, double)>>.generate(count, (_) => <(int, double)>[]);
    final List<List<(int, double)>> after = List<List<(int, double)>>.generate(count, (_) => <(int, double)>[]);
    for (final List<int> layer in layers) {
      for (int i = 1; i < layer.length; i++) {
        final int a = block[layer[i - 1]];
        final int b = block[layer[i]];
        if (a == b) return false;
        final double sep = _separation(v[layer[i - 1]], v[layer[i]]);
        before[b].add((a, sep));
        after[a].add((b, sep));
      }
    }
    // Order the blocks so that every block comes after those above it.
    final List<int> waiting = <int>[for (int b = 0; b < count; b++) before[b].length];
    final List<int> order = <int>[
      for (int b = 0; b < count; b++)
        if (waiting[b] == 0) b,
    ];
    for (int head = 0; head < order.length; head++) {
      for (final (int b, double _) in after[order[head]]) {
        if (--waiting[b] == 0) order.add(b);
      }
    }
    if (order.length != count) return false;

    // Start from the balanced positions.
    final List<double> wanted = List<double>.filled(count, 0);
    final List<int> members = List<int>.filled(count, 0);
    for (int i = 0; i < v.length; i++) {
      wanted[block[i]] += v[i].pos;
      members[block[i]]++;
    }
    for (int b = 0; b < count; b++) {
      wanted[b] /= members[b];
    }
    final List<double> low = List<double>.filled(count, 0);
    final List<double> high = List<double>.filled(count, 0);
    final List<double> x = List<double>.filled(count, 0);
    void project() {
      for (final int b in order) {
        double p = wanted[b];
        for (final (int a, double sep) in before[b]) {
          p = math.max(p, low[a] + sep);
        }
        low[b] = p;
      }
      for (int i = count - 1; i >= 0; i--) {
        final int b = order[i];
        double p = wanted[b];
        for (final (int c, double sep) in after[b]) {
          p = math.min(p, high[c] - sep);
        }
        high[b] = p;
      }
      for (int b = 0; b < count; b++) {
        x[b] = (low[b] + high[b]) / 2;
      }
    }

    project();
    final List<double> sum = List<double>.filled(count, 0);
    final List<double> total = List<double>.filled(count, 0);
    for (int round = 0; round < 16; round++) {
      sum.fillRange(0, count, 0);
      total.fillRange(0, count, 0);
      for (int i = 0; i < v.length; i++) {
        final int b = block[i];
        for (int k = 0; k < v[i].down.length; k++) {
          final int d = v[i].down[k];
          final int o = block[d];
          if (o == b) continue;
          final double w = _weight(v[i], v[d]) * v[i].downGain[k];
          sum[b] += w * x[o];
          total[b] += w;
          sum[o] += w * x[b];
          total[o] += w;
        }
      }
      for (int b = 0; b < count; b++) {
        if (total[b] > 0) wanted[b] = (x[b] + sum[b] / total[b]) / 2;
      }
      project();
    }

    // On the grid, keeping every gap.
    for (final int b in order) {
      double p = kkSnap(x[b]);
      for (final (int a, double sep) in before[b]) {
        p = math.max(p, x[a] + sep);
      }
      x[b] = p;
    }
    for (int i = 0; i < v.length; i++) {
      v[i].pos = x[block[i]];
    }
    return true;
  }

  /// Puts all lane points of a long wire on one line when nothing is in the way.
  void _straighten() {
    for (final _Wire wire in wires) {
      if (wire.chain.length < 3) continue;
      final List<int> lanes = wire.chain.sublist(1, wire.chain.length - 1);
      double mean = 0;
      for (final int id in lanes) {
        mean += v[id].pos;
      }
      mean /= lanes.length;
      final List<double> candidates = <double>[v[wire.a].pos, v[wire.b].pos, mean];
      for (final double candidate in candidates) {
        bool fits = true;
        for (final int id in lanes) {
          final List<int> layer = layers[v[id].layer];
          final int i = v[id].order;
          if (i > 0 && v[layer[i - 1]].pos + _separation(v[layer[i - 1]], v[id]) > candidate + 0.01) fits = false;
          if (i + 1 < layer.length && candidate + _separation(v[id], v[layer[i + 1]]) > v[layer[i + 1]].pos + 0.01) {
            fits = false;
          }
          if (!fits) break;
        }
        if (fits) {
          for (final int id in lanes) {
            v[id].pos = candidate;
          }
          break;
        }
      }
    }
  }

  void _snap() {
    double least = double.infinity;
    for (final _V vertex in v) {
      least = math.min(least, vertex.pos - vertex.before);
    }
    if (!least.isFinite) least = 0;
    for (final List<int> layer in layers) {
      for (int i = 0; i < layer.length; i++) {
        final _V vertex = v[layer[i]];
        double p = kkSnap(vertex.pos - least);
        if (i > 0) {
          final _V prev = v[layer[i - 1]];
          p = math.max(p, prev.pos + _separation(prev, vertex));
        }
        vertex.pos = p;
      }
    }
  }

  // ── 6. the flow axis ────────────────────────────────────────────────────

  /// How many wires change lane between rank [l] and the next.
  int _changes(int l) {
    int count = 0;
    for (final int id in layers[l]) {
      for (final int d in v[id].down) {
        if ((v[d].pos - v[id].pos).abs() > 0.5) count++;
      }
    }
    return count;
  }

  static const double _trackPitch = 8;

  List<double> _mainAxis() {
    final int count = layers.length;
    final List<double> before = List<double>.filled(count, 0);
    final List<double> after = List<double>.filled(count, 0);
    for (int l = 0; l < count; l++) {
      for (final int id in layers[l]) {
        before[l] = math.max(before[l], v[id].mainBefore);
        after[l] = math.max(after[l], v[id].mainAfter);
      }
    }
    final List<double> centre = List<double>.filled(count, 0);
    centre[0] = kkSnapUp(before[0]);
    for (int l = 0; l + 1 < count; l++) {
      final int tracks = _changes(l);
      final double gap = math.max(layerGap, 32 + _trackPitch * math.max(0, tracks - 1));
      centre[l + 1] = kkSnapUp(centre[l] + after[l] + gap + before[l + 1]);
    }
    _before = before;
    _after = after;
    return centre;
  }

  List<double> _before = const <double>[];
  List<double> _after = const <double>[];

  // ── 7. tracks ───────────────────────────────────────────────────────────

  /// For every wire, the place along the flow axis where each of its legs
  /// changes lane. Legs between the same two ranks get tracks ordered so they
  /// cross each other as little as possible.
  Map<int, List<double>> _tracks(List<double> centre) {
    final Map<int, List<double>> out = <int, List<double>>{};
    for (int w = 0; w < wires.length; w++) {
      out[w] = List<double>.filled(wires[w].chain.length - 1, double.nan);
    }
    // Legs by the rank they leave.
    final List<List<(int, int)>> byRank = List<List<(int, int)>>.generate(layers.length, (_) => <(int, int)>[]);
    for (int w = 0; w < wires.length; w++) {
      final List<int> chain = wires[w].chain;
      for (int leg = 0; leg + 1 < chain.length; leg++) {
        if ((v[chain[leg]].pos - v[chain[leg + 1]].pos).abs() > 0.5) {
          byRank[v[chain[leg]].layer].add((w, leg));
        }
      }
    }
    for (int l = 0; l + 1 < layers.length; l++) {
      final List<(int, int)> legs = byRank[l];
      if (legs.isEmpty) continue;
      double from((int, int) leg) => v[wires[leg.$1].chain[leg.$2]].pos;
      double to((int, int) leg) => v[wires[leg.$1].chain[leg.$2 + 1]].pos;
      legs.sort(((int, int) a, (int, int) b) {
        final int c = from(a).compareTo(from(b));
        return c != 0 ? c : to(a).compareTo(to(b));
      });
      bool within(double x, double a, double b) => x > math.min(a, b) + 0.01 && x < math.max(a, b) - 0.01;
      // Crossings when leg x has the earlier track than leg y.
      int cost((int, int) x, (int, int) y) =>
          (within(from(y), from(x), to(x)) ? 1 : 0) + (within(to(x), from(y), to(y)) ? 1 : 0);
      final List<(int, int)> order = <(int, int)>[];
      for (final (int, int) leg in legs) {
        int bestAt = order.length;
        int bestCost = 1 << 30;
        for (int at = 0; at <= order.length; at++) {
          int c = 0;
          for (int i = 0; i < order.length; i++) {
            c += i < at ? cost(order[i], leg) : cost(leg, order[i]);
          }
          if (c < bestCost) {
            bestCost = c;
            bestAt = at;
          }
        }
        order.insert(bestAt, leg);
      }
      final double start = centre[l] + _after[l];
      final double end = centre[l + 1] - _before[l + 1];
      final double room = end - start;
      final double pitch = order.length > 1 ? math.min(_trackPitch, math.max(2, (room - 16) / (order.length - 1))) : 0;
      final double mid = kkSnap((start + end) / 2);
      for (int i = 0; i < order.length; i++) {
        final (int w, int leg) = order[i];
        final double track = mid + (i - (order.length - 1) / 2) * pitch;
        out[w]![leg] = track;
        // A bend on this track may be cut as far as the nearer rank.
        final double clear = math.max(0.0, math.min(track - start, end - track));
        _cutRoom[w] = math.min(_cutRoom[w] ?? double.infinity, clear);
      }
    }
    return out;
  }

  /// For every wire that changes lane, the least distance from one of its
  /// tracks to the ranks on either side.
  final Map<int, double> _cutRoom = <int, double>{};
}
