import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

/// Catalogue sheet F-05: the HUD instruments.
class HudSheet extends StatelessWidget {
  const HudSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-05',
      cjk: '計測',
      en: 'instruments',
      note: '상태는 색 + 단어 + 상태 아이콘 세 가지로 말한다. 패널은 선과 명도로 나누고, 경보일 때만 움직인다.',
      sections: <Widget>[
        SheetSection(code: 'H-01', cjk: '構造', en: 'panel', child: _Panels()),
        SheetSection(code: 'H-02', cjk: '警報', en: 'alert bar', child: _AlertBars()),
        SheetSection(code: 'H-03', cjk: '計測', en: 'readout', child: _Readouts()),
        SheetSection(code: 'H-04', cjk: '計器', en: 'meter', child: _Meters()),
        SheetSection(code: 'H-05', cjk: '計時', en: 'timer', child: _Timers()),
        SheetSection(code: 'H-06', cjk: '蜂巣', en: 'hex matrix', child: _Hexes()),
        SheetSection(code: 'H-07', cjk: '記録', en: 'data log', child: _Logs()),
        SheetSection(code: 'H-08', cjk: '手順', en: 'sequence · annunciator', child: _Procedures()),
        SheetSection(code: 'H-09', cjk: '合議', en: 'consensus', child: _Polls()),
        SheetSection(code: 'H-10', cjk: '運転', en: 'mode strip', child: _Modes()),
        SheetSection(code: 'H-11', cjk: '表題', en: 'heading', child: _Headings()),
        SheetSection(code: 'H-12', cjk: '緊急', en: 'emergency', child: _Alarm()),
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines(this.lines);

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 6,
      shrinkWrap: true,
      children: <Widget>[
        for (final (String, String) line in lines)
          KkRow(
            gap: 12,
            children: <Widget>[
              KkExpanded(child: KkText.en(line.$1, size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim)),
              KkText.num(line.$2, size: 12, weight: FontWeight.w500, color: c.ink),
            ],
          ),
      ],
    );
  }
}

class _Panels extends StatelessWidget {
  const _Panels();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 8,
      shrinkWrap: true,
      children: <Widget>[
        const KkRow(
          gap: 8,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'SEC-01',
                  cjk: '電源系統',
                  en: 'power',
                  meta: '14:02:31Z',
                  trailing: <Widget>[KkIcon(KkIcons.bolt)],
                  child: _Lines(<(String, String)>[
                    ('main bus', '440.2 V'),
                    ('aux bus', '027.9 V'),
                    ('load', '078 %'),
                    ('frequency', '060.0 Hz'),
                  ]),
                ),
              ),
            ),
            KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'SEC-02',
                  cjk: '通信回線',
                  en: 'comms',
                  meta: 'CH.12',
                  trailing: <Widget>[KkIcon(KkIcons.signal)],
                  variant: KkPanelVariant.quiet,
                  child: _Lines(<(String, String)>[
                    ('uplink', '-062 dBm'),
                    ('downlink', '-071 dBm'),
                    ('packet loss', '000.2 %'),
                    ('latency', '042 ms'),
                  ]),
                ),
              ),
            ),
            KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'SEC-03',
                  cjk: '冷却',
                  en: 'cooling',
                  meta: 'SELECTED',
                  variant: KkPanelVariant.active,
                  child: _Lines(<(String, String)>[
                    ('inlet temp', '042.7 °C'),
                    ('outlet temp', '051.3 °C'),
                    ('flow', '118.0 L/min'),
                    ('pump', '2 / 2'),
                  ]),
                ),
              ),
            ),
            KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'SEC-05',
                  cjk: '接続状態',
                  en: 'link',
                  meta: 'N-01 — N-12',
                  spine: '第三管区',
                  child: _Lines(<(String, String)>[
                    ('nodes online', '11 / 12'),
                    ('handshake', 'ACK'),
                    ('last sync', '14:02:28Z'),
                    ('route', 'N-03 → N-07'),
                  ]),
                ),
              ),
            ),
          ],
        ),
        KkRow(
          gap: 8,
          cross: KkCrossAlign.start,
          children: <Widget>[
            const KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'SEC-04',
                  cjk: '冷却水圧',
                  en: 'pressure',
                  meta: 'E-4127',
                  level: KkLevel.critical,
                  child: _Lines(<(String, String)>[
                    ('pressure', '071.2 kPa'),
                    ('limit low', '090.0 kPa'),
                    ('since', '14:02:31Z'),
                    ('aux pump', 'STANDBY'),
                  ]),
                ),
              ),
            ),
            const KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  code: 'N-07',
                  cjk: '中継局',
                  en: 'relay',
                  meta: 'NO CARRIER',
                  level: KkLevel.offline,
                  child: KkColumn(
                    gap: 12,
                    shrinkWrap: true,
                    children: <Widget>[
                      KkMeter(cjk: '信号', en: 'signal', value: 0.34, unit: '%', minWidth: 0),
                      _Lines(<(String, String)>[('last contact', '13:48:02Z')]),
                    ],
                  ),
                ),
              ),
            ),
            KkExpanded(
              child: KkColumn(
                gap: 8,
                shrinkWrap: true,
                children: <Widget>[
                  KkPanel(
                    code: 'SEC-06',
                    cjk: '補助電源',
                    en: 'auxiliary',
                    meta: 'OPEN',
                    collapsible: true,
                    child: KkText.body(
                      '보조 펌프 2기 대기. 수동 기동 가능.',
                      size: 12,
                      height: 1.5,
                      color: c.inkDim,
                    ),
                  ),
                  const KkPanel(
                    code: 'SEC-07',
                    cjk: '排気',
                    en: 'exhaust',
                    meta: 'FOLDED',
                    variant: KkPanelVariant.quiet,
                    collapsible: true,
                    initiallyCollapsed: true,
                    child: _Lines(<(String, String)>[('fan', '2 / 2')]),
                  ),
                ],
              ),
            ),
            const KkExpanded(
              child: KkBox(
                height: 168,
                child: KkPanel(
                  cjk: '監視',
                  en: 'watch',
                  variant: KkPanelVariant.quiet,
                  flush: true,
                  child: KkBackdrop(
                    kind: KkBackdropKind.plot,
                    alignment: Alignment.center,
                    child: KkStateWord(level: KkLevel.nominal, size: 13, glyphSize: 14, gap: 6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AlertBars extends StatelessWidget {
  const _AlertBars();

  @override
  Widget build(BuildContext context) {
    return const KkColumn(
      gap: 8,
      shrinkWrap: true,
      children: <Widget>[
        KkAlertBar(
          cjk: '通知',
          title: 'advisory — auxiliary power online',
          sub: '補助電源 投入 · SEC-06 · 14:01:07Z',
          code: 'A-0031',
        ),
        KkAlertBar(
          level: KkLevel.caution,
          cjk: '注意',
          title: 'caution — coolant temp rising',
          sub: '冷却水温 上昇 · SEC-03 · 14:02:02Z',
          code: 'W-2204',
        ),
        KkAlertBar(
          level: KkLevel.critical,
          cjk: '警報',
          title: 'critical — coolant pressure low',
          sub: '冷却水圧 低下 · SEC-04 · 14:02:31Z',
          code: 'E-4127',
        ),
      ],
    );
  }
}

class _Readouts extends StatelessWidget {
  const _Readouts();

  @override
  Widget build(BuildContext context) {
    return const KkWrap(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkBox(
          width: 268,
          child: KkReadout(
            cjk: '冷却水温',
            en: 'coolant temp',
            value: '042.7',
            unit: '°C',
            level: KkLevel.nominal,
            position: 0.42,
            footStart: 'MIN 030.0',
            footEnd: 'MAX 060.0',
          ),
        ),
        KkBox(
          width: 268,
          child: KkReadout(
            cjk: '水圧',
            en: 'pressure',
            value: '094.1',
            unit: 'kPa',
            level: KkLevel.caution,
            position: 0.78,
            footStart: 'MIN 090.0',
            footEnd: 'MAX 140.0',
          ),
        ),
        KkBox(
          width: 268,
          child: KkReadout(
            cjk: '炉心温度',
            en: 'core temp',
            value: '098.4',
            unit: '°C',
            level: KkLevel.critical,
            position: 0.96,
            footStart: 'MIN 040.0',
            footEnd: 'MAX 095.0',
          ),
        ),
        KkBox(
          width: 268,
          child: KkReadout(
            cjk: '信号強度',
            en: 'signal',
            value: '---.-',
            unit: 'dBm',
            level: KkLevel.offline,
            position: 0,
            footStart: 'LAST 13:48:02Z',
            footEnd: 'N-07',
          ),
        ),
        KkReadout(cjk: '回転数', en: 'rotor', value: '1250', unit: 'rpm'),
      ],
    );
  }
}

class _Meters extends StatelessWidget {
  const _Meters();

  @override
  Widget build(BuildContext context) {
    const List<String> ticks = <String>['0', '25', '50', '75', '100'];
    return const KkWrap(
      gap: 32,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkBox(
          width: 320,
          child: KkMeter(cjk: '出力', en: 'output', value: 0.42, unit: '%', ticks: ticks),
        ),
        KkBox(
          width: 320,
          child: KkMeter(cjk: '負荷', en: 'load', value: 0.78, unit: '%', ticks: ticks),
        ),
        KkBox(
          width: 320,
          child: KkMeter(cjk: '温度', en: 'temp', value: 0.94, unit: '%', ticks: ticks),
        ),
        KkBox(
          width: 280,
          child: KkMeter(
            cjk: '燃料',
            en: 'fuel',
            value: 0.61,
            valueText: '1220',
            unit: 'L',
            level: KkLevel.nominal,
            showMarks: false,
          ),
        ),
      ],
    );
  }
}

class _Timers extends StatelessWidget {
  const _Timers();

  @override
  Widget build(BuildContext context) {
    return const KkWrap(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkTimer(
          cjk: '残り時間',
          en: 't-minus',
          mode: 'COUNTDOWN',
          value: Duration(minutes: 4, seconds: 59, milliseconds: 820),
          progress: 0.62,
        ),
        KkTimer(
          cjk: '点検窓',
          en: 'window',
          mode: 'HOLD',
          level: KkLevel.caution,
          value: Duration(minutes: 1, seconds: 12, milliseconds: 400),
          progress: 0.24,
        ),
        KkTimer(
          cjk: '自動停止',
          en: 'auto scram',
          mode: 'ARMED',
          level: KkLevel.critical,
          value: Duration(seconds: 9, milliseconds: 310),
          progress: 0.04,
        ),
        KkTimer(
          cjk: '経過',
          en: 'elapsed',
          mode: 'UTC',
          level: KkLevel.nominal,
          value: Duration(hours: 1, minutes: 2, seconds: 3),
        ),
      ],
    );
  }
}

class _Hexes extends StatelessWidget {
  const _Hexes();

  @override
  Widget build(BuildContext context) {
    return const KkHexMatrix(
      columns: 12,
      cells: <KkHexCell>[
        KkHexCell(id: 'N-01', value: '98%', level: KkLevel.nominal),
        KkHexCell(id: 'N-02', value: '97%', level: KkLevel.nominal),
        KkHexCell(id: 'N-03', value: '71%', level: KkLevel.caution),
        KkHexCell(id: 'N-04', value: '99%', level: KkLevel.nominal),
        KkHexCell(id: 'N-05', value: '12%', level: KkLevel.critical),
        KkHexCell(id: 'N-06', value: '96%', level: KkLevel.nominal),
        KkHexCell(id: 'N-07', value: '---', level: KkLevel.offline),
        KkHexCell(id: 'N-08', value: '95%', level: KkLevel.nominal),
        KkHexCell(id: 'N-09', value: '64%'),
        KkHexCell(id: 'N-10', value: '93%', level: KkLevel.nominal),
        KkHexCell.empty(),
        KkHexCell(id: 'N-12', value: '99%', level: KkLevel.nominal),
        KkHexCell(id: 'N-13', value: '98%', level: KkLevel.nominal),
        KkHexCell(id: 'N-14', value: '68%', level: KkLevel.caution),
        KkHexCell(id: 'N-15', value: '97%', level: KkLevel.nominal),
        KkHexCell(id: 'N-16', value: '99%', level: KkLevel.nominal),
        KkHexCell.empty(),
        KkHexCell(id: 'N-18', value: '94%', level: KkLevel.nominal),
        KkHexCell(id: 'N-19', value: '---', level: KkLevel.offline),
        KkHexCell(id: 'N-20', value: '96%', level: KkLevel.nominal),
        KkHexCell(id: 'N-21', value: '09%', level: KkLevel.critical),
        KkHexCell(id: 'N-22', value: '98%', level: KkLevel.nominal),
        KkHexCell(id: 'N-23', value: '51%'),
      ],
    );
  }
}

class _Logs extends StatelessWidget {
  const _Logs();

  @override
  Widget build(BuildContext context) {
    return const KkDataLog(
      entries: <KkLogEntry>[
        KkLogEntry(time: '14:01:07.412Z', source: 'SEC-06', level: KkLevel.nominal, message: 'AUX POWER ONLINE  0x1A'),
        KkLogEntry(time: '14:01:44.090Z', source: 'N-07', level: KkLevel.offline, message: 'CARRIER LOST  RETRY 03 / 05'),
        KkLogEntry(time: '14:02:02.118Z', source: 'SEC-03', level: KkLevel.caution, message: 'COOLANT TEMP 051.3 °C  RISING'),
        KkLogEntry(time: '14:02:28.660Z', source: 'CH.12', message: 'HANDSHAKE ACK  0x3F'),
        KkLogEntry(
          time: '14:02:31.004Z',
          source: 'SEC-04',
          level: KkLevel.critical,
          message: 'COOLANT PRESSURE LOW  071.2 kPa  LIMIT 090.0 kPa',
        ),
        KkLogEntry(time: '14:02:31.870Z', source: 'OP-07', message: 'ALARM ACKNOWLEDGED  E-4127'),
        KkLogEntry(time: '14:02:33.240Z', source: 'SEC-06', level: KkLevel.nominal, message: 'AUX PUMP 1 START  ACK'),
      ],
    );
  }
}

class _Procedures extends StatelessWidget {
  const _Procedures();

  @override
  Widget build(BuildContext context) {
    return const KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkSequence(
            cjk: '起動手順',
            en: 'start-up sequence',
            steps: <KkSequenceStep>[
              KkSequenceStep(
                cjk: '電源投入',
                en: 'power on',
                note: 'MAIN BUS 440.2 V',
                status: KkStepStatus.done,
                time: '14:00:02Z',
              ),
              KkSequenceStep(
                cjk: '自己診断',
                en: 'self test',
                note: '128 / 128 PASS',
                status: KkStepStatus.done,
                time: '14:00:41Z',
              ),
              KkSequenceStep(
                cjk: '冷却循環',
                en: 'coolant loop',
                note: 'FLOW 118.0 L/min  TARGET 120.0',
                status: KkStepStatus.active,
                time: '14:01:10Z',
              ),
              KkSequenceStep(
                cjk: '外部同期',
                en: 'external sync',
                note: 'N-07 NO CARRIER',
                status: KkStepStatus.failed,
                time: '14:01:44Z',
              ),
              KkSequenceStep(cjk: '負荷試験', en: 'load test', status: KkStepStatus.skipped),
              KkSequenceStep(cjk: '定常運転', en: 'steady run', note: 'WAITING FOR STEP 03'),
            ],
          ),
        ),
        KkExpanded(
          child: KkAnnunciator(
            tiles: <KkAlarmTile>[
              KkAlarmTile(code: 'A-01', cjk: '電源', en: 'power'),
              KkAlarmTile(code: 'A-02', cjk: '水圧', en: 'pressure', state: KkAlarmState.alarm),
              KkAlarmTile(code: 'A-03', cjk: '水温', en: 'coolant temp', state: KkAlarmState.ack, level: KkLevel.caution),
              KkAlarmTile(code: 'A-04', cjk: '通信', en: 'comms', state: KkAlarmState.rtn),
              KkAlarmTile(code: 'A-05', cjk: '排気', en: 'exhaust'),
              KkAlarmTile(code: 'A-06', cjk: '振動', en: 'vibration', state: KkAlarmState.ack),
              KkAlarmTile(code: 'A-07', cjk: '火災', en: 'fire'),
              KkAlarmTile(code: 'A-08', cjk: '試験', en: 'lamp test', state: KkAlarmState.test),
              KkAlarmTile(code: 'A-09', cjk: '漏洩', en: 'leak'),
              KkAlarmTile(code: 'A-10', cjk: '過負荷', en: 'overload', state: KkAlarmState.alarm, level: KkLevel.caution),
              KkAlarmTile(code: 'A-11', cjk: '扉', en: 'door'),
              KkAlarmTile(code: 'A-12', cjk: '侵入', en: 'intrusion'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Polls extends StatelessWidget {
  const _Polls();

  @override
  Widget build(BuildContext context) {
    return const KkRow(
      gap: 8,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          child: KkConsensus(
            cjk: '発進可否',
            en: 'launch poll',
            meta: '14:02:40Z',
            voters: <KkVoter>[
              KkVoter(id: 'CH.01', name: 'guidance', vote: KkVote.go, note: 'ALIGN 000.02°'),
              KkVoter(id: 'CH.02', name: 'propulsion', vote: KkVote.go, note: 'TANK 098 %'),
              KkVoter(id: 'CH.03', name: 'range', vote: KkVote.wait, note: 'WIND 012 m/s'),
            ],
          ),
        ),
        KkExpanded(
          child: KkConsensus(
            cjk: '再起動',
            en: 'restart poll',
            meta: '3-OF-3',
            quorum: 3,
            voters: <KkVoter>[
              KkVoter(id: 'CH.01', name: 'reactor', vote: KkVote.go, note: 'CORE 042.7 °C'),
              KkVoter(id: 'CH.02', name: 'cooling', vote: KkVote.wait, note: 'FLOW 118.0 L/min'),
              KkVoter(id: 'CH.03', name: 'grid', vote: KkVote.wait, note: 'SYNC PENDING'),
            ],
          ),
        ),
        KkExpanded(
          child: KkConsensus(
            cjk: '切替',
            en: 'failover poll',
            meta: '2-OF-3',
            voters: <KkVoter>[
              KkVoter(id: 'CH.01', name: 'primary', vote: KkVote.nogo, note: 'PRESSURE 071.2 kPa'),
              KkVoter(id: 'CH.02', name: 'backup', vote: KkVote.go, note: 'READY'),
              KkVoter(id: 'CH.03', name: 'remote', vote: KkVote.fault, note: 'N-07 NO CARRIER'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Modes extends StatelessWidget {
  const _Modes();

  @override
  Widget build(BuildContext context) {
    const List<KkModeStep> steps = <KkModeStep>[
      KkModeStep(cjk: '停止', en: 'shutdown'),
      KkModeStep(cjk: '待機', en: 'standby'),
      KkModeStep(cjk: '起動', en: 'start-up'),
      KkModeStep(cjk: '運転', en: 'run'),
      KkModeStep(cjk: '全力', en: 'full power'),
    ];
    return const KkColumn(
      gap: 12,
      shrinkWrap: true,
      children: <Widget>[
        KkModeStrip(steps: steps, current: 2, target: 3),
        KkModeStrip(steps: steps, current: 3, level: KkLevel.nominal),
        KkModeStrip(steps: steps, current: 4, target: 1, level: KkLevel.caution),
      ],
    );
  }
}

class _Headings extends StatelessWidget {
  const _Headings();

  @override
  Widget build(BuildContext context) {
    return const KkWrap(
      gap: 64,
      cross: KkCrossAlign.end,
      children: <Widget>[
        KkHeading(stem: '設計言語', code: 'KK-00', en: 'keikai for flutter', main: '警戒'),
        KkHeading(stem: '第三管区', code: 'SEC-04', en: 'coolant system', main: '冷却系統'),
        KkHeading(code: 'SEC-01', en: 'power system', main: '전원 계통', mainSize: 44, enSize: 14),
      ],
    );
  }
}

class _Alarm extends StatelessWidget {
  const _Alarm();

  @override
  Widget build(BuildContext context) {
    return const KkEmergency(
      inline: true,
      code: 'E-4127 · SEC-04 · 14:02:31Z',
      cjk: '緊急停止',
      en: 'emergency stop',
      sub: '冷却水圧 低下 — 自動停止まで 00:09',
      marquee: 'CRITICAL — COOLANT PRESSURE LOW  ///  SEC-04  ///  E-4127  ///  冷却水圧 低下',
      actions: <Widget>[_PlateAction('acknowledge'), _PlateAction('silence')],
    );
  }
}

/// A stand-in button for the emergency plate: black plate, alert ink.
class _PlateAction extends StatelessWidget {
  const _PlateAction(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = context.kk;
    return KkSurface(
      shape: KkShape.plate(theme.metrics.chamferMd),
      fill: theme.colors.bg000,
      edge: theme.colors.bg000,
      child: KkBox(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: KkText.en(label, size: 15, spacing: 0.08, color: theme.colors.alert),
      ),
    );
  }
}
