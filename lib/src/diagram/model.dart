import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../foundation/level.dart';
import 'parser.dart';

/// Which way a flow diagram runs.
enum KkDiagramDirection {
  /// Left to right (`flow LR`).
  leftToRight,

  /// Top to bottom (`flow TB`).
  topToBottom,
}

/// The symbol a diagram node is drawn with.
enum KkNodeKind {
  /// A pointy-top hexagon with a heavy outline: a junction or a core system.
  hub,

  /// A plate with the top-left corner cut: the ordinary node.
  node,

  /// A small filled square: an end point.
  leaf,

  /// A diamond: a decision.
  decision,

  /// A plate cut on both ends: a start or a stop.
  terminal,
}

/// Whether flow marks run along a wire, and which way.
enum KkEdgeFlow {
  /// No flow marks.
  none,

  /// Marks travel from the edge's `from` node to its `to` node.
  forward,

  /// Marks travel from `to` back to `from`.
  reverse,
}

/// One node of a [KkDiagram].
///
/// A node is drawn as a small symbol ([kind]) with its [text] (the code)
/// and an optional [cjk] title and [label] beside it. Equality compares the
/// text that is shown, so a node whose [code] is null equals one whose code
/// repeats its [id].
@immutable
class KkDiagramNode {
  const KkDiagramNode(
    this.id, {
    this.code,
    this.label,
    this.cjk,
    this.kind = KkNodeKind.node,
    this.level,
    this.position,
    this.size,
    this.info = const <String>[],
  });

  /// Unique key of the node inside its diagram.
  final String id;

  /// The code shown with the symbol, such as `SEC-04`. Defaults to [id].
  final String? code;

  /// A short Latin name shown under the code.
  final String? label;

  /// A short CJK title shown before the label.
  final String? cjk;

  final KkNodeKind kind;

  /// The node's status. Null draws it in the signal colour with no flag.
  final KkLevel? level;

  /// Where a manual layout puts the centre of the symbol: a fraction of the
  /// layout's size (0 to 1) or absolute pixels, as the layout says.
  final Offset? position;

  /// Overrides the symbol's size.
  final Size? size;

  /// Lines for the info plate shown when the node is selected.
  final List<String> info;

  /// The code that is drawn: [code], or [id] when there is none.
  String get text {
    final String? c = code;
    return c == null || c.isEmpty ? id : c;
  }

  KkDiagramNode copyWith({
    String? id,
    String? code,
    String? label,
    String? cjk,
    KkNodeKind? kind,
    KkLevel? level,
    bool clearLevel = false,
    Offset? position,
    bool clearPosition = false,
    Size? size,
    List<String>? info,
  }) {
    return KkDiagramNode(
      id ?? this.id,
      code: code ?? this.code,
      label: label ?? this.label,
      cjk: cjk ?? this.cjk,
      kind: kind ?? this.kind,
      level: clearLevel ? null : (level ?? this.level),
      position: clearPosition ? null : (position ?? this.position),
      size: size ?? this.size,
      info: info ?? this.info,
    );
  }

  static String? _blank(String? s) => s == null || s.isEmpty ? null : s;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkDiagramNode &&
        other.id == id &&
        other.text == text &&
        _blank(other.label) == _blank(label) &&
        _blank(other.cjk) == _blank(cjk) &&
        other.kind == kind &&
        other.level == level &&
        other.position == position &&
        other.size == size &&
        listEquals(other.info, info);
  }

  @override
  int get hashCode =>
      Object.hash(id, text, _blank(label), _blank(cjk), kind, level, position, size, Object.hashAll(info));

  @override
  String toString() => 'KkDiagramNode($id, ${kind.name}${level == null ? '' : ', ${level!.name}'})';
}

/// One wire of a [KkDiagram], from the node [from] to the node [to].
@immutable
class KkDiagramEdge {
  const KkDiagramEdge(
    this.from,
    this.to, {
    this.label,
    this.level,
    this.active = false,
    this.flow = KkEdgeFlow.none,
    this.arrow = true,
  });

  /// Id of the node the wire leaves.
  final String from;

  /// Id of the node the wire enters.
  final String to;

  /// Short text drawn on the wire.
  final String? label;

  /// Caution and critical colour the wire; offline dashes it.
  final KkLevel? level;

  /// An active wire is drawn in the signal colour.
  final bool active;

  /// Flow marks running along the wire.
  final KkEdgeFlow flow;

  /// Draw a chevron head at the [to] end.
  final bool arrow;

  KkDiagramEdge copyWith({
    String? from,
    String? to,
    String? label,
    KkLevel? level,
    bool clearLevel = false,
    bool? active,
    KkEdgeFlow? flow,
    bool? arrow,
  }) {
    return KkDiagramEdge(
      from ?? this.from,
      to ?? this.to,
      label: label ?? this.label,
      level: clearLevel ? null : (level ?? this.level),
      active: active ?? this.active,
      flow: flow ?? this.flow,
      arrow: arrow ?? this.arrow,
    );
  }

  static String? _blank(String? s) => s == null || s.isEmpty ? null : s;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkDiagramEdge &&
        other.from == from &&
        other.to == to &&
        _blank(other.label) == _blank(label) &&
        other.level == level &&
        other.active == active &&
        other.flow == flow &&
        other.arrow == arrow;
  }

  @override
  int get hashCode => Object.hash(from, to, _blank(label), level, active, flow, arrow);

  @override
  String toString() => 'KkDiagramEdge($from -> $to)';
}

/// A diagram: nodes, the wires between them and a flow direction.
///
/// The model is immutable and carries no geometry; a `KkDiagramLayout` places
/// it and a `KkDiagramView` draws it. Build one from objects, or from text
/// with [KkDiagram.parse].
///
/// The constructor checks the diagram and throws an [ArgumentError] when a
/// node id is empty or used twice, or when a wire names a node that is not
/// there.
@immutable
class KkDiagram {
  KkDiagram({
    Iterable<KkDiagramNode> nodes = const <KkDiagramNode>[],
    Iterable<KkDiagramEdge> edges = const <KkDiagramEdge>[],
    this.direction = KkDiagramDirection.leftToRight,
  }) : nodes = List<KkDiagramNode>.unmodifiable(nodes),
       edges = List<KkDiagramEdge>.unmodifiable(edges) {
    final Map<String, int> index = <String, int>{};
    for (int i = 0; i < this.nodes.length; i++) {
      final String id = this.nodes[i].id;
      if (id.isEmpty) {
        throw ArgumentError.value(id, 'nodes[$i].id', 'A node id must not be empty');
      }
      if (index.containsKey(id)) {
        throw ArgumentError.value(id, 'nodes[$i].id', 'Duplicate node id (also used by nodes[${index[id]}])');
      }
      index[id] = i;
    }
    for (int i = 0; i < this.edges.length; i++) {
      final KkDiagramEdge e = this.edges[i];
      if (!index.containsKey(e.from)) {
        throw ArgumentError.value(e.from, 'edges[$i].from', 'Wire starts at a node that is not in the diagram');
      }
      if (!index.containsKey(e.to)) {
        throw ArgumentError.value(e.to, 'edges[$i].to', 'Wire ends at a node that is not in the diagram');
      }
    }
    _index = index;
  }

  /// Reads a diagram from the small flowchart language described in
  /// [kkParseDiagram]. Throws a [FormatException] naming the line on bad input.
  factory KkDiagram.parse(String source) => kkParseDiagram(source);

  /// Like [KkDiagram.parse], but returns null instead of throwing.
  static KkDiagram? tryParse(String source) {
    try {
      return kkParseDiagram(source);
    } on FormatException {
      return null;
    }
  }

  /// A diagram with nothing in it.
  static final KkDiagram empty = KkDiagram();

  final List<KkDiagramNode> nodes;
  final List<KkDiagramEdge> edges;
  final KkDiagramDirection direction;

  late final Map<String, int> _index;

  bool get isEmpty => nodes.isEmpty;

  /// Position of the node [id] in [nodes], or -1.
  int indexOf(String id) => _index[id] ?? -1;

  /// The node called [id], or null.
  KkDiagramNode? nodeById(String id) {
    final int? i = _index[id];
    return i == null ? null : nodes[i];
  }

  /// The wires that leave [id].
  Iterable<KkDiagramEdge> outgoing(String id) => edges.where((KkDiagramEdge e) => e.from == id);

  /// The wires that enter [id].
  Iterable<KkDiagramEdge> incoming(String id) => edges.where((KkDiagramEdge e) => e.to == id);

  /// The ids of every node joined to [id] by a wire, in wire order.
  List<String> neighbours(String id) {
    final List<String> out = <String>[];
    for (final KkDiagramEdge e in edges) {
      if (e.from == id && e.to != id && !out.contains(e.to)) out.add(e.to);
      if (e.to == id && e.from != id && !out.contains(e.from)) out.add(e.from);
    }
    return out;
  }

  /// Writes the diagram in the language [KkDiagram.parse] reads.
  ///
  /// Node sizes and info lines have no text form and are left out. Throws an
  /// [ArgumentError] when an id or a text cannot be written.
  String toSource() => kkDiagramToSource(this);

  KkDiagram copyWith({
    Iterable<KkDiagramNode>? nodes,
    Iterable<KkDiagramEdge>? edges,
    KkDiagramDirection? direction,
  }) => KkDiagram(nodes: nodes ?? this.nodes, edges: edges ?? this.edges, direction: direction ?? this.direction);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkDiagram &&
        other.direction == direction &&
        listEquals(other.nodes, nodes) &&
        listEquals(other.edges, edges);
  }

  @override
  late final int hashCode = Object.hash(direction, Object.hashAll(nodes), Object.hashAll(edges));

  @override
  String toString() => 'KkDiagram(${nodes.length} nodes, ${edges.length} wires, ${direction.name})';
}
