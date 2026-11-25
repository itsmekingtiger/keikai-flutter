import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'router.dart';

/// The spanning forest of a diagram: who is whose child, how deep each node
/// is, and which wires are tree wires.
class KkDiagramForest {
  KkDiagramForest._(this.roots, this.parent, this.children, this.depth, this.treeEdge);

  /// Builds the forest of [diagram].
  ///
  /// Roots are the nodes nothing points at (or, when a part of the diagram is
  /// one big cycle, its first node). With [undirected] a wire is followed
  /// both ways, so everything joined to a root ends up in its tree.
  ///
  /// The wires are taken in the order they are written: the earliest wire
  /// that leads from the forest to a node outside it makes that node a child.
  /// So the first wire into a node names its parent, and the wires written
  /// after it (a second parent, a short cut, a link back up) are extra. With
  /// [breadthFirst] every node hangs as close to its root as it can instead,
  /// whatever the order.
  factory KkDiagramForest.of(
    KkDiagram diagram, {
    bool undirected = false,
    bool breadthFirst = false,
    String? root,
  }) {
    final int n = diagram.nodes.length;
    final List<List<(int, int)>> next = List<List<(int, int)>>.generate(n, (_) => <(int, int)>[]);
    final List<int> indegree = List<int>.filled(n, 0);
    for (int i = 0; i < diagram.edges.length; i++) {
      final int a = diagram.indexOf(diagram.edges[i].from);
      final int b = diagram.indexOf(diagram.edges[i].to);
      if (a == b || a < 0 || b < 0) continue;
      next[a].add((b, i));
      indegree[b]++;
      if (undirected) next[b].add((a, i));
    }
    final List<int> parent = List<int>.filled(n, -1);
    final List<List<int>> children = List<List<int>>.generate(n, (_) => <int>[]);
    final List<int> depth = List<int>.filled(n, 0);
    final List<bool> seen = List<bool>.filled(n, false);
    final Set<int> treeEdge = <int>{};
    final List<int> roots = <int>[];

    final int first = root == null ? -1 : diagram.indexOf(root);
    if (breadthFirst) {
      void grow(int start) {
        roots.add(start);
        seen[start] = true;
        final List<int> queue = <int>[start];
        for (int head = 0; head < queue.length; head++) {
          final int a = queue[head];
          for (final (int b, int edge) in next[a]) {
            if (seen[b]) continue;
            seen[b] = true;
            parent[b] = a;
            depth[b] = depth[a] + 1;
            children[a].add(b);
            treeEdge.add(edge);
            queue.add(b);
          }
        }
      }

      if (first >= 0) grow(first);
      for (int i = 0; i < n; i++) {
        if (!seen[i] && indegree[i] == 0) grow(i);
      }
      for (int i = 0; i < n; i++) {
        if (!seen[i]) grow(i);
      }
      return KkDiagramForest._(roots, parent, children, depth, treeEdge);
    }

    // In the order the wires are written.
    final SplayTreeSet<int> open = SplayTreeSet<int>();
    void take(int node) {
      seen[node] = true;
      for (final (int other, int edge) in next[node]) {
        if (!seen[other]) open.add(edge);
      }
    }

    void plant(int node) {
      roots.add(node);
      take(node);
    }

    if (first >= 0) plant(first);
    // With wires that point one way, every node nothing points at is a root
    // from the start, so a node with parents in two trees goes to the wire
    // written first. Followed both ways, one root takes all that is joined
    // to it.
    if (!undirected) {
      for (int i = 0; i < n; i++) {
        if (!seen[i] && indegree[i] == 0) plant(i);
      }
    }
    int unseen = 0;
    while (true) {
      while (open.isNotEmpty) {
        final int edge = open.first;
        open.remove(edge);
        final int a = diagram.indexOf(diagram.edges[edge].from);
        final int b = diagram.indexOf(diagram.edges[edge].to);
        final int from = seen[a] ? a : b;
        final int to = seen[a] ? b : a;
        if (seen[to]) continue;
        parent[to] = from;
        depth[to] = depth[from] + 1;
        children[from].add(to);
        treeEdge.add(edge);
        take(to);
      }
      // What is left is not joined to any root: start again from its first
      // node (for wires followed both ways, a node nothing points at first).
      int nextRoot = -1;
      if (undirected) {
        for (int i = unseen; i < n && nextRoot < 0; i++) {
          if (!seen[i] && indegree[i] == 0) nextRoot = i;
        }
      }
      while (unseen < n && seen[unseen]) {
        unseen++;
      }
      if (nextRoot < 0) nextRoot = unseen;
      if (nextRoot >= n) break;
      plant(nextRoot);
    }
    return KkDiagramForest._(roots, parent, children, depth, treeEdge);
  }

  /// Node indices of the roots, in order.
  final List<int> roots;

  /// Parent index of every node (-1 for a root).
  final List<int> parent;

  /// Child indices of every node, in order.
  final List<List<int>> children;

  /// Distance of every node from its root.
  final List<int> depth;

  /// Indices of the diagram edges that are tree wires.
  final Set<int> treeEdge;
}

/// The tidy tree: leaves are set out in order, every parent is centred over
/// its children, and each generation sits on its own line. A diagram with
/// several roots becomes a forest, side by side.
///
/// The first wire written into a node names its parent. Wires that are not
/// part of the tree (a second parent, a short cut, a link back up) are still
/// drawn: along the same axis where the way is clear, round the nodes that
/// stand in it where it is not.
class KkTreeLayout extends KkDiagramLayout {
  const KkTreeLayout({this.direction, this.nodeGap = 16, this.layerGap = 48})
    : assert(nodeGap >= 0),
      assert(layerGap >= 0);

  /// The axis the generations follow. Defaults to the diagram's direction.
  final KkDiagramDirection? direction;

  /// Space between neighbouring subtrees.
  final double nodeGap;

  /// Space between generations.
  final double layerGap;

  @override
  KkEdgeRouter get defaultRouter => const KkEdgeRouter.orthogonal();

  @override
  KkDiagramPlacement place(KkDiagram diagram, {KkNodeMetrics metrics = const KkNodeMetrics()}) {
    final KkDiagramDirection dir = direction ?? diagram.direction;
    final int n = diagram.nodes.length;
    if (n == 0) {
      return KkDiagramPlacement(size: Size.zero, nodes: const <String, KkNodePlacement>{}, direction: dir);
    }
    final bool horizontal = dir == KkDiagramDirection.leftToRight;
    final bool labelRight = kkLabelRight(metrics, dir);
    final List<KkNodeBox> boxes = <KkNodeBox>[
      for (final KkDiagramNode node in diagram.nodes) metrics.measure(node, labelRight: labelRight),
    ];
    final KkDiagramForest forest = KkDiagramForest.of(diagram);

    double before(int i) => horizontal ? boxes[i].anchor.dy : boxes[i].anchor.dx;
    double after(int i) =>
        horizontal ? boxes[i].size.height - boxes[i].anchor.dy : boxes[i].size.width - boxes[i].anchor.dx;
    double mainBefore(int i) => horizontal ? boxes[i].anchor.dx : boxes[i].anchor.dy;
    double mainAfter(int i) =>
        horizontal ? boxes[i].size.width - boxes[i].anchor.dx : boxes[i].size.height - boxes[i].anchor.dy;

    // Cross axis: leaves in order, parents centred, subtrees never interleave.
    final List<double> pos = List<double>.filled(n, 0);
    final List<double> start = List<double>.filled(n, 0);
    double cursor = 0;

    void shift(int root, double by) {
      final List<int> stack = <int>[root];
      while (stack.isNotEmpty) {
        final int i = stack.removeLast();
        pos[i] += by;
        stack.addAll(forest.children[i]);
      }
    }

    for (final int root in forest.roots) {
      // Post-order without recursion.
      final List<int> stackNode = <int>[root];
      final List<int> stackNext = <int>[0];
      start[root] = cursor;
      while (stackNode.isNotEmpty) {
        final int i = stackNode.last;
        final int at = stackNext.last;
        final List<int> kids = forest.children[i];
        if (at < kids.length) {
          stackNext[stackNext.length - 1] = at + 1;
          start[kids[at]] = cursor;
          stackNode.add(kids[at]);
          stackNext.add(0);
          continue;
        }
        stackNode.removeLast();
        stackNext.removeLast();
        if (kids.isEmpty) {
          pos[i] = kkSnapUp(cursor + before(i));
          cursor = pos[i] + after(i) + nodeGap;
        } else {
          pos[i] = kkSnap((pos[kids.first] + pos[kids.last]) / 2);
          final double lack = start[i] - (pos[i] - before(i));
          if (lack > 0) {
            shift(i, kkSnapUp(lack));
            cursor += kkSnapUp(lack);
          }
          cursor = math.max(cursor, pos[i] + after(i) + nodeGap);
        }
      }
    }

    // Main axis: one line per generation.
    int generations = 0;
    for (int i = 0; i < n; i++) {
      generations = math.max(generations, forest.depth[i] + 1);
    }
    final List<double> lineBefore = List<double>.filled(generations, 0);
    final List<double> lineAfter = List<double>.filled(generations, 0);
    for (int i = 0; i < n; i++) {
      final int d = forest.depth[i];
      lineBefore[d] = math.max(lineBefore[d], mainBefore(i));
      lineAfter[d] = math.max(lineAfter[d], mainAfter(i));
    }
    final List<double> centre = List<double>.filled(generations, 0);
    centre[0] = kkSnapUp(lineBefore[0]);
    for (int d = 0; d + 1 < generations; d++) {
      centre[d + 1] = kkSnapUp(centre[d] + lineAfter[d] + layerGap + lineBefore[d + 1]);
    }

    Offset pt(double main, double cross) => horizontal ? Offset(main, cross) : Offset(cross, main);

    final Map<String, KkNodePlacement> nodes = <String, KkNodePlacement>{
      for (int i = 0; i < n; i++)
        diagram.nodes[i].id: KkNodePlacement.at(boxes[i], pt(centre[forest.depth[i]], pos[i])),
    };
    // Every wire from one generation to the next changes lane on one shared
    // line, so siblings hang from a bus.
    final Map<int, KkEdgeHint> hints = <int, KkEdgeHint>{};
    for (final int e in forest.treeEdge) {
      final int a = diagram.indexOf(diagram.edges[e].from);
      final int b = diagram.indexOf(diagram.edges[e].to);
      final bool reversed = forest.parent[b] != a;
      final int d = math.min(forest.depth[a], forest.depth[b]);
      final double start = centre[d] + lineAfter[d];
      final double end = centre[d + 1] - lineBefore[d + 1];
      final double jog = kkSnap((start + end) / 2);
      hints[e] = KkEdgeHint(
        jogs: <double>[jog],
        reversed: reversed,
        maxCut: math.max(0.0, math.min(jog - start, end - jog)),
      );
    }
    return KkDiagramPlacement.normalised(nodes, hints: hints, direction: dir);
  }

  @override
  bool operator ==(Object other) =>
      other is KkTreeLayout && other.direction == direction && other.nodeGap == nodeGap && other.layerGap == layerGap;

  @override
  int get hashCode => Object.hash(KkTreeLayout, direction, nodeGap, layerGap);
}
