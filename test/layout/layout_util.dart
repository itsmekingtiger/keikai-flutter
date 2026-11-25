import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] on a [size] surface with no app around it.
///
/// With [loose] the child sits at the top left and may be smaller than the
/// surface; without it the child is forced to the surface size.
Future<void> pumpRaw(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  bool loose = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: loose ? Align(alignment: Alignment.topLeft, child: child) : child,
    ),
  );
}

/// A fixed-size box that can be found with [byId].
Widget box(String id, [double? width, double? height]) =>
    SizedBox(key: ValueKey<String>(id), width: width, height: height);

Finder byId(String id) => find.byKey(ValueKey<String>(id));

Rect rectOf(WidgetTester tester, String id) => tester.getRect(byId(id));

/// The test font: every glyph is an em square, ascent 0.75em.
TextStyle testStyle(double size) => TextStyle(fontSize: size, height: 1.0, color: const Color(0xFFFFFFFF));

/// The distance from the top of [box] to its alphabetic baseline, measured
/// without a layout pass (the real distance may only be read by a parent
/// during layout).
double? baselineOf(RenderBox box) => box.getDryBaseline(box.constraints, TextBaseline.alphabetic);
