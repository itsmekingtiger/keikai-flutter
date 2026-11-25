import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

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

/// Whether a recorded [Paint] has [color]. A paint hands its colour back in
/// 32-bit floats, so the components are compared as 8-bit values.
bool _inked(Object? paint, Color color) => paint is Paint && paint.color.toARGB32() == color.toARGB32();

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

    testWidgets('turning interactive off lets go of the crosshair', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      Widget chart({required bool interactive}) => KkBox(
        width: 400,
        height: 200,
        child: KkTimeSeries(
          frame: false,
          legend: false,
          axes: false,
          plotPadding: EdgeInsets.zero,
          series: _two,
          interactive: interactive,
          onPointHover: seen.add,
        ),
      );
      await pumpKk(tester, chart(interactive: true));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkTimeSeries)).topLeft + const Offset(205, 100));
      await tester.pump();
      expect(seen, <int?>[2]);
      await tester.pumpWidget(kkHarness(chart(interactive: false)));
      await tester.pump();
      expect(seen, <int?>[2, null]);
      expect(find.byType(KkPlotPointer), findsNothing);
      // And nothing is left painted over the plot: no crosshair, no tooltip.
      const KkColors c = KkColors.standby;
      bool plate(Symbol method, List<dynamic> a) => method == #drawRect && _inked(a[1], c.bg200);
      expect(
        tester.renderObject(find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint))),
        isNot(paints..something(plate)),
      );
    });

    testWidgets('interactive: false ignores the pointer', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(width: 400, height: 200, child: KkTimeSeries(frame: false, series: _two, interactive: false)),
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
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[7]),
        ],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[7, 7, 7, 7], area: true),
        ],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[null, null, null]),
        ],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[double.nan, 1, double.infinity, 2, null, 3, double.negativeInfinity]),
          KkSeries(name: 'B', values: <double?>[4], area: true, line: false),
        ],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[1e300, -1e300, 0, 1e-300]),
        ],
        <KkSeries>[
          KkSeries(name: 'A', values: <double?>[-5, -3, -9], area: true),
        ],
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
        await pumpKk(
          tester,
          _exact(
            series: <KkSeries>[KkSeries(name: 'A', values: values)],
          ),
        );
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
        kkHarness(
          _exact(
            series: const <KkSeries>[
              KkSeries(name: 'A', values: <double?>[1, 2]),
            ],
            onHover: seen.add,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(seen, <int?>[4, 1], reason: 'the listener hears where the crosshair went');
      await tester.pumpWidget(kkHarness(_exact(series: const <KkSeries>[], onHover: seen.add)));
      await tester.pump();
      expect(seen, <int?>[4, 1, null]);
    });

    testWidgets('a listener that rebuilds its parent is never called in the middle of a build', (
      WidgetTester tester,
    ) async {
      final List<int?> seen = <int?>[];
      List<KkSeries> data = _two;
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => KkBox(
          width: 400,
          height: 200,
          child: KkTimeSeries(
            frame: false,
            legend: false,
            axes: false,
            plotPadding: EdgeInsets.zero,
            series: data,
            onPointHover: (int? i) => setState(() => seen.add(i)),
          ),
        ),
      );
      await pumpKk(tester, build());
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkTimeSeries)).topLeft + const Offset(399, 100));
      await tester.pump();
      data = const <KkSeries>[
        KkSeries(name: 'A', values: <double?>[1, 2, 3]),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(seen, <int?>[4, 2]);
      // The same length again: nothing to say.
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[4, 2]);
    });

    testWidgets('the crosshair stays under a resting pointer while the series grows', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      // One list, appended to in place, as live data is.
      final List<double?> live = <double?>[1, 2, 3, 4, 5];
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => KkBox(
          width: 400,
          height: 200,
          child: KkTimeSeries(
            frame: false,
            legend: false,
            axes: false,
            plotPadding: EdgeInsets.zero,
            series: <KkSeries>[KkSeries(name: 'A', values: live)],
            onPointHover: (int? i) => setState(() => seen.add(i)),
          ),
        ),
      );
      await pumpKk(tester, build());
      final TestGesture pointer = await mouse(tester);
      final Rect plot = plotRect(tester, find.byType(KkTimeSeries));
      // On the newest point, and a little left of the middle.
      await pointer.moveTo(plot.topLeft + const Offset(399, 100));
      await tester.pump();
      expect(seen, <int?>[4]);
      live.addAll(<double?>[6, 7, 8, 9]);
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[4, 8], reason: 'still the newest point');

      await pointer.moveTo(plot.topLeft + const Offset(190, 100));
      await tester.pump();
      expect(seen.last, 4);
      live.addAll(<double?>[10, 11, 12, 13, 14, 15, 16, 17]);
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      // 17 points 25px apart: 190px is nearest to point 8.
      expect(seen.last, 8);
      expect(tester.takeException(), isNull);

      // The keys take the cursor: the resting pointer leaves it alone.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen.last, 9);
      live.add(18);
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen.last, 9);
    });
  });

  testWidgets('a value far off a pinned axis keeps the line on the canvas', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 400,
        height: 200,
        child: KkTimeSeries(
          frame: false,
          legend: false,
          axes: false,
          plotPadding: EdgeInsets.zero,
          yMin: 0,
          yMax: 1,
          series: <KkSeries>[
            KkSeries(name: 'A', values: <double?>[0.5, 1.7e308, 0.5, -1.7e308, 0.5]),
          ],
        ),
      ),
    );
    Path? traced;
    bool first(Symbol method, List<dynamic> a) {
      if (method != #drawPath) return false;
      traced = a[0] as Path;
      return true;
    }

    expect(
      tester.renderObject(find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint))),
      paints..something(first),
    );
    final Rect bounds = traced!.getBounds();
    expect(bounds.isFinite, isTrue, reason: '$bounds');
    expect(bounds.left, 0);
    expect(bounds.right, 400);
    expect(tester.takeException(), isNull);
  });

  group('KkTimeSeries linked cursor', () {
    Widget chart({int? cursor, ValueChanged<int?>? onHover}) => KkBox(
      width: 400,
      height: 200,
      child: KkTimeSeries(
        frame: false,
        legend: false,
        axes: false,
        plotPadding: EdgeInsets.zero,
        series: _two,
        cursor: cursor,
        onPointHover: onHover,
      ),
    );

    // The x of the crosshair line, or null when there is none.
    double? crosshair(WidgetTester tester) {
      const KkColors c = KkColors.standby;
      double? x;
      bool line(Symbol method, List<dynamic> a) {
        if (method == #drawRect &&
            _inked(a[1], c.inkDim) &&
            (a[0] as Rect).width == 1 &&
            (a[0] as Rect).height == 200) {
          x = (a[0] as Rect).left;
        }
        return false;
      }

      expect(
        tester.renderObject(find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint))),
        isNot(paints..something(line)),
      );
      return x;
    }

    testWidgets('holds the crosshair where it is told while nothing else has it', (WidgetTester tester) async {
      await pumpKk(tester, chart());
      expect(crosshair(tester), isNull);
      await tester.pumpWidget(kkHarness(chart(cursor: 2)));
      await tester.pump();
      expect(crosshair(tester), 200);
      await tester.pumpWidget(kkHarness(chart(cursor: 4)));
      await tester.pump();
      expect(crosshair(tester), 400);
      // An index with no point is ignored.
      for (final int bad in const <int>[5, 99, -1]) {
        await tester.pumpWidget(kkHarness(chart(cursor: bad)));
        await tester.pump();
        expect(crosshair(tester), isNull, reason: 'cursor $bad');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pointer and the keys take over, and hand it back', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, chart(cursor: 1, onHover: seen.add));
      expect(crosshair(tester), 100);
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkTimeSeries)).topLeft + const Offset(305, 50));
      await tester.pump();
      expect(crosshair(tester), 300);
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      expect(crosshair(tester), 100, reason: 'back to the linked place');
      expect(seen, <int?>[3, null]);

      // The keys step on from the linked place.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen.last, 2);
      expect(crosshair(tester), 200);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(crosshair(tester), 100);
    });

    testWidgets('two charts follow each other', (WidgetTester tester) async {
      int? shared;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => KkColumn(
            shrinkWrap: true,
            children: <Widget>[
              for (final String name in const <String>['a', 'b'])
                KkBox(
                  width: 400,
                  height: 100,
                  child: KkTimeSeries(
                    key: ValueKey<String>(name),
                    frame: false,
                    legend: false,
                    axes: false,
                    plotPadding: EdgeInsets.zero,
                    series: _two,
                    cursor: shared,
                    onPointHover: (int? i) => setState(() => shared = i),
                  ),
                ),
            ],
          ),
        ),
      );
      double? lineOf(String name) {
        const KkColors c = KkColors.standby;
        double? x;
        bool line(Symbol method, List<dynamic> a) {
          if (method == #drawRect && _inked(a[1], c.inkDim) && (a[0] as Rect).width == 1) x = (a[0] as Rect).left;
          return false;
        }

        expect(
          tester.renderObject(
            find.descendant(of: find.byKey(ValueKey<String>(name)), matching: find.byType(CustomPaint)).first,
          ),
          isNot(paints..something(line)),
        );
        return x;
      }

      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(const Offset(205, 50));
      await tester.pump();
      await tester.pump();
      expect(shared, 2);
      expect(lineOf('a'), 200);
      expect(lineOf('b'), 200, reason: 'the other chart shows the same instant');
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      await tester.pump();
      expect(shared, isNull);
      expect(lineOf('a'), isNull);
      expect(lineOf('b'), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('KkTimeSeries thresholds', () {
    testWidgets('the dashed line goes under the series and its label over them', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 400,
          height: 200,
          child: KkTimeSeries(
            frame: false,
            legend: false,
            series: <KkSeries>[
              KkSeries(name: 'A', values: <double?>[10, 20, 30]),
            ],
            thresholds: <KkThreshold>[KkThreshold(20)],
          ),
        ),
      );
      const KkColors c = KkColors.standby;
      bool dash(Symbol method, List<dynamic> a) => method == #drawPath && _inked(a[1], c.caution);
      bool line(Symbol method, List<dynamic> a) => method == #drawPath && _inked(a[1], c.series1);
      bool plate(Symbol method, List<dynamic> a) => method == #drawRect && _inked(a[1], c.bg100);
      final RenderObject plot = tester.renderObject(
        find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint)),
      );
      expect(
        plot,
        paints
          ..something(dash)
          ..something(line)
          ..something(plate)
          ..paragraph(),
      );
      // Never the other way round: a series over the label would strike it out.
      expect(
        plot,
        isNot(
          paints
            ..something(plate)
            ..something(line),
        ),
      );
      expect(
        plot,
        isNot(
          paints
            ..something(line)
            ..something(dash),
        ),
      );
    });

    testWidgets('a level colours the line; out of range and broken ones are skipped', (WidgetTester tester) async {
      Future<RenderObject> pump(List<KkThreshold> thresholds, {double? yMax}) async {
        await pumpKk(
          tester,
          KkBox(
            width: 400,
            height: 200,
            child: KkTimeSeries(
              frame: false,
              legend: false,
              yMin: 0,
              yMax: yMax,
              series: const <KkSeries>[
                KkSeries(name: 'A', values: <double?>[10, 20, 30]),
              ],
              thresholds: thresholds,
            ),
          ),
        );
        return tester.renderObject(find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint)));
      }

      const KkColors c = KkColors.standby;
      int dashes(RenderObject plot, Color color) {
        int count = 0;
        bool counter(Symbol method, List<dynamic> a) {
          if (method == #drawPath && _inked(a[1], color) && (a[1] as Paint).strokeWidth == 1) count++;
          return false;
        }

        expect(plot, isNot(paints..something(counter)));
        return count;
      }

      RenderObject plot = await pump(const <KkThreshold>[
        KkThreshold(15, level: KkLevel.critical),
        KkThreshold(25, level: null),
        KkThreshold(double.nan, level: KkLevel.critical),
        KkThreshold(double.infinity, level: KkLevel.critical),
      ]);
      expect(dashes(plot, c.alert), 1);
      expect(dashes(plot, c.inkDim), 1);

      // A threshold above the data widens the axis to show it...
      plot = await pump(const <KkThreshold>[KkThreshold(90, level: KkLevel.critical)]);
      expect(dashes(plot, c.alert), 1);
      // ...unless the axis is pinned: then it is off the plot and not drawn.
      plot = await pump(const <KkThreshold>[KkThreshold(90, level: KkLevel.critical)], yMax: 40);
      expect(dashes(plot, c.alert), 0);
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
