import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../layout/flex.dart';
import '../widgets/text.dart';

/// The label of a checkbox, a radio option or a switch: a CJK word and Latin
/// capitals on one baseline, 13px, line height 1.2.
class KkOptionLabel extends StatelessWidget {
  const KkOptionLabel({super.key, this.label, this.cjk, this.color});

  /// Latin text; it is upper-cased.
  final String? label;
  final String? cjk;

  /// Defaults to ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color ink = color ?? KeikaiTheme.of(context).colors.ink;
    final String? c = cjk;
    final String? l = label;
    return KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      gap: 6,
      clip: Clip.hardEdge,
      children: <Widget>[
        if (c != null && c.isNotEmpty) KkText.cjk(c, size: 13, height: 1.2, color: ink, squeeze: 0.8),
        if (l != null && l.isNotEmpty)
          KkFlexible(
            child: KkText.en(
              l,
              size: 13,
              weight: FontWeight.w600,
              height: 1.2,
              spacing: 0.08,
              color: ink,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
