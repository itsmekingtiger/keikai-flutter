import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import 'live.dart';

/// Opens the detail of [sector] in a sheet: at the right edge on a wide
/// window, from the bottom on a narrow one.
Future<void> openSector(BuildContext context, Sector sector) {
  final bool wide = MediaQuery.sizeOf(context).width >= 840;
  return showKkSheet<void>(
    context: context,
    side: wide ? KkSheetSide.right : KkSheetSide.bottom,
    builder: (BuildContext context) => SectorSheet(sector: sector),
  );
}

/// Takes [sector] off the grid, after asking: its load drops to zero. The
/// question and the notice are the same wherever the action is offered.
Future<void> isolateSector(BuildContext context, Station station, Sector sector) async {
  final ConsoleNotices notices = context.notices;
  final bool yes = await showKkConfirm(
    context: context,
    code: sector.code,
    cjk: '隔離確認',
    en: 'isolate sector',
    message: '${sector.cjk} 구역을 계통에서 분리합니다. 부하는 0으로 떨어집니다.',
    confirmLabel: 'isolate',
    confirmCjk: '隔離',
    danger: true,
  );
  if (!yes) return;
  station.setSectorOffline(sector, offline: true);
  notices.show(code: sector.code, level: KkLevel.offline, message: 'SECTOR ISOLATED');
}

/// The stretches of a level history, for a status timeline.
List<KkTimelineSpan> timelineSpans(List<KkLevel> history) {
  final List<KkTimelineSpan> spans = <KkTimelineSpan>[];
  int start = 0;
  for (int i = 1; i <= history.length; i++) {
    if (i == history.length || history[i] != history[start]) {
      spans.add(KkTimelineSpan(history[start], weight: (i - start).toDouble(), label: '${i - start} S'));
      start = i;
    }
  }
  return spans;
}

/// Everything known about one sector, with the actions an operator may take.
class SectorSheet extends StatelessWidget {
  const SectorSheet({super.key, required this.sector});

  final Sector sector;

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final KkColors c = context.kk.colors;
        final bool offline = sector.level == KkLevel.offline;
        final bool mine = sector.operator == settings.operator;
        return KkSheet(
          code: sector.code,
          cjk: sector.cjk,
          en: sector.en,
          actions: <Widget>[
            KkButton(
              label: mine ? 'assigned' : 'assign to me',
              cjk: '担当',
              variant: KkButtonVariant.ghost,
              onPressed: mine || offline ? null : () => station.assignSector(sector, settings.operator),
            ),
            if (offline)
              KkButton(
                label: 'restore',
                cjk: '復帰',
                variant: KkButtonVariant.primary,
                onPressed: () => station.setSectorOffline(sector, offline: false),
              )
            else
              KkButton(
                label: 'isolate',
                cjk: '隔離',
                variant: KkButtonVariant.danger,
                onPressed: () => isolateSector(context, station, sector),
              ),
          ],
          child: KkColumn(
            gap: 16,
            shrinkWrap: true,
            children: <Widget>[
              KkWrap(
                gap: 8,
                runGap: 8,
                children: <Widget>[
                  KkStatusTag.status(sector.level, size: KkStatusTagSize.lg),
                  KkStatusTag(sector.operator, icon: KkIcons.user, size: KkStatusTagSize.lg, color: c.inkDim),
                  if (sector.note.isNotEmpty) KkStatusTag(sector.note, size: KkStatusTagSize.lg, level: sector.level),
                  if (sector.acknowledged)
                    const KkStatusTag('acknowledged', icon: KkIcons.check, size: KkStatusTagSize.lg),
                ],
              ),
              KkReadout(
                cjk: '負荷',
                en: 'load',
                value: kkFixed(sector.load, digits: 3),
                unit: '%',
                level: offline ? KkLevel.offline : sector.loadLevel,
                position: sector.load / 100,
                footStart: 'LIMIT ${kkFixed(sector.limit, digits: 3)}',
                footEnd: 'MAX 100',
                boot: false,
              ),
              _LimitSlider(sector: sector, station: station),
              KkReadout(
                cjk: '温度',
                en: 'temperature',
                value: settings.temperature(sector.temp),
                unit: settings.tempSymbol,
                level: offline ? KkLevel.offline : (sector.temp >= 70 ? KkLevel.caution : KkLevel.nominal),
                position: (sector.temp - 18) / (95 - 18),
                boot: false,
              ),
              KkTimeSeries(
                cjk: '推移',
                en: 'load trend',
                meta: '24 S',
                height: 96,
                series: <KkSeries>[KkSeries(name: 'LOAD', values: List<double?>.of(sector.trend), area: true)],
                thresholds: <KkThreshold>[
                  KkThreshold(sector.limit.toDouble(), label: 'LIMIT ${kkFixed(sector.limit, digits: 3)}'),
                ],
                yMin: 0,
                yMax: 100,
                interactive: false,
                boot: false,
              ),
              KkStatusTimeline(
                cjk: '履歴',
                en: 'status history',
                meta: '${Station.historyLength} S',
                rows: <KkTimelineRow>[
                  KkTimelineRow(cjk: sector.cjk, en: sector.code, spans: timelineSpans(sector.history)),
                ],
                axis: const <String>['-48 S', '-24 S', 'NOW'],
                boot: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The load limit of a sector on a slider. The plant takes the new limit
/// when the thumb is let go, not at every step on the way there.
class _LimitSlider extends StatefulWidget {
  const _LimitSlider({required this.sector, required this.station});

  final Sector sector;
  final Station station;

  @override
  State<_LimitSlider> createState() => _LimitSliderState();
}

class _LimitSliderState extends State<_LimitSlider> {
  // A slider does not take the keyboard when it is pressed; with a node of
  // its own it can be told to, so that the arrow keys go on from the press.
  final FocusNode _focus = FocusNode(debugLabel: 'load limit');

  /// Where the thumb is while it is being moved.
  double? _moving;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Sector sector = widget.sector;
    final bool offline = sector.level == KkLevel.offline;
    return KkSlider(
      cjk: '上限',
      en: 'load limit',
      unit: '%',
      value: _moving ?? sector.limit.toDouble(),
      min: Sector.minLimit.toDouble(),
      max: Sector.maxLimit.toDouble(),
      divisions: (Sector.maxLimit - Sector.minLimit) ~/ 5,
      enabled: !offline,
      focusNode: _focus,
      semanticLabel: 'Load limit of ${sector.code}',
      marks: <KkSliderMark>[
        KkSliderMark(Sector.minLimit.toDouble()),
        const KkSliderMark(50),
        KkSliderMark(Sector.maxLimit.toDouble()),
      ],
      onChangeStart: (double _) => _focus.requestFocus(),
      onChanged: offline ? null : (double value) => setState(() => _moving = value),
      onChangeEnd: (double value) {
        widget.station.setLoadLimit(sector, value.round());
        setState(() => _moving = null);
      },
    );
  }
}
