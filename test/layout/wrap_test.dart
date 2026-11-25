import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

void main() {
  List<Widget> five() => <Widget>[
    box('a', 40, 10),
    box('b', 40, 30),
    box('c', 40, 20),
    box('d', 40, 10),
    box('e', 40, 10),
  ];

  Future<void> pump(WidgetTester tester, KkWrap wrap, {double width = 100}) =>
      pumpRaw(tester, SizedBox(width: width, child: wrap));

  group('KkWrap runs', () {
    testChecked('starts a new run when the next child does not fit', (WidgetTester tester) async {
      await pump(tester, KkWrap(key: const ValueKey<String>('w'), gap: 10, cross: KkCrossAlign.start, children: five()));
      // 40 + 10 + 40 = 90 fits in 100; a third would need 140.
      expect(rectOf(tester, 'a').topLeft, Offset.zero);
      expect(rectOf(tester, 'b').topLeft, const Offset(50, 0));
      expect(rectOf(tester, 'c').topLeft, const Offset(0, 40));
      expect(rectOf(tester, 'd').topLeft, const Offset(50, 40));
      expect(rectOf(tester, 'e').topLeft, const Offset(0, 70));
      // Runs are 30, 20 and 10 tall, with two run gaps of 10.
      expect(rectOf(tester, 'w').size, const Size(100, 80));
    });

    testChecked('an exact fit stays on the run', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 20, children: five()));
      // 40 + 20 + 40 = 100: exactly the limit.
      expect(rectOf(tester, 'b').top, rectOf(tester, 'a').top - 10);
      expect(rectOf(tester, 'b').left, 60);
    });

    testChecked('runGap is separate from gap', (WidgetTester tester) async {
      await pump(tester, KkWrap(key: const ValueKey<String>('w'), gap: 10, runGap: 3, cross: KkCrossAlign.start, children: five()));
      expect(rectOf(tester, 'c').top, 33);
      expect(rectOf(tester, 'e').top, 56);
      expect(rectOf(tester, 'w').height, 66);
    });

    testChecked('centres or bottom-aligns a child in its run', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, children: five()));
      expect(rectOf(tester, 'a').top, 10);
      expect(rectOf(tester, 'd').top, 45);
      await pump(tester, KkWrap(gap: 10, cross: KkCrossAlign.end, children: five()));
      expect(rectOf(tester, 'a').top, 20);
      expect(rectOf(tester, 'd').top, 50);
      await pump(tester, KkWrap(gap: 10, cross: KkCrossAlign.stretch, children: five()));
      expect(rectOf(tester, 'a').top, 0);
      await pump(tester, KkWrap(gap: 10, cross: KkCrossAlign.baseline, children: five()));
      expect(rectOf(tester, 'a').top, 0);
    });

    testChecked('a child wider than the limit is narrowed to it and gets its own run', (WidgetTester tester) async {
      await pump(
        tester,
        KkWrap(
          gap: 10,
          cross: KkCrossAlign.start,
          children: <Widget>[
            box('a', 40, 10),
            ConstrainedBox(
              key: const ValueKey<String>('wide'),
              constraints: const BoxConstraints(minWidth: 0),
              child: const SizedBox(width: 300, height: 10),
            ),
            box('c', 40, 10),
          ],
        ),
      );
      expect(rectOf(tester, 'wide'), const Rect.fromLTWH(0, 20, 100, 10));
      expect(rectOf(tester, 'c').topLeft, const Offset(0, 40));
    });

    testChecked('with no width limit everything is on one run', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkWrap(key: const ValueKey<String>('w'), gap: 10, children: five()),
        ),
      );
      expect(rectOf(tester, 'w').size, const Size(240, 30));
      expect(tester.takeException(), isNull);
    });

    testChecked('empty', (WidgetTester tester) async {
      await pump(tester, const KkWrap(key: ValueKey<String>('w'), gap: 10));
      expect(rectOf(tester, 'w').size, const Size(100, 0));
    });

    testChecked('is as wide as its widest run when the width is loose', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: KkWrap(key: const ValueKey<String>('w'), gap: 10, children: five()),
        ),
      );
      expect(rectOf(tester, 'w').width, 90);
    });
  });

  group('KkWrap main alignment', () {
    // One run of two 40px children with a 10px gap in 200px: 110px free.
    List<Widget> two() => <Widget>[box('a', 40, 10), box('b', 40, 10)];

    testChecked('end', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.end, children: two()), width: 200);
      expect(rectOf(tester, 'a').left, 110);
      expect(rectOf(tester, 'b').right, 200);
    });

    testChecked('center', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.center, children: two()), width: 200);
      expect(rectOf(tester, 'a').left, 55);
    });

    testChecked('between', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.between, children: two()), width: 200);
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'b').right, 200);
    });

    testChecked('around', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.around, children: two()), width: 200);
      expect(rectOf(tester, 'a').left, 27.5);
      expect(rectOf(tester, 'b').right, 172.5);
    });

    testChecked('evenly', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.evenly, children: two()), width: 200);
      expect(rectOf(tester, 'a').left, closeTo(110 / 3, 1e-6));
      expect(rectOf(tester, 'b').right, closeTo(200 - 110 / 3, 1e-6));
    });

    testChecked('each run is aligned on its own', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.end, children: five()));
      expect(rectOf(tester, 'a').left, 10);
      expect(rectOf(tester, 'e').left, 60);
    });

    testChecked('between with a single child in the run keeps it at the start', (WidgetTester tester) async {
      await pump(tester, KkWrap(gap: 10, main: KkMainAlign.between, children: <Widget>[box('a', 40, 10)]), width: 200);
      expect(rectOf(tester, 'a').left, 0);
    });
  });

  group('KkWrap measuring', () {
    testChecked('intrinsic sizes', (WidgetTester tester) async {
      await pump(tester, KkWrap(key: const ValueKey<String>('w'), gap: 10, children: five()));
      final RenderKkWrap r = tester.renderObject<RenderKkWrap>(byId('w'));
      expect(r.getMinIntrinsicWidth(double.infinity), 40);
      expect(r.getMaxIntrinsicWidth(double.infinity), 240);
      expect(r.getMinIntrinsicHeight(100), 80);
      expect(r.getMaxIntrinsicHeight(240), 30);
      expect(r.getDryLayout(r.constraints), r.size);
    });

    testChecked('hit testing reaches children on later runs', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget target(String id) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => log.add(id),
        child: const SizedBox(width: 40, height: 20),
      );
      await pump(tester, KkWrap(gap: 10, children: <Widget>[target('a'), target('b'), target('c')]));
      await tester.tapAt(const Offset(20, 40));
      await tester.tapAt(const Offset(70, 10));
      expect(log, <String>['c', 'b']);
    });

    testChecked('changing the properties relays out', (WidgetTester tester) async {
      await pump(tester, KkWrap(key: const ValueKey<String>('w'), gap: 10, children: five()));
      final RenderKkWrap r = tester.renderObject<RenderKkWrap>(byId('w'));
      await pump(tester, KkWrap(key: const ValueKey<String>('w'), gap: 0, runGap: 0, children: five()));
      expect(r.gap, 0);
      expect(rectOf(tester, 'b').left, 40);
      expect(rectOf(tester, 'w').height, 60);
    });
  });
}
