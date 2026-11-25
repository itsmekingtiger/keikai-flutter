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
}
