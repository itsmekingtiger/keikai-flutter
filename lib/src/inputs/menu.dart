import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/routes.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';
import 'modality.dart';
import 'popup.dart';

/// One entry of a menu: a [KkMenuItem], a [KkMenuSeparator] or a
/// [KkMenuLabel].
@immutable
sealed class KkMenuEntry<T> {
  const KkMenuEntry();
}

/// A row of a menu the user can choose.
class KkMenuItem<T> extends KkMenuEntry<T> {
  const KkMenuItem({
    this.value,
    required this.label,
    this.cjk,
    this.icon,
    this.shortcut,
    this.checked,
    this.danger = false,
    this.enabled = true,
    this.closeOnPressed = true,
    this.onPressed,
    this.semanticLabel,
  });

  /// What the menu reports when this item is chosen.
  final T? value;

  /// The Latin label. It is shown in capitals.
  final String label;

  /// An optional CJK label shown before [label].
  final String? cjk;

  /// Icon in the 16px slot at the left.
  final KkIconData? icon;

  /// Keyboard hint at the right, such as `CTRL+K`.
  final String? shortcut;

  /// For a checkable item: true lights the icon slot (a tick when the item
  /// has no [icon]); false leaves it dark. Null for a plain action.
  final bool? checked;

  /// A destructive action: alert text, alert-deep ground when highlighted.
  final bool danger;
  final bool enabled;

  /// Whether choosing the item closes a popup menu.
  final bool closeOnPressed;

  /// Called when the item is chosen, before the menu's `onSelected`.
  final VoidCallback? onPressed;
  final String? semanticLabel;
}

/// A 1px rule between groups of items.
class KkMenuSeparator<T> extends KkMenuEntry<T> {
  const KkMenuSeparator();
}

/// A small caption above a group of items.
class KkMenuLabel<T> extends KkMenuEntry<T> {
  const KkMenuLabel(this.text);

  final String text;
}

/// The menu surface: a panel-coloured list with a 2px signal top edge.
///
/// It can sit inline in a page, but most menus float: see [KkMenuAnchor] and
/// [showKkMenu].
///
/// One highlight is shared by pointer and keyboard. Arrow keys, Home and End
/// move it (disabled items are skipped), Enter or Space chooses, typing a
/// letter jumps to the next item starting with it, Escape calls [onDismiss].
class KkMenu<T> extends StatefulWidget {
  const KkMenu({
    super.key,
    required this.entries,
    this.onSelected,
    this.onDismiss,
    this.minWidth = 232,
    this.width,
    this.maxHeight,
    this.autofocus = false,
    this.trapFocus = false,
    this.canRequestFocus = true,
    this.focusNode,
    this.initialValue,
    this.semanticLabel,
  });

  final List<KkMenuEntry<T>> entries;

  /// Called with the chosen item (after its own `onPressed`).
  final ValueChanged<KkMenuItem<T>>? onSelected;

  /// Called on Escape.
  final VoidCallback? onDismiss;
  final double minWidth;

  /// A fixed width; by default the menu is as wide as its widest item.
  final double? width;

  /// The list scrolls beyond this height.
  final double? maxHeight;

  /// Take keyboard focus as soon as the menu is shown.
  final bool autofocus;

  /// Keep Tab and Shift+Tab inside the menu (they move the highlight).
  final bool trapFocus;

  /// Whether the menu may take keyboard focus. Turn it off for a menu that
  /// serves another focused control (a text field's own menu): the pointer
  /// then drives it and the focus stays where it was.
  final bool canRequestFocus;
  final FocusNode? focusNode;

  /// The item with this value starts highlighted.
  final T? initialValue;
  final String? semanticLabel;

  @override
  State<KkMenu<T>> createState() => _KkMenuState<T>();
}

class _KkMenuState<T> extends State<KkMenu<T>> {
  FocusNode? _ownNode;
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey<State<StatefulWidget>>> _keys = <int, GlobalKey<State<StatefulWidget>>>{};
  int? _active;
  bool _keyboard = false;
  String _typed = '';
  Timer? _typeTimer;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'KkMenu'));

  @override
  void initState() {
    super.initState();
    final T? initial = widget.initialValue;
    if (initial != null) {
      for (int i = 0; i < widget.entries.length; i++) {
        final KkMenuEntry<T> e = widget.entries[i];
        if (e is KkMenuItem<T> && e.value == initial) {
          _active = i;
          break;
        }
      }
    }
    KkInputModality.watch();
    if (widget.autofocus) {
      _keyboard = KkInputModality.keyboard;
      if (_active == null && _keyboard) _active = _firstEnabled();
      _node.requestFocus();
    }
    if (_active != null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) _reveal();
      });
    }
  }

  @override
  void didUpdateWidget(KkMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? a = _active;
    if (a != null && (a >= widget.entries.length || widget.entries[a] is! KkMenuItem<T>)) _active = null;
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _ownNode?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<int> _enabledIndices() => <int>[
    for (int i = 0; i < widget.entries.length; i++)
      if (widget.entries[i] case final KkMenuItem<T> item when item.enabled) i,
  ];

  int? _firstEnabled() {
    final List<int> list = _enabledIndices();
    return list.isEmpty ? null : list.first;
  }

  void _setActive(int? index, {required bool keyboard}) {
    if (_active == index && _keyboard == keyboard) return;
    setState(() {
      _active = index;
      _keyboard = keyboard;
    });
    if (keyboard) _reveal();
  }

  void _reveal() {
    final BuildContext? ctx = _keys[_active]?.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    // Scroll only as far as needed, whichever edge the row is beyond.
    Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
  }

  void _move(int delta) {
    final List<int> list = _enabledIndices();
    if (list.isEmpty) return;
    final int at = _active == null ? -1 : list.indexOf(_active!);
    final int next = at < 0 ? (delta > 0 ? 0 : list.length - 1) : (at + delta) % list.length;
    _setActive(list[next < 0 ? next + list.length : next], keyboard: true);
  }

  void _activate(KkMenuItem<T> item) {
    if (!item.enabled) return;
    item.onPressed?.call();
    widget.onSelected?.call(item);
  }

  void _typeAhead(String character) {
    _typeTimer?.cancel();
    _typeTimer = Timer(const Duration(milliseconds: 700), () => _typed = '');
    _typed += character.toLowerCase();
    final List<int> list = _enabledIndices();
    if (list.isEmpty) return;
    // With one letter typed, start after the current item so that repeating
    // the letter cycles through the matches.
    final int at = _active == null ? -1 : list.indexOf(_active!);
    final int start = _typed.length == 1 ? at + 1 : (at < 0 ? 0 : at);
    for (int k = 0; k < list.length; k++) {
      final int index = list[(start + k) % list.length];
      final KkMenuItem<T> item = widget.entries[index] as KkMenuItem<T>;
      final String label = item.label.toLowerCase();
      final String cjk = (item.cjk ?? '').toLowerCase();
      if (label.startsWith(_typed) || (cjk.isNotEmpty && cjk.startsWith(_typed))) {
        _setActive(index, keyboard: true);
        return;
      }
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      final List<int> list = _enabledIndices();
      if (list.isNotEmpty) _setActive(key == LogicalKeyboardKey.home ? list.first : list.last, keyboard: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && widget.trapFocus) {
      _move(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && widget.onDismiss != null) {
      widget.onDismiss!();
      return KeyEventResult.handled;
    }
    final bool space = key == LogicalKeyboardKey.space;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || (space && _typed.isEmpty)) {
      final int? a = _active;
      if (a != null && event is KeyDownEvent) _activate(widget.entries[a] as KkMenuItem<T>);
      return KeyEventResult.handled;
    }
    final String? ch = event.character;
    final bool modified =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (ch != null && ch.length == 1 && !modified && ch.codeUnitAt(0) >= 0x20 && ch.codeUnitAt(0) != 0x7F) {
      _typeAhead(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange(bool focused) {
    setState(() {
      if (!focused) {
        _keyboard = false;
      } else if (KkInputModality.keyboard) {
        _keyboard = true;
        _active ??= _firstEnabled();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool showFocus = _keyboard && _node.hasFocus;
    final List<Widget> rows = <Widget>[
      for (int i = 0; i < widget.entries.length; i++)
        switch (widget.entries[i]) {
          final KkMenuItem<T> item => _KkMenuRow<T>(
            key: _keys.putIfAbsent(i, GlobalKey<State<StatefulWidget>>.new),
            item: item,
            active: _active == i && item.enabled,
            focusBar: showFocus && _active == i,
            onHover: (bool inside) {
              if (!item.enabled) return;
              if (inside) {
                _setActive(i, keyboard: false);
              } else if (_active == i && !_keyboard) {
                _setActive(null, keyboard: false);
              }
            },
            onTap: () {
              if (!_node.hasFocus && _node.canRequestFocus) _node.requestFocus();
              _activate(item);
            },
          ),
          KkMenuSeparator<T>() => KkBox(
            padding: EdgeInsets.symmetric(vertical: m.space1),
            child: KkBox(height: m.stroke1, fill: c.line),
          ),
          final KkMenuLabel<T> label => KkBox(
            padding: EdgeInsets.fromLTRB(m.space3, m.space2, m.space3, m.space1),
            child: KkText.en(label.text, size: 10, weight: FontWeight.w600, spacing: 0.16, color: c.inkFaint),
          ),
        },
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _node,
        canRequestFocus: widget.canRequestFocus,
        onKeyEvent: _onKey,
        onFocusChange: _onFocusChange,
        child: KkBox(
          width: widget.width,
          minWidth: widget.width == null ? widget.minWidth : 0,
          maxHeight: widget.maxHeight ?? double.infinity,
          padding: EdgeInsets.symmetric(vertical: m.space1),
          decoration: KkDecoration(
            fill: c.bg100,
            edges: KkEdges(
              top: KkSide(c.signal, width: m.stroke2),
              right: KkSide(c.line, width: m.stroke1),
              bottom: KkSide(c.line, width: m.stroke1),
              left: KkSide(c.line, width: m.stroke1),
            ),
          ),
          child: KkScroll(
            controller: _scroll,
            child: KkColumn(shrinkWrap: true, children: rows),
          ),
        ),
      ),
    );
  }
}

class _KkMenuRow<T> extends StatelessWidget {
  const _KkMenuRow({
    super.key,
    required this.item,
    required this.active,
    required this.focusBar,
    required this.onHover,
    required this.onTap,
  });

  final KkMenuItem<T> item;
  final bool active;
  final bool focusBar;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool enabled = item.enabled;
    final Color ink = !enabled
        ? c.inkFaint
        : item.danger
        ? (active ? c.ink : c.alert)
        : c.ink;
    final Color iconColor = item.danger
        ? (active ? c.ink : c.alert)
        : (active || item.checked == true)
        ? c.signal
        : c.inkDim;
    final Color? ground = !active
        ? null
        : item.danger
        ? c.alertDeep
        : c.bg300;
    final KkIconData? glyph = item.icon ?? (item.checked == true ? KkIcons.check : null);
    final String? cjk = item.cjk;
    final String? shortcut = item.shortcut;
    // The keyboard focus mark is a 2px bar inside the left edge. It takes its
    // room from the left padding, so the row does not move.
    final double bar = focusBar ? m.stroke2 : 0;
    final Widget content = KkBox(
      height: m.space8,
      padding: EdgeInsets.fromLTRB(m.space2 - bar, 0, m.space3, 0),
      decoration: KkDecoration(
        fill: ground,
        edges: focusBar ? KkEdges(left: KkSide(c.focus, width: bar)) : KkEdges.none,
      ),
      opaque: true,
      child: KkRow(
        shrinkWrap: true,
        gap: m.space2,
        main: KkMainAlign.between,
        clip: Clip.hardEdge,
        children: <Widget>[
          KkFlexible(
            child: KkRow(
              shrinkWrap: true,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                KkBox(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  child: glyph == null ? null : KkIcon(glyph, size: 16, color: iconColor),
                ),
                KkFlexible(
                  child: KkRow(
                    shrinkWrap: true,
                    gap: 6,
                    cross: KkCrossAlign.baseline,
                    clip: Clip.hardEdge,
                    children: <Widget>[
                      if (cjk != null && cjk.isNotEmpty) KkText.cjk(cjk, size: 13, color: ink, squeeze: 0.8),
                      KkFlexible(
                        child: KkText.en(
                          item.label,
                          size: 13,
                          weight: FontWeight.w600,
                          spacing: 0.08,
                          color: ink,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (shortcut != null) KkText.num(shortcut, size: 11, spacing: 0.02, color: c.inkDim),
        ],
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        checked: item.checked,
        label: item.semanticLabel,
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          // An enter without pointer movement is the list scrolling under a
          // resting pointer: while the keyboard drives, it must not take the
          // highlight. A real move always arrives as a hover as well.
          onEnter: (PointerEnterEvent event) {
            if (!KkInputModality.keyboard) onHover(true);
          },
          onHover: (PointerHoverEvent event) => onHover(true),
          onExit: (PointerExitEvent event) => onHover(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? onTap : null,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Opens, closes and toggles the menu of a [KkMenuAnchor].
typedef KkMenuController = KkPopupController;

/// Anchors a popup menu to a trigger.
///
/// [builder] builds the trigger and gets the controller: call
/// `controller.toggle()` from the trigger's `onPressed`. The menu opens below
/// the trigger's left edge with a 4px gap, flips above when there is no room,
/// stays on screen, wipes in (.25s, 5 steps) and takes keyboard focus. It
/// closes on a press outside, on Escape and when an item is chosen, and gives
/// focus back to whatever had it.
class KkMenuAnchor<T> extends StatefulWidget {
  const KkMenuAnchor({
    super.key,
    required this.entries,
    required this.builder,
    this.controller,
    this.onSelected,
    this.onOpen,
    this.onClose,
    this.side = KkPopupSide.below,
    this.align = KkPopupAlign.start,
    this.gap = 4,
    this.matchWidth = false,
    this.minAnchorWidth = false,
    this.minWidth = 232,
    this.maxHeight,
    this.initialValue,
    this.takeFocus = true,
    this.restoreFocus = true,
    this.initiallyOpen = false,
    this.menuSemanticLabel,
  });

  final List<KkMenuEntry<T>> entries;

  /// Builds the trigger.
  final Widget Function(BuildContext context, KkMenuController controller) builder;
  final KkMenuController? controller;

  /// Called with the value of the chosen item (items without a value only
  /// run their own `onPressed`).
  final ValueChanged<T>? onSelected;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final KkPopupSide side;
  final KkPopupAlign align;
  final double gap;

  /// Make the menu exactly as wide as the trigger.
  final bool matchWidth;

  /// Make the menu at least as wide as the trigger.
  final bool minAnchorWidth;
  final double minWidth;
  final double? maxHeight;

  /// The item with this value starts highlighted.
  final T? initialValue;

  /// Move keyboard focus into the menu when it opens.
  final bool takeFocus;

  /// Give focus back to the previously focused control when the menu closes.
  final bool restoreFocus;
  final bool initiallyOpen;
  final String? menuSemanticLabel;

  @override
  State<KkMenuAnchor<T>> createState() => _KkMenuAnchorState<T>();
}

class _KkMenuAnchorState<T> extends State<KkMenuAnchor<T>> {
  KkMenuController? _own;
  FocusNode? _restore;
  bool _wasOpen = false;

  KkMenuController get _controller => widget.controller ?? (_own ??= KkMenuController());

  @override
  void initState() {
    super.initState();
    KkInputModality.watch();
    if (widget.initiallyOpen) _controller.open();
    _wasOpen = _controller.isOpen;
    _controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(KkMenuAnchor<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_onChange);
      _controller.addListener(_onChange);
      _wasOpen = _controller.isOpen;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _own?.dispose();
    super.dispose();
  }

  void _onChange() {
    final bool open = _controller.isOpen;
    if (open == _wasOpen) return;
    _wasOpen = open;
    if (open) {
      _restore = FocusManager.instance.primaryFocus;
      widget.onOpen?.call();
    } else {
      final FocusNode? node = _restore;
      _restore = null;
      if (widget.restoreFocus && widget.takeFocus && node != null && node.context != null && node.canRequestFocus) {
        node.requestFocus();
      }
      widget.onClose?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return KkPopup(
      controller: _controller,
      side: widget.side,
      align: widget.align,
      gap: widget.gap,
      matchWidth: widget.matchWidth,
      minAnchorWidth: widget.minAnchorWidth,
      minWidth: widget.matchWidth ? 0 : widget.minWidth,
      popupBuilder: (BuildContext context) => KkBoot(
        duration: kkMenuWipe,
        steps: kkMenuWipeSteps,
        stagger: false,
        child: KkMenu<T>(
          entries: widget.entries,
          minWidth: widget.matchWidth ? 0 : widget.minWidth,
          maxHeight: widget.maxHeight,
          autofocus: widget.takeFocus,
          trapFocus: true,
          initialValue: widget.initialValue,
          semanticLabel: widget.menuSemanticLabel,
          onDismiss: _controller.close,
          onSelected: (KkMenuItem<T> item) {
            if (item.closeOnPressed) _controller.close();
            final T? value = item.value;
            if (value != null) widget.onSelected?.call(value);
          },
        ),
      ),
      child: widget.builder(context, _controller),
    );
  }
}

/// The entrance of a popup menu: a left-to-right wipe.
const Duration kkMenuWipe = Duration(milliseconds: 250);

/// Steps of [kkMenuWipe].
const int kkMenuWipeSteps = 5;

/// Shows a menu at a point (a context menu) or next to a rectangle, both in
/// global coordinates, and completes with the value of the chosen item, or
/// null when the menu is dismissed.
///
/// Give [position] for a pointer position (the menu's top-left corner goes
/// there) or [anchorRect] to attach it to a control.
Future<T?> showKkMenu<T>({
  required BuildContext context,
  required List<KkMenuEntry<T>> entries,
  Offset? position,
  Rect? anchorRect,
  KkPopupSide side = KkPopupSide.below,
  KkPopupAlign align = KkPopupAlign.start,
  double? gap,
  double minWidth = 232,
  double? maxHeight,
  T? initialValue,
  bool useRootNavigator = false,
  String? semanticLabel,
}) {
  assert(position != null || anchorRect != null, 'Give a position or an anchorRect.');
  final NavigatorState navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  Rect anchor = anchorRect ?? (position! & Size.zero);
  final RenderObject? overlayBox = navigator.overlay?.context.findRenderObject();
  if (overlayBox is RenderBox && overlayBox.attached) {
    anchor = Rect.fromPoints(overlayBox.globalToLocal(anchor.topLeft), overlayBox.globalToLocal(anchor.bottomRight));
  }
  return navigator.push<T>(
    KkPopupRoute<T>(
      duration: Duration.zero,
      label: semanticLabel ?? 'Dismiss menu',
      builder: (BuildContext context, Animation<double> animation) => KkPopupLayout(
        anchor: anchor,
        side: side,
        align: align,
        gap: gap ?? (anchorRect == null ? 0 : 4),
        minWidth: minWidth,
        child: KkBoot(
          duration: kkMenuWipe,
          steps: kkMenuWipeSteps,
          stagger: false,
          child: KkMenu<T>(
            entries: entries,
            minWidth: minWidth,
            maxHeight: maxHeight,
            autofocus: true,
            trapFocus: true,
            initialValue: initialValue,
            semanticLabel: semanticLabel,
            onDismiss: () => Navigator.of(context).pop(),
            onSelected: (KkMenuItem<T> item) {
              if (item.closeOnPressed) Navigator.of(context).pop(item.value);
            },
          ),
        ),
      ),
    ),
  );
}
