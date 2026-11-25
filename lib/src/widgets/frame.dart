import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/wrap.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/patterns.dart';
import '../painting/shapes.dart';
import 'text.dart';

/// The head band of a HUD widget: CJK title, Latin subtitle and, pushed to the
/// right, a mono meta value.
class KkWidgetHead extends StatelessWidget {
  const KkWidgetHead({super.key, this.cjk, this.en, this.meta, this.trailing, this.divider = true});

  final String? cjk;
  final String? en;

  /// Short mono text on the right (a count, a time, a value).
  final String? meta;

  /// A widget on the right instead of (or after) [meta].
  final Widget? trailing;

  /// Draw the 1px line under the head.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? metaText = meta;
    final Widget? tail = trailing;
    return KkBox(
      padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: m.space2),
      edges: divider ? KkEdges(bottom: KkSide(c.line, width: m.stroke1)) : null,
      child: KkRow(
        gap: m.space2,
        cross: KkCrossAlign.baseline,
        clip: Clip.hardEdge,
        children: <Widget>[
          if (cjk != null) KkText.cjk(cjk!, size: 14, height: 1.55, color: c.ink, squeeze: 0.8),
          if (en != null) KkText.en(en!, size: 11, weight: FontWeight.w600, height: 1.55, spacing: 0.14, color: c.inkDim),
          const KkSpacer(),
          if (metaText != null) KkText.num(metaText, size: 12, weight: FontWeight.w500, color: c.ink),
          if (tail != null) KkAlignSelf(align: KkCrossAlign.center, child: tail),
        ],
      ),
    );
  }
}

/// The foot band of a HUD widget: legend keys and notes in dim mono, wrapping.
class KkWidgetFoot extends StatelessWidget {
  const KkWidgetFoot({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    return KkBox(
      padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: m.space2),
      edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
      child: DefaultTextStyle(
        style: theme.type.mono(11, color: c.inkDim),
        child: KkWrap(gap: m.space4, runGap: m.space1, children: children),
      ),
    );
  }
}

/// One legend key: a colour swatch (a line or a box) and its label.
class KkWidgetKey extends StatelessWidget {
  const KkWidgetKey({super.key, required this.label, this.color, this.box = false, this.swatch, this.value});

  final String label;

  /// Swatch colour. Without one (and without [swatch]) only the label shows.
  final Color? color;

  /// A 10×10 box instead of a 12×3 line.
  final bool box;

  /// A custom swatch widget.
  final Widget? swatch;

  /// A value after the label, in ink.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final Color? sw = color;
    return KkRow(
      shrinkWrap: true,
      gap: 6,
      children: <Widget>[
        if (swatch != null) swatch! else if (sw != null) KkBox(width: box ? 10 : 12, height: box ? 10 : 3, fill: sw),
        KkText.num(label, size: 11, weight: FontWeight.w500, color: c.inkDim),
        if (value != null) KkText.num(value!, size: 11, weight: FontWeight.w600, color: c.ink),
      ],
    );
  }
}

/// The shell every HUD widget and chart sits in: a panel-coloured box with a
/// 1px line border, an optional head and foot, and the boot wipe on entry.
class KkWidgetFrame extends StatelessWidget {
  const KkWidgetFrame({
    super.key,
    this.cjk,
    this.en,
    this.meta,
    this.trailing,
    this.footer,
    this.level,
    this.fill,
    this.border = true,
    this.boot = true,
    this.expandBody = false,
    required this.child,
  });

  final String? cjk;
  final String? en;
  final String? meta;
  final Widget? trailing;

  /// Legend keys and notes for the foot band.
  final List<Widget>? footer;

  /// Critical turns the border red and adds the alarm glow; offline dashes it.
  final KkLevel? level;

  /// Defaults to the panel colour (bg-100).
  final Color? fill;
  final bool border;

  /// Play the boot wipe when first shown.
  final bool boot;

  /// Let the body take all remaining height (use inside a grid cell or any
  /// parent that fixes the frame's height).
  final bool expandBody;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final bool hasHead = cjk != null || en != null || meta != null || trailing != null;
    final List<Widget>? foot = footer;
    final Color edge = switch (level) {
      KkLevel.critical => c.alert,
      KkLevel.offline => c.offline,
      _ => c.line,
    };
    final Widget frame = KkBox(
      decoration: KkDecoration(
        fill: fill ?? c.bg100,
        edges: border
            ? KkEdges.line(edge, width: theme.metrics.stroke1, dashed: level == KkLevel.offline)
            : KkEdges.none,
        glow: level == KkLevel.critical ? c.glowAlert : null,
      ),
      clip: true,
      child: KkColumn(
        shrinkWrap: !expandBody,
        children: <Widget>[
          if (hasHead) KkWidgetHead(cjk: cjk, en: en, meta: meta, trailing: trailing),
          if (expandBody) KkExpanded(child: child) else child,
          if (foot != null && foot.isNotEmpty) KkWidgetFoot(children: foot),
        ],
      ),
    );
    return boot ? KkBoot(child: frame) : frame;
  }
}

/// Frames its child with the four L-shaped corner brackets.
class KkBrackets extends StatelessWidget {
  const KkBrackets({
    super.key,
    this.color,
    this.level,
    this.length,
    this.width,
    this.outset = 1,
    this.visible = true,
    required this.child,
  });

  /// Defaults to the level colour, or signal.
  final Color? color;
  final KkLevel? level;

  /// Arm length. Defaults to 12.
  final double? length;

  /// Arm thickness. Defaults to 2.
  final double? width;

  /// Distance outside the child's box.
  final double outset;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    if (!visible) return KkBox(child: child);
    return KkBox(
      decoration: KkDecoration(
        brackets: KkBracketSpec(
          color: color ?? theme.colors.level(level),
          length: length ?? theme.metrics.space3,
          width: width ?? theme.metrics.stroke2,
          outset: outset,
        ),
      ),
      child: child,
    );
  }
}

/// The grounds a screen or a panel can sit on.
enum KkBackdropKind {
  /// The 24px screen grid.
  grid,

  /// The 8px fine grid.
  fineGrid,

  /// The plot ground: fine grid with a major grid every 8 cells.
  plot,

  /// The hexagon field of an alarm zone (never above 20% opacity).
  hex,

  /// Flat ground, no pattern.
  none,
}

/// Paints a KEIKAI ground behind its child: the screen grid by default.
///
/// Patterns carry no information; they are hard-stopped lines, never
/// gradients.
class KkBackdrop extends StatelessWidget {
  const KkBackdrop({
    super.key,
    this.kind = KkBackdropKind.grid,
    this.level,
    this.fill,
    this.scanlines = false,
    this.padding = EdgeInsets.zero,
    this.alignment,
    this.child,
  });

  final KkBackdropKind kind;

  /// Colours the hexagon field.
  final KkLevel? level;

  /// Defaults to the screen ground (bg-000).
  final Color? fill;

  /// Draw CRT scan lines over the child.
  final bool scanlines;
  final EdgeInsets padding;
  final Alignment? alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkPattern? pattern = switch (kind) {
      KkBackdropKind.grid => KkPattern.grid(color: c.grid, pitch: m.pitchGrid, stroke: m.stroke1),
      KkBackdropKind.fineGrid => KkPattern.grid(color: c.grid, pitch: m.pitchFine, stroke: m.stroke1),
      KkBackdropKind.plot => KkPattern.plot(minor: c.grid, major: c.signalDim, pitch: m.pitchFine, stroke: m.stroke1),
      KkBackdropKind.hex => KkPattern.hex(color: c.level(level), pitch: m.pitchGrid),
      KkBackdropKind.none => null,
    };
    return KkBox(
      decoration: KkDecoration(
        fill: fill ?? c.bg000,
        pattern: pattern,
        overlay: scanlines ? KkPattern.scanlines(color: kkFade(c.bg000, 0.5)) : null,
      ),
      padding: padding,
      alignment: alignment,
      child: child,
    );
  }
}

/// The alarm strobe: [builder] is called with `lit` true for the first half of
/// every 1.2s and false for the second, with a hard cut between.
///
/// Lit is the alert fill with dark ink; unlit is the deep alert fill with
/// light ink. With motion off it stays lit.
class KkStrobe extends StatelessWidget {
  const KkStrobe({super.key, this.period = KkMotion.strobe, this.enabled = true, required this.builder});

  final Duration period;
  final bool enabled;
  final Widget Function(BuildContext context, bool lit) builder;

  @override
  Widget build(BuildContext context) {
    return KkPhaseBuilder(
      period: period,
      enabled: enabled,
      builder: (BuildContext context, int phase, Widget? child) => builder(context, phase == 0),
    );
  }
}
