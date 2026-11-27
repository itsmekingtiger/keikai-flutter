import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

/// A row of single columns, then cells of every span the grid allows. Dense
/// packing starts them at many different columns.
List<Widget> _ruler(int columns) => <Widget>[
  for (int c = 0; c < columns; c++) _cell('t$c', span: 1, rows: 1),
  for (int span = 2; span <= columns; span++) _cell('s$span', span: span, rows: 1),
  for (int span = columns - 1; span >= 1; span--) _cell('r$span', span: span, rows: 1),
];

/// Where the last layout put every child of [grid]: its first column, the
/// columns it spans and its left and right edges.
List<({int column, int span, double left, double right})> _placed(RenderKkGrid grid) {
  final List<({int column, int span, double left, double right})> cells =
      <({int column, int span, double left, double right})>[];
  for (RenderBox? child = grid.firstChild; child != null; child = grid.childAfter(child)) {
    final KkGridParentData pd = child.parentData! as KkGridParentData;
    cells.add((column: pd.column, span: pd.placedSpan, left: pd.offset.dx, right: pd.offset.dx + child.size.width));
  }
  return cells;
}

/// Checks a laid out [_ruler]: its first row is the tracks of the grid. They
/// start at the left edge and end at [width], [gutter] apart, and every other
/// cell starts with its first track and ends with its last one. Returns the
/// tracks.
List<({int column, int span, double left, double right})> _expectTiled(
  RenderKkGrid grid,
  double width, {
  double gutter = 8,
  double tolerance = 0,
}) {
  final String at = 'at width $width';
  final int columns = grid.resolvedColumns;
  final List<({int column, int span, double left, double right})> cells = _placed(grid);
  final List<({int column, int span, double left, double right})> tracks = cells.sublist(0, columns);
  for (int c = 0; c < columns; c++) {
    expect((tracks[c].column, tracks[c].span), (c, 1), reason: 'track $c $at');
    expect(tracks[c].right, greaterThanOrEqualTo(tracks[c].left), reason: 'track $c $at');
    if (c > 0) expect(tracks[c].left - tracks[c - 1].right, closeTo(gutter, tolerance), reason: 'gutter $c $at');
  }
  expect(tracks.first.left, 0, reason: at);
  expect(tracks.last.right, closeTo(width, tolerance), reason: at);
  for (final ({int column, int span, double left, double right}) cell in cells) {
    final String which = 'span ${cell.span} from column ${cell.column} $at';
    expect(cell.left, closeTo(tracks[cell.column].left, tolerance), reason: which);
    expect(cell.right, closeTo(tracks[cell.column + cell.span - 1].right, tolerance), reason: which);
  }
  return tracks;
}

/// The red channel of row [y] of what the repaint boundary [id] painted, one
/// value for every pixel.
Future<List<int>> _redRow(WidgetTester tester, String id, int y) async {
  final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(byId(id));
  late ByteData bytes;
  late int width;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    width = image.width;
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  return <int>[for (int x = 0; x < width; x++) bytes.getUint8((y * width + x) * 4)];
}

/// Logs when its state is made and thrown away, and notes the stagger index
/// it is built with.
class _Probe extends StatefulWidget {
  const _Probe({super.key, required this.id, required this.log, this.seen});

  final String id;
  final List<String> log;
  final Map<String, int>? seen;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init ${widget.id}');
  }

  @override
  void dispose() {
    widget.log.add('dispose ${widget.id}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.seen?[widget.id] = KkStagger.of(context);
    return const SizedBox.shrink();
  }
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
      // Two columns of (1000 − 4×8) / 5 = 193.6px and the gutter between them, in whole pixels.
      expect(rectOf(tester, 'a').width, 395);
    });
  });

  group('cells', () {
    testChecked('a cell spans columns and rows: n×48 + (n−1)×8 tall', (WidgetTester tester) async {
      await _pump(tester, 840, KkGrid(children: <Widget>[_cell('a', span: 4, rows: 2), _cell('b', span: 8, rows: 1)]));
      // A column is (840 − 11×8) / 12 = 62.67px: four of them and three gutters come to 274.67px, and the fifth
      // column starts 8px further on. Both are placed on whole pixels.
      expect(rectOf(tester, 'a').left, 0);
      expect(rectOf(tester, 'a').width, 275);
      expect(rectOf(tester, 'a').height, 104);
      expect(rectOf(tester, 'b').left, 283);
      expect(rectOf(tester, 'b').right, 840);
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
      // Four columns of (840 − 11×8) / 12 = 62.67px and three gutters, in whole pixels.
      expect(rectOf(tester, 'a').width, 275);
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

  group('whole pixels', () {
    testChecked('columns that do not divide evenly start and end on whole pixels', (WidgetTester tester) async {
      // 12 columns of (840 − 11×8) / 12 = 62.67px: six cells of two columns.
      final RenderKkGrid r = await _pump(
        tester,
        840,
        KkGrid(children: <Widget>[for (int i = 0; i < 6; i++) _cell('c$i', span: 2, rows: 1)]),
      );
      final List<({int column, int span, double left, double right})> cells = _placed(r);
      expect(cells.map((({int column, int span, double left, double right}) c) => c.left), <double>[
        0,
        141,
        283,
        424,
        565,
        707,
      ]);
      expect(cells.map((({int column, int span, double left, double right}) c) => c.right), <double>[
        133,
        275,
        416,
        557,
        699,
        840,
      ]);
    });

    testChecked('at every width the gutters are exact, the tracks fill the grid and a span is its tracks', (
      WidgetTester tester,
    ) async {
      final List<double> widths = <double>[
        for (double w = 300; w <= 2700; w += 37) w,
        // Every remainder of each column count.
        for (double w = 320; w < 324; w++) w,
        for (double w = 600; w < 608; w++) w,
        for (double w = 840; w < 852; w++) w,
        for (double w = 1600; w < 1616; w++) w,
        for (double w = 2560; w < 2584; w++) w,
      ];
      for (final double width in widths) {
        final int columns = const KkMetrics().columnsFor(width);
        final RenderKkGrid r = await _pump(tester, width, KkGrid(children: _ruler(columns)));
        expect(r.resolvedColumns, columns);
        final List<({int column, int span, double left, double right})> tracks = _expectTiled(r, width);
        // No track is more than half a pixel from its exact share, so no two differ by more than a pixel.
        final double share = (width - 8 * (columns - 1)) / columns;
        for (int c = 0; c < columns; c++) {
          final String which = 'track $c at width $width';
          expect(tracks[c].left, tracks[c].left.roundToDouble(), reason: which);
          expect(tracks[c].right, tracks[c].right.roundToDouble(), reason: which);
          expect(tracks[c].left, closeTo(c * (share + 8), 0.5 + 1e-9), reason: which);
          expect(tracks[c].right - tracks[c].left, closeTo(share, 1), reason: which);
        }
      }
    });

    testChecked('a width that divides evenly is laid out in equal columns, as it always was', (
      WidgetTester tester,
    ) async {
      for (final (double width, int columns, double track) in <(double, int, double)>[
        (400, 4, 94),
        (616, 8, 70),
        (1336, 12, 104),
        (1816, 16, 106),
        (2584, 24, 100),
      ]) {
        final RenderKkGrid r = await _pump(tester, width, KkGrid(children: _ruler(columns)));
        expect(r.resolvedColumns, columns);
        _expectTiled(r, width);
        for (final ({int column, int span, double left, double right}) cell in _placed(r)) {
          final String which = 'span ${cell.span} from column ${cell.column} at width $width';
          expect(cell.left, cell.column * (track + 8), reason: which);
          expect(cell.right - cell.left, track * cell.span + 8 * (cell.span - 1), reason: which);
        }
      }
    });

    testChecked('a fixed column count shares the width in whole pixels too', (WidgetTester tester) async {
      // (1000 − 4×8) / 5 = 193.6px a column.
      final RenderKkGrid r = await _pump(tester, 1000, KkGrid(columns: 5, children: _ruler(5)));
      final List<({int column, int span, double left, double right})> tracks = _expectTiled(r, 1000);
      expect(tracks.map((({int column, int span, double left, double right}) t) => t.right - t.left), <double>[
        194,
        193,
        194,
        193,
        194,
      ]);
    });

    testChecked('a grid of a fractional width keeps the fraction in its last column', (WidgetTester tester) async {
      for (final double width in <double>[840.5, 1365.25, 2001.75, 613.3]) {
        final int columns = const KkMetrics().columnsFor(width);
        final RenderKkGrid r = await _pump(tester, width, KkGrid(children: _ruler(columns)));
        final List<({int column, int span, double left, double right})> tracks = _expectTiled(
          r,
          width,
          tolerance: 1e-9,
        );
        for (int c = 0; c < columns; c++) {
          expect(tracks[c].left, tracks[c].left.roundToDouble(), reason: 'track $c at width $width');
        }
        expect(r.size.width, width);
      }
    });

    testChecked('an overridden gutter stays exact between columns of whole pixels', (WidgetTester tester) async {
      // 12 columns share 1000 − 11×4.5 = 950.5px.
      final RenderKkGrid r = await _pump(tester, 1000, KkGrid(gutter: 4.5, children: _ruler(12)));
      final List<({int column, int span, double left, double right})> tracks = _expectTiled(
        r,
        1000,
        gutter: 4.5,
        tolerance: 1e-9,
      );
      for (int c = 0; c < 11; c++) {
        final double width = tracks[c].right - tracks[c].left;
        expect(width, closeTo(width.roundToDouble(), 1e-9), reason: 'track $c');
        expect(width, closeTo(950.5 / 12, 1));
      }
    });

    testChecked('a grid with less room than a pixel a column never makes a cell of negative width', (
      WidgetTester tester,
    ) async {
      for (final (double width, int columns) in <(double, int)>[(88.6, 12), (89.5, 12), (24.6, 4), (30, 4), (7, 4)]) {
        final RenderKkGrid r = await _pump(tester, width, KkGrid(columns: columns, children: _ruler(columns)));
        expect(tester.takeException(), isNull, reason: 'width $width');
        final double gutter = width < 8.0 * (columns - 1) ? width / (columns - 1) : 8;
        _expectTiled(r, width, gutter: gutter, tolerance: 1e-9);
      }
    });

    testChecked('the 1px border of a cell covers one column of pixels', (WidgetTester tester) async {
      const Color white = Color(0xFFFFFFFF);
      await pumpRaw(
        tester,
        KeikaiTheme(
          data: const KeikaiThemeData(),
          child: RepaintBoundary(
            key: const ValueKey<String>('paint'),
            child: SizedBox(
              width: 840,
              child: KkGrid(
                children: <Widget>[
                  for (int i = 0; i < 6; i++) KkCell(span: 2, rows: 1, child: KkBox(edges: KkEdges.line(white))),
                ],
              ),
            ),
          ),
        ),
        size: const Size(840, 100),
      );
      // Half way down the cells: only their left and right borders.
      final List<int> row = await _redRow(tester, 'paint', 24);
      final List<int> lit = <int>[
        for (int x = 0; x < row.length; x++)
          if (row[x] != 0) x,
      ];
      expect(lit, <int>[0, 132, 141, 274, 283, 415, 424, 556, 565, 698, 707, 839]);
      expect(lit.map((int x) => row[x]), everyElement(255));
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
        KkGrid(
          children: <Widget>[
            KkCell(child: probe('a')),
            probe('b'),
            KkCell(span: 2, child: probe('c')),
          ],
        ),
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
            child: KkGrid(
              children: <Widget>[
                KkCell(child: probe('a')),
                KkCell(child: probe('b')),
              ],
            ),
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
            child: KkGrid(
              stagger: false,
              children: <Widget>[
                KkCell(child: probe('a')),
                KkCell(child: probe('b')),
              ],
            ),
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
        KkGrid(
          children: <Widget>[KkCell(key: const ValueKey<String>('cell'), span: 6, rows: 2, child: box('a'))],
        ),
      );
      expect(find.byKey(const ValueKey<String>('cell')), findsOneWidget);
      expect(rectOf(tester, 'a').height, 104);
      expect(rectOf(tester, 'a').width, closeTo((840 - 88) / 12 * 6 + 5 * 8, 1e-6));
    });

    testChecked('a keyed child that is not a KkCell keeps its state when the children change', (
      WidgetTester tester,
    ) async {
      for (final bool stagger in <bool>[true, false]) {
        final List<String> log = <String>[];
        final Map<String, int> seen = <String, int>{};
        KkGrid grid(List<String> ids) => KkGrid(
          stagger: stagger,
          children: <Widget>[
            for (final String id in ids) _Probe(key: ValueKey<String>(id), id: id, log: log, seen: seen),
          ],
        );
        await _pump(tester, 840, grid(<String>['a', 'b']));
        expect(log, <String>['init a', 'init b'], reason: 'stagger $stagger');
        // The key is that of the child alone: it finds one widget.
        final State<StatefulWidget> a = tester.state(byId('a'));
        log.clear();

        // Swapped: nothing is made or thrown away, and each child is told its new place.
        await _pump(tester, 840, grid(<String>['b', 'a']));
        expect(log, isEmpty, reason: 'stagger $stagger');
        expect(tester.state(byId('a')), same(a));
        expect(seen, stagger ? <String, int>{'b': 0, 'a': 1} : <String, int>{'b': 0, 'a': 0});

        // One more in front, then one taken out of the middle.
        await _pump(tester, 840, grid(<String>['c', 'b', 'a']));
        expect(log, <String>['init c'], reason: 'stagger $stagger');
        await _pump(tester, 840, grid(<String>['c', 'a']));
        expect(log, <String>['init c', 'dispose b'], reason: 'stagger $stagger');
        expect(tester.state(byId('a')), same(a));
        expect(seen['a'], stagger ? 1 : 0);

        await _pump(tester, 840, const KkGrid(children: <Widget>[]));
      }
    });

    testChecked('keyed cells and other keyed children move together, each with its state', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget child(String id) => id.startsWith('cell')
          ? KkCell(
              key: ValueKey<String>(id),
              span: 2,
              rows: 1,
              child: _Probe(id: id, log: log),
            )
          : _Probe(key: ValueKey<String>(id), id: id, log: log);
      KkGrid grid(List<String> ids) => KkGrid(children: <Widget>[for (final String id in ids) child(id)]);
      await _pump(tester, 840, grid(<String>['cell 1', 'a', 'cell 2', 'b']));
      expect(log, hasLength(4));
      log.clear();
      await _pump(tester, 840, grid(<String>['b', 'cell 2', 'a', 'cell 1']));
      expect(log, isEmpty);
      await _pump(tester, 840, grid(<String>['a', 'cell 1']));
      expect(log, unorderedEquals(<String>['dispose b', 'dispose cell 2']));
    });

    testChecked('children with global keys keep their state, and no key is used twice', (WidgetTester tester) async {
      final List<String> log = <String>[];
      final Map<String, GlobalKey> keys = <String, GlobalKey>{
        for (final String id in <String>['a', 'b', 'c']) id: GlobalKey(debugLabel: id),
      };
      KkGrid grid(List<String> ids) => KkGrid(
        children: <Widget>[for (final String id in ids) _Probe(key: keys[id], id: id, log: log)],
      );
      await _pump(tester, 840, grid(<String>['a', 'b', 'c']));
      expect(tester.takeException(), isNull);
      final State<StatefulWidget> a = keys['a']!.currentState!;
      log.clear();
      await _pump(tester, 840, grid(<String>['c', 'a', 'b']));
      expect(tester.takeException(), isNull);
      expect(log, isEmpty);
      expect(keys['a']!.currentState, same(a));
    });
  });

  group('measuring', () {
    testChecked('intrinsic height and dry layout match the real layout', (WidgetTester tester) async {
      final RenderKkGrid r = await _pump(
        tester,
        840,
        KkGrid(
          children: <Widget>[_cell('a', span: 8, rows: 2), _cell('b', span: 8, rows: 3), _cell('c', span: 4, rows: 1)],
        ),
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
