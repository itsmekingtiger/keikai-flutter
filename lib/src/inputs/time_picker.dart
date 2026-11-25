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

/// A time of day: hour 0–23, minute 0–59, second 0–59.
@immutable
class KkTime implements Comparable<KkTime> {
  const KkTime(this.hour, this.minute, [this.second = 0])
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60),
      assert(second >= 0 && second < 60);

  /// The time of day of [duration] since midnight (wrapped into one day).
  factory KkTime.fromDuration(Duration duration) {
    final int s = duration.inSeconds % 86400;
    final int t = s < 0 ? s + 86400 : s;
    return KkTime(t ~/ 3600, (t % 3600) ~/ 60, t % 60);
  }

  /// The time of day of [time], as it stands (convert to UTC first if needed).
  factory KkTime.fromDateTime(DateTime time) => KkTime(time.hour, time.minute, time.second);

  final int hour;
  final int minute;
  final int second;

  /// Time since midnight.
  Duration get duration => Duration(hours: hour, minutes: minute, seconds: second);

  KkTime copyWith({int? hour, int? minute, int? second}) =>
      KkTime(hour ?? this.hour, minute ?? this.minute, second ?? this.second);

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  /// `14:02` or, with [seconds], `14:02:31`.
  String format({bool seconds = false}) =>
      seconds ? '${_two(hour)}:${_two(minute)}:${_two(second)}' : '${_two(hour)}:${_two(minute)}';

  @override
  int compareTo(KkTime other) => duration.compareTo(other.duration);

  @override
  bool operator ==(Object other) =>
      other is KkTime && other.hour == hour && other.minute == minute && other.second == second;

  @override
  int get hashCode => Object.hash(hour, minute, second);

  @override
  String toString() => 'KkTime(${format(seconds: true)})';
}

enum _Unit { hour, minute, second }

/// Sets a time of day with large mono digits: hours, minutes and, with
/// [showSeconds], seconds.
///
/// Each segment takes focus. Arrow up / down change it by one step, Page Up /
/// Page Down by ten, Home / End go to the lowest and highest value; the wheel
/// and a vertical drag do the same; digits can be typed. Values wrap around
/// (23 goes to 00) without carrying into the next segment. Arrow left / right
/// move between segments.
class KkTimePicker extends StatefulWidget {
  const KkTimePicker({
    super.key,
    required this.value,
    this.onChanged,
    this.cjk,
    this.en,
    this.zone = 'UTC',
    this.showSeconds = false,
    this.hourStep = 1,
    this.minuteStep = 1,
    this.secondStep = 1,
    this.hourLabel = 'HH',
    this.minuteLabel = 'MM',
    this.secondLabel = 'SS',
    this.enabled = true,
    this.frame = true,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(hourStep > 0 && minuteStep > 0 && secondStep > 0);

  final KkTime value;

  /// Called with the new time. Null makes the picker read-only.
  final ValueChanged<KkTime>? onChanged;
  final String? cjk;
  final String? en;

  /// The zone text at the right of the head. Times in KEIKAI are UTC.
  final String? zone;
  final bool showSeconds;
  final int hourStep;

  /// Minutes change by this much per arrow press (5 or 15 for coarse entry).
  final int minuteStep;
  final int secondStep;

  /// Caption under the hours.
  final String hourLabel;
  final String minuteLabel;
  final String secondLabel;
  final bool enabled;

  /// Draw the panel-coloured box and border around the picker.
  final bool frame;
  final bool autofocus;
  final String? semanticLabel;

  @override
  State<KkTimePicker> createState() => _KkTimePickerState();
}

class _KkTimePickerState extends State<KkTimePicker> {
  final Map<_Unit, FocusNode> _nodes = <_Unit, FocusNode>{
    for (final _Unit u in _Unit.values) u: FocusNode(debugLabel: 'KkTimePicker.${u.name}'),
  };

  // The first digit of a two-digit entry, per segment.
  _Unit? _typingUnit;
  int? _typedTens;

  bool get _live => widget.enabled && widget.onChanged != null;

  List<_Unit> get _units => <_Unit>[_Unit.hour, _Unit.minute, if (widget.showSeconds) _Unit.second];

  @override
  void initState() {
    super.initState();
    for (final FocusNode n in _nodes.values) {
      n.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    for (final FocusNode n in _nodes.values) {
      n
        ..removeListener(_onFocus)
        ..dispose();
    }
    super.dispose();
  }

  void _onFocus() {
    final _Unit? typing = _typingUnit;
    if (typing != null && !_nodes[typing]!.hasFocus) {
      _typingUnit = null;
      _typedTens = null;
    }
    if (mounted) setState(() {});
  }

  int _max(_Unit u) => u == _Unit.hour ? 23 : 59;
  int _step(_Unit u) => switch (u) {
    _Unit.hour => widget.hourStep,
    _Unit.minute => widget.minuteStep,
    _Unit.second => widget.secondStep,
  };
  int _get(_Unit u) => switch (u) {
    _Unit.hour => widget.value.hour,
    _Unit.minute => widget.value.minute,
    _Unit.second => widget.value.second,
  };

  void _set(_Unit u, int v) {
    if (!_live) return;
    final int n = _max(u) + 1;
    final int wrapped = ((v % n) + n) % n;
    if (wrapped == _get(u)) return;
    widget.onChanged?.call(switch (u) {
      _Unit.hour => widget.value.copyWith(hour: wrapped),
      _Unit.minute => widget.value.copyWith(minute: wrapped),
      _Unit.second => widget.value.copyWith(second: wrapped),
    });
  }

  void _nudge(_Unit u, int steps) {
    _typingUnit = null;
    _typedTens = null;
    final int step = _step(u);
    final int current = _get(u);
    // Snap to the step grid first, so 07 with a step of 5 goes to 10 or 05.
    final int base = steps > 0 ? (current ~/ step) * step : ((current + step - 1) ~/ step) * step;
    _set(u, base + steps * step);
  }

  void _focusNext(_Unit u, int delta) {
    final List<_Unit> units = _units;
    final int i = units.indexOf(u) + delta;
    if (i >= 0 && i < units.length) _nodes[units[i]]!.requestFocus();
  }

  void _typeDigit(_Unit u, int digit) {
    final int max = _max(u);
    final int? tens = _typingUnit == u ? _typedTens : null;
    if (tens == null) {
      _set(u, digit);
      if (digit * 10 > max) {
        // No second digit can follow (6 in minutes): move on.
        _typingUnit = null;
        _typedTens = null;
        _focusNext(u, 1);
      } else {
        _typingUnit = u;
        _typedTens = digit;
      }
      return;
    }
    final int value = tens * 10 + digit;
    _set(u, value <= max ? value : digit);
    _typingUnit = null;
    _typedTens = null;
    _focusNext(u, 1);
  }

  KeyEventResult _onKey(_Unit u, KeyEvent event) {
    if (!_live) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _nudge(u, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _nudge(u, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      _typingUnit = null;
      _set(u, _get(u) + 10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      _typingUnit = null;
      _set(u, _get(u) - 10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _typingUnit = null;
      _set(u, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _typingUnit = null;
      _set(u, _max(u));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusNext(u, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusNext(u, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _typingUnit = null;
      _typedTens = null;
      _set(u, 0);
      return KeyEventResult.handled;
    }
    final String? ch = event.character;
    if (ch != null && ch.length == 1 && event is KeyDownEvent) {
      final int code = ch.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        _typeDigit(u, code - 0x30);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    final String? zone = widget.zone;
    final bool hasHead = (cjk?.isNotEmpty ?? false) || (en?.isNotEmpty ?? false) || (zone?.isNotEmpty ?? false);
    final List<_Unit> units = _units;

    Widget colon() => KkBox(
      padding: const EdgeInsets.only(bottom: 6),
      child: KkText.num(':', size: 32, weight: FontWeight.w500, color: c.inkDim),
    );

    final Widget row = KkRow(
      shrinkWrap: true,
      gap: m.space1,
      children: <Widget>[
        for (int i = 0; i < units.length; i++) ...<Widget>[
          if (i > 0) colon(),
          _KkTimeSegment(
            value: _get(units[i]),
            max: _max(units[i]),
            label: switch (units[i]) {
              _Unit.hour => widget.hourLabel,
              _Unit.minute => widget.minuteLabel,
              _Unit.second => widget.secondLabel,
            },
            semanticLabel: switch (units[i]) {
              _Unit.hour => 'Hours',
              _Unit.minute => 'Minutes',
              _Unit.second => 'Seconds',
            },
            focusNode: _nodes[units[i]]!,
            autofocus: widget.autofocus && i == 0,
            live: _live,
            enabled: widget.enabled,
            onKey: (KeyEvent event) => _onKey(units[i], event),
            onNudge: (int steps) => _nudge(units[i], steps),
          ),
        ],
      ],
    );

    final Widget body = KkColumn(
      gap: m.space2,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        if (hasHead)
          // The head is as wide as the digits: it hugs when measured and
          // spreads label and zone apart once stretched.
          KkAlignSelf(
            align: KkCrossAlign.stretch,
            child: KkRow(
              shrinkWrap: true,
              gap: m.space2,
              main: KkMainAlign.between,
              cross: KkCrossAlign.baseline,
              clip: Clip.hardEdge,
              children: <Widget>[
                KkRow(
                  shrinkWrap: true,
                  gap: m.space2,
                  cross: KkCrossAlign.baseline,
                  children: <Widget>[
                    if (cjk != null && cjk.isNotEmpty)
                      KkText.cjk(cjk, size: 14, height: 1.55, color: c.ink, squeeze: 0.8),
                    if (en != null && en.isNotEmpty)
                      KkText.en(en, size: 11, weight: FontWeight.w600, height: 1.55, spacing: 0.14, color: c.inkDim),
                  ],
                ),
                if (zone != null && zone.isNotEmpty)
                  KkText.num(zone, size: 11, weight: FontWeight.w600, color: widget.enabled ? c.signal : c.inkFaint),
              ],
            ),
          ),
        row,
      ],
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel ?? en ?? cjk ?? 'Time',
      value: widget.value.format(seconds: widget.showSeconds),
      child: widget.frame
          ? KkBox(
              padding: EdgeInsets.symmetric(horizontal: m.space4, vertical: m.space3),
              decoration: KkDecoration(
                fill: c.bg100,
                edges: KkEdges.line(widget.enabled ? c.line : c.offline, width: m.stroke1, dashed: !widget.enabled),
              ),
              child: body,
            )
          : body,
    );
  }
}

class _KkTimeSegment extends StatefulWidget {
  const _KkTimeSegment({
    required this.value,
    required this.max,
    required this.label,
    required this.semanticLabel,
    required this.focusNode,
    required this.autofocus,
    required this.live,
    required this.enabled,
    required this.onKey,
    required this.onNudge,
  });

  final int value;
  final int max;
  final String label;
  final String semanticLabel;
  final FocusNode focusNode;
  final bool autofocus;
  final bool live;
  final bool enabled;
  final KeyEventResult Function(KeyEvent event) onKey;
  final ValueChanged<int> onNudge;

  @override
  State<_KkTimeSegment> createState() => _KkTimeSegmentState();
}

class _KkTimeSegmentState extends State<_KkTimeSegment> {
  double _drag = 0;

  static const double _dragPerStep = 10;

  void _onDrag(DragUpdateDetails details) {
    _drag += details.delta.dy;
    while (_drag <= -_dragPerStep) {
      _drag += _dragPerStep;
      widget.onNudge(1);
    }
    while (_drag >= _dragPerStep) {
      _drag -= _dragPerStep;
      widget.onNudge(-1);
    }
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !widget.live || event.scrollDelta.dy == 0) return;
    // Claim the wheel so the page behind does not scroll as well.
    GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent e) {
      widget.onNudge((e as PointerScrollEvent).scrollDelta.dy < 0 ? 1 : -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool focused = widget.focusNode.hasFocus && widget.live;
    final Color ink = !widget.enabled
        ? c.inkFaint
        : focused
        ? c.signal
        : c.ink;
    final String text = widget.value.toString().padLeft(2, '0');
    final double ring = focused ? m.stroke1 : 0;
    return Semantics(
      label: widget.semanticLabel,
      value: text,
      increasedValue: ((widget.value + 1) % (widget.max + 1)).toString().padLeft(2, '0'),
      decreasedValue: ((widget.value + widget.max) % (widget.max + 1)).toString().padLeft(2, '0'),
      onIncrease: widget.live ? () => widget.onNudge(1) : null,
      onDecrease: widget.live ? () => widget.onNudge(-1) : null,
      enabled: widget.enabled,
      child: KkColumn(
        gap: 2,
        shrinkWrap: true,
        cross: KkCrossAlign.center,
        children: <Widget>[
          Focus(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            canRequestFocus: widget.live,
            onKeyEvent: (FocusNode node, KeyEvent event) => widget.onKey(event),
            child: Listener(
              onPointerSignal: _onSignal,
              child: MouseRegion(
                cursor: widget.live ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.forbidden,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapDown: widget.live ? (TapDownDetails details) => widget.focusNode.requestFocus() : null,
                  onVerticalDragStart: widget.live
                      ? (DragStartDetails details) {
                          _drag = 0;
                          widget.focusNode.requestFocus();
                        }
                      : null,
                  onVerticalDragUpdate: widget.live ? _onDrag : null,
                  child: KkBox(
                    width: 64,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: KkDecoration(
                      fill: c.bg000,
                      edges: KkEdges.line(
                        !widget.enabled
                            ? c.offline
                            : focused
                            ? c.signal
                            : c.inkFaint,
                        width: m.stroke1 + ring,
                        dashed: !widget.enabled,
                      ),
                    ),
                    child: KkText.num(text, size: 36, weight: FontWeight.w500, color: ink),
                  ),
                ),
              ),
            ),
          ),
          KkText.en(widget.label, size: 9, weight: FontWeight.w600, spacing: 0.16, color: c.inkFaint),
        ],
      ),
    );
  }
}
