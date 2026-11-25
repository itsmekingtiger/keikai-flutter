import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/inputs/field.dart';
import 'package:keikai/src/inputs/menu.dart';
import 'package:keikai/src/inputs/text_field.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadKkFonts);

  testWidgets('smoke', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changed;
    await pumpKk(
      tester,
      KkColumn(
        gap: 24,
        cross: KkCrossAlign.start,
        children: <Widget>[
          KkTextField(
            width: 320,
            controller: controller,
            cjk: '識別符号',
            en: 'call sign',
            isRequired: true,
            placeholder: 'SEC-04',
            support: 'SECTOR CODE · 6 CHARS',
            maxLength: 12,
            onChanged: (String v) => changed = v,
          ),
          const KkTextField(width: 320, cjk: '水圧', en: 'pressure', suffix: 'kPa', mono: true, error: 'BELOW LIMIT 120', icon: KkIcons.gauge),
          const KkTextField(width: 320, en: 'disabled', enabled: false, placeholder: 'LOCKED'),
          const KkTextField(width: 320, cjk: '所見', en: 'remarks', maxLines: null, placeholder: '두 줄 이내로 적는다.'),
          KkMenuAnchor<String>(
            initiallyOpen: true,
            entries: const <KkMenuEntry<String>>[
              KkMenuLabel<String>('sector'),
              KkMenuItem<String>(value: 'ack', label: 'acknowledge', cjk: '確認', icon: KkIcons.check, shortcut: 'CTRL+K'),
              KkMenuItem<String>(value: 'mute', label: 'mute alarm', checked: true),
              KkMenuItem<String>(value: 'x', label: 'unavailable', enabled: false),
              KkMenuSeparator<String>(),
              KkMenuItem<String>(value: 'trip', label: 'trip breaker', cjk: '遮断', icon: KkIcons.power, danger: true),
            ],
            builder: (BuildContext context, KkMenuController menu) => KkPressable(
              onPressed: menu.toggle,
              builder: (BuildContext context, KkStates s) => const KkBox(
                width: 120,
                height: 32,
                alignment: Alignment.center,
                child: KkText.en('actions', size: 13),
              ),
            ),
          ),
        ],
      ),
      size: const Size(640, 760),
      pixelRatio: 2,
      padding: const EdgeInsets.all(24),
    );
    await tester.enterText(find.byType(EditableText).first, 'SEC-0');
    await tester.pump();
    expect(changed, 'SEC-0');
    expect(tester.getSize(find.byType(KkFieldBox).first).height, 36);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await expectLater(find.byType(KeikaiApp), matchesGoldenFile('goldens/smoke.png'));
  });
}
