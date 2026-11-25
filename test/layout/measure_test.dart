import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

// Measuring without laying out. A parent may ask any box for its size or its
// baseline "dry" (a wrap measuring its rows, a paragraph placing an inline
// widget, an intrinsic-height pass). A box that cannot answer asserts in debug
// builds, so every KEIKAI layout box answers, and answers what the real layout
// would give. The second half is checked by the framework itself: every test
// here runs through [testChecked].

RenderBox _render(WidgetTester tester, String id) => tester.renderObject<RenderBox>(byId(id));

void main() {
  group('a baseline row measured dry', () {
    testChecked('holds every kind of layout box without asserting', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Baseline(
          baseline: 300,
          baselineType: TextBaseline.alphabetic,
          child: KkRow(
            key: const ValueKey<String>('row'),
            shrinkWrap: true,
            cross: KkCrossAlign.baseline,
            gap: 4,
            children: <Widget>[
              Text('A', style: testStyle(20)),
              const KkGap(8),
              KkWrap(children: <Widget>[Text('B', style: testStyle(10))]),
              KkLayers(children: <Widget>[Text('C', style: testStyle(30))]),
              KkBox(padding: const EdgeInsets.all(3), child: Text('D', style: testStyle(10))),
              SizedBox(width: 30, child: KkAspect(ratio: 1, child: Text('E', style: testStyle(10)))),
              SizedBox(
                width: 96,
                child: KkGrid(
                  children: <Widget>[KkCell(rows: 1, child: Text('F', style: testStyle(10)))],
                ),
              ),
              SizedBox(
                width: 108,
                height: 40,
                child: KkSplit(first: Text('G', style: testStyle(10)), second: Text('H', style: testStyle(10))),
              ),
              KkColumn(shrinkWrap: true, cross: KkCrossAlign.start, children: <Widget>[Text('I', style: testStyle(10))]),
              const KkSized(width: 4, height: 4),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final RenderBox row = _render(tester, 'row');
      // Asked from outside a layout pass, as a measuring parent would.
      expect(row.getDryLayout(row.constraints), row.size);
      for (final TextBaseline kind in TextBaseline.values) {
        expect(row.getDryBaseline(row.constraints, kind), isNotNull, reason: '$kind');
      }
      // The row hangs from the Baseline widget by its real baseline, which is
      // that of its largest text (30px, the one in the layers).
      final double dry = row.getDryBaseline(row.constraints, TextBaseline.alphabetic)!;
      expect(rectOf(tester, 'row').top, closeTo(300 - dry, 1e-6));
      final double big = baselineOf(tester.renderObject<RenderBox>(find.text('C')))!;
      expect(dry, closeTo(big, 1e-6));
    });

    testChecked('boxes without a baseline say so', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          shrinkWrap: true,
          cross: KkCrossAlign.baseline,
          children: <Widget>[
            const KkGap(8, key: ValueKey<String>('gap')),
            SizedBox(
              width: 96,
              child: KkGrid(
                key: const ValueKey<String>('grid'),
                children: <Widget>[KkCell(rows: 1, child: Text('F', style: testStyle(10)))],
              ),
            ),
            SizedBox(
              width: 108,
              height: 40,
              child: KkSplit(
                key: const ValueKey<String>('split'),
                first: Text('G', style: testStyle(10)),
                second: Text('H', style: testStyle(10)),
              ),
            ),
            KkWrap(key: const ValueKey<String>('wrap'), children: <Widget>[box('a', 10, 10)]),
            KkLayers(key: const ValueKey<String>('layers'), children: <Widget>[box('b', 10, 10)]),
            const KkBox(key: ValueKey<String>('box'), width: 10, height: 10),
            const SizedBox(width: 10, child: KkAspect(key: ValueKey<String>('aspect'), ratio: 1)),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      for (final String id in <String>['gap', 'grid', 'split', 'wrap', 'layers', 'box', 'aspect']) {
        final RenderBox r = id == 'grid' || id == 'split'
            ? tester.renderObject<RenderBox>(
                find.descendant(of: byId(id), matching: find.byWidgetPredicate((Widget w) => w is RenderObjectWidget)).first,
              )
            : _render(tester, id);
        for (final TextBaseline kind in TextBaseline.values) {
          expect(r.getDryBaseline(r.constraints, kind), isNull, reason: '$id $kind');
        }
      }
    });
  });

  group('KkWrap baseline', () {
    testChecked('is the highest baseline of its first row, whatever the cross alignment', (WidgetTester tester) async {
      for (final KkCrossAlign cross in <KkCrossAlign>[KkCrossAlign.start, KkCrossAlign.center, KkCrossAlign.end]) {
        await pumpRaw(
          tester,
          Baseline(
            baseline: 200,
            baselineType: TextBaseline.alphabetic,
            child: SizedBox(
              width: 100,
              child: KkWrap(
                key: const ValueKey<String>('w'),
                gap: 10,
                cross: cross,
                children: <Widget>[
                  // 40 + 10 + 20 fits in 100; the third starts a new row.
                  Text('A', key: const ValueKey<String>('big'), style: testStyle(40)),
                  Text('B', key: const ValueKey<String>('small'), style: testStyle(20)),
                  Text('C', key: const ValueKey<String>('next'), style: testStyle(40)),
                ],
              ),
            ),
          ),
        );
        final double big = baselineOf(_render(tester, 'big'))!;
        final double small = baselineOf(_render(tester, 'small'))!;
        // The first row is 40 tall; the small text sits at 0, 10 or 20 in it.
        final double smallTop = switch (cross) {
          KkCrossAlign.center => 10,
          KkCrossAlign.end => 20,
          _ => 0,
        };
        final double top = rectOf(tester, 'w').top;
        expect(rectOf(tester, 'small').top - top, smallTop, reason: '$cross');
        expect(rectOf(tester, 'next').top - top, 50, reason: '$cross');
        final double expected = math.min(big, smallTop + small);
        expect(baselineOf(_render(tester, 'w')), closeTo(expected, 1e-6), reason: '$cross');
        expect(top, closeTo(200 - expected, 1e-6), reason: '$cross');
      }
    });

    testChecked('a row of boxes above text: the text row gives the baseline', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          child: KkWrap(
            key: const ValueKey<String>('w'),
            gap: 10,
            runGap: 6,
            cross: KkCrossAlign.start,
            children: <Widget>[box('a', 90, 12), Text('A', key: const ValueKey<String>('t'), style: testStyle(20))],
          ),
        ),
      );
      final double text = baselineOf(_render(tester, 't'))!;
      expect(baselineOf(_render(tester, 'w')), closeTo(12 + 6 + text, 1e-6));
    });

    testChecked('a wrap of text sits on the baseline of the label beside it', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          shrinkWrap: true,
          cross: KkCrossAlign.baseline,
          gap: 8,
          children: <Widget>[
            Text('L', key: const ValueKey<String>('label'), style: testStyle(40)),
            KkWrap(gap: 4, children: <Widget>[Text('a', key: const ValueKey<String>('tag'), style: testStyle(10))]),
          ],
        ),
      );
      final double label = baselineOf(_render(tester, 'label'))!;
      final double tag = baselineOf(_render(tester, 'tag'))!;
      expect(rectOf(tester, 'tag').top, closeTo(label - tag, 1e-6));
    });
  });

  group('KkLayers baseline', () {
    testChecked('follows the alignment and the pinned children', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Baseline(
          baseline: 300,
          baselineType: TextBaseline.alphabetic,
          child: KkLayers(
            key: const ValueKey<String>('l'),
            alignment: Alignment.bottomRight,
            children: <Widget>[
              box('size', 200, 120),
              // Bottom right by the stack's alignment: 100 down.
              Text('A', key: const ValueKey<String>('a'), style: testStyle(20)),
              // Pinned 50 above the bottom: 120 - 50 - 40 = 30 down.
              KkPositioned(left: 10, bottom: 50, child: Text('B', key: const ValueKey<String>('b'), style: testStyle(40))),
              // Centred by its own alignment: 55 down.
              KkLayerAlign(alignment: Alignment.center, child: Text('C', key: const ValueKey<String>('c'), style: testStyle(10))),
              // Stretched between two edges, pinned to the top.
              KkPositioned(left: 0, right: 0, top: 90, child: Text('D', key: const ValueKey<String>('d'), style: testStyle(10))),
            ],
          ),
        ),
      );
      final double top = rectOf(tester, 'l').top;
      expect(rectOf(tester, 'a').top - top, 100);
      expect(rectOf(tester, 'b').top - top, 30);
      expect(rectOf(tester, 'c').top - top, 55);
      expect(rectOf(tester, 'd').top - top, 90);
      final double expected = <double>[
        100 + baselineOf(_render(tester, 'a'))!,
        30 + baselineOf(_render(tester, 'b'))!,
        55 + baselineOf(_render(tester, 'c'))!,
        90 + baselineOf(_render(tester, 'd'))!,
      ].reduce(math.min);
      expect(baselineOf(_render(tester, 'l')), closeTo(expected, 1e-6));
      expect(top, closeTo(300 - expected, 1e-6));
    });
  });

  group('KkAspect baseline', () {
    testChecked('is its child\'s, at the size the ratio gives', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Baseline(
          baseline: 100,
          baselineType: TextBaseline.alphabetic,
          child: SizedBox(
            width: 60,
            child: KkAspect(
              key: const ValueKey<String>('aspect'),
              ratio: 2,
              child: Text('A', key: const ValueKey<String>('t'), style: testStyle(20)),
            ),
          ),
        ),
      );
      expect(rectOf(tester, 'aspect').size, const Size(60, 30));
      final double text = baselineOf(_render(tester, 't'))!;
      expect(baselineOf(_render(tester, 'aspect')), closeTo(text, 1e-6));
      expect(rectOf(tester, 'aspect').top, closeTo(100 - text, 1e-6));
    });
  });

  group('measured by Flutter\'s own widgets', () {
    testChecked('IntrinsicHeight and IntrinsicWidth around a wrap of baseline rows', (WidgetTester tester) async {
      // The wrap finds its height by measuring its children dry; they are
      // baseline rows holding a gap, which has to answer for its baseline.
      Widget chip(String id) => KkRow(
        key: ValueKey<String>(id),
        shrinkWrap: true,
        cross: KkCrossAlign.baseline,
        children: <Widget>[Text('A', style: testStyle(20)), const KkGap(6), Text('b', style: testStyle(10))],
      );
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          child: IntrinsicHeight(
            child: KkWrap(key: const ValueKey<String>('w'), gap: 8, children: <Widget>[chip('a'), chip('b'), chip('c')]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // 36 wide chips: two on a row (36 + 8 + 36 = 80), the third below.
      expect(rectOf(tester, 'w').size, const Size(100, 48));
      expect(rectOf(tester, 'c').topLeft, const Offset(0, 28));
      final RenderBox wrap = _render(tester, 'w');
      expect(wrap.getMinIntrinsicHeight(100), 48);
      expect(wrap.getMaxIntrinsicHeight(60), 76);
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(
            child: KkWrap(key: const ValueKey<String>('w'), gap: 8, children: <Widget>[chip('a'), chip('b'), chip('c')]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'w').size, const Size(124, 20));
    });

    testChecked('a baseline row that was measured first still puts its children on one baseline', (
      WidgetTester tester,
    ) async {
      // IntrinsicHeight makes the wrap measure the row dry before anything is
      // laid out. A box keeps the dry and the real baseline of a child in one
      // cache, so a dry baseline that differs from the real one moves the
      // label off the line of the value in the real layout.
      Widget block() => KkRow(
        cross: KkCrossAlign.baseline,
        shrinkWrap: true,
        gap: 8,
        children: <Widget>[
          KkColumn(
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkRow(
                shrinkWrap: true,
                children: <Widget>[
                  KkColumn(children: <Widget>[Text('A', key: const ValueKey<String>('label'), style: testStyle(8))]),
                  box('tall', 10, 40),
                ],
              ),
            ],
          ),
          Text('B', key: const ValueKey<String>('value'), style: testStyle(20)),
        ],
      );
      for (final bool measured in <bool>[false, true]) {
        final Widget wrap = KkWrap(children: <Widget>[block()]);
        await pumpRaw(tester, measured ? IntrinsicHeight(child: wrap) : wrap);
        expect(tester.takeException(), isNull, reason: 'measured first: $measured');
        // The label is centred in the 40px row: its baseline is 16 + 6 down,
        // and the 20px value (baseline 15 down) is moved to meet it.
        final double label = rectOf(tester, 'label').top + baselineOf(_render(tester, 'label'))!;
        final double value = rectOf(tester, 'value').top + baselineOf(_render(tester, 'value'))!;
        expect(label, closeTo(22, 1e-6), reason: 'measured first: $measured');
        expect(value, closeTo(22, 1e-6), reason: 'measured first: $measured');
      }
    });

    testChecked('inline in a paragraph, on its baseline', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        Text.rich(
          TextSpan(
            style: testStyle(20),
            children: <InlineSpan>[
              const TextSpan(text: 'AA'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: KkRow(
                  key: const ValueKey<String>('row'),
                  shrinkWrap: true,
                  cross: KkCrossAlign.baseline,
                  children: <Widget>[
                    const KkGap(4),
                    KkBox(
                      key: const ValueKey<String>('box'),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text('b', key: const ValueKey<String>('small'), style: testStyle(10)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          key: const ValueKey<String>('p'),
        ),
      );
      expect(tester.takeException(), isNull);
      // The small text shares the baseline of the 20px text around it.
      final double line = baselineOf(_render(tester, 'p'))!;
      final double small = baselineOf(_render(tester, 'small'))!;
      expect(rectOf(tester, 'small').top - rectOf(tester, 'p').top, closeTo(line - small, 1e-6));
      expect(rectOf(tester, 'row').left, 40);
    });
  });
}
