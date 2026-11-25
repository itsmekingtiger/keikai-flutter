import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../motion/scramble.dart';
import '../widgets/text.dart';
import 'plot.dart';
import 'series.dart';

/// Parts of a whole as a ring: the total in the hole, a legend with each
/// part's value and share beside it.
///
/// The ring is 136px with an 18px band. Hovering a part (or its legend row),
/// or moving to it with the arrow keys, dims the others to 30%. The arcs wipe
/// in one after another and the total scrambles when it changes. Keep to
/// three parts plus OTHER (`kkGroupOtherSlices`).
class KkDonut extends StatefulWidget {
  const KkDonut({
    super.key,
    required this.slices,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.total,
    this.caption = 'TOTAL',
    this.format,
    this.percentDecimals = 1,
    this.size = 136,
    this.thickness = 18,
    this.gap = 2,
    this.legend = true,
    this.focusable = true,
    this.onSliceHover,
    this.onSliceTap,
    this.scramble = true,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// The parts, clockwise from the top. Zero and negative values are left out
  /// of the ring.
  final List<KkSlice> slices;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the donut bare.
  final bool frame;

  /// The text in the hole. Defaults to the formatted sum.
  final String? total;

  /// Small capitals under the total.
  final String? caption;

  /// Formats a value. Defaults to a whole number (one decimal when the values
  /// are not whole).
  final String Function(double value)? format;
  final int percentDecimals;

  /// Outer diameter of the ring.
  final double size;

  /// Width of the ring's band.
  final double thickness;

  /// Gap between parts, in px along the ring.
  final double gap;

  /// Show the legend beside the ring.
  final bool legend;

  /// Let the ring take keyboard focus (arrow keys move between parts).
  final bool focusable;

  /// The hovered part, or null when the pointer leaves.
  final ValueChanged<int?>? onSliceHover;
  final ValueChanged<int>? onSliceTap;

  /// Scramble the total when it changes.
  final bool scramble;

  /// Play the wipe-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkDonut> createState() => _KkDonutState();
}

class _KkDonutState extends State<KkDonut> {
  final ValueNotifier<int?> _active = ValueNotifier<int?>(null);

  List<double> get _values => <double>[
    for (final KkSlice s in widget.slices) (s.value.isFinite && s.value > 0) ? s.value : 0,
  ];

  void _setActive(int? index) {
    if (_active.value == index) return;
    _active.value = index;
    widget.onSliceHover?.call(index);
  }

  int? _sliceAt(Offset position, Size size) {
    final List<double> values = _values;
    final double total = values.fold<double>(0, (double a, double b) => a + b);
    if (!(total > 0)) return null;
    final Offset d = position - size.center(Offset.zero);
    final double outer = math.min(size.width, size.height) / 2;
    final double r = d.distance;
    if (r > outer + 2 || r < outer - widget.thickness - 2) return null;
    double a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    double start = 0;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final double sweep = 2 * math.pi * values[i] / total;
      if (a >= start && a < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  void _step(int dx, int dy) {
    final List<double> values = _values;
    final List<int> shown = <int>[
      for (int i = 0; i < values.length; i++)
        if (values[i] > 0) i,
    ];
    if (shown.isEmpty) return;
    final int delta = dx != 0 ? dx : dy;
    if (delta == 0) return;
    final int? current = _active.value;
    final int at = current == null ? -1 : shown.indexOf(current);
    final int next = at < 0 ? (delta > 0 ? 0 : shown.length - 1) : (at + delta) % shown.length;
    _setActive(shown[next < 0 ? next + shown.length : next]);
  }

  @override
  void didUpdateWidget(KkDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? active = _active.value;
    if (active != null && active >= widget.slices.length) _active.value = null;
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
    final List<KkSlice> slices = widget.slices;
    final List<double> values = _values;
    final double sum = values.fold<double>(0, (double a, double b) => a + b);
    final bool whole = values.every((double v) => v == v.roundToDouble());
    String text(double v) {
      if (!v.isFinite) return '--';
      return widget.format?.call(v) ?? (whole ? v.round().toString() : v.toStringAsFixed(1));
    }

    final List<Color> colors = <Color>[
      for (int i = 0; i < slices.length; i++)
        slices[i].color ?? (slices[i].level != null ? c.level(slices[i].level) : kkSeriesColor(c, i)),
    ];
    final KkCascade cascade = KkCascade(
      count: slices.length,
      item: KkMotion.wipe,
      step: const Duration(milliseconds: 90),
    );
    final String totalText = widget.total ?? text(sum);
    final String? caption = widget.caption;

    Widget ring = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 300),
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _DonutPainter(
            values: values,
            colors: colors,
            empty: c.signalDim,
            thickness: widget.thickness,
            gap: widget.gap,
            cascade: cascade,
            progress: progress,
            active: _active,
          ),
        );
      },
    );
    ring = KkPlotPointer(
      onMove: (Offset? position, Size size) => _setActive(position == null ? null : _sliceAt(position, size)),
      onTap: (Offset position, Size size) {
        final int? index = _sliceAt(position, size);
        if (index != null) widget.onSliceTap?.call(index);
      },
      child: ring,
    );
    ring = KkPlotFocus(
      enabled: widget.focusable,
      onStep: _step,
      onActivate: () {
        final int? index = _active.value;
        if (index != null) widget.onSliceTap?.call(index);
      },
      onDismiss: () => _setActive(null),
      ringOffset: 2,
      child: ring,
    );

    final double hole = math.max(0, widget.size - widget.thickness * 2 - 8);
    final Widget dial = KkBox(
      width: widget.size,
      height: widget.size,
      child: KkLayers(
        alignment: Alignment.center,
        children: <Widget>[
          ring,
          IgnorePointer(
            child: KkBox(
              maxWidth: hole,
              clip: true,
              child: KkColumn(
                shrinkWrap: true,
                gap: 4,
                cross: KkCrossAlign.center,
                children: <Widget>[
                  KkScramble(
                    totalText,
                    style: theme.type.mono(24, weight: FontWeight.w500, color: c.ink),
                    enabled: widget.scramble,
                  ),
                  if (caption != null && caption.isNotEmpty)
                    KkText.en(caption, size: 9, weight: FontWeight.w700, spacing: 0.16, color: c.inkDim),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    String percent(double v) => sum > 0 ? '${(v / sum * 100).toStringAsFixed(widget.percentDecimals)}%' : '--';

    final Widget body = KkBox(
      padding: EdgeInsets.all(theme.metrics.space3),
      alignment: Alignment.centerLeft,
      clip: true,
      child: KkRow(
        gap: theme.metrics.space4,
        children: <Widget>[
          dial,
          if (widget.legend)
            KkExpanded(
              child: KkColumn(
                gap: 7,
                shrinkWrap: true,
                children: <Widget>[
                  for (int i = 0; i < slices.length; i++)
                    MouseRegion(
                      onEnter: (PointerEnterEvent event) => _setActive(values[i] > 0 ? i : null),
                      onExit: (PointerExitEvent event) => _setActive(null),
                      child: KkRow(
                        gap: theme.metrics.space2,
                        children: <Widget>[
                          KkBox(width: 10, height: 10, fill: colors[i]),
                          KkExpanded(
                            child: KkText.en(
                              slices[i].name,
                              size: 12,
                              weight: FontWeight.w600,
                              spacing: 0.06,
                              color: c.ink,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          KkText.num(text(slices[i].value), size: 12, weight: FontWeight.w500, color: c.ink),
                          KkBox(
                            width: 44,
                            alignment: Alignment.centerRight,
                            child: KkText.num(percent(values[i]), size: 11, color: c.inkDim),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: slices.isEmpty
          ? 'no data'
          : <String>[
              '${caption ?? 'total'} $totalText',
              for (int i = 0; i < slices.length; i++) '${slices[i].name} ${text(slices[i].value)} ${percent(values[i])}',
            ].join(', '),
      child: body,
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.empty,
    required this.thickness,
    required this.gap,
    required this.cascade,
    required this.progress,
    required this.active,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, active]));

  final List<double> values;
  final List<Color> colors;
  final Color empty;
  final double thickness;
  final double gap;
  final KkCascade cascade;
  final Animation<double> progress;
  final ValueNotifier<int?> active;

  @override
  void paint(Canvas canvas, Size size) {
    final double outer = math.min(size.width, size.height) / 2;
    final double band = math.min(thickness, outer);
    final double radius = outer - band / 2;
    if (!(radius > 0) || !(band > 0)) return;
    final Rect rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = band;
    double total = 0;
    int shown = 0;
    for (final double v in values) {
      if (v > 0) {
        total += v;
        shown++;
      }
    }
    if (!(total > 0)) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = empty);
      return;
    }
    final double gapAngle = shown > 1 ? gap / radius : 0;
    final int? hover = active.value;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (!(values[i] > 0)) continue;
      final double sweep = math.pi * 2 * values[i] / total;
      final double visible = math.max(sweep - gapAngle, math.min(sweep, 0.01));
      final double t = cascade.at(progress.value, i, steps: KkMotion.wipeSteps);
      if (t > 0) {
        final Color color = i < colors.length ? colors[i] : empty;
        paint.color = (hover != null && hover != i) ? color.withValues(alpha: color.a * 0.3) : color;
        canvas.drawArc(rect, start + (sweep - visible) / 2, visible * t, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.empty != empty ||
      oldDelegate.thickness != thickness ||
      oldDelegate.gap != gap ||
      oldDelegate.progress != progress;
}
