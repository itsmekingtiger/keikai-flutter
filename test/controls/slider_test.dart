import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

/// The 22px track row of the slider under test.
Finder _track() => find.descendant(of: find.byType(KkSlider), matching: find.byType(CustomPaint)).first;

/// A 208px wide slider: 8px thumb, so 200px of travel, 2px per unit on 0…100.
Widget _slider({
  double initial = 20,
  double min = 0,
  double max = 100,
  int? divisions,
  ValueChanged<double>? onChanged,
  ValueChanged<double>? onStart,
  ValueChanged<double>? onEnd,
  bool autofocus = false,
}) {
  return KkBox(
    width: 208,
    child: Hold<double>(
      initial: initial,
      onChanged: onChanged,
      builder: (BuildContext context, double value, ValueChanged<double> set) => KkSlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        en: 'gain',
        autofocus: autofocus,
        onChanged: set,
        onChangeStart: onStart,
        onChangeEnd: onEnd,
      ),
    ),
  );
}

void main() {
  setUpAll(loadKkFonts);

  group('KkSlider maths', () {
    test('snap clamps to the range and snaps to divisions', () {
      expect(KkSlider.snap(50), 50);
      expect(KkSlider.snap(-10), 0);
      expect(KkSlider.snap(140), 100);
      expect(KkSlider.snap(double.nan), 0);
      expect(KkSlider.snap(double.infinity), 100);
      expect(KkSlider.snap(44, divisions: 10), 40);
      expect(KkSlider.snap(45, divisions: 10), 50);
      expect(KkSlider.snap(2.4, min: -6, max: 6, divisions: 12), 2);
      expect(KkSlider.snap(-5.6, min: -6, max: 6, divisions: 12), -6);
      expect(KkSlider.snap(0.34, min: 0, max: 1, divisions: 4), 0.25);
      expect(KkSlider.snap(99.9, divisions: 3), 100);
    });

    test('valueAt: the centre of the thumb follows the pointer', () {
      expect(KkSlider.valueAt(4, 208), 0);
      expect(KkSlider.valueAt(0, 208), 0);
      expect(KkSlider.valueAt(-50, 208), 0);
      expect(KkSlider.valueAt(104, 208), 50);
      expect(KkSlider.valueAt(204, 208), 100);
      expect(KkSlider.valueAt(999, 208), 100);
      expect(KkSlider.valueAt(54, 208, divisions: 4), 25);
      expect(KkSlider.valueAt(104, 208, min: -6, max: 6), 0);
      // No travel at all: the value stays at the minimum.
      expect(KkSlider.valueAt(10, 8), 0);
      expect(KkSlider.valueAt(10, 0, min: 3, max: 9), 3);
    });

    test('formatValue keeps a fixed digit count', () {
      expect(KkSlider.formatValue(42), '042');
      expect(KkSlider.formatValue(100), '100');
      expect(KkSlider.formatValue(0), '000');
      expect(KkSlider.formatValue(7, max: 10), '07');
      expect(KkSlider.formatValue(2, min: -6, max: 6), '2');
      expect(KkSlider.formatValue(-2, min: -6, max: 6), '-2');
      expect(KkSlider.formatValue(42.66, fractionDigits: 1), '042.7');
      expect(KkSlider.formatValue(0.5, max: 1, fractionDigits: 2), '0.50');
      expect(KkSlider.formatValue(-0.001, min: -6, max: 6), '0', reason: 'no negative zero');
      expect(KkSlider.formatValue(-40, min: -100, max: 0), '-040');
    });

    test('a slider needs max > min and positive divisions', () {
      expect(() => KkSlider(value: 0, min: 5, max: 5), throwsAssertionError);
      expect(() => KkSlider(value: 0, divisions: 0), throwsAssertionError);
    });
  });

  group('KkSlider', () {
    testWidgets('a tap moves the thumb there', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(tester, _slider(onChanged: changes.add));
      final Offset origin = tester.getTopLeft(_track());
      await tester.tapAt(origin + const Offset(104, 11));
      await tester.pump();
      expect(changes, <double>[50]);
      expect(find.text('050'), findsOneWidget);
      await tester.tapAt(origin + const Offset(2, 11));
      await tester.pump();
      expect(changes.last, 0);
      await tester.tapAt(origin + const Offset(207, 11));
      await tester.pump();
      expect(changes.last, 100);
    });

    testWidgets('a drag follows the pointer and reports start and end', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      final List<double> starts = <double>[];
      final List<double> ends = <double>[];
      await pumpKk(tester, _slider(onChanged: changes.add, onStart: starts.add, onEnd: ends.add));
      final Offset origin = tester.getTopLeft(_track());
      await tester.dragFrom(origin + const Offset(54, 11), const Offset(100, 0));
      await tester.pump();
      expect(changes.last, 75);
      expect(starts, <double>[20]);
      expect(ends, <double>[75]);
      // Every reported value lies on the way.
      expect(changes.every((double v) => v >= 20 && v <= 75), isTrue);
    });

    testWidgets('a tap is a whole gesture: start, change, end', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        _slider(
          onChanged: (double v) => log.add('change $v'),
          onStart: (double v) => log.add('start $v'),
          onEnd: (double v) => log.add('end $v'),
        ),
      );
      final Offset origin = tester.getTopLeft(_track());
      await tester.tapAt(origin + const Offset(104, 11));
      await tester.pump();
      expect(log, <String>['start 20.0', 'change 50.0', 'end 50.0']);

      // A press on the thumb changes nothing, but it is still a gesture.
      log.clear();
      await tester.tapAt(origin + const Offset(104, 11));
      await tester.pump();
      expect(log, <String>['start 50.0', 'end 50.0']);
    });

    testWidgets('a press that turns into a drag starts once and ends once', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        _slider(
          onChanged: (double v) => log.add('change $v'),
          onStart: (double v) => log.add('start $v'),
          onEnd: (double v) => log.add('end $v'),
        ),
      );
      final Offset origin = tester.getTopLeft(_track());
      final TestGesture gesture = await tester.startGesture(origin + const Offset(104, 11));
      // Held still, the press is recognised and the thumb jumps under it.
      await tester.pump(const Duration(milliseconds: 150));
      expect(log, <String>['start 20.0', 'change 50.0']);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(log.first, 'start 20.0');
      expect(log.last, 'end 75.0');
      expect(log.where((String line) => line.startsWith('start')), hasLength(1));
      expect(log.where((String line) => line.startsWith('end')), hasLength(1));
      expect(find.text('075'), findsOneWidget);
    });

    testWidgets('a press held still and let go ends with the value it set', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        _slider(
          onChanged: (double v) => log.add('change $v'),
          onStart: (double v) => log.add('start $v'),
          onEnd: (double v) => log.add('end $v'),
        ),
      );
      final TestGesture gesture = await tester.startGesture(tester.getTopLeft(_track()) + const Offset(164, 11));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start 20.0', 'change 80.0', 'end 80.0']);
    });

    testWidgets('a press lost to a scroll view still ends', (WidgetTester tester) async {
      final List<String> log = <String>[];
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: KkColumn(
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              _slider(
                onChanged: (double v) => log.add('change $v'),
                onStart: (double v) => log.add('start $v'),
                onEnd: (double v) => log.add('end $v'),
              ),
              const KkBox(width: 10, height: 1200),
            ],
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(tester.getTopLeft(_track()) + const Offset(104, 11));
      await tester.pump(const Duration(milliseconds: 150));
      expect(log, <String>['start 20.0', 'change 50.0']);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(log, <String>['start 20.0', 'change 50.0', 'end 50.0']);
      expect(scroll.offset, greaterThan(0));
      await gesture.up();
      await tester.pump();
      expect(log, hasLength(3));
    });

    testWidgets('a key step is a whole gesture too', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        _slider(
          initial: 99,
          autofocus: true,
          onChanged: (double v) => log.add('change $v'),
          onStart: (double v) => log.add('start $v'),
          onEnd: (double v) => log.add('end $v'),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(log, <String>['start 99.0', 'change 100.0', 'end 100.0']);
      // At the end of the range there is nothing to start.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(log, hasLength(3));
    });

    testWidgets('a key during a press belongs to that press', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        _slider(
          autofocus: true,
          onChanged: (double v) => log.add('change $v'),
          onStart: (double v) => log.add('start $v'),
          onEnd: (double v) => log.add('end $v'),
        ),
      );
      await tester.pump();
      final TestGesture gesture = await tester.startGesture(tester.getTopLeft(_track()) + const Offset(104, 11));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start 20.0', 'change 50.0', 'change 51.0', 'end 51.0']);
    });

    testWidgets('an owner that declines a change is asked again from the value shown', (WidgetTester tester) async {
      final List<double> asked = <double>[];
      // The owner records the request and never rebuilds.
      await pumpKk(
        tester,
        KkBox(
          width: 208,
          child: KkSlider(value: 50, en: 'gain', autofocus: true, onChanged: asked.add),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(asked, <double>[51, 51, 49]);
      expect(find.text('050'), findsOneWidget);
      // The same for a pointer: the declined value can be asked for again.
      asked.clear();
      final Offset at = tester.getTopLeft(_track()) + const Offset(164, 11);
      await tester.tapAt(at);
      await tester.pump();
      await tester.tapAt(at);
      await tester.pump();
      expect(asked, <double>[80, 80]);
    });

    testWidgets('removed with a pointer on it: it ends quietly', (WidgetTester tester) async {
      final List<String> log = <String>[];
      bool show = true;
      double value = 20;
      late StateSetter rebuild;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            if (!show) return const KkBox(width: 208, height: 22);
            return KkBox(
              width: 208,
              child: KkSlider(
                value: value,
                en: 'gain',
                onChanged: (double v) => setState(() => value = v),
                onChangeStart: (double v) => log.add('start $v'),
                // An owner that rebuilds when the gesture ends, as one that
                // commits the value would.
                onChangeEnd: (double v) => setState(() => log.add('end $v')),
              ),
            );
          },
        ),
      );
      final TestGesture gesture = await tester.startGesture(tester.getTopLeft(_track()) + const Offset(104, 11));
      await tester.pump(const Duration(milliseconds: 150));
      expect(log, <String>['start 20.0']);
      expect(value, 50);
      rebuild(() => show = false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(log, <String>['start 20.0']);
    });

    testWidgets('disabled under the pointer: the gesture is dropped', (WidgetTester tester) async {
      final List<String> log = <String>[];
      bool enabled = true;
      double value = 20;
      late StateSetter rebuild;
      await pumpKk(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return KkBox(
              width: 208,
              child: KkSlider(
                value: value,
                en: 'gain',
                enabled: enabled,
                onChanged: (double v) => setState(() => value = v),
                onChangeStart: (double v) => log.add('start $v'),
                onChangeEnd: (double v) => setState(() => log.add('end $v')),
              ),
            );
          },
        ),
      );
      final TestGesture gesture = await tester.startGesture(tester.getTopLeft(_track()) + const Offset(104, 11));
      await tester.pump(const Duration(milliseconds: 150));
      expect(value, 50);
      rebuild(() => enabled = false);
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(value, 50);
      expect(log, <String>['start 20.0']);
      // Enabled again, it works as before.
      rebuild(() => enabled = true);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(_track()) + const Offset(164, 11));
      await tester.pump();
      expect(value, 80);
      expect(log, <String>['start 20.0', 'start 50.0', 'end 80.0']);
    });

    testWidgets('dragging past the ends clamps', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(tester, _slider(onChanged: changes.add));
      final Offset origin = tester.getTopLeft(_track());
      await tester.dragFrom(origin + const Offset(44, 11), const Offset(600, 0));
      await tester.pump();
      expect(changes.last, 100);
      await tester.dragFrom(origin + const Offset(204, 11), const Offset(-600, 0));
      await tester.pump();
      expect(changes.last, 0);
    });

    testWidgets('a vertical drag is left to the scroll view', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: KkColumn(
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              _slider(onChanged: changes.add),
              const KkBox(width: 10, height: 1200),
            ],
          ),
        ),
      );
      await tester.dragFrom(tester.getTopLeft(_track()) + const Offset(150, 11), const Offset(0, -120));
      await tester.pump();
      expect(changes, isEmpty);
      expect(scroll.offset, greaterThan(0));
    });

    testWidgets('divisions snap taps and drags to the steps', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(tester, _slider(initial: 0, divisions: 4, onChanged: changes.add));
      final Offset origin = tester.getTopLeft(_track());
      await tester.tapAt(origin + const Offset(70, 11));
      await tester.pump();
      expect(changes, <double>[25]);
      await tester.tapAt(origin + const Offset(140, 11));
      await tester.pump();
      expect(changes.last, 75);
    });

    testWidgets('keys: arrows step, Page keys step ten, Home and End jump', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(tester, _slider(initial: 50, autofocus: true, onChanged: changes.add));
      await tester.pump();
      Future<double> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
        return changes.last;
      }

      expect(await press(LogicalKeyboardKey.arrowRight), 51);
      expect(await press(LogicalKeyboardKey.arrowUp), 52);
      expect(await press(LogicalKeyboardKey.arrowLeft), 51);
      expect(await press(LogicalKeyboardKey.arrowDown), 50);
      expect(await press(LogicalKeyboardKey.pageUp), 60);
      expect(await press(LogicalKeyboardKey.pageDown), 50);
      expect(await press(LogicalKeyboardKey.home), 0);
      final int count = changes.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(changes.length, count, reason: 'already at the minimum: nothing to report');
      expect(await press(LogicalKeyboardKey.end), 100);
      expect(ringOf(tester, find.byType(KkSlider)).visible, isTrue);
      expect(ringOf(tester, find.byType(KkSlider)).offset, 4);
    });

    testWidgets('two key presses before a rebuild move two steps', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(tester, _slider(initial: 50, autofocus: true, onChanged: changes.add));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes, <double>[51, 52]);
    });

    testWidgets('keys move one division at a time', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpKk(
        tester,
        _slider(initial: 0, min: -6, max: 6, divisions: 12, autofocus: true, onChanged: changes.add),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes.last, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(changes.last, -6, reason: 'ten divisions down, clamped');
    });

    testWidgets('disabled: nothing moves it', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 208, child: KkSlider(value: 40, en: 'output')));
      final Offset origin = tester.getTopLeft(_track());
      await tester.tapAt(origin + const Offset(150, 11));
      await tester.dragFrom(origin + const Offset(84, 11), const Offset(60, 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('040'), findsOneWidget);
      expect(tester.takeException(), isNull);

      int calls = 0;
      await pumpKk(
        tester,
        KkBox(width: 208, child: KkSlider(value: 40, enabled: false, onChanged: (double v) => calls++)),
      );
      await tester.tapAt(tester.getTopLeft(_track()) + const Offset(150, 11));
      expect(calls, 0);
    });

    testWidgets('layout: 200 wide at least, a 22px track row, 12px marks, 8px gaps', (WidgetTester tester) async {
      // In a row the width is unbounded, so the slider falls back to its minimum.
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSlider(
              value: 62,
              cjk: '冷却流量',
              en: 'coolant flow',
              unit: '%',
              marks: const <KkSliderMark>[KkSliderMark(0), KkSliderMark(50, 'MID'), KkSliderMark(100)],
              onChanged: (double v) {},
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byType(KkSlider)).width, 200);
      final Finder paints = find.descendant(of: find.byType(KkSlider), matching: find.byType(CustomPaint));
      expect(paints, findsNWidgets(2));
      final Rect track = tester.getRect(paints.at(0));
      final Rect marks = tester.getRect(paints.at(1));
      expect(track.size, const Size(200, 22));
      expect(marks.size, const Size(200, 12));
      expect(marks.top - track.bottom, 8);
      final Rect head = tester.getRect(find.descendant(of: find.byType(KkSlider), matching: find.byType(KkRow)).first);
      expect(track.top - head.bottom, 8);
      expect(find.text('062'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('COOLANT FLOW'), findsOneWidget);
      // The value ends flush with the right edge; its unit follows 3px after the digits.
      expect(tester.getRect(find.text('%')).right, moreOrLessEquals(200, epsilon: 0.01));
      expect(
        tester.getRect(find.text('%')).left - tester.getRect(find.text('062')).right,
        moreOrLessEquals(3, epsilon: 0.01),
      );
    });

    testWidgets('track only: no head, just the 22px row', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(shrinkWrap: true, children: <Widget>[KkSlider(value: 20, showValue: false, onChanged: (double v) {})]),
      );
      expect(tester.getSize(find.byType(KkSlider)), const Size(200, 22));
    });

    testWidgets('takes the width it is offered, with or without a head', (WidgetTester tester) async {
      await pumpKk(tester, KkSlider(value: 20, showValue: false, onChanged: (double v) {}));
      expect(tester.getSize(find.byType(KkSlider)), const Size(800, 22));
      await pumpKk(tester, KkSlider(value: 20, en: 'gain', onChanged: (double v) {}));
      expect(tester.getSize(find.byType(KkSlider)).width, 800);
    });

    testWidgets('fills the width it is given and respects a narrower parent', (WidgetTester tester) async {
      await pumpKk(tester, KkBox(width: 480, child: KkSlider(value: 20, onChanged: (double v) {})));
      expect(tester.getSize(_track()).width, 480);
      await pumpKk(tester, KkBox(width: 90, child: KkSlider(value: 20, onChanged: (double v) {})));
      expect(tester.getSize(_track()).width, 90);
      expect(tester.takeException(), isNull);
    });

    testWidgets('format, unit and fraction digits', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSlider(value: 0.5, max: 1, fractionDigits: 2, onChanged: (double v) {}),
            KkSlider(value: 3, max: 6, format: (double v) => 'T+${v.round()}', unit: 'min', onChanged: (double v) {}),
          ],
        ),
      );
      expect(find.text('0.50'), findsOneWidget);
      expect(find.text('T+3'), findsOneWidget);
      expect(find.text('min'), findsOneWidget, reason: 'units keep their case');
    });

    testWidgets('values outside the range are shown clamped, never thrown on', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSlider(value: 150, onChanged: (double v) {}),
            KkSlider(value: -20, onChanged: (double v) {}),
            KkSlider(value: double.nan, max: 10, onChanged: (double v) {}),
            KkSlider(
              value: 5,
              max: 10,
              marks: const <KkSliderMark>[KkSliderMark(-40, 'LOW'), KkSliderMark(900, 'HIGH')],
              onChanged: (double v) {},
            ),
            KkSlider(value: 5, max: 10, marks: const <KkSliderMark>[KkSliderMark(5)], onChanged: (double v) {}),
            KkSlider(value: 5, max: 10, marks: const <KkSliderMark>[], onChanged: (double v) {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('000'), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
    });

    testWidgets('accessibility: a slider with a value that can be stepped', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<double> changes = <double>[];
      await pumpKk(
        tester,
        Hold<double>(
          initial: 40,
          onChanged: changes.add,
          builder: (BuildContext context, double value, ValueChanged<double> set) =>
              KkSlider(value: value, en: 'gain', unit: 'dB', onChanged: set),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('gain')),
        isSemantics(
          isSlider: true,
          label: 'gain',
          value: '040 dB',
          increasedValue: '041',
          decreasedValue: '039',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('gain'));
      await tester.pump();
      tester.semantics.decrease(find.semantics.byLabel('gain'));
      await tester.pump();
      expect(changes, <double>[41, 40]);
      handle.dispose();
    });

    testWidgets('the alert theme and a forced hover do not break it', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkStateOverride(
          hovered: true,
          focused: true,
          pressed: true,
          child: KkSlider(value: 40, onChanged: (double v) {}),
        ),
        condition: KkCondition.alert,
      );
      expect(tester.takeException(), isNull);
      expect(ringOf(tester, find.byType(KkSlider)).visible, isTrue);
      expect(ringOf(tester, find.byType(KkSlider)).color, KkColors.alertTheme.focus);
    });
  });
}
