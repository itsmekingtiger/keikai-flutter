import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';

/// The label row above a field: CJK title, Latin subtitle and, at the right,
/// the `REQ` mark of a required field.
class KkFieldLabel extends StatelessWidget {
  const KkFieldLabel({
    super.key,
    this.cjk,
    this.en,
    this.isRequired = false,
    this.requiredMark = 'REQ',
    this.trailing,
  });

  final String? cjk;
  final String? en;

  /// Show [requiredMark] at the right.
  final bool isRequired;
  final String requiredMark;

  /// A widget at the right, after the required mark.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final String? title = cjk;
    final String? sub = en;
    final Widget? tail = trailing;
    return KkRow(
      gap: theme.metrics.space2,
      cross: KkCrossAlign.baseline,
      clip: Clip.hardEdge,
      children: <Widget>[
        if (title != null && title.isNotEmpty) KkText.cjk(title, size: 13, height: 1.55, color: c.ink, squeeze: 0.8),
        if (sub != null && sub.isNotEmpty)
          KkText.en(sub, size: 11, weight: FontWeight.w600, height: 1.55, spacing: 0.14, color: c.inkDim),
        const KkSpacer(),
        if (isRequired) KkText.num(requiredMark, size: 9, weight: FontWeight.w600, spacing: 0.08, color: c.signal),
        if (tail != null) KkAlignSelf(align: KkCrossAlign.center, child: tail),
      ],
    );
  }
}

/// The box of a field: panel-coloured ground with a 1px border that tells the
/// state.
///
/// * idle: faint ink; hovered: dim ink;
/// * focused: signal border doubled by a 1px inner ring, and four corner
///   brackets sitting 5px outside;
/// * error: all of that in alert;
/// * disabled: dashed, in the offline colour.
///
/// The focus ring takes no room: the content does not move when focus comes
/// and goes.
class KkFieldBox extends StatelessWidget {
  const KkFieldBox({
    super.key,
    this.focused = false,
    this.hovered = false,
    this.error = false,
    this.enabled = true,
    this.multiline = false,
    this.height = 36,
    this.padding,
    this.brackets = true,
    this.fill,
    required this.child,
  });

  final bool focused;
  final bool hovered;
  final bool error;
  final bool enabled;

  /// Let the box grow with its content instead of fixing [height].
  final bool multiline;

  /// Height of a single-line box, border included.
  final double height;

  /// Space between the border and the content. Defaults to 12px left and
  /// right (plus 8px top and bottom when [multiline]).
  final EdgeInsets? padding;

  /// Show the corner brackets while focused.
  final bool brackets;

  /// Defaults to the panel colour (bg-100).
  final Color? fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool active = focused && enabled;
    final Color accent = error ? c.alert : c.signal;
    final Color edge = !enabled
        ? c.offline
        : active
        ? accent
        : error
        ? c.alert
        : hovered
        ? c.inkDim
        : c.inkFaint;
    // Focus doubles the border with an inner ring; shave the padding by the
    // same amount so nothing shifts.
    final double ring = active ? m.stroke1 : 0;
    final EdgeInsets base =
        padding ??
        (multiline
            ? EdgeInsets.symmetric(horizontal: m.space3, vertical: m.space2)
            : EdgeInsets.symmetric(horizontal: m.space3));
    final EdgeInsets pad = EdgeInsets.fromLTRB(
      math.max(0, base.left - ring),
      math.max(0, base.top - ring),
      math.max(0, base.right - ring),
      math.max(0, base.bottom - ring),
    );
    return KkBox(
      height: multiline ? null : height,
      padding: pad,
      decoration: KkDecoration(
        fill: fill ?? c.bg100,
        edges: KkEdges.line(edge, width: m.stroke1 + ring, dashed: !enabled),
        brackets: active && brackets
            ? KkBracketSpec(color: accent, length: m.space2, width: m.stroke2, outset: 5)
            : null,
      ),
      child: child,
    );
  }
}

/// The line under a field: support text (or the error, with the critical
/// status icon) at the left and a counter at the right.
class KkFieldFoot extends StatelessWidget {
  const KkFieldFoot({super.key, this.support, this.error, this.counter});

  final String? support;

  /// Replaces [support] and turns the line alert-coloured.
  final String? error;
  final String? counter;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final String? err = error;
    final String? text = err ?? support;
    final String? count = counter;
    return KkRow(
      gap: theme.metrics.space3,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: text == null
              ? const KkGap(0)
              : KkRow(
                  gap: 6,
                  children: <Widget>[
                    if (err != null) const KkGlyph(level: KkLevel.critical, size: 10),
                    KkFlexible(
                      child: KkText.num(
                        text,
                        size: 11,
                        height: 1.4,
                        color: err != null ? c.alert : c.inkDim,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
        if (count != null) KkText.num(count, size: 11, height: 1.4, color: c.inkDim),
      ],
    );
  }
}

/// Gives a field its width rules: never narrower than [minWidth] (200), as
/// wide as the parent allows, and [fallbackWidth] when the parent sets no
/// limit at all (inside a row, for example).
class KkFieldWidth extends SingleChildRenderObjectWidget {
  const KkFieldWidth({super.key, this.width, this.minWidth = 200, this.fallbackWidth = 280, super.child});

  /// A fixed width.
  final double? width;
  final double minWidth;
  final double fallbackWidth;

  @override
  RenderKkFieldWidth createRenderObject(BuildContext context) =>
      RenderKkFieldWidth(width: width, minWidth: minWidth, fallbackWidth: fallbackWidth);

  @override
  void updateRenderObject(BuildContext context, RenderKkFieldWidth renderObject) {
    renderObject
      ..width = width
      ..minWidth = minWidth
      ..fallbackWidth = fallbackWidth;
  }
}

/// The render object behind [KkFieldWidth].
class RenderKkFieldWidth extends RenderProxyBox {
  RenderKkFieldWidth({double? width, double minWidth = 200, double fallbackWidth = 280, RenderBox? child})
    : _width = width,
      _minWidth = minWidth,
      _fallbackWidth = fallbackWidth,
      super(child);

  double? _width;
  double? get width => _width;
  set width(double? value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  double _minWidth;
  double get minWidth => _minWidth;
  set minWidth(double value) {
    if (value == _minWidth) return;
    _minWidth = value;
    markNeedsLayout();
  }

  double _fallbackWidth;
  double get fallbackWidth => _fallbackWidth;
  set fallbackWidth(double value) {
    if (value == _fallbackWidth) return;
    _fallbackWidth = value;
    markNeedsLayout();
  }

  BoxConstraints _inner(BoxConstraints c) {
    final double? fixed = _width;
    if (fixed != null) {
      final double w = c.constrainWidth(fixed);
      return BoxConstraints(minWidth: w, maxWidth: w, minHeight: c.minHeight, maxHeight: c.maxHeight);
    }
    final double minW = math.max(c.minWidth, math.min(_minWidth, c.maxWidth));
    final double maxW = c.hasBoundedWidth ? c.maxWidth : math.max(_fallbackWidth, minW);
    return BoxConstraints(minWidth: minW, maxWidth: maxW, minHeight: c.minHeight, maxHeight: c.maxHeight);
  }

  double get _natural => _width ?? math.max(_minWidth, _fallbackWidth);

  @override
  double computeMinIntrinsicWidth(double height) => _width ?? _minWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _natural;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width.isFinite ? width : _natural) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width.isFinite ? width : _natural) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? c = child;
    if (c == null) return constraints.constrain(Size(_natural, 0));
    return constraints.constrain(c.getDryLayout(_inner(constraints)));
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child?.getDryBaseline(_inner(constraints), baseline);

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.constrain(Size(_natural, 0));
      return;
    }
    c.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(c.size);
  }
}
