import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/flex.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';

/// A state said the KEIKAI way, inline: the status icon and the status word,
/// both in the level's colour. Never colour alone.
///
/// With no [level] it shows the info plate and `INFO` in dim ink.
class KkStateWord extends StatelessWidget {
  const KkStateWord({
    super.key,
    this.level,
    this.text,
    this.color,
    this.size = 10,
    this.glyphSize = 10,
    this.gap = 4,
    this.weight = FontWeight.w700,
    this.spacing = 0.14,
    this.showGlyph = true,
  });

  final KkLevel? level;

  /// The word. Defaults to the level's word (`NOMINAL`, `CAUTION` …) or `INFO`.
  final String? text;

  /// Defaults to the level colour, or dim ink without a level.
  final Color? color;

  /// Font size of the word.
  final double size;
  final double glyphSize;
  final double gap;
  final FontWeight weight;

  /// Tracking of the word in em.
  final double spacing;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final Color ink = color ?? (level != null ? c.level(level) : c.inkDim);
    return KkRow(
      shrinkWrap: true,
      gap: gap,
      children: <Widget>[
        if (showGlyph) KkGlyph(level: level, size: glyphSize, color: ink),
        KkText.en(text ?? level?.word ?? 'INFO', size: size, weight: weight, spacing: spacing, color: ink),
      ],
    );
  }
}

/// A number with a fixed count of digits, the way every KEIKAI readout is
/// written: `kkFixedDigits(42.7)` is `042.7`, `kkFixedDigits(78, decimals: 0)`
/// is `078`.
///
/// The integer part is zero-padded to [integers] places and never truncated;
/// a negative value keeps its sign in front.
String kkFixedDigits(num value, {int integers = 3, int decimals = 1}) {
  if (value.isNaN || value.isInfinite) return '-' * (integers + (decimals > 0 ? decimals + 1 : 0));
  final bool negative = value < 0;
  final String raw = value.abs().toStringAsFixed(decimals < 0 ? 0 : decimals);
  final int dot = raw.indexOf('.');
  final String whole = dot < 0 ? raw : raw.substring(0, dot);
  final String rest = dot < 0 ? '' : raw.substring(dot);
  return '${negative ? '-' : ''}${whole.padLeft(integers, '0')}$rest';
}
