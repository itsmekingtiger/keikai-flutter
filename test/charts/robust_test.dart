import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// One of every chart, with ordinary data. [frame] false gives the bare form
/// of the ones that have a frame.
Map<String, Widget> _every({required bool frame}) {
  const List<double?> wave = <double?>[3, 5, 4, 8, 6, null, 7, 9, 5, 4, 6, 8];
  return <String, Widget>{
    'sparkline': const KkSparkline(values: wave, reference: 5),
    'delta': const KkDelta(value: -1.5, tone: KkDeltaTone.good, unit: '%', period: '1H'),
    'stat': KkStat(
      frame: frame,
      cjk: '冷却水温',
      en: 'coolant temp',
      value: '042.7',
      unit: '°C',
      level: KkLevel.caution,
      spark: wave,
      delta: const KkDelta(value: 0.4, unit: '°C', period: '1H'),
      note: 'MAX 080.0',
    ),
    'time series': KkTimeSeries(
      frame: frame,
      cjk: '冷却水温',
      en: 'coolant temp',
      meta: '°C',
      series: const <KkSeries>[
        KkSeries(name: 'SEC-01', values: wave),
        KkSeries(name: 'SEC-02', values: <double?>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], area: true),
      ],
      thresholds: const <KkThreshold>[
        KkThreshold(7),
        KkThreshold(10, level: KkLevel.critical),
      ],
    ),
    'bar chart': KkBarChart(
      frame: frame,
      cjk: '区画別負荷',
      en: 'load by sector',
      labels: const <String>['SEC-01', 'SEC-02', 'SEC-03'],
      series: const <KkSeries>[
        KkSeries(name: 'MAIN', values: <double?>[42, -12, 38]),
        KkSeries(name: 'AUX', values: <double?>[18, 22, null]),
      ],
      thresholds: const <KkThreshold>[KkThreshold(30)],
      showValues: true,
    ),
    'stacked bar chart': KkBarChart(
      frame: frame,
      en: 'traffic',
      mode: KkBarMode.stacked,
      labels: const <String>['08Z', '09Z', '10Z'],
      series: const <KkSeries>[
        KkSeries(name: 'A', values: <double?>[4, 5, 6]),
        KkSeries(name: 'B', values: <double?>[2, 1, 3]),
      ],
      showValues: true,
    ),
    'bar list': KkBarList(
      frame: frame,
      cjk: '通信量上位',
      en: 'top talkers',
      unit: 'GB',
      items: const <KkBarListItem>[
        KkBarListItem(cjk: '管制', en: 'control', value: 482),
        KkBarListItem(en: 'coolant loop', value: 391, level: KkLevel.caution),
        KkBarListItem(en: 'standby', value: double.nan, level: KkLevel.offline),
      ],
    ),
    'category bar': KkCategoryBar(
      frame: frame,
      cjk: '記憶域',
      en: 'storage',
      meta: '060 / 100 TB',
      total: 100,
      marker: 0.85,
      segments: const <KkSlice>[
        KkSlice(name: 'LOGS', value: 38),
        KkSlice(name: 'VIDEO', value: 22),
      ],
    ),
    'status timeline': KkStatusTimeline(
      frame: frame,
      cjk: '稼働履歴',
      en: 'uptime',
      axis: const <String>['14:00Z', '20:00Z', '02:00Z'],
      rows: const <KkTimelineRow>[
        KkTimelineRow(
          cjk: '冷却',
          en: 'coolant',
          spans: <KkTimelineSpan>[
            KkTimelineSpan(KkLevel.nominal, weight: 4),
            KkTimelineSpan(KkLevel.critical),
            KkTimelineSpan(KkLevel.offline, weight: 2),
          ],
        ),
        KkTimelineRow(en: 'uplink', spans: <KkTimelineSpan>[KkTimelineSpan(KkLevel.caution, weight: 3)]),
      ],
    ),
    'gauge': KkGauge(frame: frame, cjk: '電源負荷', en: 'power load', value: 62, unit: '%', caution: 70, critical: 90),
    'donut': KkDonut(
      frame: frame,
      cjk: '警報内訳',
      en: 'alarms by class',
      slices: const <KkSlice>[
        KkSlice(name: 'power', value: 42),
        KkSlice(name: 'coolant', value: 27),
        KkSlice(name: 'comms', value: 18),
        KkSlice(name: 'other', value: 9),
      ],
    ),
    'heatmap': KkHeatmap(
      frame: frame,
      cjk: '時間別負荷',
      en: 'load by hour',
      values: const <List<double?>>[
        <double?>[1, 5, 9, null, 3],
        <double?>[2, 6, 4, 8, 7],
      ],
      rowLabels: const <String>['SEC-01', 'SEC-02'],
      columnLabels: const <String>['00Z', '', '08Z', '', '16Z'],
    ),
    'trace': KkTrace(frame: frame, cjk: '主電源', en: 'main bus', value: '050.0 Hz', samples: wave, flowing: true),
    'radar': KkRadar(
      frame: frame,
      cjk: '探知',
      en: 'sector scan',
      meta: 'RNG 40 KM',
      range: 40,
      contacts: const <KkRadarContact>[
        KkRadarContact(id: 'T-01', bearing: 30, range: 28, level: KkLevel.nominal),
        KkRadarContact(id: 'T-07', bearing: 215, range: 12, level: KkLevel.critical),
        KkRadarContact(id: 'T-11', bearing: 350, range: 400),
      ],
    ),
    'waterfall': KkWaterfall(
      frame: frame,
      cjk: '周波数',
      en: 'spectrum',
      startFrequency: 2400,
      endFrequency: 2480,
      rows: <List<double?>>[
        for (int r = 0; r < 12; r++) <double?>[for (int b = 0; b < 24; b++) -120.0 + ((r * 5 + b * 7) % 80)],
      ],
    ),
  };
}

Widget _scaled(Widget child, double factor) {
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(factor)),
      child: child,
    ),
  );
}

void main() {
  setUpAll(loadKkFonts);

  for (final bool frame in const <bool>[true, false]) {
    final String form = frame ? 'framed' : 'bare';

    testWidgets('every chart, $form, in both conditions: no errors, a finite size', (WidgetTester tester) async {
      for (final KkCondition condition in KkCondition.values) {
        for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
          await pumpKk(tester, chart.value, condition: condition);
          expect(tester.takeException(), isNull, reason: '${chart.key} $form in $condition');
          final Size size = tester.getSize(find.byWidget(chart.value));
          expect(size.isFinite, isTrue, reason: chart.key);
          expect(size.width > 0 && size.height > 0, isTrue, reason: '${chart.key} is $size');
          expect(size.height < 600, isTrue, reason: '${chart.key} must not fill a loose parent, is $size');
        }
      }
    });

    testWidgets('every chart, $form, with free width and height takes its natural size', (WidgetTester tester) async {
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        await pumpKk(
          tester,
          KkScroll(
            axis: Axis.horizontal,
            child: KkScroll(child: chart.value),
          ),
          alignment: null,
        );
        expect(tester.takeException(), isNull, reason: '${chart.key} $form');
        final Size size = tester.getSize(find.byWidget(chart.value));
        expect(size.isFinite, isTrue, reason: chart.key);
        expect(size.width > 0 && size.height > 0, isTrue, reason: '${chart.key} is $size');
      }
    });

    testWidgets('every chart, $form, fills a fixed box exactly', (WidgetTester tester) async {
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        // The two inline pieces keep their own size.
        if (chart.key == 'delta' || chart.key == 'sparkline') continue;
        await pumpKk(tester, KkBox(width: 420, height: 380, child: chart.value));
        expect(tester.takeException(), isNull, reason: '${chart.key} $form');
        expect(tester.getSize(find.byWidget(chart.value)), const Size(420, 380), reason: chart.key);
      }
    });

    testWidgets('every chart, $form, survives boxes too small for it', (WidgetTester tester) async {
      const List<Size> sizes = <Size>[Size.zero, Size(1, 1), Size(9, 9), Size(60, 14), Size(14, 300), Size(700, 5)];
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        for (final Size size in sizes) {
          await pumpKk(tester, KkBox(width: size.width, height: size.height, clip: true, child: chart.value));
          expect(tester.takeException(), isNull, reason: '${chart.key} $form at $size');
        }
      }
    });

    testWidgets('every chart, $form, survives large text', (WidgetTester tester) async {
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        for (final double width in const <double>[160, 480]) {
          await pumpKk(tester, _scaled(KkBox(width: width, child: chart.value), 2.5));
          expect(tester.takeException(), isNull, reason: '${chart.key} $form at $width, text x2.5');
        }
      }
    });

    testWidgets('every chart, $form, plays its entrance and can leave half way', (WidgetTester tester) async {
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        await pumpKk(tester, chart.value, motion: true);
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 90));
          expect(tester.takeException(), isNull, reason: '${chart.key} $form, frame $i');
        }
        // Removed while still animating.
        await pumpKk(tester, const KkBox(width: 1, height: 1), motion: true);
        expect(tester.takeException(), isNull, reason: '${chart.key} $form, removed');
        // And once more to the end, then well past it for the loops.
        await pumpKk(tester, chart.value, motion: true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull, reason: '${chart.key} $form, settled');
        await pumpKk(tester, const KkBox(width: 1, height: 1), motion: true);
      }
    });
  }

  testWidgets('every chart builds a sound semantics tree and names itself', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final bool frame in const <bool>[true, false]) {
      for (final MapEntry<String, Widget> chart in _every(frame: frame).entries) {
        await pumpKk(tester, chart.value);
        expect(tester.takeException(), isNull, reason: chart.key);
        // A delta is plain text, and a sparkline without a label is decoration.
        if (chart.key == 'delta' || chart.key == 'sparkline') continue;
        final String all = tester.getSemantics(find.byWidget(chart.value)).toStringDeep();
        expect(all.contains('label:') || all.contains('value:'), isTrue, reason: '${chart.key}: $all');
      }
    }
    handle.dispose();
  });

  testWidgets('every chart repaints cleanly when the theme condition flips under it', (WidgetTester tester) async {
    for (final MapEntry<String, Widget> chart in _every(frame: true).entries) {
      await pumpKk(tester, chart.value);
      await tester.pumpWidget(kkHarness(chart.value, condition: KkCondition.alert));
      await tester.pump();
      await tester.pumpWidget(kkHarness(chart.value));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: chart.key);
    }
  });
}
