import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

void main() {
  setUpAll(loadKkFonts);

  const KkColors c = KkColors.standby;

  group('KkButton', () {
    testWidgets('calls onPressed and onLongPress', (WidgetTester tester) async {
      int presses = 0;
      int holds = 0;
      await pumpKk(tester, KkButton(label: 'ack', onPressed: () => presses++, onLongPress: () => holds++));
      await tester.tap(find.byType(KkButton));
      expect(presses, 1);
      await tester.longPress(find.byType(KkButton));
      expect(holds, 1);
      expect(presses, 1);
    });

    testWidgets('is inert without a callback or with enabled false', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            const KkButton(key: ValueKey<String>('a'), label: 'no callback'),
            KkButton(key: const ValueKey<String>('b'), label: 'off', enabled: false, onPressed: () => presses++),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('a')));
      await tester.tap(find.byKey(const ValueKey<String>('b')));
      expect(presses, 0);
      for (final String key in <String>['a', 'b']) {
        final RenderKkSurface plate = surfaceOf(tester, find.byKey(ValueKey<String>(key)));
        expect(plate.edge, c.offline);
        expect(plate.fill, c.bg100);
      }
      expect(kkTextOf(tester, 'NO CALLBACK').color, c.inkFaint);
    });

    testWidgets('Enter and Space activate it and keyboard focus shows the ring', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(tester, KkButton(label: 'ack', autofocus: true, onPressed: () => presses++));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
      await tester.pump();
      expect(ringOf(tester, find.byType(KkButton)).visible, isTrue);
      expect(ringOf(tester, find.byType(KkButton)).color, c.focus);
    });

    testWidgets('a pointer press does not show the focus ring', (WidgetTester tester) async {
      await pumpKk(tester, KkButton(label: 'ack', onPressed: () {}));
      await tester.tap(find.byType(KkButton));
      await tester.pump();
      expect(ringOf(tester, find.byType(KkButton)).visible, isFalse);
    });

    testWidgets('heights follow the size: 28, 36, 48', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkButton(key: const ValueKey<String>('sm'), label: 'a', size: KkButtonSize.sm, onPressed: () {}),
            KkButton(key: const ValueKey<String>('md'), label: 'a', onPressed: () {}),
            KkButton(key: const ValueKey<String>('lg'), label: 'a', size: KkButtonSize.lg, onPressed: () {}),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('sm'))).height, 28);
      expect(tester.getSize(find.byKey(const ValueKey<String>('md'))).height, 36);
      expect(tester.getSize(find.byKey(const ValueKey<String>('lg'))).height, 48);
    });

    testWidgets('side padding is 12 / 16 / 24 and a leading icon sits 4px closer', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            KkButton(key: const ValueKey<String>('md'), label: 'ack', onPressed: () {}),
            KkButton(key: const ValueKey<String>('icon'), label: 'ack', icon: KkIcons.check, onPressed: () {}),
            KkButton(key: const ValueKey<String>('only'), icon: KkIcons.check, onPressed: () {}),
          ],
        ),
      );
      final Rect md = tester.getRect(find.byKey(const ValueKey<String>('md')));
      final Rect mdText = tester.getRect(
        find.descendant(of: find.byKey(const ValueKey<String>('md')), matching: find.text('ACK')),
      );
      expect(mdText.left - md.left, 16);
      // The plate is rounded up to a whole pixel, and the room that adds is
      // at the right.
      expect(md.right - mdText.right, allOf(greaterThanOrEqualTo(16), lessThan(17)));
      expect(md.width, md.width.roundToDouble());

      final Rect withIcon = tester.getRect(find.byKey(const ValueKey<String>('icon')));
      final Rect icon = tester.getRect(
        find.descendant(of: find.byKey(const ValueKey<String>('icon')), matching: find.byType(KkIcon)),
      );
      expect(icon.left - withIcon.left, 12);

      // An icon on its own is centred: 16 + 16 + 16.
      expect(tester.getSize(find.byKey(const ValueKey<String>('only'))), const Size(48, 36));
    });

    testWidgets('upper-cases the label and puts the cjk word first', (WidgetTester tester) async {
      await pumpKk(tester, KkButton(label: 'acknowledge', cjk: '確認', onPressed: () {}));
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      expect(tester.getCenter(find.text('確認')).dx, lessThan(tester.getCenter(find.text('ACKNOWLEDGE')).dx));
      // The cjk word is set in 長体: 80% of its natural width.
      expect(tester.widget<KkSqueeze>(find.byType(KkSqueeze)).scaleX, 0.8);
    });

    testWidgets('each variant has its own plate, and hover changes it', (WidgetTester tester) async {
      Future<RenderKkSurface> plate(KkButtonVariant variant, {bool hover = false}) async {
        await pumpKk(tester, KkButton(label: 'x', variant: variant, onPressed: () {}));
        if (hover) await hoverOn(tester, find.byType(KkButton));
        return surfaceOf(tester, find.byType(KkButton));
      }

      RenderKkSurface p = await plate(KkButtonVariant.outline);
      expect(<Color?>[p.edge, p.fill], <Color>[c.signal, c.bg100]);
      expect(kkTextOf(tester, 'X').color, c.signal);

      p = await plate(KkButtonVariant.primary);
      expect(<Color?>[p.edge, p.fill], <Color>[c.signal, c.signal]);
      expect(p.glow, isNull);
      expect(kkTextOf(tester, 'X').color, c.onFill);

      p = await plate(KkButtonVariant.danger);
      expect(<Color?>[p.edge, p.fill], <Color>[c.alert, c.bg100]);
      expect(kkTextOf(tester, 'X').color, c.alert);

      p = await plate(KkButtonVariant.ghost);
      expect(p.edge!.a, 0);
      expect(p.fill!.a, 0);

      p = await plate(KkButtonVariant.tonal);
      expect(<Color?>[p.edge, p.fill], <Color>[c.signalDim, c.signalDim]);
      expect(kkTextOf(tester, 'X').color, c.ink);
    });

    testWidgets('hover: outline and ghost fill, primary glows, danger fills red, tonal lights its edge', (
      WidgetTester tester,
    ) async {
      for (final KkButtonVariant variant in KkButtonVariant.values) {
        await pumpKk(
          tester,
          KkStateOverride(
            hovered: true,
            child: KkButton(label: 'x', variant: variant, onPressed: () {}),
          ),
        );
        final RenderKkSurface p = surfaceOf(tester, find.byType(KkButton));
        final Color? ink = kkTextOf(tester, 'X').color;
        switch (variant) {
          case KkButtonVariant.outline:
            expect(p.fill, c.bg300);
          case KkButtonVariant.primary:
            expect(p.fill, c.signal);
            expect(p.glow, const KkGlow(color: Color(0xFFFF7A1A), ring: 0, blur: 12, alpha: 1));
          case KkButtonVariant.danger:
            expect(p.fill, c.alert);
            expect(ink, c.onFill);
          case KkButtonVariant.ghost:
            expect(p.fill, c.bg300);
            expect(p.edge!.a, 0);
          case KkButtonVariant.tonal:
            expect(p.edge, c.signal);
            expect(p.fill, c.signalDim);
        }
      }
    });

    testWidgets('a real mouse pointer hovers and leaves', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkButton(label: 'x', onPressed: () {}),
        padding: const EdgeInsets.all(20),
      );
      expect(surfaceOf(tester, find.byType(KkButton)).fill, c.bg100);
      final TestGesture mouse = await hoverOn(tester, find.byType(KkButton));
      expect(surfaceOf(tester, find.byType(KkButton)).fill, c.bg300);
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(surfaceOf(tester, find.byType(KkButton)).fill, c.bg100);
    });

    testWidgets('pressing shifts the button down 1px', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkButton(label: 'ack', onPressed: () {}),
        padding: const EdgeInsets.all(20),
      );
      final double rest = tester.getTopLeft(find.byType(KkSurface)).dy;
      final TestGesture press = await tester.startGesture(tester.getCenter(find.byType(KkButton)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(KkSurface)).dy, rest + 1);
      await press.up();
      await tester.pump();
      expect(tester.getTopLeft(find.byType(KkSurface)).dy, rest);
    });

    testWidgets('the alert theme turns the signal red', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkButton(label: 'ack', onPressed: () {}),
        condition: KkCondition.alert,
      );
      expect(surfaceOf(tester, find.byType(KkButton)).edge, KkColors.alertTheme.signal);
      expect(surfaceOf(tester, find.byType(KkButton)).fill, KkColors.alertTheme.bg100);
    });

    testWidgets('expand fills the width and centres the content', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 400,
          child: KkButton(label: 'ack', expand: true, onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(KkButton)), const Size(400, 36));
      expect(tester.getCenter(find.text('ACK')).dx, moreOrLessEquals(200, epsilon: 1.5));
    });

    testWidgets('stretches in a column and keeps its content centred', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          child: KkColumn(
            shrinkWrap: true,
            children: <Widget>[KkButton(label: 'ack', onPressed: () {})],
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkButton)).width, 300);
      expect(tester.getCenter(find.text('ACK')).dx, moreOrLessEquals(150, epsilon: 1.5));
    });

    testWidgets('loading ignores presses but keeps the live look', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(tester, KkButton(label: 'engage', loading: true, onPressed: () => presses++));
      await tester.tap(find.byType(KkButton));
      expect(presses, 0);
      final RenderKkSurface p = surfaceOf(tester, find.byType(KkButton));
      expect(p.edge, c.signal);
      expect(p.clip, isTrue);
    });

    testWidgets('loading scans with motion on and stops when it ends', (WidgetTester tester) async {
      await pumpKk(tester, KkButton(label: 'engage', loading: true, onPressed: () {}), motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await pumpKk(tester, KkButton(label: 'engage', onPressed: () {}), motion: true);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a long label is cut with an ellipsis, never overflowed', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 96,
          child: KkButton(label: 'acknowledge every alarm in sector four', cjk: '確認', onPressed: () {}),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkButton)), const Size(96, 36));
      final Rect text = tester.getRect(find.textContaining('ACKNOWLEDGE'));
      expect(text.right, lessThanOrEqualTo(96 - 16 + 0.01));
    });

    testWidgets('survives a box far too small for it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 10,
          height: 6,
          child: KkButton(
            label: 'acknowledge',
            icon: KkIcons.check,
            trailingIcon: KkIcons.chevronRight,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkButton)), const Size(10, 6));
    });

    testWidgets('style overrides the plate colours, hover fields win under the pointer', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkButton(
          label: 'ack',
          onPressed: () {},
          style: KkPlateStyle(edge: c.bg000, fill: c.bg000, ink: c.alert, hoverFill: c.alertDeep),
        ),
      );
      RenderKkSurface p = surfaceOf(tester, find.byType(KkButton));
      expect(<Color?>[p.edge, p.fill], <Color>[c.bg000, c.bg000]);
      expect(kkTextOf(tester, 'ACK').color, c.alert);
      await hoverOn(tester, find.byType(KkButton));
      p = surfaceOf(tester, find.byType(KkButton));
      expect(p.fill, c.alertDeep);
      expect(p.edge, c.bg000);
    });

    testWidgets('a child replaces the text and inherits the ink', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkButton(variant: KkButtonVariant.primary, onPressed: () {}, child: const KkText('T-00:42')),
      );
      final RenderParagraph text = tester.renderObject<RenderParagraph>(find.text('T-00:42'));
      expect(text.text.style!.color, c.onFill);
    });

    testWidgets('semanticLabel replaces the visible text', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkButton(icon: KkIcons.download, onPressed: () {}, semanticLabel: 'Download log'));
      expect(find.bySemanticsLabel('Download log'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Download log')),
        isSemantics(label: 'Download log', isButton: true, hasTapAction: true, isEnabled: true, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('KkStateOverride pins a state but never on a disabled button', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkStateOverride(
          hovered: true,
          focused: true,
          child: KkRow(
            shrinkWrap: true,
            children: <Widget>[
              KkButton(key: const ValueKey<String>('live'), label: 'a', onPressed: () {}),
              const KkButton(key: ValueKey<String>('off'), label: 'a'),
            ],
          ),
        ),
      );
      expect(surfaceOf(tester, find.byKey(const ValueKey<String>('live'))).fill, c.bg300);
      expect(ringOf(tester, find.byKey(const ValueKey<String>('live'))).visible, isTrue);
      expect(surfaceOf(tester, find.byKey(const ValueKey<String>('off'))).fill, c.bg100);
      expect(ringOf(tester, find.byKey(const ValueKey<String>('off'))).visible, isFalse);
    });
  });

  group('KkIconButton', () {
    testWidgets('is 24, 32 or 40 square and calls onPressed', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkIconButton(
              key: const ValueKey<String>('sm'),
              icon: KkIcons.close,
              size: KkIconButtonSize.sm,
              onPressed: () => presses++,
            ),
            KkIconButton(key: const ValueKey<String>('md'), icon: KkIcons.close, onPressed: () => presses++),
            KkIconButton(
              key: const ValueKey<String>('lg'),
              icon: KkIcons.close,
              size: KkIconButtonSize.lg,
              onPressed: () => presses++,
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('sm'))), const Size(24, 24));
      expect(tester.getSize(find.byKey(const ValueKey<String>('md'))), const Size(32, 32));
      expect(tester.getSize(find.byKey(const ValueKey<String>('lg'))), const Size(40, 40));
      await tester.tap(find.byKey(const ValueKey<String>('sm')));
      await tester.tap(find.byKey(const ValueKey<String>('md')));
      await tester.tap(find.byKey(const ValueKey<String>('lg')));
      expect(presses, 3);
    });

    testWidgets('variants, hover, toggled and disabled colours', (WidgetTester tester) async {
      Future<(RenderKkSurface, Color)> look(
        KkIconButtonVariant variant, {
        bool hover = false,
        bool? toggled,
        bool live = true,
      }) async {
        await pumpKk(
          tester,
          KkStateOverride(
            hovered: hover,
            child: KkIconButton(
              icon: KkIcons.settings,
              variant: variant,
              toggled: toggled,
              onPressed: live ? () {} : null,
            ),
          ),
        );
        return (surfaceOf(tester, find.byType(KkIconButton)), tester.widget<KkIcon>(find.byType(KkIcon)).color!);
      }

      var (RenderKkSurface p, Color ink) = await look(KkIconButtonVariant.plain);
      expect(p.edge!.a, 0);
      expect(p.fill!.a, 0);
      expect(ink, c.inkDim);

      (p, ink) = await look(KkIconButtonVariant.plain, hover: true);
      expect(p.fill, c.bg300);
      expect(ink, c.ink);

      (p, ink) = await look(KkIconButtonVariant.outline);
      expect(<Color?>[p.edge, p.fill, ink], <Color>[c.inkFaint, c.bg100, c.inkDim]);

      (p, ink) = await look(KkIconButtonVariant.outline, hover: true);
      expect(<Color?>[p.edge, p.fill, ink], <Color>[c.signal, c.bg300, c.ink]);

      (p, ink) = await look(KkIconButtonVariant.filled);
      expect(<Color?>[p.edge, p.fill, ink], <Color>[c.signal, c.signal, c.onFill]);
      expect(p.glow, isNull);

      (p, ink) = await look(KkIconButtonVariant.filled, hover: true);
      expect(p.glow, isNotNull);

      (p, ink) = await look(KkIconButtonVariant.tonal);
      expect(<Color?>[p.edge, p.fill, ink], <Color>[c.signalDim, c.signalDim, c.ink]);

      (p, ink) = await look(KkIconButtonVariant.tonal, hover: true);
      expect(<Color?>[p.edge, p.fill], <Color>[c.signalDim, c.bg300]);

      for (final KkIconButtonVariant variant in KkIconButtonVariant.values) {
        (p, ink) = await look(variant, toggled: true);
        expect(<Color?>[p.edge, p.fill, ink], <Color>[c.signal, c.signalDim, c.signal], reason: '$variant toggled');
      }

      (p, ink) = await look(KkIconButtonVariant.plain, live: false);
      expect(p.edge!.a, 0);
      expect(p.fill!.a, 0);
      expect(ink, c.inkFaint);

      (p, ink) = await look(KkIconButtonVariant.outline, live: false);
      expect(<Color?>[p.edge, p.fill, ink], <Color>[c.offline, c.bg100, c.inkFaint]);
    });

    testWidgets('disabled filled, tonal and toggled buttons are empty frames, not lit blocks', (
      WidgetTester tester,
    ) async {
      CustomPaint frame() => tester.widget<CustomPaint>(
        find.descendant(of: find.byType(KkPlate), matching: find.byType(CustomPaint)).first,
      );

      for (final (KkIconButtonVariant variant, bool? toggled) in <(KkIconButtonVariant, bool?)>[
        (KkIconButtonVariant.filled, null),
        (KkIconButtonVariant.tonal, null),
        (KkIconButtonVariant.plain, true),
        (KkIconButtonVariant.filled, true),
      ]) {
        await pumpKk(tester, KkIconButton(icon: KkIcons.settings, variant: variant, toggled: toggled));
        final RenderKkSurface p = surfaceOf(tester, find.byType(KkIconButton));
        expect(p.edge, isNull, reason: '$variant $toggled: no solid edge plate');
        expect(p.fill!.a, 0, reason: '$variant $toggled');
        expect(frame().painter, isNotNull, reason: '$variant $toggled: outlined instead');
        expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, c.inkFaint);
      }

      // A live filled button is a real plate, with no outline painter.
      await pumpKk(tester, KkIconButton(icon: KkIcons.settings, variant: KkIconButtonVariant.filled, onPressed: () {}));
      expect(surfaceOf(tester, find.byType(KkIconButton)).edge, c.signal);
      expect(frame().painter, isNull);
    });

    testWidgets('the badge is pinned 5px above and 7px outside the top-right corner', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkIconButton(icon: KkIcons.bell, badge: const KkBadge(count: 7), onPressed: () {}),
        padding: const EdgeInsets.all(40),
      );
      final Rect button = tester.getRect(find.byType(KkSurface).first);
      final Rect badge = tester.getRect(find.byType(KkBadge));
      expect(badge.top, button.top - 5);
      expect(badge.right, button.right + 7);
      // The button itself keeps its size.
      expect(button.size, const Size(32, 32));
    });

    testWidgets('a toggle button reports its state to accessibility', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkIconButton(icon: KkIcons.bell, toggled: true, onPressed: () {}, semanticLabel: 'Audible alarm'),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Audible alarm')),
        isSemantics(
          label: 'Audible alarm',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('spinTrigger turns the icon once in 8 steps over 0.6s', (WidgetTester tester) async {
      Widget build(int trigger) =>
          KkIconButton(icon: KkIcons.refresh, spinTrigger: trigger, onPressed: () {}, semanticLabel: 'Refresh');

      double angle() {
        final Transform t = tester.widget<Transform>(
          find.descendant(of: find.byType(KkIconButton), matching: find.byType(Transform)).first,
        );
        // rotationZ: sin is entry (1, 0), cos is entry (0, 0).
        final double sin = t.transform.entry(1, 0);
        final double cos = t.transform.entry(0, 0);
        return (sin == 0 && cos == 1) ? 0 : (cos.abs() < 1e-9 ? (sin > 0 ? 0.25 : 0.75) : -1);
      }

      await pumpKk(tester, build(0), motion: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(angle(), 0, reason: 'no spin when first shown');

      await tester.pumpWidget(kkHarness(build(1), motion: true));
      await tester.pump();
      // 2/8 of a turn after 150ms..225ms: a quarter turn.
      await tester.pump(const Duration(milliseconds: 160));
      expect(angle(), 0.25);
      await tester.pump(const Duration(milliseconds: 600));
      expect(angle(), 0, reason: 'a full turn ends where it began');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('spinTrigger does nothing with motion off', (WidgetTester tester) async {
      Widget build(int trigger) => KkIconButton(icon: KkIcons.refresh, spinTrigger: trigger, onPressed: () {});
      await pumpKk(tester, build(0));
      await tester.pumpWidget(kkHarness(build(1)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('spinning keeps turning and stops when switched off', (WidgetTester tester) async {
      Widget build(bool spinning) => KkIconButton(icon: KkIcons.sync, spinning: spinning, onPressed: () {});
      await pumpKk(tester, build(true), motion: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(kkHarness(build(false), motion: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('KkFab', () {
    testWidgets('hexagon sizes and the extended plate', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkFab(key: const ValueKey<String>('md'), icon: KkIcons.plus, onPressed: () => presses++),
            KkFab(key: const ValueKey<String>('sm'), icon: KkIcons.plus, size: KkFabSize.sm, onPressed: () {}),
            KkFab.extended(
              key: const ValueKey<String>('ext'),
              label: 'new report',
              icon: KkIcons.plus,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('md'))), const Size(56, 64));
      expect(tester.getSize(find.byKey(const ValueKey<String>('sm'))), const Size(40, 46));
      expect(tester.getSize(find.byKey(const ValueKey<String>('ext'))).height, 48);
      expect(find.text('NEW REPORT'), findsOneWidget);
      final Rect ext = tester.getRect(find.byKey(const ValueKey<String>('ext')));
      final Rect icon = tester.getRect(
        find.descendant(of: find.byKey(const ValueKey<String>('ext')), matching: find.byType(KkIcon)),
      );
      expect(icon.left - ext.left, 16);
      // The plate is rounded up to a whole pixel, and the room that adds is
      // at the right.
      expect(ext.right - tester.getRect(find.text('NEW REPORT')).right, allOf(greaterThanOrEqualTo(24), lessThan(25)));
      expect(ext.width, ext.width.roundToDouble());
      await tester.tap(find.byKey(const ValueKey<String>('md')));
      expect(presses, 1);
    });

    testWidgets('fill by variant, hover glow, disabled', (WidgetTester tester) async {
      await pumpKk(tester, KkFab(icon: KkIcons.plus, onPressed: () {}));
      expect(surfaceOf(tester, find.byType(KkFab)).fill, c.signal);
      expect(surfaceOf(tester, find.byType(KkFab)).glow, isNull);
      await hoverOn(tester, find.byType(KkFab));
      expect(surfaceOf(tester, find.byType(KkFab)).glow, KkGlow(color: c.signal, ring: 0, blur: 16, alpha: 1));

      await pumpKk(tester, KkFab(icon: KkIcons.power, variant: KkFabVariant.danger, onPressed: () {}));
      expect(surfaceOf(tester, find.byType(KkFab)).fill, c.alert);

      await pumpKk(tester, const KkFab(icon: KkIcons.plus));
      expect(surfaceOf(tester, find.byType(KkFab)).fill, c.offline);
    });

    testWidgets('keyboard focus ring sits 3px out', (WidgetTester tester) async {
      await pumpKk(tester, KkFab(icon: KkIcons.plus, autofocus: true, onPressed: () {}));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final RenderKkFocusRing ring = ringOf(tester, find.byType(KkFab));
      expect(ring.visible, isTrue);
      expect(ring.offset, 3);
    });
  });

  group('KkBadge', () {
    testWidgets('count, cap and label', (WidgetTester tester) async {
      expect(const KkBadge(count: 3).text, '3');
      expect(const KkBadge(count: 99).text, '99');
      expect(const KkBadge(count: 128).text, '99+');
      expect(const KkBadge(count: 12, max: 9).text, '9+');
      expect(const KkBadge(label: 'NEW').text, 'NEW');
      expect(const KkBadge(count: -4).text, '-4');
    });

    testWidgets('is 16 high, at least 16 wide, and a dot is 8 square', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkBadge(key: ValueKey<String>('one'), count: 3),
            KkBadge(key: ValueKey<String>('wide'), count: 128),
            KkBadge.dot(key: ValueKey<String>('dot')),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('one'))), const Size(16, 16));
      final Size wide = tester.getSize(find.byKey(const ValueKey<String>('wide')));
      expect(wide.height, 16);
      expect(wide.width, greaterThan(16));
      expect(tester.getSize(find.byKey(const ValueKey<String>('dot'))), const Size(8, 8));
    });

    testWidgets('is alert by default and takes a level colour', (WidgetTester tester) async {
      await pumpKk(tester, const KkBadge(count: 1));
      expect(surfaceOf(tester, find.byType(KkBadge)).fill, c.alert);
      await pumpKk(tester, const KkBadge(count: 1, level: KkLevel.caution));
      expect(surfaceOf(tester, find.byType(KkBadge)).fill, c.caution);
    });

    testWidgets('KkBadgeAnchor pins the badge 6px up and 8px out, and can hide it', (WidgetTester tester) async {
      Widget build(bool show) => KkBadgeAnchor(
        show: show,
        badge: const KkBadge(count: 5),
        child: const KkBox(key: ValueKey<String>('host'), width: 40, height: 20),
      );
      await pumpKk(tester, build(true), padding: const EdgeInsets.all(40));
      final Rect host = tester.getRect(find.byKey(const ValueKey<String>('host')));
      final Rect badge = tester.getRect(find.byType(KkBadge));
      expect(badge.top, host.top - 6);
      expect(badge.right, host.right + 8);
      expect(tester.getSize(find.byType(KkBadgeAnchor)), const Size(40, 20));
      await tester.pumpWidget(kkHarness(build(false), padding: const EdgeInsets.all(40)));
      expect(find.byType(KkBadge), findsNothing);
      expect(tester.getSize(find.byType(KkBadgeAnchor)), const Size(40, 20));
    });
  });

  group('KkStatusTag and KkKbd', () {
    testWidgets('a level tag says the state three ways', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTag.status(KkLevel.critical));
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('警報'), findsOneWidget);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, KkLevel.critical);
      expect(kkTextOf(tester, 'CRITICAL').color, c.alert);
    });

    testWidgets('no level: INFO in signal with the info plate', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTag.status(null));
      expect(find.text('INFO'), findsOneWidget);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, isNull);
      expect(kkTextOf(tester, 'INFO').color, c.signal);
    });

    testWidgets('heights are 22 and 28; a plain tag has no glyph', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkStatusTag('standby', key: ValueKey<String>('md')),
            KkStatusTag('standby', key: ValueKey<String>('lg'), size: KkStatusTagSize.lg),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('md'))).height, 22);
      expect(tester.getSize(find.byKey(const ValueKey<String>('lg'))).height, 28);
      expect(find.byType(KkGlyph), findsNothing);
      // 8px side padding inside the 1px outline.
      final Rect tag = tester.getRect(find.byKey(const ValueKey<String>('md')));
      final Rect text = tester.getRect(find.text('STANDBY').first);
      expect(text.left - tag.left, 9);
    });

    testWidgets('solid fills with the level colour and uses the on-fill ink', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTag.status(KkLevel.nominal, variant: KkStatusTagVariant.solid));
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: find.byType(KkStatusTag), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.fill, c.nominal);
      expect(kkTextOf(tester, 'NOMINAL').color, c.onFill);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).color, c.onFill);
    });

    testWidgets('glyph, icon, colour and cjk options', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkStatusTag('caution', level: KkLevel.caution, glyph: false),
            KkStatusTag('live', icon: KkIcons.pulse),
            KkStatusTag.status(KkLevel.offline, showCjk: false),
            KkStatusTag('custom', cjk: '待機', color: Color(0xFF123456)),
          ],
        ),
      );
      expect(find.byType(KkGlyph), findsOneWidget);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).icon, KkIcons.pulse);
      expect(find.text('断線'), findsNothing);
      expect(find.text('待機'), findsOneWidget);
      expect(kkTextOf(tester, 'CUSTOM').color, const Color(0xFF123456));
    });

    testWidgets('KkKbd is 18 high with a 2px bottom edge', (WidgetTester tester) async {
      await pumpKk(tester, const KkKbd('ESC'));
      expect(tester.getSize(find.byType(KkKbd)).height, 18);
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: find.byType(KkKbd), matching: find.byType(KkBox)),
      );
      expect(box.decoration!.edges.bottom.width, 2);
      expect(box.decoration!.edges.top.width, 1);
      expect(box.decoration!.edges.top.color, c.inkFaint);
      expect(find.text('ESC'), findsOneWidget);
    });
  });
}
