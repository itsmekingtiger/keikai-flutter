import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;

/// Captures what a descendant sees.
class _Seen {
  KeikaiThemeData? theme;
  DefaultTextStyle? defaults;
  TextStyle? text;
  bool? motion;
  int builds = 0;

  Widget probe() => Builder(
    builder: (BuildContext context) {
      theme = KeikaiTheme.of(context);
      defaults = DefaultTextStyle.of(context);
      text = defaults!.style;
      motion = KeikaiTheme.motionOf(context);
      builds++;
      expect(context.kk, same(theme));
      return const SizedBox.shrink();
    },
  );
}

Widget _dir(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

/// What happened to the State of a [_Kept].
class _Life {
  int inits = 0;
  int disposals = 0;
  KkCondition? condition;
}

/// A stateful leaf that reads the theme. Its State has to outlive every
/// switch of the condition above it.
class _Kept extends StatefulWidget {
  const _Kept(this.life);

  final _Life life;

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> {
  @override
  void initState() {
    super.initState();
    widget.life.inits++;
  }

  @override
  void dispose() {
    widget.life.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.life.condition = KeikaiTheme.of(context).condition;
    return const SizedBox.shrink();
  }
}

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
    testChecked('without a theme the default standby theme is used', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(_dir(seen.probe()));
      expect(seen.theme, const KeikaiThemeData());
      expect(seen.motion, isTrue);
    });

    testChecked('provides its data and sets the body text style in ink', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      const KeikaiThemeData data = KeikaiThemeData(condition: KkCondition.alert);
      await tester.pumpWidget(_dir(KeikaiTheme(data: data, child: seen.probe())));
      expect(seen.theme, same(data));
      expect(seen.text!.fontFamily, 'packages/keikai/IBM Plex Sans KR');
      expect(seen.text!.fontSize, 14);
      expect(seen.text!.height, 1.55);
      expect(seen.text!.color, KkColors.alertTheme.ink);
    });

    testChecked('dependents rebuild when the data changes, and only then', (WidgetTester tester) async {
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

    testChecked('the nearest theme wins', (WidgetTester tester) async {
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

    testChecked('motionOf: off when the theme says so or the platform asks for reduced motion', (
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
    testChecked('turns one region red and leaves the rest alone', (WidgetTester tester) async {
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

    testChecked('nested scopes: the inner one wins, and standby can be restored inside alert', (
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

    testChecked('a scope with the condition already in force hands the same theme down', (WidgetTester tester) async {
      final _Seen outside = _Seen();
      final _Seen inside = _Seen();
      const KeikaiThemeData data = KeikaiThemeData(metrics: KkMetrics(rowUnit: 40));
      await tester.pumpWidget(
        _dir(
          KeikaiTheme(
            data: data,
            child: Column(
              children: <Widget>[
                outside.probe(),
                KkConditionScope(condition: KkCondition.standby, child: inside.probe()),
              ],
            ),
          ),
        ),
      );
      expect(inside.theme, same(data));
      expect(inside.text!.color, KkColors.standby.ink);
      expect(inside.text, same(outside.text));
    });

    testChecked('switching the condition keeps the State of the region', (WidgetTester tester) async {
      final _Life life = _Life();
      Widget tree(KkCondition condition) => _dir(
        KeikaiTheme(
          data: const KeikaiThemeData(),
          child: KkConditionScope(condition: condition, child: _Kept(life)),
        ),
      );
      await tester.pumpWidget(tree(KkCondition.standby));
      final State<StatefulWidget> state = tester.state(find.byType(_Kept));
      for (final KkCondition condition in <KkCondition>[KkCondition.alert, KkCondition.standby, KkCondition.alert]) {
        await tester.pumpWidget(tree(condition));
        expect(tester.state(find.byType(_Kept)), same(state), reason: 'turning to $condition');
        // The region did follow the switch.
        expect(life.condition, condition);
      }
      expect(life.inits, 1);
      expect(life.disposals, 0);
    });

    testChecked('a pinned region keeps its State when the theme around it switches', (WidgetTester tester) async {
      final _Life life = _Life();
      Widget tree(KkCondition around) => _dir(
        KeikaiTheme(
          data: KeikaiThemeData(condition: around),
          child: KkConditionScope(condition: KkCondition.standby, child: _Kept(life)),
        ),
      );
      await tester.pumpWidget(tree(KkCondition.standby));
      final State<StatefulWidget> state = tester.state(find.byType(_Kept));
      for (final KkCondition around in <KkCondition>[KkCondition.alert, KkCondition.standby]) {
        await tester.pumpWidget(tree(around));
        expect(tester.state(find.byType(_Kept)), same(state), reason: 'the theme around turning to $around');
        expect(life.condition, KkCondition.standby);
      }
      expect(life.inits, 1);
      expect(life.disposals, 0);
    });

    testChecked('a scroll position in the region survives the turn to alert', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      Widget tree(KkCondition condition) => _dir(
        KeikaiTheme(
          data: const KeikaiThemeData(),
          child: KkConditionScope(
            condition: condition,
            child: KkScroll(controller: controller, child: const SizedBox(height: 4000)),
          ),
        ),
      );
      await tester.pumpWidget(tree(KkCondition.standby));
      controller.jumpTo(400);
      await tester.pump();
      await tester.pumpWidget(tree(KkCondition.alert));
      expect(controller.offset, 400);
    });

    testChecked('the default text style around it goes on inside, in either condition', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      const TextHeightBehavior heights = TextHeightBehavior(applyHeightToFirstAscent: false);
      Widget tree(KkCondition condition) => _dir(
        KeikaiTheme(
          data: const KeikaiThemeData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 30, fontFamily: 'packages/keikai/IBM Plex Mono'),
                textAlign: TextAlign.center,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textWidthBasis: TextWidthBasis.longestLine,
                textHeightBehavior: heights,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('ALARM', key: ValueKey<String>('outside')),
                    KkConditionScope(
                      condition: condition,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          seen.probe(),
                          const Text('ALARM', key: ValueKey<String>('inside')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (final KkCondition condition in KkCondition.values) {
        await tester.pumpWidget(tree(condition));
        final DefaultTextStyle inside = seen.defaults!;
        expect(inside.style.fontSize, 30, reason: '$condition');
        expect(inside.style.fontFamily, 'packages/keikai/IBM Plex Mono');
        expect(inside.style.height, 1.55);
        expect(inside.textAlign, TextAlign.center);
        expect(inside.softWrap, isFalse);
        expect(inside.overflow, TextOverflow.ellipsis);
        expect(inside.maxLines, 1);
        expect(inside.textWidthBasis, TextWidthBasis.longestLine);
        expect(inside.textHeightBehavior, heights);
        // The text is laid out as it is outside the region.
        expect(
          tester.getSize(find.byKey(const ValueKey<String>('inside'))),
          tester.getSize(find.byKey(const ValueKey<String>('outside'))),
          reason: '$condition',
        );
        // Only the ink follows the condition.
        final KkColors colors = condition == KkCondition.alert ? KkColors.alertTheme : KkColors.standby;
        expect(inside.style.color, colors.ink);
      }
    });

    testChecked('a text colour chosen by an ancestor is kept', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(
        _dir(
          KeikaiTheme(
            data: const KeikaiThemeData(),
            child: KkInk(
              color: KkColors.standby.inkDim,
              child: KkConditionScope(condition: KkCondition.alert, child: seen.probe()),
            ),
          ),
        ),
      );
      expect(seen.theme!.colors, KkColors.alertTheme);
      expect(seen.text!.color, KkColors.standby.inkDim);
      expect(seen.text!.fontSize, 14);
    });

    testChecked('works without a theme above it', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      await tester.pumpWidget(_dir(KkConditionScope(condition: KkCondition.alert, child: seen.probe())));
      expect(seen.theme!.colors, KkColors.alertTheme);
    });

    testChecked('with no default text style above it sets none, in either condition', (WidgetTester tester) async {
      final _Seen seen = _Seen();
      for (final KkCondition condition in KkCondition.values) {
        await tester.pumpWidget(_dir(KkConditionScope(condition: condition, child: seen.probe())));
        expect(seen.theme!.condition, condition);
        expect(seen.text, const TextStyle(), reason: '$condition');
      }
    });
  });
}
