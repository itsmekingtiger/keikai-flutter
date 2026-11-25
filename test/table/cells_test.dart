import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

/// Pumps [cell] alone, or on a row of the given [level].
Future<void> _pump(WidgetTester tester, Widget cell, {KkLevel? level, KkCondition condition = KkCondition.standby}) {
  return pumpKk(
    tester,
    KkTableRowScope(
      level: level,
      child: KkBox(alignment: Alignment.topLeft, shrinkWrap: true, child: cell),
    ),
    condition: condition,
  );
}

Finder get _painted => find.descendant(of: find.byType(KkTableRowScope), matching: find.byType(CustomPaint));

void main() {
  setUpAll(loadKkFonts);

  group('KkTableLevel', () {
    testWidgets('icon 10, 6px, the word in 11px / 700 / .12em, all in the level colour', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableLevel(level: KkLevel.caution));
      final TextStyle style = styleOf(tester, 'CAUTION');
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, closeTo(1.32, 1e-9));
      expect(style.color, c.caution);
      final Rect glyph = tester.getRect(find.byType(KkGlyph));
      expect(glyph.size, const Size(10, 10));
      expect(tester.getRect(find.text('CAUTION')).left - glyph.right, 6);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).color, c.caution);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, KkLevel.caution);
    });

    testWidgets('without a level it takes the row\'s; without either it is INFO in dim ink', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableLevel(), level: KkLevel.offline);
      expect(styleOf(tester, 'OFFLINE').color, c.offline);
      await _pump(tester, const KkTableLevel());
      expect(styleOf(tester, 'INFO').color, c.inkDim);
      await _pump(tester, const KkTableLevel(level: KkLevel.nominal, text: 'running', showGlyph: false));
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.byType(KkGlyph), findsNothing);
    });

    testWidgets('on a critical row it is ink, icon included', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableLevel(), level: KkLevel.critical);
      expect(styleOf(tester, 'CRITICAL').color, c.ink);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).color, c.ink);
      // Its own level does not bring the colour back.
      await _pump(tester, const KkTableLevel(level: KkLevel.caution), level: KkLevel.critical);
      expect(styleOf(tester, 'CAUTION').color, c.ink);
    });
  });

  group('KkTableCode and KkTableValue', () {
    testWidgets('a code is signal, ink on a critical row', (WidgetTester tester) async {
      await _pump(tester, const KkTableCode('SEC-04'));
      expect(tester.widget<KkText>(find.byType(KkText)).color, KkColors.standby.signal);
      await _pump(tester, const KkTableCode('SEC-04'), level: KkLevel.critical);
      expect(tester.widget<KkText>(find.byType(KkText)).color, KkColors.standby.ink);
      await _pump(tester, const KkTableCode('SEC-04'), condition: KkCondition.alert);
      expect(tester.widget<KkText>(find.byType(KkText)).color, KkColors.alertTheme.signal);
    });

    testWidgets('a value shows its level by colour, weight and, unless nominal, the icon', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableValue('096', level: KkLevel.caution));
      Text text = tester.widget<Text>(find.text('096'));
      expect(text.style!.color, c.caution);
      expect(text.style!.fontWeight, FontWeight.w600);
      final Rect glyph = tester.getRect(find.byType(KkGlyph));
      expect(glyph.size, const Size(10, 10));
      expect(tester.getRect(find.text('096')).left - glyph.right, 4);
      final double flagged = tester.getSize(find.byType(KkTableValue)).width;

      // Nominal: coloured and semibold, no icon, but the icon's place is kept.
      await _pump(tester, const KkTableValue('096', level: KkLevel.nominal));
      text = tester.widget<Text>(find.text('096'));
      expect(text.style!.color, c.nominal);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(find.byType(KkGlyph), findsNothing);
      expect(tester.getSize(find.byType(KkTableValue)).width, flagged);
      expect(tester.getRect(find.text('096')).left, 14);

      // Plain: regular weight, the row's ink.
      await _pump(tester, const KkTableValue('096'));
      text = tester.widget<Text>(find.text('096'));
      expect(text.style!.fontWeight, isNot(FontWeight.w600));
      await _pump(tester, const KkTableValue('096', reserveGlyph: false));
      expect(tester.getRect(find.text('096')).left, 0);

      await _pump(tester, const KkTableValue('096', level: KkLevel.offline), level: KkLevel.critical);
      expect(tester.widget<Text>(find.text('096')).style!.color, c.ink);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).color, c.ink);
    });
  });

  group('KkTableBar', () {
    testWidgets('72 × 6: a signal-dim track lit up to the value', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableBar(0.25));
      expect(tester.getSize(_painted), const Size(72, 6));
      expect(
        _painted,
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 72, 6), color: c.signalDim)
          ..rect(rect: const Rect.fromLTWH(0, 0, 18, 6), color: c.signal),
      );
      await _pump(tester, const KkTableBar(0.5, level: KkLevel.caution));
      expect(
        _painted,
        paints
          ..rect()
          ..rect(rect: const Rect.fromLTWH(0, 0, 36, 6), color: c.caution),
      );
    });

    testWidgets('values outside 0 to 1 are clamped and NaN is empty', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableBar(7));
      expect(
        _painted,
        paints
          ..rect()
          ..rect(rect: const Rect.fromLTWH(0, 0, 72, 6), color: c.signal),
      );
      await _pump(tester, const KkTableBar(-1));
      expect(_painted, paintsExactlyCountTimes(#drawRect, 1));
      await _pump(tester, const KkTableBar(double.nan));
      expect(_painted, paintsExactlyCountTimes(#drawRect, 1));
    });

    testWidgets('on a critical row: ink on a quarter-ink track', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableBar(0.5, level: KkLevel.caution), level: KkLevel.critical);
      expect(
        _painted,
        paints
          ..rect(color: kkMix(c.ink, 0.25, c.alertDeep))
          ..rect(rect: const Rect.fromLTWH(0, 0, 36, 6), color: c.ink),
      );
    });
  });

  group('KkTableMeter', () {
    testWidgets('ten 5 × 10 segments 1px apart, the percentage 6px after them in 11px dim mono', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableMeter(0.72));
      expect(tester.getSize(_painted), const Size(59, 10));
      PaintPattern expected = paints;
      for (int i = 0; i < 10; i++) {
        expected = expected..rect(rect: Rect.fromLTWH(i * 6.0, 0, 5, 10), color: i < 7 ? c.signal : c.signalDim);
      }
      expect(_painted, expected);
      final Rect percent = tester.getRect(find.text('72%'));
      expect(styleOf(tester, '72%').fontSize, 11);
      expect(styleOf(tester, '72%').color, c.inkDim);
      // The text is right-aligned in a box at least 4ch (26.4px) wide.
      expect(percent.right, closeTo(59 + 6 + 26.4, 0.01));
    });

    test('a segment lights only when the value has reached it', () {
      expect(KkTableMeter.litSegments(0, 10), 0);
      expect(KkTableMeter.litSegments(0.09, 10), 0);
      expect(KkTableMeter.litSegments(0.1, 10), 1);
      expect(KkTableMeter.litSegments(0.3, 10), 3);
      expect(KkTableMeter.litSegments(0.7, 10), 7);
      expect(KkTableMeter.litSegments(0.99, 10), 9);
      expect(KkTableMeter.litSegments(1, 10), 10);
      expect(KkTableMeter.litSegments(4, 10), 10);
      expect(KkTableMeter.litSegments(-1, 10), 0);
      expect(KkTableMeter.litSegments(double.nan, 10), 0);
      expect(KkTableMeter.litSegments(0.5, 4), 2);
    });

    testWidgets('level, segment count, label, no percentage, NaN', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableMeter(0.5, segments: 4, level: KkLevel.nominal, showPercent: false));
      expect(tester.getSize(_painted), const Size(23, 10));
      expect(
        _painted,
        paints
          ..rect(color: c.nominal)
          ..rect(color: c.nominal)
          ..rect(color: c.signalDim),
      );
      expect(find.byType(Text), findsNothing);
      await _pump(tester, const KkTableMeter(0.5, label: '5/10'));
      expect(find.text('5/10'), findsOneWidget);
      await _pump(tester, const KkTableMeter(double.nan));
      expect(find.text('--'), findsOneWidget);
      await _pump(tester, const KkTableMeter(3));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('on a critical row: ink segments, ink text', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableMeter(0.2), level: KkLevel.critical);
      expect(
        _painted,
        paints
          ..rect(color: c.ink)
          ..rect(color: c.ink)
          ..rect(color: kkMix(c.ink, 0.22, c.alertDeep)),
      );
      expect(styleOf(tester, '20%').color, c.ink);
    });
  });

  group('KkTableSpark and KkTableSummary', () {
    testWidgets('a sparkline is 80 × 18 and turns ink on a critical row', (WidgetTester tester) async {
      await _pump(tester, const KkTableSpark(<double?>[1, 3, 2, 5]));
      expect(tester.getSize(find.byType(KkSparkline)), const Size(80, 18));
      expect(tester.widget<KkSparkline>(find.byType(KkSparkline)).color, isNull);
      await _pump(tester, const KkTableSpark(<double?>[1, 3, 2, 5], level: KkLevel.caution), level: KkLevel.critical);
      expect(tester.widget<KkSparkline>(find.byType(KkSparkline)).color, KkColors.standby.ink);
      await _pump(tester, const KkTableSpark(<double?>[], width: 40, height: 12));
      expect(tester.getSize(find.byType(KkSparkline)), const Size(40, 12));
    });

    testWidgets('summary: a 9px key 6px before a 12px / 500 value; the title cell is 13 + 10', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await _pump(tester, const KkTableSummary('042.7', label: 'avg'));
      expect(styleOf(tester, 'AVG').fontSize, 9);
      expect(styleOf(tester, 'AVG').fontWeight, FontWeight.w700);
      expect(styleOf(tester, 'AVG').color, c.inkDim);
      expect(styleOf(tester, '042.7').fontSize, 12);
      expect(styleOf(tester, '042.7').fontWeight, FontWeight.w500);
      expect(styleOf(tester, '042.7').color, c.ink);
      expect(tester.getRect(find.text('042.7')).left - tester.getRect(find.text('AVG')).right, 6);
      await _pump(tester, const KkTableSummary('042.7', level: KkLevel.caution));
      expect(styleOf(tester, '042.7').color, c.caution);
      await _pump(tester, const KkTableSummary.title(cjk: '合計', en: 'total'));
      expect(styleOf(tester, '合計').fontSize, 13);
      expect(styleOf(tester, 'TOTAL').fontSize, 10);
      expect(styleOf(tester, 'TOTAL').color, c.inkDim);
    });
  });

  group('rows', () {
    Widget table({
      KkLevel? Function(Pump p)? level,
      double? Function(Pump p)? fill,
      Set<Object>? selected,
      bool numbers = false,
    }) => KkBox(
      width: 600,
      child: KkDataTable<Pump>(
        rows: pumps,
        rowKey: pumpKey,
        rowLevel: level,
        rowFill: fill,
        showRowNumbers: numbers,
        selection: selected == null ? KkTableSelection.none : KkTableSelection.multi,
        selected: selected,
        columns: <KkTableColumn<Pump>>[
          KkTableColumn<Pump>(id: 'id', en: 'id', cell: (BuildContext _, Pump p) => KkTableCode(p.id)),
          nameColumn(),
          flowColumn(),
        ],
      ),
    );

    testWidgets('a row has a 1px bg-200 line under it, turns bg-200 under the pointer and bg-300 when selected', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await pumpKk(tester, table(selected: const <Object>{'P-03'}));
      expect(lookOf(tester, 'P-01').background, isNull);
      expect(lookOf(tester, 'P-01').lineBottom, c.bg200);
      expect(lookOf(tester, 'P-01').lineWidth, 1);
      expect(lookOf(tester, 'P-03').background, c.bg300);
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.text('coolant loop a')));
      await tester.pump();
      expect(lookOf(tester, 'P-01').background, c.bg200);
      expect(lookOf(tester, 'P-02').background, isNull);
      // Selected wins over hover.
      await pointer.moveTo(tester.getCenter(find.text('feed water')));
      await tester.pump();
      expect(lookOf(tester, 'P-01').background, isNull);
      expect(lookOf(tester, 'P-03').background, c.bg300);
      // The row paints its ground, then the line along its bottom edge.
      await pointer.moveTo(tester.getCenter(find.text('coolant loop b')));
      await tester.pump();
      final RenderBox row = rowOf(tester, 'P-02');
      expect(
        row,
        paints
          ..rect(rect: Offset.zero & row.size, color: c.bg200)
          ..rect(rect: Rect.fromLTWH(0, 31, row.size.width, 1), color: c.bg200),
      );
    });

    testWidgets('a progress fill is 18% signal over the ground up to the value; a full row is all fill', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      final Color fill = kkMix(c.signal, 0.18, c.bg100);
      await pumpKk(
        tester,
        table(
          fill: (Pump p) => switch (p.id) {
            'P-01' => 0.25,
            'P-02' => 1,
            'P-03' => double.nan,
            _ => null,
          },
        ),
      );
      expect(lookOf(tester, 'P-01').fillColor, fill);
      expect(lookOf(tester, 'P-01').fill, 0.25);
      expect(lookOf(tester, 'P-01').background, isNull);
      final RenderBox row = rowOf(tester, 'P-01');
      expect(row, paints..rect(rect: Rect.fromLTWH(0, 0, row.size.width * 0.25, 32), color: fill));
      // Full: the whole row, as a ground, so nothing is left to grow.
      expect(lookOf(tester, 'P-02').background, fill);
      expect(lookOf(tester, 'P-02').fillColor, isNull);
      expect(lookOf(tester, 'P-03').fillColor, isNull);
      expect(lookOf(tester, 'P-04').fillColor, isNull);
      // The alert theme has its own fill.
      await pumpKk(tester, table(fill: (Pump p) => 0.5), condition: KkCondition.alert);
      expect(lookOf(tester, 'P-01').fillColor, kkMix(KkColors.alertTheme.signal, 0.18, KkColors.alertTheme.bg100));
    });

    testWidgets('a critical row is on alert-deep whatever else is true of it, and its text is ink', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await pumpKk(
        tester,
        table(level: (Pump p) => p.level, fill: (Pump p) => 0.5, selected: const <Object>{'P-02'}, numbers: true),
      );
      expect(lookOf(tester, 'P-02').background, c.alertDeep);
      expect(lookOf(tester, 'P-02').fillColor, isNull);
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.text('coolant loop b')));
      await tester.pump();
      expect(lookOf(tester, 'P-02').background, c.alertDeep);
      // Code and row number give up their own colours.
      expect(tester.widget<KkText>(find.widgetWithText(KkText, 'P-02')).color, c.ink);
      expect(tester.widget<Text>(inRow('P-02', find.text('02'))).style!.color, c.ink);
      expect(tester.widget<Text>(inRow('P-01', find.text('01'))).style!.color, c.inkDim);
      expect(tester.widget<KkText>(find.widgetWithText(KkText, 'P-01')).color, c.signal);
      // Other levels leave the ground alone.
      expect(lookOf(tester, 'P-03').background, isNull);
      expect(lookOf(tester, 'P-03').fill, 0.5);
    });
  });
}
