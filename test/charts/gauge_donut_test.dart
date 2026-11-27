import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

void main() {
  setUpAll(loadKkFonts);

  group('KkGauge', () {
    testWidgets('scales with the width up to 300 and keeps its aspect', (WidgetTester tester) async {
      // Free width 800: the dial stops at 300 wide, 132/200 of that tall, plus 16 padding.
      await pumpKk(tester, const KkGauge(frame: false, value: 50, level: KkLevel.nominal));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(800, 300 * 132 / 200 + 16));
      // Without a state the drawing is 116 units tall.
      await pumpKk(tester, const KkGauge(frame: false, value: 50));
      expect(tester.getSize(find.byType(KkCanvas)).height, 300 * 116 / 200 + 16);
      // Narrow: (224 - 24) wide dial.
      await pumpKk(tester, const KkBox(width: 224, child: KkGauge(frame: false, value: 50)));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(224, 116 + 16));
      // Free width falls back to the 224 natural width.
      await pumpKk(tester, const KkRow(children: <Widget>[KkGauge(frame: false, value: 50)]));
      expect(tester.getSize(find.byType(KkCanvas)).width, 224);
    });

    testWidgets('fills a fixed-height parent', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 260,
          height: 300,
          child: KkGauge(cjk: '電源負荷', en: 'power load', value: 62),
        ),
      );
      expect(tester.getSize(find.byType(KkGauge)), const Size(260, 300));
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(300 - 2 - 38.7, 1));
    });

    testWidgets('the painter gets the fraction, text, limits and bands', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkGauge(value: 412, min: 0, max: 800, unit: '°C', level: KkLevel.nominal, caution: 560, critical: 680),
      );
      final KkGaugePainter p = painterOf<KkGaugePainter>(tester);
      expect(p.fraction, closeTo(0.515, 1e-9));
      expect(p.needleFraction, closeTo(0.515, 1e-9));
      expect(p.valueText, '412');
      expect(p.unit, '°C');
      expect(p.stateWord, 'NOMINAL');
      expect(p.minLabel, '0');
      expect(p.maxLabel, '800');
      expect(p.bands.length, 2);
      expect(p.bands[0].from, closeTo(0.7, 1e-9));
      expect(p.bands[0].to, closeTo(0.85, 1e-9));
      expect(p.bands[0].color, KkColors.standby.caution);
      expect(p.bands[1].to, 1);
      expect(p.bands[1].color, KkColors.standby.alert);
    });

    testWidgets('display, format, limits and explicit bands', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkGauge(
          value: 71.5,
          display: '071.5',
          showLimits: false,
          state: 'holding',
          bands: const <KkGaugeBand>[KkGaugeBand(0, 20, KkLevel.critical), KkGaugeBand(-50, 500, null)],
          limitFormat: (double v) => 'L$v',
        ),
      );
      KkGaugePainter p = painterOf<KkGaugePainter>(tester);
      expect(p.valueText, '071.5');
      expect(p.minLabel, isNull);
      expect(p.stateWord, 'holding');
      expect(p.bands[0].to, closeTo(0.2, 1e-9));
      expect(p.bands[1].from, 0);
      expect(p.bands[1].to, 1);
      expect(p.bands[1].color, KkColors.standby.inkDim);

      await pumpKk(tester, KkGauge(value: 0.25, min: 0, max: 1, format: (double v) => '${(v * 100).round()}P'));
      p = painterOf<KkGaugePainter>(tester);
      expect(p.valueText, '25P');
      expect(p.maxLabel, '1.0');
      // The default format follows the range.
      await pumpKk(tester, const KkGauge(value: 0.257, min: 0, max: 1));
      expect(painterOf<KkGaugePainter>(tester).valueText, '0.26');
    });

    test('levelFor', () {
      expect(KkGauge.levelFor(10, caution: 60, critical: 80), KkLevel.nominal);
      expect(KkGauge.levelFor(60, caution: 60, critical: 80), KkLevel.caution);
      expect(KkGauge.levelFor(80, caution: 60, critical: 80), KkLevel.critical);
      expect(KkGauge.levelFor(999), KkLevel.nominal);
    });

    testWidgets('the needle sweeps up from zero in 12 steps, then steps to new values', (WidgetTester tester) async {
      await pumpKk(tester, const KkGauge(value: 50), motion: true);
      KkGaugePainter p() => painterOf<KkGaugePainter>(tester);
      expect(p().needleFraction, 0);
      // Still in the 0.3s delay.
      await tester.pump(const Duration(milliseconds: 250));
      expect(p().needleFraction, 0);
      // 380ms into the 700ms sweep: 6 of 12 steps.
      await tester.pump(const Duration(milliseconds: 430));
      expect(p().needleFraction, closeTo(0.5 * 6 / 12, 1e-9));
      // 660ms in: 11 of 12 steps.
      await tester.pump(const Duration(milliseconds: 280));
      expect(p().needleFraction, closeTo(0.5 * 11 / 12, 1e-9));
      await tester.pump(const Duration(milliseconds: 400));
      expect(p().needleFraction, 0.5);

      // A new value: 0.5s in 10 steps, from where the needle is.
      await tester.pumpWidget(kkHarness(const KkGauge(value: 100), motion: true));
      expect(p().fraction, 1);
      expect(p().needleFraction, 0.5);
      await tester.pump(const Duration(milliseconds: 260));
      expect(p().needleFraction, closeTo(0.5 + 0.5 * 5 / 10, 1e-9));
      await tester.pump(const Duration(milliseconds: 300));
      expect(p().needleFraction, 1);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the value scrambles on entry and on change', (WidgetTester tester) async {
      await pumpKk(tester, const KkGauge(value: 62, display: '0620'), motion: true);
      KkGaugePainter p() => painterOf<KkGaugePainter>(tester);
      await tester.pump(const Duration(milliseconds: 60));
      expect(p().valueText, isNot('0620'));
      expect(p().valueText.length, 4);
      await tester.pump(const Duration(milliseconds: 600));
      expect(p().valueText, '0620');
      await tester.pumpWidget(kkHarness(const KkGauge(value: 62, display: '0731'), motion: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(p().valueText, isNot('0731'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(p().valueText, '0731');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('gauges with values of the same length do not churn in unison', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkColumn(
          children: <Widget>[
            KkGauge(frame: false, value: 42.7, display: '042.7'),
            KkGauge(frame: false, value: 78.3, display: '078.3'),
            KkGauge(frame: false, value: 11.9, display: '011.9'),
          ],
        ),
        size: const Size(800, 900),
        motion: true,
      );
      List<String> values() => <String>[
        for (final CustomPaint paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
          if (paint.painter case final KkGaugePainter painter) painter.valueText,
      ];
      // Nothing has settled in the first noise frame: three dials show three different numbers.
      expect(values().toSet(), hasLength(3));
      for (int ms = 0; ms < 460; ms += 46) {
        expect(values().toSet().length, greaterThan(1), reason: 'at ${ms}ms');
        await tester.pump(const Duration(milliseconds: 46));
      }
      expect(values(), <String>['042.7', '078.3', '011.9']);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('reduced motion that arrives mid-entrance shows the final state at once', (WidgetTester tester) async {
      // At a quarter of the speed the value scrambles for 1.84s and the needle starts its sweep after 1.2s.
      await pumpKk(
        tester,
        const KkGauge(value: 62, display: '0620'),
        motion: true,
        theme: const KeikaiThemeData(motion: KkMotion(timeScale: 4)),
      );
      KkGaugePainter p() => painterOf<KkGaugePainter>(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(p().valueText, isNot('0620'));
      expect(p().needleFraction, 0);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(p().valueText, '0620');
      expect(p().needleFraction, 0.62);
      await tester.pump(const Duration(milliseconds: 500));
      expect(p().valueText, '0620');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing is left to animate');
    });

    testWidgets('with motion off it shows the final state at once', (WidgetTester tester) async {
      await pumpKk(tester, const KkGauge(value: 75));
      expect(painterOf<KkGaugePainter>(tester).needleFraction, 0.75);
      expect(painterOf<KkGaugePainter>(tester).valueText, '75');
    });

    testWidgets('survives bad ranges, bad values and tiny sizes', (WidgetTester tester) async {
      const List<({double value, double min, double max})> cases = <({double value, double min, double max})>[
        (value: double.nan, min: 0, max: 100),
        (value: double.infinity, min: 0, max: 100),
        (value: -50, min: 0, max: 100),
        (value: 500, min: 0, max: 100),
        (value: 5, min: 10, max: 10),
        (value: 5, min: 100, max: 0),
        (value: 5, min: double.nan, max: double.infinity),
        (value: 1e300, min: -1e300, max: 1e300),
      ];
      for (final ({double value, double min, double max}) c in cases) {
        await pumpKk(
          tester,
          KkGauge(
            cjk: '電源負荷',
            en: 'power load',
            value: c.value,
            min: c.min,
            max: c.max,
            unit: '%',
            level: KkLevel.critical,
            caution: 60,
            critical: double.nan,
            ticks: -4,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$c');
        final KkGaugePainter p = painterOf<KkGaugePainter>(tester);
        expect(p.fraction >= 0 && p.fraction <= 1, isTrue, reason: '$c');
      }
      for (final Size size in const <Size>[Size.zero, Size(1, 1), Size(20, 20), Size(30, 400), Size(900, 20)]) {
        await pumpKk(
          tester,
          KkBox(
            width: size.width,
            height: size.height,
            child: const KkGauge(value: 62, unit: '%', level: KkLevel.caution, display: '123456789', ticks: 100000),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  group('KkDonut', () {
    const List<KkSlice> slices = <KkSlice>[
      KkSlice(name: 'power', value: 50),
      KkSlice(name: 'coolant', value: 25),
      KkSlice(name: 'comms', value: 25),
    ];

    testWidgets('ring, total, caption and legend', (WidgetTester tester) async {
      await pumpKk(tester, const KkDonut(cjk: '警報内訳', en: 'alarms by class', caption: 'alarms', slices: slices));
      expect(find.text('100'), findsOneWidget);
      expect(find.text('ALARMS'), findsOneWidget);
      expect(find.text('POWER'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.text('25.0%'), findsNWidgets(2));
      expect(tester.getSize(find.byType(KkPlotPointer)), const Size(136, 136));
      // 1 + head + 12 + 136 + 12 + 1
      expect(tester.getSize(find.byType(KkDonut)).height, closeTo(2 + 38.7 + 24 + 136, 1.5));
      // The percent column is 44 wide, ending 12 + 1 from the right edge.
      expect(tester.getTopRight(find.text('50.0%')).dx, closeTo(800 - 13, 0.6));
    });

    testWidgets('hover, tap and keys report the part', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      final List<int> taps = <int>[];
      await pumpKk(tester, KkDonut(frame: false, slices: slices, onSliceHover: seen.add, onSliceTap: taps.add));
      final Rect ring = plotRect(tester, find.byType(KkDonut));
      final Offset c = ring.center;
      final TestGesture pointer = await mouse(tester);
      // Right of centre, on the band: the first part (top to bottom on the right).
      await pointer.moveTo(c + const Offset(59, 0));
      await tester.pump();
      // Bottom left quadrant: the second part.
      await pointer.moveTo(c + const Offset(-42, 42));
      await tester.pump();
      // Top left quadrant: the third.
      await pointer.moveTo(c + const Offset(-42, -42));
      await tester.pump();
      // The hole is not a part.
      await pointer.moveTo(c);
      await tester.pump();
      expect(seen, <int?>[0, 1, 2, null]);
      await tester.tapAt(c + const Offset(-42, 42));
      expect(taps, <int>[1]);
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      seen.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(seen, <int?>[0, 1, 2, 0, 2, null]);
      expect(taps, <int>[1, 2]);
    });

    testWidgets('the cursor follows the parts when they change under the pointer', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      List<KkSlice> data = slices;
      // The listener rebuilds its parent: that throws if it is called mid-build.
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            KkDonut(frame: false, slices: data, onSliceHover: (int? i) => setState(() => seen.add(i))),
      );
      await pumpKk(tester, build());
      final TestGesture pointer = await mouse(tester);
      // Top left quadrant: the third part.
      await pointer.moveTo(plotRect(tester, find.byType(KkDonut)).center + const Offset(-42, -42));
      await tester.pump();
      expect(seen, <int?>[2]);

      // Still under the pointer, with another value: the cursor stays on it.
      data = const <KkSlice>[
        KkSlice(name: 'power', value: 50),
        KkSlice(name: 'coolant', value: 25),
        KkSlice(name: 'comms', value: 30),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[2]);

      // It has no share left: the cursor lets go of it, and the part that now
      // lies under the resting pointer (coolant, from 240 to 360 degrees) takes it.
      data = const <KkSlice>[
        KkSlice(name: 'power', value: 50),
        KkSlice(name: 'coolant', value: 25),
        KkSlice(name: 'comms', value: 0),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[2, null, 1]);
      expect(tester.takeException(), isNull);

      // That one goes too: the only part left is everywhere.
      data = const <KkSlice>[KkSlice(name: 'power', value: 50)];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[2, null, 1, null, 0]);

      // Nothing left at all.
      data = const <KkSlice>[];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen.last, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cursor moved by the keys is not taken back by a resting pointer', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      List<KkSlice> data = slices;
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            KkDonut(frame: false, slices: data, onSliceHover: (int? i) => setState(() => seen.add(i))),
      );
      await pumpKk(tester, build());
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkDonut)).center + const Offset(-42, -42));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump();
      expect(seen, <int?>[2, 0], reason: 'the listener rebuilt the chart, and the pointer did not snatch it back');

      // The same data arrives again: the keyboard still has it.
      data = List<KkSlice>.of(slices);
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[2, 0]);

      // Until the pointer really moves.
      await pointer.moveTo(plotRect(tester, find.byType(KkDonut)).center + const Offset(-43, -42));
      await tester.pump();
      expect(seen, <int?>[2, 0, 2]);
    });

    testWidgets('hovering a legend row selects its part', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, KkDonut(slices: slices, onSliceHover: seen.add));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.text('COOLANT')));
      await tester.pump();
      await pointer.moveTo(tester.getCenter(find.text('COMMS')));
      await tester.pump();
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      expect(seen.where((int? i) => i != null).toList(), <int?>[1, 2]);
      expect(seen.last, isNull);
    });

    testWidgets('total, format, decimals and no legend', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkDonut(
          slices: const <KkSlice>[
            KkSlice(name: 'a', value: 1.5),
            KkSlice(name: 'b', value: 0.5),
          ],
          total: '002',
          caption: null,
          percentDecimals: 0,
          format: (double v) => '${v}X',
        ),
      );
      expect(find.text('002'), findsOneWidget);
      expect(find.text('1.5X'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      await pumpKk(tester, const KkDonut(slices: slices, legend: false));
      expect(find.text('POWER'), findsNothing);
      // Values that are not whole get one decimal by default.
      await pumpKk(
        tester,
        const KkDonut(
          slices: <KkSlice>[
            KkSlice(name: 'a', value: 1.25),
            KkSlice(name: 'b', value: 1),
          ],
        ),
      );
      expect(find.text('2.3'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
    });

    testWidgets('the total scrambles when it changes', (WidgetTester tester) async {
      await pumpKk(tester, const KkDonut(slices: slices, total: '0964'), motion: true);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('0964'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('0964'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('survives empty, zero, negative and non-finite parts at any size', (WidgetTester tester) async {
      const List<List<KkSlice>> cases = <List<KkSlice>>[
        <KkSlice>[],
        <KkSlice>[KkSlice(name: 'a', value: 0)],
        <KkSlice>[KkSlice(name: 'a', value: 7)],
        <KkSlice>[KkSlice(name: 'a', value: -3), KkSlice(name: 'b', value: double.nan), KkSlice(name: 'c', value: 2)],
        <KkSlice>[KkSlice(name: 'a', value: double.infinity), KkSlice(name: 'b', value: 1e300)],
        <KkSlice>[
          KkSlice(name: 'a part with a name far too long to fit the legend column', value: 1e-12),
          KkSlice(name: 'b', value: 1e12, level: KkLevel.critical),
        ],
      ];
      final TestGesture pointer = await mouse(tester);
      for (final List<KkSlice> s in cases) {
        for (final Size size in const <Size>[Size(800, 600), Size(150, 150), Size(20, 20), Size.zero]) {
          await pumpKk(
            tester,
            KkBox(
              width: size.width,
              height: size == const Size(800, 600) ? null : size.height,
              child: KkDonut(cjk: '警報内訳', en: 'alarms', slices: s, size: 136, thickness: 500, gap: 900),
            ),
          );
          await pointer.moveTo(const Offset(70, 100));
          await tester.pump();
          await pointer.moveTo(const Offset(9999, 9999));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$s at $size');
        }
      }
    });
  });
}
