import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flex.dart' show KkCrossAlign, KkMainAlign;

class KkWrapParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays children out in a row and starts a new row when the next child does
/// not fit: chips, tags, legends, filter bars.
class KkWrap extends MultiChildRenderObjectWidget {
  const KkWrap({
    super.key,
    this.gap = 0,
    this.runGap,
    this.main = KkMainAlign.start,
    this.cross = KkCrossAlign.center,
    super.children,
  });

  /// Space between children in a row.
  final double gap;

  /// Space between rows. Defaults to [gap].
  final double? runGap;

  /// Placement of the children inside each row.
  final KkMainAlign main;

  /// Vertical placement of a child inside its row ([KkCrossAlign.stretch] and
  /// [KkCrossAlign.baseline] behave as start).
  final KkCrossAlign cross;

  @override
  RenderKkWrap createRenderObject(BuildContext context) =>
      RenderKkWrap(gap: gap, runGap: runGap ?? gap, main: main, cross: cross);

  @override
  void updateRenderObject(BuildContext context, RenderKkWrap renderObject) {
    renderObject
      ..gap = gap
      ..runGap = runGap ?? gap
      ..main = main
      ..cross = cross;
  }
}

class _Run {
  _Run(this.start);

  final int start;
  int count = 0;
  double width = 0;
  double height = 0;
}

/// The render object behind [KkWrap].
class RenderKkWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkWrapParentData> {
  RenderKkWrap({
    double gap = 0,
    double runGap = 0,
    KkMainAlign main = KkMainAlign.start,
    KkCrossAlign cross = KkCrossAlign.center,
  }) : _gap = gap,
       _runGap = runGap,
       _main = main,
       _cross = cross;

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _runGap;
  double get runGap => _runGap;
  set runGap(double value) {
    if (value == _runGap) return;
    _runGap = value;
    markNeedsLayout();
  }

  KkMainAlign _main;
  KkMainAlign get main => _main;
  set main(KkMainAlign value) {
    if (value == _main) return;
    _main = value;
    markNeedsLayout();
  }

  KkCrossAlign _cross;
  KkCrossAlign get cross => _cross;
  set cross(KkCrossAlign value) {
    if (value == _cross) return;
    _cross = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkWrapParentData) child.parentData = KkWrapParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double w = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      w = math.max(w, child.getMinIntrinsicWidth(double.infinity));
    }
    return w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double w = 0;
    int n = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      w += child.getMaxIntrinsicWidth(double.infinity);
      n++;
    }
    return w + (n > 1 ? _gap * (n - 1) : 0);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild).size.height;

  ({Size size, List<_Run> runs, List<Size> sizes}) _layout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final double limit = constraints.maxWidth;
    final BoxConstraints childConstraints = BoxConstraints(maxWidth: limit);
    final List<_Run> runs = <_Run>[];
    final List<Size> sizes = <Size>[];
    _Run? run;
    int index = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), index++) {
      final Size s = layoutChild(child, childConstraints);
      sizes.add(s);
      if (run == null || (run.count > 0 && run.width + _gap + s.width > limit + 0.01)) {
        run = _Run(index);
        runs.add(run);
      }
      run.width += (run.count > 0 ? _gap : 0) + s.width;
      run.height = math.max(run.height, s.height);
      run.count++;
    }
    double width = 0;
    double height = 0;
    for (final _Run r in runs) {
      width = math.max(width, r.width);
      height += r.height;
    }
    if (runs.length > 1) height += _runGap * (runs.length - 1);
    return (size: constraints.constrain(Size(width, height)), runs: runs, sizes: sizes);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final ({Size size, List<_Run> runs, List<Size> sizes}) r = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = r.size;
    double y = 0;
    RenderBox? child = firstChild;
    for (final _Run run in r.runs) {
      final double free = math.max(0, size.width - run.width);
      double leading = 0;
      double between = 0;
      switch (_main) {
        case KkMainAlign.start:
          break;
        case KkMainAlign.end:
          leading = free;
        case KkMainAlign.center:
          leading = free / 2;
        case KkMainAlign.between:
          between = run.count > 1 ? free / (run.count - 1) : 0;
        case KkMainAlign.around:
          between = free / run.count;
          leading = between / 2;
        case KkMainAlign.evenly:
          between = free / (run.count + 1);
          leading = between;
      }
      double x = leading;
      for (int i = 0; i < run.count; i++) {
        final RenderBox c = child!;
        final double dy = switch (_cross) {
          KkCrossAlign.center => (run.height - c.size.height) / 2,
          KkCrossAlign.end => run.height - c.size.height,
          _ => 0,
        };
        (c.parentData! as KkWrapParentData).offset = Offset(x, y + dy);
        x += c.size.width + _gap + between;
        child = childAfter(c);
      }
      y += run.height + _runGap;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
