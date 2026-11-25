import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkSequenceStep> _steps = <KkSequenceStep>[
  KkSequenceStep(cjk: '電源投入', en: 'power on', note: 'MAIN BUS 440.2 V', status: KkStepStatus.done, time: '14:00:02Z'),
  KkSequenceStep(cjk: '自己診断', en: 'self test', status: KkStepStatus.done),
  KkSequenceStep(cjk: '冷却循環', en: 'coolant loop', note: 'FLOW 118.0 L/min', status: KkStepStatus.active),
  KkSequenceStep(cjk: '外部同期', en: 'external sync', note: 'N-07 NO CARRIER', status: KkStepStatus.failed),
  KkSequenceStep(cjk: '負荷試験', en: 'load test', status: KkStepStatus.skipped),
  KkSequenceStep(cjk: '定常運転', en: 'steady run'),
];

/// The fill of the row of the step titled [en] (null when the row has none).
Color? _rowFill(WidgetTester tester, String en) {
  final Iterable<KkBox> boxes = tester.widgetList<KkBox>(
    find.ancestor(of: find.text(en), matching: find.byType(KkBox)),
  );
  // The row is the box that directly holds the rail painter.
  return boxes.firstWhere((KkBox b) => b.child is CustomPaint).fill;
}

TextStyle _style(WidgetTester tester, String text) => tester.widget<Text>(find.text(text).first).style!;

void main() {
  setUpAll(loadKkFonts);

  test('status words and the done count', () {
    expect(KkStepStatus.values.map((KkStepStatus s) => s.word), <String>['DONE', 'ACTIVE', 'PENDING', 'FAILED', 'SKIPPED']);
    expect(KkSequence.doneCount(_steps), 2);
    expect(KkSequence.doneCount(const <KkSequenceStep>[]), 0);
  });

  testWidgets('head counts the finished steps; rows are 40px at least', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 520, child: KkSequence(cjk: '起動手順', en: 'start-up', steps: _steps)));
    expect(find.text('02 / 06'), findsOneWidget);
    expect(find.text('起動手順'), findsOneWidget);
    for (int i = 1; i <= 6; i++) {
      expect(find.text('0$i'), findsOneWidget);
    }
    expect(find.text('DONE'), findsNWidgets(2));
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('SKIPPED'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    // A row without a note is exactly the 40px minimum.
    expect(tester.getSize(find.bySemanticsLabel(RegExp('^02 '))).height, 40);
    // A row with a note is taller: 6 + title line + 3 + note line + 6.
    expect(tester.getSize(find.bySemanticsLabel(RegExp('^03 '))).height, inInclusiveRange(50.0, 53.0));
    // The title of a 40px row is centred in it.
    expect(
      tester.getCenter(find.text('SELF TEST')).dy,
      closeTo(tester.getCenter(find.bySemanticsLabel(RegExp('^02 '))).dy, 3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('each status has its own look', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 520, child: KkSequence(steps: _steps)));
    const KkColors c = KkColors.standby;
    // Row grounds.
    expect(_rowFill(tester, 'POWER ON'), isNull, reason: 'done rows sit on the panel ground');
    expect(_rowFill(tester, 'COOLANT LOOP'), c.bg200);
    expect(_rowFill(tester, 'EXTERNAL SYNC'), c.alertDeep);
    // Title ink.
    expect(_style(tester, '電源投入').color, c.ink);
    expect(_style(tester, 'POWER ON').color, c.inkDim);
    expect(_style(tester, 'COOLANT LOOP').color, c.ink);
    expect(_style(tester, 'EXTERNAL SYNC').color, c.ink);
    expect(_style(tester, '定常運転').color, c.inkDim);
    expect(_style(tester, '負荷試験').color, c.inkDim);
    // Skipped titles are struck through, others are not.
    expect(_style(tester, '負荷試験').decoration, TextDecoration.lineThrough);
    expect(_style(tester, 'LOAD TEST').decoration, TextDecoration.lineThrough);
    expect(_style(tester, '定常運転').decoration, TextDecoration.none);
    // Index and state ink.
    expect(_style(tester, '03').color, c.signal);
    expect(_style(tester, 'ACTIVE').color, c.signal);
    expect(_style(tester, '04').color, c.ink);
    expect(_style(tester, '01').color, c.inkFaint);
    expect(_style(tester, 'DONE').color, c.inkDim);
    // Marks: two checks for the done steps, the critical plate for the failed one.
    expect(
      tester.widgetList<KkIcon>(find.byType(KkIcon)).map((KkIcon i) => i.icon).toList(),
      <KkIconData>[KkIcons.check, KkIcons.check, KkIcons.statusCritical],
    );
    expect(find.byType(KkBlink), findsOneWidget, reason: 'only the active mark blinks');
  });

  testWidgets('progress follows the done share unless given; the level colours the bar', (WidgetTester tester) async {
    CustomPainter bar() => tester
        .widget<CustomPaint>(
          find.descendant(of: find.byType(KkSequence), matching: find.byType(CustomPaint)).first,
        )
        .painter!;
    await pumpKk(tester, const KkBox(width: 520, child: KkSequence(steps: _steps)));
    // ignore: avoid_dynamic_calls
    expect((bar() as dynamic).value, closeTo(2 / 6, 1e-9));
    // ignore: avoid_dynamic_calls
    expect((bar() as dynamic).fill, KkColors.standby.signal);

    await pumpKk(
      tester,
      const KkBox(
        width: 520,
        child: KkSequence(steps: _steps, progress: 0.9, count: 'STEP 03', level: KkLevel.caution),
      ),
    );
    // ignore: avoid_dynamic_calls
    expect((bar() as dynamic).value, 0.9);
    // ignore: avoid_dynamic_calls
    expect((bar() as dynamic).fill, KkColors.standby.caution);
    expect(find.text('STEP 03'), findsOneWidget);
    // The bar is 4px high with 12px margins.
    final Rect bar2 = tester.getRect(
      find.descendant(of: find.byType(KkSequence), matching: find.byType(CustomPaint)).first,
    );
    final Rect seq = tester.getRect(find.byType(KkSequence));
    expect(bar2.height, 4);
    expect(bar2.left - seq.left, 13);
    expect(seq.right - bar2.right, 13);
  });

  testWidgets('steps can be pressed, with the pointer and from the keyboard', (WidgetTester tester) async {
    final List<int> taps = <int>[];
    await pumpKk(tester, KkBox(width: 520, child: KkSequence(steps: _steps, onStepTap: taps.add)));
    await tester.tap(find.text('EXTERNAL SYNC'));
    expect(taps, <int>[3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, <int>[3, 1]);
  });

  testWidgets('fills a fixed height and scrolls its steps', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 520, height: 160, child: KkSequence(cjk: '手順', steps: _steps)));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkSequence)), const Size(520, 160));
    final double before = tester.getCenter(find.text('POWER ON')).dy;
    await tester.dragFrom(tester.getCenter(find.text('SELF TEST')), const Offset(0, -60));
    await tester.pump();
    expect(tester.getCenter(find.text('POWER ON')).dy, before - 60);
  });

  testWidgets('options and odd input do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 520, child: KkSequence(steps: <KkSequenceStep>[])));
    expect(tester.takeException(), isNull);
    expect(find.text('00 / 00'), findsOneWidget);

    await pumpKk(
      tester,
      const KkBox(
        width: 520,
        child: KkSequence(
          showIndex: false,
          progress: double.nan,
          steps: <KkSequenceStep>[
            KkSequenceStep(status: KkStepStatus.active, stateLabel: ''),
            KkSequenceStep(cjk: '冷却', stateLabel: 'HOLD'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('01'), findsNothing);
    expect(find.text('HOLD'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);

    await pumpKk(
      tester,
      KkBox(
        width: 30,
        height: 20,
        child: KkSequence(
          cjk: '起動手順起動手順',
          en: 'a very long sequence title',
          steps: <KkSequenceStep>[
            KkSequenceStep(cjk: '冷却循環' * 8, en: 'coolant loop ' * 8, note: 'FLOW ' * 40, time: '14:01:10Z'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // It is 300px wide at least when nothing forces it narrower.
    await pumpKk(
      tester,
      const KkRow(cross: KkCrossAlign.start, children: <Widget>[KkSequence(steps: <KkSequenceStep>[])]),
    );
    expect(tester.getSize(find.byType(KkSequence)).width, 300);
  });
}
