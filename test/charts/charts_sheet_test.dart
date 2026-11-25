import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/charts_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('charts sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ChartsSheet());
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'charts_sheet');
  });

  testWidgets('charts sheet in the alert theme', (WidgetTester tester) async {
    await pumpKkSheet(tester, const ChartsSheet(), condition: KkCondition.alert);
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'charts_sheet_alert');
  });
}
