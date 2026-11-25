import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

Widget table({
  double? width = 600,
  double? height = 400,
  List<Pump> rows = pumps,
  List<KkTableColumn<Pump>>? columns,
  bool dense = false,
  bool band = true,
  int? pageSize = 25,
  KkTableSelection selection = KkTableSelection.none,
  bool numbers = false,
  bool detail = false,
}) {
  return KkBox(
    width: width,
    height: height,
    child: KkDataTable<Pump>(
      code: band ? 'TBL-01' : null,
      en: band ? 'pumps' : null,
      rows: rows,
      rowKey: pumpKey,
      columns: columns ?? basicColumns(),
      dense: dense,
      initialPageSize: pageSize,
      selection: selection,
      showRowNumbers: numbers,
      detail: detail ? (BuildContext _, Pump p) => KkText('detail ${p.id}') : null,
    ),
  );
}

void main() {
  setUpAll(loadKkFonts);

  group('sizes from the CSS', () {
    testChecked('band 40, rail 2, header 30, rows 32, footer 36, inside a 1px frame', (WidgetTester tester) async {
      await pumpKk(tester, table());
      expect(tableRect(tester), const Rect.fromLTWH(0, 0, 600, 400));
      expect(globalRect(frameOf(tester)), const Rect.fromLTWH(1, 1, 598, 398));
      expect(tester.getRect(byRuntimeType('KkTableBand')), const Rect.fromLTWH(1, 1, 598, 40));
      final List<RenderBox> rows = cellRows(tester);
      // Header, then the four rows.
      expect(rows, hasLength(5));
      expect(globalRect(rows[0]), const Rect.fromLTWH(1, 43, 598, 30));
      for (int i = 0; i < 4; i++) {
        expect(globalRect(rows[i + 1]), Rect.fromLTWH(1, 73.0 + 32 * i, 598, 32), reason: 'row $i');
      }
      expect(tester.getRect(byRuntimeType('KkTableFooter')), const Rect.fromLTWH(1, 363, 598, 36));
    });

    testChecked('columns: fixed 80, flex, fixed 96; cells are padded by 8', (WidgetTester tester) async {
      await pumpKk(tester, table());
      final KkTableGeometry g = rowOf(tester, 'P-01').link.geometry;
      expect(g.widths, <double>[80, 422, 96]);
      expect(g.offsets, <double>[0, 80, 502]);
      expect(g.rowWidth, 598);
      // Text starts 8px into its column; numbers end 8px before the edge.
      expect(tester.getRect(find.text('P-01')).left, 1 + 8);
      expect(tester.getRect(find.text('coolant loop a')).left, 1 + 80 + 8);
      expect(tester.getRect(find.text('204')).right, 1 + 598 - 8);
      // Header labels sit on the same edges.
      expect(tester.getRect(find.text('ID')).left, 1 + 8);
      expect(tester.getRect(find.text('NAME')).left, 1 + 80 + 8);
    });

    testChecked('cells are 12px mono with tabular figures; dense is 11px on 24px rows under a 24px header', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, table());
      TextStyle style = styleOf(tester, '204');
      expect(style.fontSize, 12);
      expect(style.height, 1.4);
      expect(style.fontFamily, contains('IBM Plex Mono'));
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.color, KkColors.standby.ink);

      await pumpKk(tester, table(dense: true));
      style = styleOf(tester, '204');
      expect(style.fontSize, 11);
      final List<RenderBox> rows = cellRows(tester);
      expect(globalRect(rows[0]), const Rect.fromLTWH(1, 43, 598, 24));
      expect(globalRect(rows[1]), const Rect.fromLTWH(1, 67, 598, 24));
      expect(globalRect(rows[2]).top, 91);
    });

    testChecked('a CJK label on any column makes the header 42 high (36 dense), with the words 4px apart', (
      WidgetTester tester,
    ) async {
      final List<KkTableColumn<Pump>> columns = <KkTableColumn<Pump>>[
        KkTableColumn<Pump>(
          id: 'id',
          cjk: '符号',
          en: 'id',
          width: const KkTableWidth.fixed(120),
          value: (Pump p) => p.id,
        ),
        nameColumn(),
      ];
      await pumpKk(tester, table(columns: columns));
      expect(globalRect(cellRows(tester)[0]).height, 42);
      expect(globalRect(cellRows(tester)[1]).top, 43 + 42);
      final Rect cjk = tester.getRect(find.text('符号'));
      final Rect en = tester.getRect(find.text('ID'));
      expect(cjk.height, 13);
      expect(en.height, 10);
      expect(en.top - cjk.bottom, 4);
      // The pair is centred in the header.
      expect(cjk.top - 43, closeTo((42 - 27) / 2, 0.01));
      final TextStyle cjkStyle = styleOf(tester, '符号');
      expect(cjkStyle.fontSize, 13);
      expect(cjkStyle.color, KkColors.standby.ink);
      final TextStyle enStyle = styleOf(tester, 'ID');
      expect(enStyle.fontSize, 10);
      expect(enStyle.fontWeight, FontWeight.w600);
      expect(enStyle.letterSpacing, closeTo(1.6, 1e-9));
      expect(enStyle.color, KkColors.standby.inkDim);
      // A column without a CJK word keeps its one line, centred.
      final Rect name = tester.getRect(find.text('NAME'));
      expect(name.center.dy, closeTo(43 + 21, 0.01));

      await pumpKk(tester, table(columns: columns, dense: true));
      expect(globalRect(cellRows(tester)[0]).height, 36);
    });

    testChecked('the special columns are 36, 40 and 28 wide, in that order', (WidgetTester tester) async {
      await pumpKk(tester, table(selection: KkTableSelection.multi, numbers: true, detail: true, pageSize: null));
      final KkTableGeometry g = rowOf(tester, 'P-01').link.geometry;
      expect(g.widths.sublist(0, 3), <double>[36, 40, 28]);
      expect(g.widths.sublist(3), <double>[80, 598 - 104 - 80 - 96, 96]);
      // The checkbox is 8px in; the number ends 4px before its column's edge.
      final Rect check = tester.getRect(find.byType(KkCheckbox).at(1));
      expect(check.left, 1 + 8);
      expect(check.size, const Size(16, 16));
      expect(tester.getRect(find.text('01')).right, 1 + 36 + 40 - 4);
      expect(styleOf(tester, '01').fontSize, 11);
      expect(styleOf(tester, '01').color, KkColors.standby.inkDim);
      // The expander is a 24px button in the 28px column.
      final Rect expander = tester.getRect(find.byType(KkIconButton).first);
      expect(expander.size, const Size(24, 24));
      expect(expander.left, 1 + 76 + 2);
    });

    testChecked('the header numbers column reads No in 11px with .06em tracking', (WidgetTester tester) async {
      await pumpKk(tester, table(numbers: true));
      final TextStyle style = styleOf(tester, 'No');
      expect(style.fontSize, 11);
      expect(style.letterSpacing, closeTo(0.66, 1e-9));
      expect(tester.getRect(find.text('No')).right, 1 + 40 - 4);
    });
  });

  group('height', () {
    testChecked('free height: the table is as high as its parts and builds every row', (WidgetTester tester) async {
      await pumpKk(tester, KkScroll(child: table(height: null)));
      // frame 2 + band 40 + rail 2 + header 30 + 4 rows + footer 36.
      expect(tableRect(tester).size, const Size(600, 2 + 40 + 2 + 30 + 4 * 32 + 36));
      expect(rowItems(tester), hasLength(4));
      final RenderBox frame = frameOf(tester);
      expect(frame.getDryLayout(frame.constraints), frame.size);
      expect(frame.getMaxIntrinsicHeight(598), frame.size.height);
      expect(frame.getMinIntrinsicHeight(598), 40 + 2 + 30 + 36);
    });

    testChecked('free height without a band or a footer: rail, header and rows only', (WidgetTester tester) async {
      await pumpKk(tester, KkScroll(child: table(height: null, band: false, pageSize: null)));
      expect(tableRect(tester).size, const Size(600, 2 + 2 + 30 + 4 * 32));
    });

    testChecked('a height limit caps the table and the rows scroll', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          maxHeight: 200,
          width: 600,
          child: KkDataTable<Pump>(rows: manyPumps(40), rowKey: pumpKey, columns: basicColumns()),
        ),
      );
      expect(tableRect(tester).size, const Size(600, 200));
      final RenderBox frame = frameOf(tester);
      expect(frame.getDryLayout(frame.constraints), frame.size);
      // 198 - rail 2 - header 30 = 166 of rows: five full rows and a bit, plus the cache.
      expect(find.text('R-0000'), findsOneWidget);
      expect(find.text('R-0039'), findsNothing);
    });

    testChecked('a fixed height is filled; the rows keep their height and the rest stays empty', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, table(band: false, pageSize: null));
      expect(tableRect(tester).size, const Size(600, 400));
      expect(globalRect(cellRows(tester).last), const Rect.fromLTWH(1, 1 + 2 + 30 + 3 * 32, 598, 32));
    });

    testChecked('inside an expanded slot of a column', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 500,
          height: 300,
          child: KkColumn(
            children: <Widget>[
              const KkBox(height: 50),
              KkExpanded(
                child: KkDataTable<Pump>(rows: manyPumps(30), rowKey: pumpKey, columns: basicColumns()),
              ),
            ],
          ),
        ),
      );
      expect(tableRect(tester), const Rect.fromLTWH(0, 50, 500, 250));
    });

    testChecked('the summary row is 30 high: right under few rows, at the bottom of the rows when they scroll', (
      WidgetTester tester,
    ) async {
      List<KkTableColumn<Pump>> columns() => <KkTableColumn<Pump>>[
        KkTableColumn<Pump>(
          id: 'id',
          en: 'id',
          width: const KkTableWidth.fixed(120),
          value: (Pump p) => p.id,
          summary: (BuildContext _, List<Pump> rows) => const KkTableSummary.title(cjk: '合計', en: 'total'),
        ),
        KkTableColumn<Pump>(
          id: 'flow',
          en: 'flow',
          numeric: true,
          width: const KkTableWidth.flex(),
          value: (Pump p) => p.flow,
          summary: (BuildContext _, List<Pump> rows) => KkTableSummary('${rows.length}', label: 'n'),
        ),
      ];
      await pumpKk(
        tester,
        KkBox(
          width: 400,
          height: 300,
          child: KkDataTable<Pump>(rows: pumps, rowKey: pumpKey, columns: columns()),
        ),
      );
      final List<RenderBox> rows = cellRows(tester);
      // rail 2 + header 30 + 4 rows, then the summary.
      expect(globalRect(rows.last), const Rect.fromLTWH(1, 1 + 2 + 30 + 4 * 32, 398, 30));
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.getRect(find.text('4')).right, 1 + 398 - 8);
      expect(styleOf(tester, '4').fontWeight, FontWeight.w500);
      expect(styleOf(tester, 'N').fontSize, 9);

      await pumpKk(
        tester,
        KkBox(
          width: 400,
          height: 300,
          child: KkDataTable<Pump>(rows: manyPumps(50), rowKey: pumpKey, columns: columns()),
        ),
      );
      // (Rows below the fold are laid out too, so the summary is found by what it shows.)
      expect(rowRectOf(tester, '50'), const Rect.fromLTWH(1, 299 - 30, 398, 30));
    });
  });

  group('width', () {
    testChecked('without a width limit the table is as wide as its columns', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkScroll(
          axis: Axis.horizontal,
          child: KkBox(
            height: 200,
            child: KkDataTable<Pump>(
              rows: pumps,
              rowKey: pumpKey,
              columns: <KkTableColumn<Pump>>[
                idColumn(),
                nameColumn(width: const KkTableWidth.fixed(150)),
                flowColumn(),
              ],
            ),
          ),
        ),
      );
      expect(tableRect(tester).size, const Size(2 + 80 + 150 + 96, 200));
      final RenderBox frame = frameOf(tester);
      expect(frame.getMaxIntrinsicWidth(double.infinity), 326);
      expect(frame.getMinIntrinsicWidth(double.infinity), 0);
    });

    testChecked('content columns fit their header and their cells in the first frame', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 800,
          child: KkDataTable<Pump>(
            rows: pumps,
            rowKey: pumpKey,
            columns: <KkTableColumn<Pump>>[
              idColumn(width: const KkTableWidth.content()),
              KkTableColumn<Pump>(
                id: 'state',
                en: 'st',
                cell: (BuildContext _, Pump p) => KkTableLevel(level: p.level),
              ),
              nameColumn(),
            ],
          ),
        ),
      );
      final KkTableGeometry g = rowOf(tester, 'P-01').link.geometry;
      // The id column is as wide as "P-01" (wider than its header) plus padding.
      final double id = tester.getSize(find.text('P-01')).width;
      expect(g.widths[0], (id + 16).ceilToDouble());
      // The level column is as wide as its widest word with its icon.
      final double critical = tester.getSize(find.byType(KkStateWord).at(1)).width;
      final double nominal = tester.getSize(find.byType(KkStateWord).at(0)).width;
      expect(critical, greaterThan(nominal));
      expect(g.offsets[2] - g.offsets[1], (critical + 16).ceilToDouble());
      // Nothing waits for another frame.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testChecked('columns wider than the table scroll sideways: header, rows and summary together', (
      WidgetTester tester,
    ) async {
      final ScrollController horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          height: 260,
          child: KkDataTable<Pump>(
            rows: pumps,
            rowKey: pumpKey,
            horizontalController: horizontal,
            columns: <KkTableColumn<Pump>>[
              idColumn(width: const KkTableWidth.fixed(200)),
              KkTableColumn<Pump>(
                id: 'name',
                en: 'name',
                width: const KkTableWidth.fixed(200),
                value: (Pump p) => p.name,
                summary: (BuildContext _, List<Pump> rows) => const KkTableSummary('sum'),
              ),
              flowColumn(width: const KkTableWidth.fixed(200)),
            ],
          ),
        ),
      );
      expect(horizontal.position.maxScrollExtent, 600 - 298);
      final List<RenderBox> rows = cellRows(tester);
      expect(rows.first.size.width, 600);
      double left(String text) => tester.getRect(find.text(text)).left;
      expect(left('NAME'), 1 + 200 + 8);
      expect(left('coolant loop a'), 1 + 200 + 8);
      expect(left('sum'), 1 + 200 + 8);
      horizontal.jumpTo(150);
      await tester.pump();
      expect(left('NAME'), 1 + 200 + 8 - 150);
      expect(left('coolant loop a'), 1 + 200 + 8 - 150);
      expect(left('sum'), 1 + 200 + 8 - 150);
      // The table itself does not move.
      expect(tableRect(tester), const Rect.fromLTWH(0, 0, 300, 260));
    });

    testChecked('a truncating column cuts long text with an ellipsis inside its column', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkDataTable<Pump>(
            rows: const <Pump>[Pump('P-01', 'a very long name that cannot possibly fit in this column', 1)],
            rowKey: pumpKey,
            columns: <KkTableColumn<Pump>>[
              idColumn(),
              KkTableColumn<Pump>(
                id: 'name',
                en: 'name',
                width: const KkTableWidth.flex(),
                truncate: true,
                value: (Pump p) => p.name,
              ),
            ],
          ),
        ),
      );
      final Finder text = find.textContaining('a very long name');
      expect(tester.widget<Text>(text).overflow, TextOverflow.ellipsis);
      expect(tester.getRect(text).right, lessThanOrEqualTo(1 + 298 - 8));
      expect(tester.getRect(text).left, 1 + 80 + 8);
    });
  });

  group('edge sizes', () {
    testChecked('zero width, zero height and a zero box do not throw', (WidgetTester tester) async {
      for (final Size size in <Size>[const Size(0, 300), const Size(300, 0), Size.zero, const Size(3, 3)]) {
        await pumpKk(
          tester,
          KkBox(
            width: size.width,
            height: size.height,
            child: KkDataTable<Pump>(
              code: 'T',
              en: 'pumps',
              rows: pumps,
              rowKey: pumpKey,
              columns: basicColumns(),
              filterable: true,
              initialPageSize: 2,
              selection: KkTableSelection.multi,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
        expect(tableRect(tester).size, size);
      }
    });

    testChecked('unbounded in both directions', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkScroll(
          child: KkScroll(
            axis: Axis.horizontal,
            child: KkDataTable<Pump>(rows: pumps, rowKey: pumpKey, columns: basicColumns()),
          ),
        ),
      );
      // 80 + the name header's own width (a flex column's floor is 64) + 96.
      expect(tableRect(tester).size, const Size(2 + 80 + 64 + 96, 2 + 2 + 30 + 4 * 32));
    });
  });
}
