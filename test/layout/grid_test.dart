import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

Widget _cell(String id, {int span = 4, int rows = 4, KkSpanBuilder? spanBuilder}) =>
    KkCell(span: span, rows: rows, spanBuilder: spanBuilder, child: box(id));

Future<RenderKkGrid> _pump(WidgetTester tester, double width, KkGrid grid) async {
  await pumpRaw(
    tester,
    KeikaiTheme(
      data: const KeikaiThemeData(),
      child: SizedBox(width: width, child: grid),
    ),
    size: Size(width < 800 ? 800 : width, 2000),
  );
  return tester.renderObject<RenderKkGrid>(find.byType(KkGrid));
}

void main() {
  group('columns', () {
    testChecked('4 / 8 / 12 / 16 / 24 by the width of the grid itself', (WidgetTester tester) async {
      const List<(double, int)> expected = <(double, int)>[
        (320, 4),
        (599, 4),
        (600, 8),
        (839, 8),
        (840, 12),
        (1200, 12),
        (1599, 12),
        (1600, 16),
        (2559, 16),
        (2560, 24),
        (3840, 24),
      ];
      for (final (double width, int columns) in expected) {
        final RenderKkGrid r = await _pump(tester, width, KkGrid(children: <Widget>[_cell('a')]));
        expect(r.resolvedColumns, columns, reason: 'width $width');
      }
    });

    testChecked('a fixed column count overrides the width', (WidgetTester tester) async {
      final RenderKkGrid r = await _pump(tester, 1000, KkGrid(columns: 5, children: <Widget>[_cell('a', span: 2)]));
      expect(r.resolvedColumns, 5);
      expect(rectOf(tester, 'a').width, closeTo((1000 - 4 * 8) / 5 * 2 + 8, 1e-6));
    });
  });

  group('cells', () {
    testChecked('a cell spans columns and rows: n×48 + (n−1)×8 tall', (WidgetTester tester) async {
      await _pump(tester, 840, KkGrid(children: <Widget>[_cell('a', span: 4, rows: 2), _cell('b', span: 8, rows: 1)]));
      const double col = (840 - 11 * 8) / 12;
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'a').width, closeTo(col * 4 + 3 * 8, 1e-6));
      expect(rectOf(tester, 'a').height, 104);
      expect(rectOf(tester, 'b').left, closeTo((col + 8) * 4, 1e-6));
      expect(rectOf(tester, 'b').right, closeTo(840, 1e-6));
      expect(rectOf(tester, 'b').height, 48);
      for (int n = 1; n <= 8; n++) {
        await _pump(tester, 840, KkGrid(children: <Widget>[_cell('a', rows: n)]));
        expect(rectOf(tester, 'a').height, n * 48.0 + (n - 1) * 8.0);
        expect(const KkMetrics().rowsHeight(n), n * 48.0 + (n - 1) * 8.0);
      }
    });

    testChecked('a child that is not a KkCell is 4 columns by 4 rows', (WidgetTester tester) async {
      await _pump(tester, 840, KkGrid(children: <Widget>[box('a')]));
      expect(rectOf(tester, 'a').height, 4 * 48 + 3 * 8);
      expect(rectOf(tester, 'a').width, closeTo((840 - 11 * 8) / 12 * 4 + 3 * 8, 1e-6));
    });

    testChecked('a span never exceeds the columns the grid has', (WidgetTester tester) async {
      await _pump(tester, 400, KkGrid(children: <Widget>[_cell('a', span: 12, rows: 1), _cell('b', span: 8, rows: 1)]));
      expect(rectOf(tester, 'a').width, 400);
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(0, 56, 400, 48));
    });

    testChecked('spanBuilder picks the span from the column count', (WidgetTester tester) async {
      int half(int columns) => columns ~/ 2;
      await _pump(tester, 400, KkGrid(children: <Widget>[_cell('a', spanBuilder: half, rows: 1)]));
      expect(rectOf(tester, 'a').width, closeTo((400 - 24) / 4 * 2 + 8, 1e-6));
      await _pump(tester, 1600, KkGrid(children: <Widget>[_cell('a', spanBuilder: half, rows: 1)]));
      expect(rectOf(tester, 'a').width, closeTo((1600 - 15 * 8) / 16 * 8 + 7 * 8, 1e-6));
    });

    testChecked('the grid is as tall as the rows it used', (WidgetTester tester) async {
      await _pump(
        tester,
        400,
        KkGrid(key: const ValueKey<String>('g'), children: <Widget>[_cell('a', rows: 2), _cell('b', rows: 3)]),
      );
      // Two full-width cells in a 4-column grid: 2 rows, then 3 rows.
      expect(rectOf(tester, 'b').top, 2 * 56.0);
      expect(rectOf(tester, 'g').height, 5 * 48 + 4 * 8);
      await _pump(tester, 400, const KkGrid(key: ValueKey<String>('g'), children: <Widget>[]));
      expect(rectOf(tester, 'g').height, 0);
    });

    testChecked('gutter and row unit can be overridden', (WidgetTester tester) async {
      await _pump(
        tester,
        400,
        KkGrid(
          key: const ValueKey<String>('g'),
          gutter: 4,
          rowUnit: 20,
          children: <Widget>[_cell('a', span: 2, rows: 2), _cell('b', span: 2, rows: 1), _cell('c', span: 2, rows: 1)],
        ),
      );
      expect(rectOf(tester, 'a'), const Rect.fromLTWH(0, 0, 198, 44));
      expect(rectOf(tester, 'b'), const Rect.fromLTWH(202, 0, 198, 20));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(202, 24, 198, 20));
      expect(rectOf(tester, 'g').height, 44);
    });

    testChecked('changing a cell relays the grid out', (WidgetTester tester) async {
      await _pump(tester, 400, KkGrid(children: <Widget>[_cell('a', span: 2, rows: 1)]));
      expect(rectOf(tester, 'a').width, closeTo(196, 1e-6));
      await _pump(tester, 400, KkGrid(children: <Widget>[_cell('a', span: 4, rows: 2)]));
      expect(rectOf(tester, 'a').size, const Size(400, 104));
    });
  });

  group('packing', () {
    // In 4 columns: A takes 3, B needs 2 and wraps, C needs 1.
    List<Widget> abc() => <Widget>[
      _cell('a', span: 3, rows: 1),
      _cell('b', span: 2, rows: 1),
      _cell('c', span: 1, rows: 1),
    ];

    testChecked('dense: a later, smaller cell moves up into the hole', (WidgetTester tester) async {
      await _pump(tester, 400, KkGrid(children: abc()));
      expect(rectOf(tester, 'a').topLeft, Offset.zero);
      expect(rectOf(tester, 'b').topLeft, const Offset(0, 56));
      expect(rectOf(tester, 'c').top, 0);
      expect(rectOf(tester, 'c').right, 400);
    });

    testChecked('ordered: cells never move back', (WidgetTester tester) async {
      await _pump(tester, 400, KkGrid(dense: false, children: abc()));
      expect(rectOf(tester, 'b').topLeft, const Offset(0, 56));
      expect(rectOf(tester, 'c').top, 56);
      expect(rectOf(tester, 'c').left, closeTo(2 * (94 + 8), 1e-6));
    });

    testChecked('a tall cell blocks the rows under it', (WidgetTester tester) async {
      await _pump(
        tester,
        400,
        KkGrid(
          children: <Widget>[
            _cell('tall', span: 2, rows: 3),
            _cell('a', span: 2, rows: 1),
            _cell('b', span: 2, rows: 1),
            _cell('wide', span: 4, rows: 1),
            _cell('c', span: 2, rows: 1),
          ],
        ),
      );
      expect(rectOf(tester, 'tall'), const Rect.fromLTWH(0, 0, 196, 160));
      expect(rectOf(tester, 'a').topLeft, const Offset(204, 0));
      expect(rectOf(tester, 'b').topLeft, const Offset(204, 56));
      // The wide cell cannot fit beside the tall one.
      expect(rectOf(tester, 'wide').topLeft, const Offset(0, 168));
      // Dense packing puts the last cell into the hole in row 2.
      expect(rectOf(tester, 'c').topLeft, const Offset(204, 112));
    });

    testChecked('no two cells overlap in a busy grid', (WidgetTester tester) async {
      final List<Widget> cells = <Widget>[
        for (int i = 0; i < 24; i++) _cell('c$i', span: 1 + (i * 7) % 5, rows: 1 + (i * 3) % 4),
      ];
      for (final bool dense in <bool>[true, false]) {
        await _pump(tester, 1000, KkGrid(dense: dense, children: cells));
        final List<Rect> rects = <Rect>[for (int i = 0; i < 24; i++) rectOf(tester, 'c$i')];
        for (int i = 0; i < rects.length; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(0));
          expect(rects[i].right, lessThanOrEqualTo(1000 + 1e-6));
          for (int j = i + 1; j < rects.length; j++) {
            expect(rects[i].deflate(0.01).overlaps(rects[j].deflate(0.01)), isFalse, reason: 'cells $i and $j');
          }
        }
      }
    });
  });

  group('stagger', () {
    testChecked('each cell is told its index', (WidgetTester tester) async {
      final Map<String, int> seen = <String, int>{};
      Widget probe(String id) => Builder(
        builder: (BuildContext context) {
          seen[id] = KkStagger.of(context);
          return const SizedBox.shrink();
        },
      );
      await _pump(
        tester,
        840,
        KkGrid(children: <Widget>[KkCell(child: probe('a')), probe('b'), KkCell(span: 2, child: probe('c'))]),
      );
      expect(seen, <String, int>{'a': 0, 'b': 1, 'c': 2});
    });

    testChecked('indices continue from an outer stagger, and can be turned off', (WidgetTester tester) async {
      final Map<String, int> seen = <String, int>{};
      Widget probe(String id) => Builder(
        builder: (BuildContext context) {
          seen[id] = KkStagger.of(context);
          return const SizedBox.shrink();
        },
      );
      await pumpRaw(
        tester,
        KkStagger(
          index: 10,
          child: SizedBox(
            width: 840,
            child: KkGrid(children: <Widget>[KkCell(child: probe('a')), KkCell(child: probe('b'))]),
          ),
        ),
        size: const Size(840, 2000),
      );
      expect(seen, <String, int>{'a': 10, 'b': 11});
      seen.clear();
      await pumpRaw(
        tester,
        KkStagger(
          index: 10,
          child: SizedBox(
            width: 840,
            child: KkGrid(stagger: false, children: <Widget>[KkCell(child: probe('a')), KkCell(child: probe('b'))]),
          ),
        ),
        size: const Size(840, 2000),
      );
      expect(seen, <String, int>{'a': 10, 'b': 10});
    });

    testChecked('a cell keeps its span, rows and key when it is given its index', (WidgetTester tester) async {
      await _pump(
        tester,
        840,
        KkGrid(children: <Widget>[KkCell(key: const ValueKey<String>('cell'), span: 6, rows: 2, child: box('a'))]),
      );
      expect(find.byKey(const ValueKey<String>('cell')), findsOneWidget);
      expect(rectOf(tester, 'a').height, 104);
      expect(rectOf(tester, 'a').width, closeTo((840 - 88) / 12 * 6 + 5 * 8, 1e-6));
    });
  });

  group('measuring', () {
    testChecked('intrinsic height and dry layout match the real layout', (WidgetTester tester) async {
      final RenderKkGrid r = await _pump(
        tester,
        840,
        KkGrid(children: <Widget>[_cell('a', span: 8, rows: 2), _cell('b', span: 8, rows: 3), _cell('c', span: 4, rows: 1)]),
      );
      expect(r.size.height, 5 * 48 + 4 * 8);
      expect(r.resolvedRows, 5);
      expect(r.getMinIntrinsicHeight(840), r.size.height);
      expect(r.getMaxIntrinsicHeight(840), r.size.height);
      expect(r.getDryLayout(r.constraints), r.size);
      // Narrower: 4 columns, every cell is full width.
      expect(r.getMinIntrinsicHeight(400), 6 * 48 + 5 * 8);
      // Measuring at another width must not disturb the real placement.
      await tester.pump();
      expect(rectOf(tester, 'c').top, 0);
    });

    testChecked('inside a scroll view it takes its content height', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        SizedBox(
          width: 400,
          height: 300,
          child: KkScroll(
            child: KkGrid(
              key: const ValueKey<String>('g'),
              children: <Widget>[_cell('a', rows: 4), _cell('b', rows: 4)],
            ),
          ),
        ),
      );
      expect(tester.getSize(byId('g')).height, 8 * 48 + 7 * 8);
      expect(tester.takeException(), isNull);
    });

    testChecked('a zero-width grid does not throw', (WidgetTester tester) async {
      await pumpRaw(tester, SizedBox(width: 0, child: KkGrid(children: <Widget>[_cell('a'), _cell('b', span: 1)])));
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'a').width, 0);
    });
  });
}
