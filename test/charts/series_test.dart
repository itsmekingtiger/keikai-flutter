import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

void main() {
  test('series colours are fixed, never cycled', () {
    const KkColors c = KkColors.standby;
    expect(kkSeriesColor(c, 0), c.series1);
    expect(kkSeriesColor(c, 1), c.series2);
    expect(kkSeriesColor(c, 2), c.series3);
    expect(kkSeriesColor(c, 3), c.inkFaint);
    expect(kkSeriesColor(c, 9), c.inkFaint);
    expect(kkSeriesColor(c, -1), c.inkFaint);
  });

  group('kkGroupOther', () {
    const List<KkSeries> five = <KkSeries>[
      KkSeries(name: 'A', values: <double?>[1, 2, 3]),
      KkSeries(name: 'B', values: <double?>[1, 2, 3]),
      KkSeries(name: 'C', values: <double?>[1, 2, 3]),
      KkSeries(name: 'D', values: <double?>[1, null, 3, 4]),
      KkSeries(name: 'E', values: <double?>[10, null, double.nan]),
    ];

    test('folds the fourth and later series into OTHER', () {
      final List<KkSeries> grouped = kkGroupOther(five);
      expect(grouped.map((KkSeries s) => s.name).toList(), <String>['A', 'B', 'C', 'OTHER']);
      expect(grouped.last.values, <double?>[11, null, 3, 4]);
    });

    test('leaves three or fewer alone', () {
      final List<KkSeries> three = five.sublist(0, 3);
      expect(identical(kkGroupOther(three), three), isTrue);
      expect(kkGroupOther(const <KkSeries>[]), isEmpty);
    });

    test('keep and name are adjustable', () {
      final List<KkSeries> grouped = kkGroupOther(five, keep: 1, name: 'REST');
      expect(grouped.length, 2);
      expect(grouped.last.name, 'REST');
      expect(grouped.last.values, <double?>[13, 4, 9, 4]);
      expect(kkGroupOther(five, keep: 0).single.name, 'OTHER');
    });
  });

  test('kkGroupOtherSlices sums the rest and skips bad values', () {
    const List<KkSlice> slices = <KkSlice>[
      KkSlice(name: 'A', value: 5),
      KkSlice(name: 'B', value: 4),
      KkSlice(name: 'C', value: 3),
      KkSlice(name: 'D', value: 2),
      KkSlice(name: 'E', value: -9),
      KkSlice(name: 'F', value: double.nan),
      KkSlice(name: 'G', value: 1),
    ];
    final List<KkSlice> grouped = kkGroupOtherSlices(slices);
    expect(grouped.length, 4);
    expect(grouped.last.name, 'OTHER');
    expect(grouped.last.value, 3);
    expect(identical(kkGroupOtherSlices(slices.sublist(0, 2)), slices.sublist(0, 2)), isFalse);
    expect(kkGroupOtherSlices(slices.sublist(0, 2)).length, 2);
  });

  group('KkCascade', () {
    const KkCascade cascade = KkCascade(
      count: 3,
      item: Duration(milliseconds: 800),
      step: Duration(milliseconds: 90),
    );

    test('total covers the last item', () {
      expect(cascade.total, const Duration(milliseconds: 980));
      expect(const KkCascade(count: 0, item: Duration(seconds: 1), step: Duration(seconds: 1)).total, const Duration(seconds: 1));
    });

    test('each item starts one step after the previous', () {
      // 490ms into the cascade.
      expect(cascade.at(0.5, 0), closeTo(490 / 800, 1e-9));
      expect(cascade.at(0.5, 1), closeTo(400 / 800, 1e-9));
      expect(cascade.at(0.5, 2), closeTo(310 / 800, 1e-9));
      expect(cascade.at(0, 2), 0);
      expect(cascade.at(1, 2), 1);
      expect(cascade.at(0.05, 2), 0);
    });

    test('steps quantise like steps(n, end)', () {
      expect(cascade.at(0.5, 0, steps: 16), (490 / 800 * 16).floor() / 16);
      expect(cascade.at(0.999, 0, steps: 16), 1);
    });

    test('degenerate cascades are finished', () {
      const KkCascade zero = KkCascade(count: 4, item: Duration.zero, step: Duration.zero);
      expect(zero.at(0.2, 3), 1);
    });
  });

  test('kkIsFinite', () {
    expect(kkIsFinite(1), isTrue);
    expect(kkIsFinite(null), isFalse);
    expect(kkIsFinite(double.nan), isFalse);
    expect(kkIsFinite(double.negativeInfinity), isFalse);
  });

  test('kkRampStep quantises into six steps', () {
    expect(kkRampStep(0, 0, 100), 0);
    expect(kkRampStep(16.6, 0, 100), 0);
    expect(kkRampStep(17, 0, 100), 1);
    expect(kkRampStep(50, 0, 100), 3);
    expect(kkRampStep(99.9, 0, 100), 5);
    expect(kkRampStep(100, 0, 100), 5);
    expect(kkRampStep(500, 0, 100), 5);
    expect(kkRampStep(-20, 0, 100), 0);
    expect(kkRampStep(null, 0, 100), 0);
    expect(kkRampStep(double.nan, 0, 100), 0);
    expect(kkRampStep(5, 10, 10), 0);
    expect(kkRampStep(5, 10, 0), 0);
  });
}
