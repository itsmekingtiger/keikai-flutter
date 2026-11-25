import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart' show KkLevel;
import 'package:keikai/src/diagram/diagram.dart';

Matcher failsOnLine(int line) => throwsA(
  isA<FormatException>().having((FormatException e) => e.message, 'message', startsWith('line $line:')),
);

void main() {
  group('header', () {
    test('defaults to left to right', () {
      expect(KkDiagram.parse('A --> B').direction, KkDiagramDirection.leftToRight);
      expect(KkDiagram.parse('').direction, KkDiagramDirection.leftToRight);
    });

    test('reads LR, TB and TD in any case', () {
      expect(KkDiagram.parse('flow LR\nA').direction, KkDiagramDirection.leftToRight);
      expect(KkDiagram.parse('flow TB\nA').direction, KkDiagramDirection.topToBottom);
      expect(KkDiagram.parse('FLOW td\nA').direction, KkDiagramDirection.topToBottom);
    });

    test('rejects an unknown direction', () {
      expect(() => KkDiagram.parse('A\nflow RL'), failsOnLine(2));
    });

    test('"flow" is still usable as a node id', () {
      final KkDiagram d = KkDiagram.parse('flow --> B\nflow');
      expect(d.nodes.map((KkDiagramNode n) => n.id), <String>['flow', 'B']);
      expect(d.edges, hasLength(1));
    });
  });

  group('nodes', () {
    test('every bracket form', () {
      final KkDiagram d = KkDiagram.parse('''
SEC01[SEC-01|PUMP A|冷却]
CORE((CORE))
CHK{PRESSURE}
HALT([HALT])
L1>VALVE]
BARE
''');
      expect(d.nodes, hasLength(6));
      final KkDiagramNode sec = d.nodeById('SEC01')!;
      expect(sec.kind, KkNodeKind.node);
      expect(sec.code, 'SEC-01');
      expect(sec.label, 'PUMP A');
      expect(sec.cjk, '冷却');
      expect(d.nodeById('CORE')!.kind, KkNodeKind.hub);
      expect(d.nodeById('CHK')!.kind, KkNodeKind.decision);
      expect(d.nodeById('CHK')!.text, 'PRESSURE');
      expect(d.nodeById('HALT')!.kind, KkNodeKind.terminal);
      expect(d.nodeById('L1')!.kind, KkNodeKind.leaf);
      expect(d.nodeById('L1')!.text, 'VALVE');
      final KkDiagramNode bare = d.nodeById('BARE')!;
      expect(bare.kind, KkNodeKind.node);
      expect(bare.code, isNull);
      expect(bare.text, 'BARE');
    });

    test('text may hold spaces, brackets of other kinds and a hash', () {
      final KkDiagram d = KkDiagram.parse('A[PUMP #2 (AUX)] # comment\nB((A [1]))\nC{X > 3 ?}');
      expect(d.nodeById('A')!.text, 'PUMP #2 (AUX)');
      expect(d.nodeById('B')!.text, 'A [1]');
      expect(d.nodeById('C')!.text, 'X > 3 ?');
    });

    test('quoted fields hold the closing bracket and the field separator', () {
      final KkDiagram d = KkDiagram.parse('A["X [1]"|"a|b"]');
      expect(d.nodeById('A')!.code, 'X [1]');
      expect(d.nodeById('A')!.label, 'a|b');
    });

    test('empty middle field', () {
      final KkDiagram d = KkDiagram.parse('A[SEC-01||冷却]');
      expect(d.nodeById('A')!.label, isNull);
      expect(d.nodeById('A')!.cjk, '冷却');
    });

    test('levels and positions, in either order', () {
      final KkDiagram d = KkDiagram.parse('''
A:::critical
B[SEC-02]:::caution@0.25,0.5
C@120,-8:::offline
D :::nominal
''');
      expect(d.nodeById('A')!.level, KkLevel.critical);
      expect(d.nodeById('B')!.level, KkLevel.caution);
      expect(d.nodeById('B')!.position, const Offset(0.25, 0.5));
      expect(d.nodeById('C')!.level, KkLevel.offline);
      expect(d.nodeById('C')!.position, const Offset(120, -8));
      expect(d.nodeById('D')!.level, KkLevel.nominal);
    });

    test('ids take dashes and dots inside, and CJK', () {
      final KkDiagram d = KkDiagram.parse('SEC-01 --> N.07\n冷却-->電源');
      expect(d.nodes.map((KkDiagramNode n) => n.id), <String>['SEC-01', 'N.07', '冷却', '電源']);
      expect(d.edges, hasLength(2));
    });

    test('a later declaration fills a node in', () {
      final KkDiagram d = KkDiagram.parse('A --> B\nB((HUB)):::caution');
      expect(d.nodes.map((KkDiagramNode n) => n.id), <String>['A', 'B']);
      expect(d.nodeById('B')!.kind, KkNodeKind.hub);
      expect(d.nodeById('B')!.level, KkLevel.caution);
    });
  });

  group('wires', () {
    test('every operator', () {
      final KkDiagram d = KkDiagram.parse('''
A --> B
A --- B
A ==> B
A ==< B
A === B
A -.-> B
A -.- B
''');
      expect(d.edges, <KkDiagramEdge>[
        const KkDiagramEdge('A', 'B'),
        const KkDiagramEdge('A', 'B', arrow: false),
        const KkDiagramEdge('A', 'B', active: true, flow: KkEdgeFlow.forward),
        const KkDiagramEdge('A', 'B', active: true, flow: KkEdgeFlow.reverse),
        const KkDiagramEdge('A', 'B', active: true, arrow: false),
        const KkDiagramEdge('A', 'B', level: KkLevel.offline),
        const KkDiagramEdge('A', 'B', level: KkLevel.offline, arrow: false),
      ]);
    });

    test('labels, levels and attributes', () {
      final KkDiagram d = KkDiagram.parse('''
A -->|LOW| B
A -->|"A|B"|:::critical B
A -->:::caution,active,reverse B
A --- :::flow B
A ==> |HOT| :::critical B
''');
      expect(d.edges[0].label, 'LOW');
      expect(d.edges[1].label, 'A|B');
      expect(d.edges[1].level, KkLevel.critical);
      expect(d.edges[2], const KkDiagramEdge('A', 'B', level: KkLevel.caution, active: true, flow: KkEdgeFlow.reverse));
      expect(d.edges[3], const KkDiagramEdge('A', 'B', arrow: false, flow: KkEdgeFlow.forward));
      expect(
        d.edges[4],
        const KkDiagramEdge('A', 'B', label: 'HOT', level: KkLevel.critical, active: true, flow: KkEdgeFlow.forward),
      );
    });

    test('a level after a node belongs to the node, after a wire to the wire', () {
      final KkDiagram d = KkDiagram.parse('A --> B:::critical\nA -->:::caution C');
      expect(d.edges[0].level, isNull);
      expect(d.nodeById('B')!.level, KkLevel.critical);
      expect(d.edges[1].level, KkLevel.caution);
      expect(d.nodeById('C')!.level, isNull);
    });

    test('chains, tight spacing, semicolons and comments', () {
      final KkDiagram d = KkDiagram.parse('A-->B-->C ; C ==> D # tail\n\n# only a comment\n  D-.->A');
      expect(d.nodes.map((KkDiagramNode n) => n.id), <String>['A', 'B', 'C', 'D']);
      expect(d.edges.map((KkDiagramEdge e) => '${e.from}>${e.to}'), <String>['A>B', 'B>C', 'C>D', 'D>A']);
      expect(d.edges[2].active, isTrue);
      expect(d.edges[3].level, KkLevel.offline);
    });

    test('a wire to itself is kept', () {
      final KkDiagram d = KkDiagram.parse('A --> A');
      expect(d.edges.single, const KkDiagramEdge('A', 'A'));
    });

    test('Windows line ends', () {
      final KkDiagram d = KkDiagram.parse('flow TB\r\nA --> B\r\n');
      expect(d.direction, KkDiagramDirection.topToBottom);
      expect(d.edges, hasLength(1));
    });
  });

  group('errors name the line', () {
    test('unknown wire', () {
      expect(() => KkDiagram.parse('A --> B\nB -> C'), failsOnLine(2));
      expect(() => KkDiagram.parse('A B'), failsOnLine(1));
    });

    test('missing node after a wire', () {
      expect(() => KkDiagram.parse('\n\nA -->'), failsOnLine(3));
      expect(() => KkDiagram.parse('A --> # nothing'), failsOnLine(1));
    });

    test('unclosed text', () {
      expect(() => KkDiagram.parse('A[open'), failsOnLine(1));
      expect(() => KkDiagram.parse('A\nB((open)'), failsOnLine(2));
      expect(() => KkDiagram.parse('A["open]'), failsOnLine(1));
      expect(() => KkDiagram.parse('A -->|label B'), failsOnLine(1));
    });

    test('bad level, attribute, bracket and position', () {
      expect(() => KkDiagram.parse('A:::fatal'), failsOnLine(1));
      expect(() => KkDiagram.parse('A -->:::fast B'), failsOnLine(1));
      expect(() => KkDiagram.parse('A(text)'), failsOnLine(1));
      expect(() => KkDiagram.parse('A@1'), failsOnLine(1));
      expect(() => KkDiagram.parse('A@x,2'), failsOnLine(1));
      expect(() => KkDiagram.parse('A[a|b|c|d]'), failsOnLine(1));
    });

    test('stray characters', () {
      expect(() => KkDiagram.parse('A --> B ]'), failsOnLine(1));
      expect(() => KkDiagram.parse('--> B'), failsOnLine(1));
    });

    test('the exception carries the line and a column', () {
      try {
        KkDiagram.parse('A --> B\nB ~> C');
        fail('should have thrown');
      } on FormatException catch (e) {
        expect(e.source, 'B ~> C');
        expect(e.offset, isNotNull);
      }
    });

    test('tryParse returns null instead', () {
      expect(KkDiagram.tryParse('A -> B'), isNull);
      expect(KkDiagram.tryParse('A --> B'), isNotNull);
    });
  });

  group('round trip', () {
    const String source = '''
flow TB
# cooling loop
START([START]) --> CHK{PRESSURE|OK ?}
CHK -->|YES| PUMP[SEC-01|PUMP A|冷却]:::nominal
CHK -->|NO|:::critical HALT([HALT]):::critical
PUMP ==> CORE((CORE))
CORE ==< AUX[SEC-02]:::caution@0.5,0.25
CORE -.-> L1>VALVE]:::offline
CORE --- L2>"TAP [2]"]
AUX -->:::caution,active CHK
L1 === L2
''';

    test('parse, write, parse gives the same diagram', () {
      final KkDiagram first = KkDiagram.parse(source);
      final String written = first.toSource();
      final KkDiagram second = KkDiagram.parse(written);
      expect(second, first);
      expect(second.toSource(), written);
    });

    test('every wire combination survives', () {
      final List<KkDiagramEdge> edges = <KkDiagramEdge>[
        for (final bool active in <bool>[false, true])
          for (final bool arrow in <bool>[false, true])
            for (final KkEdgeFlow flow in KkEdgeFlow.values)
              for (final KkLevel? level in <KkLevel?>[null, ...KkLevel.values])
                KkDiagramEdge('A', 'B', active: active, arrow: arrow, flow: flow, level: level, label: 'L|1'),
      ];
      final KkDiagram d = KkDiagram(
        nodes: const <KkDiagramNode>[KkDiagramNode('A'), KkDiagramNode('B')],
        edges: edges,
      );
      expect(KkDiagram.parse(d.toSource()), d);
    });

    test('a model built by hand survives', () {
      final KkDiagram d = KkDiagram(
        direction: KkDiagramDirection.topToBottom,
        nodes: const <KkDiagramNode>[
          KkDiagramNode('SEC-01', code: 'SEC-01', label: 'PUMP [A]', kind: KkNodeKind.hub, level: KkLevel.caution),
          KkDiagramNode('N2', cjk: '電源', kind: KkNodeKind.decision, position: Offset(0.125, 240)),
          KkDiagramNode('N3', code: ' padded ', kind: KkNodeKind.leaf),
          KkDiagramNode('N4', kind: KkNodeKind.terminal),
        ],
        edges: const <KkDiagramEdge>[
          KkDiagramEdge('SEC-01', 'N2', label: ' spaced '),
          KkDiagramEdge('N2', 'N2'),
        ],
      );
      expect(KkDiagram.parse(d.toSource()), d);
    });

    test('what cannot be written throws', () {
      expect(() => KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('two words')]).toSource(), throwsArgumentError);
      expect(() => KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('A', code: 'say "x"')]).toSource(), throwsArgumentError);
      expect(() => KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('A-')]).toSource(), throwsArgumentError);
    });

    test('an empty diagram writes just the header', () {
      expect(KkDiagram.empty.toSource(), 'flow LR\n');
      expect(KkDiagram.parse(KkDiagram.empty.toSource()), KkDiagram.empty);
    });
  });
}
