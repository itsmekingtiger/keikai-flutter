import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

DateTime _clock() => DateTime.utc(2026, 11, 24, 14, 2, 31);

Widget _bar({KkLevel? level, bool follow = false, VoidCallback? onId, String? cjk = '平時', String? en = 'standby'}) {
  return KkCommandBar(
    name: 'keikai',
    node: 'HQ-03 · NODE 07',
    conditionCjk: follow ? null : cjk,
    conditionEn: follow ? null : en,
    level: level,
    followCondition: follow,
    onIdPressed: onId,
    cells: const <Widget>[
      KkCommandCell(label: 'sector', value: 'SEC-04'),
      KkCommandCell(label: 'uptime', value: '076:17:42'),
      KkCommandCell(label: 'utc', child: KkClock(clock: _clock)),
    ],
  );
}

void main() {
  setUpAll(loadKkFonts);

  testWidgets('is 48px high, full width, with the name upper-cased', (WidgetTester tester) async {
    await pumpKk(tester, _bar(), size: const Size(1000, 300));
    expect(tester.getSize(find.byType(KkCommandBar)), const Size(1000, 48));
    expect(find.text('KEIKAI'), findsOneWidget);
    expect(find.text('HQ-03 · NODE 07'), findsOneWidget);
    expect(find.text('CONDITION'), findsOneWidget);
    expect(find.text('平時'), findsOneWidget);
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.text('SECTOR'), findsOneWidget);
    expect(find.text('SEC-04'), findsOneWidget);
    expect(find.text('UPTIME'), findsOneWidget);
    expect(find.text('UTC'), findsOneWidget);
    expect(find.byType(KkClock), findsOneWidget);
    expect(find.byType(KkHazard), findsNothing);
  });

  testWidgets('cells are 44px high (the bar less its 4px line) and sit at the right', (WidgetTester tester) async {
    await pumpKk(tester, _bar(), size: const Size(1000, 300));
    final Finder cells = find.byType(KkCommandCell);
    expect(cells, findsNWidgets(3));
    for (int i = 0; i < 3; i++) {
      expect(tester.getSize(cells.at(i)).height, 44);
    }
    expect(tester.getTopRight(cells.at(2)).dx, 1000);
    // In reading order.
    expect(tester.getTopLeft(cells.at(0)).dx, lessThan(tester.getTopLeft(cells.at(1)).dx));
  });

  testWidgets('at 600px of its own width and below it hides the caption and all cells but the last', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _bar(), size: const Size(601, 300));
    expect(find.text('CONDITION'), findsOneWidget);
    expect(find.byType(KkCommandCell), findsNWidgets(3));

    await pumpKk(tester, _bar(), size: const Size(600, 300));
    expect(find.text('CONDITION'), findsNothing);
    expect(find.byType(KkCommandCell), findsOneWidget);
    expect(find.text('UTC'), findsOneWidget);
    expect(find.text('SECTOR'), findsNothing);
    // The condition itself stays.
    expect(find.text('平時'), findsOneWidget);
    expect(find.text('STANDBY'), findsOneWidget);
  });

  testWidgets('the compact rule follows the bar, not the window', (WidgetTester tester) async {
    await pumpKk(tester, KkBox(width: 560, child: _bar()), size: const Size(1200, 300));
    expect(find.text('CONDITION'), findsNothing);
    expect(find.byType(KkCommandCell), findsOneWidget);
  });

  testWidgets('critical fills the condition block and adds a 24px hazard strip', (WidgetTester tester) async {
    await pumpKk(tester, _bar(level: KkLevel.critical, cjk: '警報', en: 'alert'), size: const Size(1000, 300));
    final Finder hazard = find.byType(KkHazard);
    expect(hazard, findsOneWidget);
    expect(tester.getSize(hazard), const Size(24, 44));
    expect(tester.widget<KkHazard>(hazard).running, isTrue);
    const KkColors c = KkColors.standby;
    expect(tester.widget<Text>(find.text('ALERT')).style!.color, c.onFill);
    expect(tester.widget<Text>(find.text('CONDITION')).style!.color, c.onFill);
  });

  testWidgets('followCondition shows the condition of the theme', (WidgetTester tester) async {
    await pumpKk(tester, _bar(follow: true), size: const Size(1000, 300));
    expect(find.text('平時'), findsOneWidget);
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.byType(KkHazard), findsNothing);

    await pumpKk(tester, _bar(follow: true), size: const Size(1000, 300), condition: KkCondition.alert);
    expect(find.text('警報'), findsOneWidget);
    expect(find.text('ALERT'), findsOneWidget);
    expect(find.byType(KkHazard), findsOneWidget);
  });

  testWidgets('without condition text there is no condition block', (WidgetTester tester) async {
    await pumpKk(tester, _bar(cjk: null, en: null), size: const Size(1000, 300));
    expect(find.text('CONDITION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the identity block is a button when onIdPressed is given', (WidgetTester tester) async {
    int taps = 0;
    await pumpKk(tester, _bar(onId: () => taps++), size: const Size(1000, 300));
    await tester.tap(find.text('KEIKAI'));
    expect(taps, 1);
  });

  testWidgets('leading and trailing slots are laid out at the two ends', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkCommandBar(
        name: 'keikai',
        leading: KkBox(key: ValueKey<String>('lead'), width: 32, height: 32),
        trailing: KkBox(key: ValueKey<String>('trail'), width: 32, height: 32),
        cells: <Widget>[KkCommandCell(label: 'utc', value: '14:02:31Z')],
      ),
      size: const Size(1000, 300),
    );
    final Rect lead = tester.getRect(find.byKey(const ValueKey<String>('lead')));
    final Rect trail = tester.getRect(find.byKey(const ValueKey<String>('trail')));
    expect(lead.left, 8);
    expect(lead.center.dy, 22);
    expect(trail.right, 1000 - 8);
    expect(tester.getTopLeft(find.text('KEIKAI')).dx, greaterThan(lead.right));
  });

  testWidgets('survives a tiny width, a long name and both themes', (WidgetTester tester) async {
    for (final KkCondition condition in KkCondition.values) {
      for (final double width in <double>[0, 20, 120, 320]) {
        await pumpKk(
          tester,
          KkBox(
            width: width,
            child: const KkCommandBar(
              name: 'a very long system name that cannot possibly fit',
              node: 'NODE WITH A VERY LONG DESCRIPTION 0123456789',
              conditionCjk: '冷却系統異常警報',
              conditionEn: 'coolant system abnormal',
              level: KkLevel.critical,
              cells: <Widget>[KkCommandCell(label: 'x', value: '000000000000000000000000')],
            ),
          ),
          condition: condition,
        );
        expect(tester.takeException(), isNull, reason: 'width $width in $condition');
      }
    }
  });
}
