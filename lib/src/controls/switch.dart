import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';
import 'option_label.dart';

/// A two-cell switch that spells its state out: `OFF | ON`. The cell that is
/// current is lit; nothing slides.
class KkSwitch extends StatelessWidget {
  const KkSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.cjk,
    this.offLabel = 'OFF',
    this.onLabel = 'ON',
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final bool value;

  /// Called with the new state. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Latin text beside the track; it is upper-cased.
  final String? label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;

  /// The word in the left cell.
  final String offLabel;

  /// The word in the right cell.
  final String onLabel;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Replaces the visible label for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final ValueChanged<bool>? changed = onChanged;
    final bool live = enabled && changed != null;
    final bool hasLabel = (label?.isNotEmpty ?? false) || (cjk?.isNotEmpty ?? false);

    Widget cell(String word, {Color? fill, required Color ink}) {
      return KkBox(
        minWidth: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        fill: fill,
        child: KkRow(
          shrinkWrap: true,
          main: KkMainAlign.center,
          clip: Clip.hardEdge,
          children: <Widget>[KkText.num(word, size: 11, weight: FontWeight.w700, spacing: 0.06, color: ink)],
        ),
      );
    }

    return KkPressable(
      onPressed: changed == null ? null : () => changed(!value),
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      button: false,
      toggled: value,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final Color edge = !live ? c.offline : (value ? c.signal : c.inkFaint);
        return KkRow(
          shrinkWrap: true,
          gap: m.space2,
          clip: Clip.hardEdge,
          children: <Widget>[
            KkFocusRing(
              visible: s.focused,
              offset: 2,
              width: m.stroke2,
              child: KkBox(
                height: 24,
                decoration: KkDecoration(
                  fill: c.bg100,
                  edges: KkEdges.line(edge, width: m.stroke1),
                ),
                child: KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.stretch,
                  children: <Widget>[
                    cell(offLabel, fill: value ? null : c.bg300, ink: value ? c.inkFaint : c.ink),
                    cell(
                      onLabel,
                      fill: value ? (live ? c.signal : c.offline) : null,
                      ink: value ? c.onFill : c.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (hasLabel)
              KkFlexible(
                child: KkOptionLabel(label: label, cjk: cjk, color: live ? c.ink : c.inkFaint),
              ),
          ],
        );
      },
    );
  }
}
