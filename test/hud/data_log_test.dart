import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

KkLogEntry _entry(int i, {KkLevel? level}) => KkLogEntry(
  time: '14:02:${i.toString().padLeft(2, '0')}.000Z',
  source: 'SEC-${i.toString().padLeft(2, '0')}',
  level: level,
  message: 'EVENT $i',
);

/// The fill of the row that shows [message].
Color? _rowFill(WidgetTester tester, String message) {
  final Iterable<KkBox> boxes = tester.widgetList<KkBox>(
    find.ancestor(of: find.text(message), matching: find.byType(KkBox)),
  );
  return boxes.firstWhere((KkBox b) => b.decoration != null).decoration!.fill;
}

void main() {
  setUpAll(loadKkFonts);

  testWidgets('header is 24px, rows are 26px, columns are 96 / 60 / 92 / rest', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkDataLog(entries: <KkLogEntry>[_entry(1), _entry(2, level: KkLevel.caution), _entry(3)]),
      ),
    );
    final Rect log = tester.getRect(find.byType(KkDataLog));
    // 1 border + 24 header + 3 × 26 + 1 border.
    expect(log.size, const Size(600, 104));
    expect(tester.getTopLeft(find.text('TIME')).dx, log.left + 1 + 12);
    expect(tester.getTopLeft(find.text('SRC')).dx, log.left + 1 + 12 + 96 + 12);
    expect(tester.getTopLeft(find.text('LEVEL')).dx, log.left + 1 + 12 + 96 + 12 + 60 + 12);
    expect(tester.getTopLeft(find.text('MESSAGE')).dx, log.left + 1 + 12 + 96 + 12 + 60 + 12 + 92 + 12);
    expect(tester.getTopLeft(find.text('EVENT 1')).dx, tester.getTopLeft(find.text('MESSAGE')).dx);
    final double first = tester.getCenter(find.text('EVENT 1')).dy;
    expect(first, closeTo(log.top + 1 + 24 + 13, 0.6));
    expect(tester.getCenter(find.text('EVENT 2')).dy - first, 26);
    expect(find.text('INFO'), findsNWidgets(2));
    expect(find.text('CAUTION'), findsOneWidget);
  });

  testWidgets('a critical line sits on the deep alert colour with ink text', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkDataLog(entries: <KkLogEntry>[_entry(1), _entry(2, level: KkLevel.critical)]),
      ),
    );
    const KkColors c = KkColors.standby;
    expect(_rowFill(tester, 'EVENT 2'), c.alertDeep);
    expect(_rowFill(tester, 'EVENT 1')!.a, 0);
    expect(tester.widget<Text>(find.text('SEC-02')).style!.color, c.ink);
    expect(tester.widget<Text>(find.text('SEC-01')).style!.color, c.signal);
    expect(tester.widget<Text>(find.text('CRITICAL')).style!.color, c.ink);
  });

  testWidgets('hover raises a line; a critical line keeps its colour', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkDataLog(entries: <KkLogEntry>[_entry(1), _entry(2, level: KkLevel.critical)]),
      ),
    );
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(790, 590));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('EVENT 1')));
    await tester.pump();
    expect(_rowFill(tester, 'EVENT 1'), KkColors.standby.bg300);
    await mouse.moveTo(tester.getCenter(find.text('EVENT 2')));
    await tester.pump();
    expect(_rowFill(tester, 'EVENT 1')!.a, 0);
    expect(_rowFill(tester, 'EVENT 2'), KkColors.standby.alertDeep);
  });

  testWidgets('maxHeight makes it scroll, and it follows new lines at the end', (WidgetTester tester) async {
    List<KkLogEntry> entries = <KkLogEntry>[for (int i = 0; i < 10; i++) _entry(i)];
    late StateSetter rebuild;
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(
            width: 600,
            child: KkDataLog(entries: entries, maxHeight: 104, controller: controller),
          );
        },
      ),
    );
    expect(tester.getSize(find.byType(KkDataLog)).height, 1 + 24 + 104 + 1);
    expect(controller.position.maxScrollExtent, 10 * 26 - 104);
    expect(controller.offset, 0);

    // Not at the end: a new line does not move the view.
    rebuild(() => entries = <KkLogEntry>[...entries, _entry(10)]);
    await tester.pump();
    await tester.pump();
    expect(controller.offset, 0);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    rebuild(() => entries = <KkLogEntry>[...entries, _entry(11)]);
    await tester.pump();
    await tester.pump();
    expect(controller.position.maxScrollExtent, 12 * 26 - 104);
    expect(controller.offset, controller.position.maxScrollExtent, reason: 'the log follows its newest line');
    expect(find.text('EVENT 11'), findsOneWidget);
  });

  testWidgets('newestFirst follows the top; autoScroll: false never moves', (WidgetTester tester) async {
    List<KkLogEntry> entries = <KkLogEntry>[for (int i = 9; i >= 0; i--) _entry(i)];
    late StateSetter rebuild;
    bool auto = true;
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(
            width: 600,
            child: KkDataLog(
              entries: entries,
              maxHeight: 104,
              controller: controller,
              newestFirst: true,
              autoScroll: auto,
            ),
          );
        },
      ),
    );
    rebuild(() => entries = <KkLogEntry>[_entry(10), ...entries]);
    await tester.pump();
    await tester.pump();
    expect(controller.offset, 0);
    expect(find.text('EVENT 10'), findsOneWidget);

    controller.jumpTo(52);
    rebuild(() {
      auto = false;
      entries = <KkLogEntry>[_entry(11), ...entries];
    });
    await tester.pump();
    await tester.pump();
    expect(controller.offset, 52);
  });

  testWidgets('fills a fixed height and scrolls inside it', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 500,
        height: 130,
        child: KkDataLog(entries: <KkLogEntry>[for (int i = 0; i < 30; i++) _entry(i)]),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkDataLog)), const Size(500, 130));
    expect(find.text('EVENT 0'), findsOneWidget);
    expect(find.text('EVENT 29'), findsNothing, reason: 'off screen lines are not built');
    await tester.dragFrom(tester.getCenter(find.text('EVENT 2')), const Offset(0, -52));
    await tester.pump();
    expect(find.text('EVENT 0'), findsNothing);
  });

  testWidgets('a line that is new to the list wipes in on signal-dim, then clears', (WidgetTester tester) async {
    List<KkLogEntry> entries = <KkLogEntry>[_entry(1)];
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(width: 600, child: KkDataLog(entries: entries, boot: false));
        },
      ),
      motion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    // Lines that were there from the start do not animate.
    expect(_rowFill(tester, 'EVENT 1')!.a, 0);

    rebuild(() => entries = <KkLogEntry>[...entries, _entry(2)]);
    await tester.pump();
    RenderClipRect clipOf() => tester.renderObject<RenderClipRect>(
      find.ancestor(of: find.text('EVENT 2'), matching: find.byType(ClipRect)).first,
    );
    double shown() => clipOf().clipper!.getClip(clipOf().size).width / clipOf().size.width;

    expect(shown(), 0);
    // The wipe takes the first 0.45s in ten steps; at 0.2s it is 4/10 across.
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(), closeTo(0.4, 1e-9));
    expect(_rowFill(tester, 'EVENT 2'), KkColors.standby.signalDim);
    expect(_rowFill(tester, 'EVENT 1')!.a, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(clipOf().clipBehavior, Clip.none);
    // Then the ground clears in ten steps over the remaining 0.55s.
    await tester.pump(const Duration(milliseconds: 250));
    final Color mid = _rowFill(tester, 'EVENT 2')!;
    expect(mid.a, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_rowFill(tester, 'EVENT 2')!.a, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lines can be pressed, with the pointer and from the keyboard', (WidgetTester tester) async {
    final List<String> taps = <String>[];
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkDataLog(
          entries: <KkLogEntry>[_entry(1), _entry(2)],
          onEntryTap: (KkLogEntry e) => taps.add(e.message),
        ),
      ),
    );
    await tester.tap(find.text('EVENT 2'));
    expect(taps, <String>['EVENT 2']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, <String>['EVENT 2', 'EVENT 1']);
  });

  testWidgets('columns can be hidden, renamed and resized', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkDataLog(
          entries: <KkLogEntry>[_entry(1)],
          headers: const <String>['UTC', 'NODE'],
          timeWidth: 120,
          levelWidth: 0,
          border: false,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('UTC'), findsOneWidget);
    expect(find.text('NODE'), findsOneWidget);
    expect(find.text('INFO'), findsNothing);
    expect(tester.getTopLeft(find.text('NODE')).dx, 12 + 120 + 12);
    expect(tester.getSize(find.byType(KkDataLog)).height, 24 + 26);

    await pumpKk(
      tester,
      KkBox(width: 600, child: KkDataLog(entries: <KkLogEntry>[_entry(1)], showHeader: false)),
    );
    expect(find.text('TIME'), findsNothing);
    expect(tester.getSize(find.byType(KkDataLog)).height, 28);
  });

  testWidgets('empty logs, long text and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 600, child: KkDataLog(entries: <KkLogEntry>[])));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkDataLog)).height, 26);
    await pumpKk(
      tester,
      KkBox(
        width: 40,
        height: 20,
        child: KkDataLog(
          entries: <KkLogEntry>[
            KkLogEntry(
              time: '2026-11-24T14:02:31.004Z' * 3,
              source: 'A-VERY-LONG-SOURCE-NAME',
              level: KkLevel.critical,
              levelText: 'CATASTROPHIC FAILURE',
              message: 'COOLANT PRESSURE LOW ' * 20,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('takes a sensible width where none is given', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkScroll(
        axis: Axis.horizontal,
        child: KkDataLog(entries: <KkLogEntry>[_entry(1), _entry(2)]),
      ),
    );
    expect(tester.takeException(), isNull);
    // 96 + 60 + 92 columns, five 12px gaps and paddings, two borders, 280 for the message.
    expect(tester.getSize(find.byType(KkDataLog)).width, 590);
    await pumpKk(
      tester,
      KkRow(
        cross: KkCrossAlign.start,
        children: <Widget>[
          KkDataLog(entries: <KkLogEntry>[_entry(1)], timeWidth: 0, sourceWidth: 0, levelWidth: 0),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkDataLog)).width, 342);
  });

  test('entries with the same content are the same entry', () {
    expect(_entry(1), _entry(1));
    expect(_entry(1).hashCode, _entry(1).hashCode);
    expect(_entry(1), isNot(_entry(2)));
    expect(const KkLogEntry(id: 7, time: 't', message: 'm'), isNot(const KkLogEntry(id: 8, time: 't', message: 'm')));
  });
}
