import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'hug.dart';

/// How a [KkTimer] writes its time.
enum KkTimerFormat {
  /// `MM:SS.cc` below one hour, `HH:MM:SS` from one hour.
  auto,

  /// Always `MM:SS.cc` (minutes keep counting past 59).
  minutes,

  /// Always `HH:MM:SS`.
  hours,
}

String _two(int v) => v < 10 ? '0$v' : '$v';

/// [text], or null when it is empty: an empty string is nothing to show and
/// gets no slot, gap or line of its own.
String? _given(String? text) => (text == null || text.isEmpty) ? null : text;

/// Splits [time] into the large digits and the small centiseconds part of a
/// timer: `04:59` and `.82`, or `01:02:03` and null.
///
/// A negative time has a minus sign in front, unless it is written as zero:
/// the smallest unit shown is the centisecond, or the second with hours.
({String digits, String? centis}) kkFormatTimer(Duration time, {KkTimerFormat format = KkTimerFormat.auto}) {
  final int totalCs = time.inMicroseconds.abs() ~/ 10000;
  final int cs = totalCs % 100;
  final int totalSeconds = totalCs ~/ 100;
  final int seconds = totalSeconds % 60;
  final int totalMinutes = totalSeconds ~/ 60;
  final bool hours = format == KkTimerFormat.hours || (format == KkTimerFormat.auto && totalMinutes >= 60);
  final bool shown = hours ? totalSeconds > 0 : totalCs > 0;
  final String sign = (time.isNegative && shown) ? '-' : '';
  if (hours) {
    return (digits: '$sign${_two(totalMinutes ~/ 60)}:${_two(totalMinutes % 60)}:${_two(seconds)}', centis: null);
  }
  return (digits: '$sign${_two(totalMinutes)}:${_two(seconds)}', centis: '.${_two(cs)}');
}

/// Starts, stops and resets a self-running [KkTimer] (`KkTimer.countdown` or
/// `KkTimer.stopwatch`) and reports its state.
///
/// Listeners are told when the timer starts, stops, is reset or runs out, not
/// on every tick. A timer that starts by itself, starts again because it was
/// given a new duration, or leaves the tree does so while the tree is being
/// built: listeners are told of that at the end of the frame.
class KkTimerController extends ChangeNotifier {
  _KkTimerState? _state;
  bool _disposed = false;
  bool _telling = false;

  /// Whether the attached timer is counting.
  bool get isRunning => _state?._running ?? false;

  /// The time counted so far. While the timer's page is covered by another it
  /// is counted in tenths of a second.
  Duration get elapsed => _state?._elapsed ?? Duration.zero;

  /// Starts or resumes counting.
  void start() => _state?._start();

  /// Pauses counting and keeps the time.
  void stop() => _state?._stop();

  /// Starts when stopped and stops when running.
  void toggle() => isRunning ? stop() : start();

  /// Stops and goes back to the beginning.
  void reset() => _state?._reset();

  /// What the controller reports about its timer: whether it is counting,
  /// and the time counted.
  (bool, Duration) get _report => (isRunning, elapsed);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Tells the listeners at the end of the frame, once however often it is
  /// asked to in that frame.
  ///
  /// This is for changes that are made while the tree is being built, when
  /// listeners must not be called.
  void _changedLater() {
    if (_telling) return;
    _telling = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _telling = false;
      _changed();
    });
  }

  /// Tells the listeners at the end of the frame, if the controller no longer
  /// reports what it did [before].
  void _changedSince((bool, Duration) before) {
    if (_report != before) _changedLater();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

enum _TimerKind { controlled, countdown, stopwatch }

/// How often a self-running timer counts while no frame does it for it.
const Duration _kBeat = Duration(milliseconds: 100);

/// The timer: one key figure in 56px tabular mono with a progress bar under
/// it.
///
/// * [KkTimer] shows the [Duration] you give it.
/// * [KkTimer.countdown] counts down from a duration by itself.
/// * [KkTimer.stopwatch] counts up by itself.
///
/// Caution colours the border; critical adds the alarm glow and makes the
/// digits blink at 1.2s. A label or mode that is an empty string counts as
/// not given.
///
/// The self-running forms keep time while they are not drawn, as under a
/// page that covers theirs. A countdown that runs out there calls its `onDone`
/// then, within about a tenth of a second, and the digits are right again as
/// soon as the page is back.
class KkTimer extends StatefulWidget {
  /// A timer that shows [value]. [progress] (0 to 1) fills the bar.
  const KkTimer({
    super.key,
    required Duration this.value,
    this.progress = 1,
    this.cjk,
    this.en,
    this.mode,
    this.level,
    this.format = KkTimerFormat.auto,
    this.minWidth = 264,
    this.boot = true,
    this.color,
    this.squeeze = 0.8,
  }) : _kind = _TimerKind.controlled,
       from = null,
       controller = null,
       autostart = false,
       cautionAt = null,
       criticalAt = null,
       onDone = null;

  /// A timer that counts down from [from] to zero and then calls [onDone].
  ///
  /// The bar empties with the time left. With [cautionAt] / [criticalAt] the
  /// level changes when that much time (or less) is left. With no time to
  /// count, [from] being zero or less, it has run out as soon as it starts.
  const KkTimer.countdown({
    super.key,
    required Duration this.from,
    this.controller,
    this.autostart = true,
    this.cautionAt,
    this.criticalAt,
    this.onDone,
    this.cjk,
    this.en,
    this.mode,
    this.level,
    this.format = KkTimerFormat.auto,
    this.minWidth = 264,
    this.boot = true,
    this.color,
    this.squeeze = 0.8,
  }) : _kind = _TimerKind.countdown,
       value = null,
       progress = null;

  /// A timer that counts up from zero.
  const KkTimer.stopwatch({
    super.key,
    this.controller,
    this.autostart = true,
    this.progress = 1,
    this.cjk,
    this.en,
    this.mode,
    this.level,
    this.format = KkTimerFormat.auto,
    this.minWidth = 264,
    this.boot = true,
    this.color,
    this.squeeze = 0.8,
  }) : _kind = _TimerKind.stopwatch,
       value = null,
       from = null,
       cautionAt = null,
       criticalAt = null,
       onDone = null;

  final _TimerKind _kind;

  /// The time shown by a controlled timer.
  final Duration? value;

  /// Fill of the bar, 0 to 1. A countdown computes it from the time left.
  final double? progress;

  /// Where a countdown starts.
  final Duration? from;
  final KkTimerController? controller;

  /// Start counting as soon as the timer is shown.
  final bool autostart;

  /// A countdown turns caution when this much time or less is left.
  final Duration? cautionAt;

  /// A countdown turns critical when this much time or less is left.
  final Duration? criticalAt;

  /// Called once when a countdown reaches zero. A countdown that starts by
  /// itself with nothing left calls it at the end of its first frame.
  ///
  /// A countdown that has run out stays so when it is given another duration
  /// of zero or less, and does not call again: [from] may be worked out from a
  /// deadline with every build. It calls again when it has been given time to
  /// count, or has been reset, and runs out once more.
  final VoidCallback? onDone;

  final String? cjk;
  final String? en;

  /// Short mono text at the right of the head: `T-MINUS`, `COUNTDOWN`.
  final String? mode;

  /// Overrides the level a countdown takes from [cautionAt] / [criticalAt].
  final KkLevel? level;
  final KkTimerFormat format;
  final double minWidth;

  /// Wipe in when first shown.
  final bool boot;

  /// Overrides the colour of the digits and the bar (the level's, or signal).
  final Color? color;

  /// Horizontal compression of [cjk]; 1.0 turns it off.
  final double squeeze;

  @override
  State<KkTimer> createState() => _KkTimerState();
}

class _KkTimerState extends State<KkTimer> with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  /// Counts in place of the ticker while that is muted, [_kBeat] at a time.
  Timer? _beat;
  Duration _banked = Duration.zero;
  Duration _run = Duration.zero;
  bool _running = false;

  /// Whether tickers are disabled around the timer, as they are under a page
  /// that covers its own.
  bool _muted = false;
  bool _doneFired = false;
  int _shownCs = -1;

  bool get _live => widget._kind != _TimerKind.controlled;

  Duration get _elapsed => _banked + _run;

  Duration get _left {
    final Duration left = (widget.from ?? Duration.zero) - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the timer is a countdown with no time left to count.
  bool get _spent => widget._kind == _TimerKind.countdown && _left <= Duration.zero;

  @override
  void initState() {
    super.initState();
    final KkTimerController? controller = widget.controller;
    final (bool, Duration)? before = controller?._report;
    controller?._state = this;
    if (_live && widget.autostart) _start(notify: false);
    if (before != null) controller?._changedSince(before);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool muted = !TickerMode.valuesOf(context).enabled;
    if (muted == _muted) return;
    _muted = muted;
    if (_running) _keepTime();
  }

  @override
  void didUpdateWidget(KkTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final KkTimerController? old = oldWidget.controller;
    final KkTimerController? controller = widget.controller;
    final (bool, Duration)? oldBefore = old?._report;
    final (bool, Duration)? before = controller?._report;
    if (old != controller) {
      if (old?._state == this) old?._state = null;
      controller?._state = this;
    }
    if (oldWidget._kind != widget._kind || oldWidget.from != widget.from) {
      _stop(notify: false);
      _banked = Duration.zero;
      // A countdown that has run out and is given nothing to count again has
      // not run out a second time. A duration worked out from a deadline is
      // another one with every build once the deadline has passed: reporting
      // each of them would call onDone without end when that rebuilds the
      // parent.
      _doneFired = _doneFired && _spent;
      if (_live && widget.autostart) _start(notify: false);
    }
    if (oldBefore != null) old?._changedSince(oldBefore);
    if (before != null) controller?._changedSince(before);
  }

  @override
  void dispose() {
    final KkTimerController? controller = widget.controller;
    if (controller != null && controller._state == this) {
      final (bool, Duration) before = controller._report;
      controller._state = null;
      controller._changedSince(before);
    }
    _beat?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  /// Lets the beat count for as long as the ticker is muted.
  ///
  /// A muted ticker keeps its clock but is not called. Left to it, a countdown
  /// under another page would only find out that it has run out when the page
  /// comes back, and its controller would report the time of the last frame
  /// that was drawn.
  void _keepTime() {
    _beat?.cancel();
    _beat = null;
    if (!_muted) return;
    final Duration counted = _run;
    _beat = Timer.periodic(_kBeat, (Timer beat) => _count(counted + _kBeat * beat.tick, repaint: false));
  }

  /// Starts counting. With [notify] false the timer starts while the tree is
  /// being built, and nobody is called before the frame is over.
  void _start({bool notify = true}) {
    if (!_live || _running) return;
    if (_spent) {
      // Nothing is left to count, so the countdown has run out as it starts.
      if (_doneFired) return;
      _doneFired = true;
      if (notify) {
        widget.onDone?.call();
        widget.controller?._changed();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((Duration _) {
          if (mounted) widget.onDone?.call();
        });
        widget.controller?._changedLater();
      }
      return;
    }
    final Ticker ticker = _ticker ??= createTicker(_onTick);
    _run = Duration.zero;
    _running = true;
    ticker.start();
    _keepTime();
    if (notify) {
      if (mounted) setState(() {});
      widget.controller?._changed();
    }
  }

  void _stop({bool notify = true}) {
    if (!_running) return;
    _ticker?.stop();
    _beat?.cancel();
    _beat = null;
    _banked += _run;
    _run = Duration.zero;
    _running = false;
    if (notify) {
      if (mounted) setState(() {});
      widget.controller?._changed();
    }
  }

  void _reset() {
    _stop(notify: false);
    _banked = Duration.zero;
    _doneFired = false;
    _shownCs = -1;
    if (mounted) setState(() {});
    widget.controller?._changed();
  }

  void _onTick(Duration elapsed) {
    // At zero the ticker's clock starts with this tick: it was started between
    // frames. If it was muted until now, what the beat counted in its place is
    // not part of [elapsed] and is kept here.
    if (elapsed == Duration.zero) _banked += _run;
    _count(elapsed);
  }

  /// Takes [run], the time counted since the timer was last started, from a
  /// frame or from the beat. Only a frame repaints the digits.
  void _count(Duration run, {bool repaint = true}) {
    _run = run;
    if (_spent) {
      _ticker?.stop();
      _beat?.cancel();
      _beat = null;
      _banked = widget.from ?? Duration.zero;
      _run = Duration.zero;
      _running = false;
      setState(() {});
      if (!_doneFired) {
        _doneFired = true;
        widget.onDone?.call();
      }
      widget.controller?._changed();
      return;
    }
    if (!repaint) return;
    final int cs = _elapsed.inMicroseconds ~/ 10000;
    if (cs != _shownCs) setState(() => _shownCs = cs);
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;

    final Duration shown = switch (widget._kind) {
      _TimerKind.controlled => widget.value ?? Duration.zero,
      _TimerKind.countdown => _left,
      _TimerKind.stopwatch => _elapsed,
    };
    double progress;
    KkLevel? level = widget.level;
    if (widget._kind == _TimerKind.countdown) {
      final Duration from = widget.from ?? Duration.zero;
      // The bar is the share of the time that is left. It changes with every
      // frame, and the stepped value below still moves it one jump per step.
      progress = from <= Duration.zero ? 0 : (shown.inMicroseconds / from.inMicroseconds).clamp(0.0, 1.0);
      final Duration? crit = widget.criticalAt;
      final Duration? caution = widget.cautionAt;
      if (level == null) {
        if (crit != null && shown <= crit) {
          level = KkLevel.critical;
        } else if (caution != null && shown <= caution) {
          level = KkLevel.caution;
        }
      }
    } else {
      final double p = widget.progress ?? 1;
      progress = p.isNaN ? 0 : p.clamp(0.0, 1.0);
    }

    final bool critical = level == KkLevel.critical;
    final Color ink = widget.color ?? c.level(level);
    final Color border = switch (level) {
      KkLevel.caution => c.caution,
      KkLevel.critical => c.alert,
      _ => c.line,
    };
    final ({String digits, String? centis}) text = kkFormatTimer(shown, format: widget.format);
    final String? centis = text.centis;
    final TextStyle big = theme.type.mono(56, weight: FontWeight.w500, spacingEm: -0.03, color: ink);
    final TextStyle small = theme.type.mono(32, weight: FontWeight.w500, spacingEm: -0.01, color: ink);
    final String? label = _given(widget.cjk);
    final String? sub = _given(widget.en);
    final String? mode = _given(widget.mode);
    final bool hasLabels = label != null || sub != null;

    final Widget timer = Semantics(
      container: true,
      label: <String>[?label, ?sub, ?mode].join(' '),
      value: '${text.digits}${centis ?? ''}${level != null ? ' ${level.word}' : ''}',
      child: ExcludeSemantics(
        child: KkBox(
          minWidth: widget.minWidth,
          padding: EdgeInsets.symmetric(horizontal: m.space4, vertical: m.space3),
          decoration: KkDecoration(
            fill: c.bg100,
            edges: KkEdges.line(border, width: m.stroke1),
            glow: critical ? c.glowAlert : null,
          ),
          child: KkColumn(
            gap: m.space2,
            shrinkWrap: true,
            children: <Widget>[
              // The labels and the mode are two children pushed apart, as the
              // CSS head pushes its last item away with an auto margin. A
              // spacer between them would be a child of its own, with a gap on
              // both sides.
              if (hasLabels || mode != null)
                KkRow(
                  gap: m.space2,
                  main: hasLabels ? KkMainAlign.between : KkMainAlign.end,
                  cross: KkCrossAlign.baseline,
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    if (hasLabels)
                      KkRow(
                        shrinkWrap: true,
                        gap: m.space2,
                        cross: KkCrossAlign.baseline,
                        children: <Widget>[
                          if (label != null)
                            KkText.cjk(label, size: 14, height: 1.55, color: c.ink, squeeze: widget.squeeze),
                          if (sub != null)
                            KkText.en(
                              sub,
                              size: 11,
                              weight: FontWeight.w600,
                              height: 1.55,
                              spacing: 0.14,
                              color: c.inkDim,
                            ),
                        ],
                      ),
                    if (mode != null) KkText.num(mode, size: 11, weight: FontWeight.w600, color: c.inkDim),
                  ],
                ),
              KkBlink(
                enabled: critical,
                child: Text.rich(
                  TextSpan(
                    text: text.digits,
                    style: big,
                    children: <InlineSpan>[if (centis != null) TextSpan(text: centis, style: small)],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
              KkSteppedValue(
                value: progress,
                builder: (BuildContext context, double value) => CustomPaint(
                  size: Size(0, m.space1),
                  painter: _TimerBarPainter(value: value, track: c.signalDim, fill: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return KkHugWidth(child: widget.boot ? KkBoot(child: timer) : timer);
  }
}

class _TimerBarPainter extends CustomPainter {
  const _TimerBarPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final double w = size.width * value.clamp(0.0, 1.0);
    if (w > 0) canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_TimerBarPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.track != track || oldDelegate.fill != fill;
}
