import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// What a [KkChip] is for.
enum KkChipVariant {
  /// A small action, with an optional leading icon in signal.
  assist,

  /// A filter that is on or off, shown by its lamp.
  filter,

  /// A proposed value, drawn with a dashed outline in dim ink.
  suggestion,

  /// A value the user entered, with a remove button.
  input,
}

/// A 28px chip: a compact action, filter, suggestion or entered value.
///
/// A filter chip's lamp is always there; turning the filter on fills it and
/// tints the chip, so the chip never changes width.
class KkChip extends StatelessWidget {
  /// A chip of any [variant]. The named constructors are shorter.
  const KkChip({
    super.key,
    required this.label,
    this.cjk,
    this.icon,
    this.variant = KkChipVariant.assist,
    this.selected = false,
    this.onPressed,
    this.onSelected,
    this.onRemove,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.removeLabel = 'Remove',
  });

  /// A filter chip. [onSelected] receives the new on/off state.
  const KkChip.filter({
    super.key,
    required this.label,
    this.cjk,
    this.icon,
    required this.selected,
    this.onSelected,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : variant = KkChipVariant.filter,
       onPressed = null,
       onRemove = null,
       removeLabel = 'Remove';

  /// A suggestion chip.
  const KkChip.suggestion({
    super.key,
    required this.label,
    this.cjk,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : variant = KkChipVariant.suggestion,
       selected = false,
       onSelected = null,
       onRemove = null,
       removeLabel = 'Remove';

  /// An input chip. Its body is inert; [onRemove] is the remove button.
  const KkChip.input({
    super.key,
    required this.label,
    this.cjk,
    this.icon,
    this.onRemove,
    this.onPressed,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.removeLabel = 'Remove',
  }) : variant = KkChipVariant.input,
       selected = false,
       onSelected = null;

  /// Latin text; it is upper-cased.
  final String label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;

  /// Leading icon, drawn in signal.
  final KkIconData? icon;
  final KkChipVariant variant;

  /// Whether a filter chip is on.
  final bool selected;

  /// Pressing the chip. For a filter chip prefer [onSelected].
  final VoidCallback? onPressed;

  /// Toggling a filter chip.
  final ValueChanged<bool>? onSelected;

  /// Pressing the remove button of an input chip.
  final VoidCallback? onRemove;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  /// What the remove button is called for screen readers.
  final String removeLabel;

  VoidCallback? get _press {
    final ValueChanged<bool>? toggle = onSelected;
    if (variant == KkChipVariant.filter && toggle != null) return () => toggle(!selected);
    return onPressed;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool isInput = variant == KkChipVariant.input;
    final bool isFilter = variant == KkChipVariant.filter;
    final VoidCallback? press = _press;
    // An input chip is a value, not a button: it is live while it can be
    // removed (or pressed), and its body does not react to the pointer.
    final bool live = enabled && (isInput ? (onRemove != null || press != null) : press != null);
    final bool on = isFilter && selected;

    Widget body(KkStates s) {
      final Color edge;
      final Color fill;
      final Color ink;
      if (!live) {
        edge = c.offline;
        fill = c.bg100;
        ink = c.inkFaint;
      } else {
        edge = on ? c.signal : c.inkFaint;
        fill = on ? c.signalDim : (s.hovered && !isInput ? c.bg300 : c.bg100);
        ink = variant == KkChipVariant.suggestion ? c.inkDim : c.ink;
      }
      final KkIconData? lead = icon;
      final String? cjkWord = cjk;
      final VoidCallback? remove = onRemove;
      return KkFocusRing(
        visible: s.focused,
        offset: 2,
        width: m.stroke2,
        child: KkBox(
          height: 28,
          padding: EdgeInsets.only(left: m.space3, right: isInput ? m.space1 : m.space3),
          decoration: KkDecoration(
            fill: fill,
            edges: KkEdges.line(edge, width: m.stroke1, dashed: variant == KkChipVariant.suggestion),
          ),
          child: KkRow(
            shrinkWrap: true,
            gap: 6,
            clip: Clip.hardEdge,
            children: <Widget>[
              if (lead != null) KkIcon(lead, size: 16, color: c.signal),
              if (isFilter)
                KkBox(
                  width: 10,
                  height: 10,
                  decoration: KkDecoration(
                    fill: on ? c.signal : null,
                    edges: KkEdges.line(on ? c.signal : c.inkFaint, width: 1.5),
                  ),
                ),
              if (cjkWord != null && cjkWord.isNotEmpty) KkText.cjk(cjkWord, size: 13, color: ink, squeeze: 0.8),
              if (label.isNotEmpty) KkText.en(label, size: 13, weight: FontWeight.w600, spacing: 0.08, color: ink),
              if (isInput) _ChipRemove(onPressed: enabled ? remove : null, label: removeLabel, colors: c, metrics: m),
            ],
          ),
        ),
      );
    }

    if (isInput && press == null) {
      return Semantics(container: true, label: semanticLabel, child: body(const KkStates()));
    }
    return KkPressable(
      onPressed: press,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      cursor: isInput ? SystemMouseCursors.basic : null,
      semanticLabel: semanticLabel,
      button: !isFilter,
      toggled: isFilter ? selected : null,
      builder: (BuildContext context, KkStates raw) => body(KkStateOverride.resolve(context, raw)),
    );
  }
}

class _ChipRemove extends StatelessWidget {
  const _ChipRemove({required this.onPressed, required this.label, required this.colors, required this.metrics});

  final VoidCallback? onPressed;
  final String label;
  final KkColors colors;
  final KkMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return KkPressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        return KkFocusRing(
          visible: s.focused,
          offset: 1,
          width: metrics.stroke2,
          child: KkBox(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            fill: s.hovered ? colors.bg300 : null,
            child: KkIcon(
              KkIcons.close,
              size: 12,
              color: s.disabled ? colors.inkFaint : (s.hovered ? colors.ink : colors.inkDim),
            ),
          ),
        );
      },
    );
  }
}
