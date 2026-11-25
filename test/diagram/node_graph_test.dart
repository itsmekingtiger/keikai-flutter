import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

KkDiagram grid({bool placed = true}) => KkDiagram(
  nodes: <KkDiagramNode>[
    KkDiagramNode('GA', code: 'GRID-A', kind: KkNodeKind.hub, position: placed ? const Offset(0.3, 0.4) : null),
    KkDiagramNode('S1', code: 'SEC-01', level: KkLevel.nominal, position: placed ? const Offset(0.1, 0.2) : null),
    KkDiagramNode('S4', code: 'SEC-04', level: KkLevel.critical, position: placed ? const Offset(0.7, 0.2) : null),
    KkDiagramNode('S6', code: 'SEC-06', level: KkLevel.offline, position: placed ? const Offset(0.9, 0.7) : null),
    KkDiagramNode('L1', code: 'L-71', kind: KkNodeKind.leaf, position: placed ? const Offset(0.5, 0.8) : null),
  ],
  edges: const <KkDiagramEdge>[
    KkDiagramEdge('S1', 'GA', active: true, flow: KkEdgeFlow.forward),
    KkDiagramEdge('GA', 'S4', level: KkLevel.critical),
    KkDiagramEdge('GA', 'S6', level: KkLevel.offline),
    KkDiagramEdge('GA', 'L1'),
  ],
);

Finder node(String id) => find.byKey(ValueKey<String>('kk-diagram-node-$id'));

void main() {
  setUpAll(loadKkFonts);

  testWidgets('frames the graph with a bilingual head, a meta and a legend', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(width: 520, child: KkNodeGraph(diagram: grid(), cjk: '電源系統', en: 'power grid', meta: '05 NODES')),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('電源系統'), findsOneWidget);
    expect(find.text('POWER GRID'), findsOneWidget);
    expect(find.text('05 NODES'), findsOneWidget);
    // Only what the diagram holds is in the legend.
    for (final String key in <String>['HUB', 'NODE', 'LEAF', 'ACTIVE', 'FLOW', 'OFFLINE']) {
      expect(find.text(key), findsOneWidget, reason: key);
    }
    expect(find.text('DECISION'), findsNothing);
    expect(find.text('TERMINAL'), findsNothing);
    expect(tester.getSize(find.byType(KkNodeGraph)).width, 520);
  });

  testWidgets('is never narrower than 320 unless told otherwise', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkRow(
        shrinkWrap: true,
        children: <Widget>[KkNodeGraph(diagram: KkDiagram.parse('A --- B'), layout: const KkForceLayout())],
      ),
    );
    expect(tester.getSize(find.byType(KkNodeGraph)).width, greaterThanOrEqualTo(320));
    await pumpKk(
      tester,
      KkRow(
        shrinkWrap: true,
        children: <Widget>[KkNodeGraph(diagram: KkDiagram.parse('A --- B'), minWidth: 0, legend: false)],
      ),
    );
    expect(tester.getSize(find.byType(KkNodeGraph)).width, lessThan(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the positions when every node has one, the force layout when not', (WidgetTester tester) async {
    await pumpKk(tester, KkBox(width: 520, child: KkNodeGraph(diagram: grid())));
    expect(tester.widget<KkDiagramView>(find.byType(KkDiagramView)).layout, isA<KkManualLayout>());
    await pumpKk(tester, KkBox(width: 520, child: KkNodeGraph(diagram: grid(placed: false))));
    expect(tester.widget<KkDiagramView>(find.byType(KkDiagramView)).layout, isA<KkForceLayout>());
    await pumpKk(
      tester,
      KkBox(width: 520, child: KkNodeGraph(diagram: grid(), layout: const KkRadialLayout(root: 'GA'))),
    );
    expect(tester.widget<KkDiagramView>(find.byType(KkDiagramView)).layout, isA<KkRadialLayout>());
    expect(tester.widget<KkDiagramView>(find.byType(KkDiagramView)).router, const KkEdgeRouter.octilinear());
    expect(tester.widget<KkDiagramView>(find.byType(KkDiagramView)).arrows, isFalse);
  });

  testWidgets('passes taps and selection through', (WidgetTester tester) async {
    final List<String?> picked = <String?>[];
    await pumpKk(
      tester,
      KkBox(width: 520, child: KkNodeGraph(diagram: grid(), onSelected: picked.add, selected: 'S1')),
    );
    expect(tester.widget<KkPressable>(node('S1')).selected, isTrue);
    await tester.tap(node('S4'));
    await tester.pump();
    expect(picked, <String?>['S4']);
  });

  testWidgets('fills a fixed height, takes a plot height, and survives odd inputs', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(width: 520, height: 300, child: KkNodeGraph(diagram: grid(), cjk: '電源系統', en: 'power grid', expand: true)),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkNodeGraph)), const Size(520, 300));

    await pumpKk(tester, KkBox(width: 520, child: KkNodeGraph(diagram: grid(), height: 180, legend: false)));
    expect(tester.getSize(find.byType(KkDiagramView)).height, 180);

    for (final Widget w in <Widget>[
      KkNodeGraph(diagram: KkDiagram.empty),
      KkNodeGraph(diagram: KkDiagram.empty, cjk: '空', en: 'empty', legend: false),
      KkBox(width: 40, height: 30, child: KkNodeGraph(diagram: grid(), expand: true, minWidth: 0)),
      KkNodeGraph(diagram: grid(), level: KkLevel.critical, footer: const <Widget>[KkWidgetKey(label: 'EXTRA')]),
      KkNodeGraph(diagram: grid(), level: KkLevel.offline, interactive: true, arrows: true),
    ]) {
      await pumpKk(tester, w, condition: KkCondition.alert);
      expect(tester.takeException(), isNull, reason: '$w');
    }
    expect(find.text('EXTRA'), findsNothing);
  });

  testWidgets('runs its motion without complaint', (WidgetTester tester) async {
    await pumpKk(tester, KkBox(width: 520, child: KkNodeGraph(diagram: grid(), cjk: '電源系統', en: 'power grid')), motion: true);
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });
}
