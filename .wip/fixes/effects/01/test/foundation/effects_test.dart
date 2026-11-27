import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

Duration _ms(int value) => Duration(milliseconds: value);

/// What the painter of the one [CustomPaint] inside [owner] draws on a canvas of [size].
List<RecordedInvocation> _painted(WidgetTester tester, Finder owner, Size size) {
  final CustomPaint paint = tester.widget<CustomPaint>(find.descendant(of: owner, matching: find.byType(CustomPaint)));
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, size);
  return canvas.invocations;
}

/// The right edge of the stripes a [KkHazard] of [size] paints right now.
double _stripeEdge(WidgetTester tester, Size size) {
  final RecordedInvocation draw = _painted(
    tester,
    find.byType(KkHazard),
    size,
  ).lastWhere((RecordedInvocation call) => call.invocation.memberName == #drawPath);
  return (draw.invocation.positionalArguments.first as Path).getBounds().right;
}

/// Where a [KkMarquee] of [size] puts each repetition of its text right now, from the left.
List<double> _marqueeTexts(WidgetTester tester, Size size) => <double>[
  for (final RecordedInvocation call in _painted(tester, find.byType(KkMarquee), size))
    if (call.invocation.memberName == #drawParagraph) (call.invocation.positionalArguments[1] as Offset).dx,
];

void main() {
  setUpAll(loadKkFonts);

  group('time scale', () {
    testChecked('KkHazard and KkMarquee are slowed by the time scale once, not twice', (WidgetTester tester) async {
      const Size band = Size(96, 24);
      const Size strip = Size(300, 12);
      const String text = 'CRITICAL 0123';
      const double pitch = 12;
      const double gap = 20;
      final TextStyle style = const KeikaiThemeData().type.mono(12, weight: FontWeight.w600);
      // The stripes travel one square tile per stripe period in 0.9s, the text its length and the gap in a period.
      const double tile = pitch * 2 * math.sqrt2;
      final double unit = kkMeasureText(text, style) + gap;
      for (final double timeScale in <double>[1, 2, 4]) {
        await pumpKk(
          tester,
          KkColumn(
            children: <Widget>[
              KkHazard(width: band.width, height: band.height, pitch: pitch, running: true),
              KkBox(
                width: strip.width,
                child: KkMarquee(text, style: style, period: const Duration(seconds: 1), gap: gap),
              ),
            ],
          ),
          motion: true,
          theme: KeikaiThemeData(motion: KkMotion(timeScale: timeScale)),
        );
        final double stripes = _stripeEdge(tester, band);
        final double words = _marqueeTexts(tester, strip).first;
        // At full speed 180ms is a fifth of the hazard's 0.9s and 18% of this marquee's second.
        await tester.pump(_ms(180));
        expect(
          (_stripeEdge(tester, band) - stripes) % tile,
          closeTo(tile * 0.2 / timeScale, 0.001),
          reason: 'the stripes at time scale $timeScale',
        );
        expect(
          (words - _marqueeTexts(tester, strip).first) % unit,
          closeTo(unit * 0.18 / timeScale, 0.001),
          reason: 'the text at time scale $timeScale',
        );
      }
    });
  });
}
