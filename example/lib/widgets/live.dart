import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';

/// Rebuilds [builder] whenever the station ticks or a setting changes.
class Live extends StatelessWidget {
  const Live({super.key, required this.builder});

  final Widget Function(BuildContext context, Station station, AppSettings settings) builder;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.settings,
      builder: (BuildContext context, Widget? _) => ListenableBuilder(
        listenable: scope.station,
        builder: (BuildContext context, Widget? _) => builder(context, scope.station, scope.settings),
      ),
    );
  }
}

/// How an incident phase is said on screen.
({String cjk, String en, KkLevel? level}) phaseWords(IncidentPhase phase) => switch (phase) {
  IncidentPhase.none => (cjk: '平時', en: 'standby', level: null),
  IncidentPhase.caution => (cjk: '注意', en: 'caution', level: KkLevel.caution),
  IncidentPhase.critical => (cjk: '警報', en: 'alert', level: KkLevel.critical),
  IncidentPhase.acknowledged => (cjk: '警報', en: 'alert', level: KkLevel.critical),
  IncidentPhase.recovering => (cjk: '復旧', en: 'recovery', level: KkLevel.caution),
};

/// What is wrong, in one line: `critical — coolant pressure low`.
String incidentHeadline(Station station) => switch (station.phase) {
  IncidentPhase.caution => 'caution — coolant pressure falling',
  IncidentPhase.recovering => 'recovery — coolant pressure rising',
  _ => 'critical — ${station.incidentEn}',
};

/// `076:17:42` for a count of seconds.
String formatUptime(int seconds) {
  final int h = seconds ~/ 3600;
  final int m = seconds % 3600 ~/ 60;
  final int s = seconds % 60;
  return '${kkFixed(h, digits: 3)}:${kkFixed(m, digits: 2)}:${kkFixed(s, digits: 2)}';
}

/// `14:02:31Z` for a UTC time.
String formatClock(DateTime time) => '${kkFormatTime(time)}Z';
