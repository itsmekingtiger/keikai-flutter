import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

void main() {
  group('KkLayers size and alignment', () {
    testChecked('is as large as its largest child that is not positioned', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkLayers(key: const ValueKey<String>('l'), children: <Widget>[box('a', 100, 50), box('b', 60, 80)]),
      );
      expect(rectOf(tester, 'l').size, const Size(100, 80));
      expect(rectOf(tester, 'a').topLeft, Offset.zero);
      expect(rectOf(tester, 'b').topLeft, Offset.zero);
    });

    testChecked('places children by the alignment', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkLayers(alignment: Alignment.center, children: <Widget>[box('a', 100, 50), box('b', 60, 80)]),
      );
      expect(rectOf(tester, 'a').topLeft, const Offset(0, 15));
      expect(rectOf(tester, 'b').topLeft, const Offset(20, 0));
      await pumpRaw(
        tester,
        KkLayers(alignment: Alignment.bottomRight, children: <Widget>[box('a', 100, 50), box('b', 60, 80)]),
      );
      expect(rectOf(tester, 'a').topLeft, const Offset(0, 30));
      expect(rectOf(tester, 'b').topLeft, const Offset(40, 0));
    });

    testChecked('KkLayerAlign places one child by its own alignment', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkLayers(
          children: <Widget>[
            box('a', 100, 50),
            KkLayerAlign(alignment: Alignment.bottomRight, child: box('b', 10, 10)),
          ],
        ),
      );
      expect(rectOf(tester, 'b').topLeft, const Offset(90, 40));
    });

    testChecked('with only positioned children it fills bounded space', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkLayers(
          key: const ValueKey<String>('l'),
          children: <Widget>[KkPositioned(left: 0, top: 0, child: box('a', 10, 10))],
        ),
      );
      expect(rectOf(tester, 'l').size, const Size(800, 600));
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkLayers(
            key: const ValueKey<String>('l'),
            children: <Widget>[KkPositioned(left: 0, top: 0, child: box('a', 10, 10))],
          ),
        ),
      );
      expect(rectOf(tester, 'l').size, Size.zero);
      expect(tester.takeException(), isNull);
    });

    testChecked('empty layers take the bounded space', (WidgetTester tester) async {
      await pumpRaw(tester, const SizedBox(width: 50, height: 40, child: KkLayers(key: ValueKey<String>('l'))));
      expect(rectOf(tester, 'l').size, const Size(50, 40));
    });

    testChecked('expand forces children that are not positioned to fill', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkLayers(expand: true, children: <Widget>[box('a', 10, 10)]),
        ),
      );
      expect(rectOf(tester, 'a').size, const Size(200, 100));
      // Loose constraints are filled as well.
      await pumpRaw(tester, KkLayers(expand: true, children: <Widget>[box('a', 10, 10)]));
      expect(rectOf(tester, 'a').size, const Size(800, 600));
    });

    testChecked('respects the minimum size of the incoming constraints', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, minHeight: 200),
          child: KkLayers(key: const ValueKey<String>('l'), children: <Widget>[box('a', 10, 10)]),
        ),
      );
      expect(rectOf(tester, 'l').size, const Size(300, 200));
    });
  });

  group('KkPositioned', () {
    Future<void> pump(WidgetTester tester, Widget positioned, {Alignment alignment = Alignment.topLeft}) => pumpRaw(
      tester,
      SizedBox(
        width: 200,
        height: 100,
        child: KkLayers(alignment: alignment, children: <Widget>[positioned]),
      ),
    );

    testChecked('left and top', (WidgetTester tester) async {
      await pump(tester, KkPositioned(left: 10, top: 5, child: box('a', 20, 20)));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(10, 5, 20, 20));
    });

    testChecked('right and bottom', (WidgetTester tester) async {
      await pump(tester, KkPositioned(right: 10, bottom: 5, child: box('a', 20, 20)));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(170, 75, 20, 20));
    });

    testChecked('left and right stretch the width; top and bottom the height', (WidgetTester tester) async {
      await pump(tester, KkPositioned(left: 10, right: 30, top: 4, bottom: 6, child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(10, 4, 160, 90));
    });

    testChecked('a fixed width or height', (WidgetTester tester) async {
      await pump(tester, KkPositioned(left: 10, top: 0, width: 50, height: 10, child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(10, 0, 50, 10));
      await pump(tester, KkPositioned(right: 10, bottom: 0, width: 50, height: 10, child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(140, 90, 50, 10));
    });

    testChecked('only a size: the stack alignment places it', (WidgetTester tester) async {
      await pump(tester, KkPositioned(width: 50, height: 40, child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 50, 40));
      await pump(tester, KkPositioned(width: 50, height: 40, child: box('a')), alignment: Alignment.center);
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(75, 30, 50, 40));
    });

    testChecked('one axis pinned, the other aligned', (WidgetTester tester) async {
      await pump(tester, KkPositioned(left: 12, child: box('a', 20, 20)), alignment: Alignment.center);
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(12, 40, 20, 20));
      await pump(tester, KkPositioned(bottom: 0, child: box('a', 20, 20)), alignment: Alignment.center);
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(90, 80, 20, 20));
    });

    testChecked('fill', (WidgetTester tester) async {
      await pump(tester, KkPositioned.fill(child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 200, 100));
      await pump(tester, KkPositioned.fill(left: 10, top: 20, child: box('a')));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(10, 20, 190, 80));
    });

    testChecked('insets larger than the stack give a zero-size child, not an error', (WidgetTester tester) async {
      await pump(tester, KkPositioned(left: 150, right: 150, top: 80, bottom: 80, child: box('a')));
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'a').size, Size.zero);
    });

    testChecked('a child can change between positioned and aligned', (WidgetTester tester) async {
      Widget build(bool positioned) => SizedBox(
        width: 200,
        height: 100,
        child: KkLayers(
          children: <Widget>[
            box('base', 200, 100),
            if (positioned)
              KkPositioned(key: const ValueKey<String>('p'), right: 0, bottom: 0, child: box('a', 20, 20))
            else
              KkLayerAlign(key: const ValueKey<String>('p'), alignment: Alignment.center, child: box('a', 20, 20)),
          ],
        ),
      );
      await pumpRaw(tester, build(true));
      expect(rectOf(tester, 'a').topLeft, const Offset(180, 80));
      await pumpRaw(tester, build(false));
      expect(rectOf(tester, 'a').topLeft, const Offset(90, 40));
      await pumpRaw(tester, build(true));
      expect(rectOf(tester, 'a').topLeft, const Offset(180, 80));
    });

    test('conflicting arguments are rejected', () {
      expect(() => KkPositioned(left: 0, right: 0, width: 10, child: box('a')), throwsAssertionError);
      expect(() => KkPositioned(top: 0, bottom: 0, height: 10, child: box('a')), throwsAssertionError);
    });
  });

  group('KkLayers paint and hit test', () {
    testChecked('the last child is on top', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget target(String id, double size) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => log.add(id),
        child: SizedBox(width: size, height: size),
      );
      await pumpRaw(tester, KkLayers(children: <Widget>[target('back', 100), target('front', 50)]));
      await tester.tapAt(const Offset(25, 25));
      await tester.tapAt(const Offset(75, 75));
      expect(log, <String>['front', 'back']);
    });

    testChecked('clip hides what leaves the stack and reports the clip', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        const SizedBox(
          width: 50,
          height: 50,
          child: KkLayers(
            key: ValueKey<String>('l'),
            clip: Clip.hardEdge,
            children: <Widget>[
              KkPositioned(left: 30, top: 30, child: RepaintBoundary(child: SizedBox(width: 100, height: 100))),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final RenderKkLayers r = tester.renderObject<RenderKkLayers>(byId('l'));
      expect(r.describeApproximatePaintClip(r.firstChild!), const Rect.fromLTWH(0, 0, 50, 50));
      r.clip = Clip.none;
      expect(r.describeApproximatePaintClip(r.firstChild!), isNull);
    });

    testChecked('intrinsics and dry layout follow the children that are not positioned', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkLayers(
          key: const ValueKey<String>('l'),
          children: <Widget>[
            box('a', 100, 50),
            box('b', 60, 80),
            KkPositioned(left: 0, top: 0, child: box('c', 500, 500)),
          ],
        ),
      );
      final RenderKkLayers r = tester.renderObject<RenderKkLayers>(byId('l'));
      expect(r.getMaxIntrinsicWidth(double.infinity), 100);
      expect(r.getMinIntrinsicWidth(double.infinity), 100);
      expect(r.getMaxIntrinsicHeight(double.infinity), 80);
      expect(r.getMinIntrinsicHeight(double.infinity), 80);
      expect(r.getDryLayout(r.constraints), r.size);
      expect(r.size, const Size(100, 80));
    });

    testChecked('reports the highest baseline of its children', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Baseline(
          baseline: 100,
          baselineType: TextBaseline.alphabetic,
          child: KkLayers(
            key: const ValueKey<String>('l'),
            children: <Widget>[
              Text('A', key: const ValueKey<String>('t'), style: testStyle(40)),
              Text('B', style: testStyle(20)),
            ],
          ),
        ),
      );
      final double small = baselineOf(tester.renderObject<RenderBox>(find.text('B')))!;
      expect(rectOf(tester, 'l').top, closeTo(100 - small, 1e-6));
    });
  });
}
