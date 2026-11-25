import 'dart:async';

import 'package:flutter/widgets.dart';

import '../controls/button.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';

/// A snackbar: one line of news from the system, with a code block at the
/// left that carries its level.
///
/// At least 40px high and at most 560px wide, on the raised colour with a 1px
/// line border. The code block is filled with the level colour (signal when
/// there is none) and shows the level's status icon. The message is mono and
/// wraps; an [action] and a close button can follow it.
///
/// `KkMessenger.of(context).show(...)` stacks these at the bottom left of the
/// screen; the widget can also be placed directly.
class KkSnackbar extends StatelessWidget {
  const KkSnackbar({
    super.key,
    this.code,
    required this.message,
    this.level,
    this.action,
    this.onClose,
    this.closeLabel = 'Dismiss',
    this.maxWidth = 560,
  });

  /// The text of the code block: an event code, a source. Without one the
  /// block shows the level's word; with neither there is no block.
  final String? code;
  final String message;
  final KkLevel? level;

  /// A widget after the message, usually a small ghost button.
  final Widget? action;

  /// Shows a close button that calls this.
  final VoidCallback? onClose;

  /// What screen readers call the close button.
  final String closeLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkLevel? lv = level;
    final String? block = code ?? lv?.word;
    final Widget? act = action;
    return Semantics(
      container: true,
      liveRegion: true,
      child: KkBox(
        minHeight: 40,
        maxWidth: maxWidth,
        decoration: KkDecoration(fill: c.bg200, edges: KkEdges.line(c.line, width: m.stroke1)),
        // A bare message keeps the same clearance the code block gives it.
        padding: EdgeInsets.only(right: act == null && onClose == null ? m.space3 : m.space1),
        child: KkRow(
          shrinkWrap: true,
          gap: m.space3,
          children: <Widget>[
            if (block != null)
              KkAlignSelf(
                align: KkCrossAlign.stretch,
                child: KkSurface(
                  shape: KkShape.slant(m.chamferMd),
                  fill: c.level(lv),
                  edgeWidth: 0,
                  child: KkBox(
                    padding: EdgeInsets.only(left: m.space3, right: m.space2 + m.chamferMd),
                    alignment: Alignment.center,
                    child: KkRow(
                      shrinkWrap: true,
                      gap: 6,
                      children: <Widget>[
                        if (lv != null) KkGlyph(level: lv, size: 10, color: c.onFill),
                        KkText.num(block, size: 11, weight: FontWeight.w600, spacing: 0.06, color: c.onFill),
                      ],
                    ),
                  ),
                ),
              ),
            KkFlexible(
              child: KkBox(
                padding: EdgeInsets.only(left: block == null ? m.space3 : 0, top: m.space2, bottom: m.space2),
                child: KkText.num(message, size: 12, height: 1.4, color: c.ink, maxLines: null, softWrap: true),
              ),
            ),
            ?act,
            if (onClose != null) KkIconButton(icon: KkIcons.close, semanticLabel: closeLabel, onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

/// A snackbar on screen. Returned by [KkMessengerState.show].
class KkSnackbarHandle {
  KkSnackbarHandle._(this._owner, this._id);

  final KkMessengerState _owner;
  final int _id;
  final Completer<void> _closed = Completer<void>();
  Timer? _timer;

  /// Whether the snackbar is still on screen.
  bool get isOpen => !_closed.isCompleted;

  /// Completes when the snackbar has left the screen, for whatever reason.
  Future<void> get closed => _closed.future;

  /// Takes the snackbar off the screen now. Does nothing when it is gone.
  void close() => _owner._close(this);
}

class _KkSnackEntry {
  _KkSnackEntry(this.handle, this.builder);

  final KkSnackbarHandle handle;
  final Widget Function(BuildContext context, KkSnackbarHandle handle) builder;
}

/// Stacks snackbars at the bottom left of whatever it wraps: 24px in from the
/// left and 16px above the height of a toolbar, newest at the bottom, 8px
/// apart.
///
/// `KeikaiApp` mounts one above its navigator, so every route can call
/// `KkMessenger.of(context).show(message: …)`. Wrap part of a layout in your
/// own to keep snackbars inside it or to move the stack.
class KkMessenger extends StatefulWidget {
  const KkMessenger({super.key, this.maxVisible = 4, this.left, this.bottom, required this.child})
    : assert(maxVisible > 0);

  /// How many snackbars show at once. When one more arrives the oldest is
  /// closed to make room.
  final int maxVisible;

  /// Distance of the stack from the left edge. Defaults to 24.
  final double? left;

  /// Distance of the stack from the bottom edge. Defaults to the toolbar
  /// height plus 16 (48).
  final double? bottom;
  final Widget child;

  /// The nearest messenger. There must be one (`KeikaiApp` provides it).
  static KkMessengerState of(BuildContext context) {
    final KkMessengerState? state = maybeOf(context);
    assert(state != null, 'KkMessenger.of() was called with a context that has no KkMessenger above it.');
    return state!;
  }

  /// The nearest messenger, or null.
  static KkMessengerState? maybeOf(BuildContext context) => context.findAncestorStateOfType<KkMessengerState>();

  @override
  State<KkMessenger> createState() => KkMessengerState();
}

/// The state of a [KkMessenger]: shows and closes snackbars.
class KkMessengerState extends State<KkMessenger> {
  final List<_KkSnackEntry> _entries = <_KkSnackEntry>[];
  int _nextId = 0;

  /// How many snackbars are on screen.
  int get count => _entries.length;

  /// Shows a snackbar and returns its handle.
  ///
  /// It closes by itself after [duration] (5s by default); pass null to keep
  /// it until it is closed. [actionLabel] adds a small button that calls
  /// [onAction] and closes the snackbar. [closable] adds a close button.
  KkSnackbarHandle show({
    String? code,
    required String message,
    KkLevel? level,
    Duration? duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onAction,
    bool closable = true,
  }) {
    return showCustom(
      (BuildContext context, KkSnackbarHandle handle) => KkSnackbar(
        code: code,
        message: message,
        level: level,
        action: actionLabel == null
            ? null
            : KkButton(
                label: actionLabel,
                variant: KkButtonVariant.ghost,
                size: KkButtonSize.sm,
                onPressed: () {
                  onAction?.call();
                  handle.close();
                },
              ),
        onClose: closable ? handle.close : null,
      ),
      duration: duration,
    );
  }

  /// Shows any widget in the stack; [builder] gets the handle to close it.
  KkSnackbarHandle showCustom(
    Widget Function(BuildContext context, KkSnackbarHandle handle) builder, {
    Duration? duration = const Duration(seconds: 5),
  }) {
    final KkSnackbarHandle handle = KkSnackbarHandle._(this, _nextId++);
    if (!mounted) {
      handle._closed.complete();
      return handle;
    }
    setState(() {
      _entries.add(_KkSnackEntry(handle, builder));
      while (_entries.length > widget.maxVisible) {
        _finish(_entries.removeAt(0).handle);
      }
    });
    if (duration != null) handle._timer = Timer(duration, handle.close);
    return handle;
  }

  /// Closes every snackbar.
  void clear() {
    if (_entries.isEmpty) return;
    setState(() {
      for (final _KkSnackEntry entry in _entries) {
        _finish(entry.handle);
      }
      _entries.clear();
    });
  }

  void _finish(KkSnackbarHandle handle) {
    handle._timer?.cancel();
    handle._timer = null;
    if (!handle._closed.isCompleted) handle._closed.complete();
  }

  void _close(KkSnackbarHandle handle) {
    if (!handle.isOpen) return;
    final int index = _entries.indexWhere((_KkSnackEntry e) => identical(e.handle, handle));
    _finish(handle);
    if (index >= 0 && mounted) setState(() => _entries.removeAt(index));
  }

  @override
  void didUpdateWidget(KkMessenger oldWidget) {
    super.didUpdateWidget(oldWidget);
    while (_entries.length > widget.maxVisible) {
      _finish(_entries.removeAt(0).handle);
    }
  }

  @override
  void dispose() {
    for (final _KkSnackEntry entry in _entries) {
      _finish(entry.handle);
    }
    _entries.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    final double left = widget.left ?? m.space6;
    final double bottom = (widget.bottom ?? m.toolbarHeight + m.space4) + (mq?.padding.bottom ?? 0);
    return KkLayers(
      expand: true,
      children: <Widget>[
        widget.child,
        if (_entries.isNotEmpty)
          KkPositioned(
            left: left + (mq?.padding.left ?? 0),
            bottom: bottom,
            child: KkBox(
              maxWidth: mq == null ? double.infinity : (mq.size.width - left * 2).clamp(0.0, double.infinity),
              child: KkColumn(
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                gap: m.space2,
                children: <Widget>[
                  for (final _KkSnackEntry entry in _entries)
                    KkBoot(
                      key: ValueKey<int>(entry.handle._id),
                      stagger: false,
                      child: Builder(builder: (BuildContext context) => entry.builder(context, entry.handle)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
