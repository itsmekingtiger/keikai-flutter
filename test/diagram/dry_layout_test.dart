import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

const Key _row = ValueKey<String>('row');
const Key _probe = ValueKey<String>('probe');

final KkDiagram _flow = KkDiagram.parse('''
flow LR
IN([INTAKE]) --> F1[SEC-01|FILTER]
F1 --> P1[SEC-02|PUMP A]
F1 --> P2[SEC-03|PUMP B]
P1 --> MIX((CORE|MIXER))
P2 --> MIX
MIX --> OUT([OUTLET])
''');

const List<KkSequenceParticipant> _parties = <KkSequenceParticipant>[
  KkSequenceParticipant('op', code: 'OP-07', cjk: '運用'),
  KkSequenceParticipant('ctl', code: 'CTRL'),
  KkSequenceParticipant('sec', code: 'SEC-04'),
];

const List<KkSequenceEntry> _talk = <KkSequenceEntry>[
  KkSequenceDivider(code: 'PH-01', en: 'request'),
  KkSequenceMessage('op', 'ctl', 'REQUEST CONTROL', note: '14:02:31Z'),
  KkSequenceMessage('ctl', 'sec', 'PING'),
  KkSequenceMessage('sec', 'ctl', 'ACK', kind: KkSequenceMessageKind.reply),
  KkSequenceMessage('ctl', 'ctl', 'VERIFY'),
];

/// A baseline-aligned row of [subject] and a small line of text.
Widget _baselineRow(Widget subject) {
  return KkRow(
    key: _row,
    shrinkWrap: true,
    cross: KkCrossAlign.baseline,
    children: <Widget>[
      subject,
      const KkText.num('00', key: _probe, size: 11),
    ],
  );
}

RenderBox _box(WidgetTester tester, Finder finder) => tester.renderObject<RenderBox>(finder);

RenderKkDiagramViewport _viewport(WidgetTester tester) => tester.renderObject<RenderKkDiagramViewport>(
  find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_KkDiagramViewport'),
);

RenderBox _sequencePlot(WidgetTester tester) =>
    _box(tester, find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_SequencePlot'));

/// Measures the row without laying it out, as a parent that sizes itself from
/// its children does. A child with no dry baseline makes this throw.
void _expectDryRow(WidgetTester tester) {
  final RenderBox row = _box(tester, find.byKey(_row));
  expect(row.getDryLayout(row.constraints), row.size);
}

/// The constraints a diagram may meet: free, bounded, tight both ways, and
/// squeezed to nothing.
const List<BoxConstraints> _cases = <BoxConstraints>[
  BoxConstraints(),
  BoxConstraints(maxWidth: 2000, maxHeight: 2000),
  BoxConstraints(maxWidth: 220),
  BoxConstraints(maxHeight: 60),
  BoxConstraints(maxWidth: 220, maxHeight: 60),
  BoxConstraints(minWidth: 900, minHeight: 500),
  BoxConstraints(minWidth: 900, maxWidth: 900, minHeight: 500, maxHeight: 500),
  BoxConstraints(minWidth: 40, maxWidth: 40, minHeight: 30, maxHeight: 30),
  BoxConstraints(maxWidth: 0, maxHeight: 0),
];

void main() {
  setUpAll(loadKkFonts);

  group('KkDiagramView', () {
    testChecked('stands in a baseline row that is measured dry, and has no baseline of its own', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _baselineRow(KkDiagramView(diagram: _flow)));
      expect(tester.takeException(), isNull);
      _expectDryRow(tester);
      final RenderKkDiagramViewport viewport = _viewport(tester);
      for (final TextBaseline baseline in TextBaseline.values) {
        expect(viewport.getDryBaseline(viewport.constraints, baseline), isNull);
        expect(viewport.getDryBaseline(const BoxConstraints(maxWidth: 120), baseline), isNull);
      }
      // With no baseline it is set at the top of the row, the text beside it.
      expect(tester.getTopLeft(find.byType(KkDiagramView)).dy, tester.getTopLeft(find.byKey(_row)).dy);
      expect(baselineOf(_box(tester, find.byKey(_probe))), isNotNull);
    });

    testChecked('the dry size is the laid-out size under every kind of constraint', (WidgetTester tester) async {
      for (final KkDiagramFit fit in KkDiagramFit.values) {
        await pumpKk(tester, KkDiagramView(diagram: _flow, fit: fit));
        final RenderKkDiagramViewport viewport = _viewport(tester);
        final Size natural = viewport.natural;
        expect(natural.width, greaterThan(220));
        expect(natural.height, greaterThan(60));
        for (final BoxConstraints constraints in _cases) {
          final Size dry = viewport.getDryLayout(constraints);
          // Lay it out for real under the same constraints and compare.
          viewport.layout(constraints, parentUsesSize: true);
          expect(viewport.size, dry, reason: '$fit $constraints');
          expect(constraints.isSatisfiedBy(dry), isTrue, reason: '$fit $constraints');
        }
        // Back to what its parent gave it, so the tree is left as it was.
        await pumpKk(tester, KkDiagramView(diagram: _flow, fit: fit));
        expect(tester.takeException(), isNull);
      }
    });

    testChecked('fits like a picture: never larger than drawn, both sides scaled together', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, KkDiagramView(diagram: _flow));
      final RenderKkDiagramViewport viewport = _viewport(tester);
      final Size natural = viewport.natural;
      expect(viewport.getDryLayout(const BoxConstraints()), natural);
      expect(viewport.getDryLayout(const BoxConstraints(maxWidth: 2000, maxHeight: 2000)), natural);
      final Size half = viewport.getDryLayout(BoxConstraints(maxWidth: natural.width / 2));
      expect(half.width, closeTo(natural.width / 2, 1e-6));
      expect(half.height, closeTo(natural.height / 2, 1e-6));
      final Size low = viewport.getDryLayout(BoxConstraints(maxHeight: natural.height / 4));
      expect(low.width, closeTo(natural.width / 4, 1e-6));
      expect(low.height, closeTo(natural.height / 4, 1e-6));

      // The intrinsic sizes say the same.
      expect(viewport.getMinIntrinsicWidth(double.infinity), 0);
      expect(viewport.getMaxIntrinsicWidth(double.infinity), natural.width);
      expect(viewport.getMaxIntrinsicWidth(natural.height * 3), natural.width);
      expect(viewport.getMaxIntrinsicWidth(natural.height / 4), closeTo(natural.width / 4, 1e-6));
      expect(viewport.getMinIntrinsicHeight(double.infinity), natural.height);
      expect(viewport.getMaxIntrinsicHeight(natural.width / 2), closeTo(natural.height / 2, 1e-6));
      expect(viewport.getMaxIntrinsicHeight(natural.width * 3), natural.height);
    });

    testChecked('at its own scale it keeps its height and is cut off at the side', (WidgetTester tester) async {
      await pumpKk(tester, KkDiagramView(diagram: _flow, fit: KkDiagramFit.none));
      final RenderKkDiagramViewport viewport = _viewport(tester);
      final Size natural = viewport.natural;
      expect(viewport.getDryLayout(BoxConstraints(maxWidth: natural.width / 2)), Size(natural.width / 2, natural.height));
      expect(viewport.getMaxIntrinsicWidth(natural.height / 4), natural.width);
      expect(viewport.getMinIntrinsicHeight(natural.width / 2), natural.height);
    });

    testChecked('an empty diagram measures as nothing', (WidgetTester tester) async {
      await pumpKk(tester, _baselineRow(KkDiagramView(diagram: KkDiagram.empty)));
      expect(tester.takeException(), isNull);
      _expectDryRow(tester);
      final RenderKkDiagramViewport viewport = _viewport(tester);
      expect(viewport.getDryLayout(const BoxConstraints()), viewport.natural);
      expect(viewport.getMaxIntrinsicWidth(40), viewport.natural.width);
      expect(viewport.getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic), isNull);
    });

    testChecked('pan, zoom and selection leave the measured size alone', (WidgetTester tester) async {
      final KkDiagramController controller = KkDiagramController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkBox(
          width: 400,
          height: 240,
          child: KkDiagramView(diagram: _flow, interactive: true, controller: controller, selected: 'MIX'),
        ),
      );
      final RenderKkDiagramViewport viewport = _viewport(tester);
      final Size before = viewport.size;
      controller.zoomBy(2);
      controller.panBy(const Offset(30, -12));
      await tester.pump();
      expect(viewport.size, before);
      expect(viewport.getDryLayout(viewport.constraints), before);
      expect(tester.takeException(), isNull);
    });
  });

  group('KkNodeGraph', () {
    testChecked('framed, in a baseline row, measured dry', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _baselineRow(KkNodeGraph(diagram: _flow, cjk: '電源系統', en: 'power grid', layout: const KkForceLayout())),
        size: const Size(1400, 900),
      );
      expect(tester.takeException(), isNull);
      _expectDryRow(tester);
      final RenderBox graph = _box(tester, find.byType(KkNodeGraph));
      expect(graph.getDryLayout(graph.constraints), graph.size);
    });

    testChecked('with a set height and when told to fill', (WidgetTester tester) async {
      await pumpKk(tester, KkBox(width: 520, child: KkNodeGraph(diagram: _flow, height: 180)));
      expect(tester.takeException(), isNull);
      RenderBox graph = _box(tester, find.byType(KkNodeGraph));
      expect(graph.getDryLayout(graph.constraints), graph.size);
      await pumpKk(tester, KkBox(width: 520, height: 300, child: KkNodeGraph(diagram: _flow, expand: true)));
      expect(tester.takeException(), isNull);
      graph = _box(tester, find.byType(KkNodeGraph));
      expect(graph.getDryLayout(graph.constraints), graph.size);
    });
  });

  group('KkSequenceDiagram', () {
    testChecked('stands in a baseline row that is measured dry, framed or bare', (WidgetTester tester) async {
      for (final bool framed in <bool>[true, false]) {
        await pumpKk(
          tester,
          _baselineRow(KkSequenceDiagram(participants: _parties, entries: _talk, framed: framed, en: 'handover')),
          size: const Size(1400, 900),
        );
        expect(tester.takeException(), isNull, reason: 'framed $framed');
        _expectDryRow(tester);
        final RenderBox plot = _sequencePlot(tester);
        for (final TextBaseline baseline in TextBaseline.values) {
          expect(plot.getDryBaseline(plot.constraints, baseline), isNull);
        }
      }
    });

    testChecked('the dry size is the laid-out size: free, stretched and shrunk', (WidgetTester tester) async {
      const KkSequenceDiagram diagram = KkSequenceDiagram(participants: _parties, entries: _talk, framed: false);
      final double natural = kkSequenceNaturalWidth(diagram);
      await pumpKk(tester, diagram, size: const Size(2400, 1200));
      final RenderBox plot = _sequencePlot(tester);
      final double height = plot.getDryLayout(const BoxConstraints()).height;
      expect(plot.getDryLayout(const BoxConstraints()).width, closeTo(natural, 0.01));
      for (final BoxConstraints constraints in <BoxConstraints>[
        const BoxConstraints(),
        BoxConstraints(maxWidth: natural + 240),
        BoxConstraints(maxWidth: natural / 2),
        BoxConstraints(maxWidth: natural / 2, maxHeight: 40),
        BoxConstraints(minWidth: natural + 100, maxWidth: natural + 100, minHeight: 700, maxHeight: 700),
        const BoxConstraints(maxWidth: 0),
      ]) {
        final Size dry = plot.getDryLayout(constraints);
        plot.layout(constraints, parentUsesSize: true);
        expect(plot.size, dry, reason: '$constraints');
        expect(constraints.isSatisfiedBy(dry), isTrue, reason: '$constraints');
      }
      // More room spreads the lifelines at the same height; less shrinks the whole drawing.
      expect(plot.getDryLayout(BoxConstraints(maxWidth: natural + 240)), Size(natural + 240, height));
      final Size half = plot.getDryLayout(BoxConstraints(maxWidth: natural / 2));
      expect(half.width, closeTo(natural / 2, 0.01));
      expect(half.height, closeTo(height / 2, 0.01));
      expect(plot.getMinIntrinsicWidth(double.infinity), 0);
      expect(plot.getMaxIntrinsicWidth(double.infinity), closeTo(natural, 0.01));
      expect(plot.getMaxIntrinsicHeight(double.infinity), closeTo(height, 0.01));
      expect(plot.getMaxIntrinsicHeight(natural / 2), closeTo(height / 2, 0.01));
      await pumpKk(tester, diagram, size: const Size(2400, 1200));
      expect(tester.takeException(), isNull);
    });

    testChecked('a new set of messages is measured and drawn anew', (WidgetTester tester) async {
      await pumpKk(tester, const KkSequenceDiagram(participants: _parties, entries: _talk, framed: false));
      final double before = tester.getSize(find.byType(KkSequenceDiagram)).height;
      await pumpKk(
        tester,
        const KkSequenceDiagram(
          participants: _parties,
          entries: <KkSequenceEntry>[..._talk, KkSequenceMessage('ctl', 'op', 'GRANT', kind: KkSequenceMessageKind.reply)],
          framed: false,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkSequenceDiagram)).height, greaterThan(before));
      // Under motion the box repaints as the entrance runs, and stops with it.
      await pumpKk(
        tester,
        const KkSequenceDiagram(participants: _parties, entries: _talk, framed: false),
        motion: true,
      );
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
