import 'package:keikai/keikai.dart';

/// How the screen picks its condition.
enum ConditionMode {
  /// Follow the plant: alert while an incident is critical or acknowledged.
  auto,

  /// Stay in standby whatever happens.
  standby,

  /// Show the alert theme now.
  alert,
}

/// The unit temperatures are shown in.
enum TempUnit { celsius, fahrenheit }

/// The operator's duty.
enum Duty { watch, engineer, supervisor }

/// Everything the operator can set on the settings screen. The whole app
/// listens to it, so a change shows at once.
class AppSettings extends ChangeNotifier {
  AppSettings({
    bool motion = true,
    bool changedDigits = false,
    double timeScale = 1,
    double textScale = 1,
    bool crt = false,
    bool dense = false,
    bool glitch = true,
    ConditionMode conditionMode = ConditionMode.auto,
    String operator = 'OP-07',
  }) : _motion = motion,
       _changedDigits = changedDigits,
       _timeScale = timeScale,
       _textScale = textScale,
       _crt = crt,
       _dense = dense,
       _glitch = glitch,
       _conditionMode = conditionMode,
       _operator = operator;

  static final RegExp _callSign = RegExp(r'^[A-Z]{2}-\d{2}$');

  /// Why [value] cannot be an operator call sign, or null when it can.
  static String? operatorError(String value) {
    if (value.isEmpty) return 'CALL SIGN REQUIRED';
    if (!_callSign.hasMatch(value)) return 'FORMAT AA-00 · TWO LETTERS, TWO DIGITS';
    return null;
  }

  ConditionMode _conditionMode;
  ConditionMode get conditionMode => _conditionMode;
  set conditionMode(ConditionMode value) => _set(() => _conditionMode = value, _conditionMode != value);

  bool _motion;

  /// Whether anything on screen moves.
  bool get motion => _motion;
  set motion(bool value) => _set(() => _motion = value, _motion != value);

  bool _changedDigits;

  /// Whether a value that changes scrambles only the digits that changed
  /// instead of all of them.
  bool get changedDigits => _changedDigits;
  set changedDigits(bool value) => _set(() => _changedDigits = value, _changedDigits != value);

  double _timeScale;

  /// Multiplies every duration: 2 is half speed.
  double get timeScale => _timeScale;
  set timeScale(double value) => _set(() => _timeScale = value, _timeScale != value);

  double _textScale;

  /// Multiplies every font size.
  double get textScale => _textScale;
  set textScale(double value) => _set(() => _textScale = value, _textScale != value);

  bool _crt;

  /// Draw scan lines and a sweep over the whole screen.
  bool get crt => _crt;
  set crt(bool value) => _set(() => _crt = value, _crt != value);

  bool _dense;

  /// Show lists and tables with 32px rows.
  bool get dense => _dense;
  set dense(bool value) => _set(() => _dense = value, _dense != value);

  bool _glitch;

  /// Glitch the screen and flash red when the condition turns to alert.
  bool get glitch => _glitch;
  set glitch(bool value) => _set(() => _glitch = value, _glitch != value);

  String _operator;

  /// The call sign of whoever sits at the console. Always a valid one.
  String get operator => _operator;
  set operator(String value) {
    if (operatorError(value) != null) return;
    _set(() => _operator = value, _operator != value);
  }

  String _node = 'NODE 07';
  String get node => _node;
  set node(String value) => _set(() => _node = value, _node != value);

  Duty _duty = Duty.watch;
  Duty get duty => _duty;
  set duty(Duty value) => _set(() => _duty = value, _duty != value);

  TempUnit _tempUnit = TempUnit.celsius;
  TempUnit get tempUnit => _tempUnit;
  set tempUnit(TempUnit value) => _set(() => _tempUnit = value, _tempUnit != value);

  String _notes = '';

  /// Handover notes, 120 characters at most.
  String get notes => _notes;
  set notes(String value) => _set(() => _notes = value, _notes != value);

  final Set<KkLevel> _notify = <KkLevel>{KkLevel.caution, KkLevel.critical};

  /// The levels a new log line must have to raise a snackbar.
  Set<KkLevel> get notify => _notify;

  void setNotify(KkLevel level, {required bool on}) {
    final bool changed = on ? _notify.add(level) : _notify.remove(level);
    if (changed) notifyListeners();
  }

  void setNotifyAll({required bool on}) {
    final int before = _notify.length;
    if (on) {
      _notify.addAll(KkLevel.values);
    } else {
      _notify.clear();
    }
    if (_notify.length != before) notifyListeners();
  }

  double _volume = 60;

  /// Loudness of the alarm horn, 0 to 100.
  double get volume => _volume;
  set volume(double value) => _set(() => _volume = value, _volume != value);

  DateTime _maintenance = DateTime.utc(2026, 12, 8);

  /// The day of the next maintenance window.
  DateTime get maintenance => _maintenance;
  set maintenance(DateTime value) => _set(() => _maintenance = value, _maintenance != value);

  KkTime _shiftStart = const KkTime(6, 0);

  /// When the watch changes.
  KkTime get shiftStart => _shiftStart;
  set shiftStart(KkTime value) => _set(() => _shiftStart = value, _shiftStart.compareTo(value) != 0);

  /// Puts everything back to the way it was at first start.
  void reset() {
    _conditionMode = ConditionMode.auto;
    _motion = true;
    _changedDigits = false;
    _timeScale = 1;
    _textScale = 1;
    _crt = false;
    _dense = false;
    _glitch = true;
    _operator = 'OP-07';
    _node = 'NODE 07';
    _duty = Duty.watch;
    _tempUnit = TempUnit.celsius;
    _notes = '';
    _notify
      ..clear()
      ..addAll(<KkLevel>[KkLevel.caution, KkLevel.critical]);
    _volume = 60;
    _maintenance = DateTime.utc(2026, 12, 8);
    _shiftStart = const KkTime(6, 0);
    notifyListeners();
  }

  /// A temperature in °C as a number in the chosen unit.
  double degrees(double celsius) => _tempUnit == TempUnit.celsius ? celsius : celsius * 9 / 5 + 32;

  /// A temperature in °C as text in the chosen unit, at a fixed width.
  String temperature(double celsius, {int digits = 3, int decimals = 1}) {
    return kkFixed(degrees(celsius), digits: digits, decimals: decimals);
  }

  /// `°C` or `°F`.
  String get tempSymbol => _tempUnit == TempUnit.celsius ? '°C' : '°F';

  void _set(VoidCallback change, bool changed) {
    if (!changed) return;
    change();
    notifyListeners();
  }
}
