import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/table/layout.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

Widget _table({
  List<Pump> rows = pumps,
  bool loading = false,
  int skeletonRows = 6,
  bool dense = false,
  double? width = 600,
  double? height,
  bool filterable = false,
  String? filter,
  Widget Function(BuildContext context, bool noMatch)? emptyBuilder,
  KkTableSelection selection = KkTableSelection.none,
  bool frame = true,
  Color? fill,
  List<KkTableColumn<Pump>>? columns,
}) => KkBox(
  width: width,
  height: height,
  child: KkDataTable<Pump>(
    en: 'pumps',
    rows: rows,
    rowKey: pumpKey,
    columns: columns ?? basicColumns(),
    loading: loading,
    skeletonRows: skeletonRows,
    dense: dense,
    filterable: filterable,
    filter: filter,
    emptyBuilder: emptyBuilder,
    selection: selection,
    frame: frame,
    fill: fill,
  ),
);

/// The loading rail: the 2px box right under the band.
RenderKkBox _rail(WidgetTester tester) {
  final double top = tester.getRect(byRuntimeType('KkTableBand')).bottom;
  return tester
      .renderObjectList<RenderKkBox>(find.byType(KkBox))
      .firstWhere(
        (RenderKkBox b) => b.size.height == 2 && b.localToGlobal(Offset.zero).dy == top && b.size.width > 100,
      );
}

void main() {
  setUpAll(loadKkFonts);

  group('loading', () {
    testChecked('the rail is always there, 2px under the band; it scans in signal over signal-dim while loading', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await pumpKk(tester, _table());
      expect(globalRect(_rail(tester)), const Rect.fromLTWH(1, 41, 598, 2));
      expect(_rail(tester).decoration, isNull);
      expect(find.byType(KkScanBar), findsNothing);
      final double header = globalRect(cellRows(tester).first).top;

      await pumpKk(tester, _table(loading: true));
      expect(globalRect(_rail(tester)), const Rect.fromLTWH(1, 41, 598, 2));
      expect(_rail(tester).decoration!.fill, c.signalDim);
      final KkScanBar scan = tester.widget<KkScanBar>(find.byType(KkScanBar));
      expect(scan.color, c.signal);
      expect(scan.period, const Duration(milliseconds: 1200));
      expect(scan.steps, 12);
      expect(scan.widthFactor, 0.25);
      // Nothing moved, and the rows are still there.
      expect(globalRect(cellRows(tester).first).top, header);
      expect(idsInOrder(tester), hasLength(4));
    });

    testWidgets('the rail\'s block crosses in twelve steps of 100ms; with motion off it rests at the left', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await tester.pumpWidget(kkHarness(_table(loading: true), motion: true));
      final Finder paint = find.descendant(of: find.byType(KkScanBar), matching: find.byType(CustomPaint));
      // Sampled every 50ms for 1.2s: each place is seen twice, and there are twelve of them
      // (in the first the block is still off the left edge and nothing is painted).
      final List<Rect?> blocks = <Rect?>[];
      for (int i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final RenderBox box = tester.renderObject<RenderBox>(paint);
        Rect? block;
        expect(
          box,
          anyOf(
            paintsNothing,
            paints..something((Symbol method, List<dynamic> arguments) {
              if (method != #drawRect) return false;
              block = arguments[0] as Rect;
              return true;
            }),
          ),
          reason: 'frame $i',
        );
        blocks.add(block);
      }
      expect(blocks.toSet(), hasLength(12));
      // A quarter of the rail wide once it is fully in.
      expect(
        blocks.whereType<Rect>().map((Rect r) => r.width).reduce((double a, double b) => a > b ? a : b),
        closeTo(598 / 4, 1e-6),
      );
      await tester.pumpWidget(kkHarness(_table(loading: true)));
      final RenderBox box = tester.renderObject<RenderBox>(paint);
      expect(box, paints..rect(rect: Rect.fromLTWH(0, 0, box.size.width * 0.25, 2), color: c.signal));
    });

    testChecked('loading without rows shows skeleton rows: 8px bars, 10px in from the column edges', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await pumpKk(tester, _table(rows: const <Pump>[], loading: true, selection: KkTableSelection.multi));
      final List<RenderBox> rows = cellRows(tester);
      // Header and six skeleton rows.
      expect(rows, hasLength(7));
      expect(globalRect(rows[1]), const Rect.fromLTWH(1, 73, 598, 32));
      expect(globalRect(rows[6]).bottom, 73 + 6 * 32);
      expect(tableRect(tester).height, 2 + 40 + 2 + 30 + 6 * 32);
      // One bar per data column, none in the checkbox column; the scan of the rail is the other one.
      final Finder bars = find.byWidgetPredicate(
        (Widget w) => w is KkScanBar && w.period == const Duration(milliseconds: 1400),
      );
      expect(bars, findsNWidgets(18));
      expect(tester.widget<KkScanBar>(bars.first).color, c.signalDim);
      expect(tester.widget<KkScanBar>(bars.first).steps, 14);
      final Rect first = tester.getRect(find.ancestor(of: bars.first, matching: find.byType(KkBox)).first);
      // The id column starts after the 36px checkbox column.
      expect(first, const Rect.fromLTWH(1 + 36 + 10, 73 + 12, 80 - 20, 8));
      expect(
        tester
            .renderObject<RenderKkBox>(find.ancestor(of: bars.first, matching: find.byType(KkBox)).first)
            .decoration!
            .fill,
        c.bg200,
      );
      expect(find.text('NO RECORDS'), findsNothing);
      // The header checkbox has nothing to select.
      expect(tester.widget<KkCheckbox>(find.byType(KkCheckbox)).onChanged, isNull);
    });

    testChecked('the number of skeleton rows can be set; dense ones are 24 high; none means the empty block', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table(rows: const <Pump>[], loading: true, skeletonRows: 3, dense: true));
      final List<RenderBox> rows = cellRows(tester);
      expect(rows, hasLength(4));
      expect(globalRect(rows[1]).height, 24);
      await pumpKk(tester, _table(rows: const <Pump>[], loading: true, skeletonRows: 0));
      expect(find.text('NO RECORDS'), findsOneWidget);
    });

    testChecked('rows that arrive replace the skeleton', (WidgetTester tester) async {
      await pumpKk(tester, _table(rows: const <Pump>[], loading: true));
      expect(idsInOrder(tester), isEmpty);
      await pumpKk(tester, _table());
      expect(idsInOrder(tester), hasLength(4));
      expect(find.byType(KkScanBar), findsNothing);
      expect(tableRect(tester).height, 2 + 40 + 2 + 30 + 4 * 32);
    });
  });

  group('empty', () {
    testChecked('no rows: a CJK word in 26px over capitals, 24px of room around, centred under the header', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await pumpKk(tester, _table(rows: const <Pump>[]));
      expect(styleOf(tester, '無記録').fontSize, 26);
      expect(styleOf(tester, '無記録').color, c.inkDim);
      final TextStyle en = styleOf(tester, 'NO RECORDS');
      expect(en.fontSize, 11);
      expect(en.fontWeight, FontWeight.w700);
      expect(en.letterSpacing, closeTo(1.76, 1e-9));
      expect(en.color, c.inkFaint);
      final Rect cjk = tester.getRect(find.text('無記録'));
      final Rect label = tester.getRect(find.text('NO RECORDS'));
      // Header ends at 73. 24 above, 26 + 8 + 11, 24 below and the 1px line.
      expect(cjk.top, 73 + 24);
      expect(label.top - cjk.bottom, 8);
      expect(tableRect(tester).height, 2 + 40 + 2 + 30 + 24 + 26 + 8 + 11 + 24 + 1);
      expect(label.center.dx, closeTo(300, 0.5));
      final RenderBox frame = frameOf(tester);
      expect(frame.getDryLayout(frame.constraints), frame.size);
      // No rows: no scroll view, and nothing for the keyboard to stand on.
      expect(find.byType(CustomScrollView), findsNothing);
    });

    testChecked('in a table with a height the block sits right under the header; a tiny table cuts it', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table(rows: const <Pump>[], height: 400));
      expect(tester.getRect(find.text('無記録')).top, 73 + 24);
      expect(tableRect(tester).height, 400);
      await pumpKk(tester, _table(rows: const <Pump>[], height: 90));
      expect(tester.takeException(), isNull);
      expect(tableRect(tester).height, 90);
    });

    testChecked('a filter that leaves nothing says so; a builder can replace either block', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table(filterable: true, filter: 'zzz'));
      expect(find.text('該当無'), findsOneWidget);
      expect(find.text('NO MATCH'), findsOneWidget);
      expect(find.text('NO RECORDS'), findsNothing);

      final List<bool> asked = <bool>[];
      Widget builder(BuildContext context, bool noMatch) {
        asked.add(noMatch);
        return KkBox(height: 50, child: KkText(noMatch ? 'nothing matches' : 'nothing here'));
      }

      await pumpKk(tester, _table(filterable: true, filter: 'zzz', emptyBuilder: builder));
      expect(find.text('nothing matches'), findsOneWidget);
      expect(tableRect(tester).height, 2 + 40 + 2 + 30 + 50);
      await pumpKk(tester, _table(rows: const <Pump>[], emptyBuilder: builder));
      expect(find.text('nothing here'), findsOneWidget);
      expect(asked.last, isFalse);
    });

    testChecked('the block is centred in the table, not in columns that are wider than it', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        _table(
          rows: const <Pump>[],
          width: 300,
          columns: <KkTableColumn<Pump>>[
            idColumn(width: const KkTableWidth.fixed(400)),
            nameColumn(width: const KkTableWidth.fixed(400)),
          ],
        ),
      );
      expect(tester.getRect(find.text('NO RECORDS')).center.dx, closeTo(150, 0.5));
    });
  });

  group('themes and frame', () {
    testWidgets('alert: the chrome follows the theme', (WidgetTester tester) async {
      const KkColors c = KkColors.alertTheme;
      await pumpKk(
        tester,
        KkBox(
          width: 600,
          child: KkDataTable<Pump>(
            code: 'TBL-01',
            en: 'pumps',
            rows: pumps,
            rowKey: pumpKey,
            columns: basicColumns(),
            selection: KkTableSelection.multi,
            initialPageSize: 10,
            loading: true,
          ),
        ),
        condition: KkCondition.alert,
      );
      final RenderKkBox outer = tester.renderObject<RenderKkBox>(
        find.ancestor(of: byRuntimeType('KkTableFrame'), matching: find.byType(KkBox)).first,
      );
      expect(outer.decoration!.fill, c.bg100);
      expect(outer.decoration!.edges.top, KkSide(c.line, width: 1));
      final RenderKkBox band = tester.renderObject<RenderKkBox>(
        find.descendant(of: byRuntimeType('KkTableBand'), matching: find.byType(KkBox)).first,
      );
      expect(band.decoration!.fill, c.bg200);
      expect(band.decoration!.edges.bottom.color, c.line);
      expect(
        tester
            .renderObject<RenderKkSurface>(find.ancestor(of: find.text('TBL-01'), matching: find.byType(KkSurface)))
            .fill,
        c.signal,
      );
      expect(_rail(tester).decoration!.fill, c.signalDim);
      final KkTableRowPaint header = (cellRows(tester).first as RenderKkTableCells).look!;
      expect(header.background, c.bg200);
      expect(header.lineBottom, c.line);
      expect(lookOf(tester, 'P-01').lineBottom, c.bg200);
      expect(styleOf(tester, 'P-01').color, c.ink);
      final RenderKkBox footer = tester.renderObject<RenderKkBox>(
        find.descendant(of: byRuntimeType('KkTableFooter'), matching: find.byType(KkBox)).first,
      );
      expect(footer.decoration!.edges.top.color, c.line);
      await tester.tap(inRow('P-01', find.byType(KkCheckbox)));
      await tester.pump();
      expect(lookOf(tester, 'P-01').background, c.bg300);
      expect(
        tester
            .renderObject<RenderKkBox>(
              find.descendant(of: byRuntimeType('KkTableBand'), matching: find.byType(KkBox)).first,
            )
            .decoration!
            .fill,
        c.signal,
      );
    });

    testChecked('without the frame the table has no border and is 2px less each way; the ground can be set', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table(frame: false, fill: const Color(0xFF102030)));
      final RenderKkBox outer = tester.renderObject<RenderKkBox>(
        find.ancestor(of: byRuntimeType('KkTableFrame'), matching: find.byType(KkBox)).first,
      );
      expect(outer.decoration!.edges, KkEdges.none);
      expect(outer.decoration!.fill, const Color(0xFF102030));
      expect(globalRect(frameOf(tester)), const Rect.fromLTWH(0, 0, 600, 40 + 2 + 30 + 4 * 32));
    });
  });
}
