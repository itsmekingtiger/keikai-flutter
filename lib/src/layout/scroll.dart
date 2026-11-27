import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
      if (identical(position.context.storageContext, context)) return KkScrollbar._of(position, child: child);
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
///
/// A fling or a drag that a layout stops is over on the next frame, not
/// inside that layout: see [createBallisticSimulation].
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

  /// Keeps a scroll that a layout stops from ending inside that layout.
  ///
  /// The correction above can put a fling on the very end it was running
  /// into, and rows that all fit take the view from under a finger. Clamping
  /// physics have no simulation for either, and without one the framework
  /// ends the scroll on the spot: its listeners hear of the end while the
  /// frame is being laid out, where one that rebuilds (`setState` on a
  /// `ScrollEndNotification`) is an error. Here the view gets a simulation
  /// that stands still and is over at once, and the scroll ends on the next
  /// tick like any other.
  ///
  /// Physics that a view is given and that make their own simulations
  /// (`ClampingScrollPhysics`, `BouncingScrollPhysics`) do not ask these: such
  /// a view ends the scroll the framework's way.
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Simulation? simulation = super.createBallisticSimulation(position, velocity);
    if (simulation != null) return simulation;
    final bool scrolling = position is ScrollPosition && position.isScrollingNotifier.value;
    final bool inFrame = SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;
    return scrolling && inFrame ? _KkRestSimulation(position.pixels) : null;
  }
}

/// A view that stands still at [position], for a scroll that is to end on the
/// next tick.
class _KkRestSimulation extends Simulation {
  _KkRestSimulation(this.position);

  final double position;

  @override
  double x(double time) => position;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}

/// A thin, square scrollbar thumb in the line colour on a clear track
/// (`scrollbar-width: thin; scrollbar-color: line transparent`). It shows
/// while the view scrolls and goes 0.9s after it stops, without a fade.
///
/// The bar is there for a mouse to take: a mouse that comes near it brings
/// the thumb out, drags it, and pages the view with a click on the track. To
/// a finger or a pen it is an indicator, on every platform: a touch on or
/// beside the bar goes to the content under it.
class KkScrollbar extends StatelessWidget {
  const KkScrollbar({super.key, this.controller, this.thickness = 6, this.alwaysVisible = false, required this.child})
    : _position = null;

  /// The bar that [KkScrollBehavior] gives the scroll view with [position].
  const KkScrollbar._of(ScrollPosition position, {required this.child})
    : _position = position,
      controller = null,
      thickness = 6,
      alwaysVisible = false;

  /// The controller of the scroll view in [child], for an app that has one.
  ///
  /// Without it the bar finds its view by itself: it follows the scroll view
  /// in [child] that lies in no other scroll view, whatever controller that
  /// view has, on every platform. With two such views it follows the one that
  /// moved last.
  final ScrollController? controller;
  final double thickness;

  /// Keep the thumb in sight while the view is at rest. It shows once the
  /// view has been laid out.
  final bool alwaysVisible;
  final Widget child;

  /// The position the bar was built for by [KkScrollBehavior].
  final ScrollPosition? _position;

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = this.controller;
    if (controller == null) {
      return _KkOwnScrollbar(position: _position, thickness: thickness, alwaysVisible: alwaysVisible, child: child);
    }
    return _KkRawScrollbar(
      controller: controller,
      thumbColor: KeikaiTheme.of(context).colors.line,
      thickness: thickness,
      thumbVisibility: alwaysVisible,
      child: child,
    );
  }
}

/// The framework's scrollbar in the shape of a [KkScrollbar], which only a
/// mouse can take.
class _KkRawScrollbar extends RawScrollbar {
  _KkRawScrollbar({
    required ScrollController super.controller,
    required Color super.thumbColor,
    required double super.thickness,
    required bool super.thumbVisibility,
    required Widget child,
  }) : super(
         radius: Radius.zero,
         minThumbLength: 24,
         fadeDuration: Duration.zero,
         timeToFade: const Duration(milliseconds: 900),
         child: _KkPointerKinds(child: child),
       );

  @override
  RawScrollbarState<_KkRawScrollbar> createState() => _KkRawScrollbarState();
}

/// Keeps the bar from every pointer but a mouse.
///
/// The framework's bar takes any pointer. A finger gets a zone of 24px around
/// the centre line of the 6px bar, along the whole track: a finger that rests
/// there pages the view, and one that starts a swipe near the thumb drags the
/// thumb, so the content runs the other way. The gestures of the bar ask its
/// painter whether a pointer is on the bar, and the painter can be told to
/// ignore pointers. It is, unless the last pointer heard of over the view was
/// a mouse: one that moved over the view, or went down on it.
///
/// One case stays as the framework has it. While the painter takes pointers
/// and the thumb shows, the bar hides its own 6px from the content under it,
/// [_KkPointerKinds] included. A finger that lands exactly there, after a
/// mouse has moved over the view, can therefore drag the thumb. It cannot
/// page the view.
///
/// The painter also ignores pointers while the bar has no view to move. A
/// view can leave without the bar being built again, and the bar is then left
/// with the gestures it was built with, and with its thumb if that is always
/// visible.
class _KkRawScrollbarState extends RawScrollbarState<_KkRawScrollbar> {
  /// Whether the last pointer heard of over the view is a mouse.
  bool _mouse = false;

  /// Whether the controller has the one scroll view that the bar is for, and
  /// that view is in the tree.
  bool get _hasView {
    final ScrollController controller = widget.controller!;
    return controller.positions.length == 1 && controller.position.context.notificationContext != null;
  }

  /// Takes note of a pointer of [kind] that moves over the view or goes down
  /// on it.
  void _hear(PointerDeviceKind kind) => _mouseIsHere(kind == PointerDeviceKind.mouse);

  void _mouseIsHere(bool value) {
    _mouse = value;
    _tellPainter();
  }

  void _tellPainter() => scrollbarPainter.ignorePointer = !(_mouse && _hasView);

  @override
  void updateScrollbarPainter() {
    // The framework lets the painter take pointers again each time the bar is built.
    super.updateScrollbarPainter();
    _tellPainter();
  }

  /// The painter is told again each time a pointer is looked up on the bar,
  /// which is the one moment a view that has left is sure to be missed.
  @override
  Widget build(BuildContext context) => _KkBeforeHitTest(onHitTest: _tellPainter, child: super.build(context));

  /// The framework calls this for a mouse or a trackpad, not for a pen that
  /// hovers.
  @override
  void handleHover(PointerHoverEvent event) {
    _mouseIsHere(true);
    super.handleHover(event);
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    _mouseIsHere(false);
    super.handleHoverExit(event);
  }

  @override
  void handleTrackTapDown(TapDownDetails details) {
    // The finger that lands on the bar itself while a mouse lies over the view.
    if (details.kind != PointerDeviceKind.mouse) return;
    super.handleTrackTapDown(details);
  }
}

/// Tells the [KkScrollbar] around a scroll view what kind of pointer went
/// down on the view.
///
/// It sits below the gestures of the bar, and a pointer event reaches the
/// deepest widget first: the bar knows the kind before its gestures are asked
/// whether they take the pointer.
class _KkPointerKinds extends StatelessWidget {
  const _KkPointerKinds({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) =>
          context.findAncestorStateOfType<_KkRawScrollbarState>()?._hear(event.kind),
      child: child,
    );
  }
}

/// Calls [onHitTest] each time a pointer is looked up on it, before anything
/// under it is asked whether the pointer is on it.
class _KkBeforeHitTest extends SingleChildRenderObjectWidget {
  const _KkBeforeHitTest({required this.onHitTest, super.child});

  final VoidCallback onHitTest;

  @override
  _RenderKkBeforeHitTest createRenderObject(BuildContext context) => _RenderKkBeforeHitTest(onHitTest);

  @override
  void updateRenderObject(BuildContext context, _RenderKkBeforeHitTest renderObject) {
    renderObject.onHitTest = onHitTest;
  }
}

class _RenderKkBeforeHitTest extends RenderProxyBox {
  _RenderKkBeforeHitTest(this.onHitTest);

  VoidCallback onHitTest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    onHitTest();
    return super.hitTest(result, position: position);
  }
}

/// A [KkScrollbar] that holds one scroll position on a controller of its
/// own.
///
/// For the bar that [KkScrollBehavior] gives a scroll view, that is the
/// [position] of the view: the thumb shows and a mouse can drag it whatever
/// else is attached to the controller of the view. A bar that an app puts
/// around something without a controller has no position to begin with. It
/// takes the one of the scroll view in [child] that tells of itself, by
/// being laid out or by scrolling, and that lies in no other scroll view.
class _KkOwnScrollbar extends StatefulWidget {
  const _KkOwnScrollbar({
    required this.position,
    required this.thickness,
    required this.alwaysVisible,
    required this.child,
  });

  /// The position to hold. Null for a bar that finds it in [child].
  final ScrollPosition? position;
  final double thickness;
  final bool alwaysVisible;
  final Widget child;

  @override
  State<_KkOwnScrollbar> createState() => _KkOwnScrollbarState();
}

class _KkOwnScrollbarState extends State<_KkOwnScrollbar> {
  final ScrollController _controller = ScrollController(debugLabel: 'KkScrollbar');

  /// The position that [_controller] holds.
  ScrollPosition? _position;

  void _follow(ScrollPosition? position) {
    if (identical(position, _position)) return;
    final ScrollPosition? before = _position;
    if (before != null) _controller.detach(before);
    if (position != null) _controller.attach(position);
    _position = position;
  }

  /// Follows the scroll view that sent a notification from [context], through
  /// [depth] other scroll views.
  bool _found(int depth, BuildContext? context) {
    if (depth == 0 && context != null) {
      final ScrollPosition? position = context.findAncestorStateOfType<ScrollableState>()?.position;
      if (position != null) {
        final bool first = _position == null;
        _follow(position);
        if (first) _buildAgain();
      }
    }
    return false;
  }

  /// Lets go of a view that was found and has left the tree since.
  void _letGo(Duration _) {
    final ScrollPosition? position = _position;
    if (!mounted || widget.position != null || position == null) return;
    if (position.context.notificationContext == null) {
      _follow(null);
      _buildAgain();
    }
  }

  /// Builds the bar again, which has just got a view or lost it: the
  /// framework gives a bar its gestures, and its thumb if that is always
  /// visible, when it is built with a view to its name.
  void _buildAgain() {
    // A view can tell of a scroll that starts while the frame is laid out, where nothing may ask to be built.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _follow(widget.position);
  }

  @override
  void didUpdateWidget(_KkOwnScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != null) {
      // A scroll view makes a new position when its physics or the pixel ratio change.
      _follow(widget.position);
    } else if (_position != null) {
      // The view that was found may be going with the child that was here. It is gone when this frame is over.
      WidgetsBinding.instance.addPostFrameCallback(_letGo);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KkRawScrollbar(
      controller: _controller,
      thumbColor: KeikaiTheme.of(context).colors.line,
      thickness: widget.thickness,
      // The framework wants a bar with such a thumb to have its view from the first frame it is built in.
      thumbVisibility: widget.alwaysVisible && _position != null,
      // Under the bar, so that the bar has its view before it deals with what the view tells.
      child: widget.position != null
          ? widget.child
          : NotificationListener<ScrollMetricsNotification>(
              onNotification: (ScrollMetricsNotification notification) =>
                  _found(notification.depth, notification.context),
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) => _found(notification.depth, notification.context),
                child: widget.child,
              ),
            ),
    );
  }
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
