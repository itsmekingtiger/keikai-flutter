import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../motion/entrances.dart';
import '../painting/text.dart';
import '../widgets/icon.dart';
import 'plot.dart';
import 'scale.dart';

/// A marked range on a gauge's rim: where caution or critical begins.
@immutable
class KkGaugeBand {
  const KkGaugeBand(this.from, this.to, this.level, {this.color});

  final double from;
  final double to;
  final KkLevel? level;

  /// Overrides the level colour.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is KkGaugeBand && other.from == from && other.to == to && other.level == level && other.color == color;

  @override
  int get hashCode => Object.hash(from, to, level, color);
}

/// A half-dial for one bounded value: a thick track, the filled part in the
/// level's colour, thin caution and critical bands on the rim, a needle, and
/// the value written large in the middle with its unit, limits and state.
///
/// On entry the fill wipes in and the needle sweeps up from zero (0.7s in 12
/// steps); afterwards the needle steps to each new value (0.5s in 10 steps)
/// and the number scrambles. The dial scales with the width, up to
/// [maxWidth].
class KkGauge extends StatelessWidget {
  const KkGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.level,
    this.unit,
    this.display,
    this.format,
    this.state,
    this.showState = true,
    this.caution,
    this.critical,
    this.bands,
    this.showLimits = true,
    this.limitFormat,
    this.ticks = 10,
    this.maxWidth = 300,
    this.scramble = true,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  final double value;
  final double min;
  final double max;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves the dial bare.
  final bool frame;

  /// Colours the fill, the number and the state word.
  final KkLevel? level;

  /// Written under the number (`°C`, `%`, `RPM`).
  final String? unit;

  /// The number as shown. Overrides [format].
  final String? display;

  /// Formats [value]. Defaults to the decimals the range calls for.
  final String Function(double value)? format;

  /// The state word. Defaults to the level's word.
  final String? state;

  /// Show the state word and status icon when there is a level or a [state].
  final bool showState;

  /// Where the caution band starts (it runs to [critical], or to [max]).
  final double? caution;

  /// Where the critical band starts (it runs to [max]).
  final double? critical;

  /// Explicit rim bands; overrides [caution] and [critical].
  final List<KkGaugeBand>? bands;

  /// Write [min] and [max] at the ends of the dial.
  final bool showLimits;
  final String Function(double value)? limitFormat;

  /// Number of divisions marked inside the dial.
  final int ticks;

  /// The dial stops growing at this width.
  final double maxWidth;

  /// Scramble the number when it changes.
  final bool scramble;

  /// Play the entrance (fill wipe, needle sweep) when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  /// The level a [value] falls in for the given thresholds: critical at or
  /// above [critical], caution at or above [caution], nominal below.
  static KkLevel levelFor(double value, {double? caution, double? critical}) {
    if (critical != null && value >= critical) return KkLevel.critical;
    if (caution != null && value >= caution) return KkLevel.caution;
    return KkLevel.nominal;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double span = max - min;
    final bool usable = span.isFinite && span > 0 && value.isFinite;
    final double fraction = usable ? ((value - min) / span).clamp(0.0, 1.0) : 0;
    final String text =
        display ?? (value.isFinite ? (format?.call(value) ?? kkFormatTick(value, usable ? span / 100 : 1)) : '--');
    final String? word = state ?? level?.word;
    final bool hasState = showState && word != null;
    String limit(double v) => limitFormat?.call(v) ?? kkFormatTick(v, usable ? span / 10 : 1);

    final List<KkGaugeBand> rim =
        bands ??
        <KkGaugeBand>[
          if (caution != null) KkGaugeBand(caution!, critical ?? max, KkLevel.caution),
          if (critical != null) KkGaugeBand(critical!, max, KkLevel.critical),
        ];
    final List<({double from, double to, Color color})> resolved = <({double from, double to, Color color})>[
      if (span.isFinite && span > 0)
        for (final KkGaugeBand b in rim)
          if (b.from.isFinite && b.to.isFinite)
            (
              from: ((b.from - min) / span).clamp(0.0, 1.0),
              to: ((b.to - min) / span).clamp(0.0, 1.0),
              color: b.color ?? theme.colors.level(b.level, fallback: theme.colors.inkDim),
            ),
    ];
    final double viewHeight = KkGaugePainter.viewHeightFor(hasState: hasState);

    final Widget dial = KkOneShot(
      duration: KkMotion.wipe,
      delay: const Duration(milliseconds: 300),
      enabled: animate,
      builder: (BuildContext context, Animation<double> entrance, bool done, Widget? _) {
        return KkSteppedValue(
          value: fraction,
          duration: const Duration(milliseconds: 500),
          steps: 10,
          builder: (BuildContext context, double needle) {
            return KkScrambleBuilder(
              text: text,
              enabled: scramble,
              builder: (BuildContext context, String shown) {
                return KkCanvas(
                  naturalWidth: 224,
                  aspectRatio: 200 / viewHeight,
                  insetWidth: 24,
                  maxContentWidth: maxWidth,
                  extraHeight: 16,
                  painter: KkGaugePainter(
                    fraction: fraction,
                    needle: needle,
                    entrance: entrance,
                    valueText: shown,
                    unit: unit,
                    stateWord: hasState ? word : null,
                    level: level,
                    minLabel: showLimits ? limit(min) : null,
                    maxLabel: showLimits ? limit(max) : null,
                    bands: resolved,
                    ticks: ticks,
                    maxWidth: maxWidth,
                    theme: theme,
                    scaler: scaler,
                  ),
                );
              },
            );
          },
        );
      },
    );

    return KkChartFrame(
      frame: frame,
      cjk: cjk,
      en: en,
      meta: meta,
      boot: boot,
      semanticLabel: semanticLabel,
      semanticValue: <String>['$text${unit == null ? '' : ' $unit'}', ?(hasState ? word : null)].join(', '),
      child: dial,
    );
  }
}

/// Paints the half-dial of a [KkGauge]. The drawing is laid out in a box 200
/// units wide with the needle's pivot at (100, 100) and is scaled to the
/// canvas.
class KkGaugePainter extends CustomPainter {
  KkGaugePainter({
    required this.fraction,
    required this.needle,
    required this.entrance,
    required this.valueText,
    required this.unit,
    required this.stateWord,
    required this.level,
    required this.minLabel,
    required this.maxLabel,
    required this.bands,
    required this.ticks,
    required this.maxWidth,
    required this.theme,
    required this.scaler,
  }) : super(repaint: entrance);

  /// The value's position on the dial, 0 to 1. The fill arc ends here.
  final double fraction;

  /// Where the needle is on its way to [fraction] after a change.
  final double needle;

  /// The one-shot entrance, 0 to 1 over 0.8s: wipes the fill in and sweeps the
  /// needle up from zero.
  final Animation<double> entrance;
  final String valueText;
  final String? unit;
  final String? stateWord;
  final KkLevel? level;
  final String? minLabel;
  final String? maxLabel;
  final List<({double from, double to, Color color})> bands;
  final int ticks;
  final double maxWidth;
  final KeikaiThemeData theme;
  final TextScaler scaler;

  /// Height of the drawing in its own units (it is 200 wide).
  static double viewHeightFor({required bool hasState}) => hasState ? 132 : 116;

  /// Where the needle is right now (0 to 1), entrance sweep included.
  double get needleFraction {
    final double sweep = const KkSteps(
      KkMotion.needleSteps,
    ).transform((entrance.value * KkMotion.wipe.inMicroseconds / KkMotion.needle.inMicroseconds).clamp(0.0, 1.0));
    return needle * sweep;
  }

  static const Offset _pivot = Offset(100, 100);
  static const double _trackRadius = 82;
  static const double _trackWidth = 16;
  static const double _bandRadius = 95;

  @override
  void paint(Canvas canvas, Size size) {
    final double viewHeight = viewHeightFor(hasState: stateWord != null);
    final double availableWidth = size.width - 24;
    final double availableHeight = size.height - 16;
    if (availableWidth <= 0 || availableHeight <= 0) return;
    final double unitScale = math.min(math.min(availableWidth, maxWidth) / 200, availableHeight / viewHeight);
    if (!(unitScale > 0) || !unitScale.isFinite) return;
    final KkColors c = theme.colors;
    canvas.save();
    canvas.translate((size.width - 200 * unitScale) / 2, 8 + (availableHeight - viewHeight * unitScale) / 2);
    canvas.scale(unitScale);

    final Rect track = Rect.fromCircle(center: _pivot, radius: _trackRadius);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trackWidth
      ..color = c.signalDim;
    canvas.drawArc(track, math.pi, math.pi, false, arc);

    // Rim bands.
    final Rect rim = Rect.fromCircle(center: _pivot, radius: _bandRadius);
    for (final ({double from, double to, Color color}) b in bands) {
      if (b.to <= b.from) continue;
      canvas.drawArc(
        rim,
        math.pi + math.pi * b.from,
        math.pi * (b.to - b.from),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = b.color,
      );
    }

    // Fill, wiped in from the left over its own width.
    if (fraction > 0) {
      final double wipe = const KkSteps(KkMotion.wipeSteps).transform(entrance.value.clamp(0.0, 1.0));
      if (wipe > 0) {
        final double cosEnd = math.cos(math.pi * fraction);
        const double outer = _trackRadius + _trackWidth / 2;
        const double inner = _trackRadius - _trackWidth / 2;
        final double left = _pivot.dx - outer;
        final double right = _pivot.dx - (cosEnd > 0 ? inner : outer) * cosEnd;
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(left - 1, 0, wipe >= 1 ? 201 : left + (right - left) * wipe, _pivot.dy + 1));
        canvas.drawArc(track, math.pi, math.pi * fraction, false, arc..color = c.level(level));
        canvas.restore();
      }
    }

    // Ticks inside the track.
    final int divisions = math.max(1, ticks);
    final Paint tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c.inkFaint;
    for (int i = 0; i <= divisions; i++) {
      final double a = math.pi + math.pi * i / divisions;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      final bool major = i == 0 || i == divisions || (divisions.isEven && i == divisions ~/ 2);
      canvas.drawLine(_pivot + dir * (major ? 61 : 65), _pivot + dir * 70, tick);
    }

    // Needle.
    final double na = math.pi + math.pi * needleFraction.clamp(0.0, 1.0);
    final Offset nd = Offset(math.cos(na), math.sin(na));
    canvas.drawLine(
      _pivot + nd * 64,
      _pivot + nd * 99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c.ink,
    );

    // Value, fitted to the space inside the dial.
    final Color valueInk = switch (level) {
      KkLevel.nominal => c.nominal,
      KkLevel.caution => c.caution,
      KkLevel.critical => c.alert,
      _ => c.ink,
    };
    final TextPainter value = kkLayoutText(
      valueText,
      theme.type.mono(36, weight: FontWeight.w500, spacingEm: -0.03, color: valueInk),
      scaler: scaler,
    );
    if (value.width > 0) {
      final double fit = math.min(1, math.min(104 / value.width, 44 / value.height));
      final double baseline = value.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      canvas.save();
      canvas.translate(100, 97);
      canvas.scale(fit);
      value.paint(canvas, Offset(-value.width / 2, -baseline));
      canvas.restore();
    }
    value.dispose();

    final String? u = unit;
    if (u != null && u.isNotEmpty) {
      kkPaintText(
        canvas,
        u,
        theme.type.label(12, weight: FontWeight.w600, spacingEm: 0.1, color: c.inkDim),
        const Offset(100, 104),
        align: Alignment.topCenter,
        scaler: scaler,
      );
    }
    final TextStyle limitStyle = theme.type.mono(10, color: c.inkFaint);
    final String? lo = minLabel;
    final String? hi = maxLabel;
    if (lo != null) kkPaintText(canvas, lo, limitStyle, const Offset(10, 105), scaler: scaler);
    if (hi != null) {
      kkPaintText(canvas, hi, limitStyle, const Offset(190, 105), align: Alignment.topRight, scaler: scaler);
    }

    final String? word = stateWord;
    if (word != null) {
      final Color ink = level == null ? c.inkDim : c.level(level);
      final TextPainter tp = kkLayoutText(
        word.toUpperCase(),
        theme.type.label(10, weight: FontWeight.w700, spacingEm: 0.14, color: ink),
        scaler: scaler,
      );
      const double icon = 10;
      const double gap = 4;
      final double x = 100 - (icon + gap + tp.width) / 2;
      const double y = 120;
      kkPaintIcon(canvas, Rect.fromLTWH(x, y + (tp.height - icon) / 2, icon, icon), kkStatusIcon(level), ink);
      tp.paint(canvas, Offset(x + icon + gap, y));
      tp.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KkGaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.needle != needle ||
      oldDelegate.entrance != entrance ||
      oldDelegate.valueText != valueText ||
      oldDelegate.unit != unit ||
      oldDelegate.stateWord != stateWord ||
      oldDelegate.level != level ||
      oldDelegate.minLabel != minLabel ||
      oldDelegate.maxLabel != maxLabel ||
      oldDelegate.ticks != ticks ||
      oldDelegate.maxWidth != maxWidth ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler ||
      oldDelegate.bands.length != bands.length ||
      !_sameBands(oldDelegate.bands, bands);

  static bool _sameBands(
    List<({double from, double to, Color color})> a,
    List<({double from, double to, Color color})> b,
  ) {
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
