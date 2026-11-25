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
          child: KkScroll(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: box('a', null, 500),
          ),
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
        SizedBox(width: 200, height: 100, child: KkScroll(controller: controller, child: box('a', null, 500))),
      );
      RenderObject bar() => tester.renderObject(
        find.descendant(of: find.byType(RawScrollbar), matching: find.byType(CustomPaint)).first,
      );
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
}
