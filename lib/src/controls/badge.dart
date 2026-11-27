import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// A count on a small plate cut at the top right, or a bare 8px dot.
///
/// The fill is the level colour, alert by default: a badge says something is
/// waiting. It ignores pointer events.
class KkBadge extends StatelessWidget {
  /// A badge showing [count] (capped at [max], then `99+`), or [label].
  const KkBadge({super.key, this.count, this.label, this.max = 99, this.level, this.color, this.onColor})
    : dot = false,
      assert(count != null || label != null, 'Give a count or a label, or use KkBadge.dot.');

  /// An 8px square with no text.
  const KkBadge.dot({super.key, this.level, this.color})
    : dot = true,
      count = null,
      label = null,
      max = 99,
      onColor = null;

  final int? count;

  /// Text instead of a count.
  final String? label;

  /// Counts above this read `<max>+`.
  final int max;

  /// Colours the badge. Without a level (or [color]) it is alert.
  final KkLevel? level;
  final Color? color;

  /// Text colour. Defaults to the on-fill ink.
  final Color? onColor;
  final bool dot;

  /// The text shown for the current [count] and [max].
  String get text {
    final String? l = label;
    if (l != null) return l;
    final int n = count ?? 0;
    return n > max ? '$max+' : '$n';
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color fill = color ?? c.level(level, fallback: c.alert);
    if (dot) {
      return IgnorePointer(
        child: KkBox(width: m.space2, height: m.space2, fill: fill),
      );
    }
    return IgnorePointer(
      child: KkSurface(
        shape: KkShape.chamfer(tr: m.space1),
        fill: fill,
        edgeWidth: 0,
        child: KkBox(
          minWidth: 16,
          height: 16,
          padding: EdgeInsets.symmetric(horizontal: m.space1),
          child: KkTextScaleLimit(
            height: 16,
            fontSize: 10,
            child: KkWholeWidth(
              child: KkRow(
                shrinkWrap: true,
                main: KkMainAlign.center,
                clip: Clip.hardEdge,
                children: <Widget>[
                  KkText.num(
                    text,
                    size: 10,
                    weight: FontWeight.w600,
                    color: onColor ?? c.onFill,
                    // Tabular figures only: a badge's zero is not slashed.
                    style: const TextStyle(fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins a [badge] over the top-right corner of [child] (6px up, 8px out).
///
/// The anchor is laid out as its child is: the child gets the constraints the
/// anchor was given and the anchor takes the child's size and baseline, so the
/// badge is on the corner of the child wherever a parent puts it or stretches
/// it. The badge hangs over the edge, takes no room and moves nothing.
class KkBadgeAnchor extends StatelessWidget {
  const KkBadgeAnchor({
    super.key,
    required this.child,
    required this.badge,
    this.show = true,
    this.top = -6,
    this.right = -8,
  });

  final Widget child;

  /// Usually a [KkBadge]. With null nothing is pinned, as with [show] false.
  final Widget? badge;

  /// Hide the badge without changing the layout.
  final bool show;

  /// How far below the top edge of [child] the badge starts. A negative
  /// distance is above the edge.
  final double top;

  /// How far inside the right edge of [child] the badge ends. A negative
  /// distance is beyond the edge.
  final double right;

  @override
  Widget build(BuildContext context) {
    final Widget? pinned = show ? badge : null;
    // The child keeps its slot whether or not there is a badge, so its state
    // lives through a badge that comes or goes.
    return _KkBadgePin(
      top: top,
      right: right,
      host: child,
      badge: pinned == null ? null : IgnorePointer(child: pinned),
    );
  }
}

enum _BadgeSlot { host, badge }

/// The host of a badge with the badge pinned over its top-right corner.
class _KkBadgePin extends SlottedMultiChildRenderObjectWidget<_BadgeSlot, RenderBox> {
  const _KkBadgePin({required this.top, required this.right, required this.host, required this.badge});

  final double top;
  final double right;
  final Widget host;
  final Widget? badge;

  @override
  Iterable<_BadgeSlot> get slots => _BadgeSlot.values;

  @override
  Widget? childForSlot(_BadgeSlot slot) => switch (slot) {
    _BadgeSlot.host => host,
    _BadgeSlot.badge => badge,
  };

  @override
  _RenderBadgePin createRenderObject(BuildContext context) => _RenderBadgePin(top: top, right: right);

  @override
  void updateRenderObject(BuildContext context, _RenderBadgePin renderObject) {
    renderObject
      ..top = top
      ..right = right;
  }
}

/// The render object behind [KkBadgeAnchor].
///
/// The host is laid out with the constraints this box gets and gives it its
/// size. The badge is as large as it wants to be and is placed from the
/// host's top-right corner.
class _RenderBadgePin extends RenderBox with SlottedContainerRenderObjectMixin<_BadgeSlot, RenderBox> {
  _RenderBadgePin({required double top, required double right}) : _top = top, _right = right;

  double _top;
  double get top => _top;
  set top(double value) {
    if (value == _top) return;
    _top = value;
    markNeedsLayout();
  }

  double _right;
  double get right => _right;
  set right(double value) {
    if (value == _right) return;
    _right = value;
    markNeedsLayout();
  }

  RenderBox? get _host => childForSlot(_BadgeSlot.host);
  RenderBox? get _badge => childForSlot(_BadgeSlot.badge);

  /// Back to front.
  @override
  Iterable<RenderBox> get children => <RenderBox>[?_host, ?_badge];

  @override
  double computeMinIntrinsicWidth(double height) => _host?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _host?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => _host?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => _host?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _host?.getDryLayout(constraints) ?? constraints.smallest;

  /// The baseline of the host alone. The badge is outside the layout, like an
  /// absolutely positioned box in CSS: its digits must not be what a row
  /// aligns the host by.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      _host?.getDryBaseline(constraints, baseline);

  @override
  void performLayout() {
    final RenderBox? host = _host;
    if (host == null) {
      size = constraints.smallest;
    } else {
      host.layout(constraints, parentUsesSize: true);
      size = host.size;
    }
    final RenderBox? badge = _badge;
    if (badge != null) {
      badge.layout(const BoxConstraints(), parentUsesSize: true);
      (badge.parentData! as BoxParentData).offset = Offset(size.width - _right - badge.size.width, _top);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _host?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Front to back.
    for (final RenderBox child in <RenderBox>[?_badge, ?_host]) {
      final bool hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final RenderBox child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }
}
