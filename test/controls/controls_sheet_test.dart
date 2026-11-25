import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/controls_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('controls sheet, standby', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ControlsSheet());
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'controls_sheet');
  });

  testWidgets('controls sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ControlsSheet(), condition: KkCondition.alert);
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'controls_sheet_alert');
  });

  testWidgets('controls sheet runs every animation without error', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ControlsSheet(), pixelRatio: 1, motion: true);
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    // Scans, spins and flickers keep the clock running.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('controls sheet fits a phone-width column', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ControlsSheet(), width: 390, pixelRatio: 1);
    expect(tester.takeException(), isNull);
  });
}
