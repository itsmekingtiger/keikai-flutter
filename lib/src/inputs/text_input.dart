import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import 'field.dart';
import 'menu.dart';
import 'popup.dart';

/// The bare KEIKAI text input: editing, caret, selection, touch handles and
/// the context menu, with no frame around it.
///
/// [KkTextField] and [KkSearch] put a box around this. Use it directly for
/// an input inside your own chrome (a table cell, a filter in a toolbar).
///
/// The caret is a 2px square bar in signal that blinks hard; the selection is
/// signal-dim; touch selection handles are square; the context menu is a
/// `KkMenu`.
class KkTextInput extends StatefulWidget {
  const KkTextInput({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.style,
    this.placeholder,
    this.placeholderStyle,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofocus = false,
    this.autofillHints = const <String>[],
    this.textAlign = TextAlign.start,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.cursorColor,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.contextMenu = true,
    this.scrollController,
    this.semanticLabel,
  }) : assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(controller == null || initialValue == null, 'Give a controller or an initialValue, not both.');

  final TextEditingController? controller;

  /// The text to start with when no [controller] is given.
  final String? initialValue;
  final FocusNode? focusNode;

  /// Defaults to body 14px / 1.4 in ink.
  final TextStyle? style;

  /// Shown in faint ink while the input is empty.
  final String? placeholder;
  final TextStyle? placeholderStyle;

  /// A disabled input shows faint text and takes neither focus nor pointer.
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final String obscuringCharacter;

  /// The input refuses characters beyond this count.
  final int? maxLength;

  /// 1 for a single line; null to grow without limit.
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;
  final bool autocorrect;
  final bool enableSuggestions;

  /// Defaults to signal.
  final Color? cursorColor;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  /// Called for a tap inside the input.
  final VoidCallback? onTap;

  /// Called for a pointer down outside the input. By default the input loses
  /// focus on desktop and on the web, as the framework does.
  final TapRegionCallback? onTapOutside;

  /// Offer cut / copy / paste / select all in a menu (right click, or a long
  /// press on touch).
  final bool contextMenu;
  final ScrollController? scrollController;
  final String? semanticLabel;

  bool get _multiline => maxLines != 1;

  @override
  State<KkTextInput> createState() => _KkTextInputState();
}

class _KkTextInputState extends State<KkTextInput> implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _showHandles = false;
  bool _empty = true;
  bool _focused = false;
  ScrollPosition? _ancestorScroll;

  late final _InputGestures _gestures = _InputGestures(this);

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController(text: widget.initialValue));
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkTextInput'));

  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_onFocus);
    _empty = _controller.text.isEmpty;
    _focusNode.canRequestFocus = widget.enabled;
    _focused = _focusNode.hasFocus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position != _ancestorScroll) {
      _ancestorScroll?.removeListener(_onAncestorScroll);
      _ancestorScroll = position?..addListener(_onAncestorScroll);
    }
  }

  /// The text menu is placed in screen coordinates, so it cannot stay with a
  /// field that scrolls away under it: it closes instead.
  void _onAncestorScroll() {
    // Does nothing when no menu is showing; the handles stay.
    editableTextKey.currentState?.hideToolbar(false);
  }

  @override
  void didUpdateWidget(KkTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
      _empty = _controller.text.isEmpty;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
      _focused = _focusNode.hasFocus;
    }
    // A disabled input cannot hold the focus; turning it off also drops it.
    _focusNode.canRequestFocus = widget.enabled;
    if (!widget.enabled && _showHandles) _showHandles = false;
  }

  @override
  void dispose() {
    _ancestorScroll?.removeListener(_onAncestorScroll);
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onText() {
    final bool empty = _controller.text.isEmpty;
    if (empty != _empty) setState(() => _empty = empty);
  }

  void _onFocus() {
    final bool focused = _focusNode.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    final bool show = _shouldShowHandles(cause);
    if (show != _showHandles) setState(() => _showHandles = show);
    if (cause == SelectionChangedCause.longPress) {
      editableTextKey.currentState?.bringIntoView(selection.extent);
    }
    if (cause == SelectionChangedCause.drag && !_gestures.shouldShowSelectionToolbar) {
      editableTextKey.currentState?.hideToolbar();
    }
  }

  bool _shouldShowHandles(SelectionChangedCause? cause) {
    // Handles are for touch: a mouse or the keyboard never shows them.
    if (!_gestures.shouldShowSelectionToolbar) return false;
    if (cause == SelectionChangedCause.keyboard) return false;
    if (widget.readOnly && _controller.selection.isCollapsed) return false;
    if (!widget.enabled) return false;
    if (cause == SelectionChangedCause.longPress || cause == SelectionChangedCause.stylusHandwriting) return true;
    return _controller.text.isNotEmpty;
  }

  void _onHandleTapped() {
    if (_controller.selection.isCollapsed) editableTextKey.currentState?.toggleToolbar();
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    return KkTextContextMenu(anchors: state.contextMenuAnchors, items: state.contextMenuButtonItems);
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final bool enabled = widget.enabled;
    final TextStyle base = widget.style ?? theme.type.body(14, height: 1.4);
    final TextStyle style = base.copyWith(color: enabled ? (base.color ?? c.ink) : c.inkFaint);
    final int? maxLength = widget.maxLength;
    final String? placeholder = widget.placeholder;

    final Widget editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly || !enabled,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      style: style,
      cursorColor: widget.cursorColor ?? c.signal,
      backgroundCursorColor: c.inkFaint,
      cursorWidth: theme.metrics.stroke2,
      cursorOpacityAnimates: false,
      showCursor: enabled && !widget.readOnly,
      selectionColor: _focused ? c.signalDim : null,
      selectionControls: enabled ? kkTextSelectionControls : null,
      showSelectionHandles: _showHandles,
      rendererIgnoresPointer: true,
      enableInteractiveSelection: enabled,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      autofocus: widget.autofocus && enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: <TextInputFormatter>[
        ...?widget.inputFormatters,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      onSelectionChanged: _onSelectionChanged,
      onSelectionHandleTapped: _onHandleTapped,
      onTapOutside: widget.onTapOutside,
      mouseCursor: MouseCursor.defer,
      keyboardAppearance: Brightness.dark,
      autofillHints: enabled ? widget.autofillHints : const <String>[],
      scrollController: widget.scrollController,
      contextMenuBuilder: widget.contextMenu ? _buildContextMenu : null,
    );

    final Widget stack = KkLayers(
      children: <Widget>[
        editable,
        if (_empty && placeholder != null && placeholder.isNotEmpty)
          KkPositioned.fill(
            child: IgnorePointer(
              child: KkBox(
                alignment: widget._multiline ? Alignment.topLeft : Alignment.centerLeft,
                clip: true,
                child: Text(
                  placeholder,
                  style: widget.placeholderStyle ?? style.copyWith(color: c.inkFaint),
                  maxLines: widget._multiline ? null : 1,
                  softWrap: widget._multiline,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ),
      ],
    );

    return KkFieldWidth(
      minWidth: 0,
      fallbackWidth: 200,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: Semantics(
          label: widget.semanticLabel,
          enabled: enabled,
          onTap: !enabled || widget.readOnly
              ? null
              : () {
                  if (!_controller.selection.isValid) {
                    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                  }
                  _focusNode.requestFocus();
                },
          child: IgnorePointer(
            ignoring: !enabled,
            child: _gestures.buildGestureDetector(behavior: HitTestBehavior.translucent, child: stack),
          ),
        ),
      ),
    );
  }
}

class _InputGestures extends TextSelectionGestureDetectorBuilder {
  _InputGestures(_KkTextInputState state) : _state = state, super(delegate: state);

  final _KkTextInputState _state;

  @override
  void onUserTap() => _state.widget.onTap?.call();
}

/// The shared instance of [KkTextSelectionControls].
final KkTextSelectionControls kkTextSelectionControls = KkTextSelectionControls();

/// Touch selection handles in the KEIKAI grammar: a signal square hanging
/// from the selection edge, its far corner cut at 45°.
///
/// The toolbar is not built here ([TextSelectionHandleControls]): `KkTextInput`
/// shows a `KkMenu` through the framework's context menu builder.
class KkTextSelectionControls extends TextSelectionControls with TextSelectionHandleControls {
  static const double _size = 14;

  @override
  Size getHandleSize(double textLineHeight) => const Size.square(_size);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) => switch (type) {
    TextSelectionHandleType.left => const Offset(_size, 0),
    TextSelectionHandleType.right => Offset.zero,
    TextSelectionHandleType.collapsed => const Offset(_size / 2, 0),
  };

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    final Color color = KeikaiTheme.of(context).colors.signal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(size: const Size.square(_size), painter: _HandlePainter(type, color)),
    );
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.type, this.color);

  final TextSelectionHandleType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double cut = 5;
    final Path path = Path();
    switch (type) {
      case TextSelectionHandleType.left:
        // Hangs to the left of the edge; bottom-left corner cut.
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(cut, size.height)
          ..lineTo(0, size.height - cut)
          ..close();
      case TextSelectionHandleType.right:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height - cut)
          ..lineTo(size.width - cut, size.height)
          ..lineTo(0, size.height)
          ..close();
      case TextSelectionHandleType.collapsed:
        path
          ..moveTo(size.width / 2 - 1, 0)
          ..lineTo(size.width / 2 + 1, 0)
          ..lineTo(size.width / 2 + 1, 3)
          ..lineTo(size.width, 3)
          ..lineTo(size.width, size.height - cut)
          ..lineTo(size.width - cut, size.height)
          ..lineTo(cut, size.height)
          ..lineTo(0, size.height - cut)
          ..lineTo(0, 3)
          ..lineTo(size.width / 2 - 1, 3)
          ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) => oldDelegate.type != type || oldDelegate.color != color;
}

/// The menu a [KkTextInput] shows for a context click or a touch selection:
/// the actions the framework offers for the selection, as a [KkMenu].
///
/// The menu is laid out by the overlay itself, not inside the framework's
/// toolbar wrapper: that wrapper fades its child in, and nothing in KEIKAI
/// fades. It opens with the same stepped wipe as every other menu.
class KkTextContextMenu extends StatefulWidget {
  const KkTextContextMenu({super.key, required this.anchors, required this.items});

  /// Where the framework wants the menu, in global coordinates.
  final TextSelectionToolbarAnchors anchors;

  /// The actions that apply to the current selection.
  final List<ContextMenuButtonItem> items;

  @override
  State<KkTextContextMenu> createState() => _KkTextContextMenuState();
}

class _KkTextContextMenuState extends State<KkTextContextMenu> {
  final OverlayPortalController _portal = OverlayPortalController(debugLabel: 'KkTextContextMenu');

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  static (String, String?, String?) _labels(ContextMenuButtonItem item) {
    final bool apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final bool desktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
    String? keys(String key) => desktop ? '${apple ? 'CMD' : 'CTRL'}+$key' : null;
    final ContextMenuButtonKind kind = item.kind;
    if (kind == ContextMenuButtonKind.cut) return ('cut', '切取', keys('X'));
    if (kind == ContextMenuButtonKind.copy) return ('copy', '複写', keys('C'));
    if (kind == ContextMenuButtonKind.paste) return ('paste', '貼付', keys('V'));
    if (kind == ContextMenuButtonKind.selectAll) return ('select all', '全選択', keys('A'));
    if (kind == ContextMenuButtonKind.delete) return ('delete', '削除', null);
    return (item.label ?? kind.name, null, null);
  }

  Widget _buildMenu(BuildContext context) {
    // The anchors are global; the menu is placed in the overlay's own space.
    final RenderObject? overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    Offset local(Offset global) => overlay is RenderBox && overlay.hasSize ? overlay.globalToLocal(global) : global;
    final Offset primary = local(widget.anchors.primaryAnchor);
    final Offset? secondaryGlobal = widget.anchors.secondaryAnchor;
    // One anchor: a pointer position (context click). Two: the top and the
    // bottom of a touch selection.
    final bool atPointer = secondaryGlobal == null;
    final Rect anchor = atPointer ? primary & Size.zero : Rect.fromPoints(primary, local(secondaryGlobal));
    return KkPopupLayout(
      anchor: anchor,
      side: atPointer ? KkPopupSide.below : KkPopupSide.above,
      align: atPointer ? KkPopupAlign.start : KkPopupAlign.center,
      gap: atPointer ? 0 : 8,
      child: TextFieldTapRegion(
        child: KkBoot(
          duration: kkMenuWipe,
          steps: kkMenuWipeSteps,
          stagger: false,
          child: KkMenu<Object>(
            minWidth: 200,
            // The field keeps the focus: without it the framework takes the
            // menu down.
            canRequestFocus: false,
            semanticLabel: 'Text actions',
            entries: <KkMenuEntry<Object>>[
              for (final ContextMenuButtonItem item in widget.items)
                if (_labels(item) case (final String label, final String? cjk, final String? shortcut))
                  KkMenuItem<Object>(
                    label: label,
                    cjk: cjk,
                    shortcut: shortcut,
                    enabled: item.onPressed != null,
                    onPressed: item.onPressed,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return OverlayPortal(controller: _portal, overlayChildBuilder: _buildMenu, child: const SizedBox.shrink());
  }
}
