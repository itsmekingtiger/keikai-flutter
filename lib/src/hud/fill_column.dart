import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class _FillColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// A column that adapts to its height constraint.
///
/// When the height is fixed (a grid cell, a stretched row) the [body] takes
/// what the [leading] and [trailing] children leave. When it is not, every
/// child keeps its natural height and the column is as tall as their sum.
/// Children are always as wide as the column.
///
/// Where the width is not limited (in a row, a horizontal scroller) the
/// column is as wide as its widest child. The body is measured for that at
/// the height it is given, so a body whose width follows from its height
/// works in a column of fixed height.
///
/// HUD instruments are built on this so the same panel can fill a grid cell
/// or sit in a scrolling page without a flag.
class KkFillColumn extends MultiChildRenderObjectWidget {
  KkFillColumn({
    super.key,
    List<Widget> leading = const <Widget>[],
    Widget? body,
    List<Widget> trailing = const <Widget>[],
  }) : bodyIndex = body == null ? -1 : leading.length,
       super(children: <Widget>[...leading, ?body, ...trailing]);

  /// Position of the body among the children, or -1 when there is none.
  final int bodyIndex;

  @override
  RenderKkFillColumn createRenderObject(BuildContext context) => RenderKkFillColumn(bodyIndex: bodyIndex);

  @override
  void updateRenderObject(BuildContext context, RenderKkFillColumn renderObject) {
    renderObject.bodyIndex = bodyIndex;
  }
}

/// The render object behind [KkFillColumn].
class RenderKkFillColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FillColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FillColumnParentData> {
  RenderKkFillColumn({int bodyIndex = -1}) : _bodyIndex = bodyIndex;

  int _bodyIndex;
  int get bodyIndex => _bodyIndex;
  set bodyIndex(int value) {
    if (value == _bodyIndex) return;
    _bodyIndex = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillColumnParentData) child.parentData = _FillColumnParentData();
  }

  /// The width of the widest child when the column has [height]. As in the
  /// layout, the body is asked at the height the others leave it.
  double _maxWidth(double height, double Function(RenderBox child, double height) of) {
    double w = 0;
    double taken = 0;
    RenderBox? body;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      if (i == _bodyIndex) {
        body = child;
        continue;
      }
      w = math.max(w, of(child, double.infinity));
      if (height.isFinite) taken += child.getMaxIntrinsicHeight(double.infinity);
    }
    if (body != null) w = math.max(w, of(body, math.max(0.0, height - taken)));
    return w;
  }

  double _sumHeight(double Function(RenderBox child) of) {
    double h = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      h += of(child);
    }
    return h;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _maxWidth(height, (RenderBox c, double h) => c.getMinIntrinsicWidth(h));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _maxWidth(height, (RenderBox c, double h) => c.getMaxIntrinsicWidth(h));

  @override
  double computeMinIntrinsicHeight(double width) => _sumHeight((RenderBox c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _sumHeight((RenderBox c) => c.getMaxIntrinsicHeight(width));

  /// What the body is given when the other children take [used] of the
  /// height: all that is left when the height is fixed, no more than that
  /// when it is not. Without a [width] the width is left free, to measure it.
  BoxConstraints _forBody(BoxConstraints constraints, double used, {double? width}) {
    final double left = constraints.maxHeight.isFinite ? math.max(0.0, constraints.maxHeight - used) : double.infinity;
    return BoxConstraints(
      minWidth: width ?? 0,
      maxWidth: width ?? double.infinity,
      minHeight: constraints.hasTightHeight ? left : 0,
      maxHeight: left,
    );
  }

  ({Size size, List<Size> sizes, List<BoxConstraints> given}) _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final int count = childCount;
    final List<Size> sizes = List<Size>.filled(count, Size.zero);
    double width;
    if (constraints.hasBoundedWidth) {
      width = constraints.maxWidth;
    } else {
      // No width to fill: the column is as wide as its widest child. The body
      // is measured last, at the height the others leave it: its width may
      // follow from that height, and it may have no size at all without one.
      width = constraints.minWidth;
      double taken = 0;
      RenderBox? body;
      int i = 0;
      for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
        if (i == _bodyIndex) {
          body = child;
          continue;
        }
        final Size natural = layoutChild(child, const BoxConstraints());
        width = math.max(width, natural.width);
        taken += natural.height;
      }
      if (body != null) width = math.max(width, layoutChild(body, _forBody(constraints, taken)).width);
    }
    final BoxConstraints row = BoxConstraints(minWidth: width, maxWidth: width);
    final List<BoxConstraints> given = List<BoxConstraints>.filled(count, row);
    double used = 0;
    RenderBox? body;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      if (i == _bodyIndex) {
        body = child;
        continue;
      }
      sizes[i] = layoutChild(child, row);
      used += sizes[i].height;
    }
    if (body != null) {
      final BoxConstraints bc = _forBody(constraints, used, width: width);
      given[_bodyIndex] = bc;
      sizes[_bodyIndex] = layoutChild(body, bc);
      used += sizes[_bodyIndex].height;
    }
    return (size: constraints.constrain(Size(width, used)), sizes: sizes, given: given);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    size = _compute(constraints, ChildLayoutHelper.layoutChild).size;
    double y = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as _FillColumnParentData).offset = Offset(0, y);
      y += child.size.height;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  /// The baseline of the first child that has one, as [performLayout] would
  /// place it.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final ({Size size, List<Size> sizes, List<BoxConstraints> given}) r = _compute(
      constraints,
      ChildLayoutHelper.dryLayoutChild,
    );
    double y = 0;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final double? d = child.getDryBaseline(r.given[i], baseline);
      if (d != null) return d + y;
      y += r.sizes[i].height;
    }
    return null;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
