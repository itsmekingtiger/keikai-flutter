import 'dart:typed_data';
import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const Key _body = ValueKey<String>('body');
const Key _shot = ValueKey<String>('shot');

Widget _content([double height = 40]) => KkBox(key: _body, height: height);

/// Logs when its State is made and thrown away.
class _Probe extends StatefulWidget {
  const _Probe(this.log);

  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init');
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const KkBox(height: 20);
}

/// Reads what the repaint boundary [_shot] painted: the result gives the
/// colour at a point of the screen.
Future<Color Function(Offset at)> _shoot(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  late ByteData bytes;
  late int width;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    width = image.width;
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  return (Offset at) {
    final Offset local = boundary.globalToLocal(at);
    // Bytes are red, green, blue, alpha.
    final int i = (local.dy.floor() * width + local.dx.floor()) * 4;
    return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  };
}

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

    testWidgets('a head too narrow for its parts cuts them off at its edge', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      // What is painted beside the panel, level with its head.
      Future<List<Color>> beside(KkPanel panel) async {
        await pumpKk(
          tester,
          RepaintBoundary(
            key: _shot,
            child: KkBox(
              width: 400,
              height: 120,
              fill: c.bg000,
              alignment: Alignment.topLeft,
              child: KkBox(width: 168, child: panel),
            ),
          ),
        );
        final Rect rect = tester.getRect(find.byType(KkPanel));
        final Color Function(Offset at) seen = await _shoot(tester);
        return <Color>[
          for (double y = rect.top; y < rect.top + 34; y++)
            for (double x = rect.right; x < 400; x++) seen(Offset(x, y)),
        ];
      }

      for (final KkPanelVariant variant in KkPanelVariant.values) {
        for (final KkLevel? level in <KkLevel?>[null, KkLevel.critical]) {
          final List<Color> full = await beside(
            KkPanel(
              code: 'SEC-04',
              cjk: '冷却',
              en: 'coolant',
              meta: '14:02:31Z',
              variant: variant,
              level: level,
              collapsible: true,
              child: _content(),
            ),
          );
          // Code, meta, toggle and hazard keep their widths: 78 + 79 + 32 (+ 48) in 166.
          expect(tester.getRect(find.bySemanticsLabel('Collapse panel')).right, greaterThan(168));
          // The same frame and glow around a head with room to spare.
          final List<Color> bare = await beside(
            KkPanel(code: 'SEC-04', variant: variant, level: level, child: _content()),
          );
          int spilled = 0;
          for (int i = 0; i < full.length; i++) {
            if (full[i] != bare[i]) spilled++;
          }
          expect(spilled, 0, reason: 'pixels of the head beside a $variant panel at $level');
        }
      }
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

    testWidgets('offline drains the body of colour, and no other level does', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      for (final KkLevel? level in <KkLevel?>[null, ...KkLevel.values]) {
        await pumpKk(
          tester,
          RepaintBoundary(
            key: _shot,
            child: KkBox(
              width: 300,
              child: KkPanel(
                cjk: '中継局',
                level: level,
                spine: '第三',
                frameColor: c.signal,
                child: KkBox(key: _body, height: 40, fill: c.signal),
              ),
            ),
          ),
        );
        final Color Function(Offset at) seen = await _shoot(tester);
        final Color body = seen(tester.getCenter(find.byKey(_body)));
        if (level == KkLevel.offline) {
          // Signal orange at its own brightness: 0.2126 r + 0.7152 g + 0.0722 b.
          expect((body.r * 255).round(), closeTo(143, 2));
          expect(body.g, body.r);
          expect(body.b, body.r);
        } else {
          expect(body, c.signal, reason: '$level');
        }
        // The spine is not part of the body: its glyphs keep the frame colour.
        final Rect spine = tester.getRect(find.byType(KkTate));
        bool orange = false;
        for (double y = spine.top; y < spine.bottom; y++) {
          for (double x = spine.left; x < spine.right; x++) {
            orange = orange || seen(Offset(x, y)) == c.signal;
          }
        }
        expect(orange, isTrue, reason: 'spine at $level');
      }
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

  group('KkPanel keeps what is in its body', () {
    testWidgets('through every level, offline and back included', (WidgetTester tester) async {
      final List<String> log = <String>[];
      for (final KkLevel? level in <KkLevel?>[null, ...KkLevel.values, null, KkLevel.offline, KkLevel.critical]) {
        await pumpKk(
          tester,
          KkBox(
            width: 300,
            child: KkPanel(cjk: '記録', spine: '記録', level: level, child: _Probe(log)),
          ),
        );
        expect(log, <String>['init'], reason: 'after the level turned $level');
      }
    });

    testWidgets('through every variant', (WidgetTester tester) async {
      final List<String> log = <String>[];
      for (final KkPanelVariant variant in <KkPanelVariant>[...KkPanelVariant.values, KkPanelVariant.standard]) {
        await pumpKk(
          tester,
          KkBox(
            width: 300,
            child: KkPanel(cjk: '記録', variant: variant, level: KkLevel.offline, child: _Probe(log)),
          ),
        );
        expect(log, <String>['init'], reason: 'after the variant turned $variant');
      }
    });

    testWidgets('a collapsed panel stays collapsed when its level and variant change', (WidgetTester tester) async {
      Widget panel(KkLevel? level, KkPanelVariant variant) => KkBox(
        width: 300,
        child: KkPanel(cjk: '補助電源', collapsible: true, level: level, variant: variant, child: _content()),
      );
      await pumpKk(tester, panel(null, KkPanelVariant.standard));
      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      for (final KkLevel? level in <KkLevel?>[KkLevel.offline, KkLevel.critical, null]) {
        for (final KkPanelVariant variant in KkPanelVariant.values) {
          await pumpKk(tester, panel(level, variant));
          expect(find.bySemanticsLabel('Expand panel'), findsOneWidget, reason: '$level, $variant');
          expect(tester.getSize(find.byType(KkPanel)).height, 34, reason: '$level, $variant');
        }
      }
    });

    testWidgets('a scrolled body stays where it was when the level turns offline', (WidgetTester tester) async {
      Widget panel(KkLevel? level) => KkBox(
        width: 300,
        height: 160,
        child: KkPanel(cjk: '記録', scrollBody: true, level: level, child: _content(640)),
      );
      await pumpKk(tester, panel(null));
      final double top = tester.getTopLeft(find.byKey(_body)).dy;
      await tester.dragFrom(tester.getCenter(find.byType(KkScroll)), const Offset(0, -200));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_body)).dy, top - 200);
      for (final KkLevel? level in <KkLevel?>[KkLevel.offline, null, KkLevel.critical, KkLevel.offline]) {
        await pumpKk(tester, panel(level));
        expect(tester.getTopLeft(find.byKey(_body)).dy, top - 200, reason: 'after the level turned $level');
      }
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

    testWidgets('a collapsed body stays in the tree and keeps its State', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(cjk: '補助電源', spine: '補助', collapsible: true, child: _Probe(log)),
        ),
      );
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsLabel('Collapse panel'));
        await tester.pump();
        // Hidden, with no room of its own.
        expect(find.byType(_Probe), findsNothing);
        expect(find.byType(_Probe, skipOffstage: false), findsOneWidget);
        expect(tester.getSize(find.byType(KkPanel)).height, 34);
        await tester.tap(find.bySemanticsLabel('Expand panel'));
        await tester.pump();
        expect(find.byType(_Probe), findsOneWidget);
      }
      expect(log, <String>['init']);

      // A panel that starts collapsed has its body from the start.
      final List<String> folded = <String>[];
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          height: 200,
          child: KkPanel(
            key: const ValueKey<String>('folded'),
            cjk: '排気',
            collapsible: true,
            initiallyCollapsed: true,
            child: _Probe(folded),
          ),
        ),
      );
      expect(folded, <String>['init']);
      expect(find.byType(_Probe), findsNothing);
      expect(tester.getSize(find.byType(KkPanel)).height, 200);
      await tester.tap(find.bySemanticsLabel('Expand panel'));
      await tester.pump();
      expect(find.byType(_Probe), findsOneWidget);
      expect(folded, <String>['init']);
    });

    testWidgets('a countdown in a collapsed body keeps counting', (WidgetTester tester) async {
      final KkTimerController timer = KkTimerController();
      addTearDown(timer.dispose);
      await pumpKk(
        tester,
        KkBox(
          width: 400,
          child: KkPanel(
            cjk: '発進',
            collapsible: true,
            child: KkTimer.countdown(from: const Duration(minutes: 10), controller: timer),
          ),
        ),
        motion: true,
      );
      await tester.pump(const Duration(minutes: 1));
      expect(timer.elapsed, const Duration(minutes: 1));

      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(timer.isRunning, isTrue);
      // Out of sight the time is counted in tenths of a second.
      expect(timer.elapsed.inMilliseconds, inInclusiveRange(89900, 90100));

      await tester.tap(find.bySemanticsLabel('Expand panel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(timer.elapsed.inMilliseconds, inInclusiveRange(90900, 91100));
      expect(find.textContaining('08:2'), findsOneWidget);
      // The running clock of the app stops with the tree.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nothing in a collapsed body takes the focus or is read', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkPanel(
            cjk: '補助電源',
            collapsible: true,
            child: Focus(focusNode: node, child: const KkText('보조 펌프 대기')),
          ),
        ),
      );
      List<String> read() {
        final List<String> labels = <String>[];
        void visit(SemanticsNode node) {
          if (node.label.isNotEmpty) labels.add(node.label);
          node.visitChildren((SemanticsNode child) {
            visit(child);
            return true;
          });
        }

        visit(tester.getSemantics(find.byType(KkPanel)));
        return labels;
      }

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(read().join(' '), contains('보조 펌프 대기'));

      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      expect(node.hasFocus, isFalse, reason: 'the focus does not stay on what is hidden');
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      expect(read().join(' '), isNot(contains('보조 펌프 대기')));
      // A key press goes to the toggle, not into the body.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isFalse);

      await tester.tap(find.bySemanticsLabel('Expand panel'));
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a body that comes back flickers on at once', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 280,
          child: KkPanel(cjk: '電源', collapsible: true, child: _content()),
        ),
        motion: true,
        size: const Size(280, 200),
      );
      double opacity() => tester
          .widget<FadeTransition>(
            find.ancestor(of: find.byKey(_body, skipOffstage: false), matching: find.byType(FadeTransition)).first,
          )
          .opacity
          .value;
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(), 1);

      await tester.tap(find.bySemanticsLabel('Collapse panel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_body), findsNothing);

      await tester.tap(find.bySemanticsLabel('Expand panel'));
      await tester.pump();
      expect(find.byKey(_body), findsOneWidget);
      expect(opacity(), 0);
      // No 0.3s wait for its place in the boot sequence: at 0.15s of 0.5s the
      // flicker is at its second keyframe, 10%.
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(), closeTo(0.1, 1e-9));
      await tester.pump(const Duration(milliseconds: 350));
      expect(opacity(), 1);
      await tester.pumpWidget(const SizedBox());
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

  group('KkPanel semantics', () {
    /// What a screen reader says, node by node, in reading order.
    List<String> read(WidgetTester tester) => <String>[
      for (final SemanticsNode node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.label.isNotEmpty) node.label,
    ];

    /// The labels of the nodes that are announced as headings.
    List<String> headings(WidgetTester tester) => <String>[
      for (final SemanticsNode node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.flagsCollection.isHeader) node.label,
    ];

    testWidgets('the title is one heading, read once; meta, toggle and body follow it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 400,
          child: KkPanel(
            code: 'SEC-04',
            cjk: '電源系統',
            en: 'power',
            meta: '14:02:31Z',
            spine: '第三',
            collapsible: true,
            child: KkColumn(shrinkWrap: true, children: <Widget>[KkText('보조 펌프 B 대기 중.'), KkText('수동 기동 가능.')]),
          ),
        ),
      );
      expect(read(tester), <String>[
        'SEC-04 電源系統 power',
        '14:02:31Z',
        'Collapse panel',
        '第三',
        '보조 펌프 B 대기 중.',
        '수동 기동 가능.',
      ]);
      expect(headings(tester), <String>['SEC-04 電源系統 power']);
      // The panel itself says nothing: it only keeps its parts together.
      expect(tester.getSemantics(find.byType(KkPanel)).label, isEmpty);
      expect(tester.getSemantics(find.byType(KkPanel)).flagsCollection.isHeader, isFalse);
    });

    testWidgets('semanticLabel is read instead of the code and the title', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 400,
          child: KkPanel(
            code: 'SEC-04',
            cjk: '電源系統',
            en: 'power',
            meta: '14:02:31Z',
            semanticLabel: 'Power system, sector four',
            child: KkText('보조 펌프 B 대기 중.'),
          ),
        ),
      );
      expect(read(tester), <String>['Power system, sector four', '14:02:31Z', '보조 펌프 B 대기 중.']);
      expect(headings(tester), <String>['Power system, sector four']);
    });

    testWidgets('a panel without a title has no heading', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 400,
          child: KkPanel(meta: 'CH.12', child: KkText('본문')),
        ),
      );
      expect(read(tester), <String>['CH.12', '본문']);
      expect(headings(tester), isEmpty);
    });

    testWidgets('a head with no room for its title still names the panel', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 168,
          child: KkPanel(
            code: 'SEC-04',
            cjk: '冷却',
            en: 'coolant',
            meta: '14:02:31Z',
            collapsible: true,
            child: KkText('본문'),
          ),
        ),
      );
      // Code, meta and toggle take the whole band and more: 78 + 79 + 32 in 166.
      final Finder titleBox = find.ancestor(of: find.text('冷却'), matching: find.byType(KkBox)).first;
      expect(tester.getSize(titleBox).width, 0);
      expect(headings(tester), <String>['SEC-04 冷却 coolant']);
    });

    testWidgets('widgets in the head and in the body keep their own nodes', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 480,
          child: KkPanel(
            code: 'SEC-04',
            cjk: '電源系統',
            trailing: <Widget>[
              const KkStatusTag('live'),
              KkIconButton(icon: KkIcons.close, semanticLabel: 'Close', onPressed: () {}),
            ],
            child: KkButton(label: 'start', onPressed: () {}),
          ),
        ),
      );
      expect(read(tester), <String>['SEC-04 電源系統', 'LIVE', 'Close', 'START']);
      expect(tester.getSemantics(find.bySemanticsLabel('Close')), isSemantics(isButton: true, hasTapAction: true));
      expect(tester.getSemantics(find.bySemanticsLabel('START')), isSemantics(isButton: true, hasTapAction: true));
      expect(headings(tester), <String>['SEC-04 電源系統']);
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
