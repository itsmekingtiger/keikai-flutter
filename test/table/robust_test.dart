import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

void main() {
  setUpAll(loadKkFonts);

  testChecked('no rows, no columns, one column, one row', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 300,
        child: KkDataTable<Pump>(rows: <Pump>[], rowKey: pumpKey, columns: <KkTableColumn<Pump>>[]),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('NO RECORDS'), findsOneWidget);

    await pumpKk(
      tester,
      const KkBox(
        width: 300,
        child: KkDataTable<Pump>(rows: pumps, rowKey: pumpKey, columns: <KkTableColumn<Pump>>[]),
      ),
    );
    expect(tester.takeException(), isNull);
    // Four rows with nothing in them.
    expect(tableRect(tester).height, 2 + 2 + 30 + 4 * 32);

    await pumpKk(
      tester,
      KkBox(
        width: 300,
        height: 120,
        child: KkDataTable<Pump>(
          rows: pumps.sublist(0, 1),
          rowKey: pumpKey,
          selection: KkTableSelection.multi,
          showRowNumbers: true,
          detail: (BuildContext _, Pump p) => const KkText('x'),
          initialPageSize: 1,
          columns: <KkTableColumn<Pump>>[idColumn()],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('P-01'), findsOneWidget);
  });

  testChecked('missing values read --, in text and in cells that take numbers', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 700,
        child: KkDataTable<Pump>(
          rows: const <Pump>[
            Pump('P-01', 'a', null, load: double.nan),
            Pump('P-02', 'b', double.nan),
            Pump('P-03', 'c', double.infinity, load: 9),
          ],
          rowKey: pumpKey,
          rowFill: (Pump p) => p.load,
          initialSort: const KkTableSort('flow'),
          columns: <KkTableColumn<Pump>>[
            idColumn(),
            KkTableColumn<Pump>(id: 'flow', en: 'flow', numeric: true, sortable: true, value: (Pump p) => p.flow),
            KkTableColumn<Pump>(id: 'bar', en: 'bar', cell: (BuildContext _, Pump p) => KkTableBar(p.load)),
            KkTableColumn<Pump>(id: 'meter', en: 'meter', cell: (BuildContext _, Pump p) => KkTableMeter(p.load)),
            KkTableColumn<Pump>(
              id: 'spark',
              en: 'spark',
              cell: (BuildContext _, Pump p) => KkTableSpark(<double?>[p.flow, null, double.nan, 3]),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Null, NaN and infinity all read as two dashes.
    expect(find.text('--'), findsNWidgets(4));
    // Infinity is a value and sorts; the two without one keep their order behind it.
    expect(idsInOrder(tester), <String>['P-03', 'P-01', 'P-02']);
  });

  testChecked('very long text is cut at its column and cannot push the table wider', (WidgetTester tester) async {
    final String long = 'x' * 4000;
    await pumpKk(
      tester,
      KkBox(
        width: 400,
        height: 200,
        child: KkDataTable<Pump>(
          code: long,
          cjk: '機' * 200,
          en: long,
          meta: long,
          rows: <Pump>[Pump('P-01', long, 1), const Pump('P-02', 'b', 2)],
          rowKey: pumpKey,
          columns: <KkTableColumn<Pump>>[
            idColumn(),
            KkTableColumn<Pump>(
              id: 'name',
              en: long,
              width: const KkTableWidth.flex(max: 200),
              value: (Pump p) => p.name,
            ),
            KkTableColumn<Pump>(
              id: 'n2',
              en: 'n2',
              width: const KkTableWidth.content(max: 150),
              value: (Pump p) => p.name,
              truncate: true,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tableRect(tester).size, const Size(400, 200));
    final KkTableGeometry g = rowOf(tester, 'P-02').link.geometry;
    // The long header makes its flex column as wide as its max allows; the content column stops at 150.
    expect(g.widths, <double>[80, 200, 150]);
  });

  testChecked('ten thousand rows sort, filter and page without building them', (WidgetTester tester) async {
    int built = 0;
    final List<Pump> rows = manyPumps(10000);
    final Stopwatch watch = Stopwatch()..start();
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        height: 400,
        child: KkDataTable<Pump>(
          rows: rows,
          rowKey: pumpKey,
          filterable: true,
          selection: KkTableSelection.multi,
          initialSort: const KkTableSort('flow', KkSortDirection.descending),
          columns: <KkTableColumn<Pump>>[
            KkTableColumn<Pump>(
              id: 'id',
              en: 'id',
              width: const KkTableWidth.fixed(100),
              cell: (BuildContext _, Pump p) {
                built++;
                return KkText(p.id);
              },
            ),
            nameColumn(),
            flowColumn(),
          ],
        ),
      ),
    );
    expect(idsInOrder(tester).first, 'R-9999');
    await tester.enterText(find.byType(EditableText), 'row 99');
    await tester.pump();
    // row 99, row 990 … row 999, row 9900 … row 9999: 111 rows, still sorted downwards.
    expect(idsInOrder(tester).first, 'R-9999');
    await tester.tap(find.byType(KkCheckbox).first);
    await tester.pump();
    expect(find.text('111'), findsOneWidget);
    expect(built, lessThan(120));
    // Generous: the point is that it is nowhere near the cost of ten thousand rows.
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
  });

  testChecked('state that names rows which are gone is ignored everywhere', (WidgetTester tester) async {
    Widget build(List<Pump> rows) => KkBox(
      width: 600,
      height: 300,
      child: KkDataTable<Pump>(
        en: 'pumps',
        rows: rows,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        selected: const <Object>{'P-01', 'P-04', 'nope'},
        expanded: const <Object>{'P-04', 'nope'},
        detail: (BuildContext _, Pump p) => const KkBox(height: 20),
        sort: const KkTableSort('nope'),
        page: 7,
        pageSize: 3,
        initiallyEditing: const KkTableCellRef('nope', 'name'),
      ),
    );
    await pumpKk(tester, build(pumps));
    expect(tester.takeException(), isNull);
    // Page 7 of 2 is page 2: the fourth row alone.
    expect(idsInOrder(tester), <String>['P-04']);
    expect(find.text('02'), findsWidgets);
    await pumpKk(tester, build(pumps.sublist(0, 2)));
    expect(tester.takeException(), isNull);
    expect(idsInOrder(tester), <String>['P-01', 'P-02']);
    await pumpKk(tester, build(const <Pump>[]));
    expect(tester.takeException(), isNull);
    expect(find.text('NO RECORDS'), findsOneWidget);
  });

  testChecked('columns, density, selection and paging can change under a live table', (WidgetTester tester) async {
    Widget build({
      required List<KkTableColumn<Pump>> columns,
      bool dense = false,
      KkTableSelection selection = KkTableSelection.none,
      int? pageSize,
      bool numbers = false,
      bool detail = false,
    }) => KkBox(
      width: 600,
      height: 300,
      child: KkDataTable<Pump>(
        en: 'pumps',
        rows: manyPumps(30),
        rowKey: pumpKey,
        columns: columns,
        dense: dense,
        selection: selection,
        initialPageSize: pageSize,
        showRowNumbers: numbers,
        detail: detail ? (BuildContext _, Pump p) => const KkBox(height: 20) : null,
      ),
    );
    await pumpKk(tester, build(columns: basicColumns()));
    expect(rowOf(tester, 'R-0000').link.geometry.widths, <double>[80, 422, 96]);
    await pumpKk(tester, build(columns: <KkTableColumn<Pump>>[flowColumn(), idColumn()], dense: true));
    expect(rowOf(tester, 'R-0000').link.geometry.widths, <double>[96, 80]);
    expect(rowRectOf(tester, 'R-0000').height, 24);
    await pumpKk(
      tester,
      build(columns: basicColumns(), selection: KkTableSelection.multi, pageSize: 5, numbers: true, detail: true),
    );
    expect(rowOf(tester, 'R-0000').link.geometry.widths, <double>[36, 40, 28, 80, 598 - 104 - 176, 96]);
    expect(idsInOrder(tester), hasLength(5));
    await pumpKk(tester, build(columns: const <KkTableColumn<Pump>>[]));
    expect(tester.takeException(), isNull);
    await pumpKk(tester, build(columns: basicColumns()));
    expect(rowOf(tester, 'R-0000').link.geometry.widths, <double>[80, 422, 96]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controllers and the focus node can be swapped, and nothing outlives the table', (
    WidgetTester tester,
  ) async {
    final ScrollController a = ScrollController();
    final ScrollController b = ScrollController();
    final ScrollController h = ScrollController();
    final FocusNode focus = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(h.dispose);
    addTearDown(focus.dispose);
    Widget build({ScrollController? vertical, ScrollController? horizontal, FocusNode? node, List<Pump>? rows}) =>
        kkHarness(
          KkBox(
            width: 500,
            height: 300,
            child: KkDataTable<Pump>(
              en: 'pumps',
              rows: rows ?? manyPumps(50),
              rowKey: pumpKey,
              rowLevel: (Pump p) => p.level,
              columns: basicColumns(),
              scrollController: vertical,
              horizontalController: horizontal,
              focusNode: node,
              selection: KkTableSelection.multi,
              selected: const <Object>{'R-0001'},
              filterable: true,
              loading: true,
              bulkActions: <KkTableBulkAction>[
                KkTableBulkAction(label: 'trip', danger: true, onPressed: (Set<Object> _) {}),
              ],
            ),
          ),
          motion: true,
        );
    await tester.pumpWidget(build(vertical: a));
    await tester.pump(const Duration(milliseconds: 100));
    a.jumpTo(100);
    await tester.pump();
    await tester.pumpWidget(build(vertical: b, horizontal: h, node: focus));
    await tester.pump();
    expect(a.hasClients, isFalse);
    expect(b.hasClients, isTrue);
    expect(h.hasClients, isTrue);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pumpWidget(build());
    await tester.pump();
    expect(b.hasClients, isFalse);
    // Arm an action and start a flash and a strobe, then take the table away mid-flight.
    await tester.tap(find.text('TRIP'));
    await tester.pump();
    await tester.pumpWidget(
      build(
        rows: <Pump>[
          const Pump('R-0000', 'changed', 77, level: KkLevel.critical),
          ...manyPumps(50).skip(1),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    // No ticker, timer or frame is left behind (the test binding checks timers itself).
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testChecked('a table in a panel, in a grid cell and in a split fills what it is given', (WidgetTester tester) async {
    Widget tableOf(int count) =>
        KkDataTable<Pump>(rows: manyPumps(count), rowKey: pumpKey, columns: basicColumns(), frame: false, boot: false);
    await pumpKk(
      tester,
      KkBox(
        width: 700,
        height: 400,
        child: KkPanel(code: 'SEC-01', cjk: '機器', en: 'pumps', flush: true, boot: false, child: tableOf(40)),
      ),
    );
    expect(tester.takeException(), isNull);
    // The panel's head is 32 high inside its 1px frame.
    expect(tableRect(tester), const Rect.fromLTWH(1, 33, 698, 366));

    await pumpKk(
      tester,
      KkBox(
        width: 800,
        child: KkGrid(
          children: <Widget>[
            KkCell(span: 8, rows: 4, child: tableOf(40)),
            KkCell(span: 4, rows: 4, child: tableOf(2)),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(byRuntimeType('KkTableFrame').first).height, 4 * 48 + 3 * 8);
  });
}
