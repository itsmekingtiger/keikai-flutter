// Only the one library an app imports: everything used below must come from
// it, except the two names the test needs to stand in for the platform.
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

void main() {
  test('one import gives an app its keys, clipboard, formatters and system chrome', () {
    // Keys.
    expect(LogicalKeyboardKey.escape.keyLabel, 'Escape');
    expect(PhysicalKeyboardKey.keyA.usbHidUsage, 0x00070004);
    expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
    const KeyEvent down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyD,
      logicalKey: LogicalKeyboardKey.keyD,
      timeStamp: Duration.zero,
    );
    expect(down, isA<KeyDownEvent>());
    expect(down, isNot(isA<KeyUpEvent>()));
    expect(down, isNot(isA<KeyRepeatEvent>()));
    expect(const SingleActivator(LogicalKeyboardKey.keyK, control: true).trigger, LogicalKeyboardKey.keyK);

    // Text input.
    final TextInputFormatter digits = FilteringTextInputFormatter.digitsOnly;
    expect(digits.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'a1b2')).text, '12');
    expect(
      LengthLimitingTextInputFormatter(3)
          .formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '12345'))
          .text,
      '123',
    );
    expect(TextInputType.number, isNot(TextInputType.text));
    expect(TextInputAction.done, isNot(TextInputAction.next));
    expect(TextCapitalization.characters, isNot(TextCapitalization.none));

    // Clipboard and system chrome: the types and entry points resolve.
    expect(const ClipboardData(text: 'SEC-04').text, 'SEC-04');
    expect(Clipboard.kTextPlain, 'text/plain');
    expect(SystemChrome.setPreferredOrientations, isA<Function>());
    expect(SystemUiOverlayStyle.light, isNot(SystemUiOverlayStyle.dark));
    expect(DeviceOrientation.values, isNotEmpty);
    expect(SystemUiMode.values, isNotEmpty);
    expect(SystemSoundType.values, isNotEmpty);
    expect(SystemSound.play, isA<Function>());
    expect(SystemNavigator.pop, isA<Function>());
    expect(HapticFeedback.selectionClick, isA<Function>());
  });

  testWidgets('a field takes formatters and a keyboard type from the same import', (WidgetTester tester) async {
    String typed = '';
    await tester.pumpWidget(
      KeikaiApp(
        theme: const KeikaiThemeData(motion: KkMotion.off),
        home: KkTextField(
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (String v) => typed = v,
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'a1b2c3d4');
    expect(typed, '123');
  });

  testWidgets('copying through the exported clipboard reaches the platform', (WidgetTester tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await Clipboard.setData(const ClipboardData(text: 'E-4127'));
    expect(calls.single.method, 'Clipboard.setData');
    expect((calls.single.arguments as Map<Object?, Object?>)['text'], 'E-4127');
  });
}
