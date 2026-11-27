import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  group('KkPressable keys', () {
    testChecked('Space and Enter typed in a text field inside it stay with the field', (WidgetTester tester) async {
      int presses = 0;
      final TextEditingController text = TextEditingController();
      final FocusNode field = FocusNode();
      final FocusNode row = FocusNode();
      addTearDown(text.dispose);
      addTearDown(field.dispose);
      addTearDown(row.dispose);
      await pumpKk(
        tester,
        KkPressable(
          focusNode: row,
          onPressed: () => presses++,
          builder: (BuildContext context, KkStates states) => KkBox(
            width: 400,
            height: 60,
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: KkTextField(controller: text, focusNode: field),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(field.hasFocus, isTrue);
      expect(presses, 0);

      // A key the framework reports as handled is not passed on to the text
      // input by the desktop and web embedders: nothing would be typed.
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        expect(await tester.sendKeyEvent(key), isFalse, reason: '${key.debugName} belongs to the text field');
        expect(presses, 0, reason: '${key.debugName} typed in the field must not press the control around it');
      }

      // The same keys press the control once it is the focused element itself.
      row.requestFocus();
      await tester.pump();
      expect(row.hasPrimaryFocus, isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter), isTrue);
      expect(presses, 3);
    });

    testChecked('a tappable list row leaves Space and Enter to the field in its trailing slot', (
      WidgetTester tester,
    ) async {
      int presses = 0;
      final TextEditingController text = TextEditingController();
      final FocusNode field = FocusNode();
      addTearDown(text.dispose);
      addTearDown(field.dispose);
      await pumpKk(
        tester,
        KkListRow(
          en: 'callsign',
          onPressed: () => presses++,
          trailing: SizedBox(
            width: 200,
            child: KkTextField(controller: text, focusNode: field),
          ),
        ),
        size: const Size(600, 400),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(field.hasFocus, isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isFalse);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
      expect(presses, 0);

      // The row itself still answers to the keyboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(field.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
    });

    testChecked('keys pressed on a focusable child that does not use them do not press the control', (
      WidgetTester tester,
    ) async {
      int presses = 0;
      final FocusNode child = FocusNode();
      addTearDown(child.dispose);
      await pumpKk(
        tester,
        KkPressable(
          onPressed: () => presses++,
          builder: (BuildContext context, KkStates states) => KkBox(
            width: 200,
            height: 60,
            alignment: Alignment.center,
            child: Focus(focusNode: child, child: const SizedBox(width: 20, height: 20)),
          ),
        ),
      );
      child.requestFocus();
      await tester.pump();
      expect(child.hasPrimaryFocus, isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isFalse);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
      expect(presses, 0);
    });

    testChecked('a control inside a control takes the keys itself', (WidgetTester tester) async {
      int outer = 0;
      int inner = 0;
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkPressable(
          onPressed: () => outer++,
          builder: (BuildContext context, KkStates states) => KkBox(
            width: 200,
            height: 60,
            alignment: Alignment.center,
            child: KkPressable(
              focusNode: node,
              onPressed: () => inner++,
              builder: (BuildContext context, KkStates states) => const SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
      expect(inner, 2);
      expect(outer, 0);
    });
  });

  group('KkPressable focus', () {
    /// The focus rings that are showing.
    int rings(WidgetTester tester) =>
        tester.widgetList<KkFocusRing>(find.byType(KkFocusRing)).where((KkFocusRing ring) => ring.visible).length;

    testChecked('the focus state belongs to the focused control, not to the control around it', (
      WidgetTester tester,
    ) async {
      KkStates? outer;
      KkStates? inner;
      final FocusNode outerNode = FocusNode(debugLabel: 'outer');
      final FocusNode innerNode = FocusNode(debugLabel: 'inner');
      addTearDown(outerNode.dispose);
      addTearDown(innerNode.dispose);
      await pumpKk(
        tester,
        KkPressable(
          focusNode: outerNode,
          onPressed: () {},
          builder: (BuildContext context, KkStates states) {
            outer = states;
            return KkFocusRing(
              visible: states.focused,
              offset: -2,
              child: KkBox(
                width: 300,
                height: 48,
                alignment: Alignment.centerRight,
                child: KkPressable(
                  focusNode: innerNode,
                  onPressed: () {},
                  builder: (BuildContext context, KkStates states) {
                    inner = states;
                    return KkFocusRing(visible: states.focused, child: const SizedBox(width: 40, height: 20));
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outerNode.hasPrimaryFocus, isTrue);
      expect(outer!.focused, isTrue);
      expect(inner!.focused, isFalse);

      // On to the control inside: the outer one still has the focus within
      // it, but it is not the focused element any more.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(innerNode.hasPrimaryFocus, isTrue);
      expect(outerNode.hasFocus, isTrue);
      expect(inner!.focused, isTrue);
      expect(outer!.focused, isFalse, reason: 'one focused element, one ring');
      expect(rings(tester), 1);

      // And back.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(outerNode.hasPrimaryFocus, isTrue);
      expect(outer!.focused, isTrue);
      expect(inner!.focused, isFalse);
      expect(rings(tester), 1);
    });

    testChecked('a list row with a switch in its trailing slot shows one ring at a time', (WidgetTester tester) async {
      bool on = false;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => KkListRow(
            en: 'auxiliary power',
            onPressed: () {},
            trailing: KkSwitch(value: on, onChanged: (bool value) => setState(() => on = value), semanticLabel: 'aux'),
          ),
        ),
        size: const Size(600, 400),
      );
      bool ringOf(Type control) => tester
          .widget<KkFocusRing>(find.descendant(of: find.byType(control), matching: find.byType(KkFocusRing)).first)
          .visible;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ringOf(KkListRow), isTrue);
      expect(rings(tester), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ringOf(KkSwitch), isTrue);
      expect(ringOf(KkListRow), isFalse);
      expect(rings(tester), 1);

      // Space belongs to the switch now.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(on, isTrue);
      expect(rings(tester), 1);
    });

    testChecked('a control that is given another focus node follows the new one', (WidgetTester tester) async {
      KkStates? outer;
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      final FocusNode child = FocusNode(debugLabel: 'child');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(child.dispose);
      Widget control(FocusNode? node) => KkPressable(
        focusNode: node,
        onPressed: () {},
        builder: (BuildContext context, KkStates states) {
          outer = states;
          return KkBox(
            width: 200,
            height: 48,
            alignment: Alignment.center,
            child: Focus(focusNode: child, child: const SizedBox(width: 20, height: 20)),
          );
        },
      );
      await pumpKk(tester, control(a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(outer!.focused, isTrue);

      // The new node is watched, the old one no longer.
      await pumpKk(tester, control(b));
      b.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(outer!.focused, isTrue);
      child.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(b.hasFocus, isTrue);
      expect(outer!.focused, isFalse);

      // And a node of its own when it is given none.
      await pumpKk(tester, control(null));
      await tester.pump();
      expect(outer!.focused, isFalse);
      Focus.of(tester.element(find.byType(KkBox).last)).requestFocus();
      await tester.pump();
      await tester.pump();
      expect(outer!.focused, isTrue);
      child.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(outer!.focused, isFalse);
    });
  });
}
