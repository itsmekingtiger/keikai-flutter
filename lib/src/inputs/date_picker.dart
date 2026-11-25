import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/clock.dart';
import '../widgets/text.dart';
import 'modality.dart';

/// The ISO 8601 week number of [date]: weeks start on Monday and week 1 is
/// the week that holds the year's first Thursday.
int kkIsoWeek(DateTime date) {
  final DateTime day = DateTime.utc(date.year, date.month, date.day);
  final DateTime thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final DateTime first = DateTime.utc(thursday.year);
  return 1 + thursday.difference(first).inDays ~/ 7;
}

/// The ISO 8601 week-numbering year of [date] (it differs from the calendar
/// year for a few days around New Year).
int kkIsoWeekYear(DateTime date) {
  final DateTime day = DateTime.utc(date.year, date.month, date.day);
  return day.add(Duration(days: DateTime.thursday - day.weekday)).year;
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _month(DateTime d) => DateTime.utc(d.year, d.month);
bool _same(DateTime? a, DateTime? b) => a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Says which month a [KkDatePicker] shows, and moves it.
class KkDatePickerController extends ChangeNotifier {
  /// Starts on the month of [month] (default: the current UTC month).
  KkDatePickerController({DateTime? month}) : _shown = _month(month ?? DateTime.now().toUtc());

  DateTime _shown;

  /// The first day (UTC) of the month on show.
  DateTime get month => _shown;

  /// Shows the month that holds [date].
  void show(DateTime date) {
    final DateTime m = _month(date);
    if (m == _shown) return;
    _shown = m;
    notifyListeners();
  }

  void next() => show(DateTime.utc(_shown.year, _shown.month + 1));

  void previous() => show(DateTime.utc(_shown.year, _shown.month - 1));

  void nextYear() => show(DateTime.utc(_shown.year + 1, _shown.month));

  void previousYear() => show(DateTime.utc(_shown.year - 1, _shown.month));
}

/// A month calendar for choosing one date.
///
/// 304px wide: a head with the month in mono and its name in signal, weekday
/// heads from Monday, ISO week numbers down the left, six weeks of days, and
/// a foot that states the chosen date. All dates are UTC.
///
/// Arrow keys move the focused day, Page Up / Page Down change the month
/// (with Shift: the year), Home / End go to Monday / Sunday, Enter or Space
/// chooses.
class KkDatePicker extends StatefulWidget {
  const KkDatePicker({
    super.key,
    this.value,
    this.onChanged,
    this.controller,
    this.firstDate,
    this.lastDate,
    this.selectableDayPredicate,
    this.today,
    this.caption = 'date',
    this.emptyValue = '----------',
    this.footer,
    this.showWeekNumbers = true,
    this.showTodayButton = true,
    this.monthNames = _months,
    this.weekdayNames = _weekdays,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel = 'Calendar',
  }) : assert(monthNames.length == 12),
       assert(weekdayNames.length == 7);

  static const List<String> _months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC', //
  ];
  static const List<String> _weekdays = <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  /// The chosen date, or null.
  final DateTime? value;

  /// Called with the chosen date at 00:00 UTC.
  final ValueChanged<DateTime>? onChanged;

  /// Which month is on show. Without one the picker starts on the month of
  /// [value] (or of today) and keeps its own.
  final KkDatePickerController? controller;

  /// Days before this cannot be chosen.
  final DateTime? firstDate;

  /// Days after this cannot be chosen.
  final DateTime? lastDate;

  /// Return false for days that cannot be chosen.
  final bool Function(DateTime day)? selectableDayPredicate;

  /// The day outlined as today. Defaults to the current UTC date.
  final DateTime? today;

  /// The small caption in the foot.
  final String caption;

  /// Shown in the foot while no date is chosen.
  final String emptyValue;

  /// A widget at the right of the foot, usually a small button.
  final Widget? footer;
  final bool showWeekNumbers;

  /// Show the button that returns to the month of today.
  final bool showTodayButton;

  /// Twelve month names, January first.
  final List<String> monthNames;

  /// Seven weekday names, Monday first.
  final List<String> weekdayNames;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String semanticLabel;

  @override
  State<KkDatePicker> createState() => _KkDatePickerState();
}

class _KkDatePickerState extends State<KkDatePicker> {
  KkDatePickerController? _ownController;
  FocusNode? _ownFocusNode;
  DateTime? _cursor;
  DateTime? _hovered;
  bool _keyboard = false;

  KkDatePickerController get _controller =>
      widget.controller ?? (_ownController ??= KkDatePickerController(month: widget.value ?? _today));
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'KkDatePicker'));

  DateTime get _today => _day(widget.today ?? DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    KkInputModality.watch();
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(KkDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    final DateTime? value = widget.value;
    if (value != null && !_same(value, oldWidget.value)) {
      _cursor = _day(value);
      _controller.show(value);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Whether [day] is inside the limits and passes the predicate.
  bool _allowed(DateTime day) {
    final DateTime? first = widget.firstDate;
    final DateTime? last = widget.lastDate;
    if (first != null && day.isBefore(_day(first))) return false;
    if (last != null && day.isAfter(_day(last))) return false;
    return widget.selectableDayPredicate?.call(day) ?? true;
  }

  bool _selectable(DateTime day) => widget.enabled && widget.onChanged != null && _allowed(day);

  bool get _canGoBack {
    final DateTime? first = widget.firstDate;
    return first == null || _controller.month.isAfter(_month(first));
  }

  bool get _canGoForward {
    final DateTime? last = widget.lastDate;
    return last == null || _controller.month.isBefore(_month(last));
  }

  DateTime get _effectiveCursor {
    final DateTime? c = _cursor;
    final DateTime shown = _controller.month;
    if (c != null && c.year == shown.year && c.month == shown.month) return c;
    final DateTime? value = widget.value;
    if (value != null && value.year == shown.year && value.month == shown.month) return _day(value);
    final DateTime today = _today;
    if (today.year == shown.year && today.month == shown.month) return today;
    return shown;
  }

  void _moveCursor(DateTime to) {
    DateTime target = _day(to);
    final DateTime? first = widget.firstDate;
    final DateTime? last = widget.lastDate;
    if (first != null && target.isBefore(_day(first))) target = _day(first);
    if (last != null && target.isAfter(_day(last))) target = _day(last);
    setState(() {
      _cursor = target;
      _keyboard = true;
    });
    _controller.show(target);
  }

  void _choose(DateTime day) {
    if (!_selectable(day)) return;
    setState(() => _cursor = day);
    _controller.show(day);
    widget.onChanged?.call(day);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    final DateTime c = _effectiveCursor;
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    DateTime? to;
    if (key == LogicalKeyboardKey.arrowLeft) to = DateTime.utc(c.year, c.month, c.day - 1);
    if (key == LogicalKeyboardKey.arrowRight) to = DateTime.utc(c.year, c.month, c.day + 1);
    if (key == LogicalKeyboardKey.arrowUp) to = DateTime.utc(c.year, c.month, c.day - 7);
    if (key == LogicalKeyboardKey.arrowDown) to = DateTime.utc(c.year, c.month, c.day + 7);
    if (key == LogicalKeyboardKey.home) to = DateTime.utc(c.year, c.month, c.day - (c.weekday - 1));
    if (key == LogicalKeyboardKey.end) to = DateTime.utc(c.year, c.month, c.day + (7 - c.weekday));
    if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown) {
      final int sign = key == LogicalKeyboardKey.pageUp ? -1 : 1;
      final int year = c.year + (shift ? sign : 0);
      final int month = c.month + (shift ? 0 : sign);
      // Keep the day of the month, clamped to the length of the target month.
      final int length = DateTime.utc(year, month + 1, 0).day;
      to = DateTime.utc(year, month, c.day > length ? length : c.day);
    }
    if (to != null) {
      _moveCursor(to);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        setState(() => _keyboard = true);
        _choose(c);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final DateTime shown = _controller.month;
    final DateTime today = _today;
    final DateTime? value = widget.value == null ? null : _day(widget.value!);
    final DateTime start = DateTime.utc(shown.year, shown.month, 1 - (shown.weekday - 1));
    final DateTime cursor = _effectiveCursor;
    final bool ring = _keyboard && _focusNode.hasFocus && widget.enabled;
    final Widget? footer = widget.footer;

    final Widget head = KkBox(
      height: 44,
      padding: EdgeInsets.fromLTRB(m.space3, 0, m.space2, 0),
      decoration: KkDecoration(
        fill: c.bg200,
        edges: KkEdges(bottom: KkSide(c.line, width: m.stroke1)),
      ),
      child: KkRow(
        gap: m.space2,
        children: <Widget>[
          KkText.num(
            '${shown.year.toString().padLeft(4, '0')}-${shown.month.toString().padLeft(2, '0')}',
            size: 18,
            weight: FontWeight.w500,
            color: c.ink,
          ),
          KkText.en(widget.monthNames[shown.month - 1], size: 13, spacing: 0.14, color: c.signal),
          const KkSpacer(),
          KkIconButton(
            icon: KkIcons.chevronLeft,
            onPressed: widget.enabled && _canGoBack ? _controller.previous : null,
            semanticLabel: 'Previous month',
          ),
          KkIconButton(
            icon: KkIcons.chevronRight,
            onPressed: widget.enabled && _canGoForward ? _controller.next : null,
            semanticLabel: 'Next month',
          ),
          if (widget.showTodayButton)
            KkIconButton(
              icon: KkIcons.target,
              onPressed: widget.enabled ? () => _controller.show(today) : null,
              semanticLabel: 'Today',
            ),
        ],
      ),
    );

    final Widget weekdays = KkBox(
      height: 24,
      child: KkRow(
        children: <Widget>[
          if (widget.showWeekNumbers)
            KkBox(
              width: 36,
              alignment: Alignment.center,
              child: KkText.num('WK', size: 10, color: c.inkFaint),
            ),
          for (int i = 0; i < 7; i++)
            KkExpanded(
              child: KkBox(
                alignment: Alignment.center,
                child: KkText.en(
                  widget.weekdayNames[i],
                  size: 10,
                  weight: FontWeight.w600,
                  spacing: 0.12,
                  color: i >= 5 ? c.inkDim : c.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );

    final List<Widget> weeks = <Widget>[
      for (int w = 0; w < 6; w++)
        KkRow(
          children: <Widget>[
            if (widget.showWeekNumbers)
              KkBox(
                width: 36,
                height: 34,
                alignment: Alignment.center,
                child: KkText.num(
                  kkIsoWeek(DateTime.utc(start.year, start.month, start.day + w * 7)).toString().padLeft(2, '0'),
                  size: 10,
                  color: c.inkFaint,
                ),
              ),
            for (int d = 0; d < 7; d++)
              KkExpanded(
                child: _buildDay(
                  DateTime.utc(start.year, start.month, start.day + w * 7 + d),
                  shown: shown,
                  today: today,
                  value: value,
                  focused: ring && _same(cursor, DateTime.utc(start.year, start.month, start.day + w * 7 + d)),
                  theme: theme,
                ),
              ),
          ],
        ),
    ];

    final Widget foot = KkBox(
      height: 40,
      padding: EdgeInsets.fromLTRB(m.space3, 0, m.space1, 0),
      edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
      child: KkRow(
        gap: m.space2,
        children: <Widget>[
          KkText.en(widget.caption, size: 10, weight: FontWeight.w600, spacing: 0.14, color: c.inkFaint),
          KkExpanded(
            child: KkText.num(
              value == null ? widget.emptyValue : kkFormatDate(value),
              size: 13,
              weight: FontWeight.w500,
              color: value == null ? c.inkFaint : c.ink,
            ),
          ),
          ?footer,
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: KkBox(
        width: 304,
        decoration: KkDecoration(
          fill: c.bg100,
          edges: KkEdges.line(widget.enabled ? c.line : c.offline, width: m.stroke1, dashed: !widget.enabled),
        ),
        child: KkColumn(
          shrinkWrap: true,
          children: <Widget>[
            head,
            Focus(
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              canRequestFocus: widget.enabled,
              onKeyEvent: _onKey,
              onFocusChange: (bool focused) => setState(() => _keyboard = focused && KkInputModality.keyboard),
              child: KkBox(
                padding: EdgeInsets.symmetric(vertical: m.space1),
                child: KkColumn(shrinkWrap: true, children: <Widget>[weekdays, ...weeks]),
              ),
            ),
            foot,
          ],
        ),
      ),
    );
  }

  Widget _buildDay(
    DateTime day, {
    required DateTime shown,
    required DateTime today,
    required DateTime? value,
    required bool focused,
    required KeikaiThemeData theme,
  }) {
    final bool selectable = _selectable(day);
    final bool out = day.month != shown.month || day.year != shown.year;
    return _KkDayCell(
      day: day,
      outside: out,
      weekend: day.weekday >= DateTime.saturday,
      today: _same(day, today),
      selected: _same(day, value),
      selectable: selectable,
      allowed: _allowed(day),
      enabled: widget.enabled,
      hovered: _same(day, _hovered) && selectable,
      focused: focused,
      theme: theme,
      onHover: (bool inside) {
        if (inside) {
          if (!_same(_hovered, day)) setState(() => _hovered = day);
        } else if (_same(_hovered, day)) {
          setState(() => _hovered = null);
        }
      },
      onTap: () {
        if (_focusNode.canRequestFocus) _focusNode.requestFocus();
        setState(() => _keyboard = false);
        _choose(day);
      },
    );
  }
}

class _KkDayCell extends StatelessWidget {
  const _KkDayCell({
    required this.day,
    required this.outside,
    required this.weekend,
    required this.today,
    required this.selected,
    required this.selectable,
    required this.allowed,
    required this.enabled,
    required this.hovered,
    required this.focused,
    required this.theme,
    required this.onHover,
    required this.onTap,
  });

  final DateTime day;
  final bool outside;
  final bool weekend;
  final bool today;
  final bool selected;
  final bool selectable;

  /// Inside the date limits. A day that is not is struck through.
  final bool allowed;
  final bool enabled;
  final bool hovered;
  final bool focused;
  final KeikaiThemeData theme;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KkColors c = theme.colors;
    final Color ink = selected
        ? c.onFill
        : !allowed || !enabled
        ? c.inkFaint
        : hovered
        ? c.ink
        : outside
        ? c.inkFaint
        : weekend
        ? c.inkDim
        : c.ink;
    final Color? fill = selected
        ? (enabled ? c.signal : c.offline)
        : hovered
        ? c.bg300
        : null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: selectable,
        selected: selected,
        label: kkFormatDate(day),
        onTap: selectable ? onTap : null,
        child: MouseRegion(
          cursor: selectable
              ? SystemMouseCursors.click
              : (allowed && enabled ? MouseCursor.defer : SystemMouseCursors.forbidden),
          onEnter: (PointerEnterEvent event) => onHover(true),
          onExit: (PointerExitEvent event) => onHover(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: selectable ? onTap : null,
            child: KkBox(
              padding: const EdgeInsets.all(1),
              child: CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _DayPainter(
                  text: day.day.toString(),
                  style: theme.type.mono(13, weight: selected ? FontWeight.w600 : FontWeight.w400, color: ink),
                  fill: fill,
                  outline: today && !selected ? c.signal : null,
                  focus: focused ? c.focus : null,
                  strike: enabled && !allowed ? c.inkFaint : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPainter extends CustomPainter {
  const _DayPainter({
    required this.text,
    required this.style,
    required this.fill,
    required this.outline,
    required this.focus,
    required this.strike,
  });

  final String text;
  final TextStyle style;
  final Color? fill;

  /// Today: a 1px line 4px inside the cell.
  final Color? outline;

  /// Keyboard focus: a 2px line 2px inside the cell.
  final Color? focus;

  /// A day that cannot be chosen is struck through.
  final Color? strike;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color? f = fill;
    if (f != null) canvas.drawRect(rect, Paint()..color = f);
    final Color? o = outline;
    if (o != null) {
      canvas.drawRect(
        rect.deflate(3.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = o,
      );
    }
    final Rect box = kkPaintText(canvas, text, style, rect.center, align: Alignment.center);
    final Color? s = strike;
    if (s != null) {
      canvas.drawRect(Rect.fromLTWH(box.left - 1, rect.center.dy, box.width + 2, 1), Paint()..color = s);
    }
    final Color? k = focus;
    if (k != null) {
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = k,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.focus != focus ||
      oldDelegate.strike != strike;
}
