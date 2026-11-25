/// The four status levels. One value drives colour, status icon and word in
/// every component that takes a `level`.
///
/// A `null` level means "no level": the component shows its neutral form
/// (and the status icon, where one is shown, is the info plate).
enum KkLevel {
  nominal,
  caution,
  critical,
  offline;

  /// The Latin status word: `NOMINAL`, `CAUTION`, `CRITICAL`, `OFFLINE`.
  String get word => switch (this) {
    KkLevel.nominal => 'NOMINAL',
    KkLevel.caution => 'CAUTION',
    KkLevel.critical => 'CRITICAL',
    KkLevel.offline => 'OFFLINE',
  };

  /// The 漢字 status word: 正常 · 注意 · 警報 · 断線.
  String get cjk => switch (this) {
    KkLevel.nominal => '正常',
    KkLevel.caution => '注意',
    KkLevel.critical => '警報',
    KkLevel.offline => '断線',
  };

  /// The Korean status word: 정상 · 주의 · 경보 · 단절.
  String get ko => switch (this) {
    KkLevel.nominal => '정상',
    KkLevel.caution => '주의',
    KkLevel.critical => '경보',
    KkLevel.offline => '단절',
  };

  /// Whether a higher number means a worse state. Useful for sorting.
  int get severity => switch (this) {
    KkLevel.nominal => 0,
    KkLevel.offline => 1,
    KkLevel.caution => 2,
    KkLevel.critical => 3,
  };
}

/// The two themes. [standby] is orange on black; [alert] turns the identity
/// colour red and is switched on only for a real alarm.
enum KkCondition { standby, alert }
