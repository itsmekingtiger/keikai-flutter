import 'package:keikai/keikai.dart';

import 'model/app_scope.dart';
import 'model/settings.dart';
import 'model/station.dart';
import 'shell/boot_screen.dart';
import 'shell/console_shell.dart';
import 'shell/destinations.dart';
import 'shell/not_found_screen.dart';

/// The operations console of plant HQ-03, built with KEIKAI widgets only.
///
/// Give it a [station] and [settings] to drive it from outside (tests do);
/// without them it makes its own and lets the plant run.
class KeikaiExampleApp extends StatefulWidget {
  const KeikaiExampleApp({
    super.key,
    this.station,
    this.settings,
    this.boot = true,
    this.autoStart = true,
    this.initialRoute,
  });

  /// The plant to show. The app makes (and disposes) its own when null.
  final Station? station;

  /// The operator's settings. The app makes (and disposes) its own when null.
  final AppSettings? settings;

  /// Play the start-up screen before the console appears.
  final bool boot;

  /// Let an app-made station tick by itself.
  final bool autoStart;

  /// The route to open on, such as `/systems`. Defaults to the address the
  /// platform gives (the browser's address bar), else the situation board.
  final String? initialRoute;

  @override
  State<KeikaiExampleApp> createState() => _KeikaiExampleAppState();
}

class _KeikaiExampleAppState extends State<KeikaiExampleApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final ConsoleNotices _notices = ConsoleNotices();
  Station? _ownStation;
  AppSettings? _ownSettings;

  Station get _station => widget.station ?? (_ownStation ??= Station());
  AppSettings get _settings => widget.settings ?? (_ownSettings ??= AppSettings());

  @override
  void initState() {
    super.initState();
    if (widget.station == null && widget.autoStart) _station.start();
  }

  @override
  void dispose() {
    _ownStation?.dispose();
    _ownSettings?.dispose();
    super.dispose();
  }

  /// Every address gets a page: one of the seven screens, or the page that
  /// says there is nothing there. (An address typed into the browser reaches
  /// the navigator as the initial route, where a missing page would only be
  /// reported as an error.)
  Route<Object?> _route(RouteSettings settings) {
    final Destination? destination = Destination.fromRoute(settings.name);
    return KkPageRoute<Object?>(
      settings: settings,
      builder: (BuildContext context) =>
          destination == null ? NotFoundScreen(name: settings.name ?? '') : ConsoleShell(destination: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Station station = _station;
    final AppSettings settings = _settings;
    return AppScope(
      station: station,
      settings: settings,
      notices: _notices,
      child: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? _) => ValueListenableBuilder<IncidentPhase>(
          valueListenable: station.phaseSignal,
          builder: (BuildContext context, IncidentPhase phase, Widget? _) {
            final KkCondition condition = switch (settings.conditionMode) {
              ConditionMode.auto => station.alert ? KkCondition.alert : KkCondition.standby,
              ConditionMode.standby => KkCondition.standby,
              ConditionMode.alert => KkCondition.alert,
            };
            return KeikaiApp(
              title: 'KEIKAI 管制 · HQ-03',
              theme: KeikaiThemeData(
                motion: KkMotion(
                  enabled: settings.motion,
                  timeScale: settings.timeScale,
                  scrambleScope: settings.changedDigits ? KkScrambleScope.changed : KkScrambleScope.all,
                ),
                type: KkTypography(scale: settings.textScale),
              ),
              condition: condition,
              glitchOnAlert: settings.glitch,
              navigatorKey: _navigator,
              initialRoute: widget.initialRoute,
              onGenerateRoute: _route,
              builder: (BuildContext context, Widget? child) =>
                  ConsoleFrame(navigator: _navigator, boot: widget.boot, child: child ?? const KkBox()),
            );
          },
        ),
      ),
    );
  }
}

/// What sits between the app and its pages: the start-up screen, the CRT
/// texture, the watch that raises the full-screen alarm, and the snackbars
/// for new log lines.
class ConsoleFrame extends StatefulWidget {
  const ConsoleFrame({super.key, required this.navigator, required this.boot, required this.child});

  final GlobalKey<NavigatorState> navigator;
  final bool boot;

  /// The app's navigator.
  final Widget child;

  @override
  State<ConsoleFrame> createState() => _ConsoleFrameState();
}

class _ConsoleFrameState extends State<ConsoleFrame> {
  // Keeps the pages alive when the CRT texture is switched on or off around them.
  final GlobalKey _pages = GlobalKey();

  late bool _booted = !widget.boot;
  Station? _station;
  int _seen = -1;
  bool _alarmUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Station station = context.station;
    if (station == _station) return;
    _unlisten();
    _station = station;
    _seen = station.log.isEmpty ? -1 : station.log.last.serial;
    station.addListener(_onTick);
    station.phaseSignal.addListener(_onPhase);
    if (_booted) _afterFrame(_onPhase);
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  void _unlisten() {
    _station?.removeListener(_onTick);
    _station?.phaseSignal.removeListener(_onPhase);
  }

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) action();
    });
  }

  /// New log lines of a level the operator asked to hear about become snackbars.
  void _onTick() {
    final Station station = _station!;
    final int last = station.log.isEmpty ? -1 : station.log.last.serial;
    if (last == _seen) return;
    final int from = _seen;
    _seen = last;
    if (!_booted || !mounted) return;
    // Under the full-screen alarm nothing is stacked: the alarm says it all.
    if (station.emergency) return;
    final Set<KkLevel> wanted = context.settings.notify;
    final ConsoleNotices notices = context.notices;
    for (final LogLine line in station.log) {
      final KkLevel? level = line.level;
      if (line.serial <= from || level == null || !wanted.contains(level)) continue;
      notices.show(code: line.source, message: line.message, level: level);
    }
  }

  /// Raises the full-screen alarm while the incident is critical and takes it
  /// down when it no longer is.
  void _onPhase() {
    final Station station = _station!;
    final NavigatorState? navigator = widget.navigator.currentState;
    final BuildContext? pages = widget.navigator.currentContext;
    if (!_booted || !mounted || navigator == null || pages == null) return;
    if (station.emergency && !_alarmUp) {
      _alarmUp = true;
      // What led up to the alarm is on the alarm itself: the snackbars go, so
      // that none is left over a control when the alarm has been answered.
      context.notices.clear();
      showKkEmergency<void>(
        pages,
        code: '${station.incidentCode} · SEC-04',
        cjk: station.incidentCjk,
        en: station.incidentEn,
        sub: station.incidentDetail,
        settings: const RouteSettings(name: emergencyRoute),
        actions: (BuildContext context) => <Widget>[
          KkButton(
            label: 'acknowledge',
            cjk: '確認',
            size: KkButtonSize.lg,
            style: KkEmergency.actionStyle(context),
            autofocus: true,
            onPressed: station.acknowledge,
          ),
        ],
      ).whenComplete(() => _alarmUp = false);
    } else if (!station.emergency && _alarmUp) {
      navigator.popUntil((Route<Object?> route) => route.settings.name != emergencyRoute);
    }
  }

  void _finishBoot() {
    if (_booted) return;
    setState(() => _booted = true);
    _afterFrame(_onPhase);
  }

  @override
  Widget build(BuildContext context) {
    if (!_booted) return BootScreen(onDone: _finishBoot);
    final AppSettings settings = context.settings;
    return ListenableBuilder(
      listenable: settings,
      child: KeyedSubtree(key: _pages, child: widget.child),
      builder: (BuildContext context, Widget? pages) =>
          KkCrt(scanlines: settings.crt, sweep: settings.crt, child: pages!),
    );
  }
}
