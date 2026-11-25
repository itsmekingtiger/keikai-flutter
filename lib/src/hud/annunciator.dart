import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// The state of one alarm window, following the usual annunciator sequence:
/// normal → alarm (flashing) → ack (steady) → rtn (ring-back) → normal.
enum KkAlarmState {
  /// Nothing to report: a dark window with faint text.
  normal,

  /// A new alarm: the window flashes every 0.5s until it is acknowledged.
  alarm,

  /// Acknowledged and still standing: steadily lit.
  ack,

  /// The condition has returned to normal and waits to be reset: an outlined
  /// window whose border blinks slowly.
  rtn,

  /// Lamp test: lit white.
  test;

  /// The state after the operator acknowledges: an alarm becomes ack.
  KkAlarmState get acknowledged => this == KkAlarmState.alarm ? KkAlarmState.ack : this;

  /// The state after the condition clears: an acknowledged alarm rings back.
  /// An alarm nobody acknowledged keeps flashing.
  KkAlarmState get cleared => this == KkAlarmState.ack ? KkAlarmState.rtn : this;

  /// The state after the operator resets: a ring-back goes dark.
  KkAlarmState get reset => this == KkAlarmState.rtn ? KkAlarmState.normal : this;

  /// Whether pressing the window does something (acknowledge or reset).
  bool get isActionable => this == KkAlarmState.alarm || this == KkAlarmState.rtn;
}

/// One window of a [KkAnnunciator].
@immutable
class KkAlarmTile {
  const KkAlarmTile({this.code, required this.cjk, this.en, this.state = KkAlarmState.normal, this.level});

  /// Small identifier at the top left, such as `A-03`.
  final String? code;
  final String cjk;
  final String? en;
  final KkAlarmState state;

  /// Colours the window when it is lit. Without a level it is alert red.
  final KkLevel? level;

  /// This tile in another [state].
  KkAlarmTile withState(KkAlarmState state) =>
      KkAlarmTile(code: code, cjk: cjk, en: en, state: state, level: level);

  @override
  bool operator ==(Object other) =>
      other is KkAlarmTile &&
      other.code == code &&
      other.cjk == cjk &&
      other.en == en &&
      other.state == state &&
      other.level == level;

  @override
  int get hashCode => Object.hash(code, cjk, en, state, level);
}

/// A wall of alarm windows. Every judgement stays visible side by side; none
/// is folded into a summary.
///
/// Pressing a flashing window calls [onAcknowledge]; pressing a ring-back
/// window calls [onReset]. The annunciator does not change the tiles itself:
/// answer the callbacks with new tiles (see [KkAlarmState.acknowledged] and
/// [KkAlarmState.reset]). Arrow keys move between windows.
class KkAnnunciator extends StatefulWidget {
  const KkAnnunciator({
    super.key,
    required this.tiles,
    this.columns = 4,
    this.onAcknowledge,
    this.onReset,
    this.onTileTap,
    this.gap = 3,
    this.minTileHeight = 68,
    this.border = true,
    this.boot = true,
  }) : assert(columns > 0);

  final List<KkAlarmTile> tiles;
  final int columns;

  /// Called with the index of a flashing window that was pressed.
  final ValueChanged<int>? onAcknowledge;

  /// Called with the index of a ring-back window that was pressed.
  final ValueChanged<int>? onReset;

  /// Called with the index of any window that was pressed.
  final ValueChanged<int>? onTileTap;
  final double gap;
  final double minTileHeight;
  final bool border;

  /// Wipe in when first shown.
  final bool boot;

  @override
  State<KkAnnunciator> createState() => _KkAnnunciatorState();
}

class _KkAnnunciatorState extends State<KkAnnunciator> {
  final List<FocusNode> _nodes = <FocusNode>[];

  void _syncNodes() {
    while (_nodes.length < widget.tiles.length) {
      _nodes.add(FocusNode(debugLabel: 'KkAnnunciator tile ${_nodes.length}'));
    }
    while (_nodes.length > widget.tiles.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(KkAnnunciator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final int from = _nodes.indexWhere((FocusNode n) => n.hasPrimaryFocus);
    if (from < 0) return KeyEventResult.ignored;
    final int cols = widget.columns;
    final LogicalKeyboardKey key = event.logicalKey;
    int to = from;
    if (key == LogicalKeyboardKey.arrowLeft) {
      to = from - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      to = from + 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = from - cols;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      to = from + cols;
    } else if (key == LogicalKeyboardKey.home) {
      to = 0;
    } else if (key == LogicalKeyboardKey.end) {
      to = _nodes.length - 1;
    } else {
      return KeyEventResult.ignored;
    }
    if (to < 0 || to >= _nodes.length) return KeyEventResult.handled;
    if (to != from) _nodes[to].requestFocus();
    return KeyEventResult.handled;
  }

  void _press(int index) {
    final KkAlarmState state = widget.tiles[index].state;
    widget.onTileTap?.call(index);
    if (state == KkAlarmState.alarm) widget.onAcknowledge?.call(index);
    if (state == KkAlarmState.rtn) widget.onReset?.call(index);
  }

  bool _pressable(KkAlarmState state) {
    if (widget.onTileTap != null) return true;
    if (state == KkAlarmState.alarm) return widget.onAcknowledge != null;
    if (state == KkAlarmState.rtn) return widget.onReset != null;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final List<KkAlarmTile> tiles = widget.tiles;
    final int cols = widget.columns;
    final int rows = (tiles.length / cols).ceil();

    final Widget grid = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: KkBox(
        padding: EdgeInsets.all(widget.gap),
        decoration: KkDecoration(
          fill: c.bg000,
          edges: widget.border ? KkEdges.line(c.line, width: m.stroke1) : KkEdges.none,
        ),
        child: KkColumn(
          gap: widget.gap,
          shrinkWrap: true,
          children: <Widget>[
            for (int r = 0; r < rows; r++)
              KkRow(
                gap: widget.gap,
                cross: KkCrossAlign.stretch,
                children: <Widget>[
                  for (int k = 0; k < cols; k++)
                    KkExpanded(
                      child: r * cols + k < tiles.length
                          ? _AlarmWindow(
                              tile: tiles[r * cols + k],
                              focusNode: _nodes[r * cols + k],
                              minHeight: widget.minTileHeight,
                              onPressed: _pressable(tiles[r * cols + k].state) ? () => _press(r * cols + k) : null,
                            )
                          : const KkGap(0),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
    return widget.boot ? KkBoot(child: grid) : grid;
  }
}

class _AlarmWindow extends StatefulWidget {
  const _AlarmWindow({required this.tile, required this.focusNode, required this.minHeight, required this.onPressed});

  final KkAlarmTile tile;
  final FocusNode focusNode;
  final double minHeight;
  final VoidCallback? onPressed;

  @override
  State<_AlarmWindow> createState() => _AlarmWindowState();
}

class _AlarmWindowState extends State<_AlarmWindow> {
  bool _focused = false;

  static final Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (ActivateIntent intent) {
        widget.onPressed?.call();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkAlarmTile tile = widget.tile;
    final KkAlarmState state = tile.state;
    final Color lv = c.level(tile.level, fallback: c.alert);
    final VoidCallback? press = widget.onPressed;
    final String? code = tile.code;
    final String? en = tile.en;
    final bool loops = state == KkAlarmState.alarm || state == KkAlarmState.rtn;

    final String word = switch (state) {
      KkAlarmState.normal => 'normal',
      KkAlarmState.alarm => 'alarm',
      KkAlarmState.ack => 'acknowledged',
      KkAlarmState.rtn => 'returned to normal',
      KkAlarmState.test => 'test',
    };

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      mouseCursor: press != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      shortcuts: _shortcuts,
      actions: _actions,
      onShowFocusHighlight: (bool value) {
        if (_focused != value) setState(() => _focused = value);
      },
      child: Semantics(
        container: true,
        button: press != null,
        label: <String>[?code, tile.cjk, ?en, word].join(' '),
        onTap: press,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: press,
            child: KkFocusRing(
              visible: _focused,
              offset: 1,
              child: KkPhaseBuilder(
                period: state == KkAlarmState.alarm ? const Duration(milliseconds: 500) : KkMotion.blink,
                enabled: loops,
                builder: (BuildContext context, int phase, Widget? child) {
                  final bool lit = phase == 0;
                  final Color fill;
                  final Color ink;
                  Color? inset;
                  switch (state) {
                    case KkAlarmState.normal:
                      fill = c.bg200;
                      ink = c.inkFaint;
                    case KkAlarmState.alarm:
                      fill = lit ? lv : c.bg200;
                      ink = lit ? c.onFill : lv;
                    case KkAlarmState.ack:
                      fill = lv;
                      ink = c.onFill;
                    case KkAlarmState.rtn:
                      fill = c.bg200;
                      ink = lv;
                      inset = lit ? lv : null;
                    case KkAlarmState.test:
                      fill = c.ink;
                      ink = c.bg000;
                  }
                  return CustomPaint(
                    foregroundPainter: _WindowPainter(
                      inset: inset,
                      insetWidth: m.stroke2,
                      code: code,
                      codeStyle: theme.type.mono(9, weight: FontWeight.w500, spacingEm: 0.04, color: ink),
                      scaler: MediaQuery.textScalerOf(context),
                    ),
                    child: KkBox(
                      minHeight: widget.minHeight,
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                      fill: fill,
                      clip: true,
                      child: KkColumn(
                        shrinkWrap: true,
                        gap: 4,
                        main: KkMainAlign.center,
                        cross: KkCrossAlign.center,
                        children: <Widget>[
                          KkText.cjk(tile.cjk, size: 22, color: ink, squeeze: 0.8),
                          if (en != null) KkText.en(en, size: 9, weight: FontWeight.w700, spacing: 0.14, color: ink),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints what sits over a window: the 2px inset border of a ring-back and
/// the small code at the top left.
class _WindowPainter extends CustomPainter {
  const _WindowPainter({
    required this.inset,
    required this.insetWidth,
    required this.code,
    required this.codeStyle,
    required this.scaler,
  });

  final Color? inset;
  final double insetWidth;
  final String? code;
  final TextStyle codeStyle;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (rect.isEmpty) return;
    final Color? border = inset;
    if (border != null) {
      final double w = math.min(insetWidth, size.shortestSide / 2);
      final Path ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addRect(rect.deflate(w));
      canvas.drawPath(ring, Paint()..color = border);
    }
    final String? id = code;
    if (id != null && id.isNotEmpty) {
      canvas.save();
      canvas.clipRect(rect);
      kkPaintText(canvas, id, codeStyle, const Offset(5, 4), scaler: scaler);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WindowPainter oldDelegate) =>
      oldDelegate.inset != inset ||
      oldDelegate.insetWidth != insetWidth ||
      oldDelegate.code != code ||
      oldDelegate.codeStyle != codeStyle ||
      oldDelegate.scaler != scaler;
}
