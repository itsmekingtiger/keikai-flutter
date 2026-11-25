import 'package:flutter/widgets.dart';

import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';

/// A full-screen page. It enters with the boot wipe (left to right, 7 steps,
/// 0.42s) and leaves the same way in reverse.
class KkPageRoute<T> extends PageRoute<T> {
  KkPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    this.wipe = true,
  });

  final WidgetBuilder builder;

  /// Whether to play the wipe at all.
  final bool wipe;

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  bool get _motion {
    final BuildContext? context = navigator?.context;
    return wipe && context != null && KeikaiTheme.motionOf(context);
  }

  @override
  Duration get transitionDuration {
    final BuildContext? context = navigator?.context;
    if (!_motion || context == null) return Duration.zero;
    return KeikaiTheme.of(context).motion.scaled(KkMotion.boot);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: KkBox(fill: KeikaiTheme.of(context).colors.bg000, child: builder(context)),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!wipe || !KeikaiTheme.motionOf(context)) return child;
    return ClipRect(clipper: KkWipeClipper(animation, KkMotion.bootSteps), child: child);
  }
}

/// Reveals the child from the left in [steps] jumps as [progress] goes 0 to 1.
class KkWipeClipper extends CustomClipper<Rect> {
  KkWipeClipper(this.progress, this.steps) : super(reclip: progress);

  final Animation<double> progress;
  final int steps;

  @override
  Rect getClip(Size size) {
    final double t = KkSteps(steps).transform(progress.value.clamp(0.0, 1.0));
    return Rect.fromLTWH(0, 0, size.width * t, size.height);
  }

  @override
  bool shouldReclip(KkWipeClipper oldClipper) => oldClipper.progress != progress || oldClipper.steps != steps;
}

/// A route that floats over the page behind it: the base of dialogs, sheets
/// and full-screen alarms.
///
/// [builder] receives the route's animation (0 to 1 while opening) and should
/// apply its own stepped entrance. The scrim snaps in; it never fades.
class KkPopupRoute<T> extends PopupRoute<T> {
  KkPopupRoute({
    required this.builder,
    this.scrim,
    this.dismissible = true,
    this.label = 'Dismiss',
    this.duration = KkMotion.boot,
    super.settings,
  });

  final Widget Function(BuildContext context, Animation<double> animation) builder;

  /// Colour behind the popup. Null leaves the page fully visible.
  final Color? scrim;
  final bool dismissible;
  final String label;
  final Duration duration;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration {
    final BuildContext? context = navigator?.context;
    if (context == null || !KeikaiTheme.motionOf(context)) return Duration.zero;
    return KeikaiTheme.of(context).motion.scaled(duration);
  }

  @override
  Widget buildModalBarrier() {
    final Color? color = scrim;
    return ModalBarrier(
      color: color,
      dismissible: dismissible,
      semanticsLabel: label,
      barrierSemanticsDismissible: dismissible,
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: builder(context, animation));
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
