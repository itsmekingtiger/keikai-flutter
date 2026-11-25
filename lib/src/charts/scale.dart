import 'dart:math' as math;

import 'package:flutter/foundation.dart';

const double _e10 = 7.0710678118654755; // sqrt(50)
const double _e5 = 3.1622776601683795; // sqrt(10)
const double _e2 = 1.4142135623730951; // sqrt(2)

/// The round step (1, 2 or 5 times a power of ten) that cuts [span] into about
/// [count] parts. Always finite and greater than zero.
double kkNiceStep(double span, [int count = 5]) {
  if (!span.isFinite || span <= 0) return 1;
  final double raw = span / math.max(1, count);
  final double power = (math.log(raw) / math.ln10).floorToDouble();
  final double base = math.pow(10, power).toDouble();
  if (!(base > 0) || !base.isFinite) return span;
  final double error = raw / base;
  final double factor = error >= _e10 ? 10 : (error >= _e5 ? 5 : (error >= _e2 ? 2 : 1));
  final double step = factor * base;
  return step.isFinite && step > 0 ? step : span;
}

/// How many decimals a tick label needs for ticks [step] apart: 0 for 5 or
/// 20, 1 for 0.5, 2 for 0.02.
int kkTickDecimals(double step) {
  if (!step.isFinite || step <= 0) return 0;
  final int power = (math.log(step) / math.ln10 + 1e-9).floor();
  return power >= 0 ? 0 : math.min(-power, 12);
}

double _snap(double value, int decimals) {
  final double p = math.pow(10, math.min(decimals + 2, 15)).toDouble();
  final double v = (value * p).roundToDouble() / p;
  // Adding 0.0 turns -0.0 into 0.0.
  return v.isFinite ? v + 0.0 : value;
}

/// Round tick values between [min] and [max], about [count] of them, at steps
/// of 1, 2 or 5 times a power of ten.
///
/// The input may be reversed. Equal bounds give that single value; a
/// non-finite bound gives an empty list. The result never holds NaN.
List<double> kkNiceTicks(double min, double max, [int count = 5]) {
  if (!min.isFinite || !max.isFinite) return const <double>[];
  double lo = min;
  double hi = max;
  if (lo > hi) {
    final double t = lo;
    lo = hi;
    hi = t;
  }
  if (lo == hi) return <double>[lo + 0.0];
  final double step = kkNiceStep(hi - lo, count);
  if (!(step > 0) || !step.isFinite) return <double>[lo, hi];
  final double first = (lo / step - 1e-9).ceilToDouble();
  final double last = (hi / step + 1e-9).floorToDouble();
  if (!first.isFinite || !last.isFinite || last < first) return <double>[lo, hi];
  if (last - first > 1000) return <double>[lo, hi];
  final int decimals = kkTickDecimals(step);
  final List<double> ticks = <double>[];
  for (double i = first; i <= last; i += 1) {
    ticks.add(_snap(i * step, decimals));
  }
  return ticks;
}

/// A tick label for [value] with exactly the decimals ticks [step] apart need.
String kkFormatTick(double value, double step) {
  if (!value.isFinite) return '--';
  final String s = value.toStringAsFixed(kkTickDecimals(step));
  return double.tryParse(s) == 0 ? s.replaceFirst('-', '') : s;
}

/// A linear map from a data domain ([min] to [max]) onto a range ([start] to
/// [end], usually pixels). Either may run backwards: a y axis maps onto a
/// range whose start is the bottom of the plot.
@immutable
class KkLinearScale {
  const KkLinearScale({this.min = 0, this.max = 1, this.start = 0, this.end = 1, this.clamp = false});

  /// A scale whose domain covers the finite entries of [values]. Null, NaN
  /// and infinite entries are skipped; with nothing left the domain is 0 to 1.
  ///
  /// [zero] stretches the domain to include 0. [min] and [max] pin an end.
  factory KkLinearScale.of(
    Iterable<double?> values, {
    double start = 0,
    double end = 1,
    bool zero = false,
    double? min,
    double? max,
    bool clamp = false,
  }) {
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (final double? v in values) {
      if (v == null || !v.isFinite) continue;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (!lo.isFinite || !hi.isFinite) {
      lo = 0;
      hi = 1;
    }
    if (zero) {
      if (lo > 0) lo = 0;
      if (hi < 0) hi = 0;
    }
    if (min != null && min.isFinite) lo = min;
    if (max != null && max.isFinite) hi = max;
    return KkLinearScale(min: lo, max: hi, start: start, end: end, clamp: clamp);
  }

  /// Start of the domain.
  final double min;

  /// End of the domain.
  final double max;

  /// Where [min] lands.
  final double start;

  /// Where [max] lands.
  final double end;

  /// Keep mapped values inside the range.
  final bool clamp;

  /// Whether the domain has no extent (or is not finite). Every value then
  /// maps to the middle of the range.
  bool get isDegenerate => !min.isFinite || !max.isFinite || min == max;

  /// The position of [value] in the range. A non-finite value, or a
  /// degenerate domain, gives the middle of the range; the result is never NaN
  /// for finite bounds.
  double map(double value) {
    if (isDegenerate || !value.isFinite) return (start + end) / 2;
    double t = (value - min) / (max - min);
    if (clamp) t = t.clamp(0.0, 1.0);
    return start + (end - start) * t;
  }

  /// Same as [map].
  double call(double value) => map(value);

  /// The domain value at [position] in the range.
  double invert(double position) {
    if (start == end || !position.isFinite || isDegenerate) return min.isFinite ? min : 0;
    double t = (position - start) / (end - start);
    if (clamp) t = t.clamp(0.0, 1.0);
    return min + (max - min) * t;
  }

  /// This scale with its domain widened to round tick values. A domain with
  /// no extent is opened up around its value first.
  KkLinearScale nice([int count = 5]) {
    if (!min.isFinite || !max.isFinite) return this;
    final bool reversed = min > max;
    double lo = reversed ? max : min;
    double hi = reversed ? min : max;
    if (lo == hi) {
      final double pad = lo == 0 ? 1 : lo.abs() * 0.1;
      lo -= pad;
      hi += pad;
    }
    final double step = kkNiceStep(hi - lo, count);
    final int decimals = kkTickDecimals(step);
    final double nlo = _snap((lo / step + 1e-9).floorToDouble() * step, decimals);
    final double nhi = _snap((hi / step - 1e-9).ceilToDouble() * step, decimals);
    if (!nlo.isFinite || !nhi.isFinite || nlo == nhi) return this;
    return reversed ? copyWith(min: nhi, max: nlo) : copyWith(min: nlo, max: nhi);
  }

  /// Round tick values inside the domain. See [kkNiceTicks].
  List<double> ticks([int count = 5]) => kkNiceTicks(min, max, count);

  /// The step between the values [ticks] returns for the same [count].
  double tickStep([int count = 5]) => kkNiceStep((max - min).abs(), count);

  /// This scale mapped onto another range.
  KkLinearScale withRange(double start, double end) => copyWith(start: start, end: end);

  KkLinearScale copyWith({double? min, double? max, double? start, double? end, bool? clamp}) => KkLinearScale(
    min: min ?? this.min,
    max: max ?? this.max,
    start: start ?? this.start,
    end: end ?? this.end,
    clamp: clamp ?? this.clamp,
  );

  @override
  bool operator ==(Object other) =>
      other is KkLinearScale &&
      other.min == min &&
      other.max == max &&
      other.start == start &&
      other.end == end &&
      other.clamp == clamp;

  @override
  int get hashCode => Object.hash(min, max, start, end, clamp);

  @override
  String toString() => 'KkLinearScale($min..$max -> $start..$end)';
}
