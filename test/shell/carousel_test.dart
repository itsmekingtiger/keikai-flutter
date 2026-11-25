import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// Card pitch with the default sizes: 240 wide and 8 apart.
const double _pitch = 248;

List<KkCarouselItem> _cards(int count, {ValueChanged<int>? onTap}) => <KkCarouselItem>[
  for (int i = 0; i < count; i++)
    KkCarouselItem(caption: 'CAM-0$i', onPressed: onTap == null ? null : () => onTap(i), child: const KkBox()),
];

/// The carousel in a box [width] wide: 672 shows two cards and most of a third.
Future<void> _pump(
  WidgetTester tester,
  Widget carousel, {
  double width = 672,
  bool motion = false,
  KkCondition condition = KkCondition.standby,
}) => pumpKk(
  tester,
  KkBox(width: width, child: carousel),
  motion: motion,
  condition: condition,
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(KkCarousel), matching: find.byType(Scrollable)).first)
    .position;

double _offset(WidgetTester tester) => _position(tester).pixels;

Finder _button(KkIconData icon) => find.byWidgetPredicate((Widget w) => w is KkIconButton && w.icon == icon);
final Finder _previous = _button(KkIcons.chevronLeft);
final Finder _next = _button(KkIcons.chevronRight);

bool _enabled(WidgetTester tester, Finder button) => tester.widget<KkIconButton>(button).onPressed != null;

Offset _trackCentre(WidgetTester tester) => tester.getCenter(find.byType(SingleChildScrollView));

bool _trackRing(WidgetTester tester) => tester
    .widget<KkFocusRing>(
      find.ancestor(of: find.byType(SingleChildScrollView), matching: find.byType(KkFocusRing)).first,
    )
    .visible;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('head, cards and captions follow the measures', (WidgetTester tester) async {
    await _pump(tester, KkCarousel(cjk: '監視', en: 'cameras', items: _cards(8)));
    const KkColors c = KkColors.standby;
    expect(tester.takeException(), isNull);

    // Head: title, count, two small outline buttons; 8px; cards; 8px for the scrollbar.
    expect(tester.widget<Text>(find.text('監視')).style!.fontSize, 14);
    expect(tester.widget<Text>(find.text('監視')).style!.color, c.ink);
    final TextStyle en = tester.widget<Text>(find.text('CAMERAS')).style!;
    expect(en.fontSize, 11);
    expect(en.fontWeight, FontWeight.w600);
    expect(en.letterSpacing, closeTo(11 * 0.14, 0.001));
    expect(en.color, c.inkDim);
    final TextStyle count = tester.widget<Text>(find.text('01 / 08')).style!;
    expect(count.fontSize, 12);
    expect(count.fontWeight, FontWeight.w500);
    expect(count.color, c.ink);
    expect(tester.getSize(_previous), const Size(24, 24));
    expect(tester.getSize(_next), const Size(24, 24));
    expect(tester.widget<KkIconButton>(_next).variant, KkIconButtonVariant.outline);
    expect(tester.getRect(_next).right, 672);
    expect(tester.getRect(_next).left - tester.getRect(_previous).right, 8);
    // margin-right 4 on the count, then the 8px gap.
    expect(tester.getRect(_previous).left - tester.getRect(find.text('01 / 08')).right, 12);

    final Rect first = tester.getRect(_card(0));
    expect(first.size, const Size(240, 152));
    expect(first.left, 0);
    expect(first.top, 24 + 8);
    expect(tester.getRect(_card(1)).left, _pitch);
    expect(tester.getSize(find.byType(KkCarousel)), const Size(672, 24 + 8 + 152 + 8));

    // The caption plate sits 8px from the left and bottom, inside the 1px edge.
    final Rect cap = tester.getRect(_captionPlate('CAM-00'));
    expect(cap.left, first.left + 1 + 8);
    expect(cap.bottom, first.bottom - 1 - 8);
    // 3px above and below 11px text, 6px at the sides.
    final Rect capInk = tester.getRect(find.text('CAM-00'));
    expect(capInk.left - cap.left, 6);
    expect(cap.right - capInk.right, 6);
    expect(capInk.top - cap.top, 3);
    expect(cap.bottom - capInk.bottom, 3);
    expect(tester.widget<KkBox>(_captionPlate('CAM-00')).fill, c.bg000);
    final TextStyle capText = tester.widget<Text>(find.text('CAM-00')).style!;
    expect(capText.fontSize, 11);
    expect(capText.fontWeight, FontWeight.w500);
    expect(capText.color, c.ink);

    // Eight cards: 8 × 240 + 7 × 8 = 1976 in a 672 view.
    expect(_position(tester).maxScrollExtent, 1976 - 672);
    expect(_enabled(tester, _previous), isFalse);
    expect(_enabled(tester, _next), isTrue);
  });

  testWidgets('next and previous move one card and the count follows', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    await tester.tap(_next);
    await tester.pump();
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    expect(_enabled(tester, _previous), isTrue);
    await tester.tap(_next);
    await tester.pump();
    expect(_offset(tester), 2 * _pitch);
    expect(find.text('03 / 08'), findsOneWidget);
    await tester.tap(_previous);
    await tester.pump();
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    await tester.tap(_previous);
    await tester.pump();
    expect(_offset(tester), 0);
    expect(find.text('01 / 08'), findsOneWidget);
    expect(_enabled(tester, _previous), isFalse);
    expect(log, <int>[1, 2, 1, 0]);
  });

  testWidgets('at the end the count reads the last card and next is off', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    final double max = _position(tester).maxScrollExtent;
    expect(max, 1304);
    // Cards 0–5 can lead (5 × 248 = 1240); the next press reaches the end.
    for (int i = 1; i <= 5; i++) {
      await tester.tap(_next);
      await tester.pump();
      expect(_offset(tester), i * _pitch);
      expect(find.text('0${i + 1} / 08'), findsOneWidget);
    }
    await tester.tap(_next);
    await tester.pump();
    expect(_offset(tester), max);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isFalse);
    expect(log, <int>[1, 2, 3, 4, 5, 7]);
    // The last card is fully in view.
    expect(tester.getRect(_card(7)).right, 672);

    // Back from the end: the first card that moves the row.
    await tester.tap(_previous);
    await tester.pump();
    expect(_offset(tester), 5 * _pitch);
    expect(find.text('06 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isTrue);
    expect(log.last, 5);
  });

  testWidgets('the row is a tab stop and Left and Right move it by one card', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    // Tab: the next button (previous is disabled), then the row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_trackRing(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_trackRing(tester), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_offset(tester), 2 * _pitch);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_offset(tester), _pitch);
    // Left at the start does nothing more.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_offset(tester), 0);
    expect(find.text('01 / 08'), findsOneWidget);
    expect(log, <int>[1, 2, 1, 0]);
    // The row keeps the focus, and its ring, all along.
    expect(_trackRing(tester), isTrue);
    // Right at the end does nothing more either.
    for (int i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(log, <int>[1, 2, 1, 0, 1, 2, 3, 4, 5, 7]);
  });

  testWidgets('cards that are buttons are the tab stops; the arrow keys go from card to card', (
    WidgetTester tester,
  ) async {
    final List<int> taps = <int>[];
    final List<int> log = <int>[];
    await _pump(
      tester,
      KkCarousel(
        en: 'cameras',
        items: _cards(8, onTap: taps.add),
        onChanged: log.add,
      ),
    );
    int? focusedCard() {
      for (int i = 0; i < 8; i++) {
        final KkFocusRing ring = tester.widget<KkFocusRing>(
          find.ancestor(of: _card(i), matching: find.byType(KkFocusRing)).first,
        );
        if (ring.visible) return i;
      }
      return null;
    }

    // Tab: the next button, then the first card. The row itself is no stop.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedCard(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedCard(), 0);
    expect(_trackRing(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, <int>[0]);

    // Right: the next card. It is in view, so the row stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedCard(), 1);
    expect(_offset(tester), 0);
    // Card 2 spans 496–736 and the view ends at 672: the row moves one card on.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedCard(), 2);
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    expect(log, <int>[1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, <int>[0, 2]);
    // Left twice: card 1 is in view, card 0 is not and becomes the leading card.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedCard(), 1);
    expect(_offset(tester), _pitch);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedCard(), 0);
    expect(_offset(tester), 0);
    expect(find.text('01 / 08'), findsOneWidget);
    expect(log, <int>[1, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card that takes the keyboard focus is brought fully into view, in card order', (
    WidgetTester tester,
  ) async {
    final List<int> log = <int>[];
    await _pump(
      tester,
      KkCarousel(
        en: 'cameras',
        items: _cards(8, onTap: (int i) {}),
        onChanged: log.add,
      ),
    );
    final Finder ring = find.byWidgetPredicate((Widget w) => w is KkFocusRing && w.visible);
    Future<void> tab({bool back = false}) async {
      if (back) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      if (back) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      // Whatever has the focus is whole inside the 672px view.
      expect(ring, findsOneWidget);
      expect(tester.getRect(ring).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(ring).right, lessThanOrEqualTo(672));
    }

    // The next button, then cards 0, 1, 2 and 3.
    for (int i = 0; i < 5; i++) {
      await tab();
    }
    // Card 3 spans 744–984: with card 2 leading (496) it fits in 672.
    expect(tester.getRect(ring), tester.getRect(_card(3)));
    expect(_offset(tester), 2 * _pitch);
    expect(find.text('03 / 08'), findsOneWidget);
    // One card on for card 2, one more for card 3.
    expect(log, <int>[1, 2]);
    // Back: card 2 is in view and nothing moves.
    await tab(back: true);
    expect(tester.getRect(ring), tester.getRect(_card(2)));
    expect(_offset(tester), 2 * _pitch);
    // Card 1 lies before the view: it becomes the leading card.
    await tab(back: true);
    expect(tester.getRect(ring), tester.getRect(_card(1)));
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    expect(log, <int>[1, 2, 1]);
    // On to the end: every card is reached in order and shown whole.
    for (int i = 2; i <= 7; i++) {
      await tab();
      expect(tester.getRect(ring), tester.getRect(_card(i)), reason: 'card $i');
    }
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coming back into the carousel with Shift+Tab lands on the last card, in view', (
    WidgetTester tester,
  ) async {
    final List<int> log = <int>[];
    await pumpKk(
      tester,
      KkBox(
        width: 672,
        child: KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            KkCarousel(
              en: 'cameras',
              items: _cards(8, onTap: (int i) {}),
              onChanged: log.add,
            ),
            KkButton(
              label: 'below',
              focusNode: FocusNode(debugLabel: 'below'),
              autofocus: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'below');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    // Card 7 has the focus and the row has gone to its end to show it.
    final Finder ring = find.byWidgetPredicate((Widget w) => w is KkFocusRing && w.visible);
    expect(tester.getRect(ring), tester.getRect(_card(7)));
    expect(tester.getRect(_card(7)).right, 672);
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(log, <int>[7]);
    // Tab leaves the carousel again.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'below');
  });

  testWidgets('controls inside plain cards keep their order and are brought into view too', (
    WidgetTester tester,
  ) async {
    final List<int> opened = <int>[];
    await _pump(
      tester,
      KkCarousel(
        en: 'cameras',
        items: <KkCarouselItem>[
          for (int i = 0; i < 8; i++)
            KkCarouselItem(
              caption: 'CAM-0$i',
              child: KkBox(
                alignment: Alignment.center,
                child: KkButton(label: 'open $i', onPressed: () => opened.add(i)),
              ),
            ),
        ],
      ),
    );
    Future<void> tab() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    // The next button, the row, then the button of each card in turn.
    await tab();
    await tab();
    expect(_trackRing(tester), isTrue);
    for (int i = 0; i < 5; i++) {
      await tab();
      // The row's own ring is off while something inside it has the focus.
      expect(_trackRing(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opened.last, i, reason: 'card $i');
      final Rect card = tester.getRect(_card(i));
      expect(card.left, greaterThanOrEqualTo(0), reason: 'card $i');
      expect(card.right, lessThanOrEqualTo(672), reason: 'card $i');
    }
    expect(opened, <int>[0, 1, 2, 3, 4]);
    // Card 4 spans 992–1232: card 3 leads.
    expect(_offset(tester), 3 * _pitch);
    // Left and Right belong to the row only while the row itself has the focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened.last, 3);
    expect(_offset(tester), 3 * _pitch);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag settles on the nearest card', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    // Not far enough: back to where it was, and nothing is reported.
    await tester.dragFrom(_trackCentre(tester), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(log, isEmpty);
    // Past the middle of a card: on to the next.
    await tester.dragFrom(_trackCentre(tester), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    expect(log, <int>[1]);
    // A long drag: the card nearest to where it was let go.
    await tester.dragFrom(_trackCentre(tester), const Offset(-520, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 3 * _pitch);
    expect(find.text('04 / 08'), findsOneWidget);
    expect(log, <int>[1, 3]);
    // And back.
    await tester.dragFrom(_trackCentre(tester), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 2 * _pitch);
    expect(log, <int>[1, 3, 2]);
  });

  testWidgets('the very end is a rest position too', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), initialIndex: 5, onChanged: log.add));
    expect(_offset(tester), 5 * _pitch);
    // 1240 → 1290: nearer to the end (1304) than to card 5.
    await tester.dragFrom(_trackCentre(tester), const Offset(-50, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(log, <int>[7]);
    // A small pull back (to 1284) returns to the end.
    await tester.dragFrom(_trackCentre(tester), const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 1304);
    expect(log, <int>[7]);
    // A larger one (to 1254) rests on card 5.
    await tester.dragFrom(_trackCentre(tester), const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 5 * _pitch);
    expect(find.text('06 / 08'), findsOneWidget);
    expect(log, <int>[7, 5]);
  });

  testWidgets('a fling always leaves its card and a hard one carries several', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    // A short, slow flick would stop after 80px or so: it still goes one card on.
    await tester.flingFrom(_trackCentre(tester), const Offset(-60, 0), 300);
    await tester.pumpAndSettle();
    expect(_offset(tester), _pitch);
    expect(log, <int>[1]);
    // And one back.
    await tester.flingFrom(_trackCentre(tester), const Offset(60, 0), 300);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(log, <int>[1, 0]);

    // A firm fling runs past more than one card and still stops on an edge.
    await tester.flingFrom(_trackCentre(tester), const Offset(-120, 0), 2400);
    await tester.pumpAndSettle();
    final double rest = _offset(tester);
    expect(rest, greaterThanOrEqualTo(2 * _pitch));
    expect(rest, lessThan(1304));
    expect(rest % _pitch, 0);
    final int index = (rest / _pitch).round();
    expect(find.text('0${index + 1} / 08'), findsOneWidget);
    expect(log, <int>[1, 0, index]);

    // A very hard one stops at the end.
    await tester.flingFrom(_trackCentre(tester), const Offset(-200, 0), 8000);
    await tester.pumpAndSettle();
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(log.last, 7);
    // And all the way back.
    await tester.flingFrom(_trackCentre(tester), const Offset(200, 0), 8000);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(find.text('01 / 08'), findsOneWidget);
    expect(log.last, 0);
  });

  testWidgets('a wheel scrolls the row, which then settles on a card', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add));
    Future<void> wheel(double dx) async {
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(_trackCentre(tester));
      await tester.sendEventToBinding(pointer.scroll(Offset(dx, 0)));
    }

    // Less than half a card: it comes back.
    await wheel(100);
    expect(_offset(tester), 100);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(log, isEmpty);
    // More than half: on to the next card.
    await wheel(150);
    await tester.pumpAndSettle();
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);
    expect(log, <int>[1]);
    // Past the end: it stops there.
    await wheel(5000);
    await tester.pumpAndSettle();
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(log, <int>[1, 7]);
  });

  testWidgets('a wheel that takes over a stepped move still sets the count', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), onChanged: log.add), motion: true);
    await tester.tap(_next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('02 / 08'), findsOneWidget);
    // While the row is still stepping to card 1, the wheel throws it to the end.
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(_trackCentre(tester));
    await tester.sendEventToBinding(pointer.scroll(const Offset(5000, 0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isFalse);
    expect(log, <int>[1, 7]);
  });

  testWidgets('a mouse drag does not scroll the row', (WidgetTester tester) async {
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8)));
    await tester.dragFrom(_trackCentre(tester), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
  });

  testWidgets('with motion on a move jumps in seven steps and stops on its card', (WidgetTester tester) async {
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8)), motion: true);
    await tester.tap(_next);
    await tester.pump();
    // The count changes at once.
    expect(find.text('02 / 08'), findsOneWidget);
    final Set<int> steps = <int>{};
    for (int i = 0; i <= 14; i++) {
      final double sevenths = _offset(tester) / (_pitch / 7);
      expect(sevenths, closeTo(sevenths.roundToDouble(), 1e-6), reason: 'frame $i');
      steps.add(sevenths.round());
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(steps, <int>{0, 1, 2, 3, 4, 5, 6, 7});
    expect(_offset(tester), _pitch);
    // It stays there.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_offset(tester), _pitch);
    expect(find.text('02 / 08'), findsOneWidget);

    // Two quick presses: the second redirects the first.
    await tester.tap(_next);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_next);
    await tester.pump();
    expect(find.text('04 / 08'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_offset(tester), 3 * _pitch);
    expect(find.text('04 / 08'), findsOneWidget);
  });

  testWidgets('a controlled carousel shows its index and moves only when the owner takes the change', (
    WidgetTester tester,
  ) async {
    int index = 2;
    bool accept = false;
    final List<int> log = <int>[];
    late StateSetter setOwner;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          setOwner = setState;
          return KkCarousel(
            en: 'cameras',
            items: _cards(8),
            index: index,
            onChanged: (int i) {
              log.add(i);
              if (accept) setState(() => index = i);
            },
          );
        },
      ),
    );
    expect(_offset(tester), 2 * _pitch);
    expect(find.text('03 / 08'), findsOneWidget);

    // The owner ignores the request: nothing moves.
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(log, <int>[3]);
    expect(_offset(tester), 2 * _pitch);
    expect(find.text('03 / 08'), findsOneWidget);
    // A drag is undone.
    await tester.dragFrom(_trackCentre(tester), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(log, <int>[3, 3]);
    expect(_offset(tester), 2 * _pitch);
    expect(find.text('03 / 08'), findsOneWidget);

    // The owner takes it.
    accept = true;
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(log, <int>[3, 3, 3]);
    expect(_offset(tester), 3 * _pitch);
    expect(find.text('04 / 08'), findsOneWidget);
    await tester.dragFrom(_trackCentre(tester), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(log.last, 4);
    expect(_offset(tester), 4 * _pitch);
    expect(find.text('05 / 08'), findsOneWidget);

    // The owner moves it by itself.
    setOwner(() => index = 0);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(find.text('01 / 08'), findsOneWidget);
    expect(log.last, 4);
    // An index past the end is the last card.
    setOwner(() => index = 99);
    await tester.pumpAndSettle();
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialIndex places the row before the first frame', (WidgetTester tester) async {
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(8), initialIndex: 3));
    expect(_offset(tester), 3 * _pitch);
    expect(find.text('04 / 08'), findsOneWidget);
    expect(_enabled(tester, _previous), isTrue);

    await _pump(tester, KkCarousel(key: UniqueKey(), en: 'cameras', items: _cards(8), initialIndex: 7));
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isFalse);

    // A card that can only be shown at the very end reads as the last one.
    await _pump(tester, KkCarousel(key: UniqueKey(), en: 'cameras', items: _cards(8), initialIndex: 6));
    expect(_offset(tester), 1304);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isFalse);
    await tester.tap(_previous);
    await tester.pump();
    expect(_offset(tester), 5 * _pitch);
    expect(find.text('06 / 08'), findsOneWidget);
  });

  testWidgets('when every card fits the buttons and keys are off', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await _pump(tester, KkCarousel(en: 'cameras', items: _cards(2), onChanged: log.add));
    expect(find.text('01 / 02'), findsOneWidget);
    expect(_position(tester).maxScrollExtent, 0);
    expect(_enabled(tester, _previous), isFalse);
    expect(_enabled(tester, _next), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('01 / 02'), findsOneWidget);
    expect(log, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty carousel reads 00 / 00', (WidgetTester tester) async {
    await _pump(tester, const KkCarousel(cjk: '監視', en: 'cameras', items: <KkCarouselItem>[]));
    expect(tester.takeException(), isNull);
    expect(find.text('00 / 00'), findsOneWidget);
    expect(_enabled(tester, _previous), isFalse);
    expect(_enabled(tester, _next), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the head and its buttons can be left out; sizes and gap are free', (WidgetTester tester) async {
    await _pump(tester, KkCarousel(items: _cards(8), showHead: false, itemWidth: 120, itemHeight: 80, gap: 16));
    expect(_previous, findsNothing);
    expect(find.textContaining(' / '), findsNothing);
    expect(tester.getSize(find.byType(KkCarousel)), const Size(672, 80 + 8));
    expect(tester.getSize(_card(0)), const Size(120, 80));
    expect(tester.getRect(_card(1)).left, 136);
    // 8 × 120 + 7 × 16 = 1072.
    expect(_position(tester).maxScrollExtent, 1072 - 672);
    await tester.dragFrom(_trackCentre(tester), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(_offset(tester), 136);

    await _pump(tester, KkCarousel(key: UniqueKey(), en: 'cameras', items: _cards(8), showControls: false));
    expect(_previous, findsNothing);
    expect(_next, findsNothing);
    expect(find.text('01 / 08'), findsOneWidget);
    // Without the buttons the count ends at the right edge (less its 4px margin).
    expect(tester.getRect(find.text('01 / 08')).right, 672 - 4);
  });

  testWidgets('the count and the buttons follow a change of width', (WidgetTester tester) async {
    Widget carousel() => KkCarousel(key: const ValueKey<String>('c'), en: 'cameras', items: _cards(8), initialIndex: 3);
    await _pump(tester, carousel());
    expect(_offset(tester), 3 * _pitch);
    expect(find.text('04 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isTrue);
    // Wider: 1976 − 1500 = 476 is the end, and card 3 cannot lead any more.
    await pumpKk(tester, KkBox(width: 1500, child: carousel()), size: const Size(1600, 600));
    await tester.pumpAndSettle();
    expect(_offset(tester), 476);
    expect(find.text('08 / 08'), findsOneWidget);
    expect(_enabled(tester, _next), isFalse);
    expect(_enabled(tester, _previous), isTrue);
    // Wide enough for all of them.
    await pumpKk(tester, KkBox(width: 2000, child: carousel()), size: const Size(2100, 600));
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    expect(_enabled(tester, _next), isFalse);
    expect(_enabled(tester, _previous), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the card size keeps the same card leading', (WidgetTester tester) async {
    Widget carousel(double width) => KkCarousel(
      key: const ValueKey<String>('c'),
      en: 'cameras',
      items: _cards(8),
      initialIndex: 2,
      itemWidth: width,
    );
    await _pump(tester, carousel(240));
    expect(_offset(tester), 2 * 248);
    await _pump(tester, carousel(200));
    await tester.pumpAndSettle();
    expect(_offset(tester), 2 * 208);
    expect(find.text('03 / 08'), findsOneWidget);
    expect(tester.getRect(_card(2)).left, 0);
  });

  testWidgets('a tappable card is a button with a signal edge under the pointer', (WidgetTester tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<int> taps = <int>[];
    await _pump(
      tester,
      KkCarousel(
        en: 'cameras',
        items: <KkCarouselItem>[
          KkCarouselItem(caption: 'CAM-00', onPressed: () => taps.add(0), child: const KkBox()),
          const KkCarouselItem(caption: 'CAM-01', semanticLabel: 'Camera one', child: KkBox()),
          ..._cards(6),
        ],
      ),
    );
    const KkColors c = KkColors.standby;
    KkDecoration face(int i) => tester.widget<KkBox>(_card(i)).decoration!;
    await tester.tap(find.text('CAM-00').first);
    expect(taps, <int>[0]);
    expect(face(0).fill, c.bg100);
    expect(face(0).edges.top.color, c.line);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(tester.getCenter(_card(0)));
    await tester.pump();
    expect(face(0).edges.top.color, c.signal);
    // A card that is not a button keeps its line.
    await mouse.moveTo(tester.getCenter(_card(1)));
    await tester.pump();
    expect(face(0).edges.top.color, c.line);
    expect(face(1).edges.top.color, c.line);
    await mouse.removePointer();

    // The caption names the card unless a label is given; then the caption is not read.
    expect(tester.getSemantics(find.text('CAM-00').first), isSemantics(isButton: true, label: 'CAM-00'));
    expect(tester.getSemantics(find.bySemanticsLabel('Camera one')).label, 'Camera one');
    expect(find.bySemanticsLabel('Item 1 of 8'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous'), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the labels of the buttons can be set and the alert theme is honoured', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      KkCarousel(cjk: '監視', en: 'cameras', items: _cards(8), previousLabel: '이전', nextLabel: '다음'),
      condition: KkCondition.alert,
    );
    expect(find.bySemanticsLabel('이전'), findsOneWidget);
    expect(find.bySemanticsLabel('다음'), findsOneWidget);
    const KkColors c = KkColors.alertTheme;
    expect(tester.widget<Text>(find.text('監視')).style!.color, c.ink);
    expect(tester.widget<KkBox>(_captionPlate('CAM-00')).fill, c.bg000);
    handle.dispose();
  });

  testWidgets('the row survives unbounded width and a tiny box', (WidgetTester tester) async {
    // Unbounded: every card is laid out and nothing scrolls.
    await pumpKk(
      tester,
      KkScroll(
        axis: Axis.horizontal,
        child: KkCarousel(en: 'cameras', items: _cards(3)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_enabled(tester, _next), isFalse);
    await _pump(tester, KkCarousel(key: UniqueKey(), cjk: '監視', en: 'cameras', items: _cards(8)), width: 60);
    expect(tester.takeException(), isNull);
    expect(_position(tester).maxScrollExtent, 1976 - 60);
  });
}

/// The [index]th card: the sized box that carries its ground and edge.
Finder _card(int index) => find
    .byWidgetPredicate(
      (Widget w) => w is KkBox && w.clip && w.decoration != null && w.width != null && w.height != null,
    )
    .at(index);

Finder _captionPlate(String caption) => find
    .ancestor(of: find.text(caption), matching: find.byWidgetPredicate((Widget w) => w is KkBox && w.fill != null))
    .first;
