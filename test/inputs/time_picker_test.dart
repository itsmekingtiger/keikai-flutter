import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// Holds the time, the way an app would.
class _Host extends StatefulWidget {
  const _Host(this.initial, {this.showSeconds = false, this.hourStep = 1, this.minuteStep = 1});

  final KkTime initial;
  final bool showSeconds;
  final int hourStep;
  final int minuteStep;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late KkTime value = widget.initial;
  final List<KkTime> changes = <KkTime>[];

  @override
  Widget build(BuildContext context) => KkTimePicker(
    value: value,
    cjk: '開始時刻',
    en: 'start',
    showSeconds: widget.showSeconds,
    hourStep: widget.hourStep,
    minuteStep: widget.minuteStep,
    onChanged: (KkTime t) {
      changes.add(t);
      setState(() => value = t);
    },
  );
}

KkTime _value(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).value;
List<KkTime> _changes(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).changes;

/// The 64 x 52 boxes of the segments, left to right.
Finder get _segments => find.byWidgetPredicate((Widget w) => w is KkBox && w.width == 64 && w.height == 52);

Future<void> _focus(WidgetTester tester, int segment) async {
  await tester.tap(_segments.at(segment));
  await tester.pump();
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {String? character}) async {
  await tester.sendKeyEvent(key, character: character);
  await tester.pump();
  await tester.pump();
}

Future<void> _digit(WidgetTester tester, int d) => _key(
  tester,
  <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ][d],
  character: '$d',
);

/// Which segment shows as focused (2px signal edge), or -1.
int _focused(WidgetTester tester) {
  final List<KkBox> boxes = tester.widgetList<KkBox>(_segments).toList();
  for (int i = 0; i < boxes.length; i++) {
    if (boxes[i].decoration!.edges.top == KkSide(KkColors.standby.signal, width: 2)) return i;
  }
  return -1;
}

void main() {
  setUpAll(loadKkFonts);

  group('KkTime', () {
    test('value, formatting, ordering', () {
      const KkTime t = KkTime(14, 2, 31);
      expect(t.hour, 14);
      expect(t.minute, 2);
      expect(t.second, 31);
      expect(const KkTime(7, 5).second, 0);
      expect(t.format(), '14:02');
      expect(t.format(seconds: true), '14:02:31');
      expect(const KkTime(0, 0).format(seconds: true), '00:00:00');
      expect(t.toString(), 'KkTime(14:02:31)');
      expect(t.duration, const Duration(hours: 14, minutes: 2, seconds: 31));
      expect(t.copyWith(minute: 59), const KkTime(14, 59, 31));
      expect(t.copyWith(hour: 0, second: 0), const KkTime(0, 2));
      expect(t == const KkTime(14, 2, 31), isTrue);
      expect(t.hashCode, const KkTime(14, 2, 31).hashCode);
      expect(t == const KkTime(14, 2), isFalse);
      expect(t.compareTo(const KkTime(14, 2, 30)), greaterThan(0));
      expect(t.compareTo(const KkTime(14, 3)), lessThan(0));
      expect(t.compareTo(const KkTime(14, 2, 31)), 0);
      final List<KkTime> sorted = <KkTime>[const KkTime(23, 59), const KkTime(0, 0, 1), t]..sort();
      expect(sorted, <KkTime>[const KkTime(0, 0, 1), t, const KkTime(23, 59)]);
    });

    test('from a duration (wrapped into one day) and from a DateTime', () {
      expect(KkTime.fromDuration(const Duration(hours: 14, minutes: 2, seconds: 31)), const KkTime(14, 2, 31));
      expect(KkTime.fromDuration(const Duration(hours: 25)), const KkTime(1, 0));
      expect(KkTime.fromDuration(const Duration(seconds: -1)), const KkTime(23, 59, 59));
      expect(KkTime.fromDuration(const Duration(days: 3)), const KkTime(0, 0));
      expect(KkTime.fromDateTime(DateTime.utc(2026, 11, 25, 9, 41, 7)), const KkTime(9, 41, 7));
    });

    test('rejects values outside a day', () {
      expect(() => KkTime(24, 0), throwsAssertionError);
      expect(() => KkTime(0, 60), throwsAssertionError);
      expect(() => KkTime(0, 0, 60), throwsAssertionError);
      expect(() => KkTime(-1, 0), throwsAssertionError);
    });
  });

  group('KkTimePicker', () {
    testWidgets('layout: 64 x 52 segments, colons, captions, a head as wide as the digits, a frame', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(KkTime(14, 2)), padding: const EdgeInsets.all(20));
      expect(_segments, findsNWidgets(2));
      expect(find.text('14'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text(':'), findsOneWidget);
      expect(find.text('HH'), findsOneWidget);
      expect(find.text('MM'), findsOneWidget);
      expect(find.text('SS'), findsNothing);
      expect(find.text('開始時刻'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(find.text('UTC'), findsOneWidget);
      final Rect picker = tester.getRect(find.byType(KkTimePicker));
      final Rect hours = tester.getRect(_segments.at(0));
      final Rect minutes = tester.getRect(_segments.at(1));
      // The frame: 1px line, 16px at the sides, 12px above and below.
      expect(hours.left, picker.left + 1 + 16);
      expect(minutes.right, closeTo(picker.right - 1 - 16, 0.01));
      expect(tester.getRect(find.text('開始時刻')).top, greaterThanOrEqualTo(picker.top + 1 + 12));
      expect(tester.getRect(find.text('HH')).bottom, closeTo(picker.bottom - 1 - 12, 0.01));
      // 4px on each side of the colon.
      final Rect colon = tester.getRect(find.text(':'));
      expect(colon.left, closeTo(hours.right + 4, 0.01));
      expect(minutes.left, closeTo(colon.right + 4, 0.01));
      // The head spans the digits: label at their left edge, zone at their right.
      expect(tester.getRect(find.text('開始時刻')).left, hours.left);
      expect(tester.getRect(find.text('UTC')).right, closeTo(minutes.right, 0.01));
      // It hugs its content: it does not stretch to the 760px on offer.
      expect(picker.width, lessThan(220));
      // The digits: 36px mono; the captions centred under their segment.
      final Text digits = tester.widget<Text>(find.text('14'));
      expect(digits.style!.fontSize, 36);
      expect(digits.style!.fontFamily, contains('IBM Plex Mono'));
      expect(tester.getCenter(find.text('HH')).dx, closeTo(hours.center.dx, 0.5));
      expect(tester.getRect(find.text('HH')).top, closeTo(hours.bottom + 2, 0.01));
    });

    testWidgets('with seconds there are three segments; without a frame nothing is drawn around', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(KkTime(14, 2, 31), showSeconds: true));
      expect(_segments, findsNWidgets(3));
      expect(find.text('31'), findsOneWidget);
      expect(find.text(':'), findsNWidgets(2));
      expect(find.text('SS'), findsOneWidget);

      await pumpKk(
        tester,
        KkTimePicker(value: const KkTime(9, 5), onChanged: (KkTime t) {}, frame: false, zone: null),
        padding: const EdgeInsets.all(20),
      );
      final Rect picker = tester.getRect(find.byType(KkTimePicker));
      expect(tester.getRect(_segments.at(0)).topLeft, picker.topLeft);
      expect(find.text('UTC'), findsNothing);
      expect(find.text('09'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
    });

    testWidgets('a press focuses a segment: signal digits and a 2px signal edge, same size', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(KkTime(14, 2)), padding: const EdgeInsets.all(20));
      const KkColors c = KkColors.standby;
      expect(_focused(tester), -1);
      expect(tester.widget<Text>(find.text('14')).style!.color, c.ink);
      expect(tester.widget<KkBox>(_segments.at(0)).decoration!.edges.top, KkSide(c.inkFaint));
      final Offset digits = tester.getTopLeft(find.text('14'));
      await _focus(tester, 0);
      expect(_focused(tester), 0);
      expect(tester.widget<Text>(find.text('14')).style!.color, c.signal);
      expect(tester.widget<Text>(find.text('02')).style!.color, c.ink);
      expect(tester.getSize(_segments.at(0)), const Size(64, 52));
      expect(tester.getTopLeft(find.text('14')), digits);
      await _focus(tester, 1);
      expect(_focused(tester), 1);
      expect(tester.widget<Text>(find.text('14')).style!.color, c.ink);
    });

    testWidgets('arrow up and down change the focused segment by one', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(14, 2)));
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(15, 2));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(13, 2));
      expect(find.text('13'), findsOneWidget);
      await _focus(tester, 1);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(13, 3));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(13, 2));
      expect(_changes(tester), <KkTime>[
        const KkTime(15, 2),
        const KkTime(14, 2),
        const KkTime(13, 2),
        const KkTime(13, 3),
        const KkTime(13, 2),
      ]);
    });

    testWidgets('values wrap around: 23 to 00 and back, 59 to 00, with no carry', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(23, 59, 59), showSeconds: true));
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(0, 59, 59));
      expect(find.text('00'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(23, 59, 59));
      await _focus(tester, 1);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      // Minutes wrap; the hour stays.
      expect(_value(tester), const KkTime(23, 0, 59));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(23, 59, 59));
      await _focus(tester, 2);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(23, 59));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(23, 59, 59));
    });

    testWidgets('Page keys change by ten, Home and End go to the ends, Backspace and Delete to zero', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, const _Host(KkTime(14, 55)));
      await _focus(tester, 1);
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_value(tester), const KkTime(14, 5));
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_value(tester), const KkTime(14, 55));
      await _key(tester, LogicalKeyboardKey.home);
      expect(_value(tester), const KkTime(14, 0));
      await _key(tester, LogicalKeyboardKey.end);
      expect(_value(tester), const KkTime(14, 59));
      await _key(tester, LogicalKeyboardKey.backspace);
      expect(_value(tester), const KkTime(14, 0));
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.pageUp);
      // 14 + 10 = 24 wraps to 00.
      expect(_value(tester), const KkTime(0, 0));
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(_value(tester), const KkTime(14, 0));
      await _key(tester, LogicalKeyboardKey.end);
      expect(_value(tester), const KkTime(23, 0));
      await _key(tester, LogicalKeyboardKey.delete);
      expect(_value(tester), const KkTime(0, 0));
      // Already there: nothing is reported.
      final int count = _changes(tester).length;
      await _key(tester, LogicalKeyboardKey.home);
      expect(_changes(tester).length, count);
    });

    testWidgets('arrow left and right move between the segments and stop at the ends', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(14, 2, 31), showSeconds: true));
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused(tester), 0);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused(tester), 1);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused(tester), 2);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused(tester), 2);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(14, 2, 32));
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused(tester), 0);
      expect(_changes(tester), <KkTime>[const KkTime(14, 2, 32)]);
    });

    testWidgets('Tab goes through the segments in order', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(14, 2, 31), showSeconds: true));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(tester), 0);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(tester), 1);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(tester), 2);
    });

    testWidgets('typing two digits sets a segment and moves on to the next', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(0, 0), showSeconds: true));
      await _focus(tester, 0);
      await _digit(tester, 1);
      expect(_value(tester), const KkTime(1, 0));
      expect(_focused(tester), 0);
      await _digit(tester, 4);
      expect(_value(tester), const KkTime(14, 0));
      expect(_focused(tester), 1);
      await _digit(tester, 4);
      await _digit(tester, 5);
      expect(_value(tester), const KkTime(14, 45));
      expect(_focused(tester), 2);
      await _digit(tester, 0);
      await _digit(tester, 9);
      expect(_value(tester), const KkTime(14, 45, 9));
      // The last segment keeps the focus.
      expect(_focused(tester), 2);
    });

    testWidgets('typing: a digit that cannot start a two-digit value moves on at once', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(12, 30)));
      await _focus(tester, 0);
      // No hour starts with 3.
      await _digit(tester, 3);
      expect(_value(tester), const KkTime(3, 30));
      expect(_focused(tester), 1);
      // No minute starts with 6.
      await _digit(tester, 6);
      expect(_value(tester), const KkTime(3, 6));
      expect(_focused(tester), 1);
      // 2 then 7 is not an hour: the 7 stands alone.
      await _focus(tester, 0);
      await _digit(tester, 2);
      expect(_value(tester), const KkTime(2, 6));
      await _digit(tester, 7);
      expect(_value(tester), const KkTime(7, 6));
      expect(_focused(tester), 1);
      // 2 then 3 is.
      await _focus(tester, 0);
      await _digit(tester, 2);
      await _digit(tester, 3);
      expect(_value(tester), const KkTime(23, 6));
    });

    testWidgets('typing: leaving a segment or pressing an arrow ends a half-typed value', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(0, 0)));
      await _focus(tester, 0);
      await _digit(tester, 1);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _digit(tester, 2);
      // Not 12: the 1 was finished when the focus left.
      expect(_value(tester), const KkTime(2, 0));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(3, 0));
      await _digit(tester, 1);
      // Not 21, and not 31.
      expect(_value(tester), const KkTime(1, 0));
      // Letters and other keys are left alone.
      final int count = _changes(tester).length;
      await _key(tester, LogicalKeyboardKey.keyA, character: 'a');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_changes(tester).length, count);
    });

    testWidgets('steps: arrows snap to the step grid and wrap on it', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(22, 7), hourStep: 6, minuteStep: 5));
      await _focus(tester, 1);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(22, 10));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(22, 15));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(22, 0));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(22, 55));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(22, 0));
      // Typing is not bound to the grid.
      await _digit(tester, 0);
      await _digit(tester, 7);
      expect(_value(tester), const KkTime(22, 7));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(22, 5));
      // Hours in steps of six: 22 goes down to 18, then up over the top to 00.
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(18, 5));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(0, 5));
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_value(tester), const KkTime(6, 5));
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_value(tester), const KkTime(18, 5));
    });

    testWidgets('the wheel changes the segment under the pointer and does not scroll the page', (
      WidgetTester tester,
    ) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: const KkColumn(
            cross: KkCrossAlign.start,
            children: <Widget>[_Host(KkTime(14, 2)), KkBox(width: 400, height: 1200)],
          ),
        ),
      );
      final Offset minutes = tester.getCenter(_segments.at(1));
      await tester.sendEventToBinding(PointerScrollEvent(position: minutes, scrollDelta: const Offset(0, -40)));
      await tester.pump();
      expect(_value(tester), const KkTime(14, 3));
      await tester.sendEventToBinding(PointerScrollEvent(position: minutes, scrollDelta: const Offset(0, 40)));
      await tester.sendEventToBinding(PointerScrollEvent(position: minutes, scrollDelta: const Offset(0, 40)));
      await tester.pump();
      expect(_value(tester), const KkTime(14, 1));
      expect(scroll.offset, 0);
      // Beside the segments the page scrolls as usual.
      await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(350, 300), scrollDelta: Offset(0, 40)));
      await tester.pump();
      expect(scroll.offset, 40);
      expect(_value(tester), const KkTime(14, 1));
    });

    testWidgets('a vertical drag changes the segment: one step per 10px, up is more', (WidgetTester tester) async {
      await pumpKk(tester, const _Host(KkTime(14, 30)), padding: const EdgeInsets.all(100));
      final TestGesture drag = await tester.startGesture(tester.getCenter(_segments.at(1)));
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      await drag.moveBy(const Offset(0, -30));
      await tester.pump();
      // The first 20px are the touch slop that starts the drag; the 30px
      // after it are three steps, all in one event.
      expect(_value(tester), const KkTime(14, 33));
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(_value(tester), const KkTime(14, 31));
      // A long pull in one go, across the top of the hour: no step is lost
      // and the hour does not move.
      await drag.moveBy(const Offset(0, -300));
      await tester.pump();
      expect(_value(tester), const KkTime(14, 1));
      await drag.up();
      await tester.pump();
      // The dragged segment took the focus.
      expect(_focused(tester), 1);
    });

    testWidgets('several steps between two frames add up; an owner that ignores them is taken at its word', (
      WidgetTester tester,
    ) async {
      // An owner that follows: three key presses before the next frame.
      await pumpKk(tester, const _Host(KkTime(14, 58)));
      await _focus(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_changes(tester), <KkTime>[const KkTime(14, 59), const KkTime(14, 0), const KkTime(14, 1)]);
      expect(_value(tester), const KkTime(14, 1));
      // Two segments before the next frame: neither change is lost.
      await _digit(tester, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_value(tester), const KkTime(15, 5));

      // An owner that never takes the new value: the picker keeps showing the
      // owner's value, and after a frame each press starts from it again.
      final List<KkTime> changes = <KkTime>[];
      await pumpKk(tester, KkTimePicker(value: const KkTime(14, 2), onChanged: changes.add));
      await _focus(tester, 0);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(changes, <KkTime>[const KkTime(15, 2), const KkTime(15, 2)]);
      expect(find.text('14'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('read-only (no onChanged) and disabled: no focus, no change', (WidgetTester tester) async {
      await pumpKk(tester, const KkTimePicker(value: KkTime(14, 2)));
      await tester.tap(_segments.at(0), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      expect(_focused(tester), -1);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_focused(tester), -1);
      expect(find.text('14'), findsOneWidget);
      // Read-only keeps its solid look.
      expect(tester.widget<Text>(find.text('14')).style!.color, KkColors.standby.ink);

      final List<KkTime> changes = <KkTime>[];
      await pumpKk(tester, KkTimePicker(value: const KkTime(14, 2), onChanged: changes.add, enabled: false));
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('14')).style!.color, c.inkFaint);
      expect(tester.widget<Text>(find.text('UTC')).style!.color, c.inkFaint);
      expect(tester.widget<KkBox>(_segments.at(0)).decoration!.edges.top, KkSide(c.offline, dashed: true));
      await tester.tap(_segments.at(0), warnIfMissed: false);
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: tester.getCenter(_segments.at(0)), scrollDelta: const Offset(0, -40)),
      );
      await tester.pump();
      expect(changes, isEmpty);
      expect(_focused(tester), -1);
    });

    testWidgets('semantics: the time as a value, each segment adjustable', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const _Host(KkTime(23, 59)));
      final SemanticsNode picker = tester.getSemantics(find.byType(KkTimePicker));
      expect(picker.label, 'start');
      expect(picker.value, '23:59');
      final SemanticsNode hours = tester.getSemantics(find.bySemanticsLabel('Hours'));
      expect(hours.value, '23');
      expect(hours.increasedValue, '00');
      expect(hours.decreasedValue, '22');
      final SemanticsNode minutes = tester.getSemantics(find.bySemanticsLabel('Minutes'));
      expect(minutes.value, '59');
      hours.owner!.performAction(hours.id, SemanticsAction.increase);
      await tester.pump();
      expect(_value(tester), const KkTime(0, 59));
      minutes.owner!.performAction(minutes.id, SemanticsAction.decrease);
      await tester.pump();
      expect(_value(tester), const KkTime(0, 58));
      handle.dispose();
    });

    testWidgets('own captions, the alert theme, and a value changed from outside', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkTimePicker(
          value: const KkTime(6, 0, 15),
          onChanged: (KkTime t) {},
          showSeconds: true,
          hourLabel: '時',
          minuteLabel: '分',
          secondLabel: '秒',
          zone: 'JST',
          semanticLabel: 'Shift start',
        ),
        condition: KkCondition.alert,
      );
      expect(find.text('時'), findsOneWidget);
      expect(find.text('分'), findsOneWidget);
      expect(find.text('秒'), findsOneWidget);
      expect(tester.widget<Text>(find.text('JST')).style!.color, KkColors.alertTheme.signal);
      await pumpKk(
        tester,
        KkTimePicker(value: const KkTime(18, 45, 59), onChanged: (KkTime t) {}, showSeconds: true),
        condition: KkCondition.alert,
      );
      expect(find.text('18'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('59'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
