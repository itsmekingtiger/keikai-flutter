import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/systems_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/sector_detail.dart';
import 'app_harness.dart';

/// A window where the sectors are a list: under 840px of body width.
const Size _narrow = Size(720, 900);

// ── the list ────────────────────────────────────────────────────────────────

/// The sector codes of the list rows on screen, top to bottom.
List<String> _rows(WidgetTester tester) => <String>[
  for (final KkListRow row in tester.widgetList<KkListRow>(find.byType(KkListRow))) row.en!.substring(0, 6),
];

Finder _segment(String label) => find.descendant(
  of: find.byWidgetPredicate((Widget w) => w is KkSegmented, description: 'the status switch'),
  matching: find.text(label),
);

// ── the table ───────────────────────────────────────────────────────────────

Finder _table() => find.byType(KkDataTable<Sector>);

Finder _inTable(Finder what) => find.descendant(of: _table(), matching: what);

/// The sector codes of the table rows on screen, top to bottom.
List<String> _codes(WidgetTester tester) {
  final List<(double, String)> found = <(double, String)>[];
  for (final Element e in _inTable(find.byType(KkTableCode)).evaluate()) {
    found.add((tester.getTopLeft(find.byWidget(e.widget)).dy, (e.widget as KkTableCode).text));
  }
  found.sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) f in found) f.$2];
}

/// The cells of the row of [code].
Finder _row(String code) => find
    .ancestor(
      of: _inTable(find.byWidgetPredicate((Widget w) => w is KkTableCode && w.text == code)),
      matching: find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == 'KkTableCells'),
    )
    .first;

Finder _inRow(String code, Finder what) => find.descendant(of: _row(code), matching: what);

Finder _check(String code) => _inRow(code, find.byType(KkCheckbox));

Finder _expander(String code) => _inRow(code, find.byType(KkIconButton));

/// The button of the selection band that reads [label].
Finder _bulk(String label) => _inTable(find.text(label));

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the sectors lay out and follow the plant', '/systems', (
    WidgetTester tester,
    Rig rig,
    Size size,
  ) async {
    expect(find.byType(SystemsScreen), findsOneWidget);
    expect(find.byType(KkStatusTimeline), findsOneWidget);
    expect(find.byType(KkCarousel), findsOneWidget);
    expect(find.byType(KkDataTable<Channel>), findsOneWidget);
    final Sector first = rig.station.sectors.first;
    // A table from 840px of body width (a 944px window), a list below that.
    if (size.width >= 944) {
      expect(_table(), findsOneWidget);
      expect(find.byType(KkList), findsNothing);
      expect(_codes(tester), <String>[for (final Sector s in rig.station.sectors.take(8)) s.code]);
      // Wide enough for every column: nothing scrolls sideways.
      final Rect table = tester.getRect(_table());
      final Rect state = tester.getRect(_inRow('SEC-01', find.byType(KkTableLevel)));
      expect(state.right, lessThanOrEqualTo(table.right));
      // Under it: the history beside the channels and the feeds.
      final Rect history = tester.getRect(find.byType(KkStatusTimeline));
      final Rect channels = tester.getRect(find.byType(KkDataTable<Channel>));
      expect(history.top, greaterThan(table.bottom));
      expect(channels.left, greaterThan(history.right));
      // Live: the load cell of a row says what the sector's load is.
      first.load = 91;
      await tick(tester, rig);
      expect(_inRow('SEC-01', find.text('${kkFixed(first.load, digits: 3)}%')), findsOneWidget);
    } else {
      expect(_table(), findsNothing);
      expect(find.byType(KkListRow), findsNWidgets(12));
      final Rect list = tester.getRect(find.byType(KkList));
      expect(tester.getRect(find.byType(KkStatusTimeline)).top, greaterThan(list.bottom));
      final String before = tester.widget<KkListRow>(find.byType(KkListRow).first).meta!;
      first.load = 91;
      await tick(tester, rig);
      final KkListRow row = tester.widget<KkListRow>(find.byType(KkListRow).first);
      expect(row.meta, isNot(before));
      expect(row.meta, startsWith(kkFixed(first.load, digits: 3)));
    }
  });

  runsWithMotion('the sectors run with motion on', '/systems');

  group('table', () {
    testWidgets('a header sorts by its column: up, down, off again', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final List<String> plant = <String>[for (final Sector s in rig.station.sectors) s.code];
      expect(_codes(tester), plant.take(8));

      await tester.tap(_inTable(find.text('LOAD')));
      await tester.pumpAndSettle();
      final List<Sector> up = rig.station.sectors.where((Sector s) => s.level != KkLevel.offline).toList()
        ..sort((Sector a, Sector b) => a.load.compareTo(b.load));
      expect(_codes(tester), <String>[for (final Sector s in up.take(8)) s.code]);

      await tester.tap(_inTable(find.text('LOAD')));
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>[for (final Sector s in up.reversed.take(8)) s.code]);
      // The isolated sector has no load: it is last whichever way the column runs.
      await tester.tap(find.bySemanticsLabel('Last page'));
      await tester.pumpAndSettle();
      expect(_codes(tester).last, 'SEC-12');

      await tester.tap(_inTable(find.text('LOAD')));
      await tester.pumpAndSettle();
      expect(_codes(tester), plant.skip(8), reason: 'unsorted again, still on the second page');

      // By state: the worst first.
      await tester.tap(_inTable(find.text('STATE')));
      await tester.pumpAndSettle();
      await tester.tap(_inTable(find.text('STATE')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('First page'));
      await tester.pumpAndSettle();
      expect(_codes(tester).take(2), <String>['SEC-08', 'SEC-12']);
      expectClean(tester, 'sorting');
    });

    testWidgets('the filter field narrows the rows; what it leaves out comes back with Clear', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, route: '/systems');
      final Finder field = _inTable(find.byType(EditableText));
      await tester.enterText(field, 'coolant');
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-04']);
      expect(find.text('01 / 12 SHOWN'), findsOneWidget);
      // The history under the table follows the filter.
      expect(tester.widget<KkStatusTimeline>(find.byType(KkStatusTimeline)).rows, hasLength(1));

      await tester.enterText(field, 'op-02');
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-07', 'SEC-08']);

      await tester.enterText(field, 'zzz');
      await tester.pumpAndSettle();
      expect(_codes(tester), isEmpty);
      expect(_inTable(find.text('NO SECTOR MATCHES')), findsOneWidget);
      expect(find.byType(KkStatusTimeline), findsNothing);
      await tester.tap(_inTable(button('clear filters')));
      await tester.pumpAndSettle();
      expect(_codes(tester), hasLength(8));
      expect(tester.widget<EditableText>(field).controller.text, isEmpty);
      expectClean(tester, 'filter');
    });

    testWidgets('the status switch and the operator chips choose the rows the table gets', (WidgetTester tester) async {
      await pumpApp(tester, route: '/systems');
      await tester.tap(_segment('OFFLINE'));
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-12']);
      expect(tester.widget<KkDataTable<Sector>>(_table()).meta, '01 OF 12');
      await tester.tap(_segment('TROUBLE'));
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-08']);
      await tester.tap(_segment('ALL'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: find.byType(KkChip), matching: find.text('OP-07')));
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-04', 'SEC-05']);
      await tester.tap(find.descendant(of: find.byType(KkChip), matching: find.text('OP-01')));
      await tester.pumpAndSettle();
      expect(_codes(tester), <String>['SEC-04', 'SEC-05', 'SEC-09', 'SEC-10']);
      // The summary row counts and averages what is shown.
      expect(_inTable(find.text('04 SECTORS')), findsOneWidget);
      await tester.tap(button('clear'));
      await tester.pumpAndSettle();
      expect(_codes(tester), hasLength(8));
      expect(tester.widget<KkButton>(button('clear')).onPressed, isNull);
      expectClean(tester, 'choosing');
    });

    testWidgets('eight rows to a page; the pager and the page size move through all twelve', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final List<String> plant = <String>[for (final Sector s in rig.station.sectors) s.code];
      expect(_inTable(find.text('001–008 / 012')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pumpAndSettle();
      expect(_codes(tester), plant.skip(8));
      expect(_inTable(find.text('009–012 / 012')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous page'));
      await tester.pumpAndSettle();
      expect(_codes(tester), plant.take(8));

      // Twelve to a page: all of them at once.
      await tester.tap(
        _inTable(find.byWidgetPredicate((Widget w) => w is KkSelect<int>, description: 'rows per page')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('12').last);
      await tester.pumpAndSettle();
      expect(_codes(tester), plant);
      expectClean(tester, 'paging');
    });

    testWidgets('selected rows get a band: acknowledge, assign, and isolate after a second press', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final Sector storage = rig.station.sectors[2];
      final Sector relay = rig.station.sectors[7];
      expect(_bulk('ACKNOWLEDGE'), findsNothing);

      await tester.tap(_check('SEC-03'));
      await tester.pump();
      await tester.tap(_check('SEC-08'));
      await tester.pump();
      expect(find.bySemanticsLabel('2 rows selected'), findsOneWidget);
      expect(tester.widget<KkCheckbox>(_check('SEC-08')).value, isTrue);

      // Acknowledge: only the relay has something to acknowledge.
      await tester.tap(_bulk('ACKNOWLEDGE'));
      await tester.pumpAndSettle();
      expect(relay.acknowledged, isTrue);
      expect(storage.acknowledged, isFalse);
      expect(
        find.descendant(of: find.byType(KkSnackbar), matching: find.text('ACKNOWLEDGED 01 SECTORS')),
        findsOneWidget,
      );
      expect(_inRow('SEC-08', find.text('CAUTION · ACK')), findsOneWidget);
      expect(_bulk('ACKNOWLEDGE'), findsNothing, reason: 'the selection is given back');

      // Assign: both change hands.
      await tester.tap(_check('SEC-03'));
      await tester.pump();
      await tester.tap(_check('SEC-08'));
      await tester.pump();
      await tester.tap(_bulk('ASSIGN TO ME'));
      await tester.pumpAndSettle();
      expect(storage.operator, 'OP-07');
      expect(relay.operator, 'OP-07');
      expect(_inRow('SEC-03', find.text('OP-07')), findsOneWidget);

      // Isolate: the first press only arms the button.
      await tester.tap(_check('SEC-03'));
      await tester.pump();
      await tester.tap(_bulk('ISOLATE'));
      await tester.pump();
      expect(storage.level, KkLevel.nominal);
      expect(find.bySemanticsLabel('confirm isolate isolate'), findsOneWidget);
      await tester.tap(_bulk('CONFIRM ISOLATE'));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.offline);
      expect(_inRow('SEC-03', find.text('OFFLINE')), findsOneWidget);
      expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('ISOLATED 01 SECTORS')), findsOneWidget);

      // An armed button that is left alone disarms itself.
      await tester.tap(_check('SEC-05'));
      await tester.pump();
      await tester.tap(_bulk('ISOLATE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.bySemanticsLabel('confirm isolate isolate'), findsNothing);
      expect(rig.station.sectors[4].level, KkLevel.nominal);
      await tester.tap(find.bySemanticsLabel('Clear selection'));
      await tester.pump();
      expect(_bulk('ISOLATE'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'selection band');
    });

    testWidgets('a row opens to its detail: what the row has no room for, and what to do about it', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final Sector relay = rig.station.sectors[7];
      expect(find.bySemanticsLabel('Expand row'), findsNWidgets(8));
      await tester.tap(_expander('SEC-08'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Collapse row'), findsOneWidget);
      expect(_inTable(find.text('CH.12 RESYNC')), findsWidgets);
      // How long it has been in caution, counted back through its history.
      final int run = relay.history.reversed.takeWhile((KkLevel l) => l == KkLevel.caution).length;
      expect(run, inInclusiveRange(1, Station.historyLength - 1));
      expect(
        _inTable(
          find.text(
            'LOAD ${kkFixed(relay.load, digits: 3)} % OF LIMIT 070 % · '
            'TEMPERATURE ${rig.settings.temperature(relay.temp)} °C · CAUTION FOR ${kkFixed(run, digits: 2)} S',
          ),
        ),
        findsOneWidget,
      );

      // Assign from the detail.
      expect(relay.operator, 'OP-02');
      await tester.tap(_inTable(button('assign to me')));
      await tester.pumpAndSettle();
      expect(relay.operator, 'OP-07');
      expect(tester.widget<KkButton>(_inTable(button('assigned'))).onPressed, isNull);

      // Isolate asks first, as it does in the sheet; then the detail offers Restore.
      await tester.tap(_inTable(button('isolate')));
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(KkDialog), matching: button('isolate')));
      await tester.pumpAndSettle();
      expect(relay.level, KkLevel.offline);
      await tester.tap(_inTable(button('restore')));
      await tester.pumpAndSettle();
      expect(relay.level, KkLevel.nominal);

      await tester.tap(_expander('SEC-08'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Collapse row'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'detail row');
    });

    testWidgets('a press on a row opens the sector sheet', (WidgetTester tester) async {
      await pumpApp(tester, route: '/systems');
      await tester.tap(_inRow('SEC-03', find.text('蓄電 STORAGE')));
      await tester.pumpAndSettle();
      expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-03');
      expect(tester.widget<KkCheckbox>(_check('SEC-03')).value, isFalse, reason: 'a press does not select');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SectorSheet), findsNothing);
      expectClean(tester, 'row press');
    });

    testWidgets('the load limit is edited in its cell: Enter takes it, a wrong one is refused', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final Sector power = rig.station.sectors.first;
      power.load = 64;
      await tester.pump();
      expect(power.limit, 70);
      expect(power.loadLevel, KkLevel.nominal);

      Finder editor() => _inRow('SEC-01', find.byType(EditableText));
      await tester.tap(_inRow('SEC-01', find.text('070')));
      await tester.pumpAndSettle();
      expect(editor(), findsOneWidget);
      expect(tester.widget<EditableText>(editor()).controller.text, '70');

      // Not a number, then out of range: the editor stays open and the limit stays.
      // (Enter reaches a text field as its "done" action.)
      await tester.enterText(editor(), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(editor(), findsOneWidget);
      expect(power.limit, 70);
      await tester.enterText(editor(), '95');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(editor(), findsOneWidget);
      expect(power.limit, 70);

      // A good one: the limit moves, the log says so, and the load is now over it.
      await tester.enterText(editor(), '55');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(editor(), findsNothing);
      expect(power.limit, 55);
      expect(_inRow('SEC-01', find.text('055')), findsOneWidget);
      expect(rig.station.log.last.message, 'LOAD LIMIT SET TO 055 %');
      expect(power.loadLevel, KkLevel.caution);
      expect(tester.widget<KkTableMeter>(_inRow('SEC-01', find.byType(KkTableMeter))).level, KkLevel.caution);

      // Escape leaves it as it was.
      await tester.tap(_inRow('SEC-01', find.text('055')));
      await tester.pumpAndSettle();
      await tester.enterText(editor(), '20');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(editor(), findsNothing);
      expect(power.limit, 55);
      // An isolated sector has no limit to set.
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pumpAndSettle();
      await tester.tap(_inRow('SEC-12', find.text('070')));
      await tester.pumpAndSettle();
      expect(_inRow('SEC-12', find.byType(EditableText)), findsNothing);
      expectClean(tester, 'limit');
    });

    testWidgets('the incident shows as a critical row, and the channels vote', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final KkDataTable<Sector> before = tester.widget<KkDataTable<Sector>>(_table());
      expect(before.rowLevel!(rig.station.sectors[3]), KkLevel.nominal);
      // A cell flashes when its value changes. The load wanders every second:
      // its cell counts a change only when the meter gains or loses a segment.
      expect(before.flashChanges, isTrue);
      final KkTableColumn<Sector> load = before.columns.firstWhere((KkTableColumn<Sector> c) => c.id == 'load');
      final Sector power = rig.station.sectors.first;
      power.load = 61;
      expect(load.value!(power), 6);
      power.load = 68.4;
      expect(load.value!(power), 6, reason: 'the same six segments');
      power.load = 70.2;
      expect(load.value!(power), 7);
      expect(
        load.compareRows(rig.station.sectors[1], power),
        lessThan(0),
        reason: 'sorting still goes by the exact load',
      );
      await raiseIncident(tester, rig);
      final KkDataTable<Sector> table = tester.widget<KkDataTable<Sector>>(_table());
      expect(table.rowLevel!(rig.station.sectors[3]), KkLevel.critical);
      expect(_inRow('SEC-04', find.text('CRITICAL')), findsOneWidget);
      expect(_inRow('SEC-04', find.text('PRESSURE LOW')), findsOneWidget);

      final Finder channels = find.byType(KkDataTable<Channel>);
      final KkDataTable<Channel> votes = tester.widget<KkDataTable<Channel>>(channels);
      expect(votes.rows, hasLength(3));
      expect(votes.rowLevel!(rig.station.channels.first), KkLevel.critical);
      expect(find.descendant(of: channels, matching: find.text('NO-GO')), findsNWidgets(2));
      expect(find.descendant(of: channels, matching: find.text('GO')), findsOneWidget);
      rig.station.reset();
      await tester.pump();
      expect(find.descendant(of: channels, matching: find.text('GO')), findsNWidgets(3));
      expectClean(tester, 'incident');
    });

    testWidgets('Refresh scans the rail for a moment; Export says what it wrote', (WidgetTester tester) async {
      await pumpApp(tester, route: '/systems');
      expect(tester.widget<KkDataTable<Sector>>(_table()).loading, isFalse);
      await tester.tap(_inTable(iconButton('Refresh')));
      await tester.pump();
      expect(tester.widget<KkDataTable<Sector>>(_table()).loading, isTrue);
      expect(_codes(tester), hasLength(8), reason: 'the rows stay while it reads');
      await tester.pump(const Duration(milliseconds: 950));
      expect(tester.widget<KkDataTable<Sector>>(_table()).loading, isFalse);

      await tester.tap(_inTable(iconButton('Export')));
      await tester.pump();
      expect(
        find.descendant(of: find.byType(KkSnackbar), matching: find.text('EXPORTED 12 ROWS · SECTORS-2026-11-24.CSV')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'refresh and export');
    });

    testWidgets('dense rows follow the setting, in both tables', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, route: '/systems');
      final double regular = tester.getSize(_row('SEC-01')).height;
      expect(regular, 32);
      rig.settings.dense = true;
      await tester.pump();
      expect(tester.getSize(_row('SEC-01')).height, 24);
      expect(tester.widget<KkDataTable<Channel>>(find.byType(KkDataTable<Channel>)).dense, isTrue);
      expectClean(tester, 'dense');
    });

    testWidgets('below 1000px of body the table drops its trend and remarks, and still fits', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: const Size(960, 800), route: '/systems');
      expect(_table(), findsOneWidget);
      expect(_inTable(find.byType(KkTableSpark)), findsNothing);
      expect(_inTable(find.text('REMARKS')), findsNothing);
      final Rect table = tester.getRect(_table());
      expect(tester.getRect(_inRow('SEC-01', find.byType(KkTableLevel))).right, lessThanOrEqualTo(table.right));
      await tester.pumpWidget(const KkBox());
      await pumpApp(tester, size: const Size(1280, 800), route: '/systems');
      expect(_inTable(find.byType(KkTableSpark)), findsNWidgets(8));
      expect(_inTable(find.text('REMARKS')), findsOneWidget);
      expectClean(tester, 'columns');
    });
  });

  group('list', () {
    testWidgets('search narrows the list; a result opens its sector; clearing brings all back', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: _narrow, route: '/systems');
      await tester.enterText(find.byType(EditableText).first, 'coolant');
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-04']);
      expect(find.text('01 / 12 SHOWN'), findsOneWidget);
      // The matching part of a result is marked; choosing it opens the sector.
      final Finder result = find.byWidgetPredicate(
        (Widget w) => w is RichText && w.text.toPlainText().contains('coolant · OP-07'),
        description: 'the search result for SEC-04',
      );
      expect(result, findsOneWidget);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-04');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SectorSheet), findsNothing);

      await tester.enterText(find.byType(EditableText).first, 'op-02');
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-07', 'SEC-08']);

      await tester.enterText(find.byType(EditableText).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.byType(KkListRow), findsNothing);
      expect(find.text('NO SECTOR MATCHES'), findsOneWidget);
      expect(find.byType(KkStatusTimeline), findsNothing);
      await tester.tap(button('clear filters'));
      await tester.pumpAndSettle();
      expect(find.byType(KkListRow), findsNWidgets(12));
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, isEmpty);
      expectClean(tester, 'search');
    });

    testWidgets('the status switch, the operator chips and the order work together', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: _narrow, route: '/systems');
      await tester.tap(_segment('OFFLINE'));
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-12']);
      await tester.tap(_segment('TROUBLE'));
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-08']);
      await tester.tap(_segment('NOMINAL'));
      await tester.pumpAndSettle();
      expect(_rows(tester), hasLength(10));
      await tester.tap(_segment('ALL'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: find.byType(KkChip), matching: find.text('OP-07')));
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-04', 'SEC-05']);
      await tester.tap(find.descendant(of: find.byType(KkChip), matching: find.text('OP-01')));
      await tester.pumpAndSettle();
      expect(_rows(tester), <String>['SEC-04', 'SEC-05', 'SEC-09', 'SEC-10']);
      expect(tester.widget<KkButton>(button('clear')).onPressed, isNotNull);
      await tester.tap(button('clear'));
      await tester.pumpAndSettle();
      expect(find.byType(KkListRow), findsNWidgets(12));
      expect(tester.widget<KkButton>(button('clear')).onPressed, isNull);

      // Order by load: the busiest sector comes first, the isolated one last.
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkSelect, description: 'the order select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BY LOAD').last);
      await tester.pumpAndSettle();
      final List<Sector> byLoad = rig.station.sectors.where((Sector s) => s.level != KkLevel.offline).toList()
        ..sort((Sector a, Sector b) => b.load.compareTo(a.load));
      expect(_rows(tester), <String>[for (final Sector s in byLoad) s.code, 'SEC-12']);
      expectClean(tester, 'filters');
    });

    testWidgets('a row opens the sector sheet: assign, isolate (after a question) and restore', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, size: _narrow, route: '/systems');
      final Sector storage = rig.station.sectors[2];
      await tester.tap(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-03');
      expect(find.byType(KkReadout), findsNWidgets(2));

      expect(storage.operator, 'OP-11');
      await tester.tap(button('assign to me'));
      await tester.pumpAndSettle();
      expect(storage.operator, 'OP-07');
      expect(tester.widget<KkButton>(button('assigned')).onPressed, isNull);

      // The load limit, which the table edits in a cell, is on a slider here:
      // it moves in fives, and the plant takes it when the thumb is let go.
      final Finder slider = find.descendant(of: find.byType(SectorSheet), matching: find.byType(KkSlider));
      expect(tester.widget<KkSlider>(slider).value, 70);
      final int lines = rig.station.log.length;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final Rect track = tester.getRect(slider);
      final TestGesture finger = await tester.startGesture(Offset(track.center.dx, track.center.dy));
      await finger.moveTo(Offset(track.left + track.width * 0.25, track.center.dy));
      await tester.pump();
      await finger.moveTo(Offset(track.left + 4, track.center.dy));
      await tester.pump();
      expect(tester.widget<KkSlider>(slider).value, Sector.minLimit, reason: 'the thumb follows the finger');
      expect(storage.limit, 70, reason: 'the plant waits for the release');
      await finger.up();
      await tester.pumpAndSettle();
      expect(storage.limit, Sector.minLimit);
      expect(rig.station.log.length, lines + 1, reason: 'one line for the whole drag');
      expect(rig.station.log.last.message, 'LOAD LIMIT SET TO 010 %');
      // The keyboard goes on from the press: one step up is five percent.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(storage.limit, 15);
      expect(find.descendant(of: find.byType(SectorSheet), matching: find.text('LIMIT 015')), findsWidgets);

      // Isolating asks first.
      await tester.tap(button('isolate'));
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(button('cancel'));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.nominal);
      await tester.tap(button('isolate'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(KkDialog), matching: button('isolate')));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.offline);
      expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('SECTOR ISOLATED')), findsOneWidget);
      expect(button('isolate'), findsNothing);
      expect(tester.widget<KkSlider>(slider).enabled, isFalse, reason: 'an isolated sector has no limit to set');

      await tester.tap(button('restore'));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.nominal);
      await tester.tap(iconButton('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(SectorSheet), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'sector sheet');
    });

    testWidgets('a long press on a row opens its quick actions', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: _narrow, route: '/systems');
      final Sector storage = rig.station.sectors[2];
      Finder item(String label) => find.descendant(of: find.byType(KkMenu<String>), matching: find.text(label));

      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      // The menu hangs under its row, at the row's right end, and stays on screen.
      final Rect row = tester.getRect(find.byType(KkListRow).at(2));
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      expect(menu.top, greaterThanOrEqualTo(row.bottom));
      expect(menu.right, moreOrLessEquals(row.right, epsilon: 1));
      expect(item('SEC-03'), findsOneWidget);

      // Assign: the sector changes hands and the menu closes.
      expect(storage.operator, 'OP-11');
      await tester.tap(item('ASSIGN TO ME'));
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(storage.operator, 'OP-07');

      // Now it is mine: the entry is off, and pressing it does nothing.
      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      await tester.tap(item('ASSIGN TO ME'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsOneWidget);

      // Isolate asks first; cancelling leaves the sector alone.
      await tester.tap(item('ISOLATE'));
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(button('cancel'));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.nominal);

      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      await tester.tap(item('ISOLATE'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(KkDialog), matching: button('isolate')));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.offline);
      expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('SECTOR ISOLATED')), findsOneWidget);

      // An isolated sector offers RESTORE in place of ISOLATE.
      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      expect(item('ISOLATE'), findsNothing);
      await tester.tap(item('RESTORE'));
      await tester.pumpAndSettle();
      expect(storage.level, KkLevel.nominal);

      // Acknowledge: only a sector that is not nominal has something to acknowledge.
      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      await tester.tap(item('ACKNOWLEDGE'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(storage.acknowledged, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final Sector relay = rig.station.sectors[7];
      await tester.ensureVisible(find.byType(KkListRow).at(7));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(KkListRow).at(7));
      await tester.pumpAndSettle();
      await tester.tap(item('ACKNOWLEDGE'));
      await tester.pumpAndSettle();
      expect(relay.acknowledged, isTrue);
      expect(tester.widget<KkListRow>(find.byType(KkListRow).at(7)).sub, endsWith('CH.12 RESYNC · ACK'));
      // It lasts until the sector's level changes.
      rig.station.setSectorOffline(relay, offline: true);
      await tester.pump();
      expect(relay.acknowledged, isFalse);
      rig.station.setSectorOffline(relay, offline: false);
      await tester.pump();
      await tester.ensureVisible(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();

      // Open detail leads to the sheet; Escape closes a menu without acting.
      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(find.byType(SectorSheet), findsNothing);
      await tester.longPress(find.byType(KkListRow).at(2));
      await tester.pumpAndSettle();
      await tester.tap(item('OPEN DETAIL'));
      await tester.pumpAndSettle();
      expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-03');
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'row menu');
    });

    testWidgets('with dense rows on, the list is dense', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: _narrow, route: '/systems');
      final double regular = tester.getSize(find.byType(KkListRow).first).height;
      rig.settings.dense = true;
      await tester.pump();
      final double dense = tester.getSize(find.byType(KkListRow).first).height;
      expect(dense, 32);
      expect(regular, greaterThan(dense));
      expectClean(tester, 'dense');
    });
  });

  testWidgets('table and list keep one filter and one order when the window changes', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/systems');
    await tester.enterText(_inTable(find.byType(EditableText)), 'op-0');
    await tester.pumpAndSettle();
    await tester.tap(_inTable(find.text('OPERATOR')));
    await tester.pumpAndSettle();
    await tester.tap(_inTable(find.text('OPERATOR')));
    await tester.pumpAndSettle();
    final List<String> wide = _codes(tester);
    expect(wide, isNotEmpty);

    // The window gets narrow: the list shows the same sectors in the same order.
    tester.view.physicalSize = _narrow;
    await tester.pumpAndSettle();
    expect(_table(), findsNothing);
    expect(_rows(tester).take(8), wide, reason: 'the list has no pages: it starts with the table\'s first eight');
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'op-0');
    // The select names the order it did not offer before.
    expect(find.text('BY OPERATOR DOWN'), findsOneWidget);

    // The order chosen on the narrow window is the table's sort when it is wide again.
    await tester.tap(find.byWidgetPredicate((Widget w) => w is KkSelect, description: 'the order select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BY LOAD').last);
    await tester.pumpAndSettle();
    final List<String> narrow = _rows(tester);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(tester.widget<KkDataTable<Sector>>(_table()).sort, const KkTableSort('load', KkSortDirection.descending));
    expect(_codes(tester), narrow.take(8));
    expect(rig.station.sectors, hasLength(12));
    expectClean(tester, 'one filter, one order');
  });

  testWidgets('the camera feeds step one card at a time and open their sector', (WidgetTester tester) async {
    await pumpApp(tester, route: '/systems');
    expect(find.text('01 / 12'), findsOneWidget);
    await tester.ensureVisible(find.byType(KkCarousel));
    await tester.pumpAndSettle();
    await tester.tap(iconButton('Next'));
    await tester.pumpAndSettle();
    expect(find.text('02 / 12'), findsOneWidget);
    await tester.tap(iconButton('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('01 / 12'), findsOneWidget);
    await tester.ensureVisible(find.text('CAM-01 · SEC-01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAM-01 · SEC-01'));
    await tester.pumpAndSettle();
    expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-01');
    expectClean(tester, 'feeds');
  });
}
