import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/inputs_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('inputs sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const InputsSheet());
    await expectKkGolden(tester, 'inputs_sheet');
  });

  testWidgets('inputs sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const InputsSheet(), condition: KkCondition.alert);
    await expectKkGolden(tester, 'inputs_sheet_alert');
  });
}
