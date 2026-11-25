import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'modality.dart';
import 'popup.dart';

/// A short note that appears beside a control.
///
/// The plain form is one mono line on an ink ground, joined to its target by
/// a 1px stem. It shows after a short wait when the pointer rests on the
/// child or the keyboard focuses it, and on a long press on touch; it goes
/// when the pointer leaves, on Escape, on a press, or when the page scrolls.
/// It snaps in and out: no fade.
///
/// [KkTooltip.rich] is a small card (title, body, an action) with a signal
/// border that stays up while the pointer is on it.
///
/// The child is one control or one element: for assistive technology its
/// semantics are merged with the note into a single node.
class KkTooltip extends StatefulWidget {
  /// A one-line tooltip.
  const KkTooltip({
    super.key,
    required String this.message,
    this.side = KkPopupSide.above,
    this.waitDuration = const Duration(milliseconds: 400),
    this.showDuration = const Duration(milliseconds: 1500),
    this.open,
    this.enabled = true,
    required this.child,
  }) : cjk = null,
       en = null,
       body = null,
       action = null,
       _rich = false;

  /// A tooltip card with a bilingual title, a body and an optional action.
  const KkTooltip.rich({
    super.key,
    this.cjk,
    this.en,
    this.body,
    this.action,
    this.side = KkPopupSide.above,
    this.waitDuration = const Duration(milliseconds: 400),
    this.showDuration = const Duration(milliseconds: 1500),
    this.open,
    this.enabled = true,
    required this.child,
  }) : message = null,
       _rich = true;

  /// The text of a plain tooltip.
  final String? message;
  final String? cjk;
  final String? en;

  /// Body sentence of a rich tooltip.
  final String? body;

  /// A widget at the bottom right of a rich tooltip, usually a small button.
  final Widget? action;
  final bool _rich;

  /// The preferred side; the tooltip flips when there is no room.
  final KkPopupSide side;

  /// How long the pointer must rest before the tooltip shows.
  final Duration waitDuration;

  /// How long the tooltip stays after a long press on touch.
  final Duration showDuration;

  /// Forces the tooltip open (true) or shut (false).
  final bool? open;
  final bool enabled;
  final Widget child;

  @override
  State<KkTooltip> createState() => _KkTooltipState();
}

class _KkTooltipState extends State<KkTooltip> {
  final KkPopupController _popup = KkPopupController();
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _overTarget = false;
  bool _overTip = false;
  bool _focused = false;
  bool _downInTip = false;
  bool _watching = false;
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    KkInputModality.watch();
    _applyForced();
  }

  @override
  void didUpdateWidget(KkTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open || oldWidget.enabled != widget.enabled) _applyForced();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_onScroll);
      _scroll = position;
      if (_watching) _scroll?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _unwatch();
    _popup.dispose();
    super.dispose();
  }

  void _applyForced() {
    final bool? forced = widget.open;
    if (!widget.enabled || forced == false) {
      _hideNow();
    } else if (forced == true) {
      _showTimer?.cancel();
      _hideTimer?.cancel();
      _popup.open();
    }
  }

  bool get _controlled => widget.open != null || !widget.enabled;

  void _watch() {
    if (_watching) return;
    _watching = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _scroll?.addListener(_onScroll);
  }

  void _unwatch() {
    if (!_watching) return;
    _watching = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _scroll?.removeListener(_onScroll);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) _hideNow();
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerScrollEvent) {
      _hideNow();
    } else if (event is PointerDownEvent) {
      // A press on a rich tooltip (its action) must not take it down first.
      if (_downInTip) {
        _downInTip = false;
        return;
      }
      _hideNow();
    }
  }

  void _onScroll() => _hideNow();

  void _showSoon() {
    if (_controlled || _popup.isOpen) return;
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showTimer = Timer(widget.waitDuration, _showNow);
  }

  void _showNow() {
    if (!mounted || _controlled) return;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _popup.open();
    _watch();
  }

  void _hideNow() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _unwatch();
    if (widget.open == true && widget.enabled) return;
    _popup.close();
  }

  void _hideSoon() {
    if (_controlled) return;
    _showTimer?.cancel();
    if (!_popup.isOpen) return;
    _hideTimer?.cancel();
    // A rich tooltip gets a moment for the pointer to cross the stem.
    _hideTimer = Timer(widget._rich ? const Duration(milliseconds: 160) : Duration.zero, () {
      if (!mounted) return;
      if (_overTarget || _focused || (widget._rich && _overTip)) return;
      _hideNow();
    });
  }

  void _setTarget(bool inside) {
    _overTarget = inside;
    if (inside) {
      _showSoon();
    } else {
      _hideSoon();
    }
  }

  void _setFocused(bool focused) {
    // Follow keyboard focus only: a control that was clicked keeps focus but
    // should not hold its tooltip up.
    final bool keyboard = focused && KkInputModality.keyboard;
    if (keyboard == _focused) return;
    _focused = keyboard;
    if (keyboard) {
      _showNow();
    } else {
      _hideSoon();
    }
  }

  void _onLongPress() {
    if (_controlled) return;
    _showNow();
    _hideTimer = Timer(widget.showDuration, () {
      if (mounted) _hideNow();
    });
  }

  Widget _buildTip(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    if (!widget._rich) {
      return IgnorePointer(
        child: ExcludeSemantics(
          child: KkBox(
            fill: c.ink,
            padding: EdgeInsets.symmetric(horizontal: m.space2, vertical: m.space1),
            child: KkText.num(widget.message ?? '', size: 11, weight: FontWeight.w500, height: 1.35, color: c.bg000),
          ),
        ),
      );
    }
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    final String? body = widget.body;
    final Widget? action = widget.action;
    final bool titled = (cjk != null && cjk.isNotEmpty) || (en != null && en.isNotEmpty);
    return Listener(
      onPointerDown: (PointerDownEvent event) => _downInTip = true,
      child: MouseRegion(
        onEnter: (PointerEnterEvent event) {
          _overTip = true;
          _hideTimer?.cancel();
        },
        onExit: (PointerExitEvent event) {
          _overTip = false;
          _hideSoon();
        },
        child: KkBox(
          width: 248,
          padding: EdgeInsets.fromLTRB(m.space3, m.space2, m.space3, m.space3),
          decoration: KkDecoration(
            fill: c.bg200,
            edges: KkEdges.line(c.signal, width: m.stroke1),
          ),
          child: KkColumn(
            gap: 6,
            shrinkWrap: true,
            children: <Widget>[
              if (titled)
                KkRow(
                  gap: m.space2,
                  cross: KkCrossAlign.baseline,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    if (cjk != null && cjk.isNotEmpty)
                      KkText.cjk(cjk, size: 14, height: 1.35, color: c.ink, squeeze: 0.8),
                    if (en != null && en.isNotEmpty)
                      KkText.en(en, size: 11, weight: FontWeight.w600, height: 1.35, spacing: 0.14, color: c.inkDim),
                  ],
                ),
              if (body != null) KkText.body(body, size: 12, height: 1.5, color: c.inkDim),
              if (action != null) KkRow(main: KkMainAlign.end, children: <Widget>[action]),
            ],
          ),
        ),
      ),
    );
  }

  String? get _label {
    if (!widget._rich) return widget.message;
    final List<String> parts = <String>[
      if (widget.cjk?.isNotEmpty ?? false) widget.cjk!,
      if (widget.en?.isNotEmpty ?? false) widget.en!,
      if (widget.body?.isNotEmpty ?? false) widget.body!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    return KkPopup(
      controller: _popup,
      side: widget.side,
      align: KkPopupAlign.center,
      gap: KeikaiTheme.of(context).metrics.space2,
      stem: widget._rich ? c.signal : c.ink,
      closeOnTapOutside: false,
      popupBuilder: _buildTip,
      // Merged, so that the note lands on the child's own node: a control
      // forms a node of its own, and an annotation outside it would otherwise
      // end up on some ancestor.
      child: MergeSemantics(
        child: Semantics(
          tooltip: _label,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: _setFocused,
            child: MouseRegion(
              onEnter: (PointerEnterEvent event) => _setTarget(true),
              onExit: (PointerExitEvent event) => _setTarget(false),
              child: RawGestureDetector(
                // The whole box is the target, as it is for the pointer.
                behavior: HitTestBehavior.translucent,
                excludeFromSemantics: true,
                gestures: <Type, GestureRecognizerFactory>{
                  LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(
                      supportedDevices: const <PointerDeviceKind>{PointerDeviceKind.touch, PointerDeviceKind.stylus},
                    ),
                    (LongPressGestureRecognizer recognizer) => recognizer.onLongPress = _onLongPress,
                  ),
                },
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
