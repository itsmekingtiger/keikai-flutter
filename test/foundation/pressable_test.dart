import 'dart:math' as math;
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

/// A lazy list with [first] as its first item.
///
/// Such a list builds and drops its items while it is laid out, which comes
/// after the build of the frame: an item can be rebuilt and then taken away in
/// one and the same frame, by a jump of [scroll].
Widget _lazyList(ScrollController scroll, Widget first) => CustomScrollView(
  controller: scroll,
  slivers: <Widget>[
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => SizedBox(height: 200, child: index == 0 ? first : null),
        childCount: 20,
        addAutomaticKeepAlives: false,
      ),
    ),
  ],
);

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

  group('KkPressable keys and the long press', () {
    testChecked('a control with a long press alone is operated with Enter and Space', (WidgetTester tester) async {
      int holds = 0;
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkPressable(
          focusNode: node,
          onLongPress: () => holds++,
          builder: (BuildContext context, KkStates states) => const SizedBox(width: 100, height: 40),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);

      // The keys are taken, so they must do the one thing the control does.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
      expect(holds, 1, reason: 'the only action of a focusable control must be reachable from the keyboard');
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isTrue);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter), isTrue);
      expect(holds, 3);

      // The pointer still has to hold.
      await tester.tap(find.byType(KkPressable));
      expect(holds, 3);
      await tester.longPress(find.byType(KkPressable));
      expect(holds, 4);
    });

    testChecked('with a press and a long press the keys press', (WidgetTester tester) async {
      int presses = 0;
      int holds = 0;
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkPressable(
          focusNode: node,
          onPressed: () => presses++,
          onLongPress: () => holds++,
          builder: (BuildContext context, KkStates states) => const SizedBox(width: 100, height: 40),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
      expect(holds, 0);
    });

    testChecked('a disabled control with a long press alone does nothing', (WidgetTester tester) async {
      int holds = 0;
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkPressable(
          focusNode: node,
          enabled: false,
          onLongPress: () => holds++,
          builder: (BuildContext context, KkStates states) => const SizedBox(width: 100, height: 40),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.longPress(find.byType(KkPressable));
      expect(holds, 0);
    });

    testChecked('a button, an icon button, a FAB and a list row with a long press alone answer to Enter', (
      WidgetTester tester,
    ) async {
      final List<String> held = <String>[];
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkButton(label: 'hold', onLongPress: () => held.add('button')),
            KkIconButton(icon: KkIcons.power, semanticLabel: 'power', onLongPress: () => held.add('icon button')),
            KkFab(icon: KkIcons.plus, semanticLabel: 'add', onLongPress: () => held.add('fab')),
            KkListRow(en: 'sector', onLongPress: () => held.add('row')),
          ],
        ),
        size: const Size(600, 400),
      );
      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      expect(held, <String>['button', 'icon button', 'fab', 'row']);
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

    testChecked('a focused control that is given another focus node loses its ring with the node', (
      WidgetTester tester,
    ) async {
      KkStates? states;
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      Widget control(FocusNode node) => KkPressable(
        focusNode: node,
        onPressed: () {},
        builder: (BuildContext context, KkStates s) {
          states = s;
          return KkFocusRing(visible: s.focused, child: const SizedBox(width: 100, height: 40));
        },
      );
      await pumpKk(tester, control(a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(states!.focused, isTrue);
      expect(rings(tester), 1);

      // The node that goes takes the focus with it, and no node tells the
      // control: nothing has the focus, so nothing shows a ring.
      await pumpKk(tester, control(b));
      expect(a.hasPrimaryFocus, isFalse);
      expect(b.hasFocus, isFalse);
      expect(states!.focused, isFalse);
      expect(rings(tester), 0);
    });

    testChecked('a control that is given a node that has the focus shows it as the last input says', (
      WidgetTester tester,
    ) async {
      final FocusNode moved = FocusNode(debugLabel: 'moved');
      final List<FocusNode> spare = <FocusNode>[for (int i = 0; i < 3; i++) FocusNode(debugLabel: 'spare$i')];
      addTearDown(moved.dispose);
      for (final FocusNode node in spare) {
        addTearDown(node.dispose);
      }
      final List<bool?> shown = <bool?>[null, null, null];
      // Three controls, one of them on the node that is handed along.
      Widget row(int at) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            KkPressable(
              focusNode: i == at ? moved : spare[i],
              onPressed: () {},
              builder: (BuildContext context, KkStates states) {
                shown[i] = states.focused;
                return const SizedBox(width: 100, height: 40);
              },
            ),
        ],
      );
      await pumpKk(tester, row(2));
      moved.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(shown, <bool>[false, false, true]);

      // The app hands the focused node to the control before. The node keeps
      // the focus and has nothing to tell.
      await pumpKk(tester, row(1));
      expect(moved.hasPrimaryFocus, isTrue);
      expect(shown, <bool>[false, true, false]);

      // Once more after a press of the mouse: the focus comes with the node,
      // the ring does not.
      await _click(tester, const Offset(400, 400));
      await tester.pump();
      expect(shown, <bool>[false, false, false]);
      await pumpKk(tester, row(0));
      expect(moved.hasPrimaryFocus, isTrue);
      expect(shown, <bool>[false, false, false]);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(shown, <bool>[true, false, false]);
    });

    testChecked('a control built on a node that has the focus shows it from its first frame, as the last input says', (
      WidgetTester tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      final List<bool> seen = <bool>[];
      Widget control(String name) => KkPressable(
        key: ValueKey<String>(name),
        focusNode: node,
        onPressed: () {},
        builder: (BuildContext context, KkStates states) {
          seen.add(states.focused);
          return KkFocusRing(visible: states.focused, child: const SizedBox(width: 100, height: 40));
        },
      );
      await pumpKk(tester, control('first'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(seen.last, isTrue);

      // The app keeps the node and puts another control on it. The node keeps
      // the focus and has nothing to tell the new control.
      seen.clear();
      await pumpKk(tester, control('second'));
      expect(node.hasPrimaryFocus, isTrue);
      expect(seen, isNotEmpty);
      expect(seen, everyElement(isTrue));
      expect(rings(tester), 1);

      // After a press of the mouse the next control has the focus and no ring.
      await _click(tester, const Offset(400, 400));
      await tester.pump();
      expect(seen.last, isFalse);
      seen.clear();
      await pumpKk(tester, control('third'));
      expect(node.hasPrimaryFocus, isTrue);
      expect(seen, isNotEmpty);
      expect(seen, everyElement(isFalse));
      expect(rings(tester), 0);
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

    _testOnDesktop('a key that repeats or is let go is not pressed again', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isTrue);

      // A click with Shift held down, the way a selection is extended.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(states!.focused, isTrue);
      await _click(tester, const Offset(400, 400));
      await tester.pump();
      expect(states!.focused, isFalse);
      // On some platforms a key that is held down repeats, a modifier too.
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(states!.focused, isFalse, reason: 'the key was pressed before the mouse');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(states!.focused, isFalse, reason: 'the last thing that was pressed is the mouse');
    });

    _testOnDesktop('a key event that only mends the record of the keyboard is not a key press', (
      WidgetTester tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, control(node));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(states!.focused, isTrue);
      await _click(tester, const Offset(400, 400));
      await tester.pump();
      expect(states!.focused, isFalse);

      // A modifier that went down while the window was not looking: the
      // platform notices at the click and makes the missing event up.
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
          synthesized: true,
        ),
      );
      await tester.pump();
      expect(states!.focused, isFalse, reason: 'nobody pressed a key');
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
          synthesized: true,
        ),
      );
      await tester.pump();
      expect(states!.focused, isFalse);

      // A key that is pressed does show the focus again.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(states!.focused, isTrue);
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

  group('KkPressable hover', () {
    final List<bool> log = <bool>[];
    KkStates? states;

    setUp(() {
      log.clear();
      states = null;
    });

    Widget control({bool live = true, bool enabled = true}) => KkPressable(
      enabled: enabled,
      onPressed: live ? () {} : null,
      onHoverChanged: log.add,
      builder: (BuildContext context, KkStates s) {
        states = s;
        return const SizedBox(width: 100, height: 40);
      },
    );

    /// A mouse pointer resting on the control.
    Future<TestGesture> hover(WidgetTester tester) async {
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(50, 20));
      await tester.pump();
      return mouse;
    }

    _testOnDesktop('a hovered control that stops being interactive reports the end of the hover', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, control());
      final TestGesture mouse = await hover(tester);
      expect(states!.hovered, isTrue);
      expect(log, <bool>[true]);

      // The callback is taken away: the look goes with the same frame, and
      // whoever was told that the hover began is told that it ended.
      await tester.pumpWidget(kkHarness(control(live: false)));
      expect(states!.hovered, isFalse);
      await tester.pump();
      expect(states!.hovered, isFalse);
      expect(log, <bool>[true, false]);

      // The pointer leaving later has nothing more to say.
      await mouse.moveTo(const Offset(400, 400));
      await tester.pump();
      await tester.pump();
      expect(log, <bool>[true, false]);
    });

    _testOnDesktop('enabled again under the pointer it reports the hover again', (WidgetTester tester) async {
      await pumpKk(tester, control());
      await hover(tester);
      expect(log, <bool>[true]);

      await pumpKk(tester, control(enabled: false));
      expect(states!.hovered, isFalse);
      expect(log, <bool>[true, false]);

      await pumpKk(tester, control());
      await tester.pump();
      expect(states!.hovered, isTrue);
      expect(log, <bool>[true, false, true], reason: 'every true is followed by a false before the next true');
    });

    _testOnDesktop('a control that is built disabled under the pointer reports nothing until it is enabled', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, control(enabled: false));
      final TestGesture mouse = await hover(tester);
      expect(states!.hovered, isFalse);
      expect(log, isEmpty);

      await pumpKk(tester, control());
      await tester.pump();
      expect(states!.hovered, isTrue);
      expect(log, <bool>[true]);

      await mouse.moveTo(const Offset(400, 400));
      await tester.pump();
      expect(states!.hovered, isFalse);
      expect(log, <bool>[true, false]);
    });

    _testOnDesktop('a press in progress ends when the control is disabled', (WidgetTester tester) async {
      await pumpKk(tester, control());
      final TestGesture finger = await tester.startGesture(const Offset(50, 20));
      await tester.pump();
      expect(states!.pressed, isTrue);
      await pumpKk(tester, control(enabled: false));
      expect(states!.pressed, isFalse);
      await pumpKk(tester, control());
      expect(states!.pressed, isFalse);
      await finger.up();
      await tester.pump();
      expect(states!.pressed, isFalse);
    });

    _testOnDesktop('a hovered control that is disabled and scrolled away in the same frame is left alone', (
      WidgetTester tester,
    ) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      bool enabled = true;
      late StateSetter setItem;
      await pumpKk(
        tester,
        _lazyList(
          scroll,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setItem = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: control(enabled: enabled),
              );
            },
          ),
        ),
      );
      await hover(tester);
      expect(states!.hovered, isTrue);
      expect(log, <bool>[true]);

      // The detector reports the end of the hover after the frame in which
      // its control was disabled, and by then the list has dropped the control.
      setItem(() => enabled = false);
      scroll.jumpTo(2000);
      await tester.pump();
      expect(find.byType(KkPressable), findsNothing);
      expect(tester.takeException(), isNull);
      expect(log, <bool>[true], reason: 'a control that is gone does not report');
    });
  });

  group('KkPressable onFocusChanged', () {
    final List<String> log = <String>[];

    setUp(log.clear);

    /// A control that logs what it is told about the focus as "name:value".
    Widget control(String name, {FocusNode? node, Key? key, Widget child = const SizedBox(width: 40, height: 40)}) =>
        KkPressable(
          key: key,
          focusNode: node,
          onPressed: () {},
          onFocusChanged: (bool focused) => log.add('$name:$focused'),
          builder: (BuildContext context, KkStates states) => child,
        );

    Future<void> shiftTab(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
    }

    testChecked('the control that loses the focus says so before the one that takes it', (WidgetTester tester) async {
      // The focused control kept in one variable, the way an app keeps it.
      int? active;
      final FocusNode last = FocusNode(debugLabel: 'last');
      addTearDown(last.dispose);
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              KkPressable(
                // One control on a node of the app's, the others on their own.
                focusNode: i == 2 ? last : null,
                onPressed: () {},
                onFocusChanged: (bool focused) {
                  log.add('$i:$focused');
                  active = focused ? i : null;
                },
                builder: (BuildContext context, KkStates states) => const SizedBox(width: 40, height: 40),
              ),
          ],
        ),
      );
      for (int i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(active, i, reason: 'control $i has the focus');
      }
      expect(log, <String>['0:true', '0:false', '1:true', '1:false', '2:true']);

      // Round to the first one, back again, and moved by the program.
      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(active, 0);
      await shiftTab(tester);
      expect(active, 2);
      await shiftTab(tester);
      expect(active, 1);
      last.requestFocus();
      await tester.pump();
      expect(active, 2);
      expect(log, <String>['2:false', '0:true', '0:false', '2:true', '2:false', '1:true', '1:false', '2:true']);
    });

    testChecked('next to a plain Focus it reports in the order of a plain Focus', (WidgetTester tester) async {
      final FocusNode plain = FocusNode(debugLabel: 'plain');
      addTearDown(plain.dispose);
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            Focus(
              focusNode: plain,
              onFocusChange: (bool focused) => log.add('plain:$focused'),
              child: const SizedBox(width: 40, height: 40),
            ),
            control('control'),
          ],
        ),
      );
      plain.requestFocus();
      await tester.pump();
      expect(log, <String>['plain:true']);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(log, <String>['plain:false', 'control:true']);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(log, <String>['control:false', 'plain:true']);
    });

    testChecked('the focus moving between a control and something inside it is no change for the control', (
      WidgetTester tester,
    ) async {
      final FocusNode row = FocusNode(debugLabel: 'row');
      final FocusNode inner = FocusNode(debugLabel: 'inner');
      final FocusNode next = FocusNode(debugLabel: 'next');
      addTearDown(row.dispose);
      addTearDown(inner.dispose);
      addTearDown(next.dispose);
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            control(
              'row',
              node: row,
              child: KkBox(
                width: 200,
                height: 48,
                alignment: Alignment.centerRight,
                child: control('inner', node: inner),
              ),
            ),
            control('next', node: next),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(row.hasPrimaryFocus, isTrue);
      expect(log, <String>['row:true']);

      // In to the control inside and out again: the row has the focus all along.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner.hasPrimaryFocus, isTrue);
      expect(log, <String>['row:true', 'inner:true']);
      await shiftTab(tester);
      expect(row.hasPrimaryFocus, isTrue);
      expect(log, <String>['row:true', 'inner:true', 'inner:false']);

      // From the control inside on to the next one: both are done with the
      // focus before the next one has it.
      inner.requestFocus();
      await tester.pump();
      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(next.hasPrimaryFocus, isTrue);
      expect(log, hasLength(3));
      expect(log.sublist(0, 2), unorderedEquals(<String>['row:false', 'inner:false']));
      expect(log.last, 'next:true');
    });

    testChecked('a focused control that is given another focus node says that the focus is gone', (
      WidgetTester tester,
    ) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpKk(tester, control('control', node: a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(log, <String>['control:true']);

      // The node that goes takes the focus with it, and neither node reports.
      await pumpKk(tester, control('control', node: b));
      expect(a.hasFocus, isFalse);
      expect(b.hasFocus, isFalse);
      expect(log, <String>['control:true', 'control:false'], reason: 'nothing has the focus now');

      // The new node is the one that is heard from now on.
      b.requestFocus();
      await tester.pump();
      expect(log, <String>['control:true', 'control:false', 'control:true']);

      // And once more, to a node of the control's own.
      await pumpKk(tester, control('control'));
      expect(b.hasFocus, isFalse);
      expect(log, <String>['control:true', 'control:false', 'control:true', 'control:false']);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(log, hasLength(5));
      expect(log.last, 'control:true');
    });

    testChecked('the focus that falls back on another control after an exchange of nodes is reported in order', (
      WidgetTester tester,
    ) async {
      // The focused control kept in one variable again.
      int? active;
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      Widget one(int i, FocusNode? node) => KkPressable(
        focusNode: node,
        onPressed: () {},
        onFocusChanged: (bool focused) {
          log.add('$i:$focused');
          active = focused ? i : null;
        },
        builder: (BuildContext context, KkStates states) => const SizedBox(width: 40, height: 40),
      );
      Widget row(FocusNode node) => KkRow(shrinkWrap: true, children: <Widget>[one(0, null), one(1, node)]);
      await pumpKk(tester, row(a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(active, 1);

      // The node that goes takes the focus with it, and the focus manager
      // gives it to the control that had it before.
      log.clear();
      await pumpKk(tester, row(b));
      expect(a.hasFocus, isFalse);
      expect(b.hasFocus, isFalse);
      expect(log, <String>['1:false', '0:true']);
      expect(active, 0, reason: 'the first control has the focus');
    });

    testChecked('a focus node that is handed from one control to another is reported by the one that gives it first', (
      WidgetTester tester,
    ) async {
      int? active;
      final FocusNode roving = FocusNode(debugLabel: 'roving');
      addTearDown(roving.dispose);
      // Three controls, and one node of the app's for the one that is current.
      Widget row(int current) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            KkPressable(
              focusNode: i == current ? roving : null,
              onPressed: () {},
              onFocusChanged: (bool focused) {
                log.add('$i:$focused');
                active = focused ? i : null;
              },
              builder: (BuildContext context, KkStates states) => const SizedBox(width: 40, height: 40),
            ),
        ],
      );
      await pumpKk(tester, row(1));
      roving.requestFocus();
      await tester.pump();
      expect(log, <String>['1:true']);

      // To the control before: the node keeps the focus on the way.
      log.clear();
      await pumpKk(tester, row(0));
      expect(roving.hasPrimaryFocus, isTrue);
      expect(log, <String>['1:false', '0:true']);
      expect(active, 0);

      // To a control after: the node loses the focus on the way, and the app
      // gives it back when the frame is built.
      log.clear();
      WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) => roving.requestFocus());
      await pumpKk(tester, row(2));
      expect(roving.hasPrimaryFocus, isTrue);
      expect(log, <String>['0:false', '2:true']);
      expect(active, 2);
    });

    testChecked('a focused control that is given another node says that the focus left, and when it is back', (
      WidgetTester tester,
    ) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      final FocusNode inside = FocusNode(debugLabel: 'inside');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(inside.dispose);
      Widget tree(FocusNode node) => control(
        'control',
        node: node,
        child: KkBox(
          width: 200,
          height: 48,
          alignment: Alignment.center,
          child: Focus(focusNode: inside, child: const SizedBox(width: 20, height: 20)),
        ),
      );
      await pumpKk(tester, tree(a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(log, <String>['control:true']);

      // The app exchanges the node and puts the focus on the new one. In
      // between nothing had the focus.
      b.requestFocus();
      await pumpKk(tester, tree(b));
      expect(b.hasPrimaryFocus, isTrue);
      expect(log, <String>['control:true', 'control:false', 'control:true']);

      // The focus on something inside the control stays where it is: there is
      // nothing to say.
      inside.requestFocus();
      await tester.pump();
      log.clear();
      await pumpKk(tester, tree(a));
      expect(inside.hasPrimaryFocus, isTrue);
      expect(a.hasFocus, isTrue);
      expect(log, isEmpty);

      // Left without a node, the focus falls back on what had it before, and
      // that is inside the control.
      a.requestFocus();
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(log, isEmpty);
      await pumpKk(tester, tree(b));
      expect(inside.hasPrimaryFocus, isTrue);
      expect(log, <String>['control:false', 'control:true']);
    });

    testChecked('a control built on a node that has the focus says so, and again when the focus leaves', (
      WidgetTester tester,
    ) async {
      final FocusNode node = FocusNode(debugLabel: 'node');
      final FocusNode inside = FocusNode(debugLabel: 'inside');
      final FocusNode other = FocusNode(debugLabel: 'other');
      addTearDown(node.dispose);
      addTearDown(inside.dispose);
      addTearDown(other.dispose);
      // The app keeps its nodes and puts another control on them.
      Widget tree(String name) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          control(
            name,
            node: node,
            key: ValueKey<String>(name),
            child: KkBox(
              width: 200,
              height: 48,
              alignment: Alignment.center,
              child: Focus(focusNode: inside, child: const SizedBox(width: 20, height: 20)),
            ),
          ),
          control('other', node: other),
        ],
      );
      await pumpKk(tester, tree('first'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(log, <String>['first:true']);

      // The node keeps the focus and has nothing to tell the new control.
      await pumpKk(tester, tree('second'));
      expect(node.hasPrimaryFocus, isTrue);
      expect(log, <String>['first:true', 'second:true']);
      other.requestFocus();
      await tester.pump();
      expect(log, <String>['first:true', 'second:true', 'second:false', 'other:true']);

      // The same with the focus on something inside the control.
      inside.requestFocus();
      await tester.pump();
      log.clear();
      await pumpKk(tester, tree('third'));
      expect(inside.hasPrimaryFocus, isTrue);
      expect(log, <String>['third:true']);
      other.requestFocus();
      await tester.pump();
      expect(log, <String>['third:true', 'third:false', 'other:true']);
    });

    testChecked('a node that is taken from a control is not listened to any more', (WidgetTester tester) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      Widget tree({FocusNode? first, FocusNode? second}) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          if (first != null) control('first', node: first, key: const ValueKey<String>('first')),
          if (second != null) control('second', node: second, key: const ValueKey<String>('second')),
        ],
      );
      await pumpKk(tester, tree(first: a));
      await pumpKk(tester, tree(first: b));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(b.hasPrimaryFocus, isTrue);
      expect(log, <String>['first:true']);

      // The control goes while it has the focus and shows its ring, and the
      // node it had at first serves another control.
      await pumpKk(tester, tree(second: a));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(log, <String>['first:true', 'second:true'], reason: 'a control that is gone does not report');
      a.unfocus();
      await tester.pump();
      expect(log, <String>['first:true', 'second:true', 'second:false']);
    });

    testChecked('a control that is given another node and scrolled away in the same frame says nothing', (
      WidgetTester tester,
    ) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      final ScrollController scroll = ScrollController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(scroll.dispose);
      FocusNode node = a;
      late StateSetter setItem;
      await pumpKk(
        tester,
        _lazyList(
          scroll,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setItem = setState;
              return control('control', node: node);
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(a.hasPrimaryFocus, isTrue);
      expect(log, <String>['control:true']);

      setItem(() => node = b);
      scroll.jumpTo(2000);
      await tester.pump();
      expect(find.byType(KkPressable), findsNothing);
      await tester.pump();
      expect(log, <String>['control:true'], reason: 'a control that is gone does not report');
    });

    testChecked('random focus moves and exchanges of nodes: an app that notes the focused control is never wrong', (
      WidgetTester tester,
    ) async {
      const int count = 4;
      final math.Random random = math.Random(7);
      final List<FocusNode> pool = <FocusNode>[for (int i = 0; i < 10; i++) FocusNode(debugLabel: 'pool$i')];
      for (final FocusNode node in pool) {
        addTearDown(node.dispose);
      }
      for (int round = 0; round < 24; round++) {
        // What the app notes: the focused control in one variable, and what
        // each control said last.
        int? active;
        final List<bool?> told = List<bool?>.filled(count, null);
        final List<String> repeated = <String>[];
        // What the controls are built with: a node of the app's or none, and
        // a key that is changed to put another control in the place.
        final List<FocusNode?> nodes = <FocusNode?>[pool[0], null, pool[1], pool[2]];
        final List<int> generation = List<int>.filled(count, 0);
        final List<FocusNode?> current = List<FocusNode?>.filled(count, null);
        Widget row() => KkRow(
          key: ValueKey<int>(round),
          shrinkWrap: true,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              KkPressable(
                key: ValueKey<String>('$i/${generation[i]}'),
                focusNode: nodes[i],
                onPressed: () {},
                onFocusChanged: (bool focused) {
                  if (told[i] == focused) repeated.add('$i:$focused');
                  told[i] = focused;
                  active = focused ? i : null;
                },
                builder: (BuildContext context, KkStates states) => Builder(
                  builder: (BuildContext context) {
                    current[i] = Focus.of(context);
                    return const SizedBox(width: 40, height: 40);
                  },
                ),
              ),
          ],
        );
        FocusNode? spare() {
          final List<FocusNode> free = pool.where((FocusNode node) => !nodes.contains(node)).toList();
          return random.nextBool() ? free[random.nextInt(free.length)] : null;
        }

        await tester.pumpWidget(kkHarness(row()));
        for (int step = 0; step < 30; step++) {
          final int i = random.nextInt(count);
          final int move = random.nextInt(8);
          switch (move) {
            case 0 || 1:
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            case 2:
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
            case 3:
              current[i]!.requestFocus();
            case 4:
              FocusManager.instance.primaryFocus?.unfocus();
            case 5:
              // Another node for a control, with or without the focus for it.
              final FocusNode? next = nodes[i] = spare();
              if (next != null && random.nextBool()) next.requestFocus();
            case 6:
              // The node of one control for another one, and the focus for
              // it again when the frame is built, or not.
              final int j = (i + 1 + random.nextInt(count - 1)) % count;
              final FocusNode? moved = nodes[j] = nodes[i];
              nodes[i] = spare();
              if (moved != null && random.nextBool()) {
                WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) => moved.requestFocus());
              }
            case 7:
              // Another control on the same node. The one that goes says
              // nothing, so the app forgets what it noted about it.
              generation[i]++;
              told[i] = null;
              if (active == i) active = null;
          }
          await tester.pumpWidget(kkHarness(row()));
          await tester.pump();

          final String at = 'round $round, step $step, move $move on control $i';
          int? focused;
          for (int k = 0; k < count; k++) {
            if (current[k]!.hasFocus) focused = k;
            expect(told[k] ?? false, current[k]!.hasFocus, reason: '$at: what control $k said last');
          }
          expect(active, focused, reason: '$at: the control the app takes for the focused one');
          expect(repeated, isEmpty, reason: '$at: a control said the same thing twice');
        }
      }
    });
  });
}
