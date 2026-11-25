import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../painting/patterns.dart';
import '../widgets/frame.dart';
import '../widgets/text.dart';
import 'plot.dart';
import 'series.dart';

/// One stretch of a status timeline.
@immutable
class KkTimelineSpan {
  const KkTimelineSpan(this.level, {this.weight = 1, this.label});

  /// The status during this stretch. Null means no data.
  final KkLevel? level;

  /// Relative length (a duration in any unit).
  final double weight;

  /// Free text for whoever listens to hover and tap (a time range, a cause).
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is KkTimelineSpan &&
      other.level == level &&
      (other.weight == weight || (other.weight.isNaN && weight.isNaN)) &&
      other.label == label;

  @override
  int get hashCode => Object.hash(level, weight.isNaN ? 0 : weight, label);

  @override
  String toString() => 'KkTimelineSpan($level, weight: $weight${label == null ? '' : ', label: $label'})';
}

/// One row of a status timeline: a name and its stretches, oldest first.
@immutable
class KkTimelineRow {
  const KkTimelineRow({this.cjk, this.en, required this.spans, this.percent});

  final String? cjk;

  /// Latin name (capitals).
  final String? en;

  /// The stretches of this row, oldest first.
  final List<KkTimelineSpan> spans;

  /// The figure at the right, 0 to 100. Defaults to the share of the row that
  /// is nominal.
  final double? percent;
}

/// The stretch under the pointer in a [KkStatusTimeline].
@immutable
class KkTimelineHit {
  const KkTimelineHit(this.row, this.index, this.span);

  final int row;
  final int index;
  final KkTimelineSpan span;

  @override
  bool operator ==(Object other) =>
      other is KkTimelineHit && other.row == row && other.index == index && other.span == span;

  @override
  int get hashCode => Object.hash(row, index, span);

  @override
  String toString() => 'KkTimelineHit(row: $row, index: $index, $span)';
}

/// Status over time, one row per channel: when each one was nominal, in
/// caution, critical, or offline, and the share of time it was up.
///
/// Tracks are 18px tall with 2px between stretches. Nominal is a muted green
/// (62% over the panel), caution and critical are solid, offline is a 45°
/// hatch, and a stretch with no data is dim. Rows wipe in from the left
/// (0.6s in 12 steps, 80ms apart).
///
/// With [onSpanHover] or [onSpanTap] the tracks answer the pointer and the
/// keyboard: the arrow keys walk the stretches (left and right along a row,
/// up and down to the stretch at the same moment in the next row), Home and
/// End jump to the ends of the row, Enter taps and Escape lets go.
class KkStatusTimeline extends StatefulWidget {
  const KkStatusTimeline({
    super.key,
    required this.rows,
    this.axis = const <String>[],
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.trackHeight = 18,
    this.showPercent = true,
    this.percentDecimals = 1,
    this.legend = true,
    this.focusable = true,
    this.onSpanHover,
    this.onSpanTap,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// One row per channel.
  final List<KkTimelineRow> rows;

  /// Labels spread evenly under the tracks (times, oldest first).
  final List<String> axis;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the timeline bare.
  final bool frame;

  /// Height of a track.
  final double trackHeight;

  /// Show the percent column.
  final bool showPercent;

  /// Decimals of the percent column.
  final int percentDecimals;

  /// Show a key for every level that appears.
  final bool legend;

  /// Let the tracks take keyboard focus when there is a hover or tap listener.
  final bool focusable;

  /// The stretch under the pointer, or null when it leaves.
  final ValueChanged<KkTimelineHit?>? onSpanHover;

  /// The stretch that was tapped (or activated with Enter).
  final ValueChanged<KkTimelineHit>? onSpanTap;

  /// Play the wipe-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkStatusTimeline> createState() => _KkStatusTimelineState();
}

double? _nominalShare(KkTimelineRow row) {
  double total = 0;
  double up = 0;
  for (final KkTimelineSpan s in row.spans) {
    if (!s.weight.isFinite || s.weight <= 0) continue;
    total += s.weight;
    if (s.level == KkLevel.nominal) up += s.weight;
  }
  return total > 0 ? up / total * 100 : null;
}

/// The left edge and width of every stretch across a track [width] wide.
List<Rect> _spanRects(List<KkTimelineSpan> spans, double width, double height) {
  const double gap = 2;
  const double minWidth = 2;
  final List<int> shown = <int>[
    for (int i = 0; i < spans.length; i++)
      if (spans[i].weight.isFinite && spans[i].weight > 0) i,
  ];
  final List<Rect> rects = List<Rect>.filled(spans.length, Rect.zero);
  if (shown.isEmpty || width <= 0) return rects;
  final double usable = math.max(0, width - gap * (shown.length - 1));
  double total = 0;
  for (final int i in shown) {
    total += spans[i].weight;
  }
  // Every stretch is at least 2px wide; the rest share what is left.
  double floor = 0;
  double flexible = 0;
  for (final int i in shown) {
    if (usable * spans[i].weight / total < minWidth) {
      floor += minWidth;
    } else {
      flexible += spans[i].weight;
    }
  }
  final double rest = math.max(0, usable - floor);
  double x = 0;
  for (final int i in shown) {
    final double natural = usable * spans[i].weight / total;
    final double w = natural < minWidth ? minWidth : (flexible > 0 ? rest * spans[i].weight / flexible : natural);
    rects[i] = Rect.fromLTWH(x, 0, w, height);
    x += w + gap;
  }
  return rects;
}

class _KkStatusTimelineState extends State<KkStatusTimeline> {
  final ValueNotifier<KkTimelineHit?> _active = ValueNotifier<KkTimelineHit?>(null);

  void _setActive(KkTimelineHit? hit) {
    if (_active.value == hit) return;
    _active.value = hit;
    widget.onSpanHover?.call(hit);
  }

  KkTimelineHit? _hit(int row, Offset position, Size size) {
    final List<KkTimelineSpan> spans = widget.rows[row].spans;
    final List<Rect> rects = _spanRects(spans, size.width, size.height);
    for (int i = 0; i < rects.length; i++) {
      if (rects[i].width > 0 && position.dx >= rects[i].left - 1 && position.dx <= rects[i].right + 1) {
        return KkTimelineHit(row, i, spans[i]);
      }
    }
    return null;
  }

  KkTimelineHit _at(int row, int index) => KkTimelineHit(row, index, widget.rows[row].spans[index]);

  /// The stretch of [row] nearest to [x] on a track [_reference] wide.
  int? _nearest(int row, double x) {
    final List<Rect> rects = _spanRects(widget.rows[row].spans, _reference, 1);
    int? best;
    double bestDistance = double.infinity;
    for (int i = 0; i < rects.length; i++) {
      if (!(rects[i].width > 0)) continue;
      final double d = x < rects[i].left ? rects[i].left - x : (x > rects[i].right ? x - rects[i].right : 0);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  /// Any width will do for comparing positions between rows.
  static const double _reference = 1000;

  void _step(int dx, int dy) {
    final List<KkTimelineRow> rows = widget.rows;
    final KkTimelineHit? current = _active.value;
    if (current == null || current.row >= rows.length || current.index >= rows[current.row].spans.length) {
      // Nothing under the cursor yet: start at the first stretch there is.
      for (int r = 0; r < rows.length; r++) {
        final int? first = _nearest(r, dx < 0 ? _reference : 0);
        if (first != null) return _setActive(_at(r, first));
      }
      return;
    }
    final List<Rect> here = _spanRects(rows[current.row].spans, _reference, 1);
    if (dx != 0) {
      for (int i = current.index + dx; i >= 0 && i < here.length; i += dx) {
        if (here[i].width > 0) return _setActive(_at(current.row, i));
      }
      return;
    }
    if (dy != 0) {
      final double x = here[current.index].center.dx;
      for (int r = current.row + dy; r >= 0 && r < rows.length; r += dy) {
        final int? index = _nearest(r, x);
        if (index != null) return _setActive(_at(r, index));
      }
    }
  }

  void _jump(bool toEnd) {
    final KkTimelineHit? current = _active.value;
    final int row = (current != null && current.row < widget.rows.length) ? current.row : 0;
    if (row >= widget.rows.length) return;
    final int? index = _nearest(row, toEnd ? _reference : 0);
    if (index != null) _setActive(_at(row, index));
  }

  @override
  void didUpdateWidget(KkStatusTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final KkTimelineHit? hit = _active.value;
    if (hit == null) return;
    if (widget.onSpanHover == null && widget.onSpanTap == null) {
      // No listener is left, so nothing can move the cursor away: let go.
      _active.value = null;
      return;
    }
    // The stretch under the cursor is gone, or is no longer the same one.
    final KkTimelineHit? fresh = (hit.row >= widget.rows.length || hit.index >= widget.rows[hit.row].spans.length)
        ? null
        : _at(hit.row, hit.index);
    if (fresh != hit) {
      _active.value = fresh;
      kkNotifyAfterFrame(this, () => widget.onSpanHover?.call(_active.value));
    }
  }

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final List<KkTimelineRow> rows = widget.rows;
    final KkCascade cascade = KkCascade(
      count: rows.length,
      item: const Duration(milliseconds: 600),
      step: const Duration(milliseconds: 80),
      // However many rows there are, the last one starts within 1.2s.
      cap: const Duration(milliseconds: 1200),
    );
    final bool interactive = widget.onSpanHover != null || widget.onSpanTap != null;
    final bool hasAxis = widget.axis.isNotEmpty;

    String percentText(KkTimelineRow row) {
      final double? p = row.percent ?? _nominalShare(row);
      return (p == null || !p.isFinite) ? '--' : p.toStringAsFixed(widget.percentDecimals.clamp(0, 20));
    }

    Widget grid = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 200),
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return _TlGrid(
          columnGap: theme.metrics.space3,
          rowGap: 7,
          hasAxis: hasAxis,
          children: <Widget>[
            for (int r = 0; r < rows.length; r++) ...<Widget>[
              KkRow(
                shrinkWrap: true,
                gap: 6,
                cross: KkCrossAlign.baseline,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (rows[r].cjk != null) KkText.cjk(rows[r].cjk!, size: 13, color: c.ink, squeeze: 0.8),
                  if (rows[r].en != null)
                    KkText.en(rows[r].en!, size: 12, weight: FontWeight.w600, spacing: 0.08, color: c.ink),
                ],
              ),
              _track(theme, r, cascade, progress, interactive),
              if (widget.showPercent)
                KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.baseline,
                  children: <Widget>[
                    KkText.num(percentText(rows[r]), size: 12, weight: FontWeight.w500, color: c.ink),
                    KkText.num('%', size: 10, weight: FontWeight.w500, color: c.inkDim),
                  ],
                )
              else
                const KkGap(0),
            ],
            if (hasAxis)
              KkRow(
                main: KkMainAlign.between,
                clip: Clip.hardEdge,
                children: <Widget>[
                  for (final String label in widget.axis) KkText.num(label, size: 10, color: c.inkFaint),
                ],
              ),
          ],
        );
      },
    );

    if (interactive) {
      grid = KkPlotFocus(
        enabled: widget.focusable,
        onStep: _step,
        onJump: _jump,
        onActivate: () {
          final KkTimelineHit? hit = _active.value;
          if (hit != null) widget.onSpanTap?.call(hit);
        },
        onDismiss: () => _setActive(null),
        ringOffset: 4,
        child: grid,
      );
    }

    final Set<KkLevel?> present = <KkLevel?>{
      for (final KkTimelineRow row in rows)
        for (final KkTimelineSpan s in row.spans) s.level,
    };
    final List<Widget> keys = <Widget>[
      for (final KkLevel level in KkLevel.values)
        if (present.contains(level))
          KkWidgetKey(
            label: level.word,
            swatch: CustomPaint(
              size: const Size(10, 10),
              painter: _SwatchPainter(level: level, colors: c),
            ),
          ),
      if (present.contains(null)) KkWidgetKey(label: 'NO DATA', color: c.signalDim, box: true),
    ];

    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: rows.isEmpty
          ? 'no data'
          : <String>[for (final KkTimelineRow row in rows) '${row.en ?? row.cjk ?? ''} ${percentText(row)}%']
                .join(', '),
      legend: widget.legend && keys.isNotEmpty ? keys : null,
      child: KkBox(padding: EdgeInsets.all(theme.metrics.space3), clip: true, child: grid),
    );
  }

  Widget _track(KeikaiThemeData theme, int row, KkCascade cascade, Animation<double> progress, bool interactive) {
    final Widget track = KkCanvas(
      naturalWidth: 240,
      naturalHeight: widget.trackHeight,
      painter: _TrackPainter(
        row: row,
        spans: widget.rows[row].spans,
        colors: theme.colors,
        focusWidth: theme.metrics.stroke2,
        cascade: cascade,
        progress: progress,
        active: _active,
      ),
    );
    if (!interactive) return track;
    return KkPlotPointer(
      onMove: (Offset? position, Size size) => _setActive(position == null ? null : _hit(row, position, size)),
      onTap: (Offset position, Size size) {
        final KkTimelineHit? hit = _hit(row, position, size);
        if (hit != null) widget.onSpanTap?.call(hit);
      },
      child: track,
    );
  }
}

void _paintSpan(Canvas canvas, Rect rect, KkLevel? level, KkColors c) {
  switch (level) {
    case KkLevel.nominal:
      canvas.drawRect(rect, Paint()..color = kkMix(c.nominal, 0.62, c.bg100));
    case KkLevel.caution:
      canvas.drawRect(rect, Paint()..color = c.caution);
    case KkLevel.critical:
      canvas.drawRect(rect, Paint()..color = c.alert);
    case KkLevel.offline:
      kkPaintStripes(canvas, rect, a: c.offline, b: c.bg100, width: 2, period: 5);
    case null:
      canvas.drawRect(rect, Paint()..color = c.signalDim);
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.level, required this.colors});

  final KkLevel? level;
  final KkColors colors;

  @override
  void paint(Canvas canvas, Size size) => _paintSpan(canvas, Offset.zero & size, level, colors);

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) => oldDelegate.level != level || oldDelegate.colors != colors;
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.row,
    required this.spans,
    required this.colors,
    required this.focusWidth,
    required this.cascade,
    required this.progress,
    required this.active,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, active]));

  final int row;
  final List<KkTimelineSpan> spans;
  final KkColors colors;
  final double focusWidth;
  final KkCascade cascade;
  final Animation<double> progress;
  final ValueNotifier<KkTimelineHit?> active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final List<Rect> rects = _spanRects(spans, size.width, size.height);
    final double t = cascade.at(progress.value, row, steps: 12);
    if (t <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, -4, t >= 1 ? size.width + 4 : size.width * t, size.height + 4));
    for (int i = 0; i < rects.length; i++) {
      if (rects[i].width <= 0) continue;
      _paintSpan(canvas, rects[i], spans[i].level, colors);
    }
    final KkTimelineHit? hit = active.value;
    if (hit != null && hit.row == row && hit.index < rects.length && rects[hit.index].width > 0) {
      canvas.drawRect(
        rects[hit.index].inflate(1 + focusWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = focusWidth
          ..color = colors.focus,
      );
    }
    canvas.restore();
  }

  // The data lists belong to the caller and may have been changed in place,
  // so a rebuild always repaints.
  @override
  bool shouldRepaint(_TrackPainter oldDelegate) => true;
}

class _TlParentData extends ContainerBoxParentData<RenderBox> {}

/// Three columns (name, track, percent) sized like a CSS grid of
/// `max-content minmax(0, 1fr) max-content`, with an optional last child laid
/// under the track column.
class _TlGrid extends MultiChildRenderObjectWidget {
  const _TlGrid({required this.columnGap, required this.rowGap, required this.hasAxis, super.children});

  final double columnGap;
  final double rowGap;
  final bool hasAxis;

  @override
  _RenderTlGrid createRenderObject(BuildContext context) =>
      _RenderTlGrid(columnGap: columnGap, rowGap: rowGap, hasAxis: hasAxis);

  @override
  void updateRenderObject(BuildContext context, _RenderTlGrid renderObject) {
    renderObject
      ..columnGap = columnGap
      ..rowGap = rowGap
      ..hasAxis = hasAxis;
  }
}

class _RenderTlGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TlParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TlParentData> {
  _RenderTlGrid({required double columnGap, required double rowGap, required bool hasAxis})
    : _columnGap = columnGap,
      _rowGap = rowGap,
      _hasAxis = hasAxis;

  double _columnGap;
  set columnGap(double value) {
    if (value == _columnGap) return;
    _columnGap = value;
    markNeedsLayout();
  }

  double _rowGap;
  set rowGap(double value) {
    if (value == _rowGap) return;
    _rowGap = value;
    markNeedsLayout();
  }

  bool _hasAxis;
  set hasAxis(bool value) {
    if (value == _hasAxis) return;
    _hasAxis = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TlParentData) child.parentData = _TlParentData();
  }

  Size _layout(BoxConstraints constraints, ChildLayouter layoutChild, {required bool place}) {
    final List<RenderBox> kids = getChildrenAsList();
    final bool axis = _hasAxis && kids.isNotEmpty && (kids.length % 3 == 1);
    final int rowCount = (kids.length - (axis ? 1 : 0)) ~/ 3;
    final double maxWidth = constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
    final BoxConstraints nameLimit = BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth * 0.45 : double.infinity);
    final BoxConstraints pctLimit = BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth * 0.3 : double.infinity);

    final List<Size> names = <Size>[];
    final List<Size> pcts = <Size>[];
    double nameWidth = 0;
    double pctWidth = 0;
    for (int r = 0; r < rowCount; r++) {
      final Size n = layoutChild(kids[r * 3], nameLimit);
      final Size p = layoutChild(kids[r * 3 + 2], pctLimit);
      names.add(n);
      pcts.add(p);
      nameWidth = math.max(nameWidth, n.width);
      pctWidth = math.max(pctWidth, p.width);
    }
    final double leftGap = nameWidth > 0 ? _columnGap : 0;
    final double rightGap = pctWidth > 0 ? _columnGap : 0;
    final double trackWidth = maxWidth.isFinite
        ? math.max(0, maxWidth - nameWidth - pctWidth - leftGap - rightGap)
        : 240;
    final double width = maxWidth.isFinite ? maxWidth : nameWidth + leftGap + trackWidth + rightGap + pctWidth;
    final double trackLeft = nameWidth + leftGap;
    final BoxConstraints trackLimit = BoxConstraints.tightFor(width: trackWidth);

    double y = 0;
    for (int r = 0; r < rowCount; r++) {
      final Size t = layoutChild(kids[r * 3 + 1], trackLimit);
      final double height = math.max(t.height, math.max(names[r].height, pcts[r].height));
      if (place) {
        (kids[r * 3].parentData! as _TlParentData).offset = Offset(0, y + (height - names[r].height) / 2);
        (kids[r * 3 + 1].parentData! as _TlParentData).offset = Offset(trackLeft, y + (height - t.height) / 2);
        (kids[r * 3 + 2].parentData! as _TlParentData).offset = Offset(
          width - pcts[r].width,
          y + (height - pcts[r].height) / 2,
        );
      }
      y += height;
      if (r < rowCount - 1 || axis) y += _rowGap;
    }
    if (axis) {
      final Size a = layoutChild(kids.last, trackLimit);
      if (place) (kids.last.parentData! as _TlParentData).offset = Offset(trackLeft, y);
      y += a.height;
    }
    return constraints.constrain(Size(width, y));
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _layout(const BoxConstraints(), ChildLayoutHelper.dryLayoutChild, place: false).width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild, place: false).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  /// A grid of tracks has no baseline.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() => size = _layout(constraints, ChildLayoutHelper.layoutChild, place: true);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
