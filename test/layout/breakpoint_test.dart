import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

void main() {
  group('KkWindowClass order', () {
    test('compact < medium < expanded < large < xlarge < wall', () {
      const List<KkWindowClass> order = KkWindowClass.values;
      for (int i = 0; i < order.length; i++) {
        for (int j = 0; j < order.length; j++) {
          expect(order[i].isAtLeast(order[j]), i >= j);
          expect(order[i].isAtMost(order[j]), i <= j);
          expect(order[i].isBelow(order[j]), i < j);
          expect(order[i].isAbove(order[j]), i > j);
          expect(order[i] >= order[j], i >= j);
          expect(order[i] > order[j], i > j);
          expect(order[i] <= order[j], i <= j);
          expect(order[i] < order[j], i < j);
        }
      }
    });
  });

  group('KkBreakpoint', () {
    testChecked('builds from the class of its own width', (WidgetTester tester) async {
      const List<(double, KkWindowClass)> cases = <(double, KkWindowClass)>[
        (300, KkWindowClass.compact),
        (599.5, KkWindowClass.compact),
        (600, KkWindowClass.medium),
        (840, KkWindowClass.expanded),
        (1200, KkWindowClass.large),
        (1600, KkWindowClass.xlarge),
        (2560, KkWindowClass.wall),
      ];
      for (final (double width, KkWindowClass expected) in cases) {
        KkWindowClass? seen;
        KkWindowClass? scoped;
        BoxConstraints? got;
        await pumpRaw(
          tester,
          SizedBox(
            width: width,
            height: 50,
            child: KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                seen = windowClass;
                scoped = KkWindowScope.of(context);
                got = constraints;
                return const SizedBox.shrink();
              },
            ),
          ),
          size: const Size(3000, 100),
        );
        expect(seen, expected, reason: '$width');
        expect(scoped, expected, reason: '$width');
        expect(got, BoxConstraints.tight(Size(width, 50)));
      }
    });

    testChecked('rebuilds when the width crosses a threshold', (WidgetTester tester) async {
      final List<KkWindowClass> log = <KkWindowClass>[];
      Widget build(double width) => SizedBox(
        width: width,
        child: KkBreakpoint(
          builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
            log.add(windowClass);
            return const SizedBox(height: 10);
          },
        ),
      );
      await pumpRaw(tester, build(500), size: const Size(2000, 100));
      await pumpRaw(tester, build(700), size: const Size(2000, 100));
      await pumpRaw(tester, build(1000), size: const Size(2000, 100));
      expect(log, <KkWindowClass>[KkWindowClass.compact, KkWindowClass.medium, KkWindowClass.expanded]);
    });

    testChecked('uses the theme breakpoints', (WidgetTester tester) async {
      KkWindowClass? seen;
      await pumpRaw(
        tester,
        KeikaiTheme(
          data: const KeikaiThemeData(metrics: KkMetrics(bpMedium: 300)),
          child: SizedBox(
            width: 400,
            child: KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                seen = windowClass;
                return const SizedBox(height: 10);
              },
            ),
          ),
        ),
      );
      expect(seen, KkWindowClass.medium);
    });

    testChecked('with no width limit it falls back to the window width', (WidgetTester tester) async {
      KkWindowClass? seen;
      await pumpRaw(
        tester,
        MediaQuery(
          data: const MediaQueryData(size: Size(1300, 600)),
          child: UnconstrainedBox(
            child: KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                seen = windowClass;
                return const SizedBox(width: 10, height: 10);
              },
            ),
          ),
        ),
      );
      expect(seen, KkWindowClass.large);
    });
  });

  group('KkWindowScope', () {
    testChecked('falls back to the window, then to expanded', (WidgetTester tester) async {
      KkWindowClass? seen;
      Widget probe() => Builder(
        builder: (BuildContext context) {
          seen = KkWindowScope.of(context);
          expect(KkWindowScope.maybeOf(context), isNull);
          return const SizedBox.shrink();
        },
      );
      await pumpRaw(tester, MediaQuery(data: const MediaQueryData(size: Size(500, 600)), child: probe()));
      expect(seen, KkWindowClass.compact);
      await pumpRaw(tester, MediaQuery(data: const MediaQueryData(size: Size(1700, 600)), child: probe()));
      expect(seen, KkWindowClass.xlarge);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: probe()));
      // pumpWidget always provides a view; without MediaQuery data the default applies.
      expect(seen, isNotNull);
    });

    testChecked('the nearest scope wins and dependents rebuild when it changes', (WidgetTester tester) async {
      final List<KkWindowClass> log = <KkWindowClass>[];
      final Widget probe = Builder(
        builder: (BuildContext context) {
          log.add(KkWindowScope.of(context));
          return const SizedBox.shrink();
        },
      );
      await pumpRaw(
        tester,
        KkWindowScope(
          windowClass: KkWindowClass.wall,
          child: KkWindowScope(windowClass: KkWindowClass.medium, child: probe),
        ),
      );
      await pumpRaw(
        tester,
        KkWindowScope(
          windowClass: KkWindowClass.wall,
          child: KkWindowScope(windowClass: KkWindowClass.large, child: probe),
        ),
      );
      await pumpRaw(
        tester,
        KkWindowScope(
          windowClass: KkWindowClass.compact,
          child: KkWindowScope(windowClass: KkWindowClass.large, child: probe),
        ),
      );
      expect(log, <KkWindowClass>[KkWindowClass.medium, KkWindowClass.large]);
    });
  });

  group('KkResponsive', () {
    test('a class without a value takes the nearest smaller one', () {
      const KkResponsive<int> span = KkResponsive<int>(compact: 4, expanded: 6, xlarge: 3);
      expect(span.resolve(KkWindowClass.compact), 4);
      expect(span.resolve(KkWindowClass.medium), 4);
      expect(span.resolve(KkWindowClass.expanded), 6);
      expect(span.resolve(KkWindowClass.large), 6);
      expect(span.resolve(KkWindowClass.xlarge), 3);
      expect(span.resolve(KkWindowClass.wall), 3);
      const KkResponsive<String> every = KkResponsive<String>(
        compact: 'c',
        medium: 'm',
        expanded: 'e',
        large: 'l',
        xlarge: 'x',
        wall: 'w',
      );
      expect(<String>[for (final KkWindowClass c in KkWindowClass.values) every.resolve(c)], <String>[
        'c',
        'm',
        'e',
        'l',
        'x',
        'w',
      ]);
    });

    test('all gives the same value everywhere', () {
      const KkResponsive<double> gap = KkResponsive<double>.all(8);
      for (final KkWindowClass c in KkWindowClass.values) {
        expect(gap.resolve(c), 8);
      }
    });

    test('equality', () {
      expect(const KkResponsive<int>(compact: 1, large: 2), const KkResponsive<int>(compact: 1, large: 2));
      expect(
        const KkResponsive<int>(compact: 1, large: 2).hashCode,
        const KkResponsive<int>(compact: 1, large: 2).hashCode,
      );
      expect(const KkResponsive<int>(compact: 1, large: 2) == const KkResponsive<int>(compact: 1, large: 3), isFalse);
    });

    testChecked('of reads the window class of the context', (WidgetTester tester) async {
      const KkResponsive<int> span = KkResponsive<int>(compact: 4, expanded: 6);
      int? seen;
      await pumpRaw(
        tester,
        SizedBox(
          width: 900,
          child: KkBreakpoint(
            builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
              seen = span.of(context);
              return const SizedBox(height: 10);
            },
          ),
        ),
        size: const Size(1000, 100),
      );
      expect(seen, 6);
    });

    testChecked('a span builder from a responsive value drives a grid cell', (WidgetTester tester) async {
      const KkResponsive<int> span = KkResponsive<int>(compact: 4, medium: 4, expanded: 6, xlarge: 4);
      int pick(int columns) => span.resolve(const KkMetrics().windowClass(columns == 4 ? 0 : (columns == 8 ? 600 : (columns == 12 ? 840 : 1600))));
      for (final (double width, double expected) in <(double, double)>[
        (400, 400),
        (840, (840 - 88) / 12 * 6 + 40),
        (1600, (1600 - 120) / 16 * 4 + 24),
      ]) {
        await pumpRaw(
          tester,
          SizedBox(
            width: width,
            child: KkGrid(children: <Widget>[KkCell(spanBuilder: pick, rows: 1, child: box('a'))]),
          ),
          size: Size(width, 200),
        );
        expect(rectOf(tester, 'a').width, closeTo(expected, 1e-6));
      }
    });
  });

  group('conveniences', () {
    testChecked('KkCenter and KkAlign', (WidgetTester tester) async {
      await pumpRaw(tester, SizedBox(width: 200, height: 100, child: KkCenter(child: box('a', 20, 10))));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(90, 45, 20, 10));
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkAlign(alignment: Alignment.bottomRight, child: box('a', 20, 10)),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(180, 90, 20, 10));
      await pumpRaw(tester, const SizedBox(width: 20, height: 10, child: KkCenter(key: ValueKey<String>('c'))));
      expect(rectOf(tester, 'c').size, const Size(20, 10));
    });

    testChecked('KkPadding', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkPadding(
          key: const ValueKey<String>('p'),
          padding: const EdgeInsets.fromLTRB(1, 2, 3, 4),
          child: box('a', 20, 10),
        ),
      );
      expect(rectOf(tester, 'p').size, const Size(24, 16));
      expect(rectOf(tester, 'a').topLeft, const Offset(1, 2));
    });

    testChecked('KkSized', (WidgetTester tester) async {
      await pumpRaw(tester, KkSized(width: 30, child: box('a', null, 10)));
      expect(rectOf(tester, 'a').size, const Size(30, 10));
      await pumpRaw(tester, const KkSized.square(24, key: ValueKey<String>('s')));
      expect(rectOf(tester, 's').size, const Size(24, 24));
      await pumpRaw(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: KkAlign(alignment: Alignment.topLeft, child: KkSized.expand(key: ValueKey<String>('s'))),
        ),
      );
      expect(rectOf(tester, 's').size, const Size(300, 200));
    });

    testChecked('KkAspect', (WidgetTester tester) async {
      // Width bounded: height follows.
      await pumpRaw(tester, SizedBox(width: 320, child: KkAspect(ratio: 16 / 9, child: box('a'))));
      expect(rectOf(tester, 'a').size, const Size(320, 180));
      // The height limit wins when the box would be too tall.
      await pumpRaw(
        tester,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 90),
          child: KkAspect(ratio: 16 / 9, child: box('a')),
        ),
      );
      expect(rectOf(tester, 'a').size, const Size(160, 90));
      // Only the height is bounded.
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          constrainedAxis: Axis.vertical,
          child: SizedBox(height: 100, child: KkAspect(ratio: 2, child: box('a'))),
        ),
      );
      expect(rectOf(tester, 'a').size, const Size(200, 100));
      // Tight constraints win over the ratio.
      await pumpRaw(tester, SizedBox(width: 50, height: 50, child: KkAspect(ratio: 2, child: box('a'))));
      expect(rectOf(tester, 'a').size, const Size(50, 50));
      // A minimum is respected.
      await pumpRaw(
        tester,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100, minHeight: 80, maxHeight: 400),
          child: KkAspect(ratio: 2, child: box('a')),
        ),
      );
      expect(rectOf(tester, 'a').height, 80);
      // Nothing bounded: the child decides, widened to the ratio.
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkAspect(key: const ValueKey<String>('asp'), ratio: 2, child: box('a', 30, 40)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'asp').size, const Size(80, 40));
      expect(rectOf(tester, 'a').size, const Size(80, 40));
      // No child.
      await pumpRaw(tester, const SizedBox(width: 100, child: KkAspect(key: ValueKey<String>('asp'), ratio: 4)));
      expect(rectOf(tester, 'asp').size, const Size(100, 25));
      final RenderKkAspect r = tester.renderObject<RenderKkAspect>(byId('asp'));
      expect(r.getMaxIntrinsicHeight(200), 50);
      expect(r.getMaxIntrinsicWidth(50), 200);
      expect(r.getMinIntrinsicHeight(double.infinity), 0);
      expect(r.getDryLayout(r.constraints), r.size);
      r.ratio = 2;
      expect(r.ratio, 2);
    });

    testChecked('KkListView builds lazily and spaces rows by the gap', (WidgetTester tester) async {
      final Set<int> built = <int>{};
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 100,
          child: KkListView(
            itemCount: 1000,
            gap: 4,
            padding: const EdgeInsets.all(6),
            itemBuilder: (BuildContext context, int index) {
              built.add(index);
              return box('row$index', null, 20);
            },
          ),
        ),
      );
      expect(built.length, lessThan(40));
      expect(rectOf(tester, 'row0'), const Rect.fromLTWH(6, 6, 188, 20));
      expect(rectOf(tester, 'row1').top, 30);
      expect(rectOf(tester, 'row2').top, 54);
      await tester.drag(find.byType(KkListView), const Offset(0, -500));
      await tester.pump();
      expect(byId('row0'), findsNothing);
      expect(built.any((int i) => i > 20), isTrue);
    });

    testChecked('KkListView without a gap, horizontal, and shrink-wrapped', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 50,
          child: KkListView(
            axis: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (BuildContext context, int index) => box('c$index', 30),
          ),
        ),
      );
      expect(rectOf(tester, 'c1'), const Rect.fromLTWH(30, 0, 30, 50));
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 50,
          child: KkListView(
            axis: Axis.horizontal,
            gap: 5,
            itemCount: 3,
            itemBuilder: (BuildContext context, int index) => box('c$index', 30),
          ),
        ),
      );
      expect(rectOf(tester, 'c1').left, 35);
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          child: KkListView(
            key: const ValueKey<String>('list'),
            shrinkWrap: true,
            gap: 2,
            itemCount: 3,
            itemBuilder: (BuildContext context, int index) => box('c$index', null, 10),
          ),
        ),
      );
      expect(rectOf(tester, 'list').height, 34);
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 50,
          child: KkListView(itemCount: 0, itemBuilder: (BuildContext context, int index) => box('c$index', null, 10)),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testChecked('KkSafeArea', (WidgetTester tester) async {
      const MediaQueryData mq = MediaQueryData(
        size: Size(400, 300),
        padding: EdgeInsets.fromLTRB(5, 24, 7, 10),
        viewInsets: EdgeInsets.only(bottom: 120),
      );
      await pumpRaw(
        tester,
        const MediaQuery(
          data: mq,
          child: SizedBox(width: 400, height: 300, child: KkSafeArea(child: SizedBox.expand(key: ValueKey<String>('a')))),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTRB(5, 24, 393, 180));
      await pumpRaw(
        tester,
        const MediaQuery(
          data: mq,
          child: SizedBox(
            width: 400,
            height: 300,
            child: KkSafeArea(
              keyboard: false,
              left: false,
              top: false,
              child: SizedBox.expand(key: ValueKey<String>('a')),
            ),
          ),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTRB(0, 0, 393, 290));
      // Without a MediaQuery it is transparent.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: KkSafeArea(child: SizedBox.expand(key: ValueKey<String>('a'))),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testChecked('KkSafeArea: what it deals with is gone for its child, the rest is left', (WidgetTester tester) async {
      const MediaQueryData mq = MediaQueryData(
        size: Size(400, 300),
        padding: EdgeInsets.fromLTRB(5, 24, 7, 10),
        viewPadding: EdgeInsets.fromLTRB(5, 24, 7, 10),
        viewInsets: EdgeInsets.only(bottom: 120),
      );
      MediaQueryData? inner;
      Widget probe() => Builder(
        builder: (BuildContext context) {
          inner = MediaQuery.of(context);
          return const SizedBox.expand();
        },
      );
      await pumpRaw(tester, MediaQuery(data: mq, child: KkSafeArea(child: probe())));
      expect(inner!.padding, EdgeInsets.zero);
      expect(inner!.viewInsets, EdgeInsets.zero);
      expect(inner!.size, const Size(400, 300));
      // Sides it was told to leave, and the keyboard, stay for the child.
      await pumpRaw(tester, MediaQuery(data: mq, child: KkSafeArea(top: false, keyboard: false, child: probe())));
      expect(inner!.padding, const EdgeInsets.only(top: 24));
      expect(inner!.viewInsets, const EdgeInsets.only(bottom: 120));
      await pumpRaw(tester, MediaQuery(data: mq, child: KkSafeArea(bottom: false, child: probe())));
      expect(inner!.padding, const EdgeInsets.only(bottom: 10));
      expect(inner!.viewInsets, const EdgeInsets.only(bottom: 120));
      // Nested: the inner one has nothing left to add.
      await pumpRaw(
        tester,
        const MediaQuery(
          data: mq,
          child: SizedBox(
            width: 400,
            height: 300,
            child: KkSafeArea(child: KkSafeArea(child: SizedBox.expand(key: ValueKey<String>('a')))),
          ),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTRB(5, 24, 393, 180));
    });

    testChecked('KkSafeArea paints its fill under the intrusions', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        const MediaQuery(
          data: MediaQueryData(size: Size(400, 300), padding: EdgeInsets.only(top: 24)),
          child: SizedBox(
            width: 400,
            height: 300,
            child: KkSafeArea(fill: Color(0xFF112233), child: SizedBox.expand()),
          ),
        ),
      );
      expect(
        tester.renderObject<RenderBox>(find.byType(KkSafeArea)),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 400, 300), color: const Color(0xFF112233)),
      );
    });
  });
}
