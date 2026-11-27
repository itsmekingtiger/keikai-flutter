import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart' show testChecked;
import '../support/harness.dart';

Duration _ms(int value) => Duration(milliseconds: value);

/// What the painter of the one [CustomPaint] inside [owner] draws on a canvas of [size].
List<RecordedInvocation> _painted(WidgetTester tester, Finder owner, Size size) {
  final CustomPaint paint = tester.widget<CustomPaint>(find.descendant(of: owner, matching: find.byType(CustomPaint)));
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  (paint.painter ?? paint.foregroundPainter)!.paint(canvas, size);
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

/// A canvas that gives up on a painter that draws more text than any band can hold.
class _CappedCanvas implements Canvas {
  int paragraphs = 0;

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    if (++paragraphs > 1000) throw StateError('still painting after 1000 repetitions of the text');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A child with a State, which writes down when that State is made and when it is thrown away.
class _Lifecycle extends StatefulWidget {
  const _Lifecycle(this.log);

  final List<String> log;

  @override
  State<_Lifecycle> createState() => _LifecycleState();
}

class _LifecycleState extends State<_Lifecycle> {
  @override
  void initState() {
    super.initState();
    widget.log.add('initState');
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 120, height: 80);
}

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

  group('KkMarquee', () {
    testChecked('is one repetition wide where the width is free', (WidgetTester tester) async {
      const String text = 'CRITICAL — COOLANT PRESSURE LOW';
      const KkMarquee marquee = KkMarquee(text, gap: 40);
      final TextStyle style = const KeikaiThemeData().type.mono(13, weight: FontWeight.w600, spacingEm: 0.08);
      final Size natural = Size(kkMeasureText(text, style) + 40, 13);
      final Finder band = find.byType(KkMarquee, skipOffstage: false);
      const Map<String, Widget> free = <String, Widget>{
        'a Row': Row(children: <Widget>[marquee]),
        'a KkRow': KkRow(children: <Widget>[marquee]),
        'a sideways scroll': KkScroll(axis: Axis.horizontal, child: marquee),
        'an UnconstrainedBox': UnconstrainedBox(child: marquee),
      };
      for (final MapEntry<String, Widget> parent in free.entries) {
        // Kept offstage: a band of infinite width has to be caught here, because its painter would never return.
        await pumpKk(tester, Offstage(child: parent.value), motion: true);
        expect(tester.takeException(), isNull, reason: 'laid out in ${parent.key}');
        expect(tester.getSize(band), natural, reason: 'in ${parent.key}');
      }
      // On stage the text runs through that width: one repetition leaves on the left as the next comes in.
      await pumpKk(tester, const KkRow(children: <Widget>[marquee]), motion: true);
      expect(tester.getSize(band), natural);
      await tester.pump(_ms(3500));
      expect(tester.takeException(), isNull);
      final List<double> texts = _marqueeTexts(tester, natural);
      expect(texts, hasLength(2));
      expect(texts.first, closeTo(-natural.width / 4, 0.001), reason: '3.5s is a quarter of the 14s period');
      expect(texts.last - texts.first, closeTo(natural.width, 0.001));
      // Where the width is given, it is taken, as before.
      await pumpKk(tester, const KkBox(width: 300, child: marquee), motion: true);
      expect(tester.getSize(band), const Size(300, 13));
      await pumpKk(tester, marquee, motion: true);
      expect(tester.getSize(band), const Size(800, 13));
    });

    testChecked('its painter returns on a canvas of infinite width', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 300, child: KkMarquee('CRITICAL')), motion: true);
      final CustomPainter painter = tester
          .widget<CustomPaint>(find.descendant(of: find.byType(KkMarquee), matching: find.byType(CustomPaint)))
          .painter!;
      final _CappedCanvas canvas = _CappedCanvas();
      painter.paint(canvas, const Size(300, 13));
      expect(canvas.paragraphs, greaterThan(1), reason: 'the band is filled with repetitions');
      canvas.paragraphs = 0;
      painter.paint(canvas, const Size(double.infinity, 13));
      expect(canvas.paragraphs, 0, reason: 'there is no end to fill up to');
    });
  });

  group('KkCrt', () {
    testChecked('keeps the State of its child when a texture is switched on or off', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget crt({bool scanlines = false, bool sweep = false, bool noise = false}) =>
          KkCrt(scanlines: scanlines, sweep: sweep, noise: noise, child: _Lifecycle(log));
      await pumpKk(tester, crt(), motion: true);
      expect(log, <String>['initState']);
      final State<StatefulWidget> state = tester.state(find.byType(_Lifecycle));
      // No signal: noise comes over the picture, and goes again.
      await pumpKk(tester, crt(noise: true), motion: true);
      expect(log, <String>['initState'], reason: 'noise on');
      await pumpKk(tester, crt(), motion: true);
      expect(log, <String>['initState'], reason: 'noise off');
      // Every other way from one set of textures to another.
      await pumpKk(tester, crt(scanlines: true), motion: true);
      expect(log, <String>['initState'], reason: 'scan lines on');
      await pumpKk(tester, crt(scanlines: true, sweep: true), motion: true);
      expect(log, <String>['initState'], reason: 'sweep on');
      await pumpKk(tester, crt(scanlines: true, sweep: true, noise: true), motion: true);
      await pumpKk(tester, crt(scanlines: true), motion: true);
      expect(log, <String>['initState'], reason: 'sweep and noise off');
      await pumpKk(tester, crt(), motion: true);
      expect(log, <String>['initState'], reason: 'everything off');
      expect(tester.state(find.byType(_Lifecycle)), same(state));
    });

    testChecked('paints and ticks only for the textures that are on', (WidgetTester tester) async {
      const Size panel = Size(120, 80);
      Future<void> show({bool scanlines = false, bool sweep = false, bool noise = false}) async {
        await pumpKk(
          tester,
          KkCrt(
            scanlines: scanlines,
            sweep: sweep,
            noise: noise,
            child: SizedBox(width: panel.width, height: panel.height),
          ),
          motion: true,
        );
        await tester.pump(_ms(20));
      }

      CustomPaint texture() =>
          tester.widget<CustomPaint>(find.descendant(of: find.byType(KkCrt), matching: find.byType(CustomPaint)));
      // The sweep is the one line of two pixels that the painter draws.
      double sweepLine() => _painted(tester, find.byType(KkCrt), panel)
          .where((RecordedInvocation call) => call.invocation.memberName == #drawRect)
          .map((RecordedInvocation call) => call.invocation.positionalArguments.first as Rect)
          .lastWhere((Rect rect) => rect.height == 2)
          .top;

      await show();
      // The page of the harness has wiped in after 0.42s; from then on only the texture can ask for frames.
      await tester.pump(_ms(600));
      await tester.pump(_ms(20));
      expect(texture().foregroundPainter, isNull);
      expect(tester.getSize(find.byType(KkCrt)), panel);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing is on');
      await show(scanlines: true);
      expect(texture().foregroundPainter, isNotNull);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'scan lines stand still');
      await show(scanlines: true, sweep: true);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the sweep runs');
      final double line = sweepLine();
      await tester.pump(_ms(1000));
      expect(sweepLine() - line, closeTo(panel.height / 5, 0.001), reason: 'down the panel in 5s');
      await show(scanlines: true);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the sweep is off again');
      await show(noise: true);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the noise flickers');
      await show();
      expect(texture().foregroundPainter, isNull);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'everything is off again');
    });
  });
}
