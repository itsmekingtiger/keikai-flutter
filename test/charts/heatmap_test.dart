import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

import '../support/harness.dart';
import 'util.dart';

final List<List<double?>> _grid = <List<double?>>[
  <double?>[0, 10, 20, 30],
  <double?>[40, null, 60, 70],
  <double?>[80, 90, 100, double.nan],
];

/// A bare 3 x 4 map: 12px padding, 48.5 x 18 cells, 2px gaps.
Widget _exact({
  double height = 82,
  ValueChanged<KkHeatCell?>? onHover,
  ValueChanged<KkHeatCell>? onTap,
}) {
  return KkBox(
    width: 224,
    height: height,
    child: KkHeatmap(frame: false, legend: false, values: _grid, onCellHover: onHover, onCellTap: onTap),
  );
}

String _name(KkHeatCell? c) => c == null ? '-' : '${c.row},${c.column}=${c.value}';

void main() {
  setUpAll(loadKkFonts);

  group('KkHeatmap layout', () {
    testWidgets('natural height: 18px cells, 2px gaps, 12px padding, labels', (WidgetTester tester) async {
      await pumpKk(tester, KkHeatmap(frame: false, legend: false, values: _grid));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(800, 24 + 3 * 18 + 2 * 2));
      await pumpKk(
        tester,
        KkHeatmap(frame: false, legend: false, values: _grid, columnLabels: const <String>['00Z', '', '', '12Z']),
      );
      expect(tester.getSize(find.byType(KkCanvas)).height, 24 + 3 * 18 + 2 * 2 + 4 + 10);
      await pumpKk(tester, KkHeatmap(frame: false, legend: false, values: _grid, cellHeight: 30, gap: 4));
      expect(tester.getSize(find.byType(KkCanvas)).height, 24 + 3 * 30 + 2 * 4);
    });

    testWidgets('framed, with the ramp legend', (WidgetTester tester) async {
      await pumpKk(tester, KkHeatmap(cjk: '時間別負荷', en: 'load by hour', values: _grid));
      expect(find.byType(KkRampKey), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(tester.getSize(find.byType(KkHeatmap)).height, closeTo(2 + 38.7 + 82 + 28, 1.5));
      await pumpKk(tester, KkHeatmap(values: _grid, lowLabel: 'IDLE', highLabel: 'FULL', min: -50, max: 50));
      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('FULL'), findsOneWidget);
    });
  });

  group('KkHeatmap pointer and keyboard', () {
    testWidgets('hover and tap report the cell', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      final List<String> taps = <String>[];
      await pumpKk(
        tester,
        _exact(onHover: (KkHeatCell? c) => seen.add(_name(c)), onTap: (KkHeatCell c) => taps.add(_name(c))),
      );
      final Rect plot = plotRect(tester, find.byType(KkHeatmap));
      final TestGesture pointer = await mouse(tester);
      // Cell (1, 2): x = 12 + 2 * 50.5 + 24, y = 12 + 20 + 9.
      await pointer.moveTo(plot.topLeft + const Offset(137, 41));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(13, 13));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(211, 69));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(70, 41));
      await tester.pump();
      // The padding is not a cell.
      await pointer.moveTo(plot.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(seen, <String>['1,2=60.0', '0,0=0.0', '2,3=null', '1,1=null', '-']);
      await tester.tapAt(plot.topLeft + const Offset(137, 41));
      expect(taps, <String>['1,2=60.0']);
    });

    testWidgets('cells stretch to fill a fixed height', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pumpKk(tester, _exact(height: 200, onHover: (KkHeatCell? c) => seen.add(_name(c))));
      final Rect plot = plotRect(tester, find.byType(KkHeatmap));
      expect(plot.height, 200);
      final TestGesture pointer = await mouse(tester);
      // Cells are (200 - 24 - 4) / 3 = 57.3 tall now.
      await pointer.moveTo(plot.topLeft + const Offset(20, 60));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(20, 80));
      await tester.pump();
      await pointer.moveTo(plot.topLeft + const Offset(20, 180));
      await tester.pump();
      expect(seen, <String>['0,0=0.0', '1,0=40.0', '2,0=80.0']);
    });

    testWidgets('arrow keys walk the cells and stop at the edges', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      final List<String> taps = <String>[];
      await pumpKk(
        tester,
        _exact(onHover: (KkHeatCell? c) => seen.add(_name(c)), onTap: (KkHeatCell c) => taps.add(_name(c))),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(seen, <String>['0,0=0.0', '0,1=10.0', '1,1=null', '0,1=10.0', '0,0=0.0', '-']);
      expect(taps, <String>['0,0=0.0']);
    });
  });

  group('KkHeatmap data', () {
    testWidgets('survives empty, ragged, flat and non-finite grids at any size', (WidgetTester tester) async {
      final List<List<List<double?>>> cases = <List<List<double?>>>[
        <List<double?>>[],
        <List<double?>>[<double?>[]],
        <List<double?>>[<double?>[], <double?>[1, 2, 3], <double?>[4]],
        <List<double?>>[<double?>[5, 5], <double?>[5, 5]],
        <List<double?>>[<double?>[null, double.nan], <double?>[double.infinity, double.negativeInfinity]],
        <List<double?>>[<double?>[-1e300, 1e300, 0]],
        <List<double?>>[
          for (int r = 0; r < 40; r++) <double?>[for (int c = 0; c < 60; c++) (r * c % 97).toDouble()],
        ],
      ];
      final TestGesture pointer = await mouse(tester);
      for (final List<List<double?>> values in cases) {
        for (final Size size in const <Size>[Size(800, 600), Size(60, 60), Size(20, 20), Size.zero]) {
          await pumpKk(
            tester,
            KkBox(
              width: size.width,
              height: size == const Size(800, 600) ? null : size.height,
              child: KkHeatmap(
                cjk: '時間別負荷',
                en: 'load by hour',
                values: values,
                rowLabels: const <String>['SEC-01', 'A ROW LABEL MUCH TOO LONG TO FIT'],
                columnLabels: const <String>['00Z', '01Z', '02Z'],
              ),
            ),
          );
          await pointer.moveTo(const Offset(30, 60));
          await tester.pump();
          await pointer.moveTo(const Offset(9999, 9999));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${values.length} rows at $size');
        }
      }
    });

    testWidgets('cells flicker in and finish, in both themes', (WidgetTester tester) async {
      for (final KkCondition condition in KkCondition.values) {
        await pumpKk(tester, KkHeatmap(values: _grid), motion: true, condition: condition);
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 90));
          expect(tester.takeException(), isNull);
        }
        await tester.pump(const Duration(seconds: 2));
      }
    });

    testWidgets('the hovered cell is dropped when the grid shrinks', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pumpKk(tester, _exact(onHover: (KkHeatCell? c) => seen.add(_name(c))));
      final TestGesture pointer = await mouse(tester);
      final Rect plot = plotRect(tester, find.byType(KkHeatmap));
      await pointer.moveTo(plot.topLeft + const Offset(211, 69));
      await tester.pump();
      await tester.pumpWidget(
        kkHarness(
          const KkBox(
            width: 224,
            height: 82,
            child: KkHeatmap(frame: false, legend: false, values: <List<double?>>[<double?>[1]]),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
