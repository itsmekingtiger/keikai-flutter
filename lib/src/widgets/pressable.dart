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
  final VoidCallback? onLongPress;

  /// A control with no [onPressed] and no [onLongPress] is disabled too.
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
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
  bool _focused = false;
  bool _pressed = false;

  static final Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (ActivateIntent intent) => _activate()),
  };

  void _activate() {
    if (!widget.interactive) return;
    widget.onPressed?.call();
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(KkPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive && (_pressed || _hovered)) {
      _pressed = false;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.interactive;
    final KkStates states = KkStates(
      hovered: _hovered && interactive,
      focused: _focused && interactive,
      pressed: _pressed && interactive,
      enabled: interactive,
    );
    Widget child = widget.builder(context, states);
    if (widget.excludeSemantics) child = ExcludeSemantics(child: child);
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
      child: FocusableActionDetector(
        enabled: interactive,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        descendantsAreFocusable: true,
        mouseCursor: widget.cursor ?? (interactive ? SystemMouseCursors.click : SystemMouseCursors.forbidden),
        shortcuts: _shortcuts,
        actions: _actions,
        onShowHoverHighlight: (bool value) {
          if (_hovered == value) return;
          setState(() => _hovered = value);
          widget.onHoverChanged?.call(value);
        },
        onShowFocusHighlight: (bool value) {
          if (_focused == value) return;
          setState(() => _focused = value);
        },
        onFocusChange: widget.onFocusChanged,
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
    );
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
