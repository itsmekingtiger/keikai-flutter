import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/log_screen.dart';
import 'app_harness.dart';

List<KkLogEntry> _entries(WidgetTester tester) => tester.widget<KkDataLog>(find.byType(KkDataLog)).entries;

Finder _chip(String word) =>
    find.byWidgetPredicate((Widget w) => w is KkChip && w.label.startsWith('$word '), description: 'the $word chip');

/// Chooses a preset of the time range.
Future<void> _preset(WidgetTester tester, String label) async {
  await tester.tap(find.byWidgetPredicate((Widget w) => w is KkSelect, description: 'the preset select'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the log lays out and follows the plant', '/log', (WidgetTester tester, Rig rig, Size size) async {
    expect(find.byType(LogScreen), findsOneWidget);
    expect(find.byType(KkTimeRange<Duration>), findsOneWidget);
    expect(find.byType(KkBarChart), findsOneWidget);
    expect(find.byType(KkCategoryBar), findsOneWidget);
    final int before = _entries(tester).length;
    expect(before, greaterThanOrEqualTo(8));
    // Live: a new line of the plant shows up.
    rig.station.assignSector(rig.station.sectors[5], 'OP-01');
    await tester.pump();
    expect(_entries(tester).length, before + 1);
    expect(_entries(tester).last.message, 'ASSIGNED TO OP-01');
  });

  runsWithMotion('the log runs with motion on', '/log');

  testWidgets('the level chips hide and show their lines', (WidgetTester tester) async {
    await pumpApp(tester, route: '/log');
    final int all = _entries(tester).length;
    final int nominal = _entries(tester).where((KkLogEntry e) => e.level == KkLevel.nominal).length;
    expect(nominal, greaterThan(0));
    await tester.tap(_chip('NOMINAL'));
    await tester.pump();
    expect(_entries(tester).length, all - nominal);
    expect(_entries(tester).any((KkLogEntry e) => e.level == KkLevel.nominal), isFalse);
    await tester.tap(_chip('NOMINAL'));
    await tester.pump();
    expect(_entries(tester).length, all);

    // With every chip off nothing passes: the empty state offers the way back.
    for (final String word in <String>['INFO', 'NOMINAL', 'CAUTION', 'CRITICAL', 'OFFLINE']) {
      await tester.tap(_chip(word));
      await tester.pump();
    }
    expect(find.byType(KkDataLog), findsNothing);
    expect(find.text('NO LINES MATCH'), findsOneWidget);
    expect(tester.widget<KkButton>(button('export')).onPressed, isNull);
    await tester.tap(button('clear filters'));
    await tester.pump();
    expect(_entries(tester).length, all);
    expectClean(tester, 'chips');
  });

  testWidgets('search narrows by source and by message', (WidgetTester tester) async {
    await pumpApp(tester, route: '/log');
    await tester.enterText(find.byType(EditableText).first, 'sec-09');
    await tester.pumpAndSettle();
    expect(_entries(tester), isNotEmpty);
    expect(_entries(tester).every((KkLogEntry e) => e.source == 'SEC-09'), isTrue);
    await tester.enterText(find.byType(EditableText).first, 'heartbeat');
    await tester.pumpAndSettle();
    expect(_entries(tester).every((KkLogEntry e) => e.message.contains('HEARTBEAT')), isTrue);
    expect(tester.widget<KkButton>(button('clear')).onPressed, isNotNull);
    await tester.tap(button('clear'));
    await tester.pumpAndSettle();
    expect(_entries(tester).length, greaterThanOrEqualTo(8));
    expect(tester.widget<KkButton>(button('clear')).onPressed, isNull, reason: 'nothing left to clear');
    expectClean(tester, 'search');
  });

  testWidgets('a preset reloads the log behind skeleton lines and narrows the range', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/log');
    await tick(tester, rig, 3);
    final int inQuarter = _entries(tester).length;
    await tester.tap(find.byWidgetPredicate((Widget w) => w is KkSelect, description: 'the preset select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LAST 1 MIN').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(KkSkeleton), findsNWidgets(3));
    expect(find.byType(KkDataLog), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byType(KkSkeleton), findsNothing);
    final DateTime from = rig.station.now.subtract(const Duration(minutes: 1));
    final int expected = rig.station.log.where((l) => !l.time.isBefore(from)).length;
    expect(_entries(tester).length, expected);
    expect(expected, lessThan(inQuarter));

    await _preset(tester, 'ALL');
    expect(_entries(tester).length, rig.station.log.length);

    // A stretch with nothing in it says so and offers the whole log.
    rig.station.log.removeWhere((l) => !l.time.isBefore(rig.station.now.subtract(const Duration(minutes: 1))));
    await _preset(tester, 'LAST 1 MIN');
    expect(find.text('NO LINES IN RANGE'), findsOneWidget);
    await tester.tap(button('show all'));
    await tester.pumpAndSettle();
    expect(_entries(tester).length, rig.station.log.length);
    expectClean(tester, 'presets');
  });

  testWidgets('Refresh reloads; LIVE off freezes the end of the range', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/log');
    await tester.tap(iconButton('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(KkSkeleton), findsWidgets);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(KkDataLog), findsOneWidget);

    KkTimeRange<Duration> range() => tester.widget<KkTimeRange<Duration>>(find.byType(KkTimeRange<Duration>));
    expect(range().live, isTrue);
    await tester.tap(find.text('LIVE'));
    await tester.pump();
    expect(range().live, isFalse);
    final DateTime frozen = range().end!;
    final int shown = _entries(tester).length;
    await tick(tester, rig);
    rig.station.assignSector(rig.station.sectors[5], 'OP-01');
    await tick(tester, rig, 2);
    expect(range().end, frozen);
    expect(_entries(tester).length, shown, reason: 'lines after the frozen end stay out');
    await tester.tap(find.text('LIVE'));
    await tester.pump();
    expect(range().end, rig.station.now);
    expect(_entries(tester).length, greaterThan(shown));
    expectClean(tester, 'live');
  });

  testWidgets('Export reports what it wrote; a line opens in a dialog', (WidgetTester tester) async {
    await pumpApp(tester, route: '/log');
    final int lines = _entries(tester).length;
    await tester.tap(button('export'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(KkSnackbar),
        matching: find.text('EXPORTED ${kkFixed(lines, digits: 3)} LINES · LOG-2026-11-24.CSV'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('LINK CH.12 RESYNC'));
    await tester.pumpAndSettle();
    final KkDialog dialog = tester.widget<KkDialog>(find.byType(KkDialog));
    expect(dialog.code, startsWith('LOG-'));
    expect(find.descendant(of: find.byType(KkDialog), matching: find.text('LINK CH.12 RESYNC')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // the Close button has the focus
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'export');
  });

  testWidgets('the chart counts the lines of each minute and colours the worst', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/log');
    await raiseIncident(tester, rig);
    final KkBarChart chart = tester.widget<KkBarChart>(find.byType(KkBarChart));
    expect(chart.labels, hasLength(8));
    expect(chart.labels.last, '14:02');
    final double total = chart.series.single.values.fold<double>(0, (double a, double? b) => a + (b ?? 0));
    final DateTime from = DateTime.utc(2026, 11, 24, 13, 55);
    expect(total, rig.station.log.where((l) => !l.time.isBefore(from)).length);
    expect(chart.levels!.last, KkLevel.critical);
    expectClean(tester, 'chart');
  });
}
