import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../motion/scramble.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';
import 'plot.dart';
import 'sparkline.dart';

/// Whether a change is good news, bad news or neither. The arrow shows the
/// direction; the tone shows what it means (a rise in temperature is bad).
enum KkDeltaTone { neutral, good, bad }

/// A change against a previous period: an arrow, the amount, and the period.
///
/// 12px semibold mono; nominal green when [tone] is good, alert red when bad,
/// dim ink otherwise.
class KkDelta extends StatelessWidget {
  const KkDelta({
    super.key,
    required this.value,
    this.tone = KkDeltaTone.neutral,
    this.decimals = 1,
    this.unit = '',
    this.period,
    this.format,
  });

  /// The change. Its sign picks the arrow; the amount is shown without a sign.
  final double value;
  final KkDeltaTone tone;
  final int decimals;

  /// Appended to the amount (`%`, `°C`).
  final String unit;

  /// What the change is measured against (`1H`, `24H`), in faint ink.
  final String? period;

  /// Formats the absolute amount; overrides [decimals] and [unit].
  final String Function(double amount)? format;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final Color ink = switch (tone) {
      KkDeltaTone.good => c.nominal,
      KkDeltaTone.bad => c.alert,
      KkDeltaTone.neutral => c.inkDim,
    };
    final bool finite = value.isFinite;
    final String amount = !finite
        ? '--'
        : (format?.call(value.abs()) ?? '${value.abs().toStringAsFixed(decimals.clamp(0, 20))}$unit');
    final KkIconData arrow = !finite || value == 0
        ? KkIcons.minus
        : (value > 0 ? KkIcons.caretUp : KkIcons.caretDown);
    final String direction = !finite || value == 0 ? 'no change' : (value > 0 ? 'up' : 'down');
    final String? p = period;
    return Semantics(
      label: '$direction $amount${p == null ? '' : ' $p'}',
      child: ExcludeSemantics(
        child: KkRow(
          shrinkWrap: true,
          gap: 3,
          children: <Widget>[
            KkIcon(arrow, size: 10, color: ink),
            KkText.num(amount, size: 12, weight: FontWeight.w600, color: ink),
            if (p != null)
              KkBox(
                padding: const EdgeInsets.only(left: 4),
                child: KkText.num(p, size: 12, color: c.inkFaint),
              ),
          ],
        ),
      ),
    );
  }
}

/// A key figure: bilingual title, state word with its status icon, one large
/// number with its unit, a sparkline, and a foot with the change and a note.
///
/// The 2px top edge and the number take the level's colour (the edge is
/// signal without a level). The number scrambles for 0.46s when it changes.
/// In a parent that fixes the height (a grid cell) the head, the number and
/// the foot spread to fill it.
class KkStat extends StatelessWidget {
  const KkStat({
    super.key,
    this.cjk,
    this.en,
    required this.value,
    this.unit,
    this.level,
    this.state,
    this.showState = true,
    this.spark,
    this.sparkColor,
    this.sparkArea = true,
    this.delta,
    this.note,
    this.accent,
    this.frame = true,
    this.scramble = true,
    this.boot = true,
    this.semanticLabel,
  });

  final String? cjk;
  final String? en;

  /// The figure, already formatted at a fixed width (see `kkFixed`).
  final String value;

  /// Shown small after the figure, as written (`°C`, `dBm`, `%`).
  final String? unit;
  final KkLevel? level;

  /// The state word. Defaults to the level's word (`NOMINAL` …).
  final String? state;

  /// Show the state word and status icon when there is a level or a [state].
  final bool showState;

  /// Recent values for the sparkline beside the figure.
  final List<double?>? spark;

  /// Sparkline colour. Defaults to series-1.
  final Color? sparkColor;
  final bool sparkArea;

  /// Left of the foot; usually a [KkDelta].
  final Widget? delta;

  /// Right of the foot: a short mono note (`MAX 120` or `UPDATED 14:02Z`).
  final String? note;

  /// Colour of the 2px top edge. Defaults to the level colour, or signal.
  final Color? accent;

  /// Draw the panel ground, the border and the coloured top edge, with their
  /// padding. False leaves just the content, for a stat inside a panel body.
  final bool frame;

  /// Scramble the figure when it changes.
  final bool scramble;

  /// Play the boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final Color valueInk = level == null ? c.ink : c.level(level);
    final String? word = state ?? level?.word;
    final bool hasState = showState && word != null;
    final List<double?>? trend = spark;
    final String? u = unit;
    final String? n = note;

    final Widget head = KkRow(
      gap: theme.metrics.space2,
      cross: KkCrossAlign.baseline,
      clip: Clip.hardEdge,
      children: <Widget>[
        if (cjk != null) KkText.cjk(cjk!, size: 16, height: 1.55, color: c.ink, squeeze: 0.8),
        if (en != null)
          KkExpanded(
            child: KkText.en(
              en!,
              size: 11,
              weight: FontWeight.w600,
              height: 1.55,
              spacing: 0.14,
              color: c.inkDim,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const KkSpacer(),
        if (hasState)
          KkAlignSelf(
            align: KkCrossAlign.center,
            child: KkRow(
              shrinkWrap: true,
              gap: 5,
              children: <Widget>[
                KkGlyph(level: level, size: 10, color: level == null ? c.inkDim : null),
                KkText.en(
                  word,
                  size: 10,
                  weight: FontWeight.w700,
                  spacing: 0.14,
                  color: level == null ? c.inkDim : c.level(level),
                ),
              ],
            ),
          ),
      ],
    );

    final TextStyle valueStyle = theme.type.mono(36, weight: FontWeight.w500, spacingEm: -0.03, color: valueInk);
    final Widget figure = KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      gap: theme.metrics.space1,
      children: <Widget>[
        KkScramble(value, style: valueStyle, enabled: scramble),
        if (u != null && u.isNotEmpty)
          KkText.en(u, size: 15, weight: FontWeight.w600, spacing: 0.04, color: c.inkDim, upper: false),
      ],
    );

    final Widget row = KkRow(
      gap: theme.metrics.space3,
      cross: KkCrossAlign.end,
      clip: Clip.hardEdge,
      children: <Widget>[
        figure,
        if (trend != null)
          KkExpanded(
            child: KkBox(
              padding: const EdgeInsets.only(bottom: 2),
              child: KkSparkline(values: trend, color: sparkColor, area: sparkArea, height: 32),
            ),
          ),
      ],
    );

    final bool hasFoot = delta != null || n != null;
    final Widget stat = KkBox(
      decoration: frame
          ? KkDecoration(
              fill: c.bg100,
              edges: KkEdges(
                top: KkSide(accent ?? c.level(level), width: theme.metrics.stroke2),
                right: KkSide(c.line, width: theme.metrics.stroke1),
                bottom: KkSide(c.line, width: theme.metrics.stroke1),
                left: KkSide(c.line, width: theme.metrics.stroke1),
              ),
            )
          : null,
      padding: frame
          ? EdgeInsets.fromLTRB(theme.metrics.space3, 10, theme.metrics.space3, theme.metrics.space2)
          : EdgeInsets.zero,
      clip: true,
      child: KkColumn(
        gap: 6,
        main: KkMainAlign.between,
        children: <Widget>[
          head,
          row,
          if (hasFoot)
            KkRow(
              gap: theme.metrics.space2,
              main: KkMainAlign.between,
              clip: Clip.hardEdge,
              children: <Widget>[
                delta ?? const KkGap(0),
                if (n != null) KkText.num(n, size: 11, color: c.inkFaint),
              ],
            ),
        ],
      ),
    );

    final String label =
        semanticLabel ??
        <String>[?cjk, ?en?.toUpperCase()].join(' ');
    return Semantics(
      container: true,
      label: label.isEmpty ? null : label,
      value: <String>[
        '$value${u == null ? '' : ' $u'}',
        if (hasState) word,
      ].join(', '),
      child: ExcludeSemantics(child: KkNaturalHeight(child: boot ? KkBoot(child: stat) : stat)),
    );
  }
}
