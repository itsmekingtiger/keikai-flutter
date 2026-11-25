import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

bool _live(WidgetTester tester, String label) =>
    tester
        .widget<KkIconButton>(
          find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(KkIconButton)).first,
        )
        .onPressed !=
    null;

void main() {
  setUpAll(loadKkFonts);

  group('KkPagination', () {
    testWidgets('first, previous, 03 / 12, next, last; 24px buttons 2px apart', (WidgetTester tester) async {
      final List<int> pages = <int>[];
      await pumpKk(tester, KkPagination(page: 2, pageCount: 12, onChanged: pages.add));
      const KkColors c = KkColors.standby;
      expect(find.byType(KkIconButton), findsNWidgets(4));
      final List<Rect> buttons = <Rect>[for (int i = 0; i < 4; i++) tester.getRect(find.byType(KkIconButton).at(i))];
      for (final Rect r in buttons) {
        expect(r.size, const Size(24, 24));
      }
      expect(buttons[1].left - buttons[0].right, 2);
      expect(find.text('03'), findsOneWidget);
      expect(find.text(' / 12'), findsOneWidget);
      expect(styleOf(tester, '03').fontSize, 11);
      expect(styleOf(tester, '03').fontWeight, FontWeight.w500);
      expect(styleOf(tester, '03').color, c.ink);
      expect(styleOf(tester, ' / 12').color, c.inkDim);
      // The text is 6px from the buttons on either side (plus the row's 2px gap).
      expect(tester.getRect(find.text('03')).left - buttons[1].right, 2 + 6);

      await tester.tap(find.bySemanticsLabel('First page'));
      await tester.tap(find.bySemanticsLabel('Previous page'));
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.tap(find.bySemanticsLabel('Last page'));
      expect(pages, <int>[0, 1, 3, 11]);
    });

    testWidgets('the buttons that would leave the range are off', (WidgetTester tester) async {
      await pumpKk(tester, KkPagination(page: 0, pageCount: 3, onChanged: (int _) {}));
      expect(_live(tester, 'First page'), isFalse);
      expect(_live(tester, 'Previous page'), isFalse);
      expect(_live(tester, 'Next page'), isTrue);
      expect(_live(tester, 'Last page'), isTrue);
      await pumpKk(tester, KkPagination(page: 2, pageCount: 3, onChanged: (int _) {}));
      expect(_live(tester, 'First page'), isTrue);
      expect(_live(tester, 'Next page'), isFalse);
      expect(_live(tester, 'Last page'), isFalse);
    });

    testWidgets('no callback, no pages, a page out of range, and no end buttons', (WidgetTester tester) async {
      await pumpKk(tester, const KkPagination(page: 1, pageCount: 3));
      for (final String label in <String>['First page', 'Previous page', 'Next page', 'Last page']) {
        expect(_live(tester, label), isFalse);
      }
      expect(styleOf(tester, '02').color, KkColors.standby.inkFaint);

      await pumpKk(tester, KkPagination(page: 0, pageCount: 0, onChanged: (int _) {}));
      expect(find.text('00'), findsOneWidget);
      expect(find.text(' / 00'), findsOneWidget);
      expect(_live(tester, 'Next page'), isFalse);

      await pumpKk(tester, KkPagination(page: 99, pageCount: 4, onChanged: (int _) {}));
      expect(find.text('04'), findsOneWidget);
      expect(_live(tester, 'Next page'), isFalse);
      await pumpKk(tester, KkPagination(page: -5, pageCount: 4, onChanged: (int _) {}));
      expect(find.text('01'), findsOneWidget);
      expect(_live(tester, 'Previous page'), isFalse);

      await pumpKk(tester, KkPagination(page: 0, pageCount: 1200, showEnds: false, onChanged: (int _) {}));
      expect(find.byType(KkIconButton), findsNWidgets(2));
      expect(find.text('0001'), findsOneWidget);
      expect(find.text(' / 1200'), findsOneWidget);
    });

    testWidgets('keyboard and semantics', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<int> pages = <int>[];
      await pumpKk(tester, KkPagination(page: 1, pageCount: 5, onChanged: pages.add));
      expect(tester.getSemantics(find.bySemanticsLabel('Pages')).value, 'Page 2 of 5');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(pages, <int>[0]);
      semantics.dispose();
    });
  });

  group('paging', () {
    Widget table({
      int count = 10,
      int? pageSize,
      int? initialPageSize = 4,
      int? page,
      List<int> options = const <int>[],
      ValueChanged<int>? onPageChanged,
      ValueChanged<int>? onPageSizeChanged,
      int? totalRows,
      bool filterable = false,
      List<Pump>? rows,
    }) => KkBox(
      width: 600,
      child: KkDataTable<Pump>(
        rows: rows ?? manyPumps(count),
        rowKey: pumpKey,
        columns: basicColumns(),
        pageSize: pageSize,
        initialPageSize: initialPageSize,
        page: page,
        pageSizeOptions: options,
        onPageChanged: onPageChanged,
        onPageSizeChanged: onPageSizeChanged,
        totalRows: totalRows,
        filterable: filterable,
      ),
    );

    testWidgets('the footer is 36 high with a 1px line; range text and pager in the CSS sizes', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, table());
      const KkColors c = KkColors.standby;
      final Rect footer = tester.getRect(byRuntimeType('KkTableFooter'));
      expect(footer.size, const Size(598, 36));
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: byRuntimeType('KkTableFooter'), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.edges.top, KkSide(c.line, width: 1));
      expect(find.text('001–004 / 010'), findsOneWidget);
      final TextStyle range = styleOf(tester, '001–004 / 010');
      expect(range.fontSize, 11);
      expect(range.color, c.inkDim);
      expect(tester.getRect(find.text('001–004 / 010')).left, footer.left + 12);
      // The pager ends 4px before the edge.
      expect(tester.getRect(find.byType(KkPagination)).right, footer.right - 4);
      expect(find.text('01'), findsOneWidget);
      expect(find.text(' / 03'), findsOneWidget);
      expect(idsInOrder(tester), <String>['R-0000', 'R-0001', 'R-0002', 'R-0003']);
    });

    testWidgets('the pager moves through the pages; the last page is short', (WidgetTester tester) async {
      final List<int> pages = <int>[];
      await pumpKk(tester, table(onPageChanged: pages.add));
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      expect(idsInOrder(tester), <String>['R-0004', 'R-0005', 'R-0006', 'R-0007']);
      expect(find.text('005–008 / 010'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Last page'));
      await tester.pump();
      expect(idsInOrder(tester), <String>['R-0008', 'R-0009']);
      expect(find.text('009–010 / 010'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('First page'));
      await tester.pump();
      expect(idsInOrder(tester).first, 'R-0000');
      expect(pages, <int>[1, 2, 0]);
    });

    testWidgets('row numbers count across pages', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkDataTable<Pump>(
          rows: manyPumps(10),
          rowKey: pumpKey,
          columns: basicColumns(),
          initialPageSize: 4,
          showRowNumbers: true,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      expect(textsInOrder(tester, RegExp(r'^0[5-8]$')), <String>['05', '06', '07', '08']);
    });

    testWidgets('the rows-per-page select shows with two or more choices and keeps the first row in sight', (
      WidgetTester tester,
    ) async {
      final List<int> sizes = <int>[];
      final List<int> pages = <int>[];
      await pumpKk(tester, table());
      expect(find.byType(KkSelect<int>), findsNothing);

      await pumpKk(
        tester,
        table(count: 30, options: const <int>[4, 10, 25], onPageSizeChanged: sizes.add, onPageChanged: pages.add),
      );
      expect(find.text('ROWS'), findsOneWidget);
      expect(styleOf(tester, 'ROWS').letterSpacing, closeTo(1.1, 1e-9));
      final Rect select = tester.getRect(find.byType(KkSelect<int>));
      expect(select.height, 24);
      expect(select.left - tester.getRect(find.text('ROWS')).right, 6);
      // Go to the third page (rows 9 to 12), then choose 10 per page: row 9 is on page 1 of that.
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      expect(idsInOrder(tester).first, 'R-0008');
      await tester.tap(find.byType(KkSelect<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();
      expect(sizes, <int>[10]);
      expect(pages.last, 0);
      expect(idsInOrder(tester), hasLength(10));
      expect(idsInOrder(tester).first, 'R-0000');
      expect(find.text('001–010 / 030'), findsOneWidget);
    });

    testWidgets('a page beyond the last is shown as the last', (WidgetTester tester) async {
      await pumpKk(tester, table(page: 99));
      expect(idsInOrder(tester), <String>['R-0008', 'R-0009']);
      expect(find.text('03'), findsOneWidget);
      await pumpKk(tester, table(page: -3));
      expect(idsInOrder(tester).first, 'R-0000');
      // Rows that go away under the table's own page leave it on the last page there is.
      await pumpKk(tester, table(count: 10, initialPageSize: 4));
      await tester.tap(find.bySemanticsLabel('Last page'));
      await tester.pump();
      await pumpKk(tester, table(count: 3, initialPageSize: 4));
      expect(idsInOrder(tester), <String>['R-0000', 'R-0001', 'R-0002']);
    });

    testWidgets('controlled page and page size change only when the owner says so', (WidgetTester tester) async {
      final List<int> pages = <int>[];
      final List<int> sizes = <int>[];
      Widget build(int page, int size) => table(
        count: 30,
        initialPageSize: null,
        pageSize: size,
        page: page,
        options: const <int>[5, 10],
        onPageChanged: pages.add,
        onPageSizeChanged: sizes.add,
      );
      await pumpKk(tester, build(1, 5));
      expect(idsInOrder(tester).first, 'R-0005');
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      expect(pages, <int>[2]);
      expect(idsInOrder(tester).first, 'R-0005');
      await tester.tap(find.byType(KkSelect<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();
      expect(sizes, <int>[10]);
      expect(idsInOrder(tester), hasLength(5));
      await pumpKk(tester, build(2, 10));
      expect(idsInOrder(tester).first, 'R-0020');
      expect(idsInOrder(tester), hasLength(10));
    });

    testWidgets('filtering starts on the first page and the footer says what it was narrowed from', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      await pumpKk(tester, table(count: 30, filterable: true, onPageChanged: pages.add));
      await tester.tap(find.bySemanticsLabel('Last page'));
      await tester.pump();
      expect(pages, <int>[7]);
      await tester.enterText(find.byType(EditableText), 'row 1');
      await tester.pump();
      // row 1, row 10 … row 19: eleven rows, first page.
      expect(pages.last, 0);
      expect(idsInOrder(tester), <String>['R-0001', 'R-0010', 'R-0011', 'R-0012']);
      expect(find.text('001–004 / 011 · OF 30'), findsOneWidget);
    });

    testWidgets('no paging: every row, and a footer only when asked for', (WidgetTester tester) async {
      await pumpKk(tester, table(initialPageSize: null));
      expect(byRuntimeType('KkTableFooter'), findsNothing);
      expect(idsInOrder(tester), hasLength(10));
      await pumpKk(
        tester,
        KkDataTable<Pump>(rows: manyPumps(10), rowKey: pumpKey, columns: basicColumns(), showFooter: true),
      );
      expect(find.text('010 ROWS'), findsOneWidget);
      expect(find.byType(KkPagination), findsNothing);
      // A paged table can hide its footer.
      await pumpKk(
        tester,
        KkDataTable<Pump>(
          rows: manyPumps(10),
          rowKey: pumpKey,
          columns: basicColumns(),
          initialPageSize: 4,
          showFooter: false,
        ),
      );
      expect(byRuntimeType('KkTableFooter'), findsNothing);
      expect(idsInOrder(tester), hasLength(4));
    });

    testWidgets('a remote set: the rows are the page; sort, filter and page are only reported', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      final List<KkTableSort?> sorts = <KkTableSort?>[];
      final List<String> filters = <String>[];
      const List<Pump> page = <Pump>[Pump('P-09', 'zulu', 9), Pump('P-03', 'alpha', 3), Pump('P-05', 'mike', 5)];
      await pumpKk(
        tester,
        KkBox(
          width: 600,
          child: KkDataTable<Pump>(
            rows: page,
            rowKey: pumpKey,
            columns: basicColumns(),
            totalRows: 1234,
            pageSize: 3,
            page: 4,
            filterable: true,
            onPageChanged: pages.add,
            onSortChanged: sorts.add,
            onFilterChanged: filters.add,
          ),
        ),
      );
      expect(idsInOrder(tester), <String>['P-09', 'P-03', 'P-05']);
      expect(find.text('0013–0015 / 1234'), findsOneWidget);
      expect(find.descendant(of: find.byType(KkPagination), matching: find.text('005')), findsOneWidget);
      expect(find.text(' / 412'), findsOneWidget);
      await tester.tap(find.text('NAME'));
      await tester.pump();
      expect(sorts, <KkTableSort?>[const KkTableSort('name')]);
      // Not sorted here: that is the owner's job.
      expect(idsInOrder(tester), <String>['P-09', 'P-03', 'P-05']);
      await tester.enterText(find.byType(EditableText), 'alpha');
      await tester.pump();
      expect(filters, <String>['alpha']);
      expect(idsInOrder(tester), <String>['P-09', 'P-03', 'P-05']);
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pump();
      expect(pages.last, 5);
    });
  });
}
