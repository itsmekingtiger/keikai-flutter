import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/scroll.dart';
import '../motion/effects.dart';
import '../shell/snackbar.dart';
import 'routes.dart';

/// The root of a KEIKAI application.
///
/// It stands where `MaterialApp` or `CupertinoApp` would: it owns the
/// navigator, the overlay, focus traversal and shortcuts (through the
/// framework's `WidgetsApp`), installs the [KeikaiTheme], the KEIKAI scroll
/// behaviour and page transition, and plays the screen glitch with three red
/// flashes at the moment [condition] turns to alert.
///
/// ```dart
/// void main() => runApp(const KeikaiApp(title: 'HQ', home: SituationBoard()));
/// ```
class KeikaiApp extends StatefulWidget {
  const KeikaiApp({
    super.key,
    this.title = '',
    this.theme = const KeikaiThemeData(),
    this.condition,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.navigatorKey,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
    this.locale,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.localizationsDelegates,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior = const KkScrollBehavior(),
    this.wallScale = true,
    this.glitchOnAlert = true,
    this.debugShowCheckedModeBanner = false,
  }) : routerConfig = null;

  /// An app driven by a [RouterConfig] (declarative routing) instead of a
  /// navigator with named routes.
  const KeikaiApp.router({
    super.key,
    required RouterConfig<Object> this.routerConfig,
    this.title = '',
    this.theme = const KeikaiThemeData(),
    this.condition,
    this.builder,
    this.locale,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.localizationsDelegates,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior = const KkScrollBehavior(),
    this.wallScale = true,
    this.glitchOnAlert = true,
    this.debugShowCheckedModeBanner = false,
  }) : home = null,
       routes = const <String, WidgetBuilder>{},
       initialRoute = null,
       onGenerateRoute = null,
       onUnknownRoute = null,
       navigatorKey = null,
       navigatorObservers = const <NavigatorObserver>[];

  final String title;

  /// Colours, type, metrics and motion for the whole app.
  final KeikaiThemeData theme;

  /// The condition to show. When null the app keeps its own, starting from
  /// [theme]'s, and descendants switch it with `KeikaiApp.setCondition`.
  final KkCondition? condition;

  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final RouteFactory? onUnknownRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver> navigatorObservers;
  final RouterConfig<Object>? routerConfig;

  /// Wraps the navigator, inside the theme. Use it for app-wide chrome.
  final TransitionBuilder? builder;
  final Locale? locale;
  final Iterable<Locale> supportedLocales;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;
  final String? restorationScopeId;
  final ScrollBehavior scrollBehavior;

  /// Scale type by 1.25 on wall displays (2560px and wider).
  final bool wallScale;

  /// Glitch the screen and flash red when the condition turns to alert.
  ///
  /// Changing it plays nothing by itself: it is read at each turn to alert.
  final bool glitchOnAlert;
  final bool debugShowCheckedModeBanner;

  /// Switches the condition of the nearest [KeikaiApp].
  ///
  /// Has no effect when the app's [condition] is controlled by its parent.
  static void setCondition(BuildContext context, KkCondition condition) {
    context.findAncestorStateOfType<_KeikaiAppState>()?._setCondition(condition);
  }

  /// The condition currently shown by the nearest [KeikaiApp].
  static KkCondition conditionOf(BuildContext context) => KeikaiTheme.of(context).condition;

  @override
  State<KeikaiApp> createState() => _KeikaiAppState();
}

class _KeikaiAppState extends State<KeikaiApp> {
  late KkCondition _own = widget.theme.condition;

  /// The turns to alert that were to be shown with the glitch. It is the
  /// glitch's trigger, so it changes at a turn to alert and at nothing else:
  /// switching [KeikaiApp.glitchOnAlert] must not play the effect.
  int _glitches = 0;

  KkCondition get _condition => widget.condition ?? _own;

  void _setCondition(KkCondition condition) {
    if (widget.condition != null || condition == _own) return;
    setState(() {
      if (condition == KkCondition.alert && widget.glitchOnAlert) _glitches++;
      _own = condition;
    });
  }

  @override
  void didUpdateWidget(KeikaiApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final KkCondition? now = widget.condition;
    if (now != null && now != (oldWidget.condition ?? _own)) {
      if (now == KkCondition.alert && widget.glitchOnAlert) _glitches++;
      _own = now;
    }
  }

  Widget _build(BuildContext context, Widget? child) {
    KeikaiThemeData data = widget.theme.withCondition(_condition);
    if (widget.wallScale) {
      final double? width = MediaQuery.maybeSizeOf(context)?.width;
      if (width != null && data.metrics.windowClass(width) == KkWindowClass.wall && data.type.scale == 1.0) {
        data = data.copyWith(type: data.type.copyWith(scale: 1.25));
      }
    }
    final KkColors colors = data.colors;
    Widget content = child ?? const SizedBox.shrink();
    final TransitionBuilder? userBuilder = widget.builder;
    if (userBuilder != null) {
      final Widget navigator = content;
      content = Builder(builder: (BuildContext context) => userBuilder(context, navigator));
    }
    return KeikaiTheme(
      data: data,
      child: DefaultSelectionStyle(
        cursorColor: colors.signal,
        selectionColor: colors.signalDim,
        child: ScrollConfiguration(
          behavior: widget.scrollBehavior,
          child: KkGlitch(
            trigger: _glitches,
            // The snackbar stack sits above every route.
            child: ColoredBox(color: colors.bg000, child: KkMessenger(child: content)),
          ),
        ),
      ),
    );
  }

  PageRoute<T> _pageRoute<T>(RouteSettings settings, WidgetBuilder builder) =>
      KkPageRoute<T>(settings: settings, builder: builder);

  @override
  Widget build(BuildContext context) {
    final KkColors colors = widget.theme.withCondition(_condition).colors;
    final TextStyle textStyle = widget.theme.type.bodyMd.copyWith(color: colors.ink);
    final RouterConfig<Object>? router = widget.routerConfig;
    if (router != null) {
      return WidgetsApp.router(
        routerConfig: router,
        title: widget.title,
        color: colors.signal,
        textStyle: textStyle,
        builder: _build,
        locale: widget.locale,
        supportedLocales: widget.supportedLocales,
        localizationsDelegates: widget.localizationsDelegates,
        shortcuts: widget.shortcuts,
        actions: widget.actions,
        restorationScopeId: widget.restorationScopeId,
        debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      );
    }
    return WidgetsApp(
      title: widget.title,
      color: colors.signal,
      textStyle: textStyle,
      home: widget.home,
      routes: widget.routes,
      initialRoute: widget.initialRoute,
      onGenerateRoute: widget.onGenerateRoute,
      onUnknownRoute: widget.onUnknownRoute,
      navigatorKey: widget.navigatorKey,
      navigatorObservers: widget.navigatorObservers,
      pageRouteBuilder: _pageRoute,
      builder: _build,
      locale: widget.locale,
      supportedLocales: widget.supportedLocales,
      localizationsDelegates: widget.localizationsDelegates,
      shortcuts: widget.shortcuts,
      actions: widget.actions,
      restorationScopeId: widget.restorationScopeId,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
    );
  }
}
