import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/sheets/foundation_sheet.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('foundation sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const FoundationSheet());
    await expectKkGolden(tester, 'foundation_sheet');
  });

  testWidgets('foundation sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const FoundationSheet(), condition: KkCondition.alert);
    await expectKkGolden(tester, 'foundation_sheet_alert');
  });
}
