import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Parent data of a child of [KkLayers].
class KkLayerParentData extends ContainerBoxParentData<RenderBox> {
  double? left;
  double? top;
  double? right;
  double? bottom;
  double? width;
  double? height;

  /// Alignment of a child that is not positioned; overrides the stack's.
  Alignment? alignment;

  bool get isPositioned =>
      left != null || top != null || right != null || bottom != null || width != null || height != null;
}

/// Children drawn on top of each other, first child at the back.
///
/// Children that are not wrapped in [KkPositioned] size the stack and are
/// placed by [alignment]. Positioned children are pinned to the stack's edges.
class KkLayers extends MultiChildRenderObjectWidget {
  const KkLayers({
    super.key,
    this.alignment = Alignment.topLeft,
    this.expand = false,
    this.clip = Clip.none,
    super.children,
  });

  final Alignment alignment;

  /// Force children that are not positioned to fill the incoming constraints.
  final bool expand;
  final Clip clip;

  @override
  RenderKkLayers createRenderObject(BuildContext context) =>
      RenderKkLayers(alignment: alignment, expand: expand, clip: clip);

  @override
  void updateRenderObject(BuildContext context, RenderKkLayers renderObject) {
    renderObject
      ..alignment = alignment
      ..expand = expand
      ..clip = clip;
  }
}

/// Pins a child of [KkLayers] to the stack's edges.
class KkPositioned extends ParentDataWidget<KkLayerParentData> {
  const KkPositioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required super.child,
  }) : assert(left == null || right == null || width == null),
       assert(top == null || bottom == null || height == null);

  /// Fills the stack, inset by the given amounts.
  const KkPositioned.fill({
    super.key,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    required super.child,
  }) : width = null,
       height = null;

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkLayerParentData pd = renderObject.parentData! as KkLayerParentData;
    bool dirty = false;
    if (pd.left != left) {
      pd.left = left;
      dirty = true;
    }
    if (pd.top != top) {
      pd.top = top;
      dirty = true;
    }
    if (pd.right != right) {
      pd.right = right;
      dirty = true;
    }
    if (pd.bottom != bottom) {
      pd.bottom = bottom;
      dirty = true;
    }
    if (pd.width != width) {
      pd.width = width;
      dirty = true;
    }
    if (pd.height != height) {
      pd.height = height;
      dirty = true;
    }
    if (pd.alignment != null) {
      pd.alignment = null;
      dirty = true;
    }
    if (dirty) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => KkLayers;
}

/// Places one child of [KkLayers] by its own alignment.
class KkLayerAlign extends ParentDataWidget<KkLayerParentData> {
  const KkLayerAlign({super.key, required this.alignment, required super.child});

  final Alignment alignment;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkLayerParentData pd = renderObject.parentData! as KkLayerParentData;
    bool dirty = false;
    if (pd.isPositioned) {
      pd
        ..left = null
        ..top = null
        ..right = null
        ..bottom = null
        ..width = null
        ..height = null;
      dirty = true;
    }
    if (pd.alignment != alignment) {
      pd.alignment = alignment;
      dirty = true;
    }
    if (dirty) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => KkLayers;
}

/// The render object behind [KkLayers].
class RenderKkLayers extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkLayerParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkLayerParentData> {
  RenderKkLayers({Alignment alignment = Alignment.topLeft, bool expand = false, Clip clip = Clip.none})
    : _alignment = alignment,
      _expand = expand,
      _clip = clip;

  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  bool _expand;
  bool get expand => _expand;
  set expand(bool value) {
    if (value == _expand) return;
    _expand = value;
    markNeedsLayout();
  }

  Clip _clip;
  Clip get clip => _clip;
  set clip(Clip value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkLayerParentData) child.parentData = KkLayerParentData();
  }

  double _intrinsic(double Function(RenderBox child) of) {
    double extent = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if (!(child.parentData! as KkLayerParentData).isPositioned) extent = math.max(extent, of(child));
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic((RenderBox c) => c.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic((RenderBox c) => c.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic((RenderBox c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic((RenderBox c) => c.getMaxIntrinsicHeight(width));

  /// What a child that is not positioned is given.
  BoxConstraints _looseFor(BoxConstraints constraints) =>
      _expand && constraints.isSatisfiedBy(constraints.biggest) && constraints.biggest.isFinite
      ? BoxConstraints.tight(constraints.biggest)
      : constraints.loosen();

  Size _computeSize(BoxConstraints constraints, ChildLayouter layoutChild) {
    final BoxConstraints loose = _looseFor(constraints);
    bool any = false;
    double width = constraints.minWidth;
    double height = constraints.minHeight;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if ((child.parentData! as KkLayerParentData).isPositioned) continue;
      any = true;
      final Size s = layoutChild(child, loose);
      width = math.max(width, s.width);
      height = math.max(height, s.height);
    }
    if (any) return constraints.constrain(Size(width, height));
    return constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
  }

  /// What a positioned child is given in a stack of [size].
  static BoxConstraints _positionedConstraints(KkLayerParentData pd, Size size) {
    BoxConstraints c = const BoxConstraints();
    if (pd.left != null && pd.right != null) {
      c = c.tighten(width: math.max(0, size.width - pd.left! - pd.right!));
    } else if (pd.width != null) {
      c = c.tighten(width: pd.width);
    }
    if (pd.top != null && pd.bottom != null) {
      c = c.tighten(height: math.max(0, size.height - pd.top! - pd.bottom!));
    } else if (pd.height != null) {
      c = c.tighten(height: pd.height);
    }
    return c;
  }

  /// Where a child of [childSize] goes in a stack of [size].
  Offset _offsetFor(KkLayerParentData pd, Size size, Size childSize) {
    final Offset free = size - childSize as Offset;
    if (!pd.isPositioned) return (pd.alignment ?? _alignment).alongOffset(free);
    final Offset aligned = _alignment.alongOffset(free);
    return Offset(
      pd.left ?? (pd.right != null ? size.width - pd.right! - childSize.width : aligned.dx),
      pd.top ?? (pd.bottom != null ? size.height - pd.bottom! - childSize.height : aligned.dy),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _computeSize(constraints, ChildLayoutHelper.dryLayoutChild);

  /// The highest baseline of any layer.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final Size size = _computeSize(constraints, ChildLayoutHelper.dryLayoutChild);
    final BoxConstraints loose = _looseFor(constraints);
    double? result;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final KkLayerParentData pd = child.parentData! as KkLayerParentData;
      final BoxConstraints c = pd.isPositioned ? _positionedConstraints(pd, size) : loose;
      final double? d = child.getDryBaseline(c, baseline);
      if (d == null) continue;
      final double v = d + _offsetFor(pd, size, child.getDryLayout(c)).dy;
      result = result == null ? v : math.min(result, v);
    }
    return result;
  }

  @override
  void performLayout() {
    size = _computeSize(constraints, ChildLayoutHelper.layoutChild);
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final KkLayerParentData pd = child.parentData! as KkLayerParentData;
      if (pd.isPositioned) child.layout(_positionedConstraints(pd, size), parentUsesSize: true);
      pd.offset = _offsetFor(pd, size, child.size);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_clip == Clip.none) {
      _clipLayer.layer = null;
      defaultPaint(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      clipBehavior: _clip,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clip == Clip.none ? null : Offset.zero & size;
}
