import 'package:keikai/keikai.dart';

import '../model/settings.dart';
import '../model/station.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/screen_header.dart';
import '../widgets/sector_detail.dart';

/// The two plants that can be shown.
enum _Plant { coolant, power }

/// How the nodes are placed.
enum _Placement { layered, tree, radial, force }

const String _sample = '''
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

/// The plant as diagrams: the coolant loop and the power grid with live
/// levels, the handover protocol as a sequence, and a small editor for the
/// diagram language.
class DiagramScreen extends StatefulWidget {
  const DiagramScreen({super.key});

  @override
  State<DiagramScreen> createState() => _DiagramScreenState();
}

class _DiagramScreenState extends State<DiagramScreen> {
  final KkDiagramController _view = KkDiagramController();
  final TextEditingController _source = TextEditingController(text: _sample.trim());
  _Plant _plant = _Plant.coolant;
  int _tab = 0;
  _Placement? _placement;
  String? _selected;
  KkDiagram _parsed = KkDiagram.parse(_sample);
  String? _error;

  @override
  void dispose() {
    _view.dispose();
    _source.dispose();
    super.dispose();
  }

  _Placement get _effective => _placement ?? (_plant == _Plant.coolant ? _Placement.layered : _Placement.force);

  /// The layout for the chosen placement. On a phone a flow runs from top to
  /// bottom: nine nodes side by side would be too small to read.
  KkDiagramLayout _layout({required bool upright}) {
    final KkDiagramDirection? direction = upright ? KkDiagramDirection.topToBottom : null;
    return switch (_effective) {
      _Placement.layered => KkDiagramLayout.layered(direction: direction),
      _Placement.tree => KkDiagramLayout.tree(direction: direction),
      _Placement.radial => const KkDiagramLayout.radial(),
      _Placement.force => const KkDiagramLayout.force(seed: 3),
    };
  }

  void _onSource(String text) {
    final KkDiagram? parsed = KkDiagram.tryParse(text);
    String? error;
    if (parsed == null) {
      try {
        KkDiagram.parse(text);
      } on FormatException catch (e) {
        error = e.message.toUpperCase();
      }
      error ??= 'CANNOT READ THE DIAGRAM';
    }
    setState(() {
      if (parsed != null) _parsed = parsed;
      _error = error;
    });
  }

  /// The coolant loop, with the levels the plant has right now.
  KkDiagram _coolant(Station station) {
    final Sector coolant = station.sectors[3];
    final Sector feed = station.sectors[4];
    final bool tripped = station.alert;
    final bool auxOn = station.procedure[1].status == StepStatus.done;
    final bool valveShut = station.procedure[2].status == StepStatus.done;
    final KkLevel pumpA = tripped
        ? KkLevel.critical
        : (station.phase == IncidentPhase.none ? KkLevel.nominal : KkLevel.caution);
    return KkDiagram(
      nodes: <KkDiagramNode>[
        const KkDiagramNode('IN', code: 'INTAKE', kind: KkNodeKind.terminal),
        KkDiagramNode(feed.code, label: 'FEED', cjk: feed.cjk, level: feed.level),
        KkDiagramNode(
          'PUMP-A',
          label: 'MAIN',
          cjk: '主機',
          level: pumpA,
          info: <String>[
            'PUMP A · MAIN',
            tripped ? 'TRIPPED · INTERLOCK' : '204 L/MIN',
            'P-01 ${station.coolantPressure.text} kPa',
          ],
        ),
        KkDiagramNode(
          'PUMP-B',
          label: 'AUX',
          cjk: '補機',
          level: auxOn ? KkLevel.nominal : KkLevel.offline,
          info: <String>['PUMP B · AUX', auxOn ? '1450 RPM' : 'STANDBY'],
        ),
        const KkDiagramNode('HX-01', label: 'EXCHANGER', cjk: '熱交換', kind: KkNodeKind.hub),
        KkDiagramNode(coolant.code, label: 'COOLANT', cjk: coolant.cjk, level: coolant.level),
        KkDiagramNode(
          'V-17',
          label: valveShut ? 'SHUT' : 'LIMIT 120',
          kind: KkNodeKind.decision,
          level: valveShut ? KkLevel.offline : null,
        ),
        const KkDiagramNode('OUT', code: 'RETURN', kind: KkNodeKind.terminal),
        const KkDiagramNode('DRAIN', kind: KkNodeKind.leaf),
      ],
      edges: <KkDiagramEdge>[
        KkDiagramEdge('IN', feed.code, active: true, flow: KkEdgeFlow.forward),
        KkDiagramEdge(
          feed.code,
          'PUMP-A',
          active: !tripped,
          flow: tripped ? KkEdgeFlow.none : KkEdgeFlow.forward,
          level: tripped ? KkLevel.critical : null,
        ),
        KkDiagramEdge(
          feed.code,
          'PUMP-B',
          active: auxOn,
          flow: auxOn ? KkEdgeFlow.forward : KkEdgeFlow.none,
          level: auxOn ? null : KkLevel.offline,
        ),
        KkDiagramEdge(
          'PUMP-A',
          'HX-01',
          active: !tripped,
          flow: tripped ? KkEdgeFlow.none : KkEdgeFlow.forward,
          level: tripped ? KkLevel.critical : null,
        ),
        KkDiagramEdge(
          'PUMP-B',
          'HX-01',
          active: auxOn,
          flow: auxOn ? KkEdgeFlow.forward : KkEdgeFlow.none,
          level: auxOn ? null : KkLevel.offline,
        ),
        KkDiagramEdge('HX-01', coolant.code, active: true, flow: KkEdgeFlow.forward),
        KkDiagramEdge(coolant.code, 'V-17', active: true),
        KkDiagramEdge('V-17', 'OUT', label: 'NOMINAL', active: !valveShut, level: valveShut ? KkLevel.offline : null),
        KkDiagramEdge('V-17', 'DRAIN', label: 'LOW', level: tripped ? KkLevel.caution : null),
      ],
    );
  }

  /// The power grid: two buses and the sectors they feed.
  KkDiagram _power(Station station) {
    KkDiagramNode sector(int i, {KkNodeKind kind = KkNodeKind.node}) {
      final Sector s = station.sectors[i];
      return KkDiagramNode(
        s.code,
        label: s.en.toUpperCase(),
        cjk: s.cjk,
        kind: kind,
        level: s.level,
        info: <String>[
          '${s.code} · ${s.en.toUpperCase()}',
          s.level == KkLevel.offline ? 'OFFLINE' : 'LOAD ${kkFixed(s.load, digits: 3)} %',
          s.operator,
        ],
      );
    }

    KkDiagramEdge feed(String from, int to, {String? label}) {
      final Sector s = station.sectors[to];
      final bool live = s.level != KkLevel.offline;
      return KkDiagramEdge(
        from,
        s.code,
        label: label,
        active: live && s.load > 45,
        flow: live && s.load > 45 ? KkEdgeFlow.forward : KkEdgeFlow.none,
        level: s.level == KkLevel.nominal ? null : s.level,
        arrow: false,
      );
    }

    return KkDiagram(
      nodes: <KkDiagramNode>[
        KkDiagramNode(
          'GRID-A',
          label: 'MAIN BUS',
          kind: KkNodeKind.hub,
          level: station.busVoltage.level == KkLevel.nominal ? null : station.busVoltage.level,
          info: <String>[
            'MAIN BUS',
            '${station.busVoltage.text} V',
            '${kkFixed(station.frequency, digits: 2, decimals: 2)} Hz',
          ],
        ),
        const KkDiagramNode('GRID-B', label: 'AUX BUS', kind: KkNodeKind.hub),
        sector(0),
        sector(1),
        sector(2),
        sector(3),
        sector(5),
        sector(6),
        sector(7),
        sector(8),
        sector(9, kind: KkNodeKind.leaf),
        sector(10),
        sector(11, kind: KkNodeKind.leaf),
      ],
      edges: <KkDiagramEdge>[
        const KkDiagramEdge('GRID-A', 'GRID-B', label: 'TIE', active: true, arrow: false),
        feed('GRID-A', 0),
        feed('GRID-A', 1),
        feed('GRID-A', 3),
        feed('GRID-A', 5),
        feed('GRID-B', 2),
        feed('GRID-B', 6),
        feed(station.sectors[6].code, 7),
        feed('GRID-B', 8),
        feed(station.sectors[8].code, 9),
        feed('GRID-B', 10),
        feed(station.sectors[10].code, 11),
      ],
    );
  }

  /// The handover between operator, control and sector, grown from the
  /// procedure as it is carried out.
  List<KkSequenceEntry> _handover(Station station) {
    final List<KkSequenceEntry> entries = <KkSequenceEntry>[
      const KkSequenceDivider(code: 'PH-01', cjk: '要求', en: 'request'),
      KkSequenceMessage(
        'OP',
        'CTRL',
        'REQUEST CONTROL',
        note: formatClock(station.now.subtract(const Duration(seconds: 42))),
      ),
      const KkSequenceMessage('CTRL', 'SEC', 'PING CH.12'),
      const KkSequenceMessage('SEC', 'CTRL', 'ACK 0x3F', kind: KkSequenceMessageKind.reply),
      const KkSequenceMessage('CTRL', 'OP', 'GRANT', kind: KkSequenceMessageKind.reply),
    ];
    final List<ProcedureStep> steps = station.procedure;
    if (steps.any((ProcedureStep s) => s.status != StepStatus.pending)) {
      entries.add(const KkSequenceDivider(code: 'PH-02', cjk: '対処', en: 'respond'));
    }
    for (final ProcedureStep step in steps) {
      final DateTime? at = step.at;
      if (step.status == StepStatus.done) {
        entries
          ..add(KkSequenceMessage('OP', 'SEC', step.en.toUpperCase(), note: at == null ? null : formatClock(at)))
          ..add(const KkSequenceMessage('SEC', 'LOG', 'DONE', kind: KkSequenceMessageKind.async));
      } else if (step.status == StepStatus.active) {
        entries.add(
          KkSequenceMessage(
            'CTRL',
            'OP',
            'NEXT · ${step.en.toUpperCase()}',
            kind: KkSequenceMessageKind.async,
            level: station.alert ? KkLevel.critical : KkLevel.caution,
          ),
        );
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final KkDiagram diagram = _plant == _Plant.coolant ? _coolant(station) : _power(station);
        final KkDiagramNode? picked = _selected == null ? null : diagram.nodeById(_selected!);
        final KkWindowClass window = KkWindowScope.of(context);
        final bool wide = window.isAtLeast(KkWindowClass.expanded);
        final bool compact = window == KkWindowClass.compact;
        final bool flow = _effective == _Placement.layered || _effective == _Placement.tree;
        final KkDiagramLayout layout = _layout(upright: compact);
        final Widget graph = KkNodeGraph(
          key: ValueKey<String>('${_plant.name}-${_effective.name}-$compact'),
          diagram: diagram,
          cjk: _plant == _Plant.coolant ? '冷却系統' : '電源系統',
          en: _plant == _Plant.coolant ? 'coolant loop' : 'power grid',
          meta: '${_effective.name.toUpperCase()} · ${kkFixed(diagram.nodes.length, digits: 2)} NODES',
          level: station.alert && _plant == _Plant.coolant ? KkLevel.critical : null,
          layout: layout,
          router: layout.defaultRouter,
          // A flow is a flat band (a tall one on a phone); a map wants a square.
          height: flow ? (compact ? 560 : 320) : (wide ? 440 : 360),
          interactive: true,
          controller: _view,
          selected: picked?.id,
          onSelected: (String? id) => setState(() => _selected = id),
          arrows: flow,
        );
        final Widget controls = KkWrap(
          gap: 12,
          runGap: 8,
          children: <Widget>[
            KkSegmented<_Plant>(
              value: _plant,
              onChanged: (_Plant v) => setState(() {
                _plant = v;
                _placement = null;
                _selected = null;
              }),
              segments: const <KkSegment<_Plant>>[
                KkSegment<_Plant>(value: _Plant.coolant, cjk: '冷却', label: 'coolant'),
                KkSegment<_Plant>(value: _Plant.power, cjk: '電源', label: 'power'),
              ],
            ),
            KkSegmented<_Placement>(
              value: _effective,
              onChanged: (_Placement v) => setState(() => _placement = v),
              segments: const <KkSegment<_Placement>>[
                KkSegment<_Placement>(value: _Placement.layered, label: 'layered'),
                KkSegment<_Placement>(value: _Placement.tree, label: 'tree'),
                KkSegment<_Placement>(value: _Placement.radial, label: 'radial'),
                KkSegment<_Placement>(value: _Placement.force, label: 'force'),
              ],
            ),
            KkRow(
              shrinkWrap: true,
              gap: 2,
              children: <Widget>[
                KkTooltip(
                  message: 'ZOOM OUT',
                  child: KkIconButton(
                    icon: KkIcons.zoomOut,
                    variant: KkIconButtonVariant.outline,
                    semanticLabel: 'Zoom out',
                    onPressed: () => _view.zoomBy(1 / 1.25),
                  ),
                ),
                KkTooltip(
                  message: 'FIT',
                  child: KkIconButton(
                    icon: KkIcons.fit,
                    variant: KkIconButtonVariant.outline,
                    semanticLabel: 'Fit',
                    onPressed: _view.reset,
                  ),
                ),
                KkTooltip(
                  message: 'ZOOM IN',
                  child: KkIconButton(
                    icon: KkIcons.zoomIn,
                    variant: KkIconButtonVariant.outline,
                    semanticLabel: 'Zoom in',
                    onPressed: () => _view.zoomBy(1.25),
                  ),
                ),
              ],
            ),
          ],
        );
        final Widget inspector = _Inspector(
          node: picked,
          diagram: diagram,
          station: station,
          onClear: () => setState(() => _selected = null),
        );
        final Widget handover = KkSequenceDiagram(
          cjk: '制御移管',
          en: 'control handover',
          level: station.alert ? KkLevel.critical : null,
          participants: <KkSequenceParticipant>[
            KkSequenceParticipant('OP', code: settings.operator, cjk: '運用'),
            const KkSequenceParticipant('CTRL', cjk: '管制'),
            KkSequenceParticipant('SEC', code: 'SEC-04', cjk: '冷却', level: station.sectors[3].level),
            const KkSequenceParticipant('LOG', cjk: '記録'),
          ],
          entries: _handover(station),
        );
        // The four lifelines need 640px; a narrower window scrolls sideways.
        final Widget sequence = KkBreakpoint(
          builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
            if (constraints.maxWidth >= 640) return handover;
            return KkScroll(
              axis: Axis.horizontal,
              child: KkSized(width: 640, child: handover),
            );
          },
        );
        final Widget editor = KkTextField(
          controller: _source,
          cjk: '記述',
          en: 'source',
          mono: true,
          maxLines: 11,
          minLines: 11,
          error: _error,
          support: 'ID[CODE|LABEL|漢字] · ID((HUB)) · ID{DECISION} · A ==> B · A -->|TEXT| B · :::critical',
          onChanged: _onSource,
          semanticLabel: 'Diagram source',
        );
        final Widget rendered = KkWidgetFrame(
          cjk: '結果',
          en: 'rendered',
          meta: '${kkFixed(_parsed.nodes.length, digits: 2)} NODES · ${kkFixed(_parsed.edges.length, digits: 2)} WIRES',
          level: _error == null ? null : KkLevel.caution,
          expandBody: true,
          child: KkDiagramView(diagram: _parsed, semanticLabel: 'Diagram drawn from the source'),
        );
        return KkColumn(
          gap: 16,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.diagram,
              note: '계통을 선도로 본다. 노드 색은 실시간 상태를 따르고, 노드를 누르면 정보판이 열린다.',
              actions: <Widget>[controls],
            ),
            if (wide)
              KkRow(
                gap: 16,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkExpanded(flex: 3, child: graph),
                  KkExpanded(child: inspector),
                ],
              )
            else ...<Widget>[graph, inspector],
            KkTabs(
              variant: KkTabsVariant.secondary,
              index: _tab,
              onChanged: (int i) => setState(() => _tab = i),
              tabs: const <KkTab>[
                KkTab(code: 'T-1', cjk: '制御移管', en: 'handover', icon: KkIcons.swap),
                KkTab(code: 'T-2', cjk: '記述', en: 'editor', icon: KkIcons.code),
              ],
            ),
            KkTabView(
              index: _tab,
              children: <Widget>[
                sequence,
                if (wide)
                  KkSized(
                    height: 336,
                    child: KkSplit(
                      initialRatio: 0.42,
                      minFirst: 280,
                      minSecond: 280,
                      semanticLabel: 'Source and drawing',
                      first: KkScroll(child: editor),
                      second: rendered,
                    ),
                  )
                else
                  KkColumn(
                    gap: 16,
                    shrinkWrap: true,
                    children: <Widget>[
                      editor,
                      KkSized(height: 280, child: rendered),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// What is known about the selected node, and the way to its sector.
class _Inspector extends StatelessWidget {
  const _Inspector({required this.node, required this.diagram, required this.station, required this.onClear});

  final KkDiagramNode? node;
  final KkDiagram diagram;
  final Station station;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final KkDiagramNode? n = node;
    if (n == null) {
      return const KkEmpty(cjk: '未選択', en: 'no node selected', sub: 'TAP A NODE TO READ ITS PLATE', minHeight: 200);
    }
    Sector? sector;
    for (final Sector s in station.sectors) {
      if (s.code == n.id) sector = s;
    }
    final Sector? found = sector;
    final List<String> next = diagram.neighbours(n.id);
    Widget line(String label, String value) => KkRow(
      gap: 8,
      cross: KkCrossAlign.baseline,
      children: <Widget>[
        KkExpanded(
          child: KkText.en(label, size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
        ),
        KkText.num(value, size: 12, weight: FontWeight.w500, color: c.ink),
      ],
    );
    return KkPanel(
      code: n.text,
      cjk: n.cjk ?? '節点',
      en: n.label ?? 'node',
      level: n.level == KkLevel.critical ? KkLevel.critical : null,
      variant: KkPanelVariant.active,
      trailing: <Widget>[
        KkIconButton(
          icon: KkIcons.close,
          size: KkIconButtonSize.sm,
          semanticLabel: 'Clear selection',
          onPressed: onClear,
        ),
      ],
      child: KkColumn(
        gap: 12,
        shrinkWrap: true,
        children: <Widget>[
          KkRow(
            gap: 8,
            children: <Widget>[
              KkNodeSymbol(kind: n.kind, level: n.level, size: 20),
              KkStatusTag(n.kind.name, variant: KkStatusTagVariant.solid, color: c.inkDim),
            ],
          ),
          KkRow(
            gap: 8,
            children: <Widget>[
              KkText.en('state', size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
              const KkSpacer(),
              KkStateWord(level: n.level, size: 11, glyphSize: 12),
            ],
          ),
          line('wires in', kkFixed(diagram.incoming(n.id).length, digits: 2)),
          line('wires out', kkFixed(diagram.outgoing(n.id).length, digits: 2)),
          line('joined to', next.isEmpty ? '--' : next.take(3).join(' · ')),
          for (final String info in n.info.skip(1)) KkText.num(info, size: 12, color: c.inkDim),
          // A node that stands for a sector shows how its load has been going.
          if (found != null && found.level != KkLevel.offline)
            KkRow(
              gap: 8,
              children: <Widget>[
                KkText.en('load', size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
                KkExpanded(
                  child: KkSparkline(
                    values: List<double?>.of(found.trend),
                    height: 20,
                    min: 0,
                    max: 100,
                    level: found.level == KkLevel.nominal ? null : found.level,
                    animate: false,
                    semanticLabel: 'Load of ${found.code} over the last ${found.trend.length} seconds',
                  ),
                ),
                KkText.num('${kkFixed(found.load, digits: 3)} %', size: 12, weight: FontWeight.w500, color: c.ink),
              ],
            ),
          if (found != null)
            KkButton(
              label: 'open sector',
              cjk: '詳細',
              icon: KkIcons.external,
              expand: true,
              onPressed: () => openSector(context, found),
            ),
        ],
      ),
    );
  }
}
