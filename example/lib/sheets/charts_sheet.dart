import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

/// A triangle wave in −1 to 1 with the given [period].
double _tri(int i, int period) {
  final int p = i % period;
  final int half = period ~/ 2;
  return (p < half ? p : period - p) / half * 2 - 1;
}

/// Repeatable jitter in −1 to 1.
double _jitter(int i, int seed) => (((i * 73 + seed * 151) * 1103515245 + 12345) ~/ 4096) % 201 / 100 - 1;

/// A reading that wanders around [base] by [swing].
List<double?> _readings(int n, {required double base, required double swing, int seed = 0, double drift = 0}) {
  return <double?>[
    for (int i = 0; i < n; i++) base + swing * (0.7 * _tri(i + seed * 5, 22) + 0.3 * _jitter(i, seed)) + drift * i,
  ];
}

final DateTime _start = DateTime.utc(2026, 11, 24, 13, 2);

List<DateTime> _minutes(int n) => <DateTime>[for (int i = 0; i < n; i++) _start.add(Duration(minutes: i))];

/// Catalogue sheet F-06: charts and plots.
class ChartsSheet extends StatelessWidget {
  const ChartsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      code: 'F-07',
      cjk: '図表',
      en: 'charts',
      note: '계열 색은 series-1 · 2 · 3 고정 순서. 넷째부터는 OTHER로 묶는다. 상태는 색 + 단어 + 상태 아이콘으로 함께 말한다.',
      sections: <Widget>[
        SheetSection(code: 'G-01', cjk: '指標', en: 'stat · delta · sparkline', child: _stats()),
        SheetSection(code: 'G-02', cjk: '時系列', en: 'time series', child: _timeSeries()),
        SheetSection(code: 'G-03', cjk: '棒図', en: 'bar chart', child: _bars()),
        SheetSection(code: 'G-04', cjk: '順位', en: 'bar list · category bar', child: _lists(context)),
        SheetSection(code: 'G-05', cjk: '計器', en: 'gauge · donut', child: _dials()),
        SheetSection(code: 'G-06', cjk: '熱図', en: 'heatmap · status timeline', child: _maps()),
        SheetSection(code: 'G-07', cjk: '波形', en: 'trace · radar · waterfall', child: _scopes()),
        SheetSection(code: 'G-08', cjk: '配置', en: 'in a grid · bare in a box', child: _placed(context)),
      ],
    );
  }

  Widget _stats() {
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        KkRow(
          gap: 8,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkExpanded(
              child: KkStat(
                cjk: '冷却水温',
                en: 'coolant temp',
                value: '042.7',
                unit: '°C',
                level: KkLevel.nominal,
                spark: _readings(32, base: 42, swing: 3, seed: 1),
                delta: const KkDelta(value: -0.4, tone: KkDeltaTone.good, unit: '°C', period: '1H'),
                note: 'MAX 080.0',
              ),
            ),
            KkExpanded(
              child: KkStat(
                cjk: '電源負荷',
                en: 'power load',
                value: '078',
                unit: '%',
                level: KkLevel.caution,
                spark: _readings(32, base: 64, swing: 6, seed: 2, drift: 0.4),
                delta: const KkDelta(value: 6.2, tone: KkDeltaTone.bad, unit: '%', period: '1H'),
                note: 'LIMIT 085',
              ),
            ),
            KkExpanded(
              child: KkStat(
                cjk: '回線遅延',
                en: 'link delay',
                value: '412',
                unit: 'ms',
                level: KkLevel.critical,
                spark: _readings(32, base: 180, swing: 40, seed: 3, drift: 7),
                delta: const KkDelta(value: 188, tone: KkDeltaTone.bad, decimals: 0, unit: 'ms', period: '1H'),
                note: 'SLA 250',
              ),
            ),
            const KkExpanded(
              child: KkStat(
                cjk: '補助電源',
                en: 'aux power',
                value: '---',
                unit: 'V',
                level: KkLevel.offline,
                spark: <double?>[24.1, 24.0, 24.1, 23.9, 24.0, null, null, null, null, null],
                delta: KkDelta(value: 0, unit: 'V', period: '1H'),
                note: 'LOST 13:58:02Z',
              ),
            ),
            KkExpanded(
              child: KkStat(
                cjk: '処理件数',
                en: 'handled',
                value: '1284',
                spark: _readings(32, base: 900, swing: 120, seed: 5, drift: 9),
                sparkArea: false,
                delta: const KkDelta(value: 3.1, unit: '%', period: '24H'),
                note: 'SINCE 00:00Z',
              ),
            ),
          ],
        ),
        KkWrap(
          gap: 32,
          runGap: 16,
          cross: KkCrossAlign.end,
          children: <Widget>[
            SheetItem(
              caption: 'SPARKLINE · AREA + DOT',
              child: KkSparkline(values: _readings(40, base: 50, swing: 12, seed: 6), width: 160, height: 32),
            ),
            SheetItem(
              caption: 'LINE ONLY',
              child: KkSparkline(
                values: _readings(40, base: 50, swing: 12, seed: 7),
                width: 160,
                height: 32,
                area: false,
                dot: false,
              ),
            ),
            SheetItem(
              caption: 'REFERENCE 50',
              child: KkSparkline(
                values: _readings(40, base: 52, swing: 14, seed: 8),
                width: 160,
                height: 32,
                reference: 50,
                area: false,
              ),
            ),
            SheetItem(
              caption: 'LEVEL CRITICAL',
              child: KkSparkline(
                values: _readings(40, base: 40, swing: 8, seed: 9, drift: 1.2),
                width: 160,
                height: 32,
                level: KkLevel.critical,
              ),
            ),
            const SheetItem(
              caption: 'GAPS',
              child: KkSparkline(
                values: <double?>[4, 5, 7, 6, null, null, 9, 8, 10, null, 6, 7, 9, 12, 11],
                width: 160,
                height: 32,
              ),
            ),
            SheetItem(
              caption: 'TABLE CELL 80 × 18',
              child: KkSparkline(
                values: _readings(24, base: 10, swing: 4, seed: 10),
                width: 80,
                height: 18,
                area: false,
              ),
            ),
            const SheetItem(
              caption: 'DELTA GOOD',
              child: KkDelta(value: 2.4, tone: KkDeltaTone.good, unit: '%', period: '1H'),
            ),
            const SheetItem(
              caption: 'DELTA BAD',
              child: KkDelta(value: -12.5, tone: KkDeltaTone.bad, unit: '%', period: '24H'),
            ),
            const SheetItem(
              caption: 'DELTA NEUTRAL',
              child: KkDelta(value: 0.8, unit: 'dB'),
            ),
            const SheetItem(
              caption: 'NO CHANGE',
              child: KkDelta(value: 0, unit: '%', period: '7D'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timeSeries() {
    final List<double?> gapped = _readings(61, base: 38, swing: 10, seed: 13);
    for (int i = 24; i < 31; i++) {
      gapped[i] = null;
    }
    return KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkTimeSeries(
            cjk: '冷却水温',
            en: 'coolant temp',
            meta: '°C · 60 MIN',
            height: 220,
            times: _minutes(61),
            series: <KkSeries>[
              KkSeries(name: 'SEC-01', values: _readings(61, base: 44, swing: 5, seed: 11)),
              KkSeries(name: 'SEC-02', values: _readings(61, base: 52, swing: 6, seed: 12, drift: 0.12)),
              KkSeries(name: 'SEC-04', values: _readings(61, base: 48, swing: 4, seed: 14, drift: 0.42)),
            ],
            thresholds: const <KkThreshold>[
              KkThreshold(60),
              KkThreshold(75, level: KkLevel.critical),
            ],
          ),
        ),
        KkExpanded(
          child: KkTimeSeries(
            cjk: '回線負荷',
            en: 'link load',
            meta: 'MBPS · STEP · AREA',
            height: 220,
            times: _minutes(61),
            shape: KkLineShape.step,
            includeZero: true,
            series: <KkSeries>[
              KkSeries(name: 'UPLINK', values: _readings(61, base: 62, swing: 18, seed: 15), area: true),
              KkSeries(name: 'DOWNLINK', values: gapped, area: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bars() {
    const List<String> sectors = <String>[
      'SEC-01',
      'SEC-02',
      'SEC-03',
      'SEC-04',
      'SEC-05',
      'SEC-06',
      'SEC-07',
      'SEC-08',
    ];
    return const KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkBarChart(
            cjk: '区画別負荷',
            en: 'load by sector',
            meta: 'GROUPED · KW',
            height: 200,
            labels: sectors,
            series: <KkSeries>[
              KkSeries(name: 'MAIN', values: <double?>[42, 55, 38, 71, 64, 29, 48, 52]),
              KkSeries(name: 'AUX', values: <double?>[18, 22, 15, 34, 30, 12, null, 21]),
            ],
            thresholds: <KkThreshold>[KkThreshold(65, label: 'LIMIT 65')],
          ),
        ),
        KkExpanded(
          child: KkBarChart(
            cjk: '通信量',
            en: 'traffic',
            meta: 'STACKED · GB',
            height: 200,
            mode: KkBarMode.stacked,
            showValues: true,
            labels: <String>['08Z', '09Z', '10Z', '11Z', '12Z', '13Z', '14Z'],
            series: <KkSeries>[
              KkSeries(name: 'TELEMETRY', values: <double?>[12, 14, 13, 18, 22, 19, 16]),
              KkSeries(name: 'VIDEO', values: <double?>[8, 9, 15, 21, 18, 12, 10]),
              KkSeries(name: 'VOICE', values: <double?>[3, 4, 4, 6, 5, 4, 3]),
            ],
          ),
        ),
        KkExpanded(
          child: KkBarChart(
            cjk: '収支',
            en: 'power balance',
            meta: 'LEVELS · KW',
            height: 200,
            showValues: true,
            labels: <String>['N-01', 'N-02', 'N-03', 'N-04', 'N-05', 'N-06', 'N-07'],
            levels: <KkLevel?>[
              KkLevel.nominal,
              KkLevel.nominal,
              KkLevel.caution,
              KkLevel.nominal,
              KkLevel.critical,
              KkLevel.offline,
              KkLevel.nominal,
            ],
            series: <KkSeries>[
              KkSeries(name: 'NET', values: <double?>[24, 18, -6, 12, -21, 0, 9]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lists(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        const KkExpanded(
          child: KkBarList(
            cjk: '通信量上位',
            en: 'top talkers',
            meta: 'LAST 60 MIN',
            unit: 'GB',
            items: <KkBarListItem>[
              KkBarListItem(cjk: '管制', en: 'control', value: 482),
              KkBarListItem(cjk: '冷却', en: 'coolant loop', value: 391, level: KkLevel.caution),
              KkBarListItem(cjk: '電源', en: 'power bus', value: 344),
              KkBarListItem(cjk: '通信', en: 'uplink ch.12', value: 207, level: KkLevel.critical),
              KkBarListItem(cjk: '監視', en: 'sensors', value: 118, level: KkLevel.nominal),
              KkBarListItem(cjk: '予備', en: 'standby node', value: 0, level: KkLevel.offline, display: '---'),
            ],
          ),
        ),
        KkExpanded(
          child: KkColumn(
            gap: 8,
            shrinkWrap: true,
            children: <Widget>[
              KkCategoryBar(
                cjk: '記憶域',
                en: 'storage',
                meta: '072 / 100 TB',
                marker: 0.85,
                segments: <KkSlice>[
                  const KkSlice(name: 'LOGS', value: 38),
                  const KkSlice(name: 'VIDEO', value: 22),
                  const KkSlice(name: 'MODELS', value: 12),
                  KkSlice(name: 'FREE', value: 28, color: c.signalDim),
                ],
              ),
              const KkCategoryBar(
                cjk: '回線状態',
                en: 'channels',
                meta: '24 CH',
                segments: <KkSlice>[
                  KkSlice(name: 'NOMINAL', value: 17, level: KkLevel.nominal),
                  KkSlice(name: 'CAUTION', value: 4, level: KkLevel.caution),
                  KkSlice(name: 'CRITICAL', value: 2, level: KkLevel.critical),
                  KkSlice(name: 'OFFLINE', value: 1, level: KkLevel.offline),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dials() {
    return const KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkGauge(
            cjk: '炉心温度',
            en: 'core temp',
            value: 412,
            min: 0,
            max: 800,
            unit: '°C',
            level: KkLevel.nominal,
            caution: 560,
            critical: 680,
          ),
        ),
        KkExpanded(
          child: KkGauge(
            cjk: '冷却水圧',
            en: 'coolant press.',
            value: 71.5,
            unit: 'kPa',
            level: KkLevel.caution,
            display: '071.5',
            caution: 60,
            critical: 85,
          ),
        ),
        KkExpanded(
          child: KkGauge(
            cjk: '電源負荷',
            en: 'power load',
            value: 94,
            unit: '%',
            level: KkLevel.critical,
            display: '094',
            caution: 70,
            critical: 90,
          ),
        ),
        KkExpanded(
          flex: 2,
          child: KkDonut(
            cjk: '警報内訳',
            en: 'alarms by class',
            meta: 'LAST 24 H',
            caption: 'ALARMS',
            slices: <KkSlice>[
              KkSlice(name: 'power', value: 42),
              KkSlice(name: 'coolant', value: 27),
              KkSlice(name: 'comms', value: 18),
              KkSlice(name: 'other', value: 9),
            ],
          ),
        ),
      ],
    );
  }

  Widget _maps() {
    final List<List<double?>> load = <List<double?>>[
      for (int r = 0; r < 7; r++)
        <double?>[
          for (int h = 0; h < 24; h++)
            (r == 5 && h > 17)
                ? null
                : (50 + 45 * _tri(h + r * 2, 24) + 18 * _jitter(h + r * 31, 3)).clamp(0, 100).toDouble(),
        ],
    ];
    const KkTimelineSpan up = KkTimelineSpan(KkLevel.nominal, weight: 6);
    return KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkHeatmap(
            cjk: '時間別負荷',
            en: 'load by hour',
            meta: '% · 7 SECTORS',
            values: load,
            rowLabels: const <String>['SEC-01', 'SEC-02', 'SEC-03', 'SEC-04', 'SEC-05', 'SEC-06', 'SEC-07'],
            columnLabels: <String>[for (int h = 0; h < 24; h++) h % 4 == 0 ? '${h.toString().padLeft(2, '0')}Z' : ''],
            min: 0,
            max: 100,
          ),
        ),
        const KkExpanded(
          child: KkStatusTimeline(
            cjk: '稼働履歴',
            en: 'uptime',
            meta: 'LAST 24 H',
            axis: <String>['14:00Z', '20:00Z', '02:00Z', '08:00Z', '14:00Z'],
            rows: <KkTimelineRow>[
              KkTimelineRow(
                cjk: '管制',
                en: 'control',
                spans: <KkTimelineSpan>[KkTimelineSpan(KkLevel.nominal, weight: 24)],
              ),
              KkTimelineRow(
                cjk: '冷却',
                en: 'coolant',
                spans: <KkTimelineSpan>[
                  up,
                  KkTimelineSpan(KkLevel.caution, weight: 2),
                  up,
                  KkTimelineSpan(KkLevel.caution, weight: 1),
                  KkTimelineSpan(KkLevel.critical, weight: 1.5),
                  KkTimelineSpan(KkLevel.nominal, weight: 7.5),
                ],
              ),
              KkTimelineRow(
                cjk: '通信',
                en: 'uplink',
                spans: <KkTimelineSpan>[
                  KkTimelineSpan(KkLevel.nominal, weight: 9),
                  KkTimelineSpan(KkLevel.offline, weight: 3),
                  KkTimelineSpan(KkLevel.nominal, weight: 8),
                  KkTimelineSpan(KkLevel.critical, weight: 0.5),
                  KkTimelineSpan(KkLevel.nominal, weight: 3.5),
                ],
              ),
              KkTimelineRow(
                cjk: '電源',
                en: 'power bus',
                spans: <KkTimelineSpan>[
                  KkTimelineSpan(KkLevel.nominal, weight: 15),
                  KkTimelineSpan(KkLevel.caution, weight: 4),
                  KkTimelineSpan(KkLevel.nominal, weight: 5),
                ],
              ),
              KkTimelineRow(
                cjk: '予備',
                en: 'standby',
                spans: <KkTimelineSpan>[
                  KkTimelineSpan(null, weight: 8),
                  KkTimelineSpan(KkLevel.offline, weight: 10),
                  KkTimelineSpan(KkLevel.nominal, weight: 6),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scopes() {
    final List<double?> wave = <double?>[
      for (int i = 0; i < 160; i++) 0.62 * _tri(i, 40) + 0.3 * _tri(i * 3 + 7, 26) + 0.08 * _jitter(i, 21),
    ];
    final List<List<double?>> sweeps = <List<double?>>[
      for (int r = 0; r < 40; r++)
        <double?>[
          for (int b = 0; b < 96; b++)
            (-113 +
                    36 * (1 - ((b - 28 - r * 0.2).abs() / 9).clamp(0, 1)) +
                    58 * (1 - ((b - 61 + (r > 22 ? 4 : 0)).abs() / 5).clamp(0, 1)) +
                    7 * _jitter(b + r * 97, 5))
                .toDouble(),
        ],
    ];
    return KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkColumn(
            gap: 8,
            shrinkWrap: true,
            children: <Widget>[
              KkTrace(cjk: '主電源', en: 'main bus', value: '050.0 Hz', samples: wave),
              KkTrace(
                cjk: '回線',
                en: 'ch.12 carrier',
                value: '-091 dBm',
                level: KkLevel.caution,
                samples: <double?>[
                  for (int i = 0; i < 160; i++) i > 96 && i < 112 ? null : 0.4 * _tri(i, 14) + 0.5 * _jitter(i, 8),
                ],
              ),
            ],
          ),
        ),
        const KkExpanded(
          child: KkRadar(
            cjk: '探知',
            en: 'sector scan',
            meta: 'RNG 40 KM',
            range: 40,
            contacts: <KkRadarContact>[
              KkRadarContact(id: 'T-01', bearing: 24, range: 31, level: KkLevel.nominal),
              KkRadarContact(id: 'T-02', bearing: 78, range: 18),
              KkRadarContact(id: 'T-04', bearing: 142, range: 27, level: KkLevel.caution),
              KkRadarContact(id: 'T-07', bearing: 215, range: 12, level: KkLevel.critical),
              KkRadarContact(id: 'T-09', bearing: 301, range: 35, level: KkLevel.offline),
              KkRadarContact(id: 'T-11', bearing: 338, range: 22),
            ],
            footer: <Widget>[
              KkWidgetKey(label: 'CONTACTS 06'),
              KkWidgetKey(label: 'CRITICAL 01'),
              KkWidgetKey(label: 'SWEEP 4 S'),
            ],
          ),
        ),
        KkExpanded(
          child: KkWaterfall(
            cjk: '周波数',
            en: 'spectrum',
            meta: 'CH.12 · 40 SWEEPS',
            rows: sweeps,
            min: -120,
            max: -40,
            startFrequency: 2400,
            endFrequency: 2480,
            lowLabel: '-120 dBm',
            highLabel: '-40 dBm',
            height: 196,
          ),
        ),
      ],
    );
  }

  Widget _placed(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        KkGrid(
          columns: 12,
          children: <Widget>[
            KkCell(
              span: 3,
              rows: 2,
              child: KkStat(
                cjk: '冷却水温',
                en: 'coolant temp',
                value: '042.7',
                unit: '°C',
                level: KkLevel.nominal,
                spark: _readings(32, base: 42, swing: 3, seed: 1),
              ),
            ),
            KkCell(
              span: 6,
              rows: 5,
              child: KkTimeSeries(
                cjk: '冷却水温',
                en: 'coolant temp',
                meta: 'FILLS 6 × 5',
                times: _minutes(61),
                series: <KkSeries>[
                  KkSeries(name: 'SEC-01', values: _readings(61, base: 44, swing: 5, seed: 11)),
                  KkSeries(name: 'SEC-02', values: _readings(61, base: 52, swing: 6, seed: 12, drift: 0.12)),
                ],
                thresholds: const <KkThreshold>[KkThreshold(60)],
              ),
            ),
            const KkCell(
              span: 3,
              rows: 5,
              child: KkGauge(
                cjk: '電源負荷',
                en: 'power load',
                value: 62,
                unit: '%',
                level: KkLevel.nominal,
                display: '062',
                caution: 70,
                critical: 90,
              ),
            ),
            KkCell(
              span: 3,
              rows: 3,
              child: KkTrace(
                cjk: '主電源',
                en: 'main bus',
                value: '050.0 Hz',
                samples: <double?>[for (int i = 0; i < 120; i++) 0.7 * _tri(i, 30) + 0.2 * _tri(i * 2, 17)],
              ),
            ),
          ],
        ),
        KkRow(
          gap: 16,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkExpanded(
              child: SheetItem(
                caption: 'frame: false · TIME SERIES IN A PLAIN BOX',
                width: 440,
                child: KkBox(
                  fill: c.bg100,
                  edges: KkEdges.line(c.line),
                  padding: const EdgeInsets.all(12),
                  child: KkTimeSeries(
                    frame: false,
                    height: 120,
                    times: _minutes(31),
                    series: <KkSeries>[
                      KkSeries(name: 'SEC-04', values: _readings(31, base: 48, swing: 6, seed: 14), area: true),
                    ],
                  ),
                ),
              ),
            ),
            const KkExpanded(
              child: SheetItem(
                caption: 'frame: false · BAR LIST',
                width: 440,
                child: KkBarList(
                  frame: false,
                  unit: '%',
                  items: <KkBarListItem>[
                    KkBarListItem(en: 'sec-04', value: 91, level: KkLevel.critical),
                    KkBarListItem(en: 'sec-02', value: 74, level: KkLevel.caution),
                    KkBarListItem(en: 'sec-01', value: 58),
                    KkBarListItem(en: 'sec-07', value: 33),
                  ],
                  max: 100,
                ),
              ),
            ),
            const KkExpanded(
              child: SheetItem(
                caption: 'frame: false · CATEGORY BAR · total: 800',
                width: 440,
                child: KkCategoryBar(
                  frame: false,
                  cjk: '電力配分',
                  en: 'power budget',
                  meta: '640 / 800 KW',
                  total: 800,
                  marker: 0.9,
                  segments: <KkSlice>[
                    KkSlice(name: 'COMPUTE', value: 310),
                    KkSlice(name: 'COOLING', value: 220),
                    KkSlice(name: 'COMMS', value: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
