import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/motion.dart';
import '../foundation/theme.dart';

/// Rebuilds when a looping clock moves from one phase to the next.
///
/// A strobe is two phases of a 1.2s loop; a blinking colon is two phases of a
/// 1s loop. All loops share the frame clock, so every strobe on screen flips
/// at the same instant. With motion off the phase stays 0 (the resting look).
class KkPhaseBuilder extends StatefulWidget {
  const KkPhaseBuilder({
    super.key,
    this.period = KkMotion.strobe,
    this.phases = 2,
    this.enabled = true,
    required this.builder,
    this.child,
  }) : assert(phases > 0);

  final Duration period;
  final int phases;

  /// Stops the loop (phase 0) without removing it from the tree.
  final bool enabled;
  final Widget Function(BuildContext context, int phase, Widget? child) builder;
  final Widget? child;

  @override
  State<KkPhaseBuilder> createState() => _KkPhaseBuilderState();
}

class _KkPhaseBuilderState extends State<KkPhaseBuilder> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  int _phase = 0;
  bool _running = false;

  Duration get _period => KeikaiTheme.of(context).motion.scaled(widget.period);

  void _tick(Duration _) {
    final int p = kkPhaseAt(kkFrameTime(), _period, phases: widget.phases);
    if (p != _phase) setState(() => _phase = p);
  }

  void _sync() {
    final bool shouldRun = widget.enabled && KeikaiTheme.motionOf(context);
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      _phase = kkPhaseAt(kkFrameTime(), _period, phases: widget.phases);
      (_ticker ??= createTicker(_tick)).start();
    } else {
      _ticker?.stop();
      _phase = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KkPhaseBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _running ? _phase : 0, widget.child);
}

/// Blinks its child: full for half of [period], dimmed to [dimOpacity] for the
/// other half, with no fade between.
class KkBlink extends StatelessWidget {
  const KkBlink({
    super.key,
    this.period = KkMotion.blink,
    this.dimOpacity = 0.2,
    this.enabled = true,
    required this.child,
  });

  final Duration period;
  final double dimOpacity;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KkPhaseBuilder(
      period: period,
      enabled: enabled,
      child: child,
      builder: (BuildContext context, int phase, Widget? child) =>
          Opacity(opacity: phase == 0 ? 1.0 : dimOpacity, child: child),
    );
  }
}

/// Hands a continuously running clock to [builder] as a listenable.
///
/// Use it for the few motions that glide instead of stepping: the running
/// hazard, the radar sweep, a flowing wire. Pass the listenable to a
/// `CustomPainter(repaint: …)` so only painting happens per frame. With motion
/// off the clock stays at zero.
class KkLoop extends StatefulWidget {
  const KkLoop({super.key, this.enabled = true, required this.builder});

  final bool enabled;
  final Widget Function(BuildContext context, ValueListenable<Duration> time) builder;

  @override
  State<KkLoop> createState() => _KkLoopState();
}

class _KkLoopState extends State<KkLoop> with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _time = ValueNotifier<Duration>(Duration.zero);
  Ticker? _ticker;
  bool _running = false;
  double _scale = 1;

  void _tick(Duration _) {
    final Duration now = kkFrameTime();
    _time.value = _scale == 1.0 ? now : Duration(microseconds: (now.inMicroseconds / _scale).round());
  }

  void _sync() {
    _scale = KeikaiTheme.of(context).motion.timeScale;
    final bool shouldRun = widget.enabled && KeikaiTheme.motionOf(context);
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      (_ticker ??= createTicker(_tick)).start();
    } else {
      _ticker?.stop();
      _time.value = Duration.zero;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KkLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _time);
}
