import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

const List<Pump> _rows = <Pump>[
  Pump('P-01', 'delta', 30),
  Pump('P-02', 'alpha', 10),
  Pump('P-03', 'charlie', null),
  Pump('P-04', 'alpha', 20),
  Pump('P-05', 'bravo', 10),
];

Opacity _arrowOf(WidgetTester tester, String label) => tester.widget<Opacity>(
  find.descendant(
    of: find.ancestor(of: find.text(label), matching: byRuntimeType('KkTableHeaderLabel')),
    matching: find.byType(Opacity),
  ),
);

KkIcon _arrowIconOf(WidgetTester tester, String label) => tester.widget<KkIcon>(
  find.descendant(
    of: find.ancestor(of: find.text(label), matching: byRuntimeType('KkTableHeaderLabel')),
    matching: find.byType(KkIcon),
  ),
);

void main() {
  setUpAll(loadKkFonts);

  testWidgets('pressing a header goes none, ascending, descending, none', (WidgetTester tester) async {
    final List<KkTableSort?> changes = <KkTableSort?>[];
    await pumpKk(
      tester,
      KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns(), onSortChanged: changes.add),
    );
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
    await tester.tap(find.text('NAME'));
    await tester.pump();
    // alpha (P-02, P-04 in their own order), bravo, charlie, delta.
    expect(idsInOrder(tester), <String>['P-02', 'P-04', 'P-05', 'P-03', 'P-01']);
    await tester.tap(find.text('NAME'));
    await tester.pump();
    expect(idsInOrder(tester), <String>['P-01', 'P-03', 'P-05', 'P-02', 'P-04']);
    await tester.tap(find.text('NAME'));
    await tester.pump();
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
    expect(changes, <KkTableSort?>[
      const KkTableSort('name'),
      const KkTableSort('name', KkSortDirection.descending),
      null,
    ]);
  });

  testWidgets('the sort is stable and rows without a value go last both ways', (WidgetTester tester) async {
    await pumpKk(tester, KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns()));
    await tester.tap(find.text('FLOW'));
    await tester.pump();
    // 10 (P-02 before P-05, as given), 20, 30, then the row without a flow.
    expect(idsInOrder(tester), <String>['P-02', 'P-05', 'P-04', 'P-01', 'P-03']);
    await tester.tap(find.text('FLOW'));
    await tester.pump();
    expect(idsInOrder(tester), <String>['P-01', 'P-04', 'P-02', 'P-05', 'P-03']);
  });

  testWidgets('another column starts ascending again', (WidgetTester tester) async {
    await pumpKk(tester, KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns()));
    await tester.tap(find.text('NAME'));
    await tester.pump();
    await tester.tap(find.text('NAME'));
    await tester.pump();
    await tester.tap(find.text('ID'));
    await tester.pump();
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
    expect(_arrowOf(tester, 'ID').opacity, 1);
    expect(_arrowOf(tester, 'NAME').opacity, 0);
  });

  testWidgets('a table that keeps its own sort starts with initialSort', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: _rows,
        rowKey: pumpKey,
        columns: basicColumns(),
        initialSort: const KkTableSort('flow', KkSortDirection.descending),
      ),
    );
    expect(idsInOrder(tester), <String>['P-01', 'P-04', 'P-02', 'P-05', 'P-03']);
  });

  testWidgets('a controlled sort changes only when the owner says so', (WidgetTester tester) async {
    final List<KkTableSort?> asked = <KkTableSort?>[];
    Widget build(KkTableSort sort) =>
        KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns(), sort: sort, onSortChanged: asked.add);
    await pumpKk(tester, build(const KkTableSort('flow')));
    expect(idsInOrder(tester), <String>['P-02', 'P-05', 'P-04', 'P-01', 'P-03']);
    await tester.tap(find.text('FLOW'));
    await tester.pump();
    // Asked for descending; the owner has not answered.
    expect(asked, <KkTableSort?>[const KkTableSort('flow', KkSortDirection.descending)]);
    expect(idsInOrder(tester), <String>['P-02', 'P-05', 'P-04', 'P-01', 'P-03']);
    await pumpKk(tester, build(const KkTableSort('flow', KkSortDirection.descending)));
    expect(idsInOrder(tester), <String>['P-01', 'P-04', 'P-02', 'P-05', 'P-03']);
    // Controlled and unsorted: a press asks, nothing moves.
    await pumpKk(tester, build(KkTableSort.none));
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
    await tester.tap(find.text('NAME'));
    await tester.pump();
    expect(asked.last, const KkTableSort('name'));
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
  });

  testWidgets('a column can order rows its own way', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: _rows,
        rowKey: pumpKey,
        initialSort: const KkTableSort('len'),
        columns: <KkTableColumn<Pump>>[
          idColumn(),
          KkTableColumn<Pump>(
            id: 'len',
            en: 'name length',
            sortable: true,
            cell: (BuildContext _, Pump p) => KkText(p.name),
            compare: (Pump a, Pump b) => a.name.length.compareTo(b.name.length),
          ),
        ],
      ),
    );
    // delta(5) alpha(5) alpha(5) bravo(5) stay in order, charlie(7) last.
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-04', 'P-05', 'P-03']);
  });

  testWidgets('a sort that names a missing or unsortable column leaves the rows as they are', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: _rows,
        rowKey: pumpKey,
        sort: const KkTableSort('gone'),
        columns: <KkTableColumn<Pump>>[
          idColumn(),
          KkTableColumn<Pump>(id: 'name', en: 'name', value: (Pump p) => p.name),
        ],
      ),
    );
    expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04', 'P-05']);
    // A column that is not sortable has no button and no arrow.
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('NAME'), matching: byRuntimeType('KkTableHeaderLabel')),
        matching: find.byType(KkIcon),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the arrow keeps its place, shows on hover and stays in signal while sorted', (
    WidgetTester tester,
  ) async {
    traditionalHighlights();
    await pumpKk(tester, KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns()));
    const KkColors c = KkColors.standby;
    expect(_arrowOf(tester, 'NAME').opacity, 0);
    expect(_arrowIconOf(tester, 'NAME').size, 10);
    final Rect label = tester.getRect(find.text('NAME'));
    final Rect arrow = tester.getRect(
      find.descendant(
        of: find.ancestor(of: find.text('NAME'), matching: byRuntimeType('KkTableHeaderLabel')),
        matching: find.byType(KkIcon),
      ),
    );
    expect(arrow.left - label.right, 4);
    expect(styleOf(tester, 'NAME').color, c.inkDim);

    final TestGesture pointer = await mouse(tester);
    await pointer.moveTo(tester.getCenter(find.text('NAME')));
    await tester.pump();
    expect(_arrowOf(tester, 'NAME').opacity, 1);
    expect(_arrowIconOf(tester, 'NAME').color, c.inkDim);
    expect(_arrowIconOf(tester, 'NAME').icon, KkIcons.arrowUp);
    await pointer.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(_arrowOf(tester, 'NAME').opacity, 0);

    await tester.tap(find.text('NAME'));
    await tester.pump();
    expect(_arrowOf(tester, 'NAME').opacity, 1);
    expect(_arrowIconOf(tester, 'NAME').color, c.signal);
    expect(styleOf(tester, 'NAME').color, c.ink);
    // The label did not move when the arrow appeared.
    expect(tester.getRect(find.text('NAME')), label);
    await tester.tap(find.text('NAME'));
    await tester.pump();
    expect(_arrowIconOf(tester, 'NAME').icon, KkIcons.arrowDown);
  });

  testWidgets('headers are reachable and usable with the keyboard, and say their state', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(tester, KkDataTable<Pump>(rows: _rows, rowKey: pumpKey, columns: basicColumns()));
    expect(find.bySemanticsLabel('name, not sorted'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The first stop is the first sortable header.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.bySemanticsLabel('id, sorted ascending'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.bySemanticsLabel('name, sorted ascending'), findsOneWidget);
    expect(find.bySemanticsLabel('id, not sorted'), findsOneWidget);
    expect(idsInOrder(tester), <String>['P-02', 'P-04', 'P-05', 'P-03', 'P-01']);
    final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('name, sorted ascending'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isFocused, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('sorting goes back to the top of the rows', (WidgetTester tester) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    await pumpKk(
      tester,
      KkBox(
        height: 200,
        child: KkDataTable<Pump>(
          rows: manyPumps(60),
          rowKey: pumpKey,
          columns: basicColumns(),
          scrollController: vertical,
        ),
      ),
    );
    vertical.jumpTo(600);
    await tester.pump();
    await tester.tap(find.text('FLOW'));
    await tester.pump();
    expect(vertical.offset, 0);
  });
}
