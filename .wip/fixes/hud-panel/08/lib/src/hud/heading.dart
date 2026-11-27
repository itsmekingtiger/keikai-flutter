import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// The L-shaped heading: an upright vertical stem in signal, and beside it a
/// code with Latin capitals over one large CJK line.
///
/// ```dart
/// const KkHeading(stem: '設計言語', code: 'KK-00', en: 'keikai for flutter', main: '警戒')
/// ```
///
/// Vertical writing is kept for this and for panel spines; vertical and
/// horizontal always travel as one block.
class KkHeading extends StatelessWidget {
  const KkHeading({
    super.key,
    required this.main,
    this.stem,
    this.code,
    this.en,
    this.mainSize = 64,
    this.stemSize = 22,
    this.enSize = 18,
    this.stacked = false,
    this.squeeze = 0.8,
    this.color,
    this.accent,
  });

  /// The large CJK line.
  final String main;

  /// The vertical text of the stem. Without it the heading is stacked.
  final String? stem;

  /// A mono identifier before the Latin line, such as `KK-00`.
  final String? code;

  /// The Latin line; shown in capitals.
  final String? en;
  final double mainSize;
  final double stemSize;
  final double enSize;

  /// Drop the stem and stack the lines.
  final bool stacked;

  /// Horizontal compression of [main]; 1.0 turns it off.
  final double squeeze;

  /// Colour of [main]. Defaults to ink.
  final Color? color;

  /// Colour of the stem, its rule and the code. Defaults to signal.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color mark = accent ?? c.signal;
    final String? vertical = stacked ? null : stem;
    final String? id = code;
    final String? latin = en;
    final bool hasTop = id != null || latin != null;
    // The stem is set at a line height of 1.02: a column that wide, for the
    // glyphs as large as the text scale of the device makes them.
    final double stemColumn = MediaQuery.textScalerOf(context).scale(stemSize * theme.type.scale) * 1.02;

    return Semantics(
      header: true,
      label: <String>[?stem, ?id, ?latin, main].join(' '),
      child: ExcludeSemantics(
        child: _HeadingLayout(
          hasStem: vertical != null,
          hasTop: hasTop,
          columnGap: m.space3,
          rowGap: 2,
          children: <Widget>[
            if (vertical != null)
              KkBox(
                padding: EdgeInsets.only(right: m.space2),
                edges: KkEdges(right: KkSide(mark, width: m.stroke2)),
                alignment: Alignment.topLeft,
                child: KkTate(vertical, size: stemSize, color: mark, columnWidth: stemColumn),
              ),
            if (hasTop)
              KkRow(
                shrinkWrap: true,
                gap: m.space2,
                cross: KkCrossAlign.baseline,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (id != null) KkText.num(id, size: 11, weight: FontWeight.w600, spacing: 0.08, color: mark),
                  if (latin != null)
                    KkText.en(latin, size: enSize, weight: FontWeight.w800, spacing: 0.06, color: c.inkDim),
                ],
              ),
            KkText.cjk(main, size: mainSize, height: 0.92, spacing: -0.01, color: color ?? c.ink, squeeze: squeeze),
          ],
        ),
      ),
    );
  }
}

class _HeadingParentData extends ContainerBoxParentData<RenderBox> {}

/// A two-column, two-row grid: the stem spans both rows on the left; the top
/// line and the main line sit in the right column, each at the bottom of its
/// row. When the stem is taller than the two lines, the rows share the extra
/// height equally.
class _HeadingLayout extends MultiChildRenderObjectWidget {
  const _HeadingLayout({
    required this.hasStem,
    required this.hasTop,
    required this.columnGap,
    required this.rowGap,
    super.children,
  });

  final bool hasStem;
  final bool hasTop;
  final double columnGap;
  final double rowGap;

  @override
  _RenderHeading createRenderObject(BuildContext context) =>
      _RenderHeading(hasStem: hasStem, hasTop: hasTop, columnGap: columnGap, rowGap: rowGap);

  @override
  void updateRenderObject(BuildContext context, _RenderHeading renderObject) {
    renderObject
      ..hasStem = hasStem
      ..hasTop = hasTop
      ..columnGap = columnGap
      ..rowGap = rowGap;
  }
}

class _RenderHeading extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeadingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeadingParentData> {
  _RenderHeading({required bool hasStem, required bool hasTop, required double columnGap, required double rowGap})
    : _hasStem = hasStem,
      _hasTop = hasTop,
      _columnGap = columnGap,
      _rowGap = rowGap;

  bool _hasStem;
  bool get hasStem => _hasStem;
  set hasStem(bool value) {
    if (value == _hasStem) return;
    _hasStem = value;
    markNeedsLayout();
  }

  bool _hasTop;
  bool get hasTop => _hasTop;
  set hasTop(bool value) {
    if (value == _hasTop) return;
    _hasTop = value;
    markNeedsLayout();
  }

  double _columnGap;
  double get columnGap => _columnGap;
  set columnGap(double value) {
    if (value == _columnGap) return;
    _columnGap = value;
    markNeedsLayout();
  }

  double _rowGap;
  double get rowGap => _rowGap;
  set rowGap(double value) {
    if (value == _rowGap) return;
    _rowGap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeadingParentData) child.parentData = _HeadingParentData();
  }

  ({RenderBox? stem, RenderBox? top, RenderBox? main}) _slots() {
    RenderBox? child = firstChild;
    RenderBox? stem;
    RenderBox? top;
    if (_hasStem && child != null) {
      stem = child;
      child = childAfter(child);
    }
    if (_hasTop && child != null) {
      top = child;
      child = childAfter(child);
    }
    return (stem: stem, top: top, main: child);
  }

  @override
  double computeMinIntrinsicWidth(double height) => computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final ({RenderBox? stem, RenderBox? top, RenderBox? main}) s = _slots();
    final double left = s.stem == null ? 0 : s.stem!.getMaxIntrinsicWidth(double.infinity) + _columnGap;
    final double right = math.max(
      s.top?.getMaxIntrinsicWidth(double.infinity) ?? 0,
      s.main?.getMaxIntrinsicWidth(double.infinity) ?? 0,
    );
    return left + right;
  }

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final ({RenderBox? stem, RenderBox? top, RenderBox? main}) s = _slots();
    final double rows =
        (s.top == null ? 0 : s.top!.getMaxIntrinsicHeight(double.infinity) + _rowGap) +
        (s.main?.getMaxIntrinsicHeight(double.infinity) ?? 0);
    return math.max(rows, s.stem?.getMaxIntrinsicHeight(double.infinity) ?? 0);
  }

  /// The size, what the two lines are given and where the main line starts,
  /// worked out without laying anything out. Mirrors [performLayout].
  ({Size size, BoxConstraints right, double mainTop}) _measure(BoxConstraints constraints) {
    final ({RenderBox? stem, RenderBox? top, RenderBox? main}) s = _slots();
    final Size stemSize = s.stem?.getDryLayout(const BoxConstraints()) ?? Size.zero;
    final double left = s.stem == null ? 0 : stemSize.width + _columnGap;
    final double rightMax = constraints.maxWidth.isFinite ? math.max(0.0, constraints.maxWidth - left) : double.infinity;
    final BoxConstraints right = BoxConstraints(maxWidth: rightMax);
    final Size topSize = s.top?.getDryLayout(right) ?? Size.zero;
    final Size mainSize = s.main?.getDryLayout(right) ?? Size.zero;
    final double rows = topSize.height + (s.top != null ? _rowGap : 0) + mainSize.height;
    final double height = math.max(rows, stemSize.height);
    final double width = left + math.max(topSize.width, mainSize.width);
    final Size size = constraints.constrain(Size(s.stem == null ? width : math.max(width, stemSize.width), height));
    return (size: size, right: right, mainTop: height - mainSize.height);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints).size;

  /// The baseline of the main line, as in [computeDistanceToActualBaseline].
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final RenderBox? main = _slots().main;
    if (main == null) return null;
    final ({Size size, BoxConstraints right, double mainTop}) r = _measure(constraints);
    final double? d = main.getDryBaseline(r.right, baseline);
    return d == null ? null : d + r.mainTop;
  }

  @override
  void performLayout() {
    final ({RenderBox? stem, RenderBox? top, RenderBox? main}) s = _slots();
    final RenderBox? stem = s.stem;
    final RenderBox? top = s.top;
    final RenderBox? main = s.main;

    double left = 0;
    if (stem != null) {
      stem.layout(const BoxConstraints(), parentUsesSize: true);
      left = stem.size.width + _columnGap;
    }
    final double rightMax = constraints.maxWidth.isFinite ? math.max(0.0, constraints.maxWidth - left) : double.infinity;
    final BoxConstraints right = BoxConstraints(maxWidth: rightMax);
    top?.layout(right, parentUsesSize: true);
    main?.layout(right, parentUsesSize: true);

    final double topHeight = top?.size.height ?? 0;
    final double mainHeight = main?.size.height ?? 0;
    final double rows = topHeight + (top != null ? _rowGap : 0) + mainHeight;
    final double stemHeight = stem?.size.height ?? 0;
    final double height = math.max(rows, stemHeight);
    // The stem spans both rows; what it adds is split between them, and each
    // line stays at the bottom of its own row.
    final double extra = math.max(0.0, stemHeight - rows);
    final double share = top != null ? extra / 2 : extra;

    if (stem != null) {
      if (stem.size.height < height) {
        stem.layout(BoxConstraints.tightFor(width: stem.size.width, height: height), parentUsesSize: true);
      }
      (stem.parentData! as _HeadingParentData).offset = Offset.zero;
    }
    if (top != null) (top.parentData! as _HeadingParentData).offset = Offset(left, share);
    if (main != null) (main.parentData! as _HeadingParentData).offset = Offset(left, height - mainHeight);

    final double width = left + math.max(top?.size.width ?? 0, main?.size.width ?? 0);
    size = constraints.constrain(Size(stem == null ? width : math.max(width, stem.size.width), height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final RenderBox? main = _slots().main;
    if (main == null) return null;
    final double? d = main.getDistanceToActualBaseline(baseline);
    if (d == null) return null;
    return d + (main.parentData! as _HeadingParentData).offset.dy;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
