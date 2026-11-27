import 'package:flutter/widgets.dart';

import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'stagger.dart';

/// Runs once when it enters the tree (and again whenever [trigger] changes):
/// waits [delay] plus the ambient stagger delay, then drives [builder] from
/// 0 to 1 over [duration].
///
/// With motion off the progress is 1 from the first frame.
class KkOneShot extends StatefulWidget {
  const KkOneShot({
    super.key,
    required this.duration,
    this.delay = Duration.zero,
    this.trigger,
    this.stagger = true,
    this.enabled = true,
    this.onDone,
    required this.builder,
    this.child,
  });

  final Duration duration;
  final Duration delay;

  /// Replays the animation when this value changes.
  final Object? trigger;

  /// Add the ambient [KkStagger] index × the theme's stagger step to [delay].
  final bool stagger;
  final bool enabled;

  /// Called once each time the animation ends. That includes the times it
  /// does not play to its end: with motion off, with [enabled] false, with
  /// nothing to play, or when motion is switched off while it runs. Then the
  /// call comes at the end of the frame.
  final VoidCallback? onDone;

  /// [progress] is linear from 0 to 1; apply [KkSteps] or [KkKeyframes] to it.
  /// [done] turns true when the animation has finished.
  final Widget Function(BuildContext context, Animation<double> progress, bool done, Widget? child) builder;
  final Widget? child;

  @override
  State<KkOneShot> createState() => _KkOneShotState();
}

class _KkOneShotState extends State<KkOneShot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)..addStatusListener(_onStatus);
  Animation<double> _progress = const AlwaysStoppedAnimation<double>(1);
  CurvedAnimation? _curved;
  bool _started = false;
  bool _done = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (!_done && mounted) setState(() => _done = true);
      widget.onDone?.call();
    }
  }

  /// Ends the run without playing it to its end: the progress is 1 and the
  /// builder is told it is done.
  ///
  /// This runs while the tree is being built, where a callback must not call
  /// setState, so [KkOneShot.onDone] waits for the end of the frame.
  void _skip() {
    _controller.stop();
    _progress = const AlwaysStoppedAnimation<double>(1);
    _done = true;
    if (widget.onDone == null) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) widget.onDone?.call();
    });
  }

  void _start() {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final bool motion = widget.enabled && KeikaiTheme.motionOf(context);
    if (!motion) {
      _skip();
      return;
    }
    Duration delay = widget.delay;
    if (widget.stagger) delay += theme.motion.staggerStep * KkStagger.of(context);
    delay = theme.motion.scaled(delay);
    final Duration duration = theme.motion.scaled(widget.duration);
    final int total = delay.inMicroseconds + duration.inMicroseconds;
    if (total <= 0) {
      _skip();
      return;
    }
    _controller.duration = Duration(microseconds: total);
    _curved?.dispose();
    _progress = _curved = CurvedAnimation(parent: _controller, curve: Interval(delay.inMicroseconds / total, 1));
    _done = false;
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _start();
    } else if (!KeikaiTheme.motionOf(context) && !_done) {
      _skip();
    }
  }

  @override
  void didUpdateWidget(KkOneShot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _start();
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress, _done, widget.child);
}

/// The boot wipe: the child is revealed from the left in [steps] jumps. Every
/// panel, chart and readout enters this way.
class KkBoot extends StatelessWidget {
  const KkBoot({
    super.key,
    this.duration = KkMotion.boot,
    this.steps = KkMotion.bootSteps,
    this.delay = Duration.zero,
    this.trigger,
    this.stagger = true,
    this.enabled = true,
    this.axis = Axis.horizontal,
    required this.child,
  });

  final Duration duration;
  final int steps;
  final Duration delay;
  final Object? trigger;
  final bool stagger;
  final bool enabled;

  /// Horizontal wipes left to right; vertical wipes top to bottom.
  final Axis axis;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KkOneShot(
      duration: duration,
      delay: delay,
      trigger: trigger,
      stagger: stagger,
      enabled: enabled,
      child: child,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) {
        return ClipRect(
          clipBehavior: done ? Clip.none : Clip.hardEdge,
          clipper: _WipeClipper(progress, steps, axis),
          child: child,
        );
      },
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  _WipeClipper(this.progress, this.steps, this.axis) : super(reclip: progress);

  final Animation<double> progress;
  final int steps;
  final Axis axis;

  @override
  Rect getClip(Size size) {
    final double t = KkSteps(steps).transform(progress.value.clamp(0.0, 1.0));
    return axis == Axis.horizontal
        ? Rect.fromLTWH(0, 0, size.width * t, size.height)
        : Rect.fromLTWH(0, 0, size.width, size.height * t);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.steps != steps || oldClipper.axis != axis;
}

/// The boot flicker: opacity stutters 0 → .9 → .1 → 1 → .35 → 1. Panel bodies
/// do this right after the panel has wiped in.
class KkFlicker extends StatelessWidget {
  const KkFlicker({
    super.key,
    this.duration = KkMotion.flicker,
    this.keyframes = KkKeyframes.flicker,
    this.delay = Duration.zero,
    this.trigger,
    this.stagger = true,
    this.enabled = true,
    required this.child,
  });

  final Duration duration;
  final KkKeyframes keyframes;
  final Duration delay;
  final Object? trigger;
  final bool stagger;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KkOneShot(
      duration: duration,
      delay: delay,
      trigger: trigger,
      stagger: stagger,
      enabled: enabled,
      child: child,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) =>
          FadeTransition(opacity: keyframes.animate(progress), child: child),
    );
  }
}

/// Grows the child from nothing along one axis in [steps] jumps: panel header
/// bands grow from the left, bars from the bottom.
class KkGrow extends StatelessWidget {
  const KkGrow({
    super.key,
    this.axis = Axis.horizontal,
    this.alignment = Alignment.centerLeft,
    this.duration = KkMotion.headGrow,
    this.steps = KkMotion.headGrowSteps,
    this.delay = Duration.zero,
    this.trigger,
    this.stagger = true,
    this.enabled = true,
    required this.child,
  });

  final Axis axis;

  /// The edge the child grows from.
  final Alignment alignment;
  final Duration duration;
  final int steps;
  final Duration delay;
  final Object? trigger;
  final bool stagger;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KkOneShot(
      duration: duration,
      delay: delay,
      trigger: trigger,
      stagger: stagger,
      enabled: enabled,
      child: child,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) {
        return AnimatedBuilder(
          animation: progress,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final double t = KkSteps(steps).transform(progress.value.clamp(0.0, 1.0));
            return Transform.scale(
              scaleX: axis == Axis.horizontal ? t : 1,
              scaleY: axis == Axis.vertical ? t : 1,
              alignment: alignment,
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Animates a number toward [value] in [steps] jumps whenever it changes: the
/// 9-step transition of meters and progress bars, the 10-step swing of a
/// gauge needle.
///
/// A change that arrives while the number is moving starts [steps] new jumps
/// from the number shown, as a CSS transition does. A change that arrives
/// less than one step after the change before it does not: starting over
/// every time would never let the number move. The run in flight then keeps
/// its clock and aims the jumps it has left at the new value, so a value that
/// changes every frame is caught up with at the end of every run, one
/// [duration] after that run began.
class KkSteppedValue extends StatefulWidget {
  const KkSteppedValue({
    super.key,
    required this.value,
    this.duration = KkMotion.meter,
    this.steps = KkMotion.meterSteps,
    this.from,
    required this.builder,
  });

  final double value;
  final Duration duration;
  final int steps;

  /// The value to start from when first shown. Defaults to [value] (no
  /// entrance); pass 0 to sweep up from zero.
  final double? from;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<KkSteppedValue> createState() => _KkSteppedValueState();
}

class _KkSteppedValueState extends State<KkSteppedValue> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)..addListener(_onTick);

  /// The number the run moves from, and how far the run had stepped when it
  /// showed that number: 0 for a run that starts there, more for a run that
  /// was given a new target on its way.
  late double _from = widget.from ?? widget.value;
  double _fromStep = 0;
  late double _to = widget.value;

  /// Where the clock of the run stood (0 to 1) when its target last changed.
  double _aimedAt = 0;
  double _shown = 0;
  bool _started = false;

  /// How far the run has stepped: 0 until its first jump, 1 at the end.
  double _stepped() => KkSteps(widget.steps).transform(_controller.value.clamp(0.0, 1.0));

  /// The number to show: of the way from [_from] to [_to], the share that the
  /// steps made since [_fromStep] are of the steps that were left then.
  double _current() {
    final double stepped = _stepped();
    if (stepped >= 1) return _to;
    return _from + (_to - _from) * ((stepped - _fromStep) / (1 - _fromStep)).clamp(0.0, 1.0);
  }

  void _onTick() {
    final double v = _current();
    if (v != _shown) setState(() => _shown = v);
  }

  /// Moves from [_from] to [_to]. With [restart] false a run in flight keeps
  /// its clock.
  void _run({bool restart = true}) {
    if (!KeikaiTheme.motionOf(context) || _from == _to) {
      _controller.value = 1;
      _shown = _to;
      return;
    }
    if (restart) {
      _fromStep = 0;
      _aimedAt = 0;
      _controller.duration = KeikaiTheme.of(context).motion.scaled(widget.duration);
      _controller.forward(from: 0);
    }
    _shown = _current();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    } else if (_controller.isAnimating && !KeikaiTheme.motionOf(context)) {
      // Motion was switched off while the number was moving: it jumps to
      // where it was going, as it would have had motion been off all along.
      _run();
    }
  }

  @override
  void didUpdateWidget(KkSteppedValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // A change starts the run again from the number shown, as it restarts a
      // CSS transition, unless the run in flight was given its target less
      // than one step ago. Starting again would then push the next jump back
      // every time, and a value that changes more often than one step lasts
      // would never move. Such a run keeps its clock instead, and the jumps
      // it has left lead from the number shown to the new target.
      final double at = _controller.value;
      final double stepped = _stepped();
      final bool keep = _controller.isAnimating && stepped < 1 && kkStepAt(at - _aimedAt, widget.steps) < 1;
      _from = _current();
      _to = widget.value;
      if (keep) {
        _fromStep = stepped;
        _aimedAt = at;
      }
      _run(restart: !keep);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}
