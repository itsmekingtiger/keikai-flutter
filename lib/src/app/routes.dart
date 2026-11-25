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

/// A page for the pages API ([Navigator.pages] and [Router]): it creates a
/// [KkPageRoute], so declarative navigation gets the same stepped wipe as
/// [Navigator.push].
///
/// ```dart
/// Navigator(
///   pages: <Page<void>>[
///     const KkPage<void>(key: ValueKey<String>('board'), child: Board()),
///     if (sector != null) KkPage<void>(key: ValueKey<String>(sector), child: SectorDetail(sector)),
///   ],
///   onDidRemovePage: (Page<Object?> page) => closeSector(),
/// )
/// ```
///
/// Replacing a page with one of the same type and [key] updates the route in
/// place: the new [child] is shown and the state below it is kept.
class KkPage<T> extends Page<T> {
  const KkPage({
    required this.child,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.wipe = true,
    super.key,
    super.canPop,
    super.onPopInvoked,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The content of the page.
  final Widget child;

  /// Whether the page stays alive while another page covers it.
  final bool maintainState;

  /// Whether the page is a full-screen dialog rather than a step deeper.
  final bool fullscreenDialog;

  /// Whether to play the wipe at all.
  final bool wipe;

  @override
  Route<T> createRoute(BuildContext context) => _KkPageBasedRoute<T>(page: this);
}

/// The route of a [KkPage]. It reads everything from the page it holds at
/// the moment, which the navigator swaps when the page is updated.
class _KkPageBasedRoute<T> extends KkPageRoute<T> {
  _KkPageBasedRoute({required KkPage<T> page}) : super(settings: page, builder: _fromPage);

  // Never called: [builder] is overridden to read the current page.
  static Widget _fromPage(BuildContext context) => const SizedBox.shrink();

  KkPage<T> get _page => settings as KkPage<T>;

  @override
  WidgetBuilder get builder =>
      (BuildContext context) => _page.child;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get wipe => _page.wipe;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
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
