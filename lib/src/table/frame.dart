import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'layout.dart';
import 'widths.dart';

/// The parts of a table, top to bottom.
enum KkTableFrameSlot {
  /// The toolbar band.
  band,

  /// The 2px loading rail.
  rail,

  /// The header, the scrolling rows and the summary row.
  area,

  /// What stands in for the rows when there are none.
  empty,

  /// The footer with the pager.
  footer,

  /// The text announced to assistive technology.
  live,
}

/// Lays out the parts of a table and resolves its columns.
///
/// The frame knows how wide the table is, so it is where the column widths
/// are worked out (see [kkResolveTableWidths]) and written to the [link] for
/// every row to read. It gives the area the height that is left when its own
/// height is fixed, and the height of all rows when it is not, so the same
/// table fills a grid cell or sits in a scrolling page.
///
/// This class is not part of the public API.
class KkTableFrame extends SlottedMultiChildRenderObjectWidget<KkTableFrameSlot, RenderBox> {
  const KkTableFrame({
    super.key,
    required this.link,
    required this.headerHeight,
    this.summaryHeight = 0,
    this.band,
    this.rail,
    required this.area,
    this.empty,
    this.footer,
    this.live,
  });

  final KkTableLink link;
  final double headerHeight;

  /// The height of the summary row; 0 without one.
  final double summaryHeight;
  final Widget? band;
  final Widget? rail;
  final Widget area;
  final Widget? empty;
  final Widget? footer;
  final Widget? live;

  @override
  Iterable<KkTableFrameSlot> get slots => KkTableFrameSlot.values;

  @override
  Widget? childForSlot(KkTableFrameSlot slot) => switch (slot) {
    KkTableFrameSlot.band => band,
    KkTableFrameSlot.rail => rail,
    KkTableFrameSlot.area => area,
    KkTableFrameSlot.empty => empty,
    KkTableFrameSlot.footer => footer,
    KkTableFrameSlot.live => live,
  };

  @override
  RenderKkTableFrame createRenderObject(BuildContext context) =>
      RenderKkTableFrame(link: link, headerHeight: headerHeight, summaryHeight: summaryHeight);

  @override
  void updateRenderObject(BuildContext context, RenderKkTableFrame renderObject) {
    renderObject
      ..link = link
      ..headerHeight = headerHeight
      ..summaryHeight = summaryHeight
      // The table was rebuilt: its columns, rows or header may have changed,
      // and none of that reaches the frame through its children when they are
      // relayout boundaries. Resolving again costs next to nothing when
      // nothing moved.
      ..markNeedsLayout();
  }
}

/// The render object behind [KkTableFrame].
class RenderKkTableFrame extends RenderBox with SlottedContainerRenderObjectMixin<KkTableFrameSlot, RenderBox> {
  RenderKkTableFrame({required KkTableLink link, required double headerHeight, double summaryHeight = 0})
    : _link = link,
      _headerHeight = headerHeight,
      _summaryHeight = summaryHeight;

  KkTableLink _link;
  KkTableLink get link => _link;
  set link(KkTableLink value) {
    if (identical(value, _link)) return;
    if (attached && identical(_link.frame, this)) _link.frame = null;
    _link = value;
    if (attached) _link.frame = this;
    markNeedsLayout();
  }

  double _headerHeight;
  double get headerHeight => _headerHeight;
  set headerHeight(double value) {
    if (value == _headerHeight) return;
    _headerHeight = value;
    markNeedsLayout();
  }

  double _summaryHeight;
  double get summaryHeight => _summaryHeight;
  set summaryHeight(double value) {
    if (value == _summaryHeight) return;
    _summaryHeight = value;
    markNeedsLayout();
  }

  RenderBox? get _band => childForSlot(KkTableFrameSlot.band);
  RenderBox? get _rail => childForSlot(KkTableFrameSlot.rail);
  RenderBox? get _area => childForSlot(KkTableFrameSlot.area);
  RenderBox? get _empty => childForSlot(KkTableFrameSlot.empty);
  RenderBox? get _footer => childForSlot(KkTableFrameSlot.footer);
  RenderBox? get _live => childForSlot(KkTableFrameSlot.live);

  /// Back to front.
  @override
  Iterable<RenderBox> get children => <RenderBox>[?_area, ?_empty, ?_rail, ?_band, ?_footer, ?_live];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.frame = this;
  }

  @override
  void detach() {
    if (identical(_link.frame, this)) _link.frame = null;
    super.detach();
  }

  // ── columns ──────────────────────────────────────────────────────────────

  KkTableGeometry _geometryFor(double available) {
    final RenderKkTableCells? header = _link.header;
    final List<double> natural = (header != null && header.attached) ? header.naturalWidths() : const <double>[];
    return kkResolveTableWidths(_link.columns, header: natural, cells: _link.cells, available: available);
  }

  static double _available(BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;

  // ── intrinsics ───────────────────────────────────────────────────────────
  //
  // The table can be narrower than its columns (it scrolls sideways) and
  // lower than its rows (it scrolls), so its minimum is what does not scroll.

  double _fixedHeight(double Function(RenderBox child) of) {
    double h = 0;
    for (final RenderBox? child in <RenderBox?>[_band, _rail, _footer]) {
      if (child != null) h += of(child);
    }
    return h;
  }

  double _bodyNatural(double? emptyHeight) => emptyHeight ?? _link.rowsExtent;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _geometryFor(double.infinity).total;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _fixedHeight((RenderBox c) => c.getMinIntrinsicHeight(width)) + _headerHeight + _summaryHeight;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _fixedHeight((RenderBox c) => c.getMaxIntrinsicHeight(width)) +
      _headerHeight +
      _summaryHeight +
      _bodyNatural(_empty?.getMaxIntrinsicHeight(width));

  // ── layout ───────────────────────────────────────────────────────────────

  /// The height of the area: all that is left of a fixed height, otherwise
  /// the header, the rows and the summary, up to what is left.
  double _areaHeight(BoxConstraints constraints, double fixed, double bodyNatural) {
    final double left = math.max(0.0, constraints.maxHeight - fixed);
    if (constraints.hasTightHeight) return left;
    final double natural = _headerHeight + bodyNatural + _summaryHeight;
    final double least = math.max(0.0, constraints.minHeight - fixed);
    return math.max(least, math.min(natural, left));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double available = _available(constraints);
    final double width = available.isFinite
        ? available
        : math.max(constraints.minWidth, _geometryFor(available).rowWidth);
    final BoxConstraints row = BoxConstraints.tightFor(width: width);
    final double fixed = _fixedHeight((RenderBox c) => c.getDryLayout(row).height);
    final double? emptyHeight = _empty?.getDryLayout(row).height;
    return constraints.constrain(Size(width, fixed + _areaHeight(constraints, fixed, _bodyNatural(emptyHeight))));
  }

  /// A table has no baseline.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  double _areaTop = 0;
  double _areaExtent = 0;

  /// Lays out and places the parts; returns the size they take together.
  Size _layoutParts(double width) {
    final BoxConstraints row = BoxConstraints.tightFor(width: width);
    double fixed = 0;
    double y = 0;
    final RenderBox? band = _band;
    if (band != null) {
      band.layout(row, parentUsesSize: true);
      (band.parentData! as BoxParentData).offset = Offset(0, y);
      y += band.size.height;
      fixed += band.size.height;
    }
    final RenderBox? rail = _rail;
    if (rail != null) {
      rail.layout(row, parentUsesSize: true);
      (rail.parentData! as BoxParentData).offset = Offset(0, y);
      y += rail.size.height;
      fixed += rail.size.height;
    }
    final RenderBox? footer = _footer;
    if (footer != null) {
      footer.layout(row, parentUsesSize: true);
      fixed += footer.size.height;
    }
    final RenderBox? empty = _empty;
    double? emptyHeight;
    if (empty != null) {
      empty.layout(row, parentUsesSize: true);
      emptyHeight = empty.size.height;
    }
    final double bodyNatural = _bodyNatural(emptyHeight);
    if (bodyNatural != _link.bodyExtent) {
      _link.bodyExtent = bodyNatural;
      // The grid places the summary row from this; its constraints may well
      // be the same as before.
      final RenderObject? grid = _link.grid;
      if (grid != null && grid.attached) {
        invokeLayoutCallback<BoxConstraints>((BoxConstraints _) => grid.markNeedsLayout());
      }
    }
    final double areaHeight = _areaHeight(constraints, fixed, bodyNatural);
    final RenderBox? area = _area;
    if (area != null) {
      area.layout(BoxConstraints.tightFor(width: width, height: areaHeight));
      (area.parentData! as BoxParentData).offset = Offset(0, y);
    }
    _areaTop = y;
    _areaExtent = areaHeight;
    if (empty != null) (empty.parentData! as BoxParentData).offset = Offset(0, y + _headerHeight);
    if (footer != null) (footer.parentData! as BoxParentData).offset = Offset(0, y + areaHeight);
    return Size(width, fixed + areaHeight);
  }

  bool _resolve(double available) {
    final KkTableGeometry g = _geometryFor(available);
    if (g == _link.geometry) return false;
    _link.geometry = g;
    return true;
  }

  @override
  void performLayout() {
    final double available = _available(constraints);
    _link.inFrameLayout = true;
    try {
      // A report that arrived between frames (a row scrolled into view) is
      // already in the link; what was laid out before it is stale.
      final bool stale = _link.widthsDirty || _link.extentsDirty;
      bool changed = _resolve(available);
      double width = available.isFinite ? available : math.max(constraints.minWidth, _link.geometry.rowWidth);
      if (changed || stale) {
        // Rows that are already laid out read the columns from the link, not
        // from their constraints, so they have to be told.
        invokeLayoutCallback<BoxConstraints>((BoxConstraints _) => _link.markDependentsNeedLayout());
      }
      _link
        ..widthsDirty = false
        ..extentsDirty = false;
      Size natural = _layoutParts(width);
      // Rows that were built during this pass may have reported wider cells
      // or detail blocks of another height. Take that in at once, so the
      // first frame is already right.
      int passes = 0;
      while ((_link.widthsDirty || _link.extentsDirty) && passes < 4) {
        passes++;
        changed = _link.widthsDirty && _resolve(available);
        final bool extents = _link.extentsDirty;
        _link
          ..widthsDirty = false
          ..extentsDirty = false;
        if (!changed && !extents) break;
        width = available.isFinite ? available : math.max(constraints.minWidth, _link.geometry.rowWidth);
        invokeLayoutCallback<BoxConstraints>((BoxConstraints _) => _link.markDependentsNeedLayout());
        natural = _layoutParts(width);
      }
      // Only now: the size is what the last pass gave, never a provisional one.
      size = constraints.constrain(natural);
    } finally {
      _link.inFrameLayout = false;
    }
    if (_link.widthsDirty || _link.extentsDirty) _link.pokeFrame();
    final RenderBox? live = _live;
    if (live != null) {
      live.layout(BoxConstraints.tight(const Size(1, 1)));
      (live.parentData! as BoxParentData).offset = Offset.zero;
    }
  }

  // ── hit testing and paint ────────────────────────────────────────────────

  Rect _clipFor(RenderBox child) {
    // The empty block is cut to the body region; everything else to the frame.
    if (identical(child, _empty)) {
      final double top = _areaTop + _headerHeight;
      final double bottom = math.max(top, _areaTop + _areaExtent - _summaryHeight);
      return Rect.fromLTRB(0, top, size.width, math.min(bottom, size.height));
    }
    return Offset.zero & size;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & size).contains(position)) return false;
    for (final RenderBox child in children.toList().reversed) {
      if (identical(child, _live)) continue;
      if (!_clipFor(child).contains(position)) continue;
      final BoxParentData pd = child.parentData! as BoxParentData;
      final bool hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  bool get _overflows {
    for (final RenderBox child in children) {
      if (identical(child, _live)) continue;
      final Offset o = (child.parentData! as BoxParentData).offset;
      if (o.dy + child.size.height > size.height + precisionErrorTolerance) return true;
      if (o.dx + child.size.width > size.width + precisionErrorTolerance) return true;
    }
    return false;
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<ClipRectLayer> _emptyClipLayer = LayerHandle<ClipRectLayer>();

  void _paintChildren(PaintingContext context, Offset offset) {
    for (final RenderBox child in children) {
      final Offset at = offset + (child.parentData! as BoxParentData).offset;
      if (identical(child, _empty)) {
        final Rect clip = _clipFor(child);
        if (clip.isEmpty) {
          _emptyClipLayer.layer = null;
          continue;
        }
        final Offset o = (child.parentData! as BoxParentData).offset;
        if (o.dy + child.size.height > clip.bottom + precisionErrorTolerance) {
          _emptyClipLayer.layer = context.pushClipRect(
            needsCompositing,
            offset,
            clip,
            (PaintingContext context, Offset offset) => context.paintChild(child, offset + o),
            oldLayer: _emptyClipLayer.layer,
          );
          continue;
        }
        _emptyClipLayer.layer = null;
      }
      context.paintChild(child, at);
    }
    if (_empty == null) _emptyClipLayer.layer = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      _clipLayer.layer = null;
      _emptyClipLayer.layer = null;
      return;
    }
    if (_overflows) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildren,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      _paintChildren(context, offset);
    }
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _emptyClipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clipFor(child as RenderBox);
}

/// The slots of [KkTableGrid].
enum KkTableGridSlot { header, body, summary }

/// The header row, the scrolling rows and the summary row, one above the
/// other and all as wide as a row. This is what scrolls sideways when the
/// columns are wider than the table.
///
/// The body is as high as its rows, or lower when there is not that much
/// room; the summary row follows it directly.
///
/// This class is not part of the public API.
class KkTableGrid extends SlottedMultiChildRenderObjectWidget<KkTableGridSlot, RenderBox> {
  const KkTableGrid({
    super.key,
    required this.link,
    required this.headerHeight,
    this.summaryHeight = 0,
    required this.header,
    this.body,
    this.summary,
  });

  final KkTableLink link;
  final double headerHeight;
  final double summaryHeight;
  final Widget header;
  final Widget? body;
  final Widget? summary;

  @override
  Iterable<KkTableGridSlot> get slots => KkTableGridSlot.values;

  @override
  Widget? childForSlot(KkTableGridSlot slot) => switch (slot) {
    KkTableGridSlot.header => header,
    KkTableGridSlot.body => body,
    KkTableGridSlot.summary => summary,
  };

  @override
  RenderKkTableGrid createRenderObject(BuildContext context) =>
      RenderKkTableGrid(link: link, headerHeight: headerHeight, summaryHeight: summaryHeight);

  @override
  void updateRenderObject(BuildContext context, RenderKkTableGrid renderObject) {
    renderObject
      ..link = link
      ..headerHeight = headerHeight
      ..summaryHeight = summaryHeight;
  }
}

/// The render object behind [KkTableGrid].
class RenderKkTableGrid extends RenderBox with SlottedContainerRenderObjectMixin<KkTableGridSlot, RenderBox> {
  RenderKkTableGrid({required KkTableLink link, required double headerHeight, double summaryHeight = 0})
    : _link = link,
      _headerHeight = headerHeight,
      _summaryHeight = summaryHeight;

  KkTableLink _link;
  KkTableLink get link => _link;
  set link(KkTableLink value) {
    if (identical(value, _link)) return;
    if (attached) {
      _link.removeDependent(this);
      if (identical(_link.grid, this)) _link.grid = null;
    }
    _link = value;
    if (attached) {
      _link
        ..addDependent(this)
        ..grid = this;
    }
    markNeedsLayout();
  }

  double _headerHeight;
  double get headerHeight => _headerHeight;
  set headerHeight(double value) {
    if (value == _headerHeight) return;
    _headerHeight = value;
    markNeedsLayout();
  }

  double _summaryHeight;
  double get summaryHeight => _summaryHeight;
  set summaryHeight(double value) {
    if (value == _summaryHeight) return;
    _summaryHeight = value;
    markNeedsLayout();
  }

  RenderBox? get _header => childForSlot(KkTableGridSlot.header);
  RenderBox? get _body => childForSlot(KkTableGridSlot.body);
  RenderBox? get _summary => childForSlot(KkTableGridSlot.summary);

  /// Back to front: the header and the summary stay over the rows.
  @override
  Iterable<RenderBox> get children => <RenderBox>[?_body, ?_summary, ?_header];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link
      ..addDependent(this)
      ..grid = this;
  }

  @override
  void detach() {
    _link.removeDependent(this);
    if (identical(_link.grid, this)) _link.grid = null;
    super.detach();
  }

  double get _natural => _headerHeight + _link.bodyExtent + _summaryHeight;

  @override
  double computeMinIntrinsicWidth(double height) => _link.geometry.rowWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _link.geometry.rowWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _headerHeight + _summaryHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _natural;

  Size _sizeFor(BoxConstraints constraints) {
    final double w = math.max(_link.geometry.rowWidth, constraints.minWidth);
    final double h = constraints.hasBoundedHeight ? constraints.maxHeight : _natural;
    return constraints.constrain(Size(w, h));
  }

  double _bodyHeight(Size size) =>
      math.max(0.0, math.min(_link.bodyExtent, size.height - _headerHeight - _summaryHeight));

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  bool _overflows = false;

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    final double w = size.width;
    final double bodyHeight = _bodyHeight(size);
    final RenderBox? header = _header;
    if (header != null) {
      header.layout(BoxConstraints.tightFor(width: w, height: _headerHeight));
      (header.parentData! as BoxParentData).offset = Offset.zero;
    }
    final RenderBox? body = _body;
    if (body != null) {
      body.layout(BoxConstraints.tightFor(width: w, height: bodyHeight));
      (body.parentData! as BoxParentData).offset = Offset(0, _headerHeight);
    }
    final RenderBox? summary = _summary;
    if (summary != null) {
      summary.layout(BoxConstraints.tightFor(width: w, height: _summaryHeight));
      (summary.parentData! as BoxParentData).offset = Offset(0, _headerHeight + bodyHeight);
    }
    _overflows = _headerHeight + bodyHeight + _summaryHeight > size.height + precisionErrorTolerance;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & size).contains(position)) return false;
    for (final RenderBox child in children.toList().reversed) {
      final BoxParentData pd = child.parentData! as BoxParentData;
      final bool hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  void _paintChildren(PaintingContext context, Offset offset) {
    for (final RenderBox child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overflows) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildren,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      _paintChildren(context, offset);
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
