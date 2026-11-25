import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'app_harness.dart';

void main() {
  setUpAll(loadKkFonts);

  const Map<String, String> screens = <String, String>{
    'situation': '/',
    'systems': '/systems',
    'diagram': '/diagram',
    'procedure': '/procedure',
    'log': '/log',
    'settings': '/settings',
    'catalogue': '/catalogue',
  };

  for (final MapEntry<String, String> screen in screens.entries) {
    testWidgets('${screen.key} at 1440 x 900', (WidgetTester tester) async {
      final Rig rig = await pumpApp(tester, pixelRatio: 2, route: screen.value);
      await tick(tester, rig, 3);
      expectClean(tester, screen.key);
      await expectAppGolden(tester, 'app_${screen.key}');
    });
  }

  testWidgets('situation in alert', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, pixelRatio: 2);
    rig.station.triggerIncident();
    await tick(tester, rig, 7);
    rig.station.acknowledge();
    await tick(tester, rig, 2);
    expect(KeikaiApp.conditionOf(tester.element(find.byType(KkScreen))), KkCondition.alert);
    expectClean(tester, 'situation in alert');
    await expectAppGolden(tester, 'app_situation_alert');
  });

  testWidgets('situation on a phone', (WidgetTester tester) async {
    final Rig rig = await pumpApp(tester, size: const Size(390, 844), pixelRatio: 2);
    await tick(tester, rig, 3);
    expectClean(tester, 'situation on a phone');
    await expectAppGolden(tester, 'app_situation_compact');
  });
}
