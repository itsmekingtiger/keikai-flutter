import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'column.dart';

/// The resolved columns of a table: every header, row and summary cell is
/// laid out from one of these.
@immutable
class KkTableGeometry {
  const KkTableGeometry({required this.widths, required this.offsets, required this.total, required this.rowWidth});

  /// No columns.
  static const KkTableGeometry empty = KkTableGeometry(widths: <double>[], offsets: <double>[], total: 0, rowWidth: 0);

  /// The width of each column.
  final List<double> widths;

  /// The left edge of each column.
  final List<double> offsets;

  /// The sum of [widths].
  final double total;

  /// The width of a row: [total], or the width of the table when the columns
  /// do not fill it.
  final double rowWidth;

  int get length => widths.length;

  @override
  bool operator ==(Object other) =>
      other is KkTableGeometry &&
      other.total == total &&
      other.rowWidth == rowWidth &&
      listEquals(other.widths, widths) &&
      listEquals(other.offsets, offsets);

  @override
  int get hashCode => Object.hash(total, rowWidth, Object.hashAll(widths));

  @override
  String toString() => 'KkTableGeometry($widths, rowWidth: $rowWidth)';
}

double _sane(double v) => (v.isFinite && v > 0) ? v : 0;

/// Resolves column widths for a table [available] px wide.
///
/// [header] is the natural width of each header cell and [cells] the widest
/// cell seen so far in each column (both include the cell padding).
///
/// * A fixed column takes its width.
/// * A content column takes the larger of its header and its cells, within
///   its `min` and `max`.
/// * A flex column starts at the larger of its `min` and its header (but not
///   above its `max`).
///
/// Width that is left over goes to the flex columns by their `flex` shares
/// (up to their `max`); when there is no flex column the content columns
/// share it in proportion to their own widths, as the auto columns of an HTML
/// table do. When the columns need more than [available] they keep their
/// widths and [KkTableGeometry.total] is larger than [available]: the table
/// scrolls sideways. An infinite [available] gives every column its starting
/// width.
///
/// With [snap] the column edges are on whole pixels: measured widths are
/// rounded up, shares of the spare width to the nearest pixel.
KkTableGeometry kkResolveTableWidths(
  List<KkTableWidth> columns, {
  required List<double> header,
  required List<double> cells,
  required double available,
  bool snap = true,
}) {
  final int n = columns.length;
  if (n == 0) {
    final double w = available.isFinite ? _sane(available) : 0;
    return KkTableGeometry(widths: const <double>[], offsets: const <double>[], total: 0, rowWidth: w);
  }
  final List<double> base = List<double>.filled(n, 0);
  final List<double> cap = List<double>.filled(n, 0);
  final List<double> weight = List<double>.filled(n, 0);
  bool anyFlex = false;
  for (int i = 0; i < n; i++) {
    final KkTableWidth c = columns[i];
    // Measured widths are rounded up when edges are snapped: a column a
    // fraction of a pixel narrower than its text would cut that text.
    double h = i < header.length ? _sane(header[i]) : 0;
    double seen = i < cells.length ? _sane(cells[i]) : 0;
    if (snap) {
      h = (h - 1e-6).ceilToDouble();
      seen = (seen - 1e-6).ceilToDouble();
    }
    if (c.isFixed) {
      base[i] = _sane(c.min);
      cap[i] = base[i];
    } else if (c.isContent) {
      final double lo = _sane(c.min);
      final double hi = c.max.isNaN ? double.infinity : math.max(lo, c.max);
      base[i] = math.min(math.max(math.max(h, seen), lo), hi);
      cap[i] = hi;
    } else {
      // The header can push the floor up, but never past the column's max.
      final double hi = c.max.isNaN ? double.infinity : math.max(_sane(c.min), c.max);
      final double lo = math.min(math.max(_sane(c.min), h), hi);
      base[i] = lo;
      cap[i] = hi;
      weight[i] = _sane(c.flex);
      if (weight[i] > 0) anyFlex = true;
    }
  }
  double sum = 0;
  for (final double b in base) {
    sum += b;
  }

  if (available.isFinite && available > sum) {
    double spare = available - sum;
    // Who grows: the flex columns, or, when there is none, the content
    // columns in proportion to what they hold.
    final List<int> growers = <int>[];
    for (int i = 0; i < n; i++) {
      if (anyFlex) {
        if (weight[i] > 0) growers.add(i);
      } else if (columns[i].isContent) {
        weight[i] = math.max(base[i], 1);
        growers.add(i);
      }
    }
    // Hand out the spare width; a column that reaches its cap leaves the
    // round and the rest is shared again.
    while (growers.isNotEmpty && spare > 1e-9) {
      double totalWeight = 0;
      for (final int i in growers) {
        totalWeight += weight[i];
      }
      if (totalWeight <= 0) break;
      int capped = -1;
      for (final int i in growers) {
        if (base[i] + spare * weight[i] / totalWeight > cap[i]) {
          capped = i;
          break;
        }
      }
      if (capped >= 0) {
        spare -= cap[capped] - base[capped];
        base[capped] = cap[capped];
        growers.remove(capped);
        continue;
      }
      for (final int i in growers) {
        base[i] += spare * weight[i] / totalWeight;
      }
      spare = 0;
    }
  }

  final List<double> widths = List<double>.filled(n, 0);
  final List<double> offsets = List<double>.filled(n, 0);
  double x = 0;
  double edge = 0;
  for (int i = 0; i < n; i++) {
    offsets[i] = edge;
    x += base[i];
    double next = snap ? x.roundToDouble() : x;
    if (available.isFinite) {
      // Columns that fill the table end exactly on its edge, also when the
      // table is a fraction of a pixel wide; columns that fit never round
      // their way past it.
      if ((x - available).abs() < 1e-6) {
        next = available;
      } else if (x < available) {
        next = math.min(next, available);
      }
    }
    next = math.max(edge, next);
    widths[i] = next - edge;
    edge = next;
  }
  final double rowWidth = available.isFinite ? math.max(_sane(available), edge) : edge;
  return KkTableGeometry(widths: widths, offsets: offsets, total: edge, rowWidth: rowWidth);
}
