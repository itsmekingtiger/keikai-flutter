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
/// and the split keeps its own, starting at [initialRatio].
///
/// The handle is 8px: a 1px line with a dashed grip. Drag it, or focus it and use the
/// arrow keys (4px, 24px with Shift), Home and End; a double tap puts it back
/// at [initialRatio].
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
    _setRatio(r.clampFirst(extent) / r.available);
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
    final int percent = (_ratio * 100).round();

    Widget handle = CustomPaint(
      painter: _KkSplitHandlePainter(
        axis: widget.axis,
        line: active ? c.signal : c.line,
        grip: widget.enabled ? (active ? c.signal : c.inkFaint) : null,
        ground: c.bg000,
      ),
    );
    if (widget.enabled) {
      handle = FocusableActionDetector(
        focusNode: widget.focusNode,
        mouseCursor: h ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        shortcuts: _shortcuts,
        actions: _actions,
        onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        child: Semantics(
          container: true,
          slider: true,
          label: widget.semanticLabel ?? 'Split',
          value: '$percent%',
          increasedValue: '${math.min(100, percent + 5)}%',
          decreasedValue: '${math.max(0, percent - 5)}%',
          onIncrease: () => _nudge(24),
          onDecrease: () => _nudge(-24),
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
        ),
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

  /// [extent] limited so that both panes keep their minimum.
  double clampFirst(double extent) => _clampFirst(extent, _available);

  double _clampFirst(double extent, double available) {
    final double lo = math.min(_minFirst, available);
    final double hi = math.max(lo, available - _minSecond);
    return extent.clamp(lo, hi);
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

  double _crossIntrinsic(double Function(RenderBox child) of) =>
      math.max(_first == null ? 0 : of(_first!), _second == null ? 0 : of(_second!));

  @override
  double computeMinIntrinsicWidth(double height) => _horizontal
      ? _mainIntrinsic((RenderBox c) => c.getMinIntrinsicWidth(height))
      : _crossIntrinsic((RenderBox c) => c.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) => _horizontal
      ? _mainIntrinsic((RenderBox c) => c.getMaxIntrinsicWidth(height))
      : _crossIntrinsic((RenderBox c) => c.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) => _horizontal
      ? _crossIntrinsic((RenderBox c) => c.getMinIntrinsicHeight(double.infinity))
      : _mainIntrinsic((RenderBox c) => c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _horizontal
      ? _crossIntrinsic((RenderBox c) => c.getMaxIntrinsicHeight(double.infinity))
      : _mainIntrinsic((RenderBox c) => c.getMaxIntrinsicHeight(width));

  BoxConstraints _pane(double main, double minCross, double maxCross) => _horizontal
      ? BoxConstraints(minWidth: main, maxWidth: main, minHeight: minCross, maxHeight: maxCross)
      : BoxConstraints(minHeight: main, maxHeight: main, minWidth: minCross, maxWidth: maxCross);

  ({Size size, double available, double first, double cross}) _compute(
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

    final double paneCross = maxCross.isFinite ? maxCross : 0;
    final double paneMaxCross = maxCross.isFinite ? maxCross : double.infinity;
    double available;
    double first;
    Size sa = Size.zero;
    Size sb = Size.zero;
    if (maxMain.isFinite) {
      available = math.max(0, maxMain - _handleSize);
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
    final double cross = (maxCross.isFinite ? maxCross : math.max(crossOf(sa), crossOf(sb))).clamp(
      minCross,
      maxCross,
    );
    final double main = available + _handleSize;
    final Size size = constraints.constrain(_horizontal ? Size(main, cross) : Size(cross, main));
    return (size: size, available: available, first: first, cross: cross);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final ({Size size, double available, double first, double cross}) r = _compute(
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
        _horizontal
            ? BoxConstraints.tightFor(width: _handleSize, height: r.cross)
            : BoxConstraints.tightFor(width: r.cross, height: _handleSize),
      );
      (handle.parentData! as KkSplitParentData).offset = _horizontal ? Offset(r.first, 0) : Offset(0, r.first);
    }
    if (b != null) {
      final double start = r.first + _handleSize;
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('axis', axis))
      ..add(DoubleProperty('ratio', ratio))
      ..add(DoubleProperty('firstExtent', firstExtent));
  }
}
