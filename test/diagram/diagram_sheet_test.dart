import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/diagram_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('diagram sheet, standby', (WidgetTester tester) async {
    await pumpKkSheet(tester, const DiagramSheet());
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'diagram_sheet');
  });

  testWidgets('diagram sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const DiagramSheet(), condition: KkCondition.alert);
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'diagram_sheet_alert');
  });
}
