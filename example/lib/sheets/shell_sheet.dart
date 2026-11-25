import 'package:keikai/keikai.dart';
// ignore: implementation_imports
import 'package:keikai/src/controls/controls.dart';
// ignore: implementation_imports
import 'package:keikai/src/shell/shell.dart';

import 'sheet_scaffold.dart';

void _noop() {}

void _noopInt(int _) {}

DateTime _fixedClock() => DateTime.utc(2026, 11, 24, 14, 2, 31);

/// The shell of an app: command bar, navigation, toolbar, lists, carousels,
/// and the surfaces that float over a screen.
class ShellSheet extends StatelessWidget {
  const ShellSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-04',
      cjk: '航法',
      en: 'shell',
      note: '화면 골격과 겹침면. 상단 지휘 띠, 좌측 항법, 하단 도구 띠, 그리고 화면 위에 뜨는 대화·측판·통지.',
      sections: <Widget>[
        SheetSection(code: 'S-01', cjk: '指令', en: 'command bar', child: _CommandBars()),
        SheetSection(code: 'S-02', cjk: '分頁', en: 'tabs · primary / secondary', child: _Tabs()),
        SheetSection(code: 'S-03', cjk: '航路', en: 'nav rail · nav drawer', child: _Navigation()),
        SheetSection(code: 'S-04', cjk: '下端', en: 'toolbar · breadcrumbs', child: _Bars()),
        SheetSection(code: 'S-05', cjk: '対話', en: 'dialog', child: _Dialogs()),
        SheetSection(code: 'S-06', cjk: '側板', en: 'sheet · side / bottom', child: _Sheets()),
        SheetSection(code: 'S-07', cjk: '通知', en: 'snackbar', child: _Snackbars()),
        SheetSection(code: 'S-08', cjk: '一覧', en: 'list · regular / dense', child: _Lists()),
        SheetSection(code: 'S-09', cjk: '回転', en: 'carousel', child: _Carousels()),
      ],
    );
  }
}

// ── command bar ───────────────────────────────────────────────────────────

class _CommandBars extends StatelessWidget {
  const _CommandBars();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final List<Widget> cells = <Widget>[
      const KkCommandCell(label: 'sector', value: 'SEC-04'),
      const KkCommandCell(label: 'coolant', value: '042.7 °C', level: KkLevel.nominal),
      const KkCommandCell(label: 'uptime', value: '076:17:42'),
      const KkCommandCell(
        label: 'utc',
        child: KkClock(clock: _fixedClock),
      ),
    ];
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        SheetItem(
          caption: 'standby · leading and trailing slots',
          width: 1376,
          child: KkCommandBar(
            name: 'keikai',
            node: 'HQ-03 · NODE 07',
            conditionCjk: '平時',
            conditionEn: 'standby',
            leading: const KkIconButton(icon: KkIcons.menu, semanticLabel: 'Menu', onPressed: _noop),
            trailing: const KkIconButton(
              icon: KkIcons.bell,
              semanticLabel: 'Alarms',
              badge: KkBadge(count: 2),
              onPressed: _noop,
            ),
            cells: cells,
          ),
        ),
        SheetItem(
          caption: 'level critical · alert fill, running hazard',
          width: 1376,
          child: KkCommandBar(
            name: 'keikai',
            node: 'HQ-03 · NODE 07',
            conditionCjk: '警報',
            conditionEn: 'alert',
            level: KkLevel.critical,
            cells: <Widget>[
              const KkCommandCell(label: 'sector', value: 'SEC-04'),
              const KkCommandCell(label: 'coolant', value: '094.1 °C', level: KkLevel.critical),
              const KkCommandCell(label: 'alarms', value: '02'),
              cells.last,
            ],
          ),
        ),
        KkRow(
          gap: 32,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: '560px · caption and all cells but the last are hidden',
              width: 560,
              child: KkCommandBar(
                name: 'keikai',
                node: 'HQ-03',
                conditionCjk: '平時',
                conditionEn: 'standby',
                cells: cells,
              ),
            ),
            SheetItem(
              caption: 'KkCommandCell',
              child: KkBox(
                height: 44,
                fill: c.bg100,
                child: const KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.stretch,
                  children: <Widget>[
                    KkCommandCell(label: 'link', value: '-061 dBm', level: KkLevel.nominal),
                    KkCommandCell(label: 'load', value: '078 %', level: KkLevel.caution),
                    KkCommandCell(label: 'operator', value: 'OP-07'),
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

// ── tabs ──────────────────────────────────────────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 24,
      shrinkWrap: true,
      children: <Widget>[
        const SheetItem(
          caption: 'primary · 40px · second tab selected, last disabled',
          width: 1376,
          child: KkTabs(
            index: 1,
            onChanged: _noopInt,
            tabs: <KkTab>[
              KkTab(code: '01', cjk: '状況', en: 'situation'),
              KkTab(code: '02', cjk: '系統', en: 'systems'),
              KkTab(code: '03', cjk: '線図', en: 'diagram'),
              KkTab(code: '04', cjk: '手順', en: 'procedure'),
              KkTab(code: '05', cjk: '記録', en: 'log'),
              KkTab(code: '06', cjk: '封鎖', en: 'lockdown', enabled: false),
            ],
          ),
        ),
        KkRow(
          gap: 32,
          cross: KkCrossAlign.start,
          children: <Widget>[
            const SheetItem(
              caption: 'secondary · 32px · inside a panel',
              width: 520,
              child: KkTabs(
                variant: KkTabsVariant.secondary,
                index: 0,
                onChanged: _noopInt,
                tabs: <KkTab>[
                  KkTab(cjk: '概要', en: 'overview'),
                  KkTab(cjk: '履歴', en: 'history'),
                  KkTab(cjk: '設定', en: 'settings'),
                  KkTab(icon: KkIcons.pulse, en: 'traces'),
                ],
              ),
            ),
            const SheetItem(
              caption: 'hover',
              child: KkStateOverride(
                hovered: true,
                child: KkTabs(
                  index: 1,
                  onChanged: _noopInt,
                  tabs: <KkTab>[KkTab(cjk: '通信', en: 'comms')],
                ),
              ),
            ),
            const SheetItem(
              caption: 'keyboard focus',
              child: KkStateOverride(
                focused: true,
                child: KkTabs(
                  index: 0,
                  onChanged: _noopInt,
                  tabs: <KkTab>[KkTab(cjk: '通信', en: 'comms')],
                ),
              ),
            ),
            SheetItem(
              caption: 'KkTabView · body of the selected tab',
              width: 360,
              child: KkBox(
                fill: c.bg100,
                edges: KkEdges.line(c.line),
                child: KkColumn(
                  shrinkWrap: true,
                  children: <Widget>[
                    const KkTabs(
                      variant: KkTabsVariant.secondary,
                      index: 1,
                      onChanged: _noopInt,
                      tabs: <KkTab>[
                        KkTab(en: 'bus a'),
                        KkTab(en: 'bus b'),
                      ],
                    ),
                    KkTabView(
                      index: 1,
                      children: <Widget>[
                        const KkBox(),
                        KkBox(
                          padding: const EdgeInsets.all(12),
                          child: KkText.num('BUS B · 440.2 V · 058 %', size: 12, height: 1.5, color: c.ink),
                        ),
                      ],
                    ),
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

// ── rail and drawer ───────────────────────────────────────────────────────

const List<KkNavItem> _railItems = <KkNavItem>[
  KkNavItem(icon: KkIcons.grid, label: 'board'),
  KkNavItem(icon: KkIcons.server, label: 'systems', badge: KkBadge(count: 3)),
  KkNavItem(icon: KkIcons.node, label: 'diagram'),
  KkNavItem(icon: KkIcons.bell, label: 'alarms', badge: KkBadge.dot()),
  KkNavItem(icon: KkIcons.lock, label: 'secure', enabled: false),
];

class _Navigation extends StatelessWidget {
  const _Navigation();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final Widget header = KkBox(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      fill: c.signal,
      child: KkText.cjk('警', size: 20, color: c.onFill),
    );
    return KkRow(
      gap: 32,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'rail · 72px',
          child: KkBox(
            height: 464,
            child: KkNavRail(
              index: 1,
              onChanged: _noopInt,
              header: header,
              trailing: const KkIconButton(icon: KkIcons.settings, semanticLabel: 'Settings', onPressed: _noop),
              items: _railItems,
            ),
          ),
        ),
        const SheetItem(
          caption: 'hover · focus',
          child: KkBox(
            height: 464,
            child: KkColumn(
              shrinkWrap: true,
              gap: 16,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkStateOverride(
                  hovered: true,
                  child: KkNavRail(
                    onChanged: _noopInt,
                    items: <KkNavItem>[KkNavItem(icon: KkIcons.radar, label: 'radar')],
                  ),
                ),
                KkStateOverride(
                  focused: true,
                  child: KkNavRail(
                    onChanged: _noopInt,
                    items: <KkNavItem>[KkNavItem(icon: KkIcons.radar, label: 'radar')],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SheetItem(
          caption: 'drawer · 256px · sections, meta, levels, foot',
          child: KkBox(
            height: 464,
            child: KkNavDrawer<int>(
              value: 4,
              onChanged: _noopInt,
              head: KkLabel(cjk: '第三管制所', en: 'hq-03', cjkSize: 17, enSize: 11),
              foot: KkText('BUILD 0.1.0 · OP-07\nUPTIME 076:17:42'),
              sections: <KkNavSection<int>>[
                KkNavSection<int>(
                  cjk: '監視',
                  en: 'monitor',
                  code: 'NAV-01',
                  items: <KkNavDrawerItem<int>>[
                    KkNavDrawerItem<int>(value: 0, icon: KkIcons.grid, cjk: '状況', en: 'situation', meta: '12'),
                    KkNavDrawerItem<int>(
                      value: 1,
                      icon: KkIcons.server,
                      cjk: '系統',
                      en: 'systems',
                      meta: '11/12',
                      level: KkLevel.nominal,
                    ),
                    KkNavDrawerItem<int>(value: 2, icon: KkIcons.pulse, cjk: '波形', en: 'traces', meta: '06'),
                  ],
                ),
                KkNavSection<int>(
                  cjk: '対処',
                  en: 'respond',
                  code: 'NAV-02',
                  items: <KkNavDrawerItem<int>>[
                    KkNavDrawerItem<int>(
                      value: 3,
                      icon: KkIcons.bell,
                      cjk: '警報',
                      en: 'alarms',
                      meta: '02',
                      level: KkLevel.critical,
                    ),
                    KkNavDrawerItem<int>(
                      value: 4,
                      icon: KkIcons.list,
                      cjk: '手順',
                      en: 'procedure',
                      meta: '03/06',
                      level: KkLevel.caution,
                    ),
                    KkNavDrawerItem<int>(
                      value: 5,
                      icon: KkIcons.radio,
                      cjk: '通信',
                      en: 'comms',
                      meta: 'CH.12',
                      level: KkLevel.offline,
                    ),
                    KkNavDrawerItem<int>(value: 6, icon: KkIcons.lock, cjk: '封鎖', en: 'lockdown', enabled: false),
                  ],
                ),
              ],
            ),
          ),
        ),
        const KkExpanded(
          child: KkColumn(
            gap: 24,
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              SheetItem(
                caption: 'rail as a bottom bar · below 600px',
                width: 390,
                child: KkNavRail(bar: true, index: 3, onChanged: _noopInt, items: _railItems),
              ),
              SheetItem(
                caption: 'rail · every destination disabled (no onChanged)',
                width: 390,
                child: KkNavRail(bar: true, index: 0, items: _railItems),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── toolbar and breadcrumbs ───────────────────────────────────────────────

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) {
    return const KkColumn(
      gap: 24,
      shrinkWrap: true,
      children: <Widget>[
        SheetItem(
          caption: 'toolbar · 32px · groups, hints, status',
          width: 1376,
          child: KkToolbar(
            leading: <Widget>[
              KkToolbarGroup(
                children: <Widget>[
                  KkIconButton(icon: KkIcons.play, size: KkIconButtonSize.sm, semanticLabel: 'Run', onPressed: _noop),
                  KkIconButton(
                    icon: KkIcons.pause,
                    size: KkIconButtonSize.sm,
                    semanticLabel: 'Hold',
                    onPressed: _noop,
                  ),
                  KkIconButton(
                    icon: KkIcons.refresh,
                    size: KkIconButtonSize.sm,
                    semanticLabel: 'Refresh',
                    onPressed: _noop,
                  ),
                ],
              ),
            ],
            hints: <KkToolbarHint>[
              KkToolbarHint(keys: 'F1', label: 'help'),
              KkToolbarHint(keys: 'F5', label: 'refresh'),
              KkToolbarHint(keys: 'CTRL+K', label: 'search'),
              KkToolbarHint(keys: 'ESC', label: 'close'),
            ],
            status: 'LINK OK · 12 SECTORS · 14:02:31Z',
          ),
        ),
        KkRow(
          gap: 48,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: 'breadcrumbs · the last crumb is the current page',
              child: KkBreadcrumbs(
                items: <KkCrumb>[
                  KkCrumb(code: 'HQ-03', en: 'board', onPressed: _noop),
                  KkCrumb(cjk: '系統', en: 'systems', onPressed: _noop),
                  KkCrumb(code: 'SEC-04', cjk: '冷却', en: 'coolant'),
                ],
              ),
            ),
            SheetItem(
              caption: 'hover',
              child: KkStateOverride(
                hovered: true,
                child: KkBreadcrumbs(
                  items: <KkCrumb>[
                    KkCrumb(cjk: '系統', en: 'systems', onPressed: _noop),
                    KkCrumb(en: 'pumps'),
                  ],
                ),
              ),
            ),
            SheetItem(
              caption: 'keyboard focus',
              child: KkStateOverride(
                focused: true,
                child: KkBreadcrumbs(
                  items: <KkCrumb>[
                    KkCrumb(cjk: '系統', en: 'systems', onPressed: _noop),
                    KkCrumb(en: 'pumps'),
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

// ── dialog ────────────────────────────────────────────────────────────────

class _Dialogs extends StatelessWidget {
  const _Dialogs();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    Widget stage(Widget dialog) => KkExpanded(
      child: KkBox(
        fill: c.scrim,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        alignment: Alignment.topCenter,
        child: dialog,
      ),
    );
    return KkRow(
      gap: 32,
      cross: KkCrossAlign.stretch,
      children: <Widget>[
        stage(
          const KkDialog(
            code: 'DLG-07',
            cjk: '手順確認',
            en: 'confirm procedure',
            onClose: _noop,
            actions: <Widget>[
              KkButton(label: 'cancel', variant: KkButtonVariant.ghost, onPressed: _noop),
              KkButton(label: 'execute', cjk: '実行', variant: KkButtonVariant.primary, onPressed: _noop),
            ],
            child: KkText.body('보조 펌프 B를 기동하고 밸브 V-17을 닫습니다. 실행 후 60초 동안 냉각수 압력을 감시합니다.'),
          ),
        ),
        stage(
          const KkDialog(
            code: 'E-4127',
            cjk: '緊急停止',
            en: 'emergency stop',
            level: KkLevel.critical,
            hazard: true,
            onClose: _noop,
            actions: <Widget>[
              KkButton(label: 'cancel', variant: KkButtonVariant.ghost, onPressed: _noop),
              KkButton(label: 'stop', cjk: '停止', variant: KkButtonVariant.danger, onPressed: _noop),
            ],
            child: KkText.body('주 펌프 A를 즉시 정지합니다. 정지 후에는 수동 재기동 절차가 필요합니다.'),
          ),
        ),
      ],
    );
  }
}

// ── sheet ─────────────────────────────────────────────────────────────────

class _Sheets extends StatelessWidget {
  const _Sheets();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkRow(
      gap: 32,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'side sheet · 400px · right',
          child: KkBox(
            height: 380,
            child: KkSheet(
              side: KkSheetSide.right,
              code: 'SEC-04',
              cjk: '冷却',
              en: 'coolant detail',
              onClose: _noop,
              actions: const <Widget>[
                KkButton(label: 'close', variant: KkButtonVariant.ghost, onPressed: _noop),
                KkButton(label: 'acknowledge', variant: KkButtonVariant.primary, onPressed: _noop),
              ],
              child: KkColumn(
                shrinkWrap: true,
                gap: 12,
                children: <Widget>[
                  const KkText.body('냉각수 압력이 기준치 아래로 떨어졌습니다. 보조 펌프를 기동하십시오.'),
                  KkBox(
                    edges: KkEdges.line(c.line),
                    child: const KkList(
                      dense: true,
                      children: <Widget>[
                        KkListRow(level: KkLevel.critical, cjk: '水圧', en: 'pressure', meta: '096 kPa'),
                        KkListRow(level: KkLevel.caution, cjk: '水温', en: 'temp', meta: '076.4 °C'),
                        KkListRow(level: KkLevel.nominal, cjk: '流量', en: 'flow', meta: '204 L/MIN'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SheetItem(
          caption: 'side sheet · left',
          child: KkBox(
            height: 380,
            width: 320,
            child: KkSheet(
              side: KkSheetSide.left,
              cjk: '絞込',
              en: 'filter',
              onClose: _noop,
              child: KkText.body('수준과 구역으로 목록을 좁힙니다.', size: 12, height: 1.5),
            ),
          ),
        ),
        const KkExpanded(
          child: SheetItem(
            caption: 'bottom sheet · grip of dashes',
            width: 560,
            child: KkSheet(
              side: KkSheetSide.bottom,
              code: 'LOG',
              cjk: '記録',
              en: 'event log',
              onClose: _noop,
              actions: <Widget>[KkButton(label: 'export', icon: KkIcons.download, onPressed: _noop)],
              child: KkList(
                dense: true,
                children: <Widget>[
                  KkListRow(cjk: '警報確認', en: 'alarm acknowledged', meta: '14:02:31Z'),
                  KkListRow(cjk: '補助起動', en: 'aux pump start', meta: '14:02:44Z'),
                  KkListRow(cjk: '弁閉鎖', en: 'valve closed', meta: '14:03:02Z'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── snackbar ──────────────────────────────────────────────────────────────

class _Snackbars extends StatelessWidget {
  const _Snackbars();

  @override
  Widget build(BuildContext context) {
    return const KkRow(
      gap: 32,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkColumn(
          shrinkWrap: true,
          gap: 8,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSnackbar(code: 'SYS', message: 'ROUTE TABLE UPDATED · N-07', onClose: _noop),
            KkSnackbar(
              code: 'SEC-01',
              level: KkLevel.nominal,
              message: 'BUS VOLTAGE WITHIN LIMITS · 440.2 V',
              onClose: _noop,
            ),
            KkSnackbar(
              code: 'SEC-08',
              level: KkLevel.caution,
              message: 'LINK CH.12 RESYNC',
              action: KkButton(
                label: 'retry',
                variant: KkButtonVariant.ghost,
                size: KkButtonSize.sm,
                onPressed: _noop,
              ),
              onClose: _noop,
            ),
            KkSnackbar(
              code: 'E-4127',
              level: KkLevel.critical,
              message: 'COOLANT PRESSURE LOW · SEC-04 · 14:02:31Z',
              onClose: _noop,
            ),
            KkSnackbar(code: 'SEC-12', level: KkLevel.offline, message: 'SPARE UNIT NOT RESPONDING', onClose: _noop),
          ],
        ),
        KkColumn(
          shrinkWrap: true,
          gap: 8,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSnackbar(level: KkLevel.caution, message: 'NO CODE · THE BLOCK READS THE LEVEL WORD'),
            KkSnackbar(message: 'NO CODE, NO LEVEL · MESSAGE ONLY'),
            KkSnackbar(
              code: 'OP-07',
              message:
                  'A LONG MESSAGE WRAPS INSIDE THE 560PX LIMIT · AUX PUMP B START CONFIRMED · VALVE V-17 CLOSED · '
                  'PRESSURE RECOVERING TO 240 KPA',
              onClose: _noop,
            ),
          ],
        ),
      ],
    );
  }
}

// ── list ──────────────────────────────────────────────────────────────────

class _Lists extends StatelessWidget {
  const _Lists();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    Widget framed(Widget child) => KkBox(edges: KkEdges.line(c.line), child: child);
    return KkRow(
      gap: 32,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          flex: 3,
          child: SheetItem(
            caption: 'regular · 48px minimum · current row, disabled row',
            width: 760,
            child: framed(
              const KkList(
                children: <Widget>[
                  KkListRow(
                    level: KkLevel.nominal,
                    cjk: '電源',
                    en: 'power',
                    sub: '모선 전압 정상 범위. 마지막 점검 09:00Z.',
                    meta: 'SEC-01',
                    trailing: KkStatusTag.status(KkLevel.nominal),
                    onPressed: _noop,
                  ),
                  KkListRow(
                    level: KkLevel.caution,
                    cjk: '中継',
                    en: 'relay',
                    sub: 'CH.12 재동기 중. 손실률 4.1%.',
                    meta: 'SEC-08',
                    trailing: KkStatusTag.status(KkLevel.caution),
                    current: true,
                    onPressed: _noop,
                  ),
                  KkListRow(
                    level: KkLevel.critical,
                    cjk: '冷却',
                    en: 'coolant',
                    sub: '냉각수 압력 저하. 보조 펌프 기동 대기.',
                    meta: 'SEC-04',
                    trailing: KkStatusTag.status(KkLevel.critical, variant: KkStatusTagVariant.solid),
                    onPressed: _noop,
                  ),
                  KkListRow(
                    icon: KkIcons.lock,
                    cjk: '封鎖',
                    en: 'lockdown',
                    sub: '권한 없음.',
                    meta: 'SEC-00',
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        KkExpanded(
          flex: 2,
          child: KkColumn(
            shrinkWrap: true,
            gap: 24,
            children: <Widget>[
              SheetItem(
                caption: 'dense · 32px · no second line',
                width: 500,
                child: framed(
                  const KkList(
                    dense: true,
                    children: <Widget>[
                      KkListRow(level: KkLevel.nominal, cjk: '給水', en: 'feed water', meta: '118 L/MIN'),
                      KkListRow(level: KkLevel.nominal, cjk: '換気', en: 'ventilation', meta: '062 %'),
                      KkListRow(
                        level: KkLevel.offline,
                        cjk: '予備',
                        en: 'spare',
                        meta: 'STANDBY',
                        trailing: KkIcon(KkIcons.chevronRight),
                        onPressed: _noop,
                      ),
                    ],
                  ),
                ),
              ),
              SheetItem(
                caption: 'hover · keyboard focus',
                width: 500,
                child: framed(
                  const KkList(
                    dense: true,
                    children: <Widget>[
                      KkStateOverride(
                        hovered: true,
                        child: KkListRow(icon: KkIcons.file, cjk: '記録', en: 'log', meta: '0412', onPressed: _noop),
                      ),
                      KkStateOverride(
                        focused: true,
                        child: KkListRow(icon: KkIcons.file, cjk: '記録', en: 'log', meta: '0412', onPressed: _noop),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── carousel ──────────────────────────────────────────────────────────────

class _Carousels extends StatelessWidget {
  const _Carousels();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    const List<(String, String, KkLevel?)> feeds = <(String, String, KkLevel?)>[
      ('CAM-01 · SEC-01', '電源', KkLevel.nominal),
      ('CAM-02 · SEC-02', '配電', KkLevel.nominal),
      ('CAM-03 · SEC-04', '冷却', KkLevel.critical),
      ('CAM-04 · SEC-05', '給水', KkLevel.nominal),
      ('CAM-05 · SEC-07', '通信', KkLevel.nominal),
      ('CAM-06 · SEC-08', '中継', KkLevel.caution),
      ('CAM-07 · SEC-09', '制御', KkLevel.nominal),
      ('CAM-08 · SEC-12', '予備', KkLevel.offline),
    ];
    return KkCarousel(
      cjk: '監視映像',
      en: 'camera feeds',
      initialIndex: 2,
      items: <KkCarouselItem>[
        for (final (String caption, String cjk, KkLevel? level) in feeds)
          KkCarouselItem(
            caption: caption,
            child: KkBackdrop(
              kind: level == KkLevel.critical ? KkBackdropKind.hex : KkBackdropKind.plot,
              level: level,
              scanlines: true,
              alignment: Alignment.center,
              child: KkColumn(
                shrinkWrap: true,
                gap: 8,
                cross: KkCrossAlign.center,
                children: <Widget>[
                  KkText.cjk(cjk, size: 32, color: level == KkLevel.offline ? c.inkFaint : c.inkDim),
                  KkStatusTag.status(level),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
