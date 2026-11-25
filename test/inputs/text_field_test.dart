import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

EditableText _editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));
KkFieldBox _box(WidgetTester tester) => tester.widget<KkFieldBox>(find.byType(KkFieldBox));

/// A right click at [at].
Future<void> _secondaryClick(WidgetTester tester, Offset at) async {
  final TestGesture gesture = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pump();
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

void main() {
  setUpAll(loadKkFonts);

  group('KkTextField', () {
    testWidgets('label, placeholder, support; the box is 36px high', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkTextField(
          width: 320,
          cjk: '識別符号',
          en: 'call sign',
          isRequired: true,
          placeholder: 'SEC-04',
          support: 'SECTOR CODE',
        ),
      );
      expect(find.text('識別符号'), findsOneWidget);
      expect(find.text('CALL SIGN'), findsOneWidget);
      expect(find.text('REQ'), findsOneWidget);
      expect(find.text('SEC-04'), findsOneWidget);
      expect(find.text('SECTOR CODE'), findsOneWidget);
      final Size box = tester.getSize(find.byType(KkFieldBox));
      expect(box, const Size(320, 36));
      // Label row (13px at 1.55), 6px gap, box, 6px gap, foot (11px at 1.4).
      final Rect field = tester.getRect(find.byType(KkTextField));
      final Rect boxRect = tester.getRect(find.byType(KkFieldBox));
      expect(boxRect.top - field.top, closeTo(13 * 1.55 + 6, 1.0));
      expect(field.bottom - boxRect.bottom, closeTo(6 + 11 * 1.4, 1.0));
      // The REQ mark is at the right end of the label row.
      expect(tester.getTopRight(find.text('REQ')).dx, 320);
    });

    testWidgets('width rules: at least 200, the parent width, 280 when unbounded', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 120, child: KkTextField(en: 'a')));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkBox(width: 500, child: KkTextField(en: 'a')));
      expect(tester.getSize(find.byType(KkTextField)).width, 500);
      await pumpKk(tester, const KkRow(children: <Widget>[KkTextField(en: 'a')]));
      expect(tester.getSize(find.byType(KkTextField)).width, 280);
      await pumpKk(tester, const KkRow(children: <Widget>[KkTextField(en: 'a', width: 240)]));
      expect(tester.getSize(find.byType(KkTextField)).width, 240);
    });

    testWidgets('typing reports changes and hides the placeholder', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(tester, KkTextField(width: 320, placeholder: 'SEC-04', onChanged: changes.add));
      expect(find.text('SEC-04'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'N-07');
      await tester.pump();
      expect(changes, <String>['N-07']);
      expect(find.text('SEC-04'), findsNothing);
      await tester.enterText(find.byType(EditableText), '');
      await tester.pump();
      expect(find.text('SEC-04'), findsOneWidget);
    });

    testWidgets('controller and initialValue', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'OP-07');
      addTearDown(controller.dispose);
      await pumpKk(tester, KkTextField(width: 320, controller: controller));
      expect(_editable(tester).controller.text, 'OP-07');
      controller.text = 'OP-09';
      await tester.pump();
      expect(find.text('OP-09'), findsOneWidget);

      await pumpKk(tester, const KkTextField(key: ValueKey<int>(2), width: 320, initialValue: '256'));
      expect(_editable(tester).controller.text, '256');
    });

    testWidgets('submit and editing complete', (WidgetTester tester) async {
      final List<String> submitted = <String>[];
      int completed = 0;
      await pumpKk(tester, KkTextField(width: 320, onSubmitted: submitted.add, onEditingComplete: () => completed++));
      await tester.enterText(find.byType(EditableText), 'SEC-04');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, <String>['SEC-04']);
      expect(completed, 1);
    });

    testWidgets('maxLength refuses more and shows a zero-padded counter', (WidgetTester tester) async {
      await pumpKk(tester, const KkTextField(width: 320, maxLength: 12));
      expect(find.text('00 / 12'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'ABCDEFGHIJKLMNOP');
      await tester.pump();
      expect(_editable(tester).controller.text, 'ABCDEFGHIJKL');
      expect(find.text('12 / 12'), findsOneWidget);
      // The counter can be turned off, or shown without a limit.
      await pumpKk(tester, const KkTextField(key: ValueKey<int>(2), width: 320, maxLength: 5, showCounter: false));
      expect(find.textContaining('/ 5'), findsNothing);
      await pumpKk(
        tester,
        const KkTextField(key: ValueKey<int>(3), width: 320, showCounter: true, initialValue: 'abc'),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('input formatters, obscured, mono', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTextField(
          width: 320,
          mono: true,
          obscureText: true,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        ),
      );
      await tester.enterText(find.byType(EditableText), '12ab34');
      await tester.pump();
      final EditableText e = _editable(tester);
      expect(e.controller.text, '1234');
      expect(e.obscureText, isTrue);
      expect(e.style.fontFamily, contains('IBM Plex Mono'));
      expect(e.style.fontSize, 14);
      expect(e.style.height, 1.4);
    });

    testWidgets('caret and selection follow the design', (WidgetTester tester) async {
      await pumpKk(tester, const KkTextField(width: 320, initialValue: 'abc'));
      final EditableText e = _editable(tester);
      expect(e.cursorColor, KkColors.standby.signal);
      expect(e.cursorWidth, 2);
      expect(e.cursorRadius, isNull);
      expect(e.cursorOpacityAnimates, isFalse);
      expect(e.style.fontFamily, contains('IBM Plex Sans KR'));
      expect(e.style.color, KkColors.standby.ink);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(_editable(tester).selectionColor, KkColors.standby.signalDim);
    });

    testWidgets('focus shows the ring and the brackets without moving the text', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        KkTextField(width: 320, focusNode: focus, initialValue: 'abc'),
        padding: const EdgeInsets.all(20),
      );
      expect(_box(tester).focused, isFalse);
      final Offset before = tester.getTopLeft(find.byType(EditableText));
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(_box(tester).focused, isTrue);
      expect(tester.getTopLeft(find.byType(EditableText)), before);
      expect(tester.getSize(find.byType(KkFieldBox)), const Size(320, 36));
      // The decoration: 2px signal edge and 8px / 2px brackets 5px outside.
      final KkBox inner = tester.widget<KkBox>(
        find.descendant(of: find.byType(KkFieldBox), matching: find.byType(KkBox)).first,
      );
      expect(inner.decoration!.edges.top, const KkSide(Color(0xFFFF7A1A), width: 2));
      expect(inner.decoration!.brackets, const KkBracketSpec(color: Color(0xFFFF7A1A), length: 8, width: 2, outset: 5));
      focus.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_box(tester).focused, isFalse);
    });

    testWidgets('a press on the padding focuses the input; hover is reported', (WidgetTester tester) async {
      await pumpKk(tester, const KkTextField(width: 320, icon: KkIcons.gauge, suffix: 'kPa'));
      await tester.tapAt(tester.getTopLeft(find.byType(KkFieldBox)) + const Offset(3, 18));
      await tester.pump();
      expect(_box(tester).focused, isTrue);

      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(KkFieldBox)));
      await tester.pump();
      expect(_box(tester).hovered, isTrue);
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(_box(tester).hovered, isFalse);
    });

    testWidgets('error: alert border, message with the critical icon', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkTextField(width: 320, support: 'RANGE 120-400', error: 'BELOW LIMIT 120', initialValue: '096'),
      );
      expect(_box(tester).error, isTrue);
      expect(find.text('BELOW LIMIT 120'), findsOneWidget);
      expect(find.text('RANGE 120-400'), findsNothing);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, KkLevel.critical);
      expect(tester.widget<Text>(find.text('BELOW LIMIT 120')).style!.color, KkColors.standby.alert);
      expect(_editable(tester).cursorColor, KkColors.standby.alert);
    });

    testWidgets('disabled: dashed, faint, not focusable, not editable', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(tester, KkTextField(width: 320, enabled: false, initialValue: 'LOCKED', onChanged: changes.add));
      expect(_box(tester).enabled, isFalse);
      final EditableText e = _editable(tester);
      expect(e.readOnly, isTrue);
      expect(e.style.color, KkColors.standby.inkFaint);
      await tester.tap(find.byType(KkFieldBox), warnIfMissed: false);
      await tester.pump();
      expect(e.focusNode.hasFocus, isFalse);
      await tester.tap(find.byType(EditableText), warnIfMissed: false);
      await tester.pump();
      expect(e.focusNode.hasFocus, isFalse);
      e.focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(e.focusNode.hasFocus, isFalse);
      expect(changes, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning a focused field off drops the focus; turning it on again allows it', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(tester, KkTextField(width: 320, focusNode: focus, initialValue: 'abc'));
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await pumpKk(tester, KkTextField(width: 320, focusNode: focus, initialValue: 'abc', enabled: false));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(_box(tester).focused, isFalse);
      await pumpKk(tester, KkTextField(width: 320, focusNode: focus, initialValue: 'abc'));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('readOnly keeps the text and still takes focus', (WidgetTester tester) async {
      await pumpKk(tester, const KkTextField(width: 320, readOnly: true, initialValue: 'FIXED'));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(_editable(tester).readOnly, isTrue);
      expect(_editable(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('multiline starts at 72px of content and grows', (WidgetTester tester) async {
      await pumpKk(tester, const KkTextField(width: 320, maxLines: null, placeholder: 'REMARKS'));
      // 1px border + 8px padding + 72px + 8px + 1px.
      expect(tester.getSize(find.byType(KkFieldBox)).height, 90);
      await tester.enterText(find.byType(EditableText), List<String>.filled(8, 'LINE').join('\n'));
      await tester.pump();
      expect(tester.getSize(find.byType(KkFieldBox)).height, greaterThan(150));
      expect(tester.takeException(), isNull);
      // A fixed number of lines scrolls instead.
      await pumpKk(tester, const KkTextField(key: ValueKey<int>(2), width: 320, maxLines: 3));
      await tester.enterText(find.byType(EditableText), List<String>.filled(20, 'LINE').join('\n'));
      await tester.pump();
      expect(tester.getSize(find.byType(KkFieldBox)).height, 90);
    });

    testWidgets('long text, tiny boxes and the alert theme do not throw', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTextField(
          width: 200,
          cjk: '冷却系統冷却系統冷却系統冷却系統冷却系統',
          en: 'a very long subtitle that cannot fit in two hundred pixels',
          isRequired: true,
          prefix: 'PREFIX-PREFIX',
          suffix: 'SUFFIX-SUFFIX',
          icon: KkIcons.gauge,
          initialValue: 'x' * 400,
          support: 'support ' * 30,
          maxLength: 1000,
        ),
        condition: KkCondition.alert,
      );
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkBox(width: 30, height: 12, clip: true, child: KkTextField(en: 'tiny')));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkTextField(width: 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: a labelled text field', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkTextField(width: 320, cjk: '区画', en: 'sector', initialValue: 'SEC-04'));
      expect(find.bySemanticsLabel(RegExp('sector')), findsWidgets);
      final SemanticsNode node = tester.getSemantics(find.byType(EditableText));
      expect(node.flagsCollection.isTextField, isTrue);
      handle.dispose();
    });
  });

  group('KkTextInput', () {
    testWidgets('works bare, with no bound on its width', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(
        tester,
        KkRow(
          children: <Widget>[KkTextInput(placeholder: 'FILTER', onChanged: changes.add)],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkTextInput)).width, 200);
      await tester.enterText(find.byType(EditableText), 'pump');
      expect(changes, <String>['pump']);
    });

    testWidgets('right click opens the text menu; SELECT ALL selects', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkBox(width: 300, child: KkTextInput(controller: controller)),
        padding: const EdgeInsets.all(40),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await _secondaryClick(tester, tester.getCenter(find.byType(EditableText)));
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.text('全選択'), findsOneWidget);
      // Nothing is selected, so there is nothing to cut or copy.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      await tester.tap(find.text('SELECT ALL'));
      await tester.pump();
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 14));
      // On a touch platform the menu stays and now offers what applies to a
      // selection.
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('CUT'), findsOneWidget);
      await tester.tap(find.text('CUT'));
      await tester.pump();
      expect(controller.text, '');
      expect(find.byType(KkTextContextMenu), findsNothing);
      // Let the framework's clipboard status settle.
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('desktop: the menu opens at the pointer at once, with key hints, and closes after the action', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkBox(width: 300, child: KkTextInput(controller: controller)),
        padding: const EdgeInsets.all(40),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final Offset at = tester.getTopLeft(find.byType(EditableText)) + const Offset(60, 10);
      await _secondaryClick(tester, at);
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      // At the pointer, and not inside the framework's fading wrapper.
      expect(tester.getTopLeft(find.byType(KkMenu<Object>)), at);
      for (RenderObject? r = tester.renderObject(find.byType(KkMenu<Object>)); r != null; r = r.parent) {
        expect(r, isNot(isA<RenderAnimatedOpacity>()));
      }
      expect(tester.getSize(find.byType(KkMenu<Object>)).width, 200);
      expect(find.text('CTRL+A'), findsOneWidget);
      await tester.tap(find.text('SELECT ALL'));
      await tester.pump();
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 14));
      expect(find.byType(KkTextContextMenu), findsNothing);
      // The field keeps the focus through the whole exchange.
      expect(_editable(tester).focusNode.hasFocus, isTrue);

      // With a selection: cut, copy and select all; Escape closes.
      await _secondaryClick(tester, at);
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('CTRL+X'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      expect(_editable(tester).focusNode.hasFocus, isTrue);

      // A click in the field (left of the menu) closes it too.
      await _secondaryClick(tester, at);
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      await tester.tapAt(
        tester.getTopLeft(find.byType(EditableText)) + const Offset(10, 10),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      expect(_editable(tester).focusNode.hasFocus, isTrue);

      // And so does a click anywhere else, which also takes the focus away.
      await _secondaryClick(tester, at);
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      await tester.tapAt(const Offset(700, 500), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      expect(_editable(tester).focusNode.hasFocus, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('desktop: the menu wipes open in 5 steps over 250ms and flips at the screen edge', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkBox(width: 300, child: KkTextInput(controller: controller)),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(8),
        motion: true,
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final Offset at = tester.getBottomRight(find.byType(EditableText)) - const Offset(20, 6);
      await _secondaryClick(tester, at);
      final Rect menu = tester.getRect(find.byType(KkMenu<Object>));
      // No room below or to the right: it opens upward and stays on screen.
      expect(menu.bottom, lessThanOrEqualTo(at.dy));
      expect(menu.right, lessThanOrEqualTo(800 - 4));
      // The same stepped wipe as every other menu.
      final Finder clip = find.ancestor(of: find.byType(KkMenu<Object>), matching: find.byType(ClipRect)).first;
      Rect shown() {
        final RenderClipRect render = tester.renderObject<RenderClipRect>(clip);
        return render.clipper!.getClip(render.size);
      }

      expect(shown().width, 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(shown().width, closeTo(200 * 2 / 5, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.none);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('desktop: the menu closes when the field scrolls away', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
      addTearDown(controller.dispose);
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: KkColumn(
            children: <Widget>[
              const KkBox(height: 100),
              KkBox(width: 300, child: KkTextInput(controller: controller)),
              const KkBox(height: 900),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await _secondaryClick(tester, tester.getCenter(find.byType(EditableText)));
      expect(find.byType(KkTextContextMenu), findsOneWidget);
      scroll.jumpTo(60);
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 500));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('contextMenu: false offers no menu', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(width: 300, child: KkTextInput(initialValue: 'abc', contextMenu: false)),
        padding: const EdgeInsets.all(40),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(EditableText)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pump();
      expect(find.byType(KkTextContextMenu), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('touch selection shows square handles', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkBox(width: 300, child: KkTextInput(controller: controller)),
        padding: const EdgeInsets.all(40),
      );
      await tester.longPressAt(tester.getTopLeft(find.byType(EditableText)) + const Offset(20, 10));
      await tester.pump();
      // A long press selects the word under the finger.
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
      expect(_editable(tester).showSelectionHandles, isTrue);
      expect(_editable(tester).selectionControls, isA<KkTextSelectionControls>());
      expect(kkTextSelectionControls.getHandleSize(20), const Size.square(14));
      expect(kkTextSelectionControls.getHandleAnchor(TextSelectionHandleType.left, 20), const Offset(14, 0));
      expect(tester.takeException(), isNull);
      // Let the framework's long-press and toolbar timers finish.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('field parts', () {
    testWidgets('KkFieldBox states', (WidgetTester tester) async {
      Future<KkDecoration> decoration(KkFieldBox box) async {
        await pumpKk(tester, KkBox(width: 200, child: box));
        return tester
            .widget<KkBox>(find.descendant(of: find.byType(KkFieldBox), matching: find.byType(KkBox)).first)
            .decoration!;
      }

      const KkColors c = KkColors.standby;
      const Widget child = KkBox();
      expect((await decoration(const KkFieldBox(child: child))).edges.top, KkSide(c.inkFaint));
      expect((await decoration(const KkFieldBox(hovered: true, child: child))).edges.top, KkSide(c.inkDim));
      expect((await decoration(const KkFieldBox(error: true, hovered: true, child: child))).edges.top, KkSide(c.alert));
      final KkDecoration focusedError = await decoration(const KkFieldBox(error: true, focused: true, child: child));
      expect(focusedError.edges.top, KkSide(c.alert, width: 2));
      expect(focusedError.brackets!.color, c.alert);
      final KkDecoration disabled = await decoration(const KkFieldBox(enabled: false, focused: true, child: child));
      expect(disabled.edges.top, KkSide(c.offline, dashed: true));
      expect(disabled.brackets, isNull);
      expect((await decoration(const KkFieldBox(focused: true, brackets: false, child: child))).brackets, isNull);
      expect(tester.getSize(find.byType(KkFieldBox)).height, 36);
    });

    testWidgets('KkFieldFoot wraps long support and shows a counter', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          child: KkFieldFoot(support: 'word ' * 40, counter: '004 / 120'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getTopRight(find.text('004 / 120')).dx, 200);
      await pumpKk(tester, const KkBox(width: 200, child: KkFieldFoot()));
      expect(tester.takeException(), isNull);
    });
  });
}
