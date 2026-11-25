import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// The colour of a [KkFab].
enum KkFabVariant {
  /// Signal.
  primary,

  /// Alert: an action that stops or destroys.
  danger,
}

/// The size of a hexagon [KkFab].
enum KkFabSize {
  /// 40 × 46.
  sm,

  /// 56 × 64.
  md,
}

/// The floating action button: a filled hexagon holding one icon, or, when
/// [KkFab.extended], a 48px plate with an icon and a label.
///
/// It glows under the pointer. To float it over a screen, pin it 24px from the
/// right edge and 24px above the toolbar with `KkPositioned`.
class KkFab extends StatelessWidget {
  /// A hexagon with one icon.
  const KkFab({
    super.key,
    required KkIconData this.icon,
    this.onPressed,
    this.onLongPress,
    this.variant = KkFabVariant.primary,
    this.size = KkFabSize.md,
    this.enabled = true,
    this.color,
    this.onColor,
    this.iconSize,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : label = null;

  /// A 48px plate with an optional icon and a label.
  const KkFab.extended({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.variant = KkFabVariant.primary,
    this.enabled = true,
    this.color,
    this.onColor,
    this.iconSize,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : size = KkFabSize.md;

  final KkIconData? icon;

  /// Latin text of an extended button; it is upper-cased.
  final String? label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final KkFabVariant variant;
  final KkFabSize size;
  final bool enabled;

  /// Overrides the fill.
  final Color? color;

  /// Overrides the icon and text colour.
  final Color? onColor;

  /// Defaults to 20 on the full hexagon and 16 elsewhere.
  final double? iconSize;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  bool get _live => enabled && (onPressed != null || onLongPress != null);

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? text = label;
    final bool extended = text != null;
    final KkIconData? glyph = icon;
    // The design gives a FAB no disabled look; it borrows the offline fill
    // that disabled filled controls use elsewhere.
    final Color fill = !_live ? c.offline : (color ?? (variant == KkFabVariant.danger ? c.alert : c.signal));
    final Color ink = onColor ?? c.onFill;
    return KkPressable(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        // drop-shadow(0 0 8px fill): the length is the blur's deviation.
        final KkGlow? glow = s.hovered ? KkGlow(color: fill, ring: 0, blur: 16, alpha: 1) : null;
        final Widget plate;
        if (extended) {
          plate = KkSurface(
            shape: KkShape.plate(m.chamferLg),
            fill: fill,
            edgeWidth: 0,
            glow: glow,
            child: KkBox(
              height: m.space12,
              padding: EdgeInsets.only(left: m.space4, right: m.space6),
              child: KkRow(
                shrinkWrap: true,
                main: KkMainAlign.center,
                gap: m.space2,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (glyph != null) KkIcon(glyph, size: iconSize ?? 16, color: ink),
                  KkFlexible(
                    child: KkText.en(text, size: 16, spacing: 0.08, color: ink, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        } else {
          final bool small = size == KkFabSize.sm;
          plate = KkSurface(
            shape: const KkShape.hex(),
            fill: fill,
            edgeWidth: 0,
            glow: glow,
            child: KkBox(
              width: small ? 40 : 56,
              height: small ? 46 : 64,
              alignment: Alignment.center,
              child: glyph == null ? null : KkIcon(glyph, size: iconSize ?? (small ? 16 : 20), color: ink),
            ),
          );
        }
        return Transform.translate(
          offset: Offset(0, s.pressed ? 1 : 0),
          child: KkFocusRing(visible: s.focused, offset: 3, width: m.stroke2, child: plate),
        );
      },
    );
  }
}
