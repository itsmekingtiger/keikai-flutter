import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/effects.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// One cell at the right of a [KkCommandBar]: a small caption over a value.
///
/// The value is mono text ([value]) or any widget ([child]), for example a
/// `KkClock`.
class KkCommandCell extends StatelessWidget {
  const KkCommandCell({super.key, required this.label, this.value, this.child, this.level})
    : assert(value != null || child != null, 'Give the cell a value or a child.');

  /// The caption; it is upper-cased.
  final String label;

  /// The value as text, set in 15px mono.
  final String? value;

  /// The value as a widget. It inherits 15px medium mono in ink.
  final Widget? child;

  /// Colours a text [value]: a reading inside its normal range is nominal.
  final KkLevel? level;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color ink = level == null ? c.ink : c.level(level);
    final String? text = value;
    return KkBox(
      padding: EdgeInsets.symmetric(horizontal: m.space4),
      edges: KkEdges(left: KkSide(c.line, width: m.stroke1)),
      child: KkColumn(
        main: KkMainAlign.center,
        cross: KkCrossAlign.start,
        gap: 4,
        children: <Widget>[
          KkText.en(label, size: 10, weight: FontWeight.w600, spacing: 0.16, color: c.inkFaint),
          if (text != null)
            KkText.num(text, size: 15, weight: FontWeight.w500, color: ink)
          else
            DefaultTextStyle(
              style: theme.type.mono(15, weight: FontWeight.w500, color: ink),
              maxLines: 1,
              softWrap: false,
              child: child!,
            ),
        ],
      ),
    );
  }
}

/// The bar across the top of a screen: who this is, what condition the system
/// is in, and a few always-visible readings.
///
/// 48px high on the panel colour with a 4px signal line under it. From the
/// left: an optional [leading] slot, the identity block ([name] over [node])
/// on a signal plate with a slanted end, the condition ([conditionCjk] +
/// [conditionEn] under a small caption), then the [cells] pushed to the right
/// and an optional [trailing] slot.
///
/// With [level] critical the condition block fills with the alert colour and
/// grows a running hazard strip. When the bar itself is 600px wide or less,
/// the condition caption and every cell but the last are hidden.
class KkCommandBar extends StatelessWidget {
  const KkCommandBar({
    super.key,
    required this.name,
    this.node,
    this.conditionLabel = 'condition',
    this.conditionCjk,
    this.conditionEn,
    this.level,
    this.followCondition = false,
    this.cells = const <Widget>[],
    this.leading,
    this.trailing,
    this.onIdPressed,
    this.idSemanticLabel,
  });

  /// The system name on the identity block; it is upper-cased.
  final String name;

  /// The node or station code under the name: `HQ-03 · NODE 07`.
  final String? node;

  /// The caption before the condition; it is upper-cased. Null leaves it out.
  final String? conditionLabel;

  /// The condition in 漢字 or Hangul: 平時, 警報.
  final String? conditionCjk;

  /// The condition in Latin capitals: STANDBY, ALERT.
  final String? conditionEn;

  /// Critical turns the condition block into an alarm: alert fill, dark ink
  /// and a running hazard strip.
  final KkLevel? level;

  /// When no condition text is given, show the theme's own condition:
  /// 平時 STANDBY, or 警報 ALERT as a critical block.
  final bool followCondition;

  /// The cells at the right, usually [KkCommandCell]s.
  final List<Widget> cells;

  /// A slot before the identity block, for a menu button.
  final Widget? leading;

  /// A slot after the cells.
  final Widget? trailing;

  /// Makes the identity block a button (go home, open the drawer).
  final VoidCallback? onIdPressed;

  /// Read by screen readers for the identity block when it is a button.
  final String? idSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;

    final bool follow = followCondition && conditionCjk == null && conditionEn == null;
    final String? cjk = follow ? (theme.isAlert ? '警報' : '平時') : conditionCjk;
    final String? en = follow ? (theme.isAlert ? 'alert' : 'standby') : conditionEn;
    final KkLevel? lv = follow ? (theme.isAlert ? KkLevel.critical : null) : level;
    final bool critical = lv == KkLevel.critical;
    final String? nodeText = node;
    final String? caption = conditionLabel;
    final Widget? lead = leading;
    final Widget? trail = trailing;

    Widget id = KkSurface(
      shape: KkShape.slant(m.chamferLg),
      fill: c.signal,
      edgeWidth: 0,
      child: KkBox(
        padding: EdgeInsets.only(left: m.space4, right: m.space4 + m.chamferLg),
        child: KkColumn(
          main: KkMainAlign.center,
          cross: KkCrossAlign.start,
          gap: 3,
          children: <Widget>[
            KkText.en(name, size: 22, weight: FontWeight.w800, spacing: 0.08, color: c.onFill),
            if (nodeText != null && nodeText.isNotEmpty)
              KkText.num(nodeText, size: 10, weight: FontWeight.w600, spacing: 0.06, color: c.onFill),
          ],
        ),
      ),
    );
    if (onIdPressed != null) {
      final Widget plate = id;
      id = KkPressable(
        onPressed: onIdPressed,
        semanticLabel: idSemanticLabel ?? name,
        builder: (BuildContext context, KkStates s) =>
            KkFocusRing(visible: s.focused, offset: -4, color: c.bg000, child: plate),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The container query of the design system: (max-width: 600px).
        final bool compact = constraints.hasBoundedWidth && constraints.maxWidth <= m.bpMedium;
        final Color condInk = critical ? c.onFill : c.signal;

        Widget? condition;
        if ((cjk != null && cjk.isNotEmpty) || (en != null && en.isNotEmpty)) {
          final Widget words = KkRow(
            shrinkWrap: true,
            gap: m.space2,
            children: <Widget>[
              if (!compact && caption != null && caption.isNotEmpty)
                KkText.en(
                  caption,
                  size: 10,
                  weight: FontWeight.w600,
                  spacing: 0.16,
                  color: critical ? c.onFill : c.inkDim,
                ),
              if (cjk != null && cjk.isNotEmpty) KkText.cjk(cjk, size: 22, color: condInk, squeeze: 0.8),
              if (en != null && en.isNotEmpty) KkText.en(en, size: 14, color: condInk),
            ],
          );
          condition = Semantics(
            container: true,
            label: critical ? KkLevel.critical.word : null,
            child: KkBox(
              fill: critical ? c.alert : null,
              child: KkRow(
                shrinkWrap: true,
                cross: KkCrossAlign.stretch,
                children: <Widget>[
                  if (critical)
                    KkHazard(
                      width: m.space6,
                      color: c.onFill,
                      background: const Color(0x00000000),
                      running: true,
                    ),
                  KkBox(
                    padding: EdgeInsets.only(left: critical ? m.space2 : m.space4, right: m.space4),
                    alignment: Alignment.centerLeft,
                    child: words,
                  ),
                ],
              ),
            ),
          );
        }

        return KkBox(
          height: m.cmdbarHeight,
          decoration: KkDecoration(
            fill: c.bg100,
            edges: KkEdges(bottom: KkSide(c.signal, width: m.stroke4)),
          ),
          clip: true,
          child: KkRow(
            cross: KkCrossAlign.stretch,
            clip: Clip.hardEdge,
            children: <Widget>[
              if (lead != null)
                KkBox(
                  padding: EdgeInsets.symmetric(horizontal: m.space2),
                  alignment: Alignment.center,
                  child: lead,
                ),
              id,
              ?condition,
              const KkSpacer(),
              for (int i = 0; i < cells.length; i++)
                if (!compact || i == cells.length - 1) cells[i],
              if (trail != null)
                KkBox(
                  padding: EdgeInsets.symmetric(horizontal: m.space2),
                  edges: KkEdges(left: KkSide(c.line, width: m.stroke1)),
                  alignment: Alignment.center,
                  child: trail,
                ),
            ],
          ),
        );
      },
    );
  }
}
