import 'package:keikai/keikai.dart';

import 'settings.dart';
import 'station.dart';

/// Hands the simulated [station], the operator's [settings] and the console's
/// [notices] to every screen. The first two are listenables: wrap what should
/// follow them in a `ListenableBuilder`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.station,
    required this.settings,
    required this.notices,
    required super.child,
  });

  final Station station;
  final AppSettings settings;
  final ConsoleNotices notices;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.station != station || oldWidget.settings != settings || oldWidget.notices != notices;
}

/// The snackbars of the console.
///
/// Every page keeps a stack of its own (a `KkMessenger` around its screen),
/// so a dialog, a sheet or the full-screen alarm always lies over the
/// snackbars, and none of them can cover a button that waits for an answer. A
/// notice goes to the page on top, whoever raises it: a screen, a sheet over
/// it, or the plant.
class ConsoleNotices {
  final List<GlobalKey<KkMessengerState>> _pages = <GlobalKey<KkMessengerState>>[];

  /// A page registers its stack when it comes and takes it back when it goes.
  void attach(GlobalKey<KkMessengerState> page) => _pages.add(page);

  void detach(GlobalKey<KkMessengerState> page) => _pages.remove(page);

  KkMessengerState? get _top {
    for (int i = _pages.length - 1; i >= 0; i--) {
      final KkMessengerState? state = _pages[i].currentState;
      if (state != null) return state;
    }
    return null;
  }

  /// Shows a snackbar on the page on top. Without a page (during the boot)
  /// there is nowhere to show it and nothing happens.
  void show({String? code, required String message, KkLevel? level}) =>
      _top?.show(code: code, message: message, level: level);

  /// Closes every snackbar, on every page.
  void clear() {
    for (final GlobalKey<KkMessengerState> page in _pages) {
      page.currentState?.clear();
    }
  }
}

/// Shorthands: `context.station`, `context.settings`, `context.notices`.
extension AppScopeContext on BuildContext {
  Station get station => AppScope.of(this).station;
  AppSettings get settings => AppScope.of(this).settings;
  ConsoleNotices get notices => AppScope.of(this).notices;
}
