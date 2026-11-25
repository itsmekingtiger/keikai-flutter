import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

void main() {
  group('KkDiagram', () {
    test('rejects duplicate and empty ids', () {
      expect(
        () => KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('A'), KkDiagramNode('A')]),
        throwsA(isA<ArgumentError>().having((ArgumentError e) => e.message, 'message', contains('Duplicate node id'))),
      );
      expect(() => KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('')]), throwsArgumentError);
    });

    test('rejects wires to nodes that are not there', () {
      expect(
        () => KkDiagram(
          nodes: const <KkDiagramNode>[KkDiagramNode('A')],
          edges: const <KkDiagramEdge>[KkDiagramEdge('A', 'B')],
        ),
        throwsA(isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', 'edges[0].to')),
      );
      expect(
        () => KkDiagram(
          nodes: const <KkDiagramNode>[KkDiagramNode('A')],
          edges: const <KkDiagramEdge>[KkDiagramEdge('X', 'A')],
        ),
        throwsA(isA<ArgumentError>().having((ArgumentError e) => e.name, 'name', 'edges[0].from')),
      );
    });

    test('lists cannot be changed from outside', () {
      final List<KkDiagramNode> nodes = <KkDiagramNode>[const KkDiagramNode('A')];
      final KkDiagram d = KkDiagram(nodes: nodes);
      nodes.add(const KkDiagramNode('B'));
      expect(d.nodes, hasLength(1));
      expect(() => d.nodes.add(const KkDiagramNode('C')), throwsUnsupportedError);
      expect(() => d.edges.add(const KkDiagramEdge('A', 'A')), throwsUnsupportedError);
    });

    test('lookups', () {
      final KkDiagram d = KkDiagram.parse('A --> B --> C\nC --> A\nA --> A\nD');
      expect(d.indexOf('C'), 2);
      expect(d.indexOf('nope'), -1);
      expect(d.nodeById('nope'), isNull);
      expect(d.outgoing('A').map((KkDiagramEdge e) => e.to), <String>['B', 'A']);
      expect(d.incoming('A').map((KkDiagramEdge e) => e.from), <String>['C', 'A']);
      expect(d.neighbours('A'), <String>['B', 'C']);
      expect(d.neighbours('D'), isEmpty);
      expect(d.isEmpty, isFalse);
      expect(KkDiagram.empty.isEmpty, isTrue);
    });

    test('value equality', () {
      KkDiagram build() => KkDiagram(
        nodes: const <KkDiagramNode>[
          KkDiagramNode('A', level: KkLevel.caution, info: <String>['x']),
          KkDiagramNode('B', position: Offset(1, 2)),
        ],
        edges: const <KkDiagramEdge>[KkDiagramEdge('A', 'B', label: 'L')],
      );
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build().copyWith(direction: KkDiagramDirection.topToBottom)));
      expect(build(), isNot(build().copyWith(edges: const <KkDiagramEdge>[])));
    });
  });

  group('KkDiagramNode', () {
    test('the shown text is the code, or the id', () {
      expect(const KkDiagramNode('A').text, 'A');
      expect(const KkDiagramNode('A', code: '').text, 'A');
      expect(const KkDiagramNode('A', code: 'SEC-01').text, 'SEC-01');
    });

    test('equality compares what is shown', () {
      expect(const KkDiagramNode('A'), const KkDiagramNode('A', code: 'A'));
      expect(const KkDiagramNode('A', label: ''), const KkDiagramNode('A'));
      expect(const KkDiagramNode('A'), isNot(const KkDiagramNode('A', kind: KkNodeKind.hub)));
      expect(const KkDiagramNode('A'), isNot(const KkDiagramNode('A', level: KkLevel.offline)));
    });

    test('copyWith can clear the level and the position', () {
      const KkDiagramNode n = KkDiagramNode('A', level: KkLevel.critical, position: Offset(1, 1));
      expect(n.copyWith(clearLevel: true).level, isNull);
      expect(n.copyWith(clearPosition: true).position, isNull);
      expect(n.copyWith(label: 'x').level, KkLevel.critical);
    });
  });

  group('KkDiagramEdge', () {
    test('defaults and equality', () {
      const KkDiagramEdge e = KkDiagramEdge('A', 'B');
      expect(e.arrow, isTrue);
      expect(e.active, isFalse);
      expect(e.flow, KkEdgeFlow.none);
      expect(e, const KkDiagramEdge('A', 'B', label: ''));
      expect(e, isNot(const KkDiagramEdge('B', 'A')));
      expect(e.copyWith(level: KkLevel.caution).copyWith(clearLevel: true), e);
    });
  });
}
