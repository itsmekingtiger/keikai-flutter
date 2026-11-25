import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

/// The diagram renderer: flow charts, trees, radial maps, networks and
/// sequence diagrams, all drawn with straight lines and 45° cuts.
class DiagramSheet extends StatelessWidget {
  const DiagramSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-08',
      cjk: '線図',
      en: 'diagrams',
      note: '직선과 45° 사선만으로 그린다. 배치 다섯 가지, 배선 세 가지, 텍스트 기술 하나.',
      sections: <Widget>[
        SheetSection(code: 'D-01', cjk: '流れ図', en: 'layered flow · left to right', child: _CoolantLoop()),
        SheetSection(code: 'D-02', cjk: '判定と系統樹', en: 'top to bottom flow with a cycle · tree', child: _FlowAndTree()),
        SheetSection(code: 'D-03', cjk: '放射と網', en: 'radial map · force network', child: _RadialAndNetwork()),
        SheetSection(code: 'D-04', cjk: '通信手順', en: 'sequence diagram', child: _Handover()),
        SheetSection(code: 'D-05', cjk: '記述', en: 'diagram from text', child: _FromText()),
        SheetSection(code: 'D-06', cjk: '記号', en: 'symbols · levels · wires · routers', child: _Grammar()),
      ],
    );
  }
}

// ── D-01 ─────────────────────────────────────────────────────────────────

const String _coolantSource = '''
flow LR
IN([INTAKE]) ==> F1[SEC-01|FILTER|濾過]
F1 ==> P1[SEC-02|PUMP A|主系]:::nominal
F1 --> P2[SEC-03|PUMP B|副系]:::offline
P1 ==> HX((HX-01|EXCHANGER|熱交換))
P2 -.-> HX
HX ==> CHK{PRESS|LIMIT 4.2}
CHK ==>|NOMINAL| OUT([RETURN])
CHK -->|LOW|:::caution V1[SEC-05|RELIEF|安全弁]:::caution
V1 --> OUT
HX --> T1>DRAIN]
IN --> BYP[SEC-09|BYPASS|迂回]
BYP --> OUT
''';

class _CoolantLoop extends StatelessWidget {
  const _CoolantLoop();

  @override
  Widget build(BuildContext context) {
    return KkWidgetFrame(
      cjk: '冷却系統',
      en: 'coolant loop',
      meta: 'LAYERED · LR · 10 NODES',
      footer: const <Widget>[
        KkWidgetKey(label: 'TERMINAL', swatch: KkNodeSymbol(kind: KkNodeKind.terminal)),
        KkWidgetKey(label: 'NODE', swatch: KkNodeSymbol(kind: KkNodeKind.node)),
        KkWidgetKey(label: 'HUB', swatch: KkNodeSymbol(kind: KkNodeKind.hub)),
        KkWidgetKey(label: 'DECISION', swatch: KkNodeSymbol(kind: KkNodeKind.decision)),
        KkWidgetKey(label: 'LEAF', swatch: KkNodeSymbol(kind: KkNodeKind.leaf)),
      ],
      child: KkDiagramView(
        diagram: KkDiagram.parse(_coolantSource),
        layout: const KkLayeredLayout(layerGap: 64),
        padding: const EdgeInsets.all(24),
      ),
    );
  }
}

// ── D-02 ─────────────────────────────────────────────────────────────────

const String _startSource = '''
flow TB
S([START]) --> A[STEP-01|POWER BUS|電源]
A --> B[STEP-02|SELF TEST|自己診断]
B --> C{RESULT}
C -->|PASS| D[STEP-03|LINK UP|回線]
C -->|FAIL|:::critical R[STEP-90|RESET|再起動]:::critical
R --> A
D --> E([ONLINE]):::nominal
''';

const String _commandSource = '''
flow TB
HQ((HQ-00|COMMAND|本部)) --- OPS[OPS-10|OPERATIONS|運用]
HQ --- ENG[ENG-20|ENGINEERING|機関]
HQ --- COM[COM-30|SIGNALS|通信]
OPS --- O1[OP-11|WATCH A]:::nominal
OPS --- O2[OP-12|WATCH B]:::nominal
ENG --- E1[EN-21|REACTOR]:::caution
ENG --- E2[EN-22|COOLANT]:::critical
COM --- C1[CM-31|UPLINK]:::nominal
COM --- C2[CM-32|RELAY]:::offline
COM --- C3[CM-33|ARCHIVE]
''';

class _FlowAndTree extends StatelessWidget {
  const _FlowAndTree();

  @override
  Widget build(BuildContext context) {
    return KkRow(
      gap: 16,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          flex: 5,
          child: KkWidgetFrame(
            cjk: '起動手順',
            en: 'start sequence',
            meta: 'LAYERED · TB · CYCLE',
            child: KkDiagramView(
              diagram: KkDiagram.parse(_startSource),
              padding: const EdgeInsets.all(24),
            ),
          ),
        ),
        KkExpanded(
          flex: 8,
          child: KkWidgetFrame(
            cjk: '指揮系統',
            en: 'chain of command',
            meta: 'TREE · TB',
            child: KkDiagramView(
              diagram: KkDiagram.parse(_commandSource),
              layout: const KkTreeLayout(layerGap: 56),
              arrows: false,
              padding: const EdgeInsets.all(24),
            ),
          ),
        ),
      ],
    );
  }
}

// ── D-03 ─────────────────────────────────────────────────────────────────

const String _relaySource = '''
RLY((RLY-00|RELAY)) === N1[N-01|NORTH]
RLY === N2[N-02|EAST]
RLY === N3[N-03|SOUTH]:::caution
RLY --- N4[N-04|WEST]:::offline
RLY === N5[N-05|ORBIT]
N1 --- A1>A-11]
N1 --- A2>A-12]
N2 --- B1>B-21]
N2 --- B2>B-22]:::critical
N2 --- B3>B-23]
N3 --- C1>C-31]
N5 --- E1>E-51]
N5 --- E2>E-52]:::offline
''';

KkDiagram _powerGrid() => KkDiagram(
  nodes: const <KkDiagramNode>[
    KkDiagramNode('GA', code: 'GRID-A', label: 'MAIN BUS', kind: KkNodeKind.hub),
    KkDiagramNode('GB', code: 'GRID-B', label: 'AUX BUS', kind: KkNodeKind.hub),
    KkDiagramNode('S1', code: 'SEC-01', label: 'REACTOR', level: KkLevel.nominal),
    KkDiagramNode('S2', code: 'SEC-02', label: 'TURBINE', level: KkLevel.nominal),
    KkDiagramNode('S3', code: 'SEC-03', label: 'COOLANT', level: KkLevel.caution),
    KkDiagramNode(
      'S4',
      code: 'SEC-04',
      label: 'PUMP HALL',
      cjk: '冷却',
      level: KkLevel.critical,
      info: <String>['COOLANT PRESSURE LOW', '2.1 BAR · LIMIT 4.2', '14:02:31Z'],
    ),
    KkDiagramNode('S5', code: 'SEC-05', label: 'BATTERY'),
    KkDiagramNode('S6', code: 'SEC-06', label: 'UPLINK', level: KkLevel.offline),
    KkDiagramNode('L1', code: 'L-71', kind: KkNodeKind.leaf),
    KkDiagramNode('L2', code: 'L-72', kind: KkNodeKind.leaf, level: KkLevel.offline),
  ],
  edges: const <KkDiagramEdge>[
    KkDiagramEdge('S1', 'GA', active: true, flow: KkEdgeFlow.forward, arrow: false),
    KkDiagramEdge('S2', 'GA', active: true, flow: KkEdgeFlow.forward, arrow: false),
    KkDiagramEdge('GA', 'S3', active: true, flow: KkEdgeFlow.forward, level: KkLevel.caution, arrow: false),
    KkDiagramEdge('GA', 'S4', level: KkLevel.critical, flow: KkEdgeFlow.forward, arrow: false),
    KkDiagramEdge('GA', 'GB', active: true, flow: KkEdgeFlow.forward, label: 'TIE 0.8 MW', arrow: false),
    KkDiagramEdge('GB', 'S5', active: true, flow: KkEdgeFlow.reverse, arrow: false),
    KkDiagramEdge('GB', 'S6', level: KkLevel.offline, arrow: false),
    KkDiagramEdge('GB', 'L1', arrow: false),
    KkDiagramEdge('GB', 'L2', level: KkLevel.offline, arrow: false),
    KkDiagramEdge('S4', 'GB', arrow: false),
  ],
);

class _RadialAndNetwork extends StatelessWidget {
  const _RadialAndNetwork();

  @override
  Widget build(BuildContext context) {
    return KkRow(
      gap: 16,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          flex: 6,
          child: KkWidgetFrame(
            cjk: '通信回線',
            en: 'relay map',
            meta: 'RADIAL · 14 NODES',
            child: KkDiagramView(
              diagram: KkDiagram.parse(_relaySource),
              layout: const KkRadialLayout(root: 'RLY', ringGap: 96),
              arrows: false,
              padding: const EdgeInsets.all(24),
            ),
          ),
        ),
        KkExpanded(
          flex: 7,
          child: KkNodeGraph(
            cjk: '電源系統',
            en: 'power grid',
            meta: 'FORCE · 10 NODES · 1 ALARM',
            diagram: _powerGrid(),
            layout: const KkForceLayout(seed: 1, spacing: 104, aspect: 1.7),
            selected: 'S4',
          ),
        ),
      ],
    );
  }
}

// ── D-04 ─────────────────────────────────────────────────────────────────

class _Handover extends StatelessWidget {
  const _Handover();

  @override
  Widget build(BuildContext context) {
    return const KkSequenceDiagram(
      cjk: '制御移管',
      en: 'control handover',
      participants: <KkSequenceParticipant>[
        KkSequenceParticipant('op', code: 'OP-07', cjk: '運用'),
        KkSequenceParticipant('ctl', code: 'CTRL', cjk: '管制'),
        KkSequenceParticipant('sec', code: 'SEC-04', cjk: '冷却', level: KkLevel.caution),
        KkSequenceParticipant('log', code: 'LOG', cjk: '記録'),
      ],
      entries: <KkSequenceEntry>[
        KkSequenceDivider(code: 'PH-01', cjk: '要求', en: 'request'),
        KkSequenceMessage('op', 'ctl', 'REQUEST CONTROL', note: '14:02:31Z'),
        KkSequenceMessage('ctl', 'sec', 'PING CH.12', note: '14:02:31Z'),
        KkSequenceMessage('sec', 'ctl', 'ACK 0x3F', kind: KkSequenceMessageKind.reply, note: '14:02:32Z'),
        KkSequenceMessage('ctl', 'ctl', 'VERIFY KEY', note: '14:02:32Z'),
        KkSequenceDivider(code: 'PH-02', cjk: '移行', en: 'transfer'),
        KkSequenceMessage('ctl', 'op', 'GRANT', kind: KkSequenceMessageKind.reply, note: '14:02:33Z'),
        KkSequenceMessage('op', 'sec', 'SET MODE AUTO', note: '14:02:35Z'),
        KkSequenceMessage('sec', 'log', 'STATE CHANGE', kind: KkSequenceMessageKind.async, note: '14:02:35Z'),
        KkSequenceMessage(
          'sec',
          'op',
          'PRESSURE LOW 2.1 BAR',
          kind: KkSequenceMessageKind.reply,
          level: KkLevel.critical,
          note: '14:02:36Z',
        ),
      ],
    );
  }
}

// ── D-05 ─────────────────────────────────────────────────────────────────

const String _textSource = '''
flow LR
# sensor to alarm
SEN>PT-104] ==> ADC[ADC-02|SAMPLER]
ADC ==> FLT[DSP-01|FILTER|濾波]
FLT ==> CMP{LIMIT}
CMP -->|IN RANGE| LOG[LOG-01|ARCHIVE]
CMP ==>|OVER|:::critical ALM((ANN-07|ALARM|警報)):::critical
ALM -.-> PGR[PGR-03|PAGER]:::offline
ALM --> LOG
''';

class _FromText extends StatelessWidget {
  const _FromText();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final List<String> lines = _textSource.trimRight().split('\n');
    return KkRow(
      gap: 16,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkExpanded(
          flex: 5,
          child: KkWidgetFrame(
            cjk: '記述',
            en: 'source',
            meta: 'KkDiagram.parse',
            fill: c.bg000,
            child: KkBox(
              padding: const EdgeInsets.all(16),
              child: KkColumn(
                shrinkWrap: true,
                children: <Widget>[
                  for (int i = 0; i < lines.length; i++)
                    KkRow(
                      gap: 12,
                      children: <Widget>[
                        KkBox(
                          width: 16,
                          alignment: Alignment.centerRight,
                          child: KkText.num((i + 1).toString().padLeft(2, '0'), size: 11, height: 1.7, color: c.inkFaint),
                        ),
                        KkExpanded(
                          child: KkText.num(
                            lines[i],
                            size: 11,
                            height: 1.7,
                            color: lines[i].startsWith('#') ? c.inkFaint : c.ink,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        KkExpanded(
          flex: 8,
          child: KkWidgetFrame(
            cjk: '結果',
            en: 'rendered',
            meta: 'LAYERED · LR',
            child: KkDiagramView(
              diagram: KkDiagram.parse(_textSource),
              padding: const EdgeInsets.all(24),
            ),
          ),
        ),
      ],
    );
  }
}

// ── D-06 ─────────────────────────────────────────────────────────────────

KkDiagram _symbolGrid() {
  const List<KkLevel?> levels = <KkLevel?>[null, KkLevel.nominal, KkLevel.caution, KkLevel.critical, KkLevel.offline];
  const List<String> names = <String>['NONE', 'NOMINAL', 'CAUTION', 'CRITICAL', 'OFFLINE'];
  return KkDiagram(
    nodes: <KkDiagramNode>[
      for (int k = 0; k < KkNodeKind.values.length; k++)
        for (int l = 0; l < levels.length; l++)
          KkDiagramNode(
            '${KkNodeKind.values[k].name}$l',
            code: KkNodeKind.values[k].name.toUpperCase(),
            label: names[l],
            kind: KkNodeKind.values[k],
            level: levels[l],
            position: Offset(48.0 + l * 104, 28.0 + k * 80),
          ),
    ],
  );
}

KkDiagram _wireGrid() {
  const List<(String, KkDiagramEdge)> rows = <(String, KkDiagramEdge)>[
    ('PLAIN', KkDiagramEdge('a', 'b')),
    ('NO HEAD', KkDiagramEdge('a', 'b', arrow: false)),
    ('ACTIVE', KkDiagramEdge('a', 'b', active: true)),
    ('FLOW', KkDiagramEdge('a', 'b', active: true, flow: KkEdgeFlow.forward)),
    ('REVERSE', KkDiagramEdge('a', 'b', active: true, flow: KkEdgeFlow.reverse)),
    ('CAUTION', KkDiagramEdge('a', 'b', level: KkLevel.caution, label: 'LABEL')),
    ('CRITICAL', KkDiagramEdge('a', 'b', level: KkLevel.critical, flow: KkEdgeFlow.forward)),
    ('OFFLINE', KkDiagramEdge('a', 'b', level: KkLevel.offline)),
  ];
  return KkDiagram(
    nodes: <KkDiagramNode>[
      for (int i = 0; i < rows.length; i++) ...<KkDiagramNode>[
        KkDiagramNode('a$i', code: rows[i].$1, kind: KkNodeKind.leaf, position: Offset(40, 20.0 + i * 40)),
        KkDiagramNode('b$i', code: 'N-0${i + 1}', kind: KkNodeKind.leaf, position: Offset(300, 20.0 + i * 40)),
      ],
    ],
    edges: <KkDiagramEdge>[
      for (int i = 0; i < rows.length; i++) rows[i].$2.copyWith(from: 'a$i', to: 'b$i'),
    ],
  );
}

KkDiagram _routerSample() => KkDiagram(
  nodes: const <KkDiagramNode>[
    KkDiagramNode('H', code: 'HUB', kind: KkNodeKind.hub, position: Offset(140, 100)),
    KkDiagramNode('A', code: 'N-01', position: Offset(28, 28)),
    KkDiagramNode('B', code: 'N-02', position: Offset(252, 40)),
    KkDiagramNode('C', code: 'N-03', position: Offset(40, 184)),
    KkDiagramNode('D', code: 'N-04', position: Offset(240, 172)),
    KkDiagramNode('E', code: 'N-05', kind: KkNodeKind.leaf, position: Offset(140, 16)),
  ],
  edges: const <KkDiagramEdge>[
    KkDiagramEdge('H', 'A', active: true),
    KkDiagramEdge('H', 'B'),
    KkDiagramEdge('H', 'C'),
    KkDiagramEdge('H', 'D', active: true, flow: KkEdgeFlow.forward),
    KkDiagramEdge('H', 'E'),
    KkDiagramEdge('A', 'C'),
  ],
);

class _Grammar extends StatelessWidget {
  const _Grammar();

  @override
  Widget build(BuildContext context) {
    const KkManualLayout free = KkManualLayout(size: Size(280, 220), normalised: false);
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        KkRow(
          gap: 16,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkExpanded(
              flex: 8,
              child: KkWidgetFrame(
                cjk: '記号と状態',
                en: 'five symbols · five levels',
                meta: 'HUB · OFFLINE SELECTED',
                child: KkDiagramView(
                  diagram: _symbolGrid(),
                  layout: const KkManualLayout(size: Size(520, 400), normalised: false),
                  selected: 'hub4',
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
            KkExpanded(
              flex: 5,
              child: KkWidgetFrame(
                cjk: '配線',
                en: 'wire styles',
                meta: 'FLOW 16 PX/S',
                child: KkDiagramView(
                  diagram: _wireGrid(),
                  layout: const KkManualLayout(size: Size(340, 320), normalised: false),
                  router: const KkEdgeRouter.straight(),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
          ],
        ),
        KkRow(
          gap: 16,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkExpanded(
              child: KkWidgetFrame(
                cjk: '直交',
                en: 'orthogonal · 8 px cut',
                child: KkDiagramView(
                  diagram: _routerSample(),
                  layout: free,
                  router: const KkEdgeRouter.orthogonal(),
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
            KkExpanded(
              child: KkWidgetFrame(
                cjk: '八方',
                en: 'octilinear',
                child: KkDiagramView(
                  diagram: _routerSample(),
                  layout: free,
                  router: const KkEdgeRouter.octilinear(),
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
            KkExpanded(
              child: KkWidgetFrame(
                cjk: '直線',
                en: 'straight',
                child: KkDiagramView(
                  diagram: _routerSample(),
                  layout: free,
                  router: const KkEdgeRouter.straight(),
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
