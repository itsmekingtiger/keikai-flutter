import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('L layout: stem at the left with its rule, code and Latin over the main line', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkHeading(stem: '設計', code: 'KK-00', en: 'keikai for flutter', main: '警戒'),
    );
    final Rect heading = tester.getRect(find.byType(KkHeading));
    final Rect stem = tester.getRect(find.byType(KkTate));
    final Rect main = tester.getRect(find.text('警戒'));
    final Rect code = tester.getRect(find.text('KK-00'));
    final Rect latin = tester.getRect(find.text('KEIKAI FOR FLUTTER'));
    // Stem: 22px glyphs in a 22.44px column, then 8px, a 2px rule and a 12px gap.
    expect(stem.left, heading.left);
    expect(stem.width, closeTo(22.44, 1e-6));
    expect(stem.height, 44);
    expect(main.left - heading.left, closeTo(22.44 + 8 + 2 + 12, 1e-6));
    expect(code.left, main.left);
    expect(latin.left, greaterThan(code.right));
    // The main line is 64 × 0.92 tall and ends at the bottom of the heading.
    expect(main.height, closeTo(58.88, 0.5));
    expect(main.bottom, closeTo(heading.bottom, 1e-6));
    // The Latin line sits 2px over the main line.
    expect(main.top - latin.bottom, closeTo(2, 0.5));
    // The stem box is as tall as the heading.
    final Rect stemBox = tester.getRect(find.ancestor(of: find.byType(KkTate), matching: find.byType(KkBox)).first);
    expect(stemBox.height, heading.height);
    expect(tester.widget<KkTate>(find.byType(KkTate)).color, KkColors.standby.signal);
    expect(tester.widget<Text>(find.text('警戒')).style!.color, KkColors.standby.ink);
  });

  testWidgets('the stem column grows with the text scale, as its glyphs do', (WidgetTester tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final double scale in <double>[1, 1.3, 2]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await pumpKk(
        tester,
        const KkHeading(stem: '設計言語', code: 'KK-00', en: 'keikai', main: '警戒'),
        padding: const EdgeInsets.all(60),
      );
      final Rect heading = tester.getRect(find.byType(KkHeading));
      final Rect stem = tester.getRect(find.byType(KkTate));
      final double em = 22 * scale;
      // Four glyphs of one em each, centred in a column of 1.02em: none of
      // them reaches out of the heading or into the rule beside it.
      expect(stem.left, heading.left, reason: 'scale $scale');
      expect(stem.height, closeTo(4 * em, 1e-6), reason: 'scale $scale');
      expect(stem.width, closeTo(em * 1.02, 1e-6), reason: 'scale $scale');
      expect(tester.getRect(find.text('警戒')).left - heading.left, closeTo(em * 1.02 + 8 + 2 + 12, 1e-6));
    }
  });

  testWidgets('a stem taller than the lines shares the extra height between the two rows', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkHeading(stem: '設計言語体系', code: 'KK-00', en: 'keikai', main: '警戒'),
    );
    final Rect heading = tester.getRect(find.byType(KkHeading));
    final Rect main = tester.getRect(find.text('警戒'));
    final Rect latin = tester.getRect(find.text('KEIKAI'));
    // Six 22px glyphs.
    expect(heading.height, 132);
    final double rows = latin.height + 2 + main.height;
    final double extra = 132 - rows;
    expect(extra, greaterThan(0));
    expect(latin.top - heading.top, closeTo(extra / 2, 0.01));
    expect(main.bottom, closeTo(heading.bottom, 1e-6));
    expect(main.top - latin.bottom, closeTo(2 + extra / 2, 0.01));
  });

  testWidgets('stacked drops the stem; sizes and colours can be set', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkHeading(
        stem: '設計',
        code: 'SEC-01',
        en: 'power system',
        main: '전원 계통',
        stacked: true,
        mainSize: 44,
        enSize: 14,
        squeeze: 1,
        color: Color(0xFF123456),
        accent: Color(0xFF654321),
      ),
    );
    expect(find.byType(KkTate), findsNothing);
    final Rect heading = tester.getRect(find.byType(KkHeading));
    expect(tester.getRect(find.text('전원 계통')).left, heading.left);
    // 44 × 0.92, rounded to whole pixels by the text engine.
    expect(tester.getRect(find.text('전원 계통')).height, closeTo(44 * 0.92, 1));
    expect(tester.widget<Text>(find.text('전원 계통')).style!.color, const Color(0xFF123456));
    expect(tester.widget<Text>(find.text('SEC-01')).style!.color, const Color(0xFF654321));
    expect(find.byType(KkSqueeze), findsNothing);

    await pumpKk(tester, const KkHeading(main: '冷却'));
    expect(tester.getSize(find.byType(KkHeading)).height, closeTo(58.88, 0.5));
    expect(find.byType(KkSqueeze), findsOneWidget, reason: 'the main line is compressed by default');
  });

  testWidgets('only a stem, long text and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkHeading(stem: '設計言語', main: ''));
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      KkBox(
        width: 60,
        height: 30,
        child: KkHeading(stem: '設計言語' * 4, code: 'KK-00', en: 'keikai for flutter ' * 5, main: '警戒' * 20),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkHeading)).width, lessThanOrEqualTo(60));
  });

  testWidgets('is read as one heading', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkHeading(stem: '設計言語', code: 'KK-00', en: 'keikai for flutter', main: '警戒'),
    );
    expect(find.bySemanticsLabel('設計言語 KK-00 keikai for flutter 警戒'), findsOneWidget);
  });
}
