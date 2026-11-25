import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

/// Puts [child] in a row, where the width is unbounded and controls fall back
/// to their minimum width.
Widget _hug(Widget child) => KkRow(shrinkWrap: true, cross: KkCrossAlign.start, children: <Widget>[child]);

void main() {
  setUpAll(loadKkFonts);

  const KkColors c = KkColors.standby;

  group('scan maths', () {
    test('a quarter-width bar travels from fully off the left to fully off the right', () {
      expect(kkScanOffset(0, 20), -0.25);
      expect(kkScanOffset(10, 20), 0.375);
      expect(kkScanOffset(19, 20), closeTo(0.9375, 1e-9));
      expect(kkScanOffset(20, 20), -0.25, reason: 'the phase wraps');
      expect(kkScanOffset(0, 14, widthFactor: 0.5), -0.5);
      expect(kkScanOffset(7, 14, widthFactor: 0.5), 0.25);
    });

    test('lit length snaps down to the 8px pitch', () {
      expect(KkProgress.litWidth(0.42, 240), 96);
      expect(KkProgress.litWidth(0.5, 240), 120);
      expect(KkProgress.litWidth(0.5, 163), 80);
      expect(KkProgress.litWidth(0.049, 160), 0, reason: 'less than one segment');
      expect(KkProgress.litWidth(0.05, 160), 8);
      expect(KkProgress.litWidth(0.999, 160), 152);
      expect(KkProgress.litWidth(1, 163), 163, reason: 'a full bar is lit to its end');
      expect(KkProgress.litWidth(7, 160), 160);
      expect(KkProgress.litWidth(-1, 160), 0);
      expect(KkProgress.litWidth(double.nan, 160), 0);
      expect(KkProgress.litWidth(0.5, 0), 0);
      expect(KkProgress.litWidth(0.5, 100, pitch: 0), 50);
      // Exact multiples are not lost to floating point.
      for (int i = 0; i <= 20; i++) {
        expect(KkProgress.litWidth(i / 20, 160), i * 8.0, reason: '$i / 20');
      }
    });
  });

  group('KkProgress', () {
    testWidgets('is 160 wide at least; the bar is 6 high, 6px under the head', (WidgetTester tester) async {
      await pumpKk(tester, _hug(const KkProgress(value: 0.42, cjk: '転送', en: 'transfer')));
      expect(tester.getSize(find.byType(KkProgress)).width, 160);
      final Finder bar = find.descendant(of: find.byType(KkProgress), matching: find.byType(CustomPaint));
      expect(tester.getSize(bar), const Size(160, 6));
      final Rect head = tester.getRect(
        find.descendant(of: find.byType(KkProgress), matching: find.byType(KkRow)).first,
      );
      expect(tester.getRect(bar).top - head.bottom, 6);
      expect(find.text('042'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('TRANSFER'), findsOneWidget);
      expect(tester.getRect(find.text('%')).right, moreOrLessEquals(160, epsilon: 0.01));
      expect(
        tester.getRect(find.text('%')).left - tester.getRect(find.text('042')).right,
        moreOrLessEquals(2, epsilon: 0.01),
      );
    });

    testWidgets('takes the width it is offered, with or without a head', (WidgetTester tester) async {
      await pumpKk(tester, const KkProgress(value: 0.3, showValue: false));
      expect(tester.getSize(find.byType(KkProgress)), const Size(800, 6));
      await pumpKk(tester, const KkBox(width: 96, child: KkProgress(value: 0.3, en: 'queue')));
      expect(tester.getSize(find.byType(KkProgress)).width, 96);
      expect(tester.takeException(), isNull);
    });

    testWidgets('formats the value, or hides it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          children: <Widget>[
            KkProgress(value: 0.5, format: (double v) => '${(v * 8).round()}/8', unit: ''),
            const KkProgress(value: 1),
            const KkProgress(value: 0),
            const KkProgress(value: 0.5, showValue: false, en: 'bar only'),
          ],
        ),
      );
      expect(find.text('4/8'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('000'), findsOneWidget);
      expect(find.text('050'), findsNothing);
    });

    testWidgets('clamps silly values instead of throwing', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkColumn(
          shrinkWrap: true,
          children: <Widget>[
            KkProgress(value: -3),
            KkProgress(value: 42),
            KkProgress(value: double.nan),
            KkProgress(value: double.infinity),
            KkBox(width: 3, child: KkProgress(value: 0.5)),
            KkBox(width: 0, height: 0, child: KkProgress(value: 0.5)),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('000'), findsWidgets);
      expect(find.text('100'), findsWidgets);
    });

    testWidgets('a change of value steps there over 0.45s in 9 steps', (WidgetTester tester) async {
      await pumpKk(tester, const KkProgress(value: 0.2), motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no entrance animation');

      await tester.pumpWidget(kkHarness(const KkProgress(value: 0.8), motion: true));
      final KkSteppedValue stepped = tester.widget<KkSteppedValue>(find.byType(KkSteppedValue));
      expect(stepped.duration, const Duration(milliseconds: 450));
      expect(stepped.steps, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // The text changes at once; only the bar steps.
      expect(find.text('080'), findsOneWidget);
    });

    testWidgets('indeterminate: scans with motion on, rests with motion off', (WidgetTester tester) async {
      await pumpKk(tester, const KkProgress.indeterminate(cjk: '接続', en: 'handshake'), motion: true);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(tester.takeException(), isNull);
      expect(find.text('%'), findsNothing);

      await pumpKk(tester, const KkProgress.indeterminate());
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('accessibility: a label and a percentage', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkProgress(value: 0.42, en: 'transfer'));
      expect(tester.getSemantics(find.bySemanticsLabel('transfer')), isSemantics(label: 'transfer', value: '042%'));
      handle.dispose();
    });
  });

  group('KkRing', () {
    testWidgets('is 48 square with the percentage at its centre', (WidgetTester tester) async {
      await pumpKk(tester, const KkRing(value: 0.25), padding: const EdgeInsets.all(10));
      expect(tester.getSize(find.byType(KkRing)), const Size(48, 48));
      expect(find.text('25'), findsOneWidget);
      expect(tester.getCenter(find.text('25')).dx, moreOrLessEquals(34, epsilon: 0.5));
      expect(tester.getCenter(find.text('25')).dy, moreOrLessEquals(34, epsilon: 0.5));
      expect(kkTextOf(tester, '25').color, c.ink);
    });

    testWidgets('size, label, child and hidden value', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            KkRing(key: ValueKey<String>('a'), value: 0.5, size: 32, showValue: false),
            KkRing(key: ValueKey<String>('b'), value: 0.7, size: 64, strokeWidth: 6, label: 'T-12'),
            KkRing(key: ValueKey<String>('c'), value: 0.05),
            KkRing(key: ValueKey<String>('d'), value: 1, child: KkIcon(KkIcons.check)),
            KkRing(key: ValueKey<String>('e'), value: 3),
            KkRing(key: ValueKey<String>('f'), value: double.nan),
            KkRing(key: ValueKey<String>('g'), value: 0.3, size: 2, strokeWidth: 9),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey<String>('a'))), const Size(32, 32));
      expect(tester.getSize(find.byKey(const ValueKey<String>('b'))), const Size(64, 64));
      expect(find.text('T-12'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.text('50'), findsNothing);
      expect(find.byType(KkIcon), findsOneWidget);
      expect(find.text('100'), findsOneWidget, reason: 'values above 1 clamp to full');
      expect(find.text('00'), findsOneWidget, reason: 'NaN reads as zero');
    });

    testWidgets('steps to a new value; indeterminate turns only with motion', (WidgetTester tester) async {
      await pumpKk(tester, const KkRing(value: 0.2), motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(kkHarness(const KkRing(value: 0.9), motion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await pumpKk(tester, const KkRing.indeterminate(), motion: true);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await pumpKk(tester, const KkRing.indeterminate());
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byType(KkText), findsNothing);
    });
  });

  group('KkDivider', () {
    testWidgets('a plain rule is 1px high and as wide as it is allowed', (WidgetTester tester) async {
      await pumpKk(tester, const KkDivider());
      expect(tester.getSize(find.byType(KkDivider)), const Size(800, 1));
      final RenderKkBox rule = tester.renderObject<RenderKkBox>(find.byType(KkBox).last);
      expect(rule.decoration!.fill, c.line);
    });

    testWidgets('code and label sit before the rule; ticks make it 6px', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkColumn(
          shrinkWrap: true,
          gap: 10,
          children: <Widget>[
            KkDivider(key: ValueKey<String>('label'), code: 'SEC-04', cjk: '冷却', en: 'coolant'),
            KkDivider(key: ValueKey<String>('ticks'), ticks: true),
          ],
        ),
      );
      expect(find.text('SEC-04'), findsOneWidget);
      expect(find.text('COOLANT'), findsOneWidget);
      expect(kkTextOf(tester, 'SEC-04').color, c.signal);
      final Rect labelled = tester.getRect(find.byKey(const ValueKey<String>('label')));
      expect(labelled.width, 800);
      expect(labelled.height, greaterThan(12));
      // The rule starts 8px after the label and runs to the right edge.
      final Rect en = tester.getRect(find.text('COOLANT'));
      final Finder rules = find.descendant(
        of: find.byKey(const ValueKey<String>('label')),
        matching: find.byType(KkBox),
      );
      final Rect rule = tester.getRect(rules.last);
      expect(rule.left - en.right, moreOrLessEquals(8, epsilon: 0.01));
      expect(rule.right, moreOrLessEquals(800, epsilon: 0.01));
      expect(rule.height, 1);
      expect(tester.getSize(find.byKey(const ValueKey<String>('ticks'))), const Size(800, 6));
    });

    testWidgets('vertical: 1px wide, at least 16 tall, stretchable in a row', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          height: 40,
          child: KkRow(
            shrinkWrap: true,
            gap: 8,
            children: <Widget>[
              KkDivider.vertical(key: ValueKey<String>('min')),
              KkDivider.vertical(key: ValueKey<String>('fixed'), height: 24),
              KkAlignSelf(
                align: KkCrossAlign.stretch,
                child: KkDivider.vertical(key: ValueKey<String>('stretch')),
              ),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey<String>('min'))), const Size(1, 16));
      expect(tester.getSize(find.byKey(const ValueKey<String>('fixed'))), const Size(1, 24));
      expect(tester.getSize(find.byKey(const ValueKey<String>('stretch'))), const Size(1, 40));
    });

    testWidgets('a custom colour replaces the line token', (WidgetTester tester) async {
      await pumpKk(tester, const KkDivider.vertical(color: Color(0xFF123456)));
      final RenderKkBox rule = tester.renderObject<RenderKkBox>(find.byType(KkBox).last);
      expect(rule.decoration!.fill, const Color(0xFF123456));
    });
  });

  group('KkSkeleton', () {
    testWidgets('three 10px lines 8px apart, at least 120 wide', (WidgetTester tester) async {
      await pumpKk(tester, _hug(const KkSkeleton()));
      expect(tester.getSize(find.byType(KkSkeleton)), const Size(120, 46));
      expect(find.byType(KkScanBar), findsNWidgets(3));
      final KkScanBar scan = tester.widget<KkScanBar>(find.byType(KkScanBar).first);
      expect(scan.period, const Duration(milliseconds: 1400));
      expect(scan.steps, 14);
      expect(scan.color, c.signalDim);
    });

    testWidgets('widths shorten lines; a block is one tall bar', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 200,
          child: KkColumn(
            shrinkWrap: true,
            gap: 10,
            children: <Widget>[
              KkSkeleton(
                key: ValueKey<String>('lines'),
                widths: <double>[1, 0.5, 0, 7],
                lines: 5,
                lineHeight: 8,
                gap: 4,
              ),
              KkSkeleton.block(key: ValueKey<String>('block'), height: 96),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey<String>('lines'))), const Size(200, 5 * 8 + 4 * 4));
      final Finder bars = find.descendant(
        of: find.byKey(const ValueKey<String>('lines')),
        matching: find.byType(KkScanBar),
      );
      expect(tester.getSize(bars.at(0)).width, 200);
      expect(tester.getSize(bars.at(1)).width, 100);
      expect(tester.getSize(bars.at(2)).width, 0);
      expect(tester.getSize(bars.at(3)).width, 200);
      expect(tester.getSize(bars.at(4)).width, 200);
      expect(tester.getSize(find.byKey(const ValueKey<String>('block'))), const Size(200, 96));
    });

    testWidgets('scans with motion on, rests with motion off', (WidgetTester tester) async {
      await pumpKk(tester, const KkSkeleton(), motion: true);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await pumpKk(tester, const KkSkeleton());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('is announced as loading unless told otherwise', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkSkeleton());
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await pumpKk(tester, const KkSkeleton(semanticLabel: null));
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      handle.dispose();
    });
  });

  group('KkEmpty', () {
    testWidgets('is at least 168 high with a dashed outline and centred text', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 320,
          child: KkEmpty(cjk: '無記録', en: 'no records', sub: 'SEC-04 · 0 EVENTS'),
        ),
      );
      expect(tester.getSize(find.byType(KkEmpty)), const Size(320, 168));
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: find.byType(KkEmpty), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.edges.top.dashed, isTrue);
      expect(box.decoration!.edges.top.color, c.inkFaint);
      expect(box.decoration!.fill, c.bg000);
      expect(find.text('NO RECORDS'), findsOneWidget);
      expect(tester.getCenter(find.text('NO RECORDS')).dx, moreOrLessEquals(160, epsilon: 1));
      // The text block is centred in the box.
      final double top = tester.getRect(find.text('無記録')).top;
      final double bottom = tester.getRect(find.text('SEC-04 · 0 EVENTS')).bottom;
      expect((top + bottom) / 2, moreOrLessEquals(84, epsilon: 1.5));
    });

    testWidgets('grows with its content and wraps a long explanation', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          child: KkEmpty(
            cjk: '無記録',
            en: 'no records',
            sub: 'NO EVENT MATCHES THE FILTER SEC-04 BETWEEN 14:00:00Z AND 15:00:00Z ON ANY CHANNEL OF BUS A OR BUS B',
            loading: true,
            action: KkButton(label: 'reset filter', onPressed: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkEmpty)).height, greaterThan(168));
      expect(find.byType(KkProgress), findsOneWidget);
      expect(tester.getSize(find.byType(KkProgress)).width, 150, reason: '160 does not fit in 200 − 2 × 25');
    });

    testWidgets('the action is live', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(
        tester,
        KkEmpty(
          cjk: '照会中',
          en: 'querying',
          action: KkButton(label: 'cancel', onPressed: () => presses++),
        ),
      );
      await tester.tap(find.text('CANCEL'));
      expect(presses, 1);
      expect(tester.getSize(find.byType(KkEmpty)).width, 800);
    });

    testWidgets('no signal: solid offline outline, flickering title, noise', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 320, child: KkEmpty.noSignal(sub: 'CH.12')));
      expect(find.text('無信号'), findsOneWidget);
      expect(find.text('NO SIGNAL'), findsOneWidget);
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: find.byType(KkEmpty), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.edges.top.dashed, isFalse);
      expect(box.decoration!.edges.top.color, c.offline);
      expect(find.byType(KkCrt), findsOneWidget);
      // With motion off the title is simply there.
      expect(find.descendant(of: find.byType(KkEmpty), matching: find.byType(Opacity)), findsNothing);

      await pumpKk(tester, const KkBox(width: 320, child: KkEmpty.noSignal(noise: false)), motion: true);
      expect(find.byType(KkCrt), findsNothing);
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isTrue);
      final Opacity flicker = tester.widget<Opacity>(
        find.descendant(of: find.byType(KkEmpty), matching: find.byType(Opacity)),
      );
      expect(flicker.opacity, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('nothing at all is still a box', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 100, child: KkEmpty(minHeight: 40, padding: EdgeInsets.zero)));
      expect(tester.getSize(find.byType(KkEmpty)), const Size(100, 40));
    });
  });
}
