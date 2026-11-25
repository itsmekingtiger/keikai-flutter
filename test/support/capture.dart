import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// Writes [frames] PNG frames of the whole screen, [step] apart in animation
/// time, as `frames/<name>/0000.png`, `0001.png` … next to the test file.
///
/// Only does anything under `flutter test --update-goldens`; in a normal test
/// run it returns at once, so capture tests never fail for missing frames.
/// The frames are assembled into an animation by `tool/assemble_frames.sh`.
Future<void> captureKkFrames(
  WidgetTester tester,
  String name, {
  required int frames,
  Duration step = const Duration(milliseconds: 40),
  Future<void> Function(int frame)? onFrame,
}) async {
  if (!autoUpdateGoldenFiles) return;
  for (int i = 0; i < frames; i++) {
    if (onFrame != null) await onFrame(i);
    await expectLater(
      find.byType(KeikaiApp),
      matchesGoldenFile('frames/$name/${i.toString().padLeft(4, '0')}.png'),
    );
    await tester.pump(step);
  }
}
