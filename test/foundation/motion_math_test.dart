import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

void main() {
  group('KkSteps', () {
    test('holds each step and jumps at its end, like steps(n, end)', () {
      const KkSteps steps = KkSteps(4);
      expect(steps.transform(0), 0);
      expect(steps.transform(0.24), 0);
      expect(steps.transform(0.25), 0.25);
      expect(steps.transform(0.49), 0.25);
      expect(steps.transform(0.5), 0.5);
      expect(steps.transform(0.99), 0.75);
      expect(steps.transform(1), 1);
    });

    test('one step holds 0 until the very end', () {
      const KkSteps one = KkSteps(1);
      expect(one.transform(0.5), 0);
      expect(one.transform(0.999), 0);
      expect(one.transform(1), 1);
    });

    test('never eases: every output is a multiple of 1/n', () {
      for (final int n in <int>[2, 5, 6, 7, 9, 10, 12, 16]) {
        final KkSteps steps = KkSteps(n);
        for (int i = 0; i <= 1000; i++) {
          final double v = steps.transform(i / 1000);
          expect((v * n - (v * n).round()).abs(), lessThan(1e-9), reason: 'n=$n t=${i / 1000}');
          expect(v, lessThanOrEqualTo(i / 1000 + 1e-9));
        }
      }
    });

    test('equality and description', () {
      expect(const KkSteps(7), const KkSteps(7));
      expect(const KkSteps(7).hashCode, const KkSteps(7).hashCode);
      expect(const KkSteps(7) == const KkSteps(6), isFalse);
      expect(const KkSteps(7).toString(), 'KkSteps(7)');
      expect(() => KkSteps(0), throwsAssertionError);
    });
  });

  group('kkKeyframes', () {
    const List<double> stops = <double>[0, 0.5, 1];
    const List<double> values = <double>[0, 10, 0];

    test('interpolates linearly without steps', () {
      expect(kkKeyframes(0, stops, values), 0);
      expect(kkKeyframes(0.25, stops, values), 5);
      expect(kkKeyframes(0.5, stops, values), 10);
      expect(kkKeyframes(0.75, stops, values), 5);
      expect(kkKeyframes(1, stops, values), 0);
    });

    test('clamps outside the first and last stop', () {
      expect(kkKeyframes(-1, stops, values), 0);
      expect(kkKeyframes(2, stops, values), 0);
      expect(kkKeyframes(0.1, const <double>[0.2, 0.8], const <double>[3, 7]), 3);
      expect(kkKeyframes(0.9, const <double>[0.2, 0.8], const <double>[3, 7]), 7);
      expect(kkKeyframes(0.5, const <double>[0.2, 0.8], const <double>[3, 7]), closeTo(5, 1e-9));
    });

    test('applies the steps to each segment separately', () {
      // Five steps between 0 and 10 over the first half.
      expect(kkKeyframes(0.05, stops, values, steps: 5), 0);
      expect(kkKeyframes(0.1, stops, values, steps: 5), 2);
      expect(kkKeyframes(0.29, stops, values, steps: 5), 4);
      expect(kkKeyframes(0.49, stops, values, steps: 5), 8);
      // The second segment starts again from its own first value.
      expect(kkKeyframes(0.5, stops, values, steps: 5), 10);
      expect(kkKeyframes(0.59, stops, values, steps: 5), 10);
      expect(kkKeyframes(0.75, stops, values, steps: 5), 6);
      expect(kkKeyframes(0.99, stops, values, steps: 5), 2);
      expect(kkKeyframes(1, stops, values, steps: 5), 0);
    });

    test('one step per segment holds the segment start: a hard strobe', () {
      const List<double> s = <double>[0, 0.5, 1];
      const List<double> v = <double>[1, 0.2, 1];
      expect(kkKeyframes(0.0, s, v, steps: 1), 1);
      expect(kkKeyframes(0.49, s, v, steps: 1), 1);
      expect(kkKeyframes(0.5, s, v, steps: 1), 0.2);
      expect(kkKeyframes(0.99, s, v, steps: 1), 0.2);
      expect(kkKeyframes(1, s, v, steps: 1), 1);
    });

    test('two keyframes at the same position do not divide by zero', () {
      expect(kkKeyframes(0.5, const <double>[0, 0.5, 0.5, 1], const <double>[0, 1, 5, 6]), anyOf(1, 5));
      expect(kkKeyframes(0.75, const <double>[0, 0.5, 0.5, 1], const <double>[0, 1, 5, 6]), 5.5);
    });

    test('mismatched lists are rejected', () {
      expect(() => kkKeyframes(0, const <double>[0, 1], const <double>[0]), throwsAssertionError);
      expect(() => kkKeyframes(0, const <double>[0], const <double>[0]), throwsAssertionError);
    });
  });

  group('KkKeyframes', () {
    test('the flicker stutters 0, .9, .1, 1, .35, 1', () {
      const KkKeyframes f = KkKeyframes.flicker;
      expect(f.transform(0), 0);
      expect(f.transform(0.2), 0.9);
      expect(f.transform(0.3), closeTo(0.1, 1e-9));
      expect(f.transform(0.45), 1);
      expect(f.transform(0.55), closeTo(0.35, 1e-9));
      expect(f.transform(0.7), 1);
      expect(f.transform(0.85), 1);
      expect(f.transform(1), 1);
      for (int i = 0; i <= 200; i++) {
        final double v = f.transform(i / 200);
        expect(v, inInclusiveRange(0, 1));
      }
    });

    testWidgets('drives an animation', (WidgetTester tester) async {
      final AnimationController controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      final Animation<double> a = const KkKeyframes(<double>[0, 1], <double>[2, 4], steps: 2).animate(controller);
      expect(a.value, 2);
      controller.value = 0.49;
      expect(a.value, 2);
      controller.value = 0.5;
      expect(a.value, 3);
      controller.value = 1;
      expect(a.value, 4);
    });
  });

  group('loop clock', () {
    test('kkPhaseAt splits a period into equal phases', () {
      const Duration period = Duration(milliseconds: 1200);
      expect(kkPhaseAt(Duration.zero, period), 0);
      expect(kkPhaseAt(const Duration(milliseconds: 599), period), 0);
      expect(kkPhaseAt(const Duration(milliseconds: 600), period), 1);
      expect(kkPhaseAt(const Duration(milliseconds: 1199), period), 1);
      expect(kkPhaseAt(const Duration(milliseconds: 1200), period), 0);
      expect(kkPhaseAt(const Duration(milliseconds: 3000), period), 1);
      expect(kkPhaseAt(const Duration(milliseconds: 449), const Duration(milliseconds: 450), phases: 4), 3);
      expect(kkPhaseAt(const Duration(milliseconds: 113), const Duration(milliseconds: 450), phases: 4), 1);
      expect(kkPhaseAt(const Duration(seconds: 5), Duration.zero), 0);
      expect(kkPhaseAt(const Duration(seconds: 5), const Duration(seconds: 1), phases: 1), 0);
    });

    test('kkLoopAt is the position inside the period', () {
      const Duration period = Duration(milliseconds: 900);
      expect(kkLoopAt(Duration.zero, period), 0);
      expect(kkLoopAt(const Duration(milliseconds: 450), period), 0.5);
      expect(kkLoopAt(const Duration(milliseconds: 900), period), 0);
      expect(kkLoopAt(const Duration(milliseconds: 1125), period), 0.25);
      expect(kkLoopAt(const Duration(seconds: 3), Duration.zero), 0);
    });

    testWidgets('kkFrameTime is the frame timestamp and keeps its value between frames', (
      WidgetTester tester,
    ) async {
      kkFrameTime();
      await tester.pumpWidget(const SizedBox.shrink());
      final Duration t0 = kkFrameTime();
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 100));
      final Duration t1 = kkFrameTime();
      // Nothing sampled the clock during that frame, yet the value moved on.
      expect(t1 - t0, const Duration(milliseconds: 100));
      // No frame in between: the same value.
      expect(kkFrameTime(), t1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(kkFrameTime(), t1, reason: 'time passed but no frame was drawn');
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      expect(kkFrameTime() - t1, const Duration(milliseconds: 516));
      // Inside a frame it is that frame's own timestamp.
      Duration? inFrame;
      tester.binding.scheduleFrameCallback((Duration timeStamp) => inFrame = kkFrameTime() - timeStamp);
      await tester.pump(const Duration(milliseconds: 40));
      expect(inFrame, Duration.zero);
    });
  });

  group('KkMotion', () {
    test('the canonical timings of the language', () {
      expect(KkMotion.boot, const Duration(milliseconds: 420));
      expect(KkMotion.bootSteps, 7);
      expect(KkMotion.flicker, const Duration(milliseconds: 500));
      expect(KkMotion.headGrow, const Duration(milliseconds: 300));
      expect(KkMotion.headGrowSteps, 6);
      expect(KkMotion.scramble, const Duration(milliseconds: 460));
      expect(KkMotion.meter, const Duration(milliseconds: 450));
      expect(KkMotion.meterSteps, 9);
      expect(KkMotion.wipe, const Duration(milliseconds: 800));
      expect(KkMotion.wipeSteps, 16);
      expect(KkMotion.barGrow, const Duration(milliseconds: 500));
      expect(KkMotion.barGrowSteps, 10);
      expect(KkMotion.needle, const Duration(milliseconds: 700));
      expect(KkMotion.needleSteps, 12);
      expect(KkMotion.strobe, const Duration(milliseconds: 1200));
      expect(KkMotion.blink, const Duration(milliseconds: 1200));
      expect(KkMotion.colon, const Duration(seconds: 1));
      expect(KkMotion.hazard, const Duration(milliseconds: 900));
      expect(KkMotion.rowIn, const Duration(seconds: 1));
      expect(KkMotion.glitch, const Duration(milliseconds: 500));
      expect(KkMotion.flash, const Duration(milliseconds: 700));
      expect(KkMotion.sweep, const Duration(seconds: 4));
      expect(KkMotion.flow, const Duration(seconds: 1));
      expect(const KkMotion().staggerStep, const Duration(milliseconds: 60));
    });

    test('scaled, copyWith, equality', () {
      const KkMotion m = KkMotion();
      expect(m.enabled, isTrue);
      expect(m.scaled(KkMotion.boot), KkMotion.boot);
      expect(const KkMotion(timeScale: 2).scaled(KkMotion.boot), const Duration(milliseconds: 840));
      expect(const KkMotion(timeScale: 0.5).scaled(const Duration(milliseconds: 1)), const Duration(microseconds: 500));
      expect(KkMotion.off.enabled, isFalse);
      expect(m.copyWith(enabled: false), KkMotion.off);
      expect(m.copyWith(timeScale: 3).timeScale, 3);
      expect(m.copyWith(staggerStep: Duration.zero).staggerStep, Duration.zero);
      expect(m, const KkMotion());
      expect(m.hashCode, const KkMotion().hashCode);
      expect(m == const KkMotion(timeScale: 2), isFalse);
      expect(() => KkMotion(timeScale: 0), throwsAssertionError);
    });
  });
}
