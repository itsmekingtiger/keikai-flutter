import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/model/settings.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/settings_screen.dart';
import 'app_harness.dart';

Finder _switch(String label) =>
    find.byWidgetPredicate((Widget w) => w is KkSwitch && w.label == label, description: 'the $label switch');

Finder _slider(String en) =>
    find.byWidgetPredicate((Widget w) => w is KkSlider && w.en == en, description: 'the $en slider');

Finder _checkbox(String label) =>
    find.byWidgetPredicate((Widget w) => w is KkCheckbox && w.label == label, description: 'the $label checkbox');

KeikaiThemeData _theme(WidgetTester tester) => KeikaiTheme.of(tester.element(find.byType(KkScreen)));

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the settings lay out', '/settings', (WidgetTester tester, Rig rig, Size size) async {
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(KkPanel), findsNWidgets(4));
    expect(find.byType(KkTextField), findsNWidgets(2));
    expect(find.byType(KkSlider), findsNWidgets(3));
    expect(find.byType(KkDatePicker), findsOneWidget);
    expect(find.byType(KkTimePicker), findsOneWidget);
    // Two columns of panels from 840px of body width, one below.
    final Rect first = tester.getRect(find.byType(KkPanel).at(0));
    final Rect display = tester.getRect(find.byWidgetPredicate((Widget w) => w is KkPanel && w.code == 'DSP'));
    if (size.width >= 1000) {
      expect(display.left, greaterThan(first.right));
    } else {
      expect(display.top, greaterThan(first.bottom));
    }
    // Live: the display panel names the condition on screen.
    expect(
      tester.widget<KkPanel>(find.byWidgetPredicate((Widget w) => w is KkPanel && w.code == 'DSP')).meta,
      KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))).name.toUpperCase(),
    );
    await tick(tester, rig, 2);
  });

  runsWithMotion('the settings run with motion on', '/settings');

  testWidgets('the call sign is taken only when it is valid, and shows in the command bar', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester, route: '/settings');
    final Finder field = find.byType(EditableText).first;
    await tester.enterText(field, 'op');
    await tester.pump();
    expect(find.text('FORMAT AA-00 · TWO LETTERS, TWO DIGITS'), findsOneWidget);
    expect(rig.settings.operator, 'OP-07');
    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('CALL SIGN REQUIRED'), findsOneWidget);
    await tester.enterText(field, 'kx-12');
    await tester.pump();
    expect(find.text('CALL SIGN REQUIRED'), findsNothing);
    expect(rig.settings.operator, 'KX-12');
    expect(tester.widget<KkCommandCell>(find.byType(KkCommandCell).first).value, 'KX-12');
    expect(tester.widget<KkPanel>(find.byType(KkPanel).first).meta, 'KX-12');
    expectClean(tester, 'call sign');
  });

  testWidgets('node, duty and notes are stored as they are set', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings');
    await tester.tap(find.byWidgetPredicate((Widget w) => w is KkSelect, description: 'the node select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NODE 03').last);
    await tester.pumpAndSettle();
    expect(rig.settings.node, 'NODE 03');
    expect(tester.widget<KkCommandBar>(find.byType(KkCommandBar)).node, 'HQ-03 · NODE 03');

    await tester.tap(find.text('ENGINEER'));
    await tester.pump();
    expect(rig.settings.duty, Duty.engineer);

    await _show(tester, find.byType(EditableText).last);
    await tester.enterText(find.byType(EditableText).last, '보조 펌프 점검 요망');
    await tester.pump();
    expect(rig.settings.notes, '보조 펌프 점검 요망');
    expect(find.text('011 / 120'), findsOneWidget);
    expectClean(tester, 'operation');
  });

  testWidgets('the display settings act on the whole app at once', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings');
    final Finder condition = find.byWidgetPredicate(
      (Widget w) => w is KkSegmented,
      description: 'the condition switch',
    );

    await tester.tap(find.descendant(of: condition, matching: find.text('ALERT')));
    await tester.pumpAndSettle();
    expect(rig.settings.conditionMode, ConditionMode.alert);
    expect(_theme(tester).condition, KkCondition.alert);
    await tester.tap(find.descendant(of: condition, matching: find.text('STANDBY')));
    await tester.pumpAndSettle();
    expect(_theme(tester).condition, KkCondition.standby);
    // Pinned to standby, the screen stays orange through an incident.
    await raiseIncident(tester, rig);
    expect(rig.station.alert, isTrue);
    expect(_theme(tester).condition, KkCondition.standby);
    await tester.tap(find.descendant(of: condition, matching: find.text('AUTO')));
    await tester.pumpAndSettle();
    expect(_theme(tester).condition, KkCondition.alert);
    rig.station.reset();
    await tester.pumpAndSettle();
    expect(_theme(tester).condition, KkCondition.standby);

    expect(_theme(tester).motion.enabled, isFalse);
    expect(tester.widget<KkSlider>(_slider('time scale')).onChanged, isNull, reason: 'no motion, no time scale');
    await tester.tap(_switch('motion'));
    await tester.pump();
    expect(rig.settings.motion, isTrue);
    expect(_theme(tester).motion.enabled, isTrue);
    await tester.tap(_switch('motion'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_theme(tester).motion.enabled, isFalse);

    expect(tester.widget<KkCrt>(find.byType(KkCrt)).scanlines, isFalse);
    await tester.tap(_switch('crt'));
    await tester.pump();
    expect(tester.widget<KkCrt>(find.byType(KkCrt)).scanlines, isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the page survives the texture');
    await tester.tap(_switch('crt'));
    await tester.pump();

    await tester.tap(_switch('dense rows'));
    await tester.pump();
    expect(rig.settings.dense, isTrue);

    await _show(tester, _checkbox('glitch and flash on alert'));
    await tester.tap(_checkbox('glitch and flash on alert'));
    await tester.pump();
    expect(rig.settings.glitch, isFalse);
    expect(tester.widget<KeikaiApp>(find.byType(KeikaiApp)).glitchOnAlert, isFalse);

    await _show(tester, find.text('FAHRENHEIT °F'));
    await tester.tap(find.text('FAHRENHEIT °F'));
    await tester.pump();
    expect(rig.settings.tempUnit, TempUnit.fahrenheit);
    final KkCommandCell coolant = tester.widget<KkCommandCell>(
      find.byWidgetPredicate((Widget w) => w is KkCommandCell && w.label == 'coolant'),
    );
    expect(coolant.value, endsWith('°F'));
    expect(coolant.value, startsWith(kkFixed(rig.station.coolantTemp.value * 9 / 5 + 32, digits: 3, decimals: 1)));
    expectClean(tester, 'display');
  });

  testWidgets('the two specimens show each condition in its own colours and mark the one on screen', (
    WidgetTester tester,
  ) async {
    final Rig rig = await pumpApp(tester, route: '/settings');
    expect(find.byType(KkConditionScope), findsNWidgets(2));
    Finder specimen(KkCondition condition) =>
        find.byWidgetPredicate((Widget w) => w is KkConditionScope && w.condition == condition);
    KkColors colours(KkCondition condition) =>
        tester.element(find.descendant(of: specimen(condition), matching: find.byType(KkBox)).first).kk.colors;
    Finder now(KkCondition condition) => find.descendant(of: specimen(condition), matching: find.text('NOW'));

    // Each is drawn in its own palette, whatever the screen around it is in.
    final KkColors standby = colours(KkCondition.standby);
    final KkColors alert = colours(KkCondition.alert);
    expect(standby.signal, isNot(alert.signal));
    expect(tester.element(find.byType(KkScreen)).kk.colors.signal, standby.signal);
    expect(now(KkCondition.standby), findsOneWidget);
    expect(now(KkCondition.alert), findsNothing);
    // Side by side, the same size.
    final Rect a = tester.getRect(specimen(KkCondition.standby));
    final Rect b = tester.getRect(specimen(KkCondition.alert));
    expect(b.left, greaterThan(a.right));
    expect(b.size, a.size);

    rig.settings.conditionMode = ConditionMode.alert;
    await tester.pump();
    expect(tester.element(find.byType(KkScreen)).kk.colors.signal, alert.signal);
    expect(colours(KkCondition.standby).signal, standby.signal, reason: 'the standby specimen stays orange');
    expect(colours(KkCondition.alert).signal, alert.signal);
    expect(now(KkCondition.standby), findsNothing);
    expect(now(KkCondition.alert), findsOneWidget);
    expectClean(tester, 'specimens');
  });

  testWidgets('the sliders set time scale and text scale, by keyboard too', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings', settings: AppSettings());
    await tester.pump(const Duration(seconds: 3));
    tester.widget<KkSlider>(_slider('time scale')).onChanged!(2);
    await tester.pump();
    expect(rig.settings.timeScale, 2);
    expect(_theme(tester).motion.timeScale, 2);

    // One arrow press is one division: 0.05 of text scale.
    await tester.tap(_slider('text scale'));
    await tester.pump();
    final double set = rig.settings.textScale;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(rig.settings.textScale, closeTo(set + 0.05, 1e-9));
    expect(_theme(tester).type.scale, closeTo(set + 0.05, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(rig.settings.textScale, 0.9);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(rig.settings.textScale, 1.3);
    await tester.pump(const Duration(seconds: 2));
    expectClean(tester, 'the largest type');
    rig.settings.motion = false;
    await tester.pump();
  });

  testWidgets('the notify boxes: one for all, one per level, and a test', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings', size: const Size(1440, 1400));
    KkCheckbox master() => tester.widget<KkCheckbox>(_checkbox('every level'));
    expect(master().value, isNull, reason: 'two of four');
    await tester.tap(_checkbox('every level'));
    await tester.pump();
    expect(rig.settings.notify, hasLength(4));
    expect(master().value, isTrue);
    await tester.tap(_checkbox('every level'));
    await tester.pump();
    expect(rig.settings.notify, isEmpty);
    expect(master().value, isFalse);
    await tester.tap(_checkbox('CRITICAL'));
    await tester.pump();
    expect(rig.settings.notify, <KkLevel>{KkLevel.critical});
    expect(master().value, isNull);

    tester.widget<KkSlider>(_slider('alarm volume')).onChanged!(85);
    await tester.pump();
    expect(rig.settings.volume, 85);
    await tester.tap(button('test'));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(KkSnackbar), matching: find.text('NOTIFICATION TEST · VOLUME 085 %')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
    expectClean(tester, 'notify');
  });

  testWidgets('the maintenance day and the shift start are picked', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings', size: const Size(1440, 1400));
    expect(rig.settings.maintenance, DateTime.utc(2026, 12, 8));
    await tester.tap(
      find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == '2026-12-15', description: 'day 15'),
    );
    await tester.pump();
    expect(rig.settings.maintenance, DateTime.utc(2026, 12, 15));
    expect(
      tester.widget<KkPanel>(find.byWidgetPredicate((Widget w) => w is KkPanel && w.code == 'MNT')).meta,
      '2026-12-15',
    );

    // The hours segment takes the focus on a press; arrow up adds an hour.
    await tester.tap(find.descendant(of: find.byType(KkTimePicker), matching: find.text('06')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rig.settings.shiftStart.compareTo(const KkTime(7, 0)), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(rig.settings.shiftStart.compareTo(const KkTime(7, 15)), 0, reason: 'minutes step by a quarter');
    expectClean(tester, 'maintenance');
  });

  testWidgets('Reset asks, then puts every setting back', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, route: '/settings');
    await tester.enterText(find.byType(EditableText).first, 'KX-12');
    await tester.pump();
    rig.settings
      ..crt = true
      ..dense = true
      ..tempUnit = TempUnit.fahrenheit
      ..conditionMode = ConditionMode.alert;
    await tester.pumpAndSettle();
    await tester.tap(button('reset'));
    await tester.pumpAndSettle();
    await tester.tap(button('cancel'));
    await tester.pumpAndSettle();
    expect(rig.settings.operator, 'KX-12');
    await tester.tap(button('reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(KkDialog), matching: button('reset')));
    // The reset turns motion back on, so from here the frames are counted by hand.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(KkDialog), findsNothing);
    expect(rig.settings.operator, 'OP-07');
    expect(rig.settings.crt, isFalse);
    expect(rig.settings.dense, isFalse);
    expect(rig.settings.tempUnit, TempUnit.celsius);
    expect(rig.settings.conditionMode, ConditionMode.auto);
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'OP-07');
    // A reset turns motion back on: let the entrances finish before the end.
    expect(rig.settings.motion, isTrue);
    await tester.pump(const Duration(seconds: 6));
    rig.settings.motion = false;
    await tester.pump();
    expectClean(tester, 'reset');
  });
}
