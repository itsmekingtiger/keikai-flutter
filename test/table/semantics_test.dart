import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

List<SemanticsNode> _children(SemanticsNode node) {
  final List<SemanticsNode> out = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    out.add(child);
    return true;
  });
  return out;
}

/// Every node under [root] (and [root]) for which [test] holds.
List<SemanticsNode> _where(SemanticsNode root, bool Function(SemanticsNode node) test) {
  final List<SemanticsNode> out = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (test(node)) out.add(node);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return out;
}

SemanticsNode _root(WidgetTester tester) => tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;

void main() {
  setUpAll(loadKkFonts);

  Widget table({
    List<Pump> rows = pumps,
    bool loading = false,
    Set<Object>? expanded,
    KkTableSelection selection = KkTableSelection.multi,
    ValueChanged<Pump>? onRowPressed,
    double? height,
  }) => KkBox(
    width: 700,
    height: height,
    child: KkDataTable<Pump>(
      code: 'TBL-01',
      cjk: '機器',
      en: 'pumps',
      rows: rows,
      rowKey: pumpKey,
      loading: loading,
      selection: selection,
      showRowNumbers: true,
      expanded: expanded,
      onRowPressed: onRowPressed,
      rowSemanticLabel: (Pump p) => 'pump ${p.id}',
      detail: (BuildContext _, Pump p) => KkText('about ${p.id}'),
      columns: <KkTableColumn<Pump>>[
        KkTableColumn<Pump>(id: 'id', en: 'id', value: (Pump p) => p.id, sortable: true),
        KkTableColumn<Pump>(
          id: 'name',
          cjk: '名称',
          en: 'name',
          semanticLabel: 'pump name',
          value: (Pump p) => p.name,
          editable: true,
          onEdited: (Pump p, String text) {},
        ),
        KkTableColumn<Pump>(
          id: 'state',
          cjk: '状態',
          cell: (BuildContext _, Pump p) => KkTableLevel(level: p.level),
          summary: (BuildContext _, List<Pump> rows) => const KkTableSummary('4', label: 'n'),
        ),
      ],
    ),
  );

  testWidgets('the rows are a table of rows of cells, and the framework accepts the tree', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(tester, table(expanded: const <Object>{'P-02'}));
    expect(tester.takeException(), isNull);
    final List<SemanticsNode> tables = _where(_root(tester), (SemanticsNode n) => n.role == SemanticsRole.table);
    expect(tables, hasLength(1));
    final List<SemanticsNode> rows = _children(tables.single);
    expect(rows, hasLength(4));
    for (final SemanticsNode row in rows) {
      expect(row.role, SemanticsRole.row);
      for (final SemanticsNode cell in _children(row)) {
        expect(cell.role, SemanticsRole.cell);
      }
    }
    // Checkbox, number, expander, three data cells; the open row has its detail as a seventh.
    expect(_children(rows[0]), hasLength(6));
    expect(_children(rows[1]), hasLength(7));
    expect(rows[0].label, 'pump P-01');
    expect(rows[0].indexInParent, 0);
    expect(rows[3].indexInParent, 3);
    semantics.dispose();
  });

  testWidgets('cells are named after their columns and read their content', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(tester, table());
    final SemanticsNode row = tester.getSemantics(find.bySemanticsLabel('pump P-03'));
    final List<SemanticsNode> cells = _children(row);
    // The id cell: the column's name, then the value.
    expect(cells[3].label, 'id\nP-03');
    // An explicit semantic label wins over the header words; the editable value is a button inside the cell.
    expect(cells[4].label, 'pump name');
    final List<SemanticsNode> edit = _where(cells[4], (SemanticsNode n) => n.label.startsWith('Edit pump name'));
    expect(edit, hasLength(1));
    expect(edit.single.label, 'Edit pump name\nfeed water');
    expect(edit.single.flagsCollection.isButton, isTrue);
    // A column with only a CJK word is named by it; the level reads as its word.
    expect(cells[5].label, '状態\nCAUTION');
    // The controls of the special cells.
    expect(_where(cells[0], (SemanticsNode n) => n.label == 'Select row'), hasLength(1));
    expect(_where(cells[2], (SemanticsNode n) => n.label == 'Expand row'), hasLength(1));
    semantics.dispose();
  });

  testWidgets('the table is named by its title; headers are headers, sortable ones are buttons', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(tester, table());
    expect(find.bySemanticsLabel(RegExp('TBL-01 機器 pumps')), findsOneWidget);
    final SemanticsNode id = tester.getSemantics(find.bySemanticsLabel('id, not sorted'));
    expect(id.flagsCollection.isButton, isTrue);
    // The name column cannot be sorted: its header is a header and nothing else.
    final List<SemanticsNode> headers = _where(
      _root(tester),
      (SemanticsNode n) => n.label == 'pump name' && n.flagsCollection.isHeader,
    );
    expect(headers, hasLength(1));
    expect(headers.single.flagsCollection.isButton, isFalse);
    semantics.dispose();
  });

  testWidgets('a row that can be pressed has a tap action; selection is a state of the row', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String> pressed = <String>[];
    await pumpKk(tester, table(onRowPressed: (Pump p) => pressed.add(p.id)));
    final SemanticsNode row = tester.getSemantics(find.bySemanticsLabel('pump P-04'));
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(row.flagsCollection.isSelected, Tristate.isFalse);
    tester.semantics.tap(find.semantics.byLabel('pump P-04'));
    await tester.pump();
    expect(pressed, <String>['P-04']);

    await pumpKk(tester, const SizedBox());
    await pumpKk(tester, table(selection: KkTableSelection.none));
    final SemanticsNode plain = tester.getSemantics(find.bySemanticsLabel('pump P-04'));
    expect(plain.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(plain.flagsCollection.isSelected, Tristate.none);
    semantics.dispose();
  });

  testWidgets('skeleton rows, an empty table and a scrolled table are valid trees too', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(tester, table(rows: const <Pump>[], loading: true));
    expect(tester.takeException(), isNull);
    SemanticsNode tableNode = _where(_root(tester), (SemanticsNode n) => n.role == SemanticsRole.table).single;
    expect(_children(tableNode), hasLength(6));
    for (final SemanticsNode row in _children(tableNode)) {
      expect(row.role, SemanticsRole.row);
      expect(row.label, 'Loading');
      expect(_children(row), isEmpty);
    }
    await pumpKk(tester, table(rows: const <Pump>[]));
    expect(tester.takeException(), isNull);
    expect(_where(_root(tester), (SemanticsNode n) => n.role == SemanticsRole.table), isEmpty);
    expect(find.bySemanticsLabel(RegExp('NO RECORDS')), findsOneWidget);

    await pumpKk(tester, table(rows: manyPumps(200), height: 300));
    expect(tester.takeException(), isNull);
    tableNode = _where(_root(tester), (SemanticsNode n) => n.role == SemanticsRole.table).single;
    for (final SemanticsNode row in _children(tableNode)) {
      expect(row.role, SemanticsRole.row);
    }
    // The rows can be scrolled by assistive technology.
    final List<SemanticsNode> scrollers = _where(
      _root(tester),
      (SemanticsNode n) => n.getSemanticsData().hasAction(SemanticsAction.scrollUp),
    );
    expect(scrollers, isNotEmpty);
    semantics.dispose();
  });
}
