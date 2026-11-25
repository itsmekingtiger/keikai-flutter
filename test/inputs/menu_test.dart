import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkMenuEntry<String>> _entries = <KkMenuEntry<String>>[
  KkMenuLabel<String>('sector'),
  KkMenuItem<String>(value: 'ack', label: 'acknowledge', cjk: '確認', icon: KkIcons.check, shortcut: 'CTRL+K'),
  KkMenuItem<String>(value: 'trend', label: 'open trend'),
  KkMenuItem<String>(value: 'export', label: 'export log', enabled: false),
  KkMenuSeparator<String>(),
  KkMenuItem<String>(value: 'trip', label: 'trip breaker', danger: true),
];

Finder _row(String label) =>
    find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(MouseRegion)).first;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {String? character}) async {
  await tester.sendKeyEvent(key, character: character);
  await tester.pump();
}

/// The label of the row drawn as highlighted (bg-300 or alert-deep ground).
String? _highlighted(WidgetTester tester) {
  const KkColors c = KkColors.standby;
  const Set<String> labels = <String>{'ACKNOWLEDGE', 'OPEN TREND', 'EXPORT LOG', 'TRIP BREAKER'};
  for (final Element e in find.byType(KkBox).evaluate()) {
    final KkBox box = e.widget as KkBox;
    final Color? fill = box.decoration?.fill;
    if (box.height == 32 && (fill == c.bg300 || fill == c.alertDeep)) {
      final Finder text = find.descendant(of: find.byWidget(box), matching: find.byType(Text));
      for (final Text t in tester.widgetList<Text>(text)) {
        if (labels.contains(t.data)) return t.data;
      }
    }
  }
  return null;
}

void main() {
  setUpAll(loadKkFonts);
  // Every test starts as if the pointer had been used last, so a menu shown
  // with autofocus has no row highlighted until a key is pressed.
  setUp(KkInputModality.notePointer);

  group('KkMenu', () {
    testWidgets('lays out per the design: 232 wide at least, 32px rows', (WidgetTester tester) async {
      await pumpKk(tester, const KkMenu<String>(entries: _entries));
      final Size menu = tester.getSize(find.byType(KkMenu<String>));
      expect(menu.width, 232);
      // 2 top + 4 pad + label 22 + 4 rows of 32 + separator 9 + 4 pad + 1 bottom.
      expect(menu.height, 2 + 4 + 22 + 4 * 32 + 9 + 4 + 1);
      expect(tester.getSize(_row('open trend')).height, 32);
      expect(tester.getSize(_row('open trend')).width, 230);
      // Labels are shown in capitals; the key hint sits at the right edge.
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      expect(tester.getTopRight(find.text('CTRL+K')).dx, 232 - 1 - 12);
    });

    testWidgets('grows to its widest row and honours a fixed width', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkMenu<String>(
          entries: <KkMenuEntry<String>>[
            KkMenuItem<String>(value: 'a', label: 'restore the main coolant pump interlock now', shortcut: 'F12'),
          ],
        ),
      );
      expect(tester.getSize(find.byType(KkMenu<String>)).width, greaterThan(300));
      await pumpKk(tester, const KkMenu<String>(entries: _entries, width: 400));
      expect(tester.getSize(find.byType(KkMenu<String>)).width, 400);
      await pumpKk(tester, const KkBox(width: 120, child: KkMenu<String>(entries: _entries, minWidth: 0)));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkMenu<String>)).width, 120);
    });

    testWidgets('a tap chooses an item and runs its own callback first', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkMenu<String>(
          entries: <KkMenuEntry<String>>[
            KkMenuItem<String>(value: 'a', label: 'alpha', onPressed: () => log.add('pressed')),
            const KkMenuItem<String>(value: 'b', label: 'bravo', enabled: false),
          ],
          onSelected: (KkMenuItem<String> item) => log.add('selected ${item.value}'),
        ),
      );
      await tester.tap(find.text('ALPHA'));
      expect(log, <String>['pressed', 'selected a']);
      await tester.tap(find.text('BRAVO'));
      expect(log.length, 2);
    });

    testWidgets('arrow keys move the highlight, skip disabled rows and wrap', (WidgetTester tester) async {
      await pumpKk(tester, const KkMenu<String>(entries: _entries, autofocus: true));
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'ACKNOWLEDGE');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'OPEN TREND');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'TRIP BREAKER');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'ACKNOWLEDGE');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_highlighted(tester), 'TRIP BREAKER');
      await _key(tester, LogicalKeyboardKey.home);
      expect(_highlighted(tester), 'ACKNOWLEDGE');
      await _key(tester, LogicalKeyboardKey.end);
      expect(_highlighted(tester), 'TRIP BREAKER');
    });

    testWidgets('Enter and Space choose; Escape dismisses', (WidgetTester tester) async {
      final List<String?> chosen = <String?>[];
      int dismissed = 0;
      await pumpKk(
        tester,
        KkMenu<String>(
          entries: _entries,
          autofocus: true,
          onSelected: (KkMenuItem<String> item) => chosen.add(item.value),
          onDismiss: () => dismissed++,
        ),
      );
      await tester.pump();
      // Nothing is highlighted yet: Enter does nothing.
      await _key(tester, LogicalKeyboardKey.enter);
      expect(chosen, isEmpty);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.space, character: ' ');
      expect(chosen, <String?>['ack', 'trend']);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(dismissed, 1);
    });

    testWidgets('typing jumps to the next row that starts with the letters', (WidgetTester tester) async {
      await pumpKk(tester, const KkMenu<String>(entries: _entries, autofocus: true));
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.keyT, character: 't');
      expect(_highlighted(tester), 'TRIP BREAKER');
      // Disabled rows never match.
      await tester.pump(const Duration(seconds: 1));
      await _key(tester, LogicalKeyboardKey.keyE, character: 'e');
      expect(_highlighted(tester), 'TRIP BREAKER');
      await tester.pump(const Duration(seconds: 1));
      await _key(tester, LogicalKeyboardKey.keyO, character: 'o');
      await _key(tester, LogicalKeyboardKey.keyP, character: 'p');
      expect(_highlighted(tester), 'OPEN TREND');
      // The pending type-ahead timer is cancelled with the menu.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the pointer moves the same highlight', (WidgetTester tester) async {
      await pumpKk(tester, const KkMenu<String>(entries: _entries));
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('OPEN TREND')));
      await tester.pump();
      expect(_highlighted(tester), 'OPEN TREND');
      await mouse.moveTo(tester.getCenter(find.text('EXPORT LOG')));
      await tester.pump();
      expect(_highlighted(tester), isNull);
      await mouse.moveTo(tester.getCenter(find.text('TRIP BREAKER')));
      await tester.pump();
      expect(_highlighted(tester), 'TRIP BREAKER');
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(_highlighted(tester), isNull);
    });

    testWidgets('a row that scrolls under a resting pointer does not take the highlight from the keyboard', (
      WidgetTester tester,
    ) async {
      final List<KkMenuEntry<int>> many = <KkMenuEntry<int>>[
        for (int i = 0; i < 30; i++) KkMenuItem<int>(value: i, label: 'unit ${i.toString().padLeft(2, '0')}'),
      ];
      String? active() {
        for (final Element e in find.byType(KkBox).evaluate()) {
          final KkBox box = e.widget as KkBox;
          if (box.height == 32 && box.decoration?.fill == KkColors.standby.bg300) {
            final Finder text = find.descendant(of: find.byWidget(box), matching: find.byType(Text));
            return tester.widget<Text>(text.first).data;
          }
        }
        return null;
      }

      await pumpKk(tester, KkMenu<int>(entries: many, maxHeight: 200, autofocus: true));
      await tester.pump();
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('UNIT 02')));
      await tester.pump();
      expect(active(), 'UNIT 02');
      // Up three times wraps to the last row; the list scrolls to its end and
      // other rows pass under the pointer, which has not moved.
      for (int i = 0; i < 3; i++) {
        await _key(tester, LogicalKeyboardKey.arrowUp);
      }
      await tester.pump();
      await tester.pump();
      expect(active(), 'UNIT 29');
      final Rect menu = tester.getRect(find.byType(KkMenu<int>));
      expect(tester.getRect(find.text('UNIT 29')).bottom, lessThanOrEqualTo(menu.bottom));
      // The pointer takes the highlight back as soon as it really moves.
      await mouse.moveBy(const Offset(0, 1));
      await tester.pump();
      expect(active(), isNot('UNIT 29'));
      expect(active(), isNotNull);
    });

    testWidgets('initialValue starts highlighted; Tab is trapped only when asked', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkMenu<String>(entries: _entries, initialValue: 'trend', autofocus: true, trapFocus: true),
      );
      await tester.pump();
      expect(_highlighted(tester), 'OPEN TREND');
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_highlighted(tester), 'TRIP BREAKER');
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty, all disabled, alert theme and a long list do not throw', (WidgetTester tester) async {
      await pumpKk(tester, const KkMenu<String>(entries: <KkMenuEntry<String>>[], autofocus: true));
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(tester.takeException(), isNull);

      await pumpKk(
        tester,
        const KkMenu<String>(
          autofocus: true,
          entries: <KkMenuEntry<String>>[
            KkMenuItem<String>(value: 'a', label: 'a', enabled: false),
            KkMenuSeparator<String>(),
          ],
        ),
      );
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.end);
      expect(tester.takeException(), isNull);

      await pumpKk(
        tester,
        KkMenu<int>(
          autofocus: true,
          maxHeight: 200,
          entries: <KkMenuEntry<int>>[
            for (int i = 0; i < 60; i++) KkMenuItem<int>(value: i, label: 'channel ${i.toString().padLeft(2, '0')}'),
          ],
        ),
        condition: KkCondition.alert,
      );
      await tester.pump();
      expect(tester.getSize(find.byType(KkMenu<int>)).height, 200);
      await _key(tester, LogicalKeyboardKey.end);
      await tester.pump();
      // The last row was scrolled into view.
      expect(tester.getRect(find.text('CHANNEL 59')).bottom, lessThanOrEqualTo(200));
      expect(tester.takeException(), isNull);
    });
  });

  group('KkMenuAnchor', () {
    Widget anchor({
      KkMenuController? controller,
      ValueChanged<String>? onSelected,
      VoidCallback? onOpen,
      VoidCallback? onClose,
      bool matchWidth = false,
      FocusNode? focusNode,
    }) {
      return KkMenuAnchor<String>(
        entries: _entries,
        controller: controller,
        onSelected: onSelected,
        onOpen: onOpen,
        onClose: onClose,
        matchWidth: matchWidth,
        builder: (BuildContext context, KkMenuController menu) => KkPressable(
          focusNode: focusNode,
          onPressed: menu.toggle,
          builder: (BuildContext context, KkStates s) =>
              const KkBox(width: 120, height: 32, alignment: Alignment.center, child: KkText.en('actions', size: 13)),
        ),
      );
    }

    testWidgets('opens under the trigger with a 4px gap and closes on choice', (WidgetTester tester) async {
      final List<String> chosen = <String>[];
      int opened = 0;
      int closed = 0;
      await pumpKk(
        tester,
        anchor(onSelected: chosen.add, onOpen: () => opened++, onClose: () => closed++),
        padding: const EdgeInsets.all(40),
      );
      expect(find.byType(KkMenu<String>), findsNothing);
      await tester.tap(find.text('ACTIONS'));
      await tester.pump();
      expect(opened, 1);
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      expect(menu.topLeft, const Offset(40, 76));
      expect(menu.width, 232);
      await tester.tap(find.text('OPEN TREND'));
      await tester.pump();
      expect(chosen, <String>['trend']);
      expect(closed, 1);
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('keyboard: Enter opens, arrows move, Enter chooses, focus returns', (WidgetTester tester) async {
      final FocusNode trigger = FocusNode();
      addTearDown(trigger.dispose);
      final List<String> chosen = <String>[];
      await pumpKk(
        tester,
        anchor(onSelected: chosen.add, focusNode: trigger),
        padding: const EdgeInsets.all(40),
      );
      trigger.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      // Opened from the keyboard: the first row is highlighted at once.
      expect(_highlighted(tester), 'ACKNOWLEDGE');
      expect(trigger.hasPrimaryFocus, isFalse);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(chosen, <String>['trend']);
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('Escape and a press outside close it; the controller drives it', (WidgetTester tester) async {
      final KkMenuController controller = KkMenuController();
      addTearDown(controller.dispose);
      await pumpKk(tester, anchor(controller: controller), padding: const EdgeInsets.all(40));
      controller.open();
      await tester.pump();
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(controller.isOpen, isFalse);
      controller.toggle();
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await tester.tapAt(const Offset(700, 550));
      await tester.pump();
      expect(controller.isOpen, isFalse);
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('flips above near the bottom and shifts in near the right edge', (WidgetTester tester) async {
      await pumpKk(
        tester,
        anchor(),
        size: const Size(400, 300),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(8),
      );
      await tester.tap(find.text('ACTIONS'));
      await tester.pump();
      final Rect trigger = tester.getRect(find.byType(KkPressable));
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      expect(menu.bottom, trigger.top - 4);
      expect(menu.right, 396);
      expect(menu.top, greaterThanOrEqualTo(4));
    });

    testWidgets('matchWidth makes the menu as wide as the trigger', (WidgetTester tester) async {
      await pumpKk(tester, anchor(matchWidth: true), padding: const EdgeInsets.all(40));
      await tester.tap(find.text('ACTIONS'));
      await tester.pump();
      expect(tester.getSize(find.byType(KkMenu<String>)).width, 120);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wipes in over 250ms in 5 steps when motion is on', (WidgetTester tester) async {
      await pumpKk(tester, anchor(), padding: const EdgeInsets.all(40), motion: true);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('ACTIONS'));
      await tester.pump();
      final Finder clip = find.ancestor(of: find.byType(KkMenu<String>), matching: find.byType(ClipRect)).first;
      Rect shown() {
        final RenderClipRect render = tester.renderObject<RenderClipRect>(clip);
        return render.clipper!.getClip(render.size);
      }

      expect(shown().width, 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(shown().width, closeTo(232 * 2 / 5, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.none);
      expect(tester.takeException(), isNull);
    });

    testWidgets('removing the anchor while open cleans up', (WidgetTester tester) async {
      final KkMenuController controller = KkMenuController();
      addTearDown(controller.dispose);
      await pumpKk(tester, anchor(controller: controller));
      controller.open();
      await tester.pump();
      await pumpKk(tester, const KkBox());
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('showKkMenu', () {
    testWidgets('opens at a point and completes with the chosen value', (WidgetTester tester) async {
      String? result = 'unset';
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => KkPressable(
            onPressed: () async {
              result = await showKkMenu<String>(context: context, entries: _entries, position: const Offset(100, 120));
            },
            builder: (BuildContext context, KkStates s) => const KkBox(width: 60, height: 30, fill: Color(0xFF333333)),
          ),
        ),
      );
      await tester.tap(find.byType(KkPressable));
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(find.byType(KkMenu<String>)), const Offset(100, 120));
      await tester.tap(find.text('TRIP BREAKER'));
      await tester.pump();
      await tester.pump();
      expect(result, 'trip');
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('completes with null on Escape and on a press outside', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => KkPressable(
            onPressed: () async {
              results.add(
                await showKkMenu<String>(
                  context: context,
                  entries: _entries,
                  anchorRect: const Rect.fromLTWH(700, 560, 40, 20),
                ),
              );
            },
            builder: (BuildContext context, KkStates s) => const KkBox(width: 60, height: 30, fill: Color(0xFF333333)),
          ),
        ),
      );
      await tester.tap(find.byType(KkPressable));
      await tester.pump();
      await tester.pump();
      // Near the corner: flipped above the rect and kept on screen.
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      expect(menu.bottom, 556);
      expect(menu.right, lessThanOrEqualTo(796));
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(results, <String?>[null]);

      await tester.tap(find.byType(KkPressable));
      await tester.pump();
      await tester.pump();
      await tester.tapAt(const Offset(10, 300));
      await tester.pump();
      await tester.pump();
      expect(results, <String?>[null, null]);
      expect(find.byType(KkMenu<String>), findsNothing);
    });
  });
}
