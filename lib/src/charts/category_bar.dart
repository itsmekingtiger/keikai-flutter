import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/wrap.dart';
import '../motion/entrances.dart';
import '../widgets/frame.dart';
import '../widgets/text.dart';
import 'format.dart';
import 'plot.dart';
import 'series.dart';

/// A single bar split into weighted segments, with a title, a meta value, an
/// optional marker and a legend: a budget, a capacity split, a mix.
///
/// The bar is 12px tall with 2px gaps between segments. Segments take the
/// fixed series colours in order (or their level's colour) and grow in from
/// the left one after another (0.5s in 8 steps, 80ms apart).
class KkCategoryBar extends StatelessWidget {
  const KkCategoryBar({
    super.key,
    required this.segments,
    this.cjk,
    this.en,
    this.meta,
    this.marker,
    this.legend = true,
    this.format,
    this.barHeight = 12,
    this.frame = true,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  /// The parts of the bar. Widths follow the values; zero and negative values
  /// are left out.
  final List<KkSlice> segments;
  final String? cjk;
  final String? en;

  /// Mono value at the right of the title (`072 / 100`).
  final String? meta;

  /// Position (0 to 1) of an ink tick across the bar: a target, a limit.
  final double? marker;

  /// Show the legend under the bar.
  final bool legend;

  /// Formats a segment's value in the legend. Defaults to a whole number.
  final String Function(double value)? format;
  final double barHeight;

  /// Draw the widget frame. False leaves the bar bare.
  final bool frame;

  /// Play the grow-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final List<Color> colors = <Color>[
      for (int i = 0; i < segments.length; i++)
        segments[i].color ??
            (segments[i].level != null ? c.level(segments[i].level) : kkSeriesColor(c, i)),
    ];
    final List<double> weights = <double>[
      for (final KkSlice s in segments) (s.value.isFinite && s.value > 0) ? s.value : 0,
    ];
    final KkCascade cascade = KkCascade(
      count: segments.length,
      item: const Duration(milliseconds: 500),
      step: const Duration(milliseconds: 80),
    );
    String text(double v) => !v.isFinite ? '--' : (format?.call(v) ?? kkPlain(v));
    final bool hasHead = cjk != null || en != null || meta != null;
    final double? m = marker;

    final Widget bar = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 200),
      stagger: false,
      enabled: animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkCanvas(
          naturalWidth: 200,
          naturalHeight: barHeight,
          painter: _CategoryBarPainter(
            weights: weights,
            colors: colors,
            marker: (m != null && m.isFinite) ? m.clamp(0.0, 1.0) : null,
            markerColor: c.ink,
            markerWidth: theme.metrics.stroke2,
            cascade: cascade,
            progress: progress,
          ),
        );
      },
    );

    final Widget body = KkColumn(
      gap: 8,
      shrinkWrap: true,
      children: <Widget>[
        if (hasHead)
          KkRow(
            gap: theme.metrics.space3,
            cross: KkCrossAlign.baseline,
            clip: Clip.hardEdge,
            children: <Widget>[
              KkRow(
                shrinkWrap: true,
                gap: theme.metrics.space2,
                cross: KkCrossAlign.baseline,
                children: <Widget>[
                  if (cjk != null) KkText.cjk(cjk!, size: 15, height: 1.55, color: c.ink, squeeze: 0.8),
                  if (en != null) KkText.en(en!, size: 11, height: 1.55, spacing: 0.14, color: c.inkDim),
                ],
              ),
              const KkSpacer(),
              if (meta != null) KkText.num(meta!, size: 13, weight: FontWeight.w500, color: c.ink),
            ],
          ),
        KkBox(height: barHeight, child: bar),
        if (legend && segments.isNotEmpty)
          KkWrap(
            gap: 14,
            runGap: 4,
            children: <Widget>[
              for (int i = 0; i < segments.length; i++)
                KkWidgetKey(label: segments[i].name, color: colors[i], box: true, value: text(segments[i].value)),
            ],
          ),
      ],
    );

    return KkChartFrame(
      frame: frame,
      boot: boot,
      semanticLabel: semanticLabel ?? <String>[?cjk, ?en?.toUpperCase()].join(' '),
      semanticValue: segments.isEmpty
          ? 'no data'
          : <String>[for (final KkSlice s in segments) '${s.name} ${text(s.value)}'].join(', '),
      child: frame ? KkBox(padding: EdgeInsets.all(theme.metrics.space3), clip: true, child: body) : body,
    );
  }
}

class _CategoryBarPainter extends CustomPainter {
  _CategoryBarPainter({
    required this.weights,
    required this.colors,
    required this.marker,
    required this.markerColor,
    required this.markerWidth,
    required this.cascade,
    required this.progress,
  }) : super(repaint: progress);

  final List<double> weights;
  final List<Color> colors;
  final double? marker;
  final Color markerColor;
  final double markerWidth;
  final KkCascade cascade;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    int shown = 0;
    double total = 0;
    for (final double w in weights) {
      if (w > 0) {
        shown++;
        total += w;
      }
    }
    if (shown > 0 && total > 0) {
      const double gap = 2;
      final double usable = math.max(0, size.width - gap * (shown - 1));
      double x = 0;
      final Paint paint = Paint();
      for (int i = 0; i < weights.length; i++) {
        if (!(weights[i] > 0)) continue;
        final double width = usable * weights[i] / total;
        final double t = cascade.at(progress.value, i, steps: 8);
        if (t > 0 && width > 0) {
          paint.color = colors[i];
          canvas.drawRect(Rect.fromLTWH(x, 0, width * t, size.height), paint);
        }
        x += width + gap;
      }
    }
    final double? m = marker;
    if (m != null) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * m - markerWidth / 2, -5, markerWidth, size.height + 10),
        Paint()..color = markerColor,
      );
    }
  }

  @override
  bool shouldRepaint(_CategoryBarPainter oldDelegate) =>
      oldDelegate.weights != weights ||
      oldDelegate.colors != colors ||
      oldDelegate.marker != marker ||
      oldDelegate.markerColor != markerColor ||
      oldDelegate.progress != progress;
}
