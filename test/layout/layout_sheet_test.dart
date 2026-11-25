import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/layout_sheet.dart';
import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('layout sheet', (WidgetTester tester) async {
    await pumpKkSheet(tester, const LayoutSheet());
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'layout_sheet');
  });

  testWidgets('layout sheet, alert theme', (WidgetTester tester) async {
    await pumpKkSheet(tester, const LayoutSheet(), condition: KkCondition.alert);
    expect(tester.takeException(), isNull);
    await expectKkGolden(tester, 'layout_sheet_alert');
  });

  testWidgets('layout sheet is laid out without overflow at phone and wall widths', (WidgetTester tester) async {
    for (final double width in <double>[1440, 1024, 2560]) {
      await pumpKkSheet(tester, const LayoutSheet(), width: width, pixelRatio: 1);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
