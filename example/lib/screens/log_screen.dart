import 'dart:async';
import 'dart:math' as math;

import 'package:keikai/keikai.dart';

import '../model/app_scope.dart';
import '../model/settings.dart';
import '../model/station.dart';
import '../shell/destinations.dart';
import '../widgets/live.dart';
import '../widgets/screen_header.dart';

/// The event log: every line the plant has written, narrowed by time, text
/// and level.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  static const Duration _all = Duration(days: 1);

  final TextEditingController _search = TextEditingController();
  String _query = '';
  Duration _window = const Duration(minutes: 15);
  bool _live = true;
  DateTime? _frozen;
  bool _loading = false;
  Timer? _load;

  /// The levels shown; a line without a level counts as INFO (null).
  final Set<KkLevel?> _levels = <KkLevel?>{null, ...KkLevel.values};

  @override
  void dispose() {
    _load?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Whether the search or the level chips hide lines (the time range is not
  /// a filter: it says which stretch of the log is on screen).
  bool get _filtered => _query.isNotEmpty || _levels.length < KkLevel.values.length + 1;

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _levels
        ..clear()
        ..add(null)
        ..addAll(KkLevel.values);
    });
  }

  /// Pretends to fetch the log again: skeleton lines for most of a second.
  void _reload() {
    _load?.cancel();
    setState(() => _loading = true);
    _load = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  bool _matches(LogLine line) {
    if (!_levels.contains(line.level)) return false;
    if (_query.isEmpty) return true;
    final String q = _query.toUpperCase();
    return line.source.contains(q) || line.message.contains(q);
  }

  Future<void> _open(BuildContext context, LogLine line) {
    return showKkDialog<void>(
      context: context,
      builder: (BuildContext context) => KkDialog(
        code: 'LOG-${kkFixed(line.serial, digits: 4)}',
        cjk: '記録',
        en: 'log line',
        level: line.level == KkLevel.critical ? KkLevel.critical : null,
        actions: <Widget>[
          KkButton(label: 'close', cjk: '閉', autofocus: true, onPressed: () => Navigator.of(context).pop()),
        ],
        child: KkColumn(
          gap: 12,
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkWrap(
              gap: 8,
              runGap: 8,
              children: <Widget>[
                KkStatusTag.status(line.level),
                KkStatusTag(line.source, icon: KkIcons.node),
                KkStatusTag('${kkFormatDate(line.time)} ${formatClock(line.time)}', icon: KkIcons.clock),
              ],
            ),
            KkText.num(line.message, size: 14, maxLines: 4, softWrap: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Live(
      builder: (BuildContext context, Station station, AppSettings settings) {
        final KkColors c = context.kk.colors;
        final DateTime end = _live ? station.now : (_frozen ?? station.now);
        final DateTime start = end.subtract(_window);
        final List<LogLine> inWindow = station.log
            .where((LogLine l) => !l.time.isBefore(start) && !l.time.isAfter(end))
            .toList();
        final List<LogLine> lines = inWindow.where(_matches).toList();

        int count(KkLevel? level) => inWindow.where((LogLine l) => l.level == level).length;

        // Events per minute over the last eight minutes of the window.
        const int buckets = 8;
        final DateTime lastMinute = DateTime.utc(end.year, end.month, end.day, end.hour, end.minute);
        final List<String> labels = <String>[];
        final List<double?> perMinute = <double?>[];
        final List<KkLevel?> worst = <KkLevel?>[];
        for (int i = buckets - 1; i >= 0; i--) {
          final DateTime from = lastMinute.subtract(Duration(minutes: i));
          final DateTime to = from.add(const Duration(minutes: 1));
          final List<LogLine> hit = lines.where((LogLine l) => !l.time.isBefore(from) && l.time.isBefore(to)).toList();
          labels.add(kkFormatTime(from, seconds: false));
          perMinute.add(hit.length.toDouble());
          KkLevel? level;
          for (final LogLine l in hit) {
            final KkLevel? lv = l.level;
            if (lv != null && lv != KkLevel.nominal && (level == null || lv.severity > level.severity)) level = lv;
          }
          worst.add(level);
        }

        final Widget range = KkTimeRange<Duration>(
          start: start.isBefore(station.log.first.time) ? station.log.first.time : start,
          end: end,
          live: _live,
          onLiveChanged: (bool on) => setState(() {
            _live = on;
            _frozen = on ? null : station.now;
          }),
          preset: _window,
          onPresetChanged: (Duration d) {
            setState(() => _window = d);
            _reload();
          },
          presets: const <KkSelectOption<Duration>>[
            KkSelectOption<Duration>(value: Duration(minutes: 1), label: 'LAST 1 MIN'),
            KkSelectOption<Duration>(value: Duration(minutes: 5), label: 'LAST 5 MIN'),
            KkSelectOption<Duration>(value: Duration(minutes: 15), label: 'LAST 15 MIN'),
            KkSelectOption<Duration>(value: _all, label: 'ALL'),
          ],
          onRefresh: _reload,
        );

        final Widget search = KkSearch<String>(
          controller: _search,
          placeholder: 'source or message',
          hint: 'ENTER',
          results: _query.isEmpty
              ? const <KkSearchResult<String>>[]
              : <KkSearchResult<String>>[
                  for (final String source in <String>{
                    for (final LogLine l in inWindow)
                      if (l.source.contains(_query.toUpperCase())) l.source,
                  }.take(5))
                    KkSearchResult<String>(
                      value: source,
                      code: source,
                      title: 'ALL LINES FROM $source',
                      meta: 'SOURCE',
                    ),
                ],
          onQuery: (String q) => setState(() => _query = q.trim()),
          onSelected: (KkSearchResult<String> r) {
            _search.text = r.value;
            setState(() => _query = r.value);
          },
        );

        KkChip chip(KkLevel? level) => KkChip.filter(
          label: '${level?.word ?? 'INFO'} ${kkFixed(count(level), digits: 2)}',
          selected: _levels.contains(level),
          semanticLabel: 'Show ${level?.word ?? 'INFO'} lines',
          onSelected: (bool on) => setState(() => on ? _levels.add(level) : _levels.remove(level)),
        );

        final Widget filters = KkBox(
          decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
          padding: const EdgeInsets.all(12),
          child: KkColumn(
            gap: 12,
            shrinkWrap: true,
            children: <Widget>[
              KkScroll(axis: Axis.horizontal, child: range),
              search,
              KkWrap(
                gap: 8,
                runGap: 8,
                children: <Widget>[chip(null), for (final KkLevel level in KkLevel.values) chip(level)],
              ),
            ],
          ),
        );

        final bool wide = KkWindowScope.of(context).isAtLeast(KkWindowClass.expanded);
        final Widget chart = KkBarChart(
          cjk: '発生件数',
          en: 'events per minute',
          meta: '${kkFixed(lines.length, digits: 3)} LINES',
          labels: labels,
          series: <KkSeries>[KkSeries(name: 'EVENTS', values: perMinute)],
          levels: worst,
          height: wide ? 208 : 120,
          showValues: true,
          // Whole events only: the axis runs to at least four so its ticks are whole too.
          yMin: 0,
          yMax: math.max(4, (perMinute.fold<double>(0, (double a, double? b) => math.max(a, b ?? 0)) / 4).ceil() * 4),
          yFormat: (double v) => v.round().toString(),
          valueFormat: (double v) => v.round().toString(),
          semanticLabel: 'Events per minute',
        );

        final Widget mix = KkCategoryBar(
          cjk: '水準内訳',
          en: 'level mix',
          meta: '${kkFixed(inWindow.length, digits: 3)} IN RANGE',
          segments: <KkSlice>[
            KkSlice(name: 'INFO', value: count(null).toDouble(), color: c.inkDim),
            for (final KkLevel level in KkLevel.values)
              KkSlice(name: level.word, value: count(level).toDouble(), level: level),
          ],
        );

        final Widget body;
        if (_loading) {
          body = KkBox(
            decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
            padding: const EdgeInsets.all(16),
            child: const KkColumn(
              gap: 16,
              shrinkWrap: true,
              children: <Widget>[
                KkProgress.indeterminate(cjk: '読込', en: 'loading'),
                KkSkeleton(lines: 4, widths: <double>[0.9, 0.7, 0.8, 0.5]),
                KkSkeleton(lines: 4, widths: <double>[0.6, 0.85, 0.4, 0.75]),
                KkSkeleton(lines: 3, widths: <double>[0.8, 0.55, 0.7]),
              ],
            ),
          );
        } else if (inWindow.isEmpty) {
          body = KkEmpty(
            cjk: '範囲外',
            en: 'no lines in range',
            sub: 'NOTHING WAS LOGGED IN THIS STRETCH OF TIME',
            action: KkButton(
              label: 'show all',
              cjk: '全件',
              icon: KkIcons.clock,
              onPressed: () => setState(() => _window = _all),
            ),
          );
        } else if (lines.isEmpty) {
          body = KkEmpty(
            cjk: '記録なし',
            en: 'no lines match',
            sub: '${kkFixed(inWindow.length, digits: 3)} LINES IN RANGE · NONE PASS THE FILTERS',
            action: KkButton(label: 'clear filters', cjk: '解除', icon: KkIcons.close, onPressed: _clear),
          );
        } else {
          body = KkDataLog(
            maxHeight: 468,
            rowHeight: settings.dense ? 22 : 26,
            timeWidth: KkWindowScope.of(context) == KkWindowClass.compact ? 0 : 96,
            entries: <KkLogEntry>[
              for (final LogLine l in lines)
                KkLogEntry(
                  id: l.serial,
                  time: formatClock(l.time),
                  source: l.source,
                  level: l.level,
                  message: l.message,
                ),
            ],
            onEntryTap: (KkLogEntry e) => _open(context, lines.firstWhere((LogLine l) => l.serial == e.id)),
          );
        }

        return KkColumn(
          gap: 16,
          shrinkWrap: true,
          children: <Widget>[
            ScreenHeader(
              destination: Destination.log,
              note: '발전소가 남긴 모든 기록. 시간 범위 · 검색어 · 수준으로 좁히고, 줄을 누르면 자세히 본다.',
              actions: <Widget>[
                KkButton(label: 'clear', cjk: '解除', icon: KkIcons.filter, onPressed: _filtered ? _clear : null),
                KkButton(
                  label: 'export',
                  cjk: '出力',
                  icon: KkIcons.download,
                  variant: KkButtonVariant.primary,
                  onPressed: lines.isEmpty
                      ? null
                      : () => context.notices.show(
                          code: 'LOG',
                          level: KkLevel.nominal,
                          message: 'EXPORTED ${kkFixed(lines.length, digits: 3)} LINES · LOG-${kkFormatDate(end)}.CSV',
                        ),
                ),
              ],
            ),
            if (wide)
              KkRow(
                gap: 16,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkExpanded(flex: 2, child: KkColumn(gap: 16, shrinkWrap: true, children: <Widget>[filters, mix])),
                  KkExpanded(flex: 3, child: chart),
                ],
              )
            else ...<Widget>[filters, chart, mix],
            body,
          ],
        );
      },
    );
  }
}
