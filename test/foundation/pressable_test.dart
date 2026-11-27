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
}
