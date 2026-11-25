import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The side of its anchor a popup opens on.
enum KkPopupSide { below, above, left, right }

/// How a popup lines up with its anchor across the opening direction.
///
/// For a popup below or above: start = left edges together, end = right edges
/// together. For a popup at the left or right: start = top edges together.
enum KkPopupAlign { start, center, end }

/// Opens and closes a [KkPopup] (and everything built on it: menus, selects,
/// search results).
class KkPopupController extends ChangeNotifier {
  final OverlayPortalController _portal = OverlayPortalController(debugLabel: 'KkPopup');
  bool _open = false;

  /// How many mounted [KkPopup]s use this controller (one, normally).
  int _hosts = 0;
  bool _syncScheduled = false;
  bool _disposed = false;

  /// Whether the popup is showing.
  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    _sync();
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _sync();
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  /// Brings the overlay in line with [isOpen].
  ///
  /// The framework does not let a mounted overlay change while a frame is
  /// being built, and a widget may well open or close its popup from
  /// `didUpdateWidget` (a select that is turned off while open). In that case
  /// the overlay follows right after the frame; a closed popup already builds
  /// nothing in the frame at hand.
  void _sync() {
    if (_hosts > 0 && SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_syncScheduled) return;
      _syncScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _syncScheduled = false;
        if (!_disposed) _sync();
      });
      return;
    }
    if (_open == _portal.isShowing) return;
    if (_open) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Anchors a floating surface to [child].
///
/// While [controller] is open, [popupBuilder] is shown in the nearest overlay,
/// placed next to the child by [KkPopupLayout]: it follows the child when the
/// page scrolls or resizes, flips to the other side when it does not fit and
/// never leaves the screen. A press outside both the child and the popup
/// closes it.
///
/// This is the base of `KkMenuAnchor`, `KkSelect`, `KkSearch` and `KkTooltip`.
class KkPopup extends StatefulWidget {
  const KkPopup({
    super.key,
    required this.controller,
    required this.popupBuilder,
    required this.child,
    this.side = KkPopupSide.below,
    this.align = KkPopupAlign.start,
    this.gap = 4,
    this.margin = 4,
    this.flip = true,
    this.matchWidth = false,
    this.minAnchorWidth = false,
    this.minWidth = 0,
    this.stem,
    this.closeOnTapOutside = true,
    this.groupId,
  });

  final KkPopupController controller;

  /// Builds the floating surface.
  final WidgetBuilder popupBuilder;

  /// The anchor.
  final Widget child;
  final KkPopupSide side;
  final KkPopupAlign align;

  /// Distance between the anchor and the popup.
  final double gap;

  /// Distance the popup keeps from the edges of the screen.
  final double margin;

  /// Open on the opposite side when there is not enough room.
  final bool flip;

  /// Make the popup exactly as wide as the anchor (never narrower than
  /// [minWidth]).
  final bool matchWidth;

  /// Make the popup at least as wide as the anchor, and wider when its
  /// content needs it.
  final bool minAnchorWidth;
  final double minWidth;

  /// Colour of a 1px stem drawn across the gap, from the popup to the middle
  /// of the anchor. Null draws none.
  final Color? stem;

  /// Close when a pointer goes down outside the anchor and the popup.
  final bool closeOnTapOutside;

  /// The tap-region group the anchor and the popup belong to. Regions that
  /// share it count as "inside". Defaults to the [controller].
  final Object? groupId;

  @override
  State<KkPopup> createState() => _KkPopupState();
}

class _KkPopupState extends State<KkPopup> {
  @override
  void initState() {
    super.initState();
    widget.controller._hosts++;
  }

  @override
  void didUpdateWidget(KkPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._hosts--;
      widget.controller._hosts++;
    }
  }

  @override
  void dispose() {
    widget.controller._hosts--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KkPopup w = widget;
    final KkPopupController controller = w.controller;
    final Object group = w.groupId ?? controller;
    return TapRegion(
      groupId: group,
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: controller._portal,
        overlayChildBuilder: (BuildContext context, OverlayChildLayoutInfo info) {
          // Closed during this very frame: the overlay itself goes right
          // after it (see KkPopupController._sync).
          if (!controller.isOpen) return const SizedBox.shrink();
          final Rect anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
          return KkPopupLayout(
            anchor: anchor,
            side: w.side,
            align: w.align,
            gap: w.gap,
            margin: w.margin,
            flip: w.flip,
            matchWidth: w.matchWidth,
            minAnchorWidth: w.minAnchorWidth,
            minWidth: w.minWidth,
            stem: w.stem,
            child: TapRegion(
              groupId: group,
              onTapOutside: w.closeOnTapOutside ? (PointerDownEvent event) => controller.close() : null,
              child: w.popupBuilder(context),
            ),
          );
        },
        child: w.child,
      ),
    );
  }
}

/// Fills the overlay and places its child next to the [anchor] rectangle
/// (given in the overlay's coordinates).
///
/// The child opens on [side]; if it does not fit there and [flip] is on, it
/// opens on the opposite side; if it fits on neither, it takes the roomier
/// side and is given only the room there is (so a long menu scrolls). Across
/// the opening direction it is shifted to stay [margin] px inside the overlay.
///
/// Pointer events pass through everywhere except on the child.
class KkPopupLayout extends SingleChildRenderObjectWidget {
  const KkPopupLayout({
    super.key,
    required this.anchor,
    this.side = KkPopupSide.below,
    this.align = KkPopupAlign.start,
    this.gap = 4,
    this.margin = 4,
    this.flip = true,
    this.matchWidth = false,
    this.minAnchorWidth = false,
    this.minWidth = 0,
    this.stem,
    super.child,
  });

  final Rect anchor;
  final KkPopupSide side;
  final KkPopupAlign align;
  final double gap;
  final double margin;
  final bool flip;

  /// Exactly as wide as the anchor (below / above only).
  final bool matchWidth;

  /// At least as wide as the anchor (below / above only).
  final bool minAnchorWidth;
  final double minWidth;
  final Color? stem;

  @override
  RenderKkPopupLayout createRenderObject(BuildContext context) => RenderKkPopupLayout(
    anchor: anchor,
    side: side,
    align: align,
    gap: gap,
    margin: margin,
    flip: flip,
    matchWidth: matchWidth,
    minAnchorWidth: minAnchorWidth,
    minWidth: minWidth,
    stem: stem,
  );

  @override
  void updateRenderObject(BuildContext context, RenderKkPopupLayout renderObject) {
    renderObject
      ..anchor = anchor
      ..side = side
      ..align = align
      ..gap = gap
      ..margin = margin
      ..flip = flip
      ..matchWidth = matchWidth
      ..minAnchorWidth = minAnchorWidth
      ..minWidth = minWidth
      ..stem = stem;
  }
}

/// The render object behind [KkPopupLayout].
class RenderKkPopupLayout extends RenderShiftedBox {
  RenderKkPopupLayout({
    required Rect anchor,
    KkPopupSide side = KkPopupSide.below,
    KkPopupAlign align = KkPopupAlign.start,
    double gap = 4,
    double margin = 4,
    bool flip = true,
    bool matchWidth = false,
    bool minAnchorWidth = false,
    double minWidth = 0,
    Color? stem,
    RenderBox? child,
  }) : _anchor = anchor,
       _side = side,
       _align = align,
       _gap = gap,
       _margin = margin,
       _flip = flip,
       _matchWidth = matchWidth,
       _minAnchorWidth = minAnchorWidth,
       _minWidth = minWidth,
       _stem = stem,
       super(child);

  Rect _anchor;
  Rect get anchor => _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  KkPopupSide _side;
  KkPopupSide get side => _side;
  set side(KkPopupSide value) {
    if (value == _side) return;
    _side = value;
    markNeedsLayout();
  }

  KkPopupAlign _align;
  KkPopupAlign get align => _align;
  set align(KkPopupAlign value) {
    if (value == _align) return;
    _align = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _margin;
  double get margin => _margin;
  set margin(double value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsLayout();
  }

  bool _flip;
  bool get flip => _flip;
  set flip(bool value) {
    if (value == _flip) return;
    _flip = value;
    markNeedsLayout();
  }

  bool _matchWidth;
  bool get matchWidth => _matchWidth;
  set matchWidth(bool value) {
    if (value == _matchWidth) return;
    _matchWidth = value;
    markNeedsLayout();
  }

  bool _minAnchorWidth;
  bool get minAnchorWidth => _minAnchorWidth;
  set minAnchorWidth(bool value) {
    if (value == _minAnchorWidth) return;
    _minAnchorWidth = value;
    markNeedsLayout();
  }

  double _minWidth;
  double get minWidth => _minWidth;
  set minWidth(double value) {
    if (value == _minWidth) return;
    _minWidth = value;
    markNeedsLayout();
  }

  Color? _stem;
  Color? get stem => _stem;
  set stem(Color? value) {
    if (value == _stem) return;
    _stem = value;
    markNeedsPaint();
  }

  /// The side the child ended up on in the last layout.
  KkPopupSide get resolvedSide => _resolvedSide;
  KkPopupSide _resolvedSide = KkPopupSide.below;

  /// Where the child was placed in the last layout, in this box's coordinates.
  Rect get childRect => _childRect;
  Rect _childRect = Rect.zero;

  static KkPopupSide _opposite(KkPopupSide side) => switch (side) {
    KkPopupSide.below => KkPopupSide.above,
    KkPopupSide.above => KkPopupSide.below,
    KkPopupSide.left => KkPopupSide.right,
    KkPopupSide.right => KkPopupSide.left,
  };

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  Size _sizeFor(BoxConstraints constraints) => Size(
    constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth,
    constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight,
  );

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    size = _sizeFor(constraints);
    final RenderBox? child = this.child;
    if (child == null) return;

    // The area the child must stay in. An unbounded axis has no limit.
    final double left = _margin;
    final double top = _margin;
    final double right = constraints.hasBoundedWidth ? math.max(left, size.width - _margin) : double.infinity;
    final double bottom = constraints.hasBoundedHeight ? math.max(top, size.height - _margin) : double.infinity;
    final double areaWidth = right - left;
    final double areaHeight = bottom - top;

    double room(KkPopupSide s) => math.max(0, switch (s) {
      KkPopupSide.below => bottom - (_anchor.bottom + _gap),
      KkPopupSide.above => (_anchor.top - _gap) - top,
      KkPopupSide.right => right - (_anchor.right + _gap),
      KkPopupSide.left => (_anchor.left - _gap) - left,
    });

    final bool vertical = _side == KkPopupSide.below || _side == KkPopupSide.above;
    final double minW = math.min(
      _minAnchorWidth && vertical ? math.max(_minWidth, _anchor.width) : _minWidth,
      areaWidth,
    );
    final double fixedW = math.min(math.max(_anchor.width, _minWidth), areaWidth);

    BoxConstraints childConstraints({double? maxWidth, double? maxHeight}) {
      final double mw = maxWidth ?? areaWidth;
      final double mh = maxHeight ?? areaHeight;
      if (_matchWidth && vertical) {
        return BoxConstraints(minWidth: fixedW, maxWidth: fixedW, maxHeight: mh);
      }
      return BoxConstraints(minWidth: math.min(minW, mw), maxWidth: mw, maxHeight: mh);
    }

    child.layout(childConstraints(), parentUsesSize: true);
    final Size natural = child.size;
    final double wanted = vertical ? natural.height : natural.width;

    KkPopupSide resolved = _side;
    if (wanted > room(_side) && _flip) {
      final KkPopupSide other = _opposite(_side);
      if (wanted <= room(other) || room(other) > room(_side)) resolved = other;
    }
    final double space = room(resolved);
    if (wanted > space && space >= math.min(wanted, 64)) {
      // Not enough room: give the child what there is and let it scroll.
      child.layout(
        vertical ? childConstraints(maxHeight: space) : childConstraints(maxWidth: space),
        parentUsesSize: true,
      );
    }
    final Size s = child.size;

    double across(double start, double end, double extent, double lo, double hi) {
      final double v = switch (_align) {
        KkPopupAlign.start => start,
        KkPopupAlign.center => (start + end - extent) / 2,
        KkPopupAlign.end => end - extent,
      };
      final double max = math.max(lo, hi - extent);
      return hi.isFinite ? v.clamp(lo, max) : math.max(v, lo);
    }

    double along(double v, double extent, double lo, double hi) {
      final double max = math.max(lo, hi - extent);
      return hi.isFinite ? v.clamp(lo, max) : math.max(v, lo);
    }

    final Offset offset = switch (resolved) {
      KkPopupSide.below => Offset(
        across(_anchor.left, _anchor.right, s.width, left, right),
        along(_anchor.bottom + _gap, s.height, top, bottom),
      ),
      KkPopupSide.above => Offset(
        across(_anchor.left, _anchor.right, s.width, left, right),
        along(_anchor.top - _gap - s.height, s.height, top, bottom),
      ),
      KkPopupSide.right => Offset(
        along(_anchor.right + _gap, s.width, left, right),
        across(_anchor.top, _anchor.bottom, s.height, top, bottom),
      ),
      KkPopupSide.left => Offset(
        along(_anchor.left - _gap - s.width, s.width, left, right),
        across(_anchor.top, _anchor.bottom, s.height, top, bottom),
      ),
    };
    // Whole pixels keep 1px borders crisp.
    final Offset snapped = Offset(offset.dx.roundToDouble(), offset.dy.roundToDouble());
    (child.parentData! as BoxParentData).offset = snapped;
    _resolvedSide = resolved;
    _childRect = snapped & s;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Only the child takes pointer events; the rest of the overlay stays live.
    return hitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Color? color = _stem;
    if (color != null && child != null && color.a > 0) {
      final Rect c = _childRect.shift(offset);
      final Rect a = _anchor.shift(offset);
      final Paint paint = Paint()..color = color;
      switch (_resolvedSide) {
        case KkPopupSide.above:
        case KkPopupSide.below:
          final double x = (a.center.dx - 0.5).floorToDouble().clamp(c.left, math.max(c.left, c.right - 1));
          final double y0 = _resolvedSide == KkPopupSide.above ? c.bottom : a.bottom;
          final double y1 = _resolvedSide == KkPopupSide.above ? a.top : c.top;
          if (y1 > y0) context.canvas.drawRect(Rect.fromLTRB(x, y0, x + 1, y1), paint);
        case KkPopupSide.left:
        case KkPopupSide.right:
          final double y = (a.center.dy - 0.5).floorToDouble().clamp(c.top, math.max(c.top, c.bottom - 1));
          final double x0 = _resolvedSide == KkPopupSide.left ? c.right : a.right;
          final double x1 = _resolvedSide == KkPopupSide.left ? a.left : c.left;
          if (x1 > x0) context.canvas.drawRect(Rect.fromLTRB(x0, y, x1, y + 1), paint);
      }
    }
    super.paint(context, offset);
  }
}
