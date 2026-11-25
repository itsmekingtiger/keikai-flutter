import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'field.dart';
import 'menu.dart';

/// One option of a [KkSelect].
@immutable
class KkSelectOption<T> {
  const KkSelectOption({required this.value, required this.label, this.cjk, this.code, this.icon, this.enabled = true});

  final T value;

  /// The text shown in the field and (in capitals) in the list.
  final String label;

  /// An optional CJK word shown before [label].
  final String? cjk;

  /// A short mono code shown at the right of the option in the list.
  final String? code;

  /// An icon for the option in the list. Without one, the chosen option
  /// shows a tick.
  final KkIconData? icon;
  final bool enabled;
}

/// The size of a [KkSelect].
enum KkSelectSize {
  /// The 36px field, with label row, focus brackets and foot line.
  md,

  /// A 32px inline select in mono: toolbars, a time-range preset.
  sm,

  /// A 24px inline select in mono: table footers.
  xs,
}

/// Chooses one value from a list.
///
/// The field shows the chosen option; pressing it (or Enter, Space, an arrow
/// key) opens the options as a `KkMenu` under the field. Arrow keys move,
/// Enter chooses, Escape closes, and typing a letter jumps to the next option
/// that starts with it, with the list open or closed.
class KkSelect<T> extends StatefulWidget {
  const KkSelect({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.cjk,
    this.en,
    this.isRequired = false,
    this.requiredMark = 'REQ',
    this.placeholder,
    this.support,
    this.error,
    this.enabled = true,
    this.size = KkSelectSize.md,
    this.width,
    this.menuMaxHeight = 320,
    this.focusNode,
    this.autofocus = false,
    this.controller,
    this.initiallyOpen = false,
    this.semanticLabel,
  });

  final List<KkSelectOption<T>> options;

  /// The chosen value, or null for none.
  final T? value;

  /// Called with the newly chosen value. Null disables the select.
  final ValueChanged<T>? onChanged;
  final String? cjk;
  final String? en;
  final bool isRequired;
  final String requiredMark;

  /// Shown in faint ink while nothing is chosen.
  final String? placeholder;
  final String? support;

  /// Error message under the field; puts it in its error state.
  final String? error;
  final bool enabled;
  final KkSelectSize size;

  /// A fixed width. The md field otherwise follows the field width rules
  /// (parent's width, at least 200px); sm and xs hug their text.
  final double? width;

  /// The list scrolls beyond this height.
  final double menuMaxHeight;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Opens and closes the list from outside.
  final KkMenuController? controller;
  final bool initiallyOpen;
  final String? semanticLabel;

  @override
  State<KkSelect<T>> createState() => _KkSelectState<T>();
}

class _KkSelectState<T> extends State<KkSelect<T>> {
  FocusNode? _ownFocusNode;
  KkMenuController? _ownController;
  String _typed = '';
  Timer? _typeTimer;

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkSelect'));
  KkMenuController get _controller => widget.controller ?? (_ownController ??= KkMenuController());

  bool get _live => widget.enabled && widget.onChanged != null;

  KkSelectOption<T>? get _selected {
    final T? v = widget.value;
    if (v == null) return null;
    for (final KkSelectOption<T> o in widget.options) {
      if (o.value == v) return o;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(KkSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
    if (!_live && _controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (!_live) return;
    if (!_controller.isOpen) _focusNode.requestFocus();
    _controller.toggle();
  }

  void _choose(T value) {
    if (value != widget.value) widget.onChanged?.call(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_live || _controller.isOpen || event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _controller.open();
      return KeyEventResult.handled;
    }
    final String? ch = event.character;
    final bool modified =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (ch != null && ch.length == 1 && !modified && ch.codeUnitAt(0) > 0x20 && ch.codeUnitAt(0) != 0x7F) {
      _typeAhead(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _typeAhead(String character) {
    _typeTimer?.cancel();
    _typeTimer = Timer(const Duration(milliseconds: 700), () => _typed = '');
    _typed += character.toLowerCase();
    final List<KkSelectOption<T>> live = <KkSelectOption<T>>[
      for (final KkSelectOption<T> o in widget.options)
        if (o.enabled) o,
    ];
    if (live.isEmpty) return;
    final KkSelectOption<T>? current = _selected;
    final int at = current == null ? -1 : live.indexOf(current);
    final int start = _typed.length == 1 ? at + 1 : (at < 0 ? 0 : at);
    for (int k = 0; k < live.length; k++) {
      final KkSelectOption<T> o = live[(start + k) % live.length];
      if (o.label.toLowerCase().startsWith(_typed) || (o.cjk?.toLowerCase().startsWith(_typed) ?? false)) {
        _choose(o.value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool live = _live;
    final bool dense = widget.size != KkSelectSize.md;
    final KkSelectOption<T>? selected = _selected;
    final bool hasError = widget.error != null;
    final String? placeholder = widget.placeholder;

    final Widget anchor = KkMenuAnchor<T>(
      controller: _controller,
      initiallyOpen: widget.initiallyOpen && live,
      matchWidth: !dense,
      minAnchorWidth: dense,
      minWidth: 0,
      maxHeight: widget.menuMaxHeight,
      initialValue: widget.value,
      restoreFocus: false,
      onClose: () {
        if (_focusNode.canRequestFocus && _focusNode.context != null) _focusNode.requestFocus();
        _rebuild();
      },
      onOpen: _rebuild,
      onSelected: _choose,
      menuSemanticLabel: widget.semanticLabel ?? widget.en ?? widget.cjk,
      entries: <KkMenuEntry<T>>[
        for (final KkSelectOption<T> o in widget.options)
          KkMenuItem<T>(
            value: o.value,
            label: o.label,
            cjk: o.cjk,
            icon: o.icon,
            shortcut: o.code,
            checked: o.value == widget.value,
            enabled: o.enabled,
          ),
      ],
      builder: (BuildContext context, KkMenuController menu) {
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: KkPressable(
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            enabled: live,
            onPressed: live ? _toggle : null,
            semanticLabel: widget.semanticLabel ?? widget.en ?? widget.cjk,
            builder: (BuildContext context, KkStates raw) {
              final KkStates s = KkStateOverride.resolve(context, raw);
              final bool focused = live && (_focusNode.hasFocus || menu.isOpen || s.focused);
              final Color ink = live ? c.ink : c.inkFaint;
              if (dense) {
                final bool xs = widget.size == KkSelectSize.xs;
                final Widget text = KkText.num(
                  selected?.label ?? placeholder ?? '',
                  size: xs ? 11 : 12,
                  weight: FontWeight.w500,
                  color: selected == null ? c.inkFaint : ink,
                  overflow: TextOverflow.ellipsis,
                );
                final bool fixed = widget.width != null;
                return Semantics(
                  value: selected?.label,
                  child: KkFocusRing(
                    visible: s.focused && live,
                    offset: xs ? 1 : 2,
                    width: m.stroke2,
                    child: KkBox(
                      width: widget.width,
                      height: xs ? m.space6 : m.space8,
                      padding: EdgeInsets.symmetric(horizontal: xs ? m.space1 : m.space3),
                      decoration: KkDecoration(
                        fill: c.bg100,
                        edges: KkEdges.line(
                          live ? (menu.isOpen ? c.signal : c.inkFaint) : c.offline,
                          width: m.stroke1,
                          dashed: !live,
                        ),
                      ),
                      child: KkRow(
                        shrinkWrap: !fixed,
                        gap: xs ? m.space1 : 6,
                        children: <Widget>[
                          if (fixed) KkExpanded(child: text) else text,
                          KkIcon(KkIcons.chevronDown, size: 12, color: live ? c.inkDim : c.inkFaint),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final String? cjk = selected?.cjk;
              return Semantics(
                value: selected?.label,
                child: KkFieldBox(
                  focused: focused,
                  hovered: s.hovered,
                  error: hasError,
                  enabled: live,
                  child: KkRow(
                    gap: m.space2,
                    children: <Widget>[
                      KkExpanded(
                        child: selected == null
                            ? KkText.body(
                                placeholder ?? '',
                                size: 14,
                                height: 1.4,
                                color: c.inkFaint,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              )
                            : KkRow(
                                gap: 6,
                                cross: KkCrossAlign.baseline,
                                clip: Clip.hardEdge,
                                children: <Widget>[
                                  if (cjk != null && cjk.isNotEmpty)
                                    KkText.cjk(cjk, size: 13, height: 1.4, color: ink, squeeze: 0.8),
                                  KkFlexible(
                                    child: KkText.body(
                                      selected.label,
                                      size: 14,
                                      height: 1.4,
                                      color: ink,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      KkIcon(KkIcons.chevronDown, size: 16, color: live ? (hasError ? c.alert : c.signal) : c.inkFaint),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    final bool hasLabel = (widget.cjk?.isNotEmpty ?? false) || (widget.en?.isNotEmpty ?? false) || widget.isRequired;
    final bool hasFoot = widget.support != null || hasError;
    if (dense && !hasLabel && !hasFoot) return anchor;

    final Widget column = KkColumn(
      gap: 6,
      shrinkWrap: true,
      cross: dense ? KkCrossAlign.start : KkCrossAlign.stretch,
      children: <Widget>[
        if (hasLabel)
          KkFieldLabel(
            cjk: widget.cjk,
            en: widget.en,
            isRequired: widget.isRequired,
            requiredMark: widget.requiredMark,
          ),
        anchor,
        if (hasFoot) KkFieldFoot(support: widget.support, error: widget.error),
      ],
    );
    return dense ? column : KkFieldWidth(width: widget.width, child: column);
  }
}
