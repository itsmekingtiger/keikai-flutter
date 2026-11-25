import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// The painter of the plate (fill, rings).
dynamic _plate(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.ancestor(of: find.text('緊急停止'), matching: find.byType(CustomPaint)).first).painter;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('inline: full width, 420px tall at least, plate in the middle', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkEmergency(
        inline: true,
        code: 'E-4127 · SEC-04',
        cjk: '緊急停止',
        en: 'emergency stop',
        sub: '冷却水圧 低下',
      ),
    );
    final Rect box = tester.getRect(find.byType(KkEmergency));
    expect(box.size, const Size(800, 420));
    final Rect cjk = tester.getRect(find.text('緊急停止'));
    expect(cjk.center.dx, closeTo(400, 0.5));
    // Inline sizes: 88px CJK, 24px Latin.
    expect(cjk.height, 88);
    expect(tester.getRect(find.text('EMERGENCY STOP')).height, 24);
    // Hazard bands: 24px high, 24px from the top and the bottom, running.
    final List<KkHazard> bands = tester.widgetList<KkHazard>(find.byType(KkHazard)).toList();
    expect(bands, hasLength(2));
    expect(bands.every((KkHazard h) => h.running && h.color == KkColors.standby.alert), isTrue);
    final List<Rect> bandRects = find.byType(KkHazard).evaluate().map((Element e) => tester.getRect(find.byWidget(e.widget))).toList();
    expect(bandRects[0], const Rect.fromLTWH(0, 24, 800, 24));
    expect(bandRects[1], const Rect.fromLTWH(0, 372, 800, 24));
    // Marquees at 56px from the top and the bottom; the lower one runs backwards.
    final List<KkMarquee> marquees = tester.widgetList<KkMarquee>(find.byType(KkMarquee)).toList();
    expect(marquees.map((KkMarquee m) => m.reverse), <bool>[false, true]);
    expect(marquees.first.text, 'E-4127 · SEC-04  ///  EMERGENCY STOP  ///  冷却水圧 低下');
    expect(tester.getTopLeft(find.byType(KkMarquee).first).dy, 56);
    expect(tester.getBottomLeft(find.byType(KkMarquee).last).dy, 420 - 56);
  });

  testWidgets('grows past 420px when the plate needs it, and honours minHeight', (WidgetTester tester) async {
    await pumpKk(tester, const KkEmergency(inline: true, cjk: '緊急停止', minHeight: 200));
    expect(tester.getSize(find.byType(KkEmergency)).height, 200);
    await pumpKk(
      tester,
      const KkEmergency(
        inline: true,
        cjk: '緊急停止',
        minHeight: 100,
        code: 'E-4127',
        en: 'emergency stop',
        sub: '冷却水圧 低下',
      ),
    );
    // 16 + (16 + 13 + 8 + 88 + 8 + 24 + 8 + 13×1.4 + 24) + 16.
    expect(tester.getSize(find.byType(KkEmergency)).height, closeTo(239.2, 1));
  });

  testWidgets('the plate strobes once a second between the alert fill and its dark phase', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    await pumpKk(tester, const KkEmergency(inline: true, cjk: '緊急停止', en: 'emergency stop'), motion: true);
    Color? ink() => tester.widget<Text>(find.text('緊急停止')).style!.color;
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: avoid_dynamic_calls
    expect(_plate(tester).fill, c.alert);
    expect(ink(), c.onFill);
    await tester.pump(const Duration(milliseconds: 500));
    // ignore: avoid_dynamic_calls
    expect(_plate(tester).fill, c.alertDeep);
    expect(ink(), c.ink);
    await tester.pump(const Duration(milliseconds: 500));
    // ignore: avoid_dynamic_calls
    expect(_plate(tester).fill, c.alert);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('actions take the ink of the plate; an empty marquee hides the bands of text', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkEmergency(inline: true, cjk: '緊急停止', marquee: '', actions: <Widget>[KkText.en('acknowledge')]),
    );
    expect(find.byType(KkMarquee), findsNothing);
    expect(tester.widget<Text>(find.text('ACKNOWLEDGE')).style!.color, KkColors.standby.onFill);
  });

  testWidgets('showKkEmergency covers the screen and only an action closes it', (WidgetTester tester) async {
    String? result;
    await pumpKk(
      tester,
      Builder(
        builder: (BuildContext context) => KkPressable(
          onPressed: () async {
            result = await showKkEmergency<String>(
              context,
              code: 'E-4127',
              cjk: '緊急停止',
              en: 'emergency stop',
              actions: (BuildContext context) => <Widget>[
                KkPressable(
                  onPressed: () => Navigator.of(context).pop('ack'),
                  builder: (BuildContext context, KkStates states) => const KkText.en('acknowledge'),
                ),
              ],
            );
          },
          builder: (BuildContext context, KkStates states) => const KkText.en('raise alarm'),
        ),
      ),
    );
    expect(find.byType(KkEmergency), findsNothing);
    await tester.tap(find.text('RAISE ALARM'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    expect(tester.getSize(find.byType(KkEmergency)), const Size(800, 600));
    // Full-screen sizes: 120px CJK, 30px Latin.
    expect(tester.getRect(find.text('緊急停止')).height, 120);
    expect(tester.getRect(find.text('EMERGENCY STOP')).height, 30);

    // Tapping the veil does nothing.
    await tester.tapAt(const Offset(10, 300));
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    // Neither does Escape, nor a system back.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    expect(await navigator.maybePop(), isTrue, reason: 'the route swallows the pop');
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    // The page under it cannot be reached.
    await tester.tap(find.text('RAISE ALARM'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);

    await tester.tap(find.text('ACKNOWLEDGE'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkEmergency), findsNothing);
    expect(result, 'ack');
  });

  testWidgets('a dismissible alarm closes on Escape, still not on a tap', (WidgetTester tester) async {
    bool closed = false;
    await pumpKk(
      tester,
      Builder(
        builder: (BuildContext context) => KkPressable(
          onPressed: () async {
            await showKkEmergency<void>(context, cjk: '緊急停止', dismissible: true);
            closed = true;
          },
          builder: (BuildContext context, KkStates states) => const KkText.en('raise alarm'),
        ),
      ),
    );
    await tester.tap(find.text('RAISE ALARM'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    await tester.tapAt(const Offset(10, 300));
    await tester.pump();
    expect(find.byType(KkEmergency), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkEmergency), findsNothing);
    expect(closed, isTrue);
  });

  testWidgets('long text and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkBox(
        width: 60,
        height: 40,
        child: KkEmergency(
          inline: true,
          code: 'E-4127 · SEC-04 · 14:02:31Z' * 3,
          cjk: '緊急停止' * 4,
          en: 'emergency stop ' * 6,
          sub: '冷却水圧 低下 ' * 12,
          actions: const <Widget>[KkText.en('acknowledge'), KkText.en('silence')],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkEmergency(cjk: '緊急停止'), size: const Size(120, 90));
    expect(tester.takeException(), isNull);
  });
}
