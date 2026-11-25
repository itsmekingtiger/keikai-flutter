import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';
import 'field.dart';
import 'text_input.dart';

/// A text field: bilingual label, a 36px box with the KEIKAI focus brackets,
/// and a foot line for support text, errors and a counter.
///
/// ```dart
/// KkTextField(
///   cjk: '識別符号',
///   en: 'call sign',
///   placeholder: 'SEC-04',
///   mono: true,
///   onChanged: (String value) {},
/// )
/// ```
///
/// Give [error] to put the field in its error state: the border, the focus
/// ring and the brackets turn alert and the message replaces [support].
class KkTextField extends StatefulWidget {
  const KkTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.cjk,
    this.en,
    this.isRequired = false,
    this.requiredMark = 'REQ',
    this.placeholder,
    this.icon,
    this.prefix,
    this.suffix,
    this.trailing,
    this.support,
    this.error,
    this.mono = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.maxLength,
    this.showCounter,
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
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.contextMenu = true,
    this.width,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// CJK title of the label row.
  final String? cjk;

  /// Latin subtitle of the label row (shown in capitals).
  final String? en;

  /// Show [requiredMark] at the right of the label row.
  final bool isRequired;
  final String requiredMark;
  final String? placeholder;

  /// Icon at the left inside the box.
  final KkIconData? icon;

  /// Mono text before the input, such as `0x`.
  final String? prefix;

  /// Mono text after the input, such as `kPa`.
  final String? suffix;

  /// A widget at the right inside the box (a clear button, a unit switch).
  final Widget? trailing;

  /// Help text under the box.
  final String? support;

  /// Error message under the box; puts the field in its error state.
  final String? error;

  /// Set the input in tabular monospace (codes, numbers).
  final bool mono;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final String obscuringCharacter;
  final int? maxLength;

  /// Show `012 / 120` at the right of the foot. Defaults to true when
  /// [maxLength] is given.
  final bool? showCounter;

  /// 1 for a single line; more (or null, to grow freely) for a text area.
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
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;

  /// Offer the cut / copy / paste menu.
  final bool contextMenu;

  /// A fixed width. By default the field is as wide as its parent allows and
  /// at least 200px.
  final double? width;
  final String? semanticLabel;

  @override
  State<KkTextField> createState() => _KkTextFieldState();
}

class _KkTextFieldState extends State<KkTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _hovered = false;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkTextField'));

  bool get _counted => widget.showCounter ?? (widget.maxLength != null);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focusNode.addListener(_changed);
  }

  @override
  void didUpdateWidget(KkTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_changed);
      _focusNode.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _focusNode.removeListener(_changed);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  int _lastLength = -1;
  bool _lastFocus = false;

  void _changed() {
    final int length = _controller.text.characters.length;
    final bool focus = _focusNode.hasFocus;
    if (focus == _lastFocus && (!_counted || length == _lastLength)) return;
    _lastLength = length;
    _lastFocus = focus;
    if (mounted) setState(() {});
  }

  String? _counterText() {
    if (!_counted) return null;
    final int length = _controller.text.characters.length;
    final int? max = widget.maxLength;
    if (max == null) return '$length';
    final int digits = '$max'.length;
    return '${'$length'.padLeft(digits, '0')} / $max';
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool enabled = widget.enabled;
    final bool multiline = widget.maxLines != 1;
    final bool focused = _focusNode.hasFocus && enabled;
    final bool hasError = widget.error != null;
    final bool hasLabel = (widget.cjk?.isNotEmpty ?? false) || (widget.en?.isNotEmpty ?? false) || widget.isRequired;
    final String? counter = _counterText();
    final bool hasFoot = widget.support != null || hasError || counter != null;
    final KkIconData? icon = widget.icon;
    final String? prefix = widget.prefix;
    final String? suffix = widget.suffix;
    final Widget? trailing = widget.trailing;
    final TextStyle style = widget.mono ? theme.type.mono(14, height: 1.4) : theme.type.body(14, height: 1.4);

    Widget affix(String text) => KkText.num(text, size: 13, color: c.inkDim);

    final Widget input = KkTextInput(
      controller: _controller,
      focusNode: _focusNode,
      style: style.copyWith(color: c.ink),
      placeholder: widget.placeholder,
      enabled: enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      textAlign: widget.textAlign,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      cursorColor: hasError ? c.alert : c.signal,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      onTap: widget.onTap,
      onTapOutside: widget.onTapOutside,
      contextMenu: widget.contextMenu,
      semanticLabel: widget.semanticLabel ?? widget.en ?? widget.cjk,
    );

    final Widget box = MouseRegion(
      cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
      onExit: (PointerExitEvent event) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // A press on the padding, the icon or an affix still lands in the input.
        onTap: enabled && !widget.readOnly ? _focusNode.requestFocus : null,
        child: KkFieldBox(
          focused: focused,
          hovered: _hovered,
          error: hasError,
          enabled: enabled,
          multiline: multiline,
          child: KkRow(
            gap: m.space2,
            cross: multiline ? KkCrossAlign.start : KkCrossAlign.center,
            children: <Widget>[
              if (icon != null) KkIcon(icon, size: 16, color: c.inkDim),
              if (prefix != null) affix(prefix),
              KkExpanded(child: multiline ? KkBox(minHeight: 72, child: input) : input),
              if (suffix != null) affix(suffix),
              ?trailing,
            ],
          ),
        ),
      ),
    );

    return KkFieldWidth(
      width: widget.width,
      child: KkColumn(
        gap: 6,
        shrinkWrap: true,
        children: <Widget>[
          if (hasLabel)
            KkFieldLabel(
              cjk: widget.cjk,
              en: widget.en,
              isRequired: widget.isRequired,
              requiredMark: widget.requiredMark,
            ),
          box,
          if (hasFoot) KkFieldFoot(support: widget.support, error: widget.error, counter: counter),
        ],
      ),
    );
  }
}
