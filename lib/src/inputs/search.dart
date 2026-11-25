import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../controls/icon_button.dart';
import '../controls/kbd.dart';
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
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'field.dart';
import 'menu.dart' show kkMenuWipe, kkMenuWipeSteps;
import 'popup.dart';
import 'text_input.dart';

/// One row of the results under a [KkSearch].
@immutable
class KkSearchResult<T> {
  const KkSearchResult({required this.value, required this.title, this.code, this.meta, this.enabled = true});

  final T value;

  /// The main text. The part that matches the query is highlighted.
  final String title;

  /// A short code in signal before the title, such as `SEC-04`.
  final String? code;

  /// Dim text at the right, such as a kind or a time.
  final String? meta;
  final bool enabled;
}

/// The command-line style search bar: icon, a `>` prompt, a mono input, a key
/// hint and a clear button, with the results listed under the bar.
///
/// The widget does no searching. It reports the text through [onQuery]; give
/// the matches back as [results]. Arrow keys move through them, Enter chooses
/// the highlighted one, Escape closes the list (and, pressed again, clears
/// the text).
class KkSearch<T> extends StatefulWidget {
  const KkSearch({
    super.key,
    this.controller,
    this.focusNode,
    this.results = const <Never>[],
    this.onQuery,
    this.onSelected,
    this.onSubmitted,
    this.placeholder,
    this.prompt = '>',
    this.hint,
    this.emptyText = 'NO MATCH',
    this.open,
    this.maxResultsHeight = 320,
    this.clearOnSelect = false,
    this.enabled = true,
    this.autofocus = false,
    this.width,
    this.clearLabel = 'Clear',
    this.semanticLabel = 'Search',
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// The matches for the current text, best first.
  final List<KkSearchResult<T>> results;

  /// Called whenever the text changes.
  final ValueChanged<String>? onQuery;

  /// Called when a result is chosen.
  final ValueChanged<KkSearchResult<T>>? onSelected;

  /// Called on Enter when no result is highlighted.
  final ValueChanged<String>? onSubmitted;
  final String? placeholder;

  /// The prompt mark before the input.
  final String prompt;

  /// Key hint shown as a key cap, such as `CTRL+K`.
  final String? hint;

  /// Shown in the list when there is text but no result.
  final String emptyText;

  /// Forces the results list open or closed. By default it is open while the
  /// bar has focus and holds text.
  final bool? open;
  final double maxResultsHeight;

  /// Empty the bar after a result is chosen.
  final bool clearOnSelect;
  final bool enabled;
  final bool autofocus;

  /// A fixed width. By default the bar is as wide as its parent allows and at
  /// least 280px.
  final double? width;
  final String clearLabel;
  final String semanticLabel;

  @override
  State<KkSearch<T>> createState() => _KkSearchState<T>();
}

class _KkSearchState<T> extends State<KkSearch<T>> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  final KkPopupController _popup = KkPopupController();
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey<State<StatefulWidget>>> _keys = <int, GlobalKey<State<StatefulWidget>>>{};
  int _active = 0;
  bool _dismissed = false;
  String _lastText = '';

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkSearch'));

  @override
  void initState() {
    super.initState();
    _lastText = _controller.text;
    _controller.addListener(_onText);
    _focusNode.addListener(_sync);
    _active = _firstEnabled();
    _syncPopup();
  }

  @override
  void didUpdateWidget(KkSearch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
      _lastText = _controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_sync);
      _focusNode.addListener(_sync);
    }
    if (!identical(oldWidget.results, widget.results)) {
      if (_active >= widget.results.length || !widget.results[_active].enabled) _active = _firstEnabled();
    }
    _syncPopup();
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_sync);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _popup.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int _firstEnabled() {
    for (int i = 0; i < widget.results.length; i++) {
      if (widget.results[i].enabled) return i;
    }
    return 0;
  }

  bool get _shouldOpen {
    if (!widget.enabled) return false;
    final bool? forced = widget.open;
    if (forced != null) return forced;
    return _focusNode.hasFocus && _controller.text.isNotEmpty && !_dismissed;
  }

  void _syncPopup() {
    if (_shouldOpen) {
      _popup.open();
    } else {
      _popup.close();
    }
  }

  void _sync() {
    if (!mounted) return;
    setState(_syncPopup);
  }

  void _onText() {
    final String text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _dismissed = false;
    _active = _firstEnabled();
    widget.onQuery?.call(text);
    _sync();
  }

  void _clear() {
    _controller.clear();
    if (_focusNode.canRequestFocus) _focusNode.requestFocus();
  }

  void _choose(KkSearchResult<T> result) {
    if (!result.enabled) return;
    widget.onSelected?.call(result);
    if (widget.clearOnSelect) {
      _controller.clear();
    } else {
      _dismissed = true;
    }
    _sync();
  }

  void _submit() {
    if (_popup.isOpen && _active < widget.results.length && widget.results[_active].enabled) {
      _choose(widget.results[_active]);
    } else {
      widget.onSubmitted?.call(_controller.text);
    }
  }

  void _move(int delta) {
    final List<int> live = <int>[
      for (int i = 0; i < widget.results.length; i++)
        if (widget.results[i].enabled) i,
    ];
    if (live.isEmpty) return;
    final int at = live.indexOf(_active);
    final int next = at < 0 ? (delta > 0 ? 0 : live.length - 1) : (at + delta) % live.length;
    setState(() => _active = live[next < 0 ? next + live.length : next]);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final BuildContext? ctx = _keys[_active]?.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (_popup.isOpen) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _move(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _move(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _dismissed = true;
        _sync();
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) && event is KeyDownEvent) {
        _submit();
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.escape && _controller.text.isNotEmpty) {
      _controller.clear();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown && _dismissed && _controller.text.isNotEmpty) {
      _dismissed = false;
      _sync();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  InlineSpan _highlight(String title, TextStyle style, Color mark) {
    final String query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return TextSpan(text: title, style: style);
    final String lower = title.toLowerCase();
    final List<InlineSpan> spans = <InlineSpan>[];
    int from = 0;
    while (true) {
      final int at = lower.indexOf(query, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: title.substring(from, at)));
      spans.add(
        TextSpan(
          text: title.substring(at, at + query.length),
          style: TextStyle(backgroundColor: mark),
        ),
      );
      from = at + query.length;
    }
    if (from < title.length) spans.add(TextSpan(text: title.substring(from)));
    return TextSpan(style: style, children: spans);
  }

  Widget _buildResults(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final TextStyle row = theme.type.mono(13, color: c.ink);
    final bool codes = widget.results.any((KkSearchResult<T> r) => r.code != null);
    final List<Widget> rows = <Widget>[
      if (widget.results.isEmpty)
        KkBox(
          height: m.space8,
          padding: EdgeInsets.symmetric(horizontal: m.space3),
          alignment: Alignment.centerLeft,
          child: KkText.num(widget.emptyText, size: 13, color: c.inkFaint),
        ),
      for (int i = 0; i < widget.results.length; i++)
        _KkSearchRow(
          key: _keys.putIfAbsent(i, GlobalKey<State<StatefulWidget>>.new),
          selected: i == _active && widget.results[i].enabled,
          enabled: widget.results[i].enabled,
          onHover: () {
            if (widget.results[i].enabled && _active != i) setState(() => _active = i);
          },
          onTap: () => _choose(widget.results[i]),
          semanticLabel: widget.results[i].title,
          child: KkRow(
            gap: m.space3,
            children: <Widget>[
              if (codes)
                KkBox(
                  minWidth: 56,
                  child: KkText.num(
                    widget.results[i].code ?? '',
                    size: 13,
                    color: widget.results[i].enabled ? c.signal : c.inkFaint,
                  ),
                ),
              KkExpanded(
                child: Text.rich(
                  _highlight(
                    widget.results[i].title,
                    widget.results[i].enabled ? row : row.copyWith(color: c.inkFaint),
                    c.signalDim,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.results[i].meta != null) KkText.num(widget.results[i].meta!, size: 11, color: c.inkDim),
            ],
          ),
        ),
    ];
    return TextFieldTapRegion(
      child: KkBoot(
        duration: kkMenuWipe,
        steps: kkMenuWipeSteps,
        stagger: false,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Results',
          child: KkBox(
            maxHeight: widget.maxResultsHeight,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool enabled = widget.enabled;
    final KkStates forced = KkStateOverride.resolve(context, const KkStates());
    final bool focused = enabled && (_focusNode.hasFocus || forced.focused);
    final bool empty = _controller.text.isEmpty;
    final String? hint = widget.hint;

    final Widget bar = TextFieldTapRegion(
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? _focusNode.requestFocus : null,
          child: KkFieldBox(
            height: 40,
            padding: EdgeInsets.fromLTRB(m.space3, 0, m.space1, 0),
            brackets: false,
            focused: focused,
            enabled: enabled,
            child: KkRow(
              gap: m.space2,
              children: <Widget>[
                KkIcon(KkIcons.search, size: 16, color: c.inkDim),
                KkText.num(widget.prompt, size: 12, weight: FontWeight.w600, color: enabled ? c.signal : c.inkFaint),
                KkExpanded(
                  child: KkTextInput(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: theme.type.mono(14, color: c.ink),
                    placeholder: widget.placeholder,
                    enabled: enabled,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (String text) => _submit(),
                    // Keep focus after Enter so the next query can be typed.
                    onEditingComplete: () {},
                    semanticLabel: widget.semanticLabel,
                  ),
                ),
                // The key cap keeps 8px more than the row gap from the clear button.
                if (hint != null) ...<Widget>[KkKbd(hint), const KkGap(0)],
                if (empty || !enabled)
                  KkBox(width: m.space8, height: m.space8)
                else
                  KkIconButton(icon: KkIcons.close, onPressed: _clear, semanticLabel: widget.clearLabel),
              ],
            ),
          ),
        ),
      ),
    );

    return KkFieldWidth(
      width: widget.width,
      minWidth: 280,
      fallbackWidth: 320,
      child: KkPopup(
        controller: _popup,
        matchWidth: true,
        gap: m.space1,
        closeOnTapOutside: false,
        popupBuilder: _buildResults,
        child: Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: bar),
      ),
    );
  }
}

class _KkSearchRow extends StatelessWidget {
  const _KkSearchRow({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onHover,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onHover;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkMetrics m = theme.metrics;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          onEnter: (PointerEnterEvent event) => onHover(),
          onHover: (PointerHoverEvent event) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? onTap : null,
            child: KkBox(
              height: m.space8,
              padding: EdgeInsets.symmetric(horizontal: m.space3),
              fill: selected ? theme.colors.bg300 : null,
              opaque: true,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
