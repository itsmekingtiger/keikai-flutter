import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/catalogue_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/diagram_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/log_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/procedure_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/settings_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/situation_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/systems_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/shell/boot_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/shell/console_shell.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/shell/not_found_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/incident_band.dart';
import 'app_harness.dart';
import 'situation_test.dart' show raiseIncidentFromCaution;

/// The screen each rail label leads to, in rail order.
final List<(String, Finder)> _destinations = <(String, Finder)>[
  ('BOARD', find.byType(SituationScreen)),
  ('SYSTEMS', find.byType(SystemsScreen)),
  ('DIAGRAM', find.byType(DiagramScreen)),
  ('STEPS', find.byType(ProcedureScreen)),
  ('LOG', find.byType(LogScreen)),
  ('SETUP', find.byType(SettingsScreen)),
  ('INDEX', find.byType(CatalogueScreen)),
];

const List<(LogicalKeyboardKey, String)> _digits = <(LogicalKeyboardKey, String)>[
  (LogicalKeyboardKey.digit1, '1'),
  (LogicalKeyboardKey.digit2, '2'),
  (LogicalKeyboardKey.digit3, '3'),
  (LogicalKeyboardKey.digit4, '4'),
  (LogicalKeyboardKey.digit5, '5'),
  (LogicalKeyboardKey.digit6, '6'),
  (LogicalKeyboardKey.digit7, '7'),
];

void main() {
  setUpAll(loadKkFonts);

  group('frame', () {
    for (final Size size in windowSizes) {
      for (final bool alert in <bool>[false, true]) {
        testWidgets('bars and rail sit where they belong at ${size.width.round()}px${alert ? ', alert' : ''}', (
          WidgetTester tester,
        ) async {
          final Rig rig = await pumpApp(tester, size: size);
          if (alert) {
            rig.station.triggerIncident();
            await tick(tester, rig, 6);
            rig.station.acknowledge();
            await tick(tester, rig);
          }
          expectClean(tester, 'first frames');
          final bool compact = size.width < 600;
          expect(tester.getRect(find.byType(KkCommandBar)), Rect.fromLTWH(0, 0, size.width, 48));
          expect(tester.getRect(find.byType(KkToolbar)), Rect.fromLTWH(0, size.height - 32, size.width, 32));
          final Rect rail = tester.getRect(find.byType(KkNavRail));
          if (compact) {
            expect(rail, Rect.fromLTWH(0, size.height - 32 - 64, size.width, 64));
          } else {
            expect(rail, Rect.fromLTWH(0, 48, 72, size.height - 48 - 32));
          }
          expect(
            KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))),
            alert ? KkCondition.alert : KkCondition.standby,
          );
          expect(find.text(alert ? 'ALERT' : 'STANDBY'), findsWidgets);
          // The bell is always reachable; the readings come in as the bar gets room.
          expect(
            find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms'),
            findsOneWidget,
          );
          expect(find.text('UTC'), compact ? findsNothing : findsOneWidget);
          expect(find.text('OPERATOR'), size.width >= 1200 ? findsOneWidget : findsNothing);
          // Every destination is in the rail.
          for (final (String label, Finder _) in _destinations) {
            expect(inRail(label), findsOneWidget, reason: label);
          }
        });
      }
    }

    testWidgets('the command bar and the toolbar follow the plant', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(1280, 800));
      expect(find.text('14:02:31Z'), findsOneWidget);
      expect(find.textContaining('UP 076:17:00'), findsOneWidget);
      await tick(tester, rig, 2);
      expect(find.textContaining('UP 076:17:02'), findsOneWidget);
      expect(find.text('14:02:33Z'), findsOneWidget);
      expect(find.text('00'), findsWidgets);
      rig.station.triggerIncident();
      await tick(tester, rig, 6);
      expect(find.text('01'), findsWidgets); // one alarm sounding
      expect(find.text('SEC-04'), findsWidgets); // the worst sector
      expectClean(tester, 'incident');
    });
  });

  group('alarm band', () {
    Finder band() => find.byType(IncidentBand);
    Finder words() => find.descendant(of: band(), matching: find.byType(KkMarquee));

    for (final Size size in windowSizes) {
      testWidgets('repeats the incident under the command bar at ${size.width.round()}px', (WidgetTester tester) async {
        final Rig rig = await pumpApp(tester, size: size, route: '/systems');
        // Nothing wrong: the band takes no room at all.
        expect(words(), findsNothing);
        expect(tester.getSize(band()).height, 0);
        final double bodyTop = tester.getRect(find.byType(SystemsScreen)).top;

        rig.station.triggerIncident();
        await tick(tester, rig);
        expect(tester.widget<KkMarquee>(words()).text, 'CAUTION — COOLANT PRESSURE FALLING · SEC-04 · E-4127');
        final Rect r = tester.getRect(band());
        expect(r, Rect.fromLTWH(0, 48, size.width, 28), reason: 'pinned under the command bar, full width');
        // The body starts lower by exactly the band; the rail starts under it.
        expect(tester.getRect(find.byType(SystemsScreen)).top, bodyTop + 28);
        if (size.width >= 600) expect(tester.getRect(find.byType(KkNavRail)).top, 48 + 28);

        await raiseIncidentFromCaution(tester, rig);
        expect(tester.widget<KkMarquee>(words()).text, 'CRITICAL — COOLANT PRESSURE LOW · SEC-04 · E-4127');
        // Scrolling the body leaves the band where it is.
        await tester.dragFrom(Offset(size.width / 2, size.height / 2), const Offset(0, -200));
        await tester.pump();
        expect(tester.getRect(band()).top, 48);
        expectClean(tester, 'band');
      });
    }

    testWidgets('is on every screen but the board and the procedure, and leads to the procedure', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester, route: '/log');
      await raiseIncident(tester, rig);
      for (final (LogicalKeyboardKey key, String digit) in _digits) {
        await pressKey(tester, key, digit);
        await tester.pumpAndSettle();
        expect(words(), digit == '1' || digit == '4' ? findsNothing : findsOneWidget, reason: 'screen $digit');
      }
      // From the catalogue, the band is the way to the procedure.
      expect(find.byType(CatalogueScreen), findsOneWidget);
      await tester.tap(band());
      await tester.pumpAndSettle();
      expect(find.byType(ProcedureScreen), findsOneWidget);

      // The incident over, the band goes.
      await pressKey(tester, LogicalKeyboardKey.digit2, '2');
      await tester.pumpAndSettle();
      expect(words(), findsOneWidget);
      rig.station.reset();
      await tester.pump();
      expect(words(), findsNothing);
      expectClean(tester, 'band navigation');
    });

    testWidgets('grows in from the left and runs with motion on', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(1280, 800), route: '/settings', motion: true);
      await tester.pump(const Duration(seconds: 1));
      rig.station.triggerIncident();
      rig.station.tick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // A third of the way through its six jumps the band is a third as wide.
      final Finder plate = find.descendant(of: band(), matching: find.byType(KkPressable));
      expect(tester.getRect(plate).left, 0);
      expect(tester.getRect(plate).width, moreOrLessEquals(1280 / 3, epsilon: 0.01));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(plate).width, 1280);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expectClean(tester, 'band with motion');
    });
  });

  group('lamps', () {
    Finder bell() => find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms');

    testWidgets('the bell strobes while an alarm is unanswered', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(1280, 800), motion: true);
      await tester.pump(const Duration(seconds: 1));
      final KkColors c = tester.element(find.byType(KkScreen)).kk.colors;
      expect(tester.widget<KkIconButton>(bell()).style, isNull);
      expect(tester.widget<KkIconButton>(bell()).icon, KkIcons.bellOff);

      rig.station.alarms[4].state = AlarmState.alarm;
      rig.station.tick();
      await tester.pump();
      expect(tester.widget<KkIconButton>(bell()).icon, KkIcons.bell);
      // Lit and unlit take turns, each for half of the 1.2 s strobe.
      final Set<Color?> fills = <Color?>{};
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        fills.add(tester.widget<KkIconButton>(bell()).style?.fill);
      }
      expect(fills, <Color?>{c.alert, c.alertDeep});

      rig.station.acknowledge();
      rig.station.tick();
      await tester.pump();
      expect(tester.widget<KkIconButton>(bell()).style, isNull);
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'bell');
    });

    testWidgets('with motion off an unanswered alarm keeps the bell lit', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester);
      rig.station.alarms[4].state = AlarmState.alarm;
      await tick(tester, rig);
      final KkColors c = tester.element(find.byType(KkScreen)).kk.colors;
      expect(tester.widget<KkIconButton>(bell()).style?.fill, c.alert);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<KkIconButton>(bell()).style?.fill, c.alert);
      expectClean(tester, 'bell without motion');
    });

    testWidgets('the link lamp runs while the plant runs and is dark while it is paused', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(1280, 800), motion: true);
      await tester.pump(const Duration(seconds: 1));
      final KkColors c = tester.element(find.byType(KkScreen)).kk.colors;
      List<Color?> cells(String label) => tester
          .widgetList<KkBox>(
            find.descendant(
              of: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == label),
              matching: find.byType(KkBox),
            ),
          )
          .map((KkBox b) => b.fill)
          .toList();
      expect(cells('Simulation paused'), <Color?>[c.signalDim, c.signalDim, c.signalDim, c.signalDim]);

      rig.station.start();
      addTearDown(rig.station.stop);
      await tester.pump();
      // One cell lit at a time, and the lit cell walks through all four.
      final Set<int> lit = <int>{};
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final List<Color?> now = cells('Simulation running');
        expect(now.where((Color? f) => f == c.signal), hasLength(1));
        lit.add(now.indexOf(c.signal));
      }
      expect(lit, <int>{0, 1, 2, 3});

      rig.station.stop();
      await tester.pump();
      expect(cells('Simulation paused'), everyElement(c.signalDim));
      expectClean(tester, 'link lamp');
    });
  });

  group('snackbars', () {
    /// Isolates [count] sectors, one snackbar each.
    Future<void> raise(WidgetTester tester, Rig rig, int count) async {
      rig.settings.setNotify(KkLevel.offline, on: true);
      for (int i = 0; i < count; i++) {
        rig.station.setSectorOffline(rig.station.sectors[i], offline: true);
        await tester.pump();
      }
    }

    for (final Size size in windowSizes) {
      testWidgets('stack beside the rail and clear of every bar at ${size.width.round()}px', (
        WidgetTester tester,
      ) async {
        final Rig rig = await pumpApp(tester, size: size);
        await raise(tester, rig, 4);
        final bool compact = size.width < 600;
        // The latest ones stay: two on a phone, three on a larger window.
        expect(find.byType(KkSnackbar), findsNWidgets(compact ? 2 : 3));
        expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('SEC-04')), findsOneWidget);
        final Rect rail = tester.getRect(find.byType(KkNavRail));
        final Rect toolbar = tester.getRect(find.byType(KkToolbar));
        for (final Element e in find.byType(KkSnackbar).evaluate()) {
          final Rect bar = tester.getRect(find.byWidget(e.widget));
          expect(bar.overlaps(rail), isFalse, reason: 'a snackbar never covers a destination');
          expect(bar.overlaps(toolbar), isFalse);
          expect(bar.left, compact ? 24 : 72 + 24);
          expect(bar.right, lessThanOrEqualTo(size.width));
        }
        // 16px above the lowest bar: the toolbar, or the navigation bar of a phone.
        final double floor = compact ? rail.top : toolbar.top;
        expect(tester.getRect(find.byType(KkSnackbar).last).bottom, floor - 16);
        await tester.pump(const Duration(seconds: 6));
        expect(find.byType(KkSnackbar), findsNothing);
        expectClean(tester, 'snackbars');
      });
    }

    testWidgets('in a low window one shows at a time, over the bars and off the body', (WidgetTester tester) async {
      for (final Size size in const <Size>[Size(667, 375), Size(568, 320)]) {
        final Rig rig = await pumpApp(tester, size: size);
        await raise(tester, rig, 3);
        expect(find.byType(KkSnackbar), findsOneWidget);
        expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('SEC-03')), findsOneWidget);
        final Rect bar = tester.getRect(find.byType(KkSnackbar));
        expect(bar.bottom, size.height);
        // All but a sliver of it lies on the toolbar (and the navigation bar of a phone).
        final Rect body = tester.getRect(find.byType(SituationScreen));
        expect(bar.top, greaterThanOrEqualTo(size.height - 40));
        expect(bar.top, greaterThanOrEqualTo(tester.getRect(find.byType(KkToolbar)).top - 8));
        expect(body.top, lessThan(bar.top));
        await tester.pump(const Duration(seconds: 6));
        expectClean(tester, 'low window $size');
        await tester.pumpWidget(const KkBox());
      }
    });

    testWidgets('belong to the page: a dialog, a sheet and the alarm lie over them', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(380, 760), route: '/systems');
      await raise(tester, rig, 2);
      expect(find.byType(KkSnackbar), findsNWidgets(2));
      // Part of the page they were raised on.
      expect(find.ancestor(of: find.byType(KkSnackbar), matching: find.byType(ConsoleShell)), findsWidgets);
      final Offset onSnackbar = tester.getCenter(find.byType(KkSnackbar).last);

      // A sheet comes up over them: a press where a snackbar lies reaches the sheet.
      await tester.ensureVisible(find.byType(KkListRow).at(5));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(KkListRow).at(5));
      await tester.pumpAndSettle();
      expect(find.byType(KkSheet), findsOneWidget);
      expect(tester.getRect(find.byType(KkSheet)).contains(onSnackbar), isTrue);
      final HitTestResult hit = tester.hitTestOnBinding(onSnackbar);
      final RenderObject snackbar = tester.renderObject(find.byType(KkSnackbar).last);
      expect(hit.path.map((HitTestEntry e) => e.target), isNot(contains(snackbar)));
      await tester.tap(iconButton('Close'));
      await tester.pumpAndSettle();

      // The alarm: the stack is emptied, and nothing is added while it is up.
      rig.station.triggerIncident();
      await tick(tester, rig, 6);
      await tester.pumpAndSettle();
      expect(find.byType(KkEmergency), findsOneWidget);
      expect(find.byType(KkSnackbar), findsNothing);
      rig.station.acknowledge();
      await tick(tester, rig);
      await tester.pumpAndSettle();
      expect(find.byType(KkEmergency), findsNothing);
      expect(find.byType(KkSnackbar), findsNothing, reason: 'nothing is left over the controls after the alarm');
      expectClean(tester, 'layers');
    });
  });

  group('navigation', () {
    for (final Size size in windowSizes) {
      testWidgets('the rail leads to every screen at ${size.width.round()}px', (WidgetTester tester) async {
        await pumpApp(tester, size: size);
        expect(find.byType(SituationScreen), findsOneWidget);
        for (final (String label, Finder target) in _destinations.reversed) {
          await tester.tap(inRail(label));
          await tester.pumpAndSettle();
          expect(target, findsOneWidget, reason: label);
          expect(
            tester.widget<KkNavRail>(find.byType(KkNavRail).last).index,
            _destinations.indexWhere(((String, Finder) d) => d.$1 == label),
          );
          expectClean(tester, label);
        }
      });
    }

    testWidgets('the digit keys jump to the screens', (WidgetTester tester) async {
      await pumpApp(tester);
      for (int i = _digits.length - 1; i >= 0; i--) {
        await pressKey(tester, _digits[i].$1, _digits[i].$2);
        await tester.pumpAndSettle();
        expect(_destinations[i].$2, findsOneWidget, reason: 'key ${_digits[i].$2}');
      }
      expectClean(tester, 'keys');
    });

    testWidgets('a key with Control held is left to the browser', (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await pressKey(tester, LogicalKeyboardKey.digit3, '3');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(DiagramScreen), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
    });

    testWidgets('digits typed into a field are text, not navigation', (WidgetTester tester) async {
      await pumpApp(tester, route: '/systems');
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await pressKey(tester, LogicalKeyboardKey.digit1, '1');
      await pressKey(tester, LogicalKeyboardKey.keyD, 'd');
      await tester.pumpAndSettle();
      expect(find.byType(SystemsScreen), findsOneWidget);
      expect(find.byType(SituationScreen, skipOffstage: true), findsNothing);
    });

    testWidgets('the menu button opens the drawer; a destination closes it and goes there', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Menu'));
      await tester.pumpAndSettle();
      expect(find.byType(ConsoleDrawer), findsOneWidget);
      expect(find.text('第三管制所'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(ConsoleDrawer), matching: find.text('PROCEDURE')));
      await tester.pumpAndSettle();
      expect(find.byType(ConsoleDrawer), findsNothing);
      expect(find.byType(ProcedureScreen), findsOneWidget);
      expectClean(tester, 'drawer');
    });

    testWidgets('M opens the drawer and Escape closes it', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(380, 760));
      await pressKey(tester, LogicalKeyboardKey.keyM, 'm');
      await tester.pumpAndSettle();
      expect(find.byType(ConsoleDrawer), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ConsoleDrawer), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
      expectClean(tester, 'drawer keys');
    });

    testWidgets('Back returns to the board, and the board is the last page', (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(inRail('LOG'));
      await tester.pumpAndSettle();
      await tester.tap(inRail('SETUP'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      // The system back button (the browser's Back).
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SituationScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(LogScreen), findsNothing);
    });

    testWidgets('an address opens its screen over the board', (WidgetTester tester) async {
      await pumpApp(tester, route: '/log');
      expect(find.byType(LogScreen), findsOneWidget);
      await tester.tap(find.text('KEIKAI'));
      await tester.pumpAndSettle();
      expect(find.byType(SituationScreen), findsOneWidget);
      expect(find.byType(LogScreen), findsNothing);
    });

    testWidgets('an address that names nothing shows the no-route page', (WidgetTester tester) async {
      await pumpApp(tester, route: '/nowhere');
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.text('NOTHING AT /nowhere'), findsOneWidget);
      await tester.tap(find.text('RETURN TO BOARD'));
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundScreen), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
      expectClean(tester, 'not found');
    });
  });

  group('actions', () {
    testWidgets('the toolbar steps and runs the plant', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester);
      final int before = rig.station.ticks;
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Step one second'));
      await tester.pump();
      expect(rig.station.ticks, before + 1);
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Run simulation'));
      await tester.pump();
      expect(rig.station.running, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(rig.station.ticks, before + 4);
      // While it runs, stepping by hand is off.
      expect(
        tester
            .widget<KkIconButton>(
              find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Step one second'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Pause simulation'),
      );
      await tester.pump();
      expect(rig.station.running, isFalse);
      await pressKey(tester, LogicalKeyboardKey.keyP, 'p');
      expect(rig.station.running, isTrue);
      await pressKey(tester, LogicalKeyboardKey.keyP, 'p');
      expect(rig.station.running, isFalse);
      expectClean(tester, 'toolbar');
    });

    testWidgets('D starts the drill and A acknowledges the alarm', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester);
      await pressKey(tester, LogicalKeyboardKey.keyD, 'd');
      expect(rig.station.phase, IncidentPhase.caution);
      expect(find.text('DRILL STARTED · COOLANT LOOP'), findsOneWidget);
      await pressKey(tester, LogicalKeyboardKey.keyD, 'd'); // a second D does nothing
      await tick(tester, rig, 4);
      expect(rig.station.phase, IncidentPhase.caution);
      rig.station.reset();
      await tester.pump();
      // An alarm that sounds without the full-screen alarm is acknowledged with A.
      rig.station.alarms[2].state = AlarmState.alarm;
      await tick(tester, rig);
      expect(rig.station.soundingAlarms, 1);
      await pressKey(tester, LogicalKeyboardKey.keyA, 'a');
      expect(rig.station.soundingAlarms, 0);
      expect(rig.station.activeAlarms, 1, reason: 'acknowledged, and lit until it clears');
      expect(rig.station.alarms[2].state, AlarmState.acknowledged);
      expectClean(tester, 'keys');
    });

    testWidgets('the bell opens the alarm menu', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester);
      final Finder bell = find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms');
      await tester.tap(bell);
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      expect(find.text('START DRILL'), findsOneWidget);
      await tester.tap(find.text('START DRILL'));
      await tester.pumpAndSettle();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(rig.station.phase, IncidentPhase.caution);

      await tester.tap(bell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN PROCEDURE'));
      await tester.pumpAndSettle();
      expect(find.byType(ProcedureScreen), findsOneWidget);

      // Reset asks first; No keeps the incident, Yes ends it.
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESET PLANT'));
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(rig.station.phase, IncidentPhase.caution);
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESET PLANT'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(KkDialog), matching: find.text('RESET')));
      await tester.pumpAndSettle();
      expect(rig.station.phase, IncidentPhase.none);
      expect(find.text('CONDITION STANDBY'), findsWidgets);
      expectClean(tester, 'alarm menu');
    });

    testWidgets('? lists the keys in a dialog that Escape closes', (WidgetTester tester) async {
      await pumpApp(tester);
      await pressKey(tester, LogicalKeyboardKey.slash, '?');
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsOneWidget);
      expect(find.byType(KkKbd), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsNothing);
      // The help button in the rail opens the same list.
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Keyboard'));
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(find.byType(KkDialog), findsNothing);
      expectClean(tester, 'keys dialog');
    });

    testWidgets('a new caution or critical log line raises a snackbar; a nominal one does not', (
      WidgetTester tester,
    ) async {
      final Rig rig = await pumpApp(tester);
      rig.station.setSectorOffline(rig.station.sectors[10], offline: true); // an offline line: not wanted
      await tester.pump();
      expect(find.byType(KkSnackbar), findsNothing);
      rig.settings.setNotify(KkLevel.offline, on: true);
      rig.station.setSectorOffline(rig.station.sectors[9], offline: true);
      await tester.pump();
      expect(find.byType(KkSnackbar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(KkSnackbar), matching: find.text('SECTOR ISOLATED BY OPERATOR')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(KkSnackbar), findsNothing);
    });
  });

  group('boot', () {
    testWidgets('checks itself, then hands over to the board', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(1280, 800), motion: true, boot: true);
      expect(find.byType(BootScreen), findsOneWidget);
      expect(find.byType(KkScreen), findsNothing);
      KkProgress bar() => tester.widget<KkProgress>(find.byType(KkProgress));
      expect(bar().value, 0);
      // The bar takes a fifth for every check that has passed.
      await tester.pump(const Duration(milliseconds: 400));
      expect(bar().value, 0.2);
      await tester.pump(const Duration(milliseconds: 800));
      expect(bar().value, 0.6);
      expect(bar().level, isNull);
      expect(find.byType(BootScreen), findsOneWidget);
      expect(find.text('TOKENS'), findsOneWidget);
      expect(find.text('STARTING'), findsOneWidget);
      // All five passed: the bar is full and green, and stays for a moment.
      await tester.pump(const Duration(milliseconds: 1250));
      expect(bar().value, 1);
      expect(bar().level, KkLevel.nominal);
      expect(find.text('READY'), findsOneWidget);
      expect(find.byType(BootScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BootScreen), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expectClean(tester, 'boot');
    });

    testWidgets('Skip hands over at once', (WidgetTester tester) async {
      await pumpApp(tester, motion: true, boot: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('SKIP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(BootScreen), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expectClean(tester, 'skip');
    });

    testWidgets('with motion off there is nothing to wait for', (WidgetTester tester) async {
      await pumpApp(tester, boot: true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BootScreen), findsNothing);
      expect(find.byType(SituationScreen), findsOneWidget);
      expectClean(tester, 'boot without motion');
    });

    testWidgets('in a short window every line and the Skip button are on screen', (WidgetTester tester) async {
      for (final Size size in const <Size>[Size(667, 375), Size(568, 320)]) {
        await pumpApp(tester, size: size, motion: true, boot: true);
        await tester.pump(const Duration(milliseconds: 2000));
        final Rect window = Offset.zero & size;
        for (final Finder part in <Finder>[
          find.byType(KkHeading),
          find.text('CLOCK'),
          find.byType(KkProgress),
          button('skip'),
        ]) {
          final Rect r = tester.getRect(part);
          expect(window.contains(r.topLeft) && window.contains(r.bottomRight), isTrue, reason: '$part at $size: $r');
        }
        await tester.tap(button('skip'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(BootScreen), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expectClean(tester, 'boot at $size');
        await tester.pumpWidget(const KkBox());
      }
    });

    testWidgets('a window too short even for that scrolls', (WidgetTester tester) async {
      await pumpApp(tester, size: const Size(480, 220), motion: true, boot: true);
      await tester.pump(const Duration(milliseconds: 500));
      expectClean(tester, 'boot in a tiny window');
      expect(tester.getRect(button('skip')).top, greaterThan(220));
      await tester.dragFrom(const Offset(240, 150), const Offset(0, -200));
      await tester.pump();
      expect(tester.getRect(button('skip')).bottom, lessThanOrEqualTo(220));
      await tester.tap(button('skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(BootScreen), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expectClean(tester, 'after the boot');
    });

    testWidgets('the boot and the no-route page keep clear of a notch', (WidgetTester tester) async {
      tester.view.padding = const FakeViewPadding(left: 88, top: 96, right: 88);
      addTearDown(tester.view.resetPadding);
      await pumpApp(tester, size: const Size(760, 380), boot: true, motion: true);
      await tester.pump(const Duration(milliseconds: 300));
      Rect r = tester.getRect(find.byType(KkHeading));
      expect(r.left, greaterThanOrEqualTo(88 + 12));
      expect(r.top, greaterThanOrEqualTo(96 + 12));
      await tester.tap(button('skip'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const KkBox());

      await pumpApp(tester, size: const Size(760, 380), route: '/nowhere');
      r = tester.getRect(find.byType(KkEmpty));
      expect(r.left, greaterThanOrEqualTo(88 + 12));
      expect(r.right, lessThanOrEqualTo(760 - 88 - 12));
      expect(r.top, greaterThanOrEqualTo(96 + 12));
      expectClean(tester, 'notch');
    });

    testWidgets('an alarm that came during the boot is raised after it', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, motion: true, boot: true);
      rig.station.emergencyStop();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(KkEmergency), findsNothing);
      await tester.tap(find.text('SKIP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(KkEmergency), findsOneWidget);
      rig.station.acknowledge();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(KkEmergency), findsNothing);
      expectClean(tester, 'alarm after boot');
    });
  });
}
