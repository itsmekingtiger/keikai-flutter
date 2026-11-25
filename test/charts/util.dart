import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

/// A mouse that starts in the far corner. Remove it with the returned
/// gesture's `removePointer` (registered as a tear-down here).
Future<TestGesture> mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(9999, 9999));
  addTearDown(gesture.removePointer);
  return gesture;
}

/// The global rectangle of the [index]-th plot pointer region inside [owner].
Rect plotRect(WidgetTester tester, Finder owner, {int index = 0}) {
  return tester.getRect(find.descendant(of: owner, matching: find.byType(KkPlotPointer)).at(index));
}

/// The painter of type [T] currently mounted.
T painterOf<T extends CustomPainter>(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is T),
  );
  return paint.painter! as T;
}

/// A column that gives [child] a free height, the way a scrolling page does.
Widget freeHeight(Widget child, {double? width}) {
  return KkBox(
    width: width,
    child: KkColumn(shrinkWrap: true, children: <Widget>[child]),
  );
}
