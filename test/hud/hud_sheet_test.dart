import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/hud_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('hud sheet, standby', (WidgetTester tester) async {
    await pumpKkSheet(tester, const HudSheet());
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'hud_sheet');
  });

  testWidgets('hud sheet, alert', (WidgetTester tester) async {
    await pumpKkSheet(tester, const HudSheet(), condition: KkCondition.alert);
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'hud_sheet_alert');
  });
}
