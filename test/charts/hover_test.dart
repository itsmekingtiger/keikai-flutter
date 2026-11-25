import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// Hover states side by side, for a visual check of crosshair, tooltip,
/// dimming and outlines.
void main() {
  setUpAll(loadKkFonts);

  testWidgets('hover states', (WidgetTester tester) async {
    final List<DateTime> times = <DateTime>[for (int i = 0; i < 31; i++) DateTime.utc(2026, 11, 24, 13, i)];
    await pumpKk(
      tester,
      KkColumn(
        gap: 8,
        shrinkWrap: true,
        children: <Widget>[
          KkRow(
            gap: 8,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkExpanded(
                child: KkTimeSeries(
                  key: const ValueKey<String>('ts'),
                  cjk: '冷却水温',
                  en: 'coolant temp',
                  times: times,
                  height: 180,
                  series: <KkSeries>[
                    KkSeries(name: 'SEC-01', values: <double?>[for (int i = 0; i < 31; i++) 40 + (i % 7) * 1.5]),
                    KkSeries(name: 'SEC-02', values: <double?>[for (int i = 0; i < 31; i++) 52 - (i % 5) * 2.0]),
                  ],
                  thresholds: const <KkThreshold>[KkThreshold(50)],
                ),
              ),
              const KkExpanded(
                child: KkBarChart(
                  key: ValueKey<String>('bar'),
                  cjk: '区画別負荷',
                  en: 'load by sector',
                  height: 180,
                  labels: <String>['SEC-01', 'SEC-02', 'SEC-03', 'SEC-04', 'SEC-05'],
                  series: <KkSeries>[
                    KkSeries(name: 'MAIN', values: <double?>[42, 55, 38, 71, 64]),
                    KkSeries(name: 'AUX', values: <double?>[18, 22, 15, 34, 30]),
                  ],
                ),
              ),
            ],
          ),
          KkRow(
            gap: 8,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkExpanded(
                child: KkHeatmap(
                  key: const ValueKey<String>('heat'),
                  cjk: '時間別負荷',
                  en: 'load by hour',
                  values: <List<double?>>[
                    for (int r = 0; r < 4; r++)
                      <double?>[for (int c = 0; c < 12; c++) ((r * 7 + c * 13) % 100).toDouble()],
                  ],
                  rowLabels: const <String>['SEC-01', 'SEC-02', 'SEC-03', 'SEC-04'],
                  columnLabels: const <String>['00Z', '', '', '', '08Z', '', '', '', '16Z', '', '', ''],
                ),
              ),
              const KkExpanded(
                child: KkDonut(
                  key: ValueKey<String>('donut'),
                  cjk: '警報内訳',
                  en: 'alarms by class',
                  slices: <KkSlice>[
                    KkSlice(name: 'power', value: 42),
                    KkSlice(name: 'coolant', value: 27),
                    KkSlice(name: 'comms', value: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      size: const Size(1200, 640),
      pixelRatio: 2,
      padding: const EdgeInsets.all(16),
    );

    final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    Future<void> hover(String key, Offset fraction) async {
      final Finder canvas = find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(KkPlotPointer),
      );
      final Rect rect = tester.getRect(canvas.first);
      await gesture.moveTo(rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy));
      await tester.pump();
    }

    await hover('ts', const Offset(0.55, 0.5));
    await expectKkGolden(tester, 'hover_time_series');
    await hover('bar', const Offset(0.45, 0.5));
    await expectKkGolden(tester, 'hover_bar');
    await hover('heat', const Offset(0.6, 0.45));
    await expectKkGolden(tester, 'hover_heat');
    await hover('donut', const Offset(0.93, 0.5));
    await expectKkGolden(tester, 'hover_donut');
  });
}
