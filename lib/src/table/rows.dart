import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'layout.dart';

/// The lazy list of body rows of a table.
///
/// Rows are built only near the visible range. Every row is [KkTableLink.rowExtent]
/// high plus the height of its detail block when it is expanded, so the row at
/// any scroll offset is found by arithmetic: jumping from the first to the
/// ten-thousandth row builds only the rows that end up on screen.
///
/// This class is not part of the public API.
class KkTableRowsSliver extends SliverMultiBoxAdaptorWidget {
  const KkTableRowsSliver({super.key, required super.delegate, required this.link, required this.version});

  final KkTableLink link;

  /// A value that changes whenever the rows or their heights do.
  final Object version;

  @override
  RenderKkTableRowsSliver createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderKkTableRowsSliver(childManager: element, link: link, version: version);
  }

  @override
  void updateRenderObject(BuildContext context, RenderKkTableRowsSliver renderObject) {
    renderObject
      ..link = link
      ..version = version;
  }
}

/// The render object behind [KkTableRowsSliver].
class RenderKkTableRowsSliver extends RenderSliverFixedExtentBoxAdaptor {
  RenderKkTableRowsSliver({required super.childManager, required KkTableLink link, required Object version})
    : _link = link,
      _version = version;

  KkTableLink _link;
  KkTableLink get link => _link;
  set link(KkTableLink value) {
    if (identical(value, _link)) return;
    if (attached) _link.removeDependent(this);
    _link = value;
    if (attached) _link.addDependent(this);
    markNeedsLayout();
  }

  Object _version;
  Object get version => _version;
  set version(Object value) {
    if (value == _version) return;
    _version = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.addDependent(this);
  }

  @override
  void detach() {
    _link.removeDependent(this);
    super.detach();
  }

  @override
  double? get itemExtent => null;

  @override
  ItemExtentBuilder? get itemExtentBuilder => _extentOf;

  double? _extentOf(int index, SliverLayoutDimensions dimensions) =>
      (index >= 0 && index < _link.rowCount) ? _link.extentOfRow(index) : null;

  @override
  double indexToLayoutOffset(double itemExtent, int index) => _link.rowOffset(index.clamp(0, _link.rowCount));

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) => _link.rowAt(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _link.rowAt(scrollOffset, strict: true);

  @override
  double computeMaxScrollOffset(SliverConstraints constraints, double itemExtent) => _link.rowsExtent;

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) => _link.rowsExtent;

  /// A detail block is given the height it had when it was last measured (an
  /// estimate before that) and reports its real height while it is laid out.
  /// When a report differs, the rows after it have moved: the pass is run
  /// again with the new heights, and if that moved the first row in view (the
  /// block was above it), the scroll offset is corrected by as much, so what
  /// is on screen stays where it is.
  @override
  void performLayout() {
    final double offset = constraints.scrollOffset;
    final int anchor = _link.rowCount == 0 ? 0 : _link.rowAt(offset);
    final double before = _link.rowOffset(anchor);
    int passes = 0;
    int version;
    do {
      version = _link.extentsVersion;
      super.performLayout();
      if (geometry?.scrollOffsetCorrection != null) return;
      passes++;
    } while (_link.extentsVersion != version && passes < 3);
    final double shift = _link.rowOffset(anchor) - before;
    if (shift.abs() > precisionErrorTolerance && offset + shift >= 0) {
      geometry = SliverGeometry(scrollOffsetCorrection: shift);
    }
  }

  /// The rows form one table for assistive technology: every child is a row
  /// node of its own, directly under this node.
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..role = SemanticsRole.table;
  }
}

class _ItemParentData extends ContainerBoxParentData<RenderBox> {}

/// One item of the body list: a row of cells and, under it, the detail block
/// of an expanded row.
///
/// The row is exactly [rowExtent] high. The detail takes its natural height
/// and reports it to the [link], which is where the list learns how high the
/// item is.
///
/// This class is not part of the public API.
class KkTableRowItem extends MultiChildRenderObjectWidget {
  KkTableRowItem({
    super.key,
    required this.link,
    required this.rowKey,
    required this.rowExtent,
    required Widget row,
    Widget? detail,
  }) : super(children: <Widget>[row, ?detail]);

  final KkTableLink link;
  final Object rowKey;
  final double rowExtent;

  @override
  RenderKkTableRowItem createRenderObject(BuildContext context) =>
      RenderKkTableRowItem(link: link, rowKey: rowKey, rowExtent: rowExtent);

  @override
  void updateRenderObject(BuildContext context, RenderKkTableRowItem renderObject) {
    renderObject
      ..link = link
      ..rowKey = rowKey
      ..rowExtent = rowExtent;
  }
}

/// The render object behind [KkTableRowItem].
class RenderKkTableRowItem extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ItemParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ItemParentData> {
  RenderKkTableRowItem({required KkTableLink link, required Object rowKey, required double rowExtent})
    : _link = link,
      _rowKey = rowKey,
      _rowExtent = rowExtent;

  KkTableLink _link;
  KkTableLink get link => _link;
  set link(KkTableLink value) {
    if (identical(value, _link)) return;
    _link = value;
    markNeedsLayout();
  }

  Object _rowKey;
  Object get rowKey => _rowKey;
  set rowKey(Object value) {
    if (value == _rowKey) return;
    _rowKey = value;
    markNeedsLayout();
  }

  double _rowExtent;
  double get rowExtent => _rowExtent;
  set rowExtent(double value) {
    if (value == _rowExtent) return;
    _rowExtent = value;
    markNeedsLayout();
  }

  bool _overflows = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ItemParentData) child.parentData = _ItemParentData();
  }

  RenderBox? get _detail => firstChild == null ? null : childAfter(firstChild!);

  double _widthFor(BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? constraints.maxWidth : _link.geometry.rowWidth;

  @override
  double computeMinIntrinsicWidth(double height) => firstChild?.getMinIntrinsicWidth(_rowExtent) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild?.getMaxIntrinsicWidth(_rowExtent) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => _rowExtent + (_detail?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) => _rowExtent + (_detail?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double w = _widthFor(constraints);
    final double d = _detail?.getDryLayout(BoxConstraints.tightFor(width: w)).height ?? 0;
    return constraints.constrain(Size(w, _rowExtent + d));
  }

  /// The row's baseline; the detail comes after it.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      firstChild?.getDryBaseline(BoxConstraints.tightFor(width: _widthFor(constraints), height: _rowExtent), baseline);

  @override
  void performLayout() {
    final double w = _widthFor(constraints);
    final RenderBox? row = firstChild;
    row?.layout(BoxConstraints.tightFor(width: w, height: _rowExtent));
    double natural = _rowExtent;
    final RenderBox? detail = _detail;
    if (detail != null) {
      detail.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
      (detail.parentData! as _ItemParentData).offset = Offset(0, _rowExtent);
      natural += detail.size.height;
      _link.reportDetail(_rowKey, detail.size.height);
    }
    size = constraints.constrain(Size(w, natural));
    // Until the list has heard of the detail's real height the item can be
    // shorter than its content for one pass.
    _overflows = natural > size.height + precisionErrorTolerance;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => firstChild?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (position.dy >= size.height) return false;
    return defaultHitTestChildren(result, position: position);
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overflows) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _overflows ? Offset.zero & size : null;
}
