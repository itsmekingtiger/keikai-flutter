import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/shell_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('shell sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ShellSheet());
    await expectKkGolden(tester, 'shell_sheet');
  });

  testWidgets('shell sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ShellSheet(), condition: KkCondition.alert);
    await expectKkGolden(tester, 'shell_sheet_alert');
  });
}
