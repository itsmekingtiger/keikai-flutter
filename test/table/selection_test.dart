import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

/// The checkbox of the row that shows [id] (index 0 is the header's).
Finder _rowCheck(String id) => find.descendant(
  of: find.ancestor(of: find.text(id), matching: byRuntimeType('KkTableCells')).first,
  matching: find.byType(KkCheckbox),
);

Finder get _headerCheck => find.byType(KkCheckbox).first;

bool? _value(WidgetTester tester, Finder check) => tester.widget<KkCheckbox>(check).value;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('no selection: no checkbox column, no band, a press on a row does nothing', (WidgetTester tester) async {
    await pumpKk(tester, KkDataTable<Pump>(rows: pumps, rowKey: pumpKey, columns: basicColumns()));
    expect(find.byType(KkCheckbox), findsNothing);
    expect(byRuntimeType('KkTableBand'), findsNothing);
    await tester.tap(find.text('coolant loop a'));
    await tester.pump();
    expect(lookOf(tester, 'P-01').background, isNull);
  });

  testWidgets('multi: checkboxes, the header checkbox goes empty, dash, tick, and the band counts', (
    WidgetTester tester,
  ) async {
    final List<Set<Object>> changes = <Set<Object>>[];
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        en: 'pumps',
        rows: pumps,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        onSelectionChanged: changes.add,
      ),
    );
    expect(find.byType(KkCheckbox), findsNWidgets(5));
    expect(_value(tester, _headerCheck), isFalse);
    expect(find.text('PUMPS'), findsOneWidget);

    await tester.tap(_rowCheck('P-02'));
    await tester.pump();
    expect(changes.last, <Object>{'P-02'});
    expect(_value(tester, _rowCheck('P-02')), isTrue);
    expect(_value(tester, _headerCheck), isNull);
    expect(lookOf(tester, 'P-02').background, KkColors.standby.bg300);
    // The band now counts the selection instead of showing the title.
    expect(find.text('PUMPS'), findsNothing);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('選択'), findsOneWidget);
    expect(find.text('SELECTED'), findsOneWidget);

    await tester.tap(_headerCheck);
    await tester.pump();
    expect(changes.last, <Object>{'P-01', 'P-02', 'P-03', 'P-04'});
    expect(_value(tester, _headerCheck), isTrue);
    expect(find.text('04'), findsOneWidget);

    await tester.tap(_headerCheck);
    await tester.pump();
    expect(changes.last, isEmpty);
    expect(_value(tester, _headerCheck), isFalse);
    expect(find.text('PUMPS'), findsOneWidget);
  });

  testWidgets('a press on the row selects it too, unless the row has a press of its own', (WidgetTester tester) async {
    final List<String> pressed = <String>[];
    Widget build({ValueChanged<Pump>? onRowPressed}) => KkDataTable<Pump>(
      rows: pumps,
      rowKey: pumpKey,
      columns: basicColumns(),
      selection: KkTableSelection.multi,
      onRowPressed: onRowPressed,
    );
    await pumpKk(tester, build());
    await tester.tap(find.text('coolant loop a'));
    await tester.pump();
    expect(_value(tester, _rowCheck('P-01')), isTrue);
    await tester.tap(find.text('coolant loop a'));
    await tester.pump();
    expect(_value(tester, _rowCheck('P-01')), isFalse);

    await pumpKk(tester, build(onRowPressed: (Pump p) => pressed.add(p.id)));
    await tester.tap(find.text('feed water'));
    await tester.pump();
    expect(pressed, <String>['P-03']);
    expect(_value(tester, _rowCheck('P-03')), isFalse);
    // The checkbox still selects.
    await tester.tap(_rowCheck('P-03'));
    await tester.pump();
    expect(_value(tester, _rowCheck('P-03')), isTrue);
    expect(pressed, <String>['P-03']);
  });

  testWidgets('Shift selects the range from the last row that was toggled', (WidgetTester tester) async {
    final List<Set<Object>> changes = <Set<Object>>[];
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: manyPumps(8),
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        onSelectionChanged: changes.add,
      ),
    );
    await tester.tap(_rowCheck('R-0002'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(_rowCheck('R-0005'));
    await tester.pump();
    expect(changes.last, <Object>{'R-0002', 'R-0003', 'R-0004', 'R-0005'});
    // Backwards from the same anchor, on the row itself.
    await tester.tap(find.text('row 0'));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(changes.last, <Object>{'R-0000', 'R-0001', 'R-0002', 'R-0003', 'R-0004', 'R-0005'});
    // Without Shift a press toggles one row and moves the anchor.
    await tester.tap(_rowCheck('R-0007'));
    await tester.pump();
    expect(changes.last, hasLength(7));
  });

  testWidgets('the header checkbox works on the rows of the page; the selection lives across pages', (
    WidgetTester tester,
  ) async {
    Set<Object> selection = <Object>{};
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        en: 'rows',
        rows: manyPumps(10),
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        initialPageSize: 4,
        onSelectionChanged: (Set<Object> s) => selection = s,
      ),
    );
    await tester.tap(_headerCheck);
    await tester.pump();
    expect(selection, <Object>{'R-0000', 'R-0001', 'R-0002', 'R-0003'});
    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pump();
    expect(idsInOrder(tester), <String>['R-0004', 'R-0005', 'R-0006', 'R-0007']);
    // Nothing on this page is selected yet; the band still counts four.
    expect(_value(tester, _headerCheck), isFalse);
    expect(find.text('04'), findsOneWidget);
    await tester.tap(_rowCheck('R-0005'));
    await tester.pump();
    expect(_value(tester, _headerCheck), isNull);
    expect(find.text('05'), findsOneWidget);
    await tester.tap(_headerCheck);
    await tester.pump();
    expect(selection, hasLength(8));
    expect(_value(tester, _headerCheck), isTrue);
    // Clearing the page keeps the first page's rows.
    await tester.tap(_headerCheck);
    await tester.pump();
    expect(selection, <Object>{'R-0000', 'R-0001', 'R-0002', 'R-0003'});
  });

  testWidgets('single: one row at a time, by pressing the row; no checkbox column unless asked for', (
    WidgetTester tester,
  ) async {
    Set<Object> selection = <Object>{};
    Widget build({bool? boxes}) => KkDataTable<Pump>(
      rows: pumps,
      rowKey: pumpKey,
      columns: basicColumns(),
      selection: KkTableSelection.single,
      showCheckboxes: boxes,
      onSelectionChanged: (Set<Object> s) => selection = s,
    );
    await pumpKk(tester, build());
    expect(find.byType(KkCheckbox), findsNothing);
    await tester.tap(find.text('coolant loop a'));
    await tester.pump();
    expect(selection, <Object>{'P-01'});
    expect(lookOf(tester, 'P-01').background, KkColors.standby.bg300);
    await tester.tap(find.text('feed water'));
    await tester.pump();
    expect(selection, <Object>{'P-03'});
    expect(lookOf(tester, 'P-01').background, isNull);
    await tester.tap(find.text('feed water'));
    await tester.pump();
    expect(selection, isEmpty);

    await pumpKk(tester, build(boxes: true));
    // Four row checkboxes, none in the header.
    expect(find.byType(KkCheckbox), findsNWidgets(4));
    await tester.tap(_rowCheck('P-02'));
    await tester.pump();
    await tester.tap(_rowCheck('P-04'));
    await tester.pump();
    expect(selection, <Object>{'P-04'});
  });

  testWidgets('a controlled selection changes only when the owner says so', (WidgetTester tester) async {
    final List<Set<Object>> asked = <Set<Object>>[];
    Widget build(Set<Object> selected) => KkDataTable<Pump>(
      rows: pumps,
      rowKey: pumpKey,
      columns: basicColumns(),
      selection: KkTableSelection.multi,
      selected: selected,
      onSelectionChanged: asked.add,
    );
    await pumpKk(tester, build(const <Object>{'P-01'}));
    await tester.tap(_rowCheck('P-02'));
    await tester.pump();
    expect(asked.last, <Object>{'P-01', 'P-02'});
    expect(_value(tester, _rowCheck('P-02')), isFalse);
    await pumpKk(tester, build(const <Object>{'P-01', 'P-02'}));
    expect(_value(tester, _rowCheck('P-02')), isTrue);
    expect(find.text('02'), findsOneWidget);
    // Controlled and empty is empty, not "the table's own".
    await pumpKk(tester, build(const <Object>{}));
    expect(_value(tester, _rowCheck('P-01')), isFalse);
    expect(_value(tester, _rowCheck('P-02')), isFalse);
  });

  testWidgets('keys of rows that are gone are ignored, and the table forgets its own', (WidgetTester tester) async {
    Set<Object> selection = <Object>{};
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: pumps,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        selected: const <Object>{'P-01', 'X-99', 42},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('01'), findsOneWidget);

    Widget own(List<Pump> rows) => KkDataTable<Pump>(
      key: const ValueKey<String>('own'),
      rows: rows,
      rowKey: pumpKey,
      columns: basicColumns(),
      selection: KkTableSelection.multi,
      onSelectionChanged: (Set<Object> s) => selection = s,
    );
    await pumpKk(tester, own(pumps));
    await tester.tap(_headerCheck);
    await tester.pump();
    expect(find.text('04'), findsOneWidget);
    await pumpKk(tester, own(pumps.sublist(2)));
    expect(find.text('02'), findsOneWidget);
    // A press now starts from the two rows that are left.
    await tester.tap(_rowCheck('P-03'));
    await tester.pump();
    expect(selection, <Object>{'P-04'});
  });

  testWidgets('the close button of the band clears the selection', (WidgetTester tester) async {
    Set<Object> selection = <Object>{'x'};
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: pumps,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        onSelectionChanged: (Set<Object> s) => selection = s,
      ),
    );
    await tester.tap(_rowCheck('P-01'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Clear selection'));
    await tester.pump();
    expect(selection, isEmpty);
    expect(_value(tester, _rowCheck('P-01')), isFalse);
  });

  testWidgets('semantics: rows say whether they are selected and the count is announced', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: pumps,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: KkTableSelection.multi,
        rowSemanticLabel: (Pump p) => 'pump ${p.id}',
      ),
    );
    expect(find.bySemanticsLabel('Select all rows on this page'), findsOneWidget);
    expect(find.bySemanticsLabel('Select row'), findsNWidgets(4));
    expect(tester.getSemantics(find.bySemanticsLabel('pump P-01')).flagsCollection.isSelected, Tristate.isFalse);
    await tester.tap(_rowCheck('P-01'));
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('pump P-01')).flagsCollection.isSelected, Tristate.isTrue);
    expect(find.bySemanticsLabel('1 row selected'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('1 row selected')).flagsCollection.isLiveRegion, isTrue);
    await tester.tap(_rowCheck('P-02'));
    await tester.pump();
    expect(find.bySemanticsLabel('2 rows selected'), findsOneWidget);
    semantics.dispose();
  });
}
