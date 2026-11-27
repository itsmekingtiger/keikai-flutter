import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

Color? _numberColor(WidgetTester tester, String number) => tester.widget<Text>(find.text(number)).style!.color;

/// The fill the bar is painted with, 0 to 1.
double _bar(WidgetTester tester) {
  final CustomPaint paint = tester.widget(
    find.descendant(of: find.byType(KkMeter), matching: find.byType(CustomPaint)),
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter! as dynamic).value as double;
}

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
    await pumpKk(
      tester,
      const KkBox(
        width: 320,
        child: KkMeter(cjk: '出力', en: 'output', value: 0.42, unit: '%'),
      ),
    );
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

    await pumpKk(
      tester,
      const KkBox(
        width: 320,
        child: KkMeter(value: 0.61, valueText: '1220', unit: 'L'),
      ),
    );
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

  testWidgets('the head is its labels and the number with one gap between each', (WidgetTester tester) async {
    // The innermost row around the number: status icon, number and unit.
    Rect number() => tester.getRect(find.ancestor(of: find.text('078'), matching: find.byType(KkRow)).first);

    // A meter that hugs a long head is as wide as cjk + 8 + en + 8 + number.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[KkMeter(cjk: '冷却水温冷却水温', en: 'coolant temperature loop', value: 0.78, unit: '%')],
      ),
    );
    final Rect cjk = tester.getRect(find.byType(KkSqueeze));
    final Rect en = tester.getRect(find.text('COOLANT TEMPERATURE LOOP'));
    expect(en.left - cjk.right, closeTo(8, 0.01));
    expect(number().left - en.right, closeTo(8, 0.01));
    final Rect meter = tester.getRect(find.byType(KkMeter));
    expect(meter.width, greaterThan(200));
    expect(meter.width, closeTo(cjk.width + 8 + en.width + 8 + number().width, 0.01));

    // With room to spare, and with no labels at all, the number sits at the right.
    await pumpKk(
      tester,
      const KkBox(
        width: 320,
        child: KkMeter(cjk: '負荷', en: 'load', value: 0.78, unit: '%'),
      ),
    );
    expect(tester.getRect(find.byType(KkSqueeze)).left, 0);
    expect(number().right, closeTo(320, 0.01));
    await pumpKk(tester, const KkBox(width: 320, child: KkMeter(value: 0.78, unit: '%')));
    expect(number().right, closeTo(320, 0.01));
  });

  testChecked('with any mix of head parts it passes the render self-checks at any width', (WidgetTester tester) async {
    const List<Widget> meters = <Widget>[
      KkMeter(cjk: '出力', en: 'output', value: 0.42, unit: '%', ticks: <String>['0', '50', '100']),
      KkMeter(en: 'output', value: 0.78, unit: 'kPa'),
      KkMeter(cjk: '出力', value: 0.95),
      KkMeter(value: 0.3),
    ];
    // Hugging, side by side.
    await pumpKk(
      tester,
      const KkWrap(gap: 8, cross: KkCrossAlign.start, children: meters),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
    // Filling a column, down to widths where the head no longer fits.
    for (final double width in <double>[0, 40, 120, 200, 300]) {
      await pumpKk(
        tester,
        KkBox(
          width: width,
          child: const KkColumn(gap: 8, shrinkWrap: true, children: meters),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    // On a shared baseline, which measures each one without laying it out.
    await pumpKk(
      tester,
      const KkRow(cross: KkCrossAlign.baseline, gap: 8, children: meters),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty label or unit is laid out like one that is not given', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 300, child: KkMeter(value: 0.5)));
    final Rect number = tester.getRect(find.text('050'));
    final Size size = tester.getSize(find.byType(KkMeter));

    await pumpKk(
      tester,
      const KkBox(
        width: 300,
        child: KkMeter(cjk: '', en: '', value: 0.5, unit: ''),
      ),
    );
    // No line of labels to make the head taller, no gap for a unit after the number.
    expect(tester.getRect(find.text('050')), number);
    expect(tester.getSize(find.byType(KkMeter)), size);
    // Nor a blank in what is said of it.
    final Semantics said = tester.widget(find.descendant(of: find.byType(KkMeter), matching: find.byType(Semantics)));
    expect(said.properties.label, '');
    expect(said.properties.value, '050');
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

  testWidgets('a value that changes with every frame keeps the bar moving', (WidgetTester tester) async {
    double value = 0;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkBox(
            width: 320,
            child: KkMeter(value: value, unit: '%'),
          );
        },
      ),
      motion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    // 0 to 0.9 in 2.88s, a new value with each 16ms frame: three arrive inside every 50ms step.
    const int frames = 180;
    for (int frame = 1; frame <= frames; frame++) {
      rebuild(() => value = 0.9 * frame / frames);
      await tester.pump(const Duration(milliseconds: 16));
      // The bar steps after the value and is never more than 0.65s of rise behind it.
      expect(_bar(tester), lessThanOrEqualTo(value), reason: 'frame $frame');
      expect(value - _bar(tester), lessThan(0.9 / 2.88 * 0.65), reason: 'frame $frame');
    }
    expect(find.text('090'), findsOneWidget);
    expect(_bar(tester), greaterThan(0.7));
    // It ends on the last value no later than one transition after it.
    await tester.pump(const Duration(milliseconds: 450));
    expect(_bar(tester), 0.9);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('odd values and tiny boxes do not throw', (WidgetTester tester) async {
    for (final double v in <double>[-3, 0, 1, 42, double.nan, double.infinity, double.negativeInfinity]) {
      await pumpKk(
        tester,
        KkBox(
          width: 240,
          child: KkMeter(cjk: '負荷', en: 'load', value: v, unit: '%'),
        ),
      );
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
