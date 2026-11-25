import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';

/// Whether [value] can be drawn: not null, not NaN, not infinite.
bool kkIsFinite(double? value) => value != null && value.isFinite;

/// One named run of values on a chart.
///
/// A null (or NaN, or infinite) value is a gap: lines break there and bars are
/// left out.
@immutable
class KkSeries {
  const KkSeries({required this.name, required this.values, this.color, this.area = false, this.line = true});

  /// Shown in the legend and the tooltip. Capitals by convention.
  final String name;
  final List<double?> values;

  /// Overrides the fixed series colour. Series colours carry no status
  /// meaning; do not use a status colour here unless the series is one.
  final Color? color;

  /// Fill under the line at 14% (time series only).
  final bool area;

  /// Draw the line itself (time series only).
  final bool line;

  KkSeries copyWith({String? name, List<double?>? values, Color? color, bool? area, bool? line}) => KkSeries(
    name: name ?? this.name,
    values: values ?? this.values,
    color: color ?? this.color,
    area: area ?? this.area,
    line: line ?? this.line,
  );

  @override
  bool operator ==(Object other) =>
      other is KkSeries &&
      other.name == name &&
      listEquals(other.values, values) &&
      other.color == color &&
      other.area == area &&
      other.line == line;

  @override
  int get hashCode => Object.hash(name, Object.hashAll(values), color, area, line);
}

/// One part of a whole: a donut segment or a category-bar segment.
@immutable
class KkSlice {
  const KkSlice({required this.name, required this.value, this.color, this.level});

  final String name;
  final double value;

  /// Overrides the colour picked from the level or the fixed series order.
  final Color? color;

  /// Colours the slice by a status level instead of a series colour.
  final KkLevel? level;

  @override
  bool operator ==(Object other) =>
      other is KkSlice && other.name == name && other.value == value && other.color == color && other.level == level;

  @override
  int get hashCode => Object.hash(name, value, color, level);
}

/// A horizontal limit line on a chart: dashed, in its level's colour, with a
/// small bold label.
@immutable
class KkThreshold {
  const KkThreshold(this.value, {this.label, this.level = KkLevel.caution, this.color});

  final double value;

  /// Defaults to the level's word (`CAUTION`, `CRITICAL` …).
  final String? label;
  final KkLevel? level;

  /// Overrides the level colour.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is KkThreshold &&
      other.value == value &&
      other.label == label &&
      other.level == level &&
      other.color == color;

  @override
  int get hashCode => Object.hash(value, label, level, color);
}

/// The colour of series number [index] (from 0).
///
/// The first three are series-1, -2 and -3, always in that order and never
/// cycled. Anything after that is the neutral OTHER colour: fold extra series
/// together with [kkGroupOther] instead of inventing a fourth hue.
Color kkSeriesColor(KkColors colors, int index) {
  return switch (index) {
    0 => colors.series1,
    1 => colors.series2,
    2 => colors.series3,
    _ => colors.inkFaint,
  };
}

/// Keeps the first [keep] series and folds the rest into one series called
/// [name], summed point by point. A point is a gap only where every folded
/// series has a gap.
///
/// The palette has three series colours; a chart with more than three series
/// shows the first three and OTHER.
List<KkSeries> kkGroupOther(List<KkSeries> series, {int keep = 3, String name = 'OTHER'}) {
  final int k = math.max(0, keep);
  if (series.length <= k) return series;
  final List<KkSeries> rest = series.sublist(k);
  int length = 0;
  for (final KkSeries s in rest) {
    length = math.max(length, s.values.length);
  }
  final List<double?> sum = List<double?>.filled(length, null);
  for (final KkSeries s in rest) {
    for (int i = 0; i < s.values.length; i++) {
      final double? v = s.values[i];
      if (v == null || !v.isFinite) continue;
      sum[i] = (sum[i] ?? 0) + v;
    }
  }
  bool area = false;
  bool line = false;
  for (final KkSeries s in rest) {
    area = area || s.area;
    line = line || s.line;
  }
  return <KkSeries>[...series.take(k), KkSeries(name: name, values: sum, area: area, line: line)];
}

/// Keeps the first [keep] slices and folds the rest into one slice called
/// [name] whose value is their sum.
List<KkSlice> kkGroupOtherSlices(List<KkSlice> slices, {int keep = 3, String name = 'OTHER'}) {
  final int k = math.max(0, keep);
  if (slices.length <= k) return slices;
  double sum = 0;
  for (final KkSlice s in slices.skip(k)) {
    if (s.value.isFinite && s.value > 0) sum += s.value;
  }
  return <KkSlice>[...slices.take(k), KkSlice(name: name, value: sum)];
}

/// The timeline of a staggered entrance: [count] items, each taking [item],
/// starting [step] apart.
///
/// Drive one animation over [total] and ask [at] where each item is. Chart
/// lines wipe in 90ms apart, bars grow 30ms apart, heat cells flicker 5ms
/// apart: all of them are one cascade.
///
/// With very many items the last one would start long after the first. [cap]
/// limits that wait: past it the items start closer together, so a heatmap of
/// a thousand cells still arrives in about a second.
@immutable
class KkCascade {
  const KkCascade({required this.count, required this.item, required this.step, this.cap});

  /// How many items there are.
  final int count;

  /// How long one item's own entrance takes.
  final Duration item;

  /// The gap between two items starting, while [cap] allows it.
  final Duration step;

  /// The longest the last item waits before it starts. Null means no limit.
  final Duration? cap;

  /// The gap between two items starting, in microseconds, [cap] applied.
  double get _stepUs {
    final double wanted = math.max(0, step.inMicroseconds).toDouble();
    final Duration? limit = cap;
    if (limit == null || count <= 1) return wanted;
    return math.min(wanted, math.max(0, limit.inMicroseconds) / (count - 1));
  }

  /// The time from the first item starting to the last one finishing.
  Duration get total => item + Duration(microseconds: (_stepUs * math.max(0, count - 1)).round());

  /// The progress (0 to 1) of item [index] when the whole cascade is at
  /// [progress] (0 to 1 over [total]). With [steps] the result is quantised
  /// like `steps(steps, end)`.
  double at(double progress, int index, {int? steps}) {
    if (progress >= 1) return 1;
    final int totalUs = total.inMicroseconds;
    final int itemUs = item.inMicroseconds;
    if (totalUs <= 0 || itemUs <= 0) return 1;
    final double elapsed = progress.clamp(0.0, 1.0) * totalUs - _stepUs * index;
    final double t = (elapsed / itemUs).clamp(0.0, 1.0);
    if (steps == null) return t;
    return KkSteps(steps).transform(t);
  }
}
