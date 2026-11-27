import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/capture.dart';
import 'app_harness.dart';

/// Frames for an animation of the console: it boots, runs for a few seconds,
/// meets the scripted incident and is acknowledged.
///
/// Does nothing in a normal test run. Under `flutter test --update-goldens`
/// it writes `test/example/frames/incident/NNNN.png`, which
/// `tool/assemble_frames.sh test/example/frames/incident incident.webp 20`
/// turns into one file.
void main() {
  setUpAll(loadKkFonts);

  testWidgets('capture: boot, live board, incident, acknowledge', (WidgetTester tester) async {
    if (!autoUpdateGoldenFiles) return;
    const int fps = 20;
    final Rig rig = await pumpApp(tester, size: const Size(1280, 800), motion: true, boot: true);
    await captureKkFrames(
      tester,
      'incident',
      frames: 16 * fps,
      step: const Duration(milliseconds: 1000 ~/ fps),
      onFrame: (int frame) async {
        // The plant ticks once a second, as it does when the app runs by itself.
        if (frame > 0 && frame % fps == 0) rig.station.tick();
        if (frame == 6 * fps) rig.station.triggerIncident();
        if (frame == 13 * fps) rig.station.acknowledge();
      },
    );
    expect(KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))), KkCondition.alert);
    // Let what is still timed (snackbars, the alarm's blink) run out.
    await tester.pump(const Duration(seconds: 8));
  });
}
