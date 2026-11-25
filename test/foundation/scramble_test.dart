import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

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

    testWidgets('scrambles for 0.46s when first shown and settles on the value', (WidgetTester tester) async {
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

    testWidgets('the noise changes ten times, not every frame', (WidgetTester tester) async {
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

    testWidgets('scrambles again when the value changes', (WidgetTester tester) async {
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

    testWidgets('onMount false shows the value at once, but still scrambles on change', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('100', onMount: false), motion: true);
      expect(text(tester), '100');
      await pumpKk(tester, const KkScramble('200', onMount: false), motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(text(tester), '200');
    });

    testWidgets('with motion off it never scrambles', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('31337'));
      expect(text(tester), '31337');
      await pumpKk(tester, const KkScramble('40404'));
      expect(text(tester), '40404');
      await tester.pumpAndSettle();
    });

    testWidgets('enabled false never scrambles', (WidgetTester tester) async {
      await pumpKk(tester, const KkScramble('31337', enabled: false), motion: true);
      expect(text(tester), '31337');
    });

    testWidgets('reduced motion from the platform turns it off', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpKk(tester, const KkScramble('31337'), motion: true);
      expect(text(tester), '31337');
    });

    testWidgets('assistive technology always reads the real value', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkScramble('042.7'), motion: true);
      expect(find.bySemanticsLabel('042.7'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.bySemanticsLabel('042.7'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('takes a style and alignment, on one line', (WidgetTester tester) async {
      const TextStyle style = TextStyle(fontSize: 32);
      await pumpKk(tester, const KkScramble('7', style: style, textAlign: TextAlign.right));
      final Text t = tester.widget<Text>(shown());
      expect(t.style, style);
      expect(t.textAlign, TextAlign.right);
      expect(t.maxLines, 1);
      expect(t.softWrap, isFalse);
    });

    testWidgets('the time scale of the theme stretches it', (WidgetTester tester) async {
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
}
