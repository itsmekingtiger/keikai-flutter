import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';

/// Scrolling the KEIKAI way: no bounce, no glow, and a thin square scrollbar
/// in the line colour.
class KkScrollBehavior extends ScrollBehavior {
  const KkScrollBehavior({this.showScrollbars = true});

  /// Whether scroll views get a scrollbar automatically.
  final bool showScrollbars;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  /// Clamping physics that also put the offset back inside the content, at
  /// once, when the content or the view changes size. A scroll animation that
  /// is past the new end at that moment stops there: see
  /// [KkScroll.controller].
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const _KkScrollPhysics();

  /// Gives a scroll view its scrollbar, on every platform.
  ///
  /// The bar follows the scroll position of that one view. The view's
  /// controller may hold more positions (two views that share a controller, or
  /// that both follow the route's `PrimaryScrollController`), and a scrollbar
  /// that is handed such a controller throws the moment it shows.
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final ScrollController? controller = details.controller;
    if (!showScrollbars || controller == null) return child;
    // Each position names the context of its scroll view; [context] is that of the view being built.
    for (final ScrollPosition position in controller.positions) {
      if (identical(position.context.storageContext, context)) return _KkOwnScrollbar(position: position, child: child);
    }
    return KkScrollbar(controller: controller, child: child);
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  @override
  bool shouldNotify(KkScrollBehavior oldDelegate) => oldDelegate.showScrollbars != showScrollbars;
}

/// The scroll physics of [KkScrollBehavior]: no bounce, and no gliding back
/// after the content or the view changed size.
///
/// Such a change can leave a view scrolled past its content: rows were
/// removed, the view got taller, or a jump to the end of a lazily built list
/// found the list shorter than it had guessed. Plain clamping physics show
/// that for a frame and then bring the offset back on a spring, or leave it
/// there for as long as a finger is down. Here the offset is back in range
/// within the layout that found it out of range, the way a `KkScroll` has
/// always corrected itself.
///
/// The correction wins over an animation in flight (`animateTo`,
/// `ensureVisible` with a duration, the paging keys). The framework's
/// animation is not told that the offset moved: on its next tick it asks for
/// an offset past the new end, is refused and stops, so the view rests at
/// the new end and the future of `animateTo` completes there. Physics cannot
/// carry the animation on. They are not told whether an animation, a fling
/// or a finger moves the view (a stepped curve between two steps reports no
/// velocity, like a finger at rest), and to leave the offset alone would
/// show the space past the last row until the animation is back inside. A
/// `KkScroll` ends such an animation whatever its physics, because its
/// viewport corrects the offset itself.
class _KkScrollPhysics extends ClampingScrollPhysics {
  const _KkScrollPhysics({super.parent});

  @override
  _KkScrollPhysics applyTo(ScrollPhysics? ancestor) => _KkScrollPhysics(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final double pixels = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    return pixels.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent);
  }
}

/// A thin, square scrollbar thumb in the line colour on a clear track
/// (`scrollbar-width: thin; scrollbar-color: line transparent`). It shows
/// while the view scrolls and goes 0.9s after it stops, without a fade.
class KkScrollbar extends StatelessWidget {
  const KkScrollbar({super.key, this.controller, this.thickness = 6, this.alwaysVisible = false, required this.child});

  /// The controller of the scroll view in [child]. When null the bar uses the
  /// controller of the route, which a [KkScroll] follows only with
  /// `primary: true`.
  final ScrollController? controller;
  final double thickness;
  final bool alwaysVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    return RawScrollbar(
      controller: controller,
      thumbColor: c.line,
      thickness: thickness,
      radius: Radius.zero,
      thumbVisibility: alwaysVisible,
      minThumbLength: 24,
      fadeDuration: Duration.zero,
      timeToFade: const Duration(milliseconds: 900),
      child: child,
    );
  }
}

/// The automatic scrollbar of one scroll view: a [KkScrollbar] that follows
/// the view's own [position].
///
/// It holds that one position on a controller of its own, so the thumb shows
/// and can be dragged whatever else is attached to the controller of the view.
class _KkOwnScrollbar extends StatefulWidget {
  const _KkOwnScrollbar({required this.position, required this.child});

  final ScrollPosition position;
  final Widget child;

  @override
  State<_KkOwnScrollbar> createState() => _KkOwnScrollbarState();
}

class _KkOwnScrollbarState extends State<_KkOwnScrollbar> {
  final ScrollController _controller = ScrollController(debugLabel: 'KkScrollbar');

  @override
  void initState() {
    super.initState();
    _controller.attach(widget.position);
  }

  @override
  void didUpdateWidget(_KkOwnScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A scroll view makes a new position when its physics or the pixel ratio change.
    if (identical(oldWidget.position, widget.position)) return;
    _controller
      ..detach(oldWidget.position)
      ..attach(widget.position);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KkScrollbar(controller: _controller, child: widget.child);
}

/// A scrollable region for one child. Scrolls vertically unless [axis] says
/// otherwise; [padding] scrolls with the content.
class KkScroll extends StatelessWidget {
  const KkScroll({
    super.key,
    this.axis = Axis.vertical,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.reverse = false,
    this.primary,
    this.physics,
    required this.child,
  });

  final Axis axis;
  final EdgeInsets padding;

  /// Reads and moves the scroll offset from outside.
  ///
  /// The view is never left past its content. When the content gets shorter
  /// than where the view is, the offset is at the new end within that frame,
  /// and an animation that is on its way (`animateTo`) ends there instead of
  /// at its target: its future completes, and the view stays at the new end.
  /// To send a view somewhere in the frame its content changes, use `jumpTo`,
  /// or start the animation after that frame. A `KkListView`, and any other
  /// scroll view under a [KkScrollBehavior], does the same.
  final ScrollController? controller;
  final bool reverse;

  /// Whether this view follows the controller of the route
  /// (`PrimaryScrollController`) instead of one of its own. That controller is
  /// what the page up and page down keys move while the focus is outside every
  /// scroll view.
  ///
  /// Null means false on every platform. A screen has several scroll regions
  /// (nav, body, side, the panels of a grid), and the framework's own default
  /// would hand all the vertical ones to the route's controller on Android,
  /// iOS and Fuchsia. Set it on the one view of the route that should have it;
  /// it cannot go with a [controller].
  final bool? primary;
  final ScrollPhysics? physics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: axis,
      padding: padding,
      controller: controller,
      reverse: reverse,
      primary: primary ?? false,
      physics: physics,
      child: child,
    );
  }
}
