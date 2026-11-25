import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/settings.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/procedure_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/situation_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/metric_detail.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/widgets/sector_detail.dart';
import 'app_harness.dart';

/// The lowest, mean and highest figures of the open metric dialog.
List<KkStat> _figures(WidgetTester tester) =>
    tester.widgetList<KkStat>(find.descendant(of: find.byType(MetricDialog), matching: find.byType(KkStat))).toList();

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the board lays out and follows the plant', '/', (WidgetTester tester, Rig rig, Size size) async {
    expect(find.byType(SituationScreen), findsOneWidget);
    // Whole rows: the grid never leaves a cell hanging outside its width.
    final Rect grid = tester.getRect(find.byType(KkGrid));
    for (final Element cell in find.byType(KkCell).evaluate()) {
      final Rect r = tester.getRect(find.byWidget(cell.widget));
      expect(r.left, greaterThanOrEqualTo(grid.left - 0.01));
      expect(r.right, lessThanOrEqualTo(grid.right + 0.01));
    }
    expect(find.byType(KkStat), findsNWidgets(4));
    expect(find.byType(KkTimeSeries), findsOneWidget);
    expect(find.byType(KkHexMatrix), findsOneWidget);
    expect(find.byType(KkAnnunciator), findsOneWidget);
    expect(find.byType(KkDataLog), findsOneWidget);
    // The events-by-hour map joins the board when there are sixteen columns.
    expect(find.byType(KkHeatmap), size.width >= 1900 ? findsOneWidget : findsNothing);

    // Live: the uptime (or the incident clock) moves with every tick.
    final KkTimer before = tester.widget<KkTimer>(find.byType(KkTimer));
    await tick(tester, rig, 2);
    final KkTimer after = tester.widget<KkTimer>(find.byType(KkTimer));
    expect(after.value! - before.value!, const Duration(seconds: 2));
    final KkStat pressure = tester.widget<KkStat>(find.byType(KkStat).at(1));
    expect(pressure.value, rig.station.coolantPressure.text);
    expect(pressure.level, rig.station.coolantPressure.level);
  });

  runsWithMotion('the board runs with motion on', '/');

  testWidgets('the incident shows on the board: alert bar, mode, critical sector, alarm window', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester);
    expect(find.byType(KkAlertBar), findsNothing);
    expect(tester.widget<KkModeStrip>(find.byType(KkModeStrip)).current, 1);

    await tester.tap(button('drill'));
    await tester.pump();
    expect(rig.station.phase, IncidentPhase.caution);
    expect(tester.widget<KkButton>(button('drill')).onPressed, isNull, reason: 'a drill is running');
    await tick(tester, rig);
    expect(tester.widget<KkAlertBar>(find.byType(KkAlertBar)).level, KkLevel.caution);
    expect(tester.widget<KkModeStrip>(find.byType(KkModeStrip)).target, 2);

    await raiseIncidentFromCaution(tester, rig);
    final KkAlertBar bar = tester.widget<KkAlertBar>(find.byType(KkAlertBar));
    expect(bar.level, KkLevel.critical);
    expect(bar.code, 'E-4127');
    expect(tester.widget<KkModeStrip>(find.byType(KkModeStrip)).current, 2);
    expect(tester.widget<KkPanel>(find.byType(KkPanel).first).level, KkLevel.critical);
    final KkAnnunciator wall = tester.widget<KkAnnunciator>(find.byType(KkAnnunciator));
    expect(wall.tiles.first.state, KkAlarmState.ack);
    final KkHexMatrix matrix = tester.widget<KkHexMatrix>(find.byType(KkHexMatrix));
    expect(matrix.cells[3].level, KkLevel.critical);
    expectClean(tester, 'incident');
  });

  testWidgets('pressing a flashing alarm window acknowledges it, a ring-back window resets it', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester);
    rig.station.alarms[4].state = AlarmState.alarm;
    await tick(tester, rig);
    KkAnnunciator wall() => tester.widget<KkAnnunciator>(find.byType(KkAnnunciator));
    expect(wall().tiles[4].state, KkAlarmState.alarm);
    await tester.ensureVisible(find.text('LINK LOST'));
    await tester.tap(find.text('LINK LOST'));
    await tester.pump();
    expect(rig.station.alarms[4].state, AlarmState.acknowledged);
    expect(wall().tiles[4].state, KkAlarmState.ack);
    rig.station.alarms[4].state = AlarmState.returned;
    await tick(tester, rig);
    expect(wall().tiles[4].state, KkAlarmState.rtn);
    await tester.tap(find.text('LINK LOST'));
    await tester.pump();
    expect(rig.station.alarms[4].state, AlarmState.normal);
    expectClean(tester, 'annunciator');
  });

  testWidgets('a key figure opens the last minute of its metric and follows the plant', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester);
    final Metric pressure = rig.station.coolantPressure;
    await tester.tap(find.byType(KkStat).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(MetricDialog), findsOneWidget);
    expect(tester.widget<KkDialog>(find.byType(KkDialog)).code, 'P-01');

    void expectFigures() {
      final List<double> h = pressure.history;
      final List<KkStat> figures = _figures(tester);
      expect(figures, hasLength(3));
      expect(figures[0].value, pressure.format(h.reduce(math.min)));
      expect(figures[1].value, pressure.format(h.reduce((double a, double b) => a + b) / h.length));
      expect(figures[2].value, pressure.format(h.reduce(math.max)));
      expect(figures[0].unit, 'kPa');
      final KkTimeSeries trace = tester.widget<KkTimeSeries>(
        find.descendant(of: find.byType(MetricDialog), matching: find.byType(KkTimeSeries)),
      );
      expect(trace.series.single.values, h);
      expect(trace.thresholds.map((KkThreshold t) => t.value), <double>[pressure.warn, pressure.crit]);
    }

    expectFigures();
    // Three across in a dialog of full width.
    final Rect first = tester.getRect(find.byWidget(_figures(tester)[0]));
    final Rect last = tester.getRect(find.byWidget(_figures(tester)[2]));
    expect(last.left, greaterThan(first.right));
    expect(last.top, first.top);

    // The incident drags the pressure down: the lowest figure turns critical.
    rig.station.triggerIncident();
    await tick(tester, rig, 8);
    expectFigures();
    expect(_figures(tester)[0].level, KkLevel.critical);
    expect(_figures(tester)[2].level, KkLevel.nominal);
    expect(tester.widget<KkDialog>(find.byType(KkDialog)).level, KkLevel.critical);

    rig.station.acknowledge();
    await tick(tester, rig);
    await tester.tap(button('close'));
    await tester.pumpAndSettle();
    expect(find.byType(MetricDialog), findsNothing);
    expectClean(tester, 'metric dialog');
  });

  testWidgets('the coolant temperature opens in the unit the operator chose; figures stack on a phone', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester, size: const Size(380, 760));
    rig.settings.tempUnit = TempUnit.fahrenheit;
    await tester.pump();
    final Metric temp = rig.station.coolantTemp;
    await tester.tap(find.byType(KkStat).first);
    await tester.pumpAndSettle();
    expect(tester.widget<KkDialog>(find.byType(KkDialog)).code, 'T-01');
    final List<KkStat> figures = _figures(tester);
    expect(figures.map((KkStat f) => f.unit), everyElement('°F'));
    expect(figures[0].value, rig.settings.temperature(temp.history.reduce(math.min)));
    expect(figures[2].value, kkFixed(temp.history.reduce(math.max) * 9 / 5 + 32, digits: 3, decimals: 1));
    final KkTimeSeries trace = tester.widget<KkTimeSeries>(
      find.descendant(of: find.byType(MetricDialog), matching: find.byType(KkTimeSeries)),
    );
    expect(trace.series.single.values.last, temp.value * 9 / 5 + 32);
    expect(trace.thresholds.first.value, temp.warn * 9 / 5 + 32);
    // One under the other in the narrow dialog.
    final Rect first = tester.getRect(find.byWidget(figures[0]));
    final Rect second = tester.getRect(find.byWidget(figures[1]));
    expect(second.left, first.left);
    expect(second.top, greaterThanOrEqualTo(first.bottom));
    expect(tester.getRect(find.byType(KkDialog)).width, lessThanOrEqualTo(380));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MetricDialog), findsNothing);
    expectClean(tester, 'metric dialog on a phone');
  });

  testWidgets('a key figure is a control: brackets under the pointer, a ring and Enter from the keyboard', (
    WidgetTester tester,
  ) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await pumpApp(tester);
    final Finder load = find.byType(KkStat).at(2);
    KkBrackets brackets() =>
        tester.widget<KkBrackets>(find.ancestor(of: load, matching: find.byType(KkBrackets)).first);
    KkFocusRing ring() => tester.widget<KkFocusRing>(find.ancestor(of: load, matching: find.byType(KkFocusRing)).first);
    expect(brackets().visible, isFalse);
    expect(ring().visible, isFalse);

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(load));
    await tester.pump();
    expect(brackets().visible, isTrue);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(brackets().visible, isFalse);

    // The focus moves at the end of a frame and shows in the next one.
    Focus.of(tester.element(load)).requestFocus();
    await tester.pump();
    await tester.pump();
    expect(ring().visible, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<KkDialog>(find.byType(KkDialog)).code, 'L-01');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MetricDialog), findsNothing);
    // The figure it was opened from has the focus again.
    expect(ring().visible, isTrue);
    expectClean(tester, 'key figure');
  });

  testWidgets('the alarm counts say what the wall shows, all the way through an incident', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester);
    final Station station = rig.station;
    KkAnnunciator wall() => tester.widget<KkAnnunciator>(find.byType(KkAnnunciator));
    KkWidgetFrame frame() => tester.widget<KkWidgetFrame>(
      find.ancestor(of: find.byType(KkAnnunciator), matching: find.byType(KkWidgetFrame)),
    );
    KkCommandCell cell() =>
        tester.widget<KkCommandCell>(find.byWidgetPredicate((Widget w) => w is KkCommandCell && w.label == 'alarms'));
    KkIconButton bell() => tester.widget<KkIconButton>(
      find.byWidgetPredicate((Widget w) => w is KkIconButton && w.semanticLabel == 'Alarms'),
    );

    /// Every lit window is counted, on the wall's head and in the command bar;
    /// the bell counts the ones that still sound.
    void expectConsistent(String when, {required int lit, required int sounding}) {
      final List<KkAlarmTile> tiles = wall().tiles;
      expect(
        tiles.where((KkAlarmTile t) => t.state != KkAlarmState.normal),
        hasLength(lit),
        reason: '$when: lit windows',
      );
      expect(tiles.where((KkAlarmTile t) => t.state == KkAlarmState.alarm), hasLength(sounding), reason: when);
      expect(station.activeAlarms, lit, reason: when);
      expect(station.soundingAlarms, sounding, reason: when);
      expect(frame().meta, '${kkFixed(lit, digits: 2)} ACTIVE', reason: when);
      expect(cell().value, kkFixed(lit, digits: 2), reason: when);
      expect(
        cell().level,
        sounding > 0 ? KkLevel.critical : (lit > 0 ? KkLevel.caution : KkLevel.nominal),
        reason: when,
      );
      expect(bell().icon, lit > 0 ? KkIcons.bell : KkIcons.bellOff, reason: when);
      expect(bell().badge == null, sounding == 0, reason: '$when: the badge');
      if (sounding > 0) expect((bell().badge! as KkBadge).count, sounding, reason: when);
    }

    expectConsistent('standby', lit: 0, sounding: 0);
    station.triggerIncident();
    await tick(tester, rig, 3);
    expectConsistent('caution: nothing has tripped yet', lit: 0, sounding: 0);

    // Critical: the pressure window flashes under the full-screen alarm.
    await tick(tester, rig, 3);
    expect(station.phase, IncidentPhase.critical);
    expect(wall().tiles.first.state, KkAlarmState.alarm);
    expectConsistent('critical', lit: 1, sounding: 1);

    // Acknowledged: the window stays lit, steady, and stays counted.
    station.acknowledge();
    await tick(tester, rig);
    expect(wall().tiles.first.state, KkAlarmState.ack);
    expectConsistent('acknowledged', lit: 1, sounding: 0);

    // The coolant runs hot: a second window starts to sound.
    for (int i = 0; i < 10 && station.soundingAlarms == 0; i++) {
      await tick(tester, rig);
    }
    expect(wall().tiles[1].state, KkAlarmState.alarm);
    expectConsistent('second alarm', lit: 2, sounding: 1);
    station.acknowledge();
    await tick(tester, rig);
    expectConsistent('both acknowledged', lit: 2, sounding: 0);

    // The procedure brings the plant back; a window whose cause has gone rings
    // back and is still lit, so it is still counted.
    while (station.procedure.any((ProcedureStep s) => s.status == StepStatus.active)) {
      station.advanceProcedure();
      await tick(tester, rig);
    }
    bool rangBack = false;
    for (int i = 0; i < 40 && station.phase != IncidentPhase.none; i++) {
      await tick(tester, rig);
      final int lit = wall().tiles.where((KkAlarmTile t) => t.state != KkAlarmState.normal).length;
      final int sounding = wall().tiles.where((KkAlarmTile t) => t.state == KkAlarmState.alarm).length;
      rangBack = rangBack || wall().tiles.any((KkAlarmTile t) => t.state == KkAlarmState.rtn);
      expectConsistent('recovering, tick $i', lit: lit, sounding: sounding);
    }
    expect(rangBack, isTrue, reason: 'a window rang back on the way');
    expect(station.phase, IncidentPhase.none);
    expectConsistent('standby again', lit: 0, sounding: 0);
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'alarm counts');
  });

  testWidgets('a new alarm glitches the alarm wall, unless the operator switched that off', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester, motion: true);
    await tester.pump(const Duration(seconds: 1));
    // The wall's own glitch: the nearest one above it (the app has one around everything).
    Finder wallGlitch() => find.ancestor(of: find.byType(KkAnnunciator), matching: find.byType(KkGlitch)).first;
    bool underWallGlitch() =>
        find.ancestor(of: find.byType(KkAnnunciator), matching: find.byType(KkGlitch)).evaluate().length == 2;
    expect(underWallGlitch(), isTrue);
    expect(tester.widget<KkGlitch>(wallGlitch()).trigger, 0);

    // The second alarm of the incident (the coolant runs hot) comes after the first was answered.
    rig.station.triggerIncident();
    for (int i = 0; i < 6; i++) {
      rig.station.tick();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(rig.station.alarmsRaised, 1);
    expect(tester.widget<KkGlitch>(wallGlitch()).trigger, 1);
    rig.station.acknowledge();
    for (int i = 0; i < 8 && rig.station.alarmsRaised < 2; i++) {
      rig.station.tick();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(rig.station.alarmsRaised, 2);
    expect(tester.widget<KkGlitch>(wallGlitch()).trigger, 2);
    await tester.pump(const Duration(seconds: 1));

    rig.settings.glitch = false;
    await tester.pump();
    expect(underWallGlitch(), isFalse);
    expect(find.byType(KkAnnunciator), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'alarm wall');
  });

  testWidgets('a sector cell opens its sheet; the sheet closes with its button and with Escape', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('S-04'));
    await tester.pumpAndSettle();
    expect(find.byType(SectorSheet), findsOneWidget);
    expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-04');
    await tester.tap(iconButton('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SectorSheet), findsNothing);

    await tester.tap(find.text('S-08'));
    await tester.pumpAndSettle();
    expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, 'SEC-08');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SectorSheet), findsNothing);
    expectClean(tester, 'sector sheet');
  });

  testWidgets('on a phone the sector sheet comes up from the bottom', (WidgetTester tester) async {
    await pumpApp(tester, size: const Size(380, 760));
    await tester.ensureVisible(find.text('S-04'));
    await tester.tap(find.text('S-04'));
    await tester.pumpAndSettle();
    final Rect sheet = tester.getRect(find.byType(KkSheet));
    expect(sheet.left, 0);
    expect(sheet.width, 380);
    expect(sheet.bottom, 760);
    expect(sheet.top, greaterThanOrEqualTo(760 * 0.4 - 0.01));
    expectClean(tester, 'bottom sheet');
  });

  testWidgets('the busiest sector in the ranking opens its sheet; Procedure goes to the procedure', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester, size: const Size(1440, 2600));
    final List<Sector> ranked = rig.station.sectors.where((Sector s) => s.level != KkLevel.offline).toList()
      ..sort((Sector a, Sector b) => b.load.compareTo(a.load));
    await tester.tap(find.descendant(of: find.byType(KkBarList), matching: find.text(ranked.first.code)));
    await tester.pumpAndSettle();
    expect(tester.widget<KkSheet>(find.byType(KkSheet)).code, ranked.first.code);
    await tester.tap(iconButton('Close'));
    await tester.pumpAndSettle();

    await tester.tap(button('procedure'));
    await tester.pumpAndSettle();
    expect(find.byType(ProcedureScreen), findsOneWidget);
    expectClean(tester, 'ranking');
  });
}

/// From the caution phase to the acknowledged critical phase.
Future<void> raiseIncidentFromCaution(WidgetTester tester, Rig rig) async {
  await tick(tester, rig, 6);
  rig.station.acknowledge();
  await tick(tester, rig);
}
