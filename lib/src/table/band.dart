import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../inputs/text_input.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// An action on the selected rows, shown in the band of a `KkDataTable` while
/// rows are selected.
///
/// A [danger] action is not carried out by its first press. That press arms
/// it: the button turns to the alarm fill, blinks once a second and reads
/// [confirmLabel]. A second press carries it out. It disarms by itself after
/// [armTimeout], when it loses the focus, on Escape, on a press elsewhere and
/// when the selection changes.
@immutable
class KkTableBulkAction {
  const KkTableBulkAction({
    required this.label,
    this.cjk,
    this.icon,
    this.onPressed,
    this.danger = false,
    this.confirmLabel = 'confirm',
    this.confirmCjk,
    this.armTimeout = const Duration(seconds: 4),
    this.initiallyArmed = false,
  });

  /// Latin text; shown in capitals.
  final String label;

  /// A CJK word before [label].
  final String? cjk;
  final KkIconData? icon;

  /// Called with the keys of the selected rows. Null disables the action.
  final ValueChanged<Set<Object>>? onPressed;

  /// Ask for a second press before acting.
  final bool danger;

  /// What an armed button reads; shown in capitals.
  final String confirmLabel;

  /// A CJK word before [confirmLabel]. Defaults to [cjk].
  final String? confirmCjk;

  /// How long an armed button waits for the second press.
  final Duration armTimeout;

  /// Show the action armed from the start (for catalogues and tests). The
  /// timeout runs as usual.
  final bool initiallyArmed;
}

/// The band at the top of a table: code block, title, meta, filter field and
/// actions; or, while rows are selected, the solid signal band with the count
/// and the bulk actions. Both forms are 40px high.
///
/// This class is not part of the public API.
class KkTableBand extends StatelessWidget {
  const KkTableBand({
    super.key,
    this.code,
    this.cjk,
    this.en,
    this.meta,
    this.squeeze = 0.8,
    this.filter,
    this.actions = const <Widget>[],
    this.selected = const <Object>{},
    this.selectionCjk = '選択',
    this.selectionEn = 'selected',
    this.bulkActions = const <KkTableBulkAction>[],
    this.onClearSelection,
    this.disarm,
  });

  final String? code;
  final String? cjk;
  final String? en;
  final String? meta;
  final double squeeze;

  /// The filter field, when the table has one.
  final Widget? filter;
  final List<Widget> actions;

  /// The keys of the selected rows. The band is in its selecting form while
  /// this is not empty.
  final Set<Object> selected;
  final String selectionCjk;
  final String selectionEn;
  final List<KkTableBulkAction> bulkActions;
  final VoidCallback? onClearSelection;

  /// Notifies when armed actions should stand down (Escape in the table).
  final Listenable? disarm;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    if (selected.isNotEmpty) {
      // Focus rings on the signal band are dark.
      final KeikaiThemeData onSignal = theme.copyWith(
        standbyColors: theme.standbyColors.copyWith(focus: theme.standbyColors.bg000),
        alertColors: theme.alertColors.copyWith(focus: theme.alertColors.bg000),
      );
      return KkBoot(
        duration: const Duration(milliseconds: 250),
        steps: 5,
        stagger: false,
        child: KeikaiTheme(
          data: onSignal,
          child: KkBox(
            height: 40,
            padding: EdgeInsets.only(right: m.space2),
            decoration: KkDecoration(
              fill: c.signal,
              edges: KkEdges(bottom: KkSide(c.signal, width: m.stroke1)),
            ),
            clip: true,
            child: KkTableBandRow(
              gap: m.space2,
              children: <Widget>[
                KkTableBandSlot(
                  part: KkTableBandPart.lead,
                  child: _Slant(
                    fill: c.bg000,
                    child: KkText.num(
                      selected.length.toString().padLeft(2, '0'),
                      size: 20,
                      weight: FontWeight.w600,
                      color: c.signal,
                    ),
                  ),
                ),
                KkTableBandSlot(
                  part: KkTableBandPart.title,
                  child: KkBox(
                    padding: EdgeInsets.only(left: m.space1),
                    child: KkRow(
                      shrinkWrap: true,
                      cross: KkCrossAlign.baseline,
                      gap: m.space2,
                      children: <Widget>[
                        if (selectionCjk.isNotEmpty)
                          KkText.cjk(selectionCjk, size: 17, color: c.onFill, squeeze: squeeze),
                        if (selectionEn.isNotEmpty)
                          KkText.en(selectionEn, size: 11, weight: FontWeight.w700, spacing: 0.14, color: c.onFill),
                      ],
                    ),
                  ),
                ),
                for (final KkTableBulkAction action in bulkActions)
                  KkTableBulkButton(
                    action: action,
                    selected: selected,
                    disarm: disarm,
                    squeeze: squeeze,
                    initiallyArmed: action.initiallyArmed,
                  ),
                if (onClearSelection != null)
                  KkIconButton(
                    icon: KkIcons.close,
                    semanticLabel: 'Clear selection',
                    onPressed: onClearSelection,
                    style: KkPlateStyle(ink: c.onFill, hoverInk: c.onFill, hoverFill: kkFade(c.bg000, 0.22)),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final String? codeText = code;
    final String? cjkText = cjk;
    final String? enText = en;
    final String? metaText = meta;
    final Widget? field = filter;
    final bool hasCode = codeText != null && codeText.isNotEmpty;
    return KkBox(
      height: 40,
      padding: EdgeInsets.only(right: m.space2),
      decoration: KkDecoration(
        fill: c.bg200,
        edges: KkEdges(bottom: KkSide(c.line, width: m.stroke1)),
      ),
      clip: true,
      child: KkTableBandRow(
        gap: m.space2,
        children: <Widget>[
          if (hasCode)
            KkTableBandSlot(
              part: KkTableBandPart.lead,
              child: _Slant(
                fill: c.signal,
                child: KkText.num(codeText, size: 11, weight: FontWeight.w600, spacing: 0.06, color: c.onFill),
              ),
            ),
          KkTableBandSlot(
            part: KkTableBandPart.title,
            child: KkBox(
              padding: EdgeInsets.only(left: hasCode ? m.space1 : m.space3),
              child: Semantics(
                header: true,
                child: KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.baseline,
                  gap: m.space2,
                  children: <Widget>[
                    if (cjkText != null && cjkText.isNotEmpty)
                      KkText.cjk(cjkText, size: 17, color: c.ink, squeeze: squeeze),
                    if (enText != null && enText.isNotEmpty)
                      KkText.en(enText, size: 11, weight: FontWeight.w700, spacing: 0.14, color: c.inkDim),
                  ],
                ),
              ),
            ),
          ),
          if (metaText != null && metaText.isNotEmpty)
            KkBox(
              padding: EdgeInsets.symmetric(horizontal: m.space1),
              child: KkText.num(metaText, size: 12, weight: FontWeight.w500, color: c.ink),
            ),
          if (field != null) KkTableBandSlot(part: KkTableBandPart.filter, child: field),
          ...actions,
        ],
      ),
    );
  }
}

/// How a child of a [KkTableBandRow] takes its width.
enum KkTableBandPart {
  /// Its own width, and as high as the row: the code block, the count.
  lead,

  /// Its own width. What is left of the row lies after it, and it is the
  /// first to give way when the row is too narrow: it is then cut at its
  /// right.
  title,

  /// The filter field: [KkTableBandSlot.basis] wide, and in a row that is too
  /// narrow as little as [KkTableBandSlot.least].
  filter,

  /// Its own width, whatever the width of the row: the meta reading and the
  /// actions.
  fixed,
}

class _BandParentData extends ContainerBoxParentData<RenderBox> {
  KkTableBandPart part = KkTableBandPart.fixed;
  double basis = 200;
  double least = 120;
}

/// Marks what a child of a [KkTableBandRow] is. A child without this widget
/// is [KkTableBandPart.fixed].
///
/// This class is not part of the public API.
class KkTableBandSlot extends ParentDataWidget<_BandParentData> {
  const KkTableBandSlot({super.key, required this.part, this.basis = 200, this.least = 120, required super.child});

  final KkTableBandPart part;

  /// The width of a [KkTableBandPart.filter] child when there is room for it.
  final double basis;

  /// The least width of a [KkTableBandPart.filter] child.
  final double least;

  @override
  void applyParentData(RenderObject renderObject) {
    final _BandParentData pd = renderObject.parentData! as _BandParentData;
    if (pd.part == part && pd.basis == basis && pd.least == least) return;
    pd
      ..part = part
      ..basis = basis
      ..least = least;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => KkTableBandRow;
}

/// The row inside the band of a table. It lays its children out as the flex
/// row of the reference does:
///
/// * the children are centred on the row's height, [gap] apart, in order;
/// * the room that is left over lies after the [KkTableBandPart.title], so
///   whatever follows the title ends at the right edge;
/// * when the row is too narrow, the title and the filter field give way in
///   proportion to their widths, the field no further than its least width;
///   after that the title gives up the rest, and what still does not fit
///   runs out at the right, where the band cuts it.
///
/// The room after the title is an item of the row as well, so there are two
/// gaps between a title that has given way and its neighbour.
///
/// One title and one filter are expected; further ones are laid out as
/// [KkTableBandPart.fixed].
///
/// This class is not part of the public API.
class KkTableBandRow extends MultiChildRenderObjectWidget {
  const KkTableBandRow({super.key, this.gap = 8, super.children});

  final double gap;

  @override
  RenderKkTableBandRow createRenderObject(BuildContext context) => RenderKkTableBandRow(gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderKkTableBandRow renderObject) {
    renderObject.gap = gap;
  }
}

/// What [RenderKkTableBandRow] works out before it places its children.
class _BandSizes {
  const _BandSizes({required this.size, required this.titleWidth, required this.spare});

  final Size size;

  /// The width the title is seen through.
  final double titleWidth;

  /// The room that is left over.
  final double spare;
}

/// The render object of [KkTableBandRow].
class RenderKkTableBandRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BandParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BandParentData> {
  RenderKkTableBandRow({double gap = 8}) : _gap = gap;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// The title, while it is cut, and the part of the row it is seen through.
  RenderBox? _cut;
  Rect? _cutRect;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BandParentData) child.parentData = _BandParentData();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  static double _sane(double v) => (v.isFinite && v > 0) ? v : 0;

  RenderBox? _firstOf(KkTableBandPart part) {
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      if (pd.part == part) return child;
      child = pd.nextSibling;
    }
    return null;
  }

  double _gaps(bool hasTitle) => childCount == 0 ? 0 : _gap * (childCount - 1 + (hasTitle ? 1 : 0));

  // ── intrinsics ───────────────────────────────────────────────────────────

  double _intrinsicWidth(double height, {required bool least}) {
    final RenderBox? title = _firstOf(KkTableBandPart.title);
    final RenderBox? filter = _firstOf(KkTableBandPart.filter);
    double width = _gaps(title != null);
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      if (identical(child, filter)) {
        final double basis = _sane(pd.basis);
        width += least ? math.min(_sane(pd.least), basis) : basis;
      } else if (identical(child, title)) {
        if (!least) width += child.getMaxIntrinsicWidth(height);
      } else {
        width += child.getMaxIntrinsicWidth(height);
      }
      child = pd.nextSibling;
    }
    return width;
  }

  double _intrinsicHeight(double Function(RenderBox child, double width) of) {
    final RenderBox? filter = _firstOf(KkTableBandPart.filter);
    double height = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      height = math.max(height, of(child, identical(child, filter) ? _sane(pd.basis) : double.infinity));
      child = pd.nextSibling;
    }
    return height;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth(height, least: true);

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth(height, least: false);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight((RenderBox child, double w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight((RenderBox child, double w) => child.getMaxIntrinsicHeight(w));

  // ── layout ───────────────────────────────────────────────────────────────

  _BandSizes _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final double maxHeight = constraints.maxHeight;
    final BoxConstraints own = BoxConstraints(maxHeight: maxHeight);
    // A lead is as high as a row of a given height. In a row that takes its
    // height from its children it is one of them.
    final BoxConstraints tall = (constraints.hasTightHeight && maxHeight.isFinite)
        ? BoxConstraints.tightFor(height: maxHeight)
        : own;
    final RenderBox? title = _firstOf(KkTableBandPart.title);
    final RenderBox? filter = _firstOf(KkTableBandPart.filter);
    double others = 0;
    double height = 0;
    double titleNatural = 0;
    double basis = 0;
    double least = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      if (identical(child, filter)) {
        basis = _sane(pd.basis);
        least = math.min(_sane(pd.least), basis);
      } else {
        final Size s = layoutChild(child, pd.part == KkTableBandPart.lead ? tall : own);
        height = math.max(height, s.height);
        if (identical(child, title)) {
          titleNatural = s.width;
        } else {
          others += s.width;
        }
      }
      child = pd.nextSibling;
    }

    final double natural = others + titleNatural + basis + _gaps(title != null);
    double titleWidth = titleNatural;
    double filterWidth = basis;
    double spare = 0;
    if (constraints.hasBoundedWidth) {
      final double room = constraints.maxWidth;
      if (natural > room) {
        // Both give way by the same share of their widths.
        final double deficit = natural - room;
        final double shrinkable = titleNatural + basis;
        if (shrinkable > 0) {
          final double keep = 1 - deficit / shrinkable;
          titleWidth = titleNatural * keep;
          filterWidth = basis * keep;
        }
        if (filterWidth < least) {
          // The field stops at its least width; the title gives up the rest.
          filterWidth = least;
          titleWidth = titleNatural - (deficit - (basis - least));
        }
        titleWidth = math.max(0, titleWidth);
        filterWidth = math.max(0, filterWidth);
      } else {
        spare = room - natural;
      }
    }
    if (filter != null) {
      final Size s = layoutChild(
        filter,
        BoxConstraints(minWidth: filterWidth, maxWidth: filterWidth, maxHeight: maxHeight),
      );
      height = math.max(height, s.height);
    }
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : natural;
    return _BandSizes(size: constraints.constrain(Size(width, height)), titleWidth: titleWidth, spare: spare);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  /// The band has no baseline: its children are centred, not set on a line.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    final _BandSizes r = _compute(constraints, ChildLayoutHelper.layoutChild);
    size = r.size;
    final RenderBox? title = _firstOf(KkTableBandPart.title);
    _cut = null;
    _cutRect = null;
    double x = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      pd.offset = Offset(x, (size.height - child.size.height) / 2);
      if (identical(child, title)) {
        if (r.titleWidth < child.size.width - precisionErrorTolerance) {
          _cut = child;
          _cutRect = Rect.fromLTWH(x, 0, r.titleWidth, size.height);
        }
        // The title, then the room that is left over, an item of its own.
        x += r.titleWidth + _gap + r.spare + _gap;
      } else {
        x += child.size.width + _gap;
      }
      child = pd.nextSibling;
    }
  }

  // ── paint and hit testing ────────────────────────────────────────────────

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? cut = _cut;
    final Rect? rect = _cutRect;
    bool clipped = false;
    RenderBox? child = firstChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      if (rect != null && identical(child, cut)) {
        final RenderBox title = child;
        if (!rect.isEmpty) {
          _clipLayer.layer = context.pushClipRect(
            needsCompositing,
            offset,
            rect,
            (PaintingContext inner, Offset origin) => inner.paintChild(title, origin + pd.offset),
            oldLayer: _clipLayer.layer,
          );
          clipped = true;
        }
      } else {
        context.paintChild(child, offset + pd.offset);
      }
      child = pd.nextSibling;
    }
    if (!clipped) _clipLayer.layer = null;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => identical(child, _cut) ? _cutRect : null;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? cut = _cut;
    final Rect? rect = _cutRect;
    RenderBox? child = lastChild;
    while (child != null) {
      final _BandParentData pd = child.parentData! as _BandParentData;
      final RenderBox target = child;
      final bool hidden = rect != null && identical(child, cut) && !rect.contains(position);
      if (!hidden) {
        final bool hit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (BoxHitTestResult r, Offset p) => target.hitTest(r, position: p),
        );
        if (hit) return true;
      }
      child = pd.previousSibling;
    }
    return false;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('gap', gap));
  }
}

/// A block at the left of the band whose right edge leans in by the large
/// chamfer: the code block, the selection count.
class _Slant extends StatelessWidget {
  const _Slant({required this.fill, required this.child});

  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    return KkSurface(
      shape: KkShape.slant(m.chamferLg),
      fill: fill,
      edgeWidth: 0,
      child: KkBox(
        padding: EdgeInsets.only(left: m.space3, right: m.space2 + m.chamferLg),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// The filter field of a table band: a 28px mono input on the void ground
/// with a clear button that keeps its place while the field is empty. It is
/// as wide as it is allowed to be: the band's row gives it 200px, less in a
/// narrow table.
///
/// This class is not part of the public API.
class KkTableFilterField extends StatefulWidget {
  const KkTableFilterField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder = 'filter',
    this.onChanged,
    this.semanticLabel = 'Filter rows',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final String semanticLabel;

  @override
  State<KkTableFilterField> createState() => _KkTableFilterFieldState();
}

class _KkTableFilterFieldState extends State<KkTableFilterField> {
  FocusNode? _ownFocusNode;
  bool _focused = false;
  bool _empty = true;

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkTableFilter'));

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    widget.controller.addListener(_onText);
    _empty = widget.controller.text.isEmpty;
  }

  @override
  void didUpdateWidget(KkTableFilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
      _focused = _focusNode.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _empty = widget.controller.text.isEmpty;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focusNode.hasFocus != _focused) setState(() => _focused = _focusNode.hasFocus);
  }

  void _onText() {
    final bool empty = widget.controller.text.isEmpty;
    if (empty != _empty) setState(() => _empty = empty);
  }

  void _clear() {
    if (widget.controller.text.isEmpty) return;
    widget.controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    return KkFocusRing(
      visible: _focused,
      offset: 1,
      width: m.stroke2,
      child: KkBox(
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: KkDecoration(
          fill: c.bg000,
          edges: KkEdges.line(_focused ? c.signal : c.inkFaint, width: m.stroke1),
        ),
        child: KkRow(
          gap: 6,
          children: <Widget>[
            KkIcon(KkIcons.filter, size: 12, color: c.inkDim),
            KkExpanded(
              child: KkTextInput(
                controller: widget.controller,
                focusNode: _focusNode,
                style: theme.type.mono(12, weight: FontWeight.w500, spacingEm: 0.04, color: c.ink),
                placeholder: widget.placeholder.toUpperCase(),
                placeholderStyle: theme.type.mono(12, weight: FontWeight.w500, spacingEm: 0.14, color: c.inkFaint),
                onChanged: widget.onChanged,
                semanticLabel: widget.semanticLabel,
              ),
            ),
            // The clear button keeps its place while there is nothing to clear.
            ExcludeFocus(
              excluding: _empty,
              child: ExcludeSemantics(
                excluding: _empty,
                child: IgnorePointer(
                  ignoring: _empty,
                  child: Opacity(
                    opacity: _empty ? 0 : 1,
                    child: KkPressable(
                      onPressed: _clear,
                      semanticLabel: 'Clear filter',
                      excludeSemantics: true,
                      builder: (BuildContext context, KkStates raw) {
                        final KkStates s = KkStateOverride.resolve(context, raw);
                        return KkFocusRing(
                          visible: s.focused,
                          offset: 1,
                          width: m.stroke2,
                          child: KkBox(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: KkIcon(KkIcons.close, size: 12, color: s.hovered ? c.ink : c.inkDim),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bulk action button of the selection band.
///
/// This class is not part of the public API.
class KkTableBulkButton extends StatefulWidget {
  const KkTableBulkButton({
    super.key,
    required this.action,
    required this.selected,
    this.disarm,
    this.squeeze = 0.8,
    this.initiallyArmed = false,
  });

  final KkTableBulkAction action;
  final Set<Object> selected;
  final Listenable? disarm;
  final double squeeze;

  /// Start armed (for catalogues and tests). The timeout still runs.
  final bool initiallyArmed;

  @override
  State<KkTableBulkButton> createState() => _KkTableBulkButtonState();
}

class _KkTableBulkButtonState extends State<KkTableBulkButton> {
  bool _armed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.disarm?.addListener(_disarm);
    if (widget.initiallyArmed && widget.action.danger && widget.action.onPressed != null) _arm();
  }

  @override
  void didUpdateWidget(KkTableBulkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disarm != widget.disarm) {
      oldWidget.disarm?.removeListener(_disarm);
      widget.disarm?.addListener(_disarm);
    }
    // What was armed was armed for the rows that were selected then.
    final bool sameRows =
        oldWidget.selected.length == widget.selected.length && oldWidget.selected.containsAll(widget.selected);
    if (_armed && (!sameRows || !widget.action.danger || widget.action.onPressed == null)) {
      _timer?.cancel();
      _armed = false;
    }
  }

  @override
  void dispose() {
    widget.disarm?.removeListener(_disarm);
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.action.armTimeout, _disarm);
    _armed = true;
  }

  void _disarm() {
    _timer?.cancel();
    if (_armed && mounted) setState(() => _armed = false);
  }

  void _press() {
    final KkTableBulkAction a = widget.action;
    if (a.danger && !_armed) {
      setState(_arm);
      return;
    }
    _timer?.cancel();
    if (_armed) setState(() => _armed = false);
    a.onPressed?.call(Set<Object>.of(widget.selected));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_armed && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _disarm();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkTableBulkAction a = widget.action;
    final bool live = a.onPressed != null;
    final bool armed = _armed && live;
    final KkIconData? icon = a.icon;

    Widget text(String? cjk, String label, Color ink) => KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      main: KkMainAlign.center,
      gap: 5,
      children: <Widget>[
        if (cjk != null && cjk.isNotEmpty) KkText.cjk(cjk, size: 13, color: ink, squeeze: widget.squeeze),
        KkText.en(label, size: 12, weight: FontWeight.w700, spacing: 0.1, color: ink),
      ],
    );

    Widget hidden(Widget child, bool hide) => IgnorePointer(
      ignoring: hide,
      child: Opacity(opacity: hide ? 0 : 1, child: child),
    );

    return TapRegion(
      onTapOutside: (PointerDownEvent _) => _disarm(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: KkPressable(
          onPressed: live ? _press : null,
          onFocusChanged: (bool focused) {
            if (!focused) _disarm();
          },
          semanticLabel: armed ? '${a.confirmLabel} ${a.label}' : a.label,
          excludeSemantics: true,
          builder: (BuildContext context, KkStates raw) {
            final KkStates s = KkStateOverride.resolve(context, raw);
            final Color ink = !live ? c.inkFaint : (armed ? c.onFill : (a.danger ? c.alert : c.signal));
            final Color fill = armed ? c.alert : (s.hovered ? c.bg300 : c.bg000);
            return KkFocusRing(
              visible: s.focused,
              offset: 2,
              width: m.stroke2,
              child: KkBlink(
                period: const Duration(seconds: 1),
                enabled: armed,
                child: KkSurface(
                  shape: KkShape.plate(m.chamferSm),
                  fill: fill,
                  edgeWidth: 0,
                  child: KkBox(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    shrinkWrap: true,
                    child: KkRow(
                      shrinkWrap: true,
                      gap: 6,
                      children: <Widget>[
                        if (icon != null) KkIcon(icon, size: 12, color: ink),
                        // Both readings share one place, so arming does not
                        // change the width of the button.
                        KkLayers(
                          alignment: Alignment.center,
                          children: <Widget>[
                            hidden(text(a.cjk, a.label, ink), armed),
                            if (a.danger) hidden(text(a.confirmCjk ?? a.cjk, a.confirmLabel, ink), !armed),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
