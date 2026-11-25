import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// `steps(count, end)`: the curve of every KEIKAI transition.
///
/// Motion in KEIKAI is stepped and has no easing: it snaps from one frame to
/// the next instead of gliding.
class KkSteps extends Curve {
  const KkSteps(this.count) : assert(count > 0);

  final int count;

  @override
  double transformInternal(double t) => kkStepDown(t, count);

  @override
  bool operator ==(Object other) => other is KkSteps && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'KkSteps($count)';
}

/// The slack that lets a value on a step edge count as on it despite rounding.
const double _kkStepSlack = 1e-9;

/// `steps(count, end)` at [t]: the largest multiple of 1/[count] not above [t].
///
/// A value that sits on a step edge up to rounding error (15/22 × 22 is
/// 14.999999999999998 in floating point) counts as having reached that step.
double kkStepDown(double t, int count) {
  final double stepped = (t * count + _kkStepSlack).floorToDouble() / count;
  return stepped > 1.0 ? 1.0 : stepped;
}

/// How many of [count] equal steps have been reached at [t] (0 to 1): 0 before
/// the first edge, [count] at the end.
///
/// The edges are those of [kkStepDown], with the same allowance for rounding.
int kkStepAt(double t, int count) => (t * count + _kkStepSlack).floor();

/// Evaluates CSS-style keyframes at [t] (0 to 1).
///
/// [stops] are the keyframe positions in ascending order and [values] the
/// value at each. When [steps] is given, each segment between two keyframes
/// is quantised with `steps(steps, end)`, exactly as a CSS animation applies
/// its timing function per keyframe interval.
double kkKeyframes(double t, List<double> stops, List<double> values, {int? steps}) {
  assert(stops.length == values.length && stops.length >= 2);
  if (t <= stops.first) return values.first;
  if (t >= stops.last) return values.last;
  for (int i = 0; i < stops.length - 1; i++) {
    final double a = stops[i];
    final double b = stops[i + 1];
    if (t < b) {
      double local = b == a ? 1.0 : (t - a) / (b - a);
      if (steps != null) local = kkStepDown(local, steps);
      return values[i] + (values[i + 1] - values[i]) * local;
    }
  }
  return values.last;
}

/// An [Animatable] over CSS-style keyframes. See [kkKeyframes].
class KkKeyframes extends Animatable<double> {
  const KkKeyframes(this.stops, this.values, {this.steps});

  /// The 0.5s boot flicker of a panel body: 0 → .9 → .1 → 1 → .35 → 1.
  static const KkKeyframes flicker = KkKeyframes(
    <double>[0, 0.2, 0.3, 0.45, 0.55, 0.7, 1],
    <double>[0, 0.9, 0.1, 1, 0.35, 1, 1],
    steps: 10,
  );

  final List<double> stops;
  final List<double> values;
  final int? steps;

  @override
  double transform(double t) => kkKeyframes(t, stops, values, steps: steps);
}

/// Motion settings of a theme, and the canonical timings of the language.
///
/// | moment | movement | time |
/// | --- | --- | --- |
/// | screen / panel enters | left-to-right wipe, 7 steps, body flicker | 0.42s |
/// | value update | digits scramble then settle from the front | 0.46s |
/// | meter / progress | 9-step transition | 0.45s |
/// | charts | lines wipe in, bars grow, needles sweep | 0.5–0.9s |
/// | alarm | strobe 1.2s, hazard runs 0.9s | loop |
/// | alarm entry | screen glitch and three red flashes | 0.5–0.7s |
///
/// With [enabled] false, or when the platform asks for reduced motion, every
/// animation is skipped and only the final state is shown; a strobe becomes a
/// steady fill.
@immutable
class KkMotion {
  const KkMotion({this.enabled = true, this.timeScale = 1.0, this.staggerStep = const Duration(milliseconds: 60)})
    : assert(timeScale > 0);

  /// No motion at all. Use it in widget tests that call `pumpAndSettle`.
  static const KkMotion off = KkMotion(enabled: false);

  final bool enabled;

  /// Multiplies every duration. 2.0 is half speed.
  final double timeScale;

  /// Delay added per stagger index (grid cell order).
  final Duration staggerStep;

  static const Duration boot = Duration(milliseconds: 420);
  static const int bootSteps = 7;
  static const Duration flicker = Duration(milliseconds: 500);
  static const Duration headGrow = Duration(milliseconds: 300);
  static const int headGrowSteps = 6;
  static const Duration scramble = Duration(milliseconds: 460);
  static const Duration meter = Duration(milliseconds: 450);
  static const int meterSteps = 9;
  static const Duration wipe = Duration(milliseconds: 800);
  static const int wipeSteps = 16;
  static const Duration barGrow = Duration(milliseconds: 500);
  static const int barGrowSteps = 10;
  static const Duration needle = Duration(milliseconds: 700);
  static const int needleSteps = 12;
  static const Duration strobe = Duration(milliseconds: 1200);
  static const Duration blink = Duration(milliseconds: 1200);
  static const Duration colon = Duration(milliseconds: 1000);
  static const Duration hazard = Duration(milliseconds: 900);
  static const Duration rowIn = Duration(milliseconds: 1000);
  static const Duration glitch = Duration(milliseconds: 500);
  static const Duration flash = Duration(milliseconds: 700);
  static const Duration sweep = Duration(seconds: 4);
  static const Duration flow = Duration(seconds: 1);

  /// [d] multiplied by [timeScale].
  Duration scaled(Duration d) => timeScale == 1.0 ? d : Duration(microseconds: (d.inMicroseconds * timeScale).round());

  KkMotion copyWith({bool? enabled, double? timeScale, Duration? staggerStep}) => KkMotion(
    enabled: enabled ?? this.enabled,
    timeScale: timeScale ?? this.timeScale,
    staggerStep: staggerStep ?? this.staggerStep,
  );

  @override
  bool operator ==(Object other) =>
      other is KkMotion && other.enabled == enabled && other.timeScale == timeScale && other.staggerStep == staggerStep;

  @override
  int get hashCode => Object.hash(enabled, timeScale, staggerStep);
}

Duration _kkLastFrameTime = Duration.zero;
bool _kkFrameClockHooked = false;

/// The timestamp of the current frame (or of the last one, between frames).
///
/// Every looping animation in KEIKAI derives its phase from this one clock,
/// so all strobes, blinks and hazards on screen stay in step with each other.
Duration kkFrameTime() {
  final SchedulerBinding binding = SchedulerBinding.instance;
  if (!_kkFrameClockHooked) {
    // Record every frame from now on, so a call between frames really gets the
    // last frame's time even when nothing sampled the clock during it.
    _kkFrameClockHooked = true;
    binding.addPersistentFrameCallback((Duration timeStamp) => _kkLastFrameTime = timeStamp);
  }
  if (binding.schedulerPhase != SchedulerPhase.idle) {
    _kkLastFrameTime = binding.currentFrameTimeStamp;
  }
  return _kkLastFrameTime;
}

/// The phase index (0 to [phases] − 1) of a loop of [period] at [time].
int kkPhaseAt(Duration time, Duration period, {int phases = 2}) {
  final int p = period.inMicroseconds;
  if (p <= 0) return 0;
  return ((time.inMicroseconds % p) * phases) ~/ p;
}

/// The position (0 to 1) inside a loop of [period] at [time].
double kkLoopAt(Duration time, Duration period) {
  final int p = period.inMicroseconds;
  if (p <= 0) return 0;
  return (time.inMicroseconds % p) / p;
}
