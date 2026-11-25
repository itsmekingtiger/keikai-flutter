import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import 'scan.dart';

/// A placeholder for content that is still loading: grey bars with a dim
/// signal block scanning across them in hard steps (1.4s, 14 steps).
///
/// By default it is three text lines. [widths] sets each line's share of the
/// available width; [KkSkeleton.block] is one tall block for a chart or an
/// image. It takes the width it is offered ([minWidth] where that is
/// unbounded).
class KkSkeleton extends StatelessWidget {
  const KkSkeleton({
    super.key,
    this.lines = 3,
    this.widths,
    this.lineHeight = 10,
    this.gap,
    this.minWidth = 120,
    this.semanticLabel = 'Loading',
  }) : blockHeight = null,
       assert(lines > 0);

  /// One block [height] tall.
  const KkSkeleton.block({super.key, double height = 64, this.minWidth = 120, this.semanticLabel = 'Loading'})
    : blockHeight = height,
      lines = 1,
      widths = null,
      lineHeight = 10,
      gap = null;

  /// Number of lines.
  final int lines;

  /// Width of each line as a share (0 to 1) of the skeleton's width; lines
  /// beyond the list are full width.
  final List<double>? widths;

  /// Height of one line.
  final double lineHeight;

  /// Space between lines. Defaults to 8.
  final double? gap;

  /// Height of the single block, when built with [KkSkeleton.block].
  final double? blockHeight;

  /// The skeleton is never narrower than this (when it has the room).
  final double minWidth;

  /// What screen readers announce. Null hides the skeleton from them.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;

    Widget bar(double height) => KkBox(
      height: height,
      fill: c.bg200,
      clip: true,
      child: KkScanBar(color: c.signalDim, period: const Duration(milliseconds: 1400), steps: 14),
    );

    // A full line takes the width it is offered.
    Widget line(double height) => KkRow(children: <Widget>[KkExpanded(child: bar(height))]);

    final double? block = blockHeight;
    final List<double>? shares = widths;
    final Widget body = KkBox(
      minWidth: minWidth,
      child: block != null
          ? KkColumn(shrinkWrap: true, children: <Widget>[line(block)])
          : KkColumn(
              shrinkWrap: true,
              gap: gap ?? m.space2,
              children: <Widget>[
                for (int i = 0; i < lines; i++)
                  if (shares != null && i < shares.length && shares[i] < 1)
                    KkRow(
                      children: <Widget>[
                        KkExpanded(flex: (shares[i].clamp(0.0, 1.0) * 1000).round(), child: bar(lineHeight)),
                        KkSpacer(flex: 1000 - (shares[i].clamp(0.0, 1.0) * 1000).round()),
                      ],
                    )
                  else
                    line(lineHeight),
              ],
            ),
    );
    final String? label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: body);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: body),
    );
  }
}
