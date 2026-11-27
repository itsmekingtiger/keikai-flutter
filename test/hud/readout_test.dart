import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

Color? _valueColor(WidgetTester tester, String value) => tester.widget<Text>(find.text(value)).style!.color;

void main() {
  setUpAll(loadKkFonts);

  test('kkFixedDigits pads the integer part and keeps the sign in front', () {
    expect(kkFixedDigits(42.7), '042.7');
    expect(kkFixedDigits(78, decimals: 0), '078');
    expect(kkFixedDigits(0), '000.0');
    expect(kkFixedDigits(-3.25, integers: 2, decimals: 2), '-03.25');
    expect(kkFixedDigits(12345.6), '12345.6');
    expect(kkFixedDigits(9.96), '010.0');
    expect(kkFixedDigits(double.nan), '-----');
    expect(kkFixedDigits(double.infinity, decimals: 0), '---');
  });

  testWidgets('is 208px wide at least and hugs its content in a row', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkWrap(
        gap: 8,
        cross: KkCrossAlign.start,
        children: <Widget>[
          KkReadout(key: ValueKey<int>(0), value: '1'),
          KkReadout(
            key: ValueKey<int>(1),
            cjk: '冷却水温冷却水温',
            en: 'coolant temperature',
            value: '042.7',
            unit: '°C',
            level: KkLevel.nominal,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey<int>(0))).width, 208);
    expect(tester.getSize(find.byKey(const ValueKey<int>(1))).width, greaterThan(208));
    // Both sit on the same line of the wrap.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dy,
      tester.getTopLeft(find.byKey(const ValueKey<int>(1))).dy,
    );
  });

  testWidgets('fills the width it is given', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 400,
        child: KkColumn(
          shrinkWrap: true,
          children: <Widget>[KkReadout(cjk: '水圧', en: 'pressure', value: '094.1', unit: 'kPa', position: 0.5)],
        ),
      ),
    );
    expect(tester.getSize(find.byType(KkReadout)).width, 400);
  });

  testWidgets('lays out head, value, scale and foot on the CSS metrics', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 300,
        child: KkReadout(
          cjk: '冷却水温',
          en: 'coolant temp',
          value: '042.7',
          unit: '°C',
          level: KkLevel.nominal,
          position: 0.42,
          footStart: 'MIN 030.0',
          footEnd: 'MAX 060.0',
          scramble: false,
        ),
      ),
    );
    final Rect box = tester.getRect(find.byType(KkReadout));
    // The head is one 1.55 line of the 14px title (21.7px), plus whatever the
    // Latin subtitle hangs below the shared baseline.
    final double head = tester.getTopLeft(find.text('042.7')).dy - box.top - 2 - 12 - 8;
    expect(head, inInclusiveRange(21.7, 23.0));
    // 2 border + 12 + head + 8 + 32 value + 8 + 6 scale + 8 + 11 foot + 12.
    expect(box.height, closeTo(99 + head, 0.01));
    expect(tester.getTopLeft(find.text('042.7')).dx, box.left + 12);
    expect(tester.getSize(find.text('042.7')).height, 32);
    expect(find.text('NOMINAL'), findsOneWidget);
    expect(find.text('MIN 030.0'), findsOneWidget);
    expect(tester.getTopRight(find.text('MAX 060.0')).dx, box.right - 12);
  });

  testWidgets('the head is its labels and the status word with one gap between each', (WidgetTester tester) async {
    // At the 208px minimum the status word of every level still fits beside the labels.
    for (final KkLevel level in KkLevel.values) {
      await pumpKk(
        tester,
        KkBox(
          width: 208,
          child: KkReadout(cjk: '冷却水温', en: 'coolant temp', value: '042.7', unit: '°C', level: level, scramble: false),
        ),
      );
      final Rect box = tester.getRect(find.byType(KkReadout));
      final Rect state = tester.getRect(find.byType(KkStateWord));
      expect(state.right, closeTo(box.right - 12, 0.01), reason: '$level: pushed to the right edge, nothing cut off');
      expect(state.left - tester.getRect(find.text('COOLANT TEMP')).right, greaterThanOrEqualTo(8), reason: '$level');
    }

    // A readout that hugs a long head is as wide as cjk + 8 + en + 8 + status word inside its 12px padding.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[
          KkReadout(
            cjk: '冷却水温冷却水温',
            en: 'coolant temperature',
            value: '042.7',
            level: KkLevel.nominal,
            scramble: false,
          ),
        ],
      ),
    );
    final Rect cjk = tester.getRect(find.byType(KkSqueeze));
    final Rect en = tester.getRect(find.text('COOLANT TEMPERATURE'));
    final Rect state = tester.getRect(find.byType(KkStateWord));
    expect(en.left - cjk.right, closeTo(8, 0.01));
    expect(state.left - en.right, closeTo(8, 0.01));
    expect(
      tester.getSize(find.byType(KkReadout)).width,
      closeTo(12 + cjk.width + 8 + en.width + 8 + state.width + 12, 0.01),
    );

    // Alone in the head, the status word still sits at the right.
    await pumpKk(
      tester,
      const KkBox(
        width: 300,
        child: KkReadout(value: '042.7', level: KkLevel.caution, scramble: false),
      ),
    );
    expect(tester.getRect(find.byType(KkStateWord)).right, closeTo(300 - 12, 0.01));
  });

  testChecked('with any mix of head parts it passes the render self-checks at any width', (WidgetTester tester) async {
    const List<Widget> readouts = <Widget>[
      KkReadout(cjk: '冷却水温', en: 'coolant temp', value: '042.7', unit: '°C', level: KkLevel.nominal, position: 0.4),
      KkReadout(en: 'coolant temp', value: '042.7', level: KkLevel.caution, footStart: 'MIN 030.0'),
      KkReadout(cjk: '冷却水温', value: '042.7'),
      KkReadout(value: '042.7', level: KkLevel.critical),
      KkReadout(value: '042.7'),
    ];
    // Hugging, side by side.
    await pumpKk(
      tester,
      const KkWrap(gap: 8, cross: KkCrossAlign.start, children: readouts),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
    // Filling a column, down to widths where the head no longer fits.
    for (final double width in <double>[0, 60, 180, 208, 300]) {
      await pumpKk(
        tester,
        KkBox(
          width: width,
          child: const KkColumn(gap: 8, shrinkWrap: true, children: readouts),
        ),
        size: const Size(800, 1000),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    // On a shared baseline, which measures each one without laying it out.
    await pumpKk(
      tester,
      const KkRow(cross: KkCrossAlign.baseline, gap: 8, children: readouts),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('writes the value in the colour of its level', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    final Map<KkLevel?, Color> expected = <KkLevel?, Color>{
      null: c.ink,
      KkLevel.nominal: c.nominal,
      KkLevel.caution: c.caution,
      KkLevel.critical: c.alert,
      KkLevel.offline: c.ink,
    };
    for (final MapEntry<KkLevel?, Color> e in expected.entries) {
      await pumpKk(tester, KkReadout(value: '042.7', level: e.key, scramble: false));
      expect(_valueColor(tester, '042.7'), e.value, reason: '${e.key}');
      final KkDecoration d = tester
          .widget<KkBox>(find.descendant(of: find.byType(KkReadout), matching: find.byType(KkBox)).first)
          .decoration!;
      expect(d.edges.top.width, 2);
      expect(d.edges.top.color, e.key == null ? c.line : c.level(e.key));
      expect(d.edges.bottom.width, 0);
      // The status word shows only with a level.
      expect(find.byType(KkStateWord), e.key == null ? findsNothing : findsOneWidget);
    }
    await pumpKk(tester, const KkReadout(value: '1', state: 'HOLD', scramble: false));
    expect(find.text('HOLD'), findsOneWidget);
    await pumpKk(tester, const KkReadout(value: '1', level: KkLevel.caution, showState: false, scramble: false));
    expect(find.byType(KkStateWord), findsNothing);
  });

  testWidgets('the value scrambles for 0.46s when it changes, then settles', (WidgetTester tester) async {
    String value = '042.7';
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkReadout(cjk: '冷却水温', value: value, boot: false);
        },
      ),
      motion: true,
    );
    // The first showing scrambles too.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('042.7'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('042.7'), findsOneWidget);

    rebuild(() => value = '951.3');
    await tester.pump();
    final Set<String> seen = <String>{};
    for (int i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 46));
      final Text text = tester.widget(find.descendant(of: find.byType(KkScramble), matching: find.byType(Text)));
      final String shown = text.data!;
      seen.add(shown);
      // Same width, same punctuation: only digits churn.
      expect(shown.length, 5);
      expect(shown[3], '.');
      expect(text.semanticsLabel, '951.3');
    }
    expect(seen.length, greaterThan(3), reason: 'the digits change while scrambling');
    expect(seen.contains('951.3'), isFalse);
    // Digits settle from the front: late frames already start with the 9.
    expect(seen.last.startsWith('9'), isTrue);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('951.3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the marker is clamped to the scale; odd input does not throw', (WidgetTester tester) async {
    for (final double position in <double>[-4, 0, 1, 7, double.nan, double.infinity]) {
      await pumpKk(
        tester,
        KkBox(
          width: 240,
          child: KkReadout(value: '0', position: position),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$position');
    }
    await pumpKk(
      tester,
      const KkBox(
        width: 20,
        height: 10,
        child: KkReadout(cjk: '冷却水温', en: 'coolant', value: '042.7', unit: '°C', position: 0.5, footStart: 'a'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
