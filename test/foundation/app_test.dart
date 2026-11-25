import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// A page that shows [label].
class _Page extends StatelessWidget {
  const _Page(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

BuildContext _contextOf(WidgetTester tester, String label) => tester.element(find.text(label));

RenderKkGlitch _rootGlitch(WidgetTester tester) => tester.renderObject<RenderKkGlitch>(find.byType(KkGlitch).first);

void main() {
  group('KeikaiApp', () {
    testChecked('shows its home with everything a page needs around it', (WidgetTester tester) async {
      await _size(tester, const Size(800, 600));
      await tester.pumpWidget(const KeikaiApp(title: 'HQ', home: _Page('home')));
      expect(find.text('home'), findsOneWidget);
      final BuildContext context = _contextOf(tester, 'home');
      expect(KeikaiTheme.of(context), const KeikaiThemeData());
      expect(Directionality.of(context), TextDirection.ltr);
      expect(MediaQuery.sizeOf(context), const Size(800, 600));
      expect(Navigator.maybeOf(context), isNotNull);
      expect(Overlay.maybeOf(context), isNotNull);
      expect(ScrollConfiguration.of(context), isA<KkScrollBehavior>());
      final DefaultTextStyle text = DefaultTextStyle.of(context);
      expect(text.style.fontFamily, 'packages/keikai/IBM Plex Sans KR');
      expect(text.style.color, KkColors.standby.ink);
      final DefaultSelectionStyle selection = DefaultSelectionStyle.of(context);
      expect(selection.cursorColor, KkColors.standby.signal);
      expect(selection.selectionColor, KkColors.standby.signalDim);
      expect(KeikaiApp.conditionOf(context), KkCondition.standby);
      expect(ModalRoute.of(context), isA<KkPageRoute<dynamic>>());
      expect(find.byType(CheckedModeBanner), findsNothing);
    });

    testChecked('paints the screen ground behind every page', (WidgetTester tester) async {
      await _size(tester, const Size(300, 200));
      await tester.pumpWidget(const KeikaiApp(home: SizedBox.shrink()));
      expect(
        find.byType(KeikaiApp),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 300, 200), color: KkColors.standby.bg000),
      );
      await tester.pumpWidget(const KeikaiApp(condition: KkCondition.alert, home: SizedBox.shrink()));
      expect(
        find.byType(KeikaiApp),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 300, 200), color: KkColors.alertTheme.bg000),
      );
    });

    testChecked('named routes, push and pop', (WidgetTester tester) async {
      await tester.pumpWidget(
        KeikaiApp(
          theme: const KeikaiThemeData(motion: KkMotion.off),
          routes: <String, WidgetBuilder>{
            '/': (BuildContext context) => const _Page('home'),
            '/log': (BuildContext context) => const _Page('log'),
          },
        ),
      );
      expect(find.text('home'), findsOneWidget);
      final NavigatorState navigator = Navigator.of(_contextOf(tester, 'home'));
      navigator.pushNamed('/log');
      await tester.pump();
      await tester.pump();
      expect(find.text('log'), findsOneWidget);
      expect(find.text('home'), findsNothing, reason: 'pages are opaque');
      expect(ModalRoute.of(_contextOf(tester, 'log')), isA<KkPageRoute<dynamic>>());
      navigator.pop();
      await tester.pump();
      await tester.pump();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('log'), findsNothing);
      await tester.pumpAndSettle();
    });

    testChecked('initialRoute, onGenerateRoute and onUnknownRoute', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        KeikaiApp(
          theme: const KeikaiThemeData(motion: KkMotion.off),
          navigatorKey: key,
          initialRoute: '/sector/04',
          onGenerateRoute: (RouteSettings settings) {
            final String name = settings.name ?? '';
            if (name == '/') return KkPageRoute<void>(settings: settings, builder: (_) => const _Page('root'));
            if (name.startsWith('/sector/')) {
              return KkPageRoute<void>(
                settings: settings,
                builder: (_) => _Page('SEC-${name.substring(8)}'),
              );
            }
            return null;
          },
          onUnknownRoute: (RouteSettings settings) =>
              KkPageRoute<void>(settings: settings, builder: (_) => const _Page('unknown')),
        ),
      );
      await tester.pump();
      expect(find.text('SEC-04'), findsOneWidget);
      key.currentState!.pushNamed('/nowhere');
      await tester.pump();
      await tester.pump();
      expect(find.text('unknown'), findsOneWidget);
    });

    testChecked('a pushed page wipes in from the left in 7 steps and wipes out again', (WidgetTester tester) async {
      await _size(tester, const Size(700, 400));
      await tester.pumpWidget(const KeikaiApp(home: _Page('home')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 20));
      final NavigatorState navigator = Navigator.of(_contextOf(tester, 'home'));
      navigator.push(KkPageRoute<void>(builder: (_) => const _Page('detail')));
      await tester.pump();
      await tester.pump();
      Rect clip() {
        final ClipRect c = tester.widget<ClipRect>(
          find.ancestor(of: find.text('detail'), matching: find.byType(ClipRect)).first,
        );
        return c.clipper!.getClip(const Size(700, 400));
      }

      expect(clip().width, 0);
      // Both pages are alive during the wipe.
      expect(find.text('home'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      expect(clip().width, 0);
      for (int step = 1; step <= 6; step++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(clip().width, closeTo(100.0 * step, 1e-6), reason: 'step $step');
      }
      await tester.pump(const Duration(milliseconds: 60));
      expect(clip().width, 700);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('home'), findsNothing);
      // Back: the page shrinks away in the same steps.
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(clip().width, closeTo(500, 1e-6));
      expect(find.text('home'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('detail'), findsNothing);
    });

    testChecked('with motion off pages change at once', (WidgetTester tester) async {
      await tester.pumpWidget(
        const KeikaiApp(theme: KeikaiThemeData(motion: KkMotion.off), home: _Page('home')),
      );
      final NavigatorState navigator = Navigator.of(_contextOf(tester, 'home'));
      final KkPageRoute<void> route = KkPageRoute<void>(builder: (_) => const _Page('detail'));
      navigator.push(route);
      await tester.pump();
      expect(route.transitionDuration, Duration.zero);
      await tester.pump();
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(find.ancestor(of: find.text('detail'), matching: find.byType(ClipRect)), findsNothing);
      await tester.pumpAndSettle();
    });

    testChecked('a route can opt out of the wipe, and returns a result', (WidgetTester tester) async {
      await tester.pumpWidget(const KeikaiApp(home: _Page('home')));
      await tester.pump(const Duration(milliseconds: 500));
      final NavigatorState navigator = Navigator.of(_contextOf(tester, 'home'));
      final KkPageRoute<String> route = KkPageRoute<String>(
        wipe: false,
        fullscreenDialog: true,
        maintainState: false,
        settings: const RouteSettings(name: '/confirm'),
        builder: (_) => const _Page('confirm'),
      );
      final Future<String?> result = navigator.push(route);
      await tester.pump();
      await tester.pump();
      expect(route.transitionDuration, Duration.zero);
      expect(route.fullscreenDialog, isTrue);
      expect(route.maintainState, isFalse);
      expect(route.opaque, isTrue);
      expect(route.barrierColor, isNull);
      expect(route.barrierLabel, isNull);
      expect(find.text('confirm'), findsOneWidget);
      navigator.pop('ACK');
      await tester.pump();
      await tester.pump();
      expect(await result, 'ACK');
    });

    testChecked('builder wraps the navigator inside the theme', (WidgetTester tester) async {
      KeikaiThemeData? seen;
      await tester.pumpWidget(
        KeikaiApp(
          theme: const KeikaiThemeData(metrics: KkMetrics(rowUnit: 40)),
          home: const _Page('home'),
          builder: (BuildContext context, Widget? child) {
            seen = KeikaiTheme.of(context);
            return KkColumn(
              children: <Widget>[
                const SizedBox(key: ValueKey<String>('chrome'), height: 20),
                KkExpanded(child: child!),
              ],
            );
          },
        ),
      );
      expect(seen!.metrics.rowUnit, 40);
      expect(find.byKey(const ValueKey<String>('chrome')), findsOneWidget);
      expect(tester.getTopLeft(find.text('home')).dy, 20);
    });

    testChecked('builder alone, with no navigator', (WidgetTester tester) async {
      await tester.pumpWidget(
        KeikaiApp(builder: (BuildContext context, Widget? child) => const _Page('bare')),
      );
      expect(find.text('bare'), findsOneWidget);
      expect(Navigator.maybeOf(_contextOf(tester, 'bare')), isNull);
    });
  });

  group('condition', () {
    testChecked('setCondition switches the whole app; conditionOf reads it', (WidgetTester tester) async {
      await tester.pumpWidget(
        const KeikaiApp(theme: KeikaiThemeData(motion: KkMotion.off), home: _Page('home')),
      );
      BuildContext context = _contextOf(tester, 'home');
      expect(KeikaiApp.conditionOf(context), KkCondition.standby);
      KeikaiApp.setCondition(context, KkCondition.alert);
      await tester.pump();
      context = _contextOf(tester, 'home');
      expect(KeikaiApp.conditionOf(context), KkCondition.alert);
      expect(KeikaiTheme.of(context).colors, KkColors.alertTheme);
      expect(DefaultTextStyle.of(context).style.color, KkColors.alertTheme.ink);
      expect(DefaultSelectionStyle.of(context).cursorColor, KkColors.alertTheme.signal);
      KeikaiApp.setCondition(context, KkCondition.standby);
      await tester.pump();
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'home')), KkCondition.standby);
      // Setting the same condition again is harmless.
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.standby);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testChecked('the app starts in the condition of its theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        const KeikaiApp(theme: KeikaiThemeData(condition: KkCondition.alert), home: _Page('home')),
      );
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'home')), KkCondition.alert);
    });

    testChecked('a controlled condition ignores setCondition and follows the widget', (WidgetTester tester) async {
      Widget app(KkCondition condition) => KeikaiApp(
        theme: const KeikaiThemeData(motion: KkMotion.off),
        condition: condition,
        home: const _Page('home'),
      );
      await tester.pumpWidget(app(KkCondition.standby));
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.alert);
      await tester.pump();
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'home')), KkCondition.standby);
      await tester.pumpWidget(app(KkCondition.alert));
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'home')), KkCondition.alert);
      await tester.pumpWidget(app(KkCondition.standby));
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'home')), KkCondition.standby);
    });

    testChecked('setCondition outside an app does nothing', (WidgetTester tester) async {
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: _Page('lone')));
      KeikaiApp.setCondition(_contextOf(tester, 'lone'), KkCondition.alert);
      await tester.pump();
      expect(KeikaiApp.conditionOf(_contextOf(tester, 'lone')), KkCondition.standby);
    });

    testChecked('turning to alert glitches the screen and flashes red; returning to standby does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const KeikaiApp(home: _Page('home')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_rootGlitch(tester).progress.value, 1);
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.alert);
      await tester.pump();
      expect(_rootGlitch(tester).progress.value, 0);
      expect(_rootGlitch(tester).flashColor, KkColors.alertTheme.alert);
      int flashes = 0;
      bool wasOn = false;
      // The flash is the one rectangle drawn with the screen blend mode.
      final Matcher flash =
          (paints..something((Symbol method, List<dynamic> arguments) {
                if (method != #drawRect) return false;
                final Paint paint = arguments[1] as Paint;
                return paint.blendMode == BlendMode.screen &&
                    paint.color.toARGB32() == kkFade(KkColors.alertTheme.alert, 0.6).toARGB32();
              }))
              as Matcher;
      for (int ms = 0; ms <= 720; ms += 10) {
        final bool on = flash.matches(find.byType(KkGlitch).first, <dynamic, dynamic>{});
        if (on && !wasOn) flashes++;
        wasOn = on;
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(flashes, 3);
      expect(_rootGlitch(tester).progress.value, 1);
      // Back to standby: no glitch.
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.standby);
      await tester.pump();
      expect(_rootGlitch(tester).progress.value, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Alert again: it fires again.
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.alert);
      await tester.pump();
      expect(_rootGlitch(tester).progress.value, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 20));
    });

    testChecked('a controlled app glitches when its condition turns to alert', (WidgetTester tester) async {
      Widget app(KkCondition condition) => KeikaiApp(condition: condition, home: const _Page('home'));
      await tester.pumpWidget(app(KkCondition.standby));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(app(KkCondition.alert));
      expect(_rootGlitch(tester).progress.value, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_rootGlitch(tester).progress.value, 1);
    });

    testChecked('glitchOnAlert false, or motion off: no glitch', (WidgetTester tester) async {
      await tester.pumpWidget(const KeikaiApp(glitchOnAlert: false, home: _Page('home')));
      await tester.pump(const Duration(milliseconds: 500));
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.alert);
      await tester.pump();
      expect(_rootGlitch(tester).progress.value, 1);
      await tester.pumpWidget(
        const KeikaiApp(key: ValueKey<int>(2), theme: KeikaiThemeData(motion: KkMotion.off), home: _Page('home')),
      );
      KeikaiApp.setCondition(_contextOf(tester, 'home'), KkCondition.alert);
      await tester.pump();
      expect(_rootGlitch(tester).progress.value, 1);
      await tester.pumpAndSettle();
    });
  });

  group('wall scale', () {
    testChecked('type is scaled by 1.25 from 2560px', (WidgetTester tester) async {
      Future<double> scaleAt(double width, {bool wallScale = true, KeikaiThemeData theme = const KeikaiThemeData()}) async {
        await _size(tester, Size(width, 1000));
        await tester.pumpWidget(KeikaiApp(wallScale: wallScale, theme: theme, home: const _Page('home')));
        await tester.pump();
        return KeikaiTheme.of(_contextOf(tester, 'home')).type.scale;
      }

      expect(await scaleAt(2559), 1.0);
      expect(await scaleAt(2560), 1.25);
      expect(await scaleAt(3840), 1.25);
      expect(await scaleAt(1280), 1.0);
      expect(await scaleAt(2560, wallScale: false), 1.0);
      // A scale the app chose itself is left alone.
      expect(await scaleAt(2560, theme: const KeikaiThemeData(type: KkTypography(scale: 2))), 2.0);
      expect(await scaleAt(2560), 1.25);
      expect(DefaultTextStyle.of(_contextOf(tester, 'home')).style.fontSize, 17.5);
    });
  });

  group('KeikaiApp.router', () {
    testChecked('runs from a router configuration', (WidgetTester tester) async {
      final _Delegate delegate = _Delegate();
      addTearDown(delegate.dispose);
      await tester.pumpWidget(
        KeikaiApp.router(
          routerConfig: RouterConfig<Object>(routerDelegate: delegate),
          theme: const KeikaiThemeData(motion: KkMotion.off),
          condition: KkCondition.alert,
        ),
      );
      expect(find.text('routed 0'), findsOneWidget);
      final BuildContext context = _contextOf(tester, 'routed 0');
      expect(KeikaiTheme.of(context).colors, KkColors.alertTheme);
      expect(ScrollConfiguration.of(context), isA<KkScrollBehavior>());
      delegate.bump();
      await tester.pump();
      expect(find.text('routed 1'), findsOneWidget);
    });
  });

  group('KkPopupRoute', () {
    Future<NavigatorState> open(
      WidgetTester tester, {
      bool dismissible = true,
      Color? scrim,
      bool motion = false,
      void Function(Animation<double>)? onAnimation,
    }) async {
      await _size(tester, const Size(800, 600));
      await tester.pumpWidget(
        KeikaiApp(
          theme: KeikaiThemeData(motion: motion ? const KkMotion() : KkMotion.off),
          home: const _Page('home'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final NavigatorState navigator = Navigator.of(_contextOf(tester, 'home'));
      navigator.push(
        KkPopupRoute<void>(
          scrim: scrim,
          dismissible: dismissible,
          label: 'Close dialog',
          builder: (BuildContext context, Animation<double> animation) {
            onAnimation?.call(animation);
            return const Center(child: SizedBox(width: 200, height: 100, child: _Page('popup')));
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      return navigator;
    }

    testChecked('floats over the page with a hard scrim', (WidgetTester tester) async {
      await open(tester, scrim: KkColors.standby.scrim);
      expect(find.text('popup'), findsOneWidget);
      expect(find.text('home'), findsOneWidget, reason: 'the page stays visible behind');
      final ModalBarrier barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(barrier.color, KkColors.standby.scrim);
      expect(barrier.dismissible, isTrue);
      expect(find.byType(AnimatedModalBarrier), findsNothing, reason: 'the scrim snaps in; it never fades');
    });

    testChecked('a tap on the scrim dismisses it', (WidgetTester tester) async {
      await open(tester, scrim: KkColors.standby.scrim);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump();
      expect(find.text('popup'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testChecked('a tap inside the popup does not dismiss it', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('popup'));
      await tester.pump();
      await tester.pump();
      expect(find.text('popup'), findsOneWidget);
    });

    testChecked('Escape dismisses it', (WidgetTester tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(find.text('popup'), findsNothing);
    });

    testChecked('not dismissible: neither the scrim nor Escape closes it', (WidgetTester tester) async {
      final NavigatorState navigator = await open(tester, dismissible: false);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(find.text('popup'), findsOneWidget);
      navigator.pop();
      await tester.pump();
      await tester.pump();
      expect(find.text('popup'), findsNothing);
    });

    testChecked('hands its animation to the builder: 0 to 1 over 0.42s with motion on', (WidgetTester tester) async {
      Animation<double>? animation;
      await open(tester, motion: true, onAnimation: (Animation<double> a) => animation = a);
      expect(animation, isNotNull);
      expect(animation!.value, 0);
      await tester.pump(const Duration(milliseconds: 210));
      expect(animation!.value, closeTo(0.5, 1e-6));
      await tester.pump(const Duration(milliseconds: 210));
      expect(animation!.value, 1);
      await tester.pump(const Duration(milliseconds: 20));
    });

    testChecked('with motion off the popup is fully open at once', (WidgetTester tester) async {
      Animation<double>? animation;
      await open(tester, onAnimation: (Animation<double> a) => animation = a);
      expect(animation!.value, 1);
      await tester.pumpAndSettle();
    });

    testChecked('announces its barrier label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('Close dialog'), findsOneWidget);
      handle.dispose();
    });
  });
}

class _Delegate extends RouterDelegate<Object> with ChangeNotifier {
  int _count = 0;

  void bump() {
    _count++;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) => _Page('routed $_count');

  @override
  Future<bool> popRoute() async => false;

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
