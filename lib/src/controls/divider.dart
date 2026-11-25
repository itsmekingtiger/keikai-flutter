import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/patterns.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// A rule between groups of content.
///
/// The horizontal rule can carry a signal code and a bilingual label at its
/// start (`SEC-04 冷却 COOLANT ────`), and can be drawn as a ruler of 8px
/// ticks. [KkDivider.vertical] is a 1px upright line for toolbars and rows.
class KkDivider extends StatelessWidget {
  /// A horizontal rule that takes the remaining width.
  const KkDivider({super.key, this.code, this.cjk, this.en, this.ticks = false, this.color})
    : _vertical = false,
      height = null;

  /// A 1px upright line, at least 16px tall.
  ///
  /// In a `KkRow` wrap it in `KkAlignSelf(align: KkCrossAlign.stretch)` to
  /// make it as tall as the row, or give it a [height].
  const KkDivider.vertical({super.key, this.height, this.color})
    : _vertical = true,
      code = null,
      cjk = null,
      en = null,
      ticks = false;

  /// A short code in signal mono before the label: `SEC-04`.
  final String? code;

  /// CJK part of the label.
  final String? cjk;

  /// Latin capitals part of the label.
  final String? en;

  /// Draw the rule as a 6px ruler: a base line with a tick every 8px.
  final bool ticks;

  /// Line colour. Defaults to the line token.
  final Color? color;

  /// Fixed height of a vertical divider.
  final double? height;
  final bool _vertical;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color line = color ?? c.line;
    if (_vertical) {
      return ExcludeSemantics(
        child: KkBox(width: m.stroke1, height: height, minHeight: height == null ? m.space4 : 0, fill: line),
      );
    }
    final Widget rule = ticks
        ? KkBox(
            height: 6,
            decoration: KkDecoration(
              pattern: KkPattern.ticks(color: line, pitch: m.pitchFine, stroke: m.stroke1),
              edges: KkEdges(bottom: KkSide(line, width: m.stroke1)),
            ),
          )
        : KkBox(height: m.stroke1, fill: line);
    final String? codeText = code;
    final String? cjkText = cjk;
    final String? enText = en;
    final bool hasLabel = (cjkText?.isNotEmpty ?? false) || (enText?.isNotEmpty ?? false);
    if (codeText == null && !hasLabel) {
      return ExcludeSemantics(
        child: KkRow(children: <Widget>[KkExpanded(child: rule)]),
      );
    }
    return KkRow(
      gap: m.space2,
      children: <Widget>[
        if (codeText != null) KkText.num(codeText, size: 10, weight: FontWeight.w500, color: c.signal),
        if (hasLabel)
          KkRow(
            shrinkWrap: true,
            cross: KkCrossAlign.baseline,
            gap: 6,
            children: <Widget>[
              if (cjkText != null && cjkText.isNotEmpty)
                KkText.cjk(cjkText, size: 12, height: 1.55, color: c.ink, squeeze: 0.8),
              if (enText != null && enText.isNotEmpty)
                KkText.en(
                  enText,
                  size: 10,
                  weight: FontWeight.w600,
                  height: 1.55,
                  spacing: 0.16,
                  color: c.inkDim,
                ),
            ],
          ),
        KkExpanded(child: ExcludeSemantics(child: rule)),
      ],
    );
  }
}
