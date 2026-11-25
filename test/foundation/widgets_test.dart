import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const KkColors _c = KkColors.standby;

/// The render object that draws a [KkIcon] or a [KkGlyph].
RenderKkIcon _icon(WidgetTester tester, Type type) => tester.renderObject<RenderKkIcon>(
  find.descendant(of: find.byType(type), matching: find.byWidgetPredicate((Widget w) => w is LeafRenderObjectWidget)),
);

/// The span of a [KkClock] that carries its style and its parts.
TextSpan _clockSpan(WidgetTester tester) {
  final TextSpan root = tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
  return root.children!.single as TextSpan;
}

void main() {
  setUpAll(loadKkFonts);

  group('KkPressable', () {
    KkStates? states;
    int presses = 0;
    int longPresses = 0;

    setUp(() {
      states = null;
      presses = 0;
      longPresses = 0;
    });

    Widget pressable({
      bool enabled = true,
      bool withCallback = true,
      bool withLongPress = false,
      FocusNode? focusNode,
      bool autofocus = false,
      ValueChanged<bool>? onHover,
      ValueChanged<bool>? onFocus,
      MouseCursor? cursor,
      bool? selected,
      bool? checked,
      bool? mixed,
      bool? toggled,
      bool button = true,
      bool excludeSemantics = false,
    }) {
      return KkPressable(
        enabled: enabled,
        onPressed: withCallback ? () => presses++ : null,
        onLongPress: withLongPress ? () => longPresses++ : null,
        focusNode: focusNode,
        autofocus: autofocus,
        onHoverChanged: onHover,
        onFocusChanged: onFocus,
        cursor: cursor,
        semanticLabel: 'Acknowledge',
        selected: selected,
        checked: checked,
        mixed: mixed,
        toggled: toggled,
        button: button,
        excludeSemantics: excludeSemantics,
        builder: (BuildContext context, KkStates s) {
          states = s;
          return const SizedBox(width: 100, height: 40, child: Text('inner'));
        },
      );
    }

    testWidgets('a tap presses it', (WidgetTester tester) async {
      await pumpKk(tester, pressable());
      expect(states, const KkStates());
      await tester.tap(find.byType(KkPressable));
      expect(presses, 1);
    });

    testWidgets('shows the pressed state while the pointer is down', (WidgetTester tester) async {
      await pumpKk(tester, pressable());
      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(KkPressable)));
      await tester.pump();
      expect(states!.pressed, isTrue);
      await gesture.up();
      await tester.pump();
      expect(states!.pressed, isFalse);
      expect(presses, 1);
      // A press that slides away is cancelled.
      final TestGesture slide = await tester.startGesture(tester.getCenter(find.byType(KkPressable)));
      await tester.pump();
      expect(states!.pressed, isTrue);
      await slide.moveBy(const Offset(0, 300));
      await slide.up();
      await tester.pump();
      expect(states!.pressed, isFalse);
      expect(presses, 1);
    });

    testWidgets('Enter, numpad Enter and Space activate it when focused', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, pressable(focusNode: node));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 0, reason: 'not focused yet');
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(presses, 3);
    });

    testWidgets('works without an app around it (its own shortcuts)', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: pressable(focusNode: node)),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byType(KkPressable));
      expect(presses, 2);
    });

    testWidgets('disabled by flag or by having no callback', (WidgetTester tester) async {
      for (final Widget w in <Widget>[pressable(enabled: false), pressable(withCallback: false)]) {
        final FocusNode node = FocusNode();
        await pumpKk(tester, KeyedSubtree(key: UniqueKey(), child: w));
        expect(states!.enabled, isFalse);
        expect(states!.disabled, isTrue);
        await tester.tap(find.byType(KkPressable));
        await tester.pump();
        expect(presses, 0);
        expect(states!.pressed, isFalse);
        expect(states!.hovered, isFalse);
        node.dispose();
      }
    });

    testWidgets('a disabled control cannot take focus or keys', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, pressable(enabled: false, focusNode: node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 0);
    });

    testWidgets('a long press', (WidgetTester tester) async {
      await pumpKk(tester, pressable(withLongPress: true));
      await tester.longPress(find.byType(KkPressable));
      expect(longPresses, 1);
      expect(presses, 0);
      // Long press alone also enables the control.
      await pumpKk(tester, KeyedSubtree(key: UniqueKey(), child: pressable(withCallback: false, withLongPress: true)));
      expect(states!.enabled, isTrue);
      await tester.longPress(find.byType(KkPressable));
      expect(longPresses, 2);
    });

    testWidgets('hover with a mouse', (WidgetTester tester) async {
      // Hover highlights follow the framework's highlight mode; the test
      // platform starts in touch mode, a desktop in traditional mode.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final List<bool> log = <bool>[];
      await pumpKk(tester, pressable(onHover: log.add));
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 500));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(states!.hovered, isFalse);
      await mouse.moveTo(tester.getCenter(find.byType(KkPressable)));
      await tester.pump();
      expect(states!.hovered, isTrue);
      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      expect(states!.hovered, isFalse);
      expect(log, <bool>[true, false]);
    });

    testWidgets('the cursor is a hand, forbidden when disabled, or the given one', (WidgetTester tester) async {
      MouseCursor cursor() => tester.widget<FocusableActionDetector>(find.byType(FocusableActionDetector)).mouseCursor;
      await pumpKk(tester, pressable());
      expect(cursor(), SystemMouseCursors.click);
      await pumpKk(tester, pressable(enabled: false));
      expect(cursor(), SystemMouseCursors.forbidden);
      await pumpKk(tester, pressable(cursor: SystemMouseCursors.grab));
      expect(cursor(), SystemMouseCursors.grab);
    });

    testWidgets('the focus state shows for keyboard focus only', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      final List<bool> log = <bool>[];
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

      // Pointer mode: focused, but no ring.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      await pumpKk(tester, pressable(focusNode: node, onFocus: log.add));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(states!.focused, isFalse);
      expect(log, <bool>[true]);

      // Keyboard mode: the ring shows.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(states!.focused, isTrue);
      node.unfocus();
      await tester.pump();
      await tester.pump();
      expect(states!.focused, isFalse);
      expect(log, <bool>[true, false]);
    });

    testWidgets('autofocus', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, pressable(focusNode: node, autofocus: true));
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('Tab moves focus between controls', (WidgetTester tester) async {
      final FocusNode a = FocusNode(debugLabel: 'a');
      final FocusNode b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpKk(
        tester,
        KkRow(
          children: <Widget>[
            KkPressable(
              focusNode: a,
              onPressed: () {},
              builder: (BuildContext context, KkStates s) => const SizedBox(width: 40, height: 40),
            ),
            KkPressable(
              focusNode: b,
              onPressed: () {},
              builder: (BuildContext context, KkStates s) => const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      );
      a.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(b.hasFocus, isTrue);
    });

    testWidgets('semantics: a labelled, enabled button with its flags', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, pressable(selected: true));
      SemanticsData data = tester.getSemantics(find.bySemanticsLabel(RegExp('Acknowledge'))).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isFocused, isNot(Tristate.none));

      await pumpKk(tester, pressable(enabled: false, checked: true));
      data = tester.getSemantics(find.bySemanticsLabel(RegExp('Acknowledge'))).getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isFalse);

      await pumpKk(tester, pressable(mixed: true, checked: true));
      data = tester.getSemantics(find.bySemanticsLabel(RegExp('Acknowledge'))).getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.mixed);

      await pumpKk(tester, pressable(toggled: false, button: false, withLongPress: true));
      data = tester.getSemantics(find.bySemanticsLabel(RegExp('Acknowledge'))).getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);

      // A semantic tap presses it.
      await pumpKk(tester, pressable());
      tester.semantics.tap(find.semantics.byLabel(RegExp('Acknowledge')));
      expect(presses, 1);
      handle.dispose();
    });

    testWidgets('excludeSemantics replaces the child text with the label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, pressable());
      expect(find.bySemanticsLabel(RegExp('inner')), findsOneWidget);
      await pumpKk(tester, pressable(excludeSemantics: true));
      expect(find.bySemanticsLabel(RegExp('inner')), findsNothing);
      expect(find.bySemanticsLabel('Acknowledge'), findsOneWidget);
      handle.dispose();
    });

    test('KkStates equality', () {
      expect(const KkStates(), const KkStates());
      expect(const KkStates(hovered: true) == const KkStates(), isFalse);
      expect(const KkStates(pressed: true).hashCode, const KkStates(pressed: true).hashCode);
      expect(const KkStates(enabled: false).disabled, isTrue);
    });
  });

  group('KkFocusRing', () {
    testWidgets('draws a 2px ring 2px outside the child, in the focus colour', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkFocusRing(visible: true, child: SizedBox(width: 100, height: 40)),
        padding: const EdgeInsets.all(20),
      );
      expect(
        find.byType(KkFocusRing),
        paints..rect(
          rect: const Rect.fromLTWH(-3, -3, 106, 46),
          color: _c.focus,
          strokeWidth: 2,
          style: PaintingStyle.stroke,
        ),
      );
      expect(tester.getSize(find.byType(KkFocusRing)), const Size(100, 40));
    });

    testWidgets('a negative offset draws inside; hidden draws nothing', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkFocusRing(visible: true, offset: -2, child: SizedBox(width: 100, height: 40)),
      );
      expect(find.byType(KkFocusRing), paints..rect(rect: const Rect.fromLTWH(1, 1, 98, 38)));
      await pumpKk(
        tester,
        const KkFocusRing(visible: true, offset: 4, width: 4, color: Color(0xFF00FF00), child: SizedBox(width: 10, height: 10)),
      );
      expect(
        find.byType(KkFocusRing),
        paints..rect(rect: const Rect.fromLTWH(-6, -6, 22, 22), color: const Color(0xFF00FF00), strokeWidth: 4),
      );
      await pumpKk(tester, const KkFocusRing(visible: false, child: SizedBox(width: 100, height: 40)));
      expect(find.byType(KkFocusRing), paintsNothing);
      // A ring that would collapse is skipped.
      await pumpKk(tester, const KkFocusRing(visible: true, offset: -30, child: SizedBox(width: 10, height: 10)));
      expect(find.byType(KkFocusRing), paintsNothing);
    });
  });

  group('KkText', () {
    Text inner(WidgetTester tester, String data) => tester.widget<Text>(find.text(data));

    testWidgets('cjk: heavy Mincho, one line, no wrapping', (WidgetTester tester) async {
      await pumpKk(tester, const KkText.cjk('電源系統', size: 21));
      final Text t = inner(tester, '電源系統');
      expect(t.style!.fontFamily, 'packages/keikai/Zen Old Mincho');
      expect(t.style!.fontFamilyFallback, <String>['packages/keikai/Noto Serif KR']);
      expect(t.style!.fontWeight, FontWeight.w900);
      expect(t.style!.fontSize, 21);
      expect(t.style!.height, 1.0);
      expect(t.style!.color, _c.ink);
      expect(t.maxLines, 1);
      expect(t.softWrap, isFalse);
      expect(t.overflow, TextOverflow.clip);
      expect(find.byType(KkSqueeze), findsNothing);
    });

    testWidgets('en: condensed capitals with tracking in em', (WidgetTester tester) async {
      await pumpKk(tester, const KkText.en('system status', size: 13, spacing: 0.1));
      final Text t = inner(tester, 'SYSTEM STATUS');
      expect(t.style!.fontFamily, 'packages/keikai/Sofia Sans Extra Condensed');
      expect(t.style!.fontWeight, FontWeight.w700);
      expect(t.style!.letterSpacing, closeTo(1.3, 1e-9));
      await pumpKk(tester, const KkText.en('Mixed Case', upper: false, weight: FontWeight.w600));
      expect(inner(tester, 'Mixed Case').style!.fontWeight, FontWeight.w600);
    });

    testWidgets('num: tabular mono', (WidgetTester tester) async {
      await pumpKk(tester, const KkText.num('042.7', size: 32, weight: FontWeight.w500, spacing: -0.01));
      final Text t = inner(tester, '042.7');
      expect(t.style!.fontFamily, 'packages/keikai/IBM Plex Mono');
      expect(t.style!.fontFeatures, const <FontFeature>[FontFeature.tabularFigures(), FontFeature.slashedZero()]);
      expect(t.style!.fontWeight, FontWeight.w500);
      expect(t.style!.letterSpacing, closeTo(-0.32, 1e-9));
      // Tabular: every digit string of the same length is the same width.
      final double a = tester.getSize(find.text('042.7')).width;
      await pumpKk(tester, const KkText.num('111.1', size: 32, weight: FontWeight.w500, spacing: -0.01));
      expect(tester.getSize(find.text('111.1')).width, a);
    });

    testWidgets('body: sentences wrap', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(width: 120, child: KkText.body('냉각수 압력이 기준치 아래로 떨어졌습니다.')),
      );
      final Text t = inner(tester, '냉각수 압력이 기준치 아래로 떨어졌습니다.');
      expect(t.style!.fontFamily, 'packages/keikai/IBM Plex Sans KR');
      expect(t.style!.fontSize, 14);
      expect(t.style!.height, 1.55);
      expect(t.maxLines, isNull);
      expect(tester.getSize(find.byType(Text)).height, greaterThan(14 * 1.55 * 1.5));
    });

    testWidgets('raw: the ambient style, optionally merged', (WidgetTester tester) async {
      await pumpKk(tester, const KkText('plain'));
      Text t = inner(tester, 'plain');
      expect(t.style!.fontFamily, 'packages/keikai/IBM Plex Sans KR');
      expect(t.style!.fontSize, 14);
      expect(t.style!.color, _c.ink);
      await pumpKk(tester, const KkText('plain', style: TextStyle(fontSize: 30), color: Color(0xFF00FF00)));
      t = inner(tester, 'plain');
      expect(t.style!.fontSize, 30);
      expect(t.style!.color, const Color(0xFF00FF00));
      expect(t.style!.fontFamily, 'packages/keikai/IBM Plex Sans KR');
    });

    testWidgets('colour: explicit, then style, then the current ink', (WidgetTester tester) async {
      await pumpKk(tester, const KkInk(color: Color(0xFF112233), child: KkText.cjk('甲')));
      expect(inner(tester, '甲').style!.color, const Color(0xFF112233));
      await pumpKk(
        tester,
        const KkInk(
          color: Color(0xFF112233),
          child: KkText.cjk('甲', style: TextStyle(color: Color(0xFF445566))),
        ),
      );
      expect(inner(tester, '甲').style!.color, const Color(0xFF445566));
      await pumpKk(
        tester,
        const KkInk(
          color: Color(0xFF112233),
          child: KkText.cjk('甲', color: Color(0xFF778899), style: TextStyle(color: Color(0xFF445566))),
        ),
      );
      expect(inner(tester, '甲').style!.color, const Color(0xFF778899));
      await pumpKk(tester, const KkText.en('alert'), condition: KkCondition.alert);
      expect(inner(tester, 'ALERT').style!.color, KkColors.alertTheme.ink);
    });

    testWidgets('squeeze compresses a title to 80% of its width', (WidgetTester tester) async {
      await pumpKk(tester, const KkText.cjk('電源系統', size: 20, key: ValueKey<String>('t')));
      final double natural = tester.getSize(find.byKey(const ValueKey<String>('t'))).width;
      expect(natural, closeTo(80, 0.5));
      await pumpKk(tester, const KkText.cjk('電源系統', size: 20, squeeze: 0.8, key: ValueKey<String>('t')));
      expect(tester.getSize(find.byKey(const ValueKey<String>('t'))).width, closeTo(natural * 0.8, 1e-6));
      expect(tester.getSize(find.byKey(const ValueKey<String>('t'))).height, 20);
      expect(find.byType(KkSqueeze), findsOneWidget);
      await pumpKk(tester, const KkText.cjk('電源系統', size: 20, squeeze: 1.0));
      expect(find.byType(KkSqueeze), findsNothing);
    });

    testWidgets('the type scale of the theme multiplies the size', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkText.num('1', size: 12),
        theme: const KeikaiThemeData(type: KkTypography(scale: 1.25)),
      );
      expect(inner(tester, '1').style!.fontSize, 15);
    });

    testWidgets('alignment, lines and overflow pass through', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkText.body('abc', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true),
      );
      final Text t = inner(tester, 'abc');
      expect(t.textAlign, TextAlign.center);
      expect(t.maxLines, 2);
      expect(t.overflow, TextOverflow.ellipsis);
      expect(t.softWrap, isTrue);
    });

    testWidgets('a long single-line label is clipped by its box, not wrapped', (WidgetTester tester) async {
      await pumpKk(tester, const SizedBox(width: 40, child: KkText.en('auxiliary power online', size: 20)));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Text)).height, 20);
    });
  });

  group('KkLabel', () {
    testWidgets('a CJK title and its Latin subtitle on one baseline', (WidgetTester tester) async {
      await pumpKk(tester, const KkLabel(cjk: '電源系統', en: 'power'));
      final Text cjk = tester.widget<Text>(find.text('電源系統'));
      final Text en = tester.widget<Text>(find.text('POWER'));
      expect(cjk.style!.fontSize, 14);
      expect(cjk.style!.color, _c.ink);
      expect(en.style!.fontSize, 11);
      expect(en.style!.fontWeight, FontWeight.w600);
      expect(en.style!.color, _c.inkDim);
      expect(en.style!.letterSpacing, closeTo(1.54, 1e-9));
      // Compressed title, 8px gap.
      final Rect a = tester.getRect(find.byType(KkSqueeze));
      final Rect b = tester.getRect(find.text('POWER'));
      expect(tester.widget<KkSqueeze>(find.byType(KkSqueeze)).scaleX, 0.8);
      expect(b.left - a.right, closeTo(8, 1e-6));
      // Shared baseline: the small Latin text starts lower than the title, and
      // both baselines are on the same line.
      expect(b.top, greaterThan(a.top));
      final RenderBox cjkBox = tester.renderObject<RenderBox>(find.text('電源系統'));
      final RenderBox enBox = tester.renderObject<RenderBox>(find.text('POWER'));
      expect(
        a.top + cjkBox.getDryBaseline(cjkBox.constraints, TextBaseline.alphabetic)!,
        closeTo(b.top + enBox.getDryBaseline(enBox.constraints, TextBaseline.alphabetic)!, 0.01),
      );
      // It takes only the width it needs.
      expect(tester.getSize(find.byType(KkLabel)).width, closeTo(b.right, 1e-6));
    });

    testWidgets('either part alone; empty parts are dropped', (WidgetTester tester) async {
      await pumpKk(tester, const KkLabel(cjk: '冷却'));
      expect(find.byType(Text), findsOneWidget);
      await pumpKk(tester, const KkLabel(en: 'coolant'));
      expect(find.text('COOLANT'), findsOneWidget);
      expect(find.byType(KkSqueeze), findsNothing);
      await pumpKk(tester, const KkLabel(cjk: '', en: ''));
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(KkLabel)).width, 0);
    });

    testWidgets('sizes, colours, gap and squeeze are configurable', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkLabel(
          cjk: '通信',
          en: 'comms',
          cjkSize: 21,
          enSize: 13,
          enWeight: FontWeight.w700,
          enSpacing: 0.1,
          cjkColor: Color(0xFF010101),
          enColor: Color(0xFF020202),
          gap: 20,
          squeeze: 1.0,
        ),
      );
      expect(tester.widget<Text>(find.text('通信')).style!.color, const Color(0xFF010101));
      expect(tester.widget<Text>(find.text('COMMS')).style!.color, const Color(0xFF020202));
      expect(tester.widget<Text>(find.text('COMMS')).style!.fontWeight, FontWeight.w700);
      expect(find.byType(KkSqueeze), findsNothing);
      expect(
        tester.getRect(find.text('COMMS')).left - tester.getRect(find.text('通信')).right,
        closeTo(20, 1e-6),
      );
    });
  });

  group('KkSqueeze', () {
    testWidgets('takes the compressed width and keeps the height', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkSqueeze(key: ValueKey<String>('s'), child: SizedBox(key: ValueKey<String>('c'), width: 100, height: 20)),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('s'))), const Size(80, 20));
      final RenderBox child = tester.renderObject<RenderBox>(find.byKey(const ValueKey<String>('c')));
      expect(child.size, const Size(100, 20));
      // Painted through the scale: the child's far corner lands on the box's.
      expect(child.localToGlobal(const Offset(100, 20)), const Offset(80, 20));
    });

    testWidgets('a forced width is divided by the scale for the child', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(
          width: 80,
          child: KkSqueeze(child: SizedBox(key: ValueKey<String>('c'), height: 20)),
        ),
      );
      final RenderBox child = tester.renderObject<RenderBox>(find.byKey(const ValueKey<String>('c')));
      expect(child.size.width, closeTo(100, 1e-9));
    });

    testWidgets('taps land on the right part of the child', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkSqueeze(
          scaleX: 0.5,
          child: KkRow(
            shrinkWrap: true,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => log.add('left'),
                child: const SizedBox(width: 100, height: 40),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => log.add('right'),
                child: const SizedBox(width: 100, height: 40),
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(40, 20));
      await tester.tapAt(const Offset(60, 20));
      await tester.tapAt(const Offset(120, 20));
      expect(log, <String>['left', 'right']);
    });

    testWidgets('intrinsics, dry layout, no child, scale change', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkSqueeze(key: ValueKey<String>('s'), scaleX: 0.5, child: SizedBox(width: 100, height: 20)),
      );
      final RenderKkSqueeze r = tester.renderObject<RenderKkSqueeze>(find.byKey(const ValueKey<String>('s')));
      expect(r.getMaxIntrinsicWidth(double.infinity), 50);
      expect(r.getMinIntrinsicWidth(double.infinity), 50);
      expect(r.getMaxIntrinsicHeight(50), 20);
      expect(r.getMinIntrinsicHeight(50), 20);
      expect(r.getDryLayout(r.constraints), r.size);
      await pumpKk(
        tester,
        const KkSqueeze(key: ValueKey<String>('s'), scaleX: 0.9, child: SizedBox(width: 100, height: 20)),
      );
      expect(r.size.width, 90);
      await pumpKk(tester, const KkSqueeze(key: ValueKey<String>('s')));
      expect(tester.getSize(find.byKey(const ValueKey<String>('s'))), Size.zero);
      expect(tester.takeException(), isNull);
    });
  });

  group('KkTate', () {
    testWidgets('stacks the characters upright in one column', (WidgetTester tester) async {
      await pumpKk(tester, const KkTate('設計言語', size: 22));
      final Size s = tester.getSize(find.byType(KkTate));
      expect(s.height, closeTo(88, 1e-6));
      expect(s.width, closeTo(22, 0.5));
    });

    testWidgets('spacing is in em; the column can be made wider', (WidgetTester tester) async {
      await pumpKk(tester, const KkTate('電源系統', size: 14, spacing: 0.12, columnWidth: 24));
      final Size s = tester.getSize(find.byType(KkTate));
      expect(s.width, 24);
      expect(s.height, closeTo(4 * 14 * 1.12, 1e-6));
    });

    testWidgets('is read as one word; clipped when it does not fit; follows text changes', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const SizedBox(height: 30, child: KkTate('電源系統', size: 20)));
      expect(find.bySemanticsLabel('電源系統'), findsOneWidget);
      expect(tester.getSize(find.byType(KkTate)).height, 30);
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkTate('冷却', size: 20));
      expect(tester.getSize(find.byType(KkTate)).height, closeTo(40, 1e-6));
      await pumpKk(tester, const KkTate('', size: 20));
      expect(tester.getSize(find.byType(KkTate)).height, 0);
      // A grapheme cluster is one cell.
      await pumpKk(tester, const KkTate('가́나', size: 20));
      expect(tester.getSize(find.byType(KkTate)).height, closeTo(40, 1e-6));
      handle.dispose();
    });

    testWidgets('takes the current ink and the theme scale', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkInk(color: Color(0xFF123456), child: KkTate('警戒', size: 20)),
        theme: const KeikaiThemeData(type: KkTypography(scale: 1.5)),
      );
      final RenderKkTate r = tester.renderObject<RenderKkTate>(
        find.descendant(of: find.byType(KkTate), matching: find.byWidgetPredicate((Widget w) => w is LeafRenderObjectWidget)),
      );
      expect(r.style.color, const Color(0xFF123456));
      expect(r.style.fontSize, 30);
      expect(r.size.height, closeTo(60, 1e-6));
      expect(r.getMaxIntrinsicHeight(double.infinity), closeTo(60, 1e-6));
      expect(r.getDryLayout(r.constraints), r.size);
    });
  });

  group('KkIcon and KkGlyph', () {
    testWidgets('an icon is a 16px square in the current ink', (WidgetTester tester) async {
      await pumpKk(tester, const KkIcon(KkIcons.search));
      expect(tester.getSize(find.byType(KkIcon)), const Size(16, 16));
      final RenderKkIcon r = _icon(tester, KkIcon);
      expect(r.color, _c.ink);
      expect(r.icon, KkIcons.search);
      await pumpKk(tester, const KkInk(color: Color(0xFF00FF00), child: KkIcon(KkIcons.search, size: 24)));
      expect(tester.getSize(find.byType(KkIcon)), const Size(24, 24));
      expect(_icon(tester, KkIcon).color, const Color(0xFF00FF00));
      await pumpKk(tester, const KkIcon(KkIcons.close, color: Color(0xFF0000FF)));
      expect(_icon(tester, KkIcon).color, const Color(0xFF0000FF));
    });

    testWidgets('an icon is decorative unless it has a label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkIcon(KkIcons.trash));
      expect(find.bySemanticsLabel('Delete'), findsNothing);
      await pumpKk(tester, const KkIcon(KkIcons.trash, semanticLabel: 'Delete'));
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an icon squeezed into a smaller or uneven box still paints', (WidgetTester tester) async {
      await pumpKk(tester, const SizedBox(width: 8, height: 30, child: KkIcon(KkIcons.settings)));
      expect(tester.getSize(find.byType(KkIcon)), const Size(8, 30));
      expect(tester.takeException(), isNull);
      final RenderKkIcon r = _icon(tester, KkIcon);
      expect(r.getMaxIntrinsicWidth(double.infinity), 16);
      expect(r.getMinIntrinsicHeight(double.infinity), 16);
      expect(r.getDryLayout(const BoxConstraints()), const Size(16, 16));
    });

    testWidgets('a glyph shows the status icon of its level in the level colour', (WidgetTester tester) async {
      for (final KkLevel level in KkLevel.values) {
        await pumpKk(tester, KkGlyph(level: level));
        final RenderKkIcon r = _icon(tester, KkGlyph);
        expect(r.icon, kkStatusIcon(level));
        expect(r.color, _c.level(level));
        expect(tester.getSize(find.byType(KkGlyph)), const Size(12, 12));
      }
    });

    testWidgets('a glyph without a level is the info plate in the current ink', (WidgetTester tester) async {
      await pumpKk(tester, const KkInk(color: Color(0xFF00FF00), child: KkGlyph(size: 10)));
      final RenderKkIcon r = _icon(tester, KkGlyph);
      expect(r.icon, KkIcons.statusInfo);
      expect(r.color, const Color(0xFF00FF00));
      expect(r.size, const Size(10, 10));
      await pumpKk(tester, const KkGlyph(level: KkLevel.critical, color: Color(0xFF0000FF)));
      expect(_icon(tester, KkGlyph).color, const Color(0xFF0000FF));
    });
  });

  group('KkClock', () {
    testWidgets('shows UTC time with a Z', (WidgetTester tester) async {
      final DateTime fixed = DateTime.utc(2026, 11, 24, 14, 2, 31);
      await pumpKk(tester, KkClock(clock: () => fixed));
      expect(find.text('14:02:31Z', findRichText: true), findsOneWidget);
      await pumpKk(tester, KkClock(clock: () => fixed, seconds: false));
      expect(find.text('14:02Z', findRichText: true), findsOneWidget);
      await pumpKk(tester, KkClock(clock: () => fixed, suffix: ' UTC'));
      expect(find.text('14:02:31 UTC', findRichText: true), findsOneWidget);
      await pumpKk(tester, KkClock(clock: () => fixed, suffix: ''));
      expect(find.text('14:02:31', findRichText: true), findsOneWidget);
      // Zero-padded.
      await pumpKk(tester, KkClock(clock: () => DateTime.utc(2026, 1, 2, 3, 4, 5)));
      expect(find.text('03:04:05Z', findRichText: true), findsOneWidget);
    });

    testWidgets('converts a local time to UTC, or shows local time without a suffix', (WidgetTester tester) async {
      final DateTime local = DateTime(2026, 11, 24, 9, 30, 15);
      await pumpKk(tester, KkClock(clock: () => local));
      final DateTime utc = local.toUtc();
      expect(find.text('${kkFormatTime(utc)}Z', findRichText: true), findsOneWidget);
      await pumpKk(tester, KkClock(clock: () => local, utc: false));
      expect(find.text('09:30:15', findRichText: true), findsOneWidget);
    });

    testWidgets('ticks every second and leaves no timer behind', (WidgetTester tester) async {
      final DateTime start = DateTime.utc(2026, 11, 24, 23, 59, 58);
      final DateTime zero = tester.binding.clock.now();
      await pumpKk(tester, KkClock(clock: () => start.add(tester.binding.clock.now().difference(zero))));
      expect(find.text('23:59:58Z', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('23:59:59Z', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00:00Z', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('00:00:00Z', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('00:00:01Z', findRichText: true), findsOneWidget);
      // Removing the clock cancels its timer (the test binding checks).
      await pumpKk(tester, const SizedBox.shrink());
    });

    testWidgets('lines its ticks up with whole seconds', (WidgetTester tester) async {
      final DateTime start = DateTime.utc(2026, 11, 24, 12, 0, 0, 700);
      final DateTime zero = tester.binding.clock.now();
      await pumpKk(tester, KkClock(clock: () => start.add(tester.binding.clock.now().difference(zero))));
      expect(find.text('12:00:00Z', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('12:00:01Z', findRichText: true), findsOneWidget);
    });

    testWidgets('the colons blink once a second when motion is on', (WidgetTester tester) async {
      final DateTime fixed = DateTime.utc(2026, 11, 24, 14, 2, 31);
      Color colon() {
        final TextSpan c = _clockSpan(tester).children!.whereType<TextSpan>().firstWhere((TextSpan s) => s.text == ':');
        return c.style!.color!;
      }

      await pumpKk(tester, KkClock(clock: () => fixed), motion: true);
      final Set<double> alphas = <double>{};
      for (int i = 0; i < 110; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final double a = colon().a;
        expect(a, closeTo(kkPhaseAt(kkFrameTime(), KkMotion.colon) == 0 ? 1.0 : 0.2, 1e-6));
        alphas.add(double.parse(a.toStringAsFixed(2)));
      }
      expect(alphas, <double>{1.0, 0.2});
      // With blink off, or motion off, the colons are steady.
      await pumpKk(tester, KkClock(clock: () => fixed, blink: false), motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(colon().a, 1);
      await pumpKk(tester, KkClock(clock: () => fixed));
      await tester.pump(const Duration(milliseconds: 600));
      expect(colon().a, 1);
    });

    testWidgets('style and colour', (WidgetTester tester) async {
      final DateTime fixed = DateTime.utc(2026, 11, 24, 14, 2, 31);
      await pumpKk(tester, KkClock(clock: () => fixed));
      TextSpan root = _clockSpan(tester);
      expect(root.style!.fontFamily, 'packages/keikai/IBM Plex Mono');
      expect(root.style!.fontSize, 15);
      expect(root.style!.fontWeight, FontWeight.w500);
      expect(root.style!.color, _c.ink);
      await pumpKk(
        tester,
        KkClock(clock: () => fixed, color: const Color(0xFF00FF00), style: const TextStyle(fontSize: 22)),
      );
      root = _clockSpan(tester);
      expect(root.style!.fontSize, 22);
      expect(root.style!.color, const Color(0xFF00FF00));
    });

    testWidgets('is read as the plain time', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkClock(clock: () => DateTime.utc(2026, 11, 24, 14, 2, 31)));
      expect(find.bySemanticsLabel('14:02:31Z'), findsOneWidget);
      handle.dispose();
    });

    test('formatters', () {
      expect(kkFormatTime(DateTime(2026, 1, 2, 3, 4, 5)), '03:04:05');
      expect(kkFormatTime(DateTime(2026, 1, 2, 23, 59, 0), seconds: false), '23:59');
      expect(kkFormatDate(DateTime(2026, 1, 2)), '2026-01-02');
      expect(kkFormatDate(DateTime(2026, 11, 24)), '2026-11-24');
    });
  });

  group('frames', () {
    testWidgets('KkWidgetHead: title, subtitle, meta, trailing, with a line under it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(
          width: 320,
          child: KkWidgetHead(
            cjk: '接続状態',
            en: 'link state',
            meta: '12 / 16',
            trailing: SizedBox(key: ValueKey<String>('tail'), width: 20, height: 10),
          ),
        ),
      );
      expect(find.text('接続状態'), findsOneWidget);
      expect(find.text('LINK STATE'), findsOneWidget);
      // 8px padding above and below the baseline-aligned row, plus the 1px line.
      // The title is 14px at line-height 1.55 (the engine rounds it to 22).
      final Rect title = tester.getRect(find.byType(KkSqueeze));
      final Rect sub = tester.getRect(find.text('LINK STATE'));
      expect(title.height, closeTo(14 * 1.55, 0.5));
      expect(sub.height, closeTo(11 * 1.55, 0.5));
      final double rowTop = title.top < sub.top ? title.top : sub.top;
      final double rowBottom = title.bottom > sub.bottom ? title.bottom : sub.bottom;
      expect(rowTop, 8);
      final double headHeight = tester.getSize(find.byType(KkWidgetHead)).height;
      expect(headHeight, closeTo(rowBottom + 8 + 1, 1e-6));
      expect(headHeight, inInclusiveRange(38, 40));
      expect(tester.getSize(find.byType(KkWidgetHead)).width, 320);
      // Meta and trailing are pushed to the right edge, inside the 12px padding.
      expect(tester.getRect(find.byKey(const ValueKey<String>('tail'))).right, closeTo(308, 1e-6));
      expect(tester.getRect(find.text('12 / 16')).right, closeTo(308 - 20 - 8, 1e-6));
      expect(tester.getRect(find.byType(KkSqueeze)).left, 12);
      final Text meta = tester.widget<Text>(find.text('12 / 16'));
      expect(meta.style!.fontFamily, 'packages/keikai/IBM Plex Mono');
      expect(meta.style!.color, _c.ink);
      expect(tester.widget<Text>(find.text('LINK STATE')).style!.color, _c.inkDim);
      expect(
        find.byType(KkWidgetHead),
        paints..rect(rect: Rect.fromLTWH(0, headHeight - 1, 320, 1), color: _c.line),
      );
    });

    testWidgets('KkWidgetHead without the divider, and with a title too long for it', (WidgetTester tester) async {
      await pumpKk(tester, const SizedBox(width: 320, child: KkWidgetHead(cjk: '冷却', divider: false)));
      expect(tester.getSize(find.byType(KkWidgetHead)).height, closeTo(8 + 14 * 1.55 + 8, 0.5));
      await pumpKk(
        tester,
        const SizedBox(
          width: 60,
          child: KkWidgetHead(cjk: '非常用電源系統切替', en: 'auxiliary power changeover', meta: '14:02:31Z'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkWidgetHead)).width, 60);
    });

    testWidgets('KkWidgetFoot wraps its keys in dim mono', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(
          width: 200,
          child: KkWidgetFoot(
            children: <Widget>[
              KkWidgetKey(label: 'PRIMARY', color: Color(0xFFE8660F)),
              KkWidgetKey(label: 'BACKUP', color: Color(0xFF2F9BE0), box: true, value: '42'),
              KkWidgetKey(label: 'A LONGER THIRD KEY'),
              Text('note'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final Rect first = tester.getRect(find.byType(KkWidgetKey).at(0));
      final Rect third = tester.getRect(find.byType(KkWidgetKey).at(2));
      expect(first.left, 12);
      expect(third.top, greaterThan(first.top), reason: 'the third key wraps to a new line');
      final Text note = tester.widget<Text>(find.text('note'));
      expect(note.style, isNull);
      final DefaultTextStyle ambient = DefaultTextStyle.of(tester.element(find.text('note')));
      expect(ambient.style.fontFamily, 'packages/keikai/IBM Plex Mono');
      expect(ambient.style.color, _c.inkDim);
      expect(
        find.byType(KkWidgetFoot),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 200, 1), color: _c.line),
      );
    });

    testWidgets('KkWidgetKey: a 12×3 line or a 10×10 box, a label and a value', (WidgetTester tester) async {
      await pumpKk(tester, const KkWidgetKey(label: 'PRIMARY', color: Color(0xFFE8660F)));
      final Finder swatch = find.descendant(of: find.byType(KkWidgetKey), matching: find.byType(KkBox));
      expect(tester.getSize(swatch), const Size(12, 3));
      expect(tester.getRect(find.text('PRIMARY')).left - tester.getRect(swatch).right, 6);
      await pumpKk(tester, const KkWidgetKey(label: 'BACKUP', color: Color(0xFF2F9BE0), box: true, value: '42'));
      expect(tester.getSize(find.descendant(of: find.byType(KkWidgetKey), matching: find.byType(KkBox))), const Size(10, 10));
      expect(tester.widget<Text>(find.text('42')).style!.color, _c.ink);
      expect(tester.widget<Text>(find.text('BACKUP')).style!.color, _c.inkDim);
      await pumpKk(
        tester,
        const KkWidgetKey(label: 'CUSTOM', swatch: SizedBox(key: ValueKey<String>('sw'), width: 5, height: 5)),
      );
      expect(find.byKey(const ValueKey<String>('sw')), findsOneWidget);
      await pumpKk(tester, const KkWidgetKey(label: 'BARE'));
      expect(find.descendant(of: find.byType(KkWidgetKey), matching: find.byType(KkBox)), findsNothing);
    });

    KkDecoration frameDecoration(WidgetTester tester) => tester
        .widget<KkBox>(find.descendant(of: find.byType(KkWidgetFrame), matching: find.byType(KkBox)).first)
        .decoration!;

    testWidgets('KkWidgetFrame: panel fill, 1px line, head, body, foot', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(
          width: 300,
          child: KkWidgetFrame(
            cjk: '通信回線',
            en: 'comms',
            footer: <Widget>[KkWidgetKey(label: 'UP', color: Color(0xFF5CFF9D))],
            child: SizedBox(key: ValueKey<String>('body'), height: 50),
          ),
        ),
      );
      final KkDecoration d = frameDecoration(tester);
      expect(d.fill, _c.bg100);
      expect(d.edges, KkEdges.line(_c.line));
      expect(d.glow, isNull);
      final Rect frame = tester.getRect(find.byType(KkWidgetFrame));
      final Rect body = tester.getRect(find.byKey(const ValueKey<String>('body')));
      expect(frame.width, 300);
      expect(body.left, 1);
      expect(body.width, 298);
      expect(body.top, closeTo(tester.getRect(find.byType(KkWidgetHead)).bottom, 1e-6));
      expect(tester.getRect(find.byType(KkWidgetHead)).top, 1);
      expect(tester.getRect(find.byType(KkWidgetFoot)).top, closeTo(body.bottom, 1e-6));
      expect(frame.bottom, closeTo(tester.getRect(find.byType(KkWidgetFoot)).bottom + 1, 1e-6));
    });

    testWidgets('KkWidgetFrame levels: critical glows red, offline is dashed', (WidgetTester tester) async {
      const Widget body = SizedBox(height: 20);
      await pumpKk(tester, const SizedBox(width: 200, child: KkWidgetFrame(level: KkLevel.critical, child: body)));
      KkDecoration d = frameDecoration(tester);
      expect(d.edges, KkEdges.line(_c.alert));
      expect(d.glow, _c.glowAlert);
      await pumpKk(tester, const SizedBox(width: 200, child: KkWidgetFrame(level: KkLevel.offline, child: body)));
      d = frameDecoration(tester);
      expect(d.edges, KkEdges.line(_c.offline, dashed: true));
      expect(d.glow, isNull);
      for (final KkLevel level in <KkLevel>[KkLevel.nominal, KkLevel.caution]) {
        await pumpKk(tester, SizedBox(width: 200, child: KkWidgetFrame(level: level, child: body)));
        expect(frameDecoration(tester).edges, KkEdges.line(_c.line));
      }
      await pumpKk(
        tester,
        const SizedBox(
          width: 200,
          child: KkWidgetFrame(border: false, fill: Color(0xFF010203), child: body),
        ),
      );
      d = frameDecoration(tester);
      expect(d.edges, KkEdges.none);
      expect(d.fill, const Color(0xFF010203));
      // No head and no foot: the body is the whole frame.
      expect(find.byType(KkWidgetHead), findsNothing);
      expect(find.byType(KkWidgetFoot), findsNothing);
      expect(tester.getSize(find.byType(KkWidgetFrame)).height, 20);
    });

    testWidgets('KkWidgetFrame expandBody fills a fixed height', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: KkWidgetFrame(
            cjk: '波形',
            expandBody: true,
            footer: <Widget>[KkWidgetKey(label: 'CH.12')],
            child: SizedBox(key: ValueKey<String>('body')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkWidgetFrame)), const Size(300, 200));
      final Rect body = tester.getRect(find.byKey(const ValueKey<String>('body')));
      final Rect foot = tester.getRect(find.byType(KkWidgetFoot));
      expect(body.bottom, closeTo(foot.top, 1e-6));
      expect(foot.bottom, 199);
      expect(body.height, greaterThan(100));
    });

    testWidgets('KkWidgetFrame boots in when motion is on, and can skip it', (WidgetTester tester) async {
      await pumpKk(tester, const KkWidgetFrame(child: SizedBox(width: 50, height: 20)), motion: true);
      expect(find.descendant(of: find.byType(KkWidgetFrame), matching: find.byType(KkBoot)), findsOneWidget);
      await pumpKk(tester, const KkWidgetFrame(boot: false, child: SizedBox(width: 50, height: 20)), motion: true);
      expect(find.descendant(of: find.byType(KkWidgetFrame), matching: find.byType(KkBoot)), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('KkBrackets: four L-shaped corners, 12 by 2, 1px outside', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBrackets(child: SizedBox(width: 100, height: 60)),
        padding: const EdgeInsets.all(10),
      );
      expect(tester.getSize(find.byType(KkBrackets)), const Size(100, 60));
      final KkDecoration d = tester
          .widget<KkBox>(find.descendant(of: find.byType(KkBrackets), matching: find.byType(KkBox)))
          .decoration!;
      expect(d.brackets, KkBracketSpec(color: _c.signal, length: 12, width: 2, outset: 1));
      expect(find.byType(KkBrackets), paints..path(color: _c.signal));
      await pumpKk(tester, const KkBrackets(level: KkLevel.critical, length: 8, width: 3, outset: 5, child: SizedBox(width: 10, height: 10)));
      expect(
        tester.widget<KkBox>(find.descendant(of: find.byType(KkBrackets), matching: find.byType(KkBox))).decoration!.brackets,
        KkBracketSpec(color: _c.alert, length: 8, width: 3, outset: 5),
      );
      await pumpKk(tester, const KkBrackets(color: Color(0xFF00FF00), child: SizedBox(width: 10, height: 10)));
      expect(find.byType(KkBrackets), paints..path(color: const Color(0xFF00FF00)));
      await pumpKk(tester, const KkBrackets(visible: false, child: SizedBox(width: 10, height: 10)));
      expect(find.byType(KkBrackets), paintsNothing);
      expect(tester.getSize(find.byType(KkBrackets)), const Size(10, 10));
    });

    testWidgets('KkBackdrop grounds', (WidgetTester tester) async {
      KkDecoration deco() => tester
          .widget<KkBox>(find.descendant(of: find.byType(KkBackdrop), matching: find.byType(KkBox)).first)
          .decoration!;
      const Widget child = SizedBox(width: 96, height: 96);
      await pumpKk(tester, const KkBackdrop(child: child));
      expect(deco().fill, _c.bg000);
      expect(deco().pattern, KkPattern.grid(color: _c.grid, pitch: 24));
      expect(deco().overlay, isNull);
      await pumpKk(tester, const KkBackdrop(kind: KkBackdropKind.fineGrid, child: child));
      expect(deco().pattern, KkPattern.grid(color: _c.grid, pitch: 8));
      await pumpKk(tester, const KkBackdrop(kind: KkBackdropKind.plot, child: child));
      expect(deco().pattern, KkPattern.plot(minor: _c.grid, major: _c.signalDim, pitch: 8));
      await pumpKk(tester, const KkBackdrop(kind: KkBackdropKind.hex, level: KkLevel.critical, child: child));
      expect(deco().pattern, KkPattern.hex(color: _c.alert, pitch: 24));
      expect((deco().pattern! as KkHexPattern).opacity, lessThanOrEqualTo(0.2));
      await pumpKk(tester, const KkBackdrop(kind: KkBackdropKind.hex, child: child));
      expect(deco().pattern, KkPattern.hex(color: _c.signal, pitch: 24));
      await pumpKk(tester, const KkBackdrop(kind: KkBackdropKind.none, fill: Color(0xFF010203), scanlines: true, child: child));
      expect(deco().pattern, isNull);
      expect(deco().fill, const Color(0xFF010203));
      expect(deco().overlay, KkPattern.scanlines(color: kkFade(_c.bg000, 0.5)));
      await pumpKk(tester, const KkBackdrop(child: child), condition: KkCondition.alert);
      expect(deco().fill, KkColors.alertTheme.bg000);
      expect(deco().pattern, KkPattern.grid(color: KkColors.alertTheme.grid, pitch: 24));
      // Padding and alignment place the child.
      await pumpKk(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: KkBackdrop(padding: EdgeInsets.all(10), alignment: Alignment.bottomRight, child: SizedBox(key: ValueKey<String>('c'), width: 20, height: 20)),
        ),
      );
      expect(tester.getRect(find.byKey(const ValueKey<String>('c'))), const Rect.fromLTWH(270, 170, 20, 20));
      // No child: fills what it is given.
      await pumpKk(tester, const SizedBox(width: 50, height: 40, child: KkBackdrop()));
      expect(tester.getSize(find.byType(KkBackdrop)), const Size(50, 40));
    });
  });
}
