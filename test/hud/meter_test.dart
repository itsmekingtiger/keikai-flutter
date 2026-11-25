import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/hud/hud.dart';

import '../support/harness.dart';

Color? _numberColor(WidgetTester tester, String number) => tester.widget<Text>(find.text(number)).style!.color;

void main() {
  setUpAll(loadKkFonts);

  group('KkMeter maths', () {
    test('the lit part is a whole number of 8px segments, rounded down', () {
      expect(KkMeter.litWidth(0.5, 200), 96);
      expect(KkMeter.litWidth(0.04, 200), 8);
      expect(KkMeter.litWidth(0.039, 200), 0);
      expect(KkMeter.litWidth(1, 200), 200);
      expect(KkMeter.litWidth(1, 203), 200);
      expect(KkMeter.litWidth(0, 200), 0);
      expect(KkMeter.litWidth(0.5, 200, pitch: 10), 100);
    });

    test('odd input never throws and is clamped', () {
      expect(KkMeter.litWidth(-1, 200), 0);
      expect(KkMeter.litWidth(7, 200), 200);
      expect(KkMeter.litWidth(double.nan, 200), 0);
      expect(KkMeter.litWidth(0.5, 0), 0);
      expect(KkMeter.litWidth(0.5, -10), 0);
      expect(KkMeter.litWidth(0.5, 200, pitch: 0), 0);
    });

    test('the level comes from the thresholds', () {
      expect(KkMeter.levelFor(0), isNull);
      expect(KkMeter.levelFor(0.69), isNull);
      expect(KkMeter.levelFor(0.7), KkLevel.caution);
      expect(KkMeter.levelFor(0.89), KkLevel.caution);
      expect(KkMeter.levelFor(0.9), KkLevel.critical);
      expect(KkMeter.levelFor(1.4), KkLevel.critical);
      expect(KkMeter.levelFor(0.5, warn: 0.4, crit: 0.6), KkLevel.caution);
      expect(KkMeter.levelFor(double.nan), isNull);
    });
  });

  testWidgets('shows the percentage with three digits and takes its level from the value', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(cjk: '出力', en: 'output', value: 0.42, unit: '%')));
    expect(find.text('042'), findsOneWidget);
    expect(_numberColor(tester, '042'), c.ink);
    expect(find.byType(KkGlyph), findsNothing);

    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.78)));
    expect(_numberColor(tester, '078'), c.caution);
    expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, KkLevel.caution);

    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.94)));
    expect(_numberColor(tester, '094'), c.alert);

    // An explicit level wins; autoLevel: false keeps it plain.
    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.94, level: KkLevel.nominal)));
    expect(_numberColor(tester, '094'), c.nominal);
    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.94, autoLevel: false)));
    expect(_numberColor(tester, '094'), c.ink);

    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.61, valueText: '1220', unit: 'L')));
    expect(find.text('1220'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('is 200px wide at least, the bar is 14px, ticks spread end to end', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkRow(
        cross: KkCrossAlign.start,
        children: <Widget>[
          KkMeter(value: 0.3, ticks: <String>['0', '50', '100']),
        ],
      ),
    );
    final Rect meter = tester.getRect(find.byType(KkMeter));
    expect(meter.width, 200);
    final Rect bar = tester.getRect(find.descendant(of: find.byType(KkMeter), matching: find.byType(CustomPaint)));
    expect(bar.height, 14);
    expect(bar.width, 200);
    expect(tester.getTopLeft(find.text('0')).dx, meter.left);
    expect(tester.getTopRight(find.text('100')).dx, meter.right);
    // Bar sits 8px under the head and 8px over the ticks.
    expect(tester.getTopLeft(find.text('0')).dy - bar.bottom, 8);
  });

  testWidgets('steps to a new value in nine jumps over 0.45s', (WidgetTester tester) async {
    double value = 0;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(width: 360, child: KkMeter(value: value, autoLevel: false));
        },
      ),
      motion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    double shown() {
      final CustomPaint paint = tester.widget(
        find.descendant(of: find.byType(KkMeter), matching: find.byType(CustomPaint)),
      );
      // ignore: avoid_dynamic_calls
      return (paint.painter! as dynamic).value as double;
    }

    expect(shown(), 0);
    rebuild(() => value = 0.9);
    await tester.pump();
    // Look in the middle of each 50ms step, away from the step edges.
    await tester.pump(const Duration(milliseconds: 25));
    expect(shown(), 0, reason: 'still at the old value during the first step');
    for (int i = 1; i <= 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(shown(), closeTo(0.9 * i / 9, 1e-9), reason: 'step $i');
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(), 0.9);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('odd values and tiny boxes do not throw', (WidgetTester tester) async {
    for (final double v in <double>[-3, 0, 1, 42, double.nan, double.infinity, double.negativeInfinity]) {
      await pumpKk(tester, KkBox(width: 240, child: KkMeter(cjk: '負荷', en: 'load', value: v, unit: '%')));
      expect(tester.takeException(), isNull, reason: '$v');
    }
    await pumpKk(
      tester,
      const KkBox(
        width: 12,
        height: 6,
        child: KkMeter(cjk: '負荷負荷負荷', en: 'load load load', value: 0.5, unit: '%', ticks: <String>['0', '100']),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
