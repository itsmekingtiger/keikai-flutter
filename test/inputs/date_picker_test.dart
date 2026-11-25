import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

final DateTime _today = DateTime.utc(2026, 11, 24);

/// Holds the chosen date, the way an app would.
class _Host extends StatefulWidget {
  const _Host({this.initial, this.controller, this.firstDate, this.lastDate, this.predicate, this.focusNode});

  final DateTime? initial;
  final KkDatePickerController? controller;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime day)? predicate;
  final FocusNode? focusNode;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime? value = widget.initial;
  final List<DateTime> changes = <DateTime>[];

  void set(DateTime? v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) => KkDatePicker(
    value: value,
    today: _today,
    controller: widget.controller,
    firstDate: widget.firstDate,
    lastDate: widget.lastDate,
    selectableDayPredicate: widget.predicate,
    focusNode: widget.focusNode,
    onChanged: (DateTime day) {
      changes.add(day);
      setState(() => value = day);
    },
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

/// The cell of a day, found by its semantic label (`2026-11-18`). The foot
/// states the chosen date in the same words, so only cells are looked at.
Finder _day(String iso) => find.byElementPredicate(
  (Element e) => e.widget is MergeSemantics && e.renderObject?.debugSemantics?.label == iso,
  description: 'the day $iso',
);

/// Matches a canvas that draws a rectangle in [color] somewhere among its
/// calls, whatever else it draws before or after.
PaintPattern _rect(Color color, {PaintingStyle style = PaintingStyle.fill, double? strokeWidth}) {
  return paints..something((Symbol method, List<dynamic> arguments) {
    if (method != #drawRect) return false;
    final Paint paint = arguments[1] as Paint;
    return paint.color.toARGB32() == color.toARGB32() &&
        paint.style == style &&
        (strokeWidth == null || paint.strokeWidth == strokeWidth);
  });
}

/// The paint of a day cell.
Finder _paint(String iso) => find.descendant(of: _day(iso), matching: find.byType(CustomPaint));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// `2026-11` in the head.
String _shown(WidgetTester tester) {
  final RegExp month = RegExp(r'^\d{4}-\d{2}$');
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((Text t) => t.data)
      .whereType<String>()
      .firstWhere(month.hasMatch);
}

/// The week numbers down the left, top to bottom.
List<String> _weeks(WidgetTester tester) {
  final RegExp two = RegExp(r'^\d{2}$');
  final List<(double, String)> found = <(double, String)>[
    for (final Element e in find.byType(Text).evaluate())
      if (two.hasMatch((e.widget as Text).data ?? ''))
        (tester.getTopLeft(find.byWidget(e.widget)).dy, (e.widget as Text).data!),
  ]..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) f in found) f.$2];
}

void main() {
  setUpAll(loadKkFonts);
  setUp(KkInputModality.notePointer);

  group('kkIsoWeek', () {
    test('follows ISO 8601: Monday first, week 1 holds the first Thursday', () {
      expect(kkIsoWeek(DateTime.utc(2026)), 1);
      expect(kkIsoWeek(DateTime.utc(2027)), 53);
      expect(kkIsoWeekYear(DateTime.utc(2027)), 2026);
      expect(kkIsoWeek(DateTime.utc(2026, 12, 31)), 53);
      expect(kkIsoWeek(DateTime.utc(2027, 1, 3)), 53);
      expect(kkIsoWeek(DateTime.utc(2027, 1, 4)), 1);
      expect(kkIsoWeekYear(DateTime.utc(2027, 1, 4)), 2027);
      expect(kkIsoWeek(DateTime.utc(2025, 12, 29)), 1);
      expect(kkIsoWeekYear(DateTime.utc(2025, 12, 29)), 2026);
      expect(kkIsoWeek(DateTime.utc(2024, 12, 30)), 1);
      expect(kkIsoWeekYear(DateTime.utc(2024, 12, 30)), 2025);
      expect(kkIsoWeek(DateTime.utc(2021, 1, 3)), 53);
      expect(kkIsoWeekYear(DateTime.utc(2021, 1, 3)), 2020);
      expect(kkIsoWeek(DateTime.utc(2026, 11, 25)), 48);
      expect(kkIsoWeek(DateTime.utc(2026, 6, 15)), 25);
    });

    test('ignores the time of day and the time zone flag', () {
      expect(kkIsoWeek(DateTime.utc(2027, 1, 3, 23, 59)), 53);
      expect(kkIsoWeek(DateTime(2027, 1, 4, 0, 1)), 1);
    });

    test('every year from 1990 to 2060 has 52 or 53 weeks that run on without a gap', () {
      DateTime day = DateTime.utc(1990);
      int week = kkIsoWeek(day);
      while (day.year < 2061) {
        final DateTime next = DateTime.utc(day.year, day.month, day.day + 1);
        final int w = kkIsoWeek(next);
        if (next.weekday == DateTime.monday) {
          expect(w == week + 1 || (w == 1 && (week == 52 || week == 53)), isTrue, reason: '$next');
        } else {
          expect(w, week, reason: '$next');
        }
        week = w;
        day = next;
      }
    });
  });

  group('KkDatePicker', () {
    testWidgets('layout: 304 wide, head, weekday heads, six weeks with week numbers, foot', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _Host(initial: DateTime.utc(2026, 11, 18)), padding: const EdgeInsets.all(20));
      // 1 + head 44 + (4 + 24 + 6 x 34 + 4) + foot 40 + 1.
      expect(tester.getSize(find.byType(KkDatePicker)), const Size(304, 322));
      expect(_shown(tester), '2026-11');
      expect(find.text('NOV'), findsOneWidget);
      expect(tester.widget<Text>(find.text('NOV')).style!.color, KkColors.standby.signal);
      for (final String head in <String>['WK', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']) {
        expect(find.text(head), findsOneWidget);
      }
      // November 2026 starts on a Sunday: the first row is the week of 26 October.
      expect(_weeks(tester), <String>['44', '45', '46', '47', '48', '49']);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('2026-11-18'), findsOneWidget);
      // Week numbers take 36px; the seven days share the rest.
      final Rect picker = tester.getRect(find.byType(KkDatePicker));
      expect(tester.getRect(find.text('WK')).center.dx, closeTo(picker.left + 1 + 18, 0.5));
      expect(tester.getRect(find.text('MO')).center.dx, closeTo(picker.left + 1 + 36 + (302 - 36) / 14, 0.5));
    });

    testWidgets('week numbers around New Year: 2026-01-01 is in week 1, 2027-01-01 in week 53', (
      WidgetTester tester,
    ) async {
      final KkDatePickerController controller = KkDatePickerController(month: DateTime.utc(2026));
      addTearDown(controller.dispose);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, _Host(controller: controller), padding: const EdgeInsets.all(20));
      expect(_shown(tester), '2026-01');
      expect(_weeks(tester), <String>['01', '02', '03', '04', '05', '06']);
      // The row of week 01 holds 29 December 2025 to 4 January 2026.
      final double row = tester.getCenter(find.text('01')).dy;
      expect(tester.getCenter(_day('2025-12-29')).dy, closeTo(row, 0.5));
      expect(tester.getCenter(_day('2026-01-01')).dy, closeTo(row, 0.5));
      expect(tester.getCenter(_day('2026-01-04')).dy, closeTo(row, 0.5));
      expect(tester.getCenter(_day('2026-01-05')).dy, greaterThan(row + 30));

      controller.show(DateTime.utc(2027));
      await tester.pump();
      expect(_shown(tester), '2027-01');
      expect(_weeks(tester), <String>['53', '01', '02', '03', '04', '05']);
      final double first = tester.getCenter(find.text('53')).dy;
      expect(tester.getCenter(_day('2026-12-28')).dy, closeTo(first, 0.5));
      expect(tester.getCenter(_day('2027-01-01')).dy, closeTo(first, 0.5));
      expect(tester.getCenter(_day('2027-01-03')).dy, closeTo(first, 0.5));
      expect(tester.getCenter(_day('2027-01-04')).dy, closeTo(tester.getCenter(find.text('01')).dy, 0.5));
      handle.dispose();
    });

    testWidgets('month navigation: the buttons, the controller, across years, back to today', (
      WidgetTester tester,
    ) async {
      final KkDatePickerController controller = KkDatePickerController(month: DateTime.utc(2026, 11));
      addTearDown(controller.dispose);
      await pumpKk(tester, _Host(controller: controller), padding: const EdgeInsets.all(20));
      Finder button(KkIconData icon) => find.byWidgetPredicate((Widget w) => w is KkIconButton && w.icon == icon);

      await tester.tap(button(KkIcons.chevronRight));
      await tester.pump();
      expect(_shown(tester), '2026-12');
      expect(find.text('DEC'), findsOneWidget);
      await tester.tap(button(KkIcons.chevronRight));
      await tester.pump();
      expect(_shown(tester), '2027-01');
      expect(controller.month, DateTime.utc(2027));
      await tester.tap(button(KkIcons.chevronLeft));
      await tester.tap(button(KkIcons.chevronLeft));
      await tester.tap(button(KkIcons.chevronLeft));
      await tester.pump();
      expect(_shown(tester), '2026-10');

      controller.nextYear();
      await tester.pump();
      expect(_shown(tester), '2027-10');
      controller.previousYear();
      controller.previous();
      await tester.pump();
      expect(_shown(tester), '2026-09');
      controller.next();
      await tester.pump();
      expect(_shown(tester), '2026-10');
      controller.show(DateTime.utc(2024, 2, 29, 13));
      await tester.pump();
      expect(_shown(tester), '2024-02');
      expect(controller.month, DateTime.utc(2024, 2));
      // February 2024 starts on a Thursday and has 29 days.
      expect(_weeks(tester), <String>['05', '06', '07', '08', '09', '10']);

      await tester.tap(button(KkIcons.target));
      await tester.pump();
      expect(_shown(tester), '2026-11');
      // Moving about chose nothing.
      expect(_host(tester).changes, isEmpty);
      expect(find.text('----------'), findsOneWidget);
    });

    testWidgets('a press chooses a day; the foot states it; today is outlined', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      expect(_shown(tester), '2026-11');
      const KkColors c = KkColors.standby;
      // Today: a 1px signal outline, no fill.
      expect(_paint('2026-11-24'), _rect(c.signal, style: PaintingStyle.stroke, strokeWidth: 1));
      await tester.tap(_day('2026-11-18'));
      await tester.pump();
      expect(_host(tester).changes, <DateTime>[DateTime.utc(2026, 11, 18)]);
      expect(find.text('2026-11-18'), findsOneWidget);
      expect(tester.getSemantics(_day('2026-11-18')).flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(_day('2026-11-19')).flagsCollection.isSelected, isNot(Tristate.isTrue));
      // Chosen: a signal ground. No focus ring after a press.
      expect(_paint('2026-11-18'), _rect(c.signal));
      expect(_paint('2026-11-18'), isNot(_rect(c.focus, style: PaintingStyle.stroke, strokeWidth: 2)));
      // Choosing today replaces its outline with the ground.
      await tester.tap(_day('2026-11-24'));
      await tester.pump();
      expect(_host(tester).changes.last, DateTime.utc(2026, 11, 24));
      expect(_paint('2026-11-24'), _rect(c.signal));
      expect(_paint('2026-11-24'), isNot(_rect(c.signal, style: PaintingStyle.stroke, strokeWidth: 1)));
      handle.dispose();
    });

    testWidgets('a day of the neighbouring month can be chosen and brings that month in', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const _Host(), padding: const EdgeInsets.all(20));
      await tester.tap(_day('2026-12-03'));
      await tester.pump();
      expect(_host(tester).changes, <DateTime>[DateTime.utc(2026, 12, 3)]);
      expect(_shown(tester), '2026-12');
      expect(tester.getSemantics(_day('2026-12-03')).flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('limits: days outside cannot be chosen and the month buttons stop', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        _Host(
          firstDate: DateTime.utc(2026, 11, 9),
          lastDate: DateTime.utc(2026, 12, 4, 18),
          predicate: (DateTime d) => d.weekday != DateTime.sunday,
        ),
        padding: const EdgeInsets.all(20),
      );
      const KkColors c = KkColors.standby;
      Finder button(KkIconData icon) => find.byWidgetPredicate((Widget w) => w is KkIconButton && w.icon == icon);

      await tester.tap(_day('2026-11-08'), warnIfMissed: false);
      await tester.tap(_day('2026-11-15'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      expect(tester.getSemantics(_day('2026-11-08')).flagsCollection.isEnabled, Tristate.isFalse);
      expect(tester.getSemantics(_day('2026-11-10')).flagsCollection.isEnabled, Tristate.isTrue);
      // Struck through in faint ink.
      expect(_paint('2026-11-08'), _rect(c.inkFaint));
      expect(_paint('2026-11-10'), isNot(_rect(c.inkFaint)));
      // The first and the last day themselves can be chosen.
      await tester.tap(_day('2026-11-09'));
      await tester.pump();
      await tester.tap(_day('2026-12-04'));
      await tester.pump();
      expect(_host(tester).changes, <DateTime>[DateTime.utc(2026, 11, 9), DateTime.utc(2026, 12, 4)]);
      expect(_shown(tester), '2026-12');
      // December is the last month, November the first.
      expect(tester.widget<KkIconButton>(button(KkIcons.chevronRight)).onPressed, isNull);
      expect(tester.widget<KkIconButton>(button(KkIcons.chevronLeft)).onPressed, isNotNull);
      await tester.tap(button(KkIcons.chevronLeft));
      await tester.pump();
      expect(_shown(tester), '2026-11');
      expect(tester.widget<KkIconButton>(button(KkIcons.chevronLeft)).onPressed, isNull);
      await tester.tap(_day('2026-12-05'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).changes.length, 2);
      handle.dispose();
    });

    testWidgets('keyboard: arrows move by a day and a week, Home and End by the week, Enter chooses', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(initial: DateTime.utc(2026, 11, 18), focusNode: focus),
        padding: const EdgeInsets.all(20),
      );
      focus.requestFocus();
      await tester.pump();
      Future<DateTime> choose() async {
        await _key(tester, LogicalKeyboardKey.enter);
        return _host(tester).changes.last;
      }

      // From the chosen day (a Wednesday).
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(await choose(), DateTime.utc(2026, 11, 19));
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(await choose(), DateTime.utc(2026, 11, 17));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(await choose(), DateTime.utc(2026, 11, 24));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(await choose(), DateTime.utc(2026, 11, 10));
      await _key(tester, LogicalKeyboardKey.home);
      expect(await choose(), DateTime.utc(2026, 11, 9));
      await _key(tester, LogicalKeyboardKey.home);
      expect(await choose(), DateTime.utc(2026, 11, 9));
      await _key(tester, LogicalKeyboardKey.end);
      expect(await choose(), DateTime.utc(2026, 11, 15));
      // Space chooses too.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_host(tester).changes.last, DateTime.utc(2026, 11, 16));
    });

    testWidgets('keyboard: crossing the edge of the month brings the next one in; Page keys jump', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(initial: DateTime.utc(2026, 11, 30), focusNode: focus),
        padding: const EdgeInsets.all(20),
      );
      focus.requestFocus();
      await tester.pump();
      Future<DateTime> choose() async {
        await _key(tester, LogicalKeyboardKey.enter);
        return _host(tester).changes.last;
      }

      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_shown(tester), '2026-12');
      expect(await choose(), DateTime.utc(2026, 12));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_shown(tester), '2026-11');
      expect(await choose(), DateTime.utc(2026, 11, 24));
      // Page Down / Up: a month, keeping the day.
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_shown(tester), '2026-12');
      expect(await choose(), DateTime.utc(2026, 12, 24));
      await _key(tester, LogicalKeyboardKey.pageUp);
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(await choose(), DateTime.utc(2026, 10, 24));
      // With Shift: a year.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(_shown(tester), '2027-10');
      expect(await choose(), DateTime.utc(2027, 10, 24));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.pageUp);
      await _key(tester, LogicalKeyboardKey.pageUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(await choose(), DateTime.utc(2025, 10, 24));
    });

    testWidgets('keyboard: the day is clamped to the length of the month (31 Jan to 28 Feb, 29 in a leap year)', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(tester, _Host(initial: DateTime.utc(2027, 1, 31), focusNode: focus));
      focus.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.pageDown);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.last, DateTime.utc(2027, 2, 28));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.enter);
      // 28 Feb 2028 plus one day: the 29th exists.
      expect(_host(tester).changes.last, DateTime.utc(2028, 2, 29));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.last, DateTime.utc(2029, 2, 28));
    });

    testWidgets('keyboard: the cursor stops at the limits and Enter on a barred day does nothing', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(
          initial: DateTime.utc(2026, 11, 10),
          firstDate: DateTime.utc(2026, 11, 9),
          lastDate: DateTime.utc(2026, 11, 27),
          predicate: (DateTime d) => d.weekday != DateTime.sunday,
          focusNode: focus,
        ),
        padding: const EdgeInsets.all(20),
      );
      focus.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.last, DateTime.utc(2026, 11, 9));
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_shown(tester), '2026-11');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.last, DateTime.utc(2026, 11, 27));
      // Sunday the 22nd is inside the limits but barred by the predicate: the
      // cursor can stand on it, Enter does nothing.
      final int before = _host(tester).changes.length;
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.end);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.length, before);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).changes.last, DateTime.utc(2026, 11, 21));
    });

    testWidgets('the focus ring shows for the keyboard only, on the day the keys act on', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(initial: DateTime.utc(2026, 11, 18), focusNode: focus),
        padding: const EdgeInsets.all(20),
      );
      const KkColors c = KkColors.standby;
      final PaintPattern ring = _rect(c.focus, style: PaintingStyle.stroke, strokeWidth: 2);
      // Focused by a press: no ring.
      await tester.tap(_day('2026-11-18'));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(_paint('2026-11-18'), isNot(ring));
      // The first key shows it, on the day it moved to.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_paint('2026-11-19'), ring);
      expect(_paint('2026-11-18'), isNot(ring));
      // A press takes it away again; so does losing the focus.
      await tester.tap(_day('2026-11-20'));
      await tester.pump();
      expect(_paint('2026-11-20'), isNot(ring));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_paint('2026-11-27'), ring);
      focus.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_paint('2026-11-27'), isNot(ring));
      handle.dispose();
    });

    testWidgets('Tab reaches the month buttons and then the grid, where the ring shows at once', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(initial: DateTime.utc(2026, 11, 18), focusNode: focus),
        padding: const EdgeInsets.all(20),
      );
      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(_paint('2026-11-18'), _rect(KkColors.standby.focus, style: PaintingStyle.stroke, strokeWidth: 2));
      handle.dispose();
    });

    testWidgets('a value set from outside brings its month in, without upsetting other listeners', (
      WidgetTester tester,
    ) async {
      final KkDatePickerController controller = KkDatePickerController(month: DateTime.utc(2026, 11));
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkColumn(
          cross: KkCrossAlign.start,
          children: <Widget>[
            // Something else in the app that follows the month on show.
            ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) => KkText.num('month ${controller.month.month}', size: 12),
            ),
            _Host(initial: DateTime.utc(2026, 11, 18), controller: controller),
          ],
        ),
      );
      expect(find.text('month 11'), findsOneWidget);
      _host(tester).set(DateTime.utc(2027, 3, 5));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_shown(tester), '2027-03');
      expect(find.text('2027-03-05'), findsOneWidget);
      await tester.pump();
      expect(find.text('month 3'), findsOneWidget);
      // Clearing the value keeps the month on show.
      _host(tester).set(null);
      await tester.pump();
      expect(_shown(tester), '2027-03');
      expect(find.text('----------'), findsOneWidget);
    });

    testWidgets('with no onChanged it is read-only: nothing struck, nothing chosen, months still turn', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkDatePicker(value: DateTime.utc(2026, 11, 18), today: _today));
      const KkColors c = KkColors.standby;
      expect(_paint('2026-11-10'), isNot(_rect(c.inkFaint)));
      expect(_paint('2026-11-18'), _rect(c.signal));
      expect(tester.getSemantics(_day('2026-11-10')).flagsCollection.isEnabled, Tristate.isFalse);
      await tester.tap(_day('2026-11-10'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('2026-11-18'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.icon == KkIcons.chevronRight));
      await tester.pump();
      expect(_shown(tester), '2026-12');
      handle.dispose();
    });

    testWidgets('disabled: dashed, buttons off, no focus, the chosen day in the offline colour', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      final List<DateTime> changes = <DateTime>[];
      await pumpKk(
        tester,
        KkDatePicker(
          value: DateTime.utc(2026, 11, 18),
          today: _today,
          onChanged: changes.add,
          enabled: false,
          focusNode: focus,
        ),
      );
      const KkColors c = KkColors.standby;
      final KkBox frame = tester.widget<KkBox>(
        find.descendant(of: find.byType(KkDatePicker), matching: find.byType(KkBox)).first,
      );
      expect(frame.decoration!.edges.top, KkSide(c.offline, dashed: true));
      for (final KkIconButton b in tester.widgetList<KkIconButton>(find.byType(KkIconButton))) {
        expect(b.onPressed, isNull);
      }
      expect(_paint('2026-11-18'), _rect(c.offline));
      await tester.tap(_day('2026-11-10'), warnIfMissed: false);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(changes, isEmpty);
      expect(focus.hasFocus, isFalse);
      handle.dispose();
    });

    testWidgets('options: no week numbers, no today button, own names, caption, empty text and footer', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int cleared = 0;
      await pumpKk(
        tester,
        KkDatePicker(
          today: _today,
          onChanged: (DateTime d) {},
          showWeekNumbers: false,
          showTodayButton: false,
          caption: 'from',
          emptyValue: 'NOT SET',
          monthNames: const <String>['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'],
          weekdayNames: const <String>['月', '火', '水', '木', '金', '土', '日'],
          footer: KkButton(
            label: 'clear',
            size: KkButtonSize.sm,
            variant: KkButtonVariant.ghost,
            onPressed: () => cleared++,
          ),
        ),
        padding: const EdgeInsets.all(20),
      );
      expect(tester.getSize(find.byType(KkDatePicker)), const Size(304, 322));
      expect(find.text('WK'), findsNothing);
      expect(_weeks(tester), isEmpty);
      expect(find.byType(KkIconButton), findsNWidgets(2));
      expect(find.text('十一月'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('NOT SET'), findsOneWidget);
      // Seven columns share the full 302px.
      expect(tester.getSize(_day('2026-11-18')).width, closeTo(302 / 7, 0.01));
      expect(tester.getSize(_day('2026-11-18')).height, 34);
      await tester.tap(find.text('CLEAR'));
      expect(cleared, 1);
      handle.dispose();
    });

    testWidgets('the mouse lights the day under it', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, _Host(firstDate: DateTime.utc(2026, 11, 9)), padding: const EdgeInsets.all(20));
      const KkColors c = KkColors.standby;
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_day('2026-11-12')));
      await tester.pump();
      expect(_paint('2026-11-12'), _rect(c.bg300));
      // A day that cannot be chosen does not light up.
      await mouse.moveTo(tester.getCenter(_day('2026-11-05')));
      await tester.pump();
      expect(_paint('2026-11-12'), isNot(_rect(c.bg300)));
      expect(_paint('2026-11-05'), isNot(_rect(c.bg300)));
      handle.dispose();
    });

    testWidgets('semantics: a labelled group of day buttons', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, _Host(initial: DateTime.utc(2026, 11, 18)));
      expect(find.bySemanticsLabel('Calendar'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
      expect(find.bySemanticsLabel('Next month'), findsOneWidget);
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
      final SemanticsNode day = tester.getSemantics(_day('2026-11-18'));
      expect(day.flagsCollection.isButton, isTrue);
      expect(day.flagsCollection.isSelected, Tristate.isTrue);
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // 42 day cells, each with its full date.
      final RegExp date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(
        find.byElementPredicate(
          (Element e) => e.widget is MergeSemantics && date.hasMatch(e.renderObject?.debugSemantics?.label ?? ''),
        ),
        findsNWidgets(42),
      );
      handle.dispose();
    });

    testWidgets('the alert theme and a narrow parent do not break it', (WidgetTester tester) async {
      await pumpKk(tester, _Host(initial: DateTime.utc(2026, 11, 18)), condition: KkCondition.alert);
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('NOV')).style!.color, KkColors.alertTheme.signal);
      await pumpKk(tester, KkBox(width: 240, child: _Host(initial: DateTime.utc(2026, 11, 18))));
      expect(tester.takeException(), isNull);
    });
  });
}
