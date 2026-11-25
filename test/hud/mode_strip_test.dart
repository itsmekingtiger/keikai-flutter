import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkModeStep> _steps = <KkModeStep>[
  KkModeStep(cjk: '停止', en: 'shutdown'),
  KkModeStep(cjk: '待機', en: 'standby'),
  KkModeStep(cjk: '起動', en: 'start-up'),
  KkModeStep(cjk: '運転', en: 'run'),
  KkModeStep(cjk: '全力', en: 'full power'),
];

Color? _ink(WidgetTester tester, String cjk) => tester.widget<Text>(find.text(cjk)).style!.color;

/// The painter of the step titled [cjk] (fill, bars).
dynamic _plate(WidgetTester tester, String cjk) =>
    tester.widget<CustomPaint>(find.ancestor(of: find.text(cjk), matching: find.byType(CustomPaint)).first).painter;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('steps are 54px high, share the width and sit 2px apart', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 608, child: KkModeStrip(steps: _steps, current: 2)));
    expect(tester.getSize(find.byType(KkModeStrip)), const Size(608, 54));
    Rect step(String cjk) => tester.getRect(find.ancestor(of: find.text(cjk), matching: find.byType(KkSurface)).first);
    // (608 − 4 gaps of 2) / 5.
    expect(step('停止').width, 120);
    expect(step('待機').left - step('停止').right, 2);
    // Text starts 14px in on the first step and 22px (past the notch) on the others.
    expect(tester.getTopLeft(find.text('停止')).dx - step('停止').left, 14);
    expect(tester.getTopLeft(find.text('待機')).dx - step('待機').left, 22);
  });

  testWidgets('past, current, target and future steps each have their look', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(tester, const KkBox(width: 700, child: KkModeStrip(steps: _steps, current: 2, target: 3)));
    // ignore: avoid_dynamic_calls
    Color fill(String cjk) => _plate(tester, cjk).fill as Color;
    // ignore: avoid_dynamic_calls
    Color? bars(String cjk) => _plate(tester, cjk).bars as Color?;

    expect(_ink(tester, '停止'), c.inkDim, reason: 'past');
    expect(fill('停止'), c.bg200);
    expect(_ink(tester, '起動'), c.onFill, reason: 'current');
    expect(fill('起動'), c.signal);
    expect(_ink(tester, '運転'), c.signal, reason: 'target');
    expect(fill('運転'), c.bg200);
    expect(bars('運転'), c.signal);
    expect(_ink(tester, '全力'), c.inkFaint, reason: 'future');
    expect(bars('全力'), isNull);
    expect(bars('起動'), isNull);

    // A level recolours current and target; a step's own level wins.
    await pumpKk(
      tester,
      const KkBox(
        width: 700,
        child: KkModeStrip(
          steps: <KkModeStep>[
            KkModeStep(cjk: '停止'),
            KkModeStep(cjk: '待機', level: KkLevel.nominal),
            KkModeStep(cjk: '起動'),
          ],
          current: 1,
          target: 2,
          level: KkLevel.caution,
        ),
      ),
    );
    expect(fill('待機'), c.nominal);
    expect(bars('起動'), c.caution);
  });

  testWidgets('the target arms: outlined for 0.3s, filled for 0.3s', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(
      tester,
      const KkBox(width: 700, child: KkModeStrip(steps: _steps, current: 2, target: 3)),
      motion: true,
    );
    // ignore: avoid_dynamic_calls
    Color fill() => _plate(tester, '運転').fill as Color;
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(), c.bg200);
    expect(_ink(tester, '運転'), c.signal);
    await tester.pump(const Duration(milliseconds: 300));
    expect(fill(), c.signal);
    expect(_ink(tester, '運転'), c.onFill);
    // ignore: avoid_dynamic_calls
    expect(_plate(tester, '運転').bars, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(fill(), c.bg200);
    // The current step never blinks.
    // ignore: avoid_dynamic_calls
    expect(_plate(tester, '起動').fill, c.signal);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a target equal to the current step, or out of range, is ignored', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 700, child: KkModeStrip(steps: _steps, current: 2, target: 2)));
    // ignore: avoid_dynamic_calls
    expect(_plate(tester, '起動').bars, isNull);
    // ignore: avoid_dynamic_calls
    expect(_plate(tester, '起動').fill, KkColors.standby.signal);
    await pumpKk(tester, const KkBox(width: 700, child: KkModeStrip(steps: _steps, current: -1, target: 99)));
    expect(tester.takeException(), isNull);
    expect(_ink(tester, '停止'), KkColors.standby.inkFaint, reason: 'no current step: everything is ahead');
  });

  testWidgets('steps can be pressed inside the arrow, and from the keyboard', (WidgetTester tester) async {
    final List<int> taps = <int>[];
    await pumpKk(
      tester,
      KkBox(width: 608, child: KkModeStrip(steps: _steps, current: 2, onStepTap: taps.add)),
    );
    await tester.tap(find.text('運転'));
    expect(taps, <int>[3]);
    // The top-right corner of a step's box is outside its arrow head.
    final Rect second = tester.getRect(find.ancestor(of: find.text('待機'), matching: find.byType(KkSurface)).first);
    await tester.tapAt(second.topRight + const Offset(-2, 3));
    expect(taps, <int>[3]);
    // The middle of the left edge is inside the notch, so it belongs to nobody.
    await tester.tapAt(Offset(second.left + 2, second.center.dy));
    expect(taps, <int>[3]);
    await tester.tapAt(Offset(second.left + 2, second.top + 2));
    expect(taps, <int>[3, 1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, <int>[3, 1, 0]);
  });

  testWidgets('no steps, one step, long text and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 300, child: KkModeStrip(steps: <KkModeStep>[], current: 0)));
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      const KkBox(width: 300, child: KkModeStrip(steps: <KkModeStep>[KkModeStep(cjk: '運転')], current: 0)),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      KkBox(
        width: 40,
        height: 10,
        child: KkModeStrip(
          steps: <KkModeStep>[
            for (int i = 0; i < 6; i++) KkModeStep(cjk: '冷却循環運転' * 3, en: 'coolant loop running ' * 3),
          ],
          current: 2,
          target: 4,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Not limited in width: each step is as wide as its text needs.
    await pumpKk(
      tester,
      const KkScroll(axis: Axis.horizontal, child: KkModeStrip(steps: _steps, current: 1)),
    );
    expect(tester.takeException(), isNull);
  });
}
