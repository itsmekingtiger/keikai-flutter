import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/table_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('table sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const TableSheet());
    await expectKkGolden(tester, 'table_sheet');
  });

  testWidgets('table sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const TableSheet(), condition: KkCondition.alert);
    await expectKkGolden(tester, 'table_sheet_alert');
  });
}
