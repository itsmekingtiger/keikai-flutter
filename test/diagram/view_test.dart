import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'layout_test.dart' show pipeline, randomDiagram;

Finder node(String id) => find.byKey(ValueKey<String>('kk-diagram-node-$id'));

final KkDiagram small = KkDiagram.parse('''
flow LR
A[SEC-01|PUMP] ==> B((HX-01|CORE)):::caution
B --> C{CHECK}
C -->|OK| D([DONE]):::nominal
C -.-> E>DRAIN]:::offline
B ==> F[SEC-09|ALARM]:::critical
''');

void main() {
  setUpAll(loadKkFonts);

  group('KkDiagramView', () {
    testWidgets('draws in both themes without complaint', (WidgetTester tester) async {
      for (final KkCondition condition in KkCondition.values) {
        await pumpKk(tester, KkDiagramView(diagram: pipeline), condition: condition);
        expect(tester.takeException(), isNull);
        expect(find.byType(KkDiagramView), findsOneWidget);
        for (final KkDiagramNode n in pipeline.nodes) {
          expect(node(n.id), findsOneWidget);
        }
      }
    });

    testWidgets('takes its natural size when it can', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small, padding: const EdgeInsets.all(10)));
      final KkDiagramGeometry g = const KkLayeredLayout().compute(small);
      expect(tester.getSize(find.byType(KkDiagramView)), Size(g.size.width + 20, g.size.height + 20));
    });

    testWidgets('shrinks to fit a smaller box and never grows', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(width: 160, height: 90, child: KkDiagramView(diagram: small)),
      );
      expect(tester.takeException(), isNull);
      final Size size = tester.getSize(find.byType(KkDiagramView));
      expect(size.width, lessThanOrEqualTo(160));
      expect(size.height, lessThanOrEqualTo(90));
      // The node boxes are scaled with the picture, so taps still land.
      expect(tester.getSize(node('A')).width, greaterThan(0));
      final Rect a = tester.getRect(node('A'));
      expect(const Rect.fromLTWH(0, 0, 160, 90).contains(a.center), isTrue);

      await pumpKk(
        tester,
        KkBox(width: 2000, height: 1200, child: KkDiagramView(diagram: small, padding: EdgeInsets.zero)),
        size: const Size(2000, 1200),
      );
      final KkDiagramGeometry g = const KkLayeredLayout().compute(small);
      expect(tester.getSize(node('A')), g.nodes['A']!.bounds.size);
    });

    testWidgets('fit none keeps the natural scale and clips', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(width: 120, height: 80, child: KkDiagramView(diagram: small, fit: KkDiagramFit.none, padding: EdgeInsets.zero)),
      );
      expect(tester.takeException(), isNull);
      final KkDiagramGeometry g = const KkLayeredLayout().compute(small);
      expect(tester.getSize(find.byType(KkDiagramView)), const Size(120, 80));
      expect(tester.getSize(node('A')), g.nodes['A']!.bounds.size);
    });

    testWidgets('a tap selects the node under it and calls back', (WidgetTester tester) async {
      final List<String?> selections = <String?>[];
      final List<String> taps = <String>[];
      await pumpKk(
        tester,
        KkDiagramView(
          diagram: small,
          onSelected: selections.add,
          onNodeTap: (KkDiagramNode n) => taps.add(n.id),
        ),
      );
      await tester.tap(node('C'));
      await tester.pump();
      expect(selections, <String?>['C']);
      expect(taps, <String>['C']);
      expect(tester.widget<KkPressable>(node('C')).selected, isTrue);
      expect(tester.widget<KkPressable>(node('B')).selected, isFalse);

      await tester.tap(node('F'));
      await tester.pump();
      expect(selections, <String?>['C', 'F']);
      expect(tester.widget<KkPressable>(node('C')).selected, isFalse);

      // Tapping the selected node again clears the selection.
      await tester.tap(node('F'));
      await tester.pump();
      expect(selections, <String?>['C', 'F', null]);
      expect(taps, <String>['C', 'F', 'F']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection can be driven from outside and switched off', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small, selected: 'A'));
      expect(tester.widget<KkPressable>(node('A')).selected, isTrue);
      await pumpKk(tester, KkDiagramView(diagram: small, selected: 'B'));
      expect(tester.widget<KkPressable>(node('A')).selected, isFalse);
      expect(tester.widget<KkPressable>(node('B')).selected, isTrue);
      await pumpKk(tester, KkDiagramView(diagram: small));
      expect(tester.widget<KkPressable>(node('B')).selected, isFalse);

      int taps = 0;
      String? picked = 'unset';
      await pumpKk(
        tester,
        KkDiagramView(
          diagram: small,
          selectable: false,
          onNodeTap: (KkDiagramNode n) => taps++,
          onSelected: (String? id) => picked = id,
        ),
      );
      await tester.tap(node('A'));
      await tester.pump();
      expect(taps, 1);
      expect(picked, 'unset');
      expect(tester.widget<KkPressable>(node('A')).selected, isFalse);
    });

    testWidgets('a selection that names a node that has gone is dropped', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small, selected: 'F'));
      await pumpKk(tester, KkDiagramView(diagram: KkDiagram.parse('A --> B'), selected: 'F'));
      expect(tester.takeException(), isNull);
      expect(node('F'), findsNothing);
      expect(node('A'), findsOneWidget);
      // Old focus nodes are released after the frame.
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab reaches a node, Enter selects it, arrows move between nodes', (WidgetTester tester) async {
      final List<String?> selections = <String?>[];
      await pumpKk(
        tester,
        KkDiagramView(diagram: KkDiagram.parse('flow LR\nA --> B --> C'), onSelected: selections.add),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selections, <String?>['A']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selections, <String?>['A', 'B']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selections, <String?>['A', 'B', 'A']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selections.last, 'B');
      expect(tester.takeException(), isNull);
    });

    testWidgets('hovering a node is harmless and leaves when the pointer does', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small));
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(790, 590));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(node('B')));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(node('C')));
      await tester.pump();
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('every node is announced with its code, label and status', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkDiagramView(diagram: small));
      expect(find.bySemanticsLabel('SEC-01, PUMP'), findsOneWidget);
      expect(find.bySemanticsLabel('HX-01, CORE, CAUTION'), findsOneWidget);
      expect(find.bySemanticsLabel('SEC-09, ALARM, CRITICAL'), findsOneWidget);
      expect(find.bySemanticsLabel('Diagram, 6 nodes, 5 wires'), findsOneWidget);
      await pumpKk(tester, KkDiagramView(diagram: small, semanticLabel: 'Coolant loop'));
      expect(find.bySemanticsLabel('Coolant loop'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('edge cases: nothing, one node, long text, tiny boxes, big diagrams', (WidgetTester tester) async {
      final List<Widget> cases = <Widget>[
        KkDiagramView(diagram: KkDiagram.empty),
        KkDiagramView(diagram: KkDiagram(nodes: const <KkDiagramNode>[KkDiagramNode('ONLY')])),
        KkDiagramView(
          diagram: KkDiagram(
            nodes: const <KkDiagramNode>[
              KkDiagramNode('A', code: 'A-CODE-THAT-IS-FAR-TOO-LONG-FOR-ANY-REASONABLE-SYMBOL-0123456789', label: 'AND A LABEL JUST AS LONG AS THAT'),
              KkDiagramNode('B', cjk: '冷却系統異常警報'),
            ],
            edges: const <KkDiagramEdge>[KkDiagramEdge('A', 'B', label: 'A LABEL LONGER THAN THE WIRE IT SITS ON, BY FAR')],
          ),
        ),
        KkBox(width: 6, height: 4, child: KkDiagramView(diagram: small)),
        KkBox(width: 0, height: 0, child: KkDiagramView(diagram: small)),
        KkDiagramView(diagram: KkDiagram.parse('A --> A')),
        KkDiagramView(diagram: randomDiagram(120, extra: 60, cyclic: true), layout: const KkForceLayout(iterations: 40)),
        KkDiagramView(diagram: small, metrics: const KkNodeMetrics(showText: false)),
        KkDiagramView(diagram: small, arrows: false, showInfo: false, selected: 'B', ground: const Color(0x00000000)),
      ];
      for (final Widget w in cases) {
        await pumpKk(tester, w);
        expect(tester.takeException(), isNull, reason: '$w');
      }
    });

    testWidgets('the layout, router, metrics and info lines can be swapped', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small, layout: const KkTreeLayout(), router: const KkEdgeRouter.straight()));
      final Offset tree = tester.getCenter(node('F'));
      await pumpKk(tester, KkDiagramView(diagram: small, layout: const KkRadialLayout(root: 'B')));
      expect(tester.getCenter(node('F')), isNot(tree));
      await pumpKk(
        tester,
        KkDiagramView(
          diagram: small,
          metrics: KkNodeMetrics(sizeOf: (KkDiagramNode n) => n.id == 'B' ? const Size(64, 72) : null),
          selected: 'B',
          infoBuilder: (KkDiagramNode n) => <String>['LINE ONE', 'LINE TWO'],
        ),
      );
      expect(tester.takeException(), isNull);
      // The hooked symbol is bigger than its neighbours.
      expect(tester.getSize(node('B')).height, greaterThan(tester.getSize(node('A')).height));
    });

    testWidgets('the type scale of the theme enlarges the text', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small));
      final double normal = tester.getSize(node('A')).width;
      await pumpKk(
        tester,
        KkDiagramView(diagram: small),
        theme: const KeikaiThemeData(type: KkTypography(scale: 1.25)),
      );
      expect(tester.getSize(node('A')).width, greaterThan(normal));
      expect(tester.takeException(), isNull);
    });
  });

  group('entrance and motion', () {
    testWidgets('nodes pop in, then wires are drawn, then it rests', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small), motion: true);
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
      // Flow marks and the alarm halo keep running.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      // Nodes can be tapped straight away, mid-entrance too.
      final List<String?> picked = <String?>[];
      await pumpKk(tester, KkDiagramView(diagram: small, onSelected: picked.add), motion: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(node('A'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(picked, <String?>['A']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('with animate off or motion off the final picture is there at once', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: small, animate: false), motion: true);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, KkDiagramView(diagram: small));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('entrance timing', () {
      const KkDiagramEntrance e = KkDiagramEntrance(nodes: 3, wires: 2);
      // 200 lead + 2 x 22 + 320 for nodes; wires start half a node after the
      // last node begins, 90ms apart, 800ms each.
      expect(e.total, const Duration(milliseconds: 200 + 44 + 160 + 90 + 800));
      final double ms = e.total.inMilliseconds.toDouble();
      expect(e.node(0, 0), 0);
      expect(e.node(0, 200 / ms), 0);
      expect(e.node(0, 360 / ms), closeTo(0.5, 0.01));
      expect(e.node(1, 360 / ms), closeTo((160 - 22) / 320, 0.01));
      expect(e.node(2, 1), 1);
      expect(e.wire(0, 404 / ms), closeTo(0, 0.01));
      expect(e.wire(0, 804 / ms), closeTo(0.5, 0.01));
      expect(e.wire(1, 804 / ms), closeTo(310 / 800, 0.01));
      expect(e.wire(1, 1), 1);
      // A big diagram does not take for ever.
      expect(const KkDiagramEntrance(nodes: 500, wires: 900).total, lessThan(const Duration(seconds: 3)));
      expect(const KkDiagramEntrance(nodes: 0, wires: 0).total, const Duration(milliseconds: 520));
    });
  });

  group('pan and zoom', () {
    test('the controller keeps zoom and pan inside their limits', () {
      final KkDiagramController c = KkDiagramController(minZoom: 0.5, maxZoom: 3);
      addTearDown(c.dispose);
      int notified = 0;
      c.addListener(() => notified++);
      c.attach(view: const Size(400, 300), content: const Size(200, 100), fit: 1, alignment: Alignment.center);
      expect(c.scale, 1);
      expect(c.isReset, isTrue);
      expect(c.toView(Offset.zero), const Offset(100, 100));
      expect(c.toScene(const Offset(100, 100)), Offset.zero);
      expect(c.visible, const Rect.fromLTRB(-100, -100, 300, 200));

      c.zoomTo(10);
      expect(c.zoom, 3);
      c.zoomTo(0.01);
      expect(c.zoom, 0.5);
      c.reset();
      expect(c.isReset, isTrue);

      // Zooming about a point keeps the diagram point under it in place.
      const Offset focal = Offset(250, 120);
      final Offset before = c.toScene(focal);
      c.zoomBy(2, focal: focal);
      expect(c.zoom, 2);
      expect((c.toScene(focal) - before).distance, lessThan(0.001));

      // The diagram cannot be dragged out of sight.
      c.reset();
      c.panBy(const Offset(100000, 100000));
      final Rect content = Rect.fromPoints(c.toView(Offset.zero), c.toView(const Offset(200, 100)));
      expect(content.overlaps(const Rect.fromLTWH(0, 0, 400, 300)), isTrue);
      c.panBy(const Offset(-200000, -200000));
      final Rect other = Rect.fromPoints(c.toView(Offset.zero), c.toView(const Offset(200, 100)));
      expect(other.overlaps(const Rect.fromLTWH(0, 0, 400, 300)), isTrue);

      final int count = notified;
      c.reset();
      c.reset();
      c.zoomTo(1);
      c.panBy(Offset.zero);
      expect(notified, count + 1);
    });

    testWidgets('dragging pans, the wheel zooms, both stop at the limits', (WidgetTester tester) async {
      final KkDiagramController c = KkDiagramController(minZoom: 0.5, maxZoom: 2);
      addTearDown(c.dispose);
      await pumpKk(
        tester,
        KkBox(width: 600, height: 400, child: KkDiagramView(diagram: small, interactive: true, controller: c)),
      );
      final Offset centre = tester.getCenter(find.byType(KkDiagramView));
      await tester.dragFrom(const Offset(20, 380), const Offset(60, -30));
      await tester.pump();
      expect(c.pan.dx, greaterThan(0));
      expect(c.pan.dx, lessThanOrEqualTo(60));
      expect(c.pan.dy, lessThan(0));

      final TestPointer wheel = TestPointer(7, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(centre));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -100)));
      await tester.pump();
      expect(c.zoom, closeTo(1.1, 0.0001));
      for (int i = 0; i < 30; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, -100)));
      }
      await tester.pump();
      expect(c.zoom, 2);
      for (int i = 0; i < 60; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 100)));
      }
      await tester.pump();
      expect(c.zoom, 0.5);

      // Nodes still take taps where they are drawn.
      final List<String?> picked = <String?>[];
      await pumpKk(
        tester,
        KkBox(
          width: 600,
          height: 400,
          child: KkDiagramView(diagram: small, interactive: true, controller: c, onSelected: picked.add),
        ),
      );
      await tester.tap(node('B'));
      await tester.pump();
      expect(picked, <String?>['B']);

      c.reset();
      await tester.pump();
      expect(c.isReset, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keys zoom and reset an interactive view', (WidgetTester tester) async {
      final KkDiagramController c = KkDiagramController();
      addTearDown(c.dispose);
      await pumpKk(
        tester,
        KkBox(width: 600, height: 400, child: KkDiagramView(diagram: small, interactive: true, controller: c)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(c.zoom, 1.25);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      expect(c.zoom, closeTo(0.8, 0.0001));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(c.isReset, isTrue);
    });

    testWidgets('a view that is not interactive ignores drags and the wheel', (WidgetTester tester) async {
      final KkDiagramController c = KkDiagramController();
      addTearDown(c.dispose);
      await pumpKk(tester, KkBox(width: 600, height: 400, child: KkDiagramView(diagram: small, controller: c)));
      await tester.dragFrom(const Offset(20, 380), const Offset(60, -30));
      final TestPointer wheel = TestPointer(8, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(const Offset(300, 200)));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -100)));
      await tester.pump();
      expect(c.isReset, isTrue);
    });
  });

  group('KkDiagramPainter', () {
    KkDiagramPainter painterFor(KkDiagram d, {String? selected, String? hovered, String? focused}) => KkDiagramPainter(
      geometry: const KkLayeredLayout().compute(d),
      colors: KkColors.standby,
      type: const KkTypography(),
      selected: selected,
      hovered: hovered,
      focused: focused,
    );

    test('paints every layer onto any canvas', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final KkDiagramPainter p = painterFor(small, selected: 'F', hovered: 'B', focused: 'C');
      p.paint(canvas, time: const Duration(milliseconds: 700), scale: 1.5);
      p.paintWires(canvas, progress: (int i) => i / 5);
      p.paintLabels(canvas, progress: (int i) => 1);
      p.paintFlow(canvas, const Duration(seconds: 3), progress: (int i) => 1);
      p.paintNodes(canvas, progress: (int i) => i / 6);
      p.paintHalos(canvas, const Duration(milliseconds: 900));
      p.paintSelection(canvas, info: const <String>[], view: const Rect.fromLTWH(0, 0, 10, 10));
      p.paintSelection(canvas, plate: false);
      recorder.endRecording().dispose();
    });

    test('knows whether anything moves', () {
      expect(painterFor(small).moves, isTrue);
      expect(painterFor(KkDiagram.parse('A --> B')).moves, isFalse);
      expect(painterFor(KkDiagram.parse('A:::critical')).moves, isTrue);
      expect(painterFor(KkDiagram.parse('A -->:::flow B')).moves, isTrue);
    });

    test('default info lines: label, status, wire counts', () {
      final KkDiagramPainter p = painterFor(small);
      expect(p.defaultInfo(small.nodeById('B')!), <String>['CORE', 'CAUTION 注意', 'IN 01 · OUT 02']);
      expect(p.defaultInfo(small.nodeById('E')!), <String>['OFFLINE 断線', 'IN 01 · OUT 00']);
    });

    test('the info plate keeps off the text of its own node, whichever side the text is on', () {
      final KkDiagram d = KkDiagram.parse('''
GA((GRID-A|MAIN BUS)) --> GB((GRID-B|AUX BUS))
S1[SEC-01|REACTOR] --> GA
GA --> S3[SEC-03|COOLANT]
GA --> S4[SEC-04|PUMP HALL WITH A LONG NAME|冷却]
GB --> S5[SEC-05|BATTERY]
GB --> L1>L-71|FEEDER]
GB --> T([OUT])
S4 --> GB
''');
      bool crosses(Offset a, Offset b, Rect r) {
        for (double t = 0; t <= 1; t += 0.01) {
          if (r.contains(Offset.lerp(a, b, t)!)) return true;
        }
        return false;
      }

      final Map<String, KkDiagramLayout> layouts = <String, KkDiagramLayout>{
        'text below, flow': const KkLayeredLayout(),
        'text right, flow': const KkLayeredLayout(direction: KkDiagramDirection.topToBottom),
        'text below, network': const KkForceLayout(aspect: 1.7),
        'text below, rings': const KkRadialLayout(),
      };
      for (final MapEntry<String, KkDiagramLayout> layout in layouts.entries) {
        final KkDiagramGeometry g = layout.value.compute(d);
        final KkDiagramPainter p = KkDiagramPainter(geometry: g, colors: KkColors.standby, type: const KkTypography());
        for (final KkDiagramNode n in d.nodes) {
          final KkNodePlacement place = g.nodes[n.id]!;
          for (final Size size in const <Size>[Size(40, 20), Size(136, 70), Size(260, 120)]) {
            // Seen whole, seen through a small window, and seen with no room at all.
            for (final Rect? view in <Rect?>[
              null,
              Rect.fromCenter(center: place.shape.center, width: 2000, height: 2000),
              Rect.fromLTWH(place.shape.left - 8, place.shape.top - 8, 300, 200),
              Rect.fromLTWH(place.shape.left - 290, place.shape.top - 190, 320, 220),
              place.shape,
            ]) {
              final String why = '${layout.key}: ${n.id} $size in $view';
              final (Rect box, List<Offset> leader) = p.infoPlate(n.id, size, view: view);
              expect(box.size, size, reason: why);
              expect(box.overlaps(place.shape), isFalse, reason: why);
              final Rect? text = place.text;
              if (text != null) expect(box.overlaps(text), isFalse, reason: '$why covers its text $text with $box');
              expect(leader.length, greaterThanOrEqualTo(2), reason: why);
              expect(box.inflate(0.01).contains(leader.last), isTrue, reason: '$why leader ends off the plate');
              for (int i = 1; i < leader.length; i++) {
                final Offset leg = leader[i] - leader[i - 1];
                expect(
                  leg.dx.abs() < 0.01 || leg.dy.abs() < 0.01 || (leg.dx.abs() - leg.dy.abs()).abs() < 0.01,
                  isTrue,
                  reason: '$why leader leg $leg',
                );
                if (text != null) {
                  expect(crosses(leader[i - 1], leader[i], text.deflate(1)), isFalse, reason: '$why leader through its text');
                }
              }
            }
          }
        }
      }
    });

    test('the info plate goes up and to the right, or to the side where it can be seen', () {
      final KkDiagramGeometry g = const KkLayeredLayout().compute(KkDiagram.parse('A[SEC-01|PUMP]'));
      final KkDiagramPainter p = KkDiagramPainter(geometry: g, colors: KkColors.standby, type: const KkTypography());
      final Rect shape = g.nodes['A']!.shape;
      final Rect text = g.nodes['A']!.text!;
      const Size size = Size(120, 60);
      const double far = 2000;

      // Room everywhere.
      Rect box = p.infoPlate('A', size, view: Rect.fromCenter(center: shape.center, width: far, height: far)).$1;
      expect(box.left, shape.right + 16);
      expect(box.bottom, shape.top - 12);

      // No room above the symbol, but enough beside it.
      box = p.infoPlate('A', size, view: Rect.fromLTRB(-far, shape.center.dy - size.height / 2 - 4, far, far)).$1;
      expect(box.center.dy, closeTo(shape.center.dy, 0.5));
      expect(box.left, greaterThanOrEqualTo(shape.right + 16));
      expect(box.left, greaterThanOrEqualTo(text.right + 16));

      // Nothing to see to the right: on the left.
      box = p.infoPlate('A', size, view: Rect.fromLTRB(-far, -far, shape.right + 8, far)).$1;
      expect(box.right, shape.left - 16);
      expect(box.bottom, shape.top - 12);

      // Only below: under the text, never on it.
      final (Rect below, List<Offset> leader) = p.infoPlate(
        'A',
        size,
        view: Rect.fromLTRB(shape.left - 4, shape.bottom + 2, far, far),
      );
      expect(below.top, text.bottom + 12);
      expect(below.left, greaterThanOrEqualTo(text.right));
      expect(leader.first.dy, text.bottom);

      // A node that is not in the diagram has no plate.
      expect(p.infoPlate('NOPE', size), (Rect.zero, const <Offset>[]));
    });

    test('value equality drives repaints', () {
      final KkDiagramGeometry g = const KkLayeredLayout().compute(small);
      KkDiagramPainter make({String? hovered}) =>
          KkDiagramPainter(geometry: g, colors: KkColors.standby, type: const KkTypography(), hovered: hovered);
      expect(make(), make());
      expect(make(), isNot(make(hovered: 'A')));
      expect(make().hashCode, make().hashCode);
    });

    test('wire labels sit on their own wire and off the nodes', () {
      final KkDiagram d = KkDiagram.parse('flow LR\nC{CHECK} -->|YES| A[SEC-01]\nC -->|NO| B[SEC-02]\nC -->|MAYBE| D[SEC-03]');
      final KkDiagramGeometry g = const KkLayeredLayout().compute(d);
      final List<Rect> boxes = <Rect>[];
      for (int i = 0; i < d.edges.length; i++) {
        final Size s = KkDiagramGeometry.labelSize(d.edges[i].label!);
        final Rect box = Rect.fromCenter(center: g.labelAnchor(i), width: s.width, height: s.height);
        for (final KkNodePlacement n in g.nodes.values) {
          expect(box.overlaps(n.bounds), isFalse, reason: 'label ${d.edges[i].label} on a node');
        }
        for (final Rect other in boxes) {
          expect(box.overlaps(other), isFalse, reason: 'label ${d.edges[i].label} on another label');
        }
        boxes.add(box);
      }
      expect(g.labelAnchor(99), Offset.zero);
    });

    testWidgets('legend symbols draw', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          gap: 8,
          shrinkWrap: true,
          children: <Widget>[
            for (final KkNodeKind kind in KkNodeKind.values) KkNodeSymbol(kind: kind, level: KkLevel.critical),
            const KkNodeSymbol(kind: KkNodeKind.terminal, size: 20),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkNodeSymbol).first), const Size(12, 12));
      expect(tester.getSize(find.byType(KkNodeSymbol).last), const Size(40, 20));
    });
  });

  group('states, drawn', () {
    testWidgets('hover, keyboard focus and selection', (WidgetTester tester) async {
      final KkDiagram d = KkDiagram.parse('''
flow LR
A[SEC-01|PUMP A] ==> B((HX-01|CORE))
B --> C[SEC-02|HOVERED]
B --> D[SEC-03|FOCUSED]
B ==> E[SEC-04|SELECTED]:::caution
C --> F>DRAIN]
''');
      await pumpKk(
        tester,
        KkBackdrop(
          kind: KkBackdropKind.none,
          padding: const EdgeInsets.all(16),
          child: KkWidgetFrame(
            cjk: '状態',
            en: 'hover · focus · selected',
            child: KkDiagramView(diagram: d, selected: 'E', padding: const EdgeInsets.all(32)),
          ),
        ),
        size: const Size(560, 360),
        pixelRatio: 2,
      );
      // Tab to D: A, B, C, D in reading order is not guaranteed, so walk until it is focused.
      final FocusNode target = tester.widget<KkPressable>(node('D')).focusNode!;
      for (int i = 0; i < 8 && !target.hasPrimaryFocus; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(target.hasPrimaryFocus, isTrue);
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(555, 355));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(node('C')));
      await tester.pump();
      await expectKkGolden(tester, 'diagram_states');
    });

    testWidgets('halfway through the entrance', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBackdrop(
          kind: KkBackdropKind.none,
          padding: const EdgeInsets.all(16),
          child: KkDiagramView(diagram: small, padding: const EdgeInsets.all(24)),
        ),
        size: const Size(520, 260),
        pixelRatio: 2,
        motion: true,
      );
      await tester.pump(const Duration(milliseconds: 420));
      await tester.pump(const Duration(milliseconds: 420));
      await expectKkGolden(tester, 'diagram_entrance');
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
