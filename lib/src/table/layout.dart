import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'column.dart';
import 'widths.dart';

/// What the parts of one table share while they are laid out: the resolved
/// column geometry, the widest cell seen in each column, and the height of
/// every row.
///
/// The header, every body row and the summary row are separate render
/// objects (the body rows live in a lazy list), so the column widths cannot
/// travel through constraints. They are resolved once, by the table's frame,
/// and read from here. Rows report the natural width of their cells and the
/// natural height of their detail blocks back; when a report changes the
/// layout, the frame resolves again in the same frame if it is the one laying
/// out, and on the next frame otherwise.
///
/// This class is not part of the public API.
class KkTableLink {
  // ── columns ──────────────────────────────────────────────────────────────

  /// The width rule of every column, in order.
  List<KkTableWidth> get columns => _columns;
  List<KkTableWidth> _columns = const <KkTableWidth>[];
  Object? _signature;

  /// Which columns report the natural width of their cells.
  bool measures(int column) => column < _columns.length && _columns[column].isContent;

  /// Sets the columns. A new [signature] (the column ids and anything that
  /// changes how wide a cell is) forgets the cell widths measured so far.
  void configure(List<KkTableWidth> columns, Object signature) {
    final bool reset = signature != _signature || columns.length != _cells.length;
    _columns = columns;
    _signature = signature;
    if (reset) _cells = List<double>.filled(columns.length, 0);
  }

  /// The widest cell seen so far in each column.
  List<double> get cells => _cells;
  List<double> _cells = <double>[];

  /// The resolved columns. Set by the frame.
  KkTableGeometry geometry = KkTableGeometry.empty;

  // ── rows ─────────────────────────────────────────────────────────────────

  int _count = 0;
  double _rowExtent = 32;
  List<int> _expanded = const <int>[];
  List<Object> _expandedKeys = const <Object>[];
  List<double>? _prefix;

  /// The height an expanded row's detail is given before it has been measured.
  double detailEstimate = 96;

  final Map<Object, double> _detailHeights = <Object, double>{};

  /// Counts every change of a row height: a new set of rows, a detail block
  /// measured at another height than the one it was given.
  int get extentsVersion => _extentsVersion;
  int _extentsVersion = 0;

  /// Sets the rows of the body: [count] rows of [rowExtent], of which the rows
  /// at the (ascending) indices [expanded], with the keys [expandedKeys], show
  /// a detail block under them. Returns whether anything changed.
  bool setRows({
    required int count,
    required double rowExtent,
    List<int> expanded = const <int>[],
    List<Object> expandedKeys = const <Object>[],
  }) {
    assert(expanded.length == expandedKeys.length);
    bool same = count == _count && rowExtent == _rowExtent && expanded.length == _expanded.length;
    for (int i = 0; same && i < expanded.length; i++) {
      same = expanded[i] == _expanded[i] && expandedKeys[i] == _expandedKeys[i];
    }
    if (same) return false;
    _count = count;
    _rowExtent = rowExtent;
    _expanded = expanded;
    _expandedKeys = expandedKeys;
    _prefix = null;
    _extentsVersion++;
    return true;
  }

  /// Forgets the measured height of every detail block that is not in [keep].
  void retainDetails(Set<Object> keep) {
    _detailHeights.removeWhere((Object key, double _) => !keep.contains(key));
  }

  /// The number of body rows.
  int get rowCount => _count;

  /// The height of a row without its detail.
  double get rowExtent => _rowExtent;

  /// The measured (or estimated) height of the detail block of the row [key].
  double detailHeight(Object key) => _detailHeights[key] ?? detailEstimate;

  List<double> get _sums {
    List<double>? p = _prefix;
    if (p == null) {
      p = List<double>.filled(_expanded.length + 1, 0);
      for (int i = 0; i < _expanded.length; i++) {
        p[i + 1] = p[i] + detailHeight(_expandedKeys[i]);
      }
      _prefix = p;
    }
    return p;
  }

  /// How many expanded rows come before row [index].
  int _expandedBefore(int index) {
    int lo = 0;
    int hi = _expanded.length;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (_expanded[mid] < index) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The top of row [index] in the body (also defined for `index == rowCount`,
  /// where it is the total height).
  double rowOffset(int index) => index * _rowExtent + _sums[_expandedBefore(index)];

  /// The height of row [index] with its detail.
  double extentOfRow(int index) {
    final int k = _expandedBefore(index);
    if (k < _expanded.length && _expanded[k] == index) return _rowExtent + detailHeight(_expandedKeys[k]);
    return _rowExtent;
  }

  /// The height of all rows.
  double get rowsExtent => _count * _rowExtent + _sums.last;

  /// The last row whose top is at or before [offset] (or, with [strict],
  /// before it). 0 when there is none.
  int rowAt(double offset, {bool strict = false}) {
    if (_count <= 0) return 0;
    int lo = 0;
    int hi = _count - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      final double top = rowOffset(mid);
      if (strict ? top < offset - precisionErrorTolerance : top <= offset + precisionErrorTolerance) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The height the body takes when nothing limits it: the rows, or whatever
  /// stands in for them (the empty block). Set by the frame.
  double bodyExtent = 0;

  // ── feedback ─────────────────────────────────────────────────────────────

  /// A cell turned out wider than its column knew.
  bool widthsDirty = false;

  /// A detail block turned out to be of another height than assumed.
  bool extentsDirty = false;

  /// True while the frame is in its `performLayout`.
  bool inFrameLayout = false;
  bool _pokeScheduled = false;

  /// The render object that resolves the columns.
  RenderObject? frame;

  /// The header row, asked for the natural width of its cells.
  RenderKkTableCells? header;

  /// The render object that stacks header, rows and summary. It reads
  /// [bodyExtent], so the frame marks it when that changes.
  RenderObject? grid;

  final Set<RenderObject> _dependents = <RenderObject>{};

  /// Registers a render object that is laid out from [geometry] or from the
  /// row extents and must be laid out again when they change.
  void addDependent(RenderObject object) => _dependents.add(object);

  void removeDependent(RenderObject object) => _dependents.remove(object);

  /// The natural width (padding included) of a cell of [column].
  void reportCell(int column, double width) {
    if (column >= _cells.length || !width.isFinite) return;
    if (width > _cells[column] + 0.01) {
      _cells[column] = width;
      widthsDirty = true;
      _poke();
    }
  }

  /// The natural height of the detail block of the row [key].
  void reportDetail(Object key, double height) {
    if (!height.isFinite || height < 0) return;
    final double? old = _detailHeights[key];
    if (old != null && (old - height).abs() < 0.01) return;
    _detailHeights[key] = height;
    if (old == null && (detailEstimate - height).abs() < 0.01) return;
    _prefix = null;
    _extentsVersion++;
    extentsDirty = true;
    _poke();
  }

  /// Marks everything that reads this link as needing layout. Only legal
  /// inside the frame's layout callback or outside layout.
  void markDependentsNeedLayout() {
    for (final RenderObject object in _dependents) {
      if (object.attached) object.markNeedsLayout();
    }
    final RenderKkTableCells? h = header;
    if (h != null && h.attached) h.markNeedsLayout();
  }

  /// When a report arrives while the frame is not laying out (a row scrolled
  /// into view, a cell that grew by itself), the frame is laid out again on
  /// the next frame.
  void _poke() {
    if (inFrameLayout || _pokeScheduled) return;
    _pokeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _pokeScheduled = false;
      final RenderObject? f = frame;
      if (f != null && f.attached) f.markNeedsLayout();
    });
  }

  /// Asks for another layout of the frame after this frame.
  void pokeFrame() => _poke();
}

/// The colours a row of cells paints under and over its cells. The row's
/// state changes these without rebuilding the cells; the render object
/// repaints when notified.
///
/// This class is not part of the public API.
class KkTableRowPaint extends ChangeNotifier {
  /// The ground of the whole row (hover, selected, critical). Null is clear.
  Color? get background => _background;
  Color? _background;

  /// The colour of the progress fill across the row, and how far it goes.
  Color? get fillColor => _fillColor;
  Color? _fillColor;
  double get fill => _fill;
  double _fill = 0;

  /// A 1px line along the bottom (body rows, header) or the top (summary).
  Color? get lineBottom => _lineBottom;
  Color? _lineBottom;
  Color? get lineTop => _lineTop;
  Color? _lineTop;
  double get lineWidth => _lineWidth;
  double _lineWidth = 1;

  /// The strobe over the whole row after its level changed.
  Color? get shift => _shift;
  Color? _shift;

  /// The flash behind each cell after its value changed.
  List<Color?> get flashes => _flashes;
  List<Color?> _flashes = const <Color?>[];

  /// The keyboard focus look: a line inside the row's edge.
  Color? get focus => _focus;
  Color? _focus;
  double get focusWidth => _focusWidth;
  double _focusWidth = 2;

  /// Sets the resting look.
  void setLook({
    Color? background,
    Color? fillColor,
    double fill = 0,
    Color? lineBottom,
    Color? lineTop,
    double lineWidth = 1,
    Color? focus,
    double focusWidth = 2,
  }) {
    if (background == _background &&
        fillColor == _fillColor &&
        fill == _fill &&
        lineBottom == _lineBottom &&
        lineTop == _lineTop &&
        lineWidth == _lineWidth &&
        focus == _focus &&
        focusWidth == _focusWidth) {
      return;
    }
    _background = background;
    _fillColor = fillColor;
    _fill = fill;
    _lineBottom = lineBottom;
    _lineTop = lineTop;
    _lineWidth = lineWidth;
    _focus = focus;
    _focusWidth = focusWidth;
    notifyListeners();
  }

  /// Sets the running effects.
  void setEffects({Color? shift, List<Color?> flashes = const <Color?>[]}) {
    bool same = shift == _shift && flashes.length == _flashes.length;
    for (int i = 0; same && i < flashes.length; i++) {
      same = flashes[i] == _flashes[i];
    }
    if (same) return;
    _shift = shift;
    _flashes = flashes;
    notifyListeners();
  }
}

/// Parent data of a cell in a [KkTableCells] row.
class KkTableCellParentData extends ContainerBoxParentData<RenderBox> {}

/// One row of cells laid out on the table's columns: the header, a body row
/// or the summary row.
///
/// Every child is one column's cell and is made exactly as wide as that
/// column and as high as the row. The widths come from the [link].
///
/// This class is not part of the public API.
class KkTableCells extends MultiChildRenderObjectWidget {
  const KkTableCells({
    super.key,
    required this.link,
    required this.height,
    this.header = false,
    this.measure = false,
    this.look,
    super.children,
  });

  final KkTableLink link;

  /// The height of the row.
  final double height;

  /// This is the header row: the frame asks it for the natural width of its
  /// cells.
  final bool header;

  /// Report the natural width of the cells of content columns.
  final bool measure;
  final KkTableRowPaint? look;

  @override
  RenderKkTableCells createRenderObject(BuildContext context) =>
      RenderKkTableCells(link: link, height: height, header: header, measure: measure, look: look);

  @override
  void updateRenderObject(BuildContext context, RenderKkTableCells renderObject) {
    renderObject
      ..link = link
      ..height = height
      ..header = header
      ..measure = measure
      ..look = look;
  }
}

/// The render object behind [KkTableCells].
class RenderKkTableCells extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkTableCellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkTableCellParentData> {
  RenderKkTableCells({
    required KkTableLink link,
    required double height,
    bool header = false,
    bool measure = false,
    KkTableRowPaint? look,
  }) : _link = link,
       _height = height,
       _header = header,
       _measure = measure,
       _look = look;

  KkTableLink _link;
  KkTableLink get link => _link;
  set link(KkTableLink value) {
    if (identical(value, _link)) return;
    if (attached) _unregister();
    _link = value;
    if (attached) _register();
    markNeedsLayout();
  }

  double _height;
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  bool _header;
  bool get header => _header;
  set header(bool value) {
    if (value == _header) return;
    if (attached) _unregister();
    _header = value;
    if (attached) _register();
  }

  bool _measure;
  bool get measure => _measure;
  set measure(bool value) {
    if (value == _measure) return;
    _measure = value;
    markNeedsLayout();
  }

  KkTableRowPaint? _look;
  KkTableRowPaint? get look => _look;
  set look(KkTableRowPaint? value) {
    if (identical(value, _look)) return;
    if (attached) _look?.removeListener(markNeedsPaint);
    _look = value;
    if (attached) _look?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  void _register() {
    if (_header) {
      _link.header = this;
    } else {
      _link.addDependent(this);
    }
  }

  void _unregister() {
    if (_header) {
      if (identical(_link.header, this)) _link.header = null;
    } else {
      _link.removeDependent(this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
    _look?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _unregister();
    _look?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkTableCellParentData) child.parentData = KkTableCellParentData();
  }

  /// The natural width of each cell (its content and its padding).
  List<double> naturalWidths() {
    final List<double> out = <double>[];
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      out.add(child.getMaxIntrinsicWidth(_height));
    }
    return out;
  }

  double _naturalWidth() {
    double w = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      w += child.getMaxIntrinsicWidth(_height);
    }
    return w;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth();

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  Size _sizeFor(BoxConstraints constraints) => constraints.constrain(
    Size(constraints.hasBoundedWidth ? constraints.maxWidth : _link.geometry.rowWidth, _height),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  /// The baseline of the first cell that has one, as in
  /// [computeDistanceToActualBaseline].
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final Size s = _sizeFor(constraints);
    final KkTableGeometry g = _link.geometry;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final double w = i < g.length ? g.widths[i] : 0;
      final double? d = child.getDryBaseline(BoxConstraints.tightFor(width: w, height: s.height), baseline);
      if (d != null) return d;
    }
    return null;
  }

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    final KkTableGeometry g = _link.geometry;
    int i = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child), i++) {
      final bool known = i < g.length;
      child.layout(BoxConstraints.tightFor(width: known ? g.widths[i] : 0, height: size.height));
      (child.parentData! as KkTableCellParentData).offset = Offset(known ? g.offsets[i] : g.total, 0);
      if (_measure && _link.measures(i)) {
        _link.reportCell(i, child.getMaxIntrinsicWidth(size.height));
      }
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final KkTableRowPaint? p = _look;
    final Rect rect = offset & size;
    if (p != null && !rect.isEmpty) {
      final Canvas canvas = context.canvas;
      final Paint paint = Paint();
      final Color? background = p.background;
      if (background != null && background.a > 0) canvas.drawRect(rect, paint..color = background);
      final Color? fillColor = p.fillColor;
      if (fillColor != null && p.fill > 0) {
        final double f = p.fill.isNaN ? 0 : p.fill.clamp(0.0, 1.0);
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width * f, rect.height), paint..color = fillColor);
      }
      final Color? shift = p.shift;
      if (shift != null && shift.a > 0) canvas.drawRect(rect, paint..color = shift);
      final List<Color?> flashes = p.flashes;
      if (flashes.isNotEmpty) {
        final KkTableGeometry g = _link.geometry;
        for (int i = 0; i < flashes.length && i < g.length; i++) {
          final Color? c = flashes[i];
          if (c == null || c.a <= 0) continue;
          canvas.drawRect(
            Rect.fromLTWH(rect.left + g.offsets[i], rect.top, g.widths[i], rect.height),
            paint..color = c,
          );
        }
      }
      final double line = math.min(p.lineWidth, rect.height);
      final Color? top = p.lineTop;
      if (top != null && line > 0) {
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, line), paint..color = top);
      }
      final Color? bottom = p.lineBottom;
      if (bottom != null && line > 0) {
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - line, rect.width, line), paint..color = bottom);
      }
    }
    defaultPaint(context, offset);
    final Color? focus = p?.focus;
    if (p != null && focus != null && rect.shortestSide > p.focusWidth * 2) {
      context.canvas.drawRect(
        rect.deflate(p.focusWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.focusWidth
          ..color = focus,
      );
    }
  }
}
