import 'dart:async';
import 'dart:math' as math;

import 'package:keikai/keikai.dart';

/// One measured quantity with its limits and recent history.
class Metric {
  Metric({
    required this.code,
    required this.cjk,
    required this.en,
    required this.unit,
    required this.min,
    required this.max,
    required this.warn,
    required this.crit,
    required double value,
    this.digits = 1,
    this.width = 5,
    this.lowIsBad = false,
    this.jitter = 0.6,
  }) : _value = value,
       target = value;

  final String code;
  final String cjk;
  final String en;
  final String unit;
  final double min;
  final double max;

  /// Caution threshold.
  final double warn;

  /// Critical threshold.
  final double crit;

  /// Decimal places shown.
  final int digits;

  /// Total characters of the fixed-width text, including the point.
  final int width;

  /// Whether falling below the thresholds is the bad direction.
  final bool lowIsBad;

  /// Size of the random walk per tick.
  final double jitter;

  /// The value the metric is drifting toward.
  double target;

  double _value;
  double get value => _value;

  /// The last 60 samples, oldest first.
  final List<double> history = <double>[];

  KkLevel get level {
    if (lowIsBad) {
      if (_value <= crit) return KkLevel.critical;
      if (_value <= warn) return KkLevel.caution;
    } else {
      if (_value >= crit) return KkLevel.critical;
      if (_value >= warn) return KkLevel.caution;
    }
    return KkLevel.nominal;
  }

  /// Position of the value between [min] and [max], 0 to 1.
  double get position => ((_value - min) / (max - min)).clamp(0.0, 1.0);

  /// The value with fixed digits and leading zeros: `042.7`.
  String get text => _value.toStringAsFixed(digits).padLeft(width, '0');

  void _step(math.Random random) {
    final double pull = (target - _value) * 0.35;
    final double noise = (random.nextDouble() - 0.5) * 2 * jitter;
    _value = (_value + pull + noise).clamp(min, max);
    history.add(_value);
    if (history.length > 60) history.removeAt(0);
  }
}

/// One sector of the plant: a row of the systems table, a cell of the matrix.
class Sector {
  Sector({
    required this.code,
    required this.cjk,
    required this.en,
    required this.operator,
    required this.load,
    required this.temp,
    this.level = KkLevel.nominal,
    this.note = '',
  });

  final String code;
  final String cjk;
  final String en;
  String operator;
  double load;
  double temp;
  KkLevel level;
  String note;

  /// Load over the last 24 samples.
  final List<double> trend = <double>[];
}

/// One line of the event log.
class LogLine {
  const LogLine({required this.time, required this.source, required this.message, this.level});

  final DateTime time;
  final String source;
  final String message;
  final KkLevel? level;
}

/// The phases of the scripted coolant incident.
enum IncidentPhase { none, caution, critical, acknowledged, recovering }

/// State of one window of the alarm annunciator.
enum AlarmState { normal, alarm, acknowledged, returned }

class AlarmWindow {
  AlarmWindow({required this.code, required this.cjk, required this.en, this.level = KkLevel.critical});

  final String code;
  final String cjk;
  final String en;
  final KkLevel level;
  AlarmState state = AlarmState.normal;
}

/// One step of the recovery procedure.
enum StepStatus { pending, active, done, failed, skipped }

class ProcedureStep {
  ProcedureStep({required this.cjk, required this.en, required this.note});

  final String cjk;
  final String en;
  final String note;
  StepStatus status = StepStatus.pending;
  DateTime? at;
}

/// A decision channel of the go / no-go poll.
enum Verdict { go, noGo, wait, fault }

class Channel {
  Channel({required this.id, required this.name, required this.note, this.verdict = Verdict.wait});

  final String id;
  final String name;
  String note;
  Verdict verdict;
}

/// The simulated control room behind the example app.
///
/// Everything on screen reads from here. [tick] advances the plant by one
/// second; [start] makes it tick by itself. The random walk is seeded, so the
/// same sequence of calls always produces the same screens.
class Station extends ChangeNotifier {
  Station({int seed = 7, DateTime? epoch}) : _random = math.Random(seed), _now = epoch ?? DateTime.utc(2026, 11, 24, 14, 2, 31) {
    for (int i = 0; i < 60; i++) {
      for (final Metric m in metrics) {
        m._step(_random);
      }
      _stepSectors();
    }
    _seedLog();
  }

  final math.Random _random;
  DateTime _now;
  Timer? _timer;

  /// Simulated UTC time.
  DateTime get now => _now;

  /// Seconds since the station came up.
  int uptime = 3 * 86400 + 4 * 3600 + 17 * 60;

  IncidentPhase _phase = IncidentPhase.none;
  IncidentPhase get phase => _phase;
  int _phaseAge = 0;

  /// Whether the screen should be in the alert condition.
  bool get alert => _phase == IncidentPhase.critical || _phase == IncidentPhase.acknowledged;

  /// Whether the full-screen alarm should be up.
  bool get emergency => _phase == IncidentPhase.critical;

  final Metric coolantTemp = Metric(
    code: 'T-01',
    cjk: '冷却水温',
    en: 'coolant temp',
    unit: '°C',
    min: 0,
    max: 120,
    warn: 70,
    crit: 90,
    value: 42.7,
  );

  final Metric coolantPressure = Metric(
    code: 'P-01',
    cjk: '冷却水圧',
    en: 'coolant pressure',
    unit: 'kPa',
    min: 0,
    max: 400,
    warn: 180,
    crit: 120,
    value: 256,
    digits: 0,
    width: 3,
    lowIsBad: true,
    jitter: 2.2,
  );

  final Metric busVoltage = Metric(
    code: 'V-01',
    cjk: '母線電圧',
    en: 'bus voltage',
    unit: 'V',
    min: 0,
    max: 520,
    warn: 470,
    crit: 495,
    value: 440.2,
    jitter: 0.9,
  );

  final Metric load = Metric(
    code: 'L-01',
    cjk: '負荷率',
    en: 'load',
    unit: '%',
    min: 0,
    max: 100,
    warn: 70,
    crit: 90,
    value: 58,
    digits: 0,
    width: 3,
    jitter: 1.4,
  );

  final Metric linkQuality = Metric(
    code: 'Q-01',
    cjk: '回線品質',
    en: 'link quality',
    unit: 'dBm',
    min: -110,
    max: -30,
    warn: -85,
    crit: -98,
    value: -61,
    digits: 0,
    width: 4,
    lowIsBad: true,
    jitter: 1.1,
  );

  final Metric reserve = Metric(
    code: 'R-01',
    cjk: '予備電力',
    en: 'reserve',
    unit: '%',
    min: 0,
    max: 100,
    warn: 40,
    crit: 20,
    value: 84,
    digits: 0,
    width: 3,
    lowIsBad: true,
    jitter: 0.3,
  );

  late final List<Metric> metrics = <Metric>[coolantTemp, coolantPressure, busVoltage, load, linkQuality, reserve];

  final List<Sector> sectors = <Sector>[
    Sector(code: 'SEC-01', cjk: '電源', en: 'power', operator: 'OP-03', load: 62, temp: 41),
    Sector(code: 'SEC-02', cjk: '配電', en: 'distribution', operator: 'OP-03', load: 55, temp: 38),
    Sector(code: 'SEC-03', cjk: '蓄電', en: 'storage', operator: 'OP-11', load: 31, temp: 29),
    Sector(code: 'SEC-04', cjk: '冷却', en: 'coolant', operator: 'OP-07', load: 58, temp: 43),
    Sector(code: 'SEC-05', cjk: '給水', en: 'feed water', operator: 'OP-07', load: 47, temp: 36),
    Sector(code: 'SEC-06', cjk: '換気', en: 'ventilation', operator: 'OP-09', load: 39, temp: 27),
    Sector(code: 'SEC-07', cjk: '通信', en: 'comms', operator: 'OP-02', load: 44, temp: 33),
    Sector(code: 'SEC-08', cjk: '中継', en: 'relay', operator: 'OP-02', load: 52, temp: 35, level: KkLevel.caution, note: 'CH.12 RESYNC'),
    Sector(code: 'SEC-09', cjk: '制御', en: 'control', operator: 'OP-01', load: 36, temp: 31),
    Sector(code: 'SEC-10', cjk: '監視', en: 'monitor', operator: 'OP-01', load: 28, temp: 30),
    Sector(code: 'SEC-11', cjk: '補機', en: 'auxiliary', operator: 'OP-05', load: 12, temp: 24),
    Sector(code: 'SEC-12', cjk: '予備', en: 'spare', operator: '—', load: 0, temp: 21, level: KkLevel.offline, note: 'STANDBY'),
  ];

  /// Newest last.
  final List<LogLine> log = <LogLine>[];

  final List<AlarmWindow> alarms = <AlarmWindow>[
    AlarmWindow(code: 'A-01', cjk: '水圧', en: 'pressure low'),
    AlarmWindow(code: 'A-02', cjk: '水温', en: 'temp high'),
    AlarmWindow(code: 'A-03', cjk: '電圧', en: 'voltage', level: KkLevel.caution),
    AlarmWindow(code: 'A-04', cjk: '過負荷', en: 'overload'),
    AlarmWindow(code: 'A-05', cjk: '断線', en: 'link lost', level: KkLevel.caution),
    AlarmWindow(code: 'A-06', cjk: '漏洩', en: 'leak'),
    AlarmWindow(code: 'A-07', cjk: '火災', en: 'fire'),
    AlarmWindow(code: 'A-08', cjk: '侵入', en: 'intrusion'),
  ];

  final List<ProcedureStep> procedure = <ProcedureStep>[
    ProcedureStep(cjk: '警報確認', en: 'acknowledge alarm', note: 'A-01 PRESSURE LOW · SEC-04'),
    ProcedureStep(cjk: '補助起動', en: 'start aux pump', note: 'PUMP B · 1450 RPM'),
    ProcedureStep(cjk: '弁閉鎖', en: 'close valve', note: 'V-17 · MANUAL'),
    ProcedureStep(cjk: '圧力回復', en: 'pressure recovery', note: 'TARGET 240 kPa'),
    ProcedureStep(cjk: '主機復帰', en: 'restore main pump', note: 'PUMP A · INTERLOCK'),
    ProcedureStep(cjk: '平時復帰', en: 'return to standby', note: 'CONDITION STANDBY'),
  ];

  final List<Channel> channels = <Channel>[
    Channel(id: 'CH-A', name: 'primary', note: 'SENSOR BUS A', verdict: Verdict.go),
    Channel(id: 'CH-B', name: 'secondary', note: 'SENSOR BUS B', verdict: Verdict.go),
    Channel(id: 'CH-C', name: 'reference', note: 'MODEL ESTIMATE', verdict: Verdict.go),
  ];

  /// Index of the operating mode: 0 STANDBY, 1 MONITOR, 2 RESPOND, 3 RECOVER.
  int get mode => switch (_phase) {
    IncidentPhase.none => 1,
    IncidentPhase.caution => 1,
    IncidentPhase.critical => 2,
    IncidentPhase.acknowledged => 2,
    IncidentPhase.recovering => 3,
  };

  /// The worst level among the metrics.
  KkLevel get level {
    KkLevel worst = KkLevel.nominal;
    for (final Metric m in metrics) {
      if (m.level.severity > worst.severity) worst = m.level;
    }
    return worst;
  }

  int get activeAlarms => alarms.where((AlarmWindow a) => a.state == AlarmState.alarm).length;

  // ── running ─────────────────────────────────────────────────────────────

  /// Ticks once a second until [stop] or [dispose].
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (Timer _) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Advances the plant by one second.
  void tick() {
    _now = _now.add(const Duration(seconds: 1));
    uptime++;
    _phaseAge++;
    _script();
    for (final Metric m in metrics) {
      m._step(_random);
    }
    _stepSectors();
    _stepAlarms();
    if (_random.nextDouble() < 0.22) _routineLog();
    notifyListeners();
  }

  void _stepSectors() {
    for (final Sector s in sectors) {
      if (s.level != KkLevel.offline) {
        s.load = (s.load + (_random.nextDouble() - 0.5) * 3).clamp(4.0, 99.0);
        s.temp = (s.temp + (_random.nextDouble() - 0.5) * 0.8).clamp(18.0, 95.0);
      }
      s.trend.add(s.load);
      if (s.trend.length > 24) s.trend.removeAt(0);
    }
  }

  void _stepAlarms() {
    final AlarmWindow pressure = alarms[0];
    final AlarmWindow temp = alarms[1];
    _drive(pressure, coolantPressure.level == KkLevel.critical);
    _drive(temp, coolantTemp.level == KkLevel.critical);
  }

  void _drive(AlarmWindow window, bool active) {
    if (active && window.state == AlarmState.normal) {
      window.state = AlarmState.alarm;
    } else if (!active && window.state == AlarmState.acknowledged) {
      window.state = AlarmState.returned;
    }
  }

  void _script() {
    final Sector coolant = sectors[3];
    switch (_phase) {
      case IncidentPhase.none:
        break;
      case IncidentPhase.caution:
        coolantPressure.target = 150;
        coolantTemp.target = 76;
        if (_phaseAge == 1) {
          coolant
            ..level = KkLevel.caution
            ..note = 'PRESSURE FALLING';
          _add('SEC-04', 'COOLANT PRESSURE FALLING', KkLevel.caution);
          channels[1]
            ..verdict = Verdict.wait
            ..note = 'DEVIATION 4.1%';
        }
        if (_phaseAge >= 5) _enter(IncidentPhase.critical);
      case IncidentPhase.critical:
        coolantPressure.target = 96;
        coolantTemp.target = 94;
        if (_phaseAge == 1) {
          coolant
            ..level = KkLevel.critical
            ..note = 'PRESSURE LOW';
          _add('SEC-04', 'COOLANT PRESSURE LOW', KkLevel.critical);
          channels[0]
            ..verdict = Verdict.noGo
            ..note = 'P-01 BELOW LIMIT';
          channels[1]
            ..verdict = Verdict.noGo
            ..note = 'P-01 BELOW LIMIT';
          procedure[0].status = StepStatus.active;
        }
      case IncidentPhase.acknowledged:
        coolantPressure.target = 110;
        coolantTemp.target = 92;
      case IncidentPhase.recovering:
        coolantPressure.target = 256;
        coolantTemp.target = 42.7;
        if (_phaseAge == 6) {
          coolant
            ..level = KkLevel.caution
            ..note = 'RECOVERING';
          channels[0]
            ..verdict = Verdict.go
            ..note = 'SENSOR BUS A';
        }
        if (_phaseAge >= 12 && coolantPressure.level == KkLevel.nominal) {
          coolant
            ..level = KkLevel.nominal
            ..note = '';
          channels[1]
            ..verdict = Verdict.go
            ..note = 'SENSOR BUS B';
          for (final AlarmWindow a in alarms) {
            a.state = AlarmState.normal;
          }
          _add('SEC-04', 'COOLANT PRESSURE WITHIN LIMITS', KkLevel.nominal);
          _enter(IncidentPhase.none);
        }
    }
  }

  void _enter(IncidentPhase phase) {
    _phase = phase;
    _phaseAge = 0;
  }

  // ── operator actions ────────────────────────────────────────────────────

  /// Starts the scripted coolant incident: caution, then critical five
  /// seconds later.
  void triggerIncident() {
    if (_phase != IncidentPhase.none) return;
    for (final ProcedureStep s in procedure) {
      s
        ..status = StepStatus.pending
        ..at = null;
    }
    _enter(IncidentPhase.caution);
    _add('HQ-03', 'DRILL STARTED BY OPERATOR', null);
    notifyListeners();
  }

  /// Acknowledges every sounding alarm and takes down the full-screen alarm.
  void acknowledge() {
    for (final AlarmWindow a in alarms) {
      if (a.state == AlarmState.alarm) a.state = AlarmState.acknowledged;
    }
    if (_phase == IncidentPhase.critical) {
      _enter(IncidentPhase.acknowledged);
      _completeStep(0);
      _add('OP-07', 'ALARM A-01 ACKNOWLEDGED', null);
    }
    notifyListeners();
  }

  /// Acknowledges or resets one alarm window.
  void pressAlarm(AlarmWindow window) {
    if (window.state == AlarmState.alarm) {
      window.state = AlarmState.acknowledged;
    } else if (window.state == AlarmState.returned) {
      window.state = AlarmState.normal;
    }
    notifyListeners();
  }

  /// Completes the active procedure step and activates the next one. The
  /// plant starts to recover once the valve is closed (step 3).
  void advanceProcedure() {
    final int index = procedure.indexWhere((ProcedureStep s) => s.status == StepStatus.active);
    if (index < 0) return;
    if (index == 0) {
      acknowledge();
      return;
    }
    _completeStep(index);
    _add('OP-07', '${procedure[index].en.toUpperCase()} COMPLETE', KkLevel.nominal);
    if (index == 2 && _phase == IncidentPhase.acknowledged) _enter(IncidentPhase.recovering);
    notifyListeners();
  }

  void _completeStep(int index) {
    procedure[index]
      ..status = StepStatus.done
      ..at = _now;
    if (index + 1 < procedure.length) procedure[index + 1].status = StepStatus.active;
  }

  /// Returns everything to normal at once.
  void reset() {
    _enter(IncidentPhase.none);
    coolantPressure.target = 256;
    coolantTemp.target = 42.7;
    sectors[3]
      ..level = KkLevel.nominal
      ..note = '';
    for (final AlarmWindow a in alarms) {
      a.state = AlarmState.normal;
    }
    for (final ProcedureStep s in procedure) {
      s
        ..status = StepStatus.pending
        ..at = null;
    }
    for (final Channel c in channels) {
      c.verdict = Verdict.go;
    }
    channels[0].note = 'SENSOR BUS A';
    channels[1].note = 'SENSOR BUS B';
    _add('HQ-03', 'CONDITION STANDBY', KkLevel.nominal);
    notifyListeners();
  }

  // ── log ─────────────────────────────────────────────────────────────────

  static const List<(String, String)> _routine = <(String, String)>[
    ('SEC-01', 'BUS VOLTAGE WITHIN LIMITS'),
    ('SEC-07', 'LINK CH.04 HEARTBEAT'),
    ('SEC-09', 'SELF TEST PASS'),
    ('SEC-02', 'BREAKER Q-12 CLOSED'),
    ('SEC-06', 'FAN F-03 SPEED 62%'),
    ('SEC-10', 'CAMERA C-08 ONLINE'),
    ('SEC-05', 'FEED PUMP FLOW 118 L/MIN'),
    ('SEC-03', 'CELL BANK B BALANCED'),
    ('N-07', 'ROUTE TABLE UPDATED'),
    ('SEC-11', 'AUX UNIT IDLE'),
  ];

  void _seedLog() {
    final DateTime base = _now;
    final List<(int, String, String, KkLevel?)> seed = <(int, String, String, KkLevel?)>[
      (-412, 'HQ-03', 'OPERATOR OP-07 LOGIN', null),
      (-388, 'SEC-09', 'SELF TEST PASS', KkLevel.nominal),
      (-301, 'SEC-01', 'BUS VOLTAGE WITHIN LIMITS', KkLevel.nominal),
      (-244, 'SEC-08', 'LINK CH.12 RESYNC', KkLevel.caution),
      (-190, 'SEC-04', 'PUMP A FLOW 204 L/MIN', KkLevel.nominal),
      (-127, 'SEC-12', 'SPARE UNIT STANDBY', KkLevel.offline),
      (-64, 'SEC-07', 'LINK CH.04 HEARTBEAT', KkLevel.nominal),
      (-12, 'SEC-02', 'BREAKER Q-12 CLOSED', KkLevel.nominal),
    ];
    for (final (int offset, String source, String message, KkLevel? level) in seed) {
      log.add(LogLine(time: base.add(Duration(seconds: offset)), source: source, message: message, level: level));
    }
  }

  void _routineLog() {
    final (String source, String message) = _routine[_random.nextInt(_routine.length)];
    _add(source, message, KkLevel.nominal);
  }

  void _add(String source, String message, KkLevel? level) {
    log.add(LogLine(time: _now, source: source, message: message, level: level));
    if (log.length > 200) log.removeAt(0);
  }
}
