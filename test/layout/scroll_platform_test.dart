import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// Under a prefix, so that it makes no difference whether keikai.dart hands out the keys as well.
import 'package:flutter/services.dart' as services show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'layout_util.dart';

const List<TargetPlatform> _touch = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
];
const List<TargetPlatform> _desktop = <TargetPlatform>[
  TargetPlatform.linux,
  TargetPlatform.macOS,
  TargetPlatform.windows,
];

/// [testChecked] as the app runs on [platform].
void _testOn(TargetPlatform platform, String description, WidgetTesterCallback body) {
  testChecked('$description (${platform.name})', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      // The binding insists that the override is gone when a test ends.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// The controller the route offers to the scroll views on it.
ScrollController _routeController(WidgetTester tester) =>
    tester.widget<PrimaryScrollController>(find.byType(PrimaryScrollController).first).controller!;

/// The scroll position of the scroll view around the box [id].
ScrollPosition _positionOf(WidgetTester tester, String id) =>
    tester.state<ScrollableState>(find.ancestor(of: byId(id), matching: find.byType(Scrollable)).first).position;

/// What paints the scrollbar of the scroll view around the box [id].
RenderObject _barOf(WidgetTester tester, String id) => tester.renderObject(
  find
      .descendant(
        of: find.ancestor(of: byId(id), matching: find.bySubtype<RawScrollbar>()).first,
        matching: find.byType(CustomPaint),
      )
      .first,
);

/// A thumb at [rect], in the coordinates of its scroll view.
PaintPattern _thumb(Rect rect) =>
    paints..rrect(rrect: RRect.fromRectAndRadius(rect, Radius.zero), color: KkColors.standby.line);

final Matcher _noThumb = isNot(paints..rrect());

/// Turns the mouse wheel by [delta] over [at].
Future<void> _wheel(WidgetTester tester, Offset at, double delta) async {
  final TestPointer mouse = TestPointer(90, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.scroll(Offset(0, delta)));
  await tester.pump();
}

/// Presses the mouse at [from], moves it by [dy] and lets go.
Future<void> _mouseDrag(WidgetTester tester, Offset from, double dy) async {
  final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.moveBy(Offset(0, dy));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

/// Puts a finger down at [from] and moves it up by [distance] in small steps, as slowly as it takes for the thumb of a
/// scrollbar under the finger to take the drag, if it wants it.
Future<void> _slowSwipeUp(WidgetTester tester, Offset from, double distance) async {
  final TestGesture finger = await tester.startGesture(from);
  for (double moved = 0; moved < distance; moved += 2) {
    await finger.moveBy(const Offset(0, -2));
    await tester.pump(const Duration(milliseconds: 8));
  }
  await finger.up();
  await tester.pump();
}

/// Puts a finger down at [at], leaves it there for 0.4s and lifts it.
Future<void> _rest(WidgetTester tester, Offset at) async {
  final TestGesture finger = await tester.startGesture(at);
  await tester.pump(const Duration(milliseconds: 400));
  await finger.up();
  await tester.pump();
  // A view that the touch paged would be on its way now.
  await tester.pump(const Duration(milliseconds: 200));
}

/// Does with a mouse what would move a view of 200 by 200 that is scrolled by 100 of 800, at a bar that has lost that
/// view and may still show its thumb: a press on the thumb out of nowhere, a drag after moving there, a turn of the
/// wheel on it.
Future<void> _pokeWhereTheThumbWas(WidgetTester tester) async {
  await _mouseDrag(tester, const Offset(197, 40), 20);
  final TestPointer mouse = TestPointer(90, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(const Offset(196, 45)));
  await tester.pump();
  await tester.sendEventToBinding(mouse.down(const Offset(196, 45)));
  await tester.sendEventToBinding(mouse.move(const Offset(196, 65)));
  await tester.sendEventToBinding(mouse.up());
  await tester.pump();
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, 50)));
  await tester.pump();
}

/// A screen of 800 by 600: the nav is 72 wide and scrolls by 600, the body takes the other 728 and scrolls by 1800.
Widget _screen() => KkScreen(padding: EdgeInsets.zero, nav: box('nav', 72, 1200), body: box('body', null, 2400));

/// Two views of 200 by 200 side by side that both ask for the route's controller. Each scrolls by 800.
Widget _twoPrimary() => KkRow(
  children: <Widget>[
    SizedBox(width: 200, height: 200, child: KkScroll(primary: true, child: box('a', null, 1000))),
    SizedBox(width: 200, height: 200, child: KkScroll(primary: true, child: box('b', null, 1000))),
  ],
);

/// A scroll view around a box of 1000px called 'a' that comes and goes by itself: nothing above it is built again
/// when [_ViewAtTimesState.show] changes what is there.
class _ViewAtTimes extends StatefulWidget {
  const _ViewAtTimes({this.controller, this.there = true});

  final ScrollController? controller;

  /// Whether the view is there to begin with.
  final bool there;

  @override
  State<_ViewAtTimes> createState() => _ViewAtTimesState();
}

class _ViewAtTimesState extends State<_ViewAtTimes> {
  late bool _there = widget.there;

  void show(bool there) => setState(() => _there = there);

  @override
  Widget build(BuildContext context) {
    return _there ? KkScroll(controller: widget.controller, child: box('a', null, 1000)) : box('plain', 200, 200);
  }
}

void main() {
  group('KkScreen', () {
    for (final TargetPlatform platform in _touch) {
      _testOn(platform, 'nav and body scroll by touch, each with its own thumb', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        final ScrollPosition nav = _positionOf(tester, 'nav');
        expect(body.maxScrollExtent, 1800);
        expect(nav.maxScrollExtent, 600);

        await tester.dragFrom(const Offset(400, 300), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(body.pixels, 100);
        expect(nav.pixels, 0);
        // A quarter of the body shows: a 150px thumb at the right edge, 100 / 1800 of the way down its 450px.
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 25, 6, 150)));
        expect(_barOf(tester, 'nav'), _noThumb);

        await tester.dragFrom(const Offset(36, 300), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(nav.pixels, 100);
        expect(body.pixels, 100);
        // Half of the nav shows: a 300px thumb, 100 / 600 of the way down its 300px.
        expect(_barOf(tester, 'nav'), _thumb(const Rect.fromLTWH(66, 50, 6, 300)));

        // Both thumbs go 0.9s after their view stopped.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(_barOf(tester, 'body'), _noThumb);
        expect(_barOf(tester, 'nav'), _noThumb);
        expect(tester.takeException(), isNull);
        // Neither region follows the controller of the route.
        expect(_routeController(tester).hasClients, isFalse);
      });

      _testOn(platform, 'Page Down with nothing focused finds no view to scroll, and does not throw', (
        WidgetTester tester,
      ) async {
        await pumpKk(tester, _screen(), alignment: null);
        await tester.sendKeyEvent(services.LogicalKeyboardKey.pageDown);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_positionOf(tester, 'body').pixels, 0);
        expect(_positionOf(tester, 'nav').pixels, 0);
      });
    }

    for (final TargetPlatform platform in <TargetPlatform>[..._desktop, ..._touch]) {
      _testOn(platform, 'a mouse wheel shows the thumb, and the mouse can drag it', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        final ScrollPosition nav = _positionOf(tester, 'nav');

        await _wheel(tester, const Offset(400, 300), 120);
        expect(tester.takeException(), isNull);
        expect(body.pixels, 120);
        expect(nav.pixels, 0);
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 30, 6, 150)));
        expect(_barOf(tester, 'nav'), _noThumb);

        // 45px of the thumb's 450 are 180 of the body's 1800.
        await _mouseDrag(tester, const Offset(797, 100), 45);
        expect(tester.takeException(), isNull);
        expect(body.pixels, 300);
        expect(nav.pixels, 0);
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 75, 6, 150)));

        await _wheel(tester, const Offset(36, 300), 120);
        expect(tester.takeException(), isNull);
        expect(nav.pixels, 120);
        expect(body.pixels, 300);
        expect(_barOf(tester, 'nav'), _thumb(const Rect.fromLTWH(66, 60, 6, 300)));
      });
    }
  });

  // The bar is 6px wide. A finger could only take it by a zone around it, and that zone would be the right third of a
  // nav rail: for a finger the bar is an indicator, on a phone as on a desktop with a touch screen.
  group('the scrollbar of a KkScreen leaves a finger to the content', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      _testOn(platform, 'that rests near the edge while the thumb shows', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        double at = 0;
        // Beside the bar, on the bar under the thumb, and on the thumb (which is at 75 to 225 after the first drag).
        for (final Offset finger in const <Offset>[
          Offset(775, 500),
          Offset(788, 500),
          Offset(797, 500),
          Offset(797, 150),
        ]) {
          await tester.dragFrom(const Offset(400, 300), const Offset(0, -300));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          at += 300;
          expect(body.pixels, at);
          expect(_barOf(tester, 'body'), _thumb(Rect.fromLTWH(722, at / 4, 6, 150)));
          await _rest(tester, finger);
          expect(tester.takeException(), isNull);
          expect(body.pixels, at, reason: 'a finger at $finger');
        }
      });

      _testOn(platform, 'that swipes from the thumb: the content follows it', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        await tester.dragFrom(const Offset(400, 300), const Offset(0, -300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(body.pixels, 300);
        // Beside the thumb, then on it.
        await _slowSwipeUp(tester, const Offset(780, 200), 100);
        expect(body.pixels, 400);
        await tester.pump(const Duration(milliseconds: 200));
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 100, 6, 150)));
        await _slowSwipeUp(tester, const Offset(797, 200), 100);
        expect(tester.takeException(), isNull);
        expect(body.pixels, 500);
      });

      _testOn(platform, 'anywhere on a nav rail', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition nav = _positionOf(tester, 'nav');
        double at = 0;
        for (final double x in <double>[30, 44, 50, 60, 69]) {
          await tester.dragFrom(const Offset(20, 300), const Offset(0, -40));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          at += 40;
          expect(nav.pixels, at);
          // Half of the nav shows: a 300px thumb, half as far down as the nav is scrolled.
          expect(_barOf(tester, 'nav'), _thumb(Rect.fromLTWH(66, at / 2, 6, 300)));
          await _slowSwipeUp(tester, Offset(x, 200), 60);
          at += 60;
          expect(nav.pixels, at, reason: 'a swipe at $x');
          await tester.pump(const Duration(milliseconds: 200));
          await _rest(tester, Offset(x, 500));
          expect(nav.pixels, at, reason: 'a finger at $x');
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.windows]) {
      _testOn(platform, 'while a mouse lies over the view', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        final TestPointer mouse = TestPointer(90, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
        await tester.dragFrom(const Offset(400, 300), const Offset(0, -300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(body.pixels, 300);
        await _rest(tester, const Offset(780, 500));
        expect(body.pixels, 300);
        await _slowSwipeUp(tester, const Offset(780, 200), 100);
        expect(body.pixels, 400);

        // The mouse moves, so the bar is its to take again. A finger that then lands on the bar itself does not page.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.sendEventToBinding(mouse.hover(const Offset(410, 300)));
        await _rest(tester, const Offset(797, 500));
        expect(tester.takeException(), isNull);
        expect(body.pixels, 400);
      });
    }
  });

  group('the scrollbar takes a mouse', () {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.linux]) {
      _testOn(platform, 'that comes after a finger: it drags the thumb', (WidgetTester tester) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        await tester.dragFrom(const Offset(400, 300), const Offset(0, -300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(body.pixels, 300);
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 75, 6, 150)));
        // 45px of the thumb's 450 are 180 of the body's 1800.
        await _mouseDrag(tester, const Offset(797, 150), 45);
        expect(tester.takeException(), isNull);
        expect(body.pixels, 480);
        // And a finger after the mouse moves the content again, also from beside the thumb.
        await tester.pump(const Duration(milliseconds: 200));
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 120, 6, 150)));
        await _slowSwipeUp(tester, const Offset(780, 200), 100);
        expect(body.pixels, 580);
      });

      _testOn(platform, 'that comes near it: the thumb shows, and a click on the track pages the view', (
        WidgetTester tester,
      ) async {
        await pumpKk(tester, _screen(), alignment: null);
        final ScrollPosition body = _positionOf(tester, 'body');
        expect(_barOf(tester, 'body'), _noThumb);
        final TestPointer mouse = TestPointer(90, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
        await tester.pump();
        expect(_barOf(tester, 'body'), _noThumb);
        await tester.sendEventToBinding(mouse.hover(const Offset(790, 300)));
        await tester.pump();
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 0, 6, 150)));
        // The thumb stays for as long as the mouse lies on the bar.
        await tester.pump(const Duration(seconds: 2));
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 0, 6, 150)));

        // Below the thumb: a page down is 0.8 of the 600px in view.
        await tester.sendEventToBinding(mouse.down(const Offset(797, 400)));
        await tester.sendEventToBinding(mouse.up());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(body.pixels, 480);
        expect(_barOf(tester, 'body'), _thumb(const Rect.fromLTWH(722, 120, 6, 150)));

        // The thumb goes 0.9s after the mouse has left the bar.
        await tester.sendEventToBinding(mouse.hover(const Offset(400, 300)));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(_barOf(tester, 'body'), _noThumb);
      });
    }
  });

  group('the controller of the route', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      _testOn(platform, 'is left alone by KkScroll and KkListView', (WidgetTester tester) async {
        // Three views of 200 by 200 with 400 of content each.
        await pumpKk(
          tester,
          KkRow(
            children: <Widget>[
              SizedBox(width: 200, height: 200, child: KkScroll(child: box('a', null, 400))),
              SizedBox(
                width: 200,
                height: 200,
                child: KkListView(
                  itemCount: 8,
                  itemBuilder: (BuildContext context, int index) => box('b$index', null, 50),
                ),
              ),
              SizedBox(
                width: 200,
                height: 200,
                child: KkListView(
                  gap: 10,
                  itemCount: 5,
                  itemBuilder: (BuildContext context, int index) => box('c$index', null, 72),
                ),
              ),
            ],
          ),
        );
        expect(_routeController(tester).hasClients, isFalse);
        // A box in each view that stays in sight.
        final List<String> views = <String>['a', 'b1', 'c1'];
        for (int i = 0; i < views.length; i++) {
          expect(_positionOf(tester, views[i]).maxScrollExtent, 200);
          await tester.dragFrom(Offset(200.0 * i + 100, 100), const Offset(0, -50));
          await tester.pump();
          expect(tester.takeException(), isNull);
          // This view and the ones before it have moved, the ones after it have not.
          for (int j = 0; j < views.length; j++) {
            expect(_positionOf(tester, views[j]).pixels, j <= i ? 50 : 0, reason: '${views[j]} after ${views[i]}');
          }
          // Half of the view shows: a 100px thumb, 50 / 200 of the way down its 100px.
          expect(_barOf(tester, views[i]), _thumb(const Rect.fromLTWH(194, 25, 6, 100)));
        }
      });
    }

    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.linux]) {
      _testOn(platform, 'moves the one view that asks for it, which keeps its thumb', (WidgetTester tester) async {
        await pumpKk(
          tester,
          SizedBox(width: 200, height: 200, child: KkScroll(primary: true, child: box('a', null, 1000))),
        );
        final ScrollPosition a = _positionOf(tester, 'a');
        expect(_routeController(tester).position, same(a));

        // With nothing focused the keyboard pages the view of the route: 0.8 of its 200px.
        await tester.sendKeyEvent(services.LogicalKeyboardKey.pageDown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(a.pixels, 160);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 32, 6, 40)));

        // 20px of the thumb's 160 are 100 of the view's 800.
        await _mouseDrag(tester, const Offset(197, 50), 20);
        expect(tester.takeException(), isNull);
        expect(a.pixels, 260);
      });

      _testOn(platform, 'can be shared by two views: each thumb follows its own view', (WidgetTester tester) async {
        await pumpKk(tester, _twoPrimary());
        final ScrollPosition a = _positionOf(tester, 'a');
        final ScrollPosition b = _positionOf(tester, 'b');
        expect(_routeController(tester).positions, unorderedEquals(<ScrollPosition>[a, b]));

        await _wheel(tester, const Offset(300, 100), 100);
        expect(tester.takeException(), isNull);
        expect(b.pixels, 100);
        expect(a.pixels, 0);
        expect(_barOf(tester, 'b'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        expect(_barOf(tester, 'a'), _noThumb);

        // The thumb of the second view drags the second view: 40px of its 160 are 200 of the view's 800.
        await _mouseDrag(tester, const Offset(397, 40), 40);
        expect(tester.takeException(), isNull);
        expect(b.pixels, 300);
        expect(a.pixels, 0);

        await tester.dragFrom(const Offset(100, 100), const Offset(0, -50));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(a.pixels, 50);
        expect(b.pixels, 300);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 10, 6, 40)));
      });
    }

    for (final TargetPlatform platform in _touch) {
      _testOn(platform, "is shared by an app's own list views, which get a thumb each", (WidgetTester tester) async {
        Widget list(String id) => SizedBox(
          width: 200,
          height: 200,
          child: ListView(children: <Widget>[for (int i = 0; i < 20; i++) box('$id$i', null, 50)]),
        );
        await pumpKk(tester, KkRow(children: <Widget>[list('a'), list('b')]));
        final ScrollPosition a = _positionOf(tester, 'a1');
        final ScrollPosition b = _positionOf(tester, 'b1');
        // The framework attaches every vertical view without a controller to the route's on a touch platform.
        expect(_routeController(tester).positions, unorderedEquals(<ScrollPosition>[a, b]));

        await tester.dragFrom(const Offset(300, 100), const Offset(0, -50));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(b.pixels, 50);
        expect(a.pixels, 0);
        expect(_barOf(tester, 'b1'), _thumb(const Rect.fromLTWH(194, 10, 6, 40)));
        expect(_barOf(tester, 'a1'), _noThumb);
      });
    }
  });

  group('the automatic scrollbar', () {
    _testOn(TargetPlatform.linux, 'follows its view to a new scroll position', (WidgetTester tester) async {
      Widget view() => SizedBox(width: 200, height: 200, child: KkScroll(child: box('a', null, 1000)));
      await pumpKk(tester, view());
      final ScrollPosition before = _positionOf(tester, 'a');
      await _wheel(tester, const Offset(100, 100), 100);
      expect(before.pixels, 100);

      // A new pixel ratio makes the scrollable replace its position.
      await pumpKk(tester, view(), pixelRatio: 2);
      final ScrollPosition after = _positionOf(tester, 'a');
      expect(after, isNot(same(before)));
      expect(after.pixels, 100);

      await _wheel(tester, const Offset(100, 100), 100);
      expect(after.pixels, 200);
      expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 40, 6, 40)));
      await _mouseDrag(tester, const Offset(197, 60), 40);
      expect(tester.takeException(), isNull);
      expect(after.pixels, 400);
      expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 80, 6, 40)));
    });

    _testOn(TargetPlatform.linux, 'follows its view from one controller to another', (WidgetTester tester) async {
      final ScrollController first = ScrollController();
      final ScrollController second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget view(ScrollController? controller) => SizedBox(
        width: 200,
        height: 200,
        child: KkScroll(controller: controller, child: box('a', null, 1000)),
      );
      await pumpKk(tester, view(first));
      for (final Widget next in <Widget>[view(second), view(null), view(first)]) {
        await pumpKk(tester, next);
        final double from = _positionOf(tester, 'a').pixels;
        // The wheel shows the thumb, 40px long; 20px of its 160 are 100 of the view's 800.
        await _wheel(tester, const Offset(100, 100), 100);
        await _mouseDrag(tester, Offset(197, (from + 100) / 5 + 20), 20);
        expect(tester.takeException(), isNull);
        expect(_positionOf(tester, 'a').pixels, from + 200);
      }
      expect(first.offset, 600);
      expect(second.hasClients, isFalse);
      expect(_routeController(tester).hasClients, isFalse);
    });

    testChecked('built for something that is no scroll view takes the controller it is given', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => const KkScrollBehavior().buildScrollbar(
            context,
            const SizedBox(width: 200, height: 100),
            ScrollableDetails.vertical(controller: controller),
          ),
        ),
      );
      expect(tester.widget<KkScrollbar>(find.byType(KkScrollbar)).controller, same(controller));
    });
  });

  group('a KkScrollbar without a controller', () {
    /// A bar of 200 by 200 around [view], where scroll views get no bar of their own.
    Widget barAround(Widget view, {bool alwaysVisible = false, double thickness = 6}) => ScrollConfiguration(
      behavior: const KkScrollBehavior(showScrollbars: false),
      child: SizedBox(
        width: 200,
        height: 200,
        child: KkScrollbar(alwaysVisible: alwaysVisible, thickness: thickness, child: view),
      ),
    );

    /// A list of 20 rows of 50px.
    Widget rows() =>
        KkListView(itemCount: 20, itemBuilder: (BuildContext context, int index) => box('a$index', null, 50));

    for (final TargetPlatform platform in TargetPlatform.values) {
      _testOn(platform, 'follows the KkScroll in it', (WidgetTester tester) async {
        await pumpKk(tester, barAround(KkScroll(child: box('a', null, 1000))));
        expect(find.byType(KkScrollbar), findsOneWidget);
        expect(find.bySubtype<RawScrollbar>(), findsOneWidget);
        final ScrollPosition a = _positionOf(tester, 'a');
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(a.pixels, 100);
        // A fifth of the view shows: a 40px thumb, 100 / 800 of the way down its 160px.
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        // 20px of the thumb's 160 are 100 of the view's 800.
        await _mouseDrag(tester, const Offset(197, 40), 20);
        expect(tester.takeException(), isNull);
        expect(a.pixels, 200);
        // The view has not been given to the controller of the route for this.
        expect(_routeController(tester).hasClients, isFalse);
      });

      _testOn(platform, 'follows the KkListView in it', (WidgetTester tester) async {
        await pumpKk(tester, barAround(rows()));
        final ScrollPosition a = _positionOf(tester, 'a1');
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(a.pixels, 100);
        expect(_barOf(tester, 'a3'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 40), 20);
        expect(tester.takeException(), isNull);
        expect(a.pixels, 200);
      });

      _testOn(platform, 'shows a thumb that is always visible once the view is laid out, and keeps it', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          kkHarness(barAround(KkScroll(child: box('a', null, 1000)), alwaysVisible: true, thickness: 10)),
        );
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(190, 0, 10, 40)));
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(190, 20, 10, 40)));
      });
    }

    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.linux]) {
      _testOn(platform, 'works next to the bar that the view has of its own', (WidgetTester tester) async {
        await pumpKk(
          tester,
          SizedBox(
            width: 200,
            height: 200,
            child: KkScrollbar(alwaysVisible: true, thickness: 10, child: KkScroll(child: box('a', null, 1000))),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.bySubtype<RawScrollbar>(), findsNWidgets(2));
        final RenderObject outer = tester.renderObject(
          find.descendant(of: find.bySubtype<RawScrollbar>().first, matching: find.byType(CustomPaint)).first,
        );
        expect(outer, _thumb(const Rect.fromLTWH(190, 0, 10, 40)));
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // The thumb of the view's own bar, which shows while the view scrolls, and the wider one over it.
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        expect(
          outer,
          paints
            ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(194, 20, 6, 40), Radius.zero))
            ..rrect(
              rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(190, 20, 10, 40), Radius.zero),
              color: KkColors.standby.line,
            ),
        );
      });

      _testOn(platform, 'follows a view that follows the controller of the route', (WidgetTester tester) async {
        await pumpKk(tester, barAround(KkScroll(primary: true, child: box('a', null, 1000))));
        final ScrollPosition a = _positionOf(tester, 'a');
        expect(_routeController(tester).position, same(a));
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 40), 20);
        expect(tester.takeException(), isNull);
        expect(a.pixels, 200);
      });

      _testOn(platform, 'follows its view to a new scroll position', (WidgetTester tester) async {
        Widget view() => barAround(KkScroll(child: box('a', null, 1000)));
        await pumpKk(tester, view());
        final ScrollPosition before = _positionOf(tester, 'a');
        await _wheel(tester, const Offset(100, 100), 100);
        expect(before.pixels, 100);

        // A new pixel ratio makes the scrollable replace its position.
        await pumpKk(tester, view(), pixelRatio: 2);
        final ScrollPosition after = _positionOf(tester, 'a');
        expect(after, isNot(same(before)));
        await _wheel(tester, const Offset(100, 100), 100);
        expect(after.pixels, 200);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 40, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 60), 40);
        expect(tester.takeException(), isNull);
        expect(after.pixels, 400);
      });

      _testOn(platform, 'follows the view that moved last when there are two in it', (WidgetTester tester) async {
        await pumpKk(
          tester,
          barAround(
            KkRow(
              children: <Widget>[
                SizedBox(width: 100, child: KkScroll(child: box('a', null, 1000))),
                SizedBox(width: 100, child: KkScroll(child: box('b', null, 600))),
              ],
            ),
          ),
        );
        final ScrollPosition a = _positionOf(tester, 'a');
        final ScrollPosition b = _positionOf(tester, 'b');
        await tester.dragFrom(const Offset(50, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 40), 20);
        expect(a.pixels, 200);
        expect(b.pixels, 0);

        // A third of the second view shows: a thumb of 66.7px, 100 / 400 of the way down the rest of the track.
        await tester.dragFrom(const Offset(150, 100), const Offset(0, -100));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(b.pixels, 100);
        const double length = 200 * 200 / 600;
        expect(_barOf(tester, 'b'), _thumb(const Rect.fromLTWH(194, (200 - length) / 4, 6, length)));
        // 20px of the 133.3 the thumb can travel are 60 of the view's 400.
        await _mouseDrag(tester, const Offset(197, 60), 20);
        expect(tester.takeException(), isNull);
        expect(b.pixels, moreOrLessEquals(160, epsilon: 1e-6));
        expect(a.pixels, 200);
      });

      _testOn(platform, 'lets go of a view that leaves', (WidgetTester tester) async {
        await pumpKk(tester, barAround(KkScroll(child: box('a', null, 1000)), alwaysVisible: true));
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -100));
        await tester.pump();
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));

        await pumpKk(tester, barAround(box('plain', 200, 200), alwaysVisible: true));
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        expect(_barOf(tester, 'plain'), _noThumb);
        // Nothing is left for the mouse to drag, where the thumb was or anywhere else.
        await _mouseDrag(tester, const Offset(197, 40), 20);
        await _mouseDrag(tester, const Offset(197, 150), -20);
        expect(tester.takeException(), isNull);

        // And it takes up the next view that comes.
        await pumpKk(tester, barAround(KkScroll(child: box('b', null, 1000)), alwaysVisible: true));
        final ScrollPosition b = _positionOf(tester, 'b');
        expect(_barOf(tester, 'b'), _thumb(const Rect.fromLTWH(194, 0, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 20), 20);
        expect(tester.takeException(), isNull);
        expect(b.pixels, 100);
      });

      _testOn(platform, 'leaves a view alone that has left without the bar being built again', (
        WidgetTester tester,
      ) async {
        await pumpKk(tester, barAround(const _ViewAtTimes(), alwaysVisible: true));
        await _wheel(tester, const Offset(100, 100), 100);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        tester.state<_ViewAtTimesState>(find.byType(_ViewAtTimes)).show(false);
        await tester.pump();
        await tester.pump();
        expect(find.byType(Scrollable), findsNothing);
        await _pokeWhereTheThumbWas(tester);
        expect(tester.takeException(), isNull);
      });

      _testOn(platform, 'takes up a view that comes without the bar being built again', (WidgetTester tester) async {
        await pumpKk(tester, barAround(const _ViewAtTimes(there: false), alwaysVisible: true));
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'plain'), _noThumb);
        tester.state<_ViewAtTimesState>(find.byType(_ViewAtTimes)).show(true);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 0, 6, 40)));
        await _mouseDrag(tester, const Offset(197, 20), 20);
        expect(tester.takeException(), isNull);
        expect(_positionOf(tester, 'a').pixels, 100);
      });
    }
  });

  group('a KkScrollbar with a controller', () {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.linux]) {
      _testOn(platform, 'leaves a view alone that has left without the bar being built again', (
        WidgetTester tester,
      ) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpKk(
          tester,
          ScrollConfiguration(
            behavior: const KkScrollBehavior(showScrollbars: false),
            child: SizedBox(
              width: 200,
              height: 200,
              child: KkScrollbar(
                controller: controller,
                alwaysVisible: true,
                child: _ViewAtTimes(controller: controller),
              ),
            ),
          ),
        );
        await _wheel(tester, const Offset(100, 100), 100);
        expect(controller.offset, 100);
        expect(_barOf(tester, 'a'), _thumb(const Rect.fromLTWH(194, 20, 6, 40)));
        tester.state<_ViewAtTimesState>(find.byType(_ViewAtTimes)).show(false);
        await tester.pump();
        await tester.pump();
        expect(controller.hasClients, isFalse);
        await _pokeWhereTheThumbWas(tester);
        expect(tester.takeException(), isNull);

        // The view comes back, and the mouse has its thumb again.
        tester.state<_ViewAtTimesState>(find.byType(_ViewAtTimes)).show(true);
        await tester.pump();
        await tester.pump();
        await _mouseDrag(tester, const Offset(197, 20), 20);
        expect(tester.takeException(), isNull);
        expect(controller.offset, 100);
      });
    }
  });
}
