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

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (!showScrollbars || details.controller == null) return child;
    return KkScrollbar(controller: details.controller, child: child);
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

/// A thin, square scrollbar thumb in the line colour that turns signal while
/// dragged or hovered.
class KkScrollbar extends StatelessWidget {
  const KkScrollbar({super.key, this.controller, this.thickness = 6, this.alwaysVisible = false, required this.child});

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
  final ScrollController? controller;
  final bool reverse;
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
      primary: primary,
      physics: physics,
      child: child,
    );
  }
}
