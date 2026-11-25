import 'dart:math' as math;

import '../widgets/clock.dart';
import 'scale.dart';

/// A number at a fixed width: the integer part padded with zeros to [digits]
/// places and exactly [decimals] decimals. Readouts never change width as the
/// value moves: `kkFixed(42.7, digits: 3, decimals: 1)` is `042.7` and
/// `kkFixed(78, digits: 3)` is `078`.
///
/// A negative value keeps its sign in front of the padding; [plus] adds a
/// `+` to positive values. NaN and infinity print as dashes of the same width.
String kkFixed(num value, {int digits = 1, int decimals = 0, bool plus = false}) {
  final int d = math.max(1, digits);
  final int f = math.max(0, decimals);
  if (value is double && !value.isFinite) {
    return f > 0 ? '${'-' * d}.${'-' * f}' : '-' * d;
  }
  final String body = value.abs().toStringAsFixed(f);
  final int dot = body.indexOf('.');
  final int whole = dot < 0 ? body.length : dot;
  final String padded = whole < d ? '${'0' * (d - whole)}$body' : body;
  final bool zero = !body.contains(RegExp('[1-9]'));
  final String sign = zero ? '' : (value < 0 ? '-' : (plus ? '+' : ''));
  return '$sign$padded';
}

/// Seconds since the Unix epoch for [time], which may be a [DateTime] or a
/// number that already is epoch seconds.
double kkEpochSeconds(Object time) {
  if (time is DateTime) return time.microsecondsSinceEpoch / 1e6;
  if (time is num) return time.toDouble();
  throw ArgumentError.value(time, 'time', 'Expected a DateTime or epoch seconds');
}

const List<int> _timeSteps = <int>[
  1, 2, 5, 10, 15, 30, //
  60, 120, 300, 600, 900, 1800, //
  3600, 7200, 10800, 21600, 43200, 86400, 172800, 604800,
];

/// The round step in seconds (1s, 5s, 15s, 1min, 5min, 1h, 6h, 1 day …) that
/// cuts [spanSeconds] into at most about [count] parts. Spans under a few
/// seconds fall back to decimal steps.
double kkTimeStep(double spanSeconds, [int count = 6]) {
  if (!spanSeconds.isFinite || spanSeconds <= 0) return 1;
  final double raw = spanSeconds / math.max(1, count);
  if (raw < 0.5) return kkNiceStep(spanSeconds, count);
  for (final int step in _timeSteps) {
    if (step >= raw) return step.toDouble();
  }
  // Longer than weeks: whole days at a round count.
  return kkNiceStep(spanSeconds / 86400, count).ceilToDouble() * 86400;
}

/// Tick positions, in epoch seconds, at round UTC steps between [start] and
/// [end] (each a [DateTime] or epoch seconds). A 40 minute window gives
/// 14:00, 14:10, 14:20 … rather than arbitrary instants.
List<double> kkTimeTicks(Object start, Object end, {int count = 6}) {
  double lo = kkEpochSeconds(start);
  double hi = kkEpochSeconds(end);
  if (!lo.isFinite || !hi.isFinite) return const <double>[];
  if (lo > hi) {
    final double t = lo;
    lo = hi;
    hi = t;
  }
  if (lo == hi) return <double>[lo];
  final double step = kkTimeStep(hi - lo, count);
  final double first = (lo / step - 1e-9).ceilToDouble();
  final double last = (hi / step + 1e-9).floorToDouble();
  if (last < first || last - first > 1000) return <double>[lo, hi];
  return <double>[for (double i = first; i <= last; i += 1) i * step];
}

/// The UTC label of [time] (a [DateTime] or epoch seconds): `14:02`, or
/// `14:02:31` with [seconds], or `11-24` with [date]. Times in KEIKAI are UTC,
/// 24-hour.
String kkTimeLabel(Object time, {bool seconds = false, bool date = false}) {
  final double s = kkEpochSeconds(time);
  if (!s.isFinite || s.abs() > 8.64e12) return date ? '--' : (seconds ? '--:--:--' : '--:--');
  final DateTime t = DateTime.fromMillisecondsSinceEpoch((s * 1000).round(), isUtc: true);
  if (date) {
    final String full = kkFormatDate(t);
    return full.length >= 5 ? full.substring(full.length - 5) : full;
  }
  return kkFormatTime(t, seconds: seconds);
}

/// Labels a time axis whose ticks are [step] seconds apart: dates for day
/// steps, seconds for sub-minute steps, `HH:MM` otherwise.
String kkTimeTickLabel(double epochSeconds, double step) {
  if (step >= 86400) return kkTimeLabel(epochSeconds, date: true);
  return kkTimeLabel(epochSeconds, seconds: step < 60);
}
