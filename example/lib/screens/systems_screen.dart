import 'dart:async';

import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/screen_header.dart';
import '../widgets/sector_detail.dart';

/// Which sectors are shown.
enum _Show { all, up, trouble, offline }

/// The orders the phone's select offers. The table sorts by any column; both
/// keep the same sort.
const List<(KkTableSort, String)> _orders = <(KkTableSort, String)>[
  (KkTableSort('code'), 'BY CODE'),
  (KkTableSort('load', KkSortDirection.descending), 'BY LOAD'),
  (KkTableSort('temp', KkSortDirection.descending), 'BY TEMPERATURE'),
  (KkTableSort('state', KkSortDirection.descending), 'BY LEVEL'),
];

int _severity(KkLevel level) => switch (level) {
  KkLevel.critical => 3,
  KkLevel.caution => 2,
  KkLevel.offline => 1,
  KkLevel.nominal => 0,
};

/// Whether [sector] has no value in [column]: an isolated sector has neither
/// load nor temperature. Such rows go last whichever way the column is sorted.
bool _blank(Sector sector, String column) => sector.level == KkLevel.offline && (column == 'load' || column == 'temp');

/// How two sectors are ordered by a column, ascending. The table's columns
/// and the phone's list both sort with these.
final Map<String, int Function(Sector a, Sector b)> _compare = <String, int Function(Sector a, Sector b)>{
  'code': (Sector a, Sector b) => a.code.compareTo(b.code),
  'name': (Sector a, Sector b) => a.en.compareTo(b.en),
  'operator': (Sector a, Sector b) => a.operator.compareTo(b.operator),
  'load': (Sector a, Sector b) => a.load.compareTo(b.load),
  'limit': (Sector a, Sector b) => a.limit.compareTo(b.limit),
  'temp': (Sector a, Sector b) => a.temp.compareTo(b.temp),
  'state': (Sector a, Sector b) => _severity(a.level).compareTo(_severity(b.level)),
};

/// The sectors of the plant: a table to sort, filter, select from and edit
/// in (a list on a phone), with their history, the sensor channels and the
/// camera feeds under it.
class SystemsScreen extends StatefulWidget {
  const SystemsScreen({super.key});

  @override
  State<SystemsScreen> createState() => _SystemsScreenState();
}

class _SystemsScreenState extends State<SystemsScreen> {
  final TextEditingController _search = TextEditingController();

  /// The filter text as typed, shared by the phone's search field and the
  /// table's filter field.
  String _query = '';
  _Show _show = _Show.all;
  final Set<String> _operators = <String>{};

  /// The sort of table and list. Null leaves the sectors in plant order.
  KkTableSort? _sort;

  /// The codes of the sectors selected in the table.
  Set<Object> _selected = <Object>{};
  int _feed = 0;
  bool _loading = false;
  int _reloads = 0;
  Timer? _load;

  @override
  void dispose() {
    _load?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool get _filtered => _query.trim().isNotEmpty || _show != _Show.all || _operators.isNotEmpty;

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _show = _Show.all;
      _operators.clear();
    });
  }

  void _setQuery(String text) {
    if (_search.text != text) _search.text = text;
    if (text != _query) setState(() => _query = text);
  }

  /// Pretends to read the sectors again: the table's rail scans for a moment.
  void _reload() {
    _load?.cancel();
    setState(() {
      _loading = true;
      _reloads++;
    });
    _load = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  bool _matches(Sector s, String query) {
    final String q = query.trim().toUpperCase();
    if (q.isEmpty) return true;
    return s.code.contains(q) ||
        s.en.toUpperCase().contains(q) ||
        s.cjk.contains(query.trim()) ||
        s.operator.contains(q) ||
        s.note.contains(q);
  }

  /// The sectors the status switch and the operator chips let through, in
  /// plant order. The table takes these and applies text filter and sort
  /// itself.
  List<Sector> _chosen(Station station) => station.sectors.where((Sector s) {
    final bool shown = switch (_show) {
      _Show.all => true,
      _Show.up => s.level == KkLevel.nominal,
      _Show.trouble => s.level == KkLevel.caution || s.level == KkLevel.critical,
      _Show.offline => s.level == KkLevel.offline,
    };
    return shown && (_operators.isEmpty || _operators.contains(s.operator));
  }).toList();

  /// [chosen] narrowed by the filter text and put in order exactly as the
  /// table does it: the rows of the phone's list, of the history and of the
  /// count in the header.
  List<Sector> _visible(List<Sector> chosen) {
    final List<Sector> list = chosen.where((Sector s) => _matches(s, _query)).toList();
    final KkTableSort? sort = _sort;
    final int Function(Sector a, Sector b)? compare = sort == null ? null : _compare[sort.column];
    if (sort == null || compare == null) return list;
    // Stable, like the table's sort: sectors that compare equal keep plant
    // order, and those without a value stay last in both directions.
    final List<int> order = List<int>.generate(list.length, (int i) => i);
    final int sign = sort.ascending ? 1 : -1;
    order.sort((int a, int b) {
      final bool blankA = _blank(list[a], sort.column);
      final bool blankB = _blank(list[b], sort.column);
      if (blankA != blankB) return blankA ? 1 : -1;
      final int c = blankA ? 0 : compare(list[a], list[b]) * sign;
      return c != 0 ? c : a - b;
    });
    return <Sector>[for (final int i in order) list[i]];
  }

  // ── what the table's selection band does ──────────────────────────────────

  List<Sector> _picked(Station station, Set<Object> keys) =>
      station.sectors.where((Sector s) => keys.contains(s.code)).toList();

  void _done(String message, {KkLevel? level}) {
    context.notices.show(code: 'SEC', level: level, message: message);
    setState(() => _selected = <Object>{});
  }

  void _acknowledge(Station station, AppSettings settings, Set<Object> keys) {
    final int count = station.acknowledgeSectors(_picked(station, keys), settings.operator);
    _done(count == 0 ? 'NOTHING TO ACKNOWLEDGE' : 'ACKNOWLEDGED ${kkFixed(count, digits: 2)} SECTORS');
  }

  void _assign(Station station, AppSettings settings, Set<Object> keys) {
    int count = 0;
    for (final Sector s in _picked(station, keys)) {
      if (s.level == KkLevel.offline || s.operator == settings.operator) continue;
      station.assignSector(s, settings.operator);
      count++;
    }
    _done('ASSIGNED ${kkFixed(count, digits: 2)} SECTORS TO ${settings.operator}', level: KkLevel.nominal);
  }

  void _isolate(Station station, Set<Object> keys) {
    int count = 0;
    for (final Sector s in _picked(station, keys)) {
      if (s.level == KkLevel.offline) continue;
      station.setSectorOffline(s, offline: true);
      count++;
    }
    _done('ISOLATED ${kkFixed(count, digits: 2)} SECTORS', level: KkLevel.offline);
  }

  // ── the table ─────────────────────────────────────────────────────────────

  List<KkTableColumn<Sector>> _columns(Station station, AppSettings settings, {required bool roomy}) {
    bool off(Sector s) => s.level == KkLevel.offline;
    return <KkTableColumn<Sector>>[
      KkTableColumn<Sector>(
        id: 'code',
        cjk: '符号',
        en: 'code',
        sortable: true,
        value: (Sector s) => s.code,
        compare: _compare['code'],
        cell: (BuildContext context, Sector s) => KkTableCode(s.code),
        summary: (BuildContext context, List<Sector> rows) => const KkTableSummary.title(cjk: '合計', en: 'total'),
      ),
      KkTableColumn<Sector>(
        id: 'name',
        cjk: '名称',
        en: 'name',
        width: const KkTableWidth.flex(min: 148),
        sortable: true,
        truncate: true,
        value: (Sector s) => s.en,
        compare: _compare['name'],
        format: (Sector s) => '${s.cjk} ${s.en.toUpperCase()}',
        summary: (BuildContext context, List<Sector> rows) =>
            KkTableSummary('${kkFixed(rows.length, digits: 2)} SECTORS'),
      ),
      KkTableColumn<Sector>(
        id: 'operator',
        cjk: '担当',
        en: 'operator',
        sortable: true,
        value: (Sector s) => s.operator,
        compare: _compare['operator'],
      ),
      KkTableColumn<Sector>(
        id: 'load',
        cjk: '負荷',
        en: 'load',
        sortable: true,
        // The load moves a little every second. What counts as a change (and
        // flashes the cell) is the meter gaining or losing a segment.
        value: (Sector s) => off(s) ? null : KkTableMeter.litSegments(s.load.round() / 100, 10),
        compare: _compare['load'],
        cell: (BuildContext context, Sector s) => off(s)
            ? const KkTableMeter(double.nan, level: KkLevel.offline)
            : KkTableMeter(
                s.load.round() / 100,
                level: s.loadLevel == KkLevel.nominal ? null : s.loadLevel,
                label: '${kkFixed(s.load, digits: 3)}%',
              ),
        summary: (BuildContext context, List<Sector> rows) {
          final List<Sector> up = rows.where((Sector s) => !off(s)).toList();
          if (up.isEmpty) return const KkTableSummary('---', label: 'avg');
          final double mean = up.fold<double>(0, (double sum, Sector s) => sum + s.load) / up.length;
          return KkTableSummary('${kkFixed(mean, digits: 3)}%', label: 'avg');
        },
      ),
      KkTableColumn<Sector>(
        id: 'limit',
        cjk: '上限',
        en: 'limit',
        unit: '%',
        numeric: true,
        width: const KkTableWidth.fixed(104),
        sortable: true,
        tooltip: 'LOAD LIMIT · PRESS TO SET · ${Sector.minLimit} TO ${Sector.maxLimit}',
        value: (Sector s) => s.limit,
        compare: _compare['limit'],
        format: (Sector s) => kkFixed(s.limit, digits: 3),
        editable: true,
        canEdit: (Sector s) => !off(s),
        editText: (Sector s) => s.limit.toString(),
        editMaxLength: 3,
        validator: (Sector s, String text) {
          final int? value = int.tryParse(text.trim());
          if (value == null) return 'A WHOLE NUMBER';
          if (value < Sector.minLimit || value > Sector.maxLimit) {
            return '${Sector.minLimit} TO ${Sector.maxLimit}';
          }
          return null;
        },
        onEdited: (Sector s, String text) => station.setLoadLimit(s, int.parse(text.trim())),
      ),
      KkTableColumn<Sector>(
        id: 'temp',
        cjk: '温度',
        en: 'temp',
        unit: settings.tempSymbol,
        numeric: true,
        sortable: true,
        // Whole degrees in the table; the detail row has the tenths.
        value: (Sector s) => off(s) ? null : settings.degrees(s.temp).round(),
        compare: _compare['temp'],
        cell: (BuildContext context, Sector s) => KkTableValue(
          off(s) ? '---' : kkFixed(settings.degrees(s.temp), digits: 3),
          level: off(s) ? KkLevel.offline : (s.temp >= 70 ? KkLevel.caution : null),
        ),
        summary: (BuildContext context, List<Sector> rows) {
          final List<Sector> up = rows.where((Sector s) => !off(s)).toList();
          if (up.isEmpty) return const KkTableSummary('---', label: 'max');
          final double hottest = up.fold<double>(up.first.temp, (double m, Sector s) => s.temp > m ? s.temp : m);
          return KkTableSummary(kkFixed(settings.degrees(hottest), digits: 3), label: 'max');
        },
      ),
      if (roomy)
        KkTableColumn<Sector>(
          id: 'trend',
          cjk: '推移',
          en: 'load · 24 s',
          searchable: false,
          cell: (BuildContext context, Sector s) => KkTableSpark(
            off(s) ? const <double?>[] : List<double?>.of(s.trend),
            level: s.loadLevel == KkLevel.nominal ? null : s.loadLevel,
            animate: false,
            semanticLabel: 'Load of ${s.code} over the last ${s.trend.length} seconds',
          ),
        ),
      if (roomy)
        KkTableColumn<Sector>(
          id: 'note',
          cjk: '所見',
          en: 'remarks',
          width: const KkTableWidth.flex(min: 112),
          truncate: true,
          value: (Sector s) => s.note,
          format: (Sector s) => s.note.isEmpty ? '--' : s.note,
        ),
      KkTableColumn<Sector>(
        id: 'state',
        cjk: '状態',
        en: 'state',
        sortable: true,
        value: (Sector s) => '${s.level.word}${s.acknowledged ? ' · ACK' : ''}',
        compare: _compare['state'],
        cell: (BuildContext context, Sector s) =>
            KkTableLevel(level: s.level, text: s.acknowledged ? '${s.level.word} · ACK' : null),
      ),
    ];
  }

  Widget _table(Station station, AppSettings settings, List<Sector> chosen, {required bool roomy}) {
    final List<Sector> picked = _picked(station, _selected);
    final bool anyUp = picked.any((Sector s) => s.level != KkLevel.offline);
    return KkDataTable<Sector>(
      code: 'SEC',
      cjk: '区画一覧',
      en: 'sectors',
      meta: '${kkFixed(chosen.length, digits: 2)} OF ${kkFixed(station.sectors.length, digits: 2)}',
      semanticLabel: 'Sectors',
      filterable: true,
      filter: _query,
      onFilterChanged: _setQuery,
      filterPlaceholder: 'filter sectors',
      filterPredicate: _matches,
      sort: _sort ?? KkTableSort.none,
      onSortChanged: (KkTableSort? sort) => setState(() => _sort = sort),
      actions: <Widget>[
        KkIconButton(
          icon: KkIcons.download,
          size: KkIconButtonSize.sm,
          semanticLabel: 'Export',
          onPressed: () => context.notices.show(
            code: 'SEC',
            level: KkLevel.nominal,
            message:
                'EXPORTED ${kkFixed(_visible(chosen).length, digits: 2)} ROWS · SECTORS-${kkFormatDate(station.now)}.CSV',
          ),
        ),
        KkIconButton(
          icon: KkIcons.refresh,
          size: KkIconButtonSize.sm,
          semanticLabel: 'Refresh',
          spinTrigger: _reloads,
          onPressed: _reload,
        ),
      ],
      rows: chosen,
      rowKey: (Sector s) => s.code,
      rowLevel: (Sector s) => s.level,
      rowSemanticLabel: (Sector s) => '${s.code} ${s.en}',
      onRowPressed: (Sector s) => openSector(context, s),
      selection: KkTableSelection.multi,
      selected: _selected,
      onSelectionChanged: (Set<Object> keys) => setState(() => _selected = keys),
      bulkActions: <KkTableBulkAction>[
        KkTableBulkAction(
          label: 'acknowledge',
          cjk: '確認',
          icon: KkIcons.check,
          onPressed: (Set<Object> keys) => _acknowledge(station, settings, keys),
        ),
        KkTableBulkAction(
          label: 'assign to me',
          cjk: '担当',
          icon: KkIcons.user,
          onPressed: anyUp ? (Set<Object> keys) => _assign(station, settings, keys) : null,
        ),
        // Taking sectors off the grid has to be said twice: the first press arms the button.
        KkTableBulkAction(
          label: 'isolate',
          cjk: '隔離',
          icon: KkIcons.power,
          danger: true,
          confirmLabel: 'confirm isolate',
          onPressed: anyUp ? (Set<Object> keys) => _isolate(station, keys) : null,
        ),
      ],
      detail: (BuildContext context, Sector s) => _SectorDetail(sector: s, station: station, settings: settings),
      dense: settings.dense,
      initialPageSize: 8,
      pageSizeOptions: const <int>[8, 12],
      loading: _loading,
      emptyBuilder: (BuildContext context, bool noMatch) => KkEmpty(
        cjk: '該当なし',
        en: 'no sector matches',
        sub: 'FILTERS HIDE ALL ${station.sectors.length} SECTORS',
        minHeight: 200,
        action: KkButton(label: 'clear filters', cjk: '解除', icon: KkIcons.close, onPressed: _clear),
      ),
      columns: _columns(station, settings, roomy: roomy),
    );
  }

  /// The three sensor channels the go / no-go vote reads, as a small table.
  Widget _channels(Station station, AppSettings settings, {required bool narrow}) {
    return KkDataTable<Channel>(
      code: 'CH',
      cjk: '検出系',
      en: 'channels',
      meta: '2-OF-3',
      semanticLabel: 'Sensor channels',
      rows: station.channels,
      rowKey: (Channel c) => c.id,
      rowLevel: (Channel c) => _verdictLevel(c.verdict),
      dense: settings.dense,
      columns: <KkTableColumn<Channel>>[
        KkTableColumn<Channel>(
          id: 'id',
          en: 'id',
          value: (Channel c) => c.id,
          cell: (BuildContext context, Channel c) => KkTableCode(c.id),
        ),
        if (!narrow)
          KkTableColumn<Channel>(
            id: 'name',
            en: 'name',
            value: (Channel c) => c.name,
            format: (Channel c) => c.name.toUpperCase(),
          ),
        KkTableColumn<Channel>(
          id: 'verdict',
          en: 'verdict',
          value: (Channel c) => c.verdict.name,
          cell: (BuildContext context, Channel c) =>
              KkTableLevel(level: _verdictLevel(c.verdict), text: _verdictWord(c.verdict)),
        ),
        KkTableColumn<Channel>(
          id: 'note',
          en: 'reads',
          width: const KkTableWidth.flex(min: 96),
          truncate: true,
          value: (Channel c) => c.note,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final List<Sector> chosen = _chosen(station);
        final List<Sector> visible = _visible(chosen);
        final List<String> operators = <String>{
          for (final Sector s in station.sectors)
            if (s.level != KkLevel.offline) s.operator,
        }.toList()..sort();

        final Widget show = KkSegmented<_Show>(
          value: _show,
          onChanged: (_Show v) => setState(() => _show = v),
          segments: const <KkSegment<_Show>>[
            KkSegment<_Show>(value: _Show.all, label: 'all'),
            KkSegment<_Show>(value: _Show.up, label: 'nominal'),
            KkSegment<_Show>(value: _Show.trouble, label: 'trouble'),
            KkSegment<_Show>(value: _Show.offline, label: 'offline'),
          ],
        );
        final List<Widget> chips = <Widget>[
          for (final String op in operators)
            KkChip.filter(
              label: op,
              selected: _operators.contains(op),
              onSelected: (bool on) => setState(() => on ? _operators.add(op) : _operators.remove(op)),
            ),
        ];

        final Widget history = KkStatusTimeline(
          cjk: '稼働履歴',
          en: 'status history',
          meta: '${Station.historyLength} S',
          rows: <KkTimelineRow>[
            for (final Sector s in visible) KkTimelineRow(en: s.code, spans: timelineSpans(s.history)),
          ],
          axis: const <String>['-48 S', '-24 S', 'NOW'],
          onSpanTap: (KkTimelineHit hit) => openSector(context, visible[hit.row]),
        );
        final Widget feeds = KkCarousel(
          cjk: '監視映像',
          en: 'camera feeds',
          index: _feed.clamp(0, station.sectors.length - 1),
          onChanged: (int i) => setState(() => _feed = i),
          items: <KkCarouselItem>[
            for (int i = 0; i < station.sectors.length; i++)
              KkCarouselItem(
                caption: 'CAM-${kkFixed(i + 1, digits: 2)} · ${station.sectors[i].code}',
                onPressed: () => openSector(context, station.sectors[i]),
                child: _Feed(sector: station.sectors[i]),
              ),
          ],
        );

        return KkColumn(
          gap: 16,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.systems,
              note: '열두 개 구역의 상태. 넓은 창에서는 표로 정렬 · 선별 · 선택하고 상한을 고친다. 행을 누르면 상세 측면판이 열린다.',
              actions: <Widget>[
                KkStatusTag(
                  '${kkFixed(visible.length, digits: 2)} / ${kkFixed(station.sectors.length, digits: 2)} shown',
                  size: KkStatusTagSize.lg,
                ),
                KkButton(label: 'clear', cjk: '解除', icon: KkIcons.filter, onPressed: _filtered ? _clear : null),
              ],
            ),
            KkBreakpoint(
              builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
                // A phone or a narrow tablet: the sectors as a list, with a
                // search field and a select in place of the table's own.
                if (windowClass.isBelow(KkWindowClass.expanded)) {
                  return KkColumn(
                    gap: 16,
                    shrinkWrap: true,
                    children: <Widget>[
                      _Filters(
                        search: KkSearch<Sector>(
                          controller: _search,
                          placeholder: 'sector or operator',
                          hint: 'ENTER',
                          results: _query.trim().isEmpty
                              ? const <KkSearchResult<Sector>>[]
                              : <KkSearchResult<Sector>>[
                                  for (final Sector s
                                      in station.sectors.where((Sector s) => _matches(s, _query)).take(6))
                                    KkSearchResult<Sector>(
                                      value: s,
                                      code: s.code,
                                      title: '${s.en} · ${s.operator}',
                                      meta: s.level.word,
                                    ),
                                ],
                          onQuery: _setQuery,
                          onSelected: (KkSearchResult<Sector> r) => openSector(context, r.value),
                        ),
                        show: show,
                        order: _OrderSelect(sort: _sort, onChanged: (KkTableSort? s) => setState(() => _sort = s)),
                        operators: chips,
                      ),
                      if (visible.isEmpty)
                        KkEmpty(
                          cjk: '該当なし',
                          en: 'no sector matches',
                          sub: 'FILTERS HIDE ALL ${station.sectors.length} SECTORS',
                          action: KkButton(label: 'clear filters', cjk: '解除', icon: KkIcons.close, onPressed: _clear),
                        )
                      else
                        KkList(
                          dense: settings.dense,
                          semanticLabel: 'Sectors',
                          children: <Widget>[
                            for (final Sector s in visible) _SectorRow(sector: s, settings: settings, station: station),
                          ],
                        ),
                      if (visible.isNotEmpty) history,
                      _channels(station, settings, narrow: windowClass == KkWindowClass.compact),
                      feeds,
                    ],
                  );
                }
                // Wider: the table over the full width; it has its own
                // filter field and sorts by its headers.
                return KkColumn(
                  gap: 16,
                  shrinkWrap: true,
                  children: <Widget>[
                    _Filters(show: show, operators: chips),
                    _table(station, settings, chosen, roomy: constraints.maxWidth >= 1000),
                    KkRow(
                      gap: 16,
                      cross: KkCrossAlign.start,
                      children: <Widget>[
                        KkExpanded(
                          flex: 3,
                          child: visible.isEmpty
                              ? const KkEmpty(cjk: '履歴なし', en: 'no history', sub: 'NO SECTOR IS SHOWN', minHeight: 160)
                              : history,
                        ),
                        KkExpanded(
                          flex: 2,
                          child: KkColumn(
                            gap: 16,
                            shrinkWrap: true,
                            children: <Widget>[_channels(station, settings, narrow: false), feeds],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

KkLevel? _verdictLevel(Verdict verdict) => switch (verdict) {
  Verdict.go => KkLevel.nominal,
  Verdict.noGo => KkLevel.critical,
  Verdict.wait => KkLevel.caution,
  Verdict.fault => KkLevel.offline,
};

String _verdictWord(Verdict verdict) => switch (verdict) {
  Verdict.go => 'GO',
  Verdict.noGo => 'NO-GO',
  Verdict.wait => 'WAIT',
  Verdict.fault => 'FAULT',
};

/// How long a sector has been at the level it is at, as far back as its
/// history goes.
String _since(Sector sector) {
  final List<KkLevel> history = sector.history;
  int run = 0;
  for (int i = history.length - 1; i >= 0 && history[i] == sector.level; i--) {
    run++;
  }
  final bool whole = run >= history.length;
  return '${sector.level.word} FOR ${whole ? 'OVER ' : ''}${kkFixed(run, digits: 2)} S';
}

/// The block under a row of the table: what the row has no room for, and
/// what can be done about the sector.
class _SectorDetail extends StatelessWidget {
  const _SectorDetail({required this.sector, required this.station, required this.settings});

  final Sector sector;
  final Station station;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final bool offline = sector.level == KkLevel.offline;
    final bool mine = sector.operator == settings.operator;
    final String load = offline
        ? 'NO LOAD'
        : 'LOAD ${kkFixed(sector.load, digits: 3)} % OF LIMIT ${kkFixed(sector.limit, digits: 3)} %';
    return KkColumn(
      gap: 8,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkWrap(
          gap: 8,
          runGap: 8,
          children: <Widget>[
            KkStatusTag.status(sector.level),
            KkStatusTag(sector.operator, icon: KkIcons.user),
            if (sector.note.isNotEmpty) KkStatusTag(sector.note, level: sector.level),
            if (sector.acknowledged) const KkStatusTag('acknowledged', icon: KkIcons.check),
          ],
        ),
        KkText('$load · TEMPERATURE ${settings.temperature(sector.temp)} ${settings.tempSymbol} · ${_since(sector)}'),
        KkWrap(
          gap: 8,
          runGap: 8,
          children: <Widget>[
            KkButton(
              label: mine ? 'assigned' : 'assign to me',
              cjk: '担当',
              size: KkButtonSize.sm,
              onPressed: mine || offline ? null : () => station.assignSector(sector, settings.operator),
            ),
            if (offline)
              KkButton(
                label: 'restore',
                cjk: '復帰',
                size: KkButtonSize.sm,
                variant: KkButtonVariant.primary,
                onPressed: () => station.setSectorOffline(sector, offline: false),
              )
            else
              KkButton(
                label: 'isolate',
                cjk: '隔離',
                size: KkButtonSize.sm,
                variant: KkButtonVariant.danger,
                onPressed: () => isolateSector(context, station, sector),
              ),
          ],
        ),
      ],
    );
  }
}

/// The order of the phone's list: the four usual orders, and whatever else
/// the table was sorted by before the window got narrow.
class _OrderSelect extends StatelessWidget {
  const _OrderSelect({required this.sort, required this.onChanged});

  final KkTableSort? sort;
  final ValueChanged<KkTableSort?> onChanged;

  @override
  Widget build(BuildContext context) {
    final KkTableSort current = sort ?? _orders.first.$1;
    final bool usual = _orders.any(((KkTableSort, String) o) => o.$1 == current);
    return KkSelect<KkTableSort>(
      size: KkSelectSize.sm,
      value: current,
      semanticLabel: 'Order',
      onChanged: (KkTableSort value) => onChanged(value == _orders.first.$1 ? null : value),
      options: <KkSelectOption<KkTableSort>>[
        for (final (KkTableSort value, String label) in _orders)
          KkSelectOption<KkTableSort>(value: value, label: label),
        if (!usual)
          KkSelectOption<KkTableSort>(
            value: current,
            label: 'BY ${current.column.toUpperCase()} ${current.ascending ? 'UP' : 'DOWN'}',
          ),
      ],
    );
  }
}

/// The filter bar. Beside the table it holds the status switch and the
/// operators; over the phone's list also a search field and the order, which
/// the table has itself.
class _Filters extends StatelessWidget {
  const _Filters({this.search, required this.show, this.order, required this.operators});

  final Widget? search;
  final Widget show;
  final Widget? order;
  final List<Widget> operators;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
    final Widget? search = this.search;
    final Widget? order = this.order;
    final Widget chips = KkRow(
      gap: 12,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkPadding(
          padding: const EdgeInsets.only(top: 8),
          child: KkText.en('operator', size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
        ),
        KkExpanded(child: KkWrap(gap: 8, runGap: 8, children: operators)),
      ],
    );
    final Widget content;
    if (search == null || order == null) {
      content = KkRow(
        gap: 24,
        cross: KkCrossAlign.start,
        children: <Widget>[
          show,
          KkExpanded(child: chips),
        ],
      );
    } else {
      content = KkColumn(
        gap: 12,
        shrinkWrap: true,
        children: <Widget>[
          if (compact) ...<Widget>[
            search,
            KkScroll(axis: Axis.horizontal, child: show),
            // The select keeps its own width at the left of the stretched column.
            KkAlignSelf(align: KkCrossAlign.start, child: order),
          ] else
            KkRow(
              gap: 12,
              children: <Widget>[
                KkExpanded(child: search),
                show,
                order,
              ],
            ),
          chips,
        ],
      );
    }
    return KkBox(
      decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }
}

class _SectorRow extends StatelessWidget {
  const _SectorRow({required this.sector, required this.settings, required this.station});

  final Sector sector;
  final AppSettings settings;
  final Station station;

  /// The quick actions of a row, in a menu at the row's right end.
  Future<void> _menu(BuildContext context) async {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final bool offline = sector.level == KkLevel.offline;
    final String? action = await showKkMenu<String>(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      align: KkPopupAlign.end,
      semanticLabel: 'Actions for ${sector.code}',
      entries: <KkMenuEntry<String>>[
        KkMenuLabel<String>(sector.code),
        const KkMenuItem<String>(value: 'open', label: 'open detail', cjk: '詳細', icon: KkIcons.external),
        KkMenuItem<String>(
          value: 'acknowledge',
          label: 'acknowledge',
          cjk: '確認',
          icon: KkIcons.check,
          enabled: sector.level != KkLevel.nominal && !sector.acknowledged,
        ),
        KkMenuItem<String>(
          value: 'assign',
          label: 'assign to me',
          cjk: '担当',
          icon: KkIcons.user,
          enabled: !offline && sector.operator != settings.operator,
        ),
        const KkMenuSeparator<String>(),
        if (offline)
          const KkMenuItem<String>(value: 'restore', label: 'restore', cjk: '復帰', icon: KkIcons.power)
        else
          const KkMenuItem<String>(value: 'isolate', label: 'isolate', cjk: '隔離', icon: KkIcons.power, danger: true),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'open':
        await openSector(context, sector);
      case 'acknowledge':
        station.acknowledgeSectors(<Sector>[sector], settings.operator);
      case 'assign':
        station.assignSector(sector, settings.operator);
      case 'restore':
        station.setSectorOffline(sector, offline: false);
      case 'isolate':
        await isolateSector(context, station, sector);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
    final bool offline = sector.level == KkLevel.offline;
    final String load = offline ? '---' : kkFixed(sector.load, digits: 3);
    final String detail = <String>[
      sector.operator,
      '${settings.temperature(sector.temp)} ${settings.tempSymbol}',
      if (sector.note.isNotEmpty) sector.note,
      if (sector.acknowledged) 'ACK',
    ].join(' · ');
    return KkListRow(
      level: sector.level,
      cjk: sector.cjk,
      en: '${sector.code} ${sector.en}',
      sub: detail,
      meta: '$load %',
      trailing: compact ? const KkIcon(KkIcons.chevronRight) : KkStatusTag.status(sector.level),
      semanticLabel: '${sector.code} ${sector.en}, ${sector.level.word}, load $load percent',
      onPressed: () => openSector(context, sector),
      onLongPress: () => _menu(context),
    );
  }
}

/// What a sector's camera shows: its name over the ground of its level, or
/// the no-signal card when the sector is offline.
class _Feed extends StatelessWidget {
  const _Feed({required this.sector});

  final Sector sector;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    if (sector.level == KkLevel.offline) {
      return const KkEmpty.noSignal(minHeight: 0, padding: EdgeInsets.all(8));
    }
    final bool trouble = sector.level != KkLevel.nominal;
    return KkLayers(
      expand: true,
      children: <Widget>[
        KkBackdrop(
          kind: trouble ? KkBackdropKind.hex : KkBackdropKind.plot,
          level: trouble ? sector.level : null,
          fill: c.bg000,
          scanlines: true,
          alignment: Alignment.center,
          child: KkColumn(
            gap: 8,
            shrinkWrap: true,
            cross: KkCrossAlign.center,
            children: <Widget>[
              KkText.cjk(sector.cjk, size: 32, color: c.inkDim, squeeze: 0.8),
              KkStatusTag.status(sector.level),
            ],
          ),
        ),
        // The recording mark: a lamp that blinks, pinned to the corner.
        KkPositioned(
          top: 8,
          right: 8,
          child: KkBlink(
            child: KkRow(
              shrinkWrap: true,
              gap: 4,
              children: <Widget>[
                KkBox(width: 6, height: 6, fill: c.alert),
                KkText.en('rec', size: 10, spacing: 0.14, color: c.inkDim),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
