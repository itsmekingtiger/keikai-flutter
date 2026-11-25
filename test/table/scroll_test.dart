import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

/// Every row item in the tree, including the ones built ahead of the view.
int _built(WidgetTester tester) => find
    .byWidgetPredicate((Widget w) => w.runtimeType.toString() == 'KkTableRowItem', skipOffstage: false)
    .evaluate()
    .length;

void main() {
  setUpAll(loadKkFonts);

  testChecked('ten thousand rows: only the rows near the view are built, at the top and after a jump to the end', (
    WidgetTester tester,
  ) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    int cells = 0;
    final List<Pump> rows = manyPumps(10000);
    await pumpKk(
      tester,
      KkBox(
        width: 600,
        height: 400,
        child: KkDataTable<Pump>(
          rows: rows,
          rowKey: pumpKey,
          scrollController: vertical,
          columns: <KkTableColumn<Pump>>[
            KkTableColumn<Pump>(
              id: 'id',
              en: 'id',
              width: const KkTableWidth.fixed(120),
              cell: (BuildContext _, Pump p) {
                cells++;
                return KkText(p.id);
              },
            ),
            nameColumn(),
          ],
        ),
      ),
    );
    // 398 - rail 2 - header 30 = 366 of rows: 11.4 in view, and 250px built ahead.
    expect(vertical.position.viewportDimension, 366);
    expect(vertical.position.maxScrollExtent, 10000 * 32 - 366);
    expect(_built(tester), inInclusiveRange(12, 22));
    expect(cells, lessThan(30));
    expect(find.text('R-0000'), findsOneWidget);

    cells = 0;
    vertical.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();
    // The last row ends at the bottom edge; nothing in between was built on the way.
    expect(rowRectOf(tester, 'R-9999').bottom, 399);
    expect(_built(tester), inInclusiveRange(12, 22));
    expect(cells, lessThan(30));

    cells = 0;
    vertical.jumpTo(5000 * 32.0);
    await tester.pump();
    expect(rowRectOf(tester, 'R-5000').top, 1 + 2 + 30);
    expect(cells, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testChecked('the header stays, the summary stays, the rows move', (WidgetTester tester) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    await pumpKk(
      tester,
      KkBox(
        width: 500,
        height: 300,
        child: KkDataTable<Pump>(
          rows: manyPumps(100),
          rowKey: pumpKey,
          scrollController: vertical,
          columns: <KkTableColumn<Pump>>[
            idColumn(),
            KkTableColumn<Pump>(
              id: 'name',
              en: 'name',
              width: const KkTableWidth.flex(),
              value: (Pump p) => p.name,
              summary: (BuildContext _, List<Pump> rows) => const KkTableSummary('sum'),
            ),
          ],
        ),
      ),
    );
    final Rect header = tester.getRect(find.text('NAME'));
    final Rect summary = tester.getRect(find.text('sum'));
    expect(rowRectOf(tester, 'sum'), const Rect.fromLTWH(1, 299 - 30, 498, 30));
    vertical.jumpTo(777);
    await tester.pump();
    expect(tester.getRect(find.text('NAME')), header);
    expect(tester.getRect(find.text('sum')), summary);
    // 777 = 24 rows and 9px.
    expect(rowRectOf(tester, 'R-0025').top, 1 + 2 + 30 + 32 - 9);
    // Rows are cut at the header and at the summary: a row under either is not hit.
    final HitTestResult result = tester.hitTestOnBinding(header.center);
    expect(
      result.path.any(
        (HitTestEntry e) =>
            e.target is RenderParagraph && (e.target as RenderParagraph).text.toPlainText().startsWith('R-'),
      ),
      isFalse,
    );
  });

  testChecked('a table without a height limit builds all its rows and does not scroll itself', (
    WidgetTester tester,
  ) async {
    final ScrollController vertical = ScrollController();
    final ScrollController outer = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(outer.dispose);
    await pumpKk(
      tester,
      KkScroll(
        controller: outer,
        child: KkBox(
          width: 500,
          child: KkDataTable<Pump>(
            rows: manyPumps(60),
            rowKey: pumpKey,
            columns: basicColumns(),
            scrollController: vertical,
          ),
        ),
      ),
    );
    expect(_built(tester), 60);
    expect(vertical.position.maxScrollExtent, 0);
    expect(tableRect(tester).height, 2 + 2 + 30 + 60 * 32);
    expect(outer.position.maxScrollExtent, 2 + 2 + 30 + 60 * 32 - 600);
  });

  testChecked('a content column grows when a wider cell scrolls in, and keeps that width', (WidgetTester tester) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    final List<Pump> rows = <Pump>[
      for (int i = 0; i < 300; i++)
        Pump('R-${i.toString().padLeft(4, '0')}', i == 200 ? 'a much longer name than the others' : 'n$i', 1),
    ];
    await pumpKk(
      tester,
      KkBox(
        width: 700,
        height: 300,
        child: KkDataTable<Pump>(
          rows: rows,
          rowKey: pumpKey,
          scrollController: vertical,
          columns: <KkTableColumn<Pump>>[
            idColumn(),
            nameColumn(width: const KkTableWidth.content()),
            KkTableColumn<Pump>(id: 'rest', en: 'rest', width: const KkTableWidth.flex(), value: (Pump p) => p.flow),
          ],
        ),
      ),
    );
    double nameWidth() => rowOf(tester, idsInOrder(tester).first).link.geometry.widths[1];
    final double narrow = nameWidth();
    expect(narrow, lessThan(80));
    vertical.jumpTo(200 * 32.0);
    await tester.pump();
    // The row was built and measured in that frame; the frame after it has the new columns.
    await tester.pump();
    final double wide = nameWidth();
    final double text = tester.getSize(find.text('a much longer name than the others')).width;
    expect(wide, (text + 16).ceilToDouble());
    // The header moved with it.
    expect(tester.getRect(find.text('REST')).left, 1 + 80 + wide + 8);
    vertical.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(nameWidth(), wide);
  });

  testChecked('a detail block that is first measured above the view does not move what is in view', (
    WidgetTester tester,
  ) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    await pumpKk(
      tester,
      KkBox(
        width: 500,
        height: 300,
        child: KkDataTable<Pump>(
          rows: manyPumps(100),
          rowKey: pumpKey,
          scrollController: vertical,
          columns: basicColumns(),
          expanded: const <Object>{'R-0030'},
          detail: (BuildContext _, Pump p) => const KkBox(height: 40),
        ),
      ),
    );
    // Row 30's block is far below the view and has never been built: it counts with the 96px
    // estimate.
    expect(vertical.position.maxScrollExtent, 100 * 32 + 96 - 266);
    // Far below it, then back up to where the block is in the part built ahead of the view.
    vertical.jumpTo(2500);
    await tester.pump();
    vertical.jumpTo(1250);
    await tester.pump();
    // With the estimate, row 36 starts at 1248: 2px above the top of the view. The block turns
    // out to be 65 high, 31 less; the offset follows, and row 36 is where it would have been.
    expect(vertical.offset, 1250 - 31);
    expect(rowRectOf(tester, 'R-0036').top, 1 + 2 + 30 - 2);
    await tester.pump();
    expect(vertical.offset, 1250 - 31);
    expect(vertical.position.maxScrollExtent, 100 * 32 + 65 - 266);
    expect(tester.takeException(), isNull);
  });

  testChecked('rows that go away under a scrolled table leave it at the new end, at once', (WidgetTester tester) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    Widget build(int count) => KkBox(
      width: 500,
      height: 300,
      child: KkDataTable<Pump>(
        rows: manyPumps(count),
        rowKey: pumpKey,
        scrollController: vertical,
        columns: basicColumns(),
      ),
    );
    await pumpKk(tester, build(100));
    vertical.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();
    await pumpKk(tester, build(20));
    expect(vertical.position.maxScrollExtent, 20 * 32 - 266);
    expect(vertical.offset, 20 * 32 - 266);
    expect(rowRectOf(tester, 'R-0019').bottom, 299);
    await pumpKk(tester, build(3));
    expect(vertical.offset, 0);
    expect(rowRectOf(tester, 'R-0000').top, 33);
  });

  testChecked('both scrollbars are thin, square and in the line colour; the upright one clears header and summary', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      KkBox(
        width: 300,
        height: 300,
        child: KkDataTable<Pump>(
          rows: manyPumps(100),
          rowKey: pumpKey,
          columns: <KkTableColumn<Pump>>[
            idColumn(width: const KkTableWidth.fixed(300)),
            KkTableColumn<Pump>(
              id: 'name',
              cjk: '名称',
              en: 'name',
              width: const KkTableWidth.fixed(300),
              value: (Pump p) => p.name,
              summary: (BuildContext _, List<Pump> rows) => const KkTableSummary('sum'),
            ),
          ],
        ),
      ),
    );
    final List<RawScrollbar> bars = tester.widgetList<RawScrollbar>(find.byType(RawScrollbar)).toList();
    expect(bars, hasLength(2));
    for (final RawScrollbar bar in bars) {
      expect(bar.thumbColor, KkColors.standby.line);
      expect(bar.thickness, 6);
      expect(bar.radius, Radius.zero);
      expect(bar.fadeDuration, Duration.zero);
    }
    expect(bars[0].scrollbarOrientation, ScrollbarOrientation.bottom);
    expect(bars[1].scrollbarOrientation, ScrollbarOrientation.right);
    expect(bars[1].padding, const EdgeInsets.only(top: 42, bottom: 30));
  });
}
