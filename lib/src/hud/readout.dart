import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../motion/scramble.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'hug.dart';
import 'state_word.dart';

/// One measured value: a bilingual label, the status word with its icon, the
/// number in 32px tabular mono with its unit, a tick scale with a marker, and
/// a foot line for the limits.
///
/// Give [value] as fixed-width text (`042.7`, see [kkFixedDigits]); when it
/// changes the digits scramble for 0.46s and settle from the front. A value
/// in its normal range is written in nominal green: pass
/// `level: KkLevel.nominal`. A value with no level is plain ink.
class KkReadout extends StatelessWidget {
  const KkReadout({
    super.key,
    this.cjk,
    this.en,
    required this.value,
    this.unit,
    this.level,
    this.state,
    this.showState = true,
    this.position,
    this.footStart,
    this.footEnd,
    this.minWidth = 208,
    this.scramble = true,
    this.boot = true,
    this.valueColor,
    this.fill,
    this.squeeze = 0.8,
  });

  final String? cjk;
  final String? en;

  /// The number as text, with a fixed count of digits.
  final String value;

  /// Written small after the value: `°C`, `dBm`, `%`.
  final String? unit;
  final KkLevel? level;

  /// The status word. Defaults to the level's word; nothing without a level.
  final String? state;

  /// Show the status word and icon at the right of the head.
  final bool showState;

  /// Where the marker sits on the tick scale, 0 to 1. Null hides the scale.
  final double? position;

  /// Left foot note, such as `MIN 030.0`.
  final String? footStart;

  /// Right foot note, such as `MAX 060.0`.
  final String? footEnd;
  final double minWidth;

  /// Scramble the digits when the value changes.
  final bool scramble;

  /// Wipe in when first shown.
  final bool boot;

  /// Overrides the value colour (the level's colour; ink without a level or
  /// when offline).
  final Color? valueColor;

  /// Overrides the ground (bg-100).
  final Color? fill;

  /// Horizontal compression of [cjk]; 1.0 turns it off.
  final double squeeze;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color ink =
        valueColor ??
        switch (level) {
          KkLevel.nominal => c.nominal,
          KkLevel.caution => c.caution,
          KkLevel.critical => c.alert,
          KkLevel.offline || null => c.ink,
        };
    final TextStyle valueStyle = theme.type.mono(32, weight: FontWeight.w500, spacingEm: -0.01, color: ink);
    final String? label = cjk;
    final String? sub = en;
    final String? u = unit;
    final double? pos = position;
    final String? word = state ?? level?.word;
    final bool hasFoot = footStart != null || footEnd != null;

    final Widget readout = Semantics(
      container: true,
      label: <String>[?label, ?sub].join(' '),
      value: <String>[value, ?u, ?word].join(' '),
      child: ExcludeSemantics(
        child: KkBox(
          minWidth: minWidth,
          padding: EdgeInsets.all(m.space3),
          decoration: KkDecoration(
            fill: fill ?? c.bg100,
            edges: KkEdges(top: KkSide(level != null ? c.level(level) : c.line, width: m.stroke2)),
          ),
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
                  if (showState && word != null)
                    KkAlignSelf(
                      align: KkCrossAlign.center,
                      child: KkStateWord(level: level, text: word),
                    ),
                ],
              ),
              KkRow(
                gap: m.space1,
                cross: KkCrossAlign.baseline,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (scramble)
                    KkScramble(value, style: valueStyle)
                  else
                    Text(value, style: valueStyle, maxLines: 1, softWrap: false),
                  if (u != null)
                    KkText.en(u, size: 15, weight: FontWeight.w600, spacing: 0.04, color: c.inkDim, upper: false),
                ],
              ),
              if (pos != null)
                CustomPaint(
                  size: const Size(0, 6),
                  painter: _ScalePainter(
                    position: pos.isNaN ? 0 : pos.clamp(0.0, 1.0),
                    tick: c.line,
                    marker: c.level(level),
                    pitch: m.pitchFine,
                    stroke: m.stroke1,
                    markerWidth: m.stroke2,
                  ),
                ),
              if (hasFoot)
                KkRow(
                  gap: m.space3,
                  main: KkMainAlign.between,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    KkText.num(footStart ?? '', size: 11, color: c.inkFaint),
                    KkText.num(footEnd ?? '', size: 11, color: c.inkFaint),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    return KkHugWidth(child: boot ? KkBoot(child: readout) : readout);
  }
}

class _ScalePainter extends CustomPainter {
  const _ScalePainter({
    required this.position,
    required this.tick,
    required this.marker,
    required this.pitch,
    required this.stroke,
    required this.markerWidth,
  });

  final double position;
  final Color tick;
  final Color marker;
  final double pitch;
  final double stroke;
  final double markerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Path ticks = Path();
    for (double x = 0; x < size.width; x += pitch) {
      ticks.addRect(Rect.fromLTRB(x, 0, math.min(x + stroke, size.width), size.height));
    }
    canvas.drawPath(ticks, Paint()..color = tick);
    final double left = math.min(position * size.width, size.width - markerWidth);
    canvas.drawRect(
      Rect.fromLTWH(math.max(0, left), -3, markerWidth, size.height + 6),
      Paint()..color = marker,
    );
  }

  @override
  bool shouldRepaint(_ScalePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.tick != tick ||
      oldDelegate.marker != marker ||
      oldDelegate.pitch != pitch ||
      oldDelegate.stroke != stroke ||
      oldDelegate.markerWidth != markerWidth;
}
