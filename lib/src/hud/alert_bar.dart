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
import '../widgets/text.dart';

/// The alert bar: one line that says what is wrong, between two hazard blocks.
///
/// The wording is `[LEVEL] — [SUBJECT] [EVENT]` with a second line of detail:
/// `CRITICAL — COOLANT PRESSURE LOW` / `冷却水圧 低下 · SEC-04 · 14:02:31Z`.
///
/// Without a [level] it is framed in signal. A critical bar is filled with
/// the alert colour, glows, and its hazards run; nothing else makes them move.
class KkAlertBar extends StatelessWidget {
  const KkAlertBar({
    super.key,
    this.level,
    this.cjk,
    required this.title,
    this.sub,
    this.code,
    this.hazards = true,
    this.action,
    this.squeeze = 0.8,
    this.minHeight,
  });

  final KkLevel? level;

  /// The large CJK word at the left, such as `警報`.
  final String? cjk;

  /// The headline; shown in capitals and cut with an ellipsis when too long.
  final String title;

  /// The detail line in mono.
  final String? sub;

  /// An identifier at the right, such as `E-4127`.
  final String? code;

  /// Draw the hazard blocks at both ends.
  final bool hazards;

  /// A widget before the right hazard block, such as an acknowledge button.
  final Widget? action;

  /// Horizontal compression of [cjk]; 1.0 turns it off.
  final double squeeze;

  /// Defaults to 64.
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool critical = level == KkLevel.critical;
    final Color lv = c.level(level);
    final Color ink = critical ? c.onFill : lv;
    final double block = m.space12 + m.space4;
    final String? big = cjk;
    final String? detail = sub;
    final String? id = code;
    final Widget? trailing = action;

    Widget hazard() => KkHazard(
      color: critical ? c.onFill : lv,
      background: critical ? const Color(0x00000000) : c.bg000,
      running: critical,
      width: block,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: <String>[title, ?detail, ?id].join(', '),
      child: ExcludeSemantics(
        excluding: trailing == null,
        child: KkBox(
          minHeight: minHeight ?? block,
          decoration: KkDecoration(
            fill: critical ? c.alert : c.bg100,
            edges: KkEdges.line(lv, width: m.stroke2),
            glow: critical ? c.glowAlert : null,
          ),
          child: KkRow(
            cross: KkCrossAlign.stretch,
            children: <Widget>[
              if (hazards) hazard(),
              KkExpanded(
                child: KkBox(
                  padding: EdgeInsets.symmetric(horizontal: m.space4, vertical: m.space2),
                  child: KkRow(
                    gap: m.space4,
                    children: <Widget>[
                      if (big != null) KkText.cjk(big, size: 40, spacing: -0.01, color: ink, squeeze: squeeze),
                      KkExpanded(
                        child: KkColumn(
                          gap: 6,
                          shrinkWrap: true,
                          children: <Widget>[
                            KkText.en(
                              title,
                              size: 26,
                              weight: FontWeight.w800,
                              spacing: 0.02,
                              color: ink,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (detail != null)
                              KkText.num(
                                detail,
                                size: 12,
                                height: 1.3,
                                color: critical ? ink : c.inkDim,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (id != null)
                KkAlignSelf(
                  align: KkCrossAlign.center,
                  child: KkBox(
                    padding: EdgeInsets.symmetric(horizontal: m.space4),
                    child: KkText.num(id, size: 13, weight: FontWeight.w600, spacing: 0.06, color: ink),
                  ),
                ),
              if (trailing != null)
                KkAlignSelf(
                  align: KkCrossAlign.center,
                  child: KkBox(
                    padding: EdgeInsets.only(right: m.space4),
                    child: KkInk(color: ink, child: trailing),
                  ),
                ),
              if (hazards) hazard(),
            ],
          ),
        ),
      ),
    );
  }
}
