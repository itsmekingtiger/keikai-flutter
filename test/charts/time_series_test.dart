import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

import '../support/harness.dart';
import 'util.dart';

const List<KkSeries> _two = <KkSeries>[
  KkSeries(name: 'SEC-01', values: <double?>[10, 20, 30, 20, 10]),
  KkSeries(name: 'SEC-02', values: <double?>[5, null, 15, 25, 35]),
];

/// A bare chart whose plot is exactly [size], so index i sits at
/// `size.width * i / (n - 1)`.
Widget _exact({
  Size size = const Size(400, 200),
  List<KkSeries> series = _two,
  ValueChanged<int?>? onHover,
  ValueChanged<int>? onTap,
  bool focusable = true,
}) {
  return KkBox(
    width: size.width,
    height: size.height,
    child: KkTimeSeries(
      frame: false,
      legend: false,
      axes: false,
      plotPadding: EdgeInsets.zero,
      series: series,
      onPointHover: onHover,
      onPointTap: onTap,
      focusable: focusable,
    ),
  );
}

void main() {
  setUpAll(loadKkFonts);

  group('KkTimeSeries layout', () {
    testWidgets('natural height is head + 140 plot + legend', (WidgetTester tester) async {
      await pumpKk(tester, const KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', series: _two));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(798, 140));
      // 1 + head (8 + 21.7 + 8 + 1) + 140 + foot (1 + 8 + 11 + 8) + 1
      expect(tester.getSize(find.byType(KkTimeSeries)).height, closeTo(208.7, 1.5));
      expect(find.text('SEC-01'), findsOneWidget);
      expect(find.text('SEC-02'), findsOneWidget);
    });

    testWidgets('height sets the natural plot height', (WidgetTester tester) async {
      await pumpKk(tester, const KkTimeSeries(frame: false, height: 220, series: _two, legend: false));
      expect(tester.getSize(find.byType(KkCanvas)).height, 220);
    });

    testWidgets('fills a fixed-height parent: the plot takes what is left', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 500,
          height: 320,
          child: KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', series: _two),
        ),
      );
      expect(tester.getSize(find.byType(KkTimeSeries)), const Size(500, 320));
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(320 - 208.7 + 140, 1.5));
    });

    testWidgets('shrinks instead of overflowing a parent that is too short', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 300,
          height: 90,
          child: KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', series: _two),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkTimeSeries)), const Size(300, 90));
    });

    testWidgets('the legend defaults to more than one series', (WidgetTester tester) async {
      await pumpKk(tester, KkTimeSeries(series: _two.sublist(0, 1)));
      expect(find.byType(KkWidgetKey), findsNothing);
      await pumpKk(tester, KkTimeSeries(series: _two.sublist(0, 1), legend: true));
      expect(find.byType(KkWidgetKey), findsOneWidget);
      await pumpKk(tester, const KkTimeSeries(series: _two, legend: false));
      expect(find.byType(KkWidgetKey), findsNothing);
    });

    testWidgets('bare mode has no head and no border', (WidgetTester tester) async {
      await pumpKk(tester, const KkTimeSeries(frame: false, cjk: '冷却水温', en: 'coolant temp', series: _two));
      expect(find.byType(KkWidgetFrame), findsNothing);
      expect(find.text('冷却水温'), findsNothing);
      expect(find.byType(KkWidgetFoot), findsOneWidget);
      expect(tester.getSize(find.byType(KkCanvas)).width, 800);
    });

    testWidgets('takes a natural width when the width is free', (WidgetTester tester) async {
      await pumpKk(tester, const KkRow(children: <Widget>[KkTimeSeries(series: _two)]));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkCanvas)).width, 320);
    });
  });

  group('KkTimeSeries pointer', () {
    testWidgets('hover reports the nearest point', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onHover: seen.add));
      final Rect plot = plotRect(tester, find.byType(KkTimeSeries));
      expect(plot.size, const Size(400, 200));
      final TestGesture pointer = await mouse(tester);

      await pointer.moveTo(plot.topLeft + const Offset(210, 100));
      await tester.pump();
      expect(seen, <int?>[2]);
      await pointer.moveTo(plot.topLeft + const Offset(260, 30));
      await tester.pump();
      expect(seen, <int?>[2, 3]);
      await pointer.moveTo(plot.topLeft + const Offset(262, 180));
      await tester.pump();
      expect(seen, <int?>[2, 3], reason: 'no repeat for the same point');
      await pointer.moveTo(plot.topLeft + const Offset(1, 100));
      await tester.pump();
      expect(seen.last, 0);
      await pointer.moveTo(plot.topLeft + const Offset(399, 100));
      await tester.pump();
      expect(seen.last, 4);
      await pointer.moveTo(plot.bottomRight + const Offset(80, 80));
      await tester.pump();
      expect(seen.last, isNull);
    });

    testWidgets('tap reports the point', (WidgetTester tester) async {
      final List<int> taps = <int>[];
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onTap: taps.add, onHover: seen.add));
      final Rect plot = plotRect(tester, find.byType(KkTimeSeries));
      await tester.tapAt(plot.topLeft + const Offset(95, 50));
      await tester.pump();
      expect(taps, <int>[1]);
      expect(seen, <int?>[1, null], reason: 'a finger shows the crosshair while down and clears it on lift');
    });

    testWidgets('a drag is not a tap, and scrubs the crosshair', (WidgetTester tester) async {
      final List<int> taps = <int>[];
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onTap: taps.add, onHover: seen.add));
      final Rect plot = plotRect(tester, find.byType(KkTimeSeries));
      final TestGesture finger = await tester.startGesture(plot.topLeft + const Offset(5, 100));
      await finger.moveTo(plot.topLeft + const Offset(205, 100));
      await finger.moveTo(plot.topLeft + const Offset(395, 100));
      await finger.up();
      await tester.pump();
      expect(taps, isEmpty);
      expect(seen, <int?>[0, 2, 4, null]);
    });

    testWidgets('interactive: false ignores the pointer', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 400,
          height: 200,
          child: KkTimeSeries(frame: false, series: _two, interactive: false),
        ),
      );
      expect(find.byType(KkPlotPointer), findsNothing);
      expect(find.byType(KkPlotFocus), findsNothing);
    });
  });

  group('KkTimeSeries keyboard', () {
    testWidgets('arrow keys, Home, End and Escape move the crosshair', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      final List<int> taps = <int>[];
      await pumpKk(tester, _exact(onHover: seen.add, onTap: taps.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(seen, <int?>[0, 1, 0, 4, 0, null]);
      expect(taps, <int>[4]);
    });

    testWidgets('left from nothing starts at the last point', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onHover: seen.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(seen, <int?>[4]);
    });

    testWidgets('shows the focus ring for keyboard focus only', (WidgetTester tester) async {
      await pumpKk(tester, _exact());
      RenderKkFocusRing ring() => tester.renderObject<RenderKkFocusRing>(find.byType(KkFocusRing));
      expect(ring().visible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring().visible, isTrue);
    });

    testWidgets('focusable: false keeps it out of the tab order', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onHover: seen.add, focusable: false));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, isEmpty);
      expect(find.byType(KkFocusRing), findsNothing);
    });
  });

  group('KkTimeSeries data', () {
    testWidgets('survives empty, single, flat and broken series', (WidgetTester tester) async {
      const List<List<KkSeries>> cases = <List<KkSeries>>[
        <KkSeries>[],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[])],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[7])],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[7, 7, 7, 7], area: true)],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[null, null, null])],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[double.nan, 1, double.infinity, 2, null, 3, double.negativeInfinity]),
          KkSeries(name: 'B', values: <double?>[4], area: true, line: false),
        ],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[1e300, -1e300, 0, 1e-300])],
        <KkSeries>[KkSeries(name: 'A', values: <double?>[-5, -3, -9], area: true)],
      ];
      for (final List<KkSeries> series in cases) {
        for (final KkLineShape shape in KkLineShape.values) {
          await pumpKk(
            tester,
            KkTimeSeries(
              cjk: '冷却水温',
              en: 'coolant temp',
              series: series,
              shape: shape,
              thresholds: const <KkThreshold>[KkThreshold(2), KkThreshold(double.nan), KkThreshold(1e9, level: null)],
            ),
          );
          expect(tester.takeException(), isNull, reason: '$series $shape');
        }
      }
    });

    testWidgets('hovering works on every odd data set too', (WidgetTester tester) async {
      final TestGesture pointer = await mouse(tester);
      for (final List<double?> values in const <List<double?>>[
        <double?>[],
        <double?>[7],
        <double?>[null, double.nan],
        <double?>[1, 2],
      ]) {
        await pumpKk(tester, _exact(series: <KkSeries>[KkSeries(name: 'A', values: values)]));
        await pointer.moveTo(const Offset(120, 80));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$values');
        await pointer.moveTo(const Offset(9999, 9999));
        await tester.pump();
      }
    });

    testWidgets('survives tiny and odd sizes', (WidgetTester tester) async {
      for (final Size size in const <Size>[Size.zero, Size(1, 1), Size(20, 20), Size(60, 300), Size(900, 12)]) {
        await pumpKk(
          tester,
          KkBox(
            width: size.width,
            height: size.height,
            child: const KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', meta: 'META', series: _two),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });

    testWidgets('times give a UTC axis; x and index axes work', (WidgetTester tester) async {
      final List<DateTime> times = <DateTime>[for (int i = 0; i < 5; i++) DateTime.utc(2026, 11, 24, 13, i * 10)];
      await pumpKk(tester, KkTimeSeries(series: _two, times: times));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkTimeSeries(series: _two, x: <double>[0, 0.5, 1, 4, 9]));
      expect(tester.takeException(), isNull);
      // Too few, repeated and non-finite positions fall back gracefully.
      await pumpKk(tester, const KkTimeSeries(series: _two, x: <double>[1, 1]));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkTimeSeries(series: _two, x: <double>[0, double.nan, 2, 3, 4]));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, KkTimeSeries(series: _two, times: <DateTime>[times.first, times.first]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinned axis, formatters and both themes', (WidgetTester tester) async {
      for (final KkCondition condition in KkCondition.values) {
        await pumpKk(
          tester,
          KkTimeSeries(
            series: _two,
            yMin: 0,
            yMax: 20,
            includeZero: true,
            xFormat: (double x) => 'T${x.round()}',
            yFormat: (double y) => '${y.round()}K',
            valueFormat: (double v) => v.toStringAsFixed(3),
          ),
          condition: condition,
        );
        expect(tester.takeException(), isNull);
      }
      await pumpKk(tester, const KkTimeSeries(series: _two, yMin: 50, yMax: 50));
      expect(tester.takeException(), isNull);
      await pumpKk(tester, const KkTimeSeries(series: _two, yMin: 60, yMax: 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the crosshair index is clamped when the data shrinks', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onHover: seen.add));
      final TestGesture pointer = await mouse(tester);
      final Rect plot = plotRect(tester, find.byType(KkTimeSeries));
      await pointer.moveTo(plot.topLeft + const Offset(399, 100));
      await tester.pump();
      expect(seen.last, 4);
      await tester.pumpWidget(
        kkHarness(_exact(series: const <KkSeries>[KkSeries(name: 'A', values: <double?>[1, 2])], onHover: seen.add)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('KkTimeSeries motion', () {
    testWidgets('lines wipe in and finish', (WidgetTester tester) async {
      await pumpKk(tester, const KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', series: _two), motion: true);
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('semantics describe the chart', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(tester, const KkTimeSeries(cjk: '冷却水温', en: 'coolant temp', series: _two));
    final SemanticsNode node = tester.getSemantics(find.byType(KkTimeSeries));
    expect(node.label, '冷却水温 COOLANT TEMP');
    expect(node.value, 'SEC-01 10.0, SEC-02 35.0');
    handle.dispose();
  });
}
