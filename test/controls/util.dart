import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

/// Makes hover and focus highlights show as they do on a desktop: the test
/// platform is a phone, where they stay off until a key is pressed.
void useTraditionalHighlights() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}

/// Moves a mouse pointer over [finder] and leaves it there.
Future<TestGesture> hoverOn(WidgetTester tester, Finder finder) async {
  useTraditionalHighlights();
  await tester.pump();
  final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(799, 599));
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}

/// The plate of the control found by [owner].
RenderKkSurface surfaceOf(WidgetTester tester, Finder owner) {
  return tester.renderObject<RenderKkSurface>(find.descendant(of: owner, matching: find.byType(KkSurface)).first);
}

/// The focus ring of the control found by [owner].
RenderKkFocusRing ringOf(WidgetTester tester, Finder owner) {
  return tester.renderObject<RenderKkFocusRing>(find.descendant(of: owner, matching: find.byType(KkFocusRing)).first);
}

/// Holds one value for a controlled widget under test.
class Hold<T> extends StatefulWidget {
  const Hold({super.key, required this.initial, required this.builder, this.onChanged});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> set) builder;
  final ValueChanged<T>? onChanged;

  @override
  State<Hold<T>> createState() => HoldState<T>();
}

class HoldState<T> extends State<Hold<T>> {
  late T value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, value, (T next) {
      setState(() => value = next);
      widget.onChanged?.call(next);
    });
  }
}

/// The [KkText] that renders [text].
KkText kkTextOf(WidgetTester tester, String text) {
  return tester.widget<KkText>(find.ancestor(of: find.text(text), matching: find.byType(KkText)).first);
}
