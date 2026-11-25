import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

KkTableGeometry resolve(
  List<KkTableWidth> columns, {
  List<double>? header,
  List<double>? cells,
  required double available,
  bool snap = true,
}) => kkResolveTableWidths(
  columns,
  header: header ?? List<double>.filled(columns.length, 0),
  cells: cells ?? List<double>.filled(columns.length, 0),
  available: available,
  snap: snap,
);

void main() {
  group('kkResolveTableWidths', () {
    test('fixed columns take their width and leave the rest of the row empty', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.fixed(36),
        KkTableWidth.fixed(40),
        KkTableWidth.fixed(28),
      ], available: 400);
      expect(g.widths, <double>[36, 40, 28]);
      expect(g.offsets, <double>[0, 36, 76]);
      expect(g.total, 104);
      expect(g.rowWidth, 400);
    });

    test('a flex column takes what the others leave', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.fixed(80),
        KkTableWidth.flex(),
        KkTableWidth.fixed(96),
      ], available: 500);
      expect(g.widths, <double>[80, 324, 96]);
      expect(g.total, 500);
      expect(g.rowWidth, 500);
    });

    test('flex columns share by weight on top of their minimum', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.flex(flex: 1, min: 100),
        KkTableWidth.flex(flex: 3, min: 100),
      ], available: 600);
      // 400 spare: 100 and 300.
      expect(g.widths, <double>[200, 400]);
    });

    test('a flex column stops at its max and the others take the rest', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.flex(min: 50, max: 120),
        KkTableWidth.flex(min: 50),
        KkTableWidth.flex(min: 50),
      ], available: 600);
      expect(g.widths, <double>[120, 240, 240]);
      expect(g.total, 600);
    });

    test('every flex column at its max leaves the row wider than the columns', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.flex(min: 50, max: 100),
        KkTableWidth.flex(min: 50, max: 100),
      ], available: 600);
      expect(g.widths, <double>[100, 100]);
      expect(g.total, 200);
      expect(g.rowWidth, 600);
    });

    test('a flex column is never narrower than its header', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.flex(min: 40), KkTableWidth.fixed(300)],
        header: <double>[130, 20],
        available: 400,
      );
      // 430 needed: the table scrolls sideways.
      expect(g.widths, <double>[130, 300]);
      expect(g.total, 430);
      expect(g.rowWidth, 430);
    });

    test('a max is a max, also against a header that is wider', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.flex(max: 200), KkTableWidth.content(max: 150), KkTableWidth.flex(min: 10)],
        header: <double>[5000, 5000, 0],
        available: 1000,
      );
      expect(g.widths, <double>[200, 150, 650]);
      expect(g.total, 1000);
    });

    test('a content column is as wide as the larger of its header and its cells, within min and max', () {
      const List<KkTableWidth> columns = <KkTableWidth>[
        KkTableWidth.content(),
        KkTableWidth.content(min: 90),
        KkTableWidth.content(max: 70),
        KkTableWidth.flex(min: 10),
      ];
      final KkTableGeometry g = resolve(
        columns,
        header: <double>[60, 30, 50, 0],
        cells: <double>[48, 55, 120, 0],
        available: 1000,
      );
      expect(g.widths.sublist(0, 3), <double>[60, 90, 70]);
      expect(g.widths[3], 1000 - 220);
    });

    test('without a flex column, content columns share the spare width in proportion to their content', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.fixed(100), KkTableWidth.content(), KkTableWidth.content()],
        cells: <double>[0, 100, 300],
        available: 900,
      );
      // 400 spare over 100 : 300.
      expect(g.widths, <double>[100, 200, 600]);
      expect(g.total, 900);
    });

    test('a content column with a max passes its share on', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.content(max: 150), KkTableWidth.content()],
        cells: <double>[100, 100],
        available: 600,
      );
      expect(g.widths, <double>[150, 450]);
    });

    test('columns that need more than there is keep their widths', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.fixed(200), KkTableWidth.content(), KkTableWidth.flex(min: 120)],
        cells: <double>[0, 180, 0],
        available: 300,
      );
      expect(g.widths, <double>[200, 180, 120]);
      expect(g.total, 500);
      expect(g.rowWidth, 500);
    });

    test('an unlimited width gives every column its starting width', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.fixed(80), KkTableWidth.content(), KkTableWidth.flex(min: 64)],
        header: <double>[0, 40, 70],
        cells: <double>[0, 90, 0],
        available: double.infinity,
      );
      expect(g.widths, <double>[80, 90, 70]);
      expect(g.rowWidth, 240);
    });

    test('column edges are on whole pixels and the last one is the edge of the table', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.flex(min: 0),
        KkTableWidth.flex(min: 0),
        KkTableWidth.flex(min: 0),
      ], available: 100);
      expect(g.offsets, <double>[0, 33, 67]);
      expect(g.widths, <double>[33, 34, 33]);
      expect(g.total, 100);
      final KkTableGeometry exact = resolve(
        const <KkTableWidth>[KkTableWidth.flex(min: 0), KkTableWidth.flex(min: 0), KkTableWidth.flex(min: 0)],
        available: 100,
        snap: false,
      );
      expect(exact.widths[0], closeTo(33.3333, 1e-3));
    });

    test('a table a fraction of a pixel wide is filled exactly', () {
      final KkTableGeometry g = resolve(const <KkTableWidth>[
        KkTableWidth.fixed(40),
        KkTableWidth.flex(min: 0),
      ], available: 333.5);
      expect(g.total, 333.5);
      expect(g.rowWidth, 333.5);
      expect(g.widths, <double>[40, 293.5]);
    });

    test('no columns, zero width and useless numbers do not throw', () {
      expect(resolve(const <KkTableWidth>[], available: 300).rowWidth, 300);
      expect(resolve(const <KkTableWidth>[], available: double.infinity).rowWidth, 0);
      final KkTableGeometry zero = resolve(const <KkTableWidth>[
        KkTableWidth.fixed(50),
        KkTableWidth.flex(),
      ], available: 0);
      expect(zero.widths, <double>[50, 64]);
      expect(zero.rowWidth, 114);
      final KkTableGeometry odd = kkResolveTableWidths(
        const <KkTableWidth>[
          KkTableWidth.fixed(double.nan),
          KkTableWidth.fixed(-20),
          KkTableWidth.content(min: double.nan, max: double.nan),
          KkTableWidth.flex(min: -5),
        ],
        header: <double>[double.nan, double.infinity],
        cells: <double>[double.negativeInfinity],
        available: 200,
      );
      expect(odd.widths, <double>[0, 0, 0, 200]);
      expect(odd.total, 200);
    });

    test('measured widths are rounded up, so a column is never a fraction narrower than its content', () {
      final KkTableGeometry g = resolve(
        const <KkTableWidth>[KkTableWidth.content(), KkTableWidth.flex(min: 10), KkTableWidth.content()],
        header: <double>[30.2, 44.01, 0],
        cells: <double>[59.2, 0, 61],
        available: 400,
      );
      expect(g.widths, <double>[60, 279, 61]);
      final KkTableGeometry loose = resolve(
        const <KkTableWidth>[KkTableWidth.content(), KkTableWidth.flex(min: 10)],
        header: <double>[30.2, 44.01],
        cells: <double>[59.2, 0],
        available: double.infinity,
        snap: false,
      );
      expect(loose.widths, <Matcher>[closeTo(59.2, 1e-9), closeTo(44.01, 1e-9)]);
      expect(loose.total, closeTo(103.21, 1e-9));
    });

    test('geometries compare by value', () {
      const List<KkTableWidth> columns = <KkTableWidth>[KkTableWidth.fixed(80), KkTableWidth.flex()];
      expect(resolve(columns, available: 300), resolve(columns, available: 300));
      expect(resolve(columns, available: 300), isNot(resolve(columns, available: 301)));
    });
  });

  group('KkTableWidth', () {
    test('kinds, equality and text', () {
      expect(const KkTableWidth.fixed(36).isFixed, isTrue);
      expect(const KkTableWidth.content().isContent, isTrue);
      expect(const KkTableWidth.flex().isFlex, isTrue);
      expect(const KkTableWidth.fixed(36), const KkTableWidth.fixed(36));
      expect(const KkTableWidth.fixed(36), isNot(const KkTableWidth.fixed(40)));
      expect(const KkTableWidth.flex(flex: 2), isNot(const KkTableWidth.flex()));
      expect(const KkTableWidth.content().toString(), contains('content'));
    });
  });

  group('kkCompareTableValues', () {
    test('numbers by size, text by code units, null and NaN last', () {
      expect(kkCompareTableValues(2, 10), lessThan(0));
      expect(kkCompareTableValues(2.5, 2), greaterThan(0));
      expect(kkCompareTableValues('a', 'b'), lessThan(0));
      expect(kkCompareTableValues(null, 1), greaterThan(0));
      expect(kkCompareTableValues(1, null), lessThan(0));
      expect(kkCompareTableValues(null, double.nan), 0);
      expect(kkCompareTableValues(double.nan, 3), greaterThan(0));
      expect(kkCompareTableValues(false, true), lessThan(0));
      expect(kkCompareTableValues(DateTime(2026), DateTime(2027)), lessThan(0));
      expect(kkCompareTableValues(const Duration(seconds: 2), const Duration(seconds: 1)), greaterThan(0));
      // Values of different kinds fall back to their text.
      expect(kkCompareTableValues(1, 'a'), lessThan(0));
    });
  });
}
