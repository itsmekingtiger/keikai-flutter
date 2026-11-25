import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

void main() {
  List<Widget> abc() => <Widget>[box('a', 40, 20), box('b', 60, 30), box('c', 20, 10)];

  group('KkRow main axis', () {
    testWidgets('lays children out left to right with the gap and centres them', (WidgetTester tester) async {
      await pumpRaw(tester, KkRow(key: const ValueKey<String>('row'), gap: 8, children: abc()));
      expect(rectOf(tester, 'row'), const Rect.fromLTWH(0, 0, 800, 30));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 5, 40, 20));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(48, 0, 60, 30));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(116, 10, 20, 10));
    });

    testWidgets('shrinkWrap takes only the content width', (WidgetTester tester) async {
      await pumpRaw(tester, KkRow(key: const ValueKey<String>('row'), gap: 8, shrinkWrap: true, children: abc()));
      expect(rectOf(tester, 'row').size, const Size(136, 30));
    });

    Future<void> pumpAligned(WidgetTester tester, KkMainAlign main) => pumpRaw(
      tester,
      SizedBox(
        width: 200,
        child: KkRow(gap: 8, main: main, children: abc()),
      ),
    );

    testWidgets('start', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.start);
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'c').left, 116);
    });

    testWidgets('end', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.end);
      expect(rectOf(tester, 'a').left, 64);
      expect(rectOf(tester, 'c').right, 200);
    });

    testWidgets('center', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.center);
      expect(rectOf(tester, 'a').left, 32);
      expect(rectOf(tester, 'c').right, 168);
    });

    testWidgets('between', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.between);
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'b').left, 80);
      expect(rectOf(tester, 'c').left, 180);
    });

    testWidgets('around', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.around);
      expect(rectOf(tester, 'a').left, closeTo(64 / 6, 1e-6));
      expect(rectOf(tester, 'b').left, closeTo(80, 1e-6));
      expect(rectOf(tester, 'c').right, closeTo(200 - 64 / 6, 1e-6));
    });

    testWidgets('evenly', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.evenly);
      expect(rectOf(tester, 'a').left, 16);
      expect(rectOf(tester, 'b').left, 80);
      expect(rectOf(tester, 'c').left, 164);
    });

    testWidgets('between with one child and with none does not divide by zero', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          child: KkRow(main: KkMainAlign.between, children: <Widget>[box('a', 40, 20)]),
        ),
      );
      expect(rectOf(tester, 'a').left, 0);
      for (final KkMainAlign main in KkMainAlign.values) {
        await pumpRaw(tester, SizedBox(width: 200, child: KkRow(key: const ValueKey<String>('row'), main: main)));
        expect(rectOf(tester, 'row').size, const Size(200, 0));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('KkRow cross axis', () {
    Future<void> pumpCross(WidgetTester tester, KkCrossAlign cross) => pumpRaw(
      tester,
      SizedBox(
        height: 50,
        child: KkRow(cross: cross, children: <Widget>[box('a', 40, 20), box('b', 60)]),
      ),
    );

    testWidgets('start', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.start);
      expect(rectOf(tester, 'a').top, 0);
    });

    testWidgets('end', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.end);
      expect(rectOf(tester, 'a').bottom, 50);
    });

    testWidgets('center', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.center);
      expect(rectOf(tester, 'a').top, 15);
    });

    testWidgets('stretch with a tight cross constraint fills it', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.stretch);
      expect(rectOf(tester, 'a').height, 50);
      expect(rectOf(tester, 'b').height, 50);
    });

    testWidgets('stretch with a loose cross constraint matches the largest child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          key: const ValueKey<String>('row'),
          cross: KkCrossAlign.stretch,
          children: <Widget>[box('a', 40, 20), box('b', 60), box('c', 20, 30)],
        ),
      );
      expect(rectOf(tester, 'row').height, 30);
      expect(rectOf(tester, 'a').height, 30);
      expect(rectOf(tester, 'b').height, 30);
      expect(rectOf(tester, 'c').height, 30);
    });

    testWidgets('stretch with an unbounded cross constraint matches the largest child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkRow(
            key: const ValueKey<String>('row'),
            cross: KkCrossAlign.stretch,
            children: <Widget>[box('a', 40, 20), box('b', 60), box('c', 20, 30)],
          ),
        ),
      );
      expect(rectOf(tester, 'row').size, const Size(120, 30));
      expect(rectOf(tester, 'b').height, 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets('alignSelf overrides the line alignment for one child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          height: 50,
          child: KkRow(
            cross: KkCrossAlign.start,
            children: <Widget>[
              box('a', 40, 20),
              KkAlignSelf(align: KkCrossAlign.end, child: box('b', 40, 20)),
              KkAlignSelf(align: KkCrossAlign.stretch, child: box('c', 40)),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'a').top, 0);
      expect(rectOf(tester, 'b').bottom, 50);
      expect(rectOf(tester, 'c').height, 50);
    });

    testWidgets('baseline aligns text of different sizes on one line', (WidgetTester tester) async {
      Widget row() => KkRow(
        key: const ValueKey<String>('row'),
        cross: KkCrossAlign.baseline,
        shrinkWrap: true,
        gap: 4,
        children: <Widget>[
          Text('A', key: const ValueKey<String>('big'), style: testStyle(40)),
          Text('B', key: const ValueKey<String>('small'), style: testStyle(20)),
          box('plain', 10, 8),
        ],
      );
      await pumpRaw(tester, row());
      final double bigBase = baselineOf(tester.renderObject<RenderBox>(byId('big')))!;
      final double smallBase = baselineOf(tester.renderObject<RenderBox>(byId('small')))!;
      expect(bigBase, greaterThan(smallBase));
      // Both baselines land on the same y.
      expect(rectOf(tester, 'big').top + bigBase, closeTo(rectOf(tester, 'small').top + smallBase, 1e-6));
      expect(rectOf(tester, 'big').top, 0);
      expect(rectOf(tester, 'small').top, closeTo(bigBase - smallBase, 1e-6));
      // A child without a baseline sits at the top.
      expect(rectOf(tester, 'plain').top, 0);
      // The row is tall enough for the deepest descent.
      expect(rectOf(tester, 'row').height, closeTo(40, 1e-6));
      // The row reports the shared baseline, dry ...
      final RenderKkFlex flex = tester.renderObject<RenderKkFlex>(byId('row'));
      expect(baselineOf(flex), closeTo(bigBase, 1e-6));
      // ... and to a parent that asks during layout.
      await pumpRaw(tester, Baseline(baseline: 100, baselineType: TextBaseline.alphabetic, child: row()));
      expect(rectOf(tester, 'row').top, closeTo(100 - bigBase, 1e-6));
    });

    testWidgets('baseline row grows when a small font has the deeper descent', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          key: const ValueKey<String>('row'),
          cross: KkCrossAlign.baseline,
          shrinkWrap: true,
          children: <Widget>[
            Text('A', key: const ValueKey<String>('big'), style: testStyle(40)),
            Text('B', key: const ValueKey<String>('tall'), style: testStyle(20).copyWith(height: 3.0)),
          ],
        ),
      );
      final double bigBase = baselineOf(tester.renderObject<RenderBox>(byId('big')))!;
      final double tallBase = baselineOf(tester.renderObject<RenderBox>(byId('tall')))!;
      expect(rectOf(tester, 'tall').top + tallBase, closeTo(rectOf(tester, 'big').top + bigBase, 1e-6));
      expect(rectOf(tester, 'row').height, greaterThanOrEqualTo(rectOf(tester, 'tall').bottom - 1e-6));
      expect(rectOf(tester, 'row').height, greaterThanOrEqualTo(rectOf(tester, 'big').bottom - 1e-6));
    });

    testWidgets('a column reports the baseline of its first child with one', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Baseline(
          baseline: 100,
          baselineType: TextBaseline.alphabetic,
          child: KkColumn(
            key: const ValueKey<String>('col'),
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            gap: 5,
            children: <Widget>[
              box('a', 10, 12),
              Text('A', key: const ValueKey<String>('t'), style: testStyle(20)),
              Text('B', style: testStyle(40)),
            ],
          ),
        ),
      );
      final double textBase = baselineOf(tester.renderObject<RenderBox>(byId('t')))!;
      expect(rectOf(tester, 'col').top, closeTo(100 - (12 + 5 + textBase), 1e-6));
      final RenderKkFlex col = tester.renderObject<RenderKkFlex>(byId('col'));
      expect(baselineOf(col), closeTo(12 + 5 + textBase, 1e-6));
    });
  });

  group('flex shares', () {
    testWidgets('KkExpanded children split the free space by flex', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 300,
          child: KkRow(
            children: <Widget>[
              box('a', 60, 10),
              KkExpanded(child: box('b', null, 10)),
              KkExpanded(flex: 2, child: box('c', null, 10)),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(60, 0, 80, 10));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(140, 0, 160, 10));
    });

    testWidgets('the gap is taken out before the free space is shared', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 300,
          child: KkRow(
            gap: 10,
            children: <Widget>[
              box('a', 60, 10),
              KkExpanded(child: box('b', null, 10)),
              KkExpanded(flex: 2, child: box('c', null, 10)),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'b').width, closeTo(220 / 3, 1e-6));
      expect(rectOf(tester, 'c').width, closeTo(440 / 3, 1e-6));
      expect(rectOf(tester, 'c').right, closeTo(300, 1e-6));
    });

    testWidgets('KkFlexible lets the child stay smaller than its share', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 300,
          child: KkRow(
            children: <Widget>[
              box('a', 60, 10),
              KkFlexible(child: box('b', 30, 10)),
              box('c', 20, 10),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(60, 0, 30, 10));
      expect(rectOf(tester, 'c').left, 90);
    });

    testWidgets('KkFlexible caps the child at its share', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          child: KkRow(
            children: <Widget>[
              box('a', 60, 10),
              KkFlexible(
                child: ConstrainedBox(
                  key: const ValueKey<String>('b'),
                  constraints: const BoxConstraints(minWidth: 0, maxWidth: 500),
                  child: const SizedBox(width: 500, height: 10),
                ),
              ),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'b').width, 40);
    });

    testWidgets('KkSpacer pushes the rest to the far edge', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 300,
          child: KkRow(children: <Widget>[box('a', 60, 10), const KkSpacer(), box('b', 40, 10)]),
        ),
      );
      expect(rectOf(tester, 'b').right, 300);
    });

    testWidgets('flex children in an unbounded main axis keep their own size', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkRow(
            key: const ValueKey<String>('row'),
            gap: 5,
            children: <Widget>[
              box('a', 60, 10),
              KkExpanded(child: box('b', 30, 10)),
              const KkSpacer(),
              box('c', 20, 10),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'b').width, 30);
      expect(rectOf(tester, 'row').width, 60 + 30 + 0 + 20 + 15);
    });

    testWidgets('changing flex through the parent data widget relays out', (WidgetTester tester) async {
      Widget build(int flex) => SizedBox(
        width: 300,
        child: KkRow(
          children: <Widget>[
            KkExpanded(flex: flex, child: box('a', null, 10)),
            KkExpanded(child: box('b', null, 10)),
          ],
        ),
      );
      await pumpRaw(tester, build(1));
      expect(rectOf(tester, 'a').width, 150);
      await pumpRaw(tester, build(2));
      expect(rectOf(tester, 'a').width, 200);
    });
  });

  group('KkColumn', () {
    testWidgets('stretches children to a tight width and stacks them with the gap', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          height: 300,
          child: KkColumn(gap: 6, children: <Widget>[box('a', null, 20), box('b', 50, 30)]),
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 200, 20));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 26, 200, 30));
    });

    testWidgets('with a loose width it is as wide as its widest child and stretches the rest', (
      WidgetTester tester,
    ) async {
      await pumpRaw(
        tester,
        KkColumn(
          key: const ValueKey<String>('col'),
          shrinkWrap: true,
          children: <Widget>[box('a', 120, 20), box('b', null, 4), box('c', 50, 30)],
        ),
      );
      expect(rectOf(tester, 'col').size, const Size(120, 54));
      expect(rectOf(tester, 'b').width, 120);
      expect(rectOf(tester, 'c').width, 120);
    });

    testWidgets('takes the full height unless shrinkWrap', (WidgetTester tester) async {
      await pumpRaw(tester, KkColumn(key: const ValueKey<String>('col'), children: <Widget>[box('a', 10, 20)]));
      expect(rectOf(tester, 'col').height, 600);
      await pumpRaw(
        tester,
        KkColumn(key: const ValueKey<String>('col'), shrinkWrap: true, children: <Widget>[box('a', 10, 20)]),
      );
      expect(rectOf(tester, 'col').height, 20);
    });

    testWidgets('expanded child takes the remaining height', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          height: 300,
          child: KkColumn(
            gap: 10,
            children: <Widget>[box('a', null, 40), KkExpanded(child: box('b')), box('c', null, 20)],
          ),
        ),
      );
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 50, 100, 220));
      expect(rectOf(tester, 'c').bottom, 300);
    });

    testWidgets('a stretched wrapping text reflows and the column follows its new height', (
      WidgetTester tester,
    ) async {
      // In a loose width the column is first as wide as the wide box; the text is
      // then laid out again at that width.
      await pumpRaw(
        tester,
        KkColumn(
          key: const ValueKey<String>('col'),
          shrinkWrap: true,
          children: <Widget>[
            box('wide', 100, 10),
            Text('AAAA AAAA', key: const ValueKey<String>('text'), style: testStyle(10)),
          ],
        ),
      );
      expect(rectOf(tester, 'text').width, 100);
      expect(rectOf(tester, 'col').height, 10 + rectOf(tester, 'text').height);
      expect(rectOf(tester, 'col').width, 100);
    });
  });

  group('KkGap', () {
    testWidgets('follows the direction of the enclosing flex', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[box('a', 10, 10), const KkGap(7, key: ValueKey<String>('gap')), box('b', 10, 10)],
        ),
      );
      expect(rectOf(tester, 'gap').width, 7);
      expect(rectOf(tester, 'b').left, 17);
      await pumpRaw(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[box('a', 10, 10), const KkGap(7, key: ValueKey<String>('gap')), box('b', 10, 10)],
        ),
      );
      expect(rectOf(tester, 'gap').height, 7);
      expect(rectOf(tester, 'gap').width, 0);
      expect(rectOf(tester, 'b').top, 17);
    });

    testWidgets('is a square outside a flex', (WidgetTester tester) async {
      await pumpRaw(tester, const KkGap(9, key: ValueKey<String>('gap')));
      expect(rectOf(tester, 'gap').size, const Size(9, 9));
    });
  });

  group('intrinsics and dry layout', () {
    Widget sample({KkCrossAlign cross = KkCrossAlign.center}) => KkRow(
      key: const ValueKey<String>('row'),
      gap: 8,
      cross: cross,
      shrinkWrap: true,
      children: <Widget>[
        box('a', 40, 20),
        Text('AAAA AAAA', style: testStyle(10)),
        box('c', 20, 30),
      ],
    );

    testWidgets('intrinsic sizes add the gaps', (WidgetTester tester) async {
      await pumpRaw(tester, sample());
      final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
      // 40 + text (9 em squares of 10) + 20 + two gaps.
      expect(row.getMaxIntrinsicWidth(double.infinity), 40 + 90 + 20 + 16);
      // The text can break at the space: its min width is 4 squares.
      expect(row.getMinIntrinsicWidth(double.infinity), 40 + 40 + 20 + 16);
      expect(row.getMaxIntrinsicHeight(double.infinity), 30);
    });

    testWidgets('dry layout equals real layout for several constraints', (WidgetTester tester) async {
      for (final KkCrossAlign cross in <KkCrossAlign>[
        KkCrossAlign.start,
        KkCrossAlign.center,
        KkCrossAlign.end,
        KkCrossAlign.stretch,
      ]) {
        for (final BoxConstraints c in <BoxConstraints>[
          const BoxConstraints(),
          const BoxConstraints(maxWidth: 300),
          const BoxConstraints(maxWidth: 120, maxHeight: 200),
          BoxConstraints.tight(const Size(200, 60)),
          const BoxConstraints(minHeight: 50, maxWidth: 400),
        ]) {
          await pumpRaw(
            tester,
            UnconstrainedBox(
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: ConstrainedBox(constraints: c, child: sample(cross: cross)),
            ),
          );
          tester.takeException();
          final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
          expect(row.getDryLayout(row.constraints), row.size, reason: '$cross under $c');
        }
      }
    });

    testWidgets('IntrinsicHeight and IntrinsicWidth work around a flex', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        IntrinsicWidth(
          key: const ValueKey<String>('iw'),
          child: IntrinsicHeight(
            child: KkRow(
              gap: 8,
              cross: KkCrossAlign.stretch,
              children: <Widget>[box('a', 40, 20), box('b', 10), KkExpanded(child: box('c', null, 30))],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'iw').height, 30);
      expect(rectOf(tester, 'b').height, 30);
    });

    testWidgets('a baseline row can be measured dry by a parent', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          key: const ValueKey<String>('outer'),
          cross: KkCrossAlign.baseline,
          shrinkWrap: true,
          children: <Widget>[
            KkRow(
              key: const ValueKey<String>('inner'),
              cross: KkCrossAlign.baseline,
              shrinkWrap: true,
              children: <Widget>[Text('A', style: testStyle(40)), Text('B', style: testStyle(20))],
            ),
            Text('C', key: const ValueKey<String>('c'), style: testStyle(10)),
          ],
        ),
      );
      final RenderKkFlex outer = tester.renderObject<RenderKkFlex>(byId('outer'));
      final RenderKkFlex inner = tester.renderObject<RenderKkFlex>(byId('inner'));
      expect(outer.getDryLayout(outer.constraints), outer.size);
      // The outer row put C's baseline on the inner row's real baseline; the
      // inner row's dry baseline must be that same distance.
      final double cBase = baselineOf(tester.renderObject<RenderBox>(byId('c')))!;
      final double innerActual = rectOf(tester, 'c').top + cBase - rectOf(tester, 'inner').top;
      expect(baselineOf(inner), closeTo(innerActual, 1e-6));
      expect(baselineOf(outer), closeTo(innerActual, 1e-6));
    });
  });

  group('overflow', () {
    testWidgets('children wider than the row do not throw, with or without clipping', (WidgetTester tester) async {
      for (final Clip clip in <Clip>[Clip.none, Clip.hardEdge]) {
        await pumpRaw(
          tester,
          SizedBox(
            width: 50,
            child: KkRow(key: const ValueKey<String>('row'), clip: clip, children: abc()),
          ),
        );
        expect(tester.takeException(), isNull);
        final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
        expect(row.size.width, 50);
        expect(
          row.describeApproximatePaintClip(row.firstChild!),
          clip == Clip.none ? isNull : const Rect.fromLTWH(0, 0, 50, 30),
        );
      }
    });

    testWidgets('a clipped overflow paints inside a clip layer and stays hit-testable', (WidgetTester tester) async {
      int taps = 0;
      await pumpRaw(
        tester,
        SizedBox(
          width: 50,
          child: KkRow(
            clip: Clip.hardEdge,
            children: <Widget>[
              GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(color: Color(0xFFFF0000), child: SizedBox(width: 40, height: 20)),
              ),
              const RepaintBoundary(child: SizedBox(width: 60, height: 30)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 15));
      expect(taps, 1);
    });
  });

  group('hit testing', () {
    testWidgets('each child takes its own taps and the gap takes none', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget target(String id) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => log.add(id),
        child: const SizedBox(width: 40, height: 40),
      );
      await pumpRaw(tester, KkRow(gap: 20, shrinkWrap: true, children: <Widget>[target('a'), target('b')]));
      await tester.tapAt(const Offset(20, 20));
      await tester.tapAt(const Offset(80, 20));
      await tester.tapAt(const Offset(50, 20), buttons: 1);
      expect(log, <String>['a', 'b']);
    });
  });

  test('render object reports its properties', () {
    final RenderKkFlex flex = RenderKkFlex(direction: Axis.vertical, gap: 4, main: KkMainAlign.center);
    expect(flex.toStringDeep(), contains('gap: 4.0'));
    flex
      ..direction = Axis.horizontal
      ..gap = 6
      ..main = KkMainAlign.end
      ..cross = KkCrossAlign.stretch
      ..shrinkWrap = true
      ..clip = Clip.hardEdge
      ..textBaseline = TextBaseline.ideographic;
    expect(flex.direction, Axis.horizontal);
    expect(flex.gap, 6);
    expect(flex.shrinkWrap, isTrue);
    expect(flex.textBaseline, TextBaseline.ideographic);
  });
}
