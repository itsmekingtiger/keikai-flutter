import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/inputs/inputs.dart';

import '../support/harness.dart';

void main() {
  testWidgets('debug context menu', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController(text: 'SEC-04 COOLANT');
    await pumpKk(tester, KkBox(width: 300, child: KkTextInput(controller: controller)), padding: const EdgeInsets.all(40));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final EditableTextState state = tester.state<EditableTextState>(find.byType(EditableText));
    // ignore: avoid_print
    print('focus=${state.widget.focusNode.hasFocus} sel=${controller.selection} overlay=${state.selectionOverlay}');
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(EditableText)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump();
    // ignore: avoid_print
    print('after: overlay=${state.selectionOverlay} toolbarVisible=${state.selectionOverlay?.toolbarIsVisible} items=${state.contextMenuButtonItems.map((ContextMenuButtonItem i) => i.kind).toList()} menu=${find.byType(KkTextContextMenu).evaluate().length}');
    // ignore: avoid_print
    print('direct show: ${state.showToolbar()}');
    await tester.pump();
    // ignore: avoid_print
    print('menu=${find.byType(KkTextContextMenu).evaluate().length} visible=${state.selectionOverlay?.toolbarIsVisible}');
  });
}
