import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

void main() {
  group('kkScrambleText', () {
    test('settled text is the target', () {
      expect(kkScrambleText('042.7', 1), '042.7');
      expect(kkScrambleText('042.7', 1.5), '042.7');
      expect(kkScrambleText('', 0), '');
      expect(kkScrambleText('', 1), '');
    });

    test('only digits churn; everything else stays in place', () {
      const String target = '14:02:31.004Z  SEC-04  042.7 °C  0x3F';
      for (int step = 0; step < 10; step++) {
        final String s = kkScrambleText(target, 0, step: step);
        expect(s.length, target.length);
        for (int i = 0; i < target.length; i++) {
          if (_isDigit(target[i])) {
            expect(_isDigit(s[i]), isTrue, reason: 'position $i at step $step');
          } else {
            expect(s[i], target[i], reason: 'position $i at step $step');
          }
        }
      }
    });

    test('is a pure function of step, position and seed', () {
      const String target = '0123456789';
      expect(kkScrambleText(target, 0.3, step: 3, seed: 7), kkScrambleText(target, 0.3, step: 3, seed: 7));
      // Different steps and seeds give different noise.
      final Set<String> frames = <String>{for (int step = 0; step < 10; step++) kkScrambleText(target, 0, step: step)};
      expect(frames.length, greaterThan(7));
      final Set<String> seeds = <String>{for (int seed = 0; seed < 10; seed++) kkScrambleText(target, 0, seed: seed)};
      expect(seeds.length, greaterThan(7));
    });

    test('the noise is spread over all ten digits', () {
      final Set<String> seen = <String>{};
      for (int step = 0; step < 40; step++) {
        seen.addAll(kkScrambleText('0000000000', 0, step: step).split(''));
      }
      expect(seen, hasLength(10));
    });

    test('settles from the front', () {
      const String target = '98.7654';
      // Six digits: at progress p the first floor(6p) digits are final.
      for (int settled = 0; settled <= 6; settled++) {
        for (int step = 0; step < 8; step++) {
          final String s = kkScrambleText(target, settled / 6 + 1e-9, step: step, seed: 3);
          final List<String> got = s.split('').where(_isDigit).toList();
          final List<String> want = target.split('').where(_isDigit).toList();
          expect(got.sublist(0, settled), want.sublist(0, settled), reason: 'settled=$settled step=$step');
          expect(s[2], '.');
        }
      }
      // Halfway, something behind the settled front is still churning.
      final Set<String> tails = <String>{
        for (int step = 0; step < 10; step++) kkScrambleText(target, 0.5, step: step).substring(4),
      };
      expect(tails.length, greaterThan(1));
    });

    test('a digit settles exactly when its share of the progress is reached, whatever the rounding', () {
      // 15/22 x 22 is a hair under 15 in floating point; a plain floor would leave the fifteenth digit churning.
      expect(15 / 22 * 22, lessThan(15));
      for (int digits = 1; digits <= 40; digits++) {
        final String target = '7' * digits;
        for (int settled = 0; settled < digits; settled++) {
          // The digits that hold the target on every noise step are the settled ones.
          int held = digits;
          for (int step = 0; step < 24; step++) {
            final String s = kkScrambleText(target, settled / digits, step: step, seed: 9);
            int same = 0;
            while (same < digits && s[same] == '7') {
              same++;
            }
            if (same < held) held = same;
          }
          expect(held, settled, reason: '$settled of $digits');
        }
      }
    });

    test('negative progress is treated as zero', () {
      expect(kkScrambleText('123', -2, step: 4), kkScrambleText('123', 0, step: 4));
    });

    test('text with no digits is returned untouched', () {
      expect(kkScrambleText('NOMINAL 正常', 0), 'NOMINAL 正常');
      expect(kkScrambleText('—', 0.2), '—');
    });

    test('letters churn only when asked, and keep their case', () {
      const String target = 'Sec-04 ok';
      expect(kkScrambleText(target, 0, step: 2).replaceAll(RegExp('[0-9]'), '#'), 'Sec-## ok');
      for (int step = 0; step < 10; step++) {
        final String s = kkScrambleText(target, 0, step: step, letters: true);
        expect(s.length, target.length);
        expect(s[0], matches(RegExp('[A-Z]')));
        expect(s[1], matches(RegExp('[a-z]')));
        expect(s[3], '-');
        expect(s[4], matches(RegExp('[0-9]')));
        expect(s[6], ' ');
        expect(s[7], matches(RegExp('[a-z]')));
      }
    });
  });

  group('KkScramble', () {
    Finder shown() => find.byType(Text);
    String text(WidgetTester tester) => tester.widget<Text>(shown()).data!;

    testChecked('scrambles for 0.46s when first shown and settles on the value', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('042.7'), motion: true);
      final Set<String> frames = <String>{};
      for (int ms = 0; ms < 460; ms += 20) {
        final String s = text(tester);
        expect(s.length, 5);
        expect(s[3], '.');
        frames.add(s);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(frames.length, greaterThan(4));
      await tester.pump(const Duration(milliseconds: 40));
      expect(text(tester), '042.7');
      // And it stays there.
      await tester.pump(const Duration(seconds: 1));
      expect(text(tester), '042.7');
    });

    testChecked('the noise changes ten times, not every frame', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('0000000000'), motion: true);
      final List<String> frames = <String>[];
      for (int ms = 0; ms <= 460; ms += 2) {
        final String s = text(tester);
        if (frames.isEmpty || frames.last != s) frames.add(s);
        await tester.pump(const Duration(milliseconds: 2));
      }
      // Ten noise steps and the settled value.
      expect(frames.length, inInclusiveRange(9, 11));
      expect(frames.last, '0000000000');
    });

    testChecked('a frame that lands on a step edge shows the new noise step', (WidgetTester tester) async {
      // 0.46s in ten steps: with a frame every 46ms each frame is exactly on an edge.
      await pumpKk(tester, KkScramble('0' * 30), motion: true);
      final List<String> frames = <String>[];
      for (int step = 0; step < 10; step++) {
        final String s = text(tester);
        // Three more digits are final at every step.
        expect(s.substring(0, step * 3), '0' * (step * 3), reason: 'step $step');
        expect(s.substring(step * 3), isNot('0' * (30 - step * 3)), reason: 'step $step');
        frames.add(s.substring(27));
        await tester.pump(const Duration(milliseconds: 46));
      }
      // The last three digits churn to the end: ten steps, ten different noise frames.
      expect(frames.toSet(), hasLength(10));
      expect(text(tester), '0' * 30);
    });

    testChecked('values of the same length do not churn in unison', (WidgetTester tester) async {
      List<String> texts() => tester.widgetList<Text>(shown()).map((Text t) => t.data!).toList();
      await pumpKk(
        tester,
        const KkColumn(
          children: <Widget>[KkScramble('042.7'), KkScramble('078.3'), KkScramble('113.9'), KkScramble('256.0')],
        ),
        motion: true,
      );
      // Nothing has settled in the first noise frame: four readouts show four different numbers.
      expect(texts().toSet(), hasLength(4));
      for (int ms = 0; ms < 460; ms += 23) {
        expect(texts().toSet().length, greaterThan(1), reason: 'at ${ms}ms');
        await tester.pump(const Duration(milliseconds: 23));
      }
      await tester.pump(const Duration(milliseconds: 23));
      expect(texts(), <String>['042.7', '078.3', '113.9', '256.0']);
    });

    testChecked('the same value churns its own way in each cell of a grid', (WidgetTester tester) async {
      List<String> texts() => tester.widgetList<Text>(shown()).map((Text t) => t.data!).toList();
      await pumpKk(
        tester,
        const KkColumn(
          children: <Widget>[
            KkStagger(index: 0, child: KkScramble('0000000000', duration: Duration(seconds: 1))),
            KkStagger(index: 1, child: KkScramble('0000000000', duration: Duration(seconds: 1))),
            KkStagger(index: 1, child: KkScramble('0000000000', duration: Duration(seconds: 1))),
          ],
        ),
        motion: true,
      );
      for (int step = 0; step < 5; step++) {
        final List<String> now = texts();
        expect(now[0], isNot(now[1]), reason: 'step $step');
        // The noise stays a pure function of the value and its place: same cell, same digits.
        expect(now[1], now[2], reason: 'step $step');
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testChecked('the same value in the same place always churns the same way', (WidgetTester tester) async {
      final List<List<String>> runs = <List<String>>[];
      for (int run = 0; run < 2; run++) {
        final List<String> frames = <String>[];
        await pumpKk(tester, KkScramble('31337', key: ValueKey<int>(run)), motion: true);
        for (int ms = 0; ms < 460; ms += 46) {
          frames.add(text(tester));
          await tester.pump(const Duration(milliseconds: 46));
        }
        runs.add(frames);
      }
      expect(runs[0], runs[1]);
      expect(runs[0].toSet().length, greaterThan(4));
    });

    test('the step count must be positive', () {
      expect(() => KkScramble('31337', steps: 0), throwsAssertionError);
      expect(() => KkScramble('31337', steps: -3), throwsAssertionError);
      expect(const KkScramble('31337', steps: 1).steps, 1);
    });

    testChecked('the last frame is the value, whatever the step count and the frame times', (
      WidgetTester tester,
    ) async {
      for (final int steps in <int>[1, 2, 3, 7, 10, 23]) {
        for (final int frame in <int>[1, 7, 16, 46, 460]) {
          await pumpKk(tester, KkScramble('31337', key: ValueKey<String>('$steps/$frame'), steps: steps), motion: true);
          expect(text(tester), isNot('31337'), reason: 'steps $steps');
          for (int ms = 0; ms < 460; ms += frame) {
            await tester.pump(Duration(milliseconds: frame));
          }
          expect(text(tester), '31337', reason: 'steps $steps, ${frame}ms frames');
        }
      }
    });

    testChecked('scrambles again when the value changes', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('100'), motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(text(tester), '100');
      await pumpKk(tester, const KkScramble('999'), motion: true);
      bool churned = false;
      for (int i = 0; i < 20; i++) {
        if (text(tester) != '999') churned = true;
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(churned, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(text(tester), '999');
    });

    testChecked('onMount false shows the value at once, but still scrambles on change', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('100', onMount: false), motion: true);
      expect(text(tester), '100');
      await pumpKk(tester, const KkScramble('200', onMount: false), motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(text(tester), '200');
    });

    testChecked('with motion off it never scrambles', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('31337'));
      expect(text(tester), '31337');
      await pumpKk(tester, const KkScramble('40404'));
      expect(text(tester), '40404');
      await tester.pumpAndSettle();
    });

    testChecked('enabled false never scrambles', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('31337', enabled: false), motion: true);
      expect(text(tester), '31337');
    });

    testChecked('reduced motion from the platform turns it off', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpKk(tester, const KkScramble('31337'), motion: true);
      expect(text(tester), '31337');
    });

    testChecked('reduced motion that arrives mid-scramble shows the value at once', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('0000000000', duration: Duration(seconds: 2)), motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(text(tester), isNot('0000000000'));
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(text(tester), '0000000000');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the scramble has stopped');
      // Motion coming back does not replay what was cut short.
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(text(tester), '0000000000');
    });

    testChecked('motion switched off by the theme, or enabled false, ends a scramble in flight', (
      WidgetTester tester,
    ) async {
      const Duration slow = Duration(seconds: 2);
      await pumpKk(tester, const KkScramble('0000000000', duration: slow), motion: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(text(tester), isNot('0000000000'));
      await pumpKk(tester, const KkScramble('0000000000', duration: slow));
      expect(text(tester), '0000000000');
      await tester.pumpAndSettle();

      await pumpKk(tester, const KkScramble('1111111111', duration: slow), motion: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(text(tester), isNot('1111111111'));
      await pumpKk(tester, const KkScramble('1111111111', duration: slow, enabled: false), motion: true);
      expect(text(tester), '1111111111');
      await tester.pump(const Duration(milliseconds: 250));
      expect(text(tester), '1111111111');
      // Enabled again, it waits for the next change of value.
      await pumpKk(tester, const KkScramble('1111111111', duration: slow), motion: true);
      expect(text(tester), '1111111111');
    });

    testChecked('assistive technology always reads the real value', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkScramble('042.7'), motion: true);
      expect(find.bySemanticsLabel('042.7'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.bySemanticsLabel('042.7'), findsOneWidget);
      handle.dispose();
    });

    testChecked('takes a style and alignment, on one line', (WidgetTester tester) async {
      const TextStyle style = TextStyle(fontSize: 32);
      await pumpKk(tester, const KkScramble('7', style: style, textAlign: TextAlign.right));
      final Text t = tester.widget<Text>(shown());
      expect(t.style, style);
      expect(t.textAlign, TextAlign.right);
      expect(t.maxLines, 1);
      expect(t.softWrap, isFalse);
    });

    testChecked('the time scale of the theme stretches it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkScramble('0000000000'),
        motion: true,
        theme: const KeikaiThemeData(motion: KkMotion(timeScale: 2)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(text(tester), isNot('0000000000'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(text(tester), '0000000000');
    });
  });

  group('KkScramble.builder', () {
    /// A builder form of [value] that records every text it is handed.
    Widget probe(
      String value,
      List<String> log, {
      Duration duration = KkMotion.scramble,
      int steps = 10,
      bool onMount = true,
      bool letters = false,
      bool enabled = true,
    }) {
      return KkScramble.builder(
        value,
        duration: duration,
        steps: steps,
        onMount: onMount,
        letters: letters,
        enabled: enabled,
        builder: (BuildContext context, String shown) {
          log.add(shown);
          return const SizedBox(width: 10, height: 10);
        },
      );
    }

    testChecked('hands its builder what the text form shows, frame for frame', (WidgetTester tester) async {
      final List<String> built = <String>[];
      Widget build(String value) => KkColumn(children: <Widget>[KkScramble(value), probe(value, built)]);
      String text() => tester.widget<Text>(find.byType(Text)).data!;

      await pumpKk(tester, build('042.7 °C'), motion: true);
      expect(find.byType(Text), findsOneWidget, reason: 'the builder form lays out no text of its own');
      expect(built.last, isNot('042.7 °C'));
      final Set<String> frames = <String>{};
      for (int ms = 0; ms < 460; ms += 23) {
        expect(built.last, text(), reason: 'at ${ms}ms');
        expect(built.last, matches(RegExp(r'^\d\d\d\.\d °C$')), reason: 'at ${ms}ms');
        frames.add(built.last);
        await tester.pump(const Duration(milliseconds: 23));
      }
      expect(frames.length, greaterThan(4));
      // It is built once for each of the ten noise steps and once for the value.
      expect(built, hasLength(11));
      expect(built.last, '042.7 °C');
      expect(text(), '042.7 °C');

      // A new value churns both again, still alike.
      await tester.pumpWidget(kkHarness(build('113.9 °C'), motion: true));
      expect(built.last, isNot('113.9 °C'));
      for (int ms = 0; ms < 460; ms += 46) {
        expect(built.last, text(), reason: 'at ${ms}ms');
        await tester.pump(const Duration(milliseconds: 46));
      }
      expect(built.last, '113.9 °C');
      expect(text(), '113.9 °C');
    });

    testChecked('takes the same switches as the text form', (WidgetTester tester) async {
      final List<String> built = <String>[];
      await pumpKk(tester, probe('SEC-04', built, letters: true), motion: true);
      expect(built.last, matches(RegExp(r'^[A-Z]{3}-\d\d$')));
      expect(built.last.substring(0, 3), isNot('SEC'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(built.last, 'SEC-04');

      // Not when first shown, only on change.
      Widget keyed(int key, Widget child) => KeyedSubtree(key: ValueKey<int>(key), child: child);
      built.clear();
      await pumpKk(tester, keyed(1, probe('100', built, onMount: false)), motion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(built.toSet(), <String>{'100'});
      await pumpKk(tester, keyed(1, probe('200', built, onMount: false)), motion: true);
      expect(built.last, isNot('200'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(built.last, '200');

      // Never with motion off, nor when disabled.
      built.clear();
      await pumpKk(tester, keyed(2, probe('31337', built)));
      await pumpKk(tester, keyed(2, probe('40404', built)));
      await tester.pumpAndSettle();
      expect(built.toSet(), <String>{'31337', '40404'});
      built.clear();
      await pumpKk(tester, keyed(3, probe('31337', built, enabled: false)), motion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(built.toSet(), <String>{'31337'});

      expect(() => probe('31337', built, steps: 0), throwsAssertionError);
    });

    testChecked('reduced motion that arrives mid-scramble hands over the value at once', (WidgetTester tester) async {
      final List<String> built = <String>[];
      await pumpKk(tester, probe('0000000000', built, duration: const Duration(seconds: 2)), motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(built.last, isNot('0000000000'));
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump();
      expect(built.last, '0000000000');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the scramble has stopped');
    });
  });
}
