import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/src/charts/charts.dart';

void main() {
  group('kkNiceStep', () {
    test('picks 1, 2 or 5 times a power of ten', () {
      expect(kkNiceStep(100, 5), 20);
      expect(kkNiceStep(10, 5), 2);
      expect(kkNiceStep(1, 5), closeTo(0.2, 1e-12));
      expect(kkNiceStep(7, 5), 1);
      expect(kkNiceStep(2500, 5), 500);
      expect(kkNiceStep(0.03, 3), closeTo(0.01, 1e-12));
    });

    test('never returns zero, a negative or a non-finite step', () {
      for (final double span in <double>[0, -5, double.nan, double.infinity, double.negativeInfinity, 5e-324]) {
        final double step = kkNiceStep(span);
        expect(step.isFinite && step > 0, isTrue, reason: 'span $span gave $step');
      }
      expect(kkNiceStep(10, 0) > 0, isTrue);
      expect(kkNiceStep(10, -3) > 0, isTrue);
    });
  });

  group('kkNiceTicks', () {
    test('round values inside the range', () {
      expect(kkNiceTicks(0, 100), <double>[0, 20, 40, 60, 80, 100]);
      expect(kkNiceTicks(0, 1), <double>[0, 0.2, 0.4, 0.6, 0.8, 1]);
      expect(kkNiceTicks(-3, 7), <double>[-2, 0, 2, 4, 6]);
      expect(kkNiceTicks(0.1, 0.3, 4), <double>[0.1, 0.15, 0.2, 0.25, 0.3]);
      expect(kkNiceTicks(3, 97, 5), <double>[20, 40, 60, 80]);
    });

    test('accepts reversed input', () {
      expect(kkNiceTicks(100, 0), kkNiceTicks(0, 100));
    });

    test('equal bounds give that one value', () {
      expect(kkNiceTicks(5, 5), <double>[5]);
      expect(kkNiceTicks(0, 0), <double>[0]);
    });

    test('non-finite bounds give no ticks', () {
      expect(kkNiceTicks(double.nan, 1), isEmpty);
      expect(kkNiceTicks(0, double.infinity), isEmpty);
    });

    test('never contains NaN or infinity, and never minus zero', () {
      final List<List<double>> ranges = <List<double>>[
        <double>[-1e308, 1e308],
        <double>[1e15, 1e15 + 0.125],
        <double>[-0.5, 0.5],
        <double>[1e-300, 2e-300],
        <double>[-7, -7],
      ];
      for (final List<double> r in ranges) {
        final List<double> ticks = kkNiceTicks(r[0], r[1]);
        expect(ticks, isNotEmpty);
        for (final double t in ticks) {
          expect(t.isFinite, isTrue, reason: '$r gave $t');
          expect(t == 0 && t.isNegative, isFalse, reason: '$r gave -0.0');
        }
      }
    });

    test('ticks are evenly spaced', () {
      final List<double> ticks = kkNiceTicks(12.3, 87.9, 6);
      for (int i = 2; i < ticks.length; i++) {
        expect(ticks[i] - ticks[i - 1], closeTo(ticks[1] - ticks[0], 1e-9));
      }
      expect(ticks.first >= 12.3 && ticks.last <= 87.9, isTrue);
    });
  });

  test('kkTickDecimals follows the step', () {
    expect(kkTickDecimals(20), 0);
    expect(kkTickDecimals(1), 0);
    expect(kkTickDecimals(0.5), 1);
    expect(kkTickDecimals(0.1), 1);
    expect(kkTickDecimals(0.02), 2);
    expect(kkTickDecimals(0.001), 3);
    expect(kkTickDecimals(0), 0);
    expect(kkTickDecimals(double.nan), 0);
  });

  test('kkFormatTick uses the step decimals and never prints minus zero', () {
    expect(kkFormatTick(40, 20), '40');
    expect(kkFormatTick(0.3, 0.1), '0.3');
    expect(kkFormatTick(-0.0001, 0.1), '0.0');
    expect(kkFormatTick(double.nan, 1), '--');
  });

  group('KkLinearScale', () {
    test('maps and inverts', () {
      const KkLinearScale s = KkLinearScale(min: 0, max: 100, start: 0, end: 200);
      expect(s.map(50), 100);
      expect(s(25), 50);
      expect(s.invert(150), 75);
      expect(s.map(150), 300);
    });

    test('a reversed range puts the minimum at the bottom', () {
      const KkLinearScale y = KkLinearScale(min: 0, max: 10, start: 200, end: 0);
      expect(y.map(0), 200);
      expect(y.map(10), 0);
      expect(y.invert(50), 7.5);
    });

    test('clamp keeps values inside the range', () {
      const KkLinearScale s = KkLinearScale(min: 0, max: 10, start: 0, end: 100, clamp: true);
      expect(s.map(-5), 0);
      expect(s.map(50), 100);
      expect(s.invert(500), 10);
    });

    test('a domain with no extent maps to the middle and is never NaN', () {
      const KkLinearScale s = KkLinearScale(min: 5, max: 5, start: 0, end: 100);
      expect(s.isDegenerate, isTrue);
      expect(s.map(5), 50);
      expect(s.map(999), 50);
      expect(s.map(double.nan), 50);
      expect(s.invert(30), 5);
      expect(const KkLinearScale(min: 0, max: 10, start: 4, end: 4).invert(4), 0);
      expect(const KkLinearScale(min: 0, max: 10).map(double.infinity), 0.5);
    });

    test('of() skips nulls and non-finite values', () {
      final KkLinearScale s = KkLinearScale.of(<double?>[3, null, double.nan, 9, double.infinity]);
      expect(s.min, 3);
      expect(s.max, 9);
      expect(KkLinearScale.of(<double?>[3, 9], zero: true).min, 0);
      expect(KkLinearScale.of(<double?>[-3, -9], zero: true).max, 0);
      expect(KkLinearScale.of(<double?>[]).min, 0);
      expect(KkLinearScale.of(<double?>[null, double.nan]).max, 1);
      expect(KkLinearScale.of(<double?>[3, 9], min: 0, max: 20).max, 20);
    });

    test('nice() widens to round bounds', () {
      final KkLinearScale s = const KkLinearScale(min: 3, max: 97).nice();
      expect(s.min, 0);
      expect(s.max, 100);
      expect(const KkLinearScale(min: 0, max: 100).nice().max, 100);
      final KkLinearScale reversed = const KkLinearScale(min: 97, max: 3).nice();
      expect(reversed.min, 100);
      expect(reversed.max, 0);
    });

    test('nice() opens up a domain with no extent', () {
      final KkLinearScale s = const KkLinearScale(min: 5, max: 5).nice();
      expect(s.min < 5 && s.max > 5, isTrue);
      final KkLinearScale zero = const KkLinearScale(min: 0, max: 0).nice();
      expect(zero.min < 0 && zero.max > 0, isTrue);
      expect(zero.ticks(), isNotEmpty);
    });

    test('ticks and tickStep agree', () {
      const KkLinearScale s = KkLinearScale(min: 0, max: 100);
      final List<double> ticks = s.ticks(5);
      expect(ticks[1] - ticks[0], s.tickStep(5));
    });

    test('equality', () {
      expect(const KkLinearScale(min: 1, max: 2), const KkLinearScale(min: 1, max: 2));
      expect(const KkLinearScale(min: 1, max: 2).withRange(0, 10), const KkLinearScale(min: 1, max: 2, start: 0, end: 10));
      expect(const KkLinearScale(min: 1, max: 2) == const KkLinearScale(min: 1, max: 3), isFalse);
    });
  });
}
