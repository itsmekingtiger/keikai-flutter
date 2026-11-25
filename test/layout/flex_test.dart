import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

void main() {
  List<Widget> abc() => <Widget>[box('a', 40, 20), box('b', 60, 30), box('c', 20, 10)];

  group('KkRow main axis', () {
    testChecked('lays children out left to right with the gap and centres them', (WidgetTester tester) async {
      await pumpRaw(tester, KkRow(key: const ValueKey<String>('row'), gap: 8, children: abc()));
      expect(rectOf(tester, 'row'), const Rect.fromLTWH(0, 0, 800, 30));
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 5, 40, 20));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(48, 0, 60, 30));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(116, 10, 20, 10));
    });

    testChecked('shrinkWrap takes only the content width', (WidgetTester tester) async {
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

    testChecked('start', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.start);
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'c').left, 116);
    });

    testChecked('end', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.end);
      expect(rectOf(tester, 'a').left, 64);
      expect(rectOf(tester, 'c').right, 200);
    });

    testChecked('center', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.center);
      expect(rectOf(tester, 'a').left, 32);
      expect(rectOf(tester, 'c').right, 168);
    });

    testChecked('between', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.between);
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'b').left, 80);
      expect(rectOf(tester, 'c').left, 180);
    });

    testChecked('around', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.around);
      expect(rectOf(tester, 'a').left, closeTo(64 / 6, 1e-6));
      expect(rectOf(tester, 'b').left, closeTo(80, 1e-6));
      expect(rectOf(tester, 'c').right, closeTo(200 - 64 / 6, 1e-6));
    });

    testChecked('evenly', (WidgetTester tester) async {
      await pumpAligned(tester, KkMainAlign.evenly);
      expect(rectOf(tester, 'a').left, 16);
      expect(rectOf(tester, 'b').left, 80);
      expect(rectOf(tester, 'c').left, 164);
    });

    testChecked('between with one child and with none does not divide by zero', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 200,
          child: KkRow(main: KkMainAlign.between, children: <Widget>[box('a', 40, 20)]),
        ),
      );
      expect(rectOf(tester, 'a').left, 0);
      for (final KkMainAlign main in KkMainAlign.values) {
        await pumpRaw(
          tester,
          SizedBox(
            width: 200,
            child: KkRow(key: const ValueKey<String>('row'), main: main),
          ),
        );
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

    testChecked('start', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.start);
      expect(rectOf(tester, 'a').top, 0);
    });

    testChecked('end', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.end);
      expect(rectOf(tester, 'a').bottom, 50);
    });

    testChecked('center', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.center);
      expect(rectOf(tester, 'a').top, 15);
    });

    testChecked('stretch with a tight cross constraint fills it', (WidgetTester tester) async {
      await pumpCross(tester, KkCrossAlign.stretch);
      expect(rectOf(tester, 'a').height, 50);
      expect(rectOf(tester, 'b').height, 50);
    });

    testChecked('stretch with a loose cross constraint matches the largest child', (WidgetTester tester) async {
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

    testChecked('stretch with an unbounded cross constraint matches the largest child', (WidgetTester tester) async {
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

    testChecked('alignSelf overrides the line alignment for one child', (WidgetTester tester) async {
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

    testChecked('baseline aligns text of different sizes on one line', (WidgetTester tester) async {
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

    testChecked('baseline row grows when a small font has the deeper descent', (WidgetTester tester) async {
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

    testChecked('a column reports the baseline of its first child with one', (WidgetTester tester) async {
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

    testChecked('the baseline of a column with room to spare follows its main alignment', (WidgetTester tester) async {
      // 200 tall with 12 + 20 + 30 of content and two 5px gaps: 128 to spare.
      const Map<KkMainAlign, double> textTop = <KkMainAlign, double>{
        KkMainAlign.start: 17,
        KkMainAlign.end: 128 + 17,
        KkMainAlign.center: 64 + 17,
        KkMainAlign.between: 12 + 5 + 64,
        KkMainAlign.around: 128 / 6 + 12 + 5 + 128 / 3,
        KkMainAlign.evenly: 32 + 12 + 5 + 32,
      };
      for (final MapEntry<KkMainAlign, double> e in textTop.entries) {
        // The column hangs from a Baseline, which places it by its real
        // baseline; the dry one must be the same distance.
        await pumpRaw(
          tester,
          Baseline(
            baseline: 300,
            baselineType: TextBaseline.alphabetic,
            child: SizedBox(
              width: 200,
              height: 200,
              child: KkColumn(
                key: const ValueKey<String>('col'),
                main: e.key,
                cross: KkCrossAlign.start,
                gap: 5,
                children: <Widget>[
                  box('a', 10, 12),
                  Text('A', key: const ValueKey<String>('t'), style: testStyle(20)),
                  box('b', 10, 30),
                ],
              ),
            ),
          ),
        );
        final double textBase = baselineOf(tester.renderObject<RenderBox>(byId('t')))!;
        final double colTop = rectOf(tester, 'col').top;
        expect(rectOf(tester, 't').top - colTop, closeTo(e.value, 1e-6), reason: '${e.key}');
        expect(colTop, closeTo(300 - (e.value + textBase), 1e-6), reason: '${e.key}');
        final RenderKkFlex col = tester.renderObject<RenderKkFlex>(byId('col'));
        expect(baselineOf(col), closeTo(e.value + textBase, 1e-6), reason: '${e.key}');
      }
    });

    testChecked('a row asked for the other baseline kind still places its children by its own', (
      WidgetTester tester,
    ) async {
      await pumpRaw(
        tester,
        KkRow(
          key: const ValueKey<String>('row'),
          shrinkWrap: true,
          cross: KkCrossAlign.baseline,
          children: <Widget>[
            Text('A', key: const ValueKey<String>('big'), style: testStyle(40)),
            Text('B', key: const ValueKey<String>('small'), style: testStyle(20)),
          ],
        ),
      );
      final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
      final RenderBox small = tester.renderObject<RenderBox>(byId('small'));
      final RenderBox big = tester.renderObject<RenderBox>(byId('big'));
      // The small text sits lower by the difference of the alphabetic
      // baselines; its ideographic baseline is that much lower too.
      final double shift = baselineOf(big)! - baselineOf(small)!;
      expect(rectOf(tester, 'small').top, closeTo(shift, 1e-6));
      final double bigIdeo = big.getDryBaseline(big.constraints, TextBaseline.ideographic)!;
      final double smallIdeo = small.getDryBaseline(small.constraints, TextBaseline.ideographic)!;
      expect(
        row.getDryBaseline(row.constraints, TextBaseline.ideographic),
        closeTo(bigIdeo < smallIdeo + shift ? bigIdeo : smallIdeo + shift, 1e-6),
      );
    });
  });

  group('flex shares', () {
    testChecked('KkExpanded children split the free space by flex', (WidgetTester tester) async {
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

    testChecked('the gap is taken out before the free space is shared', (WidgetTester tester) async {
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

    testChecked('KkFlexible lets the child stay smaller than its share', (WidgetTester tester) async {
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

    testChecked('KkFlexible caps the child at its share', (WidgetTester tester) async {
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

    testChecked('KkSpacer pushes the rest to the far edge', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(width: 300, child: KkRow(children: <Widget>[box('a', 60, 10), const KkSpacer(), box('b', 40, 10)])),
      );
      expect(rectOf(tester, 'b').right, 300);
    });

    testChecked('flex children in an unbounded main axis keep their own size', (WidgetTester tester) async {
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

    testChecked('a child that grows when it is stretched takes its room from the expanded ones', (
      WidgetTester tester,
    ) async {
      // The square is 16 wide while the row is measured, then as wide as the
      // 40px line is tall. The body gives those 24px back instead of ending
      // past the right edge.
      await pumpRaw(
        tester,
        SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: KkRow(
              key: const ValueKey<String>('row'),
              cross: KkCrossAlign.stretch,
              clip: Clip.hardEdge,
              children: <Widget>[
                KkAspect(key: const ValueKey<String>('thumb'), ratio: 1, child: box('seed', 16, 16)),
                KkExpanded(child: box('body', null, 40)),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'row'), const Rect.fromLTWH(0, 0, 300, 40));
      expect(rectOf(tester, 'thumb'), const Rect.fromLTWH(0, 0, 40, 40));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(40, 0, 260, 40));
      final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
      expect(row.describeApproximatePaintClip(row.firstChild!), isNull, reason: 'nothing overflows');
    });

    testChecked('the shares after a stretch follow flex, gap and loose children', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: KkRow(
              key: const ValueKey<String>('row'),
              cross: KkCrossAlign.stretch,
              gap: 10,
              children: <Widget>[
                KkAspect(key: const ValueKey<String>('thumb'), ratio: 1, child: box('seed', 16, 16)),
                KkExpanded(flex: 2, child: box('wide', null, 40)),
                KkExpanded(child: box('narrow', null, 20)),
                KkFlexible(child: box('loose', 30, 10)),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // 300 - 40 (square) - 3 gaps = 230 to share by 2 : 1 : 1.
      expect(rectOf(tester, 'thumb'), const Rect.fromLTWH(0, 0, 40, 40));
      expect(rectOf(tester, 'wide'), const Rect.fromLTWH(50, 0, 115, 40));
      expect(rectOf(tester, 'narrow'), const Rect.fromLTWH(175, 0, 57.5, 40));
      // The loose child stays 30 wide inside its 57.5 share and is stretched.
      expect(rectOf(tester, 'loose'), const Rect.fromLTWH(242.5, 0, 30, 40));
    });

    testChecked('when the new shares make the line taller the stretched children follow once', (
      WidgetTester tester,
    ) async {
      // 106 wide. The text gets 90 at first and wraps to two lines of 10px:
      // the line is 20 tall, the square becomes 20 wide, the text is left 86
      // and needs three lines. The square is stretched to 30 and stays 20 wide.
      await pumpRaw(
        tester,
        SingleChildScrollView(
          child: SizedBox(
            width: 106,
            child: KkRow(
              key: const ValueKey<String>('row'),
              cross: KkCrossAlign.stretch,
              children: <Widget>[
                KkAspect(key: const ValueKey<String>('thumb'), ratio: 1, child: box('seed', 16, 16)),
                KkExpanded(
                  child: Text('AAAA AAAA AAAA', key: const ValueKey<String>('text'), style: testStyle(10)),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'row'), const Rect.fromLTWH(0, 0, 106, 30));
      expect(rectOf(tester, 'thumb'), const Rect.fromLTWH(0, 0, 20, 30));
      expect(rectOf(tester, 'text'), const Rect.fromLTWH(20, 0, 86, 30));
    });

    testChecked('a column in a free width shares again after a child grew taller', (WidgetTester tester) async {
      // Stretched to the 80px width, the aspect box becomes 40 tall instead of 10.
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          constrainedAxis: Axis.vertical,
          child: SizedBox(
            height: 200,
            child: KkColumn(
              key: const ValueKey<String>('column'),
              children: <Widget>[
                KkAspect(key: const ValueKey<String>('banner'), ratio: 2, child: box('seed', 20, 10)),
                KkExpanded(child: box('body', 80)),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'column'), const Rect.fromLTWH(0, 0, 80, 200));
      expect(rectOf(tester, 'banner'), const Rect.fromLTWH(0, 0, 80, 40));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(0, 40, 80, 160));
    });

    testChecked('changing flex through the parent data widget relays out', (WidgetTester tester) async {
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
    testChecked('stretches children to a tight width and stacks them with the gap', (WidgetTester tester) async {
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

    testChecked('with a loose width it is as wide as its widest child and stretches the rest', (
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

    testChecked('takes the full height unless shrinkWrap', (WidgetTester tester) async {
      await pumpRaw(tester, KkColumn(key: const ValueKey<String>('col'), children: <Widget>[box('a', 10, 20)]));
      expect(rectOf(tester, 'col').height, 600);
      await pumpRaw(
        tester,
        KkColumn(key: const ValueKey<String>('col'), shrinkWrap: true, children: <Widget>[box('a', 10, 20)]),
      );
      expect(rectOf(tester, 'col').height, 20);
    });

    testChecked('expanded child takes the remaining height', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          height: 300,
          child: KkColumn(
            gap: 10,
            children: <Widget>[
              box('a', null, 40),
              KkExpanded(child: box('b')),
              box('c', null, 20),
            ],
          ),
        ),
      );
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 50, 100, 220));
      expect(rectOf(tester, 'c').bottom, 300);
    });

    testChecked('a stretched wrapping text reflows and the column follows its new height', (WidgetTester tester) async {
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
    testChecked('follows the direction of the enclosing flex', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            box('a', 10, 10),
            const KkGap(7, key: ValueKey<String>('gap')),
            box('b', 10, 10),
          ],
        ),
      );
      expect(rectOf(tester, 'gap').width, 7);
      expect(rectOf(tester, 'b').left, 17);
      await pumpRaw(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            box('a', 10, 10),
            const KkGap(7, key: ValueKey<String>('gap')),
            box('b', 10, 10),
          ],
        ),
      );
      expect(rectOf(tester, 'gap').height, 7);
      expect(rectOf(tester, 'gap').width, 0);
      expect(rectOf(tester, 'b').top, 17);
    });

    testChecked('is a square outside a flex', (WidgetTester tester) async {
      await pumpRaw(tester, const KkGap(9, key: ValueKey<String>('gap')));
      expect(rectOf(tester, 'gap').size, const Size(9, 9));
    });

    testChecked('turns with its flex even when its constraints stay the same', (WidgetTester tester) async {
      // Unbounded on both axes, a gap is handed the same constraints in a row
      // and in a column, so nothing but the flex can tell it to measure again.
      Widget build(Axis direction) => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: KkFlex(
          key: const ValueKey<String>('flex'),
          direction: direction,
          cross: KkCrossAlign.start,
          children: <Widget>[
            box('a', 10, 10),
            const KkGap(7, key: ValueKey<String>('gap')),
            box('b', 10, 10),
          ],
        ),
      );
      await pumpRaw(tester, build(Axis.horizontal));
      expect(rectOf(tester, 'gap').size, const Size(7, 0));
      expect(rectOf(tester, 'flex').size, const Size(27, 10));
      await pumpRaw(tester, build(Axis.vertical));
      expect(rectOf(tester, 'gap').size, const Size(0, 7));
      expect(rectOf(tester, 'b').topLeft, const Offset(0, 17));
      expect(rectOf(tester, 'flex').size, const Size(10, 27));
      await pumpRaw(tester, build(Axis.horizontal));
      expect(rectOf(tester, 'gap').size, const Size(7, 0));
      expect(rectOf(tester, 'b').topLeft, const Offset(17, 0));
    });

    testChecked('turns with a flex that sits in a row of a scrolling column', (WidgetTester tester) async {
      Widget build(Axis direction) => SingleChildScrollView(
        child: KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkRow(
              shrinkWrap: true,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkFlex(
                  direction: direction,
                  cross: KkCrossAlign.start,
                  shrinkWrap: true,
                  children: <Widget>[
                    box('a', 10, 10),
                    const KkGap(7, key: ValueKey<String>('gap')),
                    box('b', 10, 10),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      await pumpRaw(tester, build(Axis.horizontal));
      expect(rectOf(tester, 'gap').size, const Size(7, 0));
      await pumpRaw(tester, build(Axis.vertical));
      expect(rectOf(tester, 'gap').size, const Size(0, 7));
      expect(rectOf(tester, 'b').topLeft, const Offset(0, 17));
    });

    testChecked('measures again when it moves to another parent', (WidgetTester tester) async {
      final GlobalKey gap = GlobalKey();
      Widget inRow() => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            box('a', 10, 10),
            KkGap(7, key: gap),
          ],
        ),
      );
      Widget inColumn() => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: KkColumn(
          cross: KkCrossAlign.start,
          children: <Widget>[
            box('a', 10, 10),
            KkGap(7, key: gap),
          ],
        ),
      );
      Widget alone() => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: KkGap(7, key: gap),
      );

      await pumpRaw(tester, inRow());
      final RenderBox render = tester.renderObject<RenderBox>(find.byKey(gap));
      expect(render.size, const Size(7, 0));
      await pumpRaw(tester, inColumn());
      expect(tester.renderObject<RenderBox>(find.byKey(gap)), same(render), reason: 'the render object moved');
      expect(render.size, const Size(0, 7));
      await pumpRaw(tester, alone());
      expect(tester.renderObject<RenderBox>(find.byKey(gap)), same(render));
      expect(render.size, const Size(7, 7));
      await pumpRaw(tester, inRow());
      expect(render.size, const Size(7, 0));
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

    testChecked('intrinsic sizes add the gaps', (WidgetTester tester) async {
      await pumpRaw(tester, sample());
      final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
      // 40 + text (9 em squares of 10) + 20 + two gaps.
      expect(row.getMaxIntrinsicWidth(double.infinity), 40 + 90 + 20 + 16);
      // The text can break at the space: its min width is 4 squares.
      expect(row.getMinIntrinsicWidth(double.infinity), 40 + 40 + 20 + 16);
      expect(row.getMaxIntrinsicHeight(double.infinity), 30);
    });

    testChecked('dry layout equals real layout for several constraints', (WidgetTester tester) async {
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
              child: ConstrainedBox(
                constraints: c,
                child: sample(cross: cross),
              ),
            ),
          );
          tester.takeException();
          final RenderKkFlex row = tester.renderObject<RenderKkFlex>(byId('row'));
          expect(row.getDryLayout(row.constraints), row.size, reason: '$cross under $c');
        }
      }
    });

    testChecked('IntrinsicHeight and IntrinsicWidth work around a flex', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        IntrinsicWidth(
          key: const ValueKey<String>('iw'),
          child: IntrinsicHeight(
            child: KkRow(
              gap: 8,
              cross: KkCrossAlign.stretch,
              children: <Widget>[
                box('a', 40, 20),
                box('b', 10),
                KkExpanded(child: box('c', null, 30)),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'iw').height, 30);
      expect(rectOf(tester, 'b').height, 30);
    });

    testChecked('the intrinsic height of a baseline row has room for the deepest descent', (WidgetTester tester) async {
      // A 40px letter (baseline 30 down) beside two 10px lines whose first
      // baseline is 7.5 down: the caption hangs 12.5 below the shared line,
      // the letter only 10, so the row is 42.5 tall, not 40.
      Widget row() => KkRow(
        key: const ValueKey<String>('row'),
        cross: KkCrossAlign.baseline,
        shrinkWrap: true,
        gap: 8,
        children: <Widget>[
          Text('A', style: testStyle(40)),
          KkColumn(
            key: const ValueKey<String>('caption'),
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              Text('B', style: testStyle(10)),
              Text('C', style: testStyle(10)),
            ],
          ),
        ],
      );
      await pumpRaw(tester, SingleChildScrollView(child: row()));
      final RenderBox free = tester.renderObject<RenderBox>(byId('row'));
      expect(free.size.height, 42.5);
      expect(free.getMaxIntrinsicHeight(double.infinity), 42.5);
      expect(free.getMinIntrinsicHeight(double.infinity), 42.5);
      expect(free.getMaxIntrinsicHeight(58), 42.5);

      // A parent that sizes the row from its intrinsic height keeps the caption inside.
      await pumpRaw(tester, IntrinsicHeight(child: row()));
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'row').height, 42.5);
      expect(rectOf(tester, 'caption').bottom, lessThanOrEqualTo(rectOf(tester, 'row').bottom));
    });

    testChecked('the intrinsic height counts the baseline of flexible children at their share', (
      WidgetTester tester,
    ) async {
      // The text gets 40 of the 100 and wraps to two lines of 10px. Its first
      // baseline is 7.5 down, so it hangs 12.5 below the line of the 20px letter
      // (baseline 15): 15 + 12.5.
      final Widget row = KkRow(
        key: const ValueKey<String>('row'),
        cross: KkCrossAlign.baseline,
        children: <Widget>[
          SizedBox(width: 60, child: Text('A', style: testStyle(20))),
          KkExpanded(child: Text('BBBB BBBB', style: testStyle(10))),
        ],
      );
      await pumpRaw(tester, SingleChildScrollView(child: SizedBox(width: 100, child: row)));
      final RenderBox render = tester.renderObject<RenderBox>(byId('row'));
      expect(render.size.height, 27.5);
      expect(render.getMaxIntrinsicHeight(100), 27.5);
      expect(render.getMinIntrinsicHeight(100), 27.5);
    });

    testChecked('a baseline row can be measured dry by a parent', (WidgetTester tester) async {
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
              children: <Widget>[
                Text('A', style: testStyle(40)),
                Text('B', style: testStyle(20)),
              ],
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

    testChecked('a flex inside a flex has the same baseline dry as laid out', (WidgetTester tester) async {
      // The row gives its column no height limit, so the column is as tall as
      // its text and sits in the middle of the 40px row. Asked at the size it
      // ended up with instead, the row would hand the column those 40px, the
      // column would fill them and the text would sit at the top.
      await pumpRaw(
        tester,
        SizedBox(
          width: 300,
          height: 200,
          child: KkColumn(
            key: const ValueKey<String>('outer'),
            children: <Widget>[
              KkRow(
                key: const ValueKey<String>('row'),
                children: <Widget>[
                  KkColumn(
                    key: const ValueKey<String>('inner'),
                    children: <Widget>[Text('A', key: const ValueKey<String>('label'), style: testStyle(8))],
                  ),
                  box('tall', 10, 40),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'inner'), const Rect.fromLTWH(0, 16, 8, 8));
      final double labelBase = baselineOf(tester.renderObject<RenderBox>(byId('label')))!;
      for (final String id in <String>['row', 'outer']) {
        expect(baselineOf(tester.renderObject<RenderBox>(byId(id))), closeTo(16 + labelBase, 1e-6), reason: id);
      }
    });

    testChecked('the dry baseline asks a stretched child at the size of the line', (WidgetTester tester) async {
      // The column is measured 8px tall, then stretched to the 40px line and
      // centres its text in it: its baseline is the one of the second layout.
      await pumpRaw(
        tester,
        KkRow(
          key: const ValueKey<String>('row'),
          cross: KkCrossAlign.stretch,
          shrinkWrap: true,
          children: <Widget>[
            KkColumn(
              shrinkWrap: true,
              main: KkMainAlign.center,
              cross: KkCrossAlign.start,
              children: <Widget>[Text('A', key: const ValueKey<String>('label'), style: testStyle(8))],
            ),
            box('tall', 10, 40),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'label').top, 16);
      final double labelBase = baselineOf(tester.renderObject<RenderBox>(byId('label')))!;
      expect(baselineOf(tester.renderObject<RenderBox>(byId('row'))), closeTo(16 + labelBase, 1e-6));
    });
  });

  group('overflow', () {
    testChecked('children wider than the row do not throw, with or without clipping', (WidgetTester tester) async {
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

    testChecked('a clipped overflow paints inside a clip layer and stays hit-testable', (WidgetTester tester) async {
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
    testChecked('each child takes its own taps and the gap takes none', (WidgetTester tester) async {
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
