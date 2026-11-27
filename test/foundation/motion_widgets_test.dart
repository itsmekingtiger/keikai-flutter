import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

const Duration _ms10 = Duration(milliseconds: 10);

/// Lets the harness page finish its 0.42s wipe, so that only the widget under
/// test can still be scheduling frames.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 20));
}

Duration _ms(int value) => Duration(milliseconds: value);

/// Paints nothing and records the loop time of every paint.
class _TimeLog extends CustomPainter {
  _TimeLog(this.time, this.log) : super(repaint: time);

  final ValueListenable<Duration> time;
  final List<Duration> log;

  @override
  void paint(Canvas canvas, Size size) => log.add(time.value);

  @override
  bool shouldRepaint(_TimeLog oldDelegate) => oldDelegate.time != time;
}

/// Records what a [KkOneShot] hands to its builder.
class _Probe {
  Animation<double>? progress;
  bool done = false;
  int builds = 0;
  int doneCalls = 0;

  double get value => progress!.value;

  Widget build({
    Duration duration = const Duration(milliseconds: 200),
    Duration delay = Duration.zero,
    Object? trigger,
    bool stagger = true,
    bool enabled = true,
  }) {
    return KkOneShot(
      duration: duration,
      delay: delay,
      trigger: trigger,
      stagger: stagger,
      enabled: enabled,
      onDone: () => doneCalls++,
      builder: (BuildContext context, Animation<double> p, bool isDone, Widget? child) {
        progress = p;
        done = isDone;
        builds++;
        return const SizedBox(width: 10, height: 10);
      },
    );
  }
}

void main() {
  group('KkOneShot', () {
    testChecked('waits for the delay, then runs linearly to 1 and reports done once', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(delay: _ms(100)), motion: true);
      expect(probe.value, 0);
      expect(probe.done, isFalse);
      await tester.pump(_ms(100));
      expect(probe.value, closeTo(0, 1e-9));
      await tester.pump(_ms(50));
      expect(probe.value, closeTo(0.25, 1e-9));
      await tester.pump(_ms(50));
      expect(probe.value, closeTo(0.5, 1e-9));
      expect(probe.done, isFalse);
      await tester.pump(_ms(100));
      expect(probe.value, 1);
      // The controller reports completion on the first frame after the end.
      await tester.pump(_ms10);
      expect(probe.done, isTrue);
      expect(probe.doneCalls, 1);
      await tester.pump(_ms(500));
      expect(probe.doneCalls, 1);
    });

    testChecked('adds 60ms per stagger index', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, KkStagger(index: 3, child: probe.build()), motion: true);
      await tester.pump(_ms(180));
      expect(probe.value, closeTo(0, 1e-9));
      await tester.pump(_ms(100));
      expect(probe.value, closeTo(0.5, 1e-9));
      await tester.pump(_ms(110));
      await tester.pump(_ms10);
      expect(probe.done, isTrue);
    });

    testChecked('stagger false ignores the index; a custom stagger step is used', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, KkStagger(index: 3, child: probe.build(stagger: false)), motion: true);
      await tester.pump(_ms(100));
      expect(probe.value, closeTo(0.5, 1e-9));
      final _Probe slow = _Probe();
      await pumpKk(
        tester,
        KkStagger(key: const ValueKey<int>(2), index: 2, child: slow.build()),
        motion: true,
        theme: KeikaiThemeData(motion: KkMotion(staggerStep: _ms(100))),
      );
      await tester.pump(_ms(200));
      expect(slow.value, closeTo(0, 1e-9));
      await tester.pump(_ms(200));
      expect(slow.value, 1);
    });

    testChecked('replays when the trigger changes', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(trigger: 1), motion: true);
      await tester.pump(_ms(300));
      expect(probe.done, isTrue);
      await pumpKk(tester, probe.build(trigger: 1), motion: true);
      expect(probe.done, isTrue, reason: 'same trigger: no replay');
      await pumpKk(tester, probe.build(trigger: 2), motion: true);
      expect(probe.done, isFalse);
      expect(probe.value, 0);
      await tester.pump(_ms(100));
      expect(probe.value, closeTo(0.5, 1e-9));
      await tester.pump(_ms(110));
      await tester.pump(_ms10);
      expect(probe.done, isTrue);
      expect(probe.doneCalls, 2);
    });

    testChecked('with motion off it is at the end from the first frame', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(delay: _ms(500)));
      expect(probe.value, 1);
      expect(probe.done, isTrue);
      await tester.pumpAndSettle();
      final _Probe off = _Probe();
      await pumpKk(tester, off.build(enabled: false), motion: true);
      expect(off.value, 1);
      expect(off.done, isTrue);
    });

    testChecked('a zero duration is done at once', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(duration: Duration.zero), motion: true);
      expect(probe.value, 1);
      expect(probe.done, isTrue);
    });

    testChecked('the time scale stretches delay and duration', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(
        tester,
        probe.build(delay: _ms(100)),
        motion: true,
        theme: const KeikaiThemeData(motion: KkMotion(timeScale: 2)),
      );
      await tester.pump(_ms(200));
      expect(probe.value, closeTo(0, 1e-9));
      await tester.pump(_ms(200));
      expect(probe.value, closeTo(0.5, 1e-9));
      await tester.pump(_ms(210));
      await tester.pump(_ms10);
      expect(probe.done, isTrue);
    });

    testChecked('turning reduced motion on mid-flight jumps to the end', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(duration: _ms(1000)), motion: true);
      await tester.pump(_ms(100));
      expect(probe.done, isFalse);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(probe.value, 1);
      expect(probe.done, isTrue);
    });

    testChecked('onDone is also called, once, when the animation does not play', (WidgetTester tester) async {
      Widget keyed(int key, Widget child) => KeyedSubtree(key: ValueKey<int>(key), child: child);
      // Motion off.
      final _Probe off = _Probe();
      await pumpKk(tester, keyed(1, off.build()));
      expect(off.done, isTrue);
      expect(off.doneCalls, 1);
      await tester.pump(_ms(500));
      expect(off.doneCalls, 1);
      // Disabled.
      final _Probe disabled = _Probe();
      await pumpKk(tester, keyed(2, disabled.build(enabled: false)), motion: true);
      expect(disabled.done, isTrue);
      expect(disabled.doneCalls, 1);
      // Nothing to play.
      final _Probe empty = _Probe();
      await pumpKk(tester, keyed(3, empty.build(duration: Duration.zero)), motion: true);
      expect(empty.done, isTrue);
      expect(empty.doneCalls, 1);
      // A rebuild is not a new run. A new trigger is, and it reports again.
      await pumpKk(tester, keyed(3, empty.build(duration: Duration.zero)), motion: true);
      expect(empty.doneCalls, 1);
      await pumpKk(tester, keyed(3, empty.build(duration: Duration.zero, trigger: 1)), motion: true);
      expect(empty.doneCalls, 2);
      await tester.pump(_ms(500));
      expect(empty.doneCalls, 2);
    });

    testChecked('onDone is called once when motion is switched off mid-flight', (WidgetTester tester) async {
      final _Probe probe = _Probe();
      await pumpKk(tester, probe.build(duration: _ms(1000)), motion: true);
      await tester.pump(_ms(100));
      expect(probe.doneCalls, 0);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(probe.done, isTrue);
      expect(probe.doneCalls, 1);
      // The run it cut short does not report a second time when its time is up.
      await tester.pump(_ms(2000));
      await tester.pump(_ms10);
      expect(probe.doneCalls, 1);
    });

    testChecked('onDone of an animation that does not play may rebuild its parent', (WidgetTester tester) async {
      int settled = 0;
      int builds = 0;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            builds++;
            return KkOneShot(
              duration: _ms(200),
              onDone: () => setState(() => settled++),
              builder: (BuildContext context, Animation<double> p, bool done, Widget? child) =>
                  const SizedBox(width: 10, height: 10),
            );
          },
        ),
      );
      expect(tester.takeException(), isNull);
      expect(settled, 1);
      await tester.pumpAndSettle();
      expect(settled, 1);
      expect(builds, 2);
    });
  });

  group('KkBoot', () {
    Rect clip(WidgetTester tester) {
      final ClipRect widget = tester.widget<ClipRect>(
        find.ancestor(of: find.byKey(const ValueKey<String>('boot')), matching: find.byType(ClipRect)).first,
      );
      return widget.clipper!.getClip(const Size(70, 20));
    }

    Clip behavior(WidgetTester tester) => tester
        .widget<ClipRect>(
          find.ancestor(of: find.byKey(const ValueKey<String>('boot')), matching: find.byType(ClipRect)).first,
        )
        .clipBehavior;

    const Widget child = SizedBox(key: ValueKey<String>('boot'), width: 70, height: 20);

    testChecked('wipes in from the left in 7 jumps over 0.42s', (WidgetTester tester) async {
      await pumpKk(tester, const KkBoot(child: child), motion: true);
      expect(clip(tester).width, 0);
      expect(behavior(tester), Clip.hardEdge);
      // Each step lasts 60ms and reveals a seventh. Sample the middle of each.
      await tester.pump(_ms(30));
      expect(clip(tester).width, 0);
      for (int step = 1; step <= 6; step++) {
        await tester.pump(_ms(60));
        expect(clip(tester).width, closeTo(10.0 * step, 1e-6), reason: 'step $step');
        expect(clip(tester).height, 20);
        expect(behavior(tester), Clip.hardEdge);
      }
      await tester.pump(_ms(60));
      expect(clip(tester).width, 70);
      // Once done the clip is lifted, so glows and brackets are not cut.
      expect(behavior(tester), Clip.none);
    });

    testChecked('stays hidden during its delay', (WidgetTester tester) async {
      await pumpKk(tester, KkBoot(delay: _ms(200), child: child), motion: true);
      await tester.pump(_ms(199));
      expect(clip(tester).width, 0);
      await tester.pump(_ms(31));
      expect(clip(tester).width, 0);
      await tester.pump(_ms(60));
      expect(clip(tester).width, closeTo(10, 1e-6));
    });

    testChecked('vertical wipes from the top; steps and duration are configurable', (WidgetTester tester) async {
      await pumpKk(tester, KkBoot(axis: Axis.vertical, duration: _ms(100), steps: 2, child: child), motion: true);
      expect(clip(tester), const Rect.fromLTWH(0, 0, 70, 0));
      await tester.pump(_ms(25));
      expect(clip(tester), const Rect.fromLTWH(0, 0, 70, 0));
      await tester.pump(_ms(50));
      expect(clip(tester), const Rect.fromLTWH(0, 0, 70, 10));
      await tester.pump(_ms(50));
      expect(clip(tester), const Rect.fromLTWH(0, 0, 70, 20));
    });

    testChecked('with motion off nothing is clipped', (WidgetTester tester) async {
      await pumpKk(tester, const KkBoot(child: child));
      expect(clip(tester).width, 70);
      expect(behavior(tester), Clip.none);
    });

    testChecked('keeps the state of its child when it finishes', (WidgetTester tester) async {
      int builds = 0;
      await pumpKk(
        tester,
        KkBoot(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              builds++;
              return child;
            },
          ),
        ),
        motion: true,
      );
      final State<StatefulBuilder> before = tester.state(find.byType(StatefulBuilder));
      await tester.pump(_ms(500));
      expect(tester.state(find.byType(StatefulBuilder)), same(before));
      expect(builds, 1);
    });
  });

  group('KkFlicker', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.ancestor(of: find.byKey(const ValueKey<String>('f')), matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;

    const Widget child = SizedBox(key: ValueKey<String>('f'), width: 10, height: 10);

    testChecked('stutters 0 → .9 → .1 → 1 → .35 → 1 over 0.5s', (WidgetTester tester) async {
      await pumpKk(tester, const KkFlicker(child: child), motion: true);
      expect(opacity(tester), 0);
      // Just after each keyframe the stepped value still holds that keyframe.
      await tester.pump(_ms(101));
      expect(opacity(tester), closeTo(0.9, 1e-9));
      await tester.pump(_ms(50));
      expect(opacity(tester), closeTo(0.1, 1e-9));
      await tester.pump(_ms(75));
      expect(opacity(tester), closeTo(1, 1e-9));
      await tester.pump(_ms(50));
      expect(opacity(tester), closeTo(0.35, 1e-9));
      await tester.pump(_ms(75));
      expect(opacity(tester), closeTo(1, 1e-9));
      await tester.pump(_ms(150));
      expect(opacity(tester), 1);
      // On the way up from 0 it climbs in ten steps: halfway is 0.45.
      await pumpKk(tester, const KkFlicker(key: ValueKey<int>(2), child: child), motion: true);
      await tester.pump(_ms(55));
      expect(opacity(tester), closeTo(0.45, 1e-9));
    });

    testChecked('motion off: fully visible', (WidgetTester tester) async {
      await pumpKk(tester, const KkFlicker(child: child));
      expect(opacity(tester), 1);
    });

    testChecked('custom keyframes', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkFlicker(
          duration: _ms(100),
          keyframes: const KkKeyframes(<double>[0, 0.5, 1], <double>[0.2, 0.8, 1], steps: 1),
          child: child,
        ),
        motion: true,
      );
      expect(opacity(tester), 0.2);
      await tester.pump(_ms(45));
      expect(opacity(tester), 0.2);
      await tester.pump(_ms(10));
      expect(opacity(tester), 0.8);
      await tester.pump(_ms(40));
      expect(opacity(tester), 0.8);
      await tester.pump(_ms(10));
      expect(opacity(tester), 1);
    });
  });

  group('KkGrow', () {
    Matrix4 matrix(WidgetTester tester) => tester
        .widget<Transform>(
          find.ancestor(of: find.byKey(const ValueKey<String>('g')), matching: find.byType(Transform)).first,
        )
        .transform;

    const Widget child = SizedBox(key: ValueKey<String>('g'), width: 60, height: 20);

    testChecked('grows along x in 6 jumps over 0.3s', (WidgetTester tester) async {
      await pumpKk(tester, const KkGrow(child: child), motion: true);
      expect(matrix(tester).entry(0, 0), 0);
      expect(matrix(tester).entry(1, 1), 1);
      await tester.pump(_ms(25));
      expect(matrix(tester).entry(0, 0), 0);
      for (int step = 1; step <= 5; step++) {
        await tester.pump(_ms(50));
        expect(matrix(tester).entry(0, 0), closeTo(step / 6, 1e-9), reason: 'step $step');
      }
      await tester.pump(_ms(50));
      expect(matrix(tester).entry(0, 0), 1);
    });

    testChecked('grows along y from the bottom when asked', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkGrow(
          axis: Axis.vertical,
          alignment: Alignment.bottomCenter,
          duration: KkMotion.barGrow,
          steps: KkMotion.barGrowSteps,
          delay: _ms(200),
          child: child,
        ),
        motion: true,
      );
      expect(matrix(tester).entry(1, 1), 0);
      expect(matrix(tester).entry(0, 0), 1);
      await tester.pump(_ms(200));
      expect(matrix(tester).entry(1, 1), 0);
      await tester.pump(_ms(275));
      expect(matrix(tester).entry(1, 1), closeTo(0.5, 1e-9));
      final Transform t = tester.widget<Transform>(
        find.ancestor(of: find.byKey(const ValueKey<String>('g')), matching: find.byType(Transform)).first,
      );
      expect(t.alignment, Alignment.bottomCenter);
      await tester.pump(_ms(250));
      expect(matrix(tester).entry(1, 1), 1);
    });

    testChecked('motion off: full size', (WidgetTester tester) async {
      await pumpKk(tester, const KkGrow(child: child));
      expect(matrix(tester).entry(0, 0), 1);
    });
  });

  group('KkSteppedValue', () {
    testChecked('moves to a new value in 9 jumps over 0.45s', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(10), motion: true);
      expect(shown, 10, reason: 'no entrance without from');
      await pumpKk(tester, build(100), motion: true);
      expect(shown, 10);
      await tester.pump(_ms(25));
      expect(shown, 10);
      for (int step = 1; step <= 8; step++) {
        await tester.pump(_ms(50));
        expect(shown, closeTo(10 + 10.0 * step, 1e-9), reason: 'step $step');
      }
      await tester.pump(_ms(100));
      expect(shown, 100);
    });

    testChecked('from sweeps up when first shown', (WidgetTester tester) async {
      double shown = -1;
      await pumpKk(
        tester,
        KkSteppedValue(
          value: 0.9,
          from: 0,
          duration: KkMotion.needle,
          steps: KkMotion.needleSteps,
          builder: (BuildContext context, double v) {
            shown = v;
            return const SizedBox(width: 10, height: 10);
          },
        ),
        motion: true,
      );
      expect(shown, 0);
      await tester.pump(_ms(380));
      expect(shown, closeTo(0.45, 1e-9));
      await tester.pump(_ms(350));
      expect(shown, 0.9);
    });

    testChecked('a change mid-flight starts from where it is', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(0), motion: true);
      await pumpKk(tester, build(90), motion: true);
      await tester.pump(_ms(175));
      expect(shown, closeTo(30, 1e-9));
      await pumpKk(tester, build(0), motion: true);
      expect(shown, closeTo(30, 1e-9));
      await tester.pump(_ms(450));
      expect(shown, 0);
    });

    testChecked('a change before the first jump re-aims the run without holding it back', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(0), motion: true);
      // Five values 10ms apart: all of them arrive inside the 50ms that the first step lasts.
      for (final double target in <double>[90, 18, 27, 63, 45]) {
        expect(shown, 0);
        await pumpKk(tester, build(target), motion: true);
        expect(shown, 0);
        await tester.pump(_ms10);
      }
      // 50ms after the first of them the run makes its first jump, a ninth of the way to the latest.
      expect(shown, closeTo(5, 1e-9));
      // It ends when it would have ended anyway, 0.45s after it began.
      await tester.pump(_ms(399));
      expect(shown, closeTo(40, 1e-9));
      await tester.pump(_ms(1));
      expect(shown, 45);
      await tester.pump(_ms10);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testChecked('a change after the first jump starts nine new steps from the value shown', (
      WidgetTester tester,
    ) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(0), motion: true);
      await pumpKk(tester, build(90), motion: true);
      await tester.pump(_ms(60));
      expect(shown, closeTo(10, 1e-9));
      await pumpKk(tester, build(100), motion: true);
      expect(shown, closeTo(10, 1e-9));
      // The new run has its own clock: nothing for 50ms, then a ninth of the new distance per step.
      await tester.pump(_ms(45));
      expect(shown, closeTo(10, 1e-9));
      await tester.pump(_ms(10));
      expect(shown, closeTo(20, 1e-9));
      await tester.pump(_ms(390));
      expect(shown, closeTo(90, 1e-9));
      await tester.pump(_ms(10));
      expect(shown, 100);
    });

    testChecked('going back to the value shown before the first jump ends the run', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(20), motion: true);
      await _settleRoute(tester);
      await pumpKk(tester, build(80), motion: true);
      await tester.pump(_ms(20));
      await pumpKk(tester, build(20), motion: true);
      expect(shown, 20);
      await tester.pump(_ms(20));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing left to animate');
      await tester.pump(_ms(500));
      expect(shown, 20);
    });

    testChecked('a value that changes every frame keeps moving and ends on its last value', (
      WidgetTester tester,
    ) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(0), motion: true);
      // The value rises by 0.005 per 16ms frame: three changes arrive inside every 50ms step.
      double value = 0;
      double last = 0;
      int jumps = 0;
      for (int frame = 1; frame <= 180; frame++) {
        value = frame * 0.005;
        await tester.pumpWidget(kkHarness(build(value), motion: true));
        await tester.pump(_ms(16));
        expect(shown, lessThan(value), reason: 'frame $frame');
        if (shown != last) {
          // Each jump covers a ninth of what is left to the latest value.
          expect(shown - last, closeTo((value - last) / 9, 1e-9), reason: 'frame $frame');
          jumps++;
        }
        last = shown;
      }
      // The first frame that is 50ms or more into a run is its fourth: one jump every four frames.
      expect(jumps, 45);
      // Behind a value that rises steadily it settles eight jumps' worth of rise back.
      expect(value - shown, closeTo(8 * 4 * 0.005, 0.002));
      // The run in flight began four frames ago, so it ends 386ms from here, on the last value.
      await tester.pump(_ms(385));
      expect(shown, lessThan(0.9));
      await tester.pump(_ms(1));
      expect(shown, 0.9);
    });

    testChecked('motion off jumps', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        from: 0,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(50));
      expect(shown, 50);
      await pumpKk(tester, build(70));
      await tester.pump();
      expect(shown, 70);
      await tester.pumpAndSettle();
    });

    testChecked('turning motion off mid-flight jumps to the value', (WidgetTester tester) async {
      double shown = -1;
      Widget build(double value) => KkSteppedValue(
        value: value,
        duration: _ms(1000),
        steps: 10,
        builder: (BuildContext context, double v) {
          shown = v;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(0), motion: true);
      await _settleRoute(tester);
      await pumpKk(tester, build(100), motion: true);
      await tester.pump(_ms(250));
      expect(shown, closeTo(20, 1e-9));
      // The platform asks for reduced motion.
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(shown, 100);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the run has stopped');
      // Motion coming back does not replay what was cut short.
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(_ms(100));
      expect(shown, 100);
      // The theme switches motion off.
      await pumpKk(tester, build(40), motion: true);
      await tester.pump(_ms(250));
      expect(shown, closeTo(88, 1e-9));
      await pumpKk(tester, build(40));
      expect(shown, 40);
      await tester.pumpAndSettle();
      expect(shown, 40);
    });
  });

  group('loops', () {
    testChecked('KkPhaseBuilder flips every half period and follows the shared clock', (WidgetTester tester) async {
      final List<int> phases = <int>[];
      int builds = 0;
      await pumpKk(
        tester,
        KkPhaseBuilder(
          builder: (BuildContext context, int phase, Widget? child) {
            builds++;
            phases.add(phase);
            return const SizedBox(width: 10, height: 10);
          },
        ),
        motion: true,
      );
      final int first = phases.last;
      expect(first, kkPhaseAt(kkFrameTime(), KkMotion.strobe));
      // Step frame by frame through 2.4s: the phase must always be the clock's.
      int flips = 0;
      int last = first;
      for (int i = 0; i < 240; i++) {
        await tester.pump(_ms10);
        expect(phases.last, kkPhaseAt(kkFrameTime(), KkMotion.strobe));
        if (phases.last != last) {
          flips++;
          last = phases.last;
        }
      }
      expect(flips, 4);
      // It rebuilt only when the phase changed, not on every frame.
      expect(builds, lessThanOrEqualTo(flips + 2));
    });

    testChecked('loops started at different times stay in step', (WidgetTester tester) async {
      int a = -1;
      int b = -1;
      Widget build(bool second) => KkRow(
        children: <Widget>[
          KkPhaseBuilder(
            builder: (BuildContext context, int phase, Widget? child) {
              a = phase;
              return const SizedBox(width: 10, height: 10);
            },
          ),
          if (second)
            KkPhaseBuilder(
              builder: (BuildContext context, int phase, Widget? child) {
                b = phase;
                return const SizedBox(width: 10, height: 10);
              },
            ),
        ],
      );
      await pumpKk(tester, build(false), motion: true);
      await tester.pump(_ms(250));
      await pumpKk(tester, build(true), motion: true);
      for (int i = 0; i < 150; i++) {
        await tester.pump(_ms10);
        expect(a, b, reason: 'frame $i');
      }
    });

    testChecked('phases and period are configurable', (WidgetTester tester) async {
      final Set<int> seen = <int>{};
      await pumpKk(
        tester,
        KkPhaseBuilder(
          period: _ms(400),
          phases: 4,
          builder: (BuildContext context, int phase, Widget? child) {
            seen.add(phase);
            return const SizedBox(width: 10, height: 10);
          },
        ),
        motion: true,
      );
      for (int i = 0; i < 50; i++) {
        await tester.pump(_ms10);
      }
      expect(seen, <int>{0, 1, 2, 3});
    });

    testChecked('motion off, or enabled false: phase 0 and no ticking', (WidgetTester tester) async {
      final List<int> phases = <int>[];
      Widget build({bool enabled = true}) => KkPhaseBuilder(
        enabled: enabled,
        builder: (BuildContext context, int phase, Widget? child) {
          phases.add(phase);
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build());
      await tester.pump(_ms(700));
      await tester.pumpAndSettle();
      expect(phases.toSet(), <int>{0});
      phases.clear();
      await pumpKk(tester, build(enabled: false), motion: true);
      await tester.pump(_ms(700));
      expect(phases.toSet(), <int>{0});
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Turning it back on resumes on the shared clock.
      await pumpKk(tester, build(), motion: true);
      await tester.pump(_ms(10));
      expect(phases.last, kkPhaseAt(kkFrameTime(), KkMotion.strobe));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testChecked('the time scale stretches the period', (WidgetTester tester) async {
      int phase = -1;
      await pumpKk(
        tester,
        KkPhaseBuilder(
          builder: (BuildContext context, int p, Widget? child) {
            phase = p;
            return const SizedBox(width: 10, height: 10);
          },
        ),
        motion: true,
        theme: const KeikaiThemeData(motion: KkMotion(timeScale: 2)),
      );
      await tester.pump(_ms(10));
      expect(phase, kkPhaseAt(kkFrameTime(), const Duration(milliseconds: 2400)));
      await tester.pump(_ms(1200));
      expect(phase, kkPhaseAt(kkFrameTime(), const Duration(milliseconds: 2400)));
    });

    testChecked('a new count, period or time scale takes effect in the frame that brings it', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      Widget build({int period = 400, int phases = 4}) => KkPhaseBuilder(
        period: _ms(period),
        phases: phases,
        builder: (BuildContext context, int phase, Widget? child) {
          calls.add('$phase/$phases');
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(), motion: true);
      await tester.pump(_ms(350));
      expect(kkFrameTime(), _ms(350));
      expect(calls.last, '3/4');
      // Fewer phases: 350ms into 400ms is the second of two, and the index never leaves the new range.
      await pumpKk(tester, build(phases: 2), motion: true);
      expect(calls.where((String call) => call.endsWith('/2')), <String>['1/2']);
      // A longer period: 350ms is the second half of 500ms but the first half of 1.2s.
      await pumpKk(tester, build(period: 500, phases: 2), motion: true);
      expect(calls.last, '1/2');
      calls.clear();
      await pumpKk(tester, build(period: 1200, phases: 2), motion: true);
      expect(calls, <String>['0/2']);
      // A slower time scale stretches the period the same way: 500ms becomes 1s.
      await pumpKk(tester, build(period: 500, phases: 2), motion: true);
      expect(calls.last, '1/2');
      calls.clear();
      await pumpKk(
        tester,
        build(period: 500, phases: 2),
        motion: true,
        theme: const KeikaiThemeData(motion: KkMotion(timeScale: 2)),
      );
      expect(calls, <String>['0/2']);
      // No frame went by in between, and the next one agrees.
      expect(kkFrameTime(), _ms(350));
      await tester.pump(_ms10);
      expect(calls, <String>['0/2']);
    });

    testChecked('KkBlink dims its child to 20% for half of each 1.2s', (WidgetTester tester) async {
      await pumpKk(tester, const KkBlink(child: SizedBox(width: 10, height: 10)), motion: true);
      final Set<double> seen = <double>{};
      for (int i = 0; i < 130; i++) {
        await tester.pump(_ms10);
        final double o = tester.widget<Opacity>(find.byType(Opacity)).opacity;
        expect(o, kkPhaseAt(kkFrameTime(), KkMotion.blink) == 0 ? 1.0 : 0.2);
        seen.add(o);
      }
      expect(seen, <double>{1.0, 0.2});
    });

    testChecked('KkBlink with motion off stays fully visible', (WidgetTester tester) async {
      await pumpKk(tester, const KkBlink(dimOpacity: 0.5, child: SizedBox(width: 10, height: 10)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await tester.pumpAndSettle();
    });

    testChecked('KkStrobe is lit for the first half of each 1.2s; always lit with motion off', (
      WidgetTester tester,
    ) async {
      bool lit = false;
      Widget build() => KkStrobe(
        builder: (BuildContext context, bool value) {
          lit = value;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(), motion: true);
      final Set<bool> seen = <bool>{};
      for (int i = 0; i < 130; i++) {
        await tester.pump(_ms10);
        expect(lit, kkPhaseAt(kkFrameTime(), KkMotion.strobe) == 0);
        seen.add(lit);
      }
      expect(seen, <bool>{true, false});
      await pumpKk(tester, build());
      await tester.pump(_ms(700));
      expect(lit, isTrue);
    });

    testChecked('KkLoop hands out the running frame clock', (WidgetTester tester) async {
      ValueListenable<Duration>? time;
      int builds = 0;
      Widget build({bool enabled = true}) => KkLoop(
        enabled: enabled,
        builder: (BuildContext context, ValueListenable<Duration> t) {
          time = t;
          builds++;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build(), motion: true);
      int ticks = 0;
      time!.addListener(() => ticks++);
      await tester.pump(_ms(100));
      final Duration t1 = time!.value;
      expect(t1, kkFrameTime());
      await tester.pump(_ms(250));
      expect(time!.value - t1, _ms(250));
      expect(ticks, 2);
      // The clock drives painting only: the builder ran once.
      expect(builds, 1);
      // Disabled: stopped at zero.
      await pumpKk(tester, build(enabled: false), motion: true);
      expect(time!.value, Duration.zero);
      await _settleRoute(tester);
      expect(time!.value, Duration.zero);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testChecked('KkLoop with motion off never ticks; time scale slows the clock', (WidgetTester tester) async {
      ValueListenable<Duration>? time;
      Widget build() => KkLoop(
        builder: (BuildContext context, ValueListenable<Duration> t) {
          time = t;
          return const SizedBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build());
      await tester.pump(_ms(300));
      expect(time!.value, Duration.zero);
      await tester.pumpAndSettle();
      await pumpKk(tester, build(), motion: true, theme: const KeikaiThemeData(motion: KkMotion(timeScale: 2)));
      await tester.pump(_ms(100));
      final Duration t1 = time!.value;
      await tester.pump(_ms(400));
      expect(time!.value - t1, _ms(200));
    });

    testChecked('KkLoop is on the shared clock in the frame that shows it', (WidgetTester tester) async {
      final List<Duration> first = <Duration>[];
      final List<Duration> second = <Duration>[];
      Widget loop(List<Duration> log, {bool enabled = true}) => KkLoop(
        enabled: enabled,
        builder: (BuildContext context, ValueListenable<Duration> time) =>
            CustomPaint(size: const Size(10, 10), painter: _TimeLog(time, log)),
      );
      Widget build({bool both = true, bool enabled = true}) => KkRow(
        children: <Widget>[
          loop(first),
          if (both) loop(second, enabled: enabled),
        ],
      );
      await pumpKk(tester, build(both: false), motion: true);
      await tester.pump(_ms(1234));
      expect(first.last, _ms(1234));
      // A loop that appears now paints its first frame where the running one is, not at zero.
      await tester.pumpWidget(kkHarness(build(), motion: true));
      expect(kkFrameTime(), _ms(1234));
      expect(second, <Duration>[_ms(1234)]);
      await tester.pump(_ms(16));
      expect(second, <Duration>[_ms(1234), _ms(1250)]);
      expect(first.last, _ms(1250));
      // Stopped, it rests at zero. Started again, it is back on the clock in that same frame.
      await tester.pumpWidget(kkHarness(build(enabled: false), motion: true));
      expect(second.last, Duration.zero);
      await tester.pump(_ms(100));
      second.clear();
      await tester.pumpWidget(kkHarness(build(), motion: true));
      expect(second, <Duration>[_ms(1350)]);
      expect(first.last, _ms(1350));
    });

    testChecked('KkLoop starts on the scaled clock when the theme slows time', (WidgetTester tester) async {
      final List<Duration> log = <Duration>[];
      const KeikaiThemeData slow = KeikaiThemeData(motion: KkMotion(timeScale: 2));
      Widget build(bool show) => show
          ? KkLoop(
              builder: (BuildContext context, ValueListenable<Duration> time) =>
                  CustomPaint(size: const Size(10, 10), painter: _TimeLog(time, log)),
            )
          : const SizedBox(width: 10, height: 10);
      await pumpKk(tester, build(false), motion: true, theme: slow);
      tester.binding.scheduleFrame();
      await tester.pump(_ms(1000));
      await tester.pumpWidget(kkHarness(build(true), motion: true, theme: slow));
      expect(log, <Duration>[_ms(500)]);
      await tester.pump(_ms(100));
      expect(log, <Duration>[_ms(500), _ms(550)]);
      // Back at full speed, the frame that brings the new scale already shows the unscaled clock.
      await tester.pumpWidget(kkHarness(build(true), motion: true));
      expect(log.last, _ms(1100));
    });

    testChecked('loops pause inside a disabled TickerMode', (WidgetTester tester) async {
      final List<int> phases = <int>[];
      await pumpKk(
        tester,
        TickerMode(
          enabled: false,
          child: KkPhaseBuilder(
            period: _ms(100),
            builder: (BuildContext context, int phase, Widget? child) {
              phases.add(phase);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
        motion: true,
      );
      final int builds = phases.length;
      for (int i = 0; i < 30; i++) {
        await tester.pump(_ms10);
      }
      expect(phases.length, builds);
    });

    /// A two-phase loop of 100ms and a gliding loop, with tickers on or off around them.
    Widget pausable(List<int> phases, List<Duration> painted, {required bool paused}) => TickerMode(
      enabled: !paused,
      child: KkRow(
        children: <Widget>[
          KkPhaseBuilder(
            period: _ms(100),
            builder: (BuildContext context, int phase, Widget? child) {
              phases.add(phase);
              return const SizedBox(width: 10, height: 10);
            },
          ),
          KkLoop(
            builder: (BuildContext context, ValueListenable<Duration> time) =>
                CustomPaint(size: const Size(10, 10), painter: _TimeLog(time, painted)),
          ),
        ],
      ),
    );

    testChecked('a paused loop stands still while its parent rebuilds', (WidgetTester tester) async {
      final List<int> phases = <int>[];
      final List<Duration> painted = <Duration>[];
      Widget build({required bool paused}) => kkHarness(pausable(phases, painted, paused: paused), motion: true);
      await pumpKk(tester, pausable(phases, painted, paused: false), motion: true);
      await tester.pump(_ms(70));
      expect(phases.last, 1);
      expect(painted.last, _ms(70));
      // Paused in the second half of a period. Time goes on, and every frame rebuilds the parent.
      await tester.pumpWidget(build(paused: true));
      phases.clear();
      painted.clear();
      for (int frame = 0; frame < 23; frame++) {
        await tester.pump(_ms10);
        await tester.pumpWidget(build(paused: true));
      }
      expect(kkFrameTime(), _ms(300));
      expect(phases, hasLength(23));
      expect(phases.toSet(), <int>{1}, reason: 'the phase it was paused in');
      expect(painted, isEmpty, reason: 'the gliding loop has not moved, so nothing was painted again');
      // Tickers are back: both loops are on the shared clock in that very frame, and stay on it.
      await tester.pumpWidget(build(paused: false));
      expect(phases.last, 0);
      expect(painted, <Duration>[_ms(300)]);
      await tester.pump(_ms(60));
      expect(phases.last, 1);
      expect(painted.last, _ms(360));
    });

    testChecked('a loop that is mounted paused rests until tickers come back', (WidgetTester tester) async {
      final List<int> phases = <int>[];
      final List<Duration> painted = <Duration>[];
      await pumpKk(tester, const SizedBox(width: 10, height: 10), motion: true);
      await tester.pump(_ms(1270));
      // 70ms into a period a running loop is in its second phase. This one has never run.
      final Widget paused = pausable(phases, painted, paused: true);
      await tester.pumpWidget(kkHarness(paused, motion: true));
      expect(phases, <int>[0]);
      expect(painted, <Duration>[Duration.zero]);
      for (int frame = 0; frame < 10; frame++) {
        await tester.pump(_ms10);
        await tester.pumpWidget(kkHarness(pausable(phases, painted, paused: true), motion: true));
      }
      expect(phases.toSet(), <int>{0});
      expect(painted, <Duration>[Duration.zero]);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'a paused loop asks for no frames');
      // Tickers come back above loops that are not rebuilt: the next frame puts them on the clock.
      final Widget loops = (pausable(phases, painted, paused: false) as TickerMode).child;
      await tester.pumpWidget(kkHarness(TickerMode(enabled: false, child: loops), motion: true));
      await tester.pump(_ms(100));
      phases.clear();
      painted.clear();
      await tester.pumpWidget(kkHarness(TickerMode(enabled: true, child: loops), motion: true));
      expect(phases, isEmpty, reason: 'nothing rebuilt the loops');
      await tester.pump(_ms10);
      expect(kkFrameTime(), _ms(1480));
      expect(phases, <int>[1]);
      expect(painted, <Duration>[_ms(1480)]);
    });

    testChecked('a paused KkPhaseBuilder takes a new count and period at the instant it was paused', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      Widget build({int period = 400, int phases = 4, bool paused = true}) => kkHarness(
        TickerMode(
          enabled: !paused,
          child: KkPhaseBuilder(
            period: _ms(period),
            phases: phases,
            builder: (BuildContext context, int phase, Widget? child) {
              calls.add('$phase/$phases');
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
        motion: true,
      );
      await tester.pumpWidget(build(paused: false));
      await tester.pump(_ms(350));
      expect(calls.last, '3/4');
      await tester.pumpWidget(build());
      await tester.pump(_ms(100));
      // The clock is at 450ms, where a running loop is back in its first phase. This one stands at 350ms.
      await tester.pumpWidget(build());
      expect(calls.last, '3/4');
      // Fewer phases: the index stays inside the new range, and it is the one of 350ms.
      await tester.pumpWidget(build(phases: 2));
      expect(calls.last, '1/2');
      await tester.pumpWidget(build(period: 1200, phases: 2));
      expect(calls.last, '0/2');
      await tester.pumpWidget(build(period: 500, phases: 5));
      expect(calls.last, '3/5');
      // Running again, it is where the clock is.
      await tester.pumpWidget(build(period: 500, phases: 5, paused: false));
      expect(calls.last, '4/5');
    });

    testChecked('a paused KkLoop takes a new time scale at the instant it was paused', (WidgetTester tester) async {
      final List<Duration> painted = <Duration>[];
      Widget build({double timeScale = 1, bool paused = true, bool enabled = true}) => kkHarness(
        TickerMode(
          enabled: !paused,
          child: KkLoop(
            enabled: enabled,
            builder: (BuildContext context, ValueListenable<Duration> time) =>
                CustomPaint(size: const Size(10, 10), painter: _TimeLog(time, painted)),
          ),
        ),
        motion: true,
        theme: KeikaiThemeData(motion: KkMotion(timeScale: timeScale)),
      );
      await tester.pumpWidget(build(paused: false));
      await tester.pump(_ms(600));
      expect(painted.last, _ms(600));
      await tester.pumpWidget(build());
      await tester.pump(_ms(400));
      painted.clear();
      // The clock is at 1s. The loop stands at 600ms, which is 300ms of a clock at half speed.
      await tester.pumpWidget(build(timeScale: 2));
      expect(painted, <Duration>[_ms(300)]);
      await tester.pump(_ms(100));
      await tester.pumpWidget(build(timeScale: 2));
      expect(painted, <Duration>[_ms(300)]);
      // Stopped, it is at rest, and started again under muted tickers it stays there.
      await tester.pumpWidget(build(timeScale: 2, enabled: false));
      expect(painted.last, Duration.zero);
      await tester.pumpWidget(build(timeScale: 2));
      await tester.pump(_ms(100));
      await tester.pumpWidget(build());
      expect(painted.last, Duration.zero);
      // Running again, it is where the clock is: 1.2s.
      await tester.pumpWidget(build(paused: false));
      expect(painted.last, _ms(1200));
    });
  });

  group('effects', () {
    testChecked('KkHazard: size, colours by level, static unless running', (WidgetTester tester) async {
      await pumpKk(tester, const KkHazard(key: ValueKey<String>('h'), width: 96, height: 32), motion: true);
      expect(tester.getSize(find.byKey(const ValueKey<String>('h'))), const Size(96, 32));
      await _settleRoute(tester);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'a hazard that is not running does not animate');
      // With no size it falls back to four stripes by two.
      await pumpKk(tester, const KkHazard(key: ValueKey<String>('h')), motion: true);
      expect(tester.getSize(find.byKey(const ValueKey<String>('h'))), const Size(48, 24));
      await pumpKk(
        tester,
        const SizedBox(width: 200, height: 10, child: KkHazard(key: ValueKey<String>('h'), pitch: 4)),
        motion: true,
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('h'))), const Size(200, 10));
    });

    testChecked('KkHazard paints the level colour over the ground', (WidgetTester tester) async {
      await pumpKk(tester, const KkHazard(width: 48, height: 24, level: KkLevel.critical));
      expect(
        find.byType(CustomPaint).last,
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 48, 24))
          ..rect(rect: const Rect.fromLTWH(0, 0, 48, 24), color: KkColors.standby.bg000)
          ..path(color: KkColors.standby.alert),
      );
      await pumpKk(tester, const KkHazard(width: 48, height: 24, background: Color(0x00000000)));
      expect(
        find.byType(CustomPaint).last,
        paints
          ..clipRect()
          ..path(color: KkColors.standby.signal),
      );
      await pumpKk(
        tester,
        const KkHazard(width: 48, height: 24, color: Color(0xFF00FF00)),
        condition: KkCondition.alert,
      );
      expect(
        find.byType(CustomPaint).last,
        paints
          ..clipRect()
          ..rect(color: KkColors.alertTheme.bg000)
          ..path(color: const Color(0xFF00FF00)),
      );
    });

    testChecked('a running KkHazard repaints every frame without rebuilding', (WidgetTester tester) async {
      await pumpKk(tester, const KkHazard(width: 96, height: 32, running: true), motion: true);
      final RenderObject paint = tester.renderObject(find.byType(CustomPaint).last);
      for (int i = 0; i < 100; i++) {
        await tester.pump(_ms10);
        expect(tester.binding.hasScheduledFrame, isTrue);
      }
      expect(tester.takeException(), isNull);
      expect(paint.attached, isTrue);
      // With motion off it is the static band.
      await pumpKk(tester, const KkHazard(width: 96, height: 32, running: true));
      await tester.pump(_ms(100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testChecked('a hazard that starts to run is in step with a running one from its first frame', (
      WidgetTester tester,
    ) async {
      // Where the painter of a hazard puts its stripes right now.
      Rect stripes(String key) {
        final CustomPaint paint = tester.widget<CustomPaint>(
          find.descendant(of: find.byKey(ValueKey<String>(key)), matching: find.byType(CustomPaint)),
        );
        final TestRecordingCanvas canvas = TestRecordingCanvas();
        paint.painter!.paint(canvas, const Size(96, 24));
        final RecordedInvocation draw = canvas.invocations.lastWhere(
          (RecordedInvocation call) => call.invocation.memberName == #drawPath,
        );
        return (draw.invocation.positionalArguments.first as Path).getBounds();
      }

      Widget build({required bool both}) => KkColumn(
        children: <Widget>[
          const KkHazard(key: ValueKey<String>('first'), width: 96, height: 24, running: true),
          if (both) const KkHazard(key: ValueKey<String>('second'), width: 96, height: 24, running: true),
        ],
      );
      await pumpKk(tester, build(both: false), motion: true);
      final Rect atRest = stripes('first');
      await tester.pump(_ms(1325));
      expect(stripes('first'), isNot(atRest), reason: 'the stripes have travelled');
      await tester.pumpWidget(kkHarness(build(both: true), motion: true));
      expect(stripes('second'), stripes('first'));
      await tester.pump(_ms(16));
      expect(stripes('second'), stripes('first'));
    });

    testChecked('KkMarquee scrolls its text and is announced once', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        const SizedBox(width: 300, child: KkMarquee('CRITICAL — COOLANT PRESSURE LOW')),
        motion: true,
      );
      expect(find.bySemanticsLabel('CRITICAL — COOLANT PRESSURE LOW'), findsOneWidget);
      for (int i = 0; i < 40; i++) {
        await tester.pump(_ms(50));
      }
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const SizedBox(width: 300, child: KkMarquee('', reverse: true)), motion: true);
      await tester.pump(_ms(50));
      await pumpKk(
        tester,
        SizedBox(width: 0, child: KkMarquee('X', reverse: true, gap: 0, period: _ms(10))),
        motion: true,
      );
      await tester.pump(_ms(50));
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testChecked('KkCrt draws over the child only when asked', (WidgetTester tester) async {
      const Widget child = SizedBox(key: ValueKey<String>('c'), width: 120, height: 80);
      await pumpKk(tester, const KkCrt(scanlines: false, child: child), motion: true);
      expect(
        find.ancestor(of: find.byKey(const ValueKey<String>('c')), matching: find.byType(CustomPaint)),
        findsNothing,
      );
      await pumpKk(tester, const KkCrt(child: child), motion: true);
      await _settleRoute(tester);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'scan lines alone are static');
      await pumpKk(tester, const KkCrt(sweep: true, noise: true, child: child), motion: true);
      for (int i = 0; i < 60; i++) {
        await tester.pump(_ms(100));
      }
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey<String>('c'))), const Size(120, 80));
      await pumpKk(tester, const KkCrt(sweep: true, noise: true, child: child));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testChecked('KkGlitch plays only when the trigger changes', (WidgetTester tester) async {
      Widget build(Object trigger, {bool flash = true}) => KkGlitch(
        trigger: trigger,
        flash: flash,
        child: const RepaintBoundary(child: SizedBox(key: ValueKey<String>('g'), width: 200, height: 100)),
      );
      RenderKkGlitch render() => tester.renderObject<RenderKkGlitch>(
        find.ancestor(of: find.byKey(const ValueKey<String>('g')), matching: find.byType(KkGlitch)).first,
      );
      await pumpKk(tester, build(0), motion: true);
      expect(render().progress.value, 1, reason: 'no glitch when first shown');
      await _settleRoute(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await pumpKk(tester, build(0), motion: true);
      expect(render().progress.value, 1);
      // Fire.
      await pumpKk(tester, build(1), motion: true);
      expect(render().progress.value, 0);
      expect(render().flashColor, KkColors.standby.alert);
      for (int ms = 0; ms < 700; ms += 20) {
        await tester.pump(_ms(20));
        expect(tester.takeException(), isNull);
      }
      expect(render().progress.value, 1);
      await tester.pump(_ms(50));
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Without the flash.
      await pumpKk(tester, build(2, flash: false), motion: true);
      expect(render().flashColor, isNull);
      await tester.pump(_ms(800));
      expect(render().progress.value, 1);
    });

    testChecked('KkGlitch paints three red flashes over 0.7s', (WidgetTester tester) async {
      Widget build(Object trigger) => KkGlitch(
        trigger: trigger,
        child: const SizedBox(key: ValueKey<String>('g'), width: 200, height: 100),
      );
      final Finder glitch = find.ancestor(of: find.byKey(const ValueKey<String>('g')), matching: find.byType(KkGlitch));
      await pumpKk(tester, build(0), motion: true);
      await pumpKk(tester, build(1), motion: true);
      int flashes = 0;
      bool wasOn = false;
      for (int ms = 0; ms <= 720; ms += 10) {
        final Matcher flash = (paints..rect(color: kkFade(KkColors.standby.alert, 0.6))) as Matcher;
        final bool on = flash.matches(glitch.first, <dynamic, dynamic>{});
        if (on && !wasOn) flashes++;
        wasOn = on;
        await tester.pump(_ms10);
      }
      expect(flashes, 3);
    });

    testChecked('KkGlitch does nothing with motion off', (WidgetTester tester) async {
      Widget build(Object trigger) => KkGlitch(trigger: trigger, child: const SizedBox(width: 20, height: 20));
      await pumpKk(tester, build(0));
      await pumpKk(tester, build(1));
      final RenderKkGlitch r = tester.renderObject<RenderKkGlitch>(find.byType(KkGlitch).last);
      expect(r.progress.value, 1);
      await tester.pumpAndSettle();
    });
  });
}
