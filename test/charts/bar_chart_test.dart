import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

const List<String> _labels = <String>['SEC-01', 'SEC-02', 'SEC-03', 'SEC-04'];
const List<KkSeries> _two = <KkSeries>[
  KkSeries(name: 'MAIN', values: <double?>[42, 55, 38, 71]),
  KkSeries(name: 'AUX', values: <double?>[18, null, 15, 34]),
];

Widget _exact({
  KkBarMode mode = KkBarMode.grouped,
  ValueChanged<int?>? onHover,
  ValueChanged<int>? onTap,
  List<String> labels = _labels,
  List<KkSeries> series = _two,
}) {
  return KkBox(
    width: 400,
    height: 200,
    child: KkBarChart(
      frame: false,
      legend: false,
      axes: false,
      plotPadding: EdgeInsets.zero,
      labels: labels,
      series: series,
      mode: mode,
      onBarHover: onHover,
      onBarTap: onTap,
    ),
  );
}

void main() {
  setUpAll(loadKkFonts);

  group('KkBarChart layout', () {
    testWidgets('natural height is head + 140 plot + legend', (WidgetTester tester) async {
      await pumpKk(tester, const KkBarChart(cjk: '区画別負荷', en: 'load by sector', labels: _labels, series: _two));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(798, 140));
      expect(tester.getSize(find.byType(KkBarChart)).height, closeTo(208.7, 1.5));
      expect(find.text('MAIN'), findsOneWidget);
      expect(find.text('AUX'), findsOneWidget);
    });

    testWidgets('fills a fixed-height parent', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 500,
          height: 300,
          child: KkBarChart(cjk: '区画別負荷', en: 'load by sector', labels: _labels, series: _two),
        ),
      );
      expect(tester.getSize(find.byType(KkBarChart)), const Size(500, 300));
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(300 - 208.7 + 140, 1.5));
    });

    testWidgets('a single series has no legend by default', (WidgetTester tester) async {
      await pumpKk(tester, KkBarChart(labels: _labels, series: _two.sublist(0, 1)));
      expect(find.byType(KkWidgetKey), findsNothing);
    });
  });

  group('KkBarChart pointer and keyboard', () {
    testWidgets('hover reports the category under the pointer', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      await pumpKk(tester, _exact(onHover: seen.add));
      final Rect plot = plotRect(tester, find.byType(KkBarChart));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plot.topLeft + const Offset(250, 100));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(299, 10));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(301, 10));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(2, 190));
      await tester.pump();
      await pointer.moveTo(plot.bottomRight + const Offset(50, 50));
      await tester.pump();
      expect(seen, <int?>[2, 3, 0, null]);
    });

    testWidgets('the cursor moves to the last category when the categories shrink', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      List<String> labels = _labels;
      // The listener rebuilds its parent: that throws if it is called mid-build.
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            _exact(labels: labels, onHover: (int? i) => setState(() => seen.add(i))),
      );
      await pumpKk(tester, build());
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkBarChart)).topLeft + const Offset(390, 100));
      await tester.pump();
      expect(seen, <int?>[3]);
      labels = const <String>['SEC-01', 'SEC-02'];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(seen, <int?>[3, 1]);
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[3, 1], reason: 'nothing changed');
      labels = const <String>[];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <int?>[3, 1, null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning interactive off lets go of the cursor', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      Widget chart({required bool interactive}) => KkBox(
        width: 400,
        height: 200,
        child: KkBarChart(
          frame: false,
          legend: false,
          axes: false,
          plotPadding: EdgeInsets.zero,
          labels: _labels,
          series: _two,
          interactive: interactive,
          onBarHover: seen.add,
        ),
      );
      await pumpKk(tester, chart(interactive: true));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plotRect(tester, find.byType(KkBarChart)).topLeft + const Offset(250, 100));
      await tester.pump();
      expect(seen, <int?>[2]);
      await tester.pumpWidget(kkHarness(chart(interactive: false)));
      await tester.pump();
      expect(seen, <int?>[2, null]);
      expect(find.byType(KkPlotPointer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap reports the category in both modes', (WidgetTester tester) async {
      for (final KkBarMode mode in KkBarMode.values) {
        final List<int> taps = <int>[];
        await pumpKk(tester, _exact(mode: mode, onTap: taps.add));
        final Rect plot = plotRect(tester, find.byType(KkBarChart));
        await tester.tapAt(plot.topLeft + const Offset(150, 100));
        await tester.tapAt(plot.topLeft + const Offset(399, 100));
        expect(taps, <int>[1, 3], reason: '$mode');
      }
    });

    testWidgets('arrow keys move between categories', (WidgetTester tester) async {
      final List<int?> seen = <int?>[];
      final List<int> taps = <int>[];
      await pumpKk(tester, _exact(onHover: seen.add, onTap: taps.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(seen, <int?>[3, 2, 0, 3, null]);
      expect(taps, <int>[0]);
    });
  });

  group('KkBarChart data', () {
    testWidgets('survives empty, missing, negative and broken data in both modes', (WidgetTester tester) async {
      const List<({List<String> labels, List<KkSeries> series})> cases =
          <({List<String> labels, List<KkSeries> series})>[
            (labels: <String>[], series: <KkSeries>[]),
            (labels: <String>['A'], series: <KkSeries>[]),
            (
              labels: <String>[],
              series: <KkSeries>[
                KkSeries(name: 'X', values: <double?>[1, 2]),
              ],
            ),
            (labels: <String>['A'], series: <KkSeries>[KkSeries(name: 'X', values: <double?>[])]),
            (
              labels: <String>['A', 'B', 'C'],
              series: <KkSeries>[
                KkSeries(name: 'X', values: <double?>[0, 0, 0]),
              ],
            ),
            (
              labels: <String>['A', 'B', 'C'],
              series: <KkSeries>[
                KkSeries(name: 'X', values: <double?>[-4, -9, -1]),
              ],
            ),
            (
              labels: <String>['A', 'B', 'C', 'D'],
              series: <KkSeries>[
                KkSeries(name: 'X', values: <double?>[double.nan, 5, double.infinity, -3]),
                KkSeries(name: 'Y', values: <double?>[null, -2, 1e300, 0]),
                KkSeries(name: 'Z', values: <double?>[1, 1]),
              ],
            ),
            (
              labels: <String>['A VERY LONG CATEGORY NAME', 'B'],
              series: <KkSeries>[
                KkSeries(name: 'X', values: <double?>[3, 4]),
              ],
            ),
          ];
      for (final ({List<String> labels, List<KkSeries> series}) c in cases) {
        for (final KkBarMode mode in KkBarMode.values) {
          await pumpKk(
            tester,
            KkBarChart(
              cjk: '区画別負荷',
              en: 'load by sector',
              labels: c.labels,
              series: c.series,
              mode: mode,
              showValues: true,
              levels: const <KkLevel?>[KkLevel.critical, null],
              thresholds: const <KkThreshold>[
                KkThreshold(3, label: 'LIMIT'),
                KkThreshold(double.infinity),
              ],
            ),
          );
          expect(tester.takeException(), isNull, reason: '${c.labels} $mode');
        }
      }
    });

    testWidgets('survives tiny sizes, many bars, pinned axes and both themes', (WidgetTester tester) async {
      for (final Size size in const <Size>[Size.zero, Size(1, 1), Size(20, 20), Size(40, 400), Size(900, 14)]) {
        await pumpKk(
          tester,
          KkBox(
            width: size.width,
            height: size.height,
            child: const KkBarChart(labels: _labels, series: _two, showValues: true),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
      final List<String> many = <String>[for (int i = 0; i < 400; i++) 'N-$i'];
      await pumpKk(
        tester,
        KkBarChart(
          labels: many,
          series: <KkSeries>[
            KkSeries(name: 'A', values: <double?>[for (int i = 0; i < 400; i++) (i % 17).toDouble()]),
            KkSeries(name: 'B', values: <double?>[for (int i = 0; i < 400; i++) (i % 5) - 2.0]),
          ],
          showValues: true,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final KkCondition condition in KkCondition.values) {
        await pumpKk(
          tester,
          KkBarChart(
            labels: _labels,
            series: _two,
            yMin: 20,
            yMax: 60,
            groupPadding: 5,
            barGap: 500,
            yFormat: (double v) => '${v.round()}KW',
            valueFormat: (double v) => v.toStringAsFixed(2),
          ),
          condition: condition,
        );
        expect(tester.takeException(), isNull);
      }
      await pumpKk(tester, const KkBarChart(labels: _labels, series: _two, yMin: 9, yMax: 9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bars grow in and finish', (WidgetTester tester) async {
      for (final KkBarMode mode in KkBarMode.values) {
        await pumpKk(tester, KkBarChart(labels: _labels, series: _two, mode: mode, showValues: true), motion: true);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 110));
          expect(tester.takeException(), isNull);
        }
        await tester.pump(const Duration(seconds: 2));
      }
    });
  });
}
