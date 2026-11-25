import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.dart';

/// Ordering helpers for [KkWindowClass]: compact < medium < expanded < large <
/// xlarge < wall.
extension KkWindowClassOrder on KkWindowClass {
  /// This class is [other] or wider.
  bool isAtLeast(KkWindowClass other) => index >= other.index;

  /// This class is [other] or narrower.
  bool isAtMost(KkWindowClass other) => index <= other.index;

  /// This class is narrower than [other].
  bool isBelow(KkWindowClass other) => index < other.index;

  /// This class is wider than [other].
  bool isAbove(KkWindowClass other) => index > other.index;

  /// Same as [isAtLeast].
  bool operator >=(KkWindowClass other) => index >= other.index;

  /// Same as [isAbove].
  bool operator >(KkWindowClass other) => index > other.index;

  /// Same as [isAtMost].
  bool operator <=(KkWindowClass other) => index <= other.index;

  /// Same as [isBelow].
  bool operator <(KkWindowClass other) => index < other.index;
}

/// Tells the subtree which window class it is being laid out for.
///
/// [KkScreen] and [KkBreakpoint] insert one from their own width, so a panel
/// inside a narrow pane reads the pane's class, not the window's.
class KkWindowScope extends InheritedWidget {
  const KkWindowScope({super.key, required this.windowClass, required super.child});

  final KkWindowClass windowClass;

  /// The class of the nearest scope; without one, the class of the window's
  /// width (and [KkWindowClass.expanded] when there is no window either).
  static KkWindowClass of(BuildContext context) {
    final KkWindowScope? scope = context.dependOnInheritedWidgetOfExactType<KkWindowScope>();
    if (scope != null) return scope.windowClass;
    final double? width = MediaQuery.maybeSizeOf(context)?.width;
    if (width == null) return KkWindowClass.expanded;
    return KeikaiTheme.of(context).metrics.windowClass(width);
  }

  /// The class of the nearest scope, or null when there is none.
  static KkWindowClass? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KkWindowScope>()?.windowClass;

  @override
  bool updateShouldNotify(KkWindowScope oldWidget) => oldWidget.windowClass != windowClass;
}

/// Builds a widget from a window class and the incoming constraints.
typedef KkBreakpointBuilder =
    Widget Function(BuildContext context, KkWindowClass windowClass, BoxConstraints constraints);

/// Builds its child from the window class of its **own width**, so the same
/// layout works full screen and inside a narrow pane.
///
/// The thresholds are the theme's breakpoints: medium 600, expanded 840,
/// large 1200, xlarge 1600, wall 2560.
class KkBreakpoint extends StatelessWidget {
  const KkBreakpoint({super.key, required this.builder});

  final KkBreakpointBuilder builder;

  @override
  Widget build(BuildContext context) {
    final KkMetrics metrics = KeikaiTheme.of(context).metrics;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (MediaQuery.maybeSizeOf(context)?.width ?? metrics.bpExpanded);
        final KkWindowClass windowClass = metrics.windowClass(width);
        return KkWindowScope(
          windowClass: windowClass,
          child: Builder(builder: (BuildContext context) => builder(context, windowClass, constraints)),
        );
      },
    );
  }
}

/// A value that changes with the window class.
///
/// Only [compact] is required. A class without its own value takes the value
/// of the nearest smaller class that has one:
///
/// ```dart
/// const KkResponsive<int> span = KkResponsive<int>(compact: 4, expanded: 6, xlarge: 4);
/// span.resolve(KkWindowClass.large); // 6
/// ```
@immutable
class KkResponsive<T extends Object> {
  const KkResponsive({required this.compact, this.medium, this.expanded, this.large, this.xlarge, this.wall});

  /// The same [value] at every class.
  const KkResponsive.all(T value) : compact = value, medium = null, expanded = null, large = null, xlarge = null, wall = null;

  final T compact;
  final T? medium;
  final T? expanded;
  final T? large;
  final T? xlarge;
  final T? wall;

  T? _own(KkWindowClass c) => switch (c) {
    KkWindowClass.compact => compact,
    KkWindowClass.medium => medium,
    KkWindowClass.expanded => expanded,
    KkWindowClass.large => large,
    KkWindowClass.xlarge => xlarge,
    KkWindowClass.wall => wall,
  };

  /// The value for [windowClass].
  T resolve(KkWindowClass windowClass) {
    for (int i = windowClass.index; i > 0; i--) {
      final T? v = _own(KkWindowClass.values[i]);
      if (v != null) return v;
    }
    return compact;
  }

  /// The value for the window class [context] is laid out in.
  T of(BuildContext context) => resolve(KkWindowScope.of(context));

  @override
  bool operator ==(Object other) =>
      other is KkResponsive<T> &&
      other.compact == compact &&
      other.medium == medium &&
      other.expanded == expanded &&
      other.large == large &&
      other.xlarge == xlarge &&
      other.wall == wall;

  @override
  int get hashCode => Object.hash(compact, medium, expanded, large, xlarge, wall);
}
