import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkAlarmTile> _tiles = <KkAlarmTile>[
  KkAlarmTile(code: 'A-01', cjk: '電源', en: 'power'),
  KkAlarmTile(code: 'A-02', cjk: '水圧', en: 'pressure', state: KkAlarmState.alarm),
  KkAlarmTile(code: 'A-03', cjk: '水温', en: 'coolant temp', state: KkAlarmState.ack, level: KkLevel.caution),
  KkAlarmTile(code: 'A-04', cjk: '通信', en: 'comms', state: KkAlarmState.rtn),
  KkAlarmTile(code: 'A-05', cjk: '排気', en: 'exhaust'),
  KkAlarmTile(code: 'A-06', cjk: '試験', en: 'lamp test', state: KkAlarmState.test),
];

/// The ground of the window titled [cjk].
Color? _fill(WidgetTester tester, String cjk) =>
    tester.widget<KkBox>(find.ancestor(of: find.text(cjk), matching: find.byType(KkBox)).first).fill;

Color? _ink(WidgetTester tester, String cjk) => tester.widget<Text>(find.text(cjk)).style!.color;

void main() {
  setUpAll(loadKkFonts);

  group('KkAlarmState', () {
    test('acknowledge, clear and reset walk the annunciator sequence', () {
      expect(KkAlarmState.alarm.acknowledged, KkAlarmState.ack);
      expect(KkAlarmState.ack.cleared, KkAlarmState.rtn);
      expect(KkAlarmState.rtn.reset, KkAlarmState.normal);
      // The whole loop.
      expect(KkAlarmState.alarm.acknowledged.cleared.reset, KkAlarmState.normal);
    });

    test('steps taken out of turn change nothing', () {
      for (final KkAlarmState s in KkAlarmState.values) {
        if (s != KkAlarmState.alarm) expect(s.acknowledged, s);
        if (s != KkAlarmState.ack) expect(s.cleared, s);
        if (s != KkAlarmState.rtn) expect(s.reset, s);
      }
      // An alarm nobody acknowledged keeps flashing when the condition clears.
      expect(KkAlarmState.alarm.cleared, KkAlarmState.alarm);
    });

    test('only flashing and ring-back windows are actionable', () {
      expect(
        KkAlarmState.values.where((KkAlarmState s) => s.isActionable),
        <KkAlarmState>[KkAlarmState.alarm, KkAlarmState.rtn],
      );
    });

    test('withState keeps everything else', () {
      const KkAlarmTile t = KkAlarmTile(code: 'A-02', cjk: '水圧', en: 'pressure', level: KkLevel.caution);
      expect(
        t.withState(KkAlarmState.alarm),
        const KkAlarmTile(code: 'A-02', cjk: '水圧', en: 'pressure', level: KkLevel.caution, state: KkAlarmState.alarm),
      );
    });
  });

  testWidgets('lays windows out in equal columns, 3px apart, 68px tall at least', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 409, child: KkAnnunciator(tiles: _tiles, columns: 3)));
    final Rect grid = tester.getRect(find.byType(KkAnnunciator));
    // 1 border + 3 padding + 2 rows of 68 + 3 gap + 3 padding + 1 border.
    expect(grid.size, const Size(409, 147));
    Rect window(String cjk) => tester.getRect(find.ancestor(of: find.text(cjk), matching: find.byType(KkBox)).first);
    // (409 − 2 − 6 − 2×3) / 3 = 131.67.
    expect(window('電源').width, closeTo(131.667, 0.01));
    expect(window('電源').height, 68);
    expect(window('電源').topLeft, grid.topLeft + const Offset(4, 4));
    expect(window('水圧').left - window('電源').right, closeTo(3, 1e-6));
    expect(window('通信').top - window('電源').bottom, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each state has its own look', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 600, child: KkAnnunciator(tiles: _tiles, columns: 3)));
    const KkColors c = KkColors.standby;
    expect(_fill(tester, '電源'), c.bg200);
    expect(_ink(tester, '電源'), c.inkFaint);
    // Alarm in its lit phase (motion is off, so it stays lit).
    expect(_fill(tester, '水圧'), c.alert);
    expect(_ink(tester, '水圧'), c.onFill);
    // Acknowledged, with a caution level.
    expect(_fill(tester, '水温'), c.caution);
    expect(_ink(tester, '水温'), c.onFill);
    // Ring-back: dark ground, coloured text.
    expect(_fill(tester, '通信'), c.bg200);
    expect(_ink(tester, '通信'), c.alert);
    // Lamp test.
    expect(_fill(tester, '試験'), c.ink);
    expect(_ink(tester, '試験'), c.bg000);
  });

  testWidgets('an alarm flashes every 0.5s and a ring-back blinks its border every 1.2s', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkBox(width: 600, child: KkAnnunciator(tiles: _tiles, columns: 3, boot: false)),
      motion: true,
    );
    const KkColors c = KkColors.standby;
    bool ringBack() {
      final CustomPaint paint = tester.widget(
        find.ancestor(of: find.text('通信'), matching: find.byType(CustomPaint)).first,
      );
      // ignore: avoid_dynamic_calls
      return (paint.foregroundPainter! as dynamic).inset != null;
    }

    await tester.pump(const Duration(milliseconds: 100));
    expect(_fill(tester, '水圧'), c.alert);
    expect(_ink(tester, '水圧'), c.onFill);
    expect(ringBack(), isTrue);

    await tester.pump(const Duration(milliseconds: 250)); // 0.35s
    expect(_fill(tester, '水圧'), c.bg200);
    expect(_ink(tester, '水圧'), c.alert);
    expect(ringBack(), isTrue);

    await tester.pump(const Duration(milliseconds: 250)); // 0.60s
    expect(_fill(tester, '水圧'), c.alert);
    expect(ringBack(), isFalse);

    await tester.pump(const Duration(milliseconds: 700)); // 1.30s
    expect(ringBack(), isTrue);
    // Steady states never change.
    expect(_fill(tester, '水温'), c.caution);
    expect(_fill(tester, '電源'), c.bg200);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pressing a flashing window acknowledges; pressing a ring-back resets', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkAnnunciator(
          tiles: _tiles,
          columns: 3,
          onAcknowledge: (int i) => calls.add('ack $i'),
          onReset: (int i) => calls.add('reset $i'),
        ),
      ),
    );
    await tester.tap(find.text('電源'));
    await tester.tap(find.text('水温'));
    await tester.tap(find.text('試験'));
    expect(calls, isEmpty, reason: 'normal, acknowledged and test windows do nothing');
    await tester.tap(find.text('水圧'));
    expect(calls, <String>['ack 1']);
    await tester.tap(find.text('通信'));
    expect(calls, <String>['ack 1', 'reset 3']);
  });

  testWidgets('drives a full alarm cycle through its callbacks', (WidgetTester tester) async {
    List<KkAlarmTile> tiles = <KkAlarmTile>[const KkAlarmTile(code: 'A-02', cjk: '水圧', state: KkAlarmState.alarm)];
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(
            width: 300,
            child: KkAnnunciator(
              tiles: tiles,
              columns: 1,
              onAcknowledge: (int i) => setState(() => tiles = <KkAlarmTile>[tiles[i].withState(tiles[i].state.acknowledged)]),
              onReset: (int i) => setState(() => tiles = <KkAlarmTile>[tiles[i].withState(tiles[i].state.reset)]),
            ),
          );
        },
      ),
    );
    const KkColors c = KkColors.standby;
    await tester.tap(find.text('水圧'));
    await tester.pump();
    expect(tiles.single.state, KkAlarmState.ack);
    expect(_fill(tester, '水圧'), c.alert);

    // Pressing an acknowledged window does nothing; the process has to clear.
    await tester.tap(find.text('水圧'));
    await tester.pump();
    expect(tiles.single.state, KkAlarmState.ack);

    rebuild(() => tiles = <KkAlarmTile>[tiles.single.withState(tiles.single.state.cleared)]);
    await tester.pump();
    expect(_fill(tester, '水圧'), c.bg200);
    expect(_ink(tester, '水圧'), c.alert);

    await tester.tap(find.text('水圧'));
    await tester.pump();
    expect(tiles.single.state, KkAlarmState.normal);
    expect(_ink(tester, '水圧'), c.inkFaint);
  });

  testWidgets('onTileTap hears every window', (WidgetTester tester) async {
    final List<int> taps = <int>[];
    await pumpKk(
      tester,
      KkBox(width: 600, child: KkAnnunciator(tiles: _tiles, columns: 3, onTileTap: taps.add)),
    );
    await tester.tap(find.text('電源'));
    await tester.tap(find.text('試験'));
    expect(taps, <int>[0, 5]);
  });

  testWidgets('arrow keys move between windows; Enter presses the focused one', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        child: KkAnnunciator(
          tiles: _tiles,
          columns: 3,
          onAcknowledge: (int i) => calls.add('ack $i'),
          onReset: (int i) => calls.add('reset $i'),
        ),
      ),
    );
    int focused() {
      final List<Element> windows = find
          .descendant(of: find.byType(KkAnnunciator), matching: find.byType(FocusableActionDetector))
          .evaluate()
          .toList();
      return windows.indexWhere((Element e) => Focus.of(e, scopeOk: true).hasPrimaryFocus || _hasFocus(e));
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, <String>['ack 1']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused(), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, <String>['ack 1', 'reset 3']);
    // Up from the second row goes to the first; further up stays put.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(focused(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(focused(), 0);
  });

  testWidgets('the number of windows can change; odd input does not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 600, child: KkAnnunciator(tiles: _tiles)));
    await pumpKk(tester, KkBox(width: 600, child: KkAnnunciator(tiles: _tiles.sublist(0, 2))));
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkBox(width: 600, child: KkAnnunciator(tiles: <KkAlarmTile>[])));
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      KkBox(
        width: 24,
        height: 10,
        child: KkAnnunciator(
          columns: 5,
          tiles: <KkAlarmTile>[
            KkAlarmTile(code: 'A-VERY-LONG-CODE', cjk: '冷却水圧' * 6, en: 'coolant pressure ' * 6, state: KkAlarmState.rtn),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // In a roomy box it stays as tall as its rows need.
    await pumpKk(tester, const KkBox(width: 600, child: KkAnnunciator(tiles: _tiles, columns: 3)));
    expect(tester.getSize(find.byType(KkAnnunciator)).height, 147);
  });
}

bool _hasFocus(Element detector) {
  bool found = false;
  void visit(Element e) {
    final Widget w = e.widget;
    if (w is Focus && w.focusNode != null && w.focusNode!.hasPrimaryFocus) found = true;
    if (!found) e.visitChildren(visit);
  }

  detector.visitChildren(visit);
  return found;
}
