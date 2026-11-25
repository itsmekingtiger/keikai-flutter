import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'fill_column.dart';
import 'state_word.dart';

/// One line of a [KkDataLog].
@immutable
class KkLogEntry {
  const KkLogEntry({this.id, required this.time, this.source = '', this.level, this.levelText, required this.message});

  /// Identifies the entry when the list changes. Defaults to the entry's
  /// content, so two entries with the same fields count as one.
  final Object? id;

  /// The time as text, such as `14:02:31.004Z`.
  final String time;

  /// Where it came from, such as `SEC-04`.
  final String source;
  final KkLevel? level;

  /// The level word. Defaults to the level's word, or `INFO`.
  final String? levelText;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is KkLogEntry &&
      other.id == id &&
      other.time == time &&
      other.source == source &&
      other.level == level &&
      other.levelText == levelText &&
      other.message == message;

  @override
  int get hashCode => Object.hash(id, time, source, level, levelText, message);
}

/// A running log in tabular mono: time, source, level, message.
///
/// A critical line sits on the deep alert colour. A line that was not in the
/// list before wipes in on a signal ground that then clears (1s). The log
/// fills a grid cell and scrolls inside it; on its own it is as tall as its
/// lines, up to [maxHeight]. While the view is at the newest line it follows
/// new lines as they arrive.
class KkDataLog extends StatefulWidget {
  const KkDataLog({
    super.key,
    required this.entries,
    this.headers = const <String>['TIME', 'SRC', 'LEVEL', 'MESSAGE'],
    this.timeWidth = 96,
    this.sourceWidth = 60,
    this.levelWidth = 92,
    this.rowHeight = 26,
    this.maxHeight,
    this.showHeader = true,
    this.newestFirst = false,
    this.autoScroll = true,
    this.animateNew = true,
    this.onEntryTap,
    this.controller,
    this.border = true,
    this.boot = true,
  });

  /// The lines, oldest first (or newest first with [newestFirst]).
  final List<KkLogEntry> entries;

  /// Column head labels, in order: time, source, level, message.
  final List<String> headers;

  /// Width of the time column. 0 hides it.
  final double timeWidth;

  /// Width of the source column. 0 hides it.
  final double sourceWidth;

  /// Width of the level column. 0 hides it.
  final double levelWidth;
  final double rowHeight;

  /// Limits the height of the lines area; taller logs scroll.
  final double? maxHeight;
  final bool showHeader;

  /// Whether [entries] has the newest line first; it decides which end the
  /// log follows.
  final bool newestFirst;

  /// Keep the newest line in view while the view is already at that end.
  final bool autoScroll;

  /// Play the wipe on lines that are new to the list.
  final bool animateNew;

  /// Makes lines focusable and pressable.
  final ValueChanged<KkLogEntry>? onEntryTap;
  final ScrollController? controller;
  final bool border;

  /// Wipe in when first shown.
  final bool boot;

  @override
  State<KkDataLog> createState() => _KkDataLogState();
}

class _KkDataLogState extends State<KkDataLog> {
  ScrollController? _own;
  final Set<Object> _fresh = <Object>{};

  ScrollController get _controller => widget.controller ?? (_own ??= ScrollController());

  static Object _idOf(KkLogEntry entry) => entry.id ?? entry;

  bool _atNewestEnd() {
    final ScrollController c = _controller;
    if (!c.hasClients) return true;
    final ScrollPosition p = c.position;
    return widget.newestFirst ? p.pixels <= p.minScrollExtent + 1 : p.pixels >= p.maxScrollExtent - 1;
  }

  @override
  void didUpdateWidget(KkDataLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.entries, widget.entries)) return;
    final Set<Object> before = <Object>{for (final KkLogEntry e in oldWidget.entries) _idOf(e)};
    final Set<Object> now = <Object>{for (final KkLogEntry e in widget.entries) _idOf(e)};
    bool added = false;
    for (final Object id in now) {
      if (!before.contains(id)) {
        added = true;
        if (widget.animateNew) _fresh.add(id);
      }
    }
    _fresh.removeWhere((Object id) => !now.contains(id));
    if (added && widget.autoScroll && _atNewestEnd()) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        final ScrollController c = _controller;
        if (!c.hasClients) return;
        final ScrollPosition p = c.position;
        c.jumpTo(widget.newestFirst ? p.minScrollExtent : p.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  Widget _cell(double width, Widget child) =>
      KkBox(width: width, alignment: Alignment.centerLeft, clip: true, child: child);

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final List<KkLogEntry> entries = widget.entries;

    Widget head(int column) => KkText.en(
      column < widget.headers.length ? widget.headers[column] : '',
      size: 10,
      weight: FontWeight.w600,
      spacing: 0.16,
      color: c.inkFaint,
    );

    final Widget header = KkBox(
      height: m.space6,
      padding: EdgeInsets.symmetric(horizontal: m.space3),
      decoration: KkDecoration(
        fill: c.bg200,
        edges: KkEdges(bottom: KkSide(c.line, width: m.stroke1)),
      ),
      child: KkRow(
        gap: m.space3,
        children: <Widget>[
          if (widget.timeWidth > 0) _cell(widget.timeWidth, head(0)),
          if (widget.sourceWidth > 0) _cell(widget.sourceWidth, head(1)),
          if (widget.levelWidth > 0) _cell(widget.levelWidth, head(2)),
          KkExpanded(
            child: KkBox(alignment: Alignment.centerLeft, clip: true, child: head(3)),
          ),
        ],
      ),
    );

    Widget rows = ListView.builder(
      controller: _controller,
      primary: false,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemExtent: widget.rowHeight,
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final KkLogEntry entry = entries[index];
        final Object id = _idOf(entry);
        return _LogRow(
          key: ValueKey<Object>(id),
          entry: entry,
          height: widget.rowHeight,
          timeWidth: widget.timeWidth,
          sourceWidth: widget.sourceWidth,
          levelWidth: widget.levelWidth,
          last: index == entries.length - 1,
          fresh: _fresh.contains(id),
          onSettled: () => _fresh.remove(id),
          onTap: widget.onEntryTap,
        );
      },
    );
    final double? max = widget.maxHeight;
    if (max != null) rows = KkBox(maxHeight: max, child: rows);

    final Widget log = Semantics(
      container: true,
      child: KkBox(
        decoration: KkDecoration(
          fill: c.bg100,
          edges: widget.border ? KkEdges.line(c.line, width: m.stroke1) : KkEdges.none,
        ),
        clip: true,
        child: KkFillColumn(leading: <Widget>[if (widget.showHeader) header], body: rows),
      ),
    );
    return widget.boot ? KkBoot(child: log) : log;
  }
}

class _LogRow extends StatefulWidget {
  const _LogRow({
    super.key,
    required this.entry,
    required this.height,
    required this.timeWidth,
    required this.sourceWidth,
    required this.levelWidth,
    required this.last,
    required this.fresh,
    required this.onSettled,
    required this.onTap,
  });

  final KkLogEntry entry;
  final double height;
  final double timeWidth;
  final double sourceWidth;
  final double levelWidth;
  final bool last;
  final bool fresh;
  final VoidCallback onSettled;
  final ValueChanged<KkLogEntry>? onTap;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hovered = false;

  static const List<double> _stops = <double>[0, 0.45, 1];
  static const List<double> _wipe = <double>[0, 1, 1];
  static const List<double> _wash = <double>[1, 1, 0];

  Widget _cell(double width, Widget child) =>
      KkBox(width: width, alignment: Alignment.centerLeft, clip: true, child: child);

  Widget _row(BuildContext context, {required double wash, required bool focused}) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkLogEntry e = widget.entry;
    final bool critical = e.level == KkLevel.critical;
    final Color base = critical
        ? c.alertDeep
        : _hovered
        ? c.bg300
        : const Color(0x00000000);
    final Color fill = wash <= 0 ? base : Color.lerp(base, c.signalDim, wash)!;
    return KkFocusRing(
      visible: focused,
      offset: -2,
      child: KkBox(
        height: widget.height,
        padding: EdgeInsets.symmetric(horizontal: m.space3),
        decoration: KkDecoration(
          fill: fill,
          edges: widget.last ? KkEdges.none : KkEdges(bottom: KkSide(c.bg200, width: m.stroke1)),
        ),
        opaque: true,
        child: KkRow(
          gap: m.space3,
          children: <Widget>[
            if (widget.timeWidth > 0)
              _cell(widget.timeWidth, KkText.num(e.time, size: 12, height: 1.5, color: critical ? c.ink : c.inkDim)),
            if (widget.sourceWidth > 0)
              _cell(widget.sourceWidth, KkText.num(e.source, size: 12, height: 1.5, color: critical ? c.ink : c.signal)),
            if (widget.levelWidth > 0)
              _cell(
                widget.levelWidth,
                KkStateWord(
                  level: e.level,
                  text: e.levelText,
                  size: 11,
                  gap: 6,
                  spacing: 0.12,
                  color: critical ? c.ink : null,
                ),
              ),
            KkExpanded(
              child: KkText.num(e.message, size: 12, height: 1.5, color: c.ink, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KkLogEntry e = widget.entry;
    final ValueChanged<KkLogEntry>? tap = widget.onTap;
    final String label = <String>[e.time, e.source, e.levelText ?? e.level?.word ?? 'INFO', e.message].join(' ');

    Widget animated(bool focused) => KkOneShot(
      duration: KkMotion.rowIn,
      stagger: false,
      enabled: widget.fresh,
      onDone: widget.onSettled,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) {
        return AnimatedBuilder(
          animation: progress,
          builder: (BuildContext context, Widget? child) {
            final double t = progress.value;
            final double shown = kkKeyframes(t, _stops, _wipe, steps: 10);
            final double wash = t >= 1 ? 0 : kkKeyframes(t, _stops, _wash, steps: 10);
            return ClipRect(
              clipBehavior: shown >= 1 ? Clip.none : Clip.hardEdge,
              clipper: _RowClipper(shown),
              child: _row(context, wash: wash, focused: focused),
            );
          },
        );
      },
    );

    Widget row;
    if (tap != null) {
      row = KkPressable(
        onPressed: () => tap(e),
        semanticLabel: label,
        excludeSemantics: true,
        builder: (BuildContext context, KkStates states) => animated(states.focused),
      );
    } else {
      row = Semantics(label: label, child: ExcludeSemantics(child: animated(false)));
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: row,
    );
  }
}

class _RowClipper extends CustomClipper<Rect> {
  const _RowClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_RowClipper oldClipper) => oldClipper.fraction != fraction;
}
