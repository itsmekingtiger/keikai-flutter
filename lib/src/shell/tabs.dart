import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'shell_paint.dart';

/// The two weights of a [KkTabs] bar.
enum KkTabsVariant {
  /// 40px tabs with a 4px signal bar under the selected one. Top-level views.
  primary,

  /// 32px tabs with a 2px bar. Views inside a panel.
  secondary,
}

/// One tab of a [KkTabs] bar.
@immutable
class KkTab {
  const KkTab({this.cjk, this.en, this.code, this.icon, this.enabled = true, this.semanticLabel})
    : assert(cjk != null || en != null || code != null || icon != null, 'A tab needs something to show.');

  /// The title in 漢字 or Hangul.
  final String? cjk;

  /// The title in Latin capitals; it is upper-cased.
  final String? en;

  /// A short mono code before the title: `01`, `T-2`.
  final String? code;
  final KkIconData? icon;
  final bool enabled;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;
}

/// A row of tabs with a line under it. The selected tab is marked by a signal
/// bar that sits on the line.
///
/// The bar scrolls sideways (without a scrollbar) when the tabs do not fit and
/// keeps the selected tab in view. Left and Right move to the neighbouring
/// tab, Home and End to the first and last; only the selected tab is in the
/// Tab order. With [onChanged] null every tab is disabled.
class KkTabs extends StatefulWidget {
  const KkTabs({
    super.key,
    required this.tabs,
    required this.index,
    this.onChanged,
    this.variant = KkTabsVariant.primary,
    this.autofocus = false,
  });

  final List<KkTab> tabs;

  /// The selected tab.
  final int index;
  final ValueChanged<int>? onChanged;
  final KkTabsVariant variant;

  /// Focus the selected tab when first shown.
  final bool autofocus;

  @override
  State<KkTabs> createState() => _KkTabsState();
}

class _KkTabsState extends State<KkTabs> {
  final ScrollController _scroll = ScrollController();
  final List<FocusNode> _nodes = <FocusNode>[];
  final List<GlobalKey> _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
    _revealSelected();
  }

  @override
  void didUpdateWidget(KkTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
    if (oldWidget.index != widget.index || oldWidget.tabs.length != widget.tabs.length) _revealSelected();
  }

  void _syncNodes() {
    while (_nodes.length < widget.tabs.length) {
      _nodes.add(FocusNode(debugLabel: 'KkTab ${_nodes.length}'));
      _keys.add(GlobalKey());
    }
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
      _keys.removeLast();
    }
    for (int i = 0; i < _nodes.length; i++) {
      // A roving tab stop: Tab reaches the selected tab only.
      _nodes[i].skipTraversal = i != widget.index;
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !_scroll.hasClients) return;
      final int i = widget.index;
      if (i < 0 || i >= _keys.length) return;
      final RenderObject? box = _keys[i].currentContext?.findRenderObject();
      if (box == null) return;
      final ScrollPosition position = _scroll.position;
      position.ensureVisible(box, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      position.ensureVisible(box, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  bool _enabled(int i) => widget.onChanged != null && widget.tabs[i].enabled;

  int get _focusedOrSelected {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return widget.index;
  }

  void _go(int i) {
    if (i < 0 || i >= widget.tabs.length || !_enabled(i)) return;
    _nodes[i].requestFocus();
    if (i != widget.index) widget.onChanged?.call(i);
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final int count = widget.tabs.length;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(kkNextEnabled(_focusedOrSelected, 1, count, _enabled)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(kkNextEnabled(_focusedOrSelected, -1, count, _enabled)),
        const SingleActivator(LogicalKeyboardKey.home): () => _go(kkEdgeEnabled(count, _enabled)),
        const SingleActivator(LogicalKeyboardKey.end): () => _go(kkEdgeEnabled(count, _enabled, last: true)),
      },
      child: CustomPaint(
        painter: _TabLinePainter(color: c.line, thickness: m.stroke1),
        child: KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkFlexible(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _scroll,
                  // The 1px under the tabs is where the line runs; the bar of
                  // the selected tab reaches down over it.
                  child: KkBox(
                    padding: EdgeInsets.only(bottom: m.stroke1),
                    child: KkRow(
                      shrinkWrap: true,
                      cross: KkCrossAlign.start,
                      children: <Widget>[
                        for (int i = 0; i < count; i++)
                          _KkTabButton(
                            key: _keys[i],
                            tab: widget.tabs[i],
                            selected: i == widget.index,
                            variant: widget.variant,
                            focusNode: _nodes[i],
                            autofocus: widget.autofocus && i == widget.index,
                            onPressed: _enabled(i) ? () => _go(i) : null,
                          ),
                      ],
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

class _TabLinePainter extends CustomPainter {
  const _TabLinePainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, size.height - thickness, size.width, thickness), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TabLinePainter oldDelegate) => oldDelegate.color != color || oldDelegate.thickness != thickness;
}

class _KkTabButton extends StatelessWidget {
  const _KkTabButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.variant,
    required this.focusNode,
    required this.autofocus,
    required this.onPressed,
  });

  final KkTab tab;
  final bool selected;
  final KkTabsVariant variant;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool primary = variant == KkTabsVariant.primary;
    final String? code = tab.code;
    final String? cjk = tab.cjk;
    final String? en = tab.en;
    final KkIconData? icon = tab.icon;
    return KkPressable(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      selected: selected,
      semanticLabel: tab.semanticLabel,
      excludeSemantics: tab.semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final Color ink = !s.enabled ? c.inkFaint : (selected || s.hovered ? c.ink : c.inkDim);
        final Color enInk = s.enabled && selected ? c.signal : ink;
        return KkFocusRing(
          visible: s.focused,
          offset: -m.stroke2,
          width: m.stroke2,
          child: CustomPaint(
            painter: KkItemGroundPainter(
              fill: s.hovered ? c.bg200 : null,
              mark: selected ? KkItemMark.bottom : KkItemMark.none,
              markColor: c.signal,
              thickness: primary ? m.stroke4 : m.stroke2,
              overhang: m.stroke1,
            ),
            child: KkBox(
              height: primary ? 40 : m.space8,
              padding: EdgeInsets.symmetric(horizontal: primary ? m.space4 : m.space3),
              child: KkRow(
                shrinkWrap: true,
                gap: m.space2,
                children: <Widget>[
                  if (code != null && code.isNotEmpty)
                    KkText.num(code, size: 10, weight: FontWeight.w500, color: c.inkFaint),
                  if (icon != null) KkIcon(icon, color: enInk),
                  if (cjk != null && cjk.isNotEmpty) KkText.cjk(cjk, size: 15, color: ink, squeeze: 0.8),
                  if (en != null && en.isNotEmpty)
                    KkText.en(en, size: primary ? 12 : 11, spacing: 0.12, color: enInk),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows the body that belongs to the selected tab. When [index] changes the
/// new body wipes in from the left (0.42s, 7 steps); the first body appears
/// at once.
class KkTabView extends StatefulWidget {
  const KkTabView({
    super.key,
    required this.index,
    required this.children,
    this.wipe = true,
    this.maintainState = false,
  });

  /// The body to show; clamped to the valid range.
  final int index;

  /// One body per tab.
  final List<Widget> children;

  /// Play the wipe when the body changes.
  final bool wipe;

  /// Keep the bodies that are not shown alive (scroll positions, field
  /// contents). All of them are then built and laid out.
  final bool maintainState;

  @override
  State<KkTabView> createState() => _KkTabViewState();
}

class _KkTabViewState extends State<KkTabView> {
  int _changes = 0;

  @override
  void didUpdateWidget(KkTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _changes++;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const KkBox();
    final int i = widget.index.clamp(0, widget.children.length - 1);
    final Widget body = widget.maintainState
        ? IndexedStack(index: i, sizing: StackFit.passthrough, children: widget.children)
        : KeyedSubtree(key: ValueKey<int>(i), child: widget.children[i]);
    return KkBoot(trigger: _changes, enabled: widget.wipe && _changes > 0, stagger: false, child: body);
  }
}
