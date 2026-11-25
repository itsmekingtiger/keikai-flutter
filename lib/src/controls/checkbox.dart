import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/flex.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import 'control_style.dart';
import 'option_label.dart';

/// A 16px square checkbox with an optional bilingual label.
///
/// [value] is true (ticked), false (empty) or, when [tristate] is on, null
/// (a dash: some of the things it stands for are ticked). Pressing cycles
/// false → true → null → false with [tristate], false ↔ true without.
class KkCheckbox extends StatelessWidget {
  const KkCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.tristate = false,
    this.label,
    this.cjk,
    this.error = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(tristate || value != null, 'A null value needs tristate: true.');

  final bool? value;

  /// Called with the next value. Null disables the checkbox.
  final ValueChanged<bool?>? onChanged;
  final bool tristate;

  /// Latin text; it is upper-cased.
  final String? label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;

  /// Outline the empty box in alert: a required box left unticked.
  final bool error;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Replaces the visible label for screen readers (or names a bare box).
  final String? semanticLabel;

  bool? get _next {
    final bool? v = value;
    if (!tristate) return !(v ?? false);
    if (v == null) return false;
    return v ? null : true;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final ValueChanged<bool?>? changed = onChanged;
    final bool live = enabled && changed != null;
    final bool mixed = value == null;
    final bool marked = mixed || value!;
    final bool hasLabel = (label?.isNotEmpty ?? false) || (cjk?.isNotEmpty ?? false);
    return KkPressable(
      onPressed: changed == null ? null : () => changed(_next),
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      button: false,
      checked: mixed ? null : value,
      mixed: mixed ? true : null,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final Color edge;
        final Color fill;
        if (!live) {
          edge = c.offline;
          fill = marked ? c.offline : c.bg100;
        } else if (marked) {
          edge = c.signal;
          fill = c.signal;
        } else {
          edge = s.hovered ? c.signal : (error ? c.alert : c.inkFaint);
          fill = c.bg100;
        }
        return KkRow(
          shrinkWrap: true,
          gap: m.space2,
          children: <Widget>[
            KkFocusRing(
              visible: s.focused,
              offset: 2,
              width: m.stroke2,
              child: CustomPaint(
                size: const Size.square(16),
                painter: _CheckPainter(
                  edge: edge,
                  fill: fill,
                  stroke: m.stroke1,
                  mark: mixed ? KkIcons.minus : (marked ? KkIcons.check : null),
                  markColor: c.onFill,
                ),
              ),
            ),
            if (hasLabel) KkOptionLabel(label: label, cjk: cjk, color: live ? c.ink : c.inkFaint),
          ],
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.edge,
    required this.fill,
    required this.stroke,
    required this.mark,
    required this.markColor,
  });

  final Color edge;
  final Color fill;
  final double stroke;
  final KkIconData? mark;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = edge);
    canvas.drawRect(rect.deflate(stroke), Paint()..color = fill);
    final KkIconData? m = mark;
    // The mark is drawn on the full 16px grid, so its line is the icon set's 1.5px.
    if (m != null) kkPaintIcon(canvas, rect, m, markColor);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.edge != edge ||
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.mark != mark ||
      oldDelegate.markColor != markColor;
}
