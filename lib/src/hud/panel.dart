import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../motion/effects.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'fill_column.dart';

/// The looks of a [KkPanel].
enum KkPanelVariant {
  /// The head band is filled with the frame colour.
  standard,

  /// A secondary panel: the head band is a quiet bg-200 with ink text.
  quiet,

  /// The selected panel: signal border and the signal glow.
  active,
}

const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// The KEIKAI panel: a bracketed frame with a 32px head band.
///
/// The head carries a code block (`SEC-04`), the title in two languages and
/// meta at the right. The body is whatever you give it. A panel fills a grid
/// cell when its height is fixed, and is as tall as its content otherwise.
///
/// * [level] critical turns the frame red, adds the alarm glow and a running
///   hazard strip at the end of the head; offline dashes the border and drains
///   the body of colour. Nominal and caution leave the frame as it is.
/// * [spine] adds a 24px column of upright vertical text down the left side.
/// * [collapsible] adds a toggle that hides the body.
///
/// On entry the panel wipes in from the left, the head band grows and the
/// body flickers on.
class KkPanel extends StatefulWidget {
  const KkPanel({
    super.key,
    this.code,
    this.cjk,
    this.en,
    this.meta,
    this.trailing = const <Widget>[],
    this.level,
    this.variant = KkPanelVariant.standard,
    this.spine,
    this.flush = false,
    this.padding,
    this.scrollBody = false,
    this.collapsible = false,
    this.collapsed,
    this.initiallyCollapsed = false,
    this.onToggle,
    this.brackets = true,
    this.boot = true,
    this.frameColor,
    this.fill,
    this.squeeze = 0.8,
    this.semanticLabel,
    this.child,
  });

  /// The identifier in the black code block, such as `SEC-04`.
  final String? code;

  /// The CJK title (2 to 6 characters reads best).
  final String? cjk;

  /// The Latin subtitle; shown in capitals.
  final String? en;

  /// Short mono text at the right of the head (a time, a count).
  final String? meta;

  /// Widgets at the right of the head, after [meta]: tags, small buttons.
  /// Plain text and icons among them take the head's ink.
  final List<Widget> trailing;

  /// Critical and offline change the frame; other levels do not.
  final KkLevel? level;
  final KkPanelVariant variant;

  /// Upright vertical text down the left edge of the body.
  final String? spine;

  /// Remove the body padding (for a chart or a table that brings its own).
  final bool flush;

  /// Body padding; 16 all round unless [flush].
  final EdgeInsets? padding;

  /// Let the body scroll when the content is taller than the panel. Leave it
  /// off for content that should fill the body, such as a chart.
  final bool scrollBody;

  /// Show a toggle in the head that hides the body and the spine.
  final bool collapsible;

  /// Whether the body is hidden. When null the panel keeps this state itself.
  final bool? collapsed;

  /// The state a self-managed panel starts in.
  final bool initiallyCollapsed;

  /// Called with the new collapsed state when the toggle is pressed.
  final ValueChanged<bool>? onToggle;

  /// Draw the four corner brackets.
  final bool brackets;

  /// Play the entrance (wipe, head grow, body flicker) when first shown.
  final bool boot;

  /// Overrides the frame colour (signal; alert when critical; offline).
  final Color? frameColor;

  /// Overrides the panel ground (bg-100).
  final Color? fill;

  /// Horizontal compression of the CJK title; 1.0 turns it off.
  final double squeeze;

  /// Read by screen readers instead of the title.
  final String? semanticLabel;

  /// The body.
  final Widget? child;

  @override
  State<KkPanel> createState() => _KkPanelState();
}

class _KkPanelState extends State<KkPanel> {
  late bool _collapsed = widget.initiallyCollapsed;
  bool _toggled = false;

  bool get _isCollapsed => widget.collapsible && (widget.collapsed ?? _collapsed);

  void _toggle() {
    final bool next = !_isCollapsed;
    setState(() {
      _toggled = true;
      if (widget.collapsed == null) _collapsed = next;
    });
    widget.onToggle?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool critical = widget.level == KkLevel.critical;
    final bool offline = widget.level == KkLevel.offline;
    final bool quiet = widget.variant == KkPanelVariant.quiet;
    final bool active = widget.variant == KkPanelVariant.active;
    final Color frame =
        widget.frameColor ??
        (critical
            ? c.alert
            : offline
            ? c.offline
            : c.signal);
    final Color border = critical
        ? c.alert
        : offline
        ? c.offline
        : active
        ? c.signal
        : c.line;
    final KkGlow? glow = critical
        ? c.glowAlert
        : active
        ? c.glowSignal
        : null;

    Widget head = _head(theme, frame, quiet: quiet, critical: critical);
    if (widget.boot) {
      head = KkGrow(delay: const Duration(milliseconds: 100), child: head);
    }

    Widget? body;
    final Widget? child = widget.child;
    final bool collapsed = _isCollapsed;
    if (child != null && !collapsed) {
      final String? spine = widget.spine;
      final EdgeInsets pad = widget.flush ? EdgeInsets.zero : (widget.padding ?? EdgeInsets.all(m.space4));
      Widget content = widget.scrollBody ? KkScroll(padding: pad, child: child) : KkBox(padding: pad, child: child);
      if (spine != null) content = KkBox(padding: EdgeInsets.only(left: m.space6), child: content);
      if (offline) content = ColorFiltered(colorFilter: _greyscale, child: content);
      body = _PanelBody(
        spineWidth: m.space6,
        children: <Widget>[
          content,
          if (spine != null)
            KkBox(
              width: m.space6,
              padding: EdgeInsets.symmetric(vertical: m.space3),
              edges: KkEdges(right: KkSide(c.line, width: m.stroke1)),
              alignment: Alignment.topLeft,
              clip: true,
              child: KkTate(spine, size: 14, color: frame, columnWidth: m.space6 - m.stroke1 - 1, spacing: 0.12),
            ),
        ],
      );
      if (widget.boot) {
        // After the first toggle the body comes back at once, without waiting
        // for its place in the boot sequence.
        body = KkFlicker(
          delay: _toggled ? Duration.zero : const Duration(milliseconds: 300),
          stagger: !_toggled,
          child: body,
        );
      }
    }

    Widget panel = KkBox(
      decoration: KkDecoration(
        fill: widget.fill ?? c.bg100,
        edges: KkEdges.line(border, width: m.stroke1, dashed: offline),
        brackets: widget.brackets
            ? KkBracketSpec(color: frame, length: m.space3, width: m.stroke2, outset: 0)
            : null,
        glow: glow,
      ),
      child: KkFillColumn(leading: <Widget>[head], body: body),
    );
    if (widget.boot) panel = KkBoot(child: panel);
    final String label =
        widget.semanticLabel ??
        <String>[?widget.code, ?widget.cjk, ?widget.en].join(' ');
    return Semantics(container: true, label: label.isEmpty ? null : label, child: panel);
  }

  Widget _head(KeikaiThemeData theme, Color frame, {required bool quiet, required bool critical}) {
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color ink = quiet ? c.ink : c.onFill;
    final Color dim = quiet ? c.inkDim : c.onFill;
    final String? code = widget.code;
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    final String? meta = widget.meta;
    final bool hasMeta = meta != null || widget.trailing.isNotEmpty;
    return KkBox(
      height: m.space8,
      fill: quiet ? c.bg200 : frame,
      edges: quiet ? KkEdges(bottom: KkSide(c.line, width: m.stroke1)) : null,
      child: KkRow(
        cross: KkCrossAlign.stretch,
        children: <Widget>[
          if (code != null)
            KkSurface(
              shape: KkShape.slant(m.chamferLg),
              fill: quiet ? frame : c.bg000,
              edgeWidth: 0,
              child: KkBox(
                padding: EdgeInsets.only(left: m.space3, right: m.space2 + m.chamferLg),
                alignment: Alignment.center,
                child: KkText.num(
                  code,
                  size: 11,
                  weight: FontWeight.w600,
                  spacing: 0.06,
                  color: quiet ? c.onFill : frame,
                ),
              ),
            ),
          KkExpanded(
            child: KkBox(
              padding: EdgeInsets.only(left: m.space2, right: m.space3),
              alignment: Alignment.centerLeft,
              clip: true,
              child: Semantics(
                header: true,
                child: KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.baseline,
                  gap: m.space2,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    if (cjk != null) KkText.cjk(cjk, size: 21, color: ink, squeeze: widget.squeeze),
                    if (en != null)
                      KkText.en(en, size: 11, weight: FontWeight.w700, height: 1.55, spacing: 0.14, color: dim),
                  ],
                ),
              ),
            ),
          ),
          if (hasMeta)
            KkBox(
              padding: EdgeInsets.only(left: m.space3, right: m.space2),
              alignment: Alignment.center,
              child: DefaultTextStyle(
                style: theme.type.mono(11, weight: FontWeight.w600, color: dim),
                child: KkRow(
                  shrinkWrap: true,
                  gap: m.space2,
                  children: <Widget>[
                    if (meta != null) KkText.num(meta, size: 11, weight: FontWeight.w600, color: dim),
                    ...widget.trailing,
                  ],
                ),
              ),
            ),
          if (widget.collapsible)
            _PanelToggle(
              collapsed: _isCollapsed,
              quiet: quiet,
              onPressed: _toggle,
            ),
          if (critical)
            KkHazard(
              color: c.onFill,
              background: const Color(0x00000000),
              running: true,
              width: m.space12,
            ),
        ],
      ),
    );
  }
}

class _PanelToggle extends StatelessWidget {
  const _PanelToggle({required this.collapsed, required this.quiet, required this.onPressed});

  final bool collapsed;
  final bool quiet;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    return KkPressable(
      onPressed: onPressed,
      semanticLabel: collapsed ? 'Expand panel' : 'Collapse panel',
      excludeSemantics: true,
      builder: (BuildContext context, KkStates states) {
        return KkFocusRing(
          visible: states.focused,
          offset: -2,
          // On the signal band the usual light ring would vanish.
          color: quiet ? null : c.bg000,
          child: KkSurface(
            shape: KkShape.chamfer(tl: m.chamferSm),
            fill: states.hovered ? kkFade(c.bg000, 0.22) : null,
            child: KkBox(
              width: m.space8,
              height: m.space8,
              alignment: Alignment.center,
              child: KkIcon(collapsed ? KkIcons.chevronDown : KkIcons.chevronUp, color: quiet ? c.inkDim : c.onFill),
            ),
          ),
        );
      },
    );
  }
}

class _PanelBodyParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays the panel body out and pins the spine (the optional second child)
/// over its left edge, as tall as the body.
class _PanelBody extends MultiChildRenderObjectWidget {
  const _PanelBody({required this.spineWidth, super.children});

  final double spineWidth;

  @override
  _RenderPanelBody createRenderObject(BuildContext context) => _RenderPanelBody(spineWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderPanelBody renderObject) {
    renderObject.spineWidth = spineWidth;
  }
}

class _RenderPanelBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PanelBodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PanelBodyParentData> {
  _RenderPanelBody(this._spineWidth);

  double _spineWidth;
  double get spineWidth => _spineWidth;
  set spineWidth(double value) {
    if (value == _spineWidth) return;
    _spineWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PanelBodyParentData) child.parentData = _PanelBodyParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) => firstChild?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => firstChild?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => firstChild?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(firstChild?.getDryLayout(constraints) ?? Size.zero);

  @override
  void performLayout() {
    final RenderBox? content = firstChild;
    if (content == null) {
      size = constraints.smallest;
      return;
    }
    content.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(content.size);
    final RenderBox? spine = childAfter(content);
    spine?.layout(BoxConstraints.tightFor(width: _spineWidth, height: size.height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
