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
        of: find.ancestor(of: byId(id), matching: find.byType(RawScrollbar)).first,
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

/// A screen of 800 by 600: the nav is 72 wide and scrolls by 600, the body takes the other 728 and scrolls by 1800.
Widget _screen() => KkScreen(padding: EdgeInsets.zero, nav: box('nav', 72, 1200), body: box('body', null, 2400));

/// Two views of 200 by 200 side by side that both ask for the route's controller. Each scrolls by 800.
Widget _twoPrimary() => KkRow(
  children: <Widget>[
    SizedBox(width: 200, height: 200, child: KkScroll(primary: true, child: box('a', null, 1000))),
    SizedBox(width: 200, height: 200, child: KkScroll(primary: true, child: box('b', null, 1000))),
  ],
);

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
}
