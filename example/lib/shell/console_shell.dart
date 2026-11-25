import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import '../screens/catalogue_screen.dart';
import '../screens/diagram_screen.dart';
import '../screens/log_screen.dart';
import '../screens/procedure_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/situation_screen.dart';
import '../screens/systems_screen.dart';
import '../widgets/incident_band.dart';
import '../widgets/live.dart';
import 'destinations.dart';

/// The frame every screen of the console sits in: command bar on top, the
/// rail at the left (a bar at the bottom on a phone), the toolbar at the
/// bottom, and the keys that work everywhere.
class ConsoleShell extends StatefulWidget {
  const ConsoleShell({super.key, required this.destination});

  final Destination destination;

  @override
  State<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends State<ConsoleShell> {
  // The body scrolls with a controller of its own. Without one it would share
  // the page's primary scroll controller with the rail's scroll view on phones
  // and tablets, and a scrollbar cannot serve two scroll views.
  final ScrollController _body = ScrollController();

  // The snackbars of this page. They are part of the page, so every dialog,
  // sheet and the full-screen alarm lie over them.
  final GlobalKey<KkMessengerState> _stack = GlobalKey<KkMessengerState>();
  ConsoleNotices? _notices;

  /// Height of the navigation bar a rail turns into on a phone.
  static const double _navBarHeight = 64;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ConsoleNotices notices = context.notices;
    if (notices == _notices) return;
    _notices?.detach(_stack);
    _notices = notices..attach(_stack);
  }

  @override
  void dispose() {
    _notices?.detach(_stack);
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Destination destination = widget.destination;
    final KkMetrics m = context.kk.metrics;
    final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
    // A window too low to give the body's corner away (a phone held sideways).
    final bool low = MediaQuery.sizeOf(context).height < 600;
    return ShellKeys(
      destination: destination,
      // Where the snackbars stack: beside the rail and above the toolbar, in
      // the bottom left corner of the body; on a phone above the navigation
      // bar too, and two at most. In a low window a single one lies over the
      // bars, where it covers no control of the screen.
      child: KkMessenger(
        key: _stack,
        maxVisible: low ? 1 : (compact ? 2 : 3),
        left: compact ? null : m.railWidth + m.space6,
        bottom: low ? 0 : m.toolbarHeight + (compact ? _navBarHeight : 0) + m.space4,
        child: KkScreen(
          // The alarm band is pinned under the command bar, clear of the scrolling body.
          commandBar: KkColumn(
            shrinkWrap: true,
            children: <Widget>[
              ConsoleCommandBar(destination: destination),
              if (destination != Destination.situation && destination != Destination.procedure) const IncidentBand(),
            ],
          ),
          nav: ConsoleRail(destination: destination),
          footer: const ConsoleToolbar(),
          // The catalogue pins its tabs and scrolls its sheet both ways itself.
          scrollBody: destination != Destination.catalogue,
          bodyController: _body,
          body: switch (destination) {
            Destination.situation => const SituationScreen(),
            Destination.systems => const SystemsScreen(),
            Destination.diagram => const DiagramScreen(),
            Destination.procedure => const ProcedureScreen(),
            Destination.log => const LogScreen(),
            Destination.settings => const SettingsScreen(),
            Destination.catalogue => const CatalogueScreen(),
          },
        ),
      ),
    );
  }
}

// ── actions shared by the bar, the rail, the drawer and the keys ──────────

/// Starts the scripted coolant drill and says so.
void startDrill(BuildContext context) {
  final Station station = context.station;
  if (station.phase != IncidentPhase.none) return;
  station.triggerIncident();
  context.notices.show(code: 'HQ-03', message: 'DRILL STARTED · COOLANT LOOP');
}

/// Acknowledges every sounding alarm.
void acknowledgeAlarms(BuildContext context) {
  final Station station = context.station;
  if (station.soundingAlarms == 0 && station.phase != IncidentPhase.critical) return;
  station.acknowledge();
}

/// Asks, then puts the plant back to normal.
Future<void> resetPlant(BuildContext context) async {
  final Station station = context.station;
  final ConsoleNotices notices = context.notices;
  final bool yes = await showKkConfirm(
    context: context,
    code: 'RST-01',
    cjk: '復帰確認',
    en: 'reset plant',
    message: '모든 경보와 절차를 지우고 평시 상태로 되돌립니다.',
    confirmLabel: 'reset',
    confirmCjk: '復帰',
    danger: true,
  );
  if (!yes) return;
  station.reset();
  notices.show(code: 'HQ-03', level: KkLevel.nominal, message: 'CONDITION STANDBY');
}

/// Opens the drawer over the left edge and goes where the operator points.
Future<void> openDrawer(BuildContext context, Destination current) async {
  final Destination? chosen = await showKkSheet<Destination>(
    context: context,
    side: KkSheetSide.left,
    builder: (BuildContext context) => ConsoleDrawer(current: current),
  );
  if (chosen != null && chosen != current && context.mounted) goTo(context, chosen);
}

/// Lists the keys of the console in a dialog.
Future<void> showKeys(BuildContext context) {
  return showKkDialog<void>(
    context: context,
    builder: (BuildContext context) => KkDialog(
      code: 'KEY-00',
      cjk: '鍵盤',
      en: 'keyboard',
      actions: <Widget>[
        KkButton(label: 'close', cjk: '閉', autofocus: true, onPressed: () => Navigator.of(context).pop()),
      ],
      child: const KkColumn(
        gap: 8,
        shrinkWrap: true,
        children: <Widget>[
          _KeyLine(keys: '1 – 7', text: '화면 이동: 상황 · 계통 · 선도 · 절차 · 기록 · 설정 · 목록'),
          _KeyLine(keys: 'M', text: '서랍 메뉴 열기'),
          _KeyLine(keys: 'D', text: '냉각 계통 훈련 시작'),
          _KeyLine(keys: 'A', text: '울리는 경보 모두 확인'),
          _KeyLine(keys: 'P', text: '시뮬레이션 진행 / 정지'),
          _KeyLine(keys: '?', text: '이 목록 열기'),
          _KeyLine(keys: 'ESC', text: '대화상자 · 측면판 · 메뉴 닫기'),
          _KeyLine(keys: 'TAB', text: '다음 조작 요소로 이동, ENTER / SPACE 로 실행'),
        ],
      ),
    ),
  );
}

class _KeyLine extends StatelessWidget {
  const _KeyLine({required this.keys, required this.text});

  final String keys;
  final String text;

  @override
  Widget build(BuildContext context) {
    return KkRow(
      gap: 12,
      children: <Widget>[
        KkBox(width: 56, alignment: Alignment.centerLeft, shrinkWrap: true, child: KkKbd(keys)),
        KkExpanded(child: KkText.body(text, size: 13, height: 1.4)),
      ],
    );
  }
}

// ── keys ──────────────────────────────────────────────────────────────────

/// The keys of the console. They work while the page (not a dialog over it)
/// has the focus and the operator is not typing into a field.
class ShellKeys extends StatelessWidget {
  const ShellKeys({super.key, required this.destination, required this.child});

  final Destination destination;
  final Widget child;

  /// Whether the focus is in a text field, where letters and digits are text.
  static bool _typing() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    if (_typing()) return KeyEventResult.ignored;
    // An activator matches a key going down (not its repeats) while Control,
    // Alt and Meta are up; Shift is ignored, so `?` and capitals work too.
    final keyboard = WidgetsBinding.instance.keyboard;
    bool hit(String character) => CharacterActivator(character, includeRepeats: false).accepts(event, keyboard);
    bool letter(String lower) => hit(lower) || hit(lower.toUpperCase());

    for (final Destination d in Destination.values) {
      if (hit(d.key)) {
        if (d != destination) goTo(context, d);
        return KeyEventResult.handled;
      }
    }
    if (hit('?')) {
      showKeys(context);
    } else if (letter('m')) {
      openDrawer(context, destination);
    } else if (letter('d')) {
      startDrill(context);
    } else if (letter('a')) {
      acknowledgeAlarms(context);
    } else if (letter('p')) {
      final Station station = context.station;
      station.running ? station.stop() : station.start();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      skipTraversal: true,
      debugLabel: 'console keys',
      onKeyEvent: (FocusNode node, KeyEvent event) => _onKey(context, event),
      child: child,
    );
  }
}

// ── command bar ───────────────────────────────────────────────────────────

class ConsoleCommandBar extends StatelessWidget {
  const ConsoleCommandBar({super.key, required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final Destination here = destination;
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final ({String cjk, String en, KkLevel? level}) words = phaseWords(station.phase);
        final Sector worst = station.sectors.reduce((Sector a, Sector b) => _rank(b.level) > _rank(a.level) ? b : a);
        // Every lit alarm window counts; the cell is red while one of them still sounds.
        final int alarms = station.activeAlarms;
        final bool sounding = station.soundingAlarms > 0;
        // How many readings fit beside the identity and the condition: none
        // on a phone, the two that matter most on a tablet, all of them from
        // 1200px.
        final KkWindowClass window = KkWindowScope.of(context);
        final bool compact = window == KkWindowClass.compact;
        final List<Widget> cells = <Widget>[
          if (window.isAtLeast(KkWindowClass.large)) KkCommandCell(label: 'operator', value: settings.operator),
          if (window.isAtLeast(KkWindowClass.expanded))
            KkCommandCell(label: 'sector', value: worst.code, level: worst.level),
          if (window.isAtLeast(KkWindowClass.large))
            KkCommandCell(
              label: 'coolant',
              value: '${settings.temperature(station.coolantTemp.value)} ${settings.tempSymbol}',
              level: station.coolantTemp.level,
            ),
          if (!compact)
            KkCommandCell(
              label: 'alarms',
              value: kkFixed(alarms, digits: 2),
              level: sounding ? KkLevel.critical : (alarms > 0 ? KkLevel.caution : KkLevel.nominal),
            ),
          if (!compact)
            KkCommandCell(
              label: 'utc',
              child: KkClock(clock: () => station.now),
            ),
        ];
        return KkCommandBar(
          name: 'keikai',
          node: compact ? 'HQ-03' : 'HQ-03 · ${settings.node}',
          conditionCjk: words.cjk,
          conditionEn: words.en,
          level: station.alert ? KkLevel.critical : null,
          idSemanticLabel: 'Situation board',
          onIdPressed: here == Destination.situation ? null : () => goTo(context, Destination.situation),
          leading: KkIconButton(
            icon: KkIcons.menu,
            size: KkIconButtonSize.lg,
            semanticLabel: 'Menu',
            onPressed: () => openDrawer(context, here),
          ),
          cells: cells,
          // Room for the badge, which hangs over the button's corner.
          trailing: KkPadding(
            padding: const EdgeInsets.only(right: 8),
            child: _AlarmMenu(station: station),
          ),
        );
      },
    );
  }

  static int _rank(KkLevel level) => switch (level) {
    KkLevel.critical => 3,
    KkLevel.caution => 2,
    KkLevel.offline => 1,
    KkLevel.nominal => 0,
  };
}

/// The bell at the right of the command bar: a count of sounding alarms and a
/// menu of what can be done about them.
class _AlarmMenu extends StatelessWidget {
  const _AlarmMenu({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    // The bell counts the alarms that still sound; it is struck through only
    // when no window is lit at all.
    final int alarms = station.soundingAlarms;
    final bool anyLit = station.activeAlarms > 0;
    final bool idle = station.phase == IncidentPhase.none;
    return KkMenuAnchor<String>(
      align: KkPopupAlign.end,
      menuSemanticLabel: 'Alarm actions',
      entries: <KkMenuEntry<String>>[
        const KkMenuLabel<String>('alarms'),
        KkMenuItem<String>(
          value: 'ack',
          label: 'acknowledge all',
          cjk: '確認',
          icon: KkIcons.check,
          shortcut: 'A',
          enabled: alarms > 0,
        ),
        const KkMenuItem<String>(value: 'procedure', label: 'open procedure', cjk: '手順', icon: KkIcons.list),
        const KkMenuSeparator<String>(),
        KkMenuItem<String>(
          value: 'drill',
          label: 'start drill',
          cjk: '訓練',
          icon: KkIcons.play,
          shortcut: 'D',
          enabled: idle,
        ),
        KkMenuItem<String>(
          value: 'reset',
          label: 'reset plant',
          cjk: '復帰',
          icon: KkIcons.power,
          danger: true,
          enabled: !idle,
        ),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'ack':
            acknowledgeAlarms(context);
          case 'procedure':
            goTo(context, Destination.procedure);
          case 'drill':
            startDrill(context);
          case 'reset':
            resetPlant(context);
        }
      },
      // An alarm nobody has answered yet: the bell strobes, alert fill and
      // deep fill in turn, until it is acknowledged.
      builder: (BuildContext context, KkMenuController controller) => KkStrobe(
        enabled: alarms > 0,
        builder: (BuildContext context, bool lit) {
          final KkColors c = context.kk.colors;
          final Color fill = lit ? c.alert : c.alertDeep;
          final Color ink = lit ? c.onFill : c.ink;
          return KkIconButton(
            icon: anyLit ? KkIcons.bell : KkIcons.bellOff,
            size: KkIconButtonSize.lg,
            semanticLabel: 'Alarms',
            badge: alarms > 0 ? KkBadge(count: alarms) : null,
            style: alarms > 0
                ? KkPlateStyle(fill: fill, hoverFill: fill, edge: c.alert, hoverEdge: c.alert, ink: ink, hoverInk: ink)
                : null,
            onPressed: controller.toggle,
          );
        },
      ),
    );
  }
}

// ── rail ──────────────────────────────────────────────────────────────────

class ConsoleRail extends StatelessWidget {
  const ConsoleRail({super.key, required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final int alarms = station.soundingAlarms;
        return KkNavRail(
          index: destination.index,
          onChanged: (int i) => goTo(context, Destination.values[i]),
          header: KkBox(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            fill: c.signal,
            child: KkText.cjk('警', size: 20, color: c.onFill),
          ),
          trailing: KkTooltip(
            message: 'KEYS · ?',
            side: KkPopupSide.right,
            child: KkIconButton(icon: KkIcons.help, semanticLabel: 'Keyboard', onPressed: () => showKeys(context)),
          ),
          items: <KkNavItem>[
            for (final Destination d in Destination.values)
              KkNavItem(
                icon: d.icon,
                label: d.label,
                semanticLabel: d.en,
                badge: d == Destination.procedure && alarms > 0 ? KkBadge(count: alarms) : null,
              ),
          ],
        );
      },
    );
  }
}

// ── drawer ────────────────────────────────────────────────────────────────

class ConsoleDrawer extends StatelessWidget {
  const ConsoleDrawer({super.key, required this.current});

  final Destination current;

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final int up = station.sectors.where((Sector s) => s.level == KkLevel.nominal).length;
        final int alarms = station.soundingAlarms;
        final int done = station.procedure.where((ProcedureStep s) => s.status == StepStatus.done).length;
        KkNavDrawerItem<Destination> item(Destination d, {String? meta, KkLevel? level}) =>
            KkNavDrawerItem<Destination>(value: d, icon: d.icon, cjk: d.cjk, en: d.en, meta: meta, level: level);
        return KkNavDrawer<Destination>(
          value: current,
          onChanged: (Destination d) => Navigator.of(context).pop(d),
          head: const KkLabel(cjk: '第三管制所', en: 'hq-03', cjkSize: 17, enSize: 11),
          foot: KkText('BUILD 0.1.0 · ${settings.operator}\nUPTIME ${formatUptime(station.uptime)}'),
          sections: <KkNavSection<Destination>>[
            KkNavSection<Destination>(
              cjk: '監視',
              en: 'monitor',
              code: 'NAV-01',
              items: <KkNavDrawerItem<Destination>>[
                item(Destination.situation, meta: kkFixed(station.metrics.length, digits: 2)),
                item(
                  Destination.systems,
                  meta: '${kkFixed(up, digits: 2)}/${kkFixed(station.sectors.length, digits: 2)}',
                  level: station.sectors.any((Sector s) => s.level == KkLevel.critical)
                      ? KkLevel.critical
                      : (up == station.sectors.length ? KkLevel.nominal : KkLevel.caution),
                ),
                item(Destination.diagram),
              ],
            ),
            KkNavSection<Destination>(
              cjk: '対処',
              en: 'respond',
              code: 'NAV-02',
              items: <KkNavDrawerItem<Destination>>[
                item(
                  Destination.procedure,
                  meta: '${kkFixed(done, digits: 2)}/${kkFixed(station.procedure.length, digits: 2)}',
                  level: alarms > 0 ? KkLevel.critical : null,
                ),
                item(Destination.log, meta: kkFixed(station.log.length, digits: 3)),
              ],
            ),
            KkNavSection<Destination>(
              cjk: '管理',
              en: 'manage',
              code: 'NAV-03',
              items: <KkNavDrawerItem<Destination>>[
                item(Destination.settings),
                item(Destination.catalogue, meta: '09'),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── toolbar ───────────────────────────────────────────────────────────────

class ConsoleToolbar extends StatelessWidget {
  const ConsoleToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final bool running = station.running;
        final String link = station.linkQuality.level == KkLevel.nominal ? 'LINK OK' : 'LINK DEGRADED';
        // No keyboard on a phone: the room goes to the status line.
        final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
        return KkToolbar(
          leading: <Widget>[
            KkToolbarGroup(
              children: <Widget>[
                KkTooltip(
                  message: running ? 'PAUSE · P' : 'RUN · P',
                  child: KkIconButton(
                    icon: running ? KkIcons.pause : KkIcons.play,
                    size: KkIconButtonSize.sm,
                    toggled: running,
                    semanticLabel: running ? 'Pause simulation' : 'Run simulation',
                    onPressed: () => running ? station.stop() : station.start(),
                  ),
                ),
                KkTooltip(
                  message: 'STEP 1 S',
                  child: KkIconButton(
                    icon: KkIcons.skip,
                    size: KkIconButtonSize.sm,
                    semanticLabel: 'Step one second',
                    onPressed: running ? null : station.tick,
                  ),
                ),
              ],
            ),
          ],
          hints: compact
              ? const <KkToolbarHint>[]
              : const <KkToolbarHint>[
                  KkToolbarHint(keys: '1-7', label: 'view'),
                  KkToolbarHint(keys: 'M', label: 'menu'),
                  KkToolbarHint(keys: 'D', label: 'drill'),
                  KkToolbarHint(keys: 'A', label: 'ack'),
                  KkToolbarHint(keys: '?', label: 'keys'),
                ],
          status: compact
              ? '$link · ${formatClock(station.now)}'
              : '$link · ${kkFixed(station.sectors.length, digits: 2)} SECTORS · UP ${formatUptime(station.uptime)}',
          trailing: <Widget>[_Heartbeat(running: running, level: station.linkQuality.level)],
        );
      },
    );
  }
}

/// The link lamp of the toolbar: four cells lit one after another for as
/// long as the plant runs, dark while it is paused.
class _Heartbeat extends StatelessWidget {
  const _Heartbeat({required this.running, required this.level});

  final bool running;
  final KkLevel level;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final Color lit = level == KkLevel.nominal ? c.signal : c.level(level);
    return Semantics(
      label: running ? 'Simulation running' : 'Simulation paused',
      child: KkPhaseBuilder(
        period: const Duration(milliseconds: 1200),
        phases: 4,
        enabled: running,
        builder: (BuildContext context, int phase, Widget? _) => KkRow(
          shrinkWrap: true,
          gap: 2,
          children: <Widget>[
            for (int i = 0; i < 4; i++) KkBox(width: 4, height: 10, fill: running && i == phase ? lit : c.signalDim),
          ],
        ),
      ),
    );
  }
}
