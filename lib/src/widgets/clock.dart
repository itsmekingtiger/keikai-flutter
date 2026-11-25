import 'dart:async';

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../motion/loops.dart';

String _two(int v) => v < 10 ? '0$v' : '$v';

/// `14:02:31` (24-hour) for [time], with seconds unless [seconds] is false.
String kkFormatTime(DateTime time, {bool seconds = true}) =>
    seconds ? '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}' : '${_two(time.hour)}:${_two(time.minute)}';

/// `2026-11-24` for [time].
String kkFormatDate(DateTime time) => '${time.year}-${_two(time.month)}-${_two(time.day)}';

/// A running clock in tabular mono. Times in KEIKAI are UTC, 24-hour, with a
/// `Z` suffix; the colons blink once a second.
class KkClock extends StatefulWidget {
  const KkClock({
    super.key,
    this.style,
    this.color,
    this.seconds = true,
    this.utc = true,
    this.suffix,
    this.blink = true,
    this.clock,
  });

  /// Defaults to 15px medium mono in ink.
  final TextStyle? style;
  final Color? color;
  final bool seconds;

  /// Show UTC (the house rule) instead of local time.
  final bool utc;

  /// Text after the time. Defaults to `Z` for UTC and nothing for local time.
  final String? suffix;

  /// Blink the colons.
  final bool blink;

  /// Source of the current time; defaults to the system clock. Give a fixed
  /// function in tests.
  final DateTime Function()? clock;

  @override
  State<KkClock> createState() => _KkClockState();
}

class _KkClockState extends State<KkClock> {
  Timer? _timer;
  late DateTime _now = _read();

  DateTime _read() {
    final DateTime t = (widget.clock ?? DateTime.now)();
    return widget.utc ? t.toUtc() : t.toLocal();
  }

  void _schedule() {
    _timer?.cancel();
    final int ms = 1000 - _now.millisecond;
    _timer = Timer(Duration(milliseconds: ms <= 0 ? 1000 : ms), () {
      if (!mounted) return;
      setState(() => _now = _read());
      _schedule();
    });
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(KkClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.utc != widget.utc || oldWidget.clock != widget.clock) {
      _now = _read();
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final Color ink = widget.color ?? widget.style?.color ?? theme.colors.ink;
    final TextStyle style = (widget.style ?? theme.type.mono(15, weight: FontWeight.w500)).copyWith(color: ink);
    final String text = kkFormatTime(_now, seconds: widget.seconds);
    final String suffix = widget.suffix ?? (widget.utc ? 'Z' : '');
    return KkPhaseBuilder(
      period: KkMotion.colon,
      enabled: widget.blink,
      builder: (BuildContext context, int phase, Widget? child) {
        final TextStyle colon = style.copyWith(color: phase == 0 ? ink : kkFade(ink, 0.2));
        final List<String> parts = text.split(':');
        return Text.rich(
          TextSpan(
            style: style,
            children: <InlineSpan>[
              for (int i = 0; i < parts.length; i++) ...<InlineSpan>[
                if (i > 0) TextSpan(text: ':', style: colon),
                TextSpan(text: parts[i]),
              ],
              if (suffix.isNotEmpty) TextSpan(text: suffix),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          semanticsLabel: '$text$suffix',
        );
      },
    );
  }
}
