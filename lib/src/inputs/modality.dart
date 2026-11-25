import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Tells whether the user's last action came from the keyboard or from a
/// pointer.
///
/// Controls that move one highlight with both (menus, the calendar grid) show
/// the focus mark only while the keyboard is driving, the way a browser's
/// `:focus-visible` does. The framework's own highlight mode cannot be used
/// for this: it treats the mouse as "traditional" input, the same as keys.
abstract final class KkInputModality {
  static bool _installed = false;
  static int _sequence = 0;
  static int _lastKey = 0;
  static int _lastPointer = 0;

  static void _ensure() {
    if (_installed) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _lastKey = ++_sequence;
    return false;
  }

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerHoverEvent || event is PointerScrollEvent) {
      _lastPointer = ++_sequence;
    }
  }

  /// Starts watching input. Called by the controls that need it; calling it
  /// again does nothing.
  static void watch() => _ensure();

  /// Whether the most recent input was a key press. False until a key has
  /// been pressed.
  static bool get keyboard {
    _ensure();
    return _lastKey > _lastPointer;
  }

  /// Marks the pointer as the most recent input (for a control that handles a
  /// pointer event the global route cannot see).
  static void notePointer() {
    _ensure();
    _lastPointer = ++_sequence;
  }
}
