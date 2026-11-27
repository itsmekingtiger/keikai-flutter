import 'dart:typed_data';
import 'dart:ui' as ui show Image;
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

Finder get _handle => find.byType(FocusableActionDetector);

/// The CustomPaint that draws the handle.
Finder get _handlePaint => find.descendant(of: find.byType(KkSplit), matching: find.byType(CustomPaint)).last;

// The painter is private; its fields are read by name.
Color _lineColor(WidgetTester tester) => (tester.widget<CustomPaint>(_handlePaint).painter! as dynamic).line as Color;

Color? _gripColor(WidgetTester tester) => (tester.widget<CustomPaint>(_handlePaint).painter! as dynamic).grip as Color?;

/// Lets the double-tap countdown that every press on the handle starts run out.
Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 400));

Future<void> _pump(WidgetTester tester, KkSplit split, {Size size = const Size(400, 200)}) =>
    pumpRaw(tester, SizedBox(width: size.width, height: size.height, child: split));

void main() {
  group('layout', () {
    testChecked('shares the space without the handle by the ratio', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 196, 200));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(204, 0, 196, 200));
      expect(tester.getRect(_handle), const Rect.fromLTWH(196, 0, 8, 200));
      await _pump(tester, KkSplit(ratio: 0.25, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 98);
      expect(rectOf(tester, 'b').left, 106);
    });

    testChecked('the divider sits on a whole pixel', (WidgetTester tester) async {
      // Half of the 393px to share is 196.5.
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(401, 200));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 197, 200));
      expect(tester.getRect(_handle), const Rect.fromLTWH(197, 0, 8, 200));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(205, 0, 196, 200));
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      expect(r.firstExtent, 197);
      expect(r.clampFirst(120.4), 120);
      expect(r.clampFirst(120.5), 121);
      // Three tenths of 712 is 213.6.
      await _pump(tester, KkSplit(ratio: 0.3, first: box('a'), second: box('b')), size: const Size(720, 200));
      expect(rectOf(tester, 'a').width, 214);
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(222, 0, 498, 200));
      // A vertical split: six tenths of 152 is 91.2.
      await _pump(
        tester,
        KkSplit(axis: Axis.vertical, ratio: 0.6, first: box('a'), second: box('b')),
        size: const Size(300, 160),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 300, 91));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 99, 300, 61));
      // Rounding never takes a pane below its minimum.
      await _pump(
        tester,
        KkSplit(ratio: 0, minFirst: 48.5, first: box('a'), second: box('b')),
        size: const Size(401, 200),
      );
      expect(rectOf(tester, 'a').width, 48.5);
      // The cross intrinsic asks the panes at the same whole extents.
      await _pump(tester, KkSplit(ratio: 0.5, first: const KkAspect(ratio: 1), second: box('b', 50, 60)));
      expect(tester.renderObject<RenderKkSplit>(find.byType(KkSplit)).getMinIntrinsicHeight(401), 197);
    });

    testChecked('at an odd width the 1px line of the handle is still one pixel wide', (WidgetTester tester) async {
      const Color line = Color(0xFF643412);
      const Color panel = Color(0xFF0C0C0E);
      const Widget pane = KkBox(fill: panel, edges: KkEdges(left: KkSide(line), right: KkSide(line)));
      await pumpRaw(
        tester,
        const RepaintBoundary(
          child: SizedBox(width: 401, height: 100, child: KkSplit(enabled: false, first: pane, second: pane)),
        ),
      );
      // One row of the picture at one pixel for one logical pixel.
      late ui.Image image;
      late ByteData bytes;
      await tester.runAsync(() async {
        image = await tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary)).toImage();
        bytes = (await image.toByteData())!;
      });
      addTearDown(image.dispose);
      int rgb(int x) => bytes.getUint32((10 * image.width + x) * 4) >> 8;
      const int lineRgb = 0x643412;
      const int panelRgb = 0x0C0C0E;
      // The first pane ends at 197 with its line; the handle's line is its
      // fourth pixel; the second pane starts at 205 with its line.
      expect(<int>[for (int x = 195; x < 207; x++) rgb(x)], <int>[
        panelRgb, lineRgb, // 195, 196
        0, 0, 0, KkColors.standby.line.toARGB32() & 0xFFFFFF, 0, 0, 0, 0, // 197 to 204: the handle
        lineRgb, panelRgb, // 205, 206
      ]);
    });

    testChecked('keeps both panes at their minimum', (WidgetTester tester) async {
      await _pump(tester, KkSplit(ratio: 0, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 48);
      await _pump(tester, KkSplit(ratio: 1, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'b').width, 48);
      await _pump(tester, KkSplit(ratio: 0, minFirst: 100, minSecond: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 100);
      await _pump(tester, KkSplit(ratio: 1, minFirst: 100, minSecond: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'b').width, 20);
    });

    testChecked('when both minimums cannot fit, the first pane wins', (WidgetTester tester) async {
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

    testChecked('vertical stacks the panes', (WidgetTester tester) async {
      await _pump(tester, KkSplit(axis: Axis.vertical, ratio: 0.5, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 400, 96));
      expect(tester.getRect(_handle), const Rect.fromLTWH(0, 96, 400, 8));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 104, 400, 96));
    });

    testChecked('the handle size is configurable', (WidgetTester tester) async {
      await _pump(tester, KkSplit(handleSize: 20, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 190);
      expect(tester.getRect(_handle).width, 20);
      await _pump(tester, KkSplit(handleSize: 0, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 200);
      expect(tester.takeException(), isNull);
    });

    testChecked('without a main-axis limit each pane takes its own size', (WidgetTester tester) async {
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
      // Both panes share the taller one's height, and so does the handle.
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 100, 60));
      expect(tester.getRect(_handle), const Rect.fromLTWH(100, 0, 8, 60));
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      expect(r.getDryLayout(r.constraints), const Size(158, 60));
    });

    testChecked('without a cross-axis limit a vertical split is as wide as its wider pane', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          constrainedAxis: Axis.vertical,
          child: KkSplit(
            key: const ValueKey<String>('s'),
            axis: Axis.vertical,
            first: box('a', 100, null),
            second: box('b', 50, null),
          ),
        ),
        size: const Size(400, 208),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 's').size, const Size(100, 208));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 100, 100));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 108, 100, 100));
    });

    testChecked('without a cross-axis limit the split grows with a pane that had been stretched', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> extent = ValueNotifier<double>(100);
      addTearDown(extent.dispose);
      for (final Axis axis in Axis.values) {
        final bool h = axis == Axis.horizontal;
        double cross(Finder finder) => h ? tester.getSize(finder).height : tester.getSize(finder).width;
        // A pane whose cross extent is what [extent] says, next to one of 300.
        final Widget growing = ValueListenableBuilder<double>(
          valueListenable: extent,
          builder: (BuildContext context, double value, Widget? child) =>
              h ? box('growing', null, value) : box('growing', value, null),
        );
        final Widget fixed = h ? box('fixed', null, 300) : box('fixed', 300, null);
        for (final bool first in <bool>[true, false]) {
          final String reason = '$axis, ${first ? 'first' : 'second'} pane';
          extent.value = 100;
          await pumpRaw(
            tester,
            SingleChildScrollView(
              scrollDirection: h ? Axis.vertical : Axis.horizontal,
              child: KkSplit(axis: axis, first: first ? growing : fixed, second: first ? fixed : growing),
            ),
            size: const Size(800, 600),
            loose: false,
          );
          // The shorter pane is stretched to the other one.
          expect(cross(find.byType(KkSplit)), 300, reason: reason);
          expect(cross(byId('growing')), 300, reason: reason);
          // It outgrows it: the split, the other pane and the handle follow.
          extent.value = 500;
          await tester.pump();
          expect(tester.takeException(), isNull, reason: reason);
          expect(cross(byId('growing')), 500, reason: reason);
          expect(cross(find.byType(KkSplit)), 500, reason: reason);
          expect(cross(byId('fixed')), 500, reason: reason);
          expect(cross(_handle), 500, reason: reason);
          // And back.
          extent.value = 100;
          await tester.pump();
          expect(cross(find.byType(KkSplit)), 300, reason: reason);
        }
      }
    });

    testChecked('without any limit the split follows a stretched pane that grows along the main axis', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> width = ValueNotifier<double>(100);
      addTearDown(width.dispose);
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkSplit(
            key: const ValueKey<String>('s'),
            // 40 high next to 60: this pane is the one that is stretched.
            first: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (BuildContext context, double value, Widget? child) => box('a', value, 40),
            ),
            second: box('b', 50, 60),
          ),
        ),
      );
      expect(rectOf(tester, 's').size, const Size(158, 60));
      expect(rectOf(tester, 'a').size, const Size(100, 60));
      width.value = 300;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'a').size, const Size(300, 60));
      expect(rectOf(tester, 's').size, const Size(358, 60));
      expect(rectOf(tester, 'b').left, 308);
    });

    testChecked('a split shorter than its handle shows what fits of it', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(5, 100));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_handle), const Rect.fromLTWH(0, 0, 5, 100));
      expect(rectOf(tester, 'a').width, 0);
      expect(rectOf(tester, 'b').width, 0);
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: Size.zero);
      expect(tester.takeException(), isNull);
    });

    testChecked('intrinsics and dry layout', (WidgetTester tester) async {
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
      // Each pane is clipped to its own box, the handle is not.
      expect(r.describeApproximatePaintClip(r.firstChild!), const Rect.fromLTWH(0, 0, 196, 200));
      expect(r.describeApproximatePaintClip(r.childAfter(r.firstChild!)!), const Rect.fromLTWH(204, 0, 196, 200));
      expect(r.describeApproximatePaintClip(r.lastChild!), isNull);
    });

    testChecked('a pane cannot paint over its neighbour', (WidgetTester tester) async {
      // The first pane's content is wider than the pane.
      await _pump(
        tester,
        KkSplit(
          first: const OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: 400,
            child: ColoredBox(color: Color(0xFFFF0000), child: SizedBox(width: 400, height: 200)),
          ),
          second: box('b'),
        ),
      );
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      expect(r, paints..clipRect(rect: const Rect.fromLTWH(0, 0, 196, 200)));
      expect(r, paints..clipRect(rect: const Rect.fromLTWH(0, 0, 196, 200))..clipRect(rect: const Rect.fromLTWH(204, 0, 196, 200)));
    });

    testChecked('the cross intrinsic asks each pane at the extent it would get', (WidgetTester tester) async {
      // A pane twice as wide as it is tall, next to a 60px tall one.
      await _pump(tester, KkSplit(ratio: 0.25, first: const KkAspect(ratio: 2), second: box('b', 50, 60)));
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      // 408 wide: 400 to share, the first pane gets 100 and is 50 tall.
      expect(r.getMinIntrinsicHeight(408), 60);
      // 808 wide: the first pane gets 200 and is 100 tall.
      expect(r.getMinIntrinsicHeight(808), 100);
      expect(r.getMaxIntrinsicHeight(808), 100);
      // With no width to go by, the pane has no height of its own.
      expect(r.getMinIntrinsicHeight(double.infinity), 60);
    });

    testChecked('a vertical split: intrinsics the other way round', (WidgetTester tester) async {
      await _pump(tester, KkSplit(axis: Axis.vertical, first: box('a', 100, 40), second: box('b', 50, 60)));
      final RenderKkSplit r = tester.renderObject<RenderKkSplit>(find.byType(KkSplit));
      expect(r.getMinIntrinsicHeight(double.infinity), 108);
      expect(r.getMaxIntrinsicHeight(double.infinity), 108);
      expect(r.getMinIntrinsicWidth(double.infinity), 100);
      expect(r.getMaxIntrinsicWidth(300), 100);
    });
  });

  group('dragging', () {
    testChecked('the handle follows the pointer and reports the ratio', (WidgetTester tester) async {
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

    testChecked('a drag stops at the minimums and the handle stays under the pointer', (WidgetTester tester) async {
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

    testChecked('a drag leaves the divider on a whole pixel and reports the share of that pixel', (
      WidgetTester tester,
    ) async {
      final List<double> log = <double>[];
      // 400 to share: the handle starts at 200.
      await _pump(
        tester,
        KkSplit(onChanged: log.add, first: box('a'), second: box('b')),
        size: const Size(408, 200),
      );
      final TestGesture gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      // The share of 230 in 400, times 400, is 229.99999999999997.
      expect(rectOf(tester, 'a').width, 230);
      expect(log.last, 230 / 400);
      await gesture.moveBy(const Offset(0.4, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, 230);
      expect(log.last, 230 / 400);
      // 30.8 from where it started.
      await gesture.moveBy(const Offset(0.4, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, 231);
      expect(log.last, 231 / 400);
      await gesture.up();
      await _settle(tester);
    });

    testChecked('a vertical split drags vertically', (WidgetTester tester) async {
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

    testChecked('a controlled split only moves when the parent says so', (WidgetTester tester) async {
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

    testChecked('handing control back keeps the divider where it was', (WidgetTester tester) async {
      await _pump(tester, KkSplit(ratio: 0.25, first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 98);
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      expect(rectOf(tester, 'a').width, 98);
      // And from there it moves by itself.
      await tester.drag(_handle, const Offset(50, 0));
      await tester.pump();
      expect(rectOf(tester, 'a').width, closeTo(148, 1e-6));
      await _settle(tester);
    });

    testChecked('a double tap returns to the initial ratio', (WidgetTester tester) async {
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

    testChecked('disabled: no handle to grab, the line stays', (WidgetTester tester) async {
      final List<double> log = <double>[];
      await _pump(tester, KkSplit(enabled: false, onChanged: log.add, first: box('a'), second: box('b')));
      expect(_handle, findsNothing);
      await tester.dragFrom(const Offset(200, 100), const Offset(50, 0));
      await tester.pump();
      expect(log, isEmpty);
      expect(rectOf(tester, 'a').width, 196);
    });

    testChecked('hovering the handle with a mouse lights it; a disabled handle forgets the pointer', (
      WidgetTester tester,
    ) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      expect(_lineColor(tester), KkColors.standby.line);
      expect(_gripColor(tester), KkColors.standby.inkFaint);
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(_handle));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_lineColor(tester), KkColors.standby.signal);
      expect(_gripColor(tester), KkColors.standby.signal);
      // Disabled under the pointer: the line goes quiet and the grip goes.
      await _pump(tester, KkSplit(enabled: false, first: box('a'), second: box('b')));
      expect(_lineColor(tester), KkColors.standby.line);
      expect(_gripColor(tester), isNull);
      // Enabled again away from the pointer: it does not come back lit.
      await mouse.moveTo(const Offset(10, 10));
      await tester.pump();
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      await tester.pump();
      expect(_lineColor(tester), KkColors.standby.line);
      expect(tester.takeException(), isNull);
    });

    testChecked('the grip is a row of dashes on the line', (WidgetTester tester) async {
      await _pump(tester, KkSplit(first: box('a'), second: box('b')));
      final RenderBox paint = tester.renderObject<RenderBox>(_handlePaint);
      // The 1px line at x 3 of the 8px handle, then the ground under the grip,
      // then four 3 × 6 dashes centred on it.
      expect(
        paint,
        paints
          ..rect(rect: const Rect.fromLTWH(3, 0, 1, 200), color: KkColors.standby.line)
          ..rect(rect: const Rect.fromLTWH(0, 81, 7, 37), color: KkColors.standby.bg000)
          ..rect(rect: const Rect.fromLTWH(2, 83, 3, 6), color: KkColors.standby.inkFaint)
          ..rect(rect: const Rect.fromLTWH(2, 92, 3, 6))
          ..rect(rect: const Rect.fromLTWH(2, 101, 3, 6))
          ..rect(rect: const Rect.fromLTWH(2, 110, 3, 6)),
      );
      // A vertical split turns it on its side.
      await _pump(tester, KkSplit(axis: Axis.vertical, first: box('a'), second: box('b')));
      expect(
        tester.renderObject<RenderBox>(_handlePaint),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 3, 400, 1), color: KkColors.standby.line)
          ..rect(rect: const Rect.fromLTWH(181, 0, 37, 7), color: KkColors.standby.bg000)
          ..rect(rect: const Rect.fromLTWH(183, 2, 6, 3), color: KkColors.standby.inkFaint),
      );
      // Too short for a grip: only the line.
      await _pump(tester, KkSplit(first: box('a'), second: box('b')), size: const Size(400, 12));
      expect(tester.renderObject<RenderBox>(_handlePaint), paintsExactlyCountTimes(#drawRect, 1));
    });
  });

  group('keyboard', () {
    testChecked('arrows move by 4px, 24px with Shift; Home and End go to the limits', (WidgetTester tester) async {
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

    testChecked('a vertical split uses up and down', (WidgetTester tester) async {
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

    testChecked('the handle is a slider to assistive technology', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pump(tester, KkSplit(semanticLabel: 'Log width', initialRatio: 0.25, first: box('a'), second: box('b')));
      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Log width'));
      expect(node.value, '25%');
      expect(node.increasedValue, '30%');
      expect(node.decreasedValue, '20%');
      final SemanticsData data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      // The slider itself is the focusable node.
      expect(data.flagsCollection.isSlider, isTrue);
      expect(data.flagsCollection.isFocused, Tristate.isFalse);
      // A step is five percent of the space, as announced: 19.6px, which the
      // divider takes on whole pixels.
      tester.semantics.increase(find.semantics.byLabel('Log width'));
      await tester.pump();
      expect(rectOf(tester, 'a').width, 118);
      expect(tester.getSemantics(find.bySemanticsLabel('Log width')).value, '30%');
      tester.semantics.decrease(find.semantics.byLabel('Log width'));
      tester.semantics.decrease(find.semantics.byLabel('Log width'));
      await tester.pump();
      expect(rectOf(tester, 'a').width, 78);
      // Steps stop at the minimums.
      for (int i = 0; i < 6; i++) {
        tester.semantics.decrease(find.semantics.byLabel('Log width'));
      }
      await tester.pump();
      expect(rectOf(tester, 'a').width, 48);
      semantics.dispose();
    });

    testChecked('the focused handle is announced as focused', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, KkSplit(focusNode: node, first: box('a'), second: box('b')));
      node.requestFocus();
      // One frame takes the focus, the next one reports it.
      await tester.pump();
      await tester.pump();
      final SemanticsData data = tester.getSemantics(find.bySemanticsLabel('Split')).getSemanticsData();
      expect(data.flagsCollection.isFocused, Tristate.isTrue);
      expect(data.flagsCollection.isSlider, isTrue);
      semantics.dispose();
    });
  });
}
