import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/diagram_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/sector_detail.dart';
import 'app_harness.dart';

KkNodeGraph _graph(WidgetTester tester) => tester.widget<KkNodeGraph>(find.byType(KkNodeGraph));

Finder _segment(String label) => find.descendant(
  of: find.byWidgetPredicate((Widget w) => w is KkSegmented, description: 'a segmented control'),
  matching: find.text(label),
);

/// Shows the second tab of the lower panel: the source editor.
Future<void> _openEditor(WidgetTester tester) async {
  await tester.ensureVisible(find.text('EDITOR'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('EDITOR'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the diagrams lay out and follow the plant', '/diagram', (
    WidgetTester tester,
    Rig rig,
    Size size,
  ) async {
    expect(find.byType(DiagramScreen), findsOneWidget);
    expect(find.byType(KkNodeGraph), findsOneWidget);
    expect(find.byType(KkSequenceDiagram), findsOneWidget);
    expect(find.byType(KkDiagramView), findsWidgets);
    // The second tab holds the editor: source and drawing share a split from
    // 840px; below that they stack.
    await _openEditor(tester);
    expect(find.byType(KkSequenceDiagram), findsNothing);
    expect(find.byType(KkTextField), findsOneWidget);
    expect(find.byType(KkSplit), size.width >= 840 ? findsOneWidget : findsNothing);
    await tester.ensureVisible(find.text('HANDOVER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HANDOVER'));
    await tester.pumpAndSettle();
    expect(find.byType(KkSequenceDiagram), findsOneWidget);
    // Live: the coolant sector's node carries the sector's level.
    expect(_graph(tester).diagram.nodeById('SEC-04')!.level, rig.station.sectors[3].level);
    await tick(tester, rig, 2);
    expect(_graph(tester).diagram.nodeById('SEC-04')!.level, rig.station.sectors[3].level);
  });

  runsWithMotion('the diagrams run with motion on', '/diagram');

  testWidgets('both plants draw in all four placements', (WidgetTester tester) async {
    await pumpApp(tester, route: '/diagram');
    for (final String plant in <String>['POWER', 'COOLANT']) {
      await tester.tap(_segment(plant));
      await tester.pumpAndSettle();
      for (final String placement in <String>['TREE', 'RADIAL', 'FORCE', 'LAYERED']) {
        await tester.tap(_segment(placement));
        await tester.pumpAndSettle();
        expect(_graph(tester).meta, startsWith(placement), reason: '$plant $placement');
        expectClean(tester, '$plant $placement');
      }
    }
    // Choosing a plant returns to that plant's own placement.
    await tester.tap(_segment('POWER'));
    await tester.pumpAndSettle();
    expect(_graph(tester).meta, 'FORCE · 13 NODES');
    await tester.tap(_segment('COOLANT'));
    await tester.pumpAndSettle();
    expect(_graph(tester).meta, 'LAYERED · 09 NODES');
  });

  testWidgets('the zoom buttons move the view and Fit puts it back', (WidgetTester tester) async {
    await pumpApp(tester, route: '/diagram');
    final KkDiagramController view = _graph(tester).controller!;
    final Offset corner = view.toView(Offset.zero);
    final Offset far = view.toView(const Offset(100, 0));
    await tester.tap(iconButton('Zoom in'));
    await tester.pump();
    expect((view.toView(const Offset(100, 0)) - view.toView(Offset.zero)).dx, closeTo((far - corner).dx * 1.25, 0.01));
    await tester.tap(iconButton('Zoom out'));
    await tester.tap(iconButton('Zoom out'));
    await tester.pump();
    expect((view.toView(const Offset(100, 0)) - view.toView(Offset.zero)).dx, closeTo((far - corner).dx / 1.25, 0.01));
    await tester.tap(iconButton('Fit'));
    await tester.pump();
    expect(view.toView(Offset.zero), corner);
    expectClean(tester, 'zoom');
  });

  testWidgets('a selected node fills the inspector and leads to its sector', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/diagram');
    expect(find.text('NO NODE SELECTED'), findsOneWidget);
    _graph(tester).onSelected!('SEC-04');
    await tester.pump();
    expect(find.text('NO NODE SELECTED'), findsNothing);
    expect(_graph(tester).selected, 'SEC-04');
    expect(find.byType(KkNodeSymbol), findsWidgets);
    // A sector's node shows how the sector's load has been going, live.
    KkSparkline trend() => tester.widget<KkSparkline>(find.byType(KkSparkline));
    final Sector coolant = rig.station.sectors[3];
    expect(trend().values, coolant.trend);
    expect(trend().level, isNull, reason: 'a nominal sector draws in the series colour');
    await tick(tester, rig, 2);
    expect(trend().values, coolant.trend);
    expect(find.text('${kkFixed(coolant.load, digits: 3)} %'), findsOneWidget);
    await tester.tap(button('open sector'));
    await tester.pumpAndSettle();
    expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-04');
    await tester.tap(iconButton('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SectorSheet), findsNothing);

    // A node that is not a sector has neither; the close button clears.
    _graph(tester).onSelected!('HX-01');
    await tester.pump();
    expect(button('open sector'), findsNothing);
    expect(find.byType(KkSparkline), findsNothing);
    await tester.tap(iconButton('Clear selection'));
    await tester.pump();
    expect(find.text('NO NODE SELECTED'), findsOneWidget);
    expect(_graph(tester).selected, isNull);
    expectClean(tester, 'inspector');
  });

  testWidgets('tapping a node on the canvas selects it', (WidgetTester tester) async {
    await pumpApp(tester, route: '/diagram');
    // The intake terminal is the first symbol of the flow: find it through the view's own geometry.
    final KkDiagramController view = _graph(tester).controller!;
    final Rect canvas = tester.getRect(find.byType(KkDiagramView).first);
    Offset? hit;
    for (double x = 8; x < canvas.width && hit == null; x += 8) {
      for (double y = 8; y < canvas.height && hit == null; y += 8) {
        await tester.tapAt(canvas.topLeft + Offset(x, y));
        await tester.pump();
        if (_graph(tester).selected != null) hit = Offset(x, y);
      }
    }
    expect(hit, isNotNull, reason: 'no tap on the canvas selected a node');
    expect(_graph(tester).diagram.nodeById(_graph(tester).selected!), isNotNull);
    expect(view.toScene(hit!).dx.isFinite, isTrue);
    expectClean(tester, 'canvas tap');
  });

  testWidgets('the incident and the procedure show in the loop and in the handover', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/diagram');
    KkDiagram loop() => _graph(tester).diagram;
    KkSequenceDiagram handover() => tester.widget<KkSequenceDiagram>(find.byType(KkSequenceDiagram));
    expect(loop().nodeById('PUMP-A')!.level, KkLevel.nominal);
    expect(loop().nodeById('PUMP-B')!.level, KkLevel.offline);
    final int quiet = handover().entries.length;

    await raiseIncident(tester, rig);
    expect(loop().nodeById('PUMP-A')!.level, KkLevel.critical);
    expect(loop().nodeById('SEC-04')!.level, KkLevel.critical);
    expect(_graph(tester).level, KkLevel.critical);
    expect(handover().entries.length, greaterThan(quiet));

    rig.station.advanceProcedure(); // start the aux pump
    await tick(tester, rig);
    expect(loop().nodeById('PUMP-B')!.level, KkLevel.nominal);
    rig.station.advanceProcedure(); // close the valve
    await tick(tester, rig);
    expect(loop().nodeById('V-17')!.level, KkLevel.offline);
    expectClean(tester, 'incident');
  });

  testWidgets('the editor draws what it can read and says what it cannot', (WidgetTester tester) async {
    await pumpApp(tester, route: '/diagram', size: const Size(1440, 2000));
    await _openEditor(tester);
    final Finder source = find.byType(EditableText);
    KkWidgetFrame rendered() =>
        tester.widget<KkWidgetFrame>(find.byWidgetPredicate((Widget w) => w is KkWidgetFrame && w.en == 'rendered'));
    expect(rendered().meta, '07 NODES · 07 WIRES');

    await tester.enterText(source, 'flow LR\nA[A-01|PUMP] ==> B((CORE))');
    await tester.pump();
    expect(rendered().meta, '02 NODES · 01 WIRES');
    expect(rendered().level, isNull);

    // A wire to nowhere: the error names the line, and the last good drawing stays.
    await tester.enterText(source, 'flow LR\nA[A-01|PUMP] ==>');
    await tester.pump();
    expect(find.textContaining('LINE 2'), findsOneWidget);
    expect(rendered().meta, '02 NODES · 01 WIRES');
    expect(rendered().level, KkLevel.caution);

    await tester.enterText(source, 'flow TB\nA --> B --> C');
    await tester.pump();
    expect(find.textContaining('LINE 2'), findsNothing);
    expect(rendered().meta, '03 NODES · 02 WIRES');
    expectClean(tester, 'editor');
  });
}
