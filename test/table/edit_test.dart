import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/table/edit.dart';

import '../support/harness.dart';
import 'util.dart';

class _Edits {
  final List<(String, String)> committed = <(String, String)>[];
}

Widget _table(
  _Edits edits, {
  String? Function(Pump p, String text)? validator,
  bool commitOnBlur = false,
  bool Function(Pump p)? canEdit,
  KkTableCellRef? open,
  bool dense = false,
  KkTableWidth nameWidth = const KkTableWidth.fixed(240),
}) => KkBox(
  width: 640,
  child: KkDataTable<Pump>(
    rows: pumps,
    rowKey: pumpKey,
    dense: dense,
    initiallyEditing: open,
    selection: KkTableSelection.multi,
    columns: <KkTableColumn<Pump>>[
      idColumn(),
      KkTableColumn<Pump>(
        id: 'name',
        en: 'name',
        width: nameWidth,
        value: (Pump p) => p.name,
        editable: true,
        canEdit: canEdit,
        validator: validator,
        commitOnBlur: commitOnBlur,
        onEdited: (Pump p, String text) => edits.committed.add((p.id, text)),
      ),
      KkTableColumn<Pump>(
        id: 'flow',
        en: 'flow',
        numeric: true,
        width: const KkTableWidth.fixed(120),
        value: (Pump p) => p.flow,
        format: (Pump p) => kkFixed(p.flow ?? 0, digits: 3),
        editText: (Pump p) => (p.flow ?? 0).toStringAsFixed(1),
        editable: true,
        editFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
        editMaxLength: 6,
        onEdited: (Pump p, String text) => edits.committed.add((p.id, text)),
      ),
    ],
  ),
);

Finder _cell(String text) => find.ancestor(of: find.text(text), matching: find.byType(KkTableEditCell)).first;

KkTableEditCellState _state(WidgetTester tester, String text) => tester.state<KkTableEditCellState>(_cell(text));

Finder get _editor => find.byType(EditableText);

/// The value of a cell (not the editor that may show the same text).
Finder _text(String data) => find.byWidgetPredicate((Widget w) => w is Text && w.data == data);

void main() {
  setUpAll(loadKkFonts);

  testWidgets('at rest: a dashed underline 2px under the value, signal under the pointer', (WidgetTester tester) async {
    traditionalHighlights();
    const KkColors c = KkColors.standby;
    await pumpKk(tester, _table(_Edits()));
    final Finder box = find.ancestor(of: find.text('feed water'), matching: find.byType(KkBox)).first;
    RenderKkBox render() => tester.renderObject<RenderKkBox>(box);
    expect(render().decoration!.edges.bottom, KkSide(c.inkFaint, width: 1, dashed: true));
    final Rect text = tester.getRect(find.text('feed water'));
    final Rect line = tester.getRect(box);
    expect(line.top, text.top - 2);
    expect(line.bottom, text.bottom + 2 + 1);
    expect(line.width, text.width);
    final TestGesture pointer = await mouse(tester);
    await pointer.moveTo(text.center);
    await tester.pump();
    expect(render().decoration!.edges.bottom.color, c.signal);
    expect(_editor, findsNothing);
  });

  testWidgets('a press puts the input over the cell: 2px in at the sides, 3px top and bottom, the text selected', (
    WidgetTester tester,
  ) async {
    const KkColors c = KkColors.standby;
    await pumpKk(tester, _table(_Edits()));
    final KkTableGeometry before = rowOf(tester, 'P-03').link.geometry;
    final Rect valueBefore = tester.getRect(find.text('feed water'));
    await tester.tap(find.text('feed water'));
    await tester.pump();
    expect(_editor, findsOneWidget);
    // The name column is the third (after the checkbox and the id): 36 + 80 from the left.
    final Rect row = rowRectOf(tester, 'P-03');
    final Finder input = find.ancestor(of: _editor, matching: find.byType(KkBox)).first;
    expect(
      tester.getRect(input),
      Rect.fromLTRB(row.left + 116 + 2, row.top + 3, row.left + 116 + 240 - 2, row.bottom - 3),
    );
    final RenderKkBox box = tester.renderObject<RenderKkBox>(input);
    expect(box.decoration!.fill, c.bg000);
    expect(box.decoration!.edges.top, KkSide(c.signal, width: 1));
    expect(box.padding, const EdgeInsets.symmetric(horizontal: 6));
    final RenderKkFocusRing ring = tester.renderObject<RenderKkFocusRing>(
      find.ancestor(of: _editor, matching: find.byType(KkFocusRing)).first,
    );
    expect(ring.visible, isTrue);
    expect(ring.offset, 1);
    expect(ring.width, 2);
    final EditableText editable = tester.widget<EditableText>(_editor);
    expect(editable.controller.text, 'feed water');
    expect(editable.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 10));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.style.fontSize, 12);
    expect(editable.style.fontFamily, contains('IBM Plex Mono'));
    expect(editable.textAlign, TextAlign.start);
    // The value stays laid out underneath, unseen: nothing moved.
    expect(tester.getRect(_text('feed water')), valueBefore);
    expect(
      tester.widget<Opacity>(find.ancestor(of: _text('feed water'), matching: find.byType(Opacity)).first).opacity,
      0,
    );
    expect(rowOf(tester, 'P-03').link.geometry, before);
  });

  testWidgets('Enter commits the text and hands the keyboard back to the rows', (WidgetTester tester) async {
    final _Edits edits = _Edits();
    await pumpKk(tester, _table(edits));
    await tester.tap(find.text('feed water'));
    await tester.pump();
    await tester.enterText(_editor, 'feed water b');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(edits.committed, <(String, String)>[('P-03', 'feed water b')]);
    expect(_editor, findsNothing);
    await tester.pump();
    // The rows have the focus again: Down moves on from the edited row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(lookOf(tester, 'P-04').focus, KkColors.standby.focus);
  });

  testWidgets('Escape cancels', (WidgetTester tester) async {
    final _Edits edits = _Edits();
    await pumpKk(tester, _table(edits));
    await tester.tap(find.text('spare'));
    await tester.pump();
    await tester.enterText(_editor, 'typed');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_editor, findsNothing);
    expect(edits.committed, isEmpty);
    expect(find.text('spare'), findsOneWidget);
    // Opening again starts from the value, not from what was typed.
    await tester.tap(find.text('spare'));
    await tester.pump();
    expect(tester.widget<EditableText>(_editor).controller.text, 'spare');
  });

  testWidgets('losing the focus drops the text, or commits it when the column says so', (WidgetTester tester) async {
    final _Edits edits = _Edits();
    await pumpKk(tester, _table(edits));
    await tester.tap(find.text('spare'));
    await tester.pump();
    await tester.enterText(_editor, 'typed');
    // Another cell takes the focus.
    await tester.tap(find.text('feed water'));
    await tester.pump();
    await tester.pump();
    expect(edits.committed, isEmpty);
    expect(tester.widget<EditableText>(_editor).controller.text, 'feed water');
    expect(_state(tester, 'spare').isEditing, isFalse);

    await pumpKk(tester, const SizedBox());
    await pumpKk(tester, _table(edits, commitOnBlur: true));
    await tester.tap(find.text('spare'));
    await tester.pump();
    await tester.enterText(_editor, 'typed');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await tester.pump();
    expect(edits.committed, <(String, String)>[('P-04', 'typed')]);
    expect(_editor, findsNothing);
  });

  testWidgets('a refused text keeps the editor open in alert with the message under it', (WidgetTester tester) async {
    final _Edits edits = _Edits();
    const KkColors c = KkColors.standby;
    await pumpKk(
      tester,
      _table(edits, validator: (Pump p, String text) => text.trim().isEmpty ? 'NAME REQUIRED' : null),
    );
    await tester.tap(find.text('spare'));
    await tester.pump();
    await tester.enterText(_editor, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(edits.committed, isEmpty);
    expect(_editor, findsOneWidget);
    expect(tester.widget<EditableText>(_editor).focusNode.hasFocus, isTrue);
    expect(_state(tester, 'spare').error, 'NAME REQUIRED');
    final Finder input = find.ancestor(of: _editor, matching: find.byType(KkBox)).first;
    expect(tester.renderObject<RenderKkBox>(input).decoration!.edges.top.color, c.alert);
    // The message hangs under the input, on the alarm fill.
    expect(find.text('NAME REQUIRED'), findsOneWidget);
    expect(styleOf(tester, 'NAME REQUIRED').color, c.onFill);
    expect(tester.getRect(find.text('NAME REQUIRED')).top, greaterThan(tester.getRect(input).bottom));
    // Typing clears the error; a good text then commits.
    await tester.enterText(_editor, 'spare b');
    await tester.pump();
    await tester.pump();
    expect(_state(tester, 'spare').error, isNull);
    expect(find.text('NAME REQUIRED'), findsNothing);
    expect(tester.renderObject<RenderKkBox>(input).decoration!.edges.top.color, c.signal);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(edits.committed, <(String, String)>[('P-04', 'spare b')]);
    expect(_editor, findsNothing);
  });

  testWidgets('with commit-on-blur a refused text is dropped when the focus leaves', (WidgetTester tester) async {
    final _Edits edits = _Edits();
    await pumpKk(tester, _table(edits, commitOnBlur: true, validator: (Pump p, String text) => 'NO'));
    await tester.tap(find.text('spare'));
    await tester.pump();
    await tester.enterText(_editor, 'x');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await tester.pump();
    expect(edits.committed, isEmpty);
    expect(_editor, findsNothing);
  });

  testWidgets('a numeric column edits right-aligned, starts from editText and applies its formatters', (
    WidgetTester tester,
  ) async {
    final _Edits edits = _Edits();
    await pumpKk(tester, _table(edits));
    await tester.tap(find.text('118'));
    await tester.pump();
    final EditableText editable = tester.widget<EditableText>(_editor);
    expect(editable.controller.text, '118.0');
    expect(editable.textAlign, TextAlign.end);
    await tester.enterText(_editor, '12a3.4567');
    await tester.pump();
    // Letters are filtered and the length is capped at six.
    expect(editable.controller.text, '123.45');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(edits.committed, <(String, String)>[('P-03', '123.45')]);
  });

  testWidgets('rows that cannot be edited are plain cells; a column without onEdited is not editable', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _table(_Edits(), canEdit: (Pump p) => p.id != 'P-02'));
    // Four flow cells and three name cells.
    expect(find.byType(KkTableEditCell), findsNWidgets(7));
    await tester.tap(find.text('coolant loop b'));
    await tester.pump();
    expect(_editor, findsNothing);
    await pumpKk(
      tester,
      KkDataTable<Pump>(
        rows: pumps,
        rowKey: pumpKey,
        columns: <KkTableColumn<Pump>>[
          KkTableColumn<Pump>(id: 'name', en: 'name', value: (Pump p) => p.name, editable: true),
        ],
      ),
    );
    expect(find.byType(KkTableEditCell), findsNothing);
  });

  testWidgets('keyboard: the value is a tab stop, Enter opens the editor, and typing is not taken for row keys', (
    WidgetTester tester,
  ) async {
    final _Edits edits = _Edits();
    Set<Object> selection = <Object>{};
    await pumpKk(
      tester,
      KkBox(
        width: 400,
        child: KkDataTable<Pump>(
          rows: pumps,
          rowKey: pumpKey,
          selection: KkTableSelection.multi,
          showCheckboxes: false,
          onSelectionChanged: (Set<Object> s) => selection = s,
          columns: <KkTableColumn<Pump>>[
            KkTableColumn<Pump>(
              id: 'name',
              en: 'name',
              value: (Pump p) => p.name,
              editable: true,
              onEdited: (Pump p, String text) => edits.committed.add((p.id, text)),
            ),
          ],
        ),
      ),
    );
    // Tab: the rows, then the first value.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(_editor, findsOneWidget);
    expect(tester.widget<EditableText>(_editor).controller.text, 'coolant loop a');
    // Space and the arrows belong to the editor now.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(selection, isEmpty);
    expect(_editor, findsOneWidget);
    await tester.enterText(_editor, 'loop a');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(edits.committed, <(String, String)>[('P-01', 'loop a')]);
  });

  testWidgets('a cell can start open without taking the focus; dense rows give a 18px input', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _table(_Edits(), open: const KkTableCellRef('P-02', 'name'), dense: true));
    expect(_editor, findsOneWidget);
    final EditableText editable = tester.widget<EditableText>(_editor);
    expect(editable.controller.text, 'coolant loop b');
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.style.fontSize, 11);
    final Finder input = find.ancestor(of: _editor, matching: find.byType(KkBox)).first;
    expect(tester.getSize(input).height, 24 - 6);
    // It stays open until it is used: a press elsewhere does not close what never had the focus.
    await tester.tap(find.text('spare'));
    await tester.pump();
    expect(find.byType(EditableText), findsNWidgets(2));
  });

  testWidgets('a content column is as wide as the value, not as the editor', (WidgetTester tester) async {
    await pumpKk(tester, _table(_Edits(), nameWidth: const KkTableWidth.content()));
    final double width = rowOf(tester, 'P-01').link.geometry.widths[2];
    await tester.tap(find.text('spare'));
    await tester.pump();
    expect(rowOf(tester, 'P-01').link.geometry.widths[2], width);
    expect(tester.getSize(find.ancestor(of: _editor, matching: find.byType(KkBox)).first).width, width - 4);
  });
}
