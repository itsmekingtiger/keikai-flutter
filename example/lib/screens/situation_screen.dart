import 'package:keikai/keikai.dart';

import '../model/settings.dart';
import '../model/station.dart';
import '../shell/console_shell.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/metric_detail.dart';
import '../widgets/screen_header.dart';
import '../widgets/sector_detail.dart';

/// The situation board: everything about the plant at one glance, live.
class SituationScreen extends StatelessWidget {
  const SituationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final IncidentPhase phase = station.phase;
        return KkColumn(
          gap: 12,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.situation,
              note: '발전소 HQ-03의 실시간 상황판. 주요 수치를 1초마다 갱신하고, 수치판을 누르면 지난 1분을 자세히 본다.',
              actions: <Widget>[
                KkButton(
                  label: 'drill',
                  cjk: '訓練',
                  icon: KkIcons.play,
                  onPressed: phase == IncidentPhase.none ? () => startDrill(context) : null,
                ),
                KkButton(
                  label: 'procedure',
                  cjk: '手順',
                  icon: KkIcons.list,
                  variant: phase == IncidentPhase.none ? KkButtonVariant.outline : KkButtonVariant.primary,
                  onPressed: () => goTo(context, Destination.procedure),
                ),
              ],
            ),
            if (phase != IncidentPhase.none) _IncidentBar(station: station),
            KkModeStrip(
              current: station.mode,
              target: phase == IncidentPhase.caution ? 2 : (phase == IncidentPhase.acknowledged ? 3 : null),
              level: phaseWords(phase).level,
              steps: const <KkModeStep>[
                KkModeStep(cjk: '待機', en: 'standby'),
                KkModeStep(cjk: '監視', en: 'monitor'),
                KkModeStep(cjk: '対処', en: 'respond'),
                KkModeStep(cjk: '復旧', en: 'recover'),
              ],
            ),
            KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                final int columns = context.kk.metrics.columnsFor(constraints.maxWidth);
                return _Board(station: station, settings: settings, columns: columns, width: constraints.maxWidth);
              },
            ),
          ],
        );
      },
    );
  }
}

/// The alert bar of the running incident.
class _IncidentBar extends StatelessWidget {
  const _IncidentBar({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final IncidentPhase phase = station.phase;
    final ({String cjk, String en, KkLevel? level}) words = phaseWords(phase);
    final bool critical = station.alert;
    return KkAlertBar(
      level: words.level,
      cjk: words.cjk,
      title: incidentHeadline(station),
      sub: '${station.incidentDetail} · ${formatClock(station.now)}',
      code: station.incidentCode,
      action: phase == IncidentPhase.critical
          ? KkButton(
              label: 'acknowledge',
              cjk: '確認',
              style: critical ? KkEmergency.actionStyle(context) : null,
              onPressed: station.acknowledge,
            )
          : null,
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.station, required this.settings, required this.columns, required this.width});

  final Station station;
  final AppSettings settings;
  final int columns;

  /// The width of the whole board.
  final double width;

  /// The cells of the board in reading order, with their span and rows, for a
  /// grid of 4, 8, 12 and 16 columns. Every table fills whole rows.
  static const List<(String, int, int)> _at4 = <(String, int, int)>[
    ('temp', 4, 2),
    ('pressure', 4, 2),
    ('load', 4, 2),
    ('link', 4, 2),
    ('series', 4, 5),
    ('matrix', 4, 5),
    ('alarms', 4, 6),
    ('gauge', 4, 5),
    ('donut', 4, 5),
    ('frequency', 4, 3),
    ('timer', 4, 3),
    ('reserve', 4, 2),
    ('budget', 4, 2),
    ('trace', 4, 3),
    ('log', 4, 6),
    ('spectrum', 4, 6),
    ('rank', 4, 6),
    ('scope', 4, 7),
    ('watch', 4, 4),
  ];
  static const List<(String, int, int)> _at8 = <(String, int, int)>[
    ('temp', 4, 2),
    ('pressure', 4, 2),
    ('load', 4, 2),
    ('link', 4, 2),
    ('series', 8, 5),
    ('gauge', 4, 5),
    ('donut', 4, 5),
    ('matrix', 8, 4),
    ('alarms', 8, 4),
    ('frequency', 4, 3),
    ('timer', 4, 3),
    ('reserve', 4, 2),
    ('budget', 4, 2),
    ('log', 8, 6),
    ('spectrum', 4, 6),
    ('rank', 4, 6),
    ('scope', 4, 7),
    ('trace', 4, 3),
    ('watch', 4, 4),
  ];
  static const List<(String, int, int)> _at12 = <(String, int, int)>[
    ('temp', 3, 2),
    ('pressure', 3, 2),
    ('load', 3, 2),
    ('link', 3, 2),
    ('series', 6, 5),
    ('gauge', 3, 5),
    ('donut', 3, 5),
    ('matrix', 5, 4),
    ('alarms', 7, 4),
    ('frequency', 4, 3),
    ('timer', 4, 3),
    ('watch', 4, 3),
    ('log', 7, 6),
    ('spectrum', 5, 6),
    ('scope', 4, 7),
    ('trace', 4, 3),
    ('rank', 4, 7),
    ('budget', 4, 2),
    ('reserve', 4, 2),
  ];
  static const List<(String, int, int)> _at16 = <(String, int, int)>[
    ('temp', 4, 2),
    ('pressure', 4, 2),
    ('load', 4, 2),
    ('link', 4, 2),
    ('series', 8, 5),
    ('gauge', 4, 5),
    ('donut', 4, 5),
    ('matrix', 6, 4),
    ('alarms', 6, 4),
    ('reserve', 4, 2),
    ('budget', 4, 2),
    ('frequency', 4, 3),
    ('timer', 4, 3),
    ('watch', 4, 3),
    ('trace', 4, 3),
    ('log', 8, 6),
    ('spectrum', 4, 6),
    ('rank', 4, 6),
    ('scope', 4, 7),
    ('heat', 12, 7),
  ];

  /// The alarm wall glitches and flashes each time a window starts to sound,
  /// unless the operator has switched that off.
  Widget _onNewAlarm(Widget wall) => settings.glitch ? KkGlitch(trigger: station.alarmsRaised, child: wall) : wall;

  /// A key figure that opens the last minute of its metric when pressed: a
  /// control of the app's own, made of a pressable, the focus ring and the
  /// corner brackets that mark it under the pointer.
  Widget _stats(
    BuildContext context,
    Metric Function(Station station) pick, {
    required bool lowIsBad,
    bool temperature = false,
  }) {
    final Metric metric = pick(station);
    final double change = metric.delta();
    final bool worse = lowIsBad ? change < 0 : change > 0;
    final String value = temperature ? settings.temperature(metric.value) : metric.text;
    final String unit = temperature ? settings.tempSymbol : metric.unit;
    return KkPressable(
      semanticLabel: '${metric.en}, $value $unit, ${metric.level.word}. Opens the last minute.',
      excludeSemantics: true,
      onPressed: () => openMetric(context, pick, temperature: temperature),
      builder: (BuildContext context, KkStates states) => KkFocusRing(
        visible: states.focused,
        child: KkBrackets(
          visible: states.hovered || states.pressed,
          level: metric.level == KkLevel.nominal ? null : metric.level,
          child: KkStat(
            cjk: metric.cjk,
            en: metric.en,
            value: value,
            unit: unit,
            level: metric.level,
            spark: List<double?>.of(metric.history),
            delta: KkDelta(
              value: change,
              decimals: metric.digits,
              tone: change.abs() < metric.jitter * 2
                  ? KkDeltaTone.neutral
                  : (worse ? KkDeltaTone.bad : KkDeltaTone.good),
              period: '30S',
            ),
            note: metric.code,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final bool incident = station.phase != IncidentPhase.none;
    final Metric pressure = station.coolantPressure;
    final Metric voltage = station.busVoltage;
    final int samples = pressure.history.length;
    final List<DateTime> times = <DateTime>[
      for (int i = 0; i < samples; i++) station.now.subtract(Duration(seconds: samples - 1 - i)),
    ];
    final double frequency = station.frequency;
    final KkLevel frequencyLevel = (frequency - 50).abs() < 0.5
        ? KkLevel.nominal
        : ((frequency - 50).abs() < 1.2 ? KkLevel.caution : KkLevel.critical);

    double group(int from, int to) {
      double sum = 0;
      for (int i = from; i <= to; i++) {
        sum += station.sectors[i].load;
      }
      return sum.roundToDouble();
    }

    // The donut sits in a cell of three (of twelve) or four columns.
    final int donutSpan = columns == 12 ? 3 : 4;
    final bool roomy = (width + 8) / columns * donutSpan - 8 >= 320;

    final List<Sector> ranked = station.sectors.where((Sector s) => s.level != KkLevel.offline).toList()
      ..sort((Sector a, Sector b) => b.load.compareTo(a.load));

    final Map<String, Widget Function()> cells = <String, Widget Function()>{
      'temp': () => _stats(context, (Station s) => s.coolantTemp, lowIsBad: false, temperature: true),
      'pressure': () => _stats(context, (Station s) => s.coolantPressure, lowIsBad: true),
      'load': () => _stats(context, (Station s) => s.load, lowIsBad: false),
      'link': () => _stats(context, (Station s) => s.linkQuality, lowIsBad: true),
      'series': () => KkTimeSeries(
        cjk: pressure.cjk,
        en: pressure.en,
        meta: '${pressure.text} kPa',
        series: <KkSeries>[KkSeries(name: 'P-01', values: List<double?>.of(pressure.history), area: true)],
        times: times,
        thresholds: <KkThreshold>[
          KkThreshold(pressure.warn, label: 'CAUTION ${pressure.format(pressure.warn)}'),
          KkThreshold(pressure.crit, level: KkLevel.critical, label: 'CRITICAL ${pressure.format(pressure.crit)}'),
        ],
        semanticLabel: 'Coolant pressure over the last minute',
      ),
      'gauge': () => KkGauge(
        cjk: voltage.cjk,
        en: voltage.en,
        meta: voltage.code,
        value: voltage.value,
        min: voltage.min,
        max: voltage.max,
        unit: voltage.unit,
        display: voltage.text,
        level: voltage.level,
        caution: voltage.warn,
        critical: voltage.crit,
      ),
      'donut': () => KkDonut(
        cjk: '負荷配分',
        en: 'load share',
        meta: '%·SEC',
        caption: 'LOAD',
        // In a narrow cell the ring is smaller and the legend shows whole percents.
        size: roomy ? 136 : 112,
        percentDecimals: roomy ? 1 : 0,
        slices: <KkSlice>[
          KkSlice(name: 'POWER', value: group(0, 2)),
          KkSlice(name: 'COOL', value: group(3, 5)),
          KkSlice(name: 'COMMS', value: group(6, 7)),
          KkSlice(name: 'OTHER', value: group(8, 11)),
        ],
      ),
      'matrix': () => KkPanel(
        code: 'SEC',
        cjk: '区画',
        en: 'sectors',
        meta: '${kkFixed(station.sectors.where((Sector s) => s.level == KkLevel.nominal).length, digits: 2)}/12',
        level: station.sectors.any((Sector s) => s.level == KkLevel.critical) ? KkLevel.critical : null,
        child: KkCenter(
          child: KkHexMatrix(
            columns: columns <= 4 ? 4 : 6,
            cells: <KkHexCell>[
              for (final Sector s in station.sectors)
                KkHexCell(
                  id: s.code.replaceFirst('SEC', 'S'),
                  value: s.level == KkLevel.offline ? '--' : '${s.load.round()}%',
                  level: s.level,
                  semanticLabel: '${s.code} ${s.en} ${s.level.word}',
                ),
            ],
            onCellTap: (KkHexCell cell) {
              final Sector sector = station.sectors.firstWhere(
                (Sector s) => s.code.replaceFirst('SEC', 'S') == cell.id,
              );
              openSector(context, sector);
            },
          ),
        ),
      ),
      'alarms': () => _onNewAlarm(
        KkWidgetFrame(
          cjk: '警報盤',
          en: 'annunciator',
          meta: '${kkFixed(station.activeAlarms, digits: 2)} ACTIVE',
          level: station.soundingAlarms > 0 ? KkLevel.critical : (station.activeAlarms > 0 ? KkLevel.caution : null),
          expandBody: true,
          child: KkAnnunciator(
            border: false,
            boot: false,
            columns: columns <= 4 ? 2 : 4,
            tiles: <KkAlarmTile>[
              for (final AlarmWindow a in station.alarms)
                KkAlarmTile(
                  code: a.code,
                  cjk: a.cjk,
                  en: a.en,
                  level: a.level,
                  state: switch (a.state) {
                    AlarmState.normal => KkAlarmState.normal,
                    AlarmState.alarm => KkAlarmState.alarm,
                    AlarmState.acknowledged => KkAlarmState.ack,
                    AlarmState.returned => KkAlarmState.rtn,
                  },
                ),
            ],
            onAcknowledge: (int i) => station.pressAlarm(station.alarms[i]),
            onReset: (int i) => station.pressAlarm(station.alarms[i]),
          ),
        ),
      ),
      'frequency': () => KkReadout(
        cjk: '周波数',
        en: 'bus frequency',
        value: kkFixed(frequency, digits: 2, decimals: 2),
        unit: 'Hz',
        level: frequencyLevel,
        position: (frequency - 48) / 4,
        footStart: 'MIN 48.00',
        footEnd: 'MAX 52.00',
      ),
      'reserve': () => KkBox(
        decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: KkColumn(
          main: KkMainAlign.center,
          children: <Widget>[
            KkMeter(
              cjk: station.reserve.cjk,
              en: station.reserve.en,
              value: station.reserve.position,
              unit: '%',
              level: station.reserve.level,
              autoLevel: false,
              showMarks: false,
              ticks: const <String>['0', '25', '50', '75', '100'],
            ),
          ],
        ),
      ),
      'timer': () => incident
          ? KkTimer(
              value: station.incidentElapsed,
              progress: (station.incidentElapsed.inSeconds / 120).clamp(0.0, 1.0),
              cjk: '経過',
              en: 'elapsed',
              mode: station.incidentCode,
              level: phaseWords(station.phase).level,
              format: KkTimerFormat.hours,
            )
          : KkTimer(
              value: Duration(seconds: station.uptime),
              progress: station.now.hour / 24,
              cjk: '稼働',
              en: 'uptime',
              mode: 'T-PLUS',
              format: KkTimerFormat.hours,
            ),
      'log': () => KkDataLog(
        entries: <KkLogEntry>[
          for (final LogLine line in station.log.skip(station.log.length > 60 ? station.log.length - 60 : 0))
            KkLogEntry(
              id: line.serial,
              time: formatClock(line.time),
              source: line.source,
              level: line.level,
              message: line.message,
            ),
        ],
        timeWidth: columns <= 4 ? 0 : 96,
        levelWidth: columns <= 4 ? 0 : 92,
      ),
      'spectrum': () => KkWaterfall(
        cjk: '帯域',
        en: 'comms band',
        meta: 'CH.04 · CH.12 · MHz',
        rows: station.sweeps,
        capacity: Station.sweepCount,
        min: -105,
        max: -65,
        startFrequency: 430,
        endFrequency: 440,
        frequencyFormat: (double f) => f.toStringAsFixed(1),
        levelFormat: (double l) => '${l.round()} dBm',
      ),
      'trace': () => KkTrace(
        cjk: '母線波形',
        en: 'bus waveform',
        value: '${kkFixed(frequency, digits: 2, decimals: 2)} Hz',
        samples: List<double?>.of(station.wave),
        level: frequencyLevel == KkLevel.nominal ? null : frequencyLevel,
        min: -1.4,
        max: 1.4,
        flowing: true,
      ),
      'budget': () => KkCategoryBar(
        cjk: '電力予算',
        en: 'power budget',
        meta: '${kkFixed(station.load.value, digits: 3)} / 100',
        total: 100,
        marker: 0.7,
        segments: <KkSlice>[
          KkSlice(name: 'BASE', value: (station.load.value * 0.55).roundToDouble()),
          KkSlice(name: 'COOLING', value: (station.load.value * 0.3).roundToDouble()),
          KkSlice(name: 'AUX', value: (station.load.value * 0.15).roundToDouble()),
        ],
      ),
      'rank': () => KkBarList(
        cjk: '負荷順位',
        en: 'top load',
        meta: 'SEC · %',
        max: 100,
        unit: '%',
        items: <KkBarListItem>[
          for (final Sector s in ranked.take(6))
            KkBarListItem(
              cjk: s.cjk,
              en: s.code,
              value: s.load.roundToDouble(),
              level: s.level == KkLevel.nominal ? null : s.level,
            ),
        ],
        onItemTap: (int i) => openSector(context, ranked[i]),
      ),
      'scope': () => KkRadar(
        cjk: '周辺',
        en: 'perimeter',
        meta: '500 M',
        range: 500,
        rings: 5,
        rangeFormat: (double r) => '${r.round()}',
        contacts: <KkRadarContact>[
          for (final Contact k in station.contacts)
            KkRadarContact(id: k.id, bearing: k.bearing, range: k.range, level: k.level),
        ],
        footer: <Widget>[
          KkWidgetKey(label: 'PATROL', color: c.signal, box: true),
          KkWidgetKey(label: 'VEHICLE', color: c.nominal, box: true),
          KkWidgetKey(label: 'UNKNOWN', color: c.caution, box: true),
        ],
      ),
      'heat': () => KkHeatmap(
        cjk: '事象分布',
        en: 'events by hour',
        meta: 'SEC × UTC',
        values: station.heat,
        rowLabels: <String>[for (final Sector s in station.sectors) s.code],
        columnLabels: <String>[for (int h = 0; h < 24; h++) h % 3 == 0 ? kkFixed(h, digits: 2) : ''],
        format: (double v) => '${v.round()} EV',
      ),
      'watch': () => _Watch(station: station, settings: settings),
    };

    final List<(String, int, int)> layout = switch (columns) {
      <= 4 => _at4,
      <= 8 => _at8,
      <= 12 => _at12,
      _ => _at16,
    };
    // A wall display has 24 columns: the 16-column board, half as wide again.
    final int scale = columns > 16 ? columns ~/ 16 : 1;
    final int stretch = columns > 16 ? columns % 16 : 0;
    return KkGrid(
      columns: columns,
      children: <Widget>[
        for (final (String name, int span, int rows) in layout)
          KkCell(
            key: ValueKey<String>(name),
            span: span * scale + span * stretch ~/ 16,
            rows: rows,
            child: cells[name]!(),
          ),
      ],
    );
  }
}

/// Who is on watch, and how far into the shift.
class _Watch extends StatelessWidget {
  const _Watch({required this.station, required this.settings});

  final Station station;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final Duration start = settings.shiftStart.duration;
    final Duration now = Duration(hours: station.now.hour, minutes: station.now.minute, seconds: station.now.second);
    const Duration shift = Duration(hours: 8);
    final Duration into = Duration(seconds: (now - start).inSeconds % shift.inSeconds);
    final String duty = switch (settings.duty) {
      Duty.watch => 'WATCH',
      Duty.engineer => 'ENGINEER',
      Duty.supervisor => 'SUPERVISOR',
    };
    Widget line(String label, String value) => KkRow(
      gap: 8,
      cross: KkCrossAlign.baseline,
      children: <Widget>[
        KkExpanded(
          child: KkText.en(label, size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
        ),
        KkText.num(value, size: 12, weight: FontWeight.w500, color: c.ink),
      ],
    );
    return KkPanel(
      code: 'OPS',
      cjk: '当直',
      en: 'watch',
      meta: settings.operator,
      variant: KkPanelVariant.quiet,
      child: KkColumn(
        gap: 8,
        main: KkMainAlign.between,
        children: <Widget>[
          line('duty', duty),
          line('maintenance', kkFormatDate(settings.maintenance)),
          KkProgress(
            cjk: '当直経過',
            en: 'shift',
            value: into.inSeconds / shift.inSeconds,
            format: (double v) => kkFixed(v * 100, digits: 3),
          ),
        ],
      ),
    );
  }
}
