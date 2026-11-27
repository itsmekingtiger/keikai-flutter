import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

/// [testChecked] as the app runs on a desktop, where the framework shows
/// focus and hover highlights from the start.
void _testOnDesktop(String description, WidgetTesterCallback body) {
  testChecked(description, (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      // The binding insists that the override is gone when a test ends.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// One click of the left mouse button at [at].
Future<void> _click(WidgetTester tester, Offset at) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: at);
  await mouse.down(at);
  await mouse.up();
  await mouse.removePointer();
}

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

  group('KkPressable focus ring and the pointer', () {
    KkStates? states;

    setUp(() => states = null);

    /// A control that takes the focus when it is pressed, the way a select does.
    Widget control(FocusNode node) => KkPressable(
      focusNode: node,
      onPressed: node.requestFocus,
      builder: (BuildContext context, KkStates s) {
        states = s;
        return KkFocusRing(visible: s.focused, child: const SizedBox(width: 100, height: 40));
      },
    );

    _testOnDesktop('focus taken with a mouse click shows no ring', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);

      await _click(tester, const Offset(50, 20));
      await tester.pump();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse, reason: 'no key was pressed: :focus-visible would not match');

      // The next key press shows where the focus is.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(states!.focused, isTrue);

      // And the next press of a pointer, anywhere, hides it again. The focus stays.
      await _click(tester, const Offset(400, 400));
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse);
    });

    _testOnDesktop('a ring left by the Tab key goes when a pointer is pressed', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isTrue);

      // Moving the mouse or turning its wheel is not a press.
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(50, 20));
      await mouse.moveTo(const Offset(60, 20));
      await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(60, 20), scrollDelta: Offset(0, 20)));
      await tester.pump();
      expect(states!.focused, isTrue);

      await mouse.down(const Offset(400, 400));
      await tester.pump();
      expect(states!.focused, isFalse);
      await mouse.up();
      await tester.pump();
      expect(states!.focused, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(states!.focused, isTrue);

      // A finger is a pointer too.
      await tester.tapAt(const Offset(400, 400));
      await tester.pump();
      expect(states!.focused, isFalse);
    });

    _testOnDesktop('focus given by the program shows as the last input says', (WidgetTester tester) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final List<bool?> rings = <bool?>[null, null];
      Widget plain(FocusNode node, int at) => KkPressable(
        focusNode: node,
        onPressed: () {},
        builder: (BuildContext context, KkStates s) {
          rings[at] = s.focused;
          return const SizedBox(width: 100, height: 40);
        },
      );
      await pumpKk(tester, KkRow(shrinkWrap: true, children: <Widget>[plain(a, 0), plain(b, 1)]));

      // Nothing was pressed yet: a control that is given the focus shows it,
      // as an autofocused one does when the app starts.
      a.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(rings, <bool>[true, false]);

      // After a press of the mouse the program moves the focus: no ring.
      await _click(tester, const Offset(400, 400));
      b.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(b.hasPrimaryFocus, isTrue);
      expect(rings, <bool>[false, false]);

      // After a key it does show.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      a.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(rings, <bool>[true, false]);
    });

    testChecked('highlights forced on for the whole app still tell the mouse from the keyboard', (
      WidgetTester tester,
    ) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      await _click(tester, const Offset(50, 20));
      await tester.pump();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(states!.focused, isTrue);
    });

    testChecked('highlights forced off for the whole app never show the ring', (WidgetTester tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse);
    });

    testChecked('what the pointer did in one test does not reach the next', (WidgetTester tester) async {
      // The test before this one ended on a press of the mouse or of a finger.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      node.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(states!.focused, isTrue);
      await tester.tapAt(const Offset(400, 400));
      await tester.pump();
      expect(states!.focused, isFalse);
    });

    testChecked('and again: a press in the test before does not hide the ring here', (WidgetTester tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      node.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(states!.focused, isTrue);
    });

    _testOnDesktop('a select worked with the mouse shows no ring; worked with the keys it does', (
      WidgetTester tester,
    ) async {
      String value = 'alpha';
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => KkSelect<String>(
            size: KkSelectSize.sm,
            value: value,
            onChanged: (String next) => setState(() => value = next),
            options: const <KkSelectOption<String>>[
              KkSelectOption<String>(value: 'alpha', label: 'alpha'),
              KkSelectOption<String>(value: 'bravo', label: 'bravo'),
            ],
          ),
        ),
        padding: const EdgeInsets.all(40),
      );
      final Finder select = find.byType(KkSelect<String>);
      bool ring() =>
          tester.widget<KkFocusRing>(find.descendant(of: select, matching: find.byType(KkFocusRing)).first).visible;

      await _click(tester, tester.getCenter(select));
      await tester.pumpAndSettle();
      expect(ring(), isFalse);
      await _click(tester, tester.getCenter(find.text('BRAVO').last));
      await tester.pumpAndSettle();
      expect(value, 'bravo');
      expect(
        Focus.of(tester.element(find.descendant(of: select, matching: find.byType(KkFocusRing)))).hasFocus,
        isTrue,
      );
      expect(ring(), isFalse, reason: 'the keyboard was never touched');

      // Opened and closed again with the keys, the select shows its focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(ring(), isTrue);
    });
  });

  group('KkPressable canRequestFocus', () {
    Widget box(
      FocusNode node, {
      bool canRequestFocus = true,
      bool autofocus = false,
      VoidCallback? onPressed,
      ValueChanged<KkStates>? onStates,
      Widget child = const SizedBox(width: 40, height: 40),
    }) => KkPressable(
      focusNode: node,
      canRequestFocus: canRequestFocus,
      autofocus: autofocus,
      onPressed: onPressed ?? () {},
      semanticLabel: node.debugLabel,
      builder: (BuildContext context, KkStates states) {
        onStates?.call(states);
        return child;
      },
    );

    testChecked('false keeps the control out of the keyboard focus, and it still answers to the pointer', (
      WidgetTester tester,
    ) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final SemanticsHandle handle = tester.ensureSemantics();
      final FocusNode first = FocusNode(debugLabel: 'first');
      final FocusNode skipped = FocusNode(debugLabel: 'skipped');
      final FocusNode last = FocusNode(debugLabel: 'last');
      addTearDown(first.dispose);
      addTearDown(skipped.dispose);
      addTearDown(last.dispose);
      int presses = 0;
      KkStates? states;
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            box(first),
            box(
              skipped,
              canRequestFocus: false,
              autofocus: true,
              onPressed: () => presses++,
              onStates: (KkStates s) => states = s,
            ),
            box(last),
          ],
        ),
      );
      await tester.pump();
      expect(skipped.hasFocus, isFalse, reason: 'autofocus is a request for the focus as well');
      expect(skipped.canRequestFocus, isFalse);

      // Not a Tab stop, in either direction.
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(skipped.hasFocus, isFalse);
      expect(last.hasPrimaryFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue);

      // Not to be focused by the program either, and so it never shows a ring.
      skipped.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(skipped.hasFocus, isFalse);
      expect(first.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse);

      // Assistive technology is told the same: one control is not focusable.
      SemanticsData data(String label) => tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
      expect(data('first').flagsCollection.isFocused, Tristate.isTrue);
      expect(data('last').flagsCollection.isFocused, Tristate.isFalse);
      expect(data('skipped').flagsCollection.isFocused, Tristate.none);
      expect(data('skipped').hasAction(SemanticsAction.focus), isFalse);
      expect(data('skipped').hasAction(SemanticsAction.tap), isTrue);

      // The pointer works as on any control: press, hover, cursor.
      await tester.tapAt(const Offset(60, 20));
      expect(presses, 1);
      expect(states!.enabled, isTrue);
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(60, 20));
      await tester.pump();
      expect(states!.hovered, isTrue);
      // A mouse of the test framework is device 1.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
      handle.dispose();
    });

    testChecked('a control inside one that cannot take the focus still can', (WidgetTester tester) async {
      final FocusNode outer = FocusNode(debugLabel: 'outer');
      final FocusNode inner = FocusNode(debugLabel: 'inner');
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      int outerPresses = 0;
      int innerPresses = 0;
      KkStates? outerStates;
      KkStates? innerStates;
      await pumpKk(
        tester,
        box(
          outer,
          canRequestFocus: false,
          onPressed: () => outerPresses++,
          onStates: (KkStates s) => outerStates = s,
          child: KkBox(
            width: 300,
            height: 48,
            alignment: Alignment.centerRight,
            child: box(inner, onPressed: () => innerPresses++, onStates: (KkStates s) => innerStates = s),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner.hasPrimaryFocus, isTrue);
      expect(outer.hasPrimaryFocus, isFalse);
      expect(innerStates!.focused, isTrue);
      expect(outerStates!.focused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(innerPresses, 1);
      expect(outerPresses, 0);

      // The row around it is pressed with the pointer.
      await tester.tapAt(const Offset(20, 24));
      expect(outerPresses, 1);
      expect(innerPresses, 1);
    });

    testChecked('a focused control that is told it cannot have the focus gives it up', (WidgetTester tester) async {
      final FocusNode node = FocusNode(debugLabel: 'node');
      final FocusNode other = FocusNode(debugLabel: 'other');
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      KkStates? states;
      Widget row({required bool canRequestFocus}) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          box(other),
          box(node, canRequestFocus: canRequestFocus, onStates: (KkStates s) => states = s),
        ],
      );
      await pumpKk(tester, row(canRequestFocus: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isTrue);

      await pumpKk(tester, row(canRequestFocus: false));
      await tester.pump();
      expect(node.hasFocus, isFalse);
      expect(states!.focused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isFalse);
      expect(other.hasPrimaryFocus, isTrue);

      // And takes it again when it may.
      await pumpKk(tester, row(canRequestFocus: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isTrue);
    });

    testChecked('a node that is told to stay out of the Tab order stays out of it', (WidgetTester tester) async {
      // Radio groups and segmented controls keep one Tab stop this way.
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b', skipTraversal: true);
      final FocusNode c = FocusNode(debugLabel: 'c');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(c.dispose);
      await pumpKk(tester, KkRow(shrinkWrap: true, children: <Widget>[box(a), box(b), box(c)]));
      a.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(c.hasPrimaryFocus, isTrue);
      expect(b.skipTraversal, isTrue);
      // It can still be given the focus.
      b.requestFocus();
      await tester.pump();
      expect(b.hasPrimaryFocus, isTrue);
    });

    testChecked('with a directional pad a disabled control can be reached, one that must not be focused cannot', (
      WidgetTester tester,
    ) async {
      final FocusNode live = FocusNode(debugLabel: 'live');
      final FocusNode disabled = FocusNode(debugLabel: 'disabled');
      final FocusNode barred = FocusNode(debugLabel: 'barred');
      addTearDown(live.dispose);
      addTearDown(disabled.dispose);
      addTearDown(barred.dispose);
      KkStates? states;
      Widget controls() => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          box(live),
          KkPressable(
            focusNode: disabled,
            builder: (BuildContext context, KkStates s) {
              states = s;
              return const SizedBox(width: 40, height: 40);
            },
          ),
          KkPressable(
            focusNode: barred,
            canRequestFocus: false,
            builder: (BuildContext context, KkStates s) => const SizedBox(width: 40, height: 40),
          ),
        ],
      );
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional),
            child: controls(),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(disabled.hasPrimaryFocus, isTrue, reason: 'it must be possible to find a disabled control');
      expect(states!.focused, isFalse);
      expect(states!.enabled, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(barred.hasFocus, isFalse);
      expect(live.hasPrimaryFocus, isTrue);

      // With keys and a mouse a disabled control is passed over.
      await pumpKk(tester, controls());
      disabled.requestFocus();
      await tester.pump();
      expect(disabled.hasFocus, isFalse);
    });

    testChecked('Tab stops at each control once', (WidgetTester tester) async {
      final List<FocusNode> nodes = <FocusNode>[for (int i = 0; i < 3; i++) FocusNode(debugLabel: 'n$i')];
      for (final FocusNode node in nodes) {
        addTearDown(node.dispose);
      }
      await pumpKk(tester, KkRow(shrinkWrap: true, children: <Widget>[for (final FocusNode node in nodes) box(node)]));
      final List<String?> visited = <String?>[];
      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        visited.add(FocusManager.instance.primaryFocus?.debugLabel);
      }
      expect(visited, <String>['n0', 'n1', 'n2', 'n0']);
    });
  });
}
