import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../widgets/frame.dart';
import 'box.dart';
import 'breakpoint.dart';
import 'scroll.dart';

/// The five regions of a [KkScreen].
enum KkScreenSlot { commandBar, nav, body, side, footer }

/// How a [KkScreen] arranges its regions.
enum KkScreenMode {
  /// Below 600px: one column. Command bar, body, side, nav (as a bottom bar),
  /// footer.
  compact,

  /// 600 to 839px: nav on the left over the full height; the side region sits
  /// under the body.
  medium,

  /// 840px and wider: nav, body and side in a row.
  expanded,
}

/// What a [KkScreen] tells its regions about the current arrangement.
@immutable
class KkScreenData {
  const KkScreenData({required this.windowClass, required this.mode, required this.width});

  /// The window class of the screen's own width.
  final KkWindowClass windowClass;
  final KkScreenMode mode;

  /// The screen's own width.
  final double width;

  /// The nav region is a horizontal bar at the bottom (compact). A nav rail
  /// lays its items out in a row when this is true.
  bool get navIsBar => mode == KkScreenMode.compact;

  /// The side region is stacked under the body instead of beside it.
  bool get sideIsStacked => mode != KkScreenMode.expanded;

  @override
  bool operator ==(Object other) =>
      other is KkScreenData && other.windowClass == windowClass && other.mode == mode && other.width == width;

  @override
  int get hashCode => Object.hash(windowClass, mode, width);

  @override
  String toString() => 'KkScreenData($windowClass, $mode, width: $width)';
}

/// Carries the [KkScreenData] of the nearest [KkScreen] down the tree.
class KkScreenScope extends InheritedWidget {
  const KkScreenScope({super.key, required this.data, required super.child});

  final KkScreenData data;

  /// The data of the nearest [KkScreen], or null outside one.
  static KkScreenData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KkScreenScope>()?.data;

  /// The data of the nearest [KkScreen]. There must be one.
  static KkScreenData of(BuildContext context) {
    final KkScreenData? data = maybeOf(context);
    assert(data != null, 'KkScreenScope.of() was called outside a KkScreen.');
    return data!;
  }

  @override
  bool updateShouldNotify(KkScreenScope oldWidget) => oldWidget.data != data;
}

/// The application skeleton: command bar on top, nav on the left, the body,
/// an optional side region and a footer.
///
/// The arrangement follows the screen's **own width**:
///
/// * 840px and wider: nav | body | side in a row.
/// * 600 to 839px: the side region moves under the body.
/// * below 600px: one column, and the nav becomes a bar above the footer.
///
/// The body is padded by the grid margin for the width (8 compact, 16, 32 on
/// a wall display) and scrolls. Nav and side scroll when they are taller than
/// the space they get. The ground is the screen colour with the 24px grid.
///
/// Descendants read the arrangement with [KkScreenScope].
class KkScreen extends StatefulWidget {
  const KkScreen({
    super.key,
    this.commandBar,
    this.nav,
    required this.body,
    this.side,
    this.footer,
    this.padding,
    this.scrollBody = true,
    this.bodyController,
    this.backdrop = KkBackdropKind.grid,
    this.safeArea = true,
  });

  /// The bar across the top.
  final Widget? commandBar;

  /// The navigation region: a rail or a drawer. It takes its own width and the
  /// full height between command bar and footer; below 600px it gets the full
  /// width and its own height instead.
  final Widget? nav;

  /// The main region.
  final Widget body;

  /// A region beside the body (a sheet, an inspector). It takes its own width.
  final Widget? side;

  /// The bar across the bottom.
  final Widget? footer;

  /// Padding around the body. Defaults to the grid margin for the width.
  final EdgeInsets? padding;

  /// Let the body scroll vertically. Turn it off for a body that fills the
  /// height by itself (a map, a diagram, its own scroll view).
  final bool scrollBody;

  /// Controls the body's scroll position (with [scrollBody]).
  final ScrollController? bodyController;

  /// The ground painted behind every region.
  final KkBackdropKind backdrop;

  /// Keep clear of system intrusions (status bar, notch, on-screen keyboard).
  final bool safeArea;

  @override
  State<KkScreen> createState() => _KkScreenState();
}

class _KkScreenState extends State<KkScreen> {
  // The wrappers around nav, side and body change with the arrangement; these
  // keys let the regions keep their state when that happens.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'KkScreen body');
  final GlobalKey _navKey = GlobalKey(debugLabel: 'KkScreen nav');
  final GlobalKey _sideKey = GlobalKey(debugLabel: 'KkScreen side');

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final Widget? cmd = widget.commandBar;
    final Widget? foot = widget.footer;
    final Widget body = KeyedSubtree(key: _bodyKey, child: widget.body);
    final Widget? navigation = widget.nav == null ? null : KeyedSubtree(key: _navKey, child: widget.nav!);
    final Widget? sideRegion = widget.side == null ? null : KeyedSubtree(key: _sideKey, child: widget.side!);

    Widget layout = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (MediaQuery.maybeSizeOf(context)?.width ?? m.bpExpanded);
        final bool bounded = constraints.hasBoundedHeight;
        final KkScreenMode mode = width >= m.bpExpanded
            ? KkScreenMode.expanded
            : (width >= m.bpMedium ? KkScreenMode.medium : KkScreenMode.compact);
        final KkWindowClass windowClass = m.windowClass(width);
        final EdgeInsets pad = widget.padding ?? EdgeInsets.all(m.marginFor(width));
        return KkScreenScope(
          data: KkScreenData(windowClass: windowClass, mode: mode, width: width),
          child: KkWindowScope(
            windowClass: windowClass,
            child: KkBackdrop(
              kind: widget.backdrop,
              child: _KkScreenLayout(
                mode: mode,
                // Paint order, back to front: body, side, nav, footer, command bar.
                children: <Widget>[
                  _KkScreenRegion(
                    key: const ValueKey<KkScreenSlot>(KkScreenSlot.body),
                    slot: KkScreenSlot.body,
                    child: widget.scrollBody && bounded
                        ? KkScroll(padding: pad, controller: widget.bodyController, child: body)
                        : KkBox(padding: pad, child: body),
                  ),
                  if (sideRegion != null)
                    _KkScreenRegion(
                      key: const ValueKey<KkScreenSlot>(KkScreenSlot.side),
                      slot: KkScreenSlot.side,
                      child: mode == KkScreenMode.expanded
                          ? _KkFillScroll(child: sideRegion)
                          : (bounded ? KkScroll(child: sideRegion) : sideRegion),
                    ),
                  if (navigation != null)
                    _KkScreenRegion(
                      key: const ValueKey<KkScreenSlot>(KkScreenSlot.nav),
                      slot: KkScreenSlot.nav,
                      child: mode == KkScreenMode.compact ? navigation : _KkFillScroll(child: navigation),
                    ),
                  if (foot != null)
                    _KkScreenRegion(
                      key: const ValueKey<KkScreenSlot>(KkScreenSlot.footer),
                      slot: KkScreenSlot.footer,
                      child: foot,
                    ),
                  if (cmd != null)
                    _KkScreenRegion(
                      key: const ValueKey<KkScreenSlot>(KkScreenSlot.commandBar),
                      slot: KkScreenSlot.commandBar,
                      child: cmd,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (widget.safeArea) {
      final MediaQueryData? mq = MediaQuery.maybeOf(context);
      if (mq != null) {
        final EdgeInsets inset = mq.padding.copyWith(bottom: math.max(mq.padding.bottom, mq.viewInsets.bottom));
        if (inset != EdgeInsets.zero) {
          layout = KkBox(
            fill: KeikaiTheme.of(context).colors.bg000,
            padding: inset,
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeTop: true,
              removeRight: true,
              removeBottom: true,
              child: layout,
            ),
          );
        }
      }
    }
    return layout;
  }
}

/// A vertical scroll region whose child is at least as tall as the region:
/// a rail fills the height, and scrolls once it no longer fits.
class _KkFillScroll extends StatelessWidget {
  const _KkFillScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) return child;
        return KkScroll(
          child: KkBox(minHeight: constraints.maxHeight, child: child),
        );
      },
    );
  }
}

/// Parent data of a region of a [KkScreen].
class KkScreenParentData extends ContainerBoxParentData<RenderBox> {
  KkScreenSlot slot = KkScreenSlot.body;
}

class _KkScreenRegion extends ParentDataWidget<KkScreenParentData> {
  const _KkScreenRegion({super.key, required this.slot, required super.child});

  final KkScreenSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkScreenParentData pd = renderObject.parentData! as KkScreenParentData;
    if (pd.slot != slot) {
      pd.slot = slot;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _KkScreenLayout;
}

class _KkScreenLayout extends MultiChildRenderObjectWidget {
  const _KkScreenLayout({required this.mode, super.children});

  final KkScreenMode mode;

  @override
  RenderKkScreen createRenderObject(BuildContext context) => RenderKkScreen(mode: mode);

  @override
  void updateRenderObject(BuildContext context, RenderKkScreen renderObject) => renderObject.mode = mode;
}

/// The render object behind [KkScreen]: places up to five regions by
/// [KkScreenMode].
class RenderKkScreen extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KkScreenParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KkScreenParentData> {
  RenderKkScreen({KkScreenMode mode = KkScreenMode.expanded}) : _mode = mode;

  KkScreenMode _mode;
  KkScreenMode get mode => _mode;
  set mode(KkScreenMode value) {
    if (value == _mode) return;
    _mode = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KkScreenParentData) child.parentData = KkScreenParentData();
  }

  RenderBox? _region(KkScreenSlot slot) {
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      if ((child.parentData! as KkScreenParentData).slot == slot) return child;
    }
    return null;
  }

  static void _place(RenderBox? child, double x, double y) {
    if (child != null) (child.parentData! as KkScreenParentData).offset = Offset(x, y);
  }

  static Size _layout(RenderBox? child, BoxConstraints constraints) {
    if (child == null) return Size.zero;
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    final double height = constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight;
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final BoxConstraints c = constraints;
    final double width = c.hasBoundedWidth ? c.maxWidth : c.minWidth;
    final bool bounded = c.hasBoundedHeight;
    final double height = bounded ? c.maxHeight : double.infinity;

    final RenderBox? cmd = _region(KkScreenSlot.commandBar);
    final RenderBox? nav = _region(KkScreenSlot.nav);
    final RenderBox? body = _region(KkScreenSlot.body);
    final RenderBox? side = _region(KkScreenSlot.side);
    final RenderBox? foot = _region(KkScreenSlot.footer);

    final double hc = _layout(cmd, BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height)).height;
    final double hf = _layout(
      foot,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: bounded ? math.max(0, height - hc) : height),
    ).height;
    // Height left between command bar and footer (infinite when unbounded).
    double middle = bounded ? math.max(0, height - hc - hf) : double.infinity;

    switch (_mode) {
      case KkScreenMode.expanded:
        if (bounded) {
          final double navW = _layout(nav, BoxConstraints(maxWidth: width, minHeight: middle, maxHeight: middle)).width;
          final double sideW = _layout(
            side,
            BoxConstraints(maxWidth: math.max(0, width - navW), minHeight: middle, maxHeight: middle),
          ).width;
          final double bodyW = math.max(0, width - navW - sideW);
          _layout(body, BoxConstraints.tightFor(width: bodyW, height: middle));
          _place(nav, 0, hc);
          _place(body, navW, hc);
          _place(side, width - sideW, hc);
        } else {
          Size navS = _layout(nav, BoxConstraints(maxWidth: width));
          Size sideS = _layout(side, BoxConstraints(maxWidth: math.max(0, width - navS.width)));
          final double bodyW = math.max(0, width - navS.width - sideS.width);
          final Size bodyS = _layout(body, BoxConstraints(minWidth: bodyW, maxWidth: bodyW));
          middle = math.max(bodyS.height, math.max(navS.height, sideS.height));
          if (navS.height != middle) {
            navS = _layout(nav, BoxConstraints(minWidth: navS.width, maxWidth: navS.width, minHeight: middle, maxHeight: middle));
          }
          if (sideS.height != middle) {
            sideS = _layout(
              side,
              BoxConstraints(minWidth: sideS.width, maxWidth: sideS.width, minHeight: middle, maxHeight: middle),
            );
          }
          if (bodyS.height != middle) _layout(body, BoxConstraints.tightFor(width: bodyW, height: middle));
          _place(nav, 0, hc);
          _place(body, navS.width, hc);
          _place(side, width - sideS.width, hc);
        }
      case KkScreenMode.medium:
        if (bounded) {
          final double navW = _layout(nav, BoxConstraints(maxWidth: width, minHeight: middle, maxHeight: middle)).width;
          final double rightW = math.max(0, width - navW);
          final double hs = _layout(side, BoxConstraints(minWidth: rightW, maxWidth: rightW, maxHeight: middle)).height;
          _layout(body, BoxConstraints.tightFor(width: rightW, height: math.max(0, middle - hs)));
          _place(nav, 0, hc);
          _place(body, navW, hc);
          _place(side, navW, hc + middle - hs);
        } else {
          Size navS = _layout(nav, BoxConstraints(maxWidth: width));
          final double rightW = math.max(0, width - navS.width);
          final Size bodyS = _layout(body, BoxConstraints(minWidth: rightW, maxWidth: rightW));
          final Size sideS = _layout(side, BoxConstraints(minWidth: rightW, maxWidth: rightW));
          middle = math.max(navS.height, bodyS.height + sideS.height);
          if (navS.height != middle) {
            navS = _layout(nav, BoxConstraints(minWidth: navS.width, maxWidth: navS.width, minHeight: middle, maxHeight: middle));
          }
          _place(nav, 0, hc);
          _place(body, navS.width, hc);
          _place(side, navS.width, hc + middle - sideS.height);
        }
      case KkScreenMode.compact:
        if (bounded) {
          final double hn = _layout(nav, BoxConstraints(minWidth: width, maxWidth: width, maxHeight: middle)).height;
          final double hs = _layout(
            side,
            BoxConstraints(minWidth: width, maxWidth: width, maxHeight: math.max(0, middle - hn)),
          ).height;
          final double hb = math.max(0, middle - hn - hs);
          _layout(body, BoxConstraints.tightFor(width: width, height: hb));
          _place(body, 0, hc);
          _place(side, 0, hc + hb);
          _place(nav, 0, hc + hb + hs);
        } else {
          final BoxConstraints full = BoxConstraints(minWidth: width, maxWidth: width);
          final double hb = _layout(body, full).height;
          final double hs = _layout(side, full).height;
          final double hn = _layout(nav, full).height;
          middle = hb + hs + hn;
          _place(body, 0, hc);
          _place(side, 0, hc + hb);
          _place(nav, 0, hc + hb + hs);
        }
    }
    _place(cmd, 0, 0);
    _place(foot, 0, hc + middle);
    size = c.constrain(Size(width, hc + middle + hf));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    // The screen never lets a region spill over its edge.
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<KkScreenMode>('mode', mode));
  }
}
