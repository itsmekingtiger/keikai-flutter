import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/loops.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';
import 'scan.dart';

/// The look of a [KkButton].
enum KkButtonVariant {
  /// Signal outline on the panel colour. The default.
  outline,

  /// Filled with signal: the one main action of a view.
  primary,

  /// Alert outline that fills with alert under the pointer: destructive actions.
  danger,

  /// No plate until hovered.
  ghost,

  /// A dim signal plate with ink text.
  tonal,
}

/// The height of a [KkButton].
enum KkButtonSize {
  /// 28px high, 13px type.
  sm,

  /// 36px high, 15px type.
  md,

  /// 48px high, 18px type.
  lg,
}

/// The KEIKAI button: a plate cut at the top left and the bottom right,
/// Latin capitals, an optional 漢字 word and icons.
///
/// A button with neither [onPressed] nor [onLongPress], or with [enabled]
/// false, is drawn disabled. Enter and Space activate it; the focus ring
/// shows for keyboard focus only.
class KkButton extends StatelessWidget {
  const KkButton({
    super.key,
    this.label,
    this.cjk,
    this.icon,
    this.trailingIcon,
    this.child,
    this.onPressed,
    this.onLongPress,
    this.variant = KkButtonVariant.outline,
    this.size = KkButtonSize.md,
    this.enabled = true,
    this.loading = false,
    this.loadingLabel = 'Loading',
    this.expand = false,
    this.style,
    this.iconSize = 16,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(
         label != null || cjk != null || icon != null || trailingIcon != null || child != null,
         'A button needs a label, a cjk word, an icon or a child.',
       );

  /// Latin text; it is upper-cased.
  final String? label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;

  /// Icon before the text.
  final KkIconData? icon;

  /// Icon after the text.
  final KkIconData? trailingIcon;

  /// Custom content instead of [cjk] and [label]. It inherits the button's
  /// label type and ink.
  final Widget? child;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final KkButtonVariant variant;
  final KkButtonSize size;
  final bool enabled;

  /// Busy: a bar scans along the bottom edge and presses are ignored. The
  /// button keeps its look, its keyboard focus and its place in the Tab order;
  /// hovering over it or pressing it shows nothing until it is done.
  final bool loading;

  /// What screen readers say with the button's name while it is [loading].
  /// An empty string says nothing.
  final String loadingLabel;

  /// Fill the available width, with the content centred.
  final bool expand;

  /// Colour overrides. They do not apply while disabled.
  final KkPlateStyle? style;
  final double iconSize;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;

  bool get _live => enabled && (onPressed != null || onLongPress != null);

  /// Stands in for the callbacks of a busy button.
  static void _swallow() {}

  ({Color edge, Color fill, Color ink, KkGlow? glow}) _look(KkColors c, KkStates s) {
    if (!_live) return (edge: c.offline, fill: c.bg100, ink: c.inkFaint, glow: null);
    const Color clear = Color(0x00000000);
    final bool hover = s.hovered;
    Color edge;
    Color fill;
    Color ink;
    KkGlow? glow;
    switch (variant) {
      case KkButtonVariant.outline:
        edge = c.signal;
        fill = hover ? c.bg300 : c.bg100;
        ink = c.signal;
      case KkButtonVariant.primary:
        edge = c.signal;
        fill = c.signal;
        ink = c.onFill;
        // drop-shadow(0 0 6px signal): the length is the blur's deviation.
        if (hover) glow = KkGlow(color: c.signal, ring: 0, blur: 12, alpha: 1);
      case KkButtonVariant.danger:
        edge = c.alert;
        fill = hover ? c.alert : c.bg100;
        ink = hover ? c.onFill : c.alert;
      case KkButtonVariant.ghost:
        edge = clear;
        fill = hover ? c.bg300 : clear;
        ink = c.signal;
      case KkButtonVariant.tonal:
        edge = hover ? c.signal : c.signalDim;
        fill = c.signalDim;
        ink = c.ink;
    }
    final KkPlateStyle? st = style;
    if (st != null) {
      edge = (hover ? st.hoverEdge : null) ?? st.edge ?? edge;
      fill = (hover ? st.hoverFill : null) ?? st.fill ?? fill;
      ink = (hover ? st.hoverInk : null) ?? st.ink ?? ink;
    }
    return (edge: edge, fill: fill, ink: ink, glow: glow);
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final (double height, double pad, double type, double cjkType) = switch (size) {
      KkButtonSize.sm => (28.0, m.space3, 13.0, 14.0),
      KkButtonSize.md => (36.0, m.space4, 15.0, 14.0),
      KkButtonSize.lg => (m.space12, m.space6, 18.0, 18.0),
    };
    final bool busy = loading && _live;
    return KkPressable(
      // A busy button is still a control. Without callbacks it would be a
      // disabled one, which cannot hold the keyboard focus: the focus would
      // fall to the page and never come back. So the press is swallowed
      // instead.
      onPressed: busy && onPressed != null ? _swallow : onPressed,
      onLongPress: busy && onLongPress != null ? _swallow : onLongPress,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      cursor: busy ? SystemMouseCursors.progress : null,
      semanticLabel: semanticLabel,
      builder: (BuildContext context, KkStates raw) {
        final KkStates live = KkStateOverride.resolve(context, raw);
        // There is nothing to press while busy, so the pointer shows nothing.
        // The focus does.
        final KkStates s = busy ? KkStates(focused: live.focused) : live;
        final ({Color edge, Color fill, Color ink, KkGlow? glow}) look = _look(c, s);
        final Color ink = look.ink;
        final KkIconData? lead = icon;
        final KkIconData? trail = trailingIcon;
        final Widget? custom = child;
        final String? cjkWord = cjk;
        final String? text = label;
        final bool iconOnly =
            custom == null && trail == null && (cjkWord == null || cjkWord.isEmpty) && (text == null || text.isEmpty);
        Widget box = KkBox(
          height: height,
          // A leading icon sits 4px closer to the edge than text does (but an
          // icon on its own stays centred).
          padding: EdgeInsets.only(left: lead != null && !iconOnly ? pad - m.space1 : pad, right: pad),
          alignment: expand ? Alignment.center : null,
          child: KkRow(
            shrinkWrap: true,
            main: KkMainAlign.center,
            gap: m.space2,
            clip: Clip.hardEdge,
            children: <Widget>[
              if (lead != null) KkIcon(lead, size: iconSize, color: ink),
              if (custom != null)
                KkFlexible(
                  child: DefaultTextStyle(
                    style: theme.type.label(type, spacingEm: 0.08, color: ink),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    child: custom,
                  ),
                )
              else ...<Widget>[
                if (cjkWord != null && cjkWord.isNotEmpty) KkText.cjk(cjkWord, size: cjkType, color: ink, squeeze: 0.8),
                if (text != null && text.isNotEmpty)
                  KkFlexible(
                    child: KkText.en(text, size: type, spacing: 0.08, color: ink, overflow: TextOverflow.ellipsis),
                  ),
              ],
              if (trail != null) KkIcon(trail, size: iconSize, color: ink),
            ],
          ),
        );
        if (busy) {
          final bool motion = KeikaiTheme.motionOf(context);
          box = KkPhaseBuilder(
            period: const Duration(milliseconds: 1200),
            phases: 12,
            child: box,
            builder: (BuildContext context, int phase, Widget? child) => CustomPaint(
              foregroundPainter: _BusyPainter(
                color: ink,
                start: motion ? kkScanOffset(phase, 12) : 0.375,
                inset: m.stroke1,
                thickness: m.stroke2,
              ),
              child: child,
            ),
          );
        }
        return Semantics(
          // Said with the name of the button, whether that is its visible
          // text or the semantic label that replaces it.
          value: busy && loadingLabel.isNotEmpty ? loadingLabel : null,
          excludeSemantics: semanticLabel != null,
          child: Transform.translate(
            offset: Offset(0, s.pressed ? 1 : 0),
            child: KkFocusRing(
              visible: s.focused,
              offset: 2,
              width: m.stroke2,
              child: KkPlate(
                shape: KkShape.plate(m.chamferMd),
                edge: look.edge,
                fill: look.fill,
                edgeWidth: m.stroke1,
                glow: look.glow,
                clip: busy,
                child: box,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The busy bar of a loading button: a quarter-width bar stepping along the
/// bottom edge, just inside the outline.
class _BusyPainter extends CustomPainter {
  const _BusyPainter({required this.color, required this.start, required this.inset, required this.thickness});

  final Color color;
  final double start;
  final double inset;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect track = Rect.fromLTRB(inset, size.height - inset - thickness, size.width - inset, size.height - inset);
    if (track.width <= 0 || track.height <= 0) return;
    final Rect bar = Rect.fromLTWH(
      track.left + start * track.width,
      track.top,
      track.width * 0.25,
      track.height,
    ).intersect(track);
    if (bar.width <= 0) return;
    canvas.drawRect(bar, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BusyPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.start != start ||
      oldDelegate.inset != inset ||
      oldDelegate.thickness != thickness;
}
