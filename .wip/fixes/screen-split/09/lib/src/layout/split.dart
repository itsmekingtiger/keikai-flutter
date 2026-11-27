import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../widgets/pressable.dart';

/// Two panes with a divider the operator can drag.
///
/// [ratio] is the share of the space (without the handle) that the first pane
/// takes. Give [ratio] and [onChanged] to control it, or leave [ratio] null
/// and the split keeps its own, starting at [initialRatio]. The divider sits
/// on a whole pixel, so the pane can be up to half a pixel off its share.
///
/// The handle is 8px: a 1px line with a dashed grip. Drag it, or focus it and
/// use the arrow keys (4px, 24px with Shift), Home and End; a double tap puts
/// it back at [initialRatio]. Assistive technology sees a slider that says
/// where the divider is and moves in steps of five percent.
///
/// Both panes fill the cross axis. The split needs a limit along [axis] to
/// have something to share out; without one each pane takes its own size and
/// the handle does not move.
class KkSplit extends StatefulWidget {
  const KkSplit({
    super.key,
    this.axis = Axis.horizontal,
    required this.first,
    required this.second,
    this.ratio,
    this.initialRatio = 0.5,
    this.onChanged,
    this.minFirst = 48,
    this.minSecond = 48,
    this.handleSize = 8,
    this.enabled = true,
    this.focusNode,
    this.semanticLabel,
  }) : assert(ratio == null || (ratio >= 0 && ratio <= 1)),
       assert(initialRatio >= 0 && initialRatio <= 1),
       assert(minFirst >= 0 && minSecond >= 0 && handleSize >= 0);

  /// Horizontal puts the panes side by side; vertical stacks them.
  final Axis axis;
  final Widget first;
  final Widget second;

  /// The first pane's share, 0 to 1. Null lets the split keep its own.
  final double? ratio;

  /// The starting share, and the share a double tap returns to.
  final double initialRatio;

  /// Called with the new share while the handle moves.
  final ValueChanged<double>? onChanged;

  /// Smallest extent of the first pane in px.
  final double minFirst;

  /// Smallest extent of the second pane in px.
  final double minSecond;

  /// Thickness of the handle in px.
  final double handleSize;

  /// Whether the handle can be moved.
  final bool enabled;
  final FocusNode? focusNode;

  /// Defaults to `Split`.
  final String? semanticLabel;

  @override
  State<KkSplit> createState() => _KkSplitState();
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.pixels);

  final double pixels;
}

class _LimitIntent extends Intent {
  const _LimitIntent(this.end);

  final bool end;
}

class _KkSplitState extends State<KkSplit> {
  final GlobalKey _layoutKey = GlobalKey();
  late double _own = widget.initialRatio;
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;
  double _dragExtent = 0;

  double get _ratio => widget.ratio ?? _own;

  @override
  void didUpdateWidget(KkSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handing control back to the split keeps the divider where it was.
    if (oldWidget.ratio != null && widget.ratio == null) _own = oldWidget.ratio!;
    // A disabled handle hears no more of the pointer or the focus.
    if (!widget.enabled && oldWidget.enabled) {
      _hovered = false;
      _focused = false;
      _dragging = false;
    }
  }

  RenderKkSplit? get _render => _layoutKey.currentContext?.findRenderObject() as RenderKkSplit?;

  void _setRatio(double value) {
    final double v = value.isNaN ? _ratio : value.clamp(0.0, 1.0);
    if (v == _ratio) return;
    if (widget.ratio == null) setState(() => _own = v);
    widget.onChanged?.call(v);
  }

  void _setExtent(double extent) {
    final RenderKkSplit? r = _render;
    if (r == null || r.available <= 0) return;
    final double next = r.clampFirst(extent);
    // Where the divider cannot follow, nothing has changed: the share stays
    // what it was, for the day there is room again, and no one is told.
    if (next == _extentNow(r)) return;
    _setRatio(next / r.available);
  }

  /// The first pane's extent for the current ratio. This reads the ratio, not
  /// the last layout, so several key presses inside one frame all count.
  double _extentNow(RenderKkSplit r) => r.clampFirst(_ratio * r.available);

  void _nudge(double pixels) {
    final RenderKkSplit? r = _render;
    if (r == null) return;
    _setExtent(_extentNow(r) + pixels);
  }

  void _limit(bool end) => _setExtent(end ? double.infinity : 0);

  /// Moves the divider by [points] of the space (0.05 is five percent) from
  /// where it is, as the slider semantics announce it.
  void _step(double points) {
    final RenderKkSplit? r = _render;
    if (r == null) return;
    _setExtent(_extentNow(r) + points * r.available);
  }

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _NudgeIntent: CallbackAction<_NudgeIntent>(onInvoke: (_NudgeIntent intent) => _nudge(intent.pixels)),
    _LimitIntent: CallbackAction<_LimitIntent>(onInvoke: (_LimitIntent intent) => _limit(intent.end)),
  };

  Map<ShortcutActivator, Intent> get _shortcuts {
    final bool h = widget.axis == Axis.horizontal;
    final LogicalKeyboardKey less = h ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowUp;
    final LogicalKeyboardKey more = h ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown;
    return <ShortcutActivator, Intent>{
      SingleActivator(less): const _NudgeIntent(-4),
      SingleActivator(more): const _NudgeIntent(4),
      SingleActivator(less, shift: true): const _NudgeIntent(-24),
      SingleActivator(more, shift: true): const _NudgeIntent(24),
      const SingleActivator(LogicalKeyboardKey.home): const _LimitIntent(false),
      const SingleActivator(LogicalKeyboardKey.end): const _LimitIntent(true),
    };
  }

  void _onDragStart(DragStartDetails details) {
    final RenderKkSplit? r = _render;
    _dragExtent = r == null ? 0 : _extentNow(r);
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragExtent += details.primaryDelta ?? 0;
    _setExtent(_dragExtent);
  }

  void _onDragEnd([DragEndDetails? details]) {
    if (_dragging) setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool h = widget.axis == Axis.horizontal;
    final bool active = widget.enabled && (_hovered || _dragging || _focused);

    Widget handle = CustomPaint(
      painter: _KkSplitHandlePainter(
        axis: widget.axis,
        line: active ? c.signal : c.line,
        grip: widget.enabled ? (active ? c.signal : c.inkFaint) : null,
        ground: c.bg000,
      ),
    );
    if (widget.enabled) {
      final Widget control = FocusableActionDetector(
        focusNode: widget.focusNode,
        mouseCursor: h ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        shortcuts: _shortcuts,
        actions: _actions,
        onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          // Track the pointer from where it went down, so the divider does
          // not trail it by the drag slop.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: h ? _onDragStart : null,
          onHorizontalDragUpdate: h ? _onDragUpdate : null,
          onHorizontalDragEnd: h ? _onDragEnd : null,
          onHorizontalDragCancel: h ? _onDragEnd : null,
          onVerticalDragStart: h ? null : _onDragStart,
          onVerticalDragUpdate: h ? null : _onDragUpdate,
          onVerticalDragEnd: h ? null : _onDragEnd,
          onVerticalDragCancel: h ? null : _onDragEnd,
          onDoubleTap: () => _setRatio(widget.initialRatio),
          child: KkFocusRing(visible: _focused, offset: 0, child: handle),
        ),
      );
      // The slider announces where the divider is. The minimums can keep it
      // away from the share it was asked for, and by how much is only known
      // once the split is laid out: the split hands the handle that position
      // with its constraints, and the handle is built from them.
      handle = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final _KkSplitHandleConstraints at = constraints as _KkSplitHandleConstraints;
          final RenderKkSplit? r = _render;
          // With nothing to share out there is no position to speak of.
          String percent(double extent) => '${((at.available > 0 ? extent / at.available : _ratio) * 100).round()}%';
          // Five percent of the space from here, as far as the divider can go.
          double step(double points) => r == null ? at.first : r.clampFirst(at.first + points * at.available);
          // The semantics node is outside the focus node, so that "focusable"
          // and "focused" land on the slider itself.
          return Semantics(
            container: true,
            slider: true,
            label: widget.semanticLabel ?? 'Split',
            value: percent(at.first),
            increasedValue: percent(step(0.05)),
            decreasedValue: percent(step(-0.05)),
            onIncrease: () => _step(0.05),
            onDecrease: () => _step(-0.05),
            child: control,
          );
        },
      );
    }

    return _KkSplitLayout(
      key: _layoutKey,
      axis: widget.axis,
      ratio: _ratio,
      minFirst: widget.minFirst,
      minSecond: widget.minSecond,
      handleSize: widget.handleSize,
      children: <Widget>[widget.first, widget.second, handle],
    );
  }
}

class _KkSplitHandlePainter extends CustomPainter {
  const _KkSplitHandlePainter({required this.axis, required this.line, required this.grip, required this.ground});

  final Axis axis;
  final Color line;

  /// Null hides the grip (a fixed divider).
  final Color? grip;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bool h = axis == Axis.horizontal;
    final Paint paint = Paint()..color = line;
    // The 1px line down the middle of the handle.
    final double across = h ? size.width : size.height;
    final double along = h ? size.height : size.width;
    final double lineAt = ((across - 1) / 2).floorToDouble();
    canvas.drawRect(h ? Rect.fromLTWH(lineAt, 0, 1, along) : Rect.fromLTWH(0, lineAt, along, 1), paint);
    final Color? g = grip;
    if (g == null) return;
    // The grip: 3px dashes, 6 long and 3 apart, 33px in all, centred on the
    // line and set on the ground colour so the line does not run through it.
    const double thick = 3;
    final double length = math.min(33, along - 8);
    if (length < 6 || across < thick) return;
    final double start = ((along - length) / 2).floorToDouble();
    final Rect bar = h
        ? Rect.fromLTWH(lineAt - 1, start, thick, length)
        : Rect.fromLTWH(start, lineAt - 1, length, thick);
    canvas.drawRect(bar.inflate(2), paint..color = ground);
    paint.color = g;
    for (double d = 0; d + 6 <= length + 0.01; d += 9) {
      canvas.drawRect(
        h ? Rect.fromLTWH(bar.left, bar.top + d, thick, 6) : Rect.fromLTWH(bar.left + d, bar.top, 6, thick),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_KkSplitHandlePainter oldDelegate) =>
      oldDelegate.axis != axis || oldDelegate.line != line || oldDelegate.grip != grip || oldDelegate.ground != ground;
}

class KkSplitParentData extends ContainerBoxParentData<RenderBox> {}

/// What a [RenderKkSplit] lays its handle out with: the exact size of the
/// handle, and where the divider is.
///
/// A handle that says where the divider is (the slider semantics) is built
/// from these with a `LayoutBuilder`. They differ when the position does, so
/// that handle is built again whenever the divider has moved.
class _KkSplitHandleConstraints extends BoxConstraints {
  const _KkSplitHandleConstraints({
    required double width,
    required double height,
    required this.first,
    required this.available,
  }) : super.tightFor(width: width, height: height);

  /// Main-axis extent of the first pane.
  final double first;

  /// Main-axis space the two panes share.
  final double available;

  @override
  bool operator ==(Object other) =>
      super == other && other is _KkSplitHandleConstraints && other.first == first && other.available == available;

  @override
  int get hashCode => Object.hash(super.hashCode, first, available);
}

class _KkSplitLayout extends MultiChildRenderObjectWidget {
  const _KkSplitLayout({
    super.key,
    required this.axis,
    required this.ratio,
    required this.minFirst,
    required this.minSecond,
    required this.handleSize,
    super.children,
  });

  final Axis axis;
  final double ratio;
  final double minFirst;
  final double minSecond;
  final double handleSize;

  @override
  RenderKkSplit createRenderObject(BuildContext context) =>
      RenderKkSplit(axis: axis, ratio: ratio, minFirst: minFirst, minSecond: minSecond, handleSize: handleSize);

  @override
  void updateRenderObject(BuildContext context, RenderKkSplit renderObject) {
    renderObject
      ..axis = axis
      ..ratio = ratio
      ..minFirst = minFirst
      ..minSecond = minSecond
      ..handleSize = handleSize;
  }
}

/// The render object behind [KkSplit]. Its three children are the first pane,
/// the second pane and the handle, in that order.
class RenderKkSplit extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkSplitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkSplitParentData> {
  RenderKkSplit({
    Axis axis = Axis.horizontal,
    double ratio = 0.5,
    double minFirst = 48,
    double minSecond = 48,
    double handleSize = 8,
  }) : _axis = axis,
       _ratio = ratio,
       _minFirst = minFirst,
       _minSecond = minSecond,
       _handleSize = handleSize;

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  double _ratio;
  double get ratio => _ratio;
  set ratio(double value) {
    if (value == _ratio) return;
    _ratio = value;
    markNeedsLayout();
  }

  double _minFirst;
  double get minFirst => _minFirst;
  set minFirst(double value) {
    if (value == _minFirst) return;
    _minFirst = value;
    markNeedsLayout();
  }

  double _minSecond;
  double get minSecond => _minSecond;
  set minSecond(double value) {
    if (value == _minSecond) return;
    _minSecond = value;
    markNeedsLayout();
  }

  double _handleSize;
  double get handleSize => _handleSize;
  set handleSize(double value) {
    if (value == _handleSize) return;
    _handleSize = value;
    markNeedsLayout();
  }

  /// Main-axis space shared by the two panes (the whole extent minus the
  /// handle), from the last layout.
  double get available => _available;
  double _available = 0;

  /// Main-axis extent of the first pane, from the last layout.
  double get firstExtent => _firstExtent;
  double _firstExtent = 0;

  /// The extent the first pane takes when it is asked to be [extent] long: on
  /// a whole pixel, and limited so that both panes keep their minimum.
  double clampFirst(double extent) => _clampFirst(extent, _available);

  double _clampFirst(double extent, double available) {
    final double lo = math.min(_minFirst, available);
    final double hi = math.max(lo, available - _minSecond);
    // The divider is a 1px line, and so are the edges of the panes next to
    // it: between two pixels each of them would be painted across both.
    return extent.roundToDouble().clamp(lo, hi);
  }

  bool get _horizontal => _axis == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkSplitParentData) child.parentData = KkSplitParentData();
  }

  RenderBox? get _first => firstChild;
  RenderBox? get _second => _first == null ? null : childAfter(_first!);
  RenderBox? get _handle => _second == null ? null : childAfter(_second!);

  double _mainIntrinsic(double Function(RenderBox child) of) =>
      (_first == null ? 0 : of(_first!)) + (_second == null ? 0 : of(_second!)) + _handleSize;

  /// The larger cross extent of the two panes when the split is [main] long:
  /// each pane is asked at the extent it would really get.
  double _crossIntrinsic(double main, double Function(RenderBox child, double main) of) {
    double a = double.infinity;
    double b = double.infinity;
    if (main.isFinite) {
      final double available = math.max(0, main - _handleSize);
      a = _clampFirst(_ratio * available, available);
      b = available - a;
    }
    return math.max(_first == null ? 0 : of(_first!, a), _second == null ? 0 : of(_second!, b));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _horizontal
      ? _mainIntrinsic((RenderBox c) => c.getMinIntrinsicWidth(height))
      : _crossIntrinsic(height, (RenderBox c, double main) => c.getMinIntrinsicWidth(main));

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal
      ? _mainIntrinsic((RenderBox c) => c.getMaxIntrinsicWidth(height))
      : _crossIntrinsic(height, (RenderBox c, double main) => c.getMaxIntrinsicWidth(main));

  @override
  double computeMinIntrinsicHeight(double width) => _horizontal
      ? _crossIntrinsic(width, (RenderBox c, double main) => c.getMinIntrinsicHeight(main))
      : _mainIntrinsic((RenderBox c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _horizontal
      ? _crossIntrinsic(width, (RenderBox c, double main) => c.getMaxIntrinsicHeight(main))
      : _mainIntrinsic((RenderBox c) => c.getMaxIntrinsicHeight(width));

  BoxConstraints _pane(double main, double minCross, double maxCross) => _horizontal
      ? BoxConstraints(minWidth: main, maxWidth: main, minHeight: minCross, maxHeight: maxCross)
      : BoxConstraints(minHeight: main, maxHeight: main, minWidth: minCross, maxWidth: maxCross);

  ({Size size, double available, double first, double cross, double handle}) _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final double maxMain = _horizontal ? constraints.maxWidth : constraints.maxHeight;
    final double maxCross = _horizontal ? constraints.maxHeight : constraints.maxWidth;
    final double minCross = _horizontal ? constraints.minHeight : constraints.minWidth;
    final RenderBox? a = _first;
    final RenderBox? b = _second;
    double mainOf(Size s) => _horizontal ? s.width : s.height;
    double crossOf(Size s) => _horizontal ? s.height : s.width;

    // With a cross-axis limit both panes fill it. Without one they are
    // measured first and then both given the larger of their two extents.
    final bool crossBounded = maxCross.isFinite;
    final double paneCross = crossBounded ? maxCross : minCross;
    final double paneMaxCross = crossBounded ? maxCross : double.infinity;
    // A split shorter than its handle shows as much of the handle as fits.
    final double handle = maxMain.isFinite ? math.min(_handleSize, maxMain) : _handleSize;
    double available;
    double first;
    Size sa = Size.zero;
    Size sb = Size.zero;
    if (maxMain.isFinite) {
      available = maxMain - handle;
      first = _clampFirst(_ratio * available, available);
      if (a != null) sa = layoutChild(a, _pane(first, paneCross, paneMaxCross));
      if (b != null) sb = layoutChild(b, _pane(available - first, paneCross, paneMaxCross));
    } else {
      // No main-axis limit: each pane takes its own extent.
      final BoxConstraints loose = _horizontal
          ? BoxConstraints(minHeight: paneCross, maxHeight: paneMaxCross)
          : BoxConstraints(minWidth: paneCross, maxWidth: paneMaxCross);
      if (a != null) sa = layoutChild(a, loose);
      if (b != null) sb = layoutChild(b, loose);
      first = mainOf(sa);
      available = first + mainOf(sb);
    }
    double cross = maxCross;
    if (!crossBounded) {
      cross = math.max(minCross, math.max(crossOf(sa), crossOf(sb)));
      // Stretch the shorter pane to the taller one, at the extent it has. It
      // is told to be at least that large and no more: a pane held to an exact
      // size would be a relayout boundary, and the split would not be laid out
      // again when the pane's content grows later.
      if (a != null && crossOf(sa) < cross) sa = layoutChild(a, _pane(mainOf(sa), cross, double.infinity));
      if (b != null && crossOf(sb) < cross) sb = layoutChild(b, _pane(mainOf(sb), cross, double.infinity));
    }
    final double main = available + handle;
    final Size size = constraints.constrain(_horizontal ? Size(main, cross) : Size(cross, main));
    return (size: size, available: available, first: first, cross: cross, handle: handle);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  /// Two panes have no baseline of their own.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    final ({Size size, double available, double first, double cross, double handle}) r = _compute(
      constraints,
      ChildLayoutHelper.layoutChild,
    );
    size = r.size;
    _available = r.available;
    _firstExtent = r.first;
    final RenderBox? a = _first;
    final RenderBox? b = _second;
    final RenderBox? handle = _handle;
    if (a != null) (a.parentData! as KkSplitParentData).offset = Offset.zero;
    if (handle != null) {
      handle.layout(
        _KkSplitHandleConstraints(
          width: _horizontal ? r.handle : r.cross,
          height: _horizontal ? r.cross : r.handle,
          first: r.first,
          available: r.available,
        ),
      );
      (handle.parentData! as KkSplitParentData).offset = _horizontal ? Offset(r.first, 0) : Offset(0, r.first);
    }
    if (b != null) {
      final double start = r.first + r.handle;
      (b.parentData! as KkSplitParentData).offset = _horizontal ? Offset(start, 0) : Offset(0, start);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  void _paintPane(PaintingContext context, Offset offset, RenderBox? pane, LayerHandle<ClipRectLayer> handle) {
    if (pane == null) {
      handle.layer = null;
      return;
    }
    final Offset o = (pane.parentData! as KkSplitParentData).offset;
    handle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      o & pane.size,
      (PaintingContext c, Offset at) => c.paintChild(pane, at + o),
      oldLayer: handle.layer,
    );
  }

  final LayerHandle<ClipRectLayer> _secondClipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    // Each pane is clipped to its own box; the handle is painted last, on top.
    _paintPane(context, offset, _first, _clipLayer);
    _paintPane(context, offset, _second, _secondClipLayer);
    final RenderBox? handle = _handle;
    if (handle != null) context.paintChild(handle, offset + (handle.parentData! as KkSplitParentData).offset);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _secondClipLayer.layer = null;
    super.dispose();
  }

  /// A pane is clipped to its own box; the handle is not clipped.
  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (child is! RenderBox || identical(child, _handle)) return null;
    return (child.parentData! as KkSplitParentData).offset & child.size;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('axis', axis))
      ..add(DoubleProperty('ratio', ratio))
      ..add(DoubleProperty('firstExtent', firstExtent));
  }
}
