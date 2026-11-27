import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../motion/loops.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import 'badge.dart';
import 'control_style.dart';

/// The look of a [KkIconButton].
enum KkIconButtonVariant {
  /// No plate until hovered. The default.
  plain,

  /// A faint outline on the panel colour; the outline turns signal on hover.
  outline,

  /// Filled with signal.
  filled,

  /// A dim signal plate.
  tonal,
}

/// The size of a [KkIconButton].
enum KkIconButtonSize {
  /// 24px square.
  sm,

  /// 32px square.
  md,

  /// 40px square.
  lg,
}

/// A square button that holds one icon, cut at the top left.
///
/// It has no visible text, so always give it a [semanticLabel].
class KkIconButton extends StatelessWidget {
  const KkIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onLongPress,
    this.variant = KkIconButtonVariant.plain,
    this.size = KkIconButtonSize.md,
    this.toggled,
    this.badge,
    this.spinning = false,
    this.spinTrigger,
    this.enabled = true,
    this.style,
    this.iconSize = 16,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final KkIconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final KkIconButtonVariant variant;
  final KkIconButtonSize size;

  /// Makes this a toggle button. True shows the pressed look (signal outline,
  /// dim signal plate, signal icon); null means it is not a toggle.
  final bool? toggled;

  /// A badge pinned over the top-right corner, usually a [KkBadge].
  final Widget? badge;

  /// Turn the icon continuously, one turn every 0.6s in 8 steps.
  final bool spinning;

  /// Turn the icon once (0.6s, 8 steps) each time this value changes: the
  /// answer to a press on a refresh button.
  final Object? spinTrigger;
  final bool enabled;

  /// Colour overrides. A disabled button ignores them.
  final KkPlateStyle? style;
  final double iconSize;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  bool get _live => enabled && (onPressed != null || onLongPress != null);

  ({Color edge, Color fill, Color ink, KkGlow? glow}) _look(KkColors c, KkStates s) {
    const Color clear = Color(0x00000000);
    final bool on = toggled ?? false;
    if (!_live) {
      // Disabled keeps the variant's outline (a pressed toggle keeps signal)
      // and loses its fill, so the plate becomes an empty frame; only the
      // outline variant swaps to the offline colour on the panel fill.
      final Color edge = switch (variant) {
        KkIconButtonVariant.outline => c.offline,
        _ when on => c.signal,
        KkIconButtonVariant.plain => clear,
        KkIconButtonVariant.filled => c.signal,
        KkIconButtonVariant.tonal => c.signalDim,
      };
      return (edge: edge, fill: variant == KkIconButtonVariant.outline ? c.bg100 : clear, ink: c.inkFaint, glow: null);
    }
    final bool hover = s.hovered;
    Color edge;
    Color fill;
    Color ink;
    KkGlow? glow;
    switch (variant) {
      case KkIconButtonVariant.plain:
        edge = clear;
        fill = hover ? c.bg300 : clear;
        ink = hover ? c.ink : c.inkDim;
      case KkIconButtonVariant.outline:
        edge = hover ? c.signal : c.inkFaint;
        fill = hover ? c.bg300 : c.bg100;
        ink = hover ? c.ink : c.inkDim;
      case KkIconButtonVariant.filled:
        edge = c.signal;
        fill = c.signal;
        ink = c.onFill;
        if (hover) glow = KkGlow(color: c.signal, ring: 0, blur: 12, alpha: 1);
      case KkIconButtonVariant.tonal:
        edge = c.signalDim;
        fill = hover ? c.bg300 : c.signalDim;
        ink = c.ink;
    }
    if (on) {
      edge = c.signal;
      fill = c.signalDim;
      ink = c.signal;
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
    final double side = switch (size) {
      KkIconButtonSize.sm => m.space6,
      KkIconButtonSize.md => m.space8,
      KkIconButtonSize.lg => 40,
    };
    final Widget? pinned = badge;
    return KkPressable(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
      toggled: toggled,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final ({Color edge, Color fill, Color ink, KkGlow? glow}) look = _look(c, s);
        final Widget plate = KkFocusRing(
          visible: s.focused,
          offset: 2,
          width: m.stroke2,
          child: KkPlate(
            shape: KkShape.chamfer(tl: m.chamferSm),
            edge: look.edge,
            fill: look.fill,
            edgeWidth: m.stroke1,
            glow: look.glow,
            child: KkBox(
              width: side,
              height: side,
              alignment: Alignment.center,
              child: _KkSpin(
                spinning: spinning,
                trigger: spinTrigger,
                child: KkIcon(icon, size: iconSize, color: look.ink),
              ),
            ),
          ),
        );
        // The same tree with and without a badge: the plate, and the turn of
        // its icon, stay where they are when a badge comes or goes.
        return KkBadgeAnchor(top: -5, right: -7, badge: pinned, child: plate);
      },
    );
  }
}

/// Turns its child in eight hard steps: once per [trigger] change, or
/// continuously while [spinning].
class _KkSpin extends StatefulWidget {
  const _KkSpin({required this.spinning, required this.trigger, required this.child});

  final bool spinning;
  final Object? trigger;
  final Widget child;

  @override
  State<_KkSpin> createState() => _KkSpinState();
}

class _KkSpinState extends State<_KkSpin> with SingleTickerProviderStateMixin {
  static const Duration _turn = Duration(milliseconds: 600);
  static const int _steps = 8;

  late final AnimationController _controller = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(_KkSpin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && KeikaiTheme.motionOf(context)) {
      _controller.duration = KeikaiTheme.of(context).motion.scaled(_turn);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget once = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = const KkSteps(_steps).transform(_controller.value.clamp(0.0, 1.0));
        // A full turn ends where it began, so t == 1 is no rotation at all.
        return Transform.rotate(angle: t >= 1 ? 0 : t * 2 * math.pi, child: child);
      },
    );
    if (!widget.spinning) return once;
    return KkPhaseBuilder(
      period: _turn,
      phases: _steps,
      child: once,
      builder: (BuildContext context, int phase, Widget? child) =>
          Transform.rotate(angle: phase * 2 * math.pi / _steps, child: child),
    );
  }
}
