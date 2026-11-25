import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

import '../support/harness.dart';
import 'util.dart';

void main() {
  setUpAll(loadKkFonts);

  group('KkStat', () {
    testWidgets('shows title, value, unit, state, delta and note', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkStat(
          cjk: '冷却水温',
          en: 'coolant temp',
          value: '042.7',
          unit: '°C',
          level: KkLevel.nominal,
          spark: <double?>[1, 2, 3, 2, 4],
          delta: KkDelta(value: -0.4, tone: KkDeltaTone.good, unit: '°C', period: '1H'),
          note: 'MAX 080.0',
        ),
      );
      expect(find.text('冷却水温'), findsOneWidget);
      expect(find.text('COOLANT TEMP'), findsOneWidget);
      expect(find.text('042.7'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('NOMINAL'), findsOneWidget);
      expect(find.text('0.4°C'), findsOneWidget);
      expect(find.text('1H'), findsOneWidget);
      expect(find.text('MAX 080.0'), findsOneWidget);
      expect(find.byType(KkSparkline), findsOneWidget);
      expect(find.byType(KkGlyph), findsOneWidget);
    });

    testWidgets('has the height the CSS gives it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkStat(cjk: '電源負荷', en: 'power load', value: '078', unit: '%', note: 'LIMIT 085'),
      );
      // 2 border + 10 + head 24.8 + 6 + value 36 + 6 + foot 11..12 + 8 + 1 border.
      expect(tester.getSize(find.byType(KkStat)).height, closeTo(105.5, 1.6));
      expect(tester.getSize(find.byType(KkStat)).width, 800);

      await pumpKk(tester, const KkStat(cjk: '電源負荷', en: 'power load', value: '078'));
      expect(tester.getSize(find.byType(KkStat)).height, closeTo(87.8, 1.2));
    });

    testWidgets('the value takes the level colour', (WidgetTester tester) async {
      Color ink(WidgetTester tester) => tester.widget<Text>(find.text('078')).style!.color!;
      for (final (KkLevel? level, Color color) in <(KkLevel?, Color)>[
        (null, KkColors.standby.ink),
        (KkLevel.nominal, KkColors.standby.nominal),
        (KkLevel.caution, KkColors.standby.caution),
        (KkLevel.critical, KkColors.standby.alert),
        (KkLevel.offline, KkColors.standby.offline),
      ]) {
        await pumpKk(tester, KkStat(en: 'power load', value: '078', level: level));
        expect(ink(tester), color, reason: '$level');
      }
    });

    testWidgets('state can be overridden or hidden', (WidgetTester tester) async {
      await pumpKk(tester, const KkStat(en: 'load', value: '1', level: KkLevel.caution, state: 'rising'));
      expect(find.text('RISING'), findsOneWidget);
      expect(find.text('CAUTION'), findsNothing);
      await pumpKk(tester, const KkStat(en: 'load', value: '1', level: KkLevel.caution, showState: false));
      expect(find.text('CAUTION'), findsNothing);
      expect(find.byType(KkGlyph), findsNothing);
      await pumpKk(tester, const KkStat(en: 'load', value: '1'));
      expect(find.byType(KkGlyph), findsNothing);
    });

    testWidgets('fills a fixed-height parent and spreads its rows', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 160,
          child: KkStat(cjk: '電源負荷', en: 'power load', value: '078', note: 'LIMIT 085'),
        ),
      );
      expect(tester.getSize(find.byType(KkStat)), const Size(300, 160));
      final double valueTop = tester.getTopLeft(find.text('078')).dy;
      final double noteBottom = tester.getBottomLeft(find.text('LIMIT 085')).dy;
      expect(noteBottom, closeTo(160 - 8 - 1, 1.5));
      expect(valueTop > 50, isTrue, reason: 'the value sits in the middle, not under the head');
    });

    testWidgets('the value scrambles on entry and settles', (WidgetTester tester) async {
      await pumpKk(tester, const KkStat(en: 'load', value: '0427'), motion: true);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('0427'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('0427'), findsOneWidget);
      // A new value scrambles again.
      await tester.pumpWidget(kkHarness(const KkStat(en: 'load', value: '0731'), motion: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('0731'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('0731'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('scramble: false shows the value at once', (WidgetTester tester) async {
      await pumpKk(tester, const KkStat(en: 'load', value: '0427', scramble: false), motion: true);
      expect(find.text('0427'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('long titles are cut, not overflowed', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 140,
          child: KkStat(
            cjk: '冷却水温冷却水温冷却水温',
            en: 'a very long latin subtitle that cannot fit',
            value: '123456789012',
            unit: 'units',
            level: KkLevel.critical,
            spark: <double?>[1, 2, 3],
            delta: KkDelta(value: 123456.789, unit: 'units', period: 'PERIOD'),
            note: 'A VERY LONG NOTE THAT CANNOT FIT',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkStat)).width, 140);
    });
  });

  group('KkDelta', () {
    testWidgets('arrow follows the sign, colour follows the tone', (WidgetTester tester) async {
      await pumpKk(tester, const KkDelta(value: 2.4, tone: KkDeltaTone.good, unit: '%'));
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.caretUp);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.nominal);
      expect(find.text('2.4%'), findsOneWidget);

      await pumpKk(tester, const KkDelta(value: -12.5, tone: KkDeltaTone.bad, unit: '%', period: '24H'));
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.caretDown);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.alert);
      expect(find.text('12.5%'), findsOneWidget);
      expect(find.text('24H'), findsOneWidget);

      await pumpKk(tester, const KkDelta(value: 0));
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.minus);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.inkDim);
    });

    testWidgets('formatter and non-finite values', (WidgetTester tester) async {
      await pumpKk(tester, KkDelta(value: -1500, format: (double v) => '${(v / 1000).toStringAsFixed(1)}K'));
      expect(find.text('1.5K'), findsOneWidget);
      await pumpKk(tester, const KkDelta(value: double.nan, unit: '%'));
      expect(find.text('--'), findsOneWidget);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.minus);
    });
  });

  group('KkSparkline', () {
    testWidgets('is 64 x 32 when free and takes a given size', (WidgetTester tester) async {
      await pumpKk(tester, const KkRow(children: <Widget>[KkSparkline(values: <double?>[1, 3, 2])]));
      expect(tester.getSize(find.byType(KkSparkline)), const Size(64, 32));
      await pumpKk(tester, const KkSparkline(values: <double?>[1, 3, 2], width: 80, height: 18));
      expect(tester.getSize(find.byType(KkSparkline)), const Size(80, 18));
    });

    testWidgets('survives empty, single, flat and broken data at any size', (WidgetTester tester) async {
      const List<List<double?>> data = <List<double?>>[
        <double?>[],
        <double?>[5],
        <double?>[5, 5, 5, 5],
        <double?>[null, null],
        <double?>[double.nan, 1, double.infinity, 2, null, 3],
        <double?>[1e300, -1e300, 0],
      ];
      for (final List<double?> values in data) {
        for (final Size size in const <Size>[Size.zero, Size(1, 1), Size(20, 20), Size(300, 40)]) {
          await pumpKk(
            tester,
            KkSparkline(values: values, width: size.width, height: size.height, reference: 2, min: 0, max: 4),
          );
          expect(tester.takeException(), isNull, reason: '$values at $size');
        }
      }
    });

    testWidgets('wipes in with motion on', (WidgetTester tester) async {
      await pumpKk(tester, const KkSparkline(values: <double?>[1, 3, 2, 5], width: 100, height: 30), motion: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantic label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkSparkline(values: <double?>[1, 3, 2], semanticLabel: 'load trend'));
      expect(find.bySemanticsLabel('load trend'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('freeHeight helper keeps charts at their natural height', (WidgetTester tester) async {
    await pumpKk(tester, freeHeight(const KkStat(en: 'load', value: '1')));
    expect(tester.getSize(find.byType(KkStat)).height, lessThan(100));
  });
}
