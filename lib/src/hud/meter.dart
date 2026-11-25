import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../painting/patterns.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';
import 'hug.dart';
import 'state_word.dart';

/// A segmented level meter with caution and critical thresholds.
///
/// [value] is the fill, 0 to 1. The lit part is always a whole number of 8px
/// segments and moves to a new value in nine steps over 0.45s. Two marks show
/// where caution ([warn]) and critical ([crit]) begin; unless you give a
/// [level], the meter takes its level from them.
class KkMeter extends StatelessWidget {
  const KkMeter({
    super.key,
    this.cjk,
    this.en,
    required this.value,
    this.valueText,
    this.unit,
    this.level,
    this.autoLevel = true,
    this.warn = 0.7,
    this.crit = 0.9,
    this.showMarks = true,
    this.ticks = const <String>[],
    this.minWidth = 200,
    this.barHeight = 14,
    this.color,
    this.animate = true,
    this.squeeze = 0.8,
  });

  final String? cjk;
  final String? en;

  /// The fill, 0 to 1. Values outside are clamped.
  final double value;

  /// The number shown at the right of the head. Defaults to the percentage
  /// with three digits (`078`).
  final String? valueText;

  /// Written small after the number: `%`, `kPa`.
  final String? unit;

  /// Overrides the level taken from the thresholds.
  final KkLevel? level;

  /// Take the level from [warn] and [crit] when [level] is null.
  final bool autoLevel;

  /// Where caution begins, 0 to 1.
  final double warn;

  /// Where critical begins, 0 to 1.
  final double crit;

  /// Draw the two threshold marks.
  final bool showMarks;

  /// Scale labels under the bar, spread from end to end: `0`, `50`, `100`.
  final List<String> ticks;
  final double minWidth;
  final double barHeight;

  /// Overrides the colour of the lit segments (the level's colour, or signal).
  final Color? color;

  /// Step to a new value instead of jumping.
  final bool animate;

  /// Horizontal compression of [cjk]; 1.0 turns it off.
  final double squeeze;

  /// The level a meter at [value] shows: critical from [crit], caution from
  /// [warn], none below.
  static KkLevel? levelFor(double value, {double warn = 0.7, double crit = 0.9}) {
    if (value.isNaN) return null;
    if (value >= crit) return KkLevel.critical;
    if (value >= warn) return KkLevel.caution;
    return null;
  }

  /// The width in px of the lit part of a bar [width] px wide: [value] of the
  /// width, rounded down to whole [pitch] segments.
  static double litWidth(double value, double width, {double pitch = 8}) {
    if (value.isNaN || width <= 0 || pitch <= 0) return 0;
    final double v = value.clamp(0.0, 1.0);
    return ((v * width) / pitch + 1e-9).floorToDouble() * pitch;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final KkLevel? lv = level ?? (autoLevel ? levelFor(v, warn: warn, crit: crit) : null);
    final Color lit = color ?? c.level(lv);
    final Color ink = lv != null ? c.level(lv) : c.ink;
    final String number = valueText ?? kkFixedDigits((v * 100).round(), decimals: 0);
    final String? label = cjk;
    final String? sub = en;
    final String? u = unit;

    Widget bar(double shown) => CustomPaint(
      size: Size(0, barHeight),
      painter: _MeterPainter(
        value: shown,
        unlit: c.signalDim,
        lit: lit,
        pitch: m.pitchFine,
        gap: m.stroke2,
        warn: showMarks ? warn : null,
        crit: showMarks ? crit : null,
        caution: c.caution,
        alert: c.alert,
        markWidth: m.stroke2,
      ),
    );

    return KkHugWidth(
      child: Semantics(
        container: true,
        label: <String>[?label, ?sub].join(' '),
        value: <String>[number, ?u, ?lv?.word].join(' '),
        child: ExcludeSemantics(
          child: KkBox(
            minWidth: minWidth,
            child: KkColumn(
              gap: m.space2,
              shrinkWrap: true,
              children: <Widget>[
                KkRow(
                  gap: m.space2,
                  cross: KkCrossAlign.baseline,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    if (label != null) KkText.cjk(label, size: 14, height: 1.55, color: c.ink, squeeze: squeeze),
                    if (sub != null)
                      KkText.en(sub, size: 11, weight: FontWeight.w600, height: 1.55, spacing: 0.14, color: c.inkDim),
                    const KkSpacer(),
                    KkRow(
                      shrinkWrap: true,
                      gap: 6,
                      cross: KkCrossAlign.baseline,
                      children: <Widget>[
                        if (lv != null)
                          KkAlignSelf(
                            align: KkCrossAlign.center,
                            child: KkGlyph(level: lv, size: 12, color: ink),
                          ),
                        KkText.num(number, size: 18, weight: FontWeight.w500, color: ink),
                        if (u != null)
                          KkText.en(
                            u,
                            size: 11,
                            weight: FontWeight.w600,
                            spacing: 0.06,
                            color: c.inkDim,
                            upper: false,
                          ),
                      ],
                    ),
                  ],
                ),
                if (animate) KkSteppedValue(value: v, builder: (BuildContext context, double shown) => bar(shown)) else bar(v),
                if (ticks.isNotEmpty)
                  KkRow(
                    main: KkMainAlign.between,
                    clip: Clip.hardEdge,
                    children: <Widget>[for (final String t in ticks) KkText.num(t, size: 10, color: c.inkFaint)],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({
    required this.value,
    required this.unlit,
    required this.lit,
    required this.pitch,
    required this.gap,
    required this.warn,
    required this.crit,
    required this.caution,
    required this.alert,
    required this.markWidth,
  });

  final double value;
  final Color unlit;
  final Color lit;
  final double pitch;
  final double gap;
  final double? warn;
  final double? crit;
  final Color caution;
  final Color alert;
  final double markWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    kkPaintSegments(canvas, rect, unlit, pitch: pitch, gap: gap);
    final double w = KkMeter.litWidth(value, size.width, pitch: pitch);
    if (w > 0) kkPaintSegments(canvas, Rect.fromLTWH(0, 0, w, size.height), lit, pitch: pitch, gap: gap);
    void mark(double? at, Color color) {
      if (at == null || at.isNaN) return;
      final double left = (size.width - markWidth) * at.clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(left, -4, markWidth, size.height + 8), Paint()..color = color);
    }

    mark(warn, caution);
    mark(crit, alert);
  }

  @override
  bool shouldRepaint(_MeterPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.unlit != unlit ||
      oldDelegate.lit != lit ||
      oldDelegate.pitch != pitch ||
      oldDelegate.gap != gap ||
      oldDelegate.warn != warn ||
      oldDelegate.crit != crit ||
      oldDelegate.caution != caution ||
      oldDelegate.alert != alert ||
      oldDelegate.markWidth != markWidth;
}
