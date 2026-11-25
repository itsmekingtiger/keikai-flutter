import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// A count on a small plate cut at the top right, or a bare 8px dot.
///
/// The fill is the level colour, alert by default: a badge says something is
/// waiting. It ignores pointer events.
class KkBadge extends StatelessWidget {
  /// A badge showing [count] (capped at [max], then `99+`), or [label].
  const KkBadge({super.key, this.count, this.label, this.max = 99, this.level, this.color, this.onColor})
    : dot = false,
      assert(count != null || label != null, 'Give a count or a label, or use KkBadge.dot.');

  /// An 8px square with no text.
  const KkBadge.dot({super.key, this.level, this.color})
    : dot = true,
      count = null,
      label = null,
      max = 99,
      onColor = null;

  final int? count;

  /// Text instead of a count.
  final String? label;

  /// Counts above this read `<max>+`.
  final int max;

  /// Colours the badge. Without a level (or [color]) it is alert.
  final KkLevel? level;
  final Color? color;

  /// Text colour. Defaults to the on-fill ink.
  final Color? onColor;
  final bool dot;

  /// The text shown for the current [count] and [max].
  String get text {
    final String? l = label;
    if (l != null) return l;
    final int n = count ?? 0;
    return n > max ? '$max+' : '$n';
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color fill = color ?? c.level(level, fallback: c.alert);
    if (dot) {
      return IgnorePointer(
        child: KkBox(width: m.space2, height: m.space2, fill: fill),
      );
    }
    return IgnorePointer(
      child: KkSurface(
        shape: KkShape.chamfer(tr: m.space1),
        fill: fill,
        edgeWidth: 0,
        child: KkBox(
          minWidth: 16,
          height: 16,
          padding: EdgeInsets.symmetric(horizontal: m.space1),
          child: KkRow(
            shrinkWrap: true,
            main: KkMainAlign.center,
            children: <Widget>[
              KkText.num(
                text,
                size: 10,
                weight: FontWeight.w600,
                color: onColor ?? c.onFill,
                // Tabular figures only: a badge's zero is not slashed.
                style: const TextStyle(fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pins a [badge] over the top-right corner of [child] (6px up, 8px out).
class KkBadgeAnchor extends StatelessWidget {
  const KkBadgeAnchor({
    super.key,
    required this.child,
    required this.badge,
    this.show = true,
    this.top = -6,
    this.right = -8,
  });

  final Widget child;

  /// Usually a [KkBadge].
  final Widget badge;

  /// Hide the badge without changing the layout.
  final bool show;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return KkLayers(
      children: <Widget>[
        child,
        if (show) KkPositioned(top: top, right: right, child: IgnorePointer(child: badge)),
      ],
    );
  }
}
