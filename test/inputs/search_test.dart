import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkSearchResult<String>> _all = <KkSearchResult<String>>[
  KkSearchResult<String>(value: 'p101', title: 'Coolant pump A', code: 'P-101', meta: 'SEC-04'),
  KkSearchResult<String>(value: 'v201', title: 'Pump relief valve', code: 'V-201', meta: 'SEC-07', enabled: false),
  KkSearchResult<String>(value: 'p102', title: 'Coolant pump B', code: 'P-102', meta: 'SEC-04'),
  KkSearchResult<String>(value: 't301', title: 'Turbine hall', code: 'T-301'),
];

/// Filters [_all] by the query, the way an app would.
class _Host extends StatefulWidget {
  const _Host({this.clearOnSelect = false, this.focusNode, this.controller});

  final bool clearOnSelect;
  final FocusNode? focusNode;
  final TextEditingController? controller;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final List<String> queries = <String>[];
  final List<String> selected = <String>[];
  final List<String> submitted = <String>[];
  String query = '';

  @override
  Widget build(BuildContext context) {
    final String q = query.trim().toLowerCase();
    return KkSearch<String>(
      width: 400,
      focusNode: widget.focusNode,
      controller: widget.controller,
      clearOnSelect: widget.clearOnSelect,
      placeholder: 'TAG OR NAME',
      hint: 'CTRL+K',
      results: <KkSearchResult<String>>[
        for (final KkSearchResult<String> r in _all)
          if (q.isNotEmpty && (r.title.toLowerCase().contains(q) || r.code!.toLowerCase().contains(q))) r,
      ],
      onQuery: (String text) {
        queries.add(text);
        setState(() => query = text);
      },
      onSelected: (KkSearchResult<String> r) => selected.add(r.value),
      onSubmitted: submitted.add,
    );
  }
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump();
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

String _plain(Text t) => t.data ?? t.textSpan!.toPlainText();

/// The results surface: a 2px signal edge on top, 1px lines on the other
/// sides (the focused bar has signal all round).
Finder get _results => find.byWidgetPredicate((Widget w) {
  if (w is! KkBox) return false;
  final KkEdges? edges = w.decoration?.edges;
  return edges != null &&
      edges.top == KkSide(KkColors.standby.signal, width: 2) &&
      edges.left == KkSide(KkColors.standby.line);
});

/// The title of the result drawn as selected (bg-300 ground).
String? _selected(WidgetTester tester) {
  for (final Element e in find.byType(KkBox).evaluate()) {
    final KkBox box = e.widget as KkBox;
    if (box.height == 32 && box.fill == KkColors.standby.bg300) {
      final Iterable<Text> texts = tester.widgetList<Text>(
        find.descendant(of: find.byWidget(box), matching: find.byType(Text)),
      );
      for (final Text t in texts) {
        if (t.textSpan != null) return _plain(t);
      }
    }
  }
  return null;
}

void main() {
  setUpAll(loadKkFonts);

  group('KkSearch', () {
    testWidgets('the bar: 40px, icon, prompt, placeholder, key hint; no clear button while empty', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      expect(tester.getSize(find.byType(KkFieldBox)), const Size(400, 40));
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.search);
      expect(tester.widget<Text>(find.text('>')).style!.color, KkColors.standby.signal);
      expect(find.text('TAG OR NAME'), findsOneWidget);
      expect(find.byType(KkKbd), findsOneWidget);
      expect(find.text('CTRL+K'), findsOneWidget);
      expect(find.byType(KkIconButton), findsNothing);
      expect(_results, findsNothing);
      // The key cap ends 8 + 8 px before the 32px clear slot, which ends 4px
      // (and the 1px border) before the edge.
      final Rect bar = tester.getRect(find.byType(KkFieldBox));
      expect(tester.getRect(find.byType(KkKbd)).right, bar.right - 1 - 4 - 32 - 16);
      // Its input is in the mono face.
      expect(tester.widget<EditableText>(find.byType(EditableText)).style.fontFamily, contains('IBM Plex Mono'));
    });

    testWidgets('width: the parent decides, 320 when it sets no limit; a fixed width wins', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const KkRow(children: <Widget>[KkSearch<String>()]));
      expect(tester.getSize(find.byType(KkSearch<String>)).width, 320);
      await pumpKk(tester, const KkBox(width: 500, child: KkSearch<String>()));
      expect(tester.getSize(find.byType(KkSearch<String>)).width, 500);
      await pumpKk(tester, const KkSearch<String>(width: 360));
      expect(tester.getSize(find.byType(KkSearch<String>)).width, 360);
      // A parent narrower than the 280px minimum is obeyed rather than overflowed.
      await pumpKk(tester, const KkBox(width: 200, child: KkSearch<String>(hint: 'CTRL+K')));
      expect(tester.getSize(find.byType(KkSearch<String>)).width, 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing reports the query and opens the results under the bar', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      expect(_host(tester).queries, <String>['pump']);
      final Rect bar = tester.getRect(find.byType(KkFieldBox));
      final Rect list = tester.getRect(_results);
      expect(list.left, bar.left);
      expect(list.width, bar.width);
      expect(list.top, bar.bottom + 4);
      // 2 top + 4 pad + 3 rows of 32 + 4 pad + 1 bottom.
      expect(list.height, 2 + 4 + 3 * 32 + 4 + 1);
      expect(find.text('Coolant pump A'), findsOneWidget);
      expect(find.text('Pump relief valve'), findsOneWidget);
      expect(find.text('Coolant pump B'), findsOneWidget);
      expect(find.text('Turbine hall'), findsNothing);
      // Codes in signal, meta in dim ink at the right edge.
      expect(tester.widget<Text>(find.text('P-101')).style!.color, KkColors.standby.signal);
      expect(tester.widget<Text>(find.text('SEC-04').first).style!.color, KkColors.standby.inkDim);
      expect(tester.getRect(find.text('SEC-04').first).right, list.right - 1 - 12);
      // The first result that can be chosen is selected.
      expect(_selected(tester), 'Coolant pump A');
      // The clear button has taken the place of the empty slot.
      expect(find.byType(KkIconButton), findsOneWidget);
      // The bar reads as focused.
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).focused, isTrue);
    });

    testWidgets('the part of a title that matches the query is marked', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'PUMP');
      final Text title = tester.widget<Text>(find.text('Coolant pump A'));
      final List<InlineSpan> parts = (title.textSpan! as TextSpan).children!;
      expect(parts.map((InlineSpan s) => s.toPlainText()).toList(), <String>['Coolant ', 'pump', ' A']);
      expect(parts[0].style?.backgroundColor, isNull);
      expect(parts[1].style!.backgroundColor, KkColors.standby.signalDim);
      // A disabled result is faint and carries no signal colour.
      expect(tester.widget<Text>(find.text('Pump relief valve')).textSpan!.style!.color, KkColors.standby.inkFaint);
      expect(tester.widget<Text>(find.text('V-201')).style!.color, KkColors.standby.inkFaint);
    });

    testWidgets('arrows move past disabled results and wrap; Enter selects and closes', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      expect(_selected(tester), 'Coolant pump A');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_selected(tester), 'Coolant pump B');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_selected(tester), 'Coolant pump A');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_selected(tester), 'Coolant pump B');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).selected, <String>['p102']);
      expect(_host(tester).submitted, isEmpty);
      expect(_results, findsNothing);
      // The query stays, and so does the focus.
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'pump');
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
      // The next change of the query opens the results again.
      await _type(tester, 'turb');
      expect(_results, findsOneWidget);
      expect(_selected(tester), 'Turbine hall');
    });

    testWidgets('the keyboard action selects too; with no result to choose it submits the text', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'turb');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      expect(_host(tester).selected, <String>['t301']);
      expect(_host(tester).submitted, isEmpty);
      // Closed now: Enter submits the text as typed.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(_host(tester).submitted, <String>['turb']);
      // No match: the list says so, and Enter submits.
      await _type(tester, 'zzz');
      expect(find.text('NO MATCH'), findsOneWidget);
      expect(tester.getSize(_results).height, 2 + 4 + 32 + 4 + 1);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).submitted, <String>['turb', 'zzz']);
      expect(_host(tester).selected, <String>['t301']);
    });

    testWidgets('a press selects a result; a disabled one does nothing', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      await tester.tap(find.text('Pump relief valve'));
      await tester.pump();
      expect(_host(tester).selected, isEmpty);
      expect(_results, findsOneWidget);
      await tester.tap(find.text('Coolant pump B'));
      await tester.pump();
      await tester.pump();
      expect(_host(tester).selected, <String>['p102']);
      expect(_results, findsNothing);
      // Pressing a result did not take the focus from the input.
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    });

    testWidgets('clearOnSelect empties the query after a selection', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(clearOnSelect: true), padding: const EdgeInsets.all(40));
      await _type(tester, 'turb');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).selected, <String>['t301']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
      expect(_host(tester).queries, <String>['turb', '']);
      expect(_results, findsNothing);
      expect(find.byType(KkIconButton), findsNothing);
    });

    testWidgets('Escape closes the results, arrow down brings them back, Escape again clears', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_results, findsNothing);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'pump');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_results, findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_results, findsNothing);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
      expect(_host(tester).queries, <String>['pump', '']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    });

    testWidgets('the clear button empties the query, reports it and keeps the focus', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      final Rect bar = tester.getRect(find.byType(KkFieldBox));
      final Rect clear = tester.getRect(find.byType(KkIconButton));
      expect(clear.size, const Size(32, 32));
      expect(clear.right, bar.right - 1 - 4);
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
      expect(_host(tester).queries, <String>['pump', '']);
      expect(_results, findsNothing);
      expect(find.byType(KkIconButton), findsNothing);
      expect(find.text('TAG OR NAME'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
      // The slot keeps its size, so the key cap does not move.
      expect(tester.getRect(find.byType(KkKbd)).right, bar.right - 1 - 4 - 32 - 16);
    });

    testWidgets('leaving the field closes the results; coming back with text shows them again', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(tester, _Host(focusNode: focus), padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      expect(_results, findsOneWidget);
      focus.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_results, findsNothing);
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).focused, isFalse);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(_results, findsOneWidget);
    });

    testWidgets('a controller drives the query from outside', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(controller: controller, focusNode: focus),
        padding: const EdgeInsets.all(40),
      );
      controller.text = 'turb';
      await tester.pump();
      expect(_host(tester).queries, <String>['turb']);
      // Not focused: the results stay shut until the field is entered.
      expect(_results, findsNothing);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(_results, findsOneWidget);
      expect(find.text('Turbine hall'), findsOneWidget);
    });

    testWidgets('open forces the list open or shut; initialQuery fills the field', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkSearch<String>(width: 400, initialQuery: 'pump', results: _all, open: true, emptyText: 'NOTHING'),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(_results, findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'pump');
      expect(find.text('Turbine hall'), findsOneWidget);
      await pumpKk(
        tester,
        const KkSearch<String>(width: 400, initialQuery: 'pump', results: _all, open: false),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(_results, findsNothing);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.pump();
      expect(_results, findsNothing);
      // Forced open with nothing to show: the empty line, in the caller's words.
      await pumpKk(
        tester,
        const KkSearch<String>(width: 400, open: true, emptyText: 'NOTHING'),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(find.text('NOTHING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: dashed, no typing, no clear button, no results', (WidgetTester tester) async {
      final List<String> queries = <String>[];
      await pumpKk(
        tester,
        KkSearch<String>(
          width: 400,
          initialQuery: 'pump',
          results: _all,
          enabled: false,
          open: true,
          onQuery: queries.add,
        ),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).enabled, isFalse);
      expect(find.byType(KkIconButton), findsNothing);
      expect(_results, findsNothing);
      expect(tester.widget<Text>(find.text('>')).style!.color, KkColors.standby.inkFaint);
      await tester.tap(find.byType(KkFieldBox), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      final EditableText e = tester.widget<EditableText>(find.byType(EditableText));
      expect(e.focusNode.hasFocus, isFalse);
      expect(e.readOnly, isTrue);
      expect(queries, isEmpty);
    });

    testWidgets('the mouse moves the selection; a long list scrolls and keeps it in view', (WidgetTester tester) async {
      final List<KkSearchResult<int>> many = <KkSearchResult<int>>[
        for (int i = 0; i < 30; i++) KkSearchResult<int>(value: i, title: 'Unit ${i.toString().padLeft(2, '0')}'),
      ];
      final List<int> chosen = <int>[];
      await pumpKk(
        tester,
        KkSearch<int>(
          width: 400,
          results: many,
          maxResultsHeight: 200,
          onSelected: (KkSearchResult<int> r) => chosen.add(r.value),
        ),
        padding: const EdgeInsets.all(40),
      );
      await _type(tester, 'unit');
      final Rect list = tester.getRect(_results);
      expect(list.height, 200);
      // No result has a code, so no column is kept for codes.
      expect(tester.getRect(find.text('Unit 00')).left, list.left + 1 + 12);

      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Unit 03')));
      await tester.pump();
      expect(_selected(tester), 'Unit 03');

      // Arrow up from there wraps around after four steps; the list follows,
      // and the row that scrolls under the resting pointer does not take the
      // selection.
      for (int i = 0; i < 4; i++) {
        await _key(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(_selected(tester), 'Unit 29');
      final Rect last = tester.getRect(find.text('Unit 29'));
      expect(last.top, greaterThanOrEqualTo(list.top));
      expect(last.bottom, lessThanOrEqualTo(list.bottom));
      await _key(tester, LogicalKeyboardKey.enter);
      expect(chosen, <int>[29]);
    });

    testWidgets('near the bottom of the screen the results open upward', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), alignment: Alignment.bottomLeft, padding: const EdgeInsets.all(40));
      await _type(tester, 'pump');
      final Rect bar = tester.getRect(find.byType(KkFieldBox));
      final Rect list = tester.getRect(_results);
      expect(list.bottom, bar.top - 4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the results wipe open in 5 steps over 250ms when motion is on', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40), motion: true);
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(EditableText), 'pump');
      await tester.pump();
      await tester.pump();
      final Finder clip = find.ancestor(of: _results, matching: find.byType(ClipRect)).first;
      Rect shown() {
        final RenderClipRect render = tester.renderObject<RenderClipRect>(clip);
        return render.clipper!.getClip(render.size);
      }

      expect(shown().width, lessThan(400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.none);
      // The results stay up while the query changes: no second wipe.
      await tester.enterText(find.byType(EditableText), 'pu');
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.none);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: a labelled text field and result buttons', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(40));
      final SemanticsNode field = tester.getSemantics(find.byType(EditableText));
      expect(field.flagsCollection.isTextField, isTrue);
      // Its name, then the placeholder and the key hint; not the prompt mark.
      expect(field.label, 'Search\nTAG OR NAME\nCTRL+K');
      await _type(tester, 'pump');
      expect(tester.getSemantics(find.byType(KkIconButton)).label, 'Clear');
      final SemanticsNode row = tester.getSemantics(find.text('Coolant pump A'));
      expect(row.flagsCollection.isButton, isTrue);
      expect(row.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });
  });
}
