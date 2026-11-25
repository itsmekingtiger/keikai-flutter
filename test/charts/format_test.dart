import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/src/charts/charts.dart';

void main() {
  group('kkFixed', () {
    test('pads the integer part and fixes the decimals', () {
      expect(kkFixed(42.7, digits: 3, decimals: 1), '042.7');
      expect(kkFixed(78, digits: 3), '078');
      expect(kkFixed(7, digits: 1), '7');
      expect(kkFixed(0, digits: 4, decimals: 2), '0000.00');
      expect(kkFixed(1234.6, digits: 3), '1235');
    });

    test('keeps the sign in front of the padding', () {
      expect(kkFixed(-4.26, digits: 2, decimals: 1), '-04.3');
      expect(kkFixed(5, plus: true), '+5');
      expect(kkFixed(-5, plus: true), '-5');
    });

    test('a value that rounds to zero has no sign', () {
      expect(kkFixed(-0.04, digits: 2, decimals: 1), '00.0');
      expect(kkFixed(0.04, digits: 2, decimals: 1, plus: true), '00.0');
    });

    test('non-finite values print as dashes of the same width', () {
      expect(kkFixed(double.nan, digits: 3, decimals: 1), '---.-');
      expect(kkFixed(double.infinity, digits: 3), '---');
    });

    test('tolerates silly arguments', () {
      expect(kkFixed(3, digits: 0), '3');
      expect(kkFixed(3.14159, digits: -2, decimals: -1), '3');
    });
  });

  group('time axis', () {
    test('kkEpochSeconds accepts a DateTime or a number', () {
      expect(kkEpochSeconds(DateTime.utc(1970, 1, 1, 0, 1)), 60);
      expect(kkEpochSeconds(90), 90);
      expect(kkEpochSeconds(1.5), 1.5);
      expect(() => kkEpochSeconds('now'), throwsArgumentError);
    });

    test('kkTimeStep picks round steps', () {
      expect(kkTimeStep(3600, 6), 600);
      expect(kkTimeStep(2400, 6), 600);
      expect(kkTimeStep(60, 6), 10);
      expect(kkTimeStep(86400, 6), 21600);
      expect(kkTimeStep(86400 * 7, 7), 86400);
      expect(kkTimeStep(86400 * 400, 5) % 86400, 0);
      expect(kkTimeStep(0), 1);
      expect(kkTimeStep(double.nan), 1);
      expect(kkTimeStep(1, 10), closeTo(0.1, 1e-12));
    });

    test('kkTimeTicks lands on round UTC instants', () {
      final DateTime start = DateTime.utc(2026, 11, 24, 13, 2);
      final DateTime end = DateTime.utc(2026, 11, 24, 14, 2);
      final List<double> ticks = kkTimeTicks(start, end, count: 6);
      expect(<String>[for (final double t in ticks) kkTimeLabel(t)], <String>['13:10', '13:20', '13:30', '13:40', '13:50', '14:00']);
      expect(kkTimeTicks(0, 3600), <double>[0, 600, 1200, 1800, 2400, 3000, 3600]);
      expect(kkTimeTicks(3600, 0), kkTimeTicks(0, 3600));
      expect(kkTimeTicks(42, 42), <double>[42]);
      expect(kkTimeTicks(double.nan, 5), isEmpty);
    });

    test('kkTimeLabel is UTC, 24-hour', () {
      final DateTime t = DateTime.utc(2026, 11, 24, 14, 2, 31);
      expect(kkTimeLabel(t), '14:02');
      expect(kkTimeLabel(t, seconds: true), '14:02:31');
      expect(kkTimeLabel(t, date: true), '11-24');
      expect(kkTimeLabel(t.millisecondsSinceEpoch / 1000), '14:02');
      expect(kkTimeLabel(double.nan), '--:--');
      expect(kkTimeLabel(double.infinity, seconds: true), '--:--:--');
      expect(kkTimeLabel(1e300), '--:--');
    });

    test('kkTimeTickLabel follows the step', () {
      final double t = DateTime.utc(2026, 11, 24, 14, 2, 31).millisecondsSinceEpoch / 1000;
      expect(kkTimeTickLabel(t, 600), '14:02');
      expect(kkTimeTickLabel(t, 10), '14:02:31');
      expect(kkTimeTickLabel(t, 86400), '11-24');
    });
  });
}
