import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const Key _target = ValueKey<String>('target');

Widget _tip({
  KkPopupSide side = KkPopupSide.above,
  bool? open,
  bool enabled = true,
  String message = 'ACKNOWLEDGE',
  Duration waitDuration = const Duration(milliseconds: 400),
}) {
  return KkTooltip(
    message: message,
    side: side,
    open: open,
    enabled: enabled,
    waitDuration: waitDuration,
    child: const KkBox(key: _target, width: 40, height: 40),
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(790, 590));
  addTearDown(mouse.removePointer);
  return mouse;
}

/// Moves the pointer onto the target and waits out the 400ms delay.
Future<void> _rest(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(tester.getCenter(find.byKey(_target)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder get _tipBox => find.byType(KkPopupLayout);

/// The rectangle of the tip itself (the one child of the popup layout).
Rect _tipRect(WidgetTester tester) => tester.renderObject<RenderKkPopupLayout>(_tipBox).childRect;

void main() {
  setUpAll(loadKkFonts);
  setUp(KkInputModality.notePointer);

  group('KkTooltip', () {
    testWidgets('shows after the pointer has rested 400ms and goes when it leaves', (WidgetTester tester) async {
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      expect(_tipBox, findsNothing);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump();
      expect(_tipBox, findsNothing);
      await tester.pump(const Duration(milliseconds: 399));
      expect(_tipBox, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_tipBox, findsOneWidget);
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      // It snapped in: nothing is animating and no frame is wanted.
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Moving inside the target changes nothing.
      await mouse.moveBy(const Offset(5, 5));
      await tester.pump(const Duration(seconds: 2));
      expect(_tipBox, findsOneWidget);
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(Duration.zero);
      expect(_tipBox, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a pointer that leaves before the wait is over shows nothing', (WidgetTester tester) async {
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(const Duration(milliseconds: 300));
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsNothing);
      // Coming back starts the wait again from zero.
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(const Duration(milliseconds: 399));
      expect(_tipBox, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_tipBox, findsOneWidget);
    });

    testWidgets('waitDuration is the delay; zero shows on the next frame', (WidgetTester tester) async {
      await pumpKk(tester, _tip(waitDuration: Duration.zero), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(Duration.zero);
      expect(_tipBox, findsOneWidget);
    });

    testWidgets('looks: ink ground, ground-coloured mono text, 8px above, centred, with a stem', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      final Rect target = tester.getRect(find.byKey(_target));
      final Rect tip = _tipRect(tester);
      expect(tip.bottom, target.top - 8);
      expect(tip.center.dx, closeTo(target.center.dx, 0.5));
      final Text text = tester.widget<Text>(find.text('ACKNOWLEDGE'));
      expect(text.style!.color, KkColors.standby.bg000);
      expect(text.style!.fontSize, 11);
      expect(text.style!.fontFamily, contains('IBM Plex Mono'));
      // One line of 11px at 1.35 plus 4px above and below; 8px at each side.
      expect(tester.getSize(find.text('ACKNOWLEDGE')).height, closeTo(11 * 1.35, 0.5));
      expect(tip.height, tester.getSize(find.text('ACKNOWLEDGE')).height + 8);
      expect(tip.width, closeTo(tester.getSize(find.text('ACKNOWLEDGE')).width + 16, 0.01));
      final KkBox box = tester.widget<KkBox>(
        find.ancestor(of: find.text('ACKNOWLEDGE'), matching: find.byType(KkBox)).first,
      );
      expect(box.fill, KkColors.standby.ink);
      final RenderKkPopupLayout layout = tester.renderObject<RenderKkPopupLayout>(_tipBox);
      expect(layout.stem, KkColors.standby.ink);
      expect(layout.resolvedSide, KkPopupSide.above);
      // The pointer goes through it to whatever is underneath.
      final HitTestResult result = tester.hitTestOnBinding(tip.center);
      expect(result.path.any((HitTestEntry<HitTestTarget> e) => e.target is RenderKkPopupLayout), isFalse);
    });

    testWidgets('flips to the other side when there is no room, and stays on the screen', (WidgetTester tester) async {
      // At the top left: no room above, and centring would leave the screen.
      await pumpKk(tester, _tip(message: 'A LONGER NOTE FOR THIS TARGET'), padding: const EdgeInsets.all(6));
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      Rect target = tester.getRect(find.byKey(_target));
      Rect tip = _tipRect(tester);
      expect(tester.renderObject<RenderKkPopupLayout>(_tipBox).resolvedSide, KkPopupSide.below);
      expect(tip.top, target.bottom + 8);
      expect(tip.left, 4);

      // At the bottom: a tooltip asked below opens above.
      await mouse.moveTo(const Offset(790, 300));
      await tester.pump(Duration.zero);
      await pumpKk(
        tester,
        _tip(side: KkPopupSide.below),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.all(6),
      );
      await _rest(tester, mouse);
      target = tester.getRect(find.byKey(_target));
      tip = _tipRect(tester);
      expect(tester.renderObject<RenderKkPopupLayout>(_tipBox).resolvedSide, KkPopupSide.above);
      expect(tip.bottom, target.top - 8);
    });

    testWidgets('left and right: beside the target, centred on it, flipping at the edge', (WidgetTester tester) async {
      await pumpKk(tester, _tip(side: KkPopupSide.right), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      Rect target = tester.getRect(find.byKey(_target));
      Rect tip = _tipRect(tester);
      expect(tip.left, target.right + 8);
      expect(tip.center.dy, closeTo(target.center.dy, 0.5));

      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(Duration.zero);
      await pumpKk(tester, _tip(side: KkPopupSide.left), alignment: Alignment.center);
      await _rest(tester, mouse);
      target = tester.getRect(find.byKey(_target));
      tip = _tipRect(tester);
      // The tip sits on whole pixels and its width is that of its text, so
      // its far edge can be half a pixel off.
      expect(tip.right, closeTo(target.left - 8, 0.51));
      expect(tip.left, tip.left.roundToDouble());

      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(Duration.zero);
      await pumpKk(
        tester,
        _tip(side: KkPopupSide.left),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(6),
      );
      await _rest(tester, mouse);
      target = tester.getRect(find.byKey(_target));
      tip = _tipRect(tester);
      expect(tester.renderObject<RenderKkPopupLayout>(_tipBox).resolvedSide, KkPopupSide.right);
      expect(tip.left, target.right + 8);
    });

    testWidgets('keyboard focus shows it at once; Escape and leaving hide it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          gap: 24,
          children: <Widget>[
            KkTooltip(
              message: 'ACKNOWLEDGE',
              child: KkIconButton(icon: KkIcons.check, onPressed: () {}, semanticLabel: 'Acknowledge'),
            ),
            KkIconButton(icon: KkIcons.close, onPressed: () {}, semanticLabel: 'Close'),
          ],
        ),
        alignment: Alignment.center,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump();
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('ACKNOWLEDGE'), findsNothing);
      // Tab away and back: it shows again, and goes when the focus moves on.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      expect(find.text('ACKNOWLEDGE'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.pump();
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      expect(find.text('ACKNOWLEDGE'), findsNothing);
    });

    testWidgets('focus that follows a click does not show it', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        KkTooltip(
          message: 'ACKNOWLEDGE',
          child: KkIconButton(icon: KkIcons.check, onPressed: () {}, focusNode: focus, semanticLabel: 'Acknowledge'),
        ),
        alignment: Alignment.center,
      );
      await tester.tap(find.byType(KkIconButton));
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(focus.hasFocus, isTrue);
      expect(find.text('ACKNOWLEDGE'), findsNothing);
    });

    testWidgets('a press hides it until the pointer comes back', (WidgetTester tester) async {
      int pressed = 0;
      await pumpKk(
        tester,
        KkTooltip(
          message: 'ACKNOWLEDGE',
          child: KkIconButton(key: _target, icon: KkIcons.check, onPressed: () => pressed++, semanticLabel: 'Ack'),
        ),
        alignment: Alignment.center,
      );
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      await mouse.down(tester.getCenter(find.byKey(_target)));
      await tester.pump();
      expect(find.text('ACKNOWLEDGE'), findsNothing);
      await mouse.up();
      await tester.pump(const Duration(seconds: 2));
      expect(pressed, 1);
      expect(find.text('ACKNOWLEDGE'), findsNothing);
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(Duration.zero);
      await _rest(tester, mouse);
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
    });

    testWidgets('the wheel and a scroll of the page hide it', (WidgetTester tester) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: KkColumn(
            cross: KkCrossAlign.start,
            children: <Widget>[const KkBox(height: 200), _tip(), const KkBox(height: 900)],
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      expect(_tipBox, findsOneWidget);
      scroll.jumpTo(30);
      await tester.pump();
      expect(_tipBox, findsNothing);

      // Back onto the target (it moved up by 30).
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(Duration.zero);
      await _rest(tester, mouse);
      expect(_tipBox, findsOneWidget);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: tester.getCenter(find.byKey(_target)), scrollDelta: const Offset(0, 10)),
      );
      await tester.pump();
      expect(_tipBox, findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('touch: a long press shows it for showDuration', (WidgetTester tester) async {
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      final TestGesture finger = await tester.startGesture(tester.getCenter(find.byKey(_target)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_tipBox, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_tipBox, findsOneWidget);
      await finger.up();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(_tipBox, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_tipBox, findsNothing);
      // A plain tap shows nothing.
      await tester.tapAt(tester.getCenter(find.byKey(_target)));
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsNothing);
    });

    testWidgets('open forces it open or shut; enabled: false never shows', (WidgetTester tester) async {
      await pumpKk(tester, _tip(open: true), alignment: Alignment.center);
      // In the very first frame, and in the right place.
      expect(_tipBox, findsOneWidget);
      expect(_tipRect(tester).bottom, tester.getRect(find.byKey(_target)).top - 8);
      // Neither a press nor Escape takes a forced tooltip down.
      await tester.tapAt(const Offset(700, 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsOneWidget);

      await pumpKk(tester, _tip(open: false), alignment: Alignment.center);
      expect(_tipBox, findsNothing);
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      expect(_tipBox, findsNothing);

      // Back to automatic with the pointer still resting on it: nothing until
      // the pointer comes in again.
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsNothing);
      await pumpKk(tester, _tip(open: true), alignment: Alignment.center);
      await tester.pump();
      expect(_tipBox, findsOneWidget);
      await pumpKk(tester, _tip(open: true, enabled: false), alignment: Alignment.center);
      await tester.pump();
      expect(_tipBox, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rich: a 248px card with title, body and action that stays under the pointer', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await pumpKk(
        tester,
        KkTooltip.rich(
          cjk: '冷却系',
          en: 'coolant loop',
          body: 'Loop pressure has been below the limit for 12 minutes.',
          action: KkButton(label: 'open trend', size: KkButtonSize.sm, onPressed: () => opened++),
          side: KkPopupSide.below,
          child: const KkBox(key: _target, width: 40, height: 40),
        ),
        alignment: Alignment.center,
      );
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      final Rect target = tester.getRect(find.byKey(_target));
      final Rect tip = _tipRect(tester);
      expect(tip.width, 248);
      expect(tip.top, target.bottom + 8);
      expect(tip.center.dx, closeTo(target.center.dx, 0.5));
      expect(find.text('冷却系'), findsOneWidget);
      expect(find.text('COOLANT LOOP'), findsOneWidget);
      expect(find.text('Loop pressure has been below the limit for 12 minutes.'), findsOneWidget);
      expect(tester.renderObject<RenderKkPopupLayout>(_tipBox).stem, KkColors.standby.signal);
      final KkBox card = tester.widget<KkBox>(
        find.descendant(of: _tipBox, matching: find.byWidgetPredicate((Widget w) => w is KkBox && w.width == 248)),
      );
      expect(card.decoration!.fill, KkColors.standby.bg200);
      expect(card.decoration!.edges.top, KkSide(KkColors.standby.signal));
      // The action sits at the right edge of the card (12px padding, 1px border).
      expect(tester.getRect(find.byType(KkButton)).right, tip.right - 1 - 12);

      // Across the 8px gap and onto the card: it stays.
      await mouse.moveTo(Offset(target.center.dx, target.bottom + 4));
      await tester.pump(const Duration(milliseconds: 100));
      await mouse.moveTo(tip.center);
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsOneWidget);
      // Its action can be pressed.
      await mouse.moveTo(tester.getCenter(find.byType(KkButton)));
      await mouse.down(tester.getCenter(find.byType(KkButton)));
      await tester.pump();
      await mouse.up();
      await tester.pump();
      expect(opened, 1);
      expect(_tipBox, findsOneWidget);
      // Leaving the card takes it down after the 160ms grace.
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(const Duration(milliseconds: 159));
      expect(_tipBox, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_tipBox, findsNothing);
    });

    testWidgets('rich: leaving the target without reaching the card takes it down', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkTooltip.rich(
          en: 'coolant loop',
          body: 'Below limit.',
          child: KkBox(key: _target, width: 40, height: 40),
        ),
        alignment: Alignment.center,
      );
      final TestGesture mouse = await _mouse(tester);
      await _rest(tester, mouse);
      expect(_tipBox, findsOneWidget);
      await mouse.moveTo(const Offset(790, 590));
      await tester.pump(const Duration(milliseconds: 160));
      expect(_tipBox, findsNothing);
    });

    testWidgets('semantics: the target carries the note', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkTooltip(
          message: 'ACKNOWLEDGE',
          child: KkIconButton(key: _target, icon: KkIcons.check, onPressed: () {}, semanticLabel: 'Ack'),
        ),
      );
      expect(tester.getSemantics(find.byKey(_target)).tooltip, 'ACKNOWLEDGE');
      await pumpKk(
        tester,
        KkTooltip.rich(
          cjk: '冷却系',
          en: 'coolant loop',
          body: 'Below limit.',
          child: KkIconButton(key: _target, icon: KkIcons.check, onPressed: () {}, semanticLabel: 'Ack'),
        ),
      );
      expect(tester.getSemantics(find.byKey(_target)).tooltip, '冷却系 · coolant loop · Below limit.');
      handle.dispose();
    });

    testWidgets('removing it while it waits or shows leaves nothing behind', (WidgetTester tester) async {
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpKk(tester, const KkBox(width: 40, height: 40), alignment: Alignment.center);
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsNothing);

      await mouse.moveTo(const Offset(790, 590));
      await pumpKk(tester, _tip(), alignment: Alignment.center);
      await _rest(tester, mouse);
      expect(_tipBox, findsOneWidget);
      await pumpKk(tester, const KkBox(width: 40, height: 40), alignment: Alignment.center);
      await tester.pump(const Duration(seconds: 1));
      expect(_tipBox, findsNothing);
      // Escape and a press after it has gone reach nobody.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(400, 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the alert theme the plain note takes that theme\'s ink', (WidgetTester tester) async {
      await pumpKk(tester, _tip(open: true), alignment: Alignment.center, condition: KkCondition.alert);
      final KkBox box = tester.widget<KkBox>(
        find.ancestor(of: find.text('ACKNOWLEDGE'), matching: find.byType(KkBox)).first,
      );
      expect(box.fill, KkColors.alertTheme.ink);
      expect(tester.widget<Text>(find.text('ACKNOWLEDGE')).style!.color, KkColors.alertTheme.bg000);
    });
  });
}
