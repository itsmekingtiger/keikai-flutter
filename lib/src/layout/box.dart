import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';

/// KEIKAI's box: size, padding, alignment and a flat [KkDecoration] in one
/// render object.
///
/// Border widths and [padding] both take space inside the box, as in CSS
/// `box-sizing: border-box`, so a `height: 36` box with a 1px border has 34px
/// of content height.
///
/// With an [alignment] the box grows to fill bounded constraints and places
/// its child inside; without one the child fills the box. Add [shrinkWrap] to
/// an aligned box to make it hug its child instead (a tag, a badge, a key cap:
/// fixed height, content width, text centred).
class KkBox extends SingleChildRenderObjectWidget {
  const KkBox({
    super.key,
    this.width,
    this.height,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.minHeight = 0,
    this.maxHeight = double.infinity,
    this.padding = EdgeInsets.zero,
    this.alignment,
    this.shrinkWrap = false,
    this.fill,
    this.edges,
    this.decoration,
    this.clip = false,
    this.opaque,
    super.child,
  }) : assert(decoration == null || (fill == null && edges == null), 'Give either a decoration or fill/edges.');

  /// Fixed width. Overrides [minWidth] and [maxWidth].
  final double? width;

  /// Fixed height. Overrides [minHeight] and [maxHeight].
  final double? height;
  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
  final EdgeInsets padding;
  final Alignment? alignment;

  /// With an [alignment]: take only the space the child needs instead of all
  /// that is available. The alignment then places the child wherever a fixed
  /// or minimum size makes the box larger than it.
  final bool shrinkWrap;

  /// Flat background colour. Shorthand for a [decoration] with only a fill.
  final Color? fill;

  /// Rectangular border. Shorthand for a [decoration] with only edges.
  final KkEdges? edges;

  /// The full decoration. Mutually exclusive with [fill] and [edges].
  final KkDecoration? decoration;

  /// Clip the child to the box.
  final bool clip;

  /// Whether the box itself takes pointer events. Defaults to true when it has
  /// a fill.
  final bool? opaque;

  BoxConstraints get _additional => BoxConstraints(
    minWidth: width ?? minWidth,
    maxWidth: width ?? maxWidth,
    minHeight: height ?? minHeight,
    maxHeight: height ?? maxHeight,
  );

  KkDecoration? get _decoration =>
      decoration ?? ((fill != null || edges != null) ? KkDecoration(fill: fill, edges: edges ?? KkEdges.none) : null);

  @override
  RenderKkBox createRenderObject(BuildContext context) => RenderKkBox(
    additional: _additional,
    padding: padding,
    alignment: alignment,
    shrinkWrap: shrinkWrap,
    decoration: _decoration,
    clip: clip,
    opaque: opaque,
  );

  @override
  void updateRenderObject(BuildContext context, RenderKkBox renderObject) {
    renderObject
      ..additional = _additional
      ..padding = padding
      ..alignment = alignment
      ..shrinkWrap = shrinkWrap
      ..decoration = _decoration
      ..clip = clip
      ..opaque = opaque;
  }
}

/// The render object behind [KkBox].
class RenderKkBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderKkBox({
    BoxConstraints additional = const BoxConstraints(),
    EdgeInsets padding = EdgeInsets.zero,
    Alignment? alignment,
    bool shrinkWrap = false,
    KkDecoration? decoration,
    bool clip = false,
    bool? opaque,
  }) : _additional = additional,
       _padding = padding,
       _alignment = alignment,
       _shrinkWrap = shrinkWrap,
       _decoration = decoration,
       _clip = clip,
       opaque = opaque;

  BoxConstraints _additional;
  BoxConstraints get additional => _additional;
  set additional(BoxConstraints value) {
    if (value == _additional) return;
    _additional = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  EdgeInsets get padding => _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  Alignment? _alignment;
  Alignment? get alignment => _alignment;
  set alignment(Alignment? value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  bool _shrinkWrap;
  bool get shrinkWrap => _shrinkWrap;
  set shrinkWrap(bool value) {
    if (value == _shrinkWrap) return;
    _shrinkWrap = value;
    markNeedsLayout();
  }

  KkDecoration? _decoration;
  KkDecoration? get decoration => _decoration;
  set decoration(KkDecoration? value) {
    if (value == _decoration) return;
    final EdgeInsets before = _decoration?.edges.insets ?? EdgeInsets.zero;
    final EdgeInsets after = value?.edges.insets ?? EdgeInsets.zero;
    _decoration = value;
    if (before != after) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  bool _clip;
  bool get clip => _clip;
  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  /// Whether the box itself takes pointer events; null means "when filled".
  bool? opaque;

  EdgeInsets get _inset => _padding + (_decoration?.edges.insets ?? EdgeInsets.zero);

  // ── intrinsics ──────────────────────────────────────────────────────────
  //
  // The child is asked at the extent it would really get: the one on offer,
  // limited by the box's own maximum (a 200px wide box asked for its height
  // at 800px still wraps its text at 200).

  // A fixed size is the answer when there is one. An infinite width or height
  // ("as large as the parent allows") says nothing about the box's own size,
  // so the child is asked instead: an intrinsic size is never infinite.

  @override
  double computeMinIntrinsicWidth(double height) {
    final BoxConstraints a = _additional;
    if (a.hasTightWidth && a.minWidth.isFinite) return a.minWidth;
    final EdgeInsets inset = _inset;
    final double inner = math.max(0, math.min(height, a.maxHeight) - inset.vertical);
    final double w = (child?.getMinIntrinsicWidth(inner) ?? 0) + inset.horizontal;
    return a.minWidth.isFinite ? a.constrainWidth(w) : w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final BoxConstraints a = _additional;
    if (a.hasTightWidth && a.minWidth.isFinite) return a.minWidth;
    final EdgeInsets inset = _inset;
    final double inner = math.max(0, math.min(height, a.maxHeight) - inset.vertical);
    final double w = (child?.getMaxIntrinsicWidth(inner) ?? 0) + inset.horizontal;
    return a.minWidth.isFinite ? a.constrainWidth(w) : w;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final BoxConstraints a = _additional;
    if (a.hasTightHeight && a.minHeight.isFinite) return a.minHeight;
    final EdgeInsets inset = _inset;
    final double inner = math.max(0, math.min(width, a.maxWidth) - inset.horizontal);
    final double h = (child?.getMinIntrinsicHeight(inner) ?? 0) + inset.vertical;
    return a.minHeight.isFinite ? a.constrainHeight(h) : h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final BoxConstraints a = _additional;
    if (a.hasTightHeight && a.minHeight.isFinite) return a.minHeight;
    final EdgeInsets inset = _inset;
    final double inner = math.max(0, math.min(width, a.maxWidth) - inset.horizontal);
    final double h = (child?.getMaxIntrinsicHeight(inner) ?? 0) + inset.vertical;
    return a.minHeight.isFinite ? a.constrainHeight(h) : h;
  }

  // ── layout ──────────────────────────────────────────────────────────────

  ({Size size, Size childSize, BoxConstraints? childConstraints}) _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final BoxConstraints own = _additional.enforce(constraints);
    final EdgeInsets inset = _inset;
    final RenderBox? c = child;
    // An aligned box fills bounded space unless it is told to hug its child.
    final bool fills = _alignment != null && !_shrinkWrap;
    if (c == null) {
      final Size s = fills
          ? own.constrain(
              Size(
                own.hasBoundedWidth ? own.maxWidth : inset.horizontal,
                own.hasBoundedHeight ? own.maxHeight : inset.vertical,
              ),
            )
          : own.constrain(Size(inset.horizontal, inset.vertical));
      return (size: s, childSize: Size.zero, childConstraints: null);
    }
    final BoxConstraints inner = own.deflate(inset);
    final BoxConstraints cc = _alignment != null ? inner.loosen() : inner;
    final Size cs = layoutChild(c, cc);
    final Size s = fills
        ? own.constrain(
            Size(
              own.hasBoundedWidth ? own.maxWidth : cs.width + inset.horizontal,
              own.hasBoundedHeight ? own.maxHeight : cs.height + inset.vertical,
            ),
          )
        : own.constrain(Size(cs.width + inset.horizontal, cs.height + inset.vertical));
    return (size: s, childSize: cs, childConstraints: cc);
  }

  Offset _childOffset(Size boxSize, Size childSize) {
    final EdgeInsets inset = _inset;
    final Size free = Size(
      boxSize.width - inset.horizontal - childSize.width,
      boxSize.height - inset.vertical - childSize.height,
    );
    final Offset aligned = (_alignment ?? Alignment.topLeft).alongSize(free);
    return Offset(inset.left + aligned.dx, inset.top + aligned.dy);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final RenderBox? c = child;
    if (c == null) return null;
    final ({Size size, Size childSize, BoxConstraints? childConstraints}) r = _compute(
      constraints,
      ChildLayoutHelper.dryLayoutChild,
    );
    final double? d = c.getDryBaseline(r.childConstraints!, baseline);
    if (d == null) return null;
    return d + _childOffset(r.size, r.childSize).dy;
  }

  @override
  void performLayout() {
    final ({Size size, Size childSize, BoxConstraints? childConstraints}) r = _compute(
      constraints,
      ChildLayoutHelper.layoutChild,
    );
    size = r.size;
    final RenderBox? c = child;
    if (c != null) {
      (c.parentData! as BoxParentData).offset = _childOffset(size, c.size);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final RenderBox? c = child;
    if (c == null) return null;
    final double? d = c.getDistanceToActualBaseline(baseline);
    if (d == null) return null;
    return d + (c.parentData! as BoxParentData).offset.dy;
  }

  // ── hit testing and paint ───────────────────────────────────────────────

  @override
  bool hitTestSelf(Offset position) => opaque ?? ((_decoration?.fill?.a ?? 0) > 0);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? c = child;
    if (c == null) return false;
    final BoxParentData pd = c.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: pd.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) => c.hitTest(result, position: transformed),
    );
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  void _paintChild(PaintingContext context, Offset offset) {
    final RenderBox? c = child;
    if (c != null) context.paintChild(c, offset + (c.parentData! as BoxParentData).offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect rect = offset & size;
    final KkDecoration? d = _decoration;
    d?.paintBackground(context.canvas, rect);
    if (_clip && child != null) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChild,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      _paintChild(context, offset);
    }
    if (d != null && d.hasForeground) d.paintForeground(context.canvas, rect);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clip ? Offset.zero & size : null;
}

/// A plated surface: an [edge] coloured plate in [shape] with a [fill] plate
/// inset by [edgeWidth] on top, an optional [glow], and the child above.
///
/// Buttons, icon buttons, FABs, badges and code blocks are all built on this.
/// The surface is exactly as large as its child; pointer events only land
/// inside the shape.
class KkSurface extends SingleChildRenderObjectWidget {
  const KkSurface({
    super.key,
    this.shape = const KkShape.rect(),
    this.fill,
    this.edge,
    this.edgeWidth = 1,
    this.glow,
    this.clip = false,
    super.child,
  });

  final KkShape shape;
  final Color? fill;
  final Color? edge;
  final double edgeWidth;
  final KkGlow? glow;

  /// Clip the child to the shape.
  final bool clip;

  @override
  RenderKkSurface createRenderObject(BuildContext context) =>
      RenderKkSurface(shape: shape, fill: fill, edge: edge, edgeWidth: edgeWidth, glow: glow, clip: clip);

  @override
  void updateRenderObject(BuildContext context, RenderKkSurface renderObject) {
    renderObject
      ..shape = shape
      ..fill = fill
      ..edge = edge
      ..edgeWidth = edgeWidth
      ..glow = glow
      ..clip = clip;
  }
}

/// The render object behind [KkSurface].
class RenderKkSurface extends RenderProxyBox {
  RenderKkSurface({
    KkShape shape = const KkShape.rect(),
    Color? fill,
    Color? edge,
    double edgeWidth = 1,
    KkGlow? glow,
    bool clip = false,
    RenderBox? child,
  }) : _shape = shape,
       _fill = fill,
       _edge = edge,
       _edgeWidth = edgeWidth,
       _glow = glow,
       _clip = clip,
       super(child);

  KkShape _shape;
  KkShape get shape => _shape;
  set shape(KkShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  Color? _fill;
  Color? get fill => _fill;
  set fill(Color? value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  Color? _edge;
  Color? get edge => _edge;
  set edge(Color? value) {
    if (value == _edge) return;
    _edge = value;
    markNeedsPaint();
  }

  double _edgeWidth;
  double get edgeWidth => _edgeWidth;
  set edgeWidth(double value) {
    if (value == _edgeWidth) return;
    _edgeWidth = value;
    markNeedsPaint();
  }

  KkGlow? _glow;
  KkGlow? get glow => _glow;
  set glow(KkGlow? value) {
    if (value == _glow) return;
    _glow = value;
    markNeedsPaint();
  }

  bool _clip;
  bool get clip => _clip;
  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_shape.contains(Offset.zero & size, position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => (_fill?.a ?? 0) > 0 || (_edge?.a ?? 0) > 0;

  final LayerHandle<ClipPathLayer> _clipLayer = LayerHandle<ClipPathLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect rect = offset & size;
    kkPaintSurface(context.canvas, rect, shape: _shape, fill: _fill, edge: _edge, edgeWidth: _edgeWidth, glow: _glow);
    if (child == null) {
      _clipLayer.layer = null;
      return;
    }
    if (_clip) {
      _clipLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        _shape.path(Offset.zero & size),
        super.paint,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      super.paint(context, offset);
    }
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
