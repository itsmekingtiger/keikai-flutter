import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/hud/hud.dart';

import '../support/harness.dart';

KkDecoration _frame(WidgetTester tester) => tester
    .widget<KkBox>(find.descendant(of: find.byType(KkAlertBar), matching: find.byType(KkBox)).first)
    .decoration!;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('is at least 64px tall, framed by a 2px line in signal', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 700, child: KkAlertBar(title: 'advisory — auxiliary power online')));
    expect(tester.getSize(find.byType(KkAlertBar)), const Size(700, 64));
    final KkDecoration d = _frame(tester);
    expect(d.fill, KkColors.standby.bg100);
    expect(d.edges.top.color, KkColors.standby.signal);
    expect(d.edges.top.width, 2);
    expect(d.glow, isNull);
    expect(find.text('ADVISORY — AUXILIARY POWER ONLINE'), findsOneWidget);
  });

  testWidgets('grows with a CJK word and a sub line', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 760,
        child: KkAlertBar(
          level: KkLevel.caution,
          cjk: '注意',
          title: 'caution — coolant temp rising',
          sub: '冷却水温 上昇 · SEC-03 · 14:02:02Z',
          code: 'W-2204',
        ),
      ),
    );
    final Size size = tester.getSize(find.byType(KkAlertBar));
    expect(size.width, 760);
    // 2 + 8 + (26 + 6 + 12×1.3) + 8 + 2, give or take the engine's line rounding.
    expect(size.height, closeTo(67.6, 0.5));
    expect(_frame(tester).edges.left.color, KkColors.standby.caution);
    expect(find.text('注意'), findsOneWidget);
    expect(find.text('W-2204'), findsOneWidget);
  });

  testWidgets('hazard blocks are 64px wide and only run when critical', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 700, child: KkAlertBar(level: KkLevel.caution, title: 'caution')));
    List<KkHazard> hazards = tester.widgetList<KkHazard>(find.byType(KkHazard)).toList();
    expect(hazards, hasLength(2));
    expect(hazards.every((KkHazard h) => !h.running && h.width == 64), isTrue);
    expect(hazards.first.color, KkColors.standby.caution);
    expect(hazards.first.background, KkColors.standby.bg000);

    await pumpKk(tester, const KkBox(width: 700, child: KkAlertBar(level: KkLevel.critical, title: 'critical')));
    hazards = tester.widgetList<KkHazard>(find.byType(KkHazard)).toList();
    expect(hazards.every((KkHazard h) => h.running), isTrue);
    expect(hazards.first.color, KkColors.standby.onFill);
    expect(hazards.first.background!.a, 0);
    final KkDecoration d = _frame(tester);
    expect(d.fill, KkColors.standby.alert);
    expect(d.glow, KkColors.standby.glowAlert);

    await pumpKk(tester, const KkBox(width: 700, child: KkAlertBar(title: 'plain', hazards: false)));
    expect(find.byType(KkHazard), findsNothing);
  });

  testWidgets('long text is cut with an ellipsis instead of overflowing', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 320,
        child: KkAlertBar(
          level: KkLevel.critical,
          cjk: '警報',
          title: 'critical — coolant pressure low in every loop of sector four',
          sub: '冷却水圧 低下 · SEC-04 · 14:02:31Z · 補助ポンプ 起動 待機 · 自動停止まで 00:09',
          code: 'E-4127',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkAlertBar)).width, 320);
    final Text title = tester.widget(find.textContaining('CRITICAL'));
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('survives a tiny box and an action widget', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 30,
        height: 12,
        child: KkAlertBar(cjk: '警報', title: 'x', sub: 'y', code: 'z', action: KkText.en('ack')),
      ),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      const KkBox(width: 600, child: KkAlertBar(title: 'advisory', action: KkText.en('acknowledge'))),
    );
    expect(find.text('ACKNOWLEDGE'), findsOneWidget);
    // The action takes the bar's ink.
    final DefaultTextStyle ink = DefaultTextStyle.of(tester.element(find.text('ACKNOWLEDGE')));
    expect(ink.style.color, KkColors.standby.signal);
  });

  testWidgets('follows the alert theme', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(width: 600, child: KkAlertBar(title: 'advisory')),
      condition: KkCondition.alert,
    );
    expect(_frame(tester).edges.top.color, KkColors.alertTheme.signal);
    expect(_frame(tester).fill, KkColors.alertTheme.bg100);
  });
}
