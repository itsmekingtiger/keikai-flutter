import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

const List<KkSegment<String>> _ranges = <KkSegment<String>>[
  KkSegment<String>(value: '1h', label: '1h'),
  KkSegment<String>(value: '6h', label: '6h'),
  KkSegment<String>(value: '24h', label: '24h', enabled: false),
  KkSegment<String>(value: '7d', label: '7d'),
];

const List<KkRadioOption<String>> _modes = <KkRadioOption<String>>[
  KkRadioOption<String>(value: 'auto', label: 'auto', cjk: '自動'),
  KkRadioOption<String>(value: 'manual', label: 'manual', cjk: '手動'),
  KkRadioOption<String>(value: 'locked', label: 'locked', enabled: false),
  KkRadioOption<String>(value: 'remote', label: 'remote'),
];

/// The box of the segment (or chip) whose label is [text].
RenderKkBox _boxAround(WidgetTester tester, String text) {
  return tester.renderObject<RenderKkBox>(find.ancestor(of: find.text(text), matching: find.byType(KkBox)).first);
}

void main() {
  setUpAll(loadKkFonts);

  const KkColors c = KkColors.standby;

  group('KkSegmented, single', () {
    testWidgets('a tap selects; the selected and disabled segments do nothing', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(
        tester,
        Hold<String>(
          initial: '1h',
          onChanged: changes.add,
          builder: (BuildContext context, String value, ValueChanged<String> set) =>
              KkSegmented<String>(segments: _ranges, value: value, onChanged: set),
        ),
      );
      await tester.tap(find.text('6H'));
      await tester.pump();
      expect(changes, <String>['6h']);
      await tester.tap(find.text('6H'));
      await tester.tap(find.text('24H'));
      await tester.pump();
      expect(changes, <String>['6h']);
      expect(_boxAround(tester, '6H').decoration!.fill, c.signal);
      expect(kkTextOf(tester, '6H').color, c.onFill);
      expect(kkTextOf(tester, '1H').color, c.inkDim);
      expect(kkTextOf(tester, '24H').color, c.inkFaint);
    });

    testWidgets('is 32 high: 30px segments inside a 1px outline', (WidgetTester tester) async {
      await pumpKk(tester, KkSegmented<String>(segments: _ranges, value: '1h', onChanged: (String v) {}));
      expect(tester.getSize(find.byType(KkSegmented<String>)).height, 32);
      expect(_boxAround(tester, '1H').size.height, 30);
      // 10px left of the lamp, 7px between lamp and text, 12px right of the text.
      final Rect seg = tester.getRect(find.ancestor(of: find.text('1H'), matching: find.byType(KkBox)).first);
      final Rect text = tester.getRect(find.text('1H'));
      expect(text.left - seg.left, 10 + 12 + 7);
      expect(seg.right - text.right, 12);
    });

    testWidgets('the lamp keeps its place: selecting never changes a width', (WidgetTester tester) async {
      Widget build(String value) => KkSegmented<String>(segments: _ranges, value: value, onChanged: (String v) {});
      await pumpKk(tester, build('1h'));
      final Size before = tester.getSize(find.byType(KkSegmented<String>));
      final double segBefore = _boxAround(tester, '6H').size.width;
      await tester.pumpWidget(kkHarness(build('6h')));
      expect(tester.getSize(find.byType(KkSegmented<String>)), before);
      expect(_boxAround(tester, '6H').size.width, segBefore);
    });

    testWidgets('without lamps the segments are 19px narrower', (WidgetTester tester) async {
      await pumpKk(tester, KkSegmented<String>(segments: _ranges, value: '1h', onChanged: (String v) {}));
      final double withLamp = _boxAround(tester, '6H').size.width;
      await pumpKk(tester, KkSegmented<String>(segments: _ranges, value: '1h', lamp: false, onChanged: (String v) {}));
      expect(_boxAround(tester, '6H').size.width, withLamp - 19);
    });

    testWidgets('arrow keys move the selection, skip disabled segments and wrap', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(
        tester,
        Hold<String>(
          initial: '6h',
          onChanged: changes.add,
          builder: (BuildContext context, String value, ValueChanged<String> set) =>
              KkSegmented<String>(segments: _ranges, value: value, onChanged: set),
        ),
      );
      // The group is one tab stop: Tab lands on the selected segment.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes, <String>['7d'], reason: '24h is disabled and is skipped');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changes.last, '1h', reason: 'wraps to the start');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(changes.last, '7d');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(changes.last, '1h');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes.last, '7d');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(changes.last, '6h');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab leaves the group in one step', (WidgetTester tester) async {
      final FocusNode after = FocusNode();
      addTearDown(after.dispose);
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSegmented<String>(segments: _ranges, value: '6h', onChanged: (String v) {}),
            KkButton(label: 'next', focusNode: after, onPressed: () {}),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('without a callback, or with enabled false, it is inert', (WidgetTester tester) async {
      await pumpKk(tester, const KkSegmented<String>(segments: _ranges, value: '6h'));
      await tester.tap(find.text('1H'));
      await tester.pump();
      expect(kkTextOf(tester, '6H').color, c.inkFaint);
      expect(_boxAround(tester, '6H').decoration, isNull);

      int calls = 0;
      await pumpKk(
        tester,
        KkSegmented<String>(segments: _ranges, value: '6h', enabled: false, onChanged: (String v) => calls++),
      );
      await tester.tap(find.text('1H'));
      expect(calls, 0);
    });

    testWidgets('expand shares the width equally', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 402,
          child: KkSegmented<String>(segments: _ranges, value: '6h', expand: true, onChanged: (String v) {}),
        ),
      );
      expect(tester.getSize(find.byType(KkSegmented<String>)).width, 402);
      for (final String label in <String>['1H', '6H', '24H', '7D']) {
        expect(_boxAround(tester, label).size.width, 100);
      }
    });

    testWidgets('a hovered idle segment turns bg-300 with ink text', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkStateOverride(
          hovered: true,
          child: KkSegmented<String>(segments: _ranges, value: '6h', onChanged: (String v) {}),
        ),
      );
      expect(_boxAround(tester, '1H').decoration!.fill, c.bg300);
      expect(kkTextOf(tester, '1H').color, c.ink);
      expect(_boxAround(tester, '6H').decoration!.fill, c.signal, reason: 'the selected one keeps its fill');
    });

    testWidgets('adding and removing segments keeps working', (WidgetTester tester) async {
      Widget build(int n) => KkSegmented<int>(
        segments: <KkSegment<int>>[for (int i = 0; i < n; i++) KkSegment<int>(value: i, label: 'ch.$i')],
        value: 0,
        onChanged: (int v) {},
      );
      await pumpKk(tester, build(4));
      await tester.pumpWidget(kkHarness(build(1)));
      await tester.pumpWidget(kkHarness(build(0)));
      await tester.pumpWidget(kkHarness(build(6)));
      expect(tester.takeException(), isNull);
      expect(find.text('CH.5'), findsOneWidget);
    });

    testWidgets('announces each segment as one of an exclusive group', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkSegmented<String>(segments: _ranges, value: '6h', onChanged: (String v) {}));
      expect(
        tester.getSemantics(find.text('6H')),
        isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('1H')),
        isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: false),
      );
      handle.dispose();
    });
  });

  group('KkSegmented, multi', () {
    const List<KkSegment<int>> channels = <KkSegment<int>>[
      KkSegment<int>(value: 1, label: 'ch.1'),
      KkSegment<int>(value: 2, label: 'ch.2'),
      KkSegment<int>(value: 3, label: 'ch.3'),
    ];

    testWidgets('each press toggles one segment', (WidgetTester tester) async {
      Set<int>? last;
      await pumpKk(
        tester,
        Hold<Set<int>>(
          initial: const <int>{1},
          onChanged: (Set<int> v) => last = v,
          builder: (BuildContext context, Set<int> values, ValueChanged<Set<int>> set) =>
              KkSegmented<int>.multi(segments: channels, values: values, onValuesChanged: set),
        ),
      );
      await tester.tap(find.text('CH.2'));
      await tester.pump();
      expect(last, <int>{1, 2});
      await tester.tap(find.text('CH.1'));
      await tester.pump();
      expect(last, <int>{2});
      await tester.tap(find.text('CH.2'));
      await tester.pump();
      expect(last, isEmpty);
    });

    testWidgets('arrows move the focus only; Space toggles', (WidgetTester tester) async {
      Set<int>? last;
      await pumpKk(
        tester,
        Hold<Set<int>>(
          initial: const <int>{},
          onChanged: (Set<int> v) => last = v,
          builder: (BuildContext context, Set<int> values, ValueChanged<Set<int>> set) =>
              KkSegmented<int>.multi(segments: channels, values: values, onValuesChanged: set),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(last, <int>{2});
    });

    testWidgets('announces toggle buttons', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkSegmented<int>.multi(segments: channels, values: const <int>{2}, onValuesChanged: (Set<int> v) {}),
      );
      expect(
        tester.getSemantics(find.text('CH.2')),
        isSemantics(isButton: true, hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });
  });

  group('KkChip', () {
    testWidgets('assist: 28 high, 12px side padding, calls onPressed', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(tester, KkChip(label: 'add note', icon: KkIcons.plus, onPressed: () => presses++));
      expect(tester.getSize(find.byType(KkChip)).height, 28);
      final Rect chip = tester.getRect(find.byType(KkChip));
      expect(tester.getRect(find.byType(KkIcon)).left - chip.left, 13);
      expect(chip.right - tester.getRect(find.text('ADD NOTE')).right, 13);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, c.signal);
      await tester.tap(find.byType(KkChip));
      expect(presses, 1);
    });

    testWidgets('filter: a press reports the opposite state and the lamp shows it', (WidgetTester tester) async {
      final List<bool> changes = <bool>[];
      await pumpKk(
        tester,
        Hold<bool>(
          initial: false,
          onChanged: changes.add,
          builder: (BuildContext context, bool on, ValueChanged<bool> set) =>
              KkChip.filter(label: 'critical', selected: on, onSelected: set),
        ),
      );
      RenderKkBox chip = _boxAround(tester, 'CRITICAL');
      final double width = chip.size.width;
      expect(chip.decoration!.fill, c.bg100);
      expect(chip.decoration!.edges.top.color, c.inkFaint);
      await tester.tap(find.byType(KkChip));
      await tester.pump();
      expect(changes, <bool>[true]);
      chip = _boxAround(tester, 'CRITICAL');
      expect(chip.decoration!.fill, c.signalDim);
      expect(chip.decoration!.edges.top.color, c.signal);
      expect(chip.size.width, width, reason: 'turning a filter on never changes its width');
      await tester.tap(find.byType(KkChip));
      await tester.pump();
      expect(changes, <bool>[true, false]);
    });

    testWidgets('filter: Enter toggles it from the keyboard', (WidgetTester tester) async {
      bool? last;
      await pumpKk(tester, KkChip.filter(label: 'critical', selected: false, onSelected: (bool v) => last = v));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(last, isTrue);
      expect(ringOf(tester, find.byType(KkChip)).visible, isTrue);
    });

    testWidgets('suggestion: dashed outline, dim ink', (WidgetTester tester) async {
      await pumpKk(tester, KkChip.suggestion(label: 'last 24h', onPressed: () {}));
      final RenderKkBox chip = _boxAround(tester, 'LAST 24H');
      expect(chip.decoration!.edges.top.dashed, isTrue);
      expect(kkTextOf(tester, 'LAST 24H').color, c.inkDim);
    });

    testWidgets('input: only the 20px remove button acts', (WidgetTester tester) async {
      int removed = 0;
      await pumpKk(tester, KkChip.input(label: 'op-07', onRemove: () => removed++));
      await tester.tap(find.text('OP-07'));
      expect(removed, 0);
      final Finder remove = find.byType(KkIcon);
      expect(tester.widget<KkIcon>(remove).icon, KkIcons.close);
      final Rect button = tester.getRect(find.ancestor(of: remove, matching: find.byType(KkBox)).first);
      expect(button.size, const Size(20, 20));
      // 4px right padding inside the 1px outline.
      expect(tester.getRect(find.byType(KkChip)).right - button.right, 5);
      await tester.tap(remove, warnIfMissed: false);
      expect(removed, 1);
    });

    testWidgets('input: the remove button is reachable by keyboard', (WidgetTester tester) async {
      int removed = 0;
      await pumpKk(tester, KkChip.input(label: 'op-07', onRemove: () => removed++));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(removed, 1);
    });

    testWidgets('disabled: offline outline, faint ink, no callbacks', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkChip(label: 'assist'),
            KkChip.filter(label: 'filter', selected: true),
            KkChip.input(label: 'input'),
            KkChip.suggestion(label: 'idea'),
          ],
        ),
      );
      for (final String label in <String>['ASSIST', 'FILTER', 'INPUT', 'IDEA']) {
        final RenderKkBox chip = _boxAround(tester, label);
        expect(chip.decoration!.edges.top.color, c.offline, reason: label);
        expect(chip.decoration!.fill, c.bg100, reason: label);
        expect(kkTextOf(tester, label).color, c.inkFaint, reason: label);
        await tester.tap(find.text(label));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('with enabled false nothing is called', (WidgetTester tester) async {
      int calls = 0;
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            KkChip(label: 'a', enabled: false, onPressed: () => calls++),
            KkChip.input(label: 'b', enabled: false, onRemove: () => calls++),
          ],
        ),
      );
      await tester.tap(find.text('A'));
      await tester.tap(find.byType(KkIcon), warnIfMissed: false);
      expect(calls, 0);
    });
  });

  group('KkCheckbox', () {
    testWidgets('toggles between false and true', (WidgetTester tester) async {
      final List<bool?> changes = <bool?>[];
      await pumpKk(
        tester,
        Hold<bool?>(
          initial: false,
          onChanged: changes.add,
          builder: (BuildContext context, bool? value, ValueChanged<bool?> set) =>
              KkCheckbox(value: value, label: 'log to file', cjk: '記録', onChanged: set),
        ),
      );
      await tester.tap(find.byType(KkCheckbox));
      await tester.pump();
      await tester.tap(find.text('LOG TO FILE'));
      await tester.pump();
      expect(changes, <bool?>[true, false]);
    });

    testWidgets('tristate cycles false, true, mixed', (WidgetTester tester) async {
      final List<bool?> changes = <bool?>[];
      await pumpKk(
        tester,
        Hold<bool?>(
          initial: false,
          onChanged: changes.add,
          builder: (BuildContext context, bool? value, ValueChanged<bool?> set) =>
              KkCheckbox(value: value, tristate: true, onChanged: set, semanticLabel: 'All sectors'),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byType(KkCheckbox));
        await tester.pump();
      }
      expect(changes, <bool?>[true, null, false, true]);
    });

    test('a null value needs tristate', () {
      expect(() => KkCheckbox(value: null, onChanged: (bool? v) {}), throwsAssertionError);
    });

    testWidgets('the box is 16 square with an 8px gap to the label', (WidgetTester tester) async {
      await pumpKk(tester, KkCheckbox(value: true, label: 'notify', onChanged: (bool? v) {}));
      final Rect box = tester.getRect(find.descendant(of: find.byType(KkCheckbox), matching: find.byType(CustomPaint)));
      expect(box.size, const Size(16, 16));
      expect(tester.getRect(find.text('NOTIFY')).left - box.right, 8);
      expect(tester.getSize(find.byType(KkCheckbox)).height, 16);
    });

    testWidgets('Space toggles it and keyboard focus rings the box', (WidgetTester tester) async {
      bool? last;
      await pumpKk(tester, KkCheckbox(value: false, autofocus: true, onChanged: (bool? v) => last = v));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(last, isTrue);
      final RenderKkFocusRing ring = ringOf(tester, find.byType(KkCheckbox));
      expect(ring.visible, isTrue);
      expect(ring.size, const Size(16, 16));
    });

    testWidgets('disabled: no callback, faint label', (WidgetTester tester) async {
      int calls = 0;
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            const KkCheckbox(value: true, label: 'interlock'),
            KkCheckbox(value: false, label: 'purge', enabled: false, onChanged: (bool? v) => calls++),
          ],
        ),
      );
      await tester.tap(find.text('INTERLOCK'));
      await tester.tap(find.text('PURGE'));
      expect(calls, 0);
      expect(kkTextOf(tester, 'INTERLOCK').color, c.inkFaint);
      expect(kkTextOf(tester, 'PURGE').color, c.inkFaint);
    });

    testWidgets('reports checked and mixed to accessibility', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkCheckbox(value: true, onChanged: (bool? v) {}, semanticLabel: 'On'),
            KkCheckbox(value: false, onChanged: (bool? v) {}, semanticLabel: 'Off'),
            KkCheckbox(value: null, tristate: true, onChanged: (bool? v) {}, semanticLabel: 'Some'),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('On')),
        isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true, isEnabled: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Off')), isSemantics(hasCheckedState: true, isChecked: false));
      expect(tester.getSemantics(find.bySemanticsLabel('Some')), isSemantics(isCheckStateMixed: true));
      handle.dispose();
    });
  });

  group('KkRadioGroup', () {
    testWidgets('a tap chooses; the chosen and disabled options do nothing', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(
        tester,
        Hold<String>(
          initial: 'auto',
          onChanged: changes.add,
          builder: (BuildContext context, String value, ValueChanged<String> set) =>
              KkRadioGroup<String>(options: _modes, value: value, onChanged: set),
        ),
      );
      await tester.tap(find.text('MANUAL'));
      await tester.pump();
      await tester.tap(find.text('MANUAL'));
      await tester.tap(find.text('LOCKED'));
      await tester.pump();
      expect(changes, <String>['manual']);
      expect(kkTextOf(tester, 'LOCKED').color, c.inkFaint);
      expect(kkTextOf(tester, 'MANUAL').color, c.ink);
    });

    testWidgets('column: 16px marks, 8px apart, starting at the left', (WidgetTester tester) async {
      await pumpKk(tester, KkRadioGroup<String>(options: _modes, value: 'auto', onChanged: (String v) {}));
      final Finder marks = find.descendant(of: find.byType(KkRadioGroup<String>), matching: find.byType(CustomPaint));
      expect(marks, findsNWidgets(4));
      expect(tester.getSize(marks.first), const Size(16, 16));
      // A row is as tall as its tallest part: the 16px mark, or the bilingual
      // label (two 15.6px lines sharing a baseline). Rows are 8px apart.
      final double rowHeight = tester.getSize(find.byType(KkOptionLabel).first).height;
      expect(rowHeight, inInclusiveRange(15.6, 19));
      final double step = tester.getTopLeft(marks.at(1)).dy - tester.getTopLeft(marks.at(0)).dy;
      expect(step, moreOrLessEquals((rowHeight < 16 ? 16 : rowHeight) + 8, epsilon: 0.01));
      expect(tester.getTopLeft(marks.first).dx, 0);
      expect(tester.getRect(find.text('自動')).left - tester.getRect(marks.first).right, 8);
    });

    testWidgets('row: options sit 16px apart and wrap', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 220,
          child: KkRadioGroup<String>(
            options: _modes,
            value: 'auto',
            direction: Axis.horizontal,
            onChanged: (String v) {},
          ),
        ),
      );
      final Finder marks = find.descendant(of: find.byType(KkRadioGroup<String>), matching: find.byType(CustomPaint));
      expect(tester.getTopLeft(marks.at(1)).dy, tester.getTopLeft(marks.at(0)).dy);
      expect(
        tester.getRect(marks.at(1)).left - tester.getRect(find.text('AUTO')).right,
        moreOrLessEquals(16, epsilon: 0.01),
      );
      expect(tester.getTopLeft(marks.last).dy, greaterThan(tester.getTopLeft(marks.first).dy), reason: 'wraps');
      expect(tester.takeException(), isNull);
    });

    testWidgets('arrow keys move the choice, skip disabled options and wrap', (WidgetTester tester) async {
      final List<String> changes = <String>[];
      await pumpKk(
        tester,
        Hold<String>(
          initial: 'manual',
          onChanged: changes.add,
          builder: (BuildContext context, String value, ValueChanged<String> set) =>
              KkRadioGroup<String>(options: _modes, value: value, onChanged: set),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(changes, <String>['remote'], reason: 'locked is skipped');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(changes.last, 'auto', reason: 'wraps');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(changes.last, 'remote');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(changes.last, 'auto');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes.last, 'remote');
    });

    testWidgets('with nothing chosen Tab lands on the first live option', (WidgetTester tester) async {
      String? chosen;
      await pumpKk(
        tester,
        KkRadioGroup<String>(
          options: const <KkRadioOption<String>>[
            KkRadioOption<String>(value: 'x', label: 'x', enabled: false),
            KkRadioOption<String>(value: 'y', label: 'y'),
            KkRadioOption<String>(value: 'z', label: 'z'),
          ],
          value: null,
          onChanged: (String v) => chosen = v,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(chosen, 'y');
    });

    testWidgets('an option whose value is null is chosen while the value is null', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String?> changes = <String?>[];
      await pumpKk(
        tester,
        Hold<String?>(
          initial: null,
          onChanged: changes.add,
          builder: (BuildContext context, String? value, ValueChanged<String?> set) => KkRadioGroup<String?>(
            options: const <KkRadioOption<String?>>[
              KkRadioOption<String?>(value: null, label: 'none'),
              KkRadioOption<String?>(value: 'a', label: 'bus a'),
            ],
            value: value,
            onChanged: set,
          ),
        ),
      );
      expect(tester.getSemantics(find.text('NONE')), isSemantics(hasCheckedState: true, isChecked: true));
      expect(tester.getSemantics(find.text('BUS A')), isSemantics(hasCheckedState: true, isChecked: false));
      await tester.tap(find.text('NONE'));
      await tester.tap(find.text('BUS A'));
      await tester.pump();
      await tester.tap(find.text('NONE'));
      await tester.pump();
      expect(changes, <String?>['a', null]);
      expect(tester.getSemantics(find.text('NONE')), isSemantics(hasCheckedState: true, isChecked: true));
      handle.dispose();
    });

    testWidgets('a group without a callback is inert', (WidgetTester tester) async {
      await pumpKk(tester, const KkRadioGroup<String>(options: _modes, value: 'auto'));
      await tester.tap(find.text('MANUAL'));
      expect(kkTextOf(tester, 'AUTO').color, c.inkFaint);
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces radio buttons', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, KkRadioGroup<String>(options: _modes, value: 'manual', onChanged: (String v) {}));
      expect(
        tester.getSemantics(find.text('MANUAL')),
        isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.text('LOCKED')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('empty and changing option lists do not throw', (WidgetTester tester) async {
      Widget build(int n) => KkRadioGroup<int>(
        options: <KkRadioOption<int>>[for (int i = 0; i < n; i++) KkRadioOption<int>(value: i, label: 'bus $i')],
        value: 0,
        onChanged: (int v) {},
      );
      await pumpKk(tester, build(0));
      await tester.pumpWidget(kkHarness(build(3)));
      await tester.pumpWidget(kkHarness(build(1)));
      expect(tester.takeException(), isNull);
    });
  });

  group('KkSwitch', () {
    testWidgets('a press reports the opposite state', (WidgetTester tester) async {
      final List<bool> changes = <bool>[];
      await pumpKk(
        tester,
        Hold<bool>(
          initial: false,
          onChanged: changes.add,
          builder: (BuildContext context, bool value, ValueChanged<bool> set) =>
              KkSwitch(value: value, label: 'aux power', cjk: '補助電源', onChanged: set),
        ),
      );
      await tester.tap(find.text('OFF'));
      await tester.pump();
      await tester.tap(find.text('AUX POWER'));
      await tester.pump();
      expect(changes, <bool>[true, false]);
    });

    testWidgets('the track is 24 high with two cells of at least 34', (WidgetTester tester) async {
      await pumpKk(tester, KkSwitch(value: true, onChanged: (bool v) {}));
      final Size size = tester.getSize(find.byType(KkSwitch));
      expect(size, const Size(70, 24));
      expect(_boxAround(tester, 'ON').size, const Size(34, 22));
      expect(_boxAround(tester, 'OFF').size, const Size(34, 22));
    });

    testWidgets('lights the current cell and outlines the track in signal when on', (WidgetTester tester) async {
      await pumpKk(tester, KkSwitch(value: false, onChanged: (bool v) {}));
      expect(_boxAround(tester, 'OFF').decoration!.fill, c.bg300);
      expect(kkTextOf(tester, 'OFF').color, c.ink);
      expect(_boxAround(tester, 'ON').decoration, isNull);
      expect(kkTextOf(tester, 'ON').color, c.inkFaint);

      await pumpKk(tester, KkSwitch(value: true, onChanged: (bool v) {}));
      expect(_boxAround(tester, 'ON').decoration!.fill, c.signal);
      expect(kkTextOf(tester, 'ON').color, c.onFill);
      expect(kkTextOf(tester, 'OFF').color, c.inkFaint);
      final RenderKkBox track = tester.renderObject<RenderKkBox>(
        find.ancestor(of: find.text('ON'), matching: find.byType(KkBox)).at(1),
      );
      expect(track.decoration!.edges.top.color, c.signal);
    });

    testWidgets('disabled: offline outline, the lit cell turns offline', (WidgetTester tester) async {
      await pumpKk(tester, const KkSwitch(value: true, label: 'bus b'));
      await tester.tap(find.byType(KkSwitch));
      expect(_boxAround(tester, 'ON').decoration!.fill, c.offline);
      expect(kkTextOf(tester, 'BUS B').color, c.inkFaint);
      final RenderKkBox track = tester.renderObject<RenderKkBox>(
        find.ancestor(of: find.text('ON'), matching: find.byType(KkBox)).at(1),
      );
      expect(track.decoration!.edges.top.color, c.offline);
    });

    testWidgets('custom words widen the cells as needed', (WidgetTester tester) async {
      await pumpKk(tester, KkSwitch(value: true, offLabel: 'SAFE', onLabel: 'ARMED', onChanged: (bool v) {}));
      expect(find.text('SAFE'), findsOneWidget);
      expect(_boxAround(tester, 'ARMED').size.width, greaterThan(34));
      expect(tester.getSize(find.byType(KkSwitch)).height, 24);
    });

    testWidgets('Enter toggles it; accessibility sees a switch', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      bool? last;
      await pumpKk(
        tester,
        KkSwitch(value: true, autofocus: true, onChanged: (bool v) => last = v, semanticLabel: 'Coolant pump'),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(last, isFalse);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Coolant pump')),
        isSemantics(hasToggledState: true, isToggled: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
