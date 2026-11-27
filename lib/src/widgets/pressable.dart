import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';

/// The interaction state of a [KkPressable].
@immutable
class KkStates {
  const KkStates({this.hovered = false, this.focused = false, this.pressed = false, this.enabled = true});

  /// A pointer is over the control.
  final bool hovered;

  /// The control has keyboard focus and the focus ring should show.
  final bool focused;

  /// The control is being pressed.
  final bool pressed;

  final bool enabled;

  bool get disabled => !enabled;

  @override
  bool operator ==(Object other) =>
      other is KkStates &&
      other.hovered == hovered &&
      other.focused == focused &&
      other.pressed == pressed &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(hovered, focused, pressed, enabled);
}

typedef KkPressableBuilder = Widget Function(BuildContext context, KkStates states);

/// The base of every KEIKAI control: pointer, keyboard, focus, cursor and
/// semantics in one place, with the visual left to [builder].
///
/// It reports hover, keyboard focus and press through [KkStates]; Enter and
/// Space activate it; the focus ring shows only for keyboard focus.
///
/// The keys count while the control itself has the focus. Pressed in a control
/// inside it (a text field or a switch in a row), they are left to that
/// control.
class KkPressable extends StatefulWidget {
  const KkPressable({
    super.key,
    required this.builder,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.cursor,
    this.semanticLabel,
    this.button = true,
    this.selected,
    this.checked,
    this.mixed,
    this.toggled,
    this.onHoverChanged,
    this.onFocusChanged,
    this.behavior = HitTestBehavior.opaque,
    this.excludeSemantics = false,
  });

  final KkPressableBuilder builder;
  final VoidCallback? onPressed;

  /// Called when a pointer has been held on the control. On a control with no
  /// [onPressed] it is the one action there is, and Enter and Space perform it
  /// as well.
  final VoidCallback? onLongPress;

  /// A control with no [onPressed] and no [onLongPress] is disabled too.
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// False keeps the control out of the keyboard focus: it is not a Tab stop,
  /// it cannot be given the focus and it shows no ring. It still answers to
  /// the pointer, and controls inside it take the focus as before.
  final bool canRequestFocus;

  /// Defaults to a hand when enabled and a forbidden sign when disabled.
  final MouseCursor? cursor;
  final String? semanticLabel;

  /// Announce as a button.
  final bool button;
  final bool? selected;
  final bool? checked;

  /// A checkbox in its indeterminate state.
  final bool? mixed;
  final bool? toggled;
  final ValueChanged<bool>? onHoverChanged;

  /// Called with true when the focus comes to the control or to something
  /// inside it, and with false when it has left both.
  ///
  /// The control's own focus node is what reports, in the order of
  /// [Focus.onFocusChange]: a control that hands the focus to its neighbour
  /// says false before the neighbour says true. A control that is given
  /// another [focusNode] while it has the focus says false, and true again
  /// if the new node takes the focus. A control that is removed while it has
  /// the focus says nothing.
  final ValueChanged<bool>? onFocusChanged;
  final HitTestBehavior behavior;

  /// Replace the semantics of the built child with [semanticLabel].
  final bool excludeSemantics;

  bool get interactive => enabled && (onPressed != null || onLongPress != null);

  @override
  State<KkPressable> createState() => _KkPressableState();
}

class _KkPressableState extends State<KkPressable> {
  bool _hovered = false;
  bool _pressed = false;

  /// Whether the focus ring shows: the control itself is the focused element
  /// (with the focus on a control inside it, it only has the focus within it)
  /// and the focus came from the keyboard.
  bool _ring = false;

  /// Whether [KkPressable.onFocusChanged] was last told that the focus is on
  /// the control or inside it.
  bool _within = false;

  static final Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{ActivateIntent: _KkActivateAction(this)};

  /// The node of a control that was not given one.
  FocusNode? _ownNode;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'KkPressable'));

  void _activate() {
    if (!widget.interactive) return;
    // The keys are taken either way, so a control with a long press alone
    // does the one thing it has to do.
    (widget.onPressed ?? widget.onLongPress)?.call();
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  bool get _showsFocus => _node.hasPrimaryFocus && _KkFocusVisibility.visible;

  /// Called when the focus moves and when the user changes between the
  /// keyboard and a pointer.
  ///
  /// The node is asked rather than the detector: the node also tells when the
  /// focus moves between the control and something inside it, and for the
  /// detector the control is focused in both cases.
  void _syncRing() {
    final bool ring = _showsFocus;
    if (ring != _ring) setState(() => _ring = ring);
  }

  /// Tells [KkPressable.onFocusChanged] that the focus has come to the control
  /// or has left it.
  ///
  /// The control's own node is asked, when its turn comes among the nodes the
  /// focus manager notifies: the node that lost the focus is told before the
  /// one that took it. The detector's node is an ancestor of the one that
  /// takes it and is told ahead of both, so a control that listened there
  /// would say that it has the focus before its neighbour says that it lost
  /// it.
  void _reportFocus() {
    final bool within = _node.hasFocus;
    if (within == _within) return;
    _within = within;
    widget.onFocusChanged?.call(within);
  }

  /// Called when the focus comes to the control's node, leaves it or moves
  /// inside it.
  void _onFocus() {
    _syncRing();
    _reportFocus();
  }

  /// Reports the focus of a node that the control was just put on.
  ///
  /// No node reports the exchange: the one that goes is no longer heard when
  /// it gives the focus up, and the one that comes has nothing to tell,
  /// whether it brings the focus along or not. So the control looks for
  /// itself as soon as the frame is built. That is before the focus manager
  /// moves the focus on, so a control that lost the focus with its node says
  /// so before the control that takes the focus next.
  void _reportFocusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      if (!mounted) return;
      if (_node.hasFocus) {
        // The node came with the focus. The control it came from speaks
        // first, in its own callback of this frame.
        scheduleMicrotask(_reportFocus);
      } else {
        _reportFocus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    _KkFocusVisibility.addListener(_syncRing);
    _ring = _showsFocus;
    // A node that has the focus already is not going to say so.
    if (_node.hasFocus) _reportFocusAfterFrame();
  }

  @override
  void didUpdateWidget(KkPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
      _ring = _showsFocus;
      _reportFocusAfterFrame();
    }
    // A press ends with the control. The hover is left alone: the look is
    // masked in build, and the detector reports its end after this frame, the
    // way that also reaches [KkPressable.onHoverChanged].
    if (!widget.interactive) _pressed = false;
  }

  @override
  void dispose() {
    _KkFocusVisibility.removeListener(_syncRing);
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.interactive;
    final KkStates states = KkStates(
      hovered: _hovered && interactive,
      focused: _ring && interactive,
      pressed: _pressed && interactive,
      enabled: interactive,
    );
    Widget child = widget.builder(context, states);
    if (widget.excludeSemantics) child = ExcludeSemantics(child: child);
    // With a directional pad a disabled control can be reached as well, so
    // that it can be found.
    final bool reachable = interactive || MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional;
    // The semantics node is outside the focus node, so that "focusable" and
    // "focused" merge into the same node as the role, label and tap action.
    return Semantics(
      container: true,
      button: widget.button,
      enabled: interactive,
      label: widget.semanticLabel,
      selected: widget.selected,
      checked: widget.mixed ?? false ? null : widget.checked,
      mixed: widget.mixed ?? false ? true : null,
      toggled: widget.toggled,
      onTap: interactive && widget.onPressed != null ? widget.onPressed : null,
      onLongPress: interactive && widget.onLongPress != null ? widget.onLongPress : null,
      // The detector gives the cursor, the hover state, the keys and their
      // action. Its own focus node takes the focus whenever the detector is
      // enabled, and it cannot be told otherwise, so that node is kept out of
      // the way (no Tab stop, no semantics) and only passes the focus on to
      // the control's node below it, which does as [KkPressable.canRequestFocus]
      // says.
      child: FocusableActionDetector(
        enabled: interactive,
        skipTraversal: true,
        includeFocusSemantics: false,
        mouseCursor: widget.cursor ?? (interactive ? SystemMouseCursors.click : SystemMouseCursors.forbidden),
        shortcuts: _shortcuts,
        actions: _actions,
        onShowHoverHighlight: (bool value) {
          if (_hovered == value || !mounted) return;
          setState(() => _hovered = value);
          widget.onHoverChanged?.call(value);
        },
        child: Focus(
          focusNode: _node,
          autofocus: widget.autofocus,
          canRequestFocus: widget.canRequestFocus && reachable,
          descendantsAreFocusable: true,
          descendantsAreTraversable: true,
          child: GestureDetector(
            behavior: widget.behavior,
            excludeFromSemantics: true,
            onTapDown: interactive ? (TapDownDetails details) => _setPressed(true) : null,
            onTapUp: interactive ? (TapUpDetails details) => _setPressed(false) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            onTap: interactive && widget.onPressed != null ? widget.onPressed : null,
            onLongPress: interactive && widget.onLongPress != null ? widget.onLongPress : null,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tells whether a control that has the focus should show it, the way
/// `:focus-visible` does in a browser: after a key press, not after a press of
/// a pointer.
///
/// The framework's highlight mode is the start: it is off after a touch and on
/// after a key press. But it takes the mouse for "traditional" input, the same
/// as keys, so a control that took the focus on a click would show its ring.
/// This adds the missing half: a pointer that goes down hides the focus until
/// the next key press.
abstract final class _KkFocusVisibility {
  /// The focus manager that [_pointer] was recorded under.
  static WeakReference<FocusManager>? _manager;
  static bool _routed = false;

  /// Whether a pointer went down after the last key press.
  static bool _pointer = false;

  static final HashedObserverList<VoidCallback> _listeners = HashedObserverList<VoidCallback>();

  static void _bind() {
    final FocusManager manager = FocusManager.instance;
    if (identical(_manager?.target, manager)) return;
    // An app keeps one focus manager. Tests get a new one each, and what the
    // pointer did in one test is not the next one's business.
    _manager = WeakReference<FocusManager>(manager);
    _pointer = false;
    manager.addHighlightModeListener(_onMode);
  }

  /// Whether the focused control shows its ring.
  static bool get visible {
    _bind();
    return FocusManager.instance.highlightMode == FocusHighlightMode.traditional && !_pointer;
  }

  /// Calls [listener] when [visible] may have changed.
  static void addListener(VoidCallback listener) {
    _bind();
    // The keyboard drops its handlers when its state is cleared (the test
    // binding does that between tests), so the handler is put back each time
    // rather than installed once.
    HardwareKeyboard.instance
      ..removeHandler(_onKey)
      ..addHandler(_onKey);
    if (!_routed) {
      _routed = true;
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    }
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) => _listeners.remove(listener);

  static bool _onKey(KeyEvent event) {
    // A synthesized event repairs the keyboard state, nobody pressed a key.
    if (event is KeyDownEvent && !event.synthesized) _setPointer(false);
    return false;
  }

  static void _onPointer(PointerEvent event) {
    // Moving the mouse or turning its wheel is not a press.
    if (event is PointerDownEvent) _setPointer(true);
  }

  static void _onMode(FocusHighlightMode mode) => _notify();

  static void _setPointer(bool value) {
    _bind();
    if (value == _pointer) return;
    _pointer = value;
    _notify();
  }

  static void _notify() {
    for (final VoidCallback listener in _listeners.toList(growable: false)) {
      if (_listeners.contains(listener)) listener();
    }
  }
}

/// Presses a [KkPressable] from the keyboard while the control itself is the
/// focused element.
///
/// The shortcuts of a control also see the keys of whatever has the focus
/// inside it: a text field in the trailing slot of a row, a switch. Those keys
/// are not for the control, so the action is disabled for them. A disabled
/// action leaves the key unhandled and it travels on, to the guard the
/// framework keeps for text fields among others.
class _KkActivateAction extends Action<ActivateIntent> {
  _KkActivateAction(this._state);

  final _KkPressableState _state;

  @override
  bool isEnabled(ActivateIntent intent) => _state._node.hasPrimaryFocus;

  @override
  Object? invoke(ActivateIntent intent) {
    _state._activate();
    return null;
  }
}

/// The keyboard focus ring: a 2px line in the focus colour, [offset] px away
/// from the child. A negative offset draws it inside.
class KkFocusRing extends SingleChildRenderObjectWidget {
  const KkFocusRing({super.key, required this.visible, this.offset = 2, this.width = 2, this.color, super.child});

  final bool visible;
  final double offset;
  final double width;

  /// Defaults to the theme's focus colour.
  final Color? color;

  @override
  RenderKkFocusRing createRenderObject(BuildContext context) => RenderKkFocusRing(
    visible: visible,
    offset: offset,
    width: width,
    color: color ?? KeikaiTheme.of(context).colors.focus,
  );

  @override
  void updateRenderObject(BuildContext context, RenderKkFocusRing renderObject) {
    renderObject
      ..visible = visible
      ..offset = offset
      ..width = width
      ..color = color ?? KeikaiTheme.of(context).colors.focus;
  }
}

/// The render object behind [KkFocusRing].
class RenderKkFocusRing extends RenderProxyBox {
  RenderKkFocusRing({
    required bool visible,
    required double offset,
    required double width,
    required Color color,
    RenderBox? child,
  }) : _visible = visible,
       _offset = offset,
       _width = width,
       _color = color,
       super(child);

  bool _visible;
  bool get visible => _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    markNeedsPaint();
  }

  double _offset;
  double get offset => _offset;
  set offset(double value) {
    if (value == _offset) return;
    _offset = value;
    markNeedsPaint();
  }

  double _width;
  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsPaint();
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_visible) return;
    final Rect r = (offset & size).inflate(_offset + _width / 2);
    if (r.width <= 0 || r.height <= 0) return;
    context.canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..color = _color,
    );
  }
}
