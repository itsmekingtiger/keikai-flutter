import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../layout/screen.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'shell_paint.dart';

/// One destination of a [KkNavRail].
@immutable
class KkNavItem {
  const KkNavItem({required this.icon, required this.label, this.badge, this.enabled = true, this.semanticLabel});

  final KkIconData icon;

  /// The caption under the icon; it is upper-cased. Keep it to one short word.
  final String label;

  /// Pinned over the top-right corner of the icon, usually a `KkBadge`.
  final Widget? badge;
  final bool enabled;

  /// Replaces [label] for screen readers.
  final String? semanticLabel;
}

/// The narrow navigation column at the left of a screen: an icon and a
/// one-word caption per destination.
///
/// 72px wide on the panel colour. The current destination has a lit icon, a
/// lighter ground and a short signal bar at its left edge.
///
/// Inside a `KkScreen` narrower than 600px the rail lays itself out as a 64px
/// bar along the bottom (the mark moves to the top edge and the [header] is
/// hidden). Force either form with [bar].
///
/// Up and Down (Left and Right in bar form) move the keyboard focus between
/// destinations; Enter or Space goes there. With [onChanged] null every
/// destination is disabled.
class KkNavRail extends StatefulWidget {
  const KkNavRail({
    super.key,
    required this.items,
    this.index,
    this.onChanged,
    this.header,
    this.trailing,
    this.bar,
    this.width,
    this.semanticLabel = 'Navigation',
  });

  final List<KkNavItem> items;

  /// The current destination, or null when none of them is.
  final int? index;
  final ValueChanged<int>? onChanged;

  /// A slot above the destinations (a logo plate, a menu button). Hidden in
  /// bar form.
  final Widget? header;

  /// A slot pinned to the bottom of the rail. Hidden in bar form.
  final Widget? trailing;

  /// True lays the rail out as a horizontal bar, false as a column. Null
  /// follows the enclosing `KkScreen`.
  final bool? bar;

  /// Width of the column form. Defaults to the theme's rail width (72).
  final double? width;

  /// Names the rail for screen readers.
  final String semanticLabel;

  @override
  State<KkNavRail> createState() => _KkNavRailState();
}

class _KkNavRailState extends State<KkNavRail> {
  final List<FocusNode> _nodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(KkNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  void _syncNodes() {
    while (_nodes.length < widget.items.length) {
      _nodes.add(FocusNode(debugLabel: 'KkNavItem ${_nodes.length}'));
    }
    while (_nodes.length > widget.items.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool _enabled(int i) => widget.onChanged != null && widget.items[i].enabled;

  void _move(int delta) {
    int from = -1;
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) from = i;
    }
    if (from < 0) return;
    final int to = kkNextEnabled(from, delta, _nodes.length, _enabled);
    if (to != from) _nodes[to].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool bar = widget.bar ?? KkScreenScope.maybeOf(context)?.navIsBar ?? false;
    final Widget? header = widget.header;
    final Widget? trailing = widget.trailing;

    final List<Widget> items = <Widget>[
      for (int i = 0; i < widget.items.length; i++)
        _KkNavRailItem(
          item: widget.items[i],
          current: i == widget.index,
          bar: bar,
          focusNode: _nodes[i],
          onPressed: _enabled(i) ? () => widget.onChanged?.call(i) : null,
        ),
    ];

    final Widget body = bar
        ? KkBox(
            height: 64,
            decoration: KkDecoration(
              fill: c.bg100,
              edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
            ),
            child: KkRow(
              cross: KkCrossAlign.stretch,
              gap: m.space1,
              children: <Widget>[for (final Widget item in items) KkExpanded(child: item)],
            ),
          )
        : KkBox(
            width: widget.width ?? m.railWidth,
            decoration: KkDecoration(
              fill: c.bg100,
              edges: KkEdges(right: KkSide(c.line, width: m.stroke1)),
            ),
            padding: EdgeInsets.symmetric(vertical: m.space2),
            // `between` keeps the trailing slot on the bottom edge whether the
            // rail is given a height or only a minimum one.
            child: KkColumn(
              main: KkMainAlign.between,
              children: <Widget>[
                KkColumn(
                  shrinkWrap: true,
                  gap: m.space1,
                  children: <Widget>[
                    if (header != null)
                      KkAlignSelf(
                        align: KkCrossAlign.center,
                        child: KkBox(
                          padding: EdgeInsets.only(top: m.space1, bottom: m.space3),
                          child: header,
                        ),
                      ),
                    ...items,
                  ],
                ),
                if (trailing != null) KkAlignSelf(align: KkCrossAlign.center, child: trailing),
              ],
            ),
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          SingleActivator(bar ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown): () => _move(1),
          SingleActivator(bar ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowUp): () => _move(-1),
        },
        child: body,
      ),
    );
  }
}

class _KkNavRailItem extends StatelessWidget {
  const _KkNavRailItem({
    required this.item,
    required this.current,
    required this.bar,
    required this.focusNode,
    required this.onPressed,
  });

  final KkNavItem item;
  final bool current;
  final bool bar;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Widget? badge = item.badge;
    return KkPressable(
      onPressed: onPressed,
      focusNode: focusNode,
      selected: current,
      semanticLabel: item.semanticLabel ?? item.label,
      excludeSemantics: true,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final bool lit = s.enabled && (current || s.hovered);
        final Color ink = !s.enabled ? c.inkFaint : (lit ? c.ink : c.inkDim);
        final Color iconInk = s.enabled && current ? c.signal : ink;
        final Widget icon = KkIcon(item.icon, color: iconInk);
        return KkFocusRing(
          visible: s.focused,
          offset: -3,
          width: m.stroke2,
          child: CustomPaint(
            painter: KkItemGroundPainter(
              fill: lit ? c.bg200 : null,
              mark: s.enabled && current ? (bar ? KkItemMark.top : KkItemMark.left) : KkItemMark.none,
              markColor: c.signal,
              thickness: m.space1,
              length: bar ? m.space6 : m.space4,
            ),
            child: KkBox(
              height: bar ? null : 56,
              alignment: Alignment.center,
              child: KkColumn(
                shrinkWrap: true,
                cross: KkCrossAlign.center,
                gap: 5,
                children: <Widget>[
                  if (badge == null)
                    icon
                  else
                    KkLayers(
                      children: <Widget>[
                        icon,
                        KkPositioned(top: -6, right: -10, child: IgnorePointer(child: badge)),
                      ],
                    ),
                  KkText.en(
                    item.label,
                    size: 10,
                    spacing: 0.12,
                    color: ink,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
