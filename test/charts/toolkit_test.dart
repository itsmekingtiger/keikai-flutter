import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

class _Probe extends CustomPainter {
  _Probe(this.onPaint);

  final void Function(Canvas canvas, Size size) onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint(canvas, size);

  @override
  bool shouldRepaint(_Probe oldDelegate) => true;
}

void main() {
  setUpAll(loadKkFonts);

  group('KkCanvas', () {
    testWidgets('fills the width; natural height when free, the given height when fixed', (WidgetTester tester) async {
      await pumpKk(tester, const KkCanvas(naturalHeight: 90));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(800, 90));
      await pumpKk(tester, const KkBox(width: 300, height: 200, child: KkCanvas(naturalHeight: 90)));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(300, 200));
      await pumpKk(tester, const KkRow(children: <Widget>[KkCanvas(naturalWidth: 111, naturalHeight: 22)]));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(111, 22));
      // Shorter than natural: it shrinks rather than overflow.
      await pumpKk(
        tester,
        const KkBox(width: 300, maxHeight: 40, alignment: Alignment.topLeft, child: KkCanvas(naturalHeight: 90)),
      );
      expect(tester.getSize(find.byType(KkCanvas)).height, 40);
    });

    testWidgets('aspect ratio follows the width up to maxContentWidth', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 224,
          alignment: Alignment.topLeft,
          child: KkCanvas(aspectRatio: 2, insetWidth: 24, extraHeight: 16, maxContentWidth: 300),
        ),
      );
      expect(tester.getSize(find.byType(KkCanvas)), const Size(224, 100 + 16));
      await pumpKk(tester, const KkCanvas(aspectRatio: 2, insetWidth: 24, extraHeight: 16, maxContentWidth: 300));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(800, 150 + 16));
      // A bad ratio falls back to the natural height.
      await pumpKk(tester, const KkCanvas(aspectRatio: 0, naturalHeight: 33));
      expect(tester.getSize(find.byType(KkCanvas)).height, 33);
      await pumpKk(tester, const KkCanvas(aspectRatio: double.nan, naturalHeight: 34));
      expect(tester.getSize(find.byType(KkCanvas)).height, 34);
    });

    testWidgets('paints with its painters', (WidgetTester tester) async {
      Size? seen;
      await pumpKk(
        tester,
        KkBox(width: 120, height: 60, child: KkCanvas(painter: _Probe((Canvas canvas, Size size) => seen = size))),
      );
      expect(seen, const Size(120, 60));
    });
  });

  group('KkNaturalHeight', () {
    testWidgets('free height: natural; fixed height: forced', (WidgetTester tester) async {
      const Widget child = KkNaturalHeight(
        child: KkColumn(
          children: <Widget>[
            KkBox(height: 30),
            KkExpanded(child: KkBox(height: 50)),
          ],
        ),
      );
      // Loose 0..600: stays at 80 instead of filling.
      await pumpKk(tester, child);
      expect(tester.getSize(find.byType(KkNaturalHeight)).height, 80);
      // Tight: forced.
      await pumpKk(tester, const KkBox(width: 200, height: 300, child: child));
      expect(tester.getSize(find.byType(KkNaturalHeight)), const Size(200, 300));
      // Natural does not fit: laid out at the limit instead of overflowing.
      await pumpKk(tester, const KkBox(width: 200, maxHeight: 60, alignment: Alignment.topLeft, child: child));
      expect(tester.getSize(find.byType(KkNaturalHeight)).height, 60);
      // A minimum taller than natural stretches it.
      await pumpKk(tester, const KkBox(width: 200, minHeight: 120, alignment: Alignment.topLeft, child: child));
      expect(tester.getSize(find.byType(KkNaturalHeight)).height, greaterThanOrEqualTo(80));
      await pumpKk(tester, const KkNaturalHeight());
      expect(tester.takeException(), isNull);
    });
  });

  group('KkChartFrame', () {
    testWidgets('framed: head, body and legend; bare: body and legend only', (WidgetTester tester) async {
      const List<Widget> keys = <Widget>[KkWidgetKey(label: 'SEC-01')];
      await pumpKk(
        tester,
        const KkChartFrame(
          cjk: '冷却水温',
          en: 'coolant temp',
          meta: 'META',
          legend: keys,
          child: KkCanvas(naturalHeight: 50),
        ),
      );
      expect(find.byType(KkWidgetFrame), findsOneWidget);
      expect(find.text('META'), findsOneWidget);
      expect(find.text('SEC-01'), findsOneWidget);
      expect(tester.getSize(find.byType(KkChartFrame)).height, closeTo(2 + 38.7 + 50 + 28, 1.5));

      await pumpKk(
        tester,
        const KkChartFrame(frame: false, cjk: '冷却水温', legend: keys, child: KkCanvas(naturalHeight: 50)),
      );
      expect(find.byType(KkWidgetFrame), findsNothing);
      expect(find.text('冷却水温'), findsNothing);
      expect(find.text('SEC-01'), findsOneWidget);
      expect(tester.getSize(find.byType(KkChartFrame)).height, closeTo(50 + 28, 1));

      await pumpKk(tester, const KkChartFrame(frame: false, legend: <Widget>[], child: KkCanvas(naturalHeight: 50)));
      expect(tester.getSize(find.byType(KkChartFrame)).height, 50);
    });

    testWidgets('in a fixed height the body takes what is left', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 240,
          child: KkChartFrame(
            cjk: '冷却水温',
            legend: <Widget>[KkWidgetKey(label: 'A')],
            child: KkCanvas(),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(240 - 2 - 38.7 - 28, 1));
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 240,
          child: KkChartFrame(
            frame: false,
            legend: <Widget>[KkWidgetKey(label: 'A')],
            child: KkCanvas(),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(240 - 28, 1));
    });

    testWidgets('semantics: one image node with a label and a value', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        const KkChartFrame(cjk: '冷却水温', en: 'coolant temp', semanticValue: 'three series', child: KkCanvas()),
      );
      expect(
        tester.getSemantics(find.byType(KkChartFrame)),
        matchesSemantics(label: '冷却水温 COOLANT TEMP', value: 'three series', isImage: true),
      );
      await pumpKk(tester, const KkChartFrame(semanticLabel: 'custom', child: KkCanvas()));
      expect(find.bySemanticsLabel('custom'), findsOneWidget);
      handle.dispose();
    });
  });

  group('KkPlotPointer', () {
    testWidgets('reports hover, touch, exit and taps in local coordinates', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 100,
          child: KkPlotPointer(
            onMove: (Offset? p, Size size) =>
                log.add(p == null ? 'none' : 'move ${p.dx.round()},${p.dy.round()} in ${size.width.round()}'),
            onTap: (Offset p, Size size) => log.add('tap ${p.dx.round()},${p.dy.round()}'),
            child: const KkCanvas(),
          ),
        ),
        padding: const EdgeInsets.all(50),
      );
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(const Offset(60, 70));
      await tester.pump();
      await pointer.moveTo(const Offset(500, 500));
      await tester.pump();
      expect(log, <String>['move 10,20 in 200', 'none']);
      log.clear();
      await tester.tapAt(const Offset(150, 100));
      expect(log, <String>['move 100,50 in 200', 'tap 100,50', 'none']);
      log.clear();
      // A mouse click taps but keeps the hover.
      await pointer.moveTo(const Offset(60, 70));
      await pointer.down(const Offset(60, 70));
      await pointer.up();
      await tester.pump();
      expect(log.contains('tap 10,20'), isTrue);
      expect(log.last, isNot('none'));
    });

    testWidgets('reports a resting pointer again after every rebuild', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget build(String tag, {double inset = 50}) => kkHarness(
        KkBox(
          width: 200,
          height: 100,
          child: KkPlotPointer(
            onMove: (Offset? p, Size size) => log.add(p == null ? '$tag none' : '$tag ${p.dx.round()},${p.dy.round()}'),
            child: const KkCanvas(),
          ),
        ),
        padding: EdgeInsets.all(inset),
      );
      await pumpKk(tester, const KkBox(width: 1, height: 1));
      await tester.pumpWidget(build('a'));
      // No pointer: a rebuild reports nothing.
      await tester.pumpWidget(build('b'));
      await tester.pump();
      expect(log, isEmpty);

      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(const Offset(60, 70));
      await tester.pump();
      expect(log, <String>['b 10,20']);
      // Rebuilt: the same place again, to the new listener, after the frame.
      await tester.pumpWidget(build('c'));
      await tester.pump();
      expect(log, <String>['b 10,20', 'c 10,20']);
      // The plot moved under the pointer: the place is worked out afresh.
      await tester.pumpWidget(build('d', inset: 40));
      await tester.pump();
      expect(log.last, 'd 20,30');
      // It moved out from under the pointer: no report, only the exit.
      log.clear();
      await tester.pumpWidget(build('e', inset: 300));
      await tester.pump();
      await tester.pump();
      expect(log.where((String s) => !s.endsWith('none')), isEmpty);
      // And once the pointer has left, rebuilds are quiet again.
      await tester.pumpWidget(build('f'));
      await tester.pump();
      await pointer.moveTo(const Offset(700, 500));
      await tester.pump();
      log.clear();
      await tester.pumpWidget(build('g'));
      await tester.pump();
      expect(log, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a finger is only followed while it is down', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget build(String tag) => kkHarness(
        KkBox(
          width: 200,
          height: 100,
          child: KkPlotPointer(
            onMove: (Offset? p, Size size) => log.add(p == null ? '$tag none' : '$tag ${p.dx.round()},${p.dy.round()}'),
            child: const KkCanvas(),
          ),
        ),
      );
      await pumpKk(tester, const KkBox(width: 1, height: 1));
      await tester.pumpWidget(build('a'));
      final TestGesture finger = await tester.startGesture(const Offset(30, 40));
      await tester.pumpWidget(build('b'));
      await tester.pump();
      expect(log, <String>['a 30,40', 'b 30,40']);
      await finger.up();
      log.clear();
      await tester.pumpWidget(build('c'));
      await tester.pump();
      expect(log, isEmpty);
    });
  });

  group('KkPlotFocus', () {
    testWidgets('keys become steps, jumps, activate and dismiss; the ring is for the keyboard', (
      WidgetTester tester,
    ) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 100,
          child: KkPlotFocus(
            onStep: (int dx, int dy) => log.add('step $dx,$dy'),
            onJump: (bool toEnd) => log.add(toEnd ? 'end' : 'home'),
            onActivate: () => log.add('activate'),
            onDismiss: () => log.add('dismiss'),
            onFocusChange: (bool focused) => log.add(focused ? 'focus' : 'blur'),
            child: const KkCanvas(),
          ),
        ),
      );
      bool ring() => tester.widget<KkFocusRing>(find.byType(KkFocusRing)).visible;
      expect(ring(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), isTrue);
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.escape,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(log, <String>[
        'focus',
        'step -1,0',
        'step 1,0',
        'step 0,-1',
        'step 0,1',
        'home',
        'end',
        'activate',
        'activate',
        'dismiss',
      ]);
      // Losing focus dismisses too.
      log.clear();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await tester.pump();
      expect(log, <String>['blur', 'dismiss']);
      expect(ring(), isFalse);
    });

    testWidgets('enabled: false leaves the plot out of the tab order', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkPlotFocus(enabled: false, onStep: (int dx, int dy) => log.add('step'), child: const KkCanvas()),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(log, isEmpty);
      expect(find.byType(KkFocusRing), findsNothing);
    });

    testWidgets('after a key press a resting pointer keeps quiet until it moves', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget build(String tag) => kkHarness(
        KkBox(
          width: 200,
          height: 100,
          child: KkPlotFocus(
            onStep: (int dx, int dy) => log.add('$tag step'),
            onDismiss: () => log.add('$tag dismiss'),
            child: KkPlotPointer(
              onMove: (Offset? p, Size size) =>
                  log.add(p == null ? '$tag none' : '$tag ${p.dx.round()},${p.dy.round()}'),
              child: const KkCanvas(),
            ),
          ),
        ),
      );
      await pumpKk(tester, const KkBox(width: 1, height: 1));
      await tester.pumpWidget(build('a'));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(const Offset(10, 20));
      await tester.pump();
      await tester.pumpWidget(build('b'));
      await tester.pump();
      expect(log, <String>['a 10,20', 'b 10,20']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      log.clear();
      await tester.pumpWidget(build('c'));
      await tester.pump();
      expect(log, isEmpty, reason: 'the keyboard has the cursor');
      // Escape lets go of the cursor, and the pointer does not grab it back either.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpWidget(build('d'));
      await tester.pump();
      expect(log, <String>['c dismiss']);

      await pointer.moveTo(const Offset(11, 20));
      await tester.pump();
      await tester.pumpWidget(build('e'));
      await tester.pump();
      expect(log, <String>['c dismiss', 'd 11,20', 'e 11,20']);
    });
  });

  group('KkScrambleBuilder', () {
    testWidgets('churns for 0.46s and settles; digits only', (WidgetTester tester) async {
      final List<String> shown = <String>[];
      Widget build(String text) => KkScrambleBuilder(
        text: text,
        builder: (BuildContext context, String s) {
          shown.add(s);
          return const KkBox(width: 10, height: 10);
        },
      );
      await pumpKk(tester, build('12:34 Z'), motion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown.last, isNot('12:34 Z'));
      expect(shown.last.length, 7);
      expect(shown.last[2], ':');
      expect(shown.last.substring(5), ' Z');
      await tester.pump(const Duration(milliseconds: 500));
      expect(shown.last, '12:34 Z');
      await tester.pumpWidget(kkHarness(build('99:99 Z'), motion: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(shown.last, isNot('99:99 Z'));
      await tester.pump(const Duration(seconds: 1));
      expect(shown.last, '99:99 Z');
    });

    testWidgets('with motion off, or disabled, it never churns', (WidgetTester tester) async {
      final List<String> shown = <String>[];
      await pumpKk(
        tester,
        KkScrambleBuilder(
          text: '0427',
          builder: (BuildContext context, String s) {
            shown.add(s);
            return const KkBox(width: 10, height: 10);
          },
        ),
      );
      expect(shown.toSet(), <String>{'0427'});
      shown.clear();
      await pumpKk(
        tester,
        KkScrambleBuilder(
          text: '0427',
          enabled: false,
          builder: (BuildContext context, String s) {
            shown.add(s);
            return const KkBox(width: 10, height: 10);
          },
        ),
        motion: true,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown.toSet(), <String>{'0427'});
    });
  });

  group('painting helpers', () {
    testWidgets('kkPaintChartTip stays inside its bounds and flips at the right edge', (WidgetTester tester) async {
      final List<Rect> rects = <Rect>[];
      await pumpKk(
        tester,
        KkBox(
          width: 300,
          height: 200,
          child: Builder(
            builder: (BuildContext context) {
              final KeikaiThemeData theme = KeikaiTheme.of(context);
              return KkCanvas(
                painter: _Probe((Canvas canvas, Size size) {
                  rects.clear();
                  const List<KkTipRow> rows = <KkTipRow>[
                    KkTipRow(color: Color(0xFFE8660F), name: 'SEC-01', value: '43.0'),
                    KkTipRow(name: 'NO KEY', value: '--', box: true),
                  ];
                  for (final Offset anchor in const <Offset>[
                    Offset(20, 100),
                    Offset(290, 100),
                    Offset(150, 0),
                    Offset(150, 199),
                  ]) {
                    rects.add(
                      kkPaintChartTip(canvas, Offset.zero & size, anchor, title: '13:16:00Z', rows: rows, theme: theme),
                    );
                  }
                  // Nothing to say: nothing painted.
                  rects.add(kkPaintChartTip(canvas, Offset.zero & size, const Offset(10, 10), theme: theme));
                  // Bounds smaller than the tip: pinned to the top left, no error.
                  kkPaintChartTip(
                    canvas,
                    const Rect.fromLTWH(0, 0, 20, 10),
                    const Offset(5, 5),
                    title: 'T',
                    theme: theme,
                  );
                }),
              );
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rects.length, 5);
      for (final Rect r in rects.take(4)) {
        expect(r.width, greaterThanOrEqualTo(132));
        expect(r.left >= 0 && r.right <= 300 && r.top >= 0 && r.bottom <= 200, isTrue, reason: '$r');
      }
      expect(rects[0].left, 32, reason: 'to the right of the anchor, 12 away');
      expect(rects[1].right, 278, reason: 'flipped to the left of the anchor');
      expect(rects[4], Rect.zero);
    });

    testWidgets('KkRampKey shows six swatches and its labels', (WidgetTester tester) async {
      await pumpKk(tester, const KkRampKey(low: '-120 dBm', high: '-40 dBm'));
      expect(find.text('-120 dBm'), findsOneWidget);
      expect(find.text('-40 dBm'), findsOneWidget);
      final CustomPaint ramp = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(KkRampKey), matching: find.byType(CustomPaint)),
      );
      expect(ramp.size, const Size(6 * 14 + 5 * 2, 8));
    });
  });
}
