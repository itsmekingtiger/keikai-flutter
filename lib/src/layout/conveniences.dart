import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'box.dart';
import 'flex.dart';

/// Centres its child in the space it is given.
class KkCenter extends StatelessWidget {
  const KkCenter({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => KkBox(alignment: Alignment.center, child: child);
}

/// Places its child by [alignment] in the space it is given.
class KkAlign extends StatelessWidget {
  const KkAlign({super.key, required this.alignment, this.child});

  final Alignment alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) => KkBox(alignment: alignment, child: child);
}

/// Insets its child by [padding].
class KkPadding extends StatelessWidget {
  const KkPadding({super.key, required this.padding, this.child});

  final EdgeInsets padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) => KkBox(padding: padding, child: child);
}

/// Forces a width, a height, or both. A null dimension is left to the child.
class KkSized extends StatelessWidget {
  const KkSized({super.key, this.width, this.height, this.child});

  /// A square of [dimension].
  const KkSized.square(double dimension, {super.key, this.child}) : width = dimension, height = dimension;

  /// As large as the parent allows in both directions.
  const KkSized.expand({super.key, this.child}) : width = double.infinity, height = double.infinity;

  final double? width;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) => KkBox(width: width, height: height, child: child);
}

/// Sizes its child to a width : height [ratio], as large as the constraints
/// allow.
class KkAspect extends SingleChildRenderObjectWidget {
  const KkAspect({super.key, required this.ratio, super.child}) : assert(ratio > 0);

  /// Width divided by height (16 / 9, 1, …).
  final double ratio;

  @override
  RenderKkAspect createRenderObject(BuildContext context) => RenderKkAspect(ratio: ratio);

  @override
  void updateRenderObject(BuildContext context, RenderKkAspect renderObject) => renderObject.ratio = ratio;
}

/// The render object behind [KkAspect].
class RenderKkAspect extends RenderProxyBox {
  RenderKkAspect({required double ratio, RenderBox? child}) : _ratio = ratio, super(child);

  double _ratio;
  double get ratio => _ratio;
  set ratio(double value) {
    if (value == _ratio) return;
    _ratio = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? height * _ratio : (child?.getMinIntrinsicWidth(height) ?? 0);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite ? height * _ratio : (child?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite ? width / _ratio : (child?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      width.isFinite ? width / _ratio : (child?.getMaxIntrinsicHeight(width) ?? 0);

  /// The size for [constraints], or null when neither dimension is bounded
  /// (then the child decides).
  Size? _apply(BoxConstraints constraints) {
    if (constraints.isTight) return constraints.smallest;
    double width = constraints.maxWidth;
    double height;
    if (width.isFinite) {
      height = width / _ratio;
    } else {
      height = constraints.maxHeight;
      if (!height.isFinite) return null;
      width = height * _ratio;
    }
    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / _ratio;
    }
    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * _ratio;
    }
    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / _ratio;
    }
    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * _ratio;
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final Size? s = _apply(constraints);
    if (s != null) return s;
    final Size natural = child?.getDryLayout(constraints) ?? Size.zero;
    return constraints.constrain(_fromChild(natural));
  }

  Size _fromChild(Size natural) {
    final double width = math.max(natural.width, natural.height * _ratio);
    return Size(width, width / _ratio);
  }

  /// The child's baseline at the size the ratio gives it.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child?.getDryBaseline(BoxConstraints.tight(getDryLayout(constraints)), baseline);

  @override
  void performLayout() {
    final RenderBox? c = child;
    final Size? s = _apply(constraints);
    if (s != null) {
      size = s;
      c?.layout(BoxConstraints.tight(size));
      return;
    }
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_fromChild(c.size));
    if (c.size != size) c.layout(BoxConstraints.tight(size));
  }
}

/// A scrolling list that builds its rows only as they come into view, with a
/// fixed [gap] between them.
///
/// Use it for long lists (logs, tables of rows, search results). For a handful
/// of rows a [KkColumn] inside a `KkScroll` is simpler.
class KkListView extends StatelessWidget {
  const KkListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 0,
    this.padding = EdgeInsets.zero,
    this.axis = Axis.vertical,
    this.controller,
    this.reverse = false,
    this.shrinkWrap = false,
    this.primary,
    this.physics,
  }) : assert(itemCount >= 0),
       assert(gap >= 0);

  final int itemCount;

  /// Builds row [index]. Called only for rows near the visible range.
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Space between rows.
  final double gap;
  final EdgeInsets padding;
  final Axis axis;

  /// Reads and moves the scroll offset from outside.
  ///
  /// The list is never left past its rows. When rows go and the list is
  /// shorter than where the view is, the offset is at the new end within that
  /// frame, and an animation that is on its way (`animateTo`) ends there
  /// instead of at its target. To send the list somewhere in the frame its
  /// rows change, use `jumpTo`, or start the animation after that frame.
  final ScrollController? controller;
  final bool reverse;

  /// Take only the height of the rows instead of all that is available.
  /// This builds every row; keep it for short lists.
  final bool shrinkWrap;
  final bool? primary;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (gap <= 0) {
      return ListView.builder(
        scrollDirection: axis,
        padding: padding,
        controller: controller,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        primary: primary ?? false,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }
    return ListView.separated(
      scrollDirection: axis,
      padding: padding,
      controller: controller,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      primary: primary ?? false,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      separatorBuilder: (BuildContext context, int index) => KkGap(gap),
    );
  }
}

/// Keeps its child clear of system intrusions: the status bar, a notch, the
/// home indicator and (with [keyboard]) the on-screen keyboard.
///
/// [KkScreen] already does this; use it for pages built without one.
class KkSafeArea extends StatelessWidget {
  const KkSafeArea({
    super.key,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.keyboard = true,
    this.fill,
    required this.child,
  });

  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  /// Also stay above the on-screen keyboard.
  final bool keyboard;

  /// Colour painted under the intrusions. Null leaves them clear.
  final Color? fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    if (mq == null) return child;
    final EdgeInsets inset = EdgeInsets.fromLTRB(
      left ? mq.padding.left : 0,
      top ? mq.padding.top : 0,
      right ? mq.padding.right : 0,
      bottom ? math.max(mq.padding.bottom, keyboard ? mq.viewInsets.bottom : 0) : 0,
    );
    // The child sees no intrusion on the sides this widget has dealt with.
    MediaQueryData inner = mq.removePadding(removeLeft: left, removeTop: top, removeRight: right, removeBottom: bottom);
    if (bottom && keyboard) inner = inner.removeViewInsets(removeBottom: true);
    return KkBox(
      padding: inset,
      fill: fill,
      child: MediaQuery(data: inner, child: child),
    );
  }
}
