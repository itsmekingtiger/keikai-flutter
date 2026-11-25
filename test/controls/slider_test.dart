import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/controls/controls.dart';

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
        KkBox(
          width: 208,
          child: KkSlider(value: 40, enabled: false, onChanged: (double v) => calls++),
        ),
      );
      await tester.tapAt(tester.getTopLeft(_track()) + const Offset(150, 11));
      expect(calls, 0);
    });

    testWidgets('layout: 200 wide at least, a 22px track row, 12px marks, 8px gaps', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkSlider(
          value: 62,
          cjk: '冷却流量',
          en: 'coolant flow',
          unit: '%',
          marks: const <KkSliderMark>[KkSliderMark(0), KkSliderMark(50, 'MID'), KkSliderMark(100)],
          onChanged: (double v) {},
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
      final Rect head = tester.getRect(find.byType(KkRow).first);
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
      await pumpKk(tester, KkSlider(value: 20, showValue: false, onChanged: (double v) {}));
      expect(tester.getSize(find.byType(KkSlider)), const Size(200, 22));
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
