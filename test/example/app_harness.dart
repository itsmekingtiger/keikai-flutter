import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/app.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/model/settings.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/model/station.dart';

export '../support/harness.dart' show loadKkFonts;

/// The instant every test plant starts at.
final DateTime epoch = DateTime.utc(2026, 11, 24, 14, 2, 31);

/// The window sizes every screen is tried at: a phone, a tablet in portrait,
/// a laptop and a desktop monitor.
const List<Size> windowSizes = <Size>[Size(380, 760), Size(720, 900), Size(1280, 800), Size(1920, 1080)];

/// The plant and the settings behind a pumped app.
class Rig {
  Rig(this.station, this.settings);

  final Station station;
  final AppSettings settings;
}

/// Pumps the whole example app on a window of [size].
///
/// The plant is seeded and does not tick by itself: call `station.tick()` and
/// pump. Motion is off unless [motion] is true (then pump explicit durations
/// and never call `pumpAndSettle`).
Future<Rig> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  double pixelRatio = 1,
  String route = '/',
  bool motion = false,
  bool boot = false,
  Station? station,
  AppSettings? settings,
  ConditionMode? condition,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  addTearDown(tester.view.reset);
  final Rig rig = Rig(station ?? Station(seed: 7, epoch: epoch), settings ?? AppSettings(motion: motion));
  if (condition != null) rig.settings.conditionMode = condition;
  await tester.pumpWidget(
    KeikaiExampleApp(station: rig.station, settings: rig.settings, boot: boot, autoStart: false, initialRoute: route),
  );
  await tester.pump();
  return rig;
}

/// Advances the plant by [seconds] ticks, pumping a frame after each.
Future<void> tick(WidgetTester tester, Rig rig, [int seconds = 1]) async {
  for (int i = 0; i < seconds; i++) {
    rig.station.tick();
    await tester.pump();
  }
}

/// Fails with [where] when the last frames threw or reported an overflow.
void expectClean(WidgetTester tester, String where) {
  expect(tester.takeException(), isNull, reason: where);
}

/// Presses a character key the way a keyboard does: down with the character,
/// then up.
Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key, String character) async {
  await tester.sendKeyDownEvent(key, character: character);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

/// The screen that is on top.
Finder screen<T extends Widget>() => find.byType(T);

/// The text [label] inside the nav rail (or the bottom bar it becomes).
Finder inRail(String label) => find.descendant(of: find.byType(KkNavRail), matching: find.text(label));

/// Puts the plant into the acknowledged coolant incident: the alert condition
/// without the full-screen alarm.
Future<void> raiseIncident(WidgetTester tester, Rig rig) async {
  rig.station.triggerIncident();
  await tick(tester, rig, 6);
  rig.station.acknowledge();
  await tick(tester, rig);
}

/// Declares one test per window size and condition that opens [route] and
/// runs [body]. The app is checked for exceptions before and after.
void forEveryWindow(
  String description,
  String route,
  Future<void> Function(WidgetTester tester, Rig rig, Size size) body,
) {
  for (final Size size in windowSizes) {
    for (final bool alert in <bool>[false, true]) {
      testWidgets('$description at ${size.width.round()} x ${size.height.round()}${alert ? ', alert' : ''}', (
        WidgetTester tester,
      ) async {
        final Rig rig = await pumpApp(tester, size: size, route: route);
        if (alert) await raiseIncident(tester, rig);
        expectClean(tester, 'opening $route');
        await body(tester, rig, size);
        expectClean(tester, 'after the checks');
      });
    }
  }
}

/// Opens [route] with motion on and lets it run for a few seconds, ticking the
/// plant, in both conditions.
void runsWithMotion(String description, String route) {
  for (final bool alert in <bool>[false, true]) {
    testWidgets('$description${alert ? ', alert' : ''}', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, size: const Size(1280, 800), route: route, motion: true);
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expectClean(tester, 'entrance');
      if (alert) {
        rig.station.triggerIncident();
        for (int i = 0; i < 6; i++) {
          rig.station.tick();
          await tester.pump(const Duration(milliseconds: 250));
        }
        rig.station.acknowledge();
      }
      for (int i = 0; i < 8; i++) {
        rig.station.tick();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expectClean(tester, 'running');
    });
  }
}

/// The icon button with [label] as its semantic label.
Finder iconButton(String label) => find.byWidgetPredicate(
  (Widget w) => w is KkIconButton && w.semanticLabel == label,
  description: 'icon button "$label"',
);

/// The button whose Latin label is [label] (as written, before upper-casing).
Finder button(String label) =>
    find.byWidgetPredicate((Widget w) => w is KkButton && w.label == label, description: 'button "$label"');

/// Compares the whole window with `goldens/<name>.png` next to the test file.
/// Run `flutter test --update-goldens` to (re)write the images.
///
/// The images are rendered on Linux; elsewhere glyphs rasterise differently,
/// so the comparison is skipped unless goldens are being updated. (The
/// catalogue screen holds a second `KeikaiApp` for its sheet, hence `first`.)
Future<void> expectAppGolden(WidgetTester tester, String name) async {
  if (!Platform.isLinux && !autoUpdateGoldenFiles) return;
  await expectLater(find.byType(KeikaiApp).first, matchesGoldenFile('goldens/$name.png'));
}
