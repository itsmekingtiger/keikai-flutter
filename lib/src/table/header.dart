import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../inputs/tooltip.dart';
import '../layout/flex.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'column.dart';

/// The label of one column in the header of a table: an optional CJK word
/// over Latin capitals with an optional unit, and, on a sortable column, the
/// sort arrow.
///
/// The arrow always has its place. It shows in signal while the column is
/// sorted and in the label's colour while the pointer or the keyboard focus
/// is on an unsorted column.
///
/// This class is not part of the public API.
class KkTableHeaderLabel extends StatelessWidget {
  const KkTableHeaderLabel({
    super.key,
    this.cjk,
    this.en,
    this.unit,
    this.end = false,
    this.sort,
    this.onSort,
    this.tooltip,
    this.squeeze = 0.8,
    required this.semanticLabel,
  });

  final String? cjk;
  final String? en;
  final String? unit;

  /// Right-aligned (a numeric column).
  final bool end;

  /// The direction this column is sorted in, or null.
  final KkSortDirection? sort;

  /// Called to move the column to its next sort state. Null means the column
  /// cannot be sorted.
  final VoidCallback? onSort;
  final String? tooltip;
  final double squeeze;
  final String semanticLabel;

  Widget _label(BuildContext context, KkStates s) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final KkSortDirection? direction = sort;
    final bool sorted = direction != null;
    final Color ink = sorted ? c.ink : c.inkDim;
    final String? enText = en;
    final String? unitText = unit;
    final String? cjkText = cjk;
    final bool showArrow = sorted || s.hovered || s.focused;
    final Widget line = KkRow(
      shrinkWrap: true,
      gap: 4,
      children: <Widget>[
        if (enText != null && enText.isNotEmpty)
          KkText.en(enText, size: 10, weight: FontWeight.w600, spacing: 0.16, color: ink),
        if (unitText != null && unitText.isNotEmpty)
          KkText.en(unitText, size: 10, weight: FontWeight.w600, spacing: 0.04, upper: false, color: ink),
        if (onSort != null)
          Opacity(
            opacity: showArrow ? 1 : 0,
            child: KkIcon(
              direction == KkSortDirection.descending ? KkIcons.arrowDown : KkIcons.arrowUp,
              size: 10,
              color: sorted ? c.signal : ink,
            ),
          ),
      ],
    );
    if (cjkText == null || cjkText.isEmpty) return line;
    return KkColumn(
      shrinkWrap: true,
      gap: 4,
      cross: end ? KkCrossAlign.end : KkCrossAlign.start,
      children: <Widget>[
        KkText.cjk(cjkText, size: 13, color: c.ink, squeeze: squeeze),
        line,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final VoidCallback? toggle = onSort;
    final KkSortDirection? direction = sort;
    Widget label;
    if (toggle == null) {
      label = Semantics(
        container: true,
        header: true,
        label: semanticLabel,
        child: ExcludeSemantics(child: _label(context, const KkStates())),
      );
    } else {
      final String state = switch (direction) {
        KkSortDirection.ascending => 'sorted ascending',
        KkSortDirection.descending => 'sorted descending',
        null => 'not sorted',
      };
      label = KkPressable(
        onPressed: toggle,
        semanticLabel: '$semanticLabel, $state',
        excludeSemantics: true,
        builder: (BuildContext context, KkStates raw) {
          final KkStates s = KkStateOverride.resolve(context, raw);
          return KkFocusRing(visible: s.focused, offset: 2, width: m.stroke2, child: _label(context, s));
        },
      );
    }
    final String? note = tooltip;
    if (note != null && note.isNotEmpty) label = KkTooltip(message: note, child: label);
    return label;
  }
}
