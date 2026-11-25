import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/procedure_screen.dart';
import 'app_harness.dart';

KkSequence _steps(WidgetTester tester) => tester.widget<KkSequence>(find.byType(KkSequence));

/// The big button that carries out the active step.
Finder _next() => find.byWidgetPredicate(
  (Widget w) => w is KkButton && (w.semanticLabel ?? '').startsWith('Execute step'),
  description: 'the execute button',
);

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the procedure lays out and follows the plant', '/procedure', (
    WidgetTester tester,
    Rig rig,
    Size size,
  ) async {
    expect(find.byType(ProcedureScreen), findsOneWidget);
    expect(_steps(tester).steps, hasLength(6));
    expect(find.byType(KkConsensus), findsOneWidget);
    expect(find.byType(KkTimer), findsNWidgets(2));
    expect(find.byType(KkModeStrip), findsOneWidget);
    final bool incident = rig.station.phase != IncidentPhase.none;
    expect(_next(), incident ? findsOneWidget : findsNothing);
    expect(find.text('NO ACTIVE PROCEDURE'), incident ? findsNothing : findsOneWidget);
    // Live: the incident clock runs with the plant.
    final KkTimer before = tester.widget<KkTimer>(find.byType(KkTimer).first);
    await tick(tester, rig, 3);
    final KkTimer after = tester.widget<KkTimer>(find.byType(KkTimer).first);
    expect(after.value! - before.value!, incident ? const Duration(seconds: 3) : Duration.zero);
  });

  runsWithMotion('the procedure runs with motion on', '/procedure');

  testWidgets('the whole recovery: drill, full-screen alarm, six steps, standby', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/procedure');
    final Station station = rig.station;

    await tester.tap(button('start drill'));
    await tester.pump();
    expect(station.phase, IncidentPhase.caution);
    await tick(tester, rig, 5);
    await tester.pumpAndSettle();

    // Critical: the alarm covers everything until it is acknowledged.
    expect(station.phase, IncidentPhase.critical);
    expect(find.byType(KkEmergency), findsOneWidget);
    expect(KeikaiApp.conditionOf(tester.element(find.byType(KkEmergency))), KkCondition.alert);
    await tester.tap(button('acknowledge'));
    await tester.pumpAndSettle();
    expect(find.byType(KkEmergency), findsNothing);
    expect(station.phase, IncidentPhase.acknowledged);
    expect(_steps(tester).steps[0].status, KkStepStatus.done);
    expect(_steps(tester).steps[1].status, KkStepStatus.active);

    // Step 2 runs at once and says so.
    await tester.tap(_next());
    await tester.pumpAndSettle();
    expect(_steps(tester).steps[1].status, KkStepStatus.done);
    expect(
      find.descendant(of: find.byType(KkSnackbar), matching: find.text('START AUX PUMP COMPLETE')),
      findsOneWidget,
    );

    // Step 3 asks first: Cancel changes nothing, Execute closes the valve.
    await tester.tap(_next());
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsOneWidget);
    await tester.tap(button('cancel'));
    await tester.pumpAndSettle();
    expect(_steps(tester).steps[2].status, KkStepStatus.active);
    await tester.tap(_next());
    await tester.pumpAndSettle();
    await tester.tap(button('execute'));
    await tester.pumpAndSettle();
    expect(_steps(tester).steps[2].status, KkStepStatus.done);
    expect(station.phase, IncidentPhase.recovering);

    // Step 4, step 5 (asks again), step 6.
    await tester.tap(_next());
    await tester.pumpAndSettle();
    await tester.tap(_next());
    await tester.pumpAndSettle();
    await tester.tap(button('execute'));
    await tester.pumpAndSettle();
    await tester.tap(_next());
    await tester.pumpAndSettle();
    expect(_steps(tester).steps.every((KkSequenceStep s) => s.status == KkStepStatus.done), isTrue);
    expect(_next(), findsNothing);
    expect(find.text('PROCEDURE COMPLETE'), findsOneWidget);

    // The plant comes back by itself once the pressure is up again.
    await tick(tester, rig, 30);
    expect(station.phase, IncidentPhase.none);
    expect(KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))), KkCondition.standby);
    expect(
      tester.widget<KkConsensus>(find.byType(KkConsensus)).voters.every((KkVoter v) => v.vote == KkVote.go),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'recovery');
  });

  testWidgets('the emergency stop asks, then trips the pump and raises the alarm', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/procedure');
    final Finder stop = find.byType(KkFab);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsOneWidget);
    expect(tester.widget<KkDialog>(find.byType(KkDialog)).level, KkLevel.critical);
    await tester.tap(button('cancel'));
    await tester.pumpAndSettle();
    expect(rig.station.phase, IncidentPhase.none);

    await tester.tap(stop);
    await tester.pumpAndSettle();
    await tester.tap(button('stop'));
    await tester.pumpAndSettle();
    expect(rig.station.phase, IncidentPhase.critical);
    expect(rig.station.manualTrip, isTrue);
    final KkEmergency alarm = tester.widget<KkEmergency>(find.byType(KkEmergency));
    expect(alarm.cjk, '緊急停止');
    expect(alarm.code, 'E-0001 · SEC-04');
    // The alarm is modal: Escape does not take it down.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(KkEmergency), findsOneWidget);
    // Enter on the focused button acknowledges.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(KkEmergency), findsNothing);
    expect(rig.station.phase, IncidentPhase.acknowledged);
    // No second stop while the plant is in alert.
    expect(tester.widget<KkFab>(stop).onPressed, isNull);
    expectClean(tester, 'emergency stop');
  });

  testWidgets('Reset asks, then puts the plant back', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/procedure');
    // The plant's Reset, not the hold timer's.
    final Finder reset = find.byWidgetPredicate((Widget w) => w is KkButton && w.label == 'reset' && w.cjk == '復帰');
    expect(tester.widget<KkButton>(reset).onPressed, isNull);
    await raiseIncident(tester, rig);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(KkDialog), matching: button('reset')));
    await tester.pumpAndSettle();
    expect(rig.station.phase, IncidentPhase.none);
    expect(_steps(tester).steps.every((KkSequenceStep s) => s.status == KkStepStatus.pending), isTrue);
    expect(KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))), KkCondition.standby);
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'reset');
  });

  testWidgets('the hold timer starts, stops, resets and reports when it runs out', (WidgetTester tester) async {
    await pumpApp(tester, route: '/procedure', motion: true);
    await tester.pump(const Duration(seconds: 2));
    Finder hold(String label) =>
        find.byWidgetPredicate((Widget w) => w is KkButton && w.semanticLabel == '$label hold timer');
    final KkTimerController controller = tester.widget<KkTimer>(find.byType(KkTimer).last).controller!;
    expect(find.text('01:00.00', findRichText: true), findsOneWidget);
    expect(controller.isRunning, isFalse);

    await tester.ensureVisible(hold('Start'));
    await tester.pump();
    await tester.tap(hold('Start'));
    await tester.pump();
    expect(controller.isRunning, isTrue);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(controller.elapsed.inMilliseconds, closeTo(10000, 40));
    expect(find.textContaining('00:50', findRichText: true), findsOneWidget);

    await tester.tap(hold('Stop'));
    await tester.pump();
    expect(controller.isRunning, isFalse);
    final Duration held = controller.elapsed;
    await tester.pump(const Duration(seconds: 5));
    expect(controller.elapsed, held, reason: 'stopped');

    await tester.tap(hold('Reset'));
    await tester.pump();
    expect(controller.elapsed, Duration.zero);
    expect(find.text('01:00.00', findRichText: true), findsOneWidget);

    await tester.tap(hold('Start'));
    await tester.pump();
    for (int i = 0; i < 61; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(find.descendant(of: find.byType(KkSnackbar), matching: find.text('HOLD TIME ELAPSED')), findsOneWidget);
    expect(find.text('00:00.00', findRichText: true), findsOneWidget);
    expect(controller.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'hold timer');
  });
}
