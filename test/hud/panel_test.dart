import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const Key _body = ValueKey<String>('body');

Widget _content([double height = 40]) => KkBox(key: _body, height: height);

void main() {
  setUpAll(loadKkFonts);

  group('KkPanel layout', () {
    testWidgets('head band is 32px, body is padded by 16, border takes 1px', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 400,
          child: KkPanel(code: 'SEC-01', cjk: '電源系統', en: 'power', meta: '14:02:31Z', child: _content()),
        ),
      );
      final Rect panel = tester.getRect(find.byType(KkPanel));
      final Rect body = tester.getRect(find.byKey(_body));
      expect(panel.width, 400);
      // 1 border + 32 head + 16 padding.
      expect(body.top - panel.top, 1 + 32 + 16);
      expect(body.left - panel.left, 1 + 16);
      expect(panel.right - body.right, 1 + 16);
      // Content height: 1 + 32 + 16 + 40 + 16 + 1.
      expect(panel.height, 106);
      expect(find.text('SEC-01'), findsOneWidget);
      expect(find.text('電源系統'), findsOneWidget);
      expect(find.text('POWER'), findsOneWidget);
      expect(find.text('14:02:31Z'), findsOneWidget);
    });

    testWidgets('fills a fixed height and gives the rest to the body', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 200,
          child: KkPanel(cjk: '冷却', en: 'cooling', flush: true, child: KkBox(key: _body)),
        ),
      );
      expect(tester.getSize(find.byType(KkPanel)), const Size(300, 200));
      // 200 - 2 borders - 32 head.
      expect(tester.getSize(find.byKey(_body)), const Size(298, 166));
    });

    testWidgets('flush removes the padding; padding overrides it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '冷却', flush: true, child: _content()),
        ),
      );
      Rect panel = tester.getRect(find.byType(KkPanel));
      Rect body = tester.getRect(find.byKey(_body));
      expect(body.left - panel.left, 1);
      expect(body.top - panel.top, 33);

      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '冷却', padding: const EdgeInsets.all(4), child: _content()),
        ),
      );
      panel = tester.getRect(find.byType(KkPanel));
      body = tester.getRect(find.byKey(_body));
      expect(body.left - panel.left, 5);
      expect(body.top - panel.top, 37);
    });

    testWidgets('spine takes a 24px column and is as tall as the body', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 200,
          child: KkPanel(cjk: '接続状態', spine: '第三管区', child: KkBox(key: _body)),
        ),
      );
      final Rect panel = tester.getRect(find.byType(KkPanel));
      final Rect body = tester.getRect(find.byKey(_body));
      final Rect spine = tester.getRect(find.byType(KkTate));
      expect(body.left - panel.left, 1 + 24 + 16);
      // The glyph column is 22 wide inside the 24px spine (1px rule at its right).
      expect(spine.left, panel.left + 1);
      expect(spine.width, 22);
      expect(spine.top, panel.top + 33 + 12);
      expect(find.byType(KkTate), findsOneWidget);
    });

    testWidgets('is as wide as its content when the width is not limited', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkPanel(code: 'SEC-01', cjk: '電源', child: KkBox(key: _body, width: 320, height: 20)),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      // 320 body + 2×16 padding + 2 borders.
      expect(tester.getSize(find.byType(KkPanel)).width, 354);
    });

    testWidgets('a long title is clipped, not overflowed', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 180,
          child: KkPanel(
            code: 'SEC-04',
            cjk: '冷却水圧低下警報',
            en: 'coolant pressure low alarm',
            meta: 'E-4127',
            level: KkLevel.critical,
            collapsible: true,
            child: _content(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkPanel)).width, 180);
    });

    testWidgets('survives being tiny', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 20,
          height: 10,
          child: KkPanel(code: 'A', cjk: '電', en: 'p', meta: 'm', spine: '第', collapsible: true, child: _content()),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrollBody scrolls content taller than a fixed panel', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          height: 120,
          child: KkPanel(cjk: '記録', scrollBody: true, child: _content(400)),
        ),
      );
      expect(tester.takeException(), isNull);
      final double before = tester.getTopLeft(find.byKey(_body)).dy;
      await tester.dragFrom(tester.getTopLeft(find.byKey(_body)) + const Offset(20, 20), const Offset(0, -80));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_body)).dy, before - 80);
    });
  });

  group('KkPanel looks', () {
    testWidgets('critical runs a hazard strip in the head; other levels do not', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '冷却水圧', level: KkLevel.critical, child: _content()),
        ),
      );
      final KkHazard hazard = tester.widget(find.byType(KkHazard));
      expect(hazard.running, isTrue);
      expect(hazard.width, 48);
      expect(hazard.color, KkColors.standby.onFill);

      for (final KkLevel level in <KkLevel>[KkLevel.nominal, KkLevel.caution, KkLevel.offline]) {
        await pumpKk(
          tester,
          KkBox(
            width: 300,
            child: KkPanel(cjk: '冷却', level: level, child: _content()),
          ),
        );
        expect(find.byType(KkHazard), findsNothing, reason: '$level');
      }
    });

    testWidgets('offline drains the body of colour', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '中継局', level: KkLevel.offline, child: _content()),
        ),
      );
      expect(find.ancestor(of: find.byKey(_body), matching: find.byType(ColorFiltered)), findsOneWidget);
    });

    testWidgets('frame colours follow variant, level and theme', (WidgetTester tester) async {
      KkDecoration frameOf() {
        final KkBox box = tester.widget<KkBox>(
          find.descendant(of: find.byType(KkPanel), matching: find.byType(KkBox)).first,
        );
        return box.decoration!;
      }

      Future<void> pump(KkPanel panel, {KkCondition condition = KkCondition.standby}) =>
          pumpKk(tester, KkBox(width: 300, child: panel), condition: condition);

      const KkColors s = KkColors.standby;
      await pump(KkPanel(cjk: '電源', child: _content()));
      expect(frameOf().fill, s.bg100);
      expect(frameOf().edges.top.color, s.line);
      expect(frameOf().brackets!.color, s.signal);
      expect(frameOf().brackets!.length, 12);
      expect(frameOf().brackets!.width, 2);
      expect(frameOf().glow, isNull);

      await pump(KkPanel(cjk: '電源', variant: KkPanelVariant.active, child: _content()));
      expect(frameOf().edges.top.color, s.signal);
      expect(frameOf().glow, s.glowSignal);

      await pump(KkPanel(cjk: '電源', level: KkLevel.critical, variant: KkPanelVariant.active, child: _content()));
      expect(frameOf().edges.top.color, s.alert);
      expect(frameOf().brackets!.color, s.alert);
      expect(frameOf().glow, s.glowAlert);

      await pump(KkPanel(cjk: '電源', level: KkLevel.offline, child: _content()));
      expect(frameOf().edges.top.color, s.offline);
      expect(frameOf().edges.top.dashed, isTrue);
      expect(frameOf().brackets!.color, s.offline);

      await pump(KkPanel(cjk: '電源', child: _content()), condition: KkCondition.alert);
      const KkColors a = KkColors.alertTheme;
      expect(frameOf().fill, a.bg100);
      expect(frameOf().edges.top.color, a.line);
      expect(frameOf().brackets!.color, a.signal);

      await pump(KkPanel(cjk: '電源', brackets: false, frameColor: s.series2, child: _content()));
      expect(frameOf().brackets, isNull);
    });
  });

  group('KkPanel collapse', () {
    testWidgets('the toggle hides the body and reports the new state', (WidgetTester tester) async {
      final List<bool> calls = <bool>[];
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '補助電源', spine: '補助', collapsible: true, onToggle: calls.add, child: _content()),
        ),
      );
      expect(find.byKey(_body), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse panel'), findsOneWidget);
      final double open = tester.getSize(find.byType(KkPanel)).height;

      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      expect(calls, <bool>[true]);
      expect(find.byKey(_body), findsNothing);
      expect(find.byType(KkTate), findsNothing);
      // Only the border and the head are left.
      expect(tester.getSize(find.byType(KkPanel)).height, 34);

      await tester.tap(find.bySemanticsLabel('Expand panel'));
      await tester.pump();
      expect(calls, <bool>[true, false]);
      expect(find.byKey(_body), findsOneWidget);
      expect(tester.getSize(find.byType(KkPanel)).height, open);
    });

    testWidgets('starts collapsed with initiallyCollapsed', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '排気', collapsible: true, initiallyCollapsed: true, child: _content()),
        ),
      );
      expect(find.byKey(_body), findsNothing);
      expect(find.bySemanticsLabel('Expand panel'), findsOneWidget);
    });

    testWidgets('a controlled panel only changes when its parent says so', (WidgetTester tester) async {
      bool collapsed = false;
      final List<bool> calls = <bool>[];
      late StateSetter rebuild;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return KkBox(
              width: 300,
              child: KkPanel(
                cjk: '排気',
                collapsible: true,
                collapsed: collapsed,
                onToggle: calls.add,
                child: _content(),
              ),
            );
          },
        ),
      );
      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      expect(calls, <bool>[true]);
      expect(find.byKey(_body), findsOneWidget, reason: 'the parent has not changed collapsed yet');

      rebuild(() => collapsed = true);
      await tester.pump();
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets('without collapsible there is no toggle and collapsed is ignored', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '排気', collapsed: true, child: _content()),
        ),
      );
      expect(find.byKey(_body), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse panel'), findsNothing);
    });

    testWidgets('the toggle works from the keyboard', (WidgetTester tester) async {
      final List<bool> calls = <bool>[];
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '排気', collapsible: true, onToggle: calls.add, child: _content()),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, <bool>[true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, <bool>[true, false]);
    });
  });

  group('KkPanel entrance', () {
    testWidgets('wipes in over 0.42s, then the body flickers on', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 280,
          child: KkPanel(code: 'SEC-01', cjk: '電源', child: _content()),
        ),
        motion: true,
        size: const Size(280, 200),
      );
      // Let the page route finish its own wipe first.
      RenderBox clipOf() => tester.renderObject<RenderBox>(
        find.descendant(of: find.byType(KkPanel), matching: find.byType(ClipRect)).first,
      );
      Rect clip() => (clipOf() as RenderClipRect).clipper!.getClip(clipOf().size);
      expect(clip().width, 0, reason: 'hidden before the first step');
      await tester.pump(const Duration(milliseconds: 210));
      // 210 / 420 = 0.5 → floor(0.5 × 7) / 7 = 3/7 of the width.
      expect(clip().width, closeTo(280 * 3 / 7, 0.01));
      await tester.pump(const Duration(milliseconds: 220));
      expect((clipOf() as RenderClipRect).clipBehavior, Clip.none, reason: 'no clipping once the wipe is done');

      final FadeTransition fade = tester.widget(
        find.ancestor(of: find.byKey(_body), matching: find.byType(FadeTransition)).first,
      );
      // The flicker starts 0.3s in and lasts 0.5s: at 0.43s it is under way.
      expect(fade.opacity.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fade.opacity.value, 1);
      expect(tester.takeException(), isNull);
      // The running clock of the app stops with the tree.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('grid cells stagger the entrance by 60ms each', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkGrid(
          columns: 4,
          children: <Widget>[
            for (int i = 0; i < 4; i++)
              KkCell(
                span: 1,
                rows: 2,
                child: KkPanel(key: ValueKey<int>(i), cjk: '電源', child: _content()),
              ),
          ],
        ),
        motion: true,
        size: const Size(800, 200),
      );
      double shown(int i) {
        final RenderClipRect clip = tester.renderObject<RenderClipRect>(
          find.descendant(of: find.byKey(ValueKey<int>(i)), matching: find.byType(ClipRect)).first,
        );
        return clip.clipper!.getClip(clip.size).width / clip.size.width;
      }

      await tester.pump(const Duration(milliseconds: 200));
      // Cell 0 is 200ms in, cell 3 only 20ms.
      expect(shown(0), greaterThan(shown(1)));
      expect(shown(1), greaterThanOrEqualTo(shown(2)));
      expect(shown(3), 0);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with motion off everything is in its final state at once', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 280,
          child: KkPanel(code: 'SEC-01', cjk: '電源', level: KkLevel.critical, child: _content()),
        ),
      );
      final RenderClipRect clip = tester.renderObject<RenderClipRect>(
        find.descendant(of: find.byType(KkPanel), matching: find.byType(ClipRect)).first,
      );
      expect(clip.clipBehavior, Clip.none);
      await tester.pumpAndSettle();
    });
  });
}
