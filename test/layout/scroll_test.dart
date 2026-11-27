import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'layout_util.dart';

void main() {
  group('KkScroll', () {
    testChecked('scrolls a child taller than itself and clamps at both ends', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(controller: controller, child: box('a', null, 500)),
        ),
      );
      expect(controller.position.maxScrollExtent, 400);
      await tester.drag(find.byType(KkScroll), const Offset(0, -150));
      await tester.pump();
      expect(controller.offset, greaterThan(100));
      // No bounce: a drag past the end stops exactly at the end.
      await tester.drag(find.byType(KkScroll), const Offset(0, -2000));
      await tester.pump();
      expect(controller.offset, 400);
      await tester.drag(find.byType(KkScroll), const Offset(0, 5000));
      await tester.pump();
      expect(controller.offset, 0);
      expect(controller.position.physics, isA<ClampingScrollPhysics>());
    });

    testChecked('padding scrolls with the content', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(controller: controller, padding: const EdgeInsets.all(16), child: box('a', null, 500)),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(16, 16, 168, 500));
      expect(controller.position.maxScrollExtent, 432);
      controller.jumpTo(16);
      await tester.pump();
      expect(rectOf(tester, 'a').top, 0);
    });

    testChecked('horizontal and reversed', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(axis: Axis.horizontal, controller: controller, child: box('a', 900)),
        ),
      );
      expect(controller.position.axis, Axis.horizontal);
      expect(controller.position.maxScrollExtent, 700);
      expect(rectOf(tester, 'a').height, 100);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(reverse: true, controller: controller, child: box('a', null, 500)),
        ),
      );
      expect(rectOf(tester, 'a').bottom, 100);
    });

    testChecked('a child that fits does not scroll and is not stretched', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(controller: controller, child: box('a', null, 40)),
        ),
      );
      expect(controller.position.maxScrollExtent, 0);
      expect(rectOf(tester, 'a').height, 40);
    });
  });

  group('KkListView', () {
    for (final double gap in <double>[0, 10]) {
      testChecked('rows that fit leave a drag to the scroll view around them (gap ${gap.round()})', (
        WidgetTester tester,
      ) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpKk(
          tester,
          SizedBox(
            width: 200,
            height: 300,
            child: KkScroll(
              controller: controller,
              child: KkBox(
                height: 1000,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: KkListView(
                    gap: gap,
                    itemCount: 2,
                    itemBuilder: (BuildContext context, int index) => box('row$index', null, 50),
                  ),
                ),
              ),
            ),
          ),
        );
        // The list has nothing to scroll, so it does not keep the drag for itself.
        await tester.dragFrom(const Offset(100, 100), const Offset(0, -80));
        await tester.pump();
        expect(controller.offset, 80);
        expect(rectOf(tester, 'row1').top, 50.0 + gap - 80);
      });
    }
  });

  group('KkScrollBehavior', () {
    testChecked('KeikaiApp installs it: no glow, no stretch, a KEIKAI scrollbar', (WidgetTester tester) async {
      late ScrollBehavior behavior;
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: Builder(
            builder: (BuildContext context) {
              behavior = ScrollConfiguration.of(context);
              return KkScroll(child: box('a', null, 500));
            },
          ),
        ),
      );
      expect(behavior, isA<KkScrollBehavior>());
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(KkScrollbar), findsOneWidget);
      final RawScrollbar bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
      expect(bar.thumbColor, KkColors.standby.line);
      expect(bar.radius, Radius.zero);
      expect(bar.thickness, 6);
    });

    testChecked('the scrollbar follows the alert theme', (WidgetTester tester) async {
      await pumpKk(
        tester,
        SizedBox(width: 200, height: 100, child: KkScroll(child: box('a', null, 500))),
        condition: KkCondition.alert,
      );
      expect(tester.widget<RawScrollbar>(find.byType(RawScrollbar)).thumbColor, KkColors.alertTheme.line);
    });

    testChecked('showScrollbars false leaves the scroll view bare', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        ScrollConfiguration(
          behavior: const KkScrollBehavior(showScrollbars: false),
          child: SizedBox(width: 200, height: 100, child: KkScroll(child: box('a', null, 500))),
        ),
      );
      expect(find.byType(KkScrollbar), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    });

    test('touch drags scroll, mouse drags do not', () {
      const KkScrollBehavior behavior = KkScrollBehavior();
      expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
      expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
      expect(behavior.dragDevices, isNot(contains(PointerDeviceKind.mouse)));
      expect(behavior.shouldNotify(const KkScrollBehavior()), isFalse);
      expect(behavior.shouldNotify(const KkScrollBehavior(showScrollbars: false)), isTrue);
    });

    testChecked('a mouse wheel scrolls', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(controller: controller, child: box('a', null, 500)),
        ),
      );
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(controller.offset, 120);
    });

    testChecked('the thumb is a square 6px bar that shows while scrolling and goes 0.9s later, in one step', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkScroll(controller: controller, child: box('a', null, 500)),
        ),
      );
      RenderObject bar() =>
          tester.renderObject(find.descendant(of: find.byType(RawScrollbar), matching: find.byType(CustomPaint)).first);
      // At rest: no thumb.
      expect(bar(), isNot(paints..rrect()));
      controller.jumpTo(100);
      await tester.pump();
      // 100 of 500 visible: a fifth of the track would be 20px, the minimum is
      // 24. A quarter of the way down the 76px it can travel, at the right edge.
      expect(
        bar(),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(194, 19, 6, 24), Radius.zero),
          color: KkColors.standby.line,
        ),
      );
      // Still there, at full strength, just before the 0.9s are up.
      await tester.pump(const Duration(milliseconds: 880));
      expect(bar(), paints..rrect(color: KkColors.standby.line));
      // And gone at once after: no fade.
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();
      expect(bar(), isNot(paints..rrect()));
      expect(tester.takeException(), isNull);
    });

    testChecked('KkScrollbar can stay visible and take a thickness', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRaw(
        tester,
        ScrollConfiguration(
          behavior: const KkScrollBehavior(showScrollbars: false),
          child: SizedBox(
            width: 200,
            height: 100,
            child: KkScrollbar(
              controller: controller,
              alwaysVisible: true,
              thickness: 10,
              child: KkScroll(controller: controller, child: box('a', null, 500)),
            ),
          ),
        ),
      );
      await tester.pump();
      final RawScrollbar bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
      expect(bar.thumbVisibility, isTrue);
      expect(bar.thickness, 10);
      expect(tester.takeException(), isNull);
    });
  });

  // A list never shows the space past its last row, not even for the frame
  // in which it loses rows, and never glides back from there.
  group('KkScrollBehavior keeps a list inside its rows', () {
    /// A list of [rows] rows of 50px in a view of 200 by [height].
    Widget list(ScrollController controller, int rows, {double height = 200, ScrollPhysics? physics}) => SizedBox(
      width: 200,
      height: height,
      child: KkListView(
        controller: controller,
        physics: physics,
        itemCount: rows,
        itemBuilder: (BuildContext context, int index) => box('row$index', null, 50),
      ),
    );

    /// One frame with [child] in place of what is on screen.
    Future<void> frame(WidgetTester tester, Widget child, {bool motion = false}) =>
        tester.pumpWidget(kkHarness(child, motion: motion));

    /// The list is at [offset], which is its end: [lastRow] sits on the bottom
    /// edge of the view, [height] down, and nothing moves any more.
    Future<void> expectRestsAtEnd(
      WidgetTester tester,
      ScrollController controller,
      double offset, {
      required String lastRow,
      double height = 200,
    }) async {
      expect(controller.offset, offset);
      expect(controller.position.maxScrollExtent, offset);
      expect(rectOf(tester, lastRow).bottom, height);
      expect(controller.position.isScrollingNotifier.value, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, offset);
    }

    for (final bool motion in <bool>[false, true]) {
      testChecked('when rows go while it rests at its end (motion ${motion ? 'on' : 'off'})', (
        WidgetTester tester,
      ) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpKk(tester, list(controller, 20), motion: motion);
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        expect(controller.offset, 800);
        // 6 rows are 300px: 100 more than the view shows.
        await frame(tester, list(controller, 6), motion: motion);
        await expectRestsAtEnd(tester, controller, 100, lastRow: 'row5');
      });
    }

    testChecked('when the view grows while it rests at its end', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 10));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.offset, 300);
      await frame(tester, list(controller, 10, height: 400));
      await expectRestsAtEnd(tester, controller, 100, lastRow: 'row9', height: 400);
    });

    testChecked('when rows go in the frame of a wheel turn', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20));
      controller.jumpTo(400);
      await tester.pump();
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      expect(controller.offset, 500);
      // 8 rows are 400px: the view can scroll by 200.
      await frame(tester, list(controller, 8));
      await expectRestsAtEnd(tester, controller, 200, lastRow: 'row7');
    });

    testChecked('when rows go under a fling, which ends there', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 40));
      await tester.fling(find.byType(KkListView), const Offset(0, -300), 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.position.isScrollingNotifier.value, isTrue);
      expect(controller.offset, greaterThan(300));
      await frame(tester, list(controller, 6));
      await expectRestsAtEnd(tester, controller, 100, lastRow: 'row5');
    });

    testChecked('when rows go under a finger, which goes on dragging from the new end', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20));
      controller.jumpTo(400);
      await tester.pump();
      final TestGesture finger = await tester.startGesture(const Offset(100, 150));
      await finger.moveBy(const Offset(0, -30));
      await tester.pump();
      await finger.moveBy(const Offset(0, -50));
      expect(controller.offset, 480);
      await frame(tester, list(controller, 8));
      expect(controller.offset, 200);
      expect(controller.position.maxScrollExtent, 200);
      expect(rectOf(tester, 'row7').bottom, 200);
      await finger.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(controller.offset, 140);
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 140);
    });

    // The end of the rows also wins over an animation that is on its way: the animation is not carried on from
    // the new end.
    for (final Curve curve in <Curve>[const KkSteps(6), Curves.linear]) {
      testChecked('when rows go in the frame an animation starts, which ends at the new end ($curve)', (
        WidgetTester tester,
      ) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpKk(tester, list(controller, 20), motion: true);
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        expect(controller.offset, 800);
        // An app filters its rows and sends the list back to the top in one go.
        bool done = false;
        controller
            .animateTo(0, duration: const Duration(milliseconds: 300), curve: curve)
            .whenComplete(() => done = true);
        await frame(tester, list(controller, 8), motion: true);
        // 8 rows are 400px. The view is on the last of them at once, and the animation has not been told.
        expect(controller.offset, 200);
        expect(rectOf(tester, 'row7').bottom, 200);
        expect(done, isFalse);
        // On its next tick the animation asks for an offset past the new end, is refused and stops.
        await tester.pump(const Duration(milliseconds: 16));
        expect(done, isTrue);
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(controller.offset, 200);
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.offset, 200);
        expect(rectOf(tester, 'row7').bottom, 200);
      });
    }

    testChecked('when rows go under an animation that has passed their new end, which goes on', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20), motion: true);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      bool done = false;
      controller
          .animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.linear)
          .whenComplete(() => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 600);
      // 16 rows can scroll by 600: the view is still inside them.
      await frame(tester, list(controller, 16), motion: true);
      expect(controller.offset, 600);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 400);
      expect(done, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.offset, 0);
      // The animation is over on the first tick after its time is up.
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, 0);
      expect(done, isTrue);
    });

    testChecked('when rows go under an animation that has not reached their new end, which stops there', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20), motion: true);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      bool done = false;
      controller
          .animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.linear)
          .whenComplete(() => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 600);
      await frame(tester, list(controller, 8), motion: true);
      expect(controller.offset, 200);
      expect(rectOf(tester, 'row7').bottom, 200);
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.offset, 200);
    });

    testChecked('and an animation that starts once the rows have gone reaches its target', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20), motion: true);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await frame(tester, list(controller, 8), motion: true);
      expect(controller.offset, 200);
      controller.animateTo(0, duration: const Duration(milliseconds: 300), curve: const KkSteps(6));
      await tester.pump();
      // 6 steps of 50ms: half way after three of them.
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.offset, 100);
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.offset, 0);
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, 0);
      expect(controller.position.isScrollingNotifier.value, isFalse);
    });

    testChecked('and a jump in the frame the rows go lands where it was sent', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpKk(tester, list(controller, 20));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      controller.jumpTo(50);
      await frame(tester, list(controller, 8));
      expect(controller.offset, 50);
      expect(rectOf(tester, 'row1').top, 0);
    });

    testChecked('when a jump to the end finds the rows it had not built yet to be short', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      // 12 rows of 90px, then 48 of 20px: 2040px in all. From the top the list
      // can only guess how long it is, and it guesses long.
      await pumpKk(
        tester,
        SizedBox(
          width: 200,
          height: 200,
          child: KkListView(
            controller: controller,
            itemCount: 60,
            itemBuilder: (BuildContext context, int index) => box('row$index', null, index < 12 ? 90 : 20),
          ),
        ),
      );
      expect(controller.position.maxScrollExtent, greaterThan(1840));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await expectRestsAtEnd(tester, controller, 1840, lastRow: 'row59');
    });

    testChecked("in an app's own ListView", (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      Widget own(int rows) => SizedBox(
        width: 200,
        height: 200,
        child: ListView.builder(
          controller: controller,
          itemCount: rows,
          itemBuilder: (BuildContext context, int index) => box('row$index', null, 50),
        ),
      );
      await pumpKk(tester, own(20));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.offset, 800);
      await frame(tester, own(6));
      await expectRestsAtEnd(tester, controller, 100, lastRow: 'row5');
    });

    testChecked("under scroll physics of the list's own", (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      const ScrollPhysics always = AlwaysScrollableScrollPhysics();
      await pumpKk(tester, list(controller, 20, physics: always));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.offset, 800);
      await frame(tester, list(controller, 6, physics: always));
      await expectRestsAtEnd(tester, controller, 100, lastRow: 'row5');
    });
  });

  group('KkScroll, like a list,', () {
    testChecked('stays inside a child that gets shorter in the frame of a wheel turn', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      Widget view(double height) => SizedBox(
        width: 200,
        height: 200,
        child: KkScroll(controller: controller, child: box('a', null, height)),
      );
      await pumpKk(tester, view(1000));
      controller.jumpTo(400);
      await tester.pump();
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      expect(controller.offset, 500);
      await tester.pumpWidget(kkHarness(view(400)));
      expect(controller.position.maxScrollExtent, 200);
      expect(controller.offset, 200);
      expect(rectOf(tester, 'a').bottom, 200);
    });

    testChecked('ends an animation at the new end of a child that gets shorter in the frame it starts', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      Widget view(double height) => SizedBox(
        width: 200,
        height: 200,
        child: KkScroll(controller: controller, child: box('a', null, height)),
      );
      await pumpKk(tester, view(1000), motion: true);
      controller.jumpTo(800);
      await tester.pump();
      bool done = false;
      controller
          .animateTo(0, duration: const Duration(milliseconds: 300), curve: const KkSteps(6))
          .whenComplete(() => done = true);
      await tester.pumpWidget(kkHarness(view(400), motion: true));
      expect(controller.offset, 200);
      expect(rectOf(tester, 'a').bottom, 200);
      await tester.pump(const Duration(milliseconds: 16));
      expect(done, isTrue);
      expect(controller.position.isScrollingNotifier.value, isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.offset, 200);
    });
  });
}
