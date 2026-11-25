import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import '../../example/lib/widgets/sector_detail.dart';
import 'app_harness.dart';

KkCondition _condition(WidgetTester tester) => KeikaiApp.conditionOf(tester.element(find.byType(KkScreen).last));

Finder _next() => find.byWidgetPredicate(
  (Widget w) => w is KkButton && (w.semanticLabel ?? '').startsWith('Execute step'),
  description: 'the execute button',
);

void main() {
  setUpAll(loadKkFonts);

  // One watch at the console, start to finish, the way an operator would live
  // it: with motion on, so every frame count below is real time.
  testWidgets('a watch: boot, board, incident, alarm, procedure, standby', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, size: const Size(1440, 900), motion: true, boot: true);
    final Station station = rig.station;

    Future<void> frames([int count = 8]) async {
      for (int i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> seconds(int count) async {
      for (int i = 0; i < count; i++) {
        station.tick();
        await frames(4);
      }
    }

    // Boot hands over to the board.
    expect(find.byType(BootScreen), findsOneWidget);
    await frames(30);
    expect(find.byType(BootScreen), findsNothing);
    expect(find.byType(SituationScreen), findsOneWidget);
    await frames(20);
    expect(_condition(tester), KkCondition.standby);
    expectClean(tester, 'board');

    // The drill: caution first.
    await tester.tap(button('drill'));
    await frames();
    expect(station.phase, IncidentPhase.caution);
    await seconds(2);
    expect(tester.widget<KkAlertBar>(find.byType(KkAlertBar)).level, KkLevel.caution);
    expect(_condition(tester), KkCondition.standby, reason: 'caution is not an alarm');

    // Critical: the condition turns to alert and the alarm takes the screen.
    await seconds(4);
    expect(station.phase, IncidentPhase.critical);
    expect(_condition(tester), KkCondition.alert);
    expect(find.byType(KkEmergency), findsOneWidget);
    // The keys of the console are out of reach behind the alarm.
    await pressKey(tester, LogicalKeyboardKey.digit2, '2');
    await frames();
    expect(find.byType(SystemsScreen), findsNothing);
    await tester.tap(find.descendant(of: find.byType(KkEmergency), matching: button('acknowledge')));
    await frames(10);
    expect(find.byType(KkEmergency), findsNothing);
    expect(station.phase, IncidentPhase.acknowledged);
    expect(tester.widget<KkAlertBar>(find.byType(KkAlertBar)).level, KkLevel.critical);
    expectClean(tester, 'alarm');

    // To the procedure by keyboard, and through it.
    await pressKey(tester, LogicalKeyboardKey.digit4, '4');
    await frames(10);
    expect(find.byType(ProcedureScreen), findsOneWidget);
    await tester.tap(_next()); // start the aux pump
    await frames();
    await tester.tap(_next()); // close the valve: asks
    await frames(10);
    expect(find.byType(KkDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // not yet
    await frames(10);
    expect(find.byType(KkDialog), findsNothing);
    expect(station.phase, IncidentPhase.acknowledged);
    await tester.tap(_next());
    await frames(10);
    await tester.tap(button('execute'));
    await frames(10);
    expect(station.phase, IncidentPhase.recovering);
    expect(_condition(tester), KkCondition.standby, reason: 'the plant recovers in the orange theme');
    await tester.tap(_next()); // pressure recovery
    await frames();
    await tester.tap(_next()); // restore the main pump: asks
    await frames(10);
    await tester.tap(button('execute'));
    await frames(10);
    await tester.tap(_next()); // return to standby
    await frames();
    expect(find.text('PROCEDURE COMPLETE'), findsOneWidget);
    await seconds(20);
    expect(station.phase, IncidentPhase.none);
    expect(station.activeAlarms, 0);
    expectClean(tester, 'procedure');

    // Back on the board everything is quiet again.
    await tester.tap(find.text('KEIKAI'));
    await frames(12);
    expect(find.byType(SituationScreen), findsOneWidget);
    expect(find.byType(KkAlertBar), findsNothing);
    expect(tester.widget<KkModeStrip>(find.byType(KkModeStrip)).current, 1);
    await frames(60); // the snackbars of the steps time out
    expect(find.byType(KkSnackbar), findsNothing);
    expectClean(tester, 'standby');
  });

  testWidgets('every overlay opens and closes by pointer and by keyboard', (WidgetTester tester) async {
    await pumpApp(tester);

    // Drawer: menu button, scrim tap.
    await tester.tap(iconButton('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsoleDrawer), findsOneWidget);
    await tester.tapAt(const Offset(1200, 450));
    await tester.pumpAndSettle();
    expect(find.byType(ConsoleDrawer), findsNothing);
    // Drawer: M, Escape.
    await pressKey(tester, LogicalKeyboardKey.keyM, 'm');
    await tester.pumpAndSettle();
    expect(find.byType(ConsoleDrawer), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConsoleDrawer), findsNothing);

    // Menu: the bell, Escape; the bell, a press outside.
    await tester.tap(iconButton('Alarms'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((Widget w) => w is KkMenu), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((Widget w) => w is KkMenu), findsNothing);
    await tester.tap(iconButton('Alarms'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((Widget w) => w is KkMenu), findsNothing);
    // Menu by keyboard: arrow down to the first live item and Enter.
    await tester.tap(iconButton('Alarms'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ProcedureScreen), findsOneWidget, reason: 'the first live item opens the procedure');
    await pressKey(tester, LogicalKeyboardKey.digit1, '1');
    await tester.pumpAndSettle();

    // Dialog: ?, the Close button; ?, Escape; ?, the scrim.
    await pressKey(tester, LogicalKeyboardKey.slash, '?');
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsOneWidget);
    await tester.tap(button('close'));
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsNothing);
    await pressKey(tester, LogicalKeyboardKey.slash, '?');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsNothing);
    await pressKey(tester, LogicalKeyboardKey.slash, '?');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(40, 860));
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsNothing);

    // Sheet: a sector cell, the close button; again, Escape; again, the scrim.
    for (final Future<void> Function() close in <Future<void> Function()>[
      () => tester.tap(iconButton('Close')),
      () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      () => tester.tapAt(const Offset(300, 450)),
    ]) {
      await tester.tap(find.text('S-02'));
      await tester.pumpAndSettle();
      expect(find.byType(SectorSheet), findsOneWidget);
      await close();
      await tester.pumpAndSettle();
      expect(find.byType(SectorSheet), findsNothing);
    }

    // Tooltip: the pointer rests on the Run button; it goes when the pointer leaves.
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 450));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(iconButton('Run simulation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('RUN · P'), findsOneWidget);
    await mouse.moveTo(const Offset(700, 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RUN · P'), findsNothing);
    // Tooltip by keyboard: Escape dismisses the one that focus brought up.
    await mouse.moveTo(tester.getCenter(iconButton('Step one second')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('STEP 1 S'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('STEP 1 S'), findsNothing);
    await mouse.moveTo(const Offset(700, 450));
    await tester.pump();

    // Snackbar: D raises one; its close button takes it away.
    await pressKey(tester, LogicalKeyboardKey.keyD, 'd');
    expect(find.byType(KkSnackbar), findsOneWidget);
    await tester.tap(iconButton('Dismiss'));
    await tester.pump();
    expect(find.byType(KkSnackbar), findsNothing);
    expectClean(tester, 'overlays');
  });

  for (final Size size in windowSizes) {
    testWidgets('every screen is reached by rail, drawer and key at ${size.width.round()}px', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: size);
      final List<(String, String, Finder)> screens = <(String, String, Finder)>[
        ('SYSTEMS', 'SYSTEMS', find.byType(SystemsScreen)),
        ('DIAGRAM', 'DIAGRAM', find.byType(DiagramScreen)),
        ('STEPS', 'PROCEDURE', find.byType(ProcedureScreen)),
        ('LOG', 'LOG', find.byType(LogScreen)),
        ('SETUP', 'SETTINGS', find.byType(SettingsScreen)),
        ('INDEX', 'CATALOGUE', find.byType(CatalogueScreen)),
        ('BOARD', 'SITUATION', find.byType(SituationScreen)),
      ];
      // The rail (the bottom bar on a phone).
      for (final (String rail, String _, Finder target) in screens) {
        await tester.tap(inRail(rail));
        await tester.pumpAndSettle();
        expect(target, findsOneWidget, reason: 'rail $rail');
      }
      // The drawer.
      for (final (String _, String drawer, Finder target) in screens) {
        await tester.tap(iconButton('Menu').last);
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(ConsoleDrawer), matching: find.text(drawer)));
        await tester.pumpAndSettle();
        expect(find.byType(ConsoleDrawer), findsNothing);
        expect(target, findsOneWidget, reason: 'drawer $drawer');
      }
      // The keys.
      const List<(LogicalKeyboardKey, String)> keys = <(LogicalKeyboardKey, String)>[
        (LogicalKeyboardKey.digit2, '2'),
        (LogicalKeyboardKey.digit3, '3'),
        (LogicalKeyboardKey.digit4, '4'),
        (LogicalKeyboardKey.digit5, '5'),
        (LogicalKeyboardKey.digit6, '6'),
        (LogicalKeyboardKey.digit7, '7'),
        (LogicalKeyboardKey.digit1, '1'),
      ];
      for (int i = 0; i < keys.length; i++) {
        await pressKey(tester, keys[i].$1, keys[i].$2);
        await tester.pumpAndSettle();
        expect(screens[i].$3, findsOneWidget, reason: 'key ${keys[i].$2}');
      }
      expectClean(tester, 'navigation at $size');
    });
  }

  // The snackbars stack at the bottom left, beside the rail (above the bars on
  // a phone). Whatever they say, they must not lie over the control the
  // operator needs next while an incident is being handled.
  for (final Size size in const <Size>[...windowSizes, Size(667, 375), Size(568, 320)]) {
    testWidgets('snackbars leave the next control free through an incident at ${size.width.round()} x '
        '${size.height.round()}', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: size);
      final Station station = rig.station;

      /// Fails when a snackbar on screen lies over [control]; returns how many
      /// snackbars were up, so the check is known to have had something to check.
      int expectFree(Finder control, String what) {
        expect(control, findsOneWidget, reason: what);
        final Rect r = tester.getRect(control);
        final Rect window = Offset.zero & size;
        expect(window.overlaps(r), isTrue, reason: '$what is on screen at $r');
        int up = 0;
        for (final Element e in find.byType(KkSnackbar).evaluate()) {
          up++;
          final Rect bar = tester.getRect(find.byWidget(e.widget));
          expect(bar.overlaps(r), isFalse, reason: 'a snackbar at $bar covers $what at $r');
        }
        return up;
      }

      // Every level raises a snackbar here, so that there is always one to be in the way.
      rig.settings.setNotifyAll(on: true);
      station.triggerIncident();
      await tick(tester, rig, 2);
      expect(find.byType(KkSnackbar), findsWidgets, reason: 'the caution line is up');

      // The full-screen alarm empties the stack and nothing is added under it.
      await tick(tester, rig, 4);
      await tester.pumpAndSettle();
      final Finder acknowledge = find.descendant(of: find.byType(KkEmergency), matching: button('acknowledge'));
      expect(expectFree(acknowledge, 'Acknowledge'), 0);
      await tester.tap(acknowledge);
      await tester.pumpAndSettle();
      expect(station.phase, IncidentPhase.acknowledged);

      // The board: the way to the procedure, with whatever the plant has said since.
      await tick(tester, rig, 2);
      await tester.ensureVisible(button('procedure'));
      await tester.pumpAndSettle();
      expectFree(button('procedure'), 'Procedure');
      await tester.tap(button('procedure'));
      await tester.pumpAndSettle();
      expect(find.byType(ProcedureScreen), findsOneWidget);

      // Every step, with the snackbars of the steps before still up.
      for (int step = 2; step <= 6; step++) {
        final Finder execute = find.byWidgetPredicate(
          (Widget w) => w is KkButton && (w.semanticLabel ?? '').startsWith('Execute step $step'),
          description: 'the button of step $step',
        );
        if (step > 2) expect(find.byType(KkSnackbar), findsWidgets, reason: 'the step before was announced');
        // (In a low window the button may have to be scrolled to first.)
        await tester.ensureVisible(execute);
        await tester.pumpAndSettle();
        expectFree(execute, 'step $step');
        await tester.tap(execute);
        await tester.pumpAndSettle();
        if (step == 3 || step == 5) {
          // These two ask first. The question lies over the page and its
          // snackbars: a press on its button reaches the button.
          final Finder yes = find.descendant(of: find.byType(KkDialog), matching: button('execute'));
          final HitTestResult hit = tester.hitTestOnBinding(tester.getCenter(yes));
          for (final Element e in find.byType(KkSnackbar).evaluate()) {
            expect(hit.path.map((HitTestEntry entry) => entry.target), isNot(contains(e.renderObject)));
          }
          await tester.tap(yes);
          await tester.pumpAndSettle();
        }
        expect(station.procedure[step - 1].status, StepStatus.done, reason: 'step $step was carried out by the press');
      }
      await tester.pump(const Duration(seconds: 6));
      expectClean(tester, 'incident at $size');
    });
  }
}
