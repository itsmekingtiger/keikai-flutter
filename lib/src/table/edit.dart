import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../inputs/popup.dart';
import '../inputs/text_input.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// A table cell whose value can be edited in place.
///
/// At rest the value has a dashed underline (it turns signal under the
/// pointer). Pressing it, or Enter or Space when it has the focus, puts an
/// input over the cell; the value underneath keeps its place, so the column
/// does not change width. Enter commits, Escape cancels, and losing the focus
/// cancels too unless [commitOnBlur] is set. A text the [validator] refuses
/// keeps the editor open in its error state with the message under it.
///
/// This class is not part of the public API.
class KkTableEditCell extends StatefulWidget {
  const KkTableEditCell({
    super.key,
    required this.child,
    required this.text,
    required this.onCommit,
    this.validator,
    this.onClosed,
    this.commitOnBlur = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.alignment = Alignment.centerLeft,
    this.style,
    this.formatters,
    this.keyboardType,
    this.maxLength,
    this.initiallyEditing = false,
    this.semanticLabel,
  });

  /// The cell's content at rest.
  final Widget child;

  /// The text the editor starts with.
  final String Function() text;

  /// Called with the accepted text.
  final ValueChanged<String> onCommit;

  /// Returns a message for a text that cannot be accepted.
  final String? Function(String text)? validator;

  /// Called when the editor has closed: whether the text was committed, and
  /// whether the editor had the focus until then (it was closed with Enter or
  /// Escape, not by the focus moving elsewhere).
  final void Function(bool committed, bool hadFocus)? onClosed;
  final bool commitOnBlur;
  final EdgeInsets padding;
  final Alignment alignment;

  /// The type of the editor; defaults to the ambient text style.
  final TextStyle? style;
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;
  final int? maxLength;

  /// Start with the editor open, without taking the focus (for catalogues
  /// and tests).
  final bool initiallyEditing;
  final String? semanticLabel;

  @override
  State<KkTableEditCell> createState() => KkTableEditCellState();
}

/// The state of a [KkTableEditCell].
class KkTableEditCellState extends State<KkTableEditCell> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  final KkPopupController _note = KkPopupController();
  bool _editing = false;
  bool _hadFocus = false;
  bool _blurred = false;
  String? _error;

  /// Whether the editor is open.
  bool get isEditing => _editing;

  /// The message of the refused text, while the editor shows one.
  String? get error => _error;

  @override
  void initState() {
    super.initState();
    if (widget.initiallyEditing) _open(focus: false);
  }

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocus);
    _focusNode?.dispose();
    _controller?.dispose();
    _note.dispose();
    super.dispose();
  }

  void _open({required bool focus}) {
    final String text = widget.text();
    final TextEditingController controller = _controller ??= TextEditingController();
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final FocusNode node = _focusNode ??= (FocusNode(debugLabel: 'KkTableEdit')..addListener(_onFocus));
    _editing = true;
    _hadFocus = false;
    _error = null;
    // The node joins the tree with the editor; the request waits for that.
    if (focus) node.requestFocus();
  }

  /// Opens the editor and gives it the focus.
  void begin() {
    if (_editing) return;
    setState(() => _open(focus: true));
  }

  void _close({required bool committed}) {
    if (!_editing) return;
    _note.close();
    final bool hadFocus = !_blurred && (_focusNode?.hasFocus ?? false);
    setState(() {
      _editing = false;
      _error = null;
    });
    widget.onClosed?.call(committed, hadFocus);
  }

  /// Commits the text when it is accepted. Returns whether it was.
  bool commit() {
    if (!_editing) return false;
    final String text = _controller?.text ?? '';
    final String? problem = widget.validator?.call(text);
    if (problem != null) {
      setState(() => _error = problem);
      _note.open();
      return false;
    }
    _close(committed: true);
    widget.onCommit(text);
    return true;
  }

  /// Closes the editor and drops what was typed.
  void cancel() => _close(committed: false);

  void _onFocus() {
    final bool focused = _focusNode?.hasFocus ?? false;
    if (focused) {
      _hadFocus = true;
      return;
    }
    if (!_editing || !_hadFocus || !mounted) return;
    _hadFocus = false;
    _blurred = true;
    if (!(widget.commitOnBlur && commit())) cancel();
    _blurred = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_editing && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(String _) {
    if (_error == null) return;
    setState(() => _error = null);
    _note.close();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool editing = _editing;
    final String? problem = _error;
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final TextStyle style = (widget.style ?? ambient).copyWith(color: c.ink);

    final Widget rest = KkPressable(
      onPressed: begin,
      cursor: SystemMouseCursors.text,
      semanticLabel: widget.semanticLabel,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        return KkFocusRing(
          visible: s.focused,
          offset: 2,
          width: m.stroke2,
          child: KkBox(
            padding: const EdgeInsets.symmetric(vertical: 2),
            edges: KkEdges(bottom: KkSide(s.hovered ? c.signal : c.inkFaint, width: m.stroke1, dashed: true)),
            child: widget.child,
          ),
        );
      },
    );

    return KkLayers(
      expand: true,
      children: <Widget>[
        KkBox(
          padding: widget.padding,
          alignment: widget.alignment,
          clip: true,
          // While the editor is open the value stays laid out underneath, so
          // the column keeps its width.
          child: ExcludeFocus(
            excluding: editing,
            child: IgnorePointer(
              ignoring: editing,
              child: ExcludeSemantics(
                excluding: editing,
                child: Opacity(opacity: editing ? 0 : 1, child: rest),
              ),
            ),
          ),
        ),
        if (editing)
          KkPositioned(
            left: 2,
            top: 3,
            right: 2,
            bottom: 3,
            child: KkPopup(
              controller: _note,
              side: KkPopupSide.below,
              gap: m.space1,
              stem: c.alert,
              closeOnTapOutside: false,
              popupBuilder: (BuildContext context) => IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  child: KkBox(
                    fill: c.alert,
                    padding: EdgeInsets.symmetric(horizontal: m.space2, vertical: m.space1),
                    child: KkRow(
                      shrinkWrap: true,
                      gap: 6,
                      children: <Widget>[
                        KkGlyph(level: KkLevel.critical, size: 10, color: c.onFill),
                        KkText.num(problem ?? '', size: 11, weight: FontWeight.w500, height: 1.35, color: c.onFill),
                      ],
                    ),
                  ),
                ),
              ),
              child: KkFocusRing(
                visible: true,
                offset: 1,
                width: m.stroke2,
                child: KkBox(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  decoration: KkDecoration(
                    fill: c.bg000,
                    edges: KkEdges.line(problem != null ? c.alert : c.signal, width: m.stroke1),
                  ),
                  clip: true,
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: _onKey,
                    child: KkTextInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: style,
                      textAlign: widget.alignment.x > 0 ? TextAlign.end : TextAlign.start,
                      inputFormatters: widget.formatters,
                      keyboardType: widget.keyboardType,
                      maxLength: widget.maxLength,
                      textInputAction: TextInputAction.done,
                      // Enter must not take the focus away: a refused text
                      // keeps the editor open.
                      onEditingComplete: () {},
                      onSubmitted: (String _) => commit(),
                      onChanged: _onChanged,
                      semanticLabel: widget.semanticLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
