import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

/// The id of the row that shows the keyboard focus, or null.
String? _focused(WidgetTester tester) {
  for (final String id in idsInOrder(tester)) {
    if (lookOf(tester, id).focus != null) return id;
  }
  return null;
}

void main() {
  setUpAll(loadKkFonts);

  Widget table({
    int count = 40,
    double? height = 300,
    ScrollController? vertical,
    ScrollController? horizontal,
    ValueChanged<Pump>? onRowPressed,
    KkTableSelection selection = KkTableSelection.none,
    ValueChanged<Set<Object>>? onSelectionChanged,
    bool autofocus = false,
    List<KkTableColumn<Pump>>? columns,
    double width = 500,
  }) => KkBox(
    width: width,
    height: height,
    child: KkDataTable<Pump>(
      rows: manyPumps(count),
      rowKey: pumpKey,
      columns:
          columns ??
          <KkTableColumn<Pump>>[
            KkTableColumn<Pump>(id: 'id', en: 'id', width: const KkTableWidth.fixed(100), value: (Pump p) => p.id),
            KkTableColumn<Pump>(id: 'name', en: 'name', width: const KkTableWidth.flex(), value: (Pump p) => p.name),
          ],
      scrollController: vertical,
      horizontalController: horizontal,
      onRowPressed: onRowPressed,
      selection: selection,
      onSelectionChanged: onSelectionChanged,
      autofocus: autofocus,
    ),
  );

  testWidgets('Tab reaches the rows as one stop and marks the first row with a 2px line inside its edge', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      KkColumn(
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          table(),
          KkButton(label: 'after', onPressed: () {}),
        ],
      ),
    );
    expect(_focused(tester), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), 'R-0000');
    const KkColors c = KkColors.standby;
    expect(lookOf(tester, 'R-0000').focus, c.focus);
    expect(lookOf(tester, 'R-0000').focusWidth, 2);
    final RenderBox row = rowOf(tester, 'R-0000');
    expect(
      row,
      paints
        // The line under the row, then the mark over the cells.
        ..rect(color: c.bg200)
        ..rect(
          rect: Rect.fromLTWH(1, 1, row.size.width - 2, 30),
          color: c.focus,
          strokeWidth: 2,
          style: PaintingStyle.stroke,
        ),
    );
    // The mark is paint only: nothing moved.
    expect(rowRectOf(tester, 'R-0000'), const Rect.fromLTWH(1, 33, 498, 32));
    // The next Tab leaves the table: the rows are a single stop.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), isNull);
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<KkButton>(), isNotNull);
    // And Shift+Tab comes back to the row it left.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), 'R-0000');
  });

  testWidgets('Down, Up, Home, End, Page Down and Page Up move the row and bring it into view', (
    WidgetTester tester,
  ) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    await pumpKk(tester, table(vertical: vertical));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0002');
    expect(vertical.offset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_focused(tester), 'R-0001');
    // 266 of view: eight full rows; a page is one row less than what fits.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_focused(tester), 'R-0008');
    // Row 8 ends at 288: the view moves just enough to show it.
    expect(vertical.offset, 9 * 32 - 266);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_focused(tester), 'R-0039');
    expect(vertical.offset, vertical.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0039');
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(_focused(tester), 'R-0032');
    expect(vertical.offset, vertical.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(_focused(tester), 'R-0025');
    // Moving up shows the row at the top edge.
    expect(vertical.offset, 25 * 32);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_focused(tester), 'R-0000');
    expect(vertical.offset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_focused(tester), 'R-0000');
  });

  testWidgets('a held arrow key keeps moving', (WidgetTester tester) async {
    await pumpKk(tester, table());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0003');
  });

  testWidgets('End in ten thousand rows lands on the last row without building the rest', (WidgetTester tester) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    int built = 0;
    await pumpKk(
      tester,
      table(
        count: 10000,
        vertical: vertical,
        columns: <KkTableColumn<Pump>>[
          KkTableColumn<Pump>(
            id: 'id',
            en: 'id',
            width: const KkTableWidth.flex(),
            cell: (BuildContext _, Pump p) {
              built++;
              return KkText(p.id);
            },
          ),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    built = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), 'R-9999');
    expect(rowRectOf(tester, 'R-9999').bottom, 299);
    expect(built, lessThan(80));
  });

  testWidgets('a press on a row moves the keyboard there without showing the mark; the next key shows it', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, table());
    await tester.tap(find.text('row 4'));
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0005');
    // The pointer takes the mark away again.
    await tester.tap(find.text('row 2'));
    await tester.pump();
    expect(_focused(tester), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_focused(tester), 'R-0001');
  });

  testWidgets('Enter activates the row; held Enter does not repeat', (WidgetTester tester) async {
    final List<String> pressed = <String>[];
    await pumpKk(tester, table(onRowPressed: (Pump p) => pressed.add(p.id)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    expect(pressed, <String>['R-0001', 'R-0001']);
  });

  testWidgets('Space selects, Shift+Space selects a range, Ctrl+A the page', (WidgetTester tester) async {
    Set<Object> selection = <Object>{};
    await pumpKk(
      tester,
      table(count: 6, selection: KkTableSelection.multi, onSelectionChanged: (Set<Object> s) => selection = s),
    );
    // Past the header checkbox to the rows.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(_focused(tester), 'R-0000');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selection, <Object>{'R-0001'});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(selection, <Object>{'R-0001', 'R-0002', 'R-0003'});
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selection, <Object>{'R-0001', 'R-0002'});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(selection, hasLength(6));
    // Without selection the keys are not taken.
    await pumpKk(tester, const SizedBox());
    await pumpKk(tester, table(count: 6));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isFalse);
  });

  testWidgets('moving up and down does not move a table that is scrolled sideways', (WidgetTester tester) async {
    final ScrollController horizontal = ScrollController();
    final ScrollController vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    await pumpKk(
      tester,
      table(
        width: 300,
        horizontal: horizontal,
        vertical: vertical,
        columns: <KkTableColumn<Pump>>[
          KkTableColumn<Pump>(id: 'id', en: 'id', width: const KkTableWidth.fixed(300), value: (Pump p) => p.id),
          KkTableColumn<Pump>(id: 'name', en: 'name', width: const KkTableWidth.fixed(300), value: (Pump p) => p.name),
        ],
      ),
    );
    horizontal.jumpTo(180);
    await tester.pump();
    await tester.tap(find.text('row 2'));
    await tester.pump();
    for (int i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
    }
    expect(_focused(tester), 'R-0014');
    expect(horizontal.offset, 180);
    expect(vertical.offset, 15 * 32 - 266);
  });

  testWidgets('in a page that scrolls, the focused row is brought into view there', (WidgetTester tester) async {
    final ScrollController outer = ScrollController();
    addTearDown(outer.dispose);
    await pumpKk(tester, KkScroll(controller: outer, child: table(height: null)));
    await tester.tap(find.text('row 3'));
    await tester.pump();
    for (int i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
    }
    expect(_focused(tester), 'R-0033');
    expect(outer.offset, greaterThan(0));
    final Rect row = rowRectOf(tester, 'R-0033');
    expect(row.top, greaterThanOrEqualTo(0));
    expect(row.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('autofocus puts the keyboard on the rows; an empty table has no rows to take it', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, table(autofocus: true));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0001');
    await pumpKk(tester, const SizedBox());
    await pumpKk(tester, table(count: 0, autofocus: true));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows that are replaced under the focus leave the keyboard on a row that exists', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, table(count: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_focused(tester), 'R-0009');
    await pumpKk(tester, table(count: 4));
    expect(_focused(tester), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focused(tester), 'R-0000');
  });
}
