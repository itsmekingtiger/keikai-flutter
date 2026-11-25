import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How children are placed along the main axis.
enum KkMainAlign { start, end, center, between, around, evenly }

/// How children are placed across the main axis.
///
/// [stretch] makes every child as large as the line: the line is as large as
/// its largest child (or as the incoming constraint, when that is tight).
enum KkCrossAlign { start, end, center, stretch, baseline }

/// Parent data of a child of [KkFlex].
class KkFlexParentData extends ContainerBoxParentData<RenderBox> {
  /// Share of the free main-axis space. 0 means the child keeps its own size.
  int flex = 0;

  /// Whether a flexible child must fill its share ([KkExpanded]) or may be
  /// smaller ([KkFlexible]).
  bool tight = true;

  /// Overrides the line's cross alignment for this child.
  KkCrossAlign? alignSelf;

  @override
  String toString() => '${super.toString()}; flex=$flex; tight=$tight; alignSelf=$alignSelf';
}

/// A row or a column with a fixed [gap] between children.
///
/// This is KEIKAI's own flex layout, written against the rendering layer.
/// Prefer [KkRow] and [KkColumn].
class KkFlex extends MultiChildRenderObjectWidget {
  const KkFlex({
    super.key,
    required this.direction,
    this.gap = 0,
    this.main = KkMainAlign.start,
    this.cross = KkCrossAlign.center,
    this.shrinkWrap = false,
    this.clip = Clip.none,
    this.textBaseline = TextBaseline.alphabetic,
    super.children,
  });

  final Axis direction;

  /// Space between adjacent children.
  final double gap;
  final KkMainAlign main;
  final KkCrossAlign cross;

  /// Take only the space the children need along the main axis instead of all
  /// that is available.
  final bool shrinkWrap;
  final Clip clip;
  final TextBaseline textBaseline;

  @override
  RenderKkFlex createRenderObject(BuildContext context) => RenderKkFlex(
    direction: direction,
    gap: gap,
    main: main,
    cross: cross,
    shrinkWrap: shrinkWrap,
    clip: clip,
    textBaseline: textBaseline,
  );

  @override
  void updateRenderObject(BuildContext context, RenderKkFlex renderObject) {
    renderObject
      ..direction = direction
      ..gap = gap
      ..main = main
      ..cross = cross
      ..shrinkWrap = shrinkWrap
      ..clip = clip
      ..textBaseline = textBaseline;
  }
}

/// A horizontal [KkFlex]. Children are centred vertically by default.
class KkRow extends KkFlex {
  const KkRow({
    super.key,
    super.gap,
    super.main,
    super.cross = KkCrossAlign.center,
    super.shrinkWrap,
    super.clip,
    super.textBaseline,
    super.children,
  }) : super(direction: Axis.horizontal);
}

/// A vertical [KkFlex]. Children are stretched to the column's width by default.
class KkColumn extends KkFlex {
  const KkColumn({
    super.key,
    super.gap,
    super.main,
    super.cross = KkCrossAlign.stretch,
    super.shrinkWrap,
    super.clip,
    super.textBaseline,
    super.children,
  }) : super(direction: Axis.vertical);
}

/// Gives a child of a [KkFlex] a share of the free space. The child may be
/// smaller than its share unless [tight] is true.
class KkFlexible extends ParentDataWidget<KkFlexParentData> {
  const KkFlexible({super.key, this.flex = 1, this.tight = false, this.align, required super.child})
    : assert(flex >= 0);

  final int flex;
  final bool tight;

  /// Overrides the cross alignment for this child.
  final KkCrossAlign? align;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkFlexParentData pd = renderObject.parentData! as KkFlexParentData;
    bool dirty = false;
    if (pd.flex != flex) {
      pd.flex = flex;
      dirty = true;
    }
    if (pd.tight != tight) {
      pd.tight = tight;
      dirty = true;
    }
    if (pd.alignSelf != align) {
      pd.alignSelf = align;
      dirty = true;
    }
    if (dirty) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => KkFlex;
}

/// A [KkFlexible] child that must fill its share of the free space.
class KkExpanded extends KkFlexible {
  const KkExpanded({super.key, super.flex, super.align, required super.child}) : super(tight: true);
}

/// Aligns one child of a [KkFlex] differently from the rest.
class KkAlignSelf extends KkFlexible {
  const KkAlignSelf({super.key, required KkCrossAlign super.align, required super.child}) : super(flex: 0);
}

/// Empty space that takes a share of the free main-axis space.
class KkSpacer extends StatelessWidget {
  const KkSpacer({super.key, this.flex = 1});

  final int flex;

  @override
  Widget build(BuildContext context) => KkExpanded(flex: flex, child: const KkGap(0));
}

/// A fixed gap along the main axis of the enclosing [KkFlex]. Outside a flex
/// it is a square of [size].
class KkGap extends LeafRenderObjectWidget {
  const KkGap(this.size, {super.key});

  final double size;

  @override
  RenderKkGap createRenderObject(BuildContext context) => RenderKkGap(size);

  @override
  void updateRenderObject(BuildContext context, RenderKkGap renderObject) => renderObject.extent = size;
}

class RenderKkGap extends RenderBox {
  RenderKkGap(this._extent);

  double _extent;
  double get extent => _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  /// A gap is sized by its parent, so one that moves to another parent
  /// measures again even when it is handed the same constraints as before.
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markNeedsLayout();
  }

  Size _sizeFor(BoxConstraints constraints) {
    final RenderObject? p = parent;
    if (p is RenderKkFlex) {
      return constraints.constrain(p.direction == Axis.horizontal ? Size(_extent, 0) : Size(0, _extent));
    }
    return constraints.constrain(Size.square(_extent));
  }

  bool get _horizontal {
    final RenderObject? p = parent;
    return p is! RenderKkFlex || p.direction == Axis.horizontal;
  }

  bool get _vertical {
    final RenderObject? p = parent;
    return p is! RenderKkFlex || p.direction == Axis.vertical;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _horizontal ? _extent : 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal ? _extent : 0;

  @override
  double computeMinIntrinsicHeight(double width) => _vertical ? _extent : 0;

  @override
  double computeMaxIntrinsicHeight(double width) => _vertical ? _extent : 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  /// Empty space has no baseline.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() => size = _sizeFor(constraints);
}

class _FlexSizes {
  const _FlexSizes(this.size, this.allocated, this.maxAscent, this.childSizes, this.childConstraints);

  final Size size;

  /// Sum of the children's main extents (without gaps).
  final double allocated;

  /// Largest distance from a child's top to its baseline, for baseline lines.
  final double maxAscent;
  final List<Size> childSizes;

  /// The constraints each child was last laid out with.
  final List<BoxConstraints> childConstraints;
}

/// The render object behind [KkFlex].
class RenderKkFlex extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkFlexParentData> {
  RenderKkFlex({
    required Axis direction,
    double gap = 0,
    KkMainAlign main = KkMainAlign.start,
    KkCrossAlign cross = KkCrossAlign.center,
    bool shrinkWrap = false,
    Clip clip = Clip.none,
    TextBaseline textBaseline = TextBaseline.alphabetic,
  }) : _direction = direction,
       _gap = gap,
       _main = main,
       _cross = cross,
       _shrinkWrap = shrinkWrap,
       _clip = clip,
       _textBaseline = textBaseline;

  Axis _direction;
  Axis get direction => _direction;
  set direction(Axis value) {
    if (value == _direction) return;
    _direction = value;
    // A gap is sized by this direction, which the framework does not track
    // for it: handed the same constraints, it would keep its old size.
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if (child is RenderKkGap) child.markNeedsLayout();
    }
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
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

  bool _shrinkWrap;
  bool get shrinkWrap => _shrinkWrap;
  set shrinkWrap(bool value) {
    if (value == _shrinkWrap) return;
    _shrinkWrap = value;
    markNeedsLayout();
  }

  Clip _clip;
  Clip get clip => _clip;
  set clip(Clip value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  TextBaseline _textBaseline;
  TextBaseline get textBaseline => _textBaseline;
  set textBaseline(TextBaseline value) {
    if (value == _textBaseline) return;
    _textBaseline = value;
    markNeedsLayout();
  }

  bool _hasOverflow = false;

  bool get _horizontal => _direction == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkFlexParentData) child.parentData = KkFlexParentData();
  }

  double _mainOf(Size s) => _horizontal ? s.width : s.height;
  double _crossOf(Size s) => _horizontal ? s.height : s.width;

  KkCrossAlign _crossFor(KkFlexParentData pd) => pd.alignSelf ?? _cross;

  BoxConstraints _box({
    required double minMain,
    required double maxMain,
    required double minCross,
    required double maxCross,
  }) {
    return _horizontal
        ? BoxConstraints(minWidth: minMain, maxWidth: maxMain, minHeight: minCross, maxHeight: maxCross)
        : BoxConstraints(minHeight: minMain, maxHeight: maxMain, minWidth: minCross, maxWidth: maxCross);
  }

  // ── intrinsics ──────────────────────────────────────────────────────────

  double _gaps() => childCount > 1 ? _gap * (childCount - 1) : 0;

  double _intrinsicMain(double crossExtent, double Function(RenderBox child, double extent) childSize) {
    double totalFlex = 0;
    double inflexible = 0;
    double maxFraction = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final int flex = (child.parentData! as KkFlexParentData).flex;
      if (flex > 0) {
        totalFlex += flex;
        maxFraction = math.max(maxFraction, childSize(child, crossExtent) / flex);
      } else {
        inflexible += childSize(child, crossExtent);
      }
    }
    return maxFraction * totalFlex + inflexible + _gaps();
  }

  double _intrinsicCross(
    double mainExtent,
    double Function(RenderBox child, double extent) childCross,
    double Function(RenderBox child, double extent) childMaxMain,
  ) {
    double totalFlex = 0;
    double inflexible = 0;
    double maxCross = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final int flex = (child.parentData! as KkFlexParentData).flex;
      if (flex > 0) {
        totalFlex += flex;
      } else {
        final double m = childMaxMain(child, double.infinity);
        inflexible += m;
        maxCross = math.max(maxCross, childCross(child, m));
      }
    }
    if (totalFlex > 0) {
      final double free = mainExtent.isFinite ? math.max(0, mainExtent - inflexible - _gaps()) : double.infinity;
      for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
        final int flex = (child.parentData! as KkFlexParentData).flex;
        if (flex > 0) {
          final double share = free.isFinite ? free * flex / totalFlex : childMaxMain(child, double.infinity);
          maxCross = math.max(maxCross, childCross(child, share));
        }
      }
    }
    return maxCross;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _horizontal
      ? _intrinsicMain(height, (RenderBox c, double e) => c.getMinIntrinsicWidth(e))
      : _intrinsicCross(
          height,
          (RenderBox c, double e) => c.getMinIntrinsicWidth(e),
          (RenderBox c, double e) => c.getMaxIntrinsicHeight(e),
        );

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal
      ? _intrinsicMain(height, (RenderBox c, double e) => c.getMaxIntrinsicWidth(e))
      : _intrinsicCross(
          height,
          (RenderBox c, double e) => c.getMaxIntrinsicWidth(e),
          (RenderBox c, double e) => c.getMaxIntrinsicHeight(e),
        );

  @override
  double computeMinIntrinsicHeight(double width) => _horizontal
      ? _intrinsicCross(
          width,
          (RenderBox c, double e) => c.getMinIntrinsicHeight(e),
          (RenderBox c, double e) => c.getMaxIntrinsicWidth(e),
        )
      : _intrinsicMain(width, (RenderBox c, double e) => c.getMinIntrinsicHeight(e));

  @override
  double computeMaxIntrinsicHeight(double width) => _horizontal
      ? _intrinsicCross(
          width,
          (RenderBox c, double e) => c.getMaxIntrinsicHeight(e),
          (RenderBox c, double e) => c.getMaxIntrinsicWidth(e),
        )
      : _intrinsicMain(width, (RenderBox c, double e) => c.getMaxIntrinsicHeight(e));

  // ── layout ──────────────────────────────────────────────────────────────

  _FlexSizes _computeSizes(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
    ChildBaselineGetter getBaseline,
  ) {
    final double maxMain = _horizontal ? constraints.maxWidth : constraints.maxHeight;
    final double maxCross = _horizontal ? constraints.maxHeight : constraints.maxWidth;
    final double minCross = _horizontal ? constraints.minHeight : constraints.minWidth;
    final bool boundedMain = maxMain.isFinite;
    final bool tightCross = minCross == maxCross;

    final int count = childCount;
    final List<Size> sizes = List<Size>.filled(count, Size.zero);
    final List<BoxConstraints> used = List<BoxConstraints>.filled(count, const BoxConstraints());
    final double gaps = count > 1 ? _gap * (count - 1) : 0;

    BoxConstraints inner(KkFlexParentData pd, double minMainExtent, double maxMainExtent, {double? forceCross}) {
      final bool stretch = _crossFor(pd) == KkCrossAlign.stretch;
      final double? c = forceCross ?? (stretch && tightCross ? maxCross : null);
      return _box(minMain: minMainExtent, maxMain: maxMainExtent, minCross: c ?? 0, maxCross: c ?? maxCross);
    }

    // Pass 1: children that keep their own main size.
    int totalFlex = 0;
    double allocated = 0;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final KkFlexParentData pd = child.parentData! as KkFlexParentData;
      if (pd.flex > 0 && boundedMain) {
        totalFlex += pd.flex;
        continue;
      }
      final BoxConstraints c = inner(pd, 0, double.infinity);
      used[i] = c;
      sizes[i] = layoutChild(child, c);
      allocated += _mainOf(sizes[i]);
    }

    // Pass 2: flexible children share what is left.
    if (totalFlex > 0) {
      final double free = math.max(0, maxMain - allocated - gaps);
      i = 0;
      for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
        final KkFlexParentData pd = child.parentData! as KkFlexParentData;
        if (pd.flex <= 0) continue;
        final double share = free * pd.flex / totalFlex;
        final BoxConstraints c = inner(pd, pd.tight ? share : 0, share);
        used[i] = c;
        sizes[i] = layoutChild(child, c);
        allocated += _mainOf(sizes[i]);
      }
    }

    // Cross size of the line.
    double crossSize = 0;
    for (final Size s in sizes) {
      crossSize = math.max(crossSize, _crossOf(s));
    }

    // Baselines (rows only make sense, but columns are tolerated).
    double maxAscent = 0;
    double maxDescent = 0;
    bool anyBaseline = false;
    i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final KkFlexParentData pd = child.parentData! as KkFlexParentData;
      if (_crossFor(pd) != KkCrossAlign.baseline || !_horizontal) continue;
      final double? d = getBaseline(child, used[i], _textBaseline);
      if (d == null) continue;
      anyBaseline = true;
      maxAscent = math.max(maxAscent, d);
      maxDescent = math.max(maxDescent, sizes[i].height - d);
    }
    if (anyBaseline) crossSize = math.max(crossSize, maxAscent + maxDescent);
    crossSize = crossSize.clamp(minCross, maxCross);

    // Pass 3: stretch. When the cross constraint was not tight the line is as
    // large as its largest child; smaller stretch children are laid out again
    // at exactly that size.
    if (!tightCross) {
      bool changed = false;
      i = 0;
      for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
        final KkFlexParentData pd = child.parentData! as KkFlexParentData;
        if (_crossFor(pd) != KkCrossAlign.stretch) continue;
        if ((_crossOf(sizes[i]) - crossSize).abs() < 0.01) continue;
        final BoxConstraints prev = used[i];
        final double minM = _horizontal ? prev.minWidth : prev.minHeight;
        final double maxM = _horizontal ? prev.maxWidth : prev.maxHeight;
        final BoxConstraints c = inner(pd, minM, maxM, forceCross: crossSize);
        used[i] = c;
        final Size before = sizes[i];
        sizes[i] = layoutChild(child, c);
        if (_mainOf(before) != _mainOf(sizes[i])) changed = true;
      }
      if (changed) {
        allocated = 0;
        for (final Size s in sizes) {
          allocated += _mainOf(s);
        }
      }
    }

    final double content = allocated + gaps;
    final double mainSize = (_shrinkWrap || !boundedMain) ? content : maxMain;
    final Size size = constraints.constrain(_horizontal ? Size(mainSize, crossSize) : Size(crossSize, mainSize));
    return _FlexSizes(size, allocated, anyBaseline ? maxAscent : 0, sizes, used);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSizes(constraints, ChildLayoutHelper.dryLayoutChild, ChildLayoutHelper.getDryBaseline).size;
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final _FlexSizes sizes = _computeSizes(
      constraints,
      ChildLayoutHelper.dryLayoutChild,
      ChildLayoutHelper.getDryBaseline,
    );
    final ({double leading, double between}) spacing = _spacing(sizes);
    double? result;
    int i = 0;
    double position = spacing.leading;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final Size s = sizes.childSizes[i];
      // Ask at the constraints the child is laid out with. At any other, even
      // tight at the size it ends up with, a child that is itself a flex gives
      // its own children different room and reports a different baseline.
      final BoxConstraints given = sizes.childConstraints[i];
      final double? d = child.getDryBaseline(given, baseline);
      if (d != null) {
        final KkFlexParentData pd = child.parentData! as KkFlexParentData;
        if (!_horizontal) return d + position;
        // A baseline-aligned child is placed by the row's own baseline kind.
        final double? own = _crossFor(pd) != KkCrossAlign.baseline
            ? null
            : (baseline == _textBaseline ? d : child.getDryBaseline(given, _textBaseline));
        final double v = d + _crossOffset(pd, s, sizes, own);
        result = result == null ? v : math.min(result, v);
      }
      position += _mainOf(s) + _gap + spacing.between;
    }
    return result;
  }

  /// Space before the first child and extra space between children, by the
  /// main alignment. Content that does not fit starts at the start.
  ({double leading, double between}) _spacing(_FlexSizes sizes) {
    final int count = childCount;
    final double gaps = count > 1 ? _gap * (count - 1) : 0;
    final double free = math.max(0, _mainOf(sizes.size) - sizes.allocated - gaps);
    return switch (_main) {
      KkMainAlign.start => (leading: 0, between: 0),
      KkMainAlign.end => (leading: free, between: 0),
      KkMainAlign.center => (leading: free / 2, between: 0),
      KkMainAlign.between => (leading: 0, between: count > 1 ? free / (count - 1) : 0),
      KkMainAlign.around => count > 0 ? (leading: free / count / 2, between: free / count) : (leading: 0, between: 0),
      KkMainAlign.evenly =>
        count > 0 ? (leading: free / (count + 1), between: free / (count + 1)) : (leading: 0, between: 0),
    };
  }

  double _crossOffset(KkFlexParentData pd, Size childSize, _FlexSizes sizes, double? baseline) {
    final double free = _crossOf(sizes.size) - _crossOf(childSize);
    return switch (_crossFor(pd)) {
      KkCrossAlign.start || KkCrossAlign.stretch => 0,
      KkCrossAlign.end => free,
      KkCrossAlign.center => free / 2,
      KkCrossAlign.baseline => (_horizontal && baseline != null) ? sizes.maxAscent - baseline : 0,
    };
  }

  @override
  void performLayout() {
    final _FlexSizes sizes = _computeSizes(constraints, ChildLayoutHelper.layoutChild, ChildLayoutHelper.getBaseline);
    size = sizes.size;

    final int count = childCount;
    final double gaps = count > 1 ? _gap * (count - 1) : 0;
    _hasOverflow = sizes.allocated + gaps > _mainOf(size) + 0.01 || _childCrossOverflows(sizes);

    final ({double leading, double between}) spacing = _spacing(sizes);
    double position = spacing.leading;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final KkFlexParentData pd = child.parentData! as KkFlexParentData;
      double? baseline;
      if (_horizontal && _crossFor(pd) == KkCrossAlign.baseline) {
        baseline = child.getDistanceToBaseline(_textBaseline, onlyReal: true);
      }
      final double crossOffset = _crossOffset(pd, child.size, sizes, baseline);
      pd.offset = _horizontal ? Offset(position, crossOffset) : Offset(crossOffset, position);
      position += _mainOf(child.size) + _gap + spacing.between;
    }
  }

  bool _childCrossOverflows(_FlexSizes sizes) {
    final double cross = _crossOf(sizes.size);
    for (final Size s in sizes.childSizes) {
      if (_crossOf(s) > cross + 0.01) return true;
    }
    return false;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return _horizontal
        ? defaultComputeDistanceToHighestActualBaseline(baseline)
        : defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasOverflow || _clip == Clip.none) {
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
  Rect? describeApproximatePaintClip(RenderObject child) {
    return (_hasOverflow && _clip != Clip.none) ? Offset.zero & size : null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('direction', direction))
      ..add(DoubleProperty('gap', gap))
      ..add(EnumProperty<KkMainAlign>('main', main))
      ..add(EnumProperty<KkCrossAlign>('cross', cross));
  }
}
