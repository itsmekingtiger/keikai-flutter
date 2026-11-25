import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

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
    const KkCascade cascade = KkCascade(count: 3, item: Duration(milliseconds: 800), step: Duration(milliseconds: 90));

    test('total covers the last item', () {
      expect(cascade.total, const Duration(milliseconds: 980));
      expect(
        const KkCascade(count: 0, item: Duration(seconds: 1), step: Duration(seconds: 1)).total,
        const Duration(seconds: 1),
      );
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

    test('a cap closes the steps up when there are many items', () {
      const Duration item = Duration(milliseconds: 350);
      const Duration step = Duration(milliseconds: 5);
      const Duration cap = Duration(milliseconds: 1200);
      // Few items: the cap changes nothing.
      const KkCascade few = KkCascade(count: 168, item: item, step: step, cap: cap);
      expect(few.total, const Duration(milliseconds: 350 + 167 * 5));
      expect(few.total, const KkCascade(count: 168, item: item, step: step).total);
      // 241 items are exactly at the cap.
      expect(const KkCascade(count: 241, item: item, step: step, cap: cap).total, const Duration(milliseconds: 1550));
      // Many: the last one still starts at 1.2s, and they stay in order.
      const KkCascade many = KkCascade(count: 10001, item: item, step: step, cap: cap);
      expect(many.total, const Duration(milliseconds: 1550));
      expect(const KkCascade(count: 10001, item: item, step: step).total, const Duration(milliseconds: 50350));
      // Half way (775ms): item 0 is done, item 5000 (starts at 600ms) is half way, the last has not begun.
      expect(many.at(0.5, 0), 1);
      expect(many.at(0.5, 5000), closeTo(175 / 350, 1e-6));
      expect(many.at(0.5, 10000), 0);
      expect(many.at(1, 10000), 1);
      double previous = 1;
      for (int i = 0; i <= 10000; i += 500) {
        final double t = many.at(0.6, i);
        expect(t <= previous, isTrue);
        previous = t;
      }
      // One item, or none, and odd caps.
      expect(const KkCascade(count: 1, item: item, step: step, cap: cap).total, item);
      expect(const KkCascade(count: 0, item: item, step: step, cap: cap).total, item);
      expect(const KkCascade(count: 9, item: item, step: step, cap: Duration.zero).total, item);
      expect(const KkCascade(count: 9, item: item, step: step, cap: Duration(seconds: -1)).total, item);
      expect(const KkCascade(count: 9, item: item, step: Duration(seconds: -1)).total, item);
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
