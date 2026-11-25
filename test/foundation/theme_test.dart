import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// Captures what a descendant sees.
class _Seen {
  KeikaiThemeData? theme;
  TextStyle? text;
  bool? motion;
  int builds = 0;

  Widget probe() => Builder(
    builder: (BuildContext context) {
      theme = KeikaiTheme.of(context);
      text = DefaultTextStyle.of(context).style;
      motion = KeikaiTheme.motionOf(context);
      builds++;
      expect(context.kk, same(theme));
      return const SizedBox.shrink();
    },
  );
}

Widget _dir(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  group('KeikaiThemeData', () {
    test('defaults: standby, the two colour sets, bundled type, default metrics and motion', () {
      const KeikaiThemeData t = KeikaiThemeData();
      expect(t.condition, KkCondition.standby);
      expect(t.isAlert, isFalse);
      expect(t.standbyColors, KkColors.standby);
      expect(t.alertColors, KkColors.alertTheme);
      expect(t.colors, KkColors.standby);
      expect(t.type, const KkTypography());
      expect(t.metrics, const KkMetrics());
      expect(t.motion, const KkMotion());
    });

    test('the condition picks the colours', () {
      const KeikaiThemeData alert = KeikaiThemeData(condition: KkCondition.alert);
      expect(alert.colors, KkColors.alertTheme);
      expect(alert.isAlert, isTrue);
      final KkColors custom = KkColors.standby.copyWith(signal: const Color(0xFF00FF00));
      final KeikaiThemeData t = KeikaiThemeData(standbyColors: custom);
      expect(t.colors.signal, const Color(0xFF00FF00));
      expect(t.withCondition(KkCondition.alert).colors, KkColors.alertTheme);
      expect(t.withCondition(KkCondition.alert).standbyColors, custom);
    });

    test('withCondition returns the same object when nothing changes', () {
      const KeikaiThemeData t = KeikaiThemeData();
      expect(t.withCondition(KkCondition.standby), same(t));
      expect(t.withCondition(KkCondition.alert), isNot(same(t)));
      expect(t.withCondition(KkCondition.alert).withCondition(KkCondition.standby), t);
    });

    test('copyWith and equality', () {
      const KeikaiThemeData t = KeikaiThemeData();
      expect(t.copyWith(), t);
      expect(t.copyWith().hashCode, t.hashCode);
      expect(t.copyWith(condition: KkCondition.alert) == t, isFalse);
      expect(t.copyWith(motion: KkMotion.off).motion, KkMotion.off);
      expect(t.copyWith(metrics: const KkMetrics(rowUnit: 40)).metrics.rowUnit, 40);
      expect(t.copyWith(type: const KkTypography(scale: 2)).type.scale, 2);
      expect(t.copyWith(standbyColors: KkColors.alertTheme).colors, KkColors.alertTheme);
      expect(t.copyWith(alertColors: KkColors.standby).alertColors, KkColors.standby);
      expect(t.copyWith(metrics: const KkMetrics(rowUnit: 40)) == t, isFalse);
    });
  });

  group('KeikaiTheme', () {
    testWidgets('without a theme the default standby theme is used', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(_dir(seen.probe()));
      expect(seen.theme, const KeikaiThemeData());
      expect(seen.motion, isTrue);
    });

    testWidgets('provides its data and sets the body text style in ink', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      const KeikaiThemeData data = KeikaiThemeData(condition: KkCondition.alert);
      await tester.pumpWidget(_dir(KeikaiTheme(data: data, child: seen.probe())));
      expect(seen.theme, same(data));
      expect(seen.text!.fontFamily, 'packages/keikai/IBM Plex Sans KR');
      expect(seen.text!.fontSize, 14);
      expect(seen.text!.height, 1.55);
      expect(seen.text!.color, KkColors.alertTheme.ink);
    });

    testWidgets('dependents rebuild when the data changes, and only then', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      final Widget probe = seen.probe();
      await tester.pumpWidget(_dir(KeikaiTheme(data: const KeikaiThemeData(), child: probe)));
      expect(seen.builds, 1);
      // An equal theme: no rebuild.
      await tester.pumpWidget(_dir(KeikaiTheme(data: const KeikaiThemeData().copyWith(), child: probe)));
      expect(seen.builds, 1);
      await tester.pumpWidget(
        _dir(KeikaiTheme(data: const KeikaiThemeData(condition: KkCondition.alert), child: probe)),
      );
      expect(seen.builds, 2);
      expect(seen.theme!.isAlert, isTrue);
    });

    testWidgets('the nearest theme wins', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(
        _dir(
          KeikaiTheme(
            data: const KeikaiThemeData(),
            child: KeikaiTheme(
              data: const KeikaiThemeData(metrics: KkMetrics(rowUnit: 40)),
              child: seen.probe(),
            ),
          ),
        ),
      );
      expect(seen.theme!.metrics.rowUnit, 40);
    });

    testWidgets('motionOf: off when the theme says so or the platform asks for reduced motion', (
      WidgetTester tester,
    ) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(_dir(KeikaiTheme(data: const KeikaiThemeData(motion: KkMotion.off), child: seen.probe())));
      expect(seen.motion, isFalse);
      await tester.pumpWidget(
        _dir(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: KeikaiTheme(data: const KeikaiThemeData(), child: seen.probe()),
          ),
        ),
      );
      expect(seen.motion, isFalse);
      await tester.pumpWidget(
        _dir(
          MediaQuery(
            data: const MediaQueryData(),
            child: KeikaiTheme(data: const KeikaiThemeData(), child: seen.probe()),
          ),
        ),
      );
      expect(seen.motion, isTrue);
    });
  });

  group('KkConditionScope', () {
    testWidgets('turns one region red and leaves the rest alone', (WidgetTester tester) async {
      final _Seen outside = _Seen();
      final _Seen inside = _Seen();
      await tester.pumpWidget(
        _dir(
          KeikaiTheme(
            data: const KeikaiThemeData(metrics: KkMetrics(rowUnit: 40)),
            child: Column(
              children: <Widget>[
                outside.probe(),
                KkConditionScope(condition: KkCondition.alert, child: inside.probe()),
              ],
            ),
          ),
        ),
      );
      expect(outside.theme!.condition, KkCondition.standby);
      expect(outside.theme!.colors.signal, KkColors.standby.signal);
      expect(inside.theme!.condition, KkCondition.alert);
      expect(inside.theme!.colors.signal, KkColors.alertTheme.signal);
      expect(inside.text!.color, KkColors.alertTheme.ink);
      // Everything else is inherited.
      expect(inside.theme!.metrics.rowUnit, 40);
    });

    testWidgets('nested scopes: the inner one wins, and standby can be restored inside alert', (
      WidgetTester tester,
    ) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(
        _dir(
          KeikaiTheme(
            data: const KeikaiThemeData(condition: KkCondition.alert),
            child: KkConditionScope(condition: KkCondition.standby, child: seen.probe()),
          ),
        ),
      );
      expect(seen.theme!.condition, KkCondition.standby);
      expect(seen.text!.color, KkColors.standby.ink);
    });

    testWidgets('a scope with the condition already in force adds nothing', (WidgetTester tester) async {
      await tester.pumpWidget(
        _dir(
          const KeikaiTheme(
            data: KeikaiThemeData(),
            child: KkConditionScope(condition: KkCondition.standby, child: SizedBox.shrink()),
          ),
        ),
      );
      expect(find.byType(KeikaiTheme), findsOneWidget);
      await tester.pumpWidget(
        _dir(
          const KeikaiTheme(
            data: KeikaiThemeData(),
            child: KkConditionScope(condition: KkCondition.alert, child: SizedBox.shrink()),
          ),
        ),
      );
      expect(find.byType(KeikaiTheme), findsNWidgets(2));
    });

    testWidgets('works without a theme above it', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(_dir(KkConditionScope(condition: KkCondition.alert, child: seen.probe())));
      expect(seen.theme!.colors, KkColors.alertTheme);
    });
  });
}
