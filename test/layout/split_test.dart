import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/layout/layout.dart';

import 'layout_util.dart';

Finder get _handle => find.byType(FocusableActionDetector);

/// Lets the double-tap countdown that every press on the handle starts run out.
Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 400));

Future<void> _pump(WidgetTester tester, KkSplit split, {Size size = const Size(400, 200)}) =>
    pumpRaw(tester, SizedBox(width: size.width, height: size.height, child: split));

void main() {
  group('layout', () {
    testWidgets('shares the space without the handle by the ratio', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 196, 200));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(204, 0, 196, 200));
      expect(tester.getRect(_handle), const Rect.fromLTWH(196, 0, 8, 200));
      await _pump(tester, KkSplit(ratio: 0.25, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 98);
      expect(rectOf(tester, 'b').left, 106);
    });

    testWidgets('keeps both panes at their minimum', (WidgetTester tester) async {
      await _pump(tester, KkSplit(ratio: 0, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 48);
      await _pump(tester, KkSplit(ratio: 1, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'b').width, 48);
      await _pump(tester, KkSplit(ratio: 0, minFirst: 100, minSecond: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 100);
      await _pump(tester, KkSplit(ratio: 1, minFirst: 100, minSecond: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'b').width, 20);
    });

    testWidgets('when both minimums cannot fit, the first pane wins', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(60, 100));
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'a').width, 48);
      expect(rectOf(tester, 'b').width, 4);
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(20, 100));
      expect(rectOf(tester, 'a').width, 12);
      expect(rectOf(tester, 'b').width, 0);
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(4, 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vertical stacks the panes', (WidgetTester tester) async {
      await _pump(tester, KkSplit(axis: Axis.vertical, ratio: 0.5, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 400, 96));
      expect(tester.getRect(_handle), const Rect.fromLTWH(0, 96, 400, 8));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 104, 400, 96));
    });

    testWidgets('the handle size is configurable', (WidgetTester tester) async {
      await _pump(tester, KkSplit(handleSize: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 190);
      expect(tester.getRect(_handle).width, 20);
      await _pump(tester, KkSplit(handleSize: 0, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a main-axis limit each pane takes its own size', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkSplit(key: const ValueKey<String>('s'), first: box('a', 100, 40), second: box('b', 50, 60)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 's').size, const Size(158, 60));
      expect(rectOf(tester, 'b').left, 108);
    });

    testWidgets('intrinsics and dry layout', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a', 100, 40), second: box('b', 50, 60)));
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      expect(r.getMaxIntrinsicWidth(double.infinity), 158);
      expect(r.getMinIntrinsicWidth(double.infinity), 158);
      expect(r.getMaxIntrinsicHeight(double.infinity), 60);
      expect(r.getDryLayout(r.constraints), r.size);
      expect(r.available, 392);
      expect(r.firstExtent, 196);
      expect(r.clampFirst(-10), 48);
      expect(r.clampFirst(1000), 344);
      expect(r.toStringDeep(), contains('ratio: 0.5'));
    });
  });

  group('dragging', () {
    testWidgets('the handle follows the pointer and reports the ratio', (WidgetTester tester) async {
      final List<double> log = <double>[];
      await _pump(tester, KkSplit(onChanged: log.add, first: box('a'), second: box('b')));
      await tester.drag(_handle, const Offset(50, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(246, 1e-6));
      expect(log.last, closeTo(246 / 392, 1e-9));
      await tester.drag(_handle, const Offset(-100, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(146, 1e-6));
      await _settle(tester);
    });

    testWidgets('a drag stops at the minimums and the handle stays under the pointer', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      final TestGesture gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(-500, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, 48);
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(196, 1e-6));
      await gesture.moveBy(const Offset(1000, 0));
      await tester.pump();
      expect(rectOf(tester, 'b').width, 48);
      await gesture.up();
      await _settle(tester);
    });

    testWidgets('a vertical split drags vertically', (WidgetTester tester) async {
      await _pump(tester, KkSplit(axis: Axis.vertical, first: box('a'), second: box('b')));
      await tester.drag(_handle, const Offset(0, 30));
      await tester.pump();
      expect(rectOf(tester, 'a').height, closeTo(126, 1e-6));
      // A sideways drag does nothing.
      await tester.drag(_handle, const Offset(40, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').height, closeTo(126, 1e-6));
      await _settle(tester);
    });

    testWidgets('a controlled split only moves when the parent says so', (WidgetTester tester) async {
      final List<double> log = <double>[];
      await _pump(tester, KkSplit(ratio: 0.5, onChanged: log.add, first: box('a'), second: box('b')));
      await tester.drag(_handle, const Offset(50, 0));
      await tester.pump();
      expect(log, isNotEmpty);
      expect(log.last, closeTo(246 / 392, 1e-9));
      expect(rectOf(tester, 'a').width, 196);
      await _pump(tester, KkSplit(ratio: log.last, onChanged: log.add, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, closeTo(246, 1e-6));
      await _settle(tester);
    });

    testWidgets('a double tap returns to the initial ratio', (WidgetTester tester) async {
      await _pump(tester, KkSplit(initialRatio: 0.25, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 98);
      await tester.drag(_handle, const Offset(100, 0));
      await _settle(tester);
      expect(rectOf(tester, 'a').width, closeTo(198, 1e-6));
      final Offset centre = tester.getCenter(_handle);
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(centre);
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(98, 1e-6));
      await _settle(tester);
    });

    testWidgets('disabled: no handle to grab, the line stays', (WidgetTester tester) async {
      final List<double> log = <double>[];
      await _pump(tester, KkSplit(enabled: false, onChanged: log.add, first: box('a'), second: box('b')));
      expect(_handle, findsNothing);
      await tester.dragFrom(const Offset(200, 100), const Offset(50, 0));
      await tester.pump();
      expect(log, isEmpty);
      expect(rectOf(tester, 'a').width, 196);
    });

    testWidgets('hovering the handle with a mouse lights it without error', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(_handle));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await mouse.moveTo(const Offset(10, 10));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard', () {
    testWidgets('arrows move by 4px, 24px with Shift; Home and End go to the limits', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, KkSplit(focusNode: node, first: box('a'), second: box('b')));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(200, 1e-6));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(192, 1e-6));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(216, 1e-6));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(rectOf(tester, 'a').width, 48);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(rectOf(tester, 'a').width, 344);
      // The other axis' arrows are left alone.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(rectOf(tester, 'a').width, 344);
    });

    testWidgets('a vertical split uses up and down', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, KkSplit(axis: Axis.vertical, focusNode: node, first: box('a'), second: box('b')));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rectOf(tester, 'a').height, closeTo(100, 1e-6));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(rectOf(tester, 'a').height, closeTo(92, 1e-6));
    });

    testWidgets('the handle is a slider to assistive technology', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pump(tester, KkSplit(semanticLabel: 'Log width', initialRatio: 0.25, first: box('a'), second: box('b')));
      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Log width'));
      expect(node.value, '25%');
      expect(node.increasedValue, '30%');
      expect(node.decreasedValue, '20%');
      final SemanticsData data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      tester.semantics.increase(find.semantics.byLabel('Log width'));
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(122, 1e-6));
      semantics.dispose();
    });
  });
}
